"""Sprite doctor, --shapes (key frame carried along the part flow) and --hitch (in-between for hitching walk loops). The usage and the reasons are in sprite_doctor.py's docstring."""
import json
import numpy as np
import os
import sys
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from steady_sheets import view_of     # a move's view letter, as the head finder reads it; its fallback head
from doctor_core import GAME, MIN_CONTEXT, SAME, _dist, _islands, _shift, _solid, before_after_gif, flicker_score, follow, frames_of, head_masks, seam, specks, treat, unsteady

# --shapes (the judge's knobs, 3 Nov): block-match window radius, px a part may move between frames, radius of the part
# vote on the flow, least agreement at every step of the chain, px/frame over which a part is left as drawn
SHAPE_WIN, SHAPE_REACH, SHAPE_PART, SHAPE_CONF, SHAPE_SPEED = 4, 6, 5, 0.5, 2
SHAPE_FROZEN = 0.3   # a move keeping under this share of its raw frame-to-frame change froze: it comes back untouched
                     # (0.5 blanked real runs that keep 0.4-0.47; the true freezes keep ~0.1)
HITCH_WIN, HITCH_REACH, HITCH_MINPART = 3, 8, 3     # --hitch: limb-scale match over the wrap jump; a smaller region rides with its neighbour
HITCH_LOOPS = {"livia": ["walk_F"], "tullus": ["walk_F"], "varro": ["walk_F", "walk_B"], "fortuna": ["walk_F", "walk_S"],
               "carriage_pull": ["walk_F", "walk_S"]}                       # the in-betweens the judge passed (art/_work/shapes/hitch/report.log)
# round two (art/_work/shapes2/loops_run.log): the remaining hitches are drawing problems, not cutting problems; a 2x midframe
# made every 4-frame loop's peak worse, and the only sound re-cut is an odd frame whose neighbours are nearer each other than it
HITCH_SKIPPED = {"scorpion": "walk_F's in-between is a little soft, walk_B would be a 3-frame loop; walk_F pending a 1x look",
                 "fortuna": "walk_B's in-between smears one leg (a 4-frame loop); pending a 1x look",
                 "raider_sword": "walk_B: frame 19 -> 0 is a different drawing (287 px vs a 40 px median step); its tweens show doubled "
                                 "outlines and a smear under the legs: needs a hand-drawn frame",
                 "cassia": "walk_B: a trim barely moves the seam (1.61 -> 1.56)",
                 "livia_boy": "walk_F: dropping frames 7/0 loses the legs-together passing pose (a shortened arc)",
                 "vulcan_new_sword": "run_spear_B: frame 9 is an odd frame (the sword dips and returns; 8 and 10 match): a manifest-only "
                                     "cut for Danyal to apply by hand after watching art/_work/shapes2/loops/vulcan_new_sword/"
                                     "run_spear_B_loop.gif, and only if vulcan_human shares that sheet"}


def flow(cur, nb, win, reach, part=0):
    """follow() keeping the shift it chose per pixel of cur (nb[y + dy, x + dx] is where that pixel came from) instead
    of the warped pixels. With part > 0 each pixel then takes the commonest shift of the figure within that radius: a
    limb moves as one piece, so a border jitter inside flat colour can't pass as its own little motion. Returns dy, dx
    and the agreement."""
    size = 2 * win + 1
    area = size * size
    best = np.full(cur.shape[:2], np.inf)
    dy_a, dx_a, agree = np.zeros(cur.shape[:2], int), np.zeros(cur.shape[:2], int), np.zeros(cur.shape[:2])
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            moved = _shift(nb, dy, dx)
            d = _dist(cur, moved)
            occ = (_solid(cur) | _solid(moved)).astype(float)
            same = (d <= SAME) * occ
            cost = ndimage.uniform_filter(np.minimum(d, 765).astype(float), size, mode="constant") + 0.5 * (abs(dy) + abs(dx))
            better = cost < best
            best[better] = cost[better]
            dy_a[better], dx_a[better] = dy, dx
            n_same = ndimage.uniform_filter(same, size, mode="constant") * area - same
            n_occ = ndimage.uniform_filter(occ, size, mode="constant") * area - occ
            agree[better] = np.where(n_occ >= MIN_CONTEXT, n_same / np.maximum(n_occ, 1), 0.0)[better]
    if part:
        occ = _solid(cur) | _solid(nb)
        votes = [(ndimage.uniform_filter(((dy_a == dy) & (dx_a == dx) & occ).astype(float), 2 * part + 1, mode="constant"), dy, dx)
                 for dy, dx in set(zip(dy_a[occ].tolist(), dx_a[occ].tolist()))]
        win_ = np.argmax(np.stack([v for v, *_ in votes]), 0)
        dy_a = np.array([v[1] for v in votes])[win_]
        dx_a = np.array([v[2] for v in votes])[win_]
    return dy_a, dx_a, agree


