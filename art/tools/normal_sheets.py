"""Bake a normal-map sheet beside every sprite sheet in a character folder: FILE.png -> FILE_n.png, same size and layout.
RGB = normal * 0.5 + 0.5 (OpenGL, green up, what Godot expects), alpha = the sprite's own alpha copied unchanged.
Each frame's depth comes from Depth-Anything-V2-Small (Apache-2.0, run the way the media-depth skill does) and is
blended 50/50 with a soft dome from the silhouette; sheets of 4+ frames are smoothed with their neighbours so the light
doesn't flicker. Sheets whose _n.png is newer are skipped unless --force.
Usage: HF_HOME=/home/danye/refs/depthtest/hf /home/danye/refs/depthtest/.venv/bin/python art/tools/normal_sheets.py
           art/elvis_blue [SHEET.png ...] [--force]
"""
import argparse, json, os, sys, time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

MODEL = 'depth-anything/Depth-Anything-V2-Small-hf'  # Apache-2.0; never Base/Large, they are CC-BY-NC-4.0
UP = 8            # nearest upscale before the model: it can't see 60 px sprites
PAD = 8           # grey border so the model sees the whole outline
GREY = 128
RELIEF = 10.0     # px of height the sprite's nearest-to-farthest depth spans
PILLOW_R = 4.0    # px in from the edge where the dome flattens out
BLEND_W = 0.5     # weight of the AI normal against the dome


