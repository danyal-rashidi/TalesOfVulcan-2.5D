"""A sheet of objects on flat green, in rows -> one small sprite per object, the size it stands in the game. Unlike props_to_sprites.py the objects
needn't sit on an even grid: each is found by its own shape, so a neighbour can't leak in.
  uv run --with pillow --with numpy --with scipy python art/tools/sheet_to_props.py PICTURE OUT_DIR ROWS name:size name:size ... (left to right, top to bottom; size = longest side in px)
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ni
from props_to_sprites import sprite

KEY = 70     # how far from the background a colour must be to count: a soft shadow on the green stays below this


def objects(picture, rows, want):
    """Colours, labels, solid mask and the `want` biggest shapes in reading order, as (row, x, slice, label)."""
    rgb = np.asarray(Image.open(picture).convert("RGB")).astype(float)
    bg = np.median(np.concatenate([rgb[:20].reshape(-1, 3), rgb[-20:].reshape(-1, 3)]), axis=0)
    solid = np.linalg.norm(rgb - bg, axis=-1) > KEY
    lab, _ = ni.label(ni.binary_dilation(solid, iterations=5))    # a spark or a stone beside an object belongs to it
    found = []
    for i, sl in enumerate(ni.find_objects(lab), 1):
        found.append(((solid[sl] & (lab[sl] == i)).sum(), sl, i))
    found = sorted(sorted(found, key=lambda t: -t[0])[:want], key=lambda t: t[1][0].start)
    per = max(1, len(found) // rows)
    ordered = []
    for r in range(rows):
        row = found[r * per:] if r == rows - 1 else found[r * per:(r + 1) * per]
        ordered += sorted(row, key=lambda t: t[1][1].start)
    return rgb, lab, solid, ordered


def main():
    picture, out, rows, jobs = sys.argv[1], sys.argv[2], int(sys.argv[3]), [a.split(":") for a in sys.argv[4:]]
    rgb, lab, solid, found = objects(picture, rows, len(jobs))
    assert len(found) == len(jobs), f"{picture}: {len(found)} objects, {len(jobs)} names"
    os.makedirs(out, exist_ok=True)
    for (name, size), (_, sl, i) in zip(jobs, found):
        px = sprite(rgb, solid[sl] & (lab[sl] == i), sl[1].start, sl[0].start, int(size))
        r, g, b = (px[..., c].astype(int) for c in range(3))
        px[(g - r > 60) & (g - b > 40) & (r < 70), 3] = 0    # flecks of the background at the edges; a palm's green has more red in it
        Image.fromarray(px).save(f"{out}/{name}.png")


if __name__ == "__main__":
    main()
