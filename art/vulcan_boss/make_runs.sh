#!/bin/bash
# The possessed Vulcan's runs (25 Oct 2026): Higgsfield nano_banana_2_1 strips -> the game's run_F/S/B. Run from the
# project folder, before make_walks.sh (it also makes the side and back heads both use). Raws: art/vulcan_boss/raw/
# run_S_h6.png (8:1, guide art/guides/B31_boss_run_S.png, a white-pink gradient behind him), run_B_h2.png (4:1, B27),
# run_F_h6.png (8:1, B25: 10 figures), all with art/guides/ref_vulcan_boss.png as image 2, over the HK Boss Run guides
# (art/tools/hand_keys.json); the side head comes from raw/walk_S_h7.png (B32). Intermediates: art/_work/boss_runs/.
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/boss_runs; mkdir -p $W
cp art/vulcan_boss/manifest.json $W/m.json     # sprites.py only reads the cell from it here; the real manifest is written below
L="--rows 1 --split shapes --palette art/vulcan_boss/palette.png --manifest $W/m.json --height 90"
C="$L --anchor body"
# Side: Gemini drew the drawn heights as a run (flights off the floor), so --anchor strip keeps them. Its frames 7, 5, 6,
# 4 are one step: contact, passing (the planted boot 13 px further back), flight, reach; that step twice is the cycle.
$P art/tools/rekey.py art/vulcan_boss/raw/run_S_h6.png $W/run_S_k.png
$P art/sprites.py $W/run_S_k.png --cols 8 $L --anchor strip --pick 7,5,6,4,7,5,6,4 --out $W/run_S_a.png --key run_S
$P art/sprites.py art/vulcan_boss/raw/run_B_h2.png --cols 8 $C --widen 1.25 --out $W/run_B_a.png --key run_B
$P art/sprites.py art/vulcan_boss/raw/run_F_h6.png --cols 10 $C --widen 1.1 --out $W/run_F_a0.png --key run_F
# From the front Gemini lifted the same leg in 7 of 10 figures: frames 3 and 4 take the legs of 1 and 9 mirrored. Frames
# 5 and 6 are bodies 8 and 9 (Gemini's 6 laid the sword across his legs, so frame 5 takes the passing legs of 3), so the
# sword swings out, high, back down, low.
$P art/tools/legswap.py $W/run_F_a0.png --cell 288 192 --row 165 --half 18 --frames 9,0,3,4:1m,8:9m,8:3,9:4,5 --out $W/run_F_a.png
# The side walk's sheet, for the one side head both side views wear.
$P art/tools/rekey.py art/vulcan_boss/raw/walk_S_h7.png $W/walk_S_k.png
$P art/sprites.py $W/walk_S_k.png --cols 8 $L --anchor strip --pick 5,7,2,4,1,7,2,4 --out $W/walk_S_src.png --key walk_S
$P - <<'EOF'
import numpy as np
from PIL import Image
W, cw = 'art/_work/boss_runs', 288
rgb = lambda h: [int(h[i:i + 2], 16) for i in (1, 3, 5)]
# Back frame 1: Gemini left both fists empty. Frame 0's greatsword (right of x 163, from row 151 down) goes in his right
# fist 3 px higher, only where frame 1 is clear.
a = np.asarray(Image.open(W + '/run_B_a.png').convert('RGBA')).copy()
s, d = a[:, :cw], a[:, cw:2 * cw]
for y, x in zip(*np.nonzero(s[..., 3] > 0)):
    if x >= 163 and y >= 151 and d[y - 3, x, 3] == 0:
        d[y - 3, x] = s[y, x]
Image.fromarray(a).save(W + '/run_B_a.png')
# One back head for the run and the walk: back frame 3's hair under the idle's own crown (ring, five spikes with red tips,
# the band's gems), its bottom on the hair's top row 113. From behind Gemini drew the crown as a plain ring (run) or the
# head as a flat block (walk).
idle = np.asarray(Image.open('art/vulcan_boss/idle_F.png').convert('RGBA'))
h = a[:, 3 * cw:4 * cw].copy(); h[96:113, 128:159] = 0
crown = idle[101:116, 134:153]
ok = {tuple(rgb(c)) for c in ('#000000', '#9aa0a6', '#111213', '#f30000', '#1d1819', '#2e201d', '#493129')}
for j in range(crown.shape[0]):
    for i in range(crown.shape[1]):
        p = crown[j, i]
        if p[3] and (j < 12 or tuple(p[:3]) in ok):    # rows 113-115 of the idle: only the crown, not the face round it
            h[99 + j, 133 + i] = p
Image.fromarray(h).save('art/vulcan_boss/head_B.png')
# One side head for the run and the walk: the side walk's frame 1 (its crown the closest to the idle's), the brown the
# shrink made of the spike tips and the band's gems red again, as the idle's.
h = np.asarray(Image.open(W + '/walk_S_src.png').convert('RGBA'))[:, cw:2 * cw].copy()
z = h[100:111, 139:159]; z[(z[..., :3] == rgb('#6e4429')).all(-1)] = rgb('#f30000') + [255]
Image.fromarray(h).save('art/vulcan_boss/head_S.png')
EOF
# One head per view (the idle's from the front, head_S and head_B from the side and from behind). The feet on idle_F's
# feet row 189 (front and back: only the boots count, --floor-half 20, so a low sword tip may sit 1-2 px below them), a
# passing squat lifted to 4 px under the median head.
H="--cell 288,192 --floor 189 --floor-half 20 --bob-max 4"
$P art/tools/headlock.py $W/run_F_a.png --src art/vulcan_boss/idle_F.png --box 134,102,152,127 $H --out art/vulcan_boss/run_F.png
$P art/tools/headlock.py $W/run_S_a.png --src art/vulcan_boss/head_S.png --box 139,100,158,123 --cell 288,192 --pad 5 --out $W/run_S_b.png
$P art/tools/headlock.py $W/run_B_a.png --src art/vulcan_boss/head_B.png --box 131,98,153,118 --align $W/run_B_a.png:3:131,101,153,118 \
    $H --out art/vulcan_boss/run_B.png
$P - <<'EOF'
import json
import numpy as np
from PIL import Image
# Side: the contact and passing frames' boots on row 189, the flights (frames 2, 3, 6, 7, drawn 2 px up) 2 px higher still,
# so his head bobs 2 px and his boots leave the floor 4 px.
a = np.asarray(Image.open('art/_work/boss_runs/run_S_b.png').convert('RGBA')); o = np.zeros_like(a)
for k in range(8):
    up = 1 + (2 if k % 4 >= 2 else 0)
    o[:-up, k * 288:(k + 1) * 288] = a[up:, k * 288:(k + 1) * 288]
Image.fromarray(o).save('art/vulcan_boss/run_S.png')
p = 'art/vulcan_boss/manifest.json'; m = json.load(open(p))
for v in 'FSB':     # 14 fps: from the side the planted boot moves 12 px from contact to passing, 168 px/s (his pace, 5.28 m/s)
    m['anims']['run_' + v] = {'file': 'run_%s.png' % v, 'frames': 8, 'fps': 14.0, 'loop': True}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/vulcan_boss/manifest.json run_F run_S run_B --row --out docs/progress/2026-10-25_boss_runs.gif
