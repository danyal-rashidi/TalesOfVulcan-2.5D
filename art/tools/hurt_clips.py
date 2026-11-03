"""His hit reaction from real clips (Danyal: "instead do the new clips for him"): the hand-picked frames of each clip go through anim_into_sheets.py as his hurt sheets. The video model drew blood on the moment of impact whatever the prompt said, so those frames are skipped.
  uv run --with pillow --with numpy --with imageio-ffmpeg python art/tools/hurt_clips.py
Then art/tools/smaller_head.py and new_sword_sheets.py. Clips: D:/SmartRig/spike/web/clips/vulcan_armed_hurt_*.mp4 and vulcan_hurt_*.mp4, Seedance 2.0 Mini, 4 s, 480p, 2 credits each, the stand picture as both start and end image.
"""
import glob, os, subprocess, sys, tempfile
import imageio_ffmpeg

CLIPS = "/mnt/d/SmartRig/spike/web/clips"
MASTER = os.path.abspath("art/guides/ref_vulcan_human.png")
HEIGHT = "50"
FPS = "12.5"    # the game stretches it to HURT_TIME anyway
# Frame numbers: standing, thrown back, held or sunk low, on the way back, standing again.
PICKS = {
    "hurt_spear_S": ("vulcan_armed_hurt_S", (0, 24, 42, 60, 66)),
    "hurt_spear_L": ("vulcan_armed_hurt_L", (0, 18, 48, 60, 66)),
    "hurt_spear_F": ("vulcan_armed_hurt_F", (0, 39, 54, 66, 72)),
    "hurt_spear_B": ("vulcan_armed_hurt_B", (0, 45, 57, 64, 70)),
}
PICKS |= {
    "hurt_S": ("vulcan_hurt_S", (0, 30, 45, 57, 66)),
    "hurt_F": ("vulcan_hurt_F", (0, 39, 54, 69, 75)),
    "hurt_B": ("vulcan_hurt_B", (0, 27, 42, 51, 57)),
}


def main():
    only = sys.argv[1:]
    for key, (clip, frames) in PICKS.items():
        if only and key not in only:
            continue
        for old in glob.glob(f"art/vulcan_human/before_steady/{key}.png"):
            os.remove(old)    # steady_sheets.py would go back to it
        with tempfile.TemporaryDirectory() as d:
            short = f"{d}/{key}.mp4"
            pick = "+".join(f"eq(n\\,{n})" for n in frames)
            subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error", "-y", "-i", f"{CLIPS}/{clip}.mp4", "-vf", f"select='{pick}',setpts=N/24/TB", "-r", "24", "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv420p", short], check=True)
            steel = ["steel"] if "spear" in key else []
            subprocess.run(["uv", "run", "--with", "pillow", "--with", "numpy", "python", "art/tools/anim_into_sheets.py", "vulcan_human", key, short, MASTER, HEIGHT, str(len(frames)), FPS, "all", *steel], check=True)


if __name__ == "__main__":
    main()
