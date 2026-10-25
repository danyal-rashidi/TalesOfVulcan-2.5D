# A pose guide with the character's own master standing in front of it, at the guide's scale: Gemini then paints every
# pose at the master's size (Gemini draws a kneel as tall as a stand unless it sees the two side by side), and
# sprites.py --scale-frame 0 --height <master height> --pick 1,2,.. sets the sheet's scale from the standing figure.
# Usage: uv run --with pillow --with numpy --with scipy python art/tools/guide_with_ref.py <master.png> <strip.png>
#            <out.png> --scale S --master-scale M [--gap 24] [--aspect 4:1]
#   --scale: the strip's pixels -> guide pixels; --master-scale: the master's pixels -> guide pixels (both whole numbers;
#   pick M so the master's head is about as wide as the mannequin's head).
import argparse
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('master'); p.add_argument('strip'); p.add_argument('out')
p.add_argument('--scale', type=int, required=True); p.add_argument('--master-scale', type=int, required=True)
p.add_argument('--gap', type=int, default=24); p.add_argument('--aspect', default='4:1')
A = p.parse_args()
MAG = (255, 0, 255)

def crop_fg(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    fg = ~((b > 110) & (r > 110) & (g < 0.62 * np.minimum(r, b)))
    ys, xs = np.nonzero(fg)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

m = Image.open(A.master).convert('RGBA')
mb = Image.new('RGBA', m.size, MAG + (255,)); mb.alpha_composite(m)
m = crop_fg(np.asarray(mb.convert('RGB')))
s = np.asarray(Image.open(A.strip).convert('RGB'))
H = s.shape[0]
cells = [crop_fg(s[:, k * H:(k + 1) * H]) for k in range(s.shape[1] // H)]
big = lambda a, k: np.asarray(Image.fromarray(a).resize((a.shape[1] * k, a.shape[0] * k), Image.NEAREST))
figs = [big(m, A.master_scale)] + [big(c, A.scale) for c in cells]
w = sum(f.shape[1] for f in figs) + A.gap * (len(figs) + 1)
h = max(f.shape[0] for f in figs) + 2 * A.gap
aw, ah = map(int, A.aspect.split(':'))
W, Hh = max(w, round(h * aw / ah)), max(h, round(w * ah / aw))
out = np.zeros((Hh, W, 3), np.uint8); out[:] = MAG
x = (W - w) // 2 + A.gap
floor = (Hh + h) // 2 - A.gap          # every figure's lowest pixel on one line
for f in figs:
    out[floor - f.shape[0]:floor, x:x + f.shape[1]] = f
    x += f.shape[1] + A.gap
Image.fromarray(out).save(A.out)
print('figures', len(figs), 'master', figs[0].shape[:2], 'poses', [f.shape[:2] for f in figs[1:]], '->', (W, Hh))
