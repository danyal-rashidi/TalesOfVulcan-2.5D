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
#   --cut X0,Y0,X1,Y1,W: the same line, but its dark pixels are left out of the paste (the idle's spear shaft by the front
#   head's neck): the frame's own pixels stay there.
#   --mane X0,Y0,X1,Y1,K,S,F: one streaming mane for every frame: frame K's own hair in that box (its cell px; pixels at
#   least 95 bright and their dark ring), stretched S times longer back from column X1 (the skull), pasted under the head
#   of every frame, its tips waving F px up and down twice a cycle (the side run: Gemini paints a different, short mane
#   in each frame). --clear X0,Y0,X1,Y1: a source box (moved with the head) where the frame's own bright pixels and
#   outline scraps go too (its own mane, round the pasted one).
#   --chest X0,Y0,X1,Y1,K: frame K's own pixels in that box (its cell px, after its head is pasted) are pasted onto every
#   frame, lined up by the head plus a 2 px search, over that frame's own pixels only: one breastplate, so the armour's
#   trim doesn't shimmer (Gemini repaints it every frame). Keep the box off the swinging arms.
#   --bob-max N: a frame whose head sits more than N px below the median head is lifted to N (its feet leave the floor:
#   the boss's runs and walks; Elvis's front and back runs now use --air and "below" instead).
#   --sink N: a frame whose head sits more than N px above the median head is moved down to N (its feet go under the
#   feet line: build with --floor 158-K and give the key "below": K). Gemini's back walk stands 8 px taller in its passing
#   frames than in its contact frames.
#   --floor ROW: every frame gets its lowest pixel back on that row (the fringe clean-up can take the boot's bottom row
#   away). --thick: the lowest pixel means the lowest row with 3 or more pixels side by side (a boot, not the spear's
#   butt). --air K:N,K:N: then frame K's feet N px above that row (a flight frame; or the front and back runs' passing
#   frames standing on the feet line N rows above a forward foot that reaches toward the camera: give the key "below": N).
#   --pad N: how far round the pasted head the frame's own head pixels are cleared (3). Self-check: headlock.py --selftest
import argparse, math, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stride import defringe

FOUR = [[0, 1, 0], [1, 1, 1], [0, 1, 0]]


def luma(a):
    return a[..., :3].astype(float) @ [0.3, 0.59, 0.11]


def on_line(shape, line):
    x0, y0, x1, y1, w = line; h, W = shape; yy, xx = np.mgrid[:h, :W]
    d = np.array([x1 - x0, y1 - y0], float); n = d / np.hypot(*d)
    return np.abs((xx - x0) * n[1] - (yy - y0) * n[0]) <= w / 2


def bright_ring(s, lo):
    on = s[..., 3] > 0                          # bright pixels and the dark ring round them
    keep = on & (luma(s) >= lo)
    keep |= ndimage.binary_dilation(keep, FOUR) & on & (luma(s) < 60)
    s = s.copy(); s[~keep] = 0
    return s


def stamp_of(src, box, lo=None, mend=None, cut=None):
    x0, y0, x1, y1 = box
    s = np.zeros_like(src); s[y0:y1 + 1, x0:x1 + 1] = src[y0:y1 + 1, x0:x1 + 1]
    if mend:                                    # the spear across the hair -> the strand colour above it
        L = luma(s)
        for y, x in sorted(zip(*np.nonzero(on_line(L.shape, mend) & (s[..., 3] > 0) & (L < 100)))):
            for up in range(1, 8):
                if y - up >= 0 and luma(s[y - up, x][None])[0] >= 100:
                    s[y, x] = s[y - up, x]; break
    if cut:                                     # the spear by the neck -> left out, the frame's own pixels stay
        s[on_line(s.shape[:2], cut) & (s[..., 3] > 0) & (luma(s) < 100)] = 0
    return bright_ring(s, lo) if lo is not None else s


def mane_of(f, box, s):
    x0, y0, x1, y1 = box                        # the hair in the box, stretched s times further back (left) from column x1
    m = np.zeros_like(f); m[y0:y1 + 1, x0:x1 + 1] = f[y0:y1 + 1, x0:x1 + 1]
    m = bright_ring(m, 95); out = np.zeros_like(m)
    for t in range(max(0, int(x1 - (x1 - x0) * s)), x1 + 1):
        out[:, t] = m[:, x1 - int(round((x1 - t) / s))]
    return out


