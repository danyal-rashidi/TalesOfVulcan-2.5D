"""Sprite doctor, --paint (flat interiors, one-pixel outline). The usage and the reasons are in sprite_doctor.py's docstring."""
import json
import numpy as np
import os
from PIL import Image
from scipy import ndimage
from doctor_core import GAME, INK_L, LUMA, RING, SHADE_L, X3, X4, _dist, _shift, _solid, before_after_gif, frames_of, head_masks, treat, unsteady
from doctor_shapes import SHAPE_PART, SHAPE_REACH, SHAPE_SPEED, SHAPE_WIN, flow, pick_key, strip

# --paint (round three: the judge's shipped pieces of art/_work/paint/try_artist.py and try_edges.py, with their knobs as tried)
PAINT_MERGE, PAINT_FLAT, PAINT_SPECK, PAINT_FORM, PAINT_CONF = 24, 8, 2, 12, 0.5   # L1 of one shade; px of a flat patch, a dot, a mark; carry agreement
PAINT_FACE = 5                      # px the head mask is grown downward: the head finder stops at the eyes; mouth and beard stay as drawn
CHROMA_DIR, CHROMA_RATIO, GREY, NEAR_BLACK = 0.97, 0.35, 10, 12   # two shades of one ramp: chroma cosine and magnitude ratio; grey under; luma that is ink
PAINT_TOOTH, PAINT_RUN = 1, 12      # longest bump treated as a staircase tooth; longest zigzag border straightened
PAINT_EDGES_ONLY = {"vulcan_human", "vulcan_new_sword", "vulcan_boss", "jackal", "scorpion", "carriage_pull",   # outline only: see the top of the file
                    "elvis", "standin"}   # the old 240x160 preview Elvis and the stand-in are not palette-locked (29-32 colours, soft shading): the interior
                                          # merged 16 of Elvis's colours, repainted 60% of a figure, smeared the stand-in's torso two-tone and took hours


def lum(rgb):
    return (rgb.astype(float) * LUMA).sum(-1)


def _enc(rgb):
    return (rgb[..., 0].astype(np.int64) << 16) | (rgb[..., 1].astype(np.int64) << 8) | rgb[..., 2]


def same_material(a, b):
    """Per pixel: can rgb a and b be shades of one material? Luma a shade apart, chroma pointing the same way; grey with grey."""
    la, lb = lum(a), lum(b)
    ca, cb = a.astype(float) - la[..., None], b.astype(float) - lb[..., None]
    ma, mb = np.linalg.norm(ca, axis=-1), np.linalg.norm(cb, axis=-1)
    cos = (ca * cb).sum(-1) / np.maximum(ma * mb, 1e-6)
    ratio = np.minimum(ma, mb) / np.maximum(np.maximum(ma, mb), 1e-6)
    alike = np.where((ma < GREY) | (mb < GREY), (ma < GREY) & (mb < GREY), (cos >= CHROMA_DIR) & (ratio >= CHROMA_RATIO))
    return (np.abs(la - lb) <= SHADE_L) & alike


def ramp_ids(frames):
    """The move's palette chained into ramps (same_material between shades, ink left out): rgb -> ramp id, -1 for none."""
    from scipy.sparse.csgraph import connected_components
    cols = np.unique(np.concatenate([f[_solid(f)][:, :3] for f in frames]), axis=0)
    cols = cols[lum(cols) >= NEAR_BLACK]
    _, ids = connected_components(same_material(cols[:, None, :], cols[None, :, :]))
    keys = _enc(cols)

    def rid(rgb):
        k = _enc(rgb)
        i = np.searchsorted(keys, k).clip(0, len(keys) - 1)
        return np.where(keys[i] == k, ids[i], -1)
    return rid


