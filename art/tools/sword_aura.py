"""The aura on Vulcan's greatsword as he winds up the slam: fire along the blade, frame by frame of slam_F, slam_S and slam_B, in the hard pixels and the same licking tongues as the burning hammer (art/tools/hammer_aura.py). Nothing is generated.
  uv run --with pillow --with numpy python art/tools/sword_aura.py
Writes art/sword_aura/aura.png, read by fx/sword_aura.gd. One column per frame of his sheet, each cell centred on his own cell, so the game only has to lay it over him; three rows of flame per view, only the flames differ between them.
Also stands his sword up behind him in the slam sheets' overhead frames, which were drawn with none, so fire always has a blade in it. Only empty pixels change, so art/tools/boss_eyes.py's marks stay and it's safe to run again. Run it after anything that rewrites those sheets.
"""
import numpy as np
from PIL import Image

W, H = 122, 118     # his cell
PAD = 40            # px of room round it: the flames go past his cell's edge. Even, so a texel lands on a screen pixel
CELL_W, CELL_H = W + PAD * 2, H + PAD * 2
VIEWS = 'FSB'       # fx/sword_aura.gd's rows, in this order
FLAMES = 3
# Each frame's blade, hilt to tip, x y x y in his cell, read off the sheets at 4x. In the back view's strike (5) the blade lies away from us, up the screen, behind him. Claude's call
BLADES = {
    'F': [(50, 91, 41, 111), (62, 60, 62, 34), (62, 56, 62, 13), (62, 92, 62, 113), (61, 96, 61, 112), (60, 95, 60, 115), (52, 87, 45, 114), (50, 92, 41, 110)],
    'S': [(64, 95, 96, 107), (71, 69, 94, 49), (48, 55, 10, 53), (49, 57, 13, 49), (76, 72, 84, 49), (70, 98, 107, 111), (70, 98, 108, 115), (66, 96, 99, 108)],
    'B': [(75, 94, 92, 114), (80, 86, 104, 86), (79, 80, 104, 70), (68, 69, 86, 59), (61, 60, 61, 38), (60, 100, 60, 62), (75, 99, 83, 114), (76, 96, 92, 114)],
}
NO_BLADE = {('F', 1), ('F', 2), ('B', 4), ('B', 5)}    # his sheets lost the blade behind his head here: without one the fire reads as a beam out of his helmet. Claude's call
SIDE_FRAME, TIP_COL, BASE_COL = 2, 9, 46    # the blade to copy: slam_S's raised frame, where it lies level and whole, with rows 48 to 59 holding nothing else
GUARD = ((14, 22, 40), (62, 51, 47), (34, 34, 36), (14, 22, 40))    # top to bottom, his sword's own colours. Its outer rows are the line core/sprite.gdshader doesn't draw
GUARD_HALF = 7
IN_FRONT = {('F', 3), ('F', 4), ('F', 5)}    # the blade comes down in front of his legs: there the fire goes over him, everywhere else behind
POWER = {    # how strong it burns by each frame: it builds to the strike, which is frame 3 from the front and 5 from the side and back (his manifest's holds). Claude's call
    'F': [0.45, 0.7, 1.0, 1.0, 1.0, 1.0, 0.7, 0.5],
    'S': [0.35, 0.5, 0.7, 0.85, 1.0, 1.0, 0.8, 0.5],
    'B': [0.35, 0.5, 0.7, 0.85, 1.0, 1.0, 0.8, 0.5],
}
PAST_TIP = 8        # px of fire past the point
HALF = 6.5          # px either side of the blade at full strength
# fx/effect.gd's FIRE, white-hot to dark red.
WHITE, YELLOW, ORANGE, RED = (255, 246, 214), (255, 214, 92), (232, 104, 30), (120, 30, 18)


def erode(m):
    out = m.copy()
    out[1:] &= m[:-1]; out[:-1] &= m[1:]; out[:, 1:] &= m[:, :-1]; out[:, :-1] &= m[:, 1:]
    return out


def dilate(m):
    out = m.copy()
    out[1:] |= m[:-1]; out[:-1] |= m[1:]; out[:, 1:] |= m[:, :-1]; out[:, :-1] |= m[:, 1:]
    return out


def tongues(width, rng, low, high):
    """Flame length per column or row: round-topped lobes four to eight wide."""
    h = np.zeros(width)
    x = 0
    while x < width:
        w = int(rng.integers(4, 9))
        tall = rng.integers(low, high)
        for i in range(w):
            if x + i < width:
                h[x + i] = tall * (1.0 - (abs(i - (w - 1) / 2) / (w / 2)) ** 2) + 1
        x += w
    return h


