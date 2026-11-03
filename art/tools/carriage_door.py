"""Cassia's carriage with a door that opens: art/props/carriage.png keeps a dark doorway behind where the door was, and carriage_door.png is the door swinging on its hinge in DOOR_FRAMES frames, each the carriage's size so it sits right on top. Run from the game's folder, after round2_props.py:
  uv run --with pillow --with numpy python art/tools/carriage_door.py
Keeps the whole picture as carriage_whole.png the first time, and always starts from that.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

WHOLE = "art/props/carriage_whole.png"
DOOR = [(96, 66), (119, 56), (120, 108), (96, 118)]    # its corners in the picture, inside the gold frame; the hinge is the right edge, the handle the left
SQUEEZE = [1.0, 0.62, 0.3, 0.12]       # how wide the door looks as it swings towards us and round
INSIDE = (38, 20, 22)                  # the dark of the carriage's inside
FLOOR = (86, 44, 30)
HINGE = 120
DOOR_FRAMES = len(SQUEEZE)


def main():
    if not os.path.exists(WHOLE):
        os.replace("art/props/carriage.png", WHOLE)
    a = np.array(Image.open(WHOLE).convert("RGBA"))
    h, w = a.shape[:2]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(DOOR, fill=255)
    mask = np.asarray(mask) > 0
    door = np.zeros_like(a)
    door[mask] = a[mask]
    # the doorway: dark inside, a lighter line of floor along the bottom where she stands
    body = a.copy()
    body[mask, :3] = INSIDE
    ys, xs = np.nonzero(mask)
    for x in np.unique(xs):
        bottom = ys[xs == x].max()
        body[max(bottom - 2, 0):bottom + 1, x, :3] = FLOOR
    Image.fromarray(body).save("art/props/carriage.png")
    frames = []
    for k in SQUEEZE:
        f = np.zeros_like(a)
        for y, x in zip(ys, xs):
            nx = HINGE - round((HINGE - x) * k)    # it narrows towards the hinge as it swings
            f[y, nx] = door[y, x]
            if k < 1.0:
                f[y, nx - 1] = door[y, x]         # no gaps as it's squeezed: it never widens, but rounding can skip
        frames.append(f)
    Image.fromarray(np.concatenate(frames, axis=1)).save("art/props/carriage_door.png")
    print("carriage door built", DOOR_FRAMES, "frames")


if __name__ == "__main__":
    main()
