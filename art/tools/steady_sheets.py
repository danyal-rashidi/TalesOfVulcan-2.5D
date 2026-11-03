"""Stops a character's sheets flickering. The video model redraws everything a little each frame, so eyes vanish and shading crawls (Danyal: "its changing too many pixels at once to the point it looks like different things"). Two passes, frame by frame:
 - A pixel that only changed shade keeps the colour it had in the frame before, followed by how the whole figure moved. What really moved differs by far more than a shade, so it still moves.
 - The head is one clean picture for each view, from the character's stand, put on wherever the head is in each frame, so the face doesn't change.
  uv run --with pillow --with numpy --with scipy python art/tools/steady_sheets.py FOLDER [FOLDER ...]    (animal:FOLDER keeps shades only: no face to lock)
Human Vulcan's sheets also have their skin brought to one tone, the stand's, since they were cut from different clips (TONED).
Keeps the sheets as they were in FOLDER/before_steady/ the first time and always starts from those, so it can be run again.
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image

SHADE = 52           # RGB distance: closer than this is the same colour, shaded differently
FOLLOW = 5           # px the whole figure may move between frames
SEARCH = 14          # px the head may be from where it is in the stand
HEAD_MATCH = 0.62    # of the head's pixels must land on the figure, with a close colour, or the head is turned, hidden, or gone
NO_HEAD = ("kneel", "look_hands", "death", "wake", "split")    # moves where the head is meant to change
HEAD_ROWS = 0.34     # of the figure, at most, from its top
TONED = ("vulcan_human",)
SKIP = ()            # sheets named this way are finished by a tool of their own (smaller_head.py sets it)
UPSIDE_DOWN = ()     # (key, frame) with no head to lock, though one fits by chance (smaller_head.py sets it)


def frames_of(sheet, n):
    w = sheet.shape[1] // n
    return [sheet[:, i * w:(i + 1) * w].copy() for i in range(n)]


def shifted(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (0, dy) if dy >= 0 else (-dy, 0)
    xs, xd = (0, dx) if dx >= 0 else (-dx, 0)
    out[yd:h - ys, xd:w - xs] = a[ys:h - yd, xs:w - xd]
    return out


def best_shift(a, b):
    """How far b has moved from a, by their outlines."""
    best, at = -1, (0, 0)
    for dy in range(-FOLLOW, FOLLOW + 1):
        for dx in range(-FOLLOW, FOLLOW + 1):
            s = int((shifted(a, dx, dy) & b).sum())
            if s > best:
                best, at = s, (dx, dy)
    return at


def keep_shades(frames):
    out = [frames[0]]
    for f in frames[1:]:
        prev = out[-1]
        dx, dy = best_shift(prev[..., 3] > 0, f[..., 3] > 0)
        moved = shifted(prev, dx, dy)
        same = (moved[..., 3] > 0) & (f[..., 3] > 0) & (np.linalg.norm(moved[..., :3].astype(float) - f[..., :3].astype(float), axis=-1) < SHADE)
        g = f.copy()
        g[same] = moved[same]
        out.append(g)
    return out


def head_of(frame):
    """(pixels, mask) of the head in a stand's frame: from the top of the figure down to where the shoulders start."""
    rows = np.nonzero(frame[..., 3].any(axis=1))[0]
    top, bottom = rows.min(), rows.max()
    last = top + int((bottom - top) * HEAD_ROWS)
    widths = [np.nonzero(frame[y, :, 3])[0] for y in range(top, last + 1)]
    spans = [(w.min(), w.max()) if len(w) else (0, 0) for w in widths]
    head_w = max(b - a + 1 for a, b in spans[:8])
    end = last
    for i, (a, b) in enumerate(spans):
        if i > 8 and b - a + 1 > head_w * 1.45:
            end = top + i - 1
            break
    x0 = min(a for a, b in spans[:8])
    x1 = max(b for a, b in spans[:8])
    mask = np.zeros(frame.shape[:2], bool)
    mask[top:end + 1, x0:x1 + 1] = frame[top:end + 1, x0:x1 + 1, 3] > 0
    return frame.copy(), mask


def fit_head(frame, head, mask, search=SEARCH):
    """How much of the head lands on the figure where it fits best, and that offset."""
    rgb = frame[..., :3].astype(float)
    best, at = -1.0, None
    total = mask.sum()
    ys, xs = np.nonzero(mask)
    colours = head[ys, xs, :3].astype(float)
    h, w = frame.shape[:2]
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            y2, x2 = ys + dy, xs + dx
            ok = (y2 >= 0) & (y2 < h) & (x2 >= 0) & (x2 < w)
            if ok.sum() < total * 0.95:
                continue
            on = frame[y2[ok], x2[ok], 3] > 0
            close = np.linalg.norm(rgb[y2[ok], x2[ok]] - colours[ok], axis=-1) < SHADE * 1.6
            score = (on & close).sum() / total
            if score > best:
                best, at = score, (dx, dy)
    return best, at


