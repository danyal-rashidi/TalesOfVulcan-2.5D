"""Human Vulcan's head a bit smaller (Danyal: 'make the head a bit smaller'), drawn by hand for each view and put on wherever steady_sheets.py found his head in each frame, with his eyes shut in his hit reaction (art/tools/hurt_clips.py cuts that).
  uv run --with pillow --with numpy --with scipy python art/tools/smaller_head.py
It starts by running steady_sheets.py on him, so it can be run again. Run new_sword_sheets.py after it. His attacks get the same head from art/tools/attack_clips.py, which uses this file's Head.
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, distance_transform_edt, label

sys.path.insert(0, os.path.dirname(__file__))
import steady_sheets as steady

FOLDER = "art/vulcan_human"
COLOURS = {"K": (3, 1, 1), "h": (18, 17, 24), "n": (38, 34, 38), "g": (62, 54, 50), "A": (207, 134, 80), "B": (186, 116, 70), "C": (160, 96, 60), "D": (128, 78, 46), "E": (92, 56, 36), "W": (236, 228, 208), "P": (26, 20, 22)}
# Hair stays warm: new_sword_sheets.py takes any sizeable cool grey for the blade. From his approved picture (art/guides/ref_vulcan_human.png, D:/SmartRig/spike/web/vulcan_armed_*.png) shrunk and tidied by hand, keeping its shield shape: flat hair, ears, a beard narrowing to the chin. Danyal's notes on earlier ones: no big nose, not round, eyes apart (pupils 2 px either side of the nose, or he's cross-eyed), a smaller head and the face higher (eyes halfway down), the side view matching the front, as tall and with as much cheek, and its mouth at the front of the face, level with his nose, not past it, or he looks like he's giving a kiss. His side view's nose stands a pixel out from his face, two rows tall: inside the outline it didn't read, and he looked like he had none.
HEADS = {
    "F": """
....KKKKK....
..KKnngnnKK..
.KnnngggnnnK.
.KnnnnnnnhnK.
.KhAAAAAAAhK.
KChAAAAAAAhCK
KChEEEAEEEhCK
.KCWPBABPWCK.
.KhBBBABBBhK.
.KhBBBDBBBhK.
.KhhhhKhhhhK.
..KhhCCChhK..
...KhhhhhK...
....KKKKK....""",
    "S": """
...KKKKKK....
.KKnnngnnK...
.KnnnggnnnK..
KnnnnnnnnnnK.
KnnnnnDAAAAK.
KnnnDCDAAAAK.
.KnDCBDAEEEK.
.KnhDBBAWPAK.
..KhBBBBBCAD.
..KhBBBBBCCK.
..KhhBBhhhhK.
...KhhhhhCCK.
....KhhhhhhhK
.....KKKKKKK.""",
    "B": """
