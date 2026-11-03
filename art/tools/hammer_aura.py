"""Hammer Blow's giant ghostly hammer, two looks from one shape. The shape is a clean silhouette of the hammer in the user's own picture (D:/SmartRig/spike/web/mem_hammer_user.png): a block head with a round rivet and a long wooden handle. Nothing is generated.
  uv run --with pillow --with numpy python art/tools/hammer_aura.py
Writes art/hammer_aura/plain.png and fire.png, read by fx/hammer_aura.gd. One column per frame of hammer_blow_S up to the strike, each cell with the grip at its middle so the game only has to place the grip in his hand; one row per look of it, the last the white flash of the strike. Fire has three rows of flame: only the flames differ between them.
"""
import numpy as np
from PIL import Image, ImageDraw

CELL = 304          # px, even: every texel lands on one screen pixel
SS = 4              # drawn and turned this many times bigger, then brought down by block majority, so edges stay clean
ANGLES = [-99, -71, -71, -41, -17, -17, 16, 84]    # degrees clockwise from straight up, facing right: the sword's own in each frame of hammer_blow_S, measured off the sheet. Frame 7, the strike, is 8 more than the sword's 76 so the head's face comes down nearly flat on the floor; the handle still covers the sword. Claude's call
GROWN = [0.12, 0.24, 0.36, 0.5, 0.62, 0.75, 0.92, 1.0]    # how much of it has formed by each frame: it comes out of his hand, along the sword, and is whole as it strikes. Claude's call: this also keeps its flames on screen at the top of the leap (tests/test_hammer_aura.gd)
# Sizes in screen px: he stands about 50 tall, so about 2.9 times that. Claude's call
LENGTH, GRIP = 118, 8           # butt to head's top; butt to the grip, the point it turns about: held by the very end, so none of it pokes back through him
HEAD_W, HEAD_H = 104, 60        # across the handle; along it
FLAMES = 3
HEART = 7          # px in from the head's edge that the iron stays dark at its heart
CLEAR = 30         # px round the grip with no flame: his fist has to show on the handle, and his face is about this far away. Claude's call

EMPTY, HANDLE, BAND, COLLAR, HEAD, BEVEL, RIVET, EYE = range(8)
HEADISH = (HEAD, BEVEL, RIVET, EYE)

# (r, g, b, a) by part. See-through but strong, with a brighter edge.
GOLD = {HANDLE: (255, 232, 160, 150), BAND: (255, 244, 200, 215), COLLAR: (255, 244, 200, 215), HEAD: (255, 232, 160, 135), BEVEL: (255, 244, 200, 190), RIVET: (255, 252, 232, 255), EYE: (212, 142, 52, 215)}
GOLD_EDGE = (255, 252, 232, 255)
GOLD_INNER = (255, 224, 132, 230)
GOLD_HALO = (255, 214, 92, 110)
# fx/effect.gd's FIRE, white-hot to dark red.
WHITE, YELLOW, ORANGE, RED = (255, 246, 214), (255, 214, 92), (232, 104, 30), (120, 30, 18)
BURN = {HANDLE: (*RED, 215), BAND: (*YELLOW, 240), COLLAR: (*YELLOW, 240), HEAD: (*ORANGE, 205), BEVEL: (*YELLOW, 230), RIVET: (*WHITE, 255), EYE: (*ORANGE, 230)}
BURN_EDGE = (*WHITE, 255)
BURN_INNER = (*YELLOW, 235)
FLASH_EDGE = (255, 255, 255, 255)
FLASH_FILL = (255, 246, 214, 235)


