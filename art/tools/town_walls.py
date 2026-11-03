"""Danyal's wall, gate and tower (docs/refs/town_gate_example.png, redrawn on green as r2_wall.png, r2_gate.png, r2_bits.png in D:\\SmartRig\\spike\\web) -> the pieces Cinerea builds its eight-sided wall from: a seamless strip for the straight runs, slices sheared
for the 45 degree corners (0.75 px down per px across: 1 m in x is 32 px, 1 m in z is 24), the top of the wall for its north-south runs, a tower and a gatehouse.
  uv run --with pillow --with numpy --with scipy python art/tools/town_walls.py D:/SmartRig/spike/web
"""
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import label
sys.path.insert(0, "art/tools")
from props_to_sprites import sprite

OUT = "art/props"
WALL_BOX = (200, 230, 1190, 500)    # the plain middle of the run: its ends in the picture are towers
WALL_H = 140         # px on screen: about three times his height, as in the picture
TOWER_H = 224
GATE_SCALE = 0.765   # a carriage goes through it (Danyal): 1.5x what it was
ARCH_MID = 294       # px across the cut picture: the middle of its arch
TOWER_CELL = (40, 0, 280, 384)
CORNER_SLICE = 32    # a corner slice: 1 m, short so nothing stands in front of or behind the wrong one
SHEAR = 0.75


def key(rgb):
    """What isn't the background. The model's green comes out olive, close to the tan stone in distance, so it goes by hue: only the background and the shadows it drew on it are greener than they are red."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return ~((g > r + 4) & (g > b + 6))


def biggest(mask):
    """Only the largest blob: the model signs some pictures with its colour code, and leaves flecks."""
    blobs, _ = label(mask, np.ones((3, 3), bool))
    sizes = np.bincount(blobs.ravel())
    sizes[0] = 0
    return blobs == sizes.argmax()


def part(rgb, solid, box, size):
    x0, y0, x1, y1 = box
    return sprite(rgb, biggest(solid[y0:y1, x0:x1]), x0, y0, size)


def main():
    src = sys.argv[1]
    rgb = np.asarray(Image.open(f"{src}/r2_wall.png").convert("RGB")).astype(float)
    solid = key(rgb)
    x0, y0, x1, y1 = WALL_BOX
    rows = np.nonzero(solid[y0:y1, x0:x1].mean(axis=1) > 0.3)[0]
    height = rows.max() - rows.min() + 1
    width = round((x1 - x0) * WALL_H / height)
    strip = part(rgb, solid, WALL_BOX, max(width, WALL_H))[:, 3:-3]    # the outline round the cut ends would show at every join
    row = strip[6, :, 3].astype(float) / 255.0
    row -= row.mean()
    corr = np.correlate(row, row, "full")[len(row):]
    period = int(np.argmax(corr[20:120]) + 21)
    strip = strip[:, :strip.shape[1] // period * period]
    print("strip", strip.shape, "battlement every", period, "px")
    Image.fromarray(strip).save(f"{OUT}/wall_strip.png")
    for i in range(8):
        slc = strip[:, i * CORNER_SLICE:(i + 1) * CORNER_SLICE + 1]    # one column over, so no gap shows between slices
        h, w = slc.shape[0], slc.shape[1]
        drop = round((w - 1) * SHEAR)
        down = np.zeros((h + drop, w, 4), np.uint8)
        for x in range(w):
            d = round(x * SHEAR)
            down[d:d + h, x] = slc[:, x]
        Image.fromarray(down).save(f"{OUT}/wall_dr{i}.png")
        Image.fromarray(down[:, ::-1]).save(f"{OUT}/wall_dl{i}.png")
    # The north-south runs: the walkway between its battlements, and a band of the wall's face on the town's side.
    top = strip[3:strip.shape[0] // 3]
    px = top[top[..., 3] > 0][:, :3].astype(float)
    light = np.percentile(px, 75, axis=0)
    dark = np.percentile(px, 30, axis=0)
    line = np.array([20, 14, 16], float)
    walk = dark * 0.72
    H, W, BAND, FACE = 24, 56, 11, 12
    v = np.zeros((H, W + FACE, 4), np.uint8)
    v[..., 3] = 255
    v[..., :3] = walk
    for y in range(H):
        on = (y // 8) % 2 == 0
        for x in range(1, W - 1):
            if x <= BAND or x >= W - 1 - BAND:
                inner = x == BAND or x == W - 1 - BAND
                v[y, x, :3] = dark * (0.75 if inner else 1.0) if not on else light
        v[y, BAND + 1, :3] = line if on else dark * 0.55
        v[y, W - 2 - BAND, :3] = line if on else dark * 0.55
    v[:, 0, :3] = line
    v[:, W - 1, :3] = line
    face = strip[strip.shape[0] // 2:strip.shape[0] // 2 + H, :FACE, :3]
    v[:H, W:, :3] = face[:, ::-1] * 0.8
    Image.fromarray(v).save(f"{OUT}/wall_vw.png")    # the west wall: its face on the east
    Image.fromarray(v[:, ::-1]).save(f"{OUT}/wall_ve.png")
    rgb = np.asarray(Image.open(f"{src}/r2_bits.png").convert("RGB")).astype(float)
    Image.fromarray(part(rgb, key(rgb), TOWER_CELL, TOWER_H)).save(f"{OUT}/tower.png")
    rgb = np.asarray(Image.open(f"{src}/r2_gate.png").convert("RGB")).astype(float)
    solid = biggest(key(rgb))
    ys, xs = np.nonzero(solid)
    size = round(max(xs.max() - xs.min(), ys.max() - ys.min()) * GATE_SCALE)
    gate = part(rgb, solid, (0, 0, rgb.shape[1], rgb.shape[0]), size)
    # symmetric about the arch: the model's is close, and a mirrored half makes the road run through its middle
    gate = np.concatenate([gate[:, :ARCH_MID + 1], gate[:, ARCH_MID::-1]], axis=1)
    Image.fromarray(gate).save(f"{OUT}/gatehouse.png")
    print("gatehouse", gate.shape, "tower", Image.open(f"{OUT}/tower.png").size)


if __name__ == "__main__":
    main()
