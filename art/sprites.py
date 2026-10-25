# Gemini frames on magenta -> real-size pixel sprites with one shared palette, feet aligned, one sheet (one row).
# Usage:
#   uv run --with pillow --with numpy --with scipy python art/sprites.py <strip> --cols C --rows R --height 80 \
#       [--palette P] --out <png> [--manifest M --key K --fps F --loop|--no-loop] [--touchup J] [--quant median|octree]
#   --palette P: lock every colour to P's colours; if P doesn't exist yet, this run's 32 colours are written to it.
#   --manifest: adds or replaces anim K in M (cell size is shared: an existing manifest's cell is kept; holds are kept).
#   --height: the tallest figure in the strip, every frame at the same scale (raise it when a spear tip sticks up).
#   --quant octree: keeps small saturated spots (a gold buckle, eye whites) that median cut (default; best for lava and
#       steel trim) merges into their surroundings. Use the same setting for every sheet of a character.
#   --anchor body: for animations. --height is then the tallest BODY (the spear left out; Elvis's is 80), and each frame
#       is placed by its body (shoulders-to-hips centre on the cell centre, feet on the bottom line), not by its box.
#   --anchor strip: as body, but each frame keeps the height it stands at in the strip (a run's bob as drawn), the
#       lowest feet of the strip on the bottom line. For strips painted over a pose guide, whose ground is one line.
#   --anchor head [--bob 0,1,-1,..]: as body, but the top of the head is on one line plus a designed bob (px, + = lower),
#       the lowest pixel of the strip on the bottom line: for a run whose frames Gemini drew crouched by different amounts.
#   --pick 0,2,3: only those strip frames, in that order (drop a bad frame).
#   --split shapes: a row's --cols biggest shapes are its frames, smaller bits join the nearest (for frames whose spear
#       blade reaches over the next frame, which a column cut would slice off). Default: cut at the emptiest columns.
#   --touchup J: hand pixel edits (eyes) applied after the clean-up, [[frame, x, y, "#rrggbb"], ...]; colours count toward 32.
#   Writes <out> and <out>_x4.png (4x nearest preview). Self-check: sprites.py --selftest
import argparse, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage


def magenta(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b > 110) & (r > 110) & (g < 0.62 * np.minimum(r, b))      # magenta and its fringe


def shapes(a, fg, cols):
    # The `cols` biggest shapes of a row are the figures, left to right; every other shape bigger than a speck (a spear
    # blade that crosses over the next figure's cape, a hair tip) joins the figure nearest it across.
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    boxes = ndimage.find_objects(lab)
    order = np.argsort(-sizes)
    figs = sorted(order[:cols], key=lambda i: boxes[i][1].start)
    assert len(figs) == cols and sizes[figs].min() > 0.2 * sizes.max(), 'fewer separate figures than --cols'
    keep = {i: lab == i + 1 for i in figs}
    for i in order[cols:]:
        if sizes[i] < 0.003 * sizes.max():
            continue
        c = (boxes[i][1].start + boxes[i][1].stop) / 2
        gap = lambda f: max(boxes[f][1].start - c, c - boxes[f][1].stop, 0) + 1e-3 * abs(c - (boxes[f][1].start + boxes[f][1].stop) / 2)
        keep[min(figs, key=gap)] |= lab == i + 1
    for i in figs:
        ys, xs = np.nonzero(keep[i])
        sl = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
        im = Image.fromarray(np.dstack([a[sl], keep[i][sl] * 255]).astype(np.uint8))
        im.info['top'] = ys.min()
        yield im


def figures(path, cols, rows, split='columns'):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    bg = magenta(a)
    H, W = bg.shape
    for j in range(rows):
        y0, y1 = j * H // rows, (j + 1) * H // rows
        if split == 'shapes':
            yield from shapes(a[y0:y1], ~bg[y0:y1], cols)
            continue
        # Gemini never spaces frames exactly evenly: cut each boundary at the emptiest column within a third of a cell
        # of the even split (nearest the split on a tie), so a figure off its slot or a spear across the gap isn't halved.
        cs, cut = (~bg[y0:y1]).sum(0), [0]
        for k in range(1, cols):
            c, r = k * W // cols, W // (3 * cols)
            cut.append(c - r + int(np.argmin(cs[c - r:c + r + 1] + 1e-3 * np.abs(np.arange(-r, r + 1)))))
        cut.append(W)
        for k in range(cols):
            x0, x1 = cut[k], cut[k + 1]
            fg = ~bg[y0:y1, x0:x1]
            lab, n = ndimage.label(fg)
            if n == 0:
                continue
            sizes = ndimage.sum(fg, lab, range(1, n + 1))
            big = np.argmax(sizes) + 1
            # Keep the figure plus its detached bits (hair tips, cape tatters, a spear past the hand), but drop
            # specks and neighbours' fists poking in across the cell's side edges.
            keep = lab == big
            for i, (s, sl) in enumerate(zip(sizes, ndimage.find_objects(lab)), 1):
                if i != big and s >= 0.003 * sizes.max() and sl[1].start > 0 and sl[1].stop < x1 - x0:
                    keep |= lab == i
            ys, xs = np.nonzero(keep)
            sl = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
            rgba = np.dstack([a[y0:y1, x0:x1][sl], keep[sl] * 255]).astype(np.uint8)
            im = Image.fromarray(rgba)
            im.info['top'] = ys.min()        # where the figure stands in its row of the strip (--anchor strip)
            yield im


