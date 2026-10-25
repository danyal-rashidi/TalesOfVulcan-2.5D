#!/bin/bash
# The possessed Vulcan's runs (25 Oct 2026): Higgsfield nano_banana_2_1 strips -> the game's run_F/S/B. Run from the
# project folder. Raws: art/vulcan_boss/raw/run_S_h4.png (8:1, guide art/guides/B26_boss_run_S.png),
# run_B_h2.png (4:1, B27), run_F_h6.png (8:1, B25: 10 figures), all with art/guides/ref_vulcan_boss.png as image 2,
# over the HK Boss Run guides (art/tools/hand_keys.json). Intermediates go to art/_work/boss_runs/ (gitignored).
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/boss_runs; mkdir -p $W
cp art/vulcan_boss/manifest.json $W/m.json     # sprites.py only reads the cell from it here; the real manifest is written below
C="--rows 1 --split shapes --anchor body --palette art/vulcan_boss/palette.png --manifest $W/m.json --height 90"
$P art/sprites.py art/vulcan_boss/raw/run_S_h4.png --cols 8 $C --out $W/run_S_a.png --key run_S
$P art/sprites.py art/vulcan_boss/raw/run_B_h2.png --cols 8 $C --widen 1.25 --out $W/run_B_a.png --key run_B
$P art/sprites.py art/vulcan_boss/raw/run_F_h6.png --cols 10 $C --widen 1.1 --out $W/run_F_a0.png --key run_F
# From the front Gemini lifted the same leg in 7 of 10 figures: frames 3 and 4 take the legs of 1 and 9 mirrored.
$P art/tools/legswap.py $W/run_F_a0.png --cell 288 192 --row 165 --half 18 --frames 9,0,3,4:1m,8:9m,6,4,5 --out $W/run_F_a.png
# One head per view (the idle's from the front, the cleanest Gemini head from the side and from behind), the feet on
# idle_F's feet row 189, a passing squat lifted to 4 px under the median head.
H="--cell 288,192 --floor 189 --bob-max 4"
$P art/tools/headlock.py $W/run_F_a.png --src art/vulcan_boss/idle_F.png --box 134,102,152,127 $H --out art/vulcan_boss/run_F.png
$P art/tools/headlock.py $W/run_S_a.png --src $W/run_S_a.png --src-frame 1 --box 155,102,176,127 $H --out art/vulcan_boss/run_S.png
$P art/tools/headlock.py $W/run_B_a.png --src $W/run_B_a.png --src-frame 3 --box 131,101,153,118 $H --out art/vulcan_boss/run_B.png
$P - <<'EOF'
import json
p = 'art/vulcan_boss/manifest.json'; m = json.load(open(p))
for v in 'FSB':     # 13 fps: a stride of about 55 px a step at 5.5 m/s (176 px/s), so the feet keep up with the ground
    m['anims']['run_' + v] = {'file': 'run_%s.png' % v, 'frames': 8, 'fps': 13.0, 'loop': True}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/vulcan_boss/manifest.json run_F run_S run_B --row --out docs/progress/2026-10-25_boss_runs.gif
