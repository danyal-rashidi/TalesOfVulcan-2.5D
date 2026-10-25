# Front and back runs from Gemini: it tends to lift the same leg in every front frame. Each output frame takes the body
# above cell row R from one frame and the legs (rows R and below, within W px of the body's centre column) from another,
# mirrored if asked, so the legs alternate while the head, armour and weapon stay as Gemini drew them. Frames sit on the
# feet line already (sprites.py --anchor body), so the legs keep their own feet.
# Usage: uv run --with pillow --with numpy python art/tools/legswap.py <sheet.png> --cell W H --row R --half W2
#            --frames 9,0,3,4:1m,8:9m,6 --out <sheet.png>
#   each item: "a" = frame a as it is; "a:b" = a's body with b's legs; "a:bm" = with b's legs mirrored about b's centre.
#   The body's centre is the middle of its shoulders (rows 20-50 below its top). Self-check: legswap.py --selftest
import argparse, sys
import numpy as np
from PIL import Image


def centre(c):
    ys, xs = np.nonzero(c[..., 3] > 0)
    band = (ys > ys.min() + 20) & (ys < ys.min() + 50)
    return int(round(xs[band].mean()))


def swap(cells, item, row, half):
    a, _, leg = item.partition(':')
    out = cells[int(a)].copy()
    if not leg:
        return out
    mirror = leg.endswith('m')
    src = cells[int(leg.rstrip('m'))]
    ca, cb = centre(out), centre(src)
    out[row:, ca - half:ca + half + 1] = 0
    for d in range(-half, half + 1):
        out[row:, ca + d] = src[row:, cb - d if mirror else cb + d]
    return out


def selftest():
    c = np.zeros((2, 60, 40, 4), np.uint8)
    c[:, 0:40, 10:30] = (90, 60, 40, 255)                  # two bodies, centre column 19.5
    c[0, 40:60, 12:18] = (200, 0, 0, 255)                   # frame 0: the left leg down, the right leg lifted
    c[0, 40:50, 22:28] = (0, 0, 200, 255)
    c[1, 40:60, 12:28] = (0, 200, 0, 255)                   # frame 1: both legs down, another colour
    out = swap(list(c), '1:0m', 40, 9)
    assert tuple(out[55, 24]) == (200, 0, 0, 255) and out[55, 14, 3] == 0, 'the long leg mirrored to the right'
    assert tuple(out[45, 14]) == (0, 0, 200, 255), 'the lifted leg mirrored to the left'
    assert tuple(out[20, 20]) == (90, 60, 40, 255), "frame 1's body kept"
    assert np.array_equal(swap(list(c), '0', 40, 9), c[0]), 'a plain item is the frame itself'
    print('selftest ok')


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        selftest(); sys.exit()
    p = argparse.ArgumentParser()
    p.add_argument('sheet'); p.add_argument('--cell', type=int, nargs=2, required=True)
    p.add_argument('--row', type=int, required=True); p.add_argument('--half', type=int, default=16)
    p.add_argument('--frames', required=True); p.add_argument('--out', required=True)
    A = p.parse_args()
    a = np.asarray(Image.open(A.sheet).convert('RGBA'))
    cw, ch = A.cell
    cells = [a[:, k * cw:(k + 1) * cw] for k in range(a.shape[1] // cw)]
    outs = [swap(cells, it, A.row, A.half) for it in A.frames.split(',')]
    Image.fromarray(np.concatenate(outs, 1)).save(A.out)
    print('frames', len(outs), 'sheet', len(outs) * cw, 'x', ch)
