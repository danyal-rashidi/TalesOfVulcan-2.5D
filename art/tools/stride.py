# A still stance -> a run cycle with no flicker. Frame 0 of an idle sheet is cut into parts (the pixels from row
# "from" down, in columns "cols"; the first part to claim a pixel keeps it) and the body (everything else). Each frame
# moves every part by its own dx/dy (plus the bob if "bob": true) and the body by the bob (px, + = down); "under"
# parts (the legs) are drawn behind the body. The eyes, trim and hair stay the stance's own pixels, and every frame
# must keep a foot on the stance's feet line.
# Usage: uv run --with pillow --with numpy python art/tools/stride.py art/<c>/stride_<key>.json --manifest art/<c>/manifest.json
# Recipe: {"idle": "idle_F.png", "out": "run_F.png", "key": "run_F", "fps": 10, "bob": [1, 2, 0, ...],
#          "parts": [{"what": "left leg", "cols": [100, 117], "from": 145, "dy": [0, 0, 0, -3, -7, -4], "under": true}, ...]}
import argparse, json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from sprites import manifest

p = argparse.ArgumentParser()
p.add_argument('recipe'); p.add_argument('--manifest', required=True)
A = p.parse_args()
R = json.load(open(A.recipe)); d = os.path.dirname(A.recipe)
cw, ch = json.load(open(A.manifest))['cell']
a = np.asarray(Image.open(os.path.join(d, R['idle'])).convert('RGBA'))[:ch, :cw].copy()
on = a[..., 3] > 0
bob = R['bob']; n = len(bob)
free = on.copy(); parts = []
for q in R['parts']:
    m = np.zeros(on.shape, bool); m[q['from']:, q['cols'][0]:q['cols'][1] + 1] = True
    m &= free; free &= ~m
    dx, dy = q.get('dx', [0] * n), q.get('dy', [0] * n)
    assert len(dx) == n and len(dy) == n, f"{q['what']}: dx and dy need one value per frame, like bob"
    parts.append((np.where(m[..., None], a, 0), q, dx, dy))
body = np.where(free[..., None], a, 0)
feet = np.nonzero(on.any(1))[0].max()


def moved(img, dx, dy):                                   # + = right / down; what leaves the cell is dropped
    out = np.zeros_like(img)
    ys, xs = np.nonzero(img[..., 3] > 0)
    keep = (ys + dy >= 0) & (ys + dy < ch) & (xs + dx >= 0) & (xs + dx < cw)
    out[ys[keep] + dy, xs[keep] + dx] = img[ys[keep], xs[keep]]
    return out


sheet = np.zeros((ch, cw * n, 4), np.uint8)
for i in range(n):
    f = np.zeros_like(a)
    layers = [moved(img, dx[i], dy[i] + (bob[i] if q.get('bob') else 0)) for img, q, dx, dy in parts]
    under = [l for l, (_, q, _, _) in zip(layers, parts) if q.get('under')]
    over = [l for l, (_, q, _, _) in zip(layers, parts) if not q.get('under')]
    for l in under + [moved(body, 0, bob[i])] + over:
        f[l[..., 3] > 0] = l[l[..., 3] > 0]
    assert np.nonzero((f[..., 3] > 0).any(1))[0].max() == feet, f'frame {i}: no foot on the feet line'
    sheet[:, i * cw:(i + 1) * cw] = f
cols = lambda x: {tuple(c) for c in x[x[..., 3] > 0][:, :3]}
assert cols(sheet) <= cols(a), 'a colour that is not in the stance'
Image.fromarray(sheet).save(os.path.join(d, R['out']))
manifest(A.manifest, R['key'], R['out'], n, R['fps'], True, (cw, ch))
print(R['key'], n, 'frames, feet row', feet, 'sheet', (cw * n, ch))
