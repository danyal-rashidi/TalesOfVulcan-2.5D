"""The road into Cinerea, the same cobbles as the town's streets (art/tools/town_floor.py) and Danyal's picture of the gate: art/floors/road.png repeats down its length, and its edges are made of whole stones with the sand showing past them. Run from the game's folder:
  uv run --with pillow --with numpy --with scipy python art/tools/road_tile.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ni
from scipy.spatial import cKDTree

WIDTH = 5.0        # m: as the town's main street
MARGIN = 1.0       # m of room each side for stones that stray past the edge
LENGTH = 12.0      # m in one repeat: Cinerea.ROAD_TILE
W, H = int((WIDTH + MARGIN * 2) * 32), int(LENGTH * 24)
# Quiet on purpose: the cobbles were the loudest thing on the screen. Keep five tones, so the stones keep the same random draws. Claude's call, these values.
TONES = np.array([[149, 141, 126], [146, 138, 123], [142, 134, 120], [152, 144, 129], [139, 131, 117]], float)
GAP = (122, 115, 102)


def main():
    rng = np.random.default_rng(7)
    gx, gy = np.meshgrid(np.arange(0, W + 10, 10.0), np.arange(0, H, 8.0))
    seeds = np.stack([gx.ravel() + rng.uniform(-3.5, 3.5, gx.size), gy.ravel() + rng.uniform(-3, 3, gx.size)], 1)
    n = len(seeds)
    # the stones repeat: every seed is there once above and once below, so the tile's top and bottom meet stone for stone
    wrapped = np.concatenate([seeds, seeds + [0, H], seeds - [0, H]])
    yy, xx = np.mgrid[:H, :W]
    dist, who = cKDTree(wrapped).query(np.stack([xx.ravel(), yy.ravel()], 1), k=2, workers=-1)
    near, second = dist[:, 0].reshape(H, W), dist[:, 1].reshape(H, W)
    who = (who[:, 0] % n).reshape(H, W)
    # a stone is in or out whole, so the edge is made of stones; the edge wanders, as a worn road's does, and repeats too
    wander = ni.gaussian_filter1d(rng.normal(size=H), 14, mode="wrap")
    wander = wander / np.abs(wander).max() * 0.5 * 32
    half = (WIDTH / 2.0) * 32
    sy = np.mod(seeds[:, 1].astype(int), H)
    off = np.abs(seeds[:, 0] - W / 2.0) - (half + wander[sy])
    keep = off < rng.uniform(-16, 16, n)
    tone = TONES[rng.integers(0, len(TONES), n)]
    paved = keep[who]
    colour = tone[who]
    out = np.zeros((H, W, 4), np.uint8)
    lit = (near < 3.2) & (yy % 2 == 0) & (xx % 3 == 0)
    out[paved, :3] = colour[paved].astype(np.uint8)
    out[paved & lit, :3] = (colour[paved & lit] * 1.02).clip(0, 255).astype(np.uint8)
    out[paved & (second - near < 1.6), :3] = GAP
    out[paved, 3] = 255
    Image.fromarray(out).save("art/floors/road.png", optimize=True)
    print("road tile", W, H, f"{paved.mean():.2f} paved")


if __name__ == "__main__":
    main()
