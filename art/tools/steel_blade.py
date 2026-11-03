"""Human Vulcan's idle sword -> steel. The armed idle clips kept their start picture's warm blade, and the palette turned it rust-brown, while the walk's sword is steel.
The blade barely moves in an idle, so its line is measured by hand for each view; the bit of steel left at the tip says where it is in each frame.
  uv run --with pillow --with numpy python art/tools/steel_blade.py
Run it again after anim_into_sheets.py remakes one of these sheets.
"""
import json
import numpy as np
from PIL import Image

FOLDER = "art/vulcan_human"
# where the tip is about in the cell (x, y), which way the blade points, its length up to the guard, in px
BLADES = {
    "idle_spear_F": ((20, 54), (-13, 9), 12.0),
    "idle_spear_S": ((55, 51), (11, 6), 10.5),
    "idle_spear_B": ((78, 50), (13, 7), 12.0),
}
TIP_WITHIN = 5       # px from the usual place
HALF_WIDE = 2.3      # px either side of the blade's line
STEELS = np.array([(205, 210, 222), (150, 156, 168), (100, 106, 118)])    # glint, lit side, shade: the last two are the walk's
LIT_FROM = 125       # lighter than this is the blade's lit side
GLINT_FROM = 190     # the glint at the tip stays
DARK_BELOW = 55      # the outline, the guard and his trousers


def recolour(frame, tip_at, way, length):
    """Sets the blade in this frame to steel and gives how many pixels it set."""
    way = np.array(way, float) / np.linalg.norm(way)
    rgb = frame[..., :3].astype(int)
    light = rgb.mean(axis=-1)
    ys, xs = np.nonzero((frame[..., 3] > 0) & (rgb[:, :, None] == STEELS[None, None]).all(axis=-1).any(axis=-1))
    near = np.hypot(xs - tip_at[0], ys - tip_at[1]) <= TIP_WITHIN
    assert near.any(), "no steel near the tip"
    pts = np.stack([xs[near], ys[near]], axis=-1).astype(float)
    tip = pts[np.argmax(pts @ way)]
    gx, gy = np.meshgrid(np.arange(frame.shape[1]), np.arange(frame.shape[0]))
    rel = np.stack([gx, gy], axis=-1) - tip
    back = -(rel @ way)
    across = np.abs(rel[..., 0] * -way[1] + rel[..., 1] * way[0])
    blade = (frame[..., 3] > 0) & (back >= -1.5) & (back <= length) & (across <= HALF_WIDE) & (light >= DARK_BELOW)
    frame[..., :3][blade] = np.where((light[blade] >= GLINT_FROM)[:, None], STEELS[0], np.where((light[blade] >= LIT_FROM)[:, None], STEELS[1], STEELS[2]))
    return int(blade.sum())


def main():
    cw = json.load(open(f"{FOLDER}/manifest.json"))["cell"][0]
    for key, (tip_at, way, length) in BLADES.items():
        sheet = np.asarray(Image.open(f"{FOLDER}/{key}.png").convert("RGBA")).copy()
        sizes = [recolour(sheet[:, i * cw:(i + 1) * cw], tip_at, way, length) for i in range(sheet.shape[1] // cw)]
        assert min(sizes) >= 12 and max(sizes) <= 70, f"{key}: {sizes}"
        Image.fromarray(sheet).save(f"{FOLDER}/{key}.png")
        print(key, sizes)


if __name__ == "__main__":
    main()
