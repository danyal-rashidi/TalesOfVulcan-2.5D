"""A character who stands in one place -> a folder the game can load: one front picture on green, shrunk, one frame, no clip. Townsperson gives it its small bob.
  uv run --with pillow --with numpy --with scipy python art/tools/still_character.py PICTURE FOLDER HEIGHT
"""
import json
import os
import sys
import numpy as np
from PIL import Image
from sheet_to_props import objects
from props_to_sprites import sprite

picture, folder, height = sys.argv[1], sys.argv[2], int(sys.argv[3])
rgb, lab, solid, found = objects(picture, 1, 1)
_, sl, i = found[0]
px = sprite(rgb, solid[sl] & (lab[sl] == i), sl[1].start, sl[0].start, height)
r, g, b = (px[..., c].astype(int) for c in range(3))
px[(g - r > 60) & (g - b > 40) & (r < 70), 3] = 0
os.makedirs(f"art/{folder}", exist_ok=True)
Image.fromarray(px).save(f"art/{folder}/idle_F.png")
with open(f"art/{folder}/manifest.json", "w") as f:
    json.dump({"cell": [px.shape[1], px.shape[0]], "anims": {"idle_F": {"file": "idle_F.png", "frames": 1, "fps": 1.0, "loop": True}}}, f, indent=1)
print(folder, px.shape)
