"""Sprite doctor, --match (one palette and the master's skin split). The usage and the reasons are in sprite_doctor.py's docstring."""
import json
import numpy as np
import os
import sys
from PIL import Image
from collections import Counter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_consistency as sc       # --match: the master's colours in Lab, the shader's luma bands
from doctor_core import GAME, MIN_FRAMES, X3, _dist, _shift, _solid, before_after_gif, frames_of, head_masks
from doctor_shapes import pick_key, strip
from doctor_paint import PAINT_FACE, carry, crop, lum, master_cmp

# --match (round four, the judge's try_match.py): Lab distance a pixel may snap over; a master colour under MATCH_MIN px is a
# stray, not palette; the gold buckle is warm like skin but isn't
MATCH_SNAP, MATCH_MIN, MATCH_NOT_SKIN = 22, 8, {(160, 106, 30), (203, 154, 57)}
MATCH_GREY = 30     # chroma (max-min) under this is grey (steel) and never snaps to a colour over it (leather)
# the tone step (round four's judge, try B): the key is a MATCH_KEY-square mean of the input's luma; a thin run MATCH_MARK luma off
# both sides and MATCH_MARK_MIN px long is a drawn line; ramp colours under MATCH_GROUP luma apart are one tone; regions under
# MATCH_TINY px merge; every tone ends within MATCH_TOL of the master's share
MATCH_KEY, MATCH_MARK, MATCH_MARK_MIN, MATCH_GROUP, MATCH_TINY, MATCH_TOL = 5, 12, 3, 6, 3, 0.01


def master_ramp(path):
    """The master's palette (colours of MATCH_MIN px or more), its Lab and bands, the skin ramp (shade to light, as
    indices into the palette) and the master's share of each ramp colour."""
    m = np.array(Image.open(path).convert("RGBA"))
    cnt = Counter(map(tuple, m[_solid(m)][:, :3].tolist()))
    pal = np.array([c for c, n in cnt.items() if n >= MATCH_MIN], np.uint8)
    skin = sorted([i for i, c in enumerate(pal.tolist()) if c[0] >= 150 and c[0] > c[1] + 30 and c[1] > c[2] and tuple(c) not in MATCH_NOT_SKIN],
                  key=lambda i: lum(pal[i]))
    share = np.array([cnt[tuple(pal[i].tolist())] for i in skin], float)
    return pal, sc.lab(pal), sc.band(pal), skin, share / max(share.sum(), 1)


def snap_frame(f, pal, plab, pband):
    """Every solid pixel takes the Lab-nearest master colour of its luma band when within MATCH_SNAP; farther (steel,
    a glow, dust) and a pixel with no master colour in its band stay as drawn."""
    out, sol = f.copy(), _solid(f)
    px = f[sol][:, :3]
    d = np.linalg.norm(sc.lab(px)[:, None] - plab[None], axis=2)
    d[sc.band(px)[:, None] != pband[None]] = np.inf
    d[(chroma(px) < MATCH_GREY)[:, None] & (chroma(pal) > MATCH_GREY)[None]] = np.inf    # the L sword's grey steel is Lab-close to leather
    j = d.argmin(1)
    ok = d[np.arange(len(j)), j] <= MATCH_SNAP
    new = px.copy()
    new[ok] = pal[j[ok]]
    out[sol, :3] = new
    return out


def chroma(px):
    return px[..., :3].astype(int).max(-1) - px[..., :3].astype(int).min(-1)


def skin_of(f, pal, skin):
    return _solid(f) & np.logical_or.reduce([(f[..., :3] == pal[i]).all(-1) for i in skin])


def tone_groups(pal, skin):
    """Ramp colours (shade to light) under MATCH_GROUP luma apart are one tone: [[0,1],[2],[3,4],[5,6]] for Vulcan."""
    groups, L = [[0]], [lum(pal[i]) for i in skin]
    for i in range(1, len(skin)):
        (groups[-1].append(i) if L[i] - L[groups[-1][-1]] < MATCH_GROUP else groups.append([i]))
    return groups


def thin_runs(L, dark):
    """Pixels of a 1-2 px wide run darker (dark) or lighter than both sides by MATCH_MARK, across or down."""
    lift = np.zeros_like(L)
    for se in ((1, 3), (3, 1)):
        lift = np.maximum(lift, (ndimage.grey_closing(L, se) - L) if dark else (L - ndimage.grey_opening(L, se)))
    return lift > MATCH_MARK


