"""Sprite doctor, the noise fixes (gentle and --strong), the shared frame helpers, every tuning constant they use. The usage and the reasons are in sprite_doctor.py's docstring."""
import json
import numpy as np
import os
import sys
from PIL import Image
from scipy import ndimage

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REACH = 4          # px a part may move between frames
WIN = 2            # radius of the window that has to match round a pixel
SAME = 24          # RGB L1 distance under which two pixels are the same colour (sheets are palette-locked)
TRUST = 0.6        # share of the window (the pixel itself left out) that must match for a fix to be trusted
ISLAND = 3         # px: a loose island this small that the neighbours don't have is a speck
MIN_FRAMES = 4
MIN_CONTEXT = 8    # of the 24 pixels round a pixel, at least this many must have something in them to judge a match
SPECK = 2          # px: a same-coloured patch this small inside the figure is texture noise
SHADE_L = 45       # luma (0-255): a patch closer than this to what surrounds it is a shade, not a mark
INK_L = 35         # luma: darker than this is outline or ink, which the tidy leaves alone
LUMA = np.array([0.3, 0.59, 0.11])
LINK = 0.5         # share of two frames' figure that must be exactly alike for them to count as one drawing; Claude's call
X3, X4 = np.ones((3, 3), bool), np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)
RING = [(-1, -1), (-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1)]     # the 8 neighbours, in a circle


def frames_of(sheet, cw, n, start=0):
    return [sheet[:, (start + i) * cw:(start + i + 1) * cw].copy() for i in range(n)]


def _dist(a, b):
    """Per-pixel distance of two RGBA frames: colour L1 where both are solid, 765 where one is and the other isn't."""
    sa, sb = a[..., 3] > 0, b[..., 3] > 0
    d = np.abs(a[..., :3].astype(int) - b[..., :3].astype(int)).sum(-1)
    return np.where(sa & sb, d, np.where(sa == sb, 0, 765))


def _shift(img, dy, dx):
    """img moved so out[y, x] = img[y + dy, x + dx]; outside is transparent."""
    out = np.zeros_like(img)
    H, W = img.shape[:2]
    if abs(dy) >= H or abs(dx) >= W:
        return out
    ys, yd = slice(max(dy, 0), H + min(dy, 0)), slice(max(-dy, 0), H + min(-dy, 0))
    xs, xd = slice(max(dx, 0), W + min(dx, 0)), slice(max(-dx, 0), W + min(-dx, 0))
    out[yd, xd] = img[ys, xs]
    return out


def follow(cur, nb):
    """nb's pixels brought to where they are in cur, part by part: for every pixel the shift (within REACH) whose
    window agrees best. Returns the warped neighbour and, per pixel, the share of its window (itself left out) that
    matches, so callers can tell a good match from a guess. Only pixels where either frame has something count: empty
    background matches anything, so a small spark flying past would otherwise look well matched."""
    size = 2 * WIN + 1
    best_cost = np.full(cur.shape[:2], np.inf)
    warped = np.zeros_like(cur)
    agree = np.zeros(cur.shape[:2])
    for dy in range(-REACH, REACH + 1):
        for dx in range(-REACH, REACH + 1):
            moved = _shift(nb, dy, dx)
            d = _dist(cur, moved)
            occ = (_solid(cur) | _solid(moved)).astype(float)
            same = (d <= SAME) * occ
            cost = ndimage.uniform_filter(np.minimum(d, 765).astype(float), size, mode="constant") + 0.5 * (abs(dy) + abs(dx))
            better = cost < best_cost
            best_cost[better] = cost[better]
            warped[better] = moved[better]
            area = size * size
            n_same = ndimage.uniform_filter(same, size, mode="constant") * area - same
            n_occ = ndimage.uniform_filter(occ, size, mode="constant") * area - occ
            ctx = np.where(n_occ >= MIN_CONTEXT, n_same / np.maximum(n_occ, 1), 0.0)
            agree[better] = ctx[better]
    return warped, agree