def height_to_normal(hgt, mask, gain=1.0):
    """Tangent-space normal from a height map, +Y up. Edge heights are carried outward so the outline isn't a cliff."""
    filled = hgt
    if mask.any() and not mask.all():
        _, lab = cv2.distanceTransformWithLabels((~mask).astype(np.uint8), cv2.DIST_L2, 3, labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(mask)
        of_label = np.zeros(lab.max() + 1, np.int64)
        of_label[lab[mask]] = np.arange(len(ys))
        near = of_label[lab]
        filled = hgt[ys[near], xs[near]]
    gx = cv2.Sobel(filled, cv2.CV_32F, 1, 0, ksize=3) / 8.0
    gy = cv2.Sobel(filled, cv2.CV_32F, 0, 1, ksize=3) / 8.0
    n = np.dstack([-gx * gain, gy * gain, np.ones_like(gx)])  # image y is down, so +gy is +Y up
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    n[~mask] = (0, 0, 1)
    return n


def pillow_height(mask):
    t = np.clip(cv2.distanceTransform(mask.astype(np.uint8), cv2.DIST_L2, 3) / PILLOW_R, 0, 1)
    return cv2.GaussianBlur(PILLOW_R * np.sqrt(1 - (1 - t) ** 2), (0, 0), 0.7) * mask


def blend(n1, n2, w):
    n = w * n1 + (1 - w) * n2
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def centroid(mask):
    ys, xs = np.nonzero(mask)
    return np.array([xs.mean(), ys.mean()])


def shift_img(img, dx, dy, fill):
    out = np.full_like(img, fill)
    h, w = img.shape[:2]
    y0, y1, x0, x1 = max(dy, 0), min(h + dy, h), max(dx, 0), min(w + dx, w)
    out[y0:y1, x0:x1] = img[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return out


def aligned(normals, masks, t, s):
    """Frame s moved by the whole-body shift onto frame t, and where the two masks overlap."""
    dx, dy = np.round(centroid(masks[t]) - centroid(masks[s])).astype(int)
    return shift_img(normals[s], dx, dy, 0.0), shift_img(masks[s], dx, dy, False) & masks[t]


def temporal_smooth(normals, masks, loop):
    """0.25/0.5/0.25 with the neighbours, only where they overlap; a loop wraps, a one-shot doesn't."""
    k, out = len(normals), []
    for t in range(k):
        acc, wsum = normals[t] * 0.5, np.full(masks[t].shape, 0.5, np.float32)
        for s in (t - 1, t + 1):
            if not loop and not 0 <= s < k:
                continue
            s %= k
            if s == t or not masks[t].any() or not masks[s].any():
                continue
            ns, ms = aligned(normals, masks, t, s)
            acc[ms] += ns[ms] * 0.25
            wsum[ms] += 0.25
        n = acc / wsum[..., None]
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        n[~masks[t]] = (0, 0, 1)
        out.append(n)
    return out


def flicker(normals, masks):
    """Mean angle (deg) between neighbouring frames after lining up their bodies."""
    errs = []
    for t in range(len(normals) - 1):
        if masks[t].any() and masks[t + 1].any():
            ns, ms = aligned(normals, masks, t, t + 1)
            if ms.any():
                errs.append(np.degrees(np.arccos(np.clip((normals[t] * ns).sum(2)[ms], -1, 1))).mean())
    return float(np.mean(errs)) if errs else 0.0


class Depth:
    def __init__(self):
        import torch
        from transformers import AutoImageProcessor, AutoModelForDepthEstimation
        self.torch = torch
        self.proc = AutoImageProcessor.from_pretrained(MODEL)
        self.model = AutoModelForDepthEstimation.from_pretrained(MODEL).eval()

    def __call__(self, rgba, mask):
        """Depth at cell size, 0..1 inside the sprite (1 = nearest), 2nd-98th percentile."""
        h, w = mask.shape
        canvas = np.full((h + 2 * PAD, w + 2 * PAD, 3), GREY, np.uint8)
        canvas[PAD:PAD + h, PAD:PAD + w][mask] = rgba[..., :3][mask]  # the boss keeps data in alpha: any alpha is opaque
        big = cv2.resize(canvas, None, fx=UP, fy=UP, interpolation=cv2.INTER_NEAREST)
        inputs = self.proc(images=Image.fromarray(big), return_tensors='pt')
        with self.torch.no_grad():
            d = self.model(**inputs).predicted_depth
        d = self.torch.nn.functional.interpolate(d[None], size=big.shape[:2], mode='bicubic', align_corners=False)
        d = cv2.resize(d[0, 0].numpy().astype(np.float32), (w + 2 * PAD, h + 2 * PAD), interpolation=cv2.INTER_AREA)
        d = d[PAD:PAD + h, PAD:PAD + w]
        lo, hi = np.percentile(d[mask], [2, 98])
        return np.where(mask, np.clip((d - lo) / max(hi - lo, 1e-6), 0, 1), 0).astype(np.float32)


def frame_normal(depth, cell, mask):
    if not mask.any():
        return np.dstack([np.zeros(mask.shape + (2,), np.float32), np.ones(mask.shape, np.float32)])
    ai = height_to_normal(depth(cell, mask) * RELIEF, mask)
    return blend(ai, height_to_normal(pillow_height(mask), mask), BLEND_W)


def bake(depth, path, cw, loop):
    sheet = np.array(Image.open(path).convert('RGBA'))
    n_frames = sheet.shape[1] // cw
    cells = [sheet[:, i * cw:(i + 1) * cw] for i in range(n_frames)]
    masks = [c[..., 3] > 0 for c in cells]
    normals = [frame_normal(depth, c, m) for c, m in zip(cells, masks)]
    raw = flicker(normals, masks)
    if n_frames >= 4:
        normals = temporal_smooth(normals, masks, loop)
    out = np.zeros_like(sheet)
    out[..., 3] = sheet[..., 3]
    for i, (n, m) in enumerate(zip(normals, masks)):
        out[:, i * cw:(i + 1) * cw, :3][m] = ((n[m] * 0.5 + 0.5) * 255).round().astype(np.uint8)
    assert out.shape == sheet.shape
    dst = path.with_name(path.stem + '_n.png')
    Image.fromarray(out).save(dst)
    return n_frames, raw, flicker(normals, masks)


def self_check():
    yy, xx = np.mgrid[:21, :21]
    disc = (xx - 10) ** 2 + (yy - 10) ** 2 <= 64
    n = height_to_normal(pillow_height(disc), disc)
    assert n[10, 10, 2] > 0.99, 'disc middle faces the camera'
    assert n[10, 3, 0] < -0.3 and n[10, 17, 0] > 0.3, 'left/right rims face out'
    assert n[3, 10, 1] > 0.3 and n[17, 10, 1] < -0.3, 'top rim faces up (+Y), bottom faces down'
    k = [n] * 5
    s = temporal_smooth(k, [disc] * 5, loop=True)
    assert np.allclose(s[2], n, atol=1e-5) and flicker(k, [disc] * 5) < 0.1, 'still frames stay still'


def main():
    p = argparse.ArgumentParser()
    p.add_argument('folder'); p.add_argument('sheets', nargs='*'); p.add_argument('--force', action='store_true')
    a = p.parse_args()
    self_check()
    folder = Path(a.folder)
    man = json.loads((folder / 'manifest.json').read_text())
    files = {}  # file -> (cell width, loops); several anims can share a file
    for anim in man['anims'].values():
        files.setdefault(anim['file'], (anim.get('w', man['cell'][0]), anim.get('loop', False)))
    names = [Path(s).name for s in a.sheets] or list(files)
    jobs = []
    for f in names:
        src = folder / f
        if f.endswith('_n.png') or f not in files:
            print('skip (not a manifest sheet):', f)
        elif not a.force and src.with_name(src.stem + '_n.png').exists() and \
                src.with_name(src.stem + '_n.png').stat().st_mtime > src.stat().st_mtime:
            print('skip (up to date):', f)
        else:
            jobs.append(src)
    if not jobs:
        return
    depth, t0, done = Depth(), time.time(), 0
    total = sum(Image.open(s).width // files[s.name][0] for s in jobs)
    for i, src in enumerate(jobs):
        cw, loop = files[src.name]
        k, raw, smooth = bake(depth, src, cw, loop)
        done += k
        print(f'[{i + 1}/{len(jobs)}] {folder.name}/{src.name}: {k} frames, flicker {raw:.1f} -> {smooth:.1f} deg, '
              f'{done}/{total} frames, {time.time() - t0:.0f}s', flush=True)


if __name__ == '__main__':
    os.environ.setdefault('HF_HOME', '/home/danye/refs/depthtest/hf')  # where the model is already downloaded
    sys.exit(main())