def waved(m, x1, amp):
    cols = np.nonzero((m[..., 3] > 0).any(0))[0]   # each column moved up or down by amp times how far back it is
    if not len(cols) or not amp:
        return m
    out = np.zeros_like(m); tip = max(1, x1 - int(cols.min()))
    for x in cols:
        out[:, x] = shift(m[:, x:x + 1], 0, int(round(amp * max(0, x1 - x) / tip)))[:, 0]
    return out


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


def lock(f, st, dx, dy, front=None, pad=3, clear=None):
    st = shift(st, dx, dy); sm = st[..., 3] > 0; on = f[..., 3] > 0
    zone = ndimage.binary_dilation(sm, np.ones((3, 3)), iterations=pad) & ~sm     # just round the pasted head: trims further off stay
    if front is not None:
        zone[:, :max(0, front + dx)] = False
    if clear:
        x0, y0, x1, y1 = clear; h, w = sm.shape
        zone[max(0, y0 + dy):max(0, min(h, y1 + dy + 1)), max(0, x0 + dx):max(0, min(w, x1 + dx + 1))] = True
        zone &= ~sm
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


def feet_row(f, thick):
    on = f[..., 3] > 0
    if thick:                                   # rows with 3 or more opaque pixels side by side (boots, not the spear butt)
        on = on & ndimage.binary_erosion(on, [[1, 1, 1]], border_value=0)
    rows = np.nonzero(on.any(1))[0]
    return int(rows.max()) if len(rows) else f.shape[0] - 1


def main():
    p = argparse.ArgumentParser()
    p.add_argument('sheet'); p.add_argument('--src', required=True); p.add_argument('--src-frame', type=int, default=0)
    p.add_argument('--box', required=True); p.add_argument('--out', required=True); p.add_argument('--cell', default='240,160')
    p.add_argument('--luma', type=float); p.add_argument('--front', type=int); p.add_argument('--search', type=int, default=16)
    p.add_argument('--fringe'); p.add_argument('--steady', action='store_true'); p.add_argument('--mend'); p.add_argument('--cut')
    p.add_argument('--mane'); p.add_argument('--clear'); p.add_argument('--chest')
    p.add_argument('--pad', type=int, default=3); p.add_argument('--floor', type=int); p.add_argument('--sink', type=int)
    p.add_argument('--thick', action='store_true'); p.add_argument('--air'); p.add_argument('--bob-max', type=int)
    A = p.parse_args()
    ints = lambda s: [int(v) for v in s.split(',')] if s else None
    cw, ch = ints(A.cell); box = ints(A.box)
    src = np.asarray(Image.open(A.src).convert('RGBA'))[:ch, A.src_frame * cw:(A.src_frame + 1) * cw]
    line = lambda s: [float(v) for v in s.split(',')] if s else None
    head = stamp_of(src, box, A.luma, line(A.mend), line(A.cut))
    a = np.asarray(Image.open(A.sheet).convert('RGBA')).copy(); n = a.shape[1] // cw
    fs = [defringe(a[:, k * cw:(k + 1) * cw], A.fringe) if A.fringe else a[:, k * cw:(k + 1) * cw] for k in range(n)]
    offs = [align(f, head, A.search) for f in fs]; stamps = []
    if A.mane:                                  # frame K's mane, moved into the source's place (the head's offsets)
        mx0, my0, mx1, my1, mk, ms, mf = line(A.mane); mk = int(mk)
        mane = shift(mane_of(fs[mk], [int(mx0), int(my0), int(mx1), int(my1)], ms), -offs[mk][0], -offs[mk][1])
        mx1 -= offs[mk][0]
    for k, f in enumerate(fs):
        st = head
        if A.mane:
            st = waved(mane, int(mx1), mf * math.sin(4 * math.pi * k / n)).copy(); st[head[..., 3] > 0] = head[head[..., 3] > 0]
        dx, dy = offs[k]; stamps.append(shift(st, dx, dy))
        a[:, k * cw:(k + 1) * cw] = lock(f, st, dx, dy, A.front, A.pad, ints(A.clear))
    if A.chest:                                 # one breastplate: frame K's, lined up on each frame by the head (+-2 px)
        x0, y0, x1, y1, K = ints(A.chest)
        cs = np.zeros((ch, cw, 4), np.uint8); cs[y0:y1 + 1, x0:x1 + 1] = a[y0:y1 + 1, K * cw + x0:K * cw + x1 + 1]
        cs[stamps[K][..., 3] > 0] = 0
        for k in range(n):
            f = a[:, k * cw:(k + 1) * cw]; gx, gy = offs[k][0] - offs[K][0], offs[k][1] - offs[K][1]
            ex, ey = align(f, shift(cs, gx, gy), 2); c = shift(cs, gx + ex, gy + ey)
            put = (c[..., 3] > 0) & (f[..., 3] > 0) & (stamps[k][..., 3] == 0)
            f[put] = c[put]
            print('frame', k, 'chest from frame', K, 'at', (gx + ex, gy + ey), put.sum(), 'px')
    drop = [0] * n                              # each frame's vertical move, to report where its head ends up
    if A.floor is not None:
        air = {int(k): int(v) for k, v in (kv.split(':') for kv in A.air.split(','))} if A.air else {}
        for k in range(n):
            f = a[:, k * cw:(k + 1) * cw]; d = A.floor - air.get(k, 0) - feet_row(f, A.thick)
            if feet_row(f, False) + d > ch - 1:
                print('frame', k, 'WARNING:', feet_row(f, False) + d - ch + 1, 'rows pushed out of the cell')
            a[:, k * cw:(k + 1) * cw] = shift(f, 0, d); drop[k] += d
    if A.bob_max is not None:                   # a squat lifted off the floor: the head bobs at most N px under the median
        mid = int(round(float(np.median([o[1] for o in offs]))))
        for k, (_, dy) in enumerate(offs):
            if dy > mid + A.bob_max:
                a[:, k * cw:(k + 1) * cw] = shift(a[:, k * cw:(k + 1) * cw], 0, mid + A.bob_max - dy); drop[k] += mid + A.bob_max - dy
                print('frame', k, 'lifted', dy - mid - A.bob_max, 'px')
    if A.sink is not None:                      # a frame drawn too tall: its head at most N px above the median, its feet below the line
        mid = int(round(float(np.median([o[1] for o in offs]))))
        for k, (_, dy) in enumerate(offs):
            if dy < mid - A.sink:
                a[:, k * cw:(k + 1) * cw] = shift(a[:, k * cw:(k + 1) * cw], 0, mid - A.sink - dy); drop[k] += mid - A.sink - dy
                print('frame', k, 'sunk', mid - A.sink - dy, 'px')
    if A.steady:                                # one head column: each frame moved sideways by its head's offset
        mid = int(round(float(np.median([o[0] for o in offs]))))
        for k, (dx, _) in enumerate(offs):
            f = a[:, k * cw:(k + 1) * cw]
            a[:, k * cw:(k + 1) * cw] = shift(f, mid - dx, 0)
    Image.fromarray(a).save(A.out)
    print('head offsets (dx, dy) per frame:', offs)
    print('head top row per frame:', [box[1] + offs[k][1] + drop[k] for k in range(n)],
          'feet row per frame:', [feet_row(a[:, k * cw:(k + 1) * cw], A.thick) for k in range(n)])


