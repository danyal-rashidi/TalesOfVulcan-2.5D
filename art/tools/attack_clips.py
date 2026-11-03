"""His three real attacks from clips (Danyal: "2 consecutive slashes that are different from each other for light attack, and 1 heavy attack that looks different"): the hand-picked frames of each clip become light1_*, light2_* and heavy_*, a sheet for every view, left-facing too, since a mirror would swap his sword's hand. They replace the one borrowed swing.
  uv run --with pillow --with numpy --with scipy --with imageio-ffmpeg python art/tools/attack_clips.py
Then art/tools/smaller_head.py (it leaves these alone) and new_sword_sheets.py. Clips: D:/SmartRig/spike/web/clips/vulcan_{light1,light2,heavy}_{S,L,F,B}.mp4, Seedance 2.0 Mini, 4 s, 480p. The model bakes in blood, sparks and white arcs while the blade moves, so those frames are never picked, and the blade's way down or up borrows the clean frames of the same arm on its way up or down.
Taller than his other sheets, and with room at the sides, so no blade is cropped ("w" in the manifest: core/character_sprite.gd). Every frame gets his approved head, with what the clip has in front of it kept in front.
"""
import glob, json, os, shutil, subprocess, sys, tempfile
import imageio_ffmpeg
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, binary_erosion, binary_fill_holes, distance_transform_edt, label, uniform_filter

sys.path.insert(0, os.path.dirname(__file__))
import new_sword_sheets as sword
import smaller_head as heads
import steady_sheets as steady

FOLDER = "art/vulcan_human"
CLIPS = "/mnt/d/SmartRig/spike/web/clips"
MASTER = os.path.abspath("art/guides/ref_vulcan_human.png")
SMARTRIG = "/home/danye/orca/workspaces/SmartRigApp/Smartrig-animation-app"
CUTTER = "/mnt/d/SmartRig/spike/elvis/ad/video_to_sprites.py"
STEEL = ["150,156,168", "100,106,118", "205,210,222"]
STEELS = np.array([(205, 210, 222), (150, 156, 168), (100, 106, 118)])    # glint, lit side, shade
WIDE = 104           # px a frame: light2's high blade from behind reaches 47 px from his middle, and the new sword is 2 px longer
TOP = 3              # rows clear over the highest blade, for the same reason
FEET = 110           # his feet's row on the canvas he's cut on, before it's trimmed to what the frames use
HALF_BLADE = 3.0     # px either side of a blade's line
RECOVERY = 3         # frames at a swing's end, on their way back to his stand
FOOT_ROWS = 8        # from his soles up: what has to stay on the same pixels while a foot is planted
TIDY_FEET = 12       # rows up from his soles left as they are
TIDY_DOT = 3         # px: a speck
SETTLE_AROUND = 5    # px a side: the patch of a recovery frame that has to lie as the stand does before it takes the stand's shades
SETTLE_SHARE = 0.85  # of that patch
PLANTED = 0.72       # of a foot band's pixels in the same place as before: it hasn't moved, and the rest is the video model redrawing it
SHADOW_HOLE = 12     # px: smaller, a gap by his head is the shadow there, not the sand showing through him
SAME_POSE = 0.85     # of his outline's area in common with the frame before, once lined up: the same pose, so its shades carry over

