"""A picture of props on flat green, 2 rows of 4 -> one small sprite per prop in art/props/, the size it stands in the game. Every small pixel takes
the most common colour of its block (low threshold, so a spear's thin shaft survives), then a 1 px dark outline.
  uv run --with pillow --with numpy python art/tools/props_to_sprites.py PICTURE SUFFIX name:size name:size ... (left to right, top to bottom; size = longest side in px)
"""
import sys
import numpy as np
from PIL import Image

OUTLINE = (20, 14, 16)


def sprite(rgb, cell, x, y, size):
    """The figure in `cell` (a mask of the part of the picture at x, y) as a sprite `size` px on its longest side, outlined."""
    ys, xs = np.nonzero(cell)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    block = (max(y1 - y0, x1 - x0)) / size
    h, w = max(1, round((y1 - y0) / block)), max(1, round((x1 - x0) / block))
    part = rgb[y + y0:y + y1, x + x0:x + x1]
    mask = cell[y0:y1, x0:x1]
    q = Image.fromarray(part.astype(np.uint8)).quantize(24, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal, idx = np.array(q.getpalette()).reshape(-1, 3), np.asarray(q)
    out = np.zeros((h + 2, w + 2, 4), np.uint8)
    yy, xx = np.linspace(0, y1 - y0, h + 1).astype(int), np.linspace(0, x1 - x0, w + 1).astype(int)
    for i in range(h):
        for j in range(w):
            a = mask[yy[i]:yy[i + 1], xx[j]:xx[j + 1]]
            if a.mean() > 0.33:
                c = np.bincount(idx[yy[i]:yy[i + 1], xx[j]:xx[j + 1]][a].ravel(), minlength=len(pal)).argmax()
                out[i + 1, j + 1] = (*pal[c], 255)
    m = out[..., 3] > 0
    assert m.sum() > 0, "nothing left"
    grow = m.copy()
    grow[1:] |= m[:-1]; grow[:-1] |= m[1:]; grow[:, 1:] |= m[:, :-1]; grow[:, :-1] |= m[:, 1:]
    out[grow & ~m] = (*OUTLINE, 255)
    return out


def grid(picture, rows, cols):
    """The picture's colours, and for each grid cell (left to right, top to bottom) its x, y and figure mask, from the flat green background."""
    rgb = np.asarray(Image.open(picture).convert("RGB")).astype(float)
    bg = np.median(np.concatenate([rgb[:20].reshape(-1, 3), rgb[-20:].reshape(-1, 3)]), axis=0)
    solid = np.linalg.norm(rgb - bg, axis=-1) > 60
    H, W = solid.shape
    return rgb, [(c * W // cols, r * H // rows, solid[r * H // rows:(r + 1) * H // rows, c * W // cols:(c + 1) * W // cols]) for r in range(rows) for c in range(cols)]


def main():
    picture, suffix, jobs = sys.argv[1], sys.argv[2], [a.split(":") for a in sys.argv[3:]]
    assert len(jobs) == 8, "2 rows of 4"
    rgb, cells = grid(picture, 2, 4)
    for (name, size), (x, y, cell) in zip(jobs, cells):
        Image.fromarray(sprite(rgb, cell, x, y, int(size))).save(f"art/props/{name}_{suffix}.png")


if __name__ == "__main__":
    main()