def shrink(im, h, quant='median'):
    # Each output pixel takes its block's most common colour (the source cut to 96 colours first), not the average:
    # thin bright lava cracks, silver trim and outlines stay crisp instead of melting into their surroundings.
    a = np.asarray(im)
    H, W = a.shape[:2]
    w = max(1, round(W * h / H))
    vis = a[..., 3] > 128
    rgb = a[..., :3].copy(); rgb[~vis] = rgb[vis][0]
    meth = Image.Quantize.FASTOCTREE if quant == 'octree' else Image.Quantize.MEDIANCUT
    q = np.asarray(Image.fromarray(rgb).quantize(colors=96, method=meth, dither=Image.Dither.NONE).convert('RGB'))
    out = np.zeros((h, w, 4), np.uint8)
    for oy in range(h):
        y0 = oy * H // h; y1 = max(y0 + 1, (oy + 1) * H // h)
        for ox in range(w):
            x0 = ox * W // w; x1 = max(x0 + 1, (ox + 1) * W // w)
            m = vis[y0:y1, x0:x1].reshape(-1)
            if m.mean() < 0.43:
                continue
            cols, cnt = np.unique(q[y0:y1, x0:x1].reshape(-1, 3)[m], axis=0, return_counts=True)
            out[oy, ox] = (*cols[cnt.argmax()], 255)
    return Image.fromarray(out)