# A clip's frames, with its stand first: the stand sets his size and place, as a clip is made from his stand picture at whatever size.
LIGHT1 = {"S": (8, 18, 33, 35, 43, 43, 69, 72, 76), "L": (8, 14, 12, 9, 48, 48, 66, 68, 72), "F": (13, 21, 40, 17, 54, 54, 67, 76, 78), "B": (6, 15, 28, 32, 44, 44, 70, 76, 84)}
LIGHT2 = {"S": (None, 13, 60, 30, 30, 59, 61, 63), "L": (None, 66, 63, 30, 30, 62, 65, 70), "F": (None, 9, 10, 24, 24, 62, 65, 70), "B": (None, 16, 17, 30, 30, 57, 61, 72)}
# His held heavy stands on pick 3 for as long as the button's down. Facing front and left, the clip's own frame for it (30, 36) came out with his fists a tangle on his hair, so it holds a clean raised frame of the same clip (HELD). Claude's call.
HEAVY = {"S": (4, 14, 24, 30, 41, 17, 48, 48, 78, 82, 86), "L": (3, 18, 29, 29, 46, 20, 54, 54, 78, 82, 86), "F": (1, 15, 17, 41, 41, 15, 79, 80, 81, 82, 84), "B": (8, 12, 24, 30, 41, 42, 54, 54, 72, 84, 86)}
# Seconds on each frame. Light: raising, held, the wrist cocks, the blade on its way, reaching the low pose at 0.22 s and holding it to the cancel at 0.35 s, then its recovery; light 2 starts on that same low pose. Heavy: a long wind-up with the blade down and its hit open from 0.29 s to 0.40 s, as the lunge's was. Claude's call.
TIMES = {"light1": (0.05, 0.09, 0.03, 0.05, 0.13, 0.10, 0.07, 0.07, 0.06), "light2": (0.03, 0.05, 0.05, 0.10, 0.17, 0.09, 0.08, 0.08), "heavy": (0.04, 0.05, 0.05, 0.08, 0.02, 0.05, 0.11, 0.15, 0.07, 0.07, 0.06)}
ACTIVE = {"light1": (4, 4), "light2": (1, 3), "heavy": (6, 6)}    # the blow lands as the blade arrives: light 1 and the heavy's frames before these still show it raised
REWIND = 0.05        # seconds a frame, back down his recovery frames when light 2 is pressed with him on his way up. It joins light 2 past its low pose: he's already risen, and dropping back into that crouch for 2 ticks read as a dip
OVERHEAD = 3         # heavy: the frame the hold stands in, and where the charged blow starts from
# The way the blade's tip cuts, for the game's mark (fx/slash.gd): x, then y from his feet (minus is up). From the tip's place in the frame the mark starts on (light 1 and the heavy: a frame before their hit) to its place as the hit lands, by eye between.
ARC = {
    "light1_S": [(26, -53), (53, -60), (72, -35), (78, -5)], "light1_L": [(25, -51), (13, -28), (35, -4), (68, -3)], "light1_F": [(11, -47), (8, -22), (35, 6), (77, -2)], "light1_B": [(81, -48), (58, -56), (30, -47), (14, -27), (11, -13)],
    "light2_S": [(78, -5), (90, -24), (92, -42), (85, -60)], "light2_L": [(40, -1), (17, -27), (9, -40), (13, -55)], "light2_F": [(77, -2), (84, -22), (74, -43), (45, -57), (9, -54)], "light2_B": [(11, -13), (14, -27), (30, -47), (60, -55), (95, -50)],
    "heavy_S": [(69, -45), (82, -23), (74, 0)], "heavy_L": [(32, -54), (15, -30), (28, -2)], "heavy_F": [(53, -76), (46, -36), (28, 6)], "heavy_B": [(69, -67), (45, -73), (22, -46), (12, -7)],
}
# The clip's edge cut the blade's tip off in these: px of point to draw on, for each of its frames.
FINISH = {"light1_S": {33: 5}, "light1_L": {12: 3}, "light1_F": {40: 3}, "light2_S": {30: 5}}
# What the clip has in front of his head: his sword hand, the hilt, an arm across it. Capsules on the canvas, x0, y0, x1, y1, radius, by eye over each frame; the clip's pixels there are never cleared and stay in front of the stamped head.
FRONT = {
    ("light1_L", 14): [(48, 57, 56, 60, 2.5)], ("light1_F", 21): [(45, 64, 50, 61, 2.5), (50, 60, 58, 60, 2)],
    ("light1_B", 15): [(56, 58.5, 62, 58.5, 2.5)], ("light1_B", 28): [(56, 59, 62, 57, 3)],
    ("heavy_F", 15): [(41, 65, 47, 62, 2.5), (61, 65, 55, 62, 2.5), (47, 61, 55, 61, 2.5)], ("heavy_F", 41): [(42, 57, 47, 53, 2.5), (59, 57, 54, 53, 2.5)],
    ("heavy_F", 17): [(43, 57, 50, 54, 2.5), (62, 57, 56, 54, 2.5), (49, 53, 57, 53, 2)],
    ("heavy_S", 24): [(41, 60, 52, 61, 2.5), (52, 61, 58, 66, 3)], ("heavy_S", 30): [(33, 66, 40, 61, 2.5), (40, 61, 49, 61, 2.5), (49, 60, 56, 62, 2), (56, 62, 58.5, 70, 2), (35, 58, 50, 57, 3)], ("heavy_S", 41): [(36, 66, 41, 61, 2.5), (41, 60, 50, 61, 2.5), (50, 61, 56, 66, 3), (38, 58, 50, 57, 3)],
    ("heavy_L", 29): [(47, 64, 52, 60, 2.5), (55, 60, 62, 60, 2.5), (62, 60, 66, 66, 3), (50, 56, 62, 56, 3)], ("heavy_L", 46): [(48, 66, 53, 60, 3), (53, 59, 62, 58, 2.5), (62, 58, 68, 63, 3), (50, 55, 60, 55, 3)],
    ("heavy_B", 24): [(45, 66, 50, 62, 2.5), (50, 61, 56, 61, 2.5), (56, 62, 61, 66, 2.5)], ("heavy_B", 30): [(45, 66, 50, 62, 2.5), (50, 61, 56, 61, 2.5), (56, 62, 61, 66, 2.5)], ("heavy_B", 41): [(44, 66, 50, 60, 2.5), (56, 62, 60, 66, 2.5)], ("heavy_B", 42): [(43, 67, 48, 62, 2.5), (48, 62, 52, 60, 2.5), (60, 67, 56, 63, 2.5), (56, 63, 53, 60, 2.5)],
}
HELD = {("heavy_F", 41), ("heavy_L", 29)}    # the gap between his arms and his head is shadow, not sand: held, it hugs his head as a bright ring
BOWED = {("heavy_S", 48), ("heavy_L", 54), ("light1_F", 54), ("light1_F", 67)}        # his head is down between his raised shoulders: what the old head leaves beside the new one is shoulder, at any height, not air
ERASE = {("light1_B", 32): [(74, 65, 76, 65, 2)], ("light2_B", 17): [(12, 84, 33, 65, 5), (37, 68, 37, 70, 4.5)], ("heavy_S", 24): [(37, 79.5, 40.5, 79.5, 1.2)]}    # what the model smeared on or beside the blade, and a stub the old chest leaves; capsules as FRONT
# A part of a frame that's another frame's, x0, y0, x1, y1 of it, moved. Light 2 from behind: the model bent the sword and smeared the hand in the only frame of this pass. Light 1 facing left: with his sword up the cut melts his free fist into his belly and the top of his legs, a skin-coloured wedge on his groin, so that arm is pick 9's, the fist by his thigh. Claude's call.
BORROW = {("light2_B", 17): (16, (8, 75, 34, 94), 7, -9), ("light1_L", 14): (9, (54, 86, 72, 99), 0, 0), ("light1_L", 12): (9, (54, 86, 72, 99), 0, 0)}
# Light 1 from behind, sword up: in every frame of the clip the blade lies along his hair, and the cut's vote eats its rows, so it comes out a club, pinched in the middle and fat at the end. The clip's blade is one straight taper, so it's drawn from its guard to its tip, in canvas px, in its own steel. The last resort: every other frame there was tried. Claude's call.
WHOLE_BLADE = {("light1_B", 15): ((57, 60), (38.5, 63.5)), ("light1_B", 28): ((57, 60.5), (38.5, 64))}
BLADE_HALF = 1.8     # px either side of its line, at the guard
BLADE_POINT = 6      # px: the last of its length, narrowing to the point
STAND_LEGS_L = (36, 94, """
__________hKnggnnKgggnKKKAAKKKKKh____
__________hKnngnnKgggnnKKAABDBDKh____
__________hKnggnnKKggnnKEABBBBKh_____
___________hKnggnKKggnnKKAAAABKh_____
___________hKnngnKKgggnnKAEEBKh______
___________hKnnnKKKgnngKDEKKh________
____________hKDCCCKh_hKnEEBKh________
____________hKCCDCKh_hKEEEBKh________
____________hKEDCKKh_hKEEECKh________
_____________hKEnKKh_hKKEEBCKKh______""")    # his left stand's legs with its sword gone
FAR_FIST_L = (40, 88)    # canvas: just in front of the fist of his far arm in his left stand
PAINT = {**heads.COLOURS, "G": (122, 108, 98)}    # his crossguard in his left stand: warm, so new_sword_sheets.py doesn't take it for the blade
# Where his head is, where the arms or the blade hide too much of it for the fit to be sure.
HEAD_AT = {("heavy_S", 30): (-6, 1), ("heavy_S", 41): (-6, 3), ("heavy_L", 29): (6, 2), ("heavy_L", 46): (5, 1), ("heavy_F", 15): (-2, 0)}    # under his forearms, with its dome showing: the clip tips his head back there, and the upright one only fits lower


