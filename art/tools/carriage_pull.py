"""Fortuna pulling Cassia's carriage: clips/carriage_pull_F.mp4 (straight at the camera) and carriage_pull_S.mp4 (to the lower right) -> art/carriage_pull/, a folder CharacterSprite plays. Run from the game's folder:
  uv run --with pillow --with numpy --with scipy --with imageio-ffmpeg python art/tools/carriage_pull.py D:/SmartRig/spike/web
Each clip is cut down to one clean loop, its windows filled so the ground doesn't show through them, and all but the camel, its harness and the wheels one still picture: only what really moves may change (Danyal, on the fountain).
"""
import glob, json, os, subprocess, sys, tempfile
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label
sys.path.insert(0, "art/tools")
from steady_sheets import keep_shades

SMARTRIG = "/home/danye/orca/workspaces/SmartRigApp/Smartrig-animation-app"
SCRIPT = "/mnt/d/SmartRig/spike/elvis/ad/video_to_sprites.py"
OUT = "art/carriage_pull"
HEIGHT = 170          # px, the whole thing top to bottom. Claude's call by eye: the clip's camel is big next to its wagon, so this makes the camel 1.42x Fortuna's sprite and the wagon 0.7x the prop, the same jump each way
CELL = (232, 192)     # both sheets: the cell's middle column runs through the middle of the whole thing, so a turn swings about it, and its bottom row is about where the camel's feet are. A whole number of Cinerea.COLUMN wide
INSIDE = (38, 20, 22) # the dark of the carriage's inside, as art/tools/carriage_door.py's
SPEED = 1.0           # m/s the sheets are timed for: CassiaScene.PULL
# first: the first video frame of a loop measured on the legs, loop: video frames in it, foot: m its planted foot goes back between two cut frames, so what speed it plays at keeps the foot still on the ground (measured on the cut sheets)
# ground: px up from the cell's bottom of the middle of what touches the ground ("below": it stands there), windows: where a hole in the picture is a window, moves: circles and boxes of what really moves, in the cut picture's px
VIEWS = {
    "F": {"first": 5, "loop": 26, "foot": 1.0 / 24.0, "ground": 52, "windows": None,
          "moves": [("box", 14, 84, 64, 180), ("box", 0, 112, 77, 180)]},
    "S": {"first": 29, "loop": 40, "foot": 0.0635, "ground": 41, "windows": (40, 30, 128, 85),
          "moves": [("disc", 30, 96, 25), ("disc", 87, 130, 20), ("disc", 130, 114, 15), ("box", 136, 78, 228, 192), ("box", 100, 112, 140, 142), ("box", 118, 143, 136, 192)]},    # the last: her hind foot, as far back as it goes
}
# Parked she's one picture of the diagonal sheet with only her breath and her chewing drawn on it (as art/tools/breathe.py does): a real idle is neither a frozen step nor a clip (Danyal). In the cell's px.
IDLE_FRAME = 13       # all four feet down and the legs straight
BREATH_X = 150        # she breathes right of this: the wagon, the shafts and her haunch stay put
BELT = 148            # the row a breath drops, so the legs below it stay: the row most like the one above it
JAW = (214, 119, 224) # x from, the mouth's row, x to
MOUTH = (38, 20, 22)
IDLE_FPS = 5.0        # Claude's call, as the two lists below: 2.4 s a breath, two slow chews and a rest
BREATH = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]
CHEW = [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0]


def video_frames(path):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error", "-i", path, f"{tmp}/f%03d.png"], check=True)
        return [np.asarray(Image.open(p).convert("RGB")) for p in sorted(glob.glob(f"{tmp}/*.png"))]


def strip_of(view, src, tmp):
    """The clip's loop cut to sprites by video_to_sprites.py, every other video frame."""
    v = VIEWS[view]
    frames = video_frames(f"{src}/clips/carriage_pull_{view}.mp4")
    bg = np.median(frames[0][:20].reshape(-1, 3).astype(float), axis=0)
    keyed = lambda f: np.linalg.norm(f.astype(float) - bg, axis=-1) > 60
    picks = frames[v["first"]:v["first"] + v["loop"]:2]
    os.makedirs(f"{tmp}/{view}")
    for i, f in enumerate(picks):
        Image.fromarray(f).save(f"{tmp}/{view}/f{i + 1:03d}.png")
    master = frames[0].copy()
    master[~keyed(master)] = (255, 0, 255)
    Image.fromarray(master).save(f"{tmp}/master_{view}.png")
    res = subprocess.run(["uv", "run", "--quiet", "--with", "imageio-ffmpeg", "python", SCRIPT, f"{tmp}/{view}/f%03d.png", f"{tmp}/master_{view}.png", f"{tmp}/{view}_out", "--height", str(HEIGHT), "--all", str(len(picks)), "--colours", "32"], cwd=SMARTRIG, capture_output=True, text=True)
    assert res.returncode == 0, res.stderr[-400:]
    return np.stack(np.split(np.asarray(Image.open(f"{tmp}/{view}_out_strip.png").convert("RGBA")), len(picks), axis=1))


