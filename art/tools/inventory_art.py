"""The inventory's parts, from D:\\SmartRig\\spike\\web\\inventory_parts.png (docs/refs/ui/2026-10-31_inventory.png was its reference). Run from the game's folder, and again after art/tools/shop_art.py, which rewrites items.png:
  uv run --with pillow --with numpy python art/tools/inventory_art.py D:/SmartRig/spike/web
art/ui/medallion.png and slot.png for ui/menu.gd, and items.png's fifth row: the helmet, armour and boots an empty slot shows faintly (Journey.ITEMS icon numbers 16 to 18).
"""
import sys
import numpy as np
from PIL import Image
sys.path.insert(0, "art/tools")
from props_to_sprites import sprite

ICON = 22
# where each part is in the picture, x0, y0, x1, y1: the medallion is wider than a grid cell, so they're measured, not cut by grid()
BOXES = {"helmet": (80, 40, 295, 322), "armour": (355, 58, 675, 322), "boots": (711, 52, 975, 316), "slot": (1059, 108, 1251, 295), "medallion": (326, 367, 700, 730)}
SIZES = {"helmet": ICON - 2, "armour": ICON - 2, "boots": ICON - 2, "slot": 30, "medallion": 156}    # longest side


def main(src):
    rgb = np.asarray(Image.open(f"{src}/inventory_parts.png").convert("RGB")).astype(float)
    bg = np.median(np.concatenate([rgb[:20].reshape(-1, 3), rgb[-20:].reshape(-1, 3)]), axis=0)
    solid = np.linalg.norm(rgb - bg, axis=-1) > 60
    parts = {}
    for name, (x0, y0, x1, y1) in BOXES.items():
        parts[name] = Image.fromarray(sprite(rgb, solid[y0:y1, x0:x1], x0, y0, SIZES[name]))
    for name in ("slot", "medallion"):
        parts[name].save(f"art/ui/{name}.png")
    old = Image.open("art/ui/items.png").convert("RGBA").crop((0, 0, 4 * ICON, 4 * ICON))
    sheet = Image.new("RGBA", (4 * ICON, 5 * ICON), (0, 0, 0, 0))
    sheet.paste(old, (0, 0))
    for n, name in enumerate(("helmet", "armour", "boots")):
        s = parts[name]
        sheet.alpha_composite(s, (n * ICON + (ICON - s.width) // 2, 4 * ICON + (ICON - s.height) // 2))
    sheet.save("art/ui/items.png")
    print("inventory art built", {k: v.size for k, v in parts.items()})


if __name__ == "__main__":
    main(sys.argv[1])