def cut(clip, frames):
    """The clip's frames through the same cutter as his other sheets, sized from the first, in his palette with the steel kept."""
    with tempfile.TemporaryDirectory() as d:
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error", "-i", f"{CLIPS}/{clip}.mp4", f"{d}/all%03d.png"], check=True)
        for i, n in enumerate(frames):
            shutil.copy(f"{d}/all{n + 1:03d}.png", f"{d}/pick{i:03d}.png")
            assert not cut_by_edge(f"{d}/all{n + 1:03d}.png", f"{d}/all001.png") or n in FINISH.get(clip[len("vulcan_"):], {}), f"{clip} frame {n}: the clip's edge cuts the sword, and no point is drawn on in FINISH"
        res = subprocess.run(["uv", "run", "--quiet", "--with", "imageio-ffmpeg", "python", CUTTER, f"{d}/pick%03d.png", MASTER, f"{d}/out", "--height", "50", "--all", str(len(frames)), "--add", *STEEL], cwd=SMARTRIG, capture_output=True, text=True)
        assert res.returncode == 0, res.stderr[-400:]
        strip = np.asarray(Image.open(f"{d}/out_strip.png").convert("RGBA")).copy()
    pal = np.asarray(Image.open(f"{FOLDER}/palette.png").convert("RGBA")).reshape(-1, 4)
    pal = np.unique(pal[pal[:, 3] > 0][:, :3], axis=0).astype(float)
    solid = strip[..., 3] > 0
    d = np.linalg.norm(strip[..., :3][solid][:, None, :].astype(float) - pal[None], axis=-1)
    keep = d.min(axis=1) > 45    # what the palette has nothing near: the sword's steel, the outline
    strip[..., :3][solid] = np.where(keep[:, None], strip[..., :3][solid], pal[d.argmin(axis=1)]).astype(np.uint8)
    w = strip.shape[1] // len(frames)
    return [strip[:, i * w:(i + 1) * w] for i in range(len(frames))]


