# A still sprite -> a 2-frame breathing idle sheet: frame 0 as drawn, frame 1 with everything above the belt 1 px lower
# (one belt row is dropped), so nothing but the breath changes: no flicker, the eyes and details stay exactly as drawn.
# Frames are placed like sprites.py --anchor body (body centre on the cell centre, the lowest pixel on the feet line).
# Usage: uv run --with pillow --with numpy --with scipy python art/tools/breathe.py <sprite.png> --out <sheet.png>
#            --manifest art/<c>/manifest.json --key idle_F [--cut ROW] [--fps 2.5]
import argparse, json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from sprites import body, manifest

p = argparse.ArgumentParser()
p.add_argument('sprite'); p.add_argument('--out', required=True)
p.add_argument('--manifest', required=True); p.add_argument('--key', required=True)
p.add_argument('--cut', type=int, help='the row the shift drops (default: the row most like the one above it, 55-70%% down)')
p.add_argument('--fps', type=float, default=2.5)
A = p.parse_args()
a = np.asarray(Image.open(A.sprite).convert('RGBA')).astype(int)
h = a.shape[0]
c = A.cut or min(range(int(0.55 * h), int(0.7 * h) + 1), key=lambda y: np.abs(a[y] - a[y - 1]).sum())
f1 = a.copy(); f1[1:c + 1] = a[:c]; f1[0] = 0
cw, ch = json.load(open(A.manifest))['cell']
ax = body(Image.fromarray(a.astype(np.uint8)))[0]
bot = np.nonzero(a[..., 3].any(1))[0].max() + 1           # a still sprite's lowest pixel is its feet
x, y = cw // 2 - round(ax), ch - 1 - bot
assert x >= 0 and x + a.shape[1] <= cw and y >= 0, f'{A.sprite} does not fit the cell {cw}x{ch}'
sheet = Image.new('RGBA', (2 * cw, ch), (0, 0, 0, 0))
for i, f in enumerate((a, f1)):
    sheet.alpha_composite(Image.fromarray(f.astype(np.uint8)), (i * cw + x, y))
sheet.save(A.out)
sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.splitext(A.out)[0] + '_x4.png')
manifest(A.manifest, A.key, os.path.basename(A.out), 2, A.fps, True, (cw, ch))
print('cut row', c, 'body x', round(ax), 'sheet', sheet.size)