...KKKKK...
.KKnnnnnKK.
.KnngnnnnK.
KnnggnnnnnK
KnnnnnhnnnK
KhnnnhnnnhK
KhhnnhnnhhK
KChhhhhhhCK
.KhhhhhhhK.
..KDBBBDK..""",
}
WINCE = {"F": [(7, 3, "EE"), (7, 8, "EE"), (11, 5, "EEE")], "S": [(7, 8, "EE"), (11, 9, "EE")], "B": []}    # row, column, what: his eyes shut, his mouth open
# Where the old head is in the stand, from the top of the figure: rows it takes, and the rows of the new one's top. Claude's call, by eye.
OLD_ROWS = {"F": 20, "S": 18, "B": 13}
RAISED = {"look_hands_F": (4, 5)}    # the frames of a move that otherwise keeps its own head where he's looked up: get_up comes next with the new one
FAR = 20       # px he can be from his stand: his lowest swing frame is 17 out, past what steady_sheets.py looks at
ROLL_TALL = 38 # px: shorter than this, a roll's frame is a ball with no head to speak of, and stays as it is
# He's upside down in these, legs in the air: what looks like a head to the fit is his shorts or belly, and a face stamped there cut a leg off (roll_F 4). They keep the clip's own picture, from steady_sheets.py too. By eye, every roll frame enlarged. Claude's call.
UPSIDE_DOWN = {("roll_F", 3), ("roll_F", 4), ("roll_F", 5), ("roll_S", 3), ("roll_S", 4), ("roll_spear_F", 4), *(("roll_B", i) for i in range(2, 6)), *(("roll_spear_B", i) for i in range(2, 6))}
FOUND = 0.6    # of the old head's pixels in place: his rolls reach 0.58, his lowest real head 0.61
LOOSE = 30     # px: a piece beside his new head this small and joined to nothing else is left over from the old one
CLEAR = 2      # px past the old head's front that can still be its own beard, not an arm
DROP = {"F": 3, "S": 3, "B": 3}
NUDGE = {"F": 0, "S": 0, "B": 0}    # px the new head sits forward of the old one's middle
# The old, bigger head hid the top of a shoulder: with the small one in place it stands up beside his face as a spike of skin (Danyal: "extra coming from the right side... from his back"). A frame's side (+1 right of the picture, -1 left) and how many rows from the new head's top are clear of him there, more as it goes away from the head. By eye, every head-swapped frame enlarged. Claude's call.
BESIDE = {("look_hands_F", 4): (1, 6), ("look_hands_F", 5): (1, 11), ("sprint_S", 2): (1, 10), ("sprint_S", 3): (1, 10), ("sprint_S", 4): (1, 10),
    ("sprint_spear_S", 1): (1, 10), ("sprint_spear_S", 2): (1, 10), ("sprint_spear_S", 3): (1, 11), ("sprint_spear_S", 4): (1, 11), ("run_spear_S", 4): (1, 10), ("hurt_S", 3): (1, 10),
    ("hurt_spear_L", 2): (-1, 11), ("run_spear_L", 5): (-1, 8), ("roll_spear_B", 0): (-1, 8), ("roll_spear_B", 7): (-1, 8)}
# His far arm raised behind his head: the old head was stamped over it, so taking that off leaves only its outline, a wire round the new head. Capsules along the arm, x0, y0, x1, y1, radius, by eye, and it comes back from the sheet as it was before the stamp. Claude's call.
HAMMER_UP = [(61, 13, 66, 16, 2.5), (66, 16, 67.5, 22, 2.5), (67.5, 22, 65, 26, 2.5), (66, 25, 63, 32, 2.5)]
BEHIND = {("hammer_blow_S", 0): [(61, 15, 65, 19, 2), (65, 19, 65, 25, 2.5), (65, 25, 60, 30, 2.5)], ("hammer_blow_S", 1): HAMMER_UP, ("hammer_blow_S", 2): HAMMER_UP, ("hammer_blow_S", 6): [(65.5, 31.5, 71, 32.5, 2.5)]}    # frame 6: his forearm across to the fist, which came out as a block in front of his face with a hole beside it
SCAR = {("look_hands_F", 5): (26, 34, 40, 56)}    # y0, y1, x0, x1 on his chest with the old head's chin left on it
BESIDE_REACH = 14    # px out from the head
SKIN = lambda a: (a[..., 3] > 0) & (a[..., :3].astype(int).sum(axis=-1) > 200)


def picture(view, wince=False):
    rows = HEADS[view].strip("\n").split("\n")
    assert len({len(r) for r in rows}) == 1, f"{view}: rows differ in length"
    if wince:
        rows = [list(r) for r in rows]
        for y, x, what in WINCE[view]:
            rows[y][x:x + len(what)] = list(what)
        rows = ["".join(r) for r in rows]
    out = np.zeros((len(rows), len(rows[0]), 4), np.uint8)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                out[y, x] = (*COLOURS[c], 255)
    return out


def flipped(view, a):
    return a[:, ::-1] if view == "L" else a


class Head:
    """A view's old head, as the steady pass stamped it, and how to take it off a frame."""
    def __init__(self, stand, view):
        self.view, self.base = view, "S" if view == "L" else view
        self.head, self.mask = steady.head_of(stand)
        ys, xs = np.nonzero(self.mask)
        self.top, self.x0, self.x1 = ys.min(), xs.min(), xs.max()
        self.rows = OLD_ROWS[self.base]

    def find(self, frame):
        score, at = steady.fit_head(frame, self.head, self.mask, FAR)
        return at if at is not None and score >= FOUND else None

    def by_hair(self, frame):
        """Where his head is when he's thrown back and it no longer looks like the stand's: the dark of his hair at the top of the figure."""
        top = np.nonzero(frame[..., 3].any(axis=1))[0].min()
        hair = (frame[top:top + 8, :, :3].astype(int).sum(axis=-1) < 120) & (frame[top:top + 8, :, 3] > 0)
        xs = np.nonzero(hair.any(axis=0))[0]
        return (xs.min() + xs.max() + 1) // 2 - (self.x0 + self.x1 + 1) // 2, top - self.top

    def cleared(self, frame, at, whole=False, keep=None):
        """The frame with the old head gone, and what it took. whole: all of where it could be, for a head that's tilted. keep: what's in front of the head, which stays."""
        out = frame.copy()
        dx, dy = at
        h, w = frame.shape[:2]
        top, left, right = self.top + dy, self.x0 + dx, self.x1 + dx + 1
        was = np.zeros((h, w), bool)
        ys, xs = np.nonzero(self.mask)    # the head's own shape, so an arm raised beside it stays
        ok = (ys + dy >= 0) & (ys + dy < h) & (xs + dx >= 0) & (xs + dx < w)
        was[ys[ok] + dy, xs[ok] + dx] = True
        was[max(ys.max() + dy + 1, 0):top + self.rows, max(left, 0):right] = True    # his beard, under where the shoulders start
        # a clip's own hair can stand higher or wider than the stamped head; only if nothing but dark is there, so it isn't an arm
        dark = out[..., :3].astype(int).sum(axis=-1) < 120
        for rows, cols in ((range(max(top - 4, 0), top), range(max(left - 2, 0), right + 2)), (range(max(top, 0), top + 8), range(max(left - 2, 0), left)), (range(max(top, 0), top + 8), range(right, right + 2))):
            part = np.zeros((h, w), bool)
            part[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1] = True
            if (dark | (out[..., 3] == 0))[part].all():
                was |= part
        if whole:
            was[max(top, 0):top + self.rows, max(left, 0):right] = True
            was[max(top, 0):top + 8, max(left - 3, 0):right + 3] = True    # his tilted hair; arms are lower than this
        was &= out[..., 3] > 0
        if keep is not None:
            was &= ~keep
        out[was, 3] = 0
        return out, was

    def put(self, frame, was, at, wince=False, bowed=False, beside=None, behind=None):
        """The new head on a cleared frame. Beside and under it, whatever has his body next to it becomes his neck and chest; the rest is air. bowed: his head is down between his shoulders, so that goes for its top rows too. beside: see BESIDE. behind: (capsules, the frame before the stamp): see BEHIND."""
        out = frame.copy()
        new = flipped(self.view, picture(self.base, wince))
        dx, dy = at
        nudge = -NUDGE[self.base] if self.view == "L" else NUDGE[self.base]
        y0 = self.top + dy + DROP[self.base]
        x0 = (self.x0 + self.x1 + 1 - new.shape[1]) // 2 + dx + nudge
        h, w = out.shape[:2]
        if bowed:    # and nothing of the old head or a shoulder's tip stands over the new one
            over = np.zeros((h, w), bool)
            over[:y0, max(x0 - 8, 0):x0 + new.shape[1] + 8] = True
            was = was | (over & (out[..., 3] > 0))
            out[over, 3] = 0
        head = np.zeros((h, w), bool)
        for y in range(new.shape[0]):
            for x in range(new.shape[1]):
                if new[y, x, 3] and 0 <= y0 + y < h and 0 <= x0 + x < w:
                    out[y0 + y, x0 + x] = new[y, x]
                    head[y0 + y, x0 + x] = True
        gap = was & ~head
        body = SKIN(out) & ~head
        # With nothing of his standing in front of a side view's face, that's open air: filling it leaves a block of "neck" where the old, bigger head was, hiding his nose. A raised arm there is really there, and stays.
        chin = y0 + new.shape[0] - 2
        beyond = frame[y0:chin, :max(self.x0 + dx - CLEAR, 0), 3] if self.view == "L" else frame[y0:chin, self.x1 + dx + CLEAR + 1:, 3]
        face_clear = self.base == "S" and not beyond.any()
        fill = np.zeros((h, w), bool)
        for y in np.nonzero(gap.any(axis=1))[0]:
            xs = np.nonzero(gap[y])[0]
            for run in np.split(xs, np.nonzero(np.diff(xs) > 1)[0] + 1):
                left, right = run[0] - 1, run[-1] + 1
                touches = (left >= 0 and out[y, left, 3] > 0 and not head[y, left]) or (right < w and out[y, right, 3] > 0 and not head[y, right])
                ahead = head[y].any() and (run[-1] < np.nonzero(head[y])[0].min() if self.view == "L" else run[0] > np.nonzero(head[y])[0].max())
                if touches and y > y0 + (1 if bowed else 4) and not (face_clear and ahead and y < chin):
                    fill[y, run] = True
        if fill.any() and body.any():
            near = distance_transform_edt(~body, return_distances=False, return_indices=True)
            out[fill] = out[near[0][fill], near[1][fill]]
            out[fill & np.roll(head, 1, axis=0), :3] = COLOURS["D"]    # a little shadow under his chin
        empty = out[..., 3] == 0
        edge = binary_dilation(empty) & ~empty & ~head & binary_dilation(was, iterations=2)
        out[edge] = (*COLOURS["h"], 255)
        near = binary_dilation(head, iterations=5) & ~head    # a clip's own head can be bigger than the stamped one, leaving its outline hanging round the new head
        solid = (out[..., 3] > 0) & (out[..., :3].astype(int).sum(axis=-1) >= 120) & ~head
        out[near & (out[..., :3].astype(int).sum(axis=-1) < 120) & ~binary_dilation(solid, np.ones((3, 3), bool)), 3] = 0
        # what's left of the old head's ear or hair hangs on the new head alone, joined to nothing else
        blobs, n = label((out[..., 3] > 0) & ~head, np.ones((3, 3), bool))
        sizes = np.bincount(blobs.ravel(), minlength=n + 1)
        sizes[0] = 0
        loose = [b for b in np.unique(blobs[binary_dilation(head, iterations=6)]) if 0 < sizes[b] < LOOSE and b != sizes.argmax()]
        out[np.isin(blobs, loose), 3] = 0
        if beside:
            side, rows = beside
            gone = np.zeros((h, w), bool)
            for y in np.nonzero(head.any(axis=1))[0]:
                at_head = np.nonzero(head[y])[0].max() if side > 0 else np.nonzero(head[y])[0].min()
                for d in range(1, BESIDE_REACH):
                    x = at_head + side * d
                    if 0 <= x < w and y - y0 < rows + d // 3:    # sloping down from the head, as a shoulder does
                        gone[y, x] = True
            gone &= out[..., 3] > 0
            out[gone, 3] = 0
            out[binary_dilation(gone) & (out[..., 3] > 0) & ~head] = (*COLOURS["h"], 255)
        if behind:
            parts, clip = behind
            gy, gx = np.mgrid[:h, :w]
            arm = np.zeros((h, w), bool)
            for ax, ay, bx, by, r in parts:
                t = np.clip(((gx - ax) * (bx - ax) + (gy - ay) * (by - ay)) / max((bx - ax) ** 2 + (by - ay) ** 2, 1), 0, 1)
                arm |= np.hypot(gx - ax - t * (bx - ax), gy - ay - t * (by - ay)) <= r
            arm &= ~head
            near = distance_transform_edt(~steady.skin_of(clip), return_distances=False, return_indices=True)    # the old hair's dark on it goes to the skin beside it
            out[arm] = clip[near[0][arm], near[1][arm]]
            out[binary_dilation(arm, iterations=1) & (out[..., 3] == 0)] = (*COLOURS["h"], 255)
            solid = out[..., 3] > 0
            sides = sum(np.roll(solid, n, axis) for n in (1, -1) for axis in (0, 1))
            out[binary_dilation(arm, iterations=2) & solid & (sides <= 1), 3] = 0    # the old outline's end, sticking out
        return out