def cut_by_edge(path, first):
    """He reaches the clip's own edge in this frame, so whatever's there is cut. 864 x 496 px: 10 px of him within 3 px of it, as a blade's end does, more than the noise."""
    a = np.asarray(Image.open(first).convert("RGB")).astype(float)
    bg = np.median(np.concatenate([a[:20].reshape(-1, 3), a[-20:].reshape(-1, 3)]), axis=0)
    him = np.linalg.norm(np.asarray(Image.open(path).convert("RGB")).astype(float) - bg, axis=-1) > 110
    return max(him[:3].sum(), him[-3:].sum(), him[:, :3].sum(), him[:, -3:].sum()) > 10


def placed(frames, stand):
    """Frames on the canvas, shifted as one so their stand lies over his real stand, which feet stay put when an attack starts."""
    h = FEET + 40
    first = frames[0]
    ys = np.nonzero(first[..., 3])[0]
    head = np.nonzero(first[ys.min():ys.min() + 10, :, 3])[1]
    dx, dy = WIDE // 2 - (head.min() + head.max()) // 2, FEET - ys.max()
    out = []
    for f in frames:
        box = Image.new("RGBA", (WIDE, h))
        box.alpha_composite(Image.fromarray(f), (max(dx, 0), max(dy, 0)), (max(-dx, 0), max(-dy, 0)))
        out.append(np.array(box))
    low = lambda a: (a[..., 3] > 0) & (np.arange(h)[:, None] > FEET - 34)    # below his head, which is about to change
    sx, sy = steady.best_shift(low(out[0]), low(stand))
    return [steady.shifted(f, sx, sy) for f in out]


def blade_line(a):
    """(the blade's pixels, its middle, its direction, how far its cool part goes each way along it), or None with no blade."""
    cool = sword.is_blade(a)
    if not cool.any():
        return None
    in_line = cool    # the blade is the only sizeable cool grey he has
    gy, gx = np.mgrid[:a.shape[0], :a.shape[1]]
    for _ in range(3):    # rust can split it into pieces, and a pale buckle can look cool: each pass keeps what's in line with the last
        ys, xs = np.nonzero(in_line)
        pts = np.stack([xs, ys], axis=-1).astype(float)
        mid = pts.mean(axis=0)
        way = np.linalg.svd(pts - mid)[2][0]
        rel = np.stack([gx, gy], axis=-1) - mid
        along, across = rel @ way, np.abs(rel @ np.array([-way[1], way[0]]))
        in_line = cool & (across <= HALF_BLADE + 1)
    return in_line, mid, way, along[in_line].min(), along[in_line].max(), along, across


def steel(a):
    """Rust out of the blade: the palette can turn its warm reflections to his skin. Only between its cool parts, so his hand stays."""
    line = blade_line(a)
    if line is None:
        return a
    _, _, _, lo, hi, along, across = line
    r, g, b = (a[..., i].astype(int) for i in range(3))
    light = (r + g + b) / 3
    warm = (a[..., 3] > 0) & (r > b + 12) & ((light >= 55) | (across <= 1.2)) & (along >= lo) & (along <= hi) & (across <= HALF_BLADE)    # dark and warm in its middle is rust too: only his outline's dark at its edges
    out = a.copy()
    out[..., :3][warm] = STEELS[np.where(light[warm] >= 190, 0, np.where(light[warm] >= 125, 1, 2))]
    return out


def finish_tip(a, length, centre):
    """A proper point where the clip's edge cut the blade off, in the blade's own colours and outline."""
    _, mid, way, lo, hi, along, across = blade_line(a)
    if np.linalg.norm(mid + way * lo - centre) > np.linalg.norm(mid + way * hi - centre):
        way, lo, hi, along = -way, -hi, -lo, -along
    out = a.copy()
    hi -= 2    # the blade's last rows run into the flat outline the cut drew along the clip's edge
    wide = np.median(across[sword.is_blade(a) & (along > hi - 6) & (along <= hi)]) + 0.5
    out[(along > hi) & (across <= HALF_BLADE + 2)] = 0
    side = np.array([-way[1], way[0]])
    new = np.zeros(a.shape[:2], bool)
    for d in np.arange(0.0, length, 0.25):
        for k in np.arange(-wide, wide + 0.25, 0.25) * (1 - d / length):
            x, y = np.round(mid + way * (hi + d) + side * k).astype(int)
            new[y, x] = True
            out[y, x] = out[tuple(np.round(mid + way * (hi - 1.5) + side * k).astype(int)[::-1])]
    edge = binary_dilation(new, np.ones((3, 3), bool)) & (out[..., 3] == 0)
    out[edge] = sword.OUTLINE
    return out