def pick_key(frames, loop):
    """The cleanest frame: best mean agreement with its neighbours over the figure, less its specks."""
    n = len(frames)

    def quality(k):
        nbs = [(k - 1) % n, (k + 1) % n] if loop else [i for i in (k - 1, k + 1) if 0 <= i < n]
        s = _solid(frames[k])
        return np.mean([follow(frames[k], frames[i])[1][s].mean() for i in nbs]) - specks(frames[k]) / max(s.sum(), 1)

    return int(np.argmax([quality(k) for k in range(n)]))


def steady(frames, loop, key, heads):
    """Frames with every confidently chained, slow-moving, non-head pixel taken from the key; and the replaced masks."""
    n = len(frames)
    H, W = frames[0].shape[:2]
    flows = {}
    out, replaced = [f.copy() for f in frames], [np.zeros((H, W), bool) for _ in frames]
    for k in range(n):
        if k == key:
            continue
        step = 1 if (loop and (key - k) % n <= n // 2) or (not loop and key > k) else -1
        ys, xs = np.indices((H, W))
        c, sp, ok, a = np.ones((H, W)), np.zeros((H, W)), np.ones((H, W), bool), k
        while a != key:
            b = (a + step) % n
            if (a, b) not in flows:
                flows[(a, b)] = flow(frames[a], frames[b], SHAPE_WIN, SHAPE_REACH, SHAPE_PART)
            dy, dx, ag = flows[(a, b)]
            ok &= (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
            yy, xx = ys.clip(0, H - 1), xs.clip(0, W - 1)
            c = np.minimum(c, ag[yy, xx])
            sp = np.maximum(sp, np.maximum(abs(dy), abs(dx))[yy, xx])
            ys, xs, a = ys + dy[yy, xx], xs + dx[yy, xx], b
        ok &= (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W) & (c >= SHAPE_CONF) & (sp <= SHAPE_SPEED) & ~heads[k]
        src = frames[key][ys.clip(0, H - 1), xs.clip(0, W - 1)]
        out[k][ok] = src[ok]
        replaced[k] = ok & (_dist(out[k], frames[k]) > 0)
    return out, replaced


def align(stand, s_below, key, k_below):
    """The stand on the key's canvas, its ground line (cell height minus the manifest's rows below it) on the key's and
    its figure's middle column on the key's."""
    (Hs, Ws), (Hk, Wk) = stand.shape[:2], key.shape[:2]
    can = np.zeros((max(Hs, Hk), max(Ws, Wk), 4), np.uint8)
    can[:Hs, :Ws] = stand
    dy = (Hk - k_below) - (Hs - s_below)
    dx = int(np.median(np.nonzero(_solid(key))[1]) - np.median(np.nonzero(_solid(stand))[1]))
    return _shift(can, -dy, -dx)[:Hk, :Wk]


def anchor(key, stand, head):
    """The key with every pixel the aligned stand tracks confidently (not the head) taken from the stand: the torso, belt
    and chest drawn as the view's idle draws them. Returns the new key and the mask of pixels taken."""
    H, W = key.shape[:2]
    dy, dx, ag = flow(key, stand, SHAPE_WIN, SHAPE_REACH, SHAPE_PART)
    ys, xs = np.indices((H, W))
    ys, xs = ys + dy, xs + dx
    ok = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W) & (ag >= SHAPE_CONF) & ~head
    src = stand[ys.clip(0, H - 1), xs.clip(0, W - 1)]
    # the stand's parts that are elsewhere in the move (an arm, the spear) may not appear in empty space: a border may grow 1 px
    ok &= _solid(key) | (_solid(src) & ndimage.binary_dilation(_solid(key)))
    out = key.copy()
    out[ok] = src[ok]
    return out, ok


def raw_change(frames, loop):
    """Frame-to-frame changed pixels with no follow at all: a frozen move shows as a drop here."""
    return int(sum((_dist(a, b) > 0).sum() for a, b in zip(frames, frames[1:] + (frames[:1] if loop else []))))


def shapes_move(frames, loop, heads, stands=(), below=0):
    """The --shapes pass on one move (see the top of the file): key, anchored to the view's stand in stands
    [(cleanest idle frame, its rows below the ground line)] where one tracks it, chained replacement, one treat() pass,
    crumbs the frame never had dropped, head pasted back and asserted untouched. Returns the frames, the key and a count
    dict; a move that would be left with fewer than 2 distinct frames or under SHAPE_FROZEN of its raw change comes back
    as given, with counts["untouched"] set (an anchored move first retries without the anchor: counts["unanchored"])."""
    key = pick_key(frames, loop)
    work, carried = list(frames), 0
    if stands:
        work[key], ok = max((anchor(frames[key], align(s, b, frames[key], below), heads[key]) for s, b in stands),
                            key=lambda c: c[1].sum())
        carried = int((ok & (_dist(work[key], frames[key]) > 0)).sum())
    out, rep = steady(work, loop, key, heads)
    fixed, counts = treat(out, loop)                  # treat() itself leaves moves under MIN_FRAMES alone
    for f, o, h in zip(fixed, frames, heads):
        f[_islands(f) & ~_solid(o)] = 0               # a key pixel carried to beside a kept part: a loose crumb
        f[h] = o[h]
        assert (f[h] == o[h]).all(), "head mask changed"
    counts["replaced"], counts["carried"] = int(sum(r.sum() for r in rep)), carried
    if len({f.tobytes() for f in fixed}) < 2 <= len({f.tobytes() for f in frames}):
        return [f.copy() for f in frames], key, dict(counts, untouched="would become a still")
    if raw_change(fixed, loop) < SHAPE_FROZEN * raw_change(frames, loop):
        if stands:                                    # the anchor froze it: ship the plain steadied result instead
            fixed, key, counts = shapes_move(frames, loop, heads, (), below)
            return fixed, key, dict(counts, unanchored="would freeze")
        return [f.copy() for f in frames], key, dict(counts, untouched="would freeze")
    return fixed, key, counts


def strip(rows, path, zoom=4):
    """Rows of frames side by side at zoom, on sand: before over after."""
    H, W = rows[0][0].shape[:2]
    img = Image.new("RGBA", (max(len(r) for r in rows) * W * zoom, len(rows) * H * zoom), (196, 178, 140, 255))
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            img.alpha_composite(Image.fromarray(f).resize((W * zoom, H * zoom), Image.NEAREST), (i * W * zoom, r * H * zoom))
    img.convert("RGB").save(path)


def shapes_folder(folder, keys=(), gifs=True):
    """--shapes over the game's current sheets of one character: the steadied sheets, report.json, before|after GIFs and
    strips (before over after) go to art/_work/doctor_shapes/<folder>/."""
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    src = os.path.join(GAME, "art", folder)
    out_dir = os.path.join(GAME, "art", "_work", "doctor_shapes", folder)
    os.makedirs(out_dir, exist_ok=True)
    if os.path.exists(os.path.join(out_dir, "manifest_patch.json")):     # a fresh sheet: --hitch must run again
        os.remove(os.path.join(out_dir, "manifest_patch.json"))
    report, sheets, stands = {}, {}, {}

    def cut(a):
        cw, n, st = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0))
        if a["file"] not in sheets:
            sheet = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
            sheets[a["file"]] = (sheet, sheet.copy())
        return frames_of(sheets[a["file"]][0], cw, n, st)

    def stands_of(view):                              # the view's idles' cleanest frames, from the game's own sheets
        if view not in stands:
            stands[view] = []
            for name in (f"idle_{view}", f"idle_spear_{view}"):
                a = man["anims"].get(name)
                if a and os.path.exists(os.path.join(src, a["file"])):
                    fr = cut(a)
                    stands[view].append((fr[pick_key(fr, bool(a.get("loop", False)))], int(a.get("below", 0))))
        return stands[view]

    for key, a in man["anims"].items():
        cw, n, st, loop = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0)), bool(a.get("loop", False))
        if (keys and key not in keys) or n < 2 or not os.path.exists(os.path.join(src, a["file"])):     # a 1-frame move is a cell of another's
            continue
        fr = cut(a)
        sheet, new = sheets[a["file"]]
        fixed, k, counts = shapes_move(fr, loop, head_masks(fr, folder, key, man, src),
                                       () if key.startswith("idle") else stands_of(view_of(key)), int(a.get("below", 0)))
        for i, f in enumerate(fixed):                 # as doctor_folder: a later move sharing cells overwrites them
            new[:, (st + i) * cw:(st + i + 1) * cw] = f
        changed = int(sum((_dist(x, y) > 0).sum() for x, y in zip(fr, fixed)))
        figure = int(sum(_solid(x).sum() for x in fr))
        report[key] = dict(file=a["file"], frames=n, loop=loop, key=k, fixed=counts, changed_px=changed, figure_px=figure,
                           flicker_before=round(flicker_score(fr, loop), 1), flicker_after=round(flicker_score(fixed, loop), 1),
                           unsteady_before=round(unsteady(fr, loop), 1), unsteady_after=round(unsteady(fixed, loop), 1),
                           seam_before=round(seam(fr), 2) if loop else None, seam_after=round(seam(fixed), 2) if loop else None)
        if gifs:                                      # always, so an untouched move never keeps an older run's GIF
            before_after_gif(fr, fixed, os.path.join(out_dir, f"{key}_before_after.gif"), a.get("fps", 10))
            strip([fr, fixed], os.path.join(out_dir, f"{key}_strip.png"))
        print(f"{folder:<14}{key:<16} fr {n:>2} key {k:>2} anchored {counts['carried']:>4} px  changed {changed / max(figure, 1) * 100:5.1f}% of figure  "
              f"unsteady {report[key]['unsteady_before']} -> {report[key]['unsteady_after']}"
              + (f"  UNTOUCHED: {counts['untouched']}" if "untouched" in counts else ""), flush=True)
    for fname, (_, new) in sheets.items():
        Image.fromarray(new).save(os.path.join(out_dir, fname))
    json.dump(report, open(os.path.join(out_dir, "report.json"), "w"), indent=1)
    return report


