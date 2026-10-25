#!/bin/bash
# The possessed Vulcan's walks (25 Oct 2026): Higgsfield nano_banana_2_1 strips -> the game's walk_F/S/B. Run from the
# project folder after make_runs.sh (it makes head_S.png and head_B.png). Raws: art/vulcan_boss/raw/walk_F_h3.png (16:9,
# 4 figures, guide art/guides/B28_boss_walk_F.png), walk_S_h7.png (8:1, B32, a grey background), walk_B_h3.png (4:1,
# B30), all with art/guides/ref_vulcan_boss.png as image 2, over Walk Forward (CC0) guides with the greatsword carried low.
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/boss_walks; mkdir -p $W
cp art/vulcan_boss/manifest.json $W/m.json     # sprites.py only reads the cell from it here; the real manifest is written below
C="--rows 1 --anchor body --palette art/vulcan_boss/palette.png --manifest $W/m.json --height 90"
$P art/sprites.py art/vulcan_boss/raw/walk_F_h3.png --cols 4 $C --out $W/walk_F_a.png --key walk_F
# Side: Gemini's frames 5, 7, 2, 4 are one step (heel down ahead, weight on it, passing, reaching), the planted boot
# moving back 15, 15 and 8 px; frame 1 is the other step's contact.
$P art/tools/rekey.py art/vulcan_boss/raw/walk_S_h7.png $W/walk_S_k.png
$P art/sprites.py $W/walk_S_k.png --cols 8 --split shapes $C --pick 5,7,2,4,1,7,2,4 --out $W/walk_S_a.png --key walk_S
$P art/sprites.py art/vulcan_boss/raw/walk_B_h3.png --cols 8 --split shapes $C --widen 1.08 --out $W/walk_B_a0.png --key walk_B
# From behind Gemini lifted the left boot in 5 of 8 figures: frame 6 takes frame 1's legs mirrored, frame 7 is frame 6's
# body on frame 3's passing legs, so the cycle goes left up, up, up, passing, right up, up, up, passing.
$P art/tools/legswap.py $W/walk_B_a0.png --cell 288 192 --row 165 --half 18 --frames 0,1,2,3,4,5,7:1m,6:3 --out $W/walk_B_a.png
$P - <<'EOF'
import numpy as np
from PIL import Image
# The back walk's frame 0 wearing head_B.png's head (the idle's crown on the back run's hair) where its own head is: its
# crown's near band sits 1 px right and 2 px up of the back run's.
w = np.asarray(Image.open('art/_work/boss_walks/walk_B_a.png').convert('RGBA'))[:, :288].copy()
h = np.asarray(Image.open('art/vulcan_boss/head_B.png').convert('RGBA'))
w[94:112, 130:157] = 0
for y, x in zip(*np.nonzero(h[98:122, 133:153, 3] > 0)):     # the hair down to row 121 covers the walk's block of a head
    w[96 + y, 134 + x] = h[98 + y, 133 + x]
Image.fromarray(w).save('art/_work/boss_walks/head_B_walk.png')
EOF
# The idle's head from the front (as the front run); from the side and behind the runs' heads (head_S.png, head_B.png),
# so walking into a run never changes his head. Front and back: only the boots count for the feet row.
H="--cell 288,192 --floor 189 --bob-max 4"
$P art/tools/headlock.py $W/walk_F_a.png --src art/vulcan_boss/idle_F.png --box 134,102,152,127 $H --floor-half 20 --out $W/walk_F_b.png
$P art/tools/headlock.py $W/walk_S_a.png --src art/vulcan_boss/head_S.png --box 139,100,158,123 $H --out art/vulcan_boss/walk_S.png
$P art/tools/headlock.py $W/walk_B_a.png --src $W/head_B_walk.png --box 134,96,153,119 --align $W/walk_B_a.png:0:133,99,154,116 \
    $H --floor-half 20 --out art/vulcan_boss/walk_B.png
$P - <<'EOF'
import json
import numpy as np
from PIL import Image
# Front: the greatsword swings with the stride. Its blade (left of x 126, from row 152 down) turns about his fist 10
# degrees out on frame 0 and 10 in on frame 2 (each boot's step), straight on the passing frames; nearest-pixel, drawn
# only where nothing else is.
a = np.asarray(Image.open('art/_work/boss_walks/walk_F_b.png').convert('RGBA')).copy(); cw = 288
yy, xx = np.mgrid[:192, :cw]
for k, deg in enumerate((10, 0, -10, 0)):
    f = a[:, k * cw:(k + 1) * cw]; blade = (f[..., 3] > 0) & (xx <= 126) & (yy >= 152)
    if not deg or not blade.any():
        continue
    px, py = 127, int(np.nonzero(blade)[0].min()) - 1
    src = f.copy(); f[blade] = 0; c, s = np.cos(np.radians(deg)), np.sin(np.radians(deg))
    for y in range(py, 192):
        for x in range(80, 135):
            sx, sy = round(px + c * (x - px) + s * (y - py)), round(py - s * (x - px) + c * (y - py))
            if 0 <= sy < 192 and 0 <= sx < cw and blade[sy, sx] and f[y, x, 3] == 0:
                f[y, x] = src[sy, sx]
Image.fromarray(a).save('art/vulcan_boss/walk_F.png')
p = 'art/vulcan_boss/manifest.json'; m = json.load(open(p))
# one cycle (two steps) in 0.8 s in every view: the front walk has 4 frames, the others 8. From the side the planted boot
# moves about 10 px a frame, so the feet keep up at about 95 px/s (3 m/s); he walks below Vulcan.RUN_FROM (4.5 m/s).
m['anims']['walk_F'] = {'file': 'walk_F.png', 'frames': 4, 'fps': 5.0, 'loop': True}
for v in 'SB':
    m['anims']['walk_' + v] = {'file': 'walk_%s.png' % v, 'frames': 8, 'fps': 10.0, 'loop': True}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/vulcan_boss/manifest.json walk_F walk_S walk_B --row --out docs/progress/2026-10-25_boss_walks.gif