def selftest():
    src = np.zeros((40, 40, 4), np.uint8); src[5:15, 10:20] = (220, 230, 240, 255); src[4, 10:20] = (5, 5, 5, 255)
    f = np.zeros_like(src); f[8:18, 13:23] = (200, 210, 220, 255); f[18:35, 10:26] = (40, 40, 50, 255)
    st = stamp_of(src, [10, 4, 19, 14])
    dx, dy = align(f, st, 6); assert (dx, dy) == (3, 3), (dx, dy)
    out = lock(f, st, dx, dy)
    assert (out[8:18, 13:23, :3] == (220, 230, 240)).all() and (out[18:35, 10:26, :3] == (40, 40, 50)).all()
    sp = src.copy(); sp[6:14, 12] = (10, 10, 10, 255)            # a dark shaft across the head is cut out of the paste
    assert (stamp_of(sp, [10, 4, 19, 14], cut=[12, 6, 12, 13, 1])[6:14, 12, 3] == 0).all()
    hr = np.zeros_like(src); hr[10, 10:20] = (230, 230, 230, 255)  # a 10 px lock behind the skull at column 19 -> 20 px
    m = mane_of(hr, [10, 8, 19, 12], 2.0); assert m[10, 1:20, 3].all() and not m[10, 0, 3]
    w = waved(m, 19, 2); assert w[12, 1, 3] and w[10, 19, 3]       # its tip waves 2 px, the root stays
    bt = np.zeros_like(src); bt[30, 5:9] = 255; bt[33, 20] = 255   # a boot on row 30 and a 1 px spear butt below it
    assert feet_row(bt, True) == 30 and feet_row(bt, False) == 33
    print('selftest ok')


if __name__ == '__main__':
    selftest() if '--selftest' in sys.argv else main()
