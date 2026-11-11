"""Sprite doctor, --selftest. The usage and the reasons are in sprite_doctor.py's docstring."""
import numpy as np
import os
import sys
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_consistency as sc       # --match: the master's colours in Lab, the shader's luma bands
from doctor_core import X3, _dist, _shift, _solid, before_after_gif, flicker_score, relink, tidy, treat
from doctor_shapes import align, midframe, shapes_move
from doctor_paint import paint_move
from doctor_match import MATCH_TINY, match_move, skin_split
from doctor_check import compare

def selftest():
    rng = np.random.default_rng(1)
    H, W, n = 40, 40, 8
    base = np.zeros((H, W, 4), np.uint8)
    base[8:32, 12:28] = (120, 80, 50, 255)                  # a body
    base[8:32, 12] = base[8:32, 27] = (20, 20, 30, 255)
    base[8, 12:28] = base[31, 12:28] = (20, 20, 30, 255)    # its outline
    base[14, 16] = base[14, 23] = (240, 240, 230, 255)      # two eyes: lone pixels that are really there
    sway = [0, 1, 1, 0, 0, 1, 1, 0]
    frames = [_shift(base, 0, -sway[k]) for k in range(n)]        # the body sways 0-1 px to the right
    clean = [f.copy() for f in frames]
    frames[3][20, 18] = (200, 150, 90, 255)                 # one-frame shimmer inside the body
    frames[5][12, 13] = (0, 0, 0, 0)                        # one-frame notch in the outline
    frames[6][7, 14] = (90, 60, 40, 255)                    # a one-frame bump on the edge (a lone speck far off is left: it could be a spark)
    frames[1][25, 15] = frames[2][25, 15] = (60, 40, 25, 255)   # shading that crawls in for two frames
    out, counts = treat(frames, loop=True)
    for k in range(n):
        assert (_dist(out[k], clean[k]) == 0).all(), f"frame {k} not restored: {counts}"
    assert counts["shimmer"] >= 1 and counts["edge_restored"] >= 1 and counts["edge_removed"] + counts["island"] >= 1, counts
    moving = [_shift(base, 0, -3 * k) for k in range(n)]   # a real 3 px/frame walk: nothing to fix
    out, counts = treat(moving, loop=False)
    assert all((_dist(a, b) == 0).all() for a, b in zip(out, moving)), counts
    shaded = base.copy()
    shaded[26:30, 13:27] = (150, 100, 64, 255)                         # a lit band: the shade the noise uses is his own
    noise = [shaded.copy() for _ in range(n)]
    for f in noise:                                                     # Seedance noise: his own colours in the wrong place
        m = (rng.random((H, W)) < 0.03) & _solid(f) & (np.indices((H, W))[0] < 26)
        f[m, :3] = np.where(rng.random(m.sum())[:, None] < 0.7, (150, 100, 64), (20, 20, 30))
    out, _ = treat(noise, loop=True)
    assert flicker_score(out, True) < 0.2 * flicker_score(noise, True) + 1, "scattered shimmer not cleaned"
    assert (out[0][14, 16] == base[14, 16]).all(), "an eye was lost"
    t = base.copy()
    t[20, 18] = (130, 88, 56, 255)                           # a shade speck
    t[24, 20] = (30, 20, 15, 255)                            # a dark dot ringed by one colour
    eyes = np.zeros((H, W), bool); eyes[13:16, 15:25] = True
    tt, c = tidy(t, eyes)
    assert c == 2 and (tt[20, 18] == base[20, 18]).all() and (tt[24, 20] == base[24, 20]).all(), c
    assert (tt[14, 16] == base[14, 16]).all() and (tt[14, 23] == base[14, 23]).all(), "tidy repainted an eye"
    spark = [np.zeros((H, W, 4), np.uint8) for _ in range(7)]          # a 2 px spark flying 5 px a frame (review #2)
    for k, f in enumerate(spark):
        f[20, 3 + 5 * k:5 + 5 * k] = (255, 220, 120, 255)
    out, c = treat(spark, loop=False)
    assert all((_dist(a, b) == 0).all() for a, b in zip(out, spark)), f"a fast spark was removed: {c}"
    glint = []
    for k in range(7):                                                  # a glint on a body moving 5 px a frame
        f = np.zeros((H, W, 4), np.uint8)
        f[10:30, 2 + 5 * k:8 + 5 * k] = (120, 80, 50, 255)
        f[15, 4 + 5 * k] = (250, 250, 250, 255)
        glint.append(f)
    out, c = treat(glint, loop=False)
    assert all((_dist(a, b) == 0).all() for a, b in zip(out, glint)), f"a glint on a fast part was repainted: {c}"
    treat([np.full((3, 3, 4), 255, np.uint8)] * 6, True)               # tiny frames don't crash (review #4)
    before_after_gif([np.zeros((H, W, 4), np.uint8)] * 4, [np.zeros((H, W, 4), np.uint8)] * 4, os.devnull, 10)   # review #3
    st_ = base.copy()
    st_[18:26, 15:25] = np.where((np.indices((8, 10)).sum(0) % 3 == 0)[..., None], (128, 86, 54, 255), (120, 80, 50, 255))
    tt, c = tidy(st_, eyes, strong=True)
    assert c > 0 and (_dist(tt, base)[18:26, 15:25] > 0).sum() < (_dist(st_, base)[18:26, 15:25] > 0).sum(), "speckled shading not smoothed"
    assert (tt[8] == base[8]).all() and (tt[14, 16] == base[14, 16]).all(), "strong tidy touched the outline or an eye"
    one = base.copy()
    one[9:31, 13:20] = (150, 100, 64, 255)                              # lit on one side, so a mirror is not the same
    c_one = one.copy()
    c_one[22, 22] = (130, 88, 56, 255)                                  # what the doctor made of the stand
    wide = np.zeros((H + 3, 2 * (W + 4), 4), np.uint8)                  # a swing in wider cells, 3 rows under the ground
    wide[5:30, 5:30] = rng.integers(0, 256, (25, 25, 4), np.uint8) | np.uint8(1)   # its first frame another drawing
    wide[:H, W + 6:2 * W + 6] = one                                     # its last frame the stand, as drawn
    c_wide = wide.copy()
    c_wide[22, W + 28] = (120, 82, 52, 255)                             # cleaned on its own: a shade apart
    c_wide[10, 10] = (1, 2, 3, 255)
    left = one[:, ::-1].copy()                                          # the left sheet: the stand flipped
    c_left = left.copy()
    n_px = relink([("idle", one, c_one, W, 0), ("swing", wide, c_wide, W + 4, 3), ("left", left, c_left, W, 0)])
    assert (c_wide[:H, W + 6:2 * W + 6] == c_one).all() and (c_left == c_one[:, ::-1]).all(), f"shared frames not linked: {n_px}"
    assert (c_wide[10, 10] == (1, 2, 3, 255)).all() and (c_one[22, 22] == (130, 88, 56, 255)).all(), "linking touched another drawing"
    arm = one.copy()
    arm[15:20, 28:31] = (20, 20, 30, 255)                               # the stand with a hand out
    c_arm = arm.copy()
    c_arm[14, 30] = (20, 20, 30, 255)                                   # its cleaning grew the hand's edge a pixel
    c_arm[22, 22] = (130, 88, 56, 255)
    c_bare = one.copy()                                                 # the same stand, the hand in
    relink([("idle", arm, c_arm, W, 0), ("bare", one.copy(), c_bare, W, 0)])
    assert c_bare[14, 30, 3] == 0 and (c_bare[22, 22] == c_arm[22, 22]).all(), "an edge fix linked onto another outline"
    # --shapes: an outlined two-tone limb drifting 1 px a frame whose colour border jitters a column settles on the key's
    # border and still drifts; a block flying 5 px a frame and the head (with its own jitter) stay exactly as drawn
    A, B = (200, 60, 60, 255), (60, 60, 200, 255)
    frames, heads = [], []
    for k, jit in enumerate((0, 1, 0, 1, 0, 1)):
        f = np.zeros((40, 60, 4), np.uint8)
        f[8:22, 8 + k:22 + k] = (20, 20, 20, 255)                        # the outline pins each window's shift
        f[9:21, 9 + k:15 + k + jit] = A
        f[9:21, 15 + k + jit:21 + k] = B
        f[30:38, 4 + 5 * k:10 + 5 * k] = A                               # the fast block
        f[30:36, 44:54] = B; f[31, 46 + jit] = A                         # the head
        head = np.zeros((40, 60), bool); head[29:37, 43:55] = True
        frames.append(f); heads.append(head)
    fixed, key, counts = shapes_move(frames, False, heads)
    for k, f in enumerate(fixed):
        assert (_dist(f[:24], _shift(fixed[0], 0, -k)[:24]) == 0).all(), f"shapes: frame {k}'s border still wobbles"
        assert (f[24:] == frames[k][24:]).all(), f"shapes: frame {k}'s fast part or head changed"
    assert counts["replaced"] > 0 and "untouched" not in counts, counts
    one_pose = [frames[0], frames[0].copy()]
    one_pose[1][9:21, 14] = B                                             # a 2-frame idle whose only difference is a border
    out, _, counts = shapes_move(one_pose, True, heads[:2])
    assert "untouched" in counts and (out[1] == one_pose[1]).all(), "a 2-frame idle silently became a still"
    # the anchor: a stand with a straight belt border; the move draws the belt with a 4 px bump that drifts with the body.
    # The key takes the stand's belt, the belt rides through the move, the fast block and the head stay as drawn
    def body(k, bump, jit=0):
        f = np.zeros((40, 60, 4), np.uint8)
        f[6:30, 8 + k:22 + k] = (20, 20, 20, 255)
        f[7:17, 9 + k:21 + k] = A
        f[17:29, 9 + k:21 + k] = B
        if bump:
            f[17, 12 + k:16 + k] = A
        f[32:38, 4 + 5 * k:10 + 5 * k] = A
        f[30:36, 44:54] = B; f[31, 46 + jit] = A
        return f
    stand = body(0, False)
    moves = [body(k, True, k % 2) for k in range(6)]
    wide = np.zeros((44, 70, 4), np.uint8); wide[2:42, 5:65] = stand        # the stand in a taller, wider cell, 2 rows below ground
    assert (align(wide, 2, stand, 0) == stand).all(), "ground line / middle alignment off"
    fixed, _, counts = shapes_move(moves, False, [heads[0]] * 6, [(wide, 2)], 0)
    assert counts["carried"] == 4 and "untouched" not in counts, counts
    for i, f in enumerate(fixed):
        assert (f[:30] == body(i, False)[:30]).all(), f"anchor: frame {i} kept the bump"
        assert (f[30:] == moves[i][30:]).all(), f"anchor: frame {i}'s fast block or head changed"
    # the freeze guard: a limb whose only motion is its border jitter, plus a 2-row block creeping 1 px a frame, would keep
    # two distinct frames but lose over 70% of its raw change: it comes back untouched
    still = []
    for k, jit in enumerate((0, 1, 0, 1)):
        f = np.zeros((40, 60, 4), np.uint8)
        f[8:22, 8:22] = (20, 20, 20, 255); f[9:21, 9:15 + jit] = A; f[9:21, 15 + jit:21] = B
        f[30:32, 4 + k:10 + k] = A
        still.append(f)
    out, _, counts = shapes_move(still, False, [np.zeros((40, 60), bool)] * 4)
    assert counts.get("untouched") == "would freeze" and all((o == s).all() for o, s in zip(out, still)), counts
    # --hitch: a square 8 px right in B lands 4 px right in the in-between; a still body beside it stays put
    A4, B4 = np.zeros((30, 40, 4), np.uint8), np.zeros((30, 40, 4), np.uint8)
    A4[4:24, 2:8] = B4[4:24, 2:8] = B
    A4[10:16, 12:18], B4[10:16, 20:26] = A, A
    mid = midframe(A4, B4, [A4, A4, A4, B4, B4, B4])
    want = np.zeros_like(A4); want[4:24, 2:8] = B; want[10:16, 16:22] = A
    assert (mid == want).all(), np.argwhere((mid != want).any(-1))
    # --paint: six frames of the outlined body, each with its own 1 px specks of a lighter shade, a 4x4 highlight block of
    # that shade, a staircase tooth of ink on the top outline and (frame 0) a speck on the face: the specks and the tooth
    # go, the block, the eyes, the outline and the face speck stay
    body = base.copy()
    body[22:26, 16:20] = (150, 100, 64, 255)
    body[7, 14] = (20, 20, 30, 255)
    pm = []
    for k in range(6):
        f = body.copy()
        for i, y in enumerate((10, 12, 18, 20)):
            f[y, 14 + (3 * k + 4 * i) % 12] = (150, 100, 64, 255)
        pm.append(f)
    pm[0][14, 20] = (150, 100, 64, 255)
    out, c = paint_move(pm, True, [eyes] * 6)
    want = body.copy(); want[7, 14] = 0
    assert c["flat"] >= 24 and c["teeth"] >= 6, c
    assert all((o == want).all() for o in out[1:]) and (out[0][14, 20] == pm[0][14, 20]).all(), "paint: specks or the tooth left, or the block, eyes or outline changed"
    out, c = paint_move(pm, True, [eyes] * 6, interior=False)
    assert out[1][7, 14, 3] == 0 and (out[1][22:26, 16:20] == body[22:26, 16:20]).all() and c["flat"] == 0, c
    # --match: a master ramp shade/base/light split 1:2:1; frame 0's body is mostly shade, frame 1's mostly base, a
    # near-shade pixel and a steel pixel on each, the (20, 20, 30) outline a band away from the master's ink: both frames
    # end on the master's split, the near shade snapped, the steel, the outline and the eyes untouched
    pal = np.array([(3, 1, 1), (167, 99, 60), (205, 134, 81), (225, 158, 100), (122, 80, 53)], np.uint8)
    ramp = (pal, sc.lab(pal), sc.band(pal), [1, 2, 3], np.array([0.25, 0.5, 0.25]))
    mm = []
    for k, (a, b) in enumerate(((1, 2), (2, 3))):
        f = base.copy()
        f[9:17, 13:27] = (60, 60, 60, 255)                 # a grey vest: no master colour near it
        f[17:31, 13:27] = (*pal[a], 255)
        f[17:31, 23 + k:27] = (*pal[b], 255)
        f[20, 20] = (170, 100, 62, 255)
        f[26, 14] = (180, 180, 200, 255)
        f[12, 14] = (122, 108, 98, 255)                   # the L sword's steel grey: Lab-close to the leather, must not snap
        mm.append(f)
    mm[1][24, 15:24] = (150, 88, 52, 255)                  # a 1-px dark line through the base: a drawn mark, snapped onto the ramp and kept as its darkest tone
    out, _, carried = match_move(mm, [eyes] * 2, ramp)
    mark = np.zeros((H, W), bool); mark[24, 15:24] = True
    for o in out:
        assert (np.abs(np.array(skin_split([o], pal, [1, 2, 3])) - ramp[4]) <= 0.02).all(), skin_split([o], pal, [1, 2, 3])
        for g in (1, 3):                                   # no shade or light region under MATCH_TINY px (the mark aside)
            lab, k = ndimage.label((o[..., :3] == pal[g]).all(-1) & ~mark, X3)
            assert k == 0 or ndimage.sum(np.ones((H, W)), lab, range(1, k + 1)).min() >= MATCH_TINY, "match: a tiny region"
    assert all((o[26, 14] == f[26, 14]).all() and (o[12, 14] == f[12, 14]).all() and (o[8] == f[8]).all() and (o[eyes] == f[eyes]).all() and o[20, 20, 0] != 170 for o, f in zip(out, mm)), "match: steel, the outline or the eyes changed, or the near shade stayed"
    assert (out[1][24, 15:24, :3] == pal[1]).all() and carried == 0, "match: the drawn mark was re-split"
    bare, _, _ = match_move(mm, [eyes] * 2, (*ramp[:3], [], np.array([])))      # no skin ramp: snapped, not toned, no crash
    assert all((b[eyes] == f[eyes]).all() and (b[26, 14] == f[26, 14]).all() for b, f in zip(bare, mm)), "match: a skinless master"
    mc = []                                                # a 6-frame sway with per-frame speckle: the key's tones ride along, no crawl
    for k in range(6):
        f = base.copy()
        f[17:31, 13:27] = (*pal[2], 255)
        f[17:31, 13:17] = (*pal[1], 255)
        m = (rng.random((H, W)) < 0.15) & (np.indices((H, W))[0] >= 17) & (np.indices((H, W))[0] < 31) & (np.indices((H, W))[1] >= 17) & (np.indices((H, W))[1] < 27)
        f[m, :3] = pal[1] if k % 2 else pal[3]
        mc.append(_shift(f, 0, k % 2))
    out, _, carried = match_move(mc, [_shift(eyes[..., None].astype(np.uint8), 0, k % 2)[..., 0] > 0 for k in range(6)], ramp, loop=True)
    back = [_shift(o, 0, -(k % 2)) for k, o in enumerate(out)]
    agree = min((_dist(b, back[0]) == 0)[17:31, 13:27].mean() for b in back[1:])
    assert carried > 0 and agree >= 0.9, (carried, agree)
    ref = dict(height=50, width=20, head_h=12, head_ratio=0.24, bands=dict(ink=20.0, line=20.0, shade=10.0, lit=50.0), skin=[30.0, 50.0, 20.0])
    m = dict(ref, height=60, width=30, head_ratio=0.2, bands=dict(ref["bands"], shade=30.0, lit=30.0), skin=[30.0, 20.0, 50.0])
    off = [t for _, t in compare(ref, m)]
    assert off[0].startswith("skin step 2") and sum(t.startswith(("height", "head_ratio")) for t in off) == 2 and not any(t.startswith("width") for t in off), off
    assert not any(t.startswith(("height", "head_ratio")) for _, t in compare(ref, m, proportions=False)), "check: a four-legged folder's proportions flagged"
    assert not any(t.startswith(("height", "head_ratio")) for _, t in compare(ref, dict(m, height=None, head_ratio=None))), "check: a lost head's proportions flagged"
    assert not compare(ref, dict(ref, height=54, width=40)), "check: 8% height or width flagged"
    print("selftest ok")
