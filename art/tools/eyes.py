# Gemini's eyes shrink to a smudge at 80 px. This finds the head in each front-facing frame of a sheet by matching the
# master's head, and writes a sprites.py --touchup list that paints the master's own eye touch-ups there (the pupil,
# the catch-light, the lid and cheek lines), so the eyes are the same in every frame. Rebuild the sheet with it.
# Usage: uv run --with pillow --with numpy python art/tools/eyes.py <sheet.png> --cell W H --master art/elvis/master.png
#            --master-touchup art/elvis/touchup.json --head X0 Y0 X1 Y1 --frames 0,1,2 --out <touchup.json>
#   --head: the master's head box (x0 y0 x1 y1, end excluded); the eye pixels must lie inside it.
# Side views (a profile facing right) have no master to match: --side finds the eye as the darkest face pixel 8-15 rows
# below the top of the hair and 1-8 px behind the face's front edge, and draws a dark pupil there with an ice-blue
# catch-light in front of it:  eyes.py <sheet> --cell W H --side --frames 0,1 --out <touchup.json>
import argparse, json, sys
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('sheet'); p.add_argument('--cell', nargs=2, type=int, required=True)
p.add_argument('--master'); p.add_argument('--master-touchup')
p.add_argument('--head', nargs=4, type=int); p.add_argument('--frames', required=True)
p.add_argument('--side', action='store_true', help='profile facing right: find the eye in the face itself')
p.add_argument('--out', required=True)
A = p.parse_args()
cw, ch = A.cell
if A.side:
    sheet = np.asarray(Image.open(A.sheet).convert('RGBA')).astype(int)
    out = []
    for f in (int(v) for v in A.frames.split(',')):
        c = sheet[:, f * cw:(f + 1) * cw]
        solid = c[..., 3] > 0
        light = solid & (c[..., :3].mean(-1) > 150)
        top = np.nonzero(light.any(1))[0].min()
        rows = range(top + 8, top + 16)
        front = max(np.nonzero(light[y])[0].max() for y in rows if light[y].any())
        cand = [(c[y, x, :3].mean(), x, y) for y in rows for x in range(front - 8, front)
                if solid[y, x] and solid[y, x + 1] and solid[y, x - 1]]
        _, x, y = min(cand)
        out += [[f, x, y, '#12142b'], [f, x + 1, y, '#9fe3ff']]
        print('frame', f, 'eye at', x, y, 'face front', front)
    json.dump(out, open(A.out, 'w'))
    sys.exit()
x0, y0, x1, y1 = A.head
head = np.asarray(Image.open(A.master).convert('RGBA')).astype(float)[y0:y1, x0:x1]
hm = head[..., 3] > 0
eyes = [(x - x0, y - y0, c) for _, x, y, c in json.load(open(A.master_touchup))]
assert all(hm[y, x] for x, y, _ in eyes), 'an eye pixel lies outside the head box'
sheet = np.asarray(Image.open(A.sheet).convert('RGBA')).astype(float)
hh, hw = hm.shape
out = []
for f in (int(v) for v in A.frames.split(',')):
    cell = sheet[:, f * cw:(f + 1) * cw]
    best = None
    for oy in range(0, ch - hh):
        for ox in range(0, cw - hw):
            win = cell[oy:oy + hh, ox:ox + hw]
            if not win[..., 3][hm].any():
                continue
            d = ((win[..., :3] - head[..., :3]) ** 2).sum(-1)
            cost = np.where(win[..., 3] > 0, d, 3 * 255 ** 2)[hm].mean()    # a head pixel over empty space costs most
            if best is None or cost < best[0]:
                best = (cost, ox, oy)
    _, ox, oy = best
    out += [[f, ox + x, oy + y, c] for x, y, c in eyes]
    print('frame', f, 'head at', ox, oy, 'cost', round(best[0]))
json.dump(out, open(A.out, 'w'))