def upright(grown):
    """The hammer standing on its butt, grip at the middle, labelled by part at SS times the size. `grown` of it has formed: the handle first, out of the grip, then the head opening at its end."""
    im = Image.new('L', (CELL * SS, CELL * SS), EMPTY)
    d = ImageDraw.Draw(im)
    def box(x0, y0, x1, y1, label):    # in px from the grip, y down
        d.rectangle([CELL * SS // 2 + x0 * SS, CELL * SS // 2 + y0 * SS, CELL * SS // 2 + x1 * SS - 1, CELL * SS // 2 + y1 * SS - 1], fill=label)
    thick = min(grown / 0.6, 1.0)      # the handle thickens from about a blade's width
    opened = max((grown - 0.3) / 0.7, 0.0)    # the head starts once the handle is past the sword
    butt, top = round(GRIP * thick), -round((LENGTH - GRIP) * grown)
    h = round(HEAD_H * opened)
    neck = top + h
    c = CELL * SS // 2
    low, high = max(4 * thick, 2), max(7 * thick, 2)
    d.polygon([(c - low * SS, c + butt * SS), (c + low * SS, c + butt * SS), (c + high * SS, c + neck * SS), (c - high * SS, c + neck * SS)], fill=HANDLE)    # thin enough for his fist to close on it, thickening to the head. Claude's call
    cap = round(max(5 * thick, 3))
    box(-cap, butt - max(round(4 * thick), 2), cap, butt, COLLAR)        # butt cap
    for y in (-16, -8, 0):                      # the grip's wrapping
        if neck < y and y + 4 < butt:
            box(-cap, y, cap, y + 4, BAND)
    if h == 0:
        return im
    collar = round(max(11 * thick, 3))
    box(-collar, neck, collar, neck + 5, COLLAR)        # iron collar under the head
    w, cut, edge = round(HEAD_W * opened) // 2, round(8 * opened), round(7 * opened)
    d.polygon([(c + (-w + cut) * SS, c + top * SS), (c + (w - cut) * SS, c + top * SS), (c + w * SS, c + (top + cut) * SS), (c + w * SS, c + (top + h - cut) * SS),
               (c + (w - cut) * SS, c + (top + h) * SS), (c + (-w + cut) * SS, c + (top + h) * SS), (c - w * SS, c + (top + h - cut) * SS), (c - w * SS, c + (top + cut) * SS)], fill=HEAD)
    box(-w + cut, top, w - cut, top + edge, BEVEL)                          # the block's lit top
    box(-w, top + cut, -w + edge, top + h - cut, BEVEL)                     # its two striking faces
    box(w - edge, top + cut, w, top + h - cut, BEVEL)
    mid = (c, c + (top + h // 2) * SS)
    for r, label in ((13 * opened, RIVET), (9 * opened, EYE)):
        d.ellipse([mid[0] - r * SS, mid[1] - r * SS, mid[0] + r * SS, mid[1] + r * SS], fill=label)
    return im


def turned(shape, angle):
    a = np.asarray(shape.rotate(-angle, resample=Image.NEAREST))
    blocks = a.reshape(CELL, SS, CELL, SS).transpose(0, 2, 1, 3)
    votes = np.stack([(blocks == label).sum(axis=(2, 3)) for label in range(EYE + 1)])
    return votes.argmax(axis=0)


def erode(m):
    out = m.copy()
    out[1:] &= m[:-1]; out[:-1] &= m[1:]; out[:, 1:] &= m[:, :-1]; out[:, :-1] &= m[:, 1:]
    out[0] = out[-1] = False; out[:, 0] = out[:, -1] = False
    return out


def dilate(m):
    out = m.copy()
    out[1:] |= m[:-1]; out[:-1] |= m[1:]; out[:, 1:] |= m[:, :-1]; out[:, :-1] |= m[:, 1:]
    return out


def body(labels, fill, edge, inner):
    """A cell's picture: each part's fill, the head ringed apart from the handle, a brighter edge all round."""
    out = np.zeros((CELL, CELL, 4), np.uint8)
    for label, colour in fill.items():
        out[labels == label] = colour
    mask = labels != EMPTY
    head = np.isin(labels, HEADISH)
    rivet = labels == RIVET
    out[(head & ~erode(head) & mask) | (mask & ~erode(mask))] = edge
    second = (erode(mask) & ~erode(erode(mask))) & ~rivet
    out[second] = inner
    return out, mask


def flash(mask):
    out = np.zeros((CELL, CELL, 4), np.uint8)
    out[mask] = FLASH_FILL
    out[mask & ~erode(mask)] = FLASH_EDGE
    return out


def tongues(width, rng, low, high):
    """Flame length per column or row: round-topped lobes six to twelve wide."""
    h = np.zeros(width)
    x = 0
    while x < width:
        w = int(rng.integers(6, 13))
        tall = rng.integers(low, high)
        for i in range(w):
            if x + i < width:
                h[x + i] = tall * (1.0 - (abs(i - (w - 1) / 2) / (w / 2)) ** 2) + 1
        x += w
    return h


def flame(out, mask, x, y, f):
    if 0 <= x < CELL and 0 <= y < CELL and not mask[y, x] and (x - CELL / 2) ** 2 + (y - CELL / 2) ** 2 >= CLEAR ** 2:
        out[y, x] = (*YELLOW, 255) if f < 0.45 else (*ORANGE, 255) if f < 0.85 else (*RED, 230)


def burn(labels, seed, grown):
    """The burning hammer: iron glowing in from its edges, flames licking up from every edge that faces up and curling up off its sides, shorter while it's still forming. Only the flames differ between the rows."""
    out, mask = body(labels, BURN, BURN_EDGE, BURN_INNER)
    heart = labels == HEAD
    for _ in range(HEART):
        heart = erode(heart)
    out[heart] = (*RED, 190)
    rng = np.random.default_rng(seed)
    up, side = tongues(CELL, rng, max(round(8 * grown), 2), max(round(25 * grown), 3)), tongues(CELL, rng, max(round(3 * grown), 1), max(round(10 * grown), 2))
    for x in range(CELL):
        for y in np.nonzero(mask[:, x] & ~np.roll(mask[:, x], 1))[0]:    # the top of each run of the shape in this column
            n = int(up[x])
            for k in range(1, n + 1):
                if mask[y - k, x]:
                    break
                flame(out, mask, x, y - k, k / n)
    for y in range(CELL):
        n = int(side[y])
        for way, edges in ((-1, mask[y] & ~np.roll(mask[y], 1)), (1, mask[y] & ~np.roll(mask[y], -1))):
            for x in np.nonzero(edges)[0]:
                for k in range(1, n + 1):
                    flame(out, mask, x + way * k, y - k // 2, k / n)
                    flame(out, mask, x + way * k, y - k // 2 - 1, k / n)
    sparks = rng.random((CELL, CELL)) < 0.012    # embers lifting off, a few px clear of the flames
    near = out[..., 3] > 0
    for _ in range(6):
        near = dilate(near)
    ys, xs = np.ogrid[:CELL, :CELL]
    out[near & (out[..., 3] == 0) & sparks & ((xs - CELL / 2) ** 2 + (ys - CELL / 2) ** 2 >= CLEAR ** 2)] = (*YELLOW, 255)
    return out


def main():
    cells = [turned(upright(g), a) for a, g in zip(ANGLES, GROWN)]
    plain = np.zeros((CELL * 2, CELL * len(ANGLES), 4), np.uint8)
    fire = np.zeros((CELL * (FLAMES + 1), CELL * len(ANGLES), 4), np.uint8)
    for i, labels in enumerate(cells):
        x = i * CELL
        cell, mask = body(labels, GOLD, GOLD_EDGE, GOLD_INNER)
        cell[dilate(mask) & ~mask] = GOLD_HALO
        plain[0:CELL, x:x + CELL] = cell
        plain[CELL:CELL * 2, x:x + CELL] = flash(mask)
        for row in range(FLAMES):
            fire[row * CELL:(row + 1) * CELL, x:x + CELL] = burn(labels, 1000 * i + row, GROWN[i])
        fire[FLAMES * CELL:(FLAMES + 1) * CELL, x:x + CELL] = flash(mask)
    for name, sheet in (('plain', plain), ('fire', fire)):
        for y in range(sheet.shape[0] // CELL):    # never cut through art
            for x in range(sheet.shape[1] // CELL):
                a = sheet[y * CELL:(y + 1) * CELL, x * CELL:(x + 1) * CELL, 3]
                assert not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()), f'{name} cell {x},{y} touches its edge'
        Image.fromarray(sheet, 'RGBA').save(f'art/hammer_aura/{name}.png')
        print(name, sheet.shape[1], 'x', sheet.shape[0])


main()
