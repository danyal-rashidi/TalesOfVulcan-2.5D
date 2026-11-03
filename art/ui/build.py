"""The menu's art, from the pictures in D:\\SmartRig\\spike\\cinerea\\. Run from the game's folder:
  uv run --with pillow --with numpy --with scipy python art/ui/build.py D:/SmartRig/spike/cinerea
The frame is art/tools/menu_frame.py's. items.png, skills.png: icon atlases
in Journey's order (then run art/tools/shop_art.py, which adds the shop's rows to items.png). map.png, map_regions.png: the world map and which region each pixel is in (red = 40 x its place in Journey.REGIONS + 40). Road props go to art/props/.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
sys.path.insert(0, "art/tools")
from props_to_sprites import grid, sprite

W, H = 640, 360
MAP_SIZE = (444, 250)
REGIONS = [  # in a 640x360 picture of the map
    [(0, 0), (640, 0), (640, 70), (0, 70)],
    [(0, 70), (400, 70), (400, 130), (320, 160), (130, 190), (0, 200)],
    [(400, 70), (640, 70), (640, 240), (500, 235), (430, 190), (400, 130)],
    [(0, 200), (130, 190), (320, 160), (400, 130), (430, 190), (500, 235), (480, 250), (400, 290), (400, 360), (0, 360)],
    [(400, 290), (480, 250), (500, 235), (640, 240), (640, 360), (400, 360)],
]


def atlas(src, name, rows, cols, size, out):
    rgb, cells = grid(f"{src}/{name}.png", rows, cols)
    sheet = Image.new("RGBA", (cols * size, rows * size), (0, 0, 0, 0))
    for n, (x, y, cell) in enumerate(cells):
        s = Image.fromarray(sprite(rgb, cell, x, y, size - 2))
        sheet.alpha_composite(s, ((n % cols) * size + (size - s.width) // 2, (n // cols) * size + (size - s.height) // 2))
    sheet.save(out)


def world(src):
    m = Image.open(f"{src}/map.png").convert("RGB")
    m.resize(MAP_SIZE, Image.LANCZOS).quantize(64, dither=Image.Dither.NONE).convert("RGB").save("art/ui/map.png")
    # wobbled borders, so a region's edge reads as a coast and not a ruler's line
    ids = Image.new("L", (W, H), 0); d = ImageDraw.Draw(ids)
    for i, p in enumerate(REGIONS):
        d.polygon(p, fill=40 * (i + 1))
    a = np.asarray(ids)
    rng = np.random.default_rng(7)
    dx, dy = (gaussian_filter(rng.standard_normal((H, W)), 9) * 110 for _ in "xy")
    yy, xx = np.mgrid[0:H, 0:W]
    wob = a[np.clip(yy + dy.round().astype(int), 0, H - 1), np.clip(xx + dx.round().astype(int), 0, W - 1)]
    Image.fromarray(wob).resize(MAP_SIZE, Image.NEAREST).save("art/ui/map_regions.png")


def road(src):
    rgb, cells = grid(f"{src}/road.png", 2, 4)
    jobs = [("tomb_big", 60), ("tomb_small", 34), ("tomb_broken", 44), ("milestone", 26), ("cypress", 72), ("bush", 22), ("rubble", 30), ("house", 96)]
    for (name, size), (x, y, cell) in zip(jobs, cells):
        Image.fromarray(sprite(rgb, cell, x, y, size)).save(f"art/props/{name}.png")


def main():
    src = sys.argv[1]
    os.makedirs("art/ui", exist_ok=True)
    atlas(src, "items", 2, 4, 22, "art/ui/items.png")
    atlas(src, "skills", 5, 6, 26, "art/ui/skills.png")
    world(src)
    road(src)
    # a visible check of the grids: 8 and 30 icons, none empty
    for f, n, s in (("art/ui/items.png", 8, 22), ("art/ui/skills.png", 30, 26)):
        a = np.asarray(Image.open(f).convert("RGBA"))[..., 3]
        cols = a.shape[1] // s
        for i in range(n):
            cell = a[(i // cols) * s:(i // cols + 1) * s, (i % cols) * s:(i % cols + 1) * s]
            assert (cell > 0).sum() > 30, f"{f} icon {i} is nearly empty"
    print("menu art built")


if __name__ == "__main__":
    main()
