# Gemini frames on magenta -> real-size pixel sprites with one shared palette, feet aligned, one sheet.
# Usage: sprites.py idle.webp walk_strip.webp COLS ROWS out_dir HEIGHT
import sys, numpy as np
from PIL import Image
from scipy import ndimage
idle, strip, COLS, ROWS, out, HT = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], int(sys.argv[6])
DARK = float(sys.argv[7]) if len(sys.argv) > 7 else 999.0   # 999 = plain average

def figures(path, cols, rows):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (b > 110) & (r > 110) & (g < 0.62 * np.minimum(r, b))      # magenta and its fringe
    H, W = bg.shape
    for j in range(rows):
        for k in range(cols):
            y0, y1, x0, x1 = j * H // rows, (j + 1) * H // rows, k * W // cols, (k + 1) * W // cols
            fg = ~bg[y0:y1, x0:x1]
            lab, n = ndimage.label(fg)
            if n == 0: continue
            keep = lab == (np.argmax(ndimage.sum(fg, lab, range(1, n + 1))) + 1)   # drop neighbours' fists
            ys, xs = np.nonzero(keep)
            sl = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
            rgba = np.dstack([a[y0:y1, x0:x1][sl], keep[sl] * 255]).astype(np.uint8)
            yield Image.fromarray(rgba)

def shrink(im, h, dark=DARK):
    # Average each block, but keep its darkest pixel when that is much darker than the average:
    # eyes, outlines and creases survive the shrink instead of melting into the skin.
    a = np.asarray(im).astype(float)
    H, W = a.shape[:2]
    w = max(1, round(W * h / H))
    out = np.zeros((h, w, 4), np.uint8)
    lumw = np.array([0.3, 0.59, 0.11])
    for oy in range(h):
        y0 = oy * H // h; y1 = max(y0 + 1, (oy + 1) * H // h)
        for ox in range(w):
            x0 = ox * W // w; x1 = max(x0 + 1, (ox + 1) * W // w)
            blk = a[y0:y1, x0:x1].reshape(-1, 4)
            px = blk[blk[:, 3] > 128, :3]
            if len(px) < 0.43 * len(blk):
                continue
            avg = px.mean(0)
            lum = px @ lumw
            c = px[lum.argmin()] if lum.min() < avg @ lumw - dark else avg
            out[oy, ox] = (*c.clip(0, 255), 255)
    return Image.fromarray(out)

frames = [shrink(f, HT) for f in figures(idle, 1, 1)] + [shrink(f, HT) for f in figures(strip, COLS, ROWS)]
cw, ch = (max(f.width for f in frames) + 3) // 2 * 2, HT + 1    # even width keeps texels on the screen grid
sheet = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * cw + (cw - f.width) // 2, ch - 1 - f.height))
a = np.asarray(sheet).copy()
purple = (a[..., 2].astype(int) > a[..., 1].astype(int) + 20) & (a[..., 0].astype(int) > a[..., 1].astype(int) + 20) & (a[..., 2].astype(int) > a[..., 0].astype(int) - 40) & (a[..., 3] > 0)
a[purple, :3] = (34, 22, 20)                                       # magenta fringe -> dark outline
sheet = Image.fromarray(a)
rgb, alpha = sheet.convert('RGB'), sheet.getchannel('A')
pal = rgb.quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
q = np.asarray(pal.convert('RGB')).copy()
tint = q[..., 2].astype(int) > q[..., 1].astype(int) + 8           # colours still pulled toward magenta
q[tint, 2] = q[tint, 1]                                            # drop the blue, keeping a warm brown
out_img = Image.fromarray(q).convert('RGBA'); out_img.putalpha(alpha)
out_img.save(out + '/vulcan_sheet.png')
out_img.resize((out_img.width * 4, out_img.height * 4), Image.NEAREST).save(out + '/vulcan_sheet_x4_preview.png')
assert len(frames) == 1 + COLS * ROWS, len(frames)
print('frames', len(frames), 'cell', cw, ch, 'sheet', out_img.size)
