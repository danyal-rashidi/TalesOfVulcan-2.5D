"""His stands: one clean picture per view with only his breath moving, armed and empty-handed, each the very first frame of that view's walk clip, so he stands in the same body and at the same size he walks and runs in (Danyal). Everything above the belt goes 1 px lower on the out-breath.
His eyes are redrawn two pixels wide so they read, and the side stands get the gold buckle if the cut lost it.
  uv run --with pillow --with numpy python art/tools/armed_idle.py
Then run art/tools/steady_sheets.py and new_sword_sheets.py. Its sources are strips/still_*.png, cut with anim_into_sheets.py ... 1 2.5 whole.
"""
import json
import numpy as np
from PIL import Image

FOLDER = "art/vulcan_human"
BREATH = {"file": "", "frames": 2, "fps": 2.5, "loop": True, "holds": {"0": 0.3, "1": 0.2}}
WHITE = (236, 228, 208)
PUPIL = (26, 20, 22)
GOLD = (236, 190, 84)
GOLD_DARK = (176, 124, 48)


def breathe(a):
    """Frame 1 of a still in its cell: every row above the belt 1 px lower, dropping the row most like the one above it."""
    rows = np.nonzero(a[..., 3].any(axis=1))[0]
    top, h = rows.min(), rows.max() + 1 - rows.min()
    cut = min(range(top + int(0.55 * h), top + int(0.7 * h) + 1), key=lambda y: np.abs(a[y].astype(int) - a[y - 1].astype(int)).sum())
    b = a.copy()
    b[top + 1:cut + 1] = a[top:cut]
    b[top] = 0
    return b


def is_gold(a):
    r, g, b = (a[..., i].astype(int) for i in range(3))
    return (a[..., 3] > 0) & (r > 170) & (g > 120) & (b < 110) & (r - b > 90)


def face_row(a):
    """The row of his eyes: most of the way down the skin of his face, under his hair."""
    rows = np.nonzero(a[..., 3].any(axis=1))[0]
    return rows.min()


def front_face(a):
    """His eyes on the row under his brows, where the clips draw them, once the clip's own marks there are cleared."""
    a = a.copy()
    top = face_row(a)
    head = np.nonzero(a[top + 3:top + 9, :, 3].any(axis=0))[0]
    mid = (head.min() + head.max()) // 2
    y = top + 12
    a[y, mid - 4:mid + 5, :3] = a[y + 1, mid - 4:mid + 5, :3]
    for x, c in ((mid - 3, WHITE), (mid - 2, PUPIL), (mid + 2, PUPIL), (mid + 3, WHITE)):
        a[y, x, :3] = c
    return a


def side_face(a):
    """He faces right. His eye, and the buckle at the front of his belt unless it's there."""
    a = a.copy()
    top = face_row(a)
    right = np.nonzero(a[top + 6:top + 11, :, 3].any(axis=0))[0].max()
    y = top + 10
    a[y, right - 7:right - 1, :3] = a[y + 1, right - 7:right - 1, :3]    # clears the clip's own marks
    a[y, right - 6, :3] = WHITE
    a[y, right - 5, :3] = PUPIL
    if not is_gold(a[top + 18:top + 32]).any():
        chest = top + 20
        for y in range(chest, chest + 14):
            if a[y, right - 8:right - 2, :3].astype(int).sum(axis=-1).mean() < 200:
                a[y, right - 7:right - 3, :3] = GOLD
                a[y + 1, right - 7:right - 3, :3] = GOLD_DARK
                a[y:y + 2, right - 7:right - 3, 3] = 255
                break
    return a


def main():
    manifest = json.load(open(f"{FOLDER}/manifest.json"))
    jobs = {"idle_F": front_face, "idle_spear_F": front_face, "idle_S": side_face, "idle_spear_S": side_face, "idle_B": None, "idle_spear_B": None, "idle_spear_L": lambda a: side_face(a[:, ::-1])[:, ::-1]}
    for key, face in jobs.items():
        still = np.array(Image.open(f"{FOLDER}/strips/still_{key}.png").convert("RGBA"))
        if face:
            still = face(still)
        Image.fromarray(np.concatenate([still, breathe(still)], axis=1)).save(f"{FOLDER}/{key}.png")
        manifest["anims"][key] = dict(BREATH, file=f"{key}.png")
    json.dump(manifest, open(f"{FOLDER}/manifest.json", "w"), indent=1)
    print("stands built")


if __name__ == "__main__":
    main()