def _solid(f):
    return f[..., 3] > 0


def _neighbours(frames, k, loop, reach):
    """Frames k-reach..k+reach (not k) that exist, each followed to frame k: (warped, trusted) pairs."""
    n, out = len(frames), []
    for j in range(-reach, reach + 1):
        i = k + j
        if j == 0 or (not loop and not 0 <= i < n) or (loop and abs(j) * 2 >= n):
            continue
        w, agree = follow(frames[k], frames[i % n])
        out.append((w, agree >= TRUST))
    return out


def _moved_detail(cand, cur, others, r=8, rare=6):
    """Of the candidate pixels, those whose colour is rare in another frame (a few px: a glint, an eye, a spark) and
    within r px there: a detail on a part that moved further than the follower can see (a plain body matches itself at
    any shift), not noise. A colour that is everywhere (the outline, a skin shade) proves nothing and isn't kept."""
    keep = np.zeros(cand.shape, bool)
    for y, x in zip(*np.nonzero(cand)):
        c = cur[y, x, :3].astype(int)
        for f in others:
            hit = (np.abs(f[..., :3].astype(int) - c).sum(-1) <= SAME) & (f[..., 3] > 0)
            if 0 < hit.sum() <= rare and hit[max(y - r, 0):y + r + 1, max(x - r, 0):x + r + 1].any():
                keep[y, x] = True
                break
    return keep


def treat(frames, loop):
    """The cleaned frames and a count of each fix. Every decision is made on the frames as given, so one frame's fix
    can't feed the next."""
    n = len(frames)
    out = [f.copy() for f in frames]
    counts = dict(shimmer=0, edge_removed=0, edge_restored=0, speck=0, pinhole=0, island=0)
    if n < MIN_FRAMES:
        return out, counts
    for k in range(n):
        cur = frames[k]
        o = out[k]
        s = _solid(cur)
        # colour: the colour most of the 2 frames either side agree on, where this frame alone breaks it (a blip, or
        # shading that crawls a pixel back and forth); a lasting change has the later frames on its side and stays
        nb = _neighbours(frames, k, loop, 2 if n >= 6 else 1)
        if len(nb) >= 2:
            need = 3 if len(nb) >= 4 else len(nb)
            W = np.stack([w for w, _ in nb]); V = np.stack([t & _solid(w) for w, t in nb])
            close = np.stack([np.stack([_dist(W[i], W[j]) <= SAME for j in range(len(nb))]) for i in range(len(nb))])
            support = (close & V[None] & V[:, None]).sum(1)                       # per neighbour: how many agree with it
            best = support.argmax(0)
            top = np.take_along_axis(support, best[None], 0)[0]
            pick = np.take_along_axis(W, best[None, ..., None], 0)[0]
            mine = np.stack([V[i] & (_dist(cur, W[i]) <= SAME) for i in range(len(nb))]).sum(0)
            shim = s & (top >= need) & (mine <= 1) & (_dist(cur, pick) > SAME) & _solid(pick)
            lum = (cur[..., :3].astype(float) * LUMA).sum(-1)
            strong = shim & (np.abs(lum - (pick[..., :3].astype(float) * LUMA).sum(-1)) > SHADE_L)
            shim &= ~(strong & _moved_detail(strong, cur, [frames[(k - 1) % n], frames[(k + 1) % n]]))
            o[shim, :3] = pick[shim, :3]
            counts["shimmer"] += int(shim.sum())
        if not loop and k in (0, n - 1):
            continue
        prev, nxt = frames[(k - 1) % n], frames[(k + 1) % n]
        wp, ap = follow(cur, prev)
        wn, an = follow(cur, nxt)
        trusted = (ap >= TRUST) & (an >= TRUST)
        sp, sn = _solid(wp), _solid(wn)
        sides_agree = (sp == sn) & np.where(sp & sn, _dist(wp, wn) <= SAME, True)
        edge = trusted & sides_agree & (s != sp)
        gone = edge & s                          # appears for one frame only
        o[gone] = 0
        counts["edge_removed"] += int(gone.sum())
        back = edge & ~s                         # missing for one frame only
        o[back] = wp[back]
        counts["edge_restored"] += int(back.sum())
        # spatial clean-up of what the neighbours don't share (the eyes and other real detail are in them), only where
        # the neighbours are matched well: a glint on a part moving faster than REACH has no trustworthy neighbour
        persistent = np.where(_solid(o) & sp, _dist(o, wp) <= SAME, False) | np.where(_solid(o) & sn, _dist(o, wn) <= SAME, False)
        sp_n, c_n = _lone(o)
        speck = sp_n & ~persistent & trusted
        speck &= ~_moved_detail(speck, cur, [prev, nxt])
        o[speck, :3] = c_n[speck]
        counts["speck"] += int(speck.sum())
        hole = _pinholes(o) & (sp | sn) & trusted
        fill = np.where(sp[..., None], wp, wn)
        o[hole] = fill[hole]
        counts["pinhole"] += int(hole.sum())
        isl = _islands(o) & ~(sp | sn) & trusted
        o[isl] = 0
        counts["island"] += int(isl.sum())
    return out, counts