def marks_of(f, pal, skin, body):
    """(dark, light) marks on the input f: thin runs of skin-like colour, MATCH_MARK_MIN+ px long, touching body skin."""
    rgb, sol = f[..., :3].astype(int), _solid(f)
    L = lum(f[..., :3]) * sol
    skinish = sol & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] > rgb[..., 2]) & (chroma(f) >= MATCH_GREY) & ndimage.binary_dilation(body)
    out = []
    for dark, lim in ((True, L < lum(pal[skin[0]]) - 4), (False, L > lum(pal[skin[-1]]) - 4)):
        m = thin_runs(L, dark) & skinish & lim & (L > 45)
        lab, n = ndimage.label(m, X3)
        out.append(np.isin(lab, np.nonzero(ndimage.sum(m, lab, range(1, n + 1)) >= MATCH_MARK_MIN)[0] + 1) & m)
    return out


def largest_region(mask):
    cc, k = ndimage.label(mask, X3)
    return mask if not k else cc == (np.argmax(ndimage.sum(mask, cc, range(1, k + 1))) + 1)


def merge_tiny(lab, pool):
    """Regions under MATCH_TINY px of any tone take the commonest neighbouring tone, up to three rounds."""
    for _ in range(3):
        moved = 0
        for g in range(lab.max() + 1):
            m = (lab == g) & pool
            cc, k = ndimage.label(m, X3)
            if not k:
                continue
            tiny = np.isin(cc, np.nonzero(ndimage.sum(m, cc, range(1, k + 1)) < MATCH_TINY)[0] + 1)
            best, cnt = np.full(lab.shape, -1), np.zeros(lab.shape, int)
            for t in range(lab.max() + 1):
                if t != g:
                    c = ndimage.convolve(((lab == t) & pool).astype(int), X3.astype(int), mode="constant")
                    best[c > cnt], cnt[c > cnt] = t, c[c > cnt]
            fix = tiny & (best >= 0)
            lab[fix], moved = best[fix], moved + int(fix.sum())
        if not moved:
            break
    return lab


def rebalance(lab, pool, key, target):
    """Pixels move from the tone most in surplus to the tone most in deficit along the edge of the deficit tone's largest
    region (seeding a MATCH_TINY-px patch at the surplus tone's edge when they do not touch) until all within MATCH_TOL."""
    N = pool.sum()
    for _ in range(300):
        dev = np.array([((lab == g) & pool).sum() for g in range(len(target))]) - target
        if (np.abs(dev) <= MATCH_TOL * N).all():
            break
        gd, gs = int(np.argmin(dev)), int(np.argmax(dev))
        src, R = (lab == gs) & pool, largest_region((lab == gd) & pool)
        cand = src & ndimage.binary_dilation(R, X3)
        seed = not cand.any()
        if seed:
            big = largest_region(src)
            ys, xs = np.nonzero(big & ~ndimage.binary_erosion(big, X3))
            if not ys.size:
                break
            p = np.argmin(key[ys, xs]) if gd < gs else np.argmax(key[ys, xs])
            one = np.zeros(lab.shape, bool)
            one[ys[p], xs[p]] = True
            cand = src & ndimage.binary_dilation(one, X3)
        ys, xs = np.nonzero(cand)
        want = MATCH_TINY if seed else int(np.ceil(min(-dev[gd], dev[gs])))
        order = np.argsort(key[ys, xs] if gd < gs else -key[ys, xs], kind="stable")[:want]
        if not order.size:
            break
        lab[ys[order], xs[order]] = gd
    return lab


