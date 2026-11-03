"""A clip -> one sheet of a character, without touching its other sheets: strip by video_to_sprites.py, each frame in the folder's own cell, head on the middle column, feet on the same row as its others,
colours moved to the folder's own palette (palette.png) so it matches them.
  uv run --with pillow --with numpy python art/tools/anim_into_sheets.py FOLDER ANIM CLIP.mp4 MASTER HEIGHT FRAMES FPS whole|once|all|loop [steel] [below=N] [keep=PX]
loop: the best looping run in the clip, however many frames that is; FRAMES is ignored and FPS is then seconds for one whole cycle, so all a move's views take the same time.
"""
import json
import os
import subprocess
import sys
import numpy as np
from PIL import Image

SMARTRIG = "/home/danye/orca/workspaces/SmartRigApp/Smartrig-animation-app"
SCRIPT = "/mnt/d/SmartRig/spike/elvis/ad/video_to_sprites.py"
STEEL = ["150,156,168", "100,106,118", "205,210,222"]

folder, anim, clip, master, height, frames, fps, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6]), float(sys.argv[7]), sys.argv[8]
steel = "steel" in sys.argv[9:]
below = next((int(a[6:]) for a in sys.argv[9:] if a.startswith("below=")), 0)    # his feet go this many rows up the cell, for what reaches below them (CharacterSprite's "below")
keep = next((a[5:] for a in sys.argv[9:] if a.startswith("keep=")), "0")    # pieces at least this big stay though they don't touch him: a thin thing he holds can lose its one joining pixel in a frame
full = os.path.abspath(f"art/{folder}")
out = f"{full}/strips/{anim}"
cmd = ["uv", "run", "--quiet", "--with", "imageio-ffmpeg", "python", SCRIPT, clip, master, out, "--height", height] + (["--first-height"] if mode == "loop" else [f"--{mode}", str(frames)]) + (["--add", *STEEL] if steel else []) + ["--keep-pieces", keep]
res = subprocess.run(cmd, cwd=SMARTRIG, capture_output=True, text=True)
assert res.returncode == 0, res.stderr[-400:]
os.remove(f"{out}.gif")
os.replace(f"{out}_strip.png", f"{out}.png")
print(res.stdout.strip().splitlines()[-1].split(" -> ")[0], anim)
if mode == "loop":
    frames = int(res.stdout.strip().splitlines()[-1].split()[0])
    fps = round(frames / fps, 2)
with open(f"{full}/manifest.json") as f:
    manifest = json.load(f)
cw, ch = manifest["cell"]
strip = np.asarray(Image.open(f"{out}.png").convert("RGBA")).copy()
pal = np.asarray(Image.open(f"{full}/palette.png").convert("RGBA")).reshape(-1, 4)
pal = np.unique(pal[pal[:, 3] > 0][:, :3], axis=0).astype(float)
solid = strip[..., 3] > 0
d = np.linalg.norm(strip[..., :3][solid][:, None, :].astype(float) - pal[None], axis=-1)
near = pal[d.argmin(axis=1)]
keep = d.min(axis=1) > 45    # what the palette has nothing near: the sword's steel, the outline
strip[..., :3][solid] = np.where(keep[:, None], strip[..., :3][solid], near).astype(np.uint8)
fw = strip.shape[1] // frames
ref = np.asarray(Image.open(f"{full}/{manifest['anims']['idle_F']['file']}").convert("RGBA"))[:, :cw]
feet = np.nonzero(ref[..., 3])[0].max()    # the row his feet stand on in this folder's sheets
first = strip[:, :fw]
ys, xs = np.nonzero(first[..., 3])
head = np.nonzero(first[ys.min():ys.min() + 10, :, 3])[1]
dx = cw // 2 - (head.min() + head.max()) // 2
dy = feet - ys.max() - below
sheet = Image.new("RGBA", (cw * frames, ch))
for i in range(frames):
    frame = Image.fromarray(strip[:, i * fw:(i + 1) * fw])
    box = Image.new("RGBA", (cw, ch))
    box.alpha_composite(frame, (max(dx, 0), max(dy, 0)), (max(-dx, 0), max(-dy, 0)))
    sheet.alpha_composite(box, (i * cw, 0))
sheet.save(f"{full}/{anim}.png")
entry = {"file": f"{anim}.png", "frames": frames, "fps": fps, "loop": mode not in ("once", "all")} | ({"below": below} if below else {})
manifest["anims"][anim] = entry
with open(f"{full}/manifest.json", "w") as f:
    json.dump(manifest, f, indent=1)
with open(f"{full}/sheets.json") as f:
    sheets = json.load(f)
sheets[anim] = {"strip": f"strips/{anim}.png", "frames": frames, "fps": fps, "loop": mode not in ("once", "all")}
with open(f"{full}/sheets.json", "w") as f:
    json.dump(sheets, f, indent=1)
print(anim, "dx", dx, "dy", dy)