def main():
    keep_own = steady.NO_HEAD
    steady.NO_HEAD += ("hurt",)    # thrown back, his head isn't where the stand's fits: it would land on his chest
    steady.SKIP = ("light", "heavy")    # art/tools/attack_clips.py finishes these, and his charge, which is its overhead frame
    steady.UPSIDE_DOWN = UPSIDE_DOWN
    steady.run("vulcan_human")
    manifest = json.load(open(f"{FOLDER}/manifest.json"))
    anims = manifest["anims"]
    cell = manifest["cell"][0]
    first = lambda key: np.array(Image.open(f"{FOLDER}/{key}.png").convert("RGBA"))[:, :cell]
    plain = {v: first(f"idle_{v}") for v in "FSB"}
    heads = {v: Head(plain[v], v) for v in "FSB"}
    heads["L"] = Head(plain["S"][:, ::-1], "L")
    done = [0, 0]
    before = np.array(Image.open(f"{FOLDER}/before_steady/idle_F.png").convert("RGBA"))
    tone = before[steady.skin_of(before)][:, :3].mean(axis=0)
    for key, a in anims.items():
        if a["file"].startswith(steady.SKIP) or any(k in key for k in keep_own) and key not in RAISED:
            continue
        hurt = "hurt" in key
        sheet = np.array(Image.open(f"{FOLDER}/{a['file']}").convert("RGBA"))
        head = heads[steady.view_of(key)]
        frames = steady.frames_of(sheet, sheet.shape[1] // cell)
        for i, f in enumerate(frames):
            at = head.by_hair(f) if hurt else head.find(f)
            if key in RAISED and i not in RAISED[key]:
                continue
            if (key, i) in UPSIDE_DOWN or "roll" in key and np.ptp(np.nonzero(f[..., 3].any(axis=1))[0]) < ROLL_TALL:
                at = None
            if at is None:
                done[1] += 1
                continue
            bare, was = head.cleared(f, at, hurt)
            behind = None
            if (key, i) in BEHIND:
                behind = BEHIND[key, i], steady.to_tone(steady.frames_of(np.array(Image.open(f"{FOLDER}/before_steady/{a['file']}").convert("RGBA")), len(frames))[i], tone)
            frames[i] = head.put(bare, was, at, hurt and 0 < i < len(frames) - 1, beside=BESIDE.get((key, i)), behind=behind)
            if (key, i) in SCAR:
                y0, y1, x0, x1 = SCAR[key, i]
                skin = SKIN(frames[i])
                scar = np.zeros(skin.shape, bool)
                scar[y0:y1, x0:x1] = ~skin[y0:y1, x0:x1]
                near = distance_transform_edt(~skin, return_distances=False, return_indices=True)
                frames[i][scar] = frames[i][near[0][scar], near[1][scar]]
            done[0] += 1
        Image.fromarray(np.concatenate(frames, axis=1)).save(f"{FOLDER}/{a['file']}")
    # These moves were an old stand with another body, so he changed shape as they began. They're his stand now, in each view, left-facing too: a mirror would swap his sword's hand.
    for v in "FSBL":
        stand = Image.open(f"{FOLDER}/idle_spear_{v}.png")
        for name in ("drink_spear", "drink_walk_spear", "death_spear"):
            stand.save(f"{FOLDER}/{name}_{v}.png")
            anims[f"{name}_{v}"] = {"file": f"{name}_{v}.png", "frames": 2, "fps": 2.5, "loop": False}
    json.dump(manifest, open(f"{FOLDER}/manifest.json", "w"), indent=1)
    print(f"new head on {done[0]} frames, left alone on {done[1]}")


if __name__ == "__main__":
    main()
