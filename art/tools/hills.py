"""The hills beside the road into Cinerea: their heights, and the picture that shades them.
  uv run --with pillow --with numpy python art/tools/hills.py [PREVIEW.png]
writes art/floors/hills_height.bin (little-endian float32, one row of WIDE heights per z, 4 a metre: core/hills.gd reads it, and nothing else knows the shapes) and art/floors/hills.png.
The picture is laid out as the screen sees it: x at 32 px a metre and, down it, z minus height x cos/sin(pitch) at 24 px a metre. So on any slope one texel is one screen pixel, and with height 0 it lines up with the flat ground's own grid.
Shaded in hard bands from the game's sand colours, by a light of its own from the top of the screen and how high up the hill each bit is: lit from below, as the game's real sun would, a mound reads as a hollow. Transparent where the ground is flat, so flat ground stays exactly what it was.
"""
import sys
import numpy as np
from PIL import Image

# What core/hills.gd also knows: the table's corner and size. Keep them the same.
X0, X1, Z0, Z1 = -46.0, 46.0, -62.0, 16.0
PER_M = 4
V0 = -67.0    # the top of the picture: the highest ground, furthest north, shows this far up
PITCH = np.radians(48.59)
BACK = np.cos(PITCH) / np.sin(PITCH)    # 1 m up shows on screen as this many m of ground depth
LIGHT = np.array([-0.35, 0.80, -0.48])    # toward the hills' own light, north and a little west. Real shadows still fall from the sun. Claude's call
LIFT = 0.6     # how much being high up brightens a slope, so the side facing the camera steps darker all the way to its foot. Claude's call
DROP = 0.14    # how much darker the far side of the top is than the near: the top of a hill is a hard edge, as on a dune. Claude's call
TALL = 3.4     # the height that shades as itself: lower hills shade nearer to this, or they'd show almost no bands
MOST_SLOPE = np.tan(np.radians(34.5))    # sprites begin to clip into the ground at about 41 degrees

# x, z of the middle; half length along its line, half width on its south and north sides; turned this many degrees; height. Claude's call, all of it.
MOUNDS = [
    # west of the road, north to south
    (-20.0, -51.5, 13.0, 8.0, 7.5, 12.0, 3.0),
    (-17.5, -45.0, 8.0, 6.5, 6.5, 20.0, 2.6),
    (-27.5, -39.5, 10.0, 9.0, 8.0, -35.0, 3.4),
    (-24.0, -26.0, 9.5, 9.0, 8.5, 5.0, 3.4),
    (-14.3, -13.6, 6.0, 5.0, 4.8, -20.0, 2.0),
    (-25.0, -14.0, 9.0, 8.0, 7.5, 50.0, 3.2),
    (-29.0, -3.0, 8.0, 7.0, 6.5, 70.0, 2.8),
    (-31.0, 7.0, 7.0, 7.0, 6.5, 85.0, 2.6),
    (-21.5, 10.5, 7.0, 4.5, 3.8, 5.0, 1.5),
    (-13.2, 11.5, 4.5, 3.5, 3.0, 0.0, 1.2),
    # east of the road
    (19.0, -51.5, 12.0, 8.0, 7.0, -12.0, 3.2),
    (14.5, -48.0, 8.0, 6.5, 6.5, -25.0, 2.8),
    (28.0, -37.5, 9.0, 8.5, 7.5, 25.0, 3.4),
    (12.5, -29.5, 5.5, 4.2, 4.0, 10.0, 1.6),
    (26.5, -24.0, 9.0, 8.5, 8.5, -15.0, 3.4),
    (13.5, -13.5, 6.0, 5.0, 4.5, 8.0, 2.0),
    (26.5, -11.0, 8.0, 7.5, 7.0, 60.0, 2.8),
    (33.5, -2.0, 8.0, 6.5, 6.5, 85.0, 2.8),
    (33.5, 7.5, 6.5, 6.0, 6.0, 85.0, 2.4),
]
# Where the ground stays flat: x0, x1, z0, z1, each with room round it. The road and what stands by it, the tomb's pit and the jackal's way, her carriage and its way to the road, the camel's way, the gate.
FLAT = [
    (-5.5, 5.5, -62.0, 16.0),      # the road, and a little either side of it
    (-14.0, 6.5, -31.0, -19.0),    # the tomb and what stands by it: test_journey walks him through this
    (-19.0, 5.5, -3.0, 6.5),       # Cassia's carriage (x -6.5, z 1), rolling to the road, and Fortuna coming from x -16
    (-9.5, 7.0, -39.0, -33.0),     # a broken tomb and rubble
    (-7.5, 7.5, -18.0, -5.0),      # tombs, a milestone, rubble, a cypress by the road
    (-12.5, -9.5, -3.0, 0.0),      # a cypress
    (-12.5, -10.0, 1.0, 4.0),      # crates
    (-8.0, 8.0, 7.0, 16.0),        # a milestone, a bush, a cypress
    # under the rocks: Cinerea.CRAGS
    (-17.2, -9.0, -37.0, -32.5),
    (7.5, 17.0, -40.0, -35.0),
    (8.0, 17.2, -25.0, -19.0),
    (-17.2, -9.0, -7.2, -3.0),
]
LAKE = (14.6, 2.6, 8.6 + 2.5, 6.1 + 2.5)    # its shore can be walked on: Cinerea.LAKE_AT, LAKE_HALF, and room