def band(blade, power):
    """How far each pixel is across the fire: 0 on the blade's line, 1 at the fire's edge, more outside it. It narrows to a point past the tip. Also how far it is off the line, in px."""
    x0, y0, x1, y1 = [v + PAD for v in blade]
    along = np.array([x1 - x0, y1 - y0], float)
    length = np.linalg.norm(along)
    along /= length
    ys, xs = np.mgrid[:CELL_H, :CELL_W]
    s = (xs + 0.5 - x0) * along[0] + (ys + 0.5 - y0) * along[1]
    off = np.abs((xs + 0.5 - x0) * along[1] - (ys + 0.5 - y0) * along[0])
    full = length + PAST_TIP
    half = HALF * power * np.clip((full - s) / (PAST_TIP * 2), 0.0, 1.0) + 0.5
    across = off / half
    across[(s < 0) | (s > full)] = 9.0
    return across, off


def stand_blade(sheet, frame, blade, side):
    """Paint the side view's blade upright into a frame, its tip on the blade's tip, behind him: empty pixels only. Each column is centred on the line, as the side view's lies a little aslant."""
    x, tip = blade[2], blade[3]
    src = side[:, SIDE_FRAME * W:(SIDE_FRAME + 1) * W]
    him = sheet[:, frame * W:(frame + 1) * W]
    sword = np.zeros_like(him)
    for col in range(TIP_COL, BASE_COL):
        rows = np.nonzero(src[48:60, col, 3])[0] + 48
        for r in rows:
            sword[tip + col - TIP_COL, x + r - (rows[0] + rows[-1]) // 2] = src[r, col]
    for i, colour in enumerate(GUARD):
        sword[tip + BASE_COL - TIP_COL + i, x - GUARD_HALF:x + GUARD_HALF + 1] = (*colour, 255)
    empty = him[..., 3] == 0
    him[empty] = sword[empty]


def cell(view, frame, sheet, seed):
    power = POWER[view][frame]
    across, off = band(BLADES[view][frame], power)
    fire = across <= 1.0
    out = np.zeros((CELL_H, CELL_W, 4), np.uint8)
    out[across <= 1.0] = (*ORANGE, 255)
    out[across <= 0.7] = (*YELLOW, 255)
    out[across <= 0.3] = (*WHITE, 255)
    rng = np.random.default_rng(seed)
    up = tongues(CELL_W, rng, round(3 * power) + 1, round(14 * power) + 2)
    side = tongues(CELL_H, rng, 1, round(5 * power) + 2)
    def flame(x, y, f):
        if 0 <= x < CELL_W and 0 <= y < CELL_H and not fire[y, x]:
            out[y, x] = (*YELLOW, 255) if f < 0.4 else (*ORANGE, 255) if f < 0.8 else (*RED, 230)
    for x in range(CELL_W):    # licking up from every edge that faces up
        for y in np.nonzero(fire[:, x] & ~np.roll(fire[:, x], 1))[0]:
            n = int(up[x])
            for k in range(1, n + 1):
                flame(x, y - k, k / n)
    for y in range(CELL_H):    # and curling up off its sides
        n = int(side[y])
        for way, edges in ((-1, fire[y] & ~np.roll(fire[y], 1)), (1, fire[y] & ~np.roll(fire[y], -1))):
            for x in np.nonzero(edges)[0]:
                for k in range(1, n + 1):
                    flame(x + way * k, y - k // 2, k / n)
    near = out[..., 3] > 0
    for _ in range(4):
        near = dilate(near)
    out[near & (out[..., 3] == 0) & (rng.random((CELL_H, CELL_W)) < 0.02)] = (*YELLOW, 255)    # embers lifting off
    him = np.zeros((CELL_H, CELL_W), bool)
    him[PAD:PAD + H, PAD:PAD + W] = sheet[:, frame * W:(frame + 1) * W, 3] > 0
    if (view, frame) in IN_FRONT:
        out[off < 1.0] = 0    # his blade itself shows through
    else:
        out[erode(him)] = 0    # not on him, but up to his art's edge: core/sprite.gdshader doesn't draw that dark line, and a gap would show
    a = out[..., 3]
    assert not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()), f'{view} {frame} touches its edge'    # never cut through art
    return out


def main():
    columns = len(POWER['F'])
    aura = np.zeros((CELL_H * FLAMES * len(VIEWS), CELL_W * columns, 4), np.uint8)
    side = np.asarray(Image.open('art/vulcan_boss/slam_S.png').convert('RGBA'))
    for v, view in enumerate(VIEWS):
        sheet = np.asarray(Image.open(f'art/vulcan_boss/slam_{view}.png').convert('RGBA')).copy()
        frames = [frame for frame in range(columns) if (view, frame) in NO_BLADE]
        for frame in frames:
            stand_blade(sheet, frame, BLADES[view][frame], side)
        if frames:
            Image.fromarray(sheet, 'RGBA').save(f'art/vulcan_boss/slam_{view}.png')
        for frame in range(columns):
            for flames in range(FLAMES):
                y, x = (v * FLAMES + flames) * CELL_H, frame * CELL_W
                aura[y:y + CELL_H, x:x + CELL_W] = cell(view, frame, sheet, 1000 * v + 100 * frame + flames)
    Image.fromarray(aura, 'RGBA').save('art/sword_aura/aura.png')
    print('aura', aura.shape[1], 'x', aura.shape[0])


main()