def merge_palette(frames):
    """Colours within PAINT_MERGE of a commoner colour take it; returns new frames and the number merged."""
    cols, cnt = np.unique(np.concatenate([f[_solid(f)][:, :3] for f in frames]), axis=0, return_counts=True)
    cols, to = cols.astype(int), {}
    for i in np.argsort(cnt):
        d = np.abs(cols - cols[i]).sum(-1)
        d[(cnt <= cnt[i]) | (np.arange(len(cols)) == i)] = 10 ** 6
        if d.min() <= PAINT_MERGE:
            to[i], cnt[d.argmin()] = d.argmin(), cnt[d.argmin()] + cnt[i]
    out = [f.copy() for f in frames]
    for i, j in to.items():
        while j in to:
            j = to[j]
        for f, o in zip(frames, out):
            o[(f[..., :3] == cols[i]).all(-1) & _solid(f), :3] = cols[j]
    return out, len(to)


def blobs(frame, mask):
    """Same-colour regions within mask: a label image (0 outside) and the regions' sizes."""
    key = np.where(mask, _enc(frame[..., :3]), -1)
    lab, n = np.zeros(mask.shape, int), 0
    for v in np.unique(key[mask]):
        l, k = ndimage.label(key == v)
        lab[l > 0], n = l[l > 0] + n, n + k
    return lab, (ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1)) if n else np.zeros(0))


def _patch(o, free, lab, b, rid):
    m = lab == b
    ring = ndimage.binary_dilation(m) & ~m & free
    c, cols = o[m][0, :3], o[ring][:, :3]
    return m, c, cols, rid(cols) == rid(c), lab[ring]


def extreme(c, cols):
    return (lum(cols) < lum(c)).all() or (lum(cols) > lum(c)).all()


def flatten(o, free, rid):
    """Patches under PAINT_FLAT px take the shade of their ramp they touch most; a dot of another ramp up to PAINT_SPECK px
    takes what surrounds it; a highlight or shadow over PAINT_SPECK px is a mark, left for form(). In place; px changed."""
    changed = 0
    for _ in range(3):
        lab, sizes = blobs(o, free)
        n = 0
        for b in np.nonzero(sizes < PAINT_FLAT)[0] + 1:
            m, c, cols, ok, _ = _patch(o, free, lab, b, rid)
            if not len(cols):
                continue
            if not ok.any():
                if m.sum() > PAINT_SPECK:
                    continue
                ok[:] = True
            elif m.sum() > PAINT_SPECK and extreme(c, cols):
                continue
            u, cnt = np.unique(cols[ok], axis=0, return_counts=True)
            o[m, :3] = u[cnt.argmax()]
            n += int(m.sum())
        changed += n
        if not n:
            break
    return changed


def form(o, free, rid):
    """One highlight and one shadow per flat area: of the marks under PAINT_FORM px in one area only the largest of each
    kind stays; the others take the area's shade. In place; returns px changed."""
    lab, sizes = blobs(o, free)
    marks, kept, changed = [], set(), 0
    for b in np.nonzero(sizes < PAINT_FORM)[0] + 1:
        m, c, cols, ok, labs = _patch(o, free, lab, b, rid)
        if not ok.any() or not extreme(c, cols):
            continue
        u, cnt = np.unique(labs[ok], return_counts=True)
        marks.append((int(sizes[b - 1]), (u[cnt.argmax()], bool(lum(c) > lum(cols).mean())), m))
    for size, k, m in sorted(marks, key=lambda t: -t[0]):
        if k in kept:
            o[m, :3] = o[lab == k[0]][0, :3]
            changed += int(m.sum())
        kept.add(k)
    return changed