def tone_frame(f, s, pal, skin, share, head, lock=None):
    """The snapped frame s with its body skin (the head is pasted back later and left out; lock: pixels whose tone was
    carried from the key and stays) re-split across the master's ramp so the light/base/shade shares equal the master's,
    as the top of the file says: marks of the input f kept, the rest cut by quantile of the input's MATCH_KEY-square
    mean luma per tone, tiny regions merged, shares balanced, each tone split between its near-twin colours. Returns the
    frame and the mask of marks."""
    out, sol = s.copy(), _solid(s)
    body = skin_of(s, pal, skin) & ~head
    dark, light = marks_of(f, pal, skin, body)
    lock = np.zeros(body.shape, bool) if lock is None else lock & body & ~dark & ~light
    pool = body & ~dark & ~light & ~lock
    n_pool, nd, nl = int(pool.sum()), int((dark & body).sum()), int((light & body).sum())
    if n_pool < MATCH_MIN:
        return out, dark | light
    t = share * (n_pool + nd + nl + lock.sum())                    # ramp marks count as the darkest / lightest tone
    for i, step, n in ((0, 1, nd), (len(t) - 1, -1, nl)):
        while n > 0 and 0 <= i < len(t):
            take = min(n, t[i]); t[i] -= take; n -= take; i += step
    t = np.maximum(t - [int((lock & (s[..., :3] == pal[i]).all(-1)).sum()) for i in skin], 0)   # locked pixels as their own tone
    t = t / max(t.sum(), 1) * n_pool
    groups = tone_groups(pal, skin)
    gt = np.array([t[g].sum() for g in groups])
    key = ndimage.uniform_filter(lum(f[..., :3]) * sol, MATCH_KEY) / np.maximum(ndimage.uniform_filter(sol.astype(float), MATCH_KEY), 1e-6)
    ys, xs = np.nonzero(pool)
    order = np.argsort(key[ys, xs], kind="stable")
    lab = np.full(f.shape[:2], -1)
    lab[ys[order], xs[order]] = np.searchsorted(np.round(np.cumsum(gt)).astype(int), np.arange(len(ys)), side="right").clip(0, len(groups) - 1)
    lab = merge_tiny(lab, pool)
    for _ in range(2):                                             # seeds are MATCH_TINY px, so they outlive the merge
        lab = merge_tiny(rebalance(lab, pool, key, gt), pool)
    lab = rebalance(lab, pool, key, gt)                            # the shares get the last word
    for gi, g in enumerate(groups):                                # each tone split between its near-twin colours by key
        ys, xs = np.nonzero((lab == gi) & pool)
        order = np.argsort(key[ys, xs], kind="stable")
        cut = np.round(np.cumsum(t[g]) / max(t[g].sum(), 1e-6) * len(ys)).astype(int)
        out[ys[order], xs[order], :3] = pal[np.array(skin)[g][np.searchsorted(cut, np.arange(len(ys)), side="right").clip(0, len(g) - 1)]]
    out[dark & body, :3], out[light & body, :3] = pal[skin[0]], pal[skin[-1]]
    return out, dark | light


def match_move(frames, heads, ramp, loop=False):
    """--match on one move's frames: snap, tone, and for a move of MIN_FRAMES+ frames the key frame's tones carried along
    the flow as --paint does (never a head or a mark), the rest of each frame re-split round them; the head pasted back
    and asserted identical. Returns the toned frames, the snapped ones (the skin split before toning is only measurable
    on master colours) and the px carried."""
    pal, plab, pband, skin, share = ramp
    snapped = [snap_frame(f, pal, plab, pband) for f in frames]
    toned, carried = [s.copy() for s in snapped], 0
    if skin:                    # a master with no skin ramp (the old preview Elvis) gets the palette snap alone
        toned, marks = map(list, zip(*[tone_frame(f, s, pal, skin, share, h) for f, s, h in zip(frames, snapped, heads)]))
        if len(frames) >= MIN_FRAMES:
            moved, carried, locks = carry(toned, loop, pick_key(toned, loop), [h | m for h, m in zip(heads, marks)],
                                          lambda f: np.where(skin_of(f, pal, skin), 0, -1))
            toned = [tone_frame(f, m, pal, skin, share, h, lock=l)[0] if l.any() else t
                     for f, m, t, h, l in zip(frames, moved, toned, heads, locks)]
    for o, f, h in zip(toned, frames, heads):
        o[h] = f[h]
        assert (o[h] == f[h]).all(), "match repainted the head"
    return toned, snapped, carried


def skin_split(frames, pal, skin, heads=None):
    """Share of the move's skin pixels (off the head, when masks are given) on each colour of the ramp, shade to light."""
    body = [_solid(f) & ~h for f, h in zip(frames, heads or [np.zeros(f.shape[:2], bool) for f in frames])]
    n = np.array([sum(int((b & (f[..., :3] == pal[i]).all(-1)).sum()) for f, b in zip(frames, body)) for i in skin], float)
    return [round(x, 2) for x in (n / max(n.sum(), 1)).tolist()]