def lock(rgb, pal):
    # Nearest palette colour per pixel (palette lock: every frame of a character shares one palette).
    a = np.asarray(rgb).astype(int).reshape(-1, 3)
    d = ((a[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
    return pal[d.argmin(1)].reshape(rgb.height, rgb.width, 3).astype(np.uint8)


def body(f):
    # The figure without its thin parts (spear, tatters): (centre x of the shoulders-to-hips band, top, bottom) in f's px.
    m = np.asarray(f)[..., 3] > 128
    r = max(1, round(0.025 * f.height))
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    lab, n = ndimage.label(ndimage.binary_opening(m, structure=xx * xx + yy * yy <= r * r))
    if n == 0:
        return f.width / 2, 0, f.height
    b = lab == np.argmax(ndimage.sum(m, lab, range(1, n + 1))) + 1
    ys, xs = np.nonzero(b)
    top, bot = ys.min(), ys.max() + 1
    band = (ys >= top + 0.15 * (bot - top)) & (ys < top + 0.6 * (bot - top))
    return xs[band].mean(), top, bot


def build(strip, cols, rows, height, out, palette=None, cell=None, touchup=(), quant='median', anchor='box', pick=None,
          bob=None, split='columns'):
    figs = list(figures(strip, cols, rows, split))
    assert len(figs) == cols * rows, f'{len(figs)} figures found, expected {cols * rows}'
    if pick:
        figs = [figs[i] for i in pick]
    if anchor in ('body', 'strip', 'head'):
        # One scale for the strip: the tallest body (spear left out) is `height`. Each frame is placed by its body: the
        # shoulders-to-hips centre on the cell's centre, the feet on the bottom line, so a spear or a stride that
        # changes the box never makes the body jump.
        bodies = [body(f) for f in figs]
        s = height / max(b - t for _, t, b in bodies)
        frames = [shrink(f, max(1, round(f.height * s)), quant) for f in figs]
        ax = [round(x * fr.width / f.width) for (x, _, _), fr, f in zip(bodies, frames, figs)]
        bot = [round(b * fr.height / f.height) for (_, _, b), fr, f in zip(bodies, frames, figs)]
        if anchor == 'strip':    # keep the heights Gemini drew them at (a run's bob), the lowest feet on the line
            t = [round(f.info['top'] * s) for f in figs]
            low = max(ti + bi for ti, bi in zip(t, bot))
            bot = [low - ti for ti in t]
        if anchor == 'head':     # the top of the head on one line plus a designed bob (px, + = lower); the lowest feet on the bottom line
            b = bob or [0] * len(figs)
            tops = [round(t * fr.height / f.height) for (_, t, _), fr, f in zip(bodies, frames, figs)]
            low = max(fr.height - tp + bi for tp, bi, fr in zip(tops, b, frames))
            bot = [low - bi + tp for tp, bi in zip(tops, b)]
        cw = (2 * max(max(a, fr.width - a) for a, fr in zip(ax, frames)) + 3) // 2 * 2
        ch = max(bot) + 1
    else:
        tall = max(f.height for f in figs)    # one scale for the strip: the tallest figure is `height`, a crouch stays low
        frames = [shrink(f, max(1, round(f.height * height / tall)), quant) for f in figs]
        cw, ch = (max(f.width for f in frames) + 3) // 2 * 2, height + 1    # even width keeps texels on the screen grid
    if cell:
        assert cw <= cell[0] and ch <= cell[1], f'frames {cw}x{ch} do not fit the manifest cell {cell}'
        cw, ch = cell
    sheet = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        if anchor in ('body', 'strip', 'head'):
            x, y = i * cw + cw // 2 - ax[i], ch - 1 - bot[i]
            if y + f.height > ch - 1:    # below the feet line the floor hides it in the game anyway
                print(f'frame {i}: {y + f.height - ch + 1} px below the feet cut off')
                f = f.crop((0, 0, f.width, ch - 1 - y))
            assert y >= 0 and x >= i * cw and x + f.width <= (i + 1) * cw, \
                f'frame {i} ({f.width}x{f.height}, body at {ax[i]},{bot[i]}) does not fit the cell {cw}x{ch}'
            sheet.alpha_composite(f, (x, y))
        else:
            sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, ch - 1 - f.height))
    a = np.asarray(sheet).copy()
    ai = a.astype(int)
    # The magenta fringe only sits on the figure's rim, so only the rim is fixed: Elvis's navy cape keeps its blue.
    solid = a[..., 3] > 0
    rim = solid & ~ndimage.binary_erosion(solid, border_value=0)
    purple = (ai[..., 2] > ai[..., 1] + 20) & (ai[..., 0] > ai[..., 1] + 20) & (ai[..., 2] > ai[..., 0] - 40) & rim
    a[purple, :3] = (34, 22, 20)                                       # magenta fringe -> dark outline
    tint = rim & (ai[..., 2] > ai[..., 1] + 8) & (ai[..., 0] > ai[..., 1] + 8)   # rim colours still pulled toward magenta
    a[tint, 2] = a[tint, 1]                                            # drop the blue, keeping a warm brown
    sheet = Image.fromarray(a)
    rgb, alpha = sheet.convert('RGB'), sheet.getchannel('A')
    fix = [(f, x, y, tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))) for f, x, y, h in touchup]
    locked = bool(palette) and os.path.exists(palette)
    if locked:
        pal = np.asarray(Image.open(palette).convert('RGB')).reshape(-1, 3).astype(int)
        q = lock(rgb, pal)
        fix = [(f, x, y, tuple(lock(Image.new('RGB', (1, 1), c), pal)[0, 0])) for f, x, y, c in fix]
    else:
        vis = np.asarray(alpha) > 0
        a3 = np.asarray(rgb).copy(); a3[~vis] = a3[vis][0]      # transparent pixels must not take a palette slot
        n = 32 - len({c for *_, c in fix})                         # hand touch-up colours count toward the 32
        q = np.asarray(Image.fromarray(a3).quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')).copy()
    for f, x, y, c in fix:                                         # hand touch-ups (eyes): [frame, x, y, '#rrggbb'] in the cell
        q[y, f * cw + x] = c
        alpha.putpixel((f * cw + x, y), 255)
    if palette and not locked:
        used = np.unique(q[np.asarray(alpha) > 0].reshape(-1, 3), axis=0)
        Image.fromarray(used.reshape(1, -1, 3).astype(np.uint8)).save(palette)
    img = Image.fromarray(q).convert('RGBA'); img.putalpha(alpha)
    img.save(out)
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(os.path.splitext(out)[0] + '_x4.png')
    return img, (cw, ch), len(frames)


def manifest(path, key, file, frames, fps, loop, cell):
    m = json.load(open(path)) if os.path.exists(path) else {'cell': list(cell), 'anims': {}}
    old = m['anims'].get(key, {})
    m['anims'][key] = {'file': file, 'frames': frames, 'fps': fps, 'loop': loop, **({'holds': old['holds']} if 'holds' in old else {})}
    json.dump(m, open(path, 'w'), indent=1)


def selftest():
    import tempfile
    d = tempfile.mkdtemp()
    a = np.zeros((200, 400, 3), np.uint8); a[...] = (255, 0, 255)
    for k in range(2):                                    # two figures, each a body, an eye and a detached spear tip
        a[40:180, 60 + 200 * k:120 + 200 * k] = (200, 150, 100)
        a[60:70, 80 + 200 * k:100 + 200 * k] = (20, 20, 30)
        a[20:30, 150 + 200 * k:155 + 200 * k] = (180, 180, 190)
    Image.fromarray(a).save(d + '/s.png')
    img, cell, n = build(d + '/s.png', 2, 1, 40, d + '/o.png', palette=d + '/p.png', touchup=[[1, 3, 10, '#00ff88']])
    assert np.asarray(img)[10, cell[0] + 3, :3].tolist() == [0, 255, 136], 'touch-up'
    assert n == 2 and img.size == (cell[0] * 2, cell[1]), (img.size, cell)
    px = np.asarray(img); vis = px[px[..., 3] > 0][:, :3].astype(int)
    assert not magenta(vis[None]).any(), 'magenta left'
    assert Image.open(d + '/p.png').width <= 32
    img2, _, _ = build(d + '/s.png', 2, 1, 40, d + '/o2.png', palette=d + '/p.png', cell=(cell[0] + 2, cell[1]))
    pal = {tuple(c) for c in np.asarray(Image.open(d + '/p.png').convert('RGB')).reshape(-1, 3)}
    v2 = np.asarray(img2)
    assert all(tuple(c) in pal for c in v2[v2[..., 3] > 0][:, :3]), 'palette lock'
    img3, (cw, ch), _ = build(d + '/s.png', 2, 1, 40, d + '/o3.png', palette=d + '/p.png', cell=(60, 50), anchor='body')
    v3 = np.asarray(img3)[..., 3] > 0
    for k in range(2):                                    # the body (not the box with the spear tip) is centred, feet on the line
        rows = v3[10:30, k * cw:(k + 1) * cw]
        assert abs(np.nonzero(rows)[1].mean() - cw / 2) <= 1, 'body anchor x'
        assert v3[ch - 2, k * cw:(k + 1) * cw].any() and not v3[ch - 1].any(), 'body anchor feet'
    img4, (cw, ch), _ = build(d + '/s.png', 2, 1, 40, d + '/o4.png', palette=d + '/p.png', cell=(60, 50), anchor='head',
                              pick=[1, 0], bob=[0, 2])
    v4 = np.asarray(img4)[..., 3] > 0
    body_top = [np.nonzero(v4[:, k * cw + 20:k * cw + 40].any(1))[0].min() for k in range(2)]    # the body's columns
    assert body_top[1] - body_top[0] == 2, ('head anchor bob', body_top)
    img5, (cw, ch), _ = build(d + '/s.png', 2, 1, 40, d + '/o5.png', palette=d + '/p.png', cell=(60, 50), anchor='body', split='shapes')
    assert np.array_equal(np.asarray(img5), np.asarray(img3)), 'shape split = column split when the figures stand apart'
    print('selftest ok')


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        selftest(); sys.exit()
    p = argparse.ArgumentParser()
    p.add_argument('strip'); p.add_argument('--cols', type=int, required=True); p.add_argument('--rows', type=int, required=True)
    p.add_argument('--height', type=int, default=80); p.add_argument('--palette'); p.add_argument('--out', required=True)
    p.add_argument('--manifest'); p.add_argument('--key'); p.add_argument('--fps', type=float, default=8)
    p.add_argument('--loop', action=argparse.BooleanOptionalAction, default=True);
    p.add_argument('--quant', choices=('median', 'octree'), default='median', help='how the source is cut to 96 colours first')
    p.add_argument('--touchup', help='JSON list of [frame, x, y, "#rrggbb"] hand pixel edits, applied last')
    p.add_argument('--anchor', choices=('box', 'body', 'strip', 'head'), default='box',
                   help='place frames by their box, or by the body (animations; strip: keep the heights they were drawn at; '
                        'head: the top of the head on one line, plus --bob)')
    p.add_argument('--pick', help='use only these strip frames, in this order: 0,2,3')
    p.add_argument('--split', choices=('columns', 'shapes'), default='columns',
                   help='cut a row into frames at the emptiest columns, or take its --cols biggest shapes (spears overlapping the next frame)')
    p.add_argument('--bob', help='--anchor head: px each frame\'s head sits lower (+) or higher (-): 0,1,-1')
    A = p.parse_args()
    cell = json.load(open(A.manifest))['cell'] if A.manifest and os.path.exists(A.manifest) else None
    fix = json.load(open(A.touchup)) if A.touchup else ()
    pick = [int(v) for v in A.pick.split(',')] if A.pick else None
    bob = [int(v) for v in A.bob.split(',')] if A.bob else None
    img, cell, n = build(A.strip, A.cols, A.rows, A.height, A.out, A.palette, cell, fix, A.quant, A.anchor, pick, bob, A.split)
    if A.manifest:
        manifest(A.manifest, A.key, os.path.basename(A.out), n, A.fps, A.loop, cell)
    print('frames', n, 'cell', *cell, 'sheet', *img.size)
