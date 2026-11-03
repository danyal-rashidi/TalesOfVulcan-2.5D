"""The possessed Vulcan's strips -> strips/ and sheets.json, for sheets_for_game.py (D:\\SmartRig\\spike\\elvis\\ad\\). Run from the game's folder:
  uv run --with pillow --with numpy python art/vulcan_boss/build_sheets.py D:/SmartRig/spike/vulcan
Each attack's frames are held so that its blow lands when boss/moves.gd says: no "active" in these sheets, so the code's fixed times stay the fight's timing
and only the pictures follow them. MOVES: windup, active, recover; VIEWS: the frame where the active part starts and the one after it ends, read off each strip.
"""
import json, os, sys
import numpy as np
from PIL import Image

CLIP = 8
MOVES = {"slam": (0.82, 0.16, 0.79), "slash": (0.50, 0.25, 0.40), "spell": (0.83, 1.5, 0.64), "breath": (0.98, 1.2, 1.04), "dive": (1.19, 0.77, 1.37), "charge": (0.6, 0.7, 0.8)}
VIEWS = {
    "slam": {"F": (3, 5), "S": (5, 6), "B": (5, 6)},
    "slash": {"F": (3, 6), "S": (4, 7), "B": (3, 6)},
    "spell": {"F": (2, 6), "S": (2, 6), "B": (2, 6)},
    "breath": {"F": (3, 6), "S": (5, 7), "B": (3, 6)},
    "dive": {"F": (2, 5), "S": (2, 6), "B": (2, 5)},
    "charge": {"F": (3, 6), "S": (2, 6), "B": (3, 6)},
}


def holds(start, end, n, times, fps=12.0):
    """Extra seconds on the last frame of the wind-up, of the active part and of the recovery, so the three parts take these shares of the sheet."""
    base = 1.0 / fps
    parts = [(start, times[0]), (end - start, times[1]), (n - end, times[2])]
    per = max(c * base / t for c, t in parts)  # seconds of sheet per second of move, so no part needs less than its plain frames
    out, last = {}, 0
    for count, t in parts:
        last += count
        extra = t * per - count * base
        if extra > 1e-6:
            out[str(last - 1)] = round(extra, 4)
    return out


def main():
    src, out = sys.argv[1], "art/vulcan_boss"
    os.makedirs(f"{out}/strips", exist_ok=True)
    old = json.load(open(f"{out}/manifest.json"))
    jobs = {}
    def add(key, img, frames, fps, loop, hold=None):
        img.save(f"{out}/strips/{key}.png")
        jobs[key] = {"strip": f"strips/{key}.png", "frames": frames, "fps": fps, "loop": loop}
        if hold:
            jobs[key]["holds"] = hold
    def strip(name):
        return Image.open(f"{src}/{name}_strip.png").convert("RGBA")
    # the runs and walks stay the shrunk sheets they were (their first build's sheets, kept in strips/ once this has run)
    for key in ("run_F", "run_S", "run_B", "walk_F", "walk_S", "walk_B"):
        a = old["anims"][key]
        path = f"{out}/strips/{key}.png"
        add(key, Image.open(path if os.path.exists(path) else f"{out}/{a['file']}").convert("RGBA"), a["frames"], a["fps"], True)
    for v in "FSB":
        add(f"idle_{v}", strip(f"idle_{v}"), CLIP, 4.0, True)
        for move, view in VIEWS.items():
            add(f"{move}_{v}", strip(f"{move}_{v}"), CLIP, 12.0, False, holds(*view[v], CLIP, MOVES[move]))
        add(f"flinch_{v}", strip(f"flinch_{v}"), CLIP, 12.0, False)
        # the backswing cuts back across from where the slash ended: the slash's sweep, backwards, then its rise to guard
        s = np.asarray(strip(f"slash_{v}")); fw = s.shape[1] // CLIP
        start, end = VIEWS["slash"][v]
        order = list(range(end, start - 1, -1)) + [start - 1] * (start > 0)
        back = np.concatenate([s[:, i * fw:(i + 1) * fw] for i in order], axis=1)
        add(f"backswing_{v}", Image.fromarray(back), len(order), 12.0, False, holds(1, 1 + end - start, len(order), (0.26, 0.10, 0.46)))
    add("roar_F", strip("roar_F"), CLIP, 6.0, False)
    # kneeling: his dropped sword is C3's prop, so it's cut from the frames where it touches him
    k = np.asarray(strip("kneel_F")).copy(); fw = k.shape[1] // CLIP
    xs = np.nonzero(k[:, 5 * fw:6 * fw, 3].max(axis=0))[0]
    for i in (6, 7):
        k[:, i * fw:i * fw + xs.min() + 1] = 0
    add("kneel_F", Image.fromarray(k), CLIP, 6.0, False)
    add("statue_F", Image.fromarray(k[:, 7 * fw:8 * fw]), 1, 1.0, True)
    add("wake_F", strip("wake_F"), CLIP, 3.0, False)
    json.dump(jobs, open(f"{out}/sheets.json", "w"), indent=1)
    print(len(jobs), "sheets")


if __name__ == "__main__":
    main()