def _lone(f):
    """Pixels unlike all 8 solid neighbours, which share one colour; and that colour."""
    H, W = f.shape[:2]
    s = _solid(f)
    rgb = f[..., :3].astype(int)
    pad = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
    spad = np.pad(s, 1)
    ref = pad[1:-1, 2:]
    lone = s.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == dx == 0:
                continue
            nb = pad[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
            ns = spad[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx]
            lone &= ns & (np.abs(nb - ref).sum(-1) <= SAME) & (np.abs(nb - rgb).sum(-1) > SAME)
    return lone, ref.astype(np.uint8)


def _pinholes(f):
    s = _solid(f)
    p = np.pad(s, 1)
    return ~s & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def _islands(f):
    lab, n = ndimage.label(_solid(f), structure=np.ones((3, 3)))
    if n <= 1:
        return np.zeros(f.shape[:2], bool)
    sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1))
    return np.isin(lab, 1 + np.nonzero(sizes <= ISLAND)[0])


def head_masks(frames, folder, key, man, src):
    """Where the locked head is in each frame (steady_sheets.py's own finder), so the tidy never repaints a face."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import steady_sheets as st
    view = st.view_of(key)

    def placed(mask, at, shape):            # the head's mask moved by at = (dx, dy), clipped to this frame
        out = np.zeros(shape, bool)
        ys, xs = np.nonzero(mask)
        y2, x2 = ys + at[1], xs + at[0]
        ok = (y2 >= 0) & (y2 < shape[0]) & (x2 >= 0) & (x2 < shape[1])
        out[y2[ok], x2[ok]] = True
        return ndimage.binary_dilation(out)

    def fitted(head, mask):
        res = []
        for f in frames:
            score, at = st.fit_head(f, head, mask) if f[..., 3].any() else (0, None)
            res.append(placed(mask, at, f.shape[:2]) if at is not None and score >= st.HEAD_MATCH else None)
        return res

    found = [None] * len(frames)
    for stand in (f"idle_{view}", f"idle_spear_{view}", "idle_F"):     # the view's stand, as steady_sheets.py locks it
        a = man["anims"].get(stand)
        if a:
            sheet = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
            found = fitted(*st.head_of(frames_of(sheet, int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0)))[0]))
            break
    if sum(m is not None for m in found) * 2 < len(frames) and frames[0][..., 3].any():   # drawn too differently: its own head
        found = fitted(*st.head_of(frames[0]))
    # where no head fits (a fall, a kneel), the top of that frame's own figure, as head_of cuts it, stays as drawn
    return [m if m is not None else (st.head_of(f)[1] if f[..., 3].any() else np.zeros(f.shape[:2], bool))
            for m, f in zip(found, frames)]


def _smooth(o, protect):
    """The strong tidy: each pixel averaged with the 8 round it that are the same material (a shade apart, not ink,
    inside the figure; the pixel itself counts double), then snapped to the nearest colour already there, so speckle
    becomes shading and no colour is invented. The edge, ink and the face stay as drawn. Returns pixels changed."""
    s = _solid(o)
    rgb = o[..., :3].astype(float)
    lum = (rgb * LUMA).sum(-1)
    H, W = s.shape
    edge = s & ~ndimage.binary_erosion(s, structure=np.ones((3, 3)))
    acc, wsum, cand = rgb * 2.0, np.full((H, W), 2.0), [rgb]
    pr, pl, ps = np.pad(rgb, ((1, 1), (1, 1), (0, 0))), np.pad(lum, 1), np.pad(s, 1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if not (dy or dx):
                continue
            nr, nl, ns = (p[1 + dy:H + 1 + dy, 1 + dx:W + 1 + dx] for p in (pr, pl, ps))
            same = ns & (np.abs(nl - lum) <= SHADE_L) & (nl >= INK_L)
            wt = same * (1.0 if dy and dx else 1.5)
            acc += nr * wt[..., None]
            wsum += wt
            cand.append(np.where(same[..., None], nr, -1000.0))
    mean = acc / wsum[..., None]
    cand = np.stack(cand)
    best = np.take_along_axis(cand, np.abs(cand - mean[None]).sum(-1).argmin(0)[None, ..., None], 0)[0]
    ok = s & ~edge & ~protect & (lum >= INK_L) & (np.abs(best - rgb).sum(-1) > 0)
    o[ok, :3] = best[ok].astype(np.uint8)
    return int(ok.sum())


def tidy(frame, protect, strong=False):
    """One frame's texture noise smoothed (see the top of the file); returns the frame and how many pixels changed."""
    o = frame.copy()
    changed = 0
    strong_after = strong
    for _ in range(2):
        s = _solid(o)
        rgb = o[..., :3].astype(int)
        key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
        key[~s] = -1
        lum = (rgb * LUMA).sum(-1)
        edge = s & ~ndimage.binary_erosion(s, structure=np.ones((3, 3)))
        for v in np.unique(key[s]):
            lab, nl = ndimage.label(key == v)
            if not nl:
                continue
            sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, nl + 1))
            for c in 1 + np.nonzero(sizes <= SPECK)[0]:
                comp = lab == c
                if (comp & (edge | protect)).any():
                    continue
                ring = ndimage.binary_dilation(comp, structure=np.ones((3, 3))) & ~comp
                if not s[ring].all():
                    continue
                cols, cnt = np.unique(key[ring], return_counts=True)
                m = cols[cnt.argmax()]
                share = cnt.max() / cnt.sum()
                l_comp = lum[comp].mean()
                l_m = ((np.array([(m >> 16) & 255, (m >> 8) & 255, m & 255])) * LUMA).sum()
                if l_comp < INK_L and l_m < INK_L:
                    continue
                strong = abs(l_comp - l_m) > SHADE_L
                if (strong and (comp.sum() > 1 or share < 1.0)) or share < 0.5:
                    continue
                o[comp, 0], o[comp, 1], o[comp, 2] = (m >> 16) & 255, (m >> 8) & 255, m & 255
                changed += int(comp.sum())
    if strong_after:
        changed += _smooth(o, protect)
    return o, changed


