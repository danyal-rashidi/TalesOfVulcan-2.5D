"""The jackal, from D:\\SmartRig\\spike\\cinerea\\ (video_to_sprites.py's strips). Run from the game's folder:
  uv run --with pillow --with numpy --with scipy python art/jackal/build_sheets.py D:/SmartRig/spike/cinerea
then sheets_for_game.py art/jackal. Shortcut: it has only a side view, so it runs and bites sideways even going up or down the screen; front and back views need about 16 credits.
"""
import json, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label


IDLE_FRAMES = 16    # jackal_idle.mp4 by video_to_sprites.py --whole 16, 4 s, so it plays at its own speed


def clean(strip, frames):
    a = np.asarray(Image.open(strip).convert("RGBA")).copy()
    fw = a.shape[1] // frames
    for i in range(frames):  # specks the video model left round it: only the biggest piece is the jackal
        f = a[:, i * fw:(i + 1) * fw]
        parts, n = label(f[..., 3] > 0)
        if n > 1:
            keep = 1 + np.bincount(parts.ravel())[1:].argmax()
            f[parts != keep] = 0
    return a


def main():
    src, out = sys.argv[1], "art/jackal"
    jobs = {}
    run, bite, idle = clean(f"{src}/jackal_run_strip.png", 8), clean(f"{src}/jackal_bite_strip.png", 6), clean(f"{src}/jackal_idle_strip.png", IDLE_FRAMES)
    for v in "FSB":
        for name, img, frames, fps, loop in (("run", run, 8, 12.0, True), ("bite", bite, 6, 12.0, False), ("idle", idle, IDLE_FRAMES, 4.0, True)):
            key = f"{name}_{v}"
            Image.fromarray(img).save(f"{out}/strips/{key}.png")
            jobs[key] = {"strip": f"strips/{key}.png", "frames": frames, "fps": fps, "loop": loop}
    json.dump(jobs, open(f"{out}/sheets.json", "w"), indent=1)


if __name__ == "__main__":
    main()