def waves(xx, zz, seed, size):
    """Smooth lumps about `size` m across, about -1 to 1, with no grid in them: a value noise's square cells show as square patches of shade."""
    rng = np.random.default_rng(seed)
    total = np.zeros_like(xx, dtype=float)
    for turn, phase, stretch in zip(rng.uniform(0.0, np.pi, 4), rng.uniform(0.0, np.pi * 2.0, 4), rng.uniform(0.8, 1.3, 4)):
        total += np.sin((xx * np.cos(turn) + zz * np.sin(turn)) * np.pi * 2.0 / (size * stretch) + phase)
    return total / 2.5


def height(xx, zz, evened=False):
    """The hills at these points: rounded on top, easing out to a clear edge where each meets the sand, the outlines uneven so they aren't ellipses. Evened: the same shapes, for shading, with the low ones raised toward TALL."""
    lumps = waves(xx, zz, 5, 11.0) * 0.05 + waves(xx, zz, 6, 4.5) * 0.01
    total = np.zeros_like(xx, dtype=float)
    for cx, cz, a, south, north, turn, high in MOUNDS:
        c, s = np.cos(np.radians(turn)), np.sin(np.radians(turn))
        u = (xx - cx) * c + (zz - cz) * s
        v = -(xx - cx) * s + (zz - cz) * c
        r = np.sqrt((u / a) ** 2 + (v / np.where(v > 0.0, south, north)) ** 2) + lumps
        r = np.clip(r, 0.0, 1.0)
        if evened:
            high = np.sqrt(high * TALL)
        h = high * (0.25 * (1.0 + np.cos(np.pi * r)) + 0.5 * np.cos(np.pi / 2.0 * r))
        h = np.where(r < 1.0, h, 0.0)
        total += h ** 4
    return total ** 0.25


def flat_mask(xx, zz):
    keep = np.zeros_like(xx, dtype=bool)
    for x0, x1, z0, z1 in FLAT:
        keep |= (xx >= x0) & (xx <= x1) & (zz >= z0) & (zz <= z1)
    keep |= ((xx - LAKE[0]) / LAKE[2]) ** 2 + ((zz - LAKE[1]) / LAKE[3]) ** 2 < 1.0
    return keep


def table():
    wide = int((X1 - X0) * PER_M) + 1
    deep = int((Z1 - Z0) * PER_M) + 1
    xx, zz = np.meshgrid(X0 + np.arange(wide) / PER_M, Z0 + np.arange(deep) / PER_M)
    h = height(xx, zz)
    if h[0].max() > 0.0 or h[-1].max() > 0.0 or h[:, 0].max() > 0.0 or h[:, -1].max() > 0.0:
        raise SystemExit("a hill runs off the table")
    bad = (h > 0.0) & flat_mask(xx, zz)
    if bad.any():
        where = sorted({(round(float(x)), round(float(z))) for x, z in zip(xx[bad], zz[bad])})
        raise SystemExit(f"hills on flat ground, about: {where[:30]} ({bad.sum()} points)")
    return xx, zz, h


# The game's sand: Cinerea.TOWN_SAND and its quiet tones (Arena._quiet), the dunes' and packed earth's from art/tools/town_floor.py, and lit ones toward its sun.
PLAIN = np.array([192, 170, 98])
BANDS = [    # its least brightness, its colour. Claude's call.
    (1.30, (216, 195, 124)),
    (1.12, (205, 183, 110)),
    (0.84, tuple(PLAIN)),
    (0.72, (178, 156, 92)),
    (0.58, (163, 141, 86)),
    (-9.0, (148, 126, 80)),
]
FOOT = (134, 113, 74)    # the dark line where a hill's south and east sides meet the sand: all the way round, it reads as a dish's rim
CREST = (228, 208, 138)    # the line along the top of a hill
CREST_FROM = 0.45    # how high up a hill, of TALL, the line starts. Claude's call