def specks(frame):
    """Patches of 1-2 px inside the figure: the texture-noise measure the report shows."""
    s = _solid(frame)
    rgb = frame[..., :3].astype(int)
    key = (rgb[..., 0] << 16) | (rgb[..., 1] << 8) | rgb[..., 2]
    key[~s] = -1
    n = 0
    for v in np.unique(key[s]):
        lab, nl = ndimage.label(key == v)
        if nl:
            n += int((ndimage.sum(np.ones(lab.shape), lab, range(1, nl + 1)) <= SPECK).sum())
    return n


def flicker_score(frames, loop):
    """Pixels per frame that change for one frame and change back (what treat() targets); the measure the report shows."""
    n = len(frames)
    if n < 3:
        return 0.0
    total = 0
    ks = range(n) if loop else range(1, n - 1)
    for k in ks:
        wp, ap = follow(frames[k], frames[(k - 1) % n])
        wn, an = follow(frames[k], frames[(k + 1) % n])
        s, sp, sn = _solid(frames[k]), _solid(wp), _solid(wn)
        sides_agree = (sp == sn) & np.where(sp & sn, _dist(wp, wn) <= SAME, True)
        differs = np.where(s & sp, _dist(frames[k], wp) > SAME, s != sp)
        total += int((sides_agree & differs & (ap >= 0.6) & (an >= 0.6)).sum())
    return total / max(len(ks), 1)