def whole_blade(a, guard, tip):
    """One straight blade from guard to tip in place of what the cut left there: see WHOLE_BLADE."""
    guard, tip = np.array(guard, float), np.array(tip, float)
    length = np.linalg.norm(tip - guard)
    way = (tip - guard) / length
    side = np.array([way[1], -way[0]])
    side = side if side[1] < 0 else -side    # up the picture, the lit side
    gy, gx = np.mgrid[:a.shape[0], :a.shape[1]]
    rel = np.stack([gx, gy], axis=-1) - guard
    along, off = rel @ way, rel @ side
    out = a.copy()
    out[(along >= 0) & (along <= length + 3) & (np.abs(off) <= BLADE_HALF + 3)] = 0
    new = (along >= 0) & (along <= length) & (np.abs(off) <= BLADE_HALF * np.minimum((length - along) / BLADE_POINT, 1))
    out[new] = (*STEELS[2], 255)
    out[new & (off > -0.2)] = (*STEELS[1], 255)
    out[new & (off > 0.3) & (along > length / 4) & (along < length / 2)] = (*STEELS[0], 255)
    out[binary_dilation(new, np.ones((3, 3), bool)) & (out[..., 3] == 0)] = sword.OUTLINE
    return out


def lock_head(frame, head, name, pick):
    """His approved head on a frame, with the blade and whatever the clip has across it in front."""
    at = HEAD_AT.get((name, pick)) or steady.fit_head(frame, head.head, head.mask, heads.FAR)[1]
    blade = sword.is_blade(frame)
    hands = capsules(frame, FRONT.get((name, pick), ()))
    frame = tidied(frame, binary_dilation(blade, iterations=2) | hands)    # or the specks of skin in a fist on a hilt go dark, and it reads as a black clump
    edge = binary_dilation(blade, np.ones((3, 3), bool)) & (frame[..., :3].astype(int).sum(axis=-1) < 90) & (frame[..., 3] > 0)
    front = blade | edge | hands & (frame[..., 3] > 0)
    bare, was = head.cleared(frame, at, keep=front)
    out = head.put(bare, was, at, bowed=(name, pick) in BOWED)
    out[front] = frame[front]
    out = outlined(out, front)
    return round_head(out, head, at, (name, pick) in FRONT)


def round_head(a, head, at, across):
    """With his arms round his head: the new head is smaller than the clip's, so the sand would show through where the old one was, as a bright halo. That's the shadow between his arms and his head. Where the arms cross it, its own outline against them is a shadow's brown, or it reads as a black box round his face."""
    new = heads.flipped(head.view, heads.picture(head.base))
    y0, x0 = head.top + at[1] + heads.DROP[head.base], (head.x0 + head.x1 + 1 - new.shape[1]) // 2 + at[0]
    stamped = np.zeros(a.shape[:2], bool)
    stamped[y0:y0 + new.shape[0], x0:x0 + new.shape[1]] = new[..., 3] > 0
    solid = a[..., 3] > 0
    holes, n = label(binary_fill_holes(solid) & ~solid)
    touching = np.unique(holes[binary_dilation(stamped, iterations=3)])
    ring = np.isin(holes, touching[touching > 0])
    ring &= (np.bincount(holes.ravel())[holes] <= SHADOW_HOLE) | ~binary_dilation(binary_erosion(holes > 0, np.ones((2, 2), bool)), np.ones((3, 3), bool))    # a sliver or a chink only: a real gap between his arm and his head stays open. Brown there read as a block or a hood
    if not ring.any() and not across:
        return a
    out = a.copy()
    out[ring] = (*heads.COLOURS["E"], 255)
    if across:
        edge = stamped & binary_dilation(heads.SKIN(out) & ~stamped) & (a[..., :3].astype(int).sum(axis=-1) < sword.DARK)
        out[edge, :3] = heads.COLOURS["E"]
    return out


def capsules(a, parts):
    """Where a frame's capsules (x0, y0, x1, y1, radius) lie."""
    gy, gx = np.mgrid[:a.shape[0], :a.shape[1]]
    out = np.zeros(a.shape[:2], bool)
    for x0, y0, x1, y1, r in parts:
        d = np.array([x1 - x0, y1 - y0], float)
        t = np.clip(((gx - x0) * d[0] + (gy - y0) * d[1]) / max(d @ d, 1), 0, 1)
        out |= np.hypot(gx - x0 - t * d[0], gy - y0 - t * d[1]) <= r
    return out


def outlined(a, around):
    """A dark edge wherever what's in `around` now meets air."""
    solid = (a[..., 3] > 0) & (a[..., :3].astype(int).sum(axis=-1) >= sword.DARK) & around
    a = a.copy()
    a[binary_dilation(solid, sword.GROW) & (a[..., 3] == 0)] = sword.OUTLINE
    return a


