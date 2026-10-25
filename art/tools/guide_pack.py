# A pose_strip.py strip -> a compact guide for Gemini: every cell cropped to the same box (the union of all poses, so
# the hips stay centred and the feet on one line), scaled up with nearest-neighbour, side by side on #FF00FF.
# Usage: uv run --with pillow --with numpy python art/tools/guide_pack.py <strip.png> <out.png> [--height 480] [--gap 24]
import argparse
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('strip'); p.add_argument('out')
p.add_argument('--height', type=int, default=480, help='height of each packed cell in px')
p.add_argument('--gap', type=int, default=24, help='magenta px between cells')
A = p.parse_args()
a = np.asarray(Image.open(A.strip).convert('RGB'))
H = a.shape[0]; n = a.shape[1] // H
fg = ~((a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200))
cells = [fg[:, k * H:(k + 1) * H] for k in range(n)]
ys, xs = np.nonzero(np.logical_or.reduce(cells))
m = 6
y0, y1, x0, x1 = max(0, ys.min() - m), min(H, ys.max() + 1 + m), max(0, xs.min() - m), min(H, xs.max() + 1 + m)
s = A.height / (y1 - y0)
w, h = round((x1 - x0) * s), A.height
out = Image.new('RGB', (n * w + (n + 1) * A.gap, h + 2 * A.gap), (255, 0, 255))
for k in range(n):
    c = Image.fromarray(a[y0:y1, k * H + x0:k * H + x1]).resize((w, h), Image.NEAREST)
    out.paste(c, (A.gap + k * (w + A.gap), A.gap))
out.save(A.out)
print('cells', n, 'box', (x1 - x0, y1 - y0), '->', out.size)
