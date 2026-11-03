"""Feet on the ground: moves each frame of a character's sheets down so its lowest pixel sits on the cell's bottom row, where the game stands it (core/character_sprite.gd). Cut frames can end a few rows up, and the character then hovers and bobs (Danyal: Cassia "floating"). Run it from the game's folder, after steady_sheets.py, which rebuilds sheets from before_steady/:
  uv run --with pillow --with numpy python art/tools/ground_feet.py FOLDER
Sheets with "below" rows draw under the feet on purpose, so they're left alone. Don't use it on a run with flying frames, such as Elvis's.
"""
import json
import sys

import numpy as np
from PIL import Image


def grounded(sheet, cell_w):
    """The sheet with every frame's lowest pixel on its bottom row, and how many frames moved."""
    out = sheet.copy()
    moved = 0
    for x in range(0, sheet.shape[1], cell_w):
        frame = sheet[:, x:x + cell_w]
        rows = np.nonzero(frame[..., 3].any(axis=1))[0]
        if len(rows) == 0:
            continue
        down = sheet.shape[0] - 1 - rows.max()
        if down:
            out[:, x:x + cell_w] = np.roll(frame, down, axis=0)    # the rows it wraps round are empty
            moved += 1
        assert out[-1, x:x + cell_w, 3].any(), f"frame at x={x} isn't on the ground"
    return out, moved


def main(folder):
    path = f"art/{folder}"
    manifest = json.load(open(f"{path}/manifest.json"))
    cell_w = int(manifest["cell"][0])
    for key, anim in manifest["anims"].items():
        if anim.get("below"):
            continue
        file = f"{path}/{anim['file']}"
        sheet, moved = grounded(np.array(Image.open(file).convert("RGBA")), cell_w)
        Image.fromarray(sheet).save(file)
        print(key, "frames moved:", moved)


if __name__ == "__main__":
    main(sys.argv[1])
