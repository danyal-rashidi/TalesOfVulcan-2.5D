"""The fountain's clip -> a sheet where only the water moves (Danyal: "just the water"). The video model redraws the stone a little every frame, which flickers, so the
stone is one still picture, each pixel its most common colour, and only what is water in a frame comes from that frame. First cut the clip, in the Smartrig repo's folder:
  uv run --with imageio-ffmpeg python /mnt/d/SmartRig/spike/elvis/ad/video_to_sprites.py CLIP MASTER /tmp/fountain --height 140 --whole 32 --colours 32
then, in the game's folder:
  uv run --with pillow --with numpy python art/tools/fountain_water.py /tmp/fountain_strip.png 32 art/props/fountain_anim.png
"""
import sys
import numpy as np
from PIL import Image

WATER_FROM = 0.5     # water in at least this share of the frames: water always, it never shows stone
STONE_UNDER = 0.15   # water in fewer than this: a stray pixel, the stone stays


def is_water(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    teal = (g > r + 12) & (b > r + 12) & (rgb.mean(axis=-1) > 60)
    foam = (rgb.min(axis=-1) > 165) & (b >= r - 8)
    return teal | foam


def most_common(colours):
    """The most common colour of (n, 3) values."""
    u, c = np.unique(colours, axis=0, return_counts=True)
    return u[c.argmax()]


def water_only(frames):
    """(n, h, w, 4) -> the same frames with one still stone under the water."""
    n, h, w = frames.shape[:3]
    wet = is_water(frames[..., :3].astype(int)) & (frames[..., 3] > 0)
    share = wet.mean(axis=0)
    stone = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            solid = frames[:, y, x, 3] > 0
            if solid.mean() < 0.5:
                continue
            dry = solid & ~wet[:, y, x]
            stone[y, x, :3] = most_common(frames[:, y, x, :3][dry if dry.any() else solid])
            stone[y, x, 3] = 255
    out = np.repeat(stone[None], n, axis=0)
    for k in range(n):
        show = wet[k] & (share >= STONE_UNDER) & (stone[..., 3] > 0)
        out[k][show] = frames[k][show]
    # always-water that a frame drew as something else keeps the water it had the frame before
    always = (share >= WATER_FROM) & (stone[..., 3] > 0)
    for _ in range(2):
        for k in range(n):
            gap = always & ~wet[k]
            out[k][gap] = out[k - 1][gap]
            wet[k] |= gap & is_water(out[k][..., :3].astype(int))
    return out, stone, always


def main():
    strip, n, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    s = np.asarray(Image.open(strip).convert("RGBA"))
    fw = s.shape[1] // n
    frames = np.stack([s[:, i * fw:(i + 1) * fw] for i in range(n)])
    done, stone, _ = water_only(frames)
    moved = [(done[k] != done[(k + 1) % n]).any(axis=-1) for k in range(n)]
    still_stone = ~is_water(np.where(np.any(moved, axis=0)[..., None], done.reshape(n, *done.shape[1:]).max(axis=0)[..., :3], 0).astype(int)) & np.any(moved, axis=0)
    print("frames", n, "cell", fw, s.shape[0], "pixels that ever change", int(np.any(moved, axis=0).sum()), "of", int((stone[..., 3] > 0).sum()), "not water-coloured at their lightest", int(still_stone.sum()))
    Image.fromarray(np.concatenate(list(done), axis=1)).save(out)


if __name__ == "__main__":
    main()