def unsteady(frames, loop):
    """Pixels per frame that change colour against the next frame where that part matches well: shimmer and crawl,
    not the movement itself (moving parts don't match, so they don't count)."""
    n = len(frames)
    pairs = range(n) if loop else range(n - 1)
    tot = 0
    for k in pairs:
        w, agree = follow(frames[(k + 1) % n], frames[k])
        b = frames[(k + 1) % n]
        tot += int(((agree >= TRUST) & _solid(b) & _solid(w) & (_dist(b, w) > SAME)).sum())
    return tot / max(len(pairs), 1)


def seam(frames):
    """How much bigger the jump from the last frame back to the first is than a typical step (a loop that hitches)."""
    if len(frames) < 3:
        return 0.0
    steps = []
    for a, b in zip(frames, frames[1:] + frames[:1]):
        w, _ = follow(b, a)
        steps.append(int((_dist(b, w) > SAME).sum()))
    return steps[-1] / max(np.median(steps[:-1]), 1)


def relink(sheets):
    """sheets: [(name, original, cleaned, cell width, rows below the ground line)], the canonical ones first. Each frame
    is stood on one canvas by its ground line and middle; where an earlier frame, as drawn or mirrored, is at least LINK
    the same (every channel, over the pixels either has), the pixels that were exactly alike take its cleaned value
    (see the top of the file). Cleaned arrays change in place; returns the pixels changed per sheet."""
    cells = [(s, i) for s in range(len(sheets)) for i in range(sheets[s][1].shape[1] // sheets[s][3])]
    ground = max(o.shape[0] - b for _, o, _, _, b in sheets)
    Hc, Wc = ground + max(b for *_, b in sheets), max(cw for *_, cw, _ in sheets)
    O = np.zeros((len(cells), Hc, Wc), np.uint32)       # each original pixel as one number, 0 where it is empty
    C = np.zeros((len(cells), Hc, Wc, 4), np.uint8)
    M = np.zeros((len(cells), Hc, Wc), bool)            # the frame's own cell on the canvas
    place = []
    for k, (s, i) in enumerate(cells):
        _, o, c, cw, b = sheets[s]
        h = o.shape[0]
        # shortcut: centred on the widest cell, a cell whose width differs from it by an odd px mirrors 1 px off and can't
        # mirror-link; place each mirrored cell on its own centre if a folder ever mixes parities
        assert (Wc - cw) % 2 == 0, f"{sheets[s][0]}: its cell width and the widest differ by an odd px"
        y0, x0 = ground - (h - b), (Wc - cw) // 2
        place.append((y0, x0, h, cw))
        cell = np.ascontiguousarray(o[:, i * cw:(i + 1) * cw])
        O[k, y0:y0 + h, x0:x0 + cw] = np.where(cell[..., 3] > 0, cell.view(np.uint32)[..., 0], 0)
        C[k, y0:y0 + h, x0:x0 + cw] = c[:, i * cw:(i + 1) * cw]
        M[k, y0:y0 + h, x0:x0 + cw] = True
    before = C.copy()
    views = ((O, C, M), (O[:, :, ::-1], C[:, :, ::-1], M[:, :, ::-1]))   # the mirror views see C as it fills
    for k in range(1, len(cells)):
        found = []
        for m, (Ov, _, Mv) in enumerate(views):
            both = Mv[:k] & M[k]
            same = (Ov[:k] == O[k]) & both
            fig = ((Ov[:k] != 0) | (O[k] != 0)) & both
            share = (same & fig).sum((1, 2)) / np.maximum(fig.sum((1, 2)), 1)
            found += [(j, m, same[j]) for j in np.nonzero(share >= LINK)[0]]
        done = np.zeros((Hc, Wc), bool)
        for j, m, same in sorted(found, key=lambda f: (f[0], f[1])):    # the earliest frame wins, as drawn before mirrored
            Ov, Cv = views[m][0], views[m][1]
            outline = ~ndimage.binary_dilation((Ov[j] != 0) != (O[k] != 0), np.ones((3, 3), bool))   # the silhouette round it alike too
            same = same & (outline | ((Cv[j, ..., 3] > 0) == (C[k, ..., 3] > 0)))   # else j's edge fixes would land on k's other outline as specks and holes
            take = same & ~done & ((Cv[j, ..., 3] > 0) | (C[k, ..., 3] > 0))
            C[k][take] = Cv[j][take]
            done |= same
    changed = [0] * len(sheets)
    for k, (s, i) in enumerate(cells):
        y0, x0, h, cw = place[k]
        changed[s] += int((C[k] != before[k]).any(-1).sum())
        sheets[s][2][:, i * cw:(i + 1) * cw] = C[k, y0:y0 + h, x0:x0 + cw]
    return changed


def relink_folder(folder, orig):
    """--relink ORIG: a later pass (--paint, --match) treats each move alone, so frames that were the same drawing (a swing
    ending on the stand, parked frames) come out a shade apart. Relinks the game's sheets against ORIG/<folder>/ (sheets
    where they were still linked: art/_work/doctor_backup_strong/) into art/_work/doctor_relink/<folder>/. A sheet whose
    size changed since (--hitch added a cell) is left out. Returns the px changed per sheet."""
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    out_dir = os.path.join(GAME, "art", "_work", "doctor_relink", folder)
    os.makedirs(out_dir, exist_ok=True)
    first = {}
    for a in man["anims"].values():
        first.setdefault(a["file"], a)
    sheets = []
    for fname in sorted(first, key=lambda f: (not f.startswith("idle"), f)):    # stands first, as doctor_folder
        o, c = (os.path.join(d, fname) for d in (orig, os.path.join(GAME, "art", folder)))
        if not (os.path.exists(o) and os.path.exists(c)):
            continue
        o, c = (np.array(Image.open(x).convert("RGBA")) for x in (o, c))
        if o.shape != c.shape:
            print(f"{folder}/{fname}: size changed since {orig}, left out", flush=True)
            continue
        a = first[fname]
        sheets.append((fname, o, c, int(a.get("w", man["cell"][0])), int(a.get("below", 0))))
    changed = dict(zip((s[0] for s in sheets), relink(sheets))) if sheets else {}
    for fname, _, c, _, _ in sheets:
        Image.fromarray(c).save(os.path.join(out_dir, fname))
    print(f"{folder}: relinked {sum(changed.values())} px over {len(sheets)} sheets", flush=True)
    return changed

def doctor_folder(folder, keys=(), out_dir=None, gifs=True, do_tidy=True, strong=False, src=None):
    """src: the folder of sheets to clean (art/<folder>/ by default); they must be the uncleaned ones, as cleaning twice
    drifts them."""
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    src = src or os.path.join(GAME, "art", folder)
    out_dir = out_dir or os.path.join(GAME, "art", "_work", "doctor_strong" if strong else "doctor", folder)
    os.makedirs(out_dir, exist_ok=True)
    report = {}
    by_file = {}
    for key, a in man["anims"].items():
        if keys and key not in keys:
            continue
        by_file.setdefault(a["file"], []).append((key, a))
    sheets, made = [], []
    for fname, uses in sorted(by_file.items(), key=lambda u: (not u[0].startswith("idle"), u[0])):   # stands first: they win the links
        path = os.path.join(src, fname)
        if not os.path.exists(path):
            continue
        sheet = np.array(Image.open(path).convert("RGBA"))
        new = sheet.copy()
        for key, a in uses:
            cw, n, st = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0))
            loop = bool(a.get("loop", False))
            fr = frames_of(sheet, cw, n, st)
            tidied = [f.copy() for f in fr]
            tidy_px = 0
            if do_tidy:
                heads = head_masks(fr, folder, key, man, src)
                for i, f in enumerate(fr):
                    tidied[i], c = tidy(f, heads[i], strong)
                    tidy_px += c
            fixed, counts = treat(tidied, loop)
            fixed2, counts2 = treat(fixed, loop)      # a second pass catches blips that sat next to each other
            for c in counts:
                counts[c] += counts2[c]
            for i, f in enumerate(fixed2):
                new[:, (st + i) * cw:(st + i + 1) * cw] = f
            counts["tidy"] = tidy_px
            report[key] = dict(file=fname, frames=n, loop=loop, fixed=counts,
                               specks_before=round(np.mean([specks(x) for x in fr]), 1), specks_after=round(np.mean([specks(x) for x in fixed2]), 1),
                               changed_px=int(sum((_dist(x, y) > 0).sum() for x, y in zip(fr, fixed2))),
                               figure_px=int(sum(_solid(x).sum() for x in fr)),
                               flicker_before=round(flicker_score(fr, loop), 1), flicker_after=round(flicker_score(fixed2, loop), 1),
                               unsteady_before=round(unsteady(fr, loop), 1), unsteady_after=round(unsteady(fixed2, loop), 1),
                               seam=round(seam(fr), 2) if loop else None)
            made.append((key, fr, new, cw, st, a.get("fps", 10)))
        a = uses[0][1]
        sheets.append((fname, sheet, new, int(a.get("w", man["cell"][0])), int(a.get("below", 0))))
    # shortcut: only the sheets cleaned in this run link to each other; a new move cleaned alone doesn't link to the
    # sheets already in the game (their originals are gone), so clean it with the folder's stand if they share frames
    linked = dict(zip((s[0] for s in sheets), relink(sheets))) if sheets else {}
    for fname, _, new, _, _ in sheets:
        Image.fromarray(new).save(os.path.join(out_dir, fname))
    for key, fr, new, cw, st, fps in made:
        report[key]["linked_px"] = linked[report[key]["file"]]      # the sheet's, shared by the moves cut from it
        if gifs and len(fr) >= MIN_FRAMES:
            before_after_gif(fr, frames_of(new, cw, len(fr), st), os.path.join(out_dir, f"{key}_before_after.gif"), fps)
    json.dump(report, open(os.path.join(out_dir, "report.json"), "w"), indent=1)
    return report


def before_after_gif(before, after, path, fps, zoom=4):
    """Before on the left, after in the middle, the pixels the doctor changed in red on the right; on sand."""
    sol = np.stack([_solid(f) for f in before + after]).any(0)
    if not sol.any():
        return
    ys, xs = np.nonzero(sol)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    H, W = y1 - y0 + 4, x1 - x0 + 4
    out = []
    for b, a in zip(before, after):
        pane = Image.new("RGBA", (W * 3, H), (196, 178, 140, 255))
        for i, f in enumerate((b, a)):
            pane.alpha_composite(Image.fromarray(f[y0:y1, x0:x1]), (i * W + 2, 2))
        ch = (_dist(b, a) > 0)[y0:y1, x0:x1]
        mark = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        mark[_solid(a)[y0:y1, x0:x1] | _solid(b)[y0:y1, x0:x1]] = (110, 100, 80, 255)
        mark[ch] = (230, 30, 30, 255)
        pane.alpha_composite(Image.fromarray(mark), (2 * W + 2, 2))
        out.append(pane.resize((pane.width * zoom, pane.height * zoom), Image.NEAREST).convert("RGB"))
    out[0].save(path, save_all=True, append_images=out[1:], duration=int(1000 / max(fps, 1)), loop=0)