def match_folder(folder, keys=(), gifs=True, out_root=None):
    """--match over one character's game sheets: sheets, report.json, GIFs, 8x strips and master_cmp.png go to
    art/_work/doctor_match/<folder>/ (or out_root/<folder>/); a folder without a master is skipped."""
    src, out_dir = os.path.join(GAME, "art", folder), os.path.join(out_root or os.path.join(GAME, "art", "_work", "doctor_match"), folder)
    if not os.path.exists(os.path.join(src, "master.png")):
        print(f"{folder:<14} no master.png: skipped", flush=True)
        return {}
    man = json.load(open(os.path.join(src, "manifest.json")))
    os.makedirs(out_dir, exist_ok=True)
    ramp = master_ramp(os.path.join(src, "master.png"))
    pal, skin = ramp[0], ramp[3]
    print(f"{folder:<14} master {len(pal)} colours, skin ramp {[tuple(pal[i].tolist()) for i in skin]} split {[round(x, 2) for x in ramp[4].tolist()]}", flush=True)
    report, sheets, shown, protect, moves = {}, {}, {}, {}, []
    for key, a in man["anims"].items():
        cw, n, st, loop = int(a.get("w", man["cell"][0])), int(a["frames"]), int(a.get("start", 0)), bool(a.get("loop", False))
        if (keys and key not in keys) or not os.path.exists(os.path.join(src, a["file"])):
            continue
        if a["file"] not in sheets:
            sheet = np.array(Image.open(os.path.join(src, a["file"])).convert("RGBA"))
            sheets[a["file"]] = (sheet, sheet.copy())
            protect[a["file"]] = np.zeros(sheet.shape[:2], bool)
        fr = frames_of(sheets[a["file"]][0], cw, n, st)
        heads = [np.logical_or.reduce([_shift(h, -d, 0) for d in range(PAINT_FACE + 1)]) & _solid(f)
                 for h, f in zip(head_masks(fr, folder, key, man, src), fr)]
        for i, h in enumerate(heads):     # moves sharing cells (charge/lunge/thrust) have different head masks: every one holds
            protect[a["file"]][:, (st + i) * cw:(st + i + 1) * cw] |= h
        moves.append((key, a["file"], cw, n, st, heads))
        fixed, snapped, carried = match_move(fr, heads, ramp, loop)
        for i, f in enumerate(fixed):
            sheets[a["file"]][1][:, (st + i) * cw:(st + i + 1) * cw] = f
        colours = [len(np.unique(np.concatenate([f[_solid(f)][:, :3] for f in fs]), axis=0)) for fs in (fr, fixed)]
        changed, figure = int(sum((_dist(x, y) > 0).sum() for x, y in zip(fr, fixed))), int(sum(_solid(x).sum() for x in fr))
        split = [skin_split(fs, pal, skin, heads) for fs in (snapped, fixed)]     # before: after the snap, which maps the move's own colours onto the ramp
        head_same = all((x[h] == y[h]).all() for x, y, h in zip(fr, fixed, heads))
        report[key] = dict(file=a["file"], frames=n, skin_before=split[0], skin_after=split[1], changed_px=changed, figure_px=figure,
                           colours=colours, carried_px=carried, head_same=head_same)
        print(f"{folder:<14}{key:<20} fr {n:>2} skin {split[0]} -> {split[1]}  changed {changed / max(figure, 1) * 100:5.1f}%  "
              f"carried {carried:>5}  colours {colours[0]:>3}->{colours[1]:<3} head {'same' if head_same else 'CHANGED'}", flush=True)
        rows = crop([fr, fixed])
        for i in range(0, n, 6):
            strip([r[i:i + 6] for r in rows], os.path.join(out_dir, f"{key}_strip{'' if i == 0 else i // 6 + 1}.png"), 8)
        if gifs and n > 1:
            before_after_gif(fr, fixed, os.path.join(out_dir, f"{key}_before_after.gif"), a.get("fps", 10))
        what = "idle" if key.startswith("idle") else "move" if key.startswith(("run", "walk")) else "other"
        shown.setdefault(what, rows[1][pick_key(fixed, loop) if what == "idle" and n > 1 else n // 2])
    for fname, (orig, new) in sheets.items():
        new[protect[fname]] = orig[protect[fname]]
        Image.fromarray(new).save(os.path.join(out_dir, fname))
    for key, fname, cw, n, st, heads in moves:     # the guarantee is on the saved sheet, after every move sharing it wrote
        orig, new = (frames_of(s, cw, n, st) for s in sheets[fname])
        report[key]["head_same"] = all((x[h] == y[h]).all() for x, y, h in zip(orig, new, heads))
        assert report[key]["head_same"], f"{folder}/{key}: head changed on the saved sheet"
    json.dump(report, open(os.path.join(out_dir, "report.json"), "w"), indent=1)
    if shown:
        idle, move, other = (shown.get(k) for k in ("idle", "move", "other"))
        master_cmp(folder, idle if idle is not None else move if move is not None else other, move if move is not None else other if other is not None else idle, os.path.join(out_dir, "master_cmp.png"))
    return report
