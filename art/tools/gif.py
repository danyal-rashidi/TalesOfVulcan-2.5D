# Manifest animations -> one 4x GIF for docs/progress/, timed by fps and holds, on the arena's sand colour, cropped to
# what the frames use. Several keys play one after another (or side by side with --row), each a full loop.
# Usage: uv run --with pillow --with numpy python art/tools/gif.py art/<c>/manifest.json <key> [<key> ...]
#            --out docs/progress/<name>.gif [--scale 4] [--loops 2] [--row]
import argparse, json, os
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('manifest'); p.add_argument('keys', nargs='+'); p.add_argument('--out', required=True)
p.add_argument('--scale', type=int, default=4); p.add_argument('--loops', type=int, default=2)
p.add_argument('--row', action='store_true', help='play the keys side by side instead of one after another')
A = p.parse_args()
m = json.load(open(A.manifest)); cw, ch = m['cell']
SAND = (150, 128, 100, 255)
LOW = max(int(m['anims'][k].get('below', 0)) for k in A.keys)    # rows drawn below the feet line, as the game places them


def frames(key):
    e = m['anims'][key]
    sheet = Image.open(os.path.join(os.path.dirname(A.manifest), e['file'])).convert('RGBA')
    first = e.get('start', 0)
    cells = []
    for i in range(e['frames']):     # a "below": N key sits N px lower, so every key's feet line is on one row
        c = Image.new('RGBA', (cw, ch + LOW))
        c.paste(sheet.crop(((first + i) * cw, 0, (first + i + 1) * cw, ch)), (0, int(e.get('below', 0))))
        cells.append(c)
    ms = [round(1000 / e['fps'] + 1000 * float(e.get('holds', {}).get(str(i), 0))) for i in range(e['frames'])]
    return cells, ms


anims = [frames(k) for k in A.keys]
alpha = np.logical_or.reduce([np.asarray(c)[..., 3] > 0 for cells, _ in anims for c in cells])
ys, xs = np.nonzero(alpha)
box = (max(0, xs.min() - 3), max(0, ys.min() - 3), min(cw, xs.max() + 4), ch + LOW)


def flat(c):
    bg = Image.new('RGBA', c.size, SAND); bg.alpha_composite(c)
    c = bg.crop(box)
    return c.resize((c.width * A.scale, c.height * A.scale), Image.NEAREST).convert('RGB')


out, dur = [], []
if A.row:    # side by side: step all keys on a shared 10 ms clock
    total = max(sum(ms) for _, ms in anims) * A.loops
    t, last = 0, None
    while t < total:
        tiles = []
        for cells, ms in anims:
            u = t % sum(ms); i = 0
            while u >= ms[i]:
                u -= ms[i]; i += 1
            tiles.append(flat(cells[i]))
        img = Image.new('RGB', (sum(x.width for x in tiles), tiles[0].height))
        for k, x in enumerate(tiles):
            img.paste(x, (k * tiles[0].width, 0))
        if last is not None and np.array_equal(np.asarray(img), np.asarray(last)):
            dur[-1] += 10
        else:
            out.append(img); dur.append(10); last = img
        t += 10
else:
    for cells, ms in anims:
        for _ in range(A.loops):
            out += [flat(c) for c in cells]; dur += ms
out[0].save(A.out, save_all=True, append_images=out[1:], duration=dur, loop=0, disposal=1)
print(A.out, len(out), 'frames', out[0].size)
