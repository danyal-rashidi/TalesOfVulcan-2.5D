"""Cassia's shop window, from the pictures in D:\\SmartRig\\spike\\web. Run from the game's folder, and again after art/ui/build.py, which rewrites items.png:
  uv run --with pillow --with numpy python art/tools/shop_art.py D:/SmartRig/spike/web
shop.png: ui_shop.png with narrower posts and a shorter awning, so the middle holds the shop (ui/shop.gd). The coin and the spice pots keep their shape; only plain stripes and wood stretch.
items.png: shop_icons.png's 8 icons as two more rows, in Journey.ITEMS' icon numbers 8 to 15.
"""
import sys
import numpy as np
from PIL import Image
sys.path.insert(0, "art/tools")
from props_to_sprites import grid, sprite

W, H = 640, 360
# (picture from, picture to, shop.png to) in the picture's own 1344x768 pixels; a run stretches if its two lengths differ
COLUMNS = [(60, 360, 300), (360, 600, 600), (600, 744, 744), (744, 984, 1044), (984, 1284, 1344)]
ROWS = [(24, 190, 166), (190, 570, 593), (570, 745, 768)]
EMPTY = (28, 19, 17)    # the panel's plain middle
MIDDLE = (86, 78, 554, 300)    # where it is in shop.png, for ui/shop.gd
ICON = 22
SPILL = (5, 7)    # the icons the green background bleeds into; not the ring, whose stone is green


def remap(runs):
    """For each pixel of the result, which pixel of the picture it comes from."""
    out, done = [], 0
    for start, end, to in runs:
        out.append(np.linspace(start, end, to - done, endpoint=False).astype(int))
        done = to
    return np.concatenate(out)


def window(src):
    a = np.asarray(Image.open(f"{src}/ui_shop.png").convert("RGB"))
    a = a[remap(ROWS)][:, remap(COLUMNS)]
    img = Image.fromarray(a).resize((W, H), Image.LANCZOS).quantize(64, dither=Image.Dither.NONE).convert("RGB")
    b = np.array(img)
    x0, y0, x1, y1 = MIDDLE
    part = b[y0:y1, x0:x1]
    part[part.sum(axis=-1) < 130] = EMPTY    # the painted middle has faint noise; the pots at its corners stay
    Image.fromarray(b).save("art/ui/shop.png")


def icons(src):
    rgb, cells = grid(f"{src}/shop_icons.png", 2, 4)
    old = Image.open("art/ui/items.png").convert("RGBA").crop((0, 0, 4 * ICON, 2 * ICON))
    sheet = Image.new("RGBA", (4 * ICON, 4 * ICON), (0, 0, 0, 0))
    sheet.paste(old, (0, 0))
    for n, (x, y, cell) in enumerate(cells):
        if n in SPILL:
            part = rgb[y:y + cell.shape[0], x:x + cell.shape[1]]
            part[..., 1] = np.minimum(part[..., 1], part[..., [0, 2]].max(axis=-1))
        s = Image.fromarray(sprite(rgb, cell, x, y, ICON - 2))
        sheet.alpha_composite(s, ((n % 4) * ICON + (ICON - s.width) // 2, (2 + n // 4) * ICON + (ICON - s.height) // 2))
        assert (np.asarray(s)[..., 3] > 0).sum() > 30, f"icon {n} is nearly empty"
    sheet.save("art/ui/items.png")


if __name__ == "__main__":
    window(sys.argv[1])
    icons(sys.argv[1])
    print("shop art built")
