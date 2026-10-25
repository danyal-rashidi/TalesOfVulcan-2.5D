#!/bin/bash
# The possessed Vulcan's walks (25 Oct 2026): Higgsfield nano_banana_2_1 strips -> the game's walk_F/S/B. Run from the
# project folder after make_runs.sh. Raws: art/vulcan_boss/raw/walk_F_h3.png (16:9, 4 figures, guide
# art/guides/B28_boss_walk_F.png), walk_S_h5.png (8:1, B29), walk_B_h3.png (4:1, B30), all with
# art/guides/ref_vulcan_boss.png as image 2, over Walk Forward (CC0) guides with the greatsword carried low.
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/boss_walks; mkdir -p $W
cp art/vulcan_boss/manifest.json $W/m.json     # sprites.py only reads the cell from it here; the real manifest is written below
C="--rows 1 --anchor body --palette art/vulcan_boss/palette.png --manifest $W/m.json --height 90"
$P art/sprites.py art/vulcan_boss/raw/walk_F_h3.png --cols 4 $C --out $W/walk_F_a.png --key walk_F
$P art/sprites.py art/vulcan_boss/raw/walk_S_h5.png --cols 8 --split shapes $C --out $W/walk_S_a.png --key walk_S
$P art/sprites.py art/vulcan_boss/raw/walk_B_h3.png --cols 8 --split shapes $C --widen 1.08 --out $W/walk_B_a0.png --key walk_B
# From behind Gemini lifted the left boot in 5 of 8 figures: frame 6 takes frame 1's legs mirrored, frame 7 is frame 6's
# body on frame 3's passing legs, so the cycle goes left up, up, up, passing, right up, up, up, passing.
$P art/tools/legswap.py $W/walk_B_a0.png --cell 288 192 --row 165 --half 18 --frames 0,1,2,3,4,5,7:1m,6:3 --out $W/walk_B_a.png
# The front walk wears the idle's head (as the front run); from the side and behind each walk keeps one of its own
# heads (Gemini drew the walk's heads unlike the run's: a profile turned a little more, the back of the head as a block).
H="--cell 288,192 --floor 189 --bob-max 4"
$P art/tools/headlock.py $W/walk_F_a.png --src art/vulcan_boss/idle_F.png --box 134,102,152,127 $H --out art/vulcan_boss/walk_F.png
$P art/tools/headlock.py $W/walk_S_a.png --src $W/walk_S_a.png --src-frame 0 --box 147,99,161,121 $H --out art/vulcan_boss/walk_S.png
$P art/tools/headlock.py $W/walk_B_a.png --src $W/walk_B_a.png --src-frame 0 --box 133,99,154,116 $H --out art/vulcan_boss/walk_B.png
$P - <<'EOF'
import json
p = 'art/vulcan_boss/manifest.json'; m = json.load(open(p))
# a heavy walk, one cycle (two steps of about 0.8 m) in 0.8 s, about 2 m/s: the front walk has 4 frames, the others 8
m['anims']['walk_F'] = {'file': 'walk_F.png', 'frames': 4, 'fps': 5.0, 'loop': True}
for v in 'SB':
    m['anims']['walk_' + v] = {'file': 'walk_%s.png' % v, 'frames': 8, 'fps': 10.0, 'loop': True}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/vulcan_boss/manifest.json walk_F walk_S walk_B --row --out docs/progress/2026-10-25_boss_walks.gif