def carry(frames, loop, key, protect, rid):
    """Every frame's shading becomes the key's where the chain to the key agrees at PAINT_CONF every step, the part moved
    at most SHAPE_SPEED px/frame and both pixels are shades of one ramp (never protect, ramp or alpha). Frames, px carried,
    the mask of tracked pixels per frame."""
    n, (H, W) = len(frames), frames[0].shape[:2]
    out, flows, carried, oks = [f.copy() for f in frames], {}, 0, [np.zeros((H, W), bool) for _ in frames]
    for k in range(n):
        if k == key:
            continue
        step = 1 if (loop and (key - k) % n <= n // 2) or (not loop and key > k) else -1
        (ys, xs), c, sp, ok, a = np.indices((H, W)), np.ones((H, W)), np.zeros((H, W)), np.ones((H, W), bool), k
        while a != key:
            b = (a + step) % n
            if (a, b) not in flows:
                flows[(a, b)] = flow(frames[a], frames[b], SHAPE_WIN, SHAPE_REACH, SHAPE_PART)
            dy, dx, ag = flows[(a, b)]
            yy, xx = ys.clip(0, H - 1), xs.clip(0, W - 1)
            c, sp = np.minimum(c, ag[yy, xx]), np.maximum(sp, np.maximum(abs(dy), abs(dx))[yy, xx])
            ys, xs, a = ys + dy[yy, xx], xs + dx[yy, xx], b
            ok &= (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
        src = frames[key][ys.clip(0, H - 1), xs.clip(0, W - 1)]
        ok &= (c >= PAINT_CONF) & (sp <= SHAPE_SPEED) & ~protect[k] & _solid(frames[k]) & _solid(src)
        ok &= (rid(frames[k]) == rid(src)) & (rid(src) >= 0)
        out[k][ok, :3] = src[ok, :3]
        carried, oks[k] = carried + int((ok & (_dist(frames[k], src) > 0)).sum()), ok
    return out, carried, oks


def labels(f):
    """Per pixel the packed RGB, -1 where transparent: the frame as a drawing of colour regions."""
    return np.where(_solid(f), _enc(f[..., :3]), -1)


def ink_of(f):
    return _solid(f) & (lum(f[..., :3]) < INK_L)


def _ink_col(c):
    return (np.array([(c >> 16) & 255, (c >> 8) & 255, c & 255]) * LUMA).sum() < INK_L


def thin_parts(s):
    """Long thin parts (under 3 px wide, 6+ px long) with a 1 px margin: a spear, a sword, a finger, left as drawn."""
    thin = s & ~ndimage.binary_opening(s, X3)
    lab, n = ndimage.label(thin, X3)
    sizes = ndimage.sum(thin, lab, range(1, n + 1))
    return ndimage.binary_dilation(np.isin(lab, 1 + np.nonzero(sizes >= 6)[0]), X3)


def ring_parts(mask, y, x):
    """How many separate groups the true pixels round (y, x) form, going round the ring; 0 when none."""
    r = [mask[y + dy, x + dx] for dy, dx in RING]
    return sum(1 for i in range(8) if r[i] and not r[i - 1]) or int(all(r))


def majority_nb(L, y, x, want):
    """The ring neighbour whose colour is the commonest among those passing want(colour); None when there is none."""
    cols = [(L[y + dy, x + dx], (y + dy, x + dx)) for dy, dx in RING if want(L[y + dy, x + dx])]
    if not cols:
        return None
    best = max(set(c for c, _ in cols), key=lambda c: sum(1 for d, _ in cols if d == c))
    return next(p for c, p in cols if c == best)


def close_gaps(f, protect):
    """A non-ink pixel on the silhouette edge with ink on two sides of it (a 1 px gap in the outline) becomes ink."""
    s, ink, L, n = _solid(f), ink_of(f), labels(f), 0
    edge = s & ~ndimage.binary_erosion(s, X4, border_value=0)
    for y, x in zip(*np.nonzero(edge & ~ink & ~protect)):
        if 0 < y < s.shape[0] - 1 and 0 < x < s.shape[1] - 1 and ring_parts(ink, y, x) >= 2:
            src = majority_nb(L, y, x, lambda c: c >= 0 and _ink_col(c))
            if src:
                f[y, x], ink[y, x], n = f[src], True, n + 1
    return n


def thin_ink(f, protect):
    """Ink at most 2 px thick thins to 1 px from the inside: a pixel of a 2x2 ink block, not on the silhouette, goes where
    the ink stays connected round it, taking the commonest non-ink colour next to it."""
    ink, L, n = ink_of(f), labels(f), 0
    core = ndimage.binary_dilation(ndimage.binary_erosion(ink, X3), X3)
    cand = ink & ~core & ~protect & ndimage.binary_erosion(_solid(f), X4, border_value=0)
    cand[[0, -1], :] = cand[:, [0, -1]] = False
    for y, x in zip(*np.nonzero(cand)):
        if not ink[y, x] or ring_parts(ink, y, x) != 1 or not any(ink[y + a:y + a + 2, x + b:x + b + 2].all() for a in (-1, 0) for b in (-1, 0)):
            continue
        src = majority_nb(L, y, x, lambda c: c >= 0 and not _ink_col(c))
        if src is not None:
            f[y, x], ink[y, x], n = f[src], False, n + 1
    return n


def bumps(f, protect, tooth):
    """Runs of up to tooth px of one colour with a second colour on three sides and their own colour on the fourth
    (a tooth, a notch, a speck off a border) take the second colour; rows then columns. Returns pixels changed."""
    n = 0
    for t in (False, True):
        L = labels(f)
        L, P = (L.T, protect.T) if t else (L, protect)
        H, W = L.shape
        for y in range(1, H - 1):
            x = 1
            while x < W - 1:
                c, k = L[y, x], 1
                while x + k < W - 1 and L[y, x + k] == c:
                    k += 1
                u = L[y, x - 1]
                if k <= tooth and u != c and L[y, x + k] == u and not P[y, x:x + k].any():
                    above, below = L[y - 1, x:x + k], L[y + 1, x:x + k]
                    if ((above == u).all() and (below == c).all()) or ((below == u).all() and (above == c).all()):
                        for i in range(k):
                            f[(x + i, y) if t else (y, x + i)] = f[(x - 1, y) if t else (y, x - 1)]
                        n += k
                x += k
    return n


def straighten(f, protect, run):
    """A border between two colours that zigzags by one pixel over 3..run columns (then rows) is straightened to its
    majority side. Returns pixels changed."""
    n = 0
    for t in (False, True):
        L = labels(f)
        L, P = (L.T, protect.T) if t else (L, protect)
        H, W = L.shape
        for y in range(H - 2):
            pair = [(L[y, x], L[y + 1, x], 0) if L[y, x] != L[y + 1, x] else (L[y, x], L[y + 2, x], 1) if L[y + 1, x] != L[y + 2, x] else None
                    for x in range(W)]                                                # the border below row y: its colours and height
            x = 0
            while x < W:
                if pair[x] is None:
                    x += 1
                    continue
                k = 1
                while x + k < W and pair[x + k] and pair[x + k][:2] == pair[x][:2]:
                    k += 1
                hs = [pair[x + i][2] for i in range(k)]
                changes = sum(1 for i in range(1, k) if hs[i] != hs[i - 1])
                if 3 <= k <= run and changes >= 2 and hs.count(0) != hs.count(1):
                    want = int(hs.count(1) > hs.count(0))
                    for i in range(k):
                        if hs[i] != want and not P[y + 1, x + i]:
                            sy, sx = (y, x + i) if want else (y + 2, x + i)       # colour a from above, b from below
                            f[(x + i, y + 1) if t else (y + 1, x + i)] = f[(sx, sy) if t else (sy, sx)]
                            n += 1
                x += k
    return n


def clean_edges(f, protect, rounds=2):
    """One frame's outline rules in order (gaps, thinning, teeth, zigzags) for rounds, in place; returns the counts."""
    counts = dict(gaps=0, thinned=0, teeth=0, straightened=0)
    for _ in range(rounds):
        for k, v in zip(counts, (close_gaps(f, protect), thin_ink(f, protect), bumps(f, protect, PAINT_TOOTH), straighten(f, protect, PAINT_RUN))):
            counts[k] += v
    return counts


def paint_move(frames, loop, heads, interior=True):
    """--paint on one move (see the top of the file): the interior (unless interior is False), the outline, one treat();
    heads (already grown) pasted back and asserted; frames that were one drawing stay one. Returns frames and counts."""
    work, merged = merge_palette(frames) if interior else ([f.copy() for f in frames], 0)
    counts = dict(merged=merged, flat=0, form=0, carried=0, gaps=0, thinned=0, teeth=0, straightened=0)
    if interior:
        free = [_solid(f) & ~h & ndimage.binary_erosion(_solid(f), X3) & (lum(f[..., :3]) >= NEAR_BLACK) for f, h in zip(work, heads)]
        rid = ramp_ids(work)
        counts["flat"] = sum(flatten(f, fr, rid) for f, fr in zip(work, free))
        key = pick_key(work, loop)
        counts["form"] = sum(form(f, fr, rid) for f, fr in zip(work, free))
        work, counts["carried"], _ = carry(work, loop, key, [~fr for fr in free], rid)
        counts["flat"] += sum(flatten(f, fr, rid) for f, fr in zip(work, free))
    for f, h in zip(work, heads):
        for k, v in clean_edges(f, h | thin_parts(_solid(f))).items():
            counts[k] += v
    fixed, tc = treat(work, loop)
    counts["treat"], seen = sum(tc.values()), {}
    for j, (f, i, h) in enumerate(zip(fixed, frames, heads)):
        f[h] = i[h]
        assert (f[h] == i[h]).all(), "head changed"
        fixed[j] = seen.setdefault(i.tobytes(), f)
    return fixed, counts


def crop(rows, pad=2):
    """Rows of frames cut to the figure's box over all of them."""
    ys, xs = np.nonzero(np.stack([_solid(f) for r in rows for f in r]).any(0))
    if not ys.size:
        return rows
    return [[np.ascontiguousarray(f[max(ys.min() - pad, 0):ys.max() + 1 + pad, max(xs.min() - pad, 0):xs.max() + 1 + pad]) for f in r] for r in rows]


def master_cmp(folder, idle, move, path, zoom=8):
    """The master (art/<folder>/master.png or art/guides/ref_<folder>.png, else the stand frame given) at 8x beside a
    painted idle frame and a painted move frame, on sand."""
    pics, sand = [], (196, 178, 140, 255)
    for p in [os.path.join(GAME, "art", folder, "master.png")] + [os.path.join(GAME, "art", "guides", f"ref_{n}.png") for n in (folder, folder.split("_")[0])]:
        if os.path.exists(p):
            m = Image.open(p).convert("RGBA")
            pics.append(m.resize((m.width * zoom, m.height * zoom), Image.NEAREST) if m.width < 120
                        else m.resize((max(m.width * idle.shape[0] * zoom // m.height, 1), idle.shape[0] * zoom), Image.LANCZOS))
            break
    pics += [Image.fromarray(f).resize((f.shape[1] * zoom, f.shape[0] * zoom), Image.NEAREST) for f in (idle, move)]
    img, x = Image.new("RGBA", (sum(p.width for p in pics) + 8 * (len(pics) + 1), max(p.height for p in pics) + 16), sand), 8
    for p in pics:
        img.alpha_composite(p, (x, 8))
        x += p.width + 8
    img.convert("RGB").save(path)


def paint_folder(folder, keys=(), gifs=True):
    """--paint over one character's --shapes output: sheets, manifest_patch.json, report.json, GIFs, 8x strips and
    master_cmp.png go to art/_work/doctor_paint/<folder>/."""
    man = json.load(open(os.path.join(GAME, "art", folder, "manifest.json")))
    src, out_dir = (os.path.join(GAME, "art", "_work", d, folder) for d in ("doctor_shapes", "doctor_paint"))
    os.makedirs(out_dir, exist_ok=True)
    patch = json.load(open(os.path.join(src, "manifest_patch.json"))) if os.path.exists(os.path.join(src, "manifest_patch.json")) else {}
    if patch:
        json.dump(patch, open(os.path.join(out_dir, "manifest_patch.json"), "w"), indent=1)
    interior, report, sheets, shown = folder not in PAINT_EDGES_ONLY, {}, {}, {}
    for key, a in man["anims"].items():
        a = dict(a, **patch.get(key, {}))
        cw, n, st, loop = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0)), bool(a.get("loop", False))
        if (keys and key not in keys) or n < 2 or not os.path.exists(os.path.join(src, a["file"])):     # a 1-frame move is a cell of another's
            continue
        if a["file"] not in sheets:
            sheet = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
            sheets[a["file"]] = (sheet, sheet.copy())
        fr = frames_of(sheets[a["file"]][0], cw, n, st)
        heads = [np.logical_or.reduce([_shift(h, -d, 0) for d in range(PAINT_FACE + 1)]) & _solid(f)
                 for h, f in zip(head_masks(fr, folder, key, man, src), fr)]
        fixed, counts = paint_move(fr, loop, heads, interior)
        for i, f in enumerate(fixed):                 # as --shapes: a later move sharing cells overwrites them
            sheets[a["file"]][1][:, (st + i) * cw:(st + i + 1) * cw] = f
        colours = [len(np.unique(np.concatenate([f[_solid(f)][:, :3] for f in fs]), axis=0)) for fs in (fr, fixed)]
        small = [sum(int((blobs(f, ndimage.binary_erosion(_solid(f), X3) & ~ink_of(f))[1] < PAINT_FLAT).sum()) for f in fs) for fs in (fr, fixed)]
        changed, figure = int(sum((_dist(x, y) > 0).sum() for x, y in zip(fr, fixed))), int(sum(_solid(x).sum() for x in fr))
        report[key] = dict(file=a["file"], frames=n, loop=loop, interior=interior, fixed=counts, changed_px=changed, figure_px=figure,
                           colours=colours, small_regions=small, unsteady_before=round(unsteady(fr, loop), 1), unsteady_after=round(unsteady(fixed, loop), 1))
        print(f"{folder:<14}{key:<16} fr {n:>2} {'paint' if interior else 'edges'} changed {changed / max(figure, 1) * 100:5.1f}% of figure  colours {colours[0]:>2}->{colours[1]:<2} "
              f"small {small[0]:>4}->{small[1]:<4} unsteady {report[key]['unsteady_before']} -> {report[key]['unsteady_after']}  {counts}", flush=True)
        rows = crop([fr, fixed])
        for i in range(0, n, 6):
            strip([r[i:i + 6] for r in rows], os.path.join(out_dir, f"{key}_strip{'' if i == 0 else i // 6 + 1}.png"), 8)
        if gifs:
            before_after_gif(fr, fixed, os.path.join(out_dir, f"{key}_before_after.gif"), a.get("fps", 10))
        what = "idle" if key.startswith("idle") else "move" if key.startswith(("run", "walk")) else "other"
        shown.setdefault(what, rows[1][pick_key(fixed, loop) if what == "idle" else n // 2])
    for fname, (_, new) in sheets.items():
        Image.fromarray(new).save(os.path.join(out_dir, fname))
    json.dump(report, open(os.path.join(out_dir, "report.json"), "w"), indent=1)
    if shown:                                         # the stand beside a run or walk frame (the first other move where there is none)
        idle, move, other = (shown.get(k) for k in ("idle", "move", "other"))
        master_cmp(folder, idle if idle is not None else move if move is not None else other, move if move is not None else other if other is not None else idle, os.path.join(out_dir, "master_cmp.png"))
    return report
