"""Clips of a new character -> its folder of game sheets: strips by video_to_sprites.py, sheets and manifest by sheets_for_game.py. A stand is the walk's first
frame, one frame long: the code gives it its small bob. Run from the game's repo, with the SmartRig repo at SMARTRIG:
  python3 art/tools/npc_sheets.py NAME HEIGHT MASTER walk_F=CLIP walk_S=CLIP ... slash_F=CLIP! (a ! means a one-shot, of 8 frames or !N, without it a loop; @H its first frame's height if it isn't a stand)
"""
import json
import os
import subprocess
import sys

SMARTRIG = "/home/danye/orca/workspaces/SmartRigApp/Smartrig-animation-app"
SCRIPTS = "/mnt/d/SmartRig/spike/elvis/ad"
CLIPS = "/mnt/d/SmartRig/spike/web/clips"
FPS = 12.0


def main():
    name, height, master, jobs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    folder = os.path.abspath(f"art/{name}")
    os.makedirs(f"{folder}/strips", exist_ok=True)
    sheets = {}
    for job in jobs:
        anim, clip = job.split("=")
        h = height
        if "@" in clip:    # its first frame's height, when that isn't a stand: crawl_S=clip!10@30
            clip, h = clip.split("@")
        once = "!" in clip
        clip, count = clip.split("!") if once else (clip, "")
        out = f"{folder}/strips/{anim}"
        args = ["uv", "run", "--quiet", "--with", "imageio-ffmpeg", "python", f"{SCRIPTS}/video_to_sprites.py", f"{CLIPS}/{clip}.mp4", master, out, "--height", h]
        res = subprocess.run(args + (["--once", count or "8"] if once else []), cwd=SMARTRIG, capture_output=True, text=True)
        assert res.returncode == 0, f"{clip}: {res.stderr[-400:]}"
        os.remove(f"{out}.gif")
        os.replace(f"{out}_strip.png", f"{out}.png")
        print(res.stdout.strip().splitlines()[-1].split(" -> ")[0], anim)
        frames = int(res.stdout.strip().splitlines()[-1].split(" frames")[0])
        sheets[anim] = {"strip": f"strips/{anim}.png", "frames": frames, "fps": FPS, "loop": not once}
    with open(f"{folder}/sheets.json", "w") as f:
        json.dump(sheets, f, indent=1)
    res = subprocess.run(["uv", "run", "--quiet", "--with", "pillow", "--with", "numpy", "python", f"{SCRIPTS}/sheets_for_game.py", folder], capture_output=True, text=True)
    assert res.returncode == 0, res.stderr[-400:]
    print(res.stdout.strip())
    with open(f"{folder}/manifest.json") as f:
        manifest = json.load(f)
    for d in "FSB":
        if f"walk_{d}" in manifest["anims"]:
            manifest["anims"][f"idle_{d}"] = {**manifest["anims"][f"walk_{d}"], "frames": 1, "fps": 1.0}
    with open(f"{folder}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=1)


if __name__ == "__main__":
    main()
