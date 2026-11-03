"""Draws his left-facing spear sheets (`*_L`). The side sheets are turned a little to the camera with the spear in his right hand, the
back one; mirrored, it would change hands. Facing left his right hand is the front one, so:
- moves with an empty-handed sheet to borrow from (EMPTY): that sheet mirrored, its back hand free, the spear behind him through its front fist;
- the rest, where he has both hands on it or the front hand is busy: each frame mirrored, the spear rubbed out where it crosses him.
Run it after sheets_for_game.py, which rewrites the manifest.
  uv run --with pillow --with numpy python art/tools/far_hand_sheets.py art/elvis_blue
"""
import json, sys
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view
from PIL import Image

KEYS = ["idle_spear", "run_spear", "roll_spear", "hurt_spear", "drink_spear", "drink_walk_spear", "death_spear",
        "light1", "light2", "light3", "light4", "lunge", "thrust", "charge", "equip", "unequip"]
EMPTY = {"idle_spear": "idle", "run_spear": "run", "hurt_spear": "hurt", "equip": "idle", "unequip": "idle"}
CLEAN = {"run_spear": "idle_spear", "hurt_spear": "idle_spear"}    # their own spear overlaps him too much to lift out: they carry the stand's
ICE = [0xd7fcfc, 0xa1f4f7, 0x71dee8]    # only the spear and a few highlights on him are this bright
SHAFT = ICE + [0x5eb2d2]                # the shaft's shaded side; so is his skin, so this only counts right by the line
DARK = [0x0e1628, 0x020307]             # the outline round the shaft
OUTLINE = (0x0e, 0x16, 0x28, 255)
GAP = 20       # px of a shaft his hand, arm or body may hide
MIN_LEN = 16   # px: anything shorter is a highlight, not the spear (the first equip frames, a roll's ball)
NEAR = 2.2     # px from the line that may be the shaft
WIDE = 4       # px from the line, at most, while the colour is still ice: the spear's head
HOLD = 26      # px from the tip to his fist: about the middle of the shaft, so it shows ahead of him and a little behind


def is_colour(rgb, colours):
    return np.isin(rgb[..., 0].astype(int) * 65536 + rgb[..., 1].astype(int) * 256 + rgb[..., 2], colours)


# Without strands under 3 px wide, which is all that's left of the spear's outline.
def opened(m):
    core = np.pad(sliding_window_view(m, (3, 3)).all((2, 3)), 1)
    return np.pad(sliding_window_view(core, (3, 3)).any((2, 3)), 1)


# The spear as (a, b, x0, x1): y = a x + b from x0 to x1, or with x and y swapped when `steep`. The straight line through the most ice.
def find_spear(ice):
    ys, xs = np.nonzero(ice)
    best, best_score = None, MIN_LEN - 1
    for steep, (u, v) in ((False, (xs, ys)), (True, (ys, xs))):
        for a in np.tan(np.radians(np.arange(-45, 45.5, 1.5))):
            rest = np.round(v - a * u).astype(int)
            for b in np.unique(rest):
                on = np.unique(u[np.abs(rest - b) <= 1])
                for run in np.split(on, np.nonzero(np.diff(on) > GAP)[0] + 1):
                    if len(run) > best_score:
                        best, best_score = (steep, float(a), float(b), int(run[0]), int(run[-1])), len(run)
    return best


# The frame's spear: (steep, a, b, columns, frame, solid), with columns {x: (first row, last row)}. A steep one swaps rows and columns,
# so the work always crosses it the short way, and `frame` and `solid` come back swapped too. None when there's no spear in it.
def trace(frame):
    solid = frame[..., 3] > 0
    ice = is_colour(frame[..., :3], ICE) & solid
    found = find_spear(ice) if ice.any() else None
    if found is None:
        return None
    steep, a, b, u0, u1 = found
    shaft, dark = is_colour(frame[..., :3], SHAFT) & solid, is_colour(frame[..., :3], DARK) & solid
    if steep:
        frame, ice, solid, shaft, dark = frame.transpose(1, 0, 2), ice.T, solid.T, shaft.T, dark.T
    rows, columns = solid.shape[0], {}
    for x in range(u0, u1 + 1):
        mid = a * x + b
        on = [y for y in range(rows) if abs(y - mid) <= NEAR and shaft[y, x]]
        if not on:    # his hand over it
            continue
        lo, hi = on[0], on[-1]
        while lo > 0 and mid - lo < WIDE and ice[lo - 1, x]:
            lo -= 1
        while hi < rows - 1 and hi - mid < WIDE and ice[hi + 1, x]:
            hi += 1
        lo -= int(lo > 0 and dark[lo - 1, x])
        hi += int(hi < rows - 1 and dark[hi + 1, x])
        if lo > 0 and hi < rows - 1:
            columns[x] = lo, hi
    return steep, a, b, columns, frame, solid


