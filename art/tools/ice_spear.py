"""Elvis's giant ice spears for his F ability, drawn from his own spear's shape (a long shaft, a barbed leaf head) and in its own ice blues. Nothing is generated.
  uv run --with pillow --with numpy python art/tools/ice_spear.py
Writes, read by fx/ice_spear.gd and ui/hud.gd:
  art/ice_spear/spears.png  one column per angle, the first pointing right, turning clockwise on screen; each cell has the spear's tip at its middle, so the game only has to place the tip. Rows: frost (as it forms), shining twice (they take turns, as its glints), a white flash.
  art/ice_spear/shards.png  the icicles out of the break, one row, the same columns.
  art/ice_spear/icon.png    its HUD icon, 26 px, as the skills' icons.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

ANGLES = 32         # columns: every 11.25 degrees, so a turning spear steps but never jumps
LENGTH = 96         # px, tip to butt: he stands about 50 tall, so nearly twice that. Claude's call
CELL = LENGTH * 2 + 8    # even; the tip at the middle, so the whole spear fits whichever way it points. Never cropped (tests/test_ice_spears.gd)
SS = 4              # drawn this many times bigger, then brought down by block majority, so edges stay clean
HEAD = 38           # px of the head along the spear
HEAD_W = 12         # px from its middle to its widest
SHAFT_W = 3.6       # px from the middle of the shaft
SHARD_CELL = 22
SHARD = 12          # px, the icicles' length

EMPTY, SHAFT, SHADE, BLADE, EDGE, GLINT = range(6)

# His spear's own blues (far_hand_sheets.py ICE), dulled to frost until the break's icicles reach them.
FROST = {SHAFT: (170, 220, 240, 255), SHADE: (120, 176, 214, 255), BLADE: (190, 232, 246, 255), EDGE: (226, 246, 250, 255), GLINT: (226, 246, 250, 255)}
# And then a more colourful, shining blue: deep cobalt in the shade, cyan in the body, white on its edges.
SHINE = {SHAFT: (42, 170, 255, 255), SHADE: (24, 92, 226, 255), BLADE: (64, 214, 255, 255), EDGE: (215, 252, 252, 255), GLINT: (255, 255, 255, 255)}
FLASH = {k: (255, 255, 255, 255) for k in FROST}


def labels():
    """The spear pointing right, labelled by part at SS times the size, its tip at the middle of the cell. Crystal, so not a smooth lance: facets down the blade and spurs at its foot."""
    im = Image.new("L", (CELL * SS, CELL * SS), EMPTY)
    d = ImageDraw.Draw(im)
    c = CELL * SS // 2
    def poly(points, label):    # px from the tip, x back along the spear, y across
        d.polygon([(c - x * SS, c + y * SS) for x, y in points], fill=label)
    poly([(HEAD - 6, -SHAFT_W), (LENGTH, -SHAFT_W + 1), (LENGTH, SHAFT_W - 1), (HEAD - 6, SHAFT_W)], SHAFT)
    poly([(HEAD - 6, 0.6), (LENGTH, 0.4), (LENGTH, SHAFT_W - 1), (HEAD - 6, SHAFT_W)], SHADE)
    for at in (50, 72):    # bands of thicker ice round the shaft
        poly([(at, -SHAFT_W - 1), (at + 4, -SHAFT_W - 1), (at + 4, SHAFT_W + 1), (at, SHAFT_W + 1)], EDGE)
    poly([(HEAD - 2, -HEAD_W), (HEAD + 7, -HEAD_W - 2), (HEAD + 2, -2), (HEAD + 2, 2), (HEAD + 7, HEAD_W + 2), (HEAD - 2, HEAD_W)], BLADE)    # the spurs at its foot, like his spear's barbs
    poly([(0, 0), (HEAD * 0.55, -HEAD_W), (HEAD, -3), (HEAD, 3), (HEAD * 0.55, HEAD_W)], EDGE)
    poly([(3, 0), (HEAD * 0.55, -HEAD_W + 2.4), (HEAD - 2, -2), (HEAD - 2, 2), (HEAD * 0.55, HEAD_W - 2.4)], BLADE)
    poly([(5, 0.2), (HEAD * 0.55, 0.2), (HEAD - 3, 0.2), (HEAD - 3, 2), (HEAD * 0.55, HEAD_W - 3.4)], SHADE)
    poly([(LENGTH, -SHAFT_W - 1.5), (LENGTH - 2, -SHAFT_W - 1.5), (LENGTH - 2, SHAFT_W + 1.5), (LENGTH, SHAFT_W + 1.5)], EDGE)
    return im


def majority(labelled, cell):
    a = np.asarray(labelled)
    out = np.zeros((cell, cell), int)
    for y in range(cell):
        for x in range(cell):
            b = a[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS].ravel()
            n = np.bincount(b, minlength=6)
            if n[1:].sum() * 2 >= b.size:
                out[y, x] = n[1:].argmax() + 1
    return out


def coloured(parts, look):
    out = np.zeros((*parts.shape, 4), np.uint8)
    for label, rgba in look.items():
        out[parts == label] = rgba
    return out


def with_glints(parts, angle, turn):
    """A few pixels of the shaft and blade flash white, walking down it: the shine."""
    out = parts.copy()
    ys, xs = np.nonzero(parts)
    c = parts.shape[0] / 2
    along = (c - xs) * np.cos(angle) + (c - ys) * np.sin(angle)
    run = (along + turn * 15) % 30 < 3
    out[ys[run], xs[run]] = GLINT
    return out


def shard_parts():
    im = Image.new("L", (SHARD_CELL * SS, SHARD_CELL * SS), EMPTY)
    d = ImageDraw.Draw(im)
    c = SHARD_CELL * SS // 2
    d.polygon([(c + SHARD * SS // 2, c), (c - SHARD * SS // 2, c - 2 * SS), (c - SHARD * SS // 2, c + 2 * SS)], fill=EDGE)
    return im


def turned(im, cell, degrees):
    """Clockwise on screen, about the middle; the labels stay labels."""
    return majority(im.rotate(-degrees, resample=Image.NEAREST), cell)


def icon():
    """A spear across its circle, on a dark plate: reads as ice at 26 px."""
    n = 26
    im = Image.new("RGBA", (n, n), (16, 34, 74, 255))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, n - 3, n - 3], outline=SHINE[SHAFT])
    d.line([(5, 20), (15, 10)], fill=SHINE[BLADE], width=2)
    d.polygon([(21, 4), (20, 12), (17, 12), (14, 9), (14, 6)], fill=SHINE[EDGE])    # the head, up to the right
    d.polygon([(19, 7), (18, 10), (16, 8)], fill=SHINE[SHADE])
    return np.asarray(im)


def main():
    os.makedirs("art/ice_spear", exist_ok=True)
    base = labels()
    rows = [[], [], [], []]
    for col in range(ANGLES):
        deg = col * 360.0 / ANGLES
        parts = turned(base, CELL, deg)
        a = np.deg2rad(deg)
        rows[0].append(coloured(parts, FROST))
        rows[1].append(coloured(with_glints(parts, a, 0), SHINE))
        rows[2].append(coloured(with_glints(parts, a, 1), SHINE))
        rows[3].append(coloured(parts, FLASH))
    Image.fromarray(np.vstack([np.hstack(r) for r in rows])).save("art/ice_spear/spears.png", optimize=True)
    shard = shard_parts()
    Image.fromarray(np.hstack([coloured(turned(shard, SHARD_CELL, c * 360.0 / ANGLES), SHINE) for c in range(ANGLES)])).save("art/ice_spear/shards.png", optimize=True)
    Image.fromarray(icon()).save("art/ice_spear/icon.png")


if __name__ == "__main__":
    main()