def drawn(a, x, y, rows):
    """A's pixels with a hand-drawn patch on them, x and y of its top left, then rows: "." leaves what's there, "_" clears, a letter is a colour of PAINT."""
    out = a.copy()
    for j, row in enumerate(rows.strip("\n").split("\n")):
        for i, c in enumerate(row):
            if c != ".":
                out[y + j, x + i] = (0, 0, 0, 0) if c == "_" else (*PAINT[c], 255)
    return out


def settled(frames, stand):
    """His recovery frames in his stand's shades wherever a pixel only differs by a shade, working back from the stand, so what's left between the last frame and it is what really moved. Not the blade, and not his head, which is already one picture."""
    below_head = np.arange(stand.shape[0])[:, None] > FEET - 30
    near = stand
    for f in frames[:-RECOVERY - 1:-1]:
        same = (f[..., 3] > 0) & (near[..., 3] > 0) & (np.linalg.norm(f[..., :3].astype(float) - near[..., :3], axis=-1) < steady.SHADE) & below_head
        same &= ~binary_dilation(sword.is_blade(f) | sword.is_blade(near), np.ones((3, 3), bool))
        same &= uniform_filter(same.astype(float), SETTLE_AROUND) > SETTLE_SHARE    # alone among pixels that moved, it only happens to match: taking it would dot the stand's shading over his moved hands and belly
        f[same] = near[same]
        near = f
    return frames


def into_stand(last, stand):
    """Left view only: the clips stand with the sword forward in his far hand, as in the approved picture, and his stand has it lying across his shins, in his near hand (from the walk clip, whose run matches it). So the first and last frames are his stand itself, with the clip's blade and a guard in the far fist he already has there."""
    out = drawn(stand, *STAND_LEGS_L)
    blade = binary_dilation(sword.is_blade(last), np.ones((3, 3), bool))
    _, mid, way, lo, hi, _, _ = blade_line(last)
    hilt = mid + way * (lo if way[0] < 0 else hi)    # the end nearer his body, on the right of the picture
    moved = steady.shifted(np.where(blade[..., None], last, 0), *np.round(np.array(FAR_FIST_L) - hilt).astype(int))
    moved[:, FAR_FIST_L[0] + 1:] = 0
    hand = out[..., 3] > 0
    out[(moved[..., 3] > 0) & ~hand] = moved[(moved[..., 3] > 0) & ~hand]
    side = np.array([-way[1], way[0]]) * 3.5
    guard = capsules(out, [(*(np.array(FAR_FIST_L) - side), *(np.array(FAR_FIST_L) + side), 0.9)]) & ~hand
    out[guard] = (*PAINT["G"], 255)
    return outlined(out, guard)


