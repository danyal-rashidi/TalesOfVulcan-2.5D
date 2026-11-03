"""Elvis snaps his spear in half, for his F ability: the hand-picked frames of each clip go through anim_into_sheets.py as his ice_snap sheets, in the views he has, then the left-facing one and steady_sheets.py.
  uv run --with pillow --with numpy --with scipy --with imageio-ffmpeg --with imageio python art/tools/ice_snap_clips.py
Clips: D:/SmartRig/spike/web/clips/elvis_ice_snap_*.mp4, Seedance 2.0 Mini, 4 s, 480p, 2 credits each, his guard picture (D:/SmartRig/spike/elvis/ad/v3/guard_*_a.png) as both start and end image. The prompt had him snap it, hold the halves apart, and bring them back together, so the spear comes back in the clip itself.
"""
import glob, json, os, subprocess, sys, tempfile
import imageio_ffmpeg
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import steady_sheets as steady

CLIPS = "/mnt/d/SmartRig/spike/web/clips"
MASTER = "/mnt/d/SmartRig/spike/elvis/ad/blue_g.png"
HEIGHT = "50"    # as his other guards (art/elvis_blue/notes.md)
UV = ["uv", "run", "--quiet", "--with", "pillow", "--with", "numpy"]
# Frame numbers: guard, lifting, lifted, the snap (frame 4 of the sheet), held apart, coming back, sealed (frame 8), back to guard.
PICKS = {
    "ice_snap_F": ("elvis_ice_snap_F", (0, 6, 12, 20, 24, 32, 40, 62, 72, 76, 84, 96)),
    "ice_snap_S": ("elvis_ice_snap_S", (0, 6, 10, 14, 18, 30, 44, 56, 64, 72, 84, 96)),
    "ice_snap_B": ("elvis_ice_snap_B", (0, 6, 10, 12, 18, 30, 50, 72, 76, 78, 84, 96)),
}
# The video model drew a bright line down the middle of the front clip while the spear was broken: over the green, painted out before the cut.
PAINT = {"ice_snap_F": "drawbox=x=428:y=0:w=24:h=60:color=0x0a903d:t=fill,drawbox=x=428:y=360:w=24:h=136:color=0x0a903d:t=fill,"}
# In the front view the thin halves lose the one pixel joining them to his hands in clip frame 40, and the cutter dropped them for that frame: a blink. They stay here, but only here: the other clips have broken-off bits that must still go.
KEEP = {"ice_snap_F": "keep=20"}
# Whole-frame times, seconds: the game plays it for ABILITIES["Ice Spears"]["time"], 2.7, and these add up to that with 12 frames at 12 fps: frame 4, the snap, starts 1.7 s in, and the halves are still apart at the launch, 2.0 s in. fx/ice_volley.gd reads "active": the snap, then the seal.
HOLDS = {"0": 0.5, "1": 0.2, "3": 0.667, "5": 0.333}
ACTIVE = [4, 8]
FPS = 12.0


def main():
    for old in glob.glob("art/elvis_blue/before_steady/ice_snap_*.png"):
        os.remove(old)    # steady_sheets.py would go back to it
    if not os.path.exists("art/elvis_blue/palette.png"):    # anim_into_sheets.py wants the folder's colours: his stand's
        stand = np.asarray(Image.open("art/elvis_blue/idle_spear_F.png").convert("RGBA")).reshape(-1, 4)
        Image.fromarray(np.unique(stand[stand[:, 3] > 0], axis=0)[None].astype(np.uint8)).save("art/elvis_blue/palette.png")
    for key, (clip, frames) in PICKS.items():
        with tempfile.TemporaryDirectory() as d:
            short = f"{d}/{key}.mp4"
            pick = "+".join(f"eq(n\\,{n})" for n in frames)
            subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error", "-y", "-i", f"{CLIPS}/{clip}.mp4", "-vf", f"{PAINT.get(key, '')}select='{pick}',setpts=N/24/TB", "-r", "24", "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", short], check=True)
            subprocess.run(UV + ["--with", "imageio-ffmpeg", "python", "art/tools/anim_into_sheets.py", "elvis_blue", key, short, MASTER, HEIGHT, str(len(frames)), str(FPS), "all", "below=4", KEEP.get(key, "keep=0")], check=True)
    subprocess.run(UV + ["python", "art/tools/far_hand_sheets.py", "art/elvis_blue", "ice_snap"], check=True)
    for name in ("sheets", "manifest"):
        path = f"art/elvis_blue/{name}.json"
        with open(path) as f:
            data = json.load(f)
        anims = data["anims"] if name == "manifest" else data
        for key in PICKS:
            anims[key] |= {"holds": HOLDS, "active": ACTIVE}
        if name == "manifest":
            anims["ice_snap_L"] |= {"holds": HOLDS, "active": ACTIVE}
        with open(path, "w") as f:
            json.dump(data, f, indent=1)
    steady.SKIP = tuple(a["file"] for a in anims.values() if not a["file"].startswith("ice_snap"))    # his other sheets stay as they are: some were finished by hand since
    steady.run("elvis_blue")


if __name__ == "__main__":
    main()
