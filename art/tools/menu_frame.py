"""The menu's frame: D:\\SmartRig\\spike\\web\\menu_frame_b.png, kept whole but fitted to the game's screen, its middle cleared for ui/menu.gd. Run from the game's folder:
  uv run --with pillow --with numpy python art/tools/menu_frame.py D:/SmartRig/spike/web
Nothing is cropped through: the bands are squeezed a little, the plain stone in the pillars stretched, and the iron diamonds keep their shape. The tools the picture hangs from its bottom band ran off its edge, half there, so they're painted out with clean stretches of the band.
"""
import sys
import numpy as np
from PIL import Image

W, H = 640, 360
# (picture from, picture to, frame to) in the picture's own 1344x768 pixels; a run stretches or squeezes if its two lengths differ
COLUMNS = [(0, 160, 134), (160, 1202, 1210), (1202, 1344, 1344)]
ROWS = [(0, 146, 128), (146, 362, 360), (362, 490, 488), (490, 684, 696), (684, 768, 768)]
TOOLS = [(150, 445, 445, 505), (890, 1195, 830, 890)]    # x from, x to, and the clean stretch of band beside them that tiles over them
TOOLS_FROM = 688     # the row they start at, under the panel's corners
CLEAR = (66, 62, 574, 324)      # what's cleared, inside the frame's thin bronze line; GameMenu.INNER is this and its margin
KEEP = (308, 58, 332, 69)       # the ember under the title plaque hangs into it
KEEP_ABOVE = 175                # how bright (r + g + b) a pixel there must be: the ember and its iron, not the panel behind them
EMPTY = (22, 16, 18)


def remap(runs):
    out, done = [], 0
    for start, end, to in runs:
        out.append(np.linspace(start, end, to - done, endpoint=False).astype(int))
        done = to
    return np.concatenate(out)


def main(src):
    a = np.array(Image.open(f"{src}/menu_frame_b.png").convert("RGB"))
    for x0, x1, c0, c1 in TOOLS:
        a[TOOLS_FROM:, x0:x1] = a[TOOLS_FROM:, c0 + (np.arange(x0, x1) - x0) % (c1 - c0)]
    a[720:, 100:160] = a[720:, 1184:1244][:, ::-1]    # a bit of the picture's forge at the left pillar's foot: the right pillar's clean foot, mirrored
    a = a[remap(ROWS)][:, remap(COLUMNS)]
    img = Image.fromarray(a).resize((W, H), Image.LANCZOS).quantize(160, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB")    # a common-colour palette turns the rare flames beige
    b = np.array(img)
    keep = b[KEEP[1]:KEEP[3], KEEP[0]:KEEP[2]].copy()
    x0, y0, x1, y1 = CLEAR
    b[y0:y1, x0:x1] = EMPTY
    part = b[KEEP[1]:KEEP[3], KEEP[0]:KEEP[2]]
    lit = keep.astype(int).sum(axis=-1) > KEEP_ABOVE
    part[lit] = keep[lit]
    Image.fromarray(b).save("art/ui/frame.png")
    print("menu frame built")


if __name__ == "__main__":
    main(sys.argv[1])