def tidied(a, keep):
    """The cut's vote leaves his dark parts speckled at this size, worst where fast hands blur: dots of skin in his trousers, dots of dark on his belly. `keep`: his head and sword, which are drawn. A foot's laces and his buckle are small and bright on purpose."""
    r, g, b = (a[..., i].astype(int) for i in range(3))
    solid = a[..., 3] > 0
    gold = solid & (r - b > 90) & (g > r * 0.62)
    laces = solid & (np.arange(a.shape[0])[:, None] > FEET - TIDY_FEET)
    skin = solid & (r + g + b >= sword.DARK * 3) & ~gold
    fixed = keep | gold | laces
    out = a.copy()
    for mine, other in ((skin, solid & ~skin), (solid & ~skin, skin)):
        blobs, _ = label(mine)
        sizes = np.bincount(blobs.ravel())
        sizes[0] = 0
        dots = (sizes[blobs] <= TIDY_DOT) & (sizes[blobs] > 0) & ~binary_dilation(a[..., 3] == 0) & ~fixed    # an outline's end is not a dot
        if dots.any():
            near = distance_transform_edt(~other, return_distances=False, return_indices=True)
            out[dots] = out[near[0][dots], near[1][dots]]
    # and his trousers and bracers are one dark, not a mosaic of them, inside their outline
    dark = (out[..., 3] > 0) & (out[..., :3].astype(int).sum(axis=-1) < sword.DARK * 2) & ~fixed
    inside = dark & ~binary_dilation(out[..., 3] == 0, iterations=2)
    light = out[..., :3].astype(int).sum(axis=-1)
    for y, x in zip(*np.nonzero(inside)):
        box = (slice(y - 1, y + 2), slice(x - 1, x + 2))
        here = light[box][dark[box]]
        out[y, x, :3] = out[box][dark[box]][np.argsort(here)[len(here) // 2], :3]
    return out


def pinholes_shut(a):
    """A pixel or three of sand showing through him is the cut's, not a gap between his arm and his side."""
    solid = a[..., 3] > 0
    holes, _ = label(binary_fill_holes(solid) & ~solid)
    sizes = np.bincount(holes.ravel())
    sizes[0] = 0
    out = a.copy()
    out[(sizes[holes] > 0) & (sizes[holes] <= TIDY_DOT)] = (*heads.COLOURS["h"], 255)
    return out


def lock_feet(frames, stand_first, stand_last):
    """A foot that hasn't moved keeps its pixels, frame to frame: the model redraws everything a little. Each foot alone, as he may step with one."""
    ground = lambda a: (a[..., 3] > 0) & ~binary_dilation(sword.is_blade(a), np.ones((3, 3), bool))
    w = frames[0].shape[1]
    rows = slice(FEET - FOOT_ROWS + 1, FEET + 2)
    def feet(a):
        band = ground(a)
        band[:rows.start] = False
        band[rows.stop:] = False
        blobs, n = label(band, np.ones((3, 3), bool))
        return [blobs == i + 1 for i in range(n) if (blobs == i + 1).sum() > 6]
    def paste(a, base):
        for mine in feet(a):
            for theirs in feet(base):
                if (mine & theirs).sum() / max((mine | theirs).sum(), 1) >= PLANTED:
                    a[mine] = 0
                    a[theirs & ground(a) | theirs] = base[theirs]
                    break
    for i in range(len(frames) - 1, -1, -1):    # from the end: he finishes in the feet of his stand
        before = frames[i].copy()
        paste(frames[i], stand_last)
        if (before == frames[i]).all():
            break
    paste(frames[0], stand_first)
    for i in range(1, len(frames)):
        paste(frames[i], frames[i - 1])
    return frames


def build(move, view, picks, stand_frame, low=None):
    name = f"{move}_{view}"
    want = [p for p in picks if p is not None]
    clip = f"vulcan_{move}_{view}"
    raw = cut(clip, [stand_frame, *dict.fromkeys(want)])
    idle = np.array(Image.open(f"{FOLDER}/idle_spear_{view}.png").convert("RGBA"))
    cell_w, cell_h = 96, idle.shape[0]
    stand = np.zeros((FEET + 40, WIDE, 4), np.uint8)
    stand[FEET + 2 - cell_h:FEET + 2, (WIDE - cell_w) // 2:(WIDE + cell_w) // 2] = idle[:, :cell_w]
    frames = placed(raw, stand)
    target = TONE()
    frames = [steel(steady.to_tone(f, target)) for f in frames]
    seen = dict(zip(dict.fromkeys(want), frames[1:]))
    for p in want:
        if (name, p) in ERASE:
            gone = capsules(seen[p], ERASE[name, p])
            seen[p][gone] = 0
            seen[p] = outlined(seen[p], binary_dilation(gone, iterations=2))
        if (name, p) in WHOLE_BLADE:
            seen[p] = whole_blade(seen[p], *WHOLE_BLADE[name, p])
        if (name, p) in BORROW:
            src, (x0, y0, x1, y1), dx, dy = BORROW[name, p]
            there = seen[p][y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            part = seen[src][y0:y1, x0:x1]
            there[part[..., 3] > 0] = part[part[..., 3] > 0]
    if name in FINISH:
        for p, length in FINISH[name].items():
            seen[p] = finish_tip(seen[p], length, np.array([WIDE / 2, FEET - 25.0]))
    order = list(dict.fromkeys(want))
    seen = dict(zip(order, kept_shades([frames[0], *[seen[p] for p in order]])[1:]))
    head = heads.Head(frames[0], view)
    done = {p: lock_head(seen[p], head, name, p) for p in order}
    for p in order:
        done[p] = pinholes_shut(done[p])
        if (name, p) in HELD:
            solid = done[p][..., 3] > 0
            done[p][binary_fill_holes(solid) & ~solid] = (*heads.COLOURS["E"], 255)
    out = [low.copy() if p is None else done[p].copy() for p in picks]
    out = lock_feet(out, low if low is not None else stand, stand)
    if view == "L":
        out[-1] = into_stand(out[-1], stand)
        if low is None:    # and he starts from it, if he isn't already mid-swing
            out[0] = into_stand(out[0], stand)
    return settled(out, stand)


def kept_shades(frames):
    """steady_sheets.py's shades, frame to frame, only where the pose holds. From another pose (overhead to low, say) a pixel that happens to be close takes its shade from a different part of him, and the arms and legs go to speckle: a pick the clip draws clearly came out mud."""
    out = frames[:1]
    for f in frames[1:]:
        was = out[-1][..., 3] > 0
        now = f[..., 3] > 0
        dx, dy = steady.best_shift(was, now)
        moved = steady.shifted(was, dx, dy)
        out.append(steady.keep_shades([out[-1], f])[1] if (moved & now).sum() / (moved | now).sum() >= SAME_POSE else f)
    return out


def TONE():
    stand =np.array(Image.open(f"{FOLDER}/before_steady/idle_F.png").convert("RGBA"))
    return stand[steady.skin_of(stand)][:, :3].mean(axis=0)


def holds(times):
    return {str(i): round(t - 0.02, 3) for i, t in enumerate(times) if t > 0.02}


def trimmed(frames):
    """(the sheet, rows it keeps below his feet, rows it dropped from the top of the canvas)."""
    used = np.nonzero(np.any([f[..., 3] > 0 for f in frames], axis=(0, 2)))[0]
    down = max(0, used.max() - FEET)
    below = down + 2 if down > 0 else 0
    y0 = min(FEET - 49, used.min() - TOP)
    y1 = FEET + 2 + below
    y0 -= (y1 - y0) % 2    # an even height, as his other sheets
    return np.concatenate([f[y0:y1] for f in frames], axis=1), int(below), y0


def main():
    only = sys.argv[1:]
    manifest = json.load(open(f"{FOLDER}/manifest.json"))
    anims = manifest["anims"]
    for view in "SLFB":
        if only and view not in only:
            continue
        l1 = build("light1", view, LIGHT1[view], 0)
        l2 = build("light2", view, LIGHT2[view], 96, l1[5])
        hv = build("heavy", view, HEAVY[view], 0)
        for move, frames in (("light1", l1), ("light2", l2), ("heavy", hv)):
            sheet, below, y0 = trimmed(frames)
            name = f"{move}_{view}"
            Image.fromarray(sheet).save(f"{FOLDER}/{name}.png")
            feet = sheet.shape[0] - 2 - below
            entry = {"file": f"{name}.png", "w": WIDE, "fps": 50, "loop": False, "below": below}
            arc = [[x, feet + y] for x, y in ARC[name]]
            times = TIMES[move]
            if move != "heavy":
                anims[name] = {**entry, "frames": len(times), "holds": holds(times), "active": list(ACTIVE[move]), "arc": arc}
            if move == "light1":    # pressed with light 2's sword still high: from its raised frame, or the sword goes high, down to his stand and high again in 3 ticks and his feet pop out and back
                a, b = ACTIVE[move]
                anims[f"light1_on_{view}"] = {**entry, "start": 1, "frames": len(times) - 1, "holds": holds(times[1:]), "active": [a - 1, b - 1], "arc": arc}
            if move == "light2":    # pressed with light 1 on its way back up: down its own recovery frames, then light 2 from past its low pose, so no tick changes more than a frame of the swing does. One key for each frame the press can land on
                late, below_late, _ = trimmed(l1[:-RECOVERY - 1:-1] + frames[1:])
                Image.fromarray(late).save(f"{FOLDER}/light2_late_{view}.png")
                feet_late = late.shape[0] - 2 - below_late
                anims.pop(f"light2_late_{view}", None)
                for back in range(1, RECOVERY + 1):
                    a, b = ACTIVE[move]
                    anims[f"light2_late{len(l1) - RECOVERY - 1 + back}_{view}"] = {"file": f"light2_late_{view}.png", "w": WIDE, "fps": 50, "loop": False, "below": below_late, "start": RECOVERY - back, "frames": back + len(times) - 1, "holds": holds((REWIND,) * back + times[1:]), "active": [a + back - 1, b + back - 1], "arc": [[x, feet_late + y] for x, y in ARC[name]]}
            if move == "heavy":
                a, b = ACTIVE[move]
                anims[f"lunge_{view}"] = {**entry, "frames": len(times), "holds": holds(times), "active": [a, b], "arc": arc}
                anims[f"thrust_{view}"] = {**entry, "start": OVERHEAD, "frames": len(times) - OVERHEAD, "holds": holds(times[OVERHEAD:]), "active": [a - OVERHEAD, b - OVERHEAD], "arc": arc}
                anims[f"charge_{view}"] = {**entry, "frames": OVERHEAD + 1, "fps": 16}    # raised, then held on the overhead frame
    for gone in ("light3", "light4"):
        for view in "FSBL":
            anims.pop(f"{gone}_{view}", None)
    with open(f"{FOLDER}/manifest.json", "w") as f:
        json.dump(manifest, f, indent=1)
    sheets = json.load(open(f"{FOLDER}/sheets.json"))
    for key in [k for k in sheets if k.split("_")[0] in ("light1", "light2", "light3", "light4", "lunge", "thrust", "charge")]:
        del sheets[key]
    json.dump(sheets, open(f"{FOLDER}/sheets.json", "w"), indent=1)
    for old in ("light3", "light4", "lunge", "thrust", "charge"):
        for path in glob.glob(f"{FOLDER}/{old}_?.png") + glob.glob(f"{FOLDER}/*/{old}_?.png") + glob.glob(f"art/vulcan_new_sword/{old}_?.png"):
            os.remove(path)
    for old in ("light1", "light2"):
        for path in glob.glob(f"{FOLDER}/before_steady/{old}_?.png") + glob.glob(f"{FOLDER}/strips/{old}_?.png"):
            os.remove(path)


if __name__ == "__main__":
    main()
