"""One shared palette per character, and steadier frames (Danyal: "limit the AI generated sprites colour palette into 16 colours and realign the pixels to make the sprite animation consistent and smooth").
  uv run --with pillow --with numpy --with scipy python art/tools/sprite_consistency.py FOLDER [ANIM ...] [--out DIR] [--colours 16]
Runs last, after new_sword_sheets.py. The palette is learnt from all the folder's sheets, so a test on a few of them shows what the whole run would do.
Without --out it rewrites the folder's sheets, keeping the first originals in FOLDER/before_consistent/ and always starting from those.
With --out it writes the new sheets, the palette, a report and a before|after GIF per move to DIR and leaves the game alone.
What it does, frame by frame:
 - Every colour becomes the nearest of N (Lab distance, no dither). A stamped head's colours are fixed slots, so faces don't change.
   A colour never crosses the shader's near-black lines (PAL_INK_L, PAL_LINE_L, PAL_SHADE_TOP luma), so outlines and ink stay what they were.
 - A pixel that is the same colour as where it was in the frame before, after the figure's move, keeps the slot it had: no shimmer between two slots.
 - A one-frame jump of the body sideways (or a standing move's feet up and down) is moved back, whole pixels only. Real travel, like a lunge, stays.
 - A lone pixel one shade off its four same-coloured neighbours takes theirs, except on the face and the blade.
Alpha is moved with the frame but never changed: the boss keeps data in it. It can't fix shapes or add frames.
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import steady_sheets as steady
import smaller_head
from new_sword_sheets import is_blade

FIXED = {"art/vulcan_human": list(smaller_head.COLOURS.values())}    # colours that keep their exact value: his stamped head
LUMA = np.array([0.3, 0.59, 0.11])    # core/palette.gdshaderinc PAL_LUMA
BANDS = [0.045, 0.14, 0.18]           # PAL_INK_L, PAL_LINE_L, PAL_SHADE_TOP: a colour stays on its side of each
LOCK = 6.0       # Lab: this close to where it was last frame, it is the same colour
SLACK = 8.0      # Lab: and keeps last frame's slot if that slot is at most this much worse than the nearest
JUMP = 2         # px: a body that jumps this far or less for one frame is put back; further is meant
STANDING = ("idle", "hurt", "drink", "breath", "kneel")    # moves whose feet stay on the ground


def lab(rgb):
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]]) / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def band(rgb):
    return np.digitize((np.asarray(rgb, float) / 255.0) @ LUMA, BANDS)


def load(folder):
    """Each sheet file's frames, by file name without .png, and the move that plays all of it (moves may share a file and start part way in)."""
    m = json.load(open(f"{folder}/manifest.json"))
    src = f"{folder}/before_consistent" if os.path.isdir(f"{folder}/before_consistent") else folder
    sheets, anims = {}, {}
    for a in m["anims"].values():
        key = a["file"][:-4]
        if key in anims and (a.get("start", 0) or a["frames"] <= anims[key]["frames"]):
            continue
        anims[key] = a
    for key, a in anims.items():
        path = f"{src}/{a['file']}"
        if os.path.exists(path):
            sheet = np.array(Image.open(path).convert("RGBA"))
            sheets[key] = steady.frames_of(sheet, sheet.shape[1] // a.get("w", m["cell"][0]))
    return anims, sheets


def make_palette(sheets, n, fixed):
    """k-means in Lab over every opaque pixel, weighted by how often each colour is used; fixed colours never move."""
    px = np.concatenate([f[f[..., 3] > 0][:, :3] for fs in sheets.values() for f in fs])
    cols, count = np.unique(px, axis=0, return_counts=True)
    pts, w = lab(cols), count.astype(float)
    fixed = [tuple(c) for c in fixed][:n]
    centres = [lab(c) for c in fixed]
    rng = np.random.default_rng(0)
    while len(centres) < n:    # k-means++: start the free slots far from the ones already taken
        d = np.min([((pts - c) ** 2).sum(-1) for c in centres], axis=0) * w if centres else w
        centres.append(pts[rng.choice(len(pts), p=d / d.sum())])
    centres = np.array(centres)
    for _ in range(40):
        near = ((pts[:, None] - centres[None]) ** 2).sum(-1).argmin(1)
        for k in range(len(fixed), n):
            if (near == k).any():
                centres[k] = np.average(pts[near == k], axis=0, weights=w[near == k])
    # each free slot becomes the most used real colour it stands for, so it is a colour the art already has
    near = ((pts[:, None] - centres[None]) ** 2).sum(-1).argmin(1)
    out = [np.array(c) for c in fixed]
    for k in range(len(fixed), n):
        mine = np.nonzero(near == k)[0]
        out.append(cols[mine[np.argmax(w[mine])]] if len(mine) else cols[np.argmax(w)])
    return np.array(out, np.uint8)


def nearest(rgb, pal):
    """Distance from each colour to each palette slot; slots across one of the shader's dark lines are ruled out when the colour's own side has any."""
    d = ((lab(rgb)[:, None] - lab(pal)[None]) ** 2).sum(-1)
    other = band(rgb)[:, None] != band(pal)[None]
    has = (~other).any(1)
    d[has[:, None] & other] = np.inf
    return d


def torso_x(f):
    """Middle of the body, without the blade, between a third and three fifths of the way down it."""
    body = (f[..., 3] > 0) & ~is_blade(f)
    ys, xs = np.nonzero(body)
    if not len(ys):
        return None
    top, h = ys.min(), ys.max() - ys.min() + 1
    mid = (ys >= top + h * 0.33) & (ys <= top + h * 0.6)
    return xs[mid].mean() if mid.any() else xs.mean()


def bottom(f):
    ys = np.nonzero((f[..., 3] > 0).any(1))[0]
    return ys.max() if len(ys) else None


def smoothed(vals, loop):
    """Each value's middle with its two neighbours: a one-frame spike goes, a steady travel stays."""
    n = len(vals)
    out = []
    for i, v in enumerate(vals):
        if v is None:
            out.append(None)
            continue
        js = [(i - 1) % n, (i + 1) % n] if loop else [max(i - 1, 0), min(i + 1, n - 1)]
        out.append(np.median([v] + [vals[j] if vals[j] is not None else v for j in js]))
    return out


def realign(key, frames, loop):
    if len(frames) < 3:
        return frames, [(0, 0)] * len(frames)
    xs = [torso_x(f) for f in frames]
    dxs = [0 if x is None else int(round(s - x)) for x, s in zip(xs, smoothed(xs, loop))]
    dys = [0] * len(frames)
    if key.startswith(STANDING):
        bs = [bottom(f) for f in frames]
        ground = int(np.median([b for b in bs if b is not None]))
        dys = [0 if b is None else ground - b for b in bs]
    moves = [(dx if abs(dx) <= JUMP else 0, dy if abs(dy) <= JUMP else 0) for dx, dy in zip(dxs, dys)]
    return [steady.shifted(f, dx, dy) for f, (dx, dy) in zip(frames, moves)], moves


def unspeckle(idx, keep):
    """A lone pixel whose four neighbours share one other slot takes it. Returns the slots and what changed."""
    p = np.pad(idx, 1, constant_values=-1)
    n4 = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
    lone = (idx >= 0) & (n4 >= 0).all(0) & (n4 == n4[0]).all(0) & (n4[0] != idx) & ~keep
    out = idx.copy()
    out[lone] = n4[0][lone]
    return out, lone


def to_palette(frames, pal, keep):
    """Slot per pixel (-1 empty), frame by frame, keeping last frame's slot where the colour hasn't really changed. keep(frame): pixels the stray pass leaves alone."""
    pal_lab = lab(pal)
    out, strays = [], 0
    prev_f = prev_i = None
    for f in frames:
        opaque = f[..., 3] > 0
        cols, inv = np.unique(f[opaque][:, :3], axis=0, return_inverse=True)
        idx = np.full(f.shape[:2], -1)
        idx[opaque] = nearest(cols, pal).argmin(1)[inv.ravel()]
        if prev_f is not None:
            dx, dy = steady.best_shift(prev_f[..., 3] > 0, opaque)
            pf = steady.shifted(prev_f, dx, dy)
            pi = steady.shifted(prev_i + 1, dx, dy) - 1    # shifted fills with 0, which is -1 (empty) here
            fl = lab(f[..., :3])
            same = opaque & (pi >= 0) & (np.linalg.norm(fl - lab(pf[..., :3]), axis=-1) < LOCK)
            safe = np.clip(pi, 0, None)
            mine = np.linalg.norm(fl - pal_lab[safe], axis=-1)
            best = np.linalg.norm(fl - pal_lab[np.clip(idx, 0, None)], axis=-1)
            take = same & (mine <= best + SLACK) & (band(pal[safe]) == band(f[..., :3]))
            idx[take] = pi[take]
        idx, lone = unspeckle(idx, keep(f))
        strays += int(lone.sum())
        out.append(idx)
        prev_f, prev_i = f, idx
    return out, strays


def painted(frames, idx, pal):
    out = []
    for f, i in zip(frames, idx):
        g = np.zeros_like(f)
        g[..., 3] = f[..., 3]
        g[i >= 0, :3] = pal[i[i >= 0]]
        out.append(g)
    return out


def flicker(frames):
    """Share of pixels that change and change back (A, B, A) after following the figure: shimmer, not movement."""
    if len(frames) < 3:
        return 0.0
    bad = tot = 0
    for a, b, c in zip(frames, frames[1:], frames[2:]):
        dx, dy = steady.best_shift(a[..., 3] > 0, b[..., 3] > 0)
        ex, ey = steady.best_shift(b[..., 3] > 0, c[..., 3] > 0)
        a2, c2 = steady.shifted(a, dx, dy), steady.shifted(c, -ex, -ey)
        both = (a2[..., 3] > 0) & (b[..., 3] > 0) & (c2[..., 3] > 0)
        ab = np.abs(a2[..., :3].astype(int) - b[..., :3]).sum(-1) > 24
        ac = np.abs(a2[..., :3].astype(int) - c2[..., :3]).sum(-1) <= 24
        bad += (both & ab & ac).sum()
        tot += both.sum()
    return bad / max(tot, 1)


def gif(path, before, after, anim, scale=3):
    bg = np.array([196, 168, 120, 255], np.uint8)    # the desert floor, so dark edges show
    holds = {int(k): v for k, v in anim.get("holds", {}).items()}
    pics, ms = [], []
    for i, (a, b) in enumerate(zip(before, after)):
        h, w = a.shape[:2]
        canvas = np.tile(bg, (h, w * 2 + 4, 1))
        for x0, f in ((0, a), (w + 4, b)):
            m = f[..., 3] > 0
            canvas[:, x0:x0 + w][m] = f[m]
        canvas[:, w:w + 4] = (60, 50, 70, 255)
        pics.append(Image.fromarray(canvas).resize(((w * 2 + 4) * scale, h * scale), Image.NEAREST).convert("RGB"))
        ms.append(int(1000 * holds.get(i, 1 / anim["fps"])))
    pics[0].save(path, save_all=True, append_images=pics[1:], duration=ms, loop=0)


def main():
    args = sys.argv[1:]
    out_dir, n = None, 16
    if "--out" in args:
        i = args.index("--out"); out_dir = args[i + 1]; del args[i:i + 2]
    if "--colours" in args:
        i = args.index("--colours"); n = int(args[i + 1]); del args[i:i + 2]
    folder, only = args[0].rstrip("/"), args[1:]
    anims, sheets = load(folder)
    fixed = FIXED.get(folder, [])
    pal = make_palette(sheets, n, fixed)
    face = [np.array(c) for c in fixed]

    def keep(f):    # the face and the blade stay as drawn
        k = is_blade(f)
        for c in face:
            k |= (f[..., :3] == c).all(-1)
        return k

    dest = out_dir or folder
    if out_dir is None and not os.path.isdir(f"{folder}/before_consistent"):
        os.makedirs(f"{folder}/before_consistent")
        for a in anims.values():
            if os.path.exists(f"{folder}/{a['file']}"):
                shutil.copy2(f"{folder}/{a['file']}", f"{folder}/before_consistent")
    os.makedirs(dest, exist_ok=True)
    report = {"folder": folder, "colours": n, "palette": pal.tolist(), "fixed": len(fixed), "moves": {}}
    for key, frames in sheets.items():
        if only and key not in only:
            continue
        anim = anims[key]
        moved, shifts = realign(key, frames, anim.get("loop", False))
        idx, strays = to_palette(moved, pal, keep)
        new = painted(moved, idx, pal)
        opaque = np.concatenate([f[..., 3].ravel() > 0 for f in moved])
        err = np.concatenate([np.linalg.norm(lab(a[..., :3]) - lab(b[..., :3]), axis=-1).ravel() for a, b in zip(moved, new)])[opaque]
        report["moves"][key] = {"colours_before": len(np.unique(np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames]), axis=0)),
                                "shifts": shifts, "strays_fixed": strays,
                                "flicker_before": round(float(flicker(frames)), 4), "flicker_after": round(float(flicker(new)), 4),
                                "lab_error_mean": round(float(err.mean()), 2), "lab_error_p99": round(float(np.percentile(err, 99)), 1)}
        Image.fromarray(np.concatenate(new, axis=1)).save(f"{dest}/{anim['file']}")
        if out_dir:
            gif(f"{out_dir}/{key}_before_after.gif", frames, new, anim)
        print(key, report["moves"][key])
    Image.fromarray(pal[None]).resize((n * 8, 8), Image.NEAREST).save(f"{dest}/palette_{n}.png")
    json.dump(report, open(f"{dest}/consistency_report.json", "w"), indent=1)
    assert all(len(np.unique(np.array(Image.open(f"{dest}/{k}.png"))[..., :3].reshape(-1, 3), axis=0)) <= n + 1 for k in report["moves"]), "a sheet has more colours than the palette"


if __name__ == "__main__":
    main()
