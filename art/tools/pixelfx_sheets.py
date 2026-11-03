"""The attacks' effects that come from pixelfx (MIT, https://github.com/patch-gg/pixelfx), recoloured to this game's colours and made hard: no soft glow, every pixel full or nothing, only the colours named here. Never upscaled.
  uv run --with pillow --with numpy python art/tools/pixelfx_sheets.py
Needs Node and a checkout of pixelfx at COMMIT (PIXELFX, or the environment variable of that name).
Writes art/pixelfx/<name>.png, one row of frames, each with the effect's origin at the middle of its cell, so the game only has to place the origin. SHEETS is the whole recipe. Each plays at its "fps".
Read by fx/ice_splash.gd, fx/ice_wake.gd and fx/hammer_blow.gd; tests/test_pixelfx.gd checks their frame counts and that nothing is cut.
Stock pixelfx effects look along the floor and these are for a camera looking down, so each here is the named stock effect ("from") redrawn with pixelfx's own helpers, in art/tools/pixelfx_own/: why is at the top of each file.
"""
import json
import os
import shutil
import subprocess
import tempfile

import numpy as np
from PIL import Image

PIXELFX = os.environ.get("PIXELFX", "/mnt/d/TalesOfVulkan/pixelfx")
COMMIT = "a841596"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "pixelfx")
OWN = os.path.join(HERE, "pixelfx_own")    # copied into the checkout's src/fx/game/ to render, and taken out after

# Elvis's ice: art/tools/ice_spear.py SHINE and white. fx/effect.gd ICY is the same.
ICE = ["#185ce2", "#2aaaff", "#40d6ff", "#d7fcfc", "#ffffff"]
# Sand as in fx/effect.gd SAND, with no grey and nothing dark that would read as an outline, on down to the floor's own shadow for rocks and cracks. His fire as in FIRE.
SAND = ["#7a5c34", "#a88a58", "#cab89c", "#e2d4ba", "#fff6d6", "#ffffff"]
FIRE = ["#781e12", "#c9281f", "#e8681e", "#ffa23d", "#ffd65c", "#fff6d6", "#ffffff"]

SHEETS = {
    # A spear's hit, his spear breaking and sealing. Chosen over ice/ice-shatter itself (it hid all of Vulcan under five heaps of rubble), water/splash (a water crown with flat rings) and ice/snowflake-burst (too slow, and pretty, for a blow).
    "ice_splash": {"id": "game/ice-burst", "from": "ice/ice-shatter", "options": {"palette": ICE, "light": 0}, "fps": 20, "keep": (0.3, 0.7), "ramp": ICE},
    # The spears' wake, a stamp at a time.
    "ice_wake": {"id": "game/ice-wake", "from": "ice/ice-lance", "options": {"palette": ICE, "light": 0}, "fps": 20, "keep": (0.5, 0.5), "ramp": ICE},
    # Hammer Blow's landing. "reach" is fx/hammer_blow.gd's RADIUS in px.
    "hammer_impact": {"id": "game/hammer-impact", "from": "impacts/ground-slam", "options": {"light": 0, "reach": 90}, "fps": 20, "keep": (0.2, 0.4), "ramp": SAND},
    "hammer_impact_fire": {"id": "game/hammer-impact", "from": "impacts/ground-slam", "options": {"light": 0, "reach": 90, "burn": True, "palette": FIRE}, "fps": 20, "keep": (0.2, 0.4), "ramp": FIRE + SAND},
}

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def render(s):
    """The effect's frames as they come from pixelfx, with its origin."""
    with tempfile.TemporaryDirectory() as tmp:
        cmd = ["node", "tools/render.mjs", s["id"], "--sheet", "--no-actor", "--fps", str(s["fps"]), "--opts", json.dumps(s["options"]), "--out", tmp]
        subprocess.run(cmd, cwd=PIXELFX, check=True, capture_output=True, text=True)
        name = s["id"].split("/")[1]
        meta = json.load(open(os.path.join(tmp, s["id"], name + ".json")))["meta"]["pixelfx"]
        img = np.asarray(Image.open(os.path.join(tmp, s["id"], name + ".png")).convert("RGBA"))
    w, h = meta["frameSize"]
    frames = [img[(i // meta["columns"]) * h:(i // meta["columns"] + 1) * h, (i % meta["columns"]) * w:(i % meta["columns"] + 1) * w] for i in range(meta["frames"])]
    return frames, meta["pivot"]


def harden(frame, ramp, keep):
    """Every pixel full or nothing, in the ramp's colours. See-through dust is dithered between keep's two alphas, and whatever is under the first goes."""
    a = frame[..., 3] / 255.0
    rgb = np.clip(frame[..., :3].astype(float) / np.maximum(a, 1 / 255.0)[..., None], 0, 255)    # pixelfx's --sheet multiplies colour by alpha as it pastes
    pal = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in ramp], float)
    d = ((rgb[:, :, None] - pal[None, None]) ** 2).sum(-1)
    out = np.zeros_like(frame)
    h, w = a.shape
    on = a >= keep[0] + (keep[1] - keep[0]) * BAYER[np.ix_(np.arange(h) % 4, np.arange(w) % 4)]
    out[on, :3] = pal[d.argmin(-1)][on]
    out[on, 3] = 255
    return out


def sheet(name, s):
    frames, (ox, oy) = render(s)
    frames = [harden(f, s["ramp"], s["keep"]) for f in frames]
    while len(frames) > 1 and not frames[-1][..., 3].any():
        frames.pop()
    # the smallest cell with the origin at its middle, from what is really drawn, so nothing is cut, with a clear pixel all round: tests/test_pixelfx.gd reads a clean edge as nothing cut
    hw = hh = 1
    for f in frames:
        ys, xs = np.nonzero(f[..., 3])
        if xs.size:
            hw = max(hw, ox - xs.min(), xs.max() + 1 - ox)
            hh = max(hh, oy - ys.min(), ys.max() + 1 - oy)
    hw, hh = hw + 1, hh + 1
    cw, ch = hw * 2, hh * 2
    row = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im = Image.fromarray(f)
        row.paste(im, (i * cw + hw - ox, hh - oy), im)    # by its own alpha: its empty margins would wipe the frame before
    os.makedirs(OUT, exist_ok=True)
    row.save(os.path.join(OUT, name + ".png"))
    print(f"{name}: {s['id']} {len(frames)} frames, cell {cw}x{ch}, plays for {len(frames) / s['fps']:.2f} s")


def main():
    head = subprocess.run(["git", "-C", PIXELFX, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    if head != COMMIT:
        raise SystemExit(f"pixelfx is at {head}, this recipe is for {COMMIT}")
    own = os.path.join(PIXELFX, "src", "fx", "game")
    shutil.rmtree(own, ignore_errors=True)
    shutil.copytree(OWN, own)
    try:
        for name, s in SHEETS.items():
            sheet(name, s)
    finally:
        shutil.rmtree(own, ignore_errors=True)    # leave the checkout as it was


if __name__ == "__main__":
    main()
