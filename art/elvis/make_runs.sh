#!/bin/bash
# Elvis's real runs (25 Oct 2026): Higgsfield nano_banana_2_1 sheets -> the game's run_F/S/B. Run from the project folder.
# Raws: art/elvis/raw/run_{S_h1,F_h3,B_h6}.png, painted over the HK Run Full guides (art/tools/hand_keys.json) with
# art/guides/ref_elvis_FSB.png. Intermediates go to art/_work/runs/ (gitignored).
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/runs; mkdir -p $W
cp art/elvis/manifest.json $W/m.json          # sprites.py only reads the cell from it here; the real manifest is written below
C="--cols 4 --rows 2 --split shapes --anchor body --palette art/elvis/palette.png --manifest $W/m.json --fps 12"
$P art/sprites.py art/elvis/raw/run_S_h1.png $C --height 80 --out $W/run_S_a.png --key run_S
$P art/sprites.py art/elvis/raw/run_F_h3.png $C --height 79 --scale-frame 3 --frame-scale 0:0.93 --out $W/run_F_a.png --key run_F
$P art/sprites.py art/elvis/raw/run_B_h6.png $C --lowest --height 66 --widen 1.36 --out $W/run_B_a.png --key run_B
H="--fringe #221616 --floor 158 --steady"
$P art/tools/headlock.py $W/run_S_a.png --src art/elvis/idle_S.png --box 108,79,138,101 --front 114 $H --out art/elvis/run_S.png
$P art/tools/headlock.py $W/run_F_a.png --src art/elvis/idle_F.png --box 106,79,135,103 $H --bob-max 4 --out art/elvis/run_F.png
$P art/tools/headlock.py $W/run_B_a.png --src art/elvis/idle_B.png --box 104,79,140,126 --luma 100 --mend 108,106,138,127,4 \
    $H --bob-max 4 --out art/elvis/run_B.png
$P - <<'EOF'
import json
p = 'art/elvis/manifest.json'; m = json.load(open(p))
for v in 'FSB':
    m['anims']['run_' + v] = {'file': 'run_%s.png' % v, 'frames': 8, 'fps': 12.0, 'loop': True}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/elvis/manifest.json run_F run_S run_B --row --out docs/progress/2026-10-25_elvis_real_runs.gif
