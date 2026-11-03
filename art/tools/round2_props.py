"""The rest of the pictures of 1 Nov 2026, from D:\\SmartRig\\spike\\web -> game art. Run from the game's folder:
  uv run --with pillow --with numpy --with scipy python art/tools/round2_props.py D:/SmartRig/spike/web
art/props/tuft_a..e_hi.png: dry grass at HI times the game's pixels, with empty columns either side, so core/grass.gdshader can bend it smoothly instead of in whole-pixel jumps. rock_tan, logs, carriage, lake. rm_*: what earlier challengers left in the desert. art/story/: the prologue's pictures. art/memories/hammer.png: Danyal's own.
"""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes
sys.path.insert(0, "art/tools")
from props_to_sprites import sprite
from town_walls import key, biggest

SWAY_ROOM = 7    # px (the game's) of empty columns either side of a tuft
HI = 4           # as core/grass.gdshader and game/grass.gd
BITS = {1: ("tuft_a", 36), 2: ("tuft_b", 22), 3: ("tuft_c", 28), 4: ("tuft_d", 26), 5: ("tuft_e", 38), 6: ("rock_tan", 18), 7: ("logs", 42)}
REMAINS = ["rm_sword:44", "rm_helmet:28", "rm_shield:34", "rm_plate:34", "rm_banner:60", "rm_column:62", "rm_arch:84", "rm_drift:52"]


def cell(rgb, solid, n, size, rows=2, cols=4):
    h, w = solid.shape
    r, c = n // cols, n % cols
    x0, y0, x1, y1 = c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows
    return sprite(rgb, biggest(solid[y0:y1, x0:x1]), x0, y0, size)


def hi_tuft(rgb, solid, n, size, rows=2, cols=4):
    """A tuft's own picture at HI times its size in the game, with no outline: the shader draws that, one game pixel wide."""
    h, w = solid.shape
    r, c = n // cols, n % cols
    x0, y0, x1, y1 = c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows
    mask = biggest(solid[y0:y1, x0:x1])
    ys, xs = np.nonzero(mask)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    part = Image.fromarray(np.dstack([rgb[y0:y1, x0:x1].astype(np.uint8), mask.astype(np.uint8) * 255])).crop(box)
    k = size * HI / max(part.size)
    part = part.resize((round(part.width * k), round(part.height * k)), Image.LANCZOS)
    a = np.array(part)
    a[..., 3] = (a[..., 3] > 128) * 255
    return np.pad(a, ((0, 0), (SWAY_ROOM * HI, SWAY_ROOM * HI), (0, 0)))


def main(src):
    rgb = np.asarray(Image.open(f"{src}/r2_bits.png").convert("RGB")).astype(float)
    solid = key(rgb)
    for n, (name, size) in BITS.items():
        if name.startswith("tuft"):
            Image.fromarray(hi_tuft(rgb, solid, n, size)).save(f"art/props/{name}_hi.png")
            continue
        Image.fromarray(cell(rgb, solid, n, size)).save(f"art/props/{name}.png")
    rgb = np.asarray(Image.open(f"{src}/r2_remains.png").convert("RGB")).astype(float)
    solid = key(rgb)
    for n, job in enumerate(REMAINS):
        name, size = job.split(":")
        s = cell(rgb, solid, n, int(size))
        Image.fromarray(s).save(f"art/props/{name}.png")
    for name, size in (("r2_carriage", ("carriage", 170)), ("r2_lake", ("lake", 660))):
        rgb = np.asarray(Image.open(f"{src}/{name}.png").convert("RGB")).astype(float)
        solid = biggest(key(rgb))
        if size[0] == "lake":
            solid = binary_fill_holes(solid)    # its reeds are as green as the background
        ys, xs = np.nonzero(solid)
        s = sprite(rgb, solid[ys.min():ys.max() + 1, xs.min():xs.max() + 1], xs.min(), ys.min(), size[1])
        Image.fromarray(s).save(f"art/props/{size[0]}.png")
        print(size[0], s.shape)
    screen = lambda path: Image.open(path).convert("RGB").resize((640, 360), Image.LANCZOS).quantize(128, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB")
    screen(f"{src}/r2_colosseum.png").save("art/story/crossing_wide.png")
    dunes = np.asarray(screen(f"{src}/r2_dunes.png"))
    Image.fromarray(np.concatenate([dunes, dunes[:, ::-1]], axis=1)).save("art/story/dunes.png")    # mirrored, so it scrolls with no seam
    m = Image.open(f"{src}/mem_hammer_user.png").convert("RGB")
    w, h = m.size
    top = (h - w * 9 // 16) // 2
    m = m.crop((0, max(top, 0), w, max(top, 0) + w * 9 // 16))
    m.resize((640, 360), Image.LANCZOS).quantize(160, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB").save("art/memories/hammer.png")
    print("round 2 art built")


if __name__ == "__main__":
    main(sys.argv[1])
