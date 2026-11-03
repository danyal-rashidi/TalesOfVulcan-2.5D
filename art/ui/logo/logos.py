# Three pixel-art logo concepts for Tales of Vulcan. Hard pixels only: every shape is a bool mask,
# letters are hand-drawn bitmaps grown with Scale2x/Scale3x (no anti-aliasing), no black anywhere.
import numpy as np
from PIL import Image
from pathlib import Path

OUT = Path(__file__).parent


def hx(c):
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


# ---------- fonts ----------
BIG = {  # chunky sans, 2-cell strokes
    'V': ["XX....XX", "XX....XX", "XX....XX", ".XX..XX.", ".XX..XX.", ".XX..XX.", "..XXXX..", "..XXXX..", "...XX..."],
    'U': ["XX....XX", "XX....XX", "XX....XX", "XX....XX", "XX....XX", "XX....XX", "XXX..XXX", ".XXXXXX.", "..XXXX.."],
    'L': ["XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XX.....", "XXXXXXX", "XXXXXXX"],
    'C': ["..XXXXX.", ".XXXXXXX", "XXX...XX", "XX......", "XX......", "XX......", "XXX...XX", ".XXXXXXX", "..XXXXX."],
    'A': ["..XXXX..", ".XXXXXX.", "XXX..XXX", "XX....XX", "XXXXXXXX", "XXXXXXXX", "XX....XX", "XX....XX", "XX....XX"],
    'N': ["XX....XX", "XXX...XX", "XXXX..XX", "XX.XX.XX", "XX..XXXX", "XX...XXX", "XX....XX", "XX....XX", "XX....XX"],
}
SERIF = {  # Roman thick/thin with serifs
    'V': ["XXXX..XXX", ".XX....X.", ".XX....X.", "..XX...X.", "..XX..X..", "..XX..X..", "...XX.X..", "...XXX...", "...XXX...", "....X....", "....X...."],
    'U': ["XXXX..XXX", ".XX....X.", ".XX....X.", ".XX....X.", ".XX....X.", ".XX....X.", ".XX....X.", ".XX....X.", ".XX...XX.", "..XXXXX..", "...XXX..."],
    'L': ["XXXX.....", ".XX......", ".XX......", ".XX......", ".XX......", ".XX......", ".XX......", ".XX......", ".XX....X.", ".XX...XX.", "XXXXXXXX."],
    'C': ["...XXXXX.", ".XXX...XX", ".XX.....X", "XX.......", "XX.......", "XX.......", "XX.......", "XX.......", ".XX.....X", ".XXX...XX", "...XXXXX."],
    'A': ["....X....", "...XXX...", "...XXX...", "..X.XX...", "..X.XX...", "..X..XX..", ".XXXXXX..", ".X....XX.", ".X....XX.", ".X....XX.", "XXX..XXXX"],
    'N': ["XXX...XXX", ".XXX...X.", ".XXX...X.", ".X.XX..X.", ".X.XX..X.", ".X..XX.X.", ".X..XX.X.", ".X...XXX.", ".X...XXX.", ".X....XX.", "XXX....X."],
}
SMALL = {
    'T': ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
    'A': [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    'L': ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
    'E': ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
    'S': [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
    'O': [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    'F': ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
}


def word(text, font, gap=1, space=3):
    h = len(next(iter(font.values())))
    cols, spans = [], []
    for ch in text:
        if ch == ' ':
            cols += [np.zeros((h, space), bool)]
            continue
        g = np.array([[c == 'X' for c in r] for r in font[ch]])
        if cols:
            cols.append(np.zeros((h, gap), bool))
        start = sum(c.shape[1] for c in cols)
        cols.append(g)
        spans.append((start, start + g.shape[1]))
    return np.hstack(cols), spans


def _nb(m):
    P = np.pad(m, 1)
    return P[:-2, :-2], P[:-2, 1:-1], P[:-2, 2:], P[1:-1, :-2], m, P[1:-1, 2:], P[2:, :-2], P[2:, 1:-1], P[2:, 2:]


def scale2x(m):
    A, B, C, D, E, F, G, H, I = _nb(m)
    o = np.zeros((m.shape[0] * 2, m.shape[1] * 2), bool)
    o[0::2, 0::2] = np.where((D == B) & (B != F) & (D != H), D, E)
    o[0::2, 1::2] = np.where((B == F) & (B != D) & (F != H), F, E)
    o[1::2, 0::2] = np.where((D == H) & (D != B) & (H != F), D, E)
    o[1::2, 1::2] = np.where((H == F) & (D != H) & (B != F), F, E)
    return o


def scale3x(m):
    A, B, C, D, E, F, G, H, I = _nb(m)
    c1 = (D == B) & (B != F) & (D != H)
    c2 = (B == F) & (B != D) & (F != H)
    c3 = (D == H) & (D != B) & (H != F)
    c4 = (H == F) & (D != H) & (B != F)
    o = np.zeros((m.shape[0] * 3, m.shape[1] * 3), bool)
    o[0::3, 0::3] = np.where(c1, D, E)
    o[0::3, 1::3] = np.where((c1 & (E != C)) | (c2 & (E != A)), B, E)
    o[0::3, 2::3] = np.where(c2, F, E)
    o[1::3, 0::3] = np.where((c1 & (E != G)) | (c3 & (E != A)), D, E)
    o[1::3, 1::3] = E
    o[1::3, 2::3] = np.where((c2 & (E != I)) | (c4 & (E != C)), F, E)
    o[2::3, 0::3] = np.where(c3, D, E)
    o[2::3, 1::3] = np.where((c3 & (E != I)) | (c4 & (E != G)), H, E)
    o[2::3, 2::3] = np.where(c4, F, E)
    return o


# ---------- canvas helpers ----------
def shift(m, dy=0, dx=0):
    o = np.zeros_like(m)
    H, W = m.shape
    o[max(dy, 0):H + min(dy, 0), max(dx, 0):W + min(dx, 0)] = m[max(-dy, 0):H + min(-dy, 0), max(-dx, 0):W + min(-dx, 0)]
    return o


def dil(m):
    return m | shift(m, 1) | shift(m, -1) | shift(m, 0, 1) | shift(m, 0, -1)


def place(shape, m, ox, oy):
    o = np.zeros(shape, bool)
    o[oy:oy + m.shape[0], ox:ox + m.shape[1]] = m
    return o


def paint(cv, m, col):
    cv[m] = hx(col) if isinstance(col, str) else col


def ramp_v(m, ramp):
    """Colour each pixel by its row within the mask's bounding box."""
    ys = np.where(m.any(1))[0]
    y0, y1 = ys[0], ys[-1] + 1
    yy = np.arange(m.shape[0])[:, None].repeat(m.shape[1], 1)
    idx = np.clip((yy - y0) * len(ramp) // max(y1 - y0, 1), 0, len(ramp) - 1)
    pal = np.array([hx(c) for c in ramp], np.uint8)
    return pal[idx]


def text(cv, M, colors, extrude, edge, hi):
    """Face colours (HxWx4 array), stepped extrusion down, outline, top-edge highlight."""
    E = np.zeros_like(M)
    for d, c in enumerate(extrude, 1):
        s = shift(M, d) & ~M & ~E
        paint(cv, s, c)
        E |= s
    paint(cv, dil(M | E) & ~(M | E), edge)
    cv[M] = colors[M]
    paint(cv, M & ~shift(M, 1), hi)


def outlined(cv, m, edge):
    paint(cv, dil(m) & ~m, edge)


def sparks(cv, pts, cols):
    for i, (x, y, big) in enumerate(pts):
        c = hx(cols[i % len(cols)])
        if big:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                cv[y + dy, x + dx] = c
            cv[y, x] = hx('#fffbe6')
        else:
            cv[y, x] = c


def save(cv, name):
    im = Image.fromarray(cv, 'RGBA')
    im.save(OUT / f'{name}.png')
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(OUT / f'{name}_4x.png')


def uv(H, W):
    ys, xs = np.mgrid[0:H, 0:W]
    return xs + ys, xs - ys, xs, ys


# ---------- concept 1: ember forge ----------
def forge():
    H, W = 100, 200
    cv = np.zeros((H, W, 4), np.uint8)
    u, v, xs, ys = uv(H, W)
    U0, VH = 178, 126
    du, dv = u - U0, v - VH
    haft = (abs(du) <= 3) & (v >= 6) & (v < 112)
    ring = (abs(du) <= 5) & (v >= 0) & (v < 6)
    head = (abs(dv) <= 14) & (abs(du) <= 26) & ~((abs(dv) >= 12) & (abs(du) >= 24))
    ham = haft | ring | head
    outlined(cv, ham, '#2c1a4c')
    wood = np.where(du <= -2, 0, np.where(du <= 0, 1, np.where(du <= 2, 2, 3)))
    for i, c in enumerate(['#f0b070', '#c87a44', '#8e4c4a', '#5e3050']):
        paint(cv, haft & (wood == i), c)
    paint(cv, haft & ((v % 10) < 2) & (v < 30), '#5e3050')  # grip wraps
    paint(cv, ring, '#9a9ccf')
    paint(cv, ring & (du <= -3), '#e8e8fa')
    paint(cv, head, '#a6a8d6')
    paint(cv, head & (dv <= -11), '#6e68a8')
    paint(cv, head & (dv >= 11), '#cfd1ee')
    paint(cv, head & (du <= -23), '#f2f2ff')
    paint(cv, head & (du >= 22), '#ff8a36')  # striking face, still molten
    paint(cv, head & (du >= 24), '#ffd060')
    paint(cv, head & (abs(du) == 15) & (abs(dv) < 13), '#7a74b0')
    paint(cv, head & (abs(du) + abs(dv) <= 6), '#ff7a2e')
    paint(cv, head & (abs(du) + abs(dv) <= 3), '#ffc040')
    paint(cv, head & (abs(du) + abs(dv) <= 1), '#fff3b0')

    sparks(cv, [(183, 6, 1), (192, 16, 0), (176, 2, 0), (196, 30, 1), (188, 44, 0), (171, 12, 0),
                (128, 20, 0), (122, 30, 1), (194, 4, 0), (180, 50, 0)],
           ['#ffd060', '#ff8a36', '#ff5a6a', '#fff3b0'])

    tw, _ = word('TALES OF', SMALL)
    t = place((H, W), scale2x(tw), 22, 34)
    text(cv, t, ramp_v(t, ['#fff8dc', '#ffe9a0', '#ffd070', '#f0a850']), ['#a8406a', '#7a2a62'], '#3a0f2e', '#fffdf0')
    vw, _ = word('VULCAN', BIG)
    m = place((H, W), scale3x(vw), 20, 56)
    text(cv, m, ramp_v(m, ['#fff3b0', '#ffdd60', '#ffc038', '#ffa030', '#ff7a2e', '#f25838', '#d83a4a']),
         ['#b02a58', '#8a2260', '#6a1e5e', '#4e1a52'], '#3a0f2e', '#fffbe6')
    save(cv, 'logo1_ember_forge')


# ---------- concept 2: the split crown ----------
def crown():
    H, W = 106, 220
    cv = np.zeros((H, W, 4), np.uint8)
    ys, xs = np.mgrid[0:H, 0:W]
    base = 30
    m = (xs >= 80) & (xs <= 140) & (ys >= base) & (ys <= base + 8)
    m |= (xs >= 77) & (xs <= 143) & (ys >= base + 7) & (ys <= base + 10)
    for sx, h in [(84, 12), (97, 17), (110, 23), (123, 17), (136, 12)]:
        top = base - h
        hw = np.clip((ys - top) * 6 // h, 0, 6)
        m |= (ys >= top) & (ys < base) & (abs(xs - sx) <= hw)
        m |= (xs - sx) ** 2 + (ys - (top - 2)) ** 2 <= 5
    gems = np.zeros_like(m)
    for gx in (97, 110, 123):
        gems |= (abs(xs - gx) + abs(ys - (base + 4)) <= 3)
    zig = np.array([0, 1, 2, 1, 0, -1, -2, -1])[(ys // 3) % 8]
    cut = 110 + zig
    left, right = m & (xs < cut), m & (xs > cut)
    gl, gr = gems & (xs < cut), gems & (xs > cut)
    L, R = shift(left, 0, -2), shift(right, 3, 3)
    GL, GR = shift(gl, 0, -2), shift(gr, 3, 3)
    crackR = shift(right & (((xs - 112) == (ys - 10) // 2) | ((xs - 126) == -(ys - 26) // 2) & (ys > 20)), 3, 3) & ~GR
    outlined(cv, L, '#4a1430')
    outlined(cv, R, '#24164a')
    cv[L] = ramp_v(L, ['#fff6c0', '#ffe070', '#ffc040', '#f09a30', '#e07a3a'])[L]
    paint(cv, L & ~shift(L, 1), '#fffbe6')
    paint(cv, L & ~shift(L, -1), '#b8504a')
    paint(cv, GL, '#ff4a5a')
    paint(cv, GL & ~shift(GL, 1), '#ffb8a8')
    cv[R] = ramp_v(R, ['#f2d4ff', '#d4a0f5', '#ad72e6', '#8a52d0', '#6a3cb0'])[R]
    paint(cv, R & ~shift(R, 1), '#faeaff')
    paint(cv, R & ~shift(R, -1), '#4e3090')
    paint(cv, GR, '#4e3090')
    paint(cv, crackR, '#ff70b0')
    # the crown's red light fleeing upward from the split
    sparks(cv, [(112, 2, 1), (117, 9, 0), (106, 6, 0), (120, 3, 0), (101, 1, 0), (125, 12, 0)],
           ['#ff5a7a', '#ffa0c0', '#ff4a5a'])

    tw, _ = word('TALES OF', SMALL)
    tm = scale2x(tw)
    t = place((H, W), tm, (W - tm.shape[1]) // 2, 46)
    text(cv, t, ramp_v(t, ['#fff3c0', '#ffd870', '#f0b040', '#d88a38']), ['#7a56b0'], '#2a1850', '#fffbe6')
    for x0 in ((W - tm.shape[1]) // 2 - 22, (W + tm.shape[1]) // 2 + 6):  # inscription rules
        bar = (xs >= x0) & (xs < x0 + 16) & (ys >= 52) & (ys <= 53)
        dia = abs(xs - (x0 + 8)) + abs(ys - 52) <= 2
        outlined(cv, bar | dia, '#2a1850')
        paint(cv, bar | dia, '#ffd870')
        paint(cv, (bar | dia) & (ys <= 51), '#fff3c0')
    vw, _ = word('VULCAN', SERIF)
    vm = scale3x(vw)
    m2 = place((H, W), vm, (W - vm.shape[1]) // 2, 64)
    text(cv, m2, ramp_v(m2, ['#fffdf2', '#fbf0d4', '#f3dfb4', '#ecc9a0', '#e0a8a8', '#c898c8']),
         ['#8a64c0', '#6a4aa8', '#4e3490'], '#24164a', '#ffffff')
    save(cv, 'logo2_split_crown')


def crown_text():
    """Danyal: keep only the text of the split crown. Same letters and colours, no crown, sparks or rules, cropped tight."""
    H, W = 64, 220
    cv = np.zeros((H, W, 4), np.uint8)
    tm = scale2x(word('TALES OF', SMALL)[0])
    t = place((H, W), tm, (W - tm.shape[1]) // 2, 4)
    text(cv, t, ramp_v(t, ['#fff3c0', '#ffd870', '#f0b040', '#d88a38']), ['#7a56b0'], '#2a1850', '#fffbe6')
    vm = scale3x(word('VULCAN', SERIF)[0])
    m2 = place((H, W), vm, (W - vm.shape[1]) // 2, 22)
    text(cv, m2, ramp_v(m2, ['#fffdf2', '#fbf0d4', '#f3dfb4', '#ecc9a0', '#e0a8a8', '#c898c8']),
         ['#8a64c0', '#6a4aa8', '#4e3490'], '#24164a', '#ffffff')
    ys, xs = np.nonzero(cv[..., 3])
    save(cv[max(ys.min() - 2, 0):ys.max() + 3, max(xs.min() - 2, 0):xs.max() + 3], 'logo_tales_of_vulcan')


GOLD = (['#fff6c0', '#ffe070', '#ffc040', '#f09a30', '#e07a3a'], ['#b8504a', '#8a2a40', '#4a1430'], '#4a1430', '#fffbe6')
VIOLET = (['#f2d4ff', '#d4a0f5', '#ad72e6', '#8a52d0', '#6a3cb0'], ['#4e3090', '#3a2470', '#24164a'], '#24164a', '#faeaff')


def tips(m, spans, k):
    """Crown points: a ball-tipped spike on each top end of every letter. spans are the letters' columns before scaling by k."""
    out = np.zeros_like(m)
    ys, _ = np.nonzero(m)
    top = ys.min()
    for a, b in spans:
        row = m[top, a * k:b * k]
        runs = np.flatnonzero(np.diff(np.r_[0, row.astype(int), 0]))
        for s, e in zip(runs[::2], runs[1::2]):
            cx = a * k + (s + e - 1) // 2
            for d, half in ((1, 2), (2, 2), (3, 1), (4, 1), (5, 0)):    # spike narrows upward, 5 wide to 1
                out[top - d, cx - half:cx + half + 1] = True
            out[top - 8:top - 5, cx - 1:cx + 2] = True    # the ball on its tip
    return out


def split_crown(crowned):
    """Danyal: the font itself in the split crown's theme. The word breaks down a jagged crack after VUL: gold on the left,
    the right half violet and sunk like the crown's broken half, glowing pink along the break. crowned: crown points on the letters."""
    H, W = 84, 220
    cv = np.zeros((H, W, 4), np.uint8)
    ys, xs = np.mgrid[0:H, 0:W]
    tw, tsp = word('TALES OF', SMALL)
    tm = scale2x(tw)
    tx = (W - tm.shape[1]) // 2
    t = place((H, W), tm, tx, 4)
    vw, vsp = word('VULCAN', SERIF)
    vm = scale3x(vw)
    vx, vy = (W - vm.shape[1]) // 2, 36
    v = place((H, W), vm, vx, vy)
    if crowned:
        v |= place((H, W), tips(np.pad(vm, ((10, 0), (0, 0))), vsp, 3), vx, vy - 10) & (ys < vy)
    cut = np.where(ys < vy - 12, tx + tsp[4][1] * 2 + 3, vx + (vsp[2][1] + vsp[3][0]) * 3 // 2)    # after TALES, after VUL
    left, right = (t | v) & (xs < cut), shift((t | v) & (xs > cut), 2, 2)
    # hairline cracks down the broken half's letters, a zigzag a third of the way into each
    zig = np.array([0, 1, 1, 0, -1, -1])[(ys // 2) % 6]
    crack = np.zeros_like(right)
    for a, b in vsp[3:]:
        crack |= (xs == vx + 2 + a * 3 + (b - a) * 3 // 3 + zig) & (ys > vy + 4) & (ys < vy + 30)
    crack &= right & shift(right, 1) & shift(right, -1)    # inside the letters, not on their edges
    for m, (face, ext, edge, hi) in ((right, VIOLET), (left, GOLD)):
        text(cv, m, ramp_v(m, face), ext, edge, hi)
    paint(cv, crack, '#ff70b0')
    yy, xx = np.nonzero(cv[..., 3])
    name = 'logo_split_font_crowned' if crowned else 'logo_split_font'
    save(cv[max(yy.min() - 2, 0):yy.max() + 3, max(xx.min() - 2, 0):xx.max() + 3], name)


# ---------- concept 3: fire and ice ----------
def fire_ice():
    H, W, OY = 108, 220, 8  # OY: headroom for the flames
    cv = np.zeros((H, W, 4), np.uint8)
    u, v, xs, ys = uv(H, W)
    u, v = u - OY, v + OY
    VS, US = 50, 170
    # flaming sword: tip top-left, hilt bottom-right
    hwb = np.clip((u - 54) // 4, 0, 3)
    blade = (u >= 54) & (u < 206) & (abs(v - VS) <= hwb)
    guard = (u >= 206) & (u < 212) & (abs(v - VS) <= 11)
    grip = (u >= 212) & (u < 232) & (abs(v - VS) <= 2)
    pom = (u >= 232) & (u < 240) & (abs(v - VS) <= 4)
    sword = blade | guard | grip | pom
    # ice spear: butt bottom-left, tip top-right
    hws = np.where(v < 120, 2 + (v - 102) * 6 // 18, (164 - v) * 8 // 44)
    head = (v >= 102) & (v <= 164) & (abs(u - US) <= hws)
    shaft = (v >= -30) & (v < 96) & (abs(u - US) <= 1)
    collar = (v >= 96) & (v < 102) & (abs(u - US) <= 3)
    spear = head | shaft | collar
    # flames rising off the blade
    flame = np.zeros((H, W), np.uint8)
    pat = [3, 6, 9, 5, 2, 7, 11, 6, 3, 8, 5, 10, 4]
    for x in range(W):
        col = blade[:, x] & (u[:, x] < 196)
        if not col.any():
            continue
        top = np.argmax(col)
        h = pat[x % len(pat)]
        for k in range(1, h + 1):
            if top - k >= 0:
                flame[top - k, x] = 1 + min(4, (k - 1) * 5 // h)
    fm = flame > 0
    outlined(cv, sword | fm, '#4a1430')
    outlined(cv, spear, '#24164a')
    for i, c in enumerate(['#fff4c0', '#ffd050', '#ff9030', '#ff5a4a', '#f04a7a'], 1):
        paint(cv, flame == i, c)
    side = v - VS  # >0 is the upper-right edge of the blade
    paint(cv, blade, '#ffd27a')
    paint(cv, blade & (side >= 1), '#fffbe0')
    paint(cv, blade & (side <= -2), '#ff8a4a')
    paint(cv, blade & (side <= -3), '#e0506a')
    paint(cv, guard, '#ffc040')
    paint(cv, guard & (u == 206), '#fff3b0')
    paint(cv, guard & (u == 211), '#c8603e')
    paint(cv, grip, '#8e4c4a')
    paint(cv, grip & (side >= 1), '#c87a44')
    paint(cv, grip & ((u % 4) == 0), '#5e3050')
    paint(cv, pom, '#ffc040')
    paint(cv, pom & (u < 235) & (side >= 0), '#fff3b0')
    sp = u - US  # <0 is the upper-left edge
    paint(cv, shaft, '#5a7ad8')
    paint(cv, shaft & (sp < 0), '#9ac0f8')
    paint(cv, shaft & (sp > 0), '#3c4aa0')
    paint(cv, collar, '#c8d0f0')
    paint(cv, collar & (sp > 1), '#7a7ac0')
    paint(cv, head, '#7fd6ff')
    paint(cv, head & (sp < 0), '#d8f6ff')
    paint(cv, head & (sp == 0), '#ffffff')
    paint(cv, head & (sp >= 2), '#4a9cf0')
    paint(cv, head & (sp >= 4), '#5a5cd0')

    sparks(cv, [(30, 48, 1), (20, 68, 0), (40, 32, 0), (14, 38, 0), (36, 92, 1), (26, 14, 0)],
           ['#ffd060', '#ff8a36', '#ff5a6a'])
    sparks(cv, [(196, 34, 1), (206, 56, 0), (192, 16, 0), (210, 78, 1), (182, 96, 0), (200, 98, 0)],
           ['#bdf0ff', '#7fd6ff', '#c8b0ff'])

    tw, _ = word('TALES OF', SMALL)
    tm = scale2x(tw)
    t = place((H, W), tm, (W - tm.shape[1]) // 2, 28 + OY)
    text(cv, t, ramp_v(t, ['#fffdf2', '#fbefd0', '#f0d8b0', '#d8c0d8']), ['#5a2f7a'], '#2a1640', '#ffffff')

    vw, spans = word('VULCAN', BIG)
    vm = scale3x(vw)
    h = vm.shape[0]
    ital = np.zeros((h, vm.shape[1] + h // 3 + 1), bool)
    for y in range(h):  # italic: 1 px every 3 rows
        s = (h - 1 - y) // 3
        ital[y, s:s + vm.shape[1]] = vm[y]
    ox, oy = (W - ital.shape[1]) // 2, 48 + OY
    m = place((H, W), ital, ox, oy)
    fams = [['#fff4b8', '#ffd85a', '#ffb030', '#f08a2a'], ['#ffe0a0', '#ffaa48', '#ff7a30', '#e8503a'],
            ['#ffd0c8', '#ff8a8a', '#f0566e', '#c83c6a'], ['#f0d0ff', '#c89af5', '#9a6ae0', '#7048c0'],
            ['#d8ecff', '#8ac0ff', '#5a8cf0', '#4a5cd0'], ['#e8ffff', '#9af0ff', '#4ac8f5', '#3a8ae0']]
    colors = np.zeros((H, W, 4), np.uint8)
    for (a, b), fam in zip(spans, fams):
        lm = np.zeros_like(ital)
        for y in range(h):
            s = (h - 1 - y) // 3
            lm[y, s + a * 3:s + b * 3] = ital[y, s + a * 3:s + b * 3]
        lm = place((H, W), lm, ox, oy)
        colors[lm] = ramp_v(m, fam)[lm]
    text(cv, m, colors, ['#7a3a8c', '#5a2f7a', '#4a2a6e', '#3b2160'], '#2a1640', '#ffffff')
    save(cv, 'logo3_fire_and_ice')


if __name__ == '__main__':
    assert scale2x(np.ones((1, 1), bool)).sum() == 4 and scale3x(np.eye(3, dtype=bool)).sum() == 3 * 9 + 4  # diagonal gets its steps filled
    forge()
    crown()
    crown_text()
    split_crown(False)
    split_crown(True)
    fire_ice()