def paint(xx, zz, h, preview):
    wide = int((X1 - X0) * 32)
    deep = int((Z1 - V0) * 24)
    out = np.zeros((deep, wide, 4), np.uint8)
    rows = V0 + (np.arange(deep) + 0.5) / 24.0
    zs = Z0 + np.arange(int((Z1 - Z0) * 48) + 1) / 48.0
    q_lumps = waves(*np.meshgrid(X0 + np.arange(wide) / 32.0, rows), 8, 3.6)    # the bands' edges wander a little, so they don't look ruled
    rng = np.random.default_rng(3)
    grain = rng.random((deep // 3 + 2, wide // 4 + 2))
    grain = np.kron(grain, np.ones((3, 4)))[:deep, :wide]
    north = np.zeros((deep, wide), bool)    # still climbing, going south: the top of a hill is where this ends
    high_up = np.zeros((deep, wide), bool)
    for i in range(wide):
        x = X0 + (i + 0.5) / 32.0
        here = height(np.full_like(zs, x), zs)
        if here.max() <= 0.0:
            continue
        evened = height(np.full_like(zs, x), zs, True)
        p = (height(np.full_like(zs, x + 1 / 32.0), zs, True) - height(np.full_like(zs, x - 1 / 32.0), zs, True)) * 16.0
        q = np.gradient(evened, zs)
        on_screen = zs - here * BACK    # always rising: nothing here is steep enough to hide ground behind it
        z = np.interp(rows, on_screen, zs)
        height_here = np.interp(z, zs, here)
        pp = np.interp(z, zs, p)
        qq = np.interp(z, zs, q)
        how_high = np.interp(z, zs, evened) / TALL
        light = (LIGHT[1] - LIGHT[0] * pp - LIGHT[2] * qq) / np.sqrt(1.0 + pp * pp + qq * qq) + how_high * LIFT - np.where(qq < 0.0, DROP, 0.0) + q_lumps[:, i] * 0.009
        colour = np.zeros((deep, 3))
        for least, c in reversed(BANDS):
            colour[light >= least] = c
        tone = grain[:, i]
        colour = np.where((tone > 0.86)[:, None], colour + (1 - colour / 255.0) * 3.0, colour)    # as quiet as the flat sand round it
        colour = np.where((tone < 0.12)[:, None], colour * 0.98, colour)
        colour[(height_here > 0.0) & (height_here < 0.04) & (pp * 0.6 + qq < 0.0)] = FOOT
        north[:, i] = qq > 0.0
        high_up[:, i] = how_high > CREST_FROM
        out[:, i, :3] = colour.round().astype(np.uint8)
        out[:, i, 3] = np.where(height_here > 0.0, 255, 0)
    south = ~north
    next_to_south = np.zeros_like(north)
    next_to_south[:-1] |= south[1:]
    next_to_south[:, :-1] |= south[:, 1:]
    next_to_south[:, 1:] |= south[:, :-1]
    out[north & next_to_south & high_up & (out[..., 3] > 0), :3] = CREST
    Image.fromarray(out).save("art/floors/hills.png", optimize=True)
    print("art/floors/hills.png", wide, deep, "highest", round(float(h.max()), 2))
    if preview:
        bg = np.zeros((deep, wide, 4), np.uint8)
        bg[..., :3] = PLAIN
        bg[..., 3] = 255
        im = Image.fromarray(bg)
        im.alpha_composite(Image.fromarray(out))
        im.resize((wide // 2, deep // 2), Image.NEAREST).save(preview)


def main():
    xx, zz, h = table()
    dx = np.gradient(h, 1.0 / PER_M, axis=1)
    dz = np.gradient(h, 1.0 / PER_M, axis=0)
    steepest = np.sqrt(dx * dx + dz * dz)
    worst = np.unravel_index(steepest.argmax(), steepest.shape)
    print(f"steepest {np.degrees(np.arctan(steepest.max())):.1f} deg at x {xx[worst]:.1f} z {zz[worst]:.1f}, {np.mean(h > 0) * 100:.0f}% of the table is hill")
    if steepest.max() > MOST_SLOPE:
        print("TOO STEEP: ", np.degrees(np.arctan(MOST_SLOPE)))
    h.astype("<f4").tofile("art/floors/hills_height.bin")
    paint(xx, zz, h, sys.argv[1] if len(sys.argv) > 1 else None)


if __name__ == "__main__":
    main()
