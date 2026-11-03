"""Human Vulcan as a playable character, from D:\\SmartRig\\spike\\cinerea\\. Run from the game's folder:
  PYTHONPATH=<the SmartRig repo> uv run --with pillow --with numpy --with imageio-ffmpeg python art/vulcan_human/build_sheets.py D:/SmartRig/spike/cinerea
then sheets_for_game.py art/vulcan_human. He has clips only for his runs, swing and roll; other moves borrow them or his idle (shortcut: a real hurt, drink, death and
four different swings need about 40 more credits). "_spear" is Elvis's word for the weapon in hand (Elvis._look), so here it means the iron sword.
"""
import json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, "D:/SmartRig/spike/elvis/ad" if os.name == "nt" else "/mnt/d/SmartRig/spike/elvis/ad")
from video_to_sprites import palette_from_master, key, vote_down, tidy, add_outline, OUTLINE

STEEL = [(150, 156, 168), (100, 106, 118), (205, 210, 222)]
HEIGHT = 49   # his standing height, as the kneel and the look at his hands
HITS = {"F": [3, 4], "S": [2, 4], "B": [3, 4]}


def still(path, pal, colours):
    f = np.asarray(Image.open(path).convert("RGB")).astype(float)
    bg = np.median(np.concatenate([f[:20].reshape(-1, 3), f[-20:].reshape(-1, 3)]), axis=0)
    rgb, a = key(f, bg)
    ys, xs = np.nonzero(a > 0.5); y0, y1, x0, x1 = max(ys.min() - 8, 0), ys.max() + 9, max(xs.min() - 8, 0), xs.max() + 9
    s = HEIGHT / (np.ptp(ys) + 1); h, w = round((y1 - y0) * s), round((x1 - x0) * s)
    idx = np.asarray(Image.fromarray(rgb[y0:y1, x0:x1].astype(np.uint8)).quantize(palette=pal, dither=Image.Dither.NONE))
    ix, m = vote_down(idx, a[y0:y1, x0:x1], h, w, len(colours))
    out = np.zeros((h + 4, w + 4, 4), np.uint8); out[2:-2, 2:-2, :3], out[2:-2, 2:-2, 3] = colours[ix], tidy(m) * 255
    return add_outline(out, OUTLINE)


def breathing(frame):
    """Two frames: as drawn, and with everything above the belt 1 px lower (art/tools/breathe.py's way): nothing else changes, so nothing flickers."""
    ys = np.nonzero(frame[..., 3])[0]
    cut = ys.min() + int(0.55 * (ys.max() - ys.min()))
    low = frame.copy()
    low[1:cut + 1] = frame[:cut]
    low[0] = 0
    return np.concatenate([frame, low], axis=1)


def main():
    src, out = sys.argv[1], "art/vulcan_human"
    os.makedirs(f"{out}/strips", exist_ok=True)
    old = json.load(open(f"{out}/manifest.json"))
    pal, colours = palette_from_master("art/guides/ref_vulcan_human.png", n=20, add=STEEL)
    jobs = {}
    def add(key_, img, frames, fps, loop, **extra):
        Image.fromarray(img).save(f"{out}/strips/{key_}.png")
        jobs[key_] = {"strip": f"strips/{key_}.png", "frames": frames, "fps": fps, "loop": loop, **extra}
    def strip(name):
        return np.asarray(Image.open(f"{src}/{name}_strip.png").convert("RGBA"))
    for k in ("idle_F", "kneel_F", "look_hands_F"):    # his older sheets, for the prologue's end
        a = old["anims"][k]
        path = f"{out}/strips/{k}.png"
        add(k, np.asarray(Image.open(path if os.path.exists(path) else f"{out}/{a['file']}").convert("RGBA")), a["frames"], a["fps"], a.get("loop", True), **{x: a[x] for x in ("holds",) if x in a})
    RUNS = {"run_F": 9, "run_S": 12, "run_B": 6, "arun_F": 9, "arun_S": 7, "arun_B": 10}
    for v in "FSB":
        add(f"run_{v}", strip(f"run_{v}"), RUNS[f"run_{v}"], 12.0, True)
        add(f"run_spear_{v}", strip(f"arun_{v}"), RUNS[f"arun_{v}"], 12.0, True)
        stand = breathing(still(f"{src}/sword_{v}.png", pal, colours))
        add(f"idle_spear_{v}", stand, 2, 2.5, True, holds={"0": 0.3, "1": 0.2})
        for borrowed in ("charge", "hurt_spear", "death_spear", "drink_spear", "drink_walk_spear"):
            add(f"{borrowed}_{v}", stand, 2, 2.5, False)
        if v != "F":    # with no sword he only stands front on in the sheets he had: from the side and behind, his run's first frame
            r = strip(f"run_{v}"); add(f"idle_{v}", r[:, :r.shape[1] // RUNS[f"run_{v}"]], 1, 1.0, True)
        swing = strip(f"swing_{v}")
        for attack in ("light1", "light2", "light3", "light4", "lunge", "thrust"):
            add(f"{attack}_{v}", swing, 8, 12.0, False, active=HITS[v])
        roll = strip(f"roll_{v}")
        add(f"roll_spear_{v}", roll, 8, 12.0, False)
        add(f"roll_{v}", roll, 8, 12.0, False)
    json.dump(jobs, open(f"{out}/sheets.json", "w"), indent=1)
    # the inventory's portrait, with and without the sword
    a = still(f"{src}/sword_F.png", pal, colours); Image.fromarray(a).crop(Image.fromarray(a).getbbox()).save("art/ui/portrait_sword.png")
    i = Image.open(f"{out}/strips/idle_F.png").convert("RGBA").crop((0, 0, old["cell"][0], old["cell"][1])); i.crop(i.getbbox()).save("art/ui/portrait.png")
    print(len(jobs), "sheets")


if __name__ == "__main__":
    main()