def moving_mask(view, shape):
    img = Image.new("L", (shape[1], shape[0]), 0)
    d = ImageDraw.Draw(img)
    for m in VIEWS[view]["moves"]:
        if m[0] == "disc":
            d.ellipse((m[1] - m[3], m[2] - m[3], m[1] + m[3], m[2] + m[3]), fill=255)
        else:
            d.rectangle(m[1:], fill=255)
    return np.asarray(img) > 0


def one_still_picture(view, frames):
    """Outside what moves each pixel is its most common colour over the loop, for every frame."""
    keep = ~moving_mask(view, frames.shape[1:3])
    packed = frames[..., 0].astype(np.uint32) | frames[..., 1].astype(np.uint32) << 8 | frames[..., 2].astype(np.uint32) << 16 | frames[..., 3].astype(np.uint32) << 24
    out = frames.copy()
    for y, x in zip(*np.nonzero(keep)):
        u, c = np.unique(packed[:, y, x], return_counts=True)
        out[:, y, x] = np.frombuffer(int(u[c.argmax()]).to_bytes(4, "little"), np.uint8)
    return out


def windows_filled(view, frames):
    """A hole shut in by the wagon, where its windows are: the clip keys them through to the ground."""
    box = VIEWS[view]["windows"]
    if box is None:
        return frames
    x0, y0, x1, y1 = box
    out = frames.copy()
    for f in out:
        holes, n = label(f[..., 3] == 0)
        outside = holes[0, 0]
        for i in range(1, n + 1):
            ys, xs = np.nonzero(holes == i)
            if i != outside and xs.min() >= x0 and xs.max() <= x1 and ys.min() >= y0 and ys.max() <= y1:
                f[ys, xs] = (*INSIDE, 255)
    return out


def parked_idle(walk, ground):
    """idle_S.png, from the finished diagonal sheet: its manifest entry."""
    cw, ch = CELL
    still = walk[:, IDLE_FRAME * cw:(IDLE_FRAME + 1) * cw]
    x0, row, x1 = JAW
    chewing = still.copy()
    chewing[row + 1:row + 6, x0:x1] = still[row:row + 5, x0:x1]
    chewing[row, x0:x1][still[row, x0:x1, 3] > 0] = (*MOUTH, 255)
    frames = []
    for breath, chew in zip(BREATH, CHEW):
        f = (chewing if chew else still).copy()
        if breath:
            f[1:BELT + 1, BREATH_X:] = f[:BELT, BREATH_X:].copy()
            f[0, BREATH_X:] = 0
        frames.append(f)
    Image.fromarray(np.hstack(frames)).save(f"{OUT}/idle_S.png")
    return {"file": "idle_S.png", "frames": len(frames), "fps": IDLE_FPS, "loop": True, "below": ground}


def main():
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    cw, ch = CELL
    anims = {}
    with tempfile.TemporaryDirectory() as tmp:
        for view, v in VIEWS.items():
            frames = windows_filled(view, one_still_picture(view, strip_of(view, src, tmp)))
            frames = keep_shades(list(frames) * 2)[len(frames):]    # steady_sheets.py's pass, twice round: once only, the loop's last frame keeps different shades from its first, and it flickers there
            h, w = frames[0].shape[:2]
            sheet = np.zeros((ch, cw * len(frames), 4), np.uint8)
            x, y = (cw - w) // 2, ch - h
            for i, f in enumerate(frames):
                sheet[y:y + h, i * cw + x:i * cw + x + w] = f
            Image.fromarray(sheet).save(f"{OUT}/walk_{view}.png")
            fps = round(SPEED / v["foot"], 2)
            anims[f"walk_{view}"] = {"file": f"walk_{view}.png", "frames": len(frames), "fps": fps, "loop": True, "below": v["ground"]}
            anims[f"idle_{view}"] = parked_idle(sheet, v["ground"]) if view == "S" else {"file": f"walk_{view}.png", "frames": 1, "fps": 1.0, "loop": True, "below": v["ground"]}
            print(view, len(frames), "frames at", fps, "fps", w, h)
    with open(f"{OUT}/manifest.json", "w") as f:
        json.dump({"cell": list(CELL), "anims": anims}, f, indent=1)


if __name__ == "__main__":
    main()
