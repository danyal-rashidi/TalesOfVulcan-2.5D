# A pose_strip.py strip -> a compact guide for Gemini: every cell cropped to the same box (the union of all poses, so
# the hips stay centred and the feet on one line), scaled up with nearest-neighbour, side by side on #FF00FF.
# Several strips (the F, S and B views of one move) -> one row each, all at the same scale (the tallest box sets it),
# so Gemini paints the same-sized man in every view; --aspect 16:9 pads the result onto a magenta canvas of that shape.
# Usage: uv run --with pillow --with numpy python art/tools/guide_pack.py <strip.png>[:cells] [<strip.png>[:cells] ...] <out.png>
#            [--height 480] [--gap 24] [--aspect W:H]       (cells: "0-3" or "0,2,4"; a wide side view as two rows)
import argparse
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('strips', nargs='+'); p.add_argument('out')
p.add_argument('--height', type=int, default=480, help='height of each packed cell in px (the tallest row)')
p.add_argument('--gap', type=int, default=24, help='magenta px between cells')
p.add_argument('--aspect', help='pad onto a magenta canvas of this shape, e.g. 16:9')
p.add_argument('--widen', type=float, default=1.0, help='cells this many times as wide: a broader mannequin (Gemini paints his build)')
A = p.parse_args()
rows = []
for f in A.strips:              # "strip.png:0-3" or "strip.png:0,2,4" packs only those cells (a wide view as two rows)
    head, _, pick = f.rpartition(':')
    f, pick = (head, pick) if head and pick and set(pick) <= set('0123456789,-') else (f, '')
    a = np.asarray(Image.open(f).convert('RGB'))
    H = a.shape[0]
    if pick:
        idx = range(int(pick.split('-')[0]), int(pick.split('-')[1]) + 1) if '-' in pick else [int(v) for v in pick.split(',')]
        a = np.concatenate([a[:, k * H:(k + 1) * H] for k in idx], axis=1)
    n = a.shape[1] // H
    fg = ~((a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200))
    ys, xs = np.nonzero(np.logical_or.reduce([fg[:, k * H:(k + 1) * H] for k in range(n)]))
    m = 6
    y0, y1, x0, x1 = max(0, ys.min() - m), min(H, ys.max() + 1 + m), max(0, xs.min() - m), min(H, xs.max() + 1 + m)
    rows.append((a, H, n, y0, y1, x0, x1))
s = A.height / max(r[4] - r[3] for r in rows)
imgs = []
for a, H, n, y0, y1, x0, x1 in rows:
    w, h = round((x1 - x0) * s * A.widen), round((y1 - y0) * s)
    row = Image.new('RGB', (n * w + (n + 1) * A.gap, h + 2 * A.gap), (255, 0, 255))
    for k in range(n):
        row.paste(Image.fromarray(a[y0:y1, k * H + x0:k * H + x1]).resize((w, h), Image.NEAREST), (A.gap + k * (w + A.gap), A.gap))
    imgs.append(row)
out = Image.new('RGB', (max(i.width for i in imgs), sum(i.height for i in imgs)), (255, 0, 255))
y = 0
for i in imgs:
    out.paste(i, ((out.width - i.width) // 2, y)); y += i.height
if A.aspect:
    aw, ah = (int(v) for v in A.aspect.split(':'))
    W, Hc = max(out.width, -(-out.height * aw // ah)), max(out.height, -(-out.width * ah // aw))
    c = Image.new('RGB', (W, Hc), (255, 0, 255)); c.paste(out, ((W - out.width) // 2, (Hc - out.height) // 2)); out = c
out.save(A.out)
print('rows', len(imgs), 'cells', [r[2] for r in rows], 'scale %.2f' % s, '->', out.size,
      '| in a 1376 px wide picture a cell is %d px tall' % (A.height * 1376 / out.width))
