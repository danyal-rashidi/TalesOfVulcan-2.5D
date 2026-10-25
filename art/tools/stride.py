# A still stance (or one good frame) -> a run cycle with no flicker. The base frame ("idle", frame "frame", default 0) is
# cut into parts and the body (everything else); each output frame moves every part by its own dx/dy (plus the body's bob
# and sway if "bob": true) and the body by "bob" (px, + = down) and "sway" (px, + = right). Pixels never get repainted, so
# nothing shimmers: the eyes, trim and hair stay the stance's own, and every frame must keep a foot on the feet line.
# Usage: uv run --with pillow --with numpy --with scipy python art/tools/stride.py art/<c>/stride_<key>.json --manifest art/<c>/manifest.json
# Recipe: {"idle": "idle_F.png", "out": "run_F.png", "key": "run_F", "fps": 13, "bob": [1, 2, 0, ...], "sway": [0, 1, ...],
#          "fringe": "#221616", "erase": [<region>, ...], "fill": true,
#          "parts": [{"what": "left leg", "cols": [100, 117], "from": 145, "dy": [0, -3, -7, ...], "under": true}, ...]}
#  A region: "cols": [x0, x1] with "from"/"to" (rows, both in; "to" defaults to the bottom), or "line": [x0, y0, x1, y1]
#    with "width" (a spear shaft), or "any": [<region>, ...] (their union); optional "luma": [lo, hi] keeps only pixels
#    that bright (hair: [90, 255]), "ring": true adds the dark 1 px outline round them, "skip": ["#rrggbb", ...] leaves
#    those colours out (the cape under a spear shaft). "feet" (top level) sets the
#    feet row when the base's own legs are erased.
#  A part without "src" claims its pixels from the base (the first part to claim a pixel keeps it). With "src" (a sheet next
#    to the recipe) and "frames" (one source frame per output frame) its pixels come from that sheet instead, moved by
#    "sx" (per frame, to line the source frames up) and, with "feet": true, dropped until its lowest pixel is on the feet
#    line; "thin": true drops strokes under 3 px wide and specks (a stray spear butt, a dotted outline).
#  Per-frame lists: "dx", "dy", "shear" (px at the region's last row, 0 at its first: hair streaming back); "bob": true adds
#    the body's bob and sway, "lag": n uses the bob and sway of n frames before (the spear bouncing after the body).
#  "under": true draws the part behind the body (legs under the hem), else over it, in the listed order; a list sets it
#    per frame (from behind, a boot kicked back comes in front of the cape).
#  "erase": regions removed from the base first. "fringe": a colour edging the outline (a clean-up left-over): deleted
#    where the pixel inside is already dark, else made the outline colour. "fill": holes a moved part leaves inside the
#    body take the colour of the body pixel next to them.
import argparse, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from sprites import manifest

FOUR = [[0, 1, 0], [1, 1, 1], [0, 1, 0]]
OUTLINE = (1, 4, 6)


def luma(img):
    return img[..., :3].astype(float) @ [0.3, 0.59, 0.11]


def defringe(f, hexc):
    c = tuple(int(hexc[i:i + 2], 16) for i in (1, 3, 5))
    f = f.copy(); on = f[..., 3] > 0; fr = on & (f[..., :3] == c).all(-1)
    edge = fr & ndimage.binary_dilation(~on, FOUR)
    L = luma(f); h, w = on.shape
    for y, x in zip(*np.nonzero(edge)):
        inner = [(y + a, x + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))
                 if 0 <= y + a < h and 0 <= x + b < w and on[y + a, x + b] and not fr[y + a, x + b]]
        if any(L[q] < 60 for q in inner):
            f[y, x] = 0                         # an outline is already there: the fringe sits outside it
        else:
            f[y, x, :3] = OUTLINE              # hair or a lit edge: the fringe becomes its outline
    rest = (f[..., 3] > 0) & (f[..., :3] == c).all(-1)
    f[rest, :3] = (0x14, 0x18, 0x1c)            # inside the figure: a neutral dark
    return f


def region(q, img):
    h, w = img.shape[:2]; yy, xx = np.mgrid[:h, :w]
    if 'any' in q:                              # a union of regions
        return np.logical_or.reduce([region(r, img) for r in q['any']])
    if 'line' in q:
        x0, y0, x1, y1 = q['line']; d = np.array([x1 - x0, y1 - y0], float); n = d / np.hypot(*d)
        t = (xx - x0) * n[0] + (yy - y0) * n[1]
        m = (np.abs((xx - x0) * n[1] - (yy - y0) * n[0]) <= q['width'] / 2) & (t >= 0) & (t <= np.hypot(*d))
    else:
        m = (yy >= q.get('from', 0)) & (yy <= q.get('to', h - 1)) & (xx >= q['cols'][0]) & (xx <= q['cols'][1])
    on = img[..., 3] > 0
    for hexc in q.get('skip', []):              # colours to leave out (the cape behind a spear shaft)
        on = on & ~(img[..., :3] == tuple(int(hexc[i:i + 2], 16) for i in (1, 3, 5))).all(-1)
    if 'luma' in q:
        L = luma(img); keep = m & on & (L >= q['luma'][0]) & (L <= q['luma'][1])
        if q.get('ring'):
            keep |= ndimage.binary_dilation(keep, FOUR) & m & on & (L < 40)
        m = keep
    return m & on