def lock_head(frame, head, mask):
    """Puts the head on where it fits best; leaves the frame alone if it fits nowhere."""
    best, at = fit_head(frame, head, mask)
    if at is None or best < HEAD_MATCH:
        return frame, False
    out = frame.copy()
    ys, xs = np.nonzero(mask)
    h, w = frame.shape[:2]
    y2, x2 = ys + at[1], xs + at[0]
    ok = (y2 >= 0) & (y2 < h) & (x2 >= 0) & (x2 < w)
    out[y2[ok], x2[ok]] = head[ys[ok], xs[ok]]
    return out, True


def skin_of(a):
    r, g, b = (a[..., i].astype(int) for i in range(3))
    return (a[..., 3] > 0) & (r > g + 25) & (g > b + 15) & (r > 110)


def to_tone(sheet, target):
    """The sheet with its skin's average at `target`, keeping its shading."""
    skin = skin_of(sheet)
    if not skin.any():
        return sheet
    out = sheet.copy()
    gain = target / sheet[skin][:, :3].mean(axis=0)
    out[skin, :3] = np.clip(sheet[skin][:, :3] * gain, 0, 255).astype(np.uint8)
    return out


def view_of(key):
    return key.rsplit("_", 1)[-1] if key.rsplit("_", 1)[-1] in ("F", "S", "B", "L") else "F"


def run(folder, with_heads=True):
    base = f"art/{folder}"
    back = f"{base}/before_steady"
    manifest = json.load(open(f"{base}/manifest.json"))
    anims = manifest["anims"]
    os.makedirs(back, exist_ok=True)
    for a in anims.values():
        if not a["file"].startswith(SKIP) and not os.path.exists(f"{back}/{a['file']}"):
            shutil.copy(f"{base}/{a['file']}", f"{back}/{a['file']}")
    target = None
    if folder in TONED:
        stand = np.array(Image.open(f"{back}/{anims['idle_F']['file']}").convert("RGBA"))
        target = stand[skin_of(stand)][:, :3].mean(axis=0)
    heads = {}
    for view in ("F", "S", "B") if with_heads else ():
        for key in (f"idle_{view}", f"idle_spear_{view}", f"walk_{view}", f"run_{view}", "idle_F"):
            if key in anims and (view != "F" or True):
                sheet = np.array(Image.open(f"{back}/{anims[key]['file']}").convert("RGBA"))
                if target is not None:
                    sheet = to_tone(sheet, target)
                heads[view] = head_of(frames_of(sheet, int(anims[key].get("frames", 1)))[int(anims[key].get("start", 0))])
                if not key.endswith(view):
                    heads.pop(view)    # no sheet of this view: don't put another view's face on it
                else:
                    break
    if "S" in heads:
        heads["L"] = (heads["S"][0][:, ::-1], heads["S"][1][:, ::-1])
    moved = [0, 0]
    locked = [0, 0]
    for key, a in anims.items():
        if a["file"].startswith(SKIP):
            continue
        n = int(a.get("frames", 1))
        sheet = np.array(Image.open(f"{back}/{a['file']}").convert("RGBA"))
        if target is not None:
            sheet = to_tone(sheet, target)
        frames = frames_of(sheet, sheet.shape[1] // max(int(manifest["cell"][0]), 1))
        before = sum(int((frames[i] != frames[i + 1]).any(axis=-1).sum()) for i in range(len(frames) - 1))
        if with_heads and not any(k in key for k in NO_HEAD):
            # the view's head from its stand; if this sheet is drawn too differently for that to fit, its own first frame's, so at least its face doesn't change as it plays
            ref = heads.get(view_of(key))
            tried = [lock_head(f, *ref) for f in frames] if ref else []
            if sum(ok for _, ok in tried) * 2 < len(frames):
                own = head_of(frames[0])
                tried = [lock_head(f, *own) for f in frames]
            tried = [(f, False) if (key, i) in UPSIDE_DOWN else t for i, (f, t) in enumerate(zip(frames, tried))]
            frames = [f for f, _ in tried]
            locked[0] += sum(ok for _, ok in tried)
            locked[1] += sum(not ok for _, ok in tried)
        frames = keep_shades(frames)
        after = sum(int((frames[i] != frames[i + 1]).any(axis=-1).sum()) for i in range(len(frames) - 1))
        moved[0] += before
        moved[1] += after
        Image.fromarray(np.concatenate(frames, axis=1)).save(f"{base}/{a['file']}")
    print(f"{folder}: pixels changing between frames {moved[0]} -> {moved[1]} ({100 - 100 * moved[1] // max(moved[0], 1)}% fewer); head locked on {locked[0]} frames, left alone on {locked[1]}")


if __name__ == "__main__":
    for f in sys.argv[1:]:
        run(f.split(":")[-1], not f.startswith("animal:"))
