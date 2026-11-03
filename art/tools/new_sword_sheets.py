"""The new iron sword on him: art/vulcan_new_sword/ is art/vulcan_human/ with every blade a pixel wider all round and brighter, so the sword from Cassia's shop shows. No clips or credits.
The blade is the only sizeable cool grey he has (his unarmed sheets have specks of 1 to 6 px), in every frame, so colour alone finds it.
  uv run --with pillow --with numpy --with scipy python art/tools/new_sword_sheets.py
Run it again after any of his sword sheets change.
"""
import json, os, shutil
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, distance_transform_edt, label

FROM = "art/vulcan_human"
TO = "art/vulcan_new_sword"
ARMED = ("_spear_", "light", "lunge", "thrust", "charge", "hammer")    # the sheets with the sword in them
BRIGHTER = 36        # added to the blade's colours
SPECK = 8            # px: a cool blob smaller than this isn't the blade
DARK = 90            # r + g + b under this is an outline or his dark trousers: a wider blade may cover it, but never his skin
OUTLINE = (20, 14, 16, 255)
GROW = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)    # no corners: the tip stays a point
ROUND = np.ones((3, 3), bool)


def is_blade(a):
    r, g, b = (a[..., i].astype(int) for i in range(3))
    cool = (a[..., 3] > 0) & (b >= r - 2) & (b >= g - 2) & (r + g + b > 170) & (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b) < 46)
    blobs, _ = label(cool, np.ones((3, 3), bool))
    sizes = np.bincount(blobs.ravel())
    sizes[0] = 0
    return sizes[blobs] >= SPECK


def tip_of(a, blade):
    """How far each pixel of a swing's blade is from its tip's end, and from its middle line: the end further from his body."""
    gy, gx = np.mgrid[:a.shape[0], :a.shape[1]]
    keep = blade
    for _ in range(3):    # each pass keeps what's in line with the last: his cool specks aren't the blade
        pts = np.stack([gx[keep], gy[keep]], axis=-1).astype(float)
        mid = pts.mean(axis=0)
        way = np.linalg.svd(pts - mid, full_matrices=False)[2][0]
        along, across = (gx - mid[0]) * way[0] + (gy - mid[1]) * way[1], np.abs(-(gx - mid[0]) * way[1] + (gy - mid[1]) * way[0])
        keep = blade & (across <= 4)
    body = np.mean(np.nonzero((a[..., 3] > 0) & ~blade)[::-1], axis=1)
    if (body - mid) @ way > 0:
        along = -along
    return along[keep].max() - along, across


def widen(a, point=False):
    """One picture or frame, with its blade wider and brighter, in a new dark outline. A frame with no blade comes back the same. point: a swing's blade ends in a point, not the round end widening leaves."""
    a = a.copy()
    blade = is_blade(a)
    if not blade.any():
        return a
    free = (a[..., 3] == 0) | (a[..., :3].astype(int).sum(axis=-1) < DARK)
    grown = blade | (binary_dilation(blade, GROW) & free)
    if point:
        to_tip, across = tip_of(a, blade)
        off = grown & (across > 0.9 * to_tip + 0.5)
        a[off & (a[..., 3] > 0), 3] = 0
        grown &= ~off
    nearest = distance_transform_edt(~blade, return_distances=False, return_indices=True)    # a new pixel is the colour of the blade beside it
    colours = np.minimum(a[nearest[0], nearest[1], :3].astype(int) + BRIGHTER, 255).astype(np.uint8)
    edge = binary_dilation(grown, ROUND) & ~grown & (a[..., 3] == 0)
    a[grown, :3] = colours[grown]
    a[grown, 3] = 255
    a[edge] = OUTLINE
    return a


def sheet(path, w, point=False):
    img = np.asarray(Image.open(path).convert("RGBA"))
    return np.concatenate([widen(img[:, i * w:(i + 1) * w], point) for i in range(img.shape[1] // w)], axis=1)


def main():
    os.makedirs(TO, exist_ok=True)
    manifest = json.load(open(f"{FROM}/manifest.json"))
    anims = manifest["anims"]
    shutil.copy(f"{FROM}/manifest.json", f"{TO}/manifest.json")
    armed = 0
    for key, anim in anims.items():
        if any(k in key for k in ARMED):
            Image.fromarray(sheet(f"{FROM}/{anim['file']}", anim.get("w", manifest["cell"][0]), "w" in anim)).save(f"{TO}/{anim['file']}")
            armed += 1
        else:
            shutil.copy(f"{FROM}/{anim['file']}", f"{TO}/{anim['file']}")
            assert not is_blade(np.asarray(Image.open(f"{FROM}/{anim['file']}").convert("RGBA"))).any(), f"{key} isn't a sword sheet, yet has blade colours"
    print(f"{armed} sword sheets widened, {len(anims) - armed} copied")


if __name__ == "__main__":
    main()