# Rubs the spear out where it has him on both sides, stretching what lies either side of it over the gap.
def behind(frame):
    found = trace(frame)
    if found is None:
        return frame
    steep, _, _, columns, frame, solid = found
    spear, out = np.zeros_like(solid), frame.copy()
    for x, (lo, hi) in columns.items():
        spear[lo:hi + 1, x] = True
    body = opened(solid & ~spear)
    for x, (lo, hi) in columns.items():
        if body[lo - 1, x] and body[hi + 1, x]:
            half = (lo + hi + 1) // 2
            out[lo:half, x] = out[lo - 1, x].copy()
            out[half:hi + 1, x] = out[hi + 1, x].copy()
    return out.transpose(1, 0, 2) if steep else out


# The spear alone, whole. Off his body a column is the whole short run of pixels there, outline and all; where his hand or body hid it,
# it is the nearest clear column moved along the line.
def spear_only(frame):
    found = trace(frame)
    if found is None or not found[3]:
        return None
    steep, a, b, columns, frame, solid = found
    rows, clear = solid.shape[0], {}
    for x in range(min(columns) - 2, max(columns) + 3):
        lo, hi = columns.get(x, (0, 0))
        y = (lo + hi) // 2 if x in columns else int(round(a * x + b))
        if not (0 <= x < solid.shape[1] and 0 <= y < rows and solid[y, x]):
            continue
        lo = hi = y
        while lo > 0 and solid[lo - 1, x]:
            lo -= 1
        while hi < rows - 1 and solid[hi + 1, x]:
            hi += 1
        if hi - lo <= 2 * WIDE:
            clear[x] = lo, hi
    if not clear or max(clear) - min(clear) < 2 * MIN_LEN:    # still forming, in a draw
        return None
    out = np.zeros_like(frame)
    for x in range(min(clear), max(clear) + 1):
        near = min(clear, key=lambda c: abs(c - x))
        lo, hi = clear[near]
        move = round(a * (x - near))
        if 0 <= lo + move and hi + move < rows:
            out[lo + move:hi + move + 1, x] = frame[lo:hi + 1, near]
    return out.transpose(1, 0, 2) if steep else out


# Where his front fist is, facing left: the part of him furthest forward at the waist.
def front_fist(solid):
    ys = np.nonzero(solid.any(1))[0]
    y0, y1 = ys[0] + int(0.3 * (ys[-1] - ys[0])), ys[0] + int(0.65 * (ys[-1] - ys[0]))
    x = np.nonzero(solid[y0:y1].any(0))[0][0]
    return x + 2, y0 + np.nonzero(solid[y0:y1, x:x + 4].any(1))[0].mean()


# `body` (mirrored, empty-handed) in front of `spear` (mirrored), moved so that his fist grips it HOLD px back from the tip.
def in_front_fist(body, spear):
    solid = body[..., 3] > 0
    if spear is None:
        return body
    fist_x, fist_y = front_fist(solid)
    tip = np.nonzero((spear[..., 3] > 0).any(0))[0][0]
    out = np.roll(spear, fist_x - HOLD - tip, axis=1)
    xs = np.nonzero((out[..., 3] > 0).any(0))[0]
    x = xs[np.abs(xs - fist_x).argmin()]
    out = np.roll(out, round(fist_y - np.nonzero(out[:, x, 3] > 0)[0].mean()), axis=0)
    out[solid] = body[solid]
    return out


def main():
    folder = sys.argv[1]
    with open(f"{folder}/manifest.json") as f:
        manifest = json.load(f)
    w = manifest["cell"][0]
    def frames(key):
        anim = manifest["anims"][f"{key}_S"]
        sheet = np.array(Image.open(f"{folder}/{anim['file']}").convert("RGBA"))
        return anim, [sheet[:, i * w:(i + 1) * w] for i in range(anim["frames"])]
    for key in sys.argv[2:] or KEYS:    # named: only those, so a new sheet leaves the rest as steady_sheets.py keeps them
        anim, spear = frames(CLEAN.get(key, key))
        if key in EMPTY:
            anim, body = frames(EMPTY[key])
            whole = [spear_only(f) for f in spear]
            done = [in_front_fist(b[:, ::-1], s if s is None else s[:, ::-1])
                    for b, s in ((b, whole[i * len(spear) // len(body)]) for i, b in enumerate(body))]
            anim = manifest["anims"][f"{key}_S"] if key in ("equip", "unequip") else anim    # a draw keeps its own speed
        else:
            done = [behind(f)[:, ::-1] for f in spear]
        name = f"{key}_L.png"
        Image.fromarray(np.hstack(done)).save(f"{folder}/{name}")
        manifest["anims"][f"{key}_L"] = {**anim, "file": name}
    with open(f"{folder}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=1)


if __name__ == "__main__":
    main()