def moved(img, dx, dy):                        # + = right / down; what leaves the cell is dropped
    out = np.zeros_like(img)
    ys, xs = np.nonzero(img[..., 3] > 0); h, w = img.shape[:2]
    keep = (ys + dy >= 0) & (ys + dy < h) & (xs + dx >= 0) & (xs + dx < w)
    out[ys[keep] + dy, xs[keep] + dx] = img[ys[keep], xs[keep]]
    return out


def sheared(img, top, bottom, px):             # each row from top (0) to bottom (px) moves right by its share
    out = np.zeros_like(img)
    for y in range(img.shape[0]):
        s = 0 if y <= top else round(px * min(1.0, (y - top) / max(1, bottom - top)))
        out[y] = np.roll(img[y], s, axis=0)
        if s > 0:
            out[y, :s] = 0
        elif s < 0:
            out[y, s:] = 0
    return out


def thin_out(img):
    m = img[..., 3] > 0
    o = ndimage.binary_dilation(ndimage.binary_opening(m, np.ones((3, 3))), FOUR) & m
    lab, n = ndimage.label(o)
    if n:
        size = ndimage.sum(o, lab, range(1, n + 1))
        o = np.isin(lab, [j + 1 for j in range(n) if size[j] >= 12])
    return np.where(o[..., None], img, 0)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('recipe'); p.add_argument('--manifest', required=True)
    A = p.parse_args()
    R = json.load(open(A.recipe)); d = os.path.dirname(A.recipe)
    cw, ch = json.load(open(A.manifest))['cell']
    sheets = {}

    def cell(name, k):
        if name not in sheets:
            sheets[name] = np.asarray(Image.open(os.path.join(d, name)).convert('RGBA')).copy()
        c = sheets[name][:ch, k * cw:(k + 1) * cw].copy()
        return defringe(c, R['fringe']) if 'fringe' in R else c

    a = cell(R['idle'], R.get('frame', 0))
    for q in R.get('erase', []):
        a[region(q, a)] = 0
    bob = R['bob']; n = len(bob); sway = R.get('sway', [0] * n)
    assert len(sway) == n, 'sway: one value per frame, like bob'
    free = a[..., 3] > 0; parts = []
    for q in R['parts']:
        lists = {k: q.get(k, [0] * n) for k in ('dx', 'dy', 'sx', 'shear')}
        assert all(len(v) == n for v in lists.values()), f"{q['what']}: dx, dy, sx and shear need one value per frame, like bob"
        if 'src' in q:
            assert len(q['frames']) == n, f"{q['what']}: frames needs one source frame per output frame"
            src = [cell(q['src'], k) for k in q['frames']]
            src = [np.where(region(q, s)[..., None], s, 0) for s in src]
            src = [thin_out(s) if q.get('thin') else s for s in src]
        else:
            m = region(q, a) & free; free &= ~m
            src = [np.where(m[..., None], a, 0)] * n
        parts.append((q, src, lists))
    body = np.where(free[..., None], a, 0)
    feet = R.get('feet', int(np.nonzero((a[..., 3] > 0).any(1))[0].max()))
    rows = lambda img: np.nonzero((img[..., 3] > 0).any(1))[0]

    sheet = np.zeros((ch, cw * n, 4), np.uint8)
    for i in range(n):
        layers = []
        for q, src, L in parts:
            img = src[i]
            if L['shear'][i]:
                r = rows(img)
                img = sheared(img, q.get('from', r.min()), q.get('to', r.max()), L['shear'][i])
            img = moved(img, L['sx'][i], 0)
            if q.get('feet'):
                img = moved(img, 0, feet - rows(img).max())
            j = (i - q.get('lag', 0)) % n
            b, s = (bob[j], sway[j]) if q.get('bob') else (0, 0)
            layers.append((q, moved(img, L['dx'][i] + s, L['dy'][i] + b)))
        f = np.zeros_like(a); base = moved(body, sway[i], bob[i])
        under = lambda q: q['under'][i] if isinstance(q.get('under'), list) else q.get('under')
        for l in [l for q, l in layers if under(q)] + [base] + [l for q, l in layers if not under(q)]:
            f[l[..., 3] > 0] = l[l[..., 3] > 0]
        if R.get('fill'):      # a hole a moved part left inside the stance's outline, filled on two sides: the nearest body colour
            shell = moved(a, sway[i], bob[i])[..., 3] > 0
            for _ in range(3):
                on = f[..., 3] > 0
                hole = shell & ~on & (sum(np.roll(on, s, ax) for s in (1, -1) for ax in (0, 1)) >= 2)
                if not hole.any():
                    break
                bon = base[..., 3] > 0
                idx = ndimage.distance_transform_edt(~bon, return_distances=False, return_indices=True)
                f[hole] = base[idx[0][hole], idx[1][hole]]
        assert rows(f).max() == feet, f'frame {i}: no foot on the feet line ({rows(f).max()} != {feet})'
        sheet[:, i * cw:(i + 1) * cw] = f
    pal = os.path.join(d, 'palette.png')
    if os.path.exists(pal):
        ok = {tuple(c) for c in np.asarray(Image.open(pal).convert('RGB')).reshape(-1, 3)}
        assert {tuple(c) for c in sheet[sheet[..., 3] > 0][:, :3]} <= ok, 'a colour that is not in palette.png'
    assert set(np.unique(sheet[..., 3])) <= {0, 255}, 'alpha must be on or off'
    Image.fromarray(sheet).save(os.path.join(d, R['out']))
    manifest(A.manifest, R['key'], R['out'], n, R['fps'], True, (cw, ch))
    print(R['key'], n, 'frames, feet row', feet, 'sheet', (cw * n, ch))


main()
