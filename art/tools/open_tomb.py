"""Makes art/props/tomb_big_open.png from tomb_big.png: a strip of FRAMES frames, its grave slab sliding off a dark pit to the right. No credits.
  uv run --with pillow --with numpy python art/tools/open_tomb.py
"""
import numpy as np
from PIL import Image, ImageDraw

SLAB = [(15, 47), (32, 39), (37, 39), (46, 46), (46, 50), (27, 61), (20, 61), (12, 53), (12, 50)]    # the slab's outline on the sheet, by eye
FRAMES = 5
STEP = 6       # px it slides each frame
PAD = STEP * (FRAMES - 1) + 2    # both sides, so the tomb stays where it was
OUTLINE, PIT, WALL, RIM = (20, 14, 16, 255), (26, 19, 18, 255), (70, 54, 46, 255), (124, 96, 78, 255)


def mask(w, h):
    m = Image.new("1", (w, h))
    ImageDraw.Draw(m).polygon(SLAB, fill=1)
    return np.array(m)


def main():
    tomb = np.array(Image.open("art/props/tomb_big.png").convert("RGBA"))
    h, w = tomb.shape[:2]
    slab = mask(w, h) & (tomb[..., 3] > 0)
    # The pit: dark, the far wall lit, a stone lip at the near edge, all inside the slab's own outline, so the tomb's silhouette stays.
    pit = tomb.copy()
    for y, x in zip(*np.nonzero(slab)):
        above, below = slab[max(y - 2, 0), x], slab[min(y + 2, h - 1), x]
        edge = not (slab[y - 1, x] and slab[min(y + 1, h - 1), x] and slab[y, x - 1] and slab[y, min(x + 1, w - 1)])
        pit[y, x] = OUTLINE if edge else WALL if not above else RIM if not below else PIT
    strip = np.zeros((h, (w + 2 * PAD) * FRAMES, 4), np.uint8)
    for i in range(FRAMES):
        left = (w + 2 * PAD) * i + PAD
        strip[:, left:left + w] = pit
        cover = strip[:, left + STEP * i:left + STEP * i + w]
        cover[slab] = tomb[slab]
    Image.fromarray(strip).save("art/props/tomb_big_open.png")
    print(strip.shape)


if __name__ == "__main__":
    main()