def parts(frame, dy, dx):
    """Connected regions of the figure sharing one shift: (mask, (dy, dx)), biggest first; regions under HITCH_MINPART px
    ride with the biggest part they touch."""
    s = _solid(frame)
    R = HITCH_REACH
    key = np.where(s, (dy + R) * (2 * R + 1) + dx + R, -1)
    out = []
    for v in np.unique(key[s]):
        lab, n = ndimage.label(key == v, structure=np.ones((3, 3)))
        out += [(lab == i, (int(v) // (2 * R + 1) - R, int(v) % (2 * R + 1) - R)) for i in range(1, n + 1)]
    out.sort(key=lambda p: -p[0].sum())
    big = [p for p in out if p[0].sum() >= HITCH_MINPART]
    for i, (m, sh) in enumerate(out):
        if m.sum() < HITCH_MINPART:
            ring = ndimage.binary_dilation(m, np.ones((3, 3))) & ~m
            host = next((b for b in big if (b[0] & ring).any()), None)
            out[i] = (m, host[1] if host else sh)
    return out


def halfway(src, dst):
    """src's parts each moved halfway to where they are in dst, biggest drawn first so hands and weapons end on top."""
    can = np.zeros_like(src)
    for m, (dy, dx) in parts(src, *flow(src, dst, HITCH_WIN, HITCH_REACH)[:2]):
        moved = _shift(np.where(m[..., None], src, 0), -(dy // 2), -(dx // 2))      # floor on both ends: they meet
        can[_solid(moved)] = moved[_solid(moved)]
    return can


def midframe(A, B, loop):
    """One in-between of A and B (A -> B): the two halfway layers laid over each other; where both have a pixel of a
    different colour (a border redrawn elsewhere, not a motion) the colour with more votes in the 3x3 of both layers
    wins, which puts the border between the two; then settled by treat() inside the loop, leftover pinholes filled."""
    ca, cb = halfway(A, B), halfway(B, A)
    mid = np.where(_solid(ca)[..., None], ca, cb)
    clash = _solid(ca) & _solid(cb) & (_dist(ca, cb) > SAME)
    votes = lambda c: sum((_dist(lay, c) <= SAME) & _solid(lay) for lay in
                          (_shift(l, dy, dx) for l in (ca, cb) for dy in (-1, 0, 1) for dx in (-1, 0, 1)))
    b_wins = clash & (votes(cb) > votes(ca))
    mid[b_wins] = cb[b_wins]
    mid = treat(loop + [mid], True)[0][-1]
    # gaps parts left between them (not a gap A or B both have, like between an arm and the body) close from the rim in
    hole = ndimage.binary_fill_holes(_solid(mid)) & ~_solid(mid) & (_solid(A) | _solid(B))
    while hole.any():
        rim = hole & ndimage.binary_dilation(_solid(mid), np.ones((3, 3)))
        for y, x in zip(*np.nonzero(rim)):
            ring = mid[y - 1:y + 2, x - 1:x + 2].reshape(-1, 4)
            cols, cnt = np.unique(ring[ring[:, 3] > 0], axis=0, return_counts=True)
            mid[y, x] = cols[cnt.argmax()]
        hole &= ~rim
    return mid


def hitch_folder(folder, gifs=True):
    """--hitch on one character's loops in HITCH_LOOPS (see the top of the file), from the --shapes sheet when there is
    one, else the game's: the sheet with one more cell, manifest_patch.json, <key>_strip.png (the old wrap over the new)
    and <key>_hitch.gif go to art/_work/doctor_shapes/<folder>/."""
    if folder in HITCH_SKIPPED:
        print(f"{folder}: hitch skipped, {HITCH_SKIPPED[folder]}", flush=True)
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    out_dir = os.path.join(GAME, "art", "_work", "doctor_shapes", folder)
    patch_path = os.path.join(out_dir, "manifest_patch.json")
    patch = json.load(open(patch_path)) if os.path.exists(patch_path) else {}
    for key in HITCH_LOOPS.get(folder, []):
        a = dict(man["anims"][key])
        if key in patch:
            print(f"{folder} {key}: already repaired (manifest_patch.json)", flush=True)
            continue
        src = out_dir if os.path.exists(os.path.join(out_dir, a["file"])) else os.path.join(GAME, "art", folder)
        sheet = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
        cw, n = int(a.get("w", man["cell"][0])), int(a["frames"])
        assert int(a.get("start", 0)) == 0 and sheet.shape[1] == cw * n, f"{key}: the sheet holds more than this loop"
        frames = frames_of(sheet, cw, n)
        new = frames + [midframe(frames[-1], frames[0], frames)]
        before, after = seam(frames), seam(new)
        assert after < before, f"{key}: the in-between made the wrap worse ({before:.2f} -> {after:.2f})"
        os.makedirs(out_dir, exist_ok=True)
        Image.fromarray(np.concatenate(new, axis=1)).save(os.path.join(out_dir, a["file"]))
        patch[key] = dict(a, frames=n + 1, fps=round(a["fps"] * (n + 1) / n, 2))   # the loop keeps its length: the drawn feet cover the same ground
        json.dump(patch, open(patch_path, "w"), indent=1)
        strip([frames[-3:] + [np.zeros_like(frames[0])] + frames[:2], new[-4:] + new[:2]], os.path.join(out_dir, f"{key}_strip.png"))
        if gifs:
            before_after_gif(frames + [frames[0]], new, os.path.join(out_dir, f"{key}_hitch.gif"), a["fps"])
        print(f"{folder:<14}{key:<8} {n} -> {n + 1} frames from {os.path.relpath(src, GAME)}, seam {before:.2f} -> {after:.2f}", flush=True)
