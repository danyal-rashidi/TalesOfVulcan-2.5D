# One head for every frame: the idle's head (and hair) pasted onto each frame of a Gemini sheet, lined up where that
# frame's own head is, so the face, the eyes and the hair never get repainted from frame to frame (Gemini repaints every
# frame; only the limbs, the weapon and the cape should move). The frame's own head pixels round the pasted one go:
# bright ones (hair, skin) and small dark scraps (its outline) inside the zone are deleted at the silhouette's edge and
# filled from the body next to them inside it. What lies outside the zone (the side run's hair streaming back) is kept.
# Usage: uv run --with pillow --with numpy --with scipy python art/tools/headlock.py <sheet> --src art/elvis/idle_S.png
#            --box X0,Y0,X1,Y1 --out <sheet> [--src-frame 0] [--cell 240,160] [--luma 100] [--front X] [--search 16]
#   --box: the head in the source frame (cell px, both ends in). --luma L: only source pixels at least that bright, plus
#   their dark 1 px outline (hair down a back, without the armour round it). --front X: the zone only reaches back to
#   source column X (side view: the hair behind the skull is the frame's own). --fringe "#221616": first remove that
#   clean-up ring round the outlines (stride.py's defringe). --steady: shift each frame sideways so the head keeps one
#   column (the body comes with it; the bob stays). --mend X0,Y0,X1,Y1,W: a spear crossing the source's hair along that
#   line (W px wide): its dark pixels there take the hair colour above them first (the run carries the spear upright).
#   --bob-max N: a frame whose head sits more than N px below the median head is lifted to N (its feet leave the floor:
#   Gemini draws a run's passing pose as a deep squat, 12 px at 80, which reads as a hop down, not a stride).
#   --sink N: a frame whose head sits more than N px above the median head is moved down to N (its feet go under the
#   feet line: build with --floor 158-K and give the key "below": K). Gemini's back walk stands 8 px taller in its passing
#   frames than in its contact frames.
#   --floor ROW: every frame not lifted gets its lowest pixel back on that row (the fringe clean-up can take the boot's
#   bottom row away).
#   --pad N: how far round the pasted head the frame's own head pixels are cleared (3). Self-check: headlock.py --selftest
import argparse, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stride import defringe

FOUR = [[0, 1, 0], [1, 1, 1], [0, 1, 0]]


def luma(a):
    return a[..., :3].astype(float) @ [0.3, 0.59, 0.11]


def stamp_of(src, box, lo=None, mend=None):
    x0, y0, x1, y1 = box
    s = np.zeros_like(src); s[y0:y1 + 1, x0:x1 + 1] = src[y0:y1 + 1, x0:x1 + 1]
    if mend:                                    # the spear across the hair -> the strand colour above it
        mx0, my0, mx1, my1, mw = mend; L = luma(s); h, w = L.shape; yy, xx = np.mgrid[:h, :w]
        d = np.array([mx1 - mx0, my1 - my0], float); n = d / np.hypot(*d)
        line = np.abs((xx - mx0) * n[1] - (yy - my0) * n[0]) <= mw / 2
        for y, x in sorted(zip(*np.nonzero(line & (s[..., 3] > 0) & (L < 100)))):
            for up in range(1, 8):
                if y - up >= 0 and luma(s[y - up, x][None])[0] >= 100:
                    s[y, x] = s[y - up, x]; break
    on = s[..., 3] > 0
    if lo is not None:                          # bright pixels and the dark ring round them
        keep = on & (luma(s) >= lo)
        keep |= ndimage.binary_dilation(keep, FOUR) & on & (luma(s) < 60)
        s[~keep] = 0
    return s


def shift(a, dx, dy):
    out = np.zeros_like(a); h, w = a.shape[:2]
    ys, xs = slice(max(0, dy), min(h, h + dy)), slice(max(0, dx), min(w, w + dx))
    yd, xd = slice(max(0, -dy), min(h, h - dy)), slice(max(0, -dx), min(w, w - dx))
    out[ys, xs] = a[yd, xd]
    return out


def align(f, st, search):
    m = st[..., 3] > 0; ys, xs = np.nonzero(m); Ls = luma(st)[m]; w = np.where(Ls > 100, 2.0, 1.0)
    Lf = luma(f); on = f[..., 3] > 0; h, W = on.shape; best = None
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            y, x = ys + dy, xs + dx
            ok = (y >= 0) & (y < h) & (x >= 0) & (x < W)
            yc, xc = np.clip(y, 0, h - 1), np.clip(x, 0, W - 1)
            d = np.where(ok & on[yc, xc], np.abs(Lf[yc, xc] - Ls), 120.0)
            c = float((d * w).sum())
            if best is None or c < best[0]:
                best = (c, dx, dy)
    return best[1], best[2]


