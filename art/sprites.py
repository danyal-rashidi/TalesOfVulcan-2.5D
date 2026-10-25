# Gemini frames on magenta -> real-size pixel sprites with one shared palette, feet aligned, one sheet (one row).
# Usage:
#   uv run --with pillow --with numpy --with scipy python art/sprites.py <strip> --cols C --rows R --height 80 \
#       [--palette P] --out <png> [--manifest M --key K --fps F --loop|--no-loop] [--touchup J] [--quant median|octree]
#   --palette P: lock every colour to P's colours; if P doesn't exist yet, this run's 32 colours are written to it.
#   --manifest: adds or replaces anim K in M (cell size is shared: an existing manifest's cell is kept; holds are kept).
#   --height: the tallest figure in the strip, every frame at the same scale (raise it when a spear tip sticks up).
#   --quant octree: keeps small saturated spots (a gold buckle, eye whites) that median cut (default; best for lava and
#       steel trim) merges into their surroundings. Use the same setting for every sheet of a character.
#   --touchup J: hand pixel edits (eyes) applied after the clean-up, [[frame, x, y, "#rrggbb"], ...]; colours count toward 32.
#   Writes <out> and <out>_x4.png (4x nearest preview). Self-check: sprites.py --selftest
import argparse, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage


def magenta(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (b > 110) & (r > 110) & (g < 0.62 * np.minimum(r, b))      # magenta and its fringe


def figures(path, cols, rows):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    bg = magenta(a)
    H, W = bg.shape
    for j in range(rows):
        for k in range(cols):
            y0, y1, x0, x1 = j * H // rows, (j + 1) * H // rows, k * W // cols, (k + 1) * W // cols
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
            yield Image.fromarray(rgba)


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


def build(strip, cols, rows, height, out, palette=None, cell=None, touchup=(), quant='median'):
    figs = list(figures(strip, cols, rows))
    tall = max(f.height for f in figs)        # one scale for the strip: the tallest figure is `height`, a crouch stays low
    frames = [shrink(f, max(1, round(f.height * height / tall)), quant) for f in figs]
    assert len(frames) == cols * rows, f'{len(frames)} figures found, expected {cols * rows}'
    cw, ch = (max(f.width for f in frames) + 3) // 2 * 2, height + 1    # even width keeps texels on the screen grid
    if cell:
        assert cw <= cell[0] and ch <= cell[1], f'frames {cw}x{ch} do not fit the manifest cell {cell}'
        cw, ch = cell
    sheet = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
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
    A = p.parse_args()
    cell = json.load(open(A.manifest))['cell'] if A.manifest and os.path.exists(A.manifest) else None
    fix = json.load(open(A.touchup)) if A.touchup else ()
    img, cell, n = build(A.strip, A.cols, A.rows, A.height, A.out, A.palette, cell, fix, A.quant)
    if A.manifest:
        manifest(A.manifest, A.key, os.path.basename(A.out), n, A.fps, A.loop, cell)
    print('frames', n, 'cell', *cell, 'sheet', *img.size)
