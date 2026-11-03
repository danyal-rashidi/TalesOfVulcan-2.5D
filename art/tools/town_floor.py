"""Cinerea's floor over its sand, its plan after docs/refs/town_example.png: grey cobbled streets and the plaza, packed earth, dunes outside the walls. Transparent where the sand shows.
Stones are whole: a stone is in the street or out of it, so the street's edge is made of stones. Also writes OUT_streets.png, where the stones are: the tests keep things off them.
  uv run --with pillow --with numpy --with scipy python art/tools/town_floor.py OUT.png
"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ni
from scipy.spatial import cKDTree

X0, X1, Z0, Z1 = -70.0, 70.0, 14.0, 108.0    # the metres it covers
W, H = int((X1 - X0) * 32), int((Z1 - Z0) * 24)
STREET = 5.0    # m, the main street
LANE = 4.0


def metres(x, z):
    return ((x - X0) * 32, (z - Z0) * 24)


at = metres
PLAZA = [(-15, 53), (15, 53), (17, 58), (17, 68), (15, 73), (-15, 73), (-17, 68), (-17, 58)]
MAIN = [(0, 22), (0, 100)]
LANES = [[(-42, 38), (42, 38)], [(-42, 38), (-42, 62)], [(-16, 62), (-58, 62)], [(16, 70), (58, 70)], [(36, 38), (36, 84)], [(0, 84), (36, 84)], [(0, 79), (-50, 79)]]
OCTAGON = [(-42, 22), (42, 22), (62, 42), (62, 80), (42, 100), (-42, 100), (-62, 80), (-62, 42)]    # metres, the wall's line


def main():
    rng = np.random.default_rng(11)
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    d.polygon([at(*p) for p in PLAZA], fill=255)
    d.line([at(*p) for p in MAIN], fill=255, width=int(STREET * 32))
    for lane in LANES:
        pts = [at(*p) for p in lane]
        d.line(pts, fill=255, width=int(LANE * 32), joint="curve")
    street = np.asarray(img) > 0
    # cobbles: a jittered grid of seeds, each pixel belongs to its nearest
    gx, gy = np.meshgrid(np.arange(0, W + 10, 10.0), np.arange(0, H + 8, 8.0))
    seeds = np.stack([gx.ravel() + rng.uniform(-3.5, 3.5, gx.size), gy.ravel() + rng.uniform(-3, 3, gx.size)], 1)
    yy, xx = np.mgrid[:H, :W]
    dist, who = cKDTree(seeds).query(np.stack([xx.ravel(), yy.ravel()], 1), k=2, workers=-1)
    near, second = dist[:, 0].reshape(H, W), dist[:, 1].reshape(H, W)
    who = who[:, 0].reshape(H, W)
    # a stone is in if its seed is: edges of whole stones, a few strays lost or scattered
    sx = np.clip(seeds[:, 0].astype(int), 0, W - 1)
    sy = np.clip(seeds[:, 1].astype(int), 0, H - 1)
    fuzzy = ni.gaussian_filter(street.astype(float), 9)
    keep = fuzzy[sy, sx] > rng.uniform(0.32, 0.68, len(seeds))
    # Quiet on purpose, as art/tools/road_tile.py's: keep five tones, so the stones keep the same random draws. They must stay grey too: Cinerea._on_stone knows stone by it.
    tones = np.array([[149, 141, 126], [146, 138, 123], [142, 134, 120], [152, 144, 129], [139, 131, 117]], float)
    tone = tones[rng.integers(0, len(tones), len(seeds))]
    out = np.zeros((H, W, 4), np.uint8)
    paved = keep[who]
    colour = tone[who]
    gap = second - near < 1.6                               # the dark line between stones
    lit = (near < 3.2) & (yy % 2 == 0) & (xx % 3 == 0)      # a touch of light on each
    out[paved, :3] = colour[paved].astype(np.uint8)
    out[paved & lit, :3] = (colour[paved & lit] * 1.02).clip(0, 255).astype(np.uint8)
    out[paved & gap, :3] = (122, 115, 102)
    out[paved, 3] = 255
    # packed earth along the streets, under the stones. Random patches of it read as stains on quiet sand
    rng.random((H // 4, W // 4)), rng.random((H, W))    # what those patches and their speckle once drew: still drawn so the dunes below don't move
    inside = Image.new("L", (W, H), 0)
    ImageDraw.Draw(inside).polygon([metres(*p) for p in OCTAGON], fill=255)
    inside = np.asarray(inside) > 0
    near_street = ni.gaussian_filter(street.astype(float), 26) > 0.05
    earth = inside & ~paved & near_street
    out[earth, :3] = (180, 160, 96)
    out[earth, 3] = 255
    # dunes outside the walls: a crescent of shadow under a crest of light
    dunes = Image.new("L", (W, H), 0)
    dd = ImageDraw.Draw(dunes)
    for _ in range(90):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        a, b = rng.uniform(70, 170), rng.uniform(16, 34)
        dd.ellipse((cx - a, cy - b, cx + a, cy + b), fill=1)
        dd.ellipse((cx - a * 1.2, cy - b * 1.7, cx + a * 1.2, cy + b * 0.55), fill=0)    # leaves a thin crescent of shadow
    dune = np.asarray(dunes)
    keep_out = Image.new("L", (W, H), 0)
    kd = ImageDraw.Draw(keep_out)
    kd.polygon([metres(*p) for p in OCTAGON], fill=255)
    kd.rectangle([*metres(-15, Z0), *metres(15, 24)], fill=255)    # his way down the road stays clean
    outside = ni.binary_dilation(np.asarray(keep_out) > 0, iterations=40) == False
    out[(dune == 1) & outside, :3] = (168, 148, 88)
    out[(dune == 1) & outside, 3] = 255
    Image.fromarray(out).save(sys.argv[1], optimize=True)
    Image.fromarray((paved * 255).astype(np.uint8)).resize((W // 8, H // 6), Image.BOX).save(sys.argv[1].replace(".png", "_streets.png"), optimize=True)    # 4 texels a metre
    print(sys.argv[1], W, H, f"{paved.mean():.2f} paved")


if __name__ == "__main__":
    main()