def lock(f, st, dx, dy, front=None, pad=3):
    st = shift(st, dx, dy); sm = st[..., 3] > 0; on = f[..., 3] > 0
    zone = ndimage.binary_dilation(sm, np.ones((3, 3)), iterations=pad) & ~sm     # just round the pasted head: trims further off stay
    if front is not None:
        zone[:, :max(0, front + dx)] = False
    gone = zone & on & (luma(f) >= 95)          # its own hair and skin
    dark = zone & on & ~gone
    lab, n = ndimage.label(dark, FOUR)
    if n:
        size = ndimage.sum(dark, lab, range(1, n + 1))
        gone |= np.isin(lab, 1 + np.nonzero(size < 20)[0])     # scraps of its own outline (a fist or the spear is bigger)
    out = f.copy()
    edge = gone & ndimage.binary_dilation(~on, FOUR)
    out[edge] = 0
    hole = gone & ~edge
    keep = (out[..., 3] > 0) & ~hole
    if hole.any() and keep.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~keep, return_indices=True)
        out[hole] = out[iy[hole], ix[hole]]     # inside the body: the colour next to it
    out[sm] = st[sm]
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('sheet'); p.add_argument('--src', required=True); p.add_argument('--src-frame', type=int, default=0)
    p.add_argument('--box', required=True); p.add_argument('--out', required=True); p.add_argument('--cell', default='240,160')
    p.add_argument('--luma', type=float); p.add_argument('--front', type=int); p.add_argument('--search', type=int, default=16)
    p.add_argument('--fringe'); p.add_argument('--steady', action='store_true'); p.add_argument('--mend')
    p.add_argument('--pad', type=int, default=3); p.add_argument('--bob-max', type=int)
    p.add_argument('--floor', type=int); p.add_argument('--sink', type=int)
    A = p.parse_args()
    cw, ch = (int(v) for v in A.cell.split(',')); box = [int(v) for v in A.box.split(',')]
    src = np.asarray(Image.open(A.src).convert('RGBA'))[:ch, A.src_frame * cw:(A.src_frame + 1) * cw]
    st = stamp_of(src, box, A.luma, [float(v) for v in A.mend.split(',')] if A.mend else None)
    a = np.asarray(Image.open(A.sheet).convert('RGBA')).copy(); n = a.shape[1] // cw; offs = []
    for k in range(n):
        f = a[:, k * cw:(k + 1) * cw]
        if A.fringe:
            f = defringe(f, A.fringe)
        dx, dy = align(f, st, A.search); offs.append((dx, dy))
        a[:, k * cw:(k + 1) * cw] = lock(f, st, dx, dy, A.front, A.pad)
    if A.floor is not None:
        for k in range(n):
            f = a[:, k * cw:(k + 1) * cw]; low = int(np.nonzero((f[..., 3] > 0).any(1))[0].max())
            a[:, k * cw:(k + 1) * cw] = shift(f, 0, A.floor - low)
    if A.bob_max is not None:                   # a squat lifted off the floor: the head bobs at most N px under the median
        mid = int(round(float(np.median([o[1] for o in offs]))))
        for k, (_, dy) in enumerate(offs):
            if dy > mid + A.bob_max:
                a[:, k * cw:(k + 1) * cw] = shift(a[:, k * cw:(k + 1) * cw], 0, mid + A.bob_max - dy)
                print('frame', k, 'lifted', dy - mid - A.bob_max, 'px')
    if A.sink is not None:                      # a frame drawn too tall: its head at most N px above the median, its feet below the line
        mid = int(round(float(np.median([o[1] for o in offs]))))
        for k, (_, dy) in enumerate(offs):
            if dy < mid - A.sink:
                a[:, k * cw:(k + 1) * cw] = shift(a[:, k * cw:(k + 1) * cw], 0, mid - A.sink - dy)
                print('frame', k, 'sunk', mid - A.sink - dy, 'px')
    if A.steady:                                # one head column: each frame moved sideways by its head's offset
        mid = int(round(float(np.median([o[0] for o in offs]))))
        for k, (dx, _) in enumerate(offs):
            f = a[:, k * cw:(k + 1) * cw]
            a[:, k * cw:(k + 1) * cw] = shift(f, mid - dx, 0)
    Image.fromarray(a).save(A.out)
    print('head offsets (dx, dy) per frame:', offs)


def selftest():
    src = np.zeros((40, 40, 4), np.uint8); src[5:15, 10:20] = (220, 230, 240, 255); src[4, 10:20] = (5, 5, 5, 255)
    f = np.zeros_like(src); f[8:18, 13:23] = (200, 210, 220, 255); f[18:35, 10:26] = (40, 40, 50, 255)
    st = stamp_of(src, [10, 4, 19, 14])
    dx, dy = align(f, st, 6); assert (dx, dy) == (3, 3), (dx, dy)
    out = lock(f, st, dx, dy)
    assert (out[8:18, 13:23, :3] == (220, 230, 240)).all() and (out[18:35, 10:26, :3] == (40, 40, 50)).all()
    print('selftest ok')


if __name__ == '__main__':
    selftest() if '--selftest' in sys.argv else main()
