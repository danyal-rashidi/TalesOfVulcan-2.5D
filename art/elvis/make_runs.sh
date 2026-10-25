#!/bin/bash
# Elvis's real runs (25 Oct 2026): Higgsfield nano_banana_2_1 sheets -> the game's run_F/S/B. Run from the project folder.
# Raws: art/elvis/raw/run_{S_h1,F_h3}.png, painted over the HK Run Full guides (art/tools/hand_keys.json), and
# raw/run_B_h8.png over HK Run Upright (art/guides/E32, the mannequin drawn 1.3 times as broad), with
# art/guides/ref_elvis_FSB.png (B: ref_elvis_B.png). Intermediates go to art/_work/runs/ (gitignored).
# Review fix (25 Oct): S keeps one long streaming mane (frame 2's, stretched) and touches the floor only in its passing
# frames (1, 5), the others in the air; F and B stand their passing frames on a feet line 8 rows up ("below": 8), where
# the forward (F) or kicked-back (B) foot of the other frames reaches toward the camera; one breastplate in F and S.
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/runs; mkdir -p $W
cp art/elvis/manifest.json $W/m.json          # sprites.py only reads the cell from it here; the real manifest is written below
C="--cols 4 --rows 2 --split shapes --anchor body --palette art/elvis/palette.png --manifest $W/m.json --fps 12"
$P art/sprites.py art/elvis/raw/run_S_h1.png $C --height 80 --out $W/run_S_a.png --key run_S
$P art/sprites.py art/elvis/raw/run_F_h3.png $C --height 79 --scale-frame 3 --frame-scale 0:0.93 --out $W/run_F_a.png --key run_F
$P art/sprites.py art/elvis/raw/run_B_h8.png $C --lowest --height 80 --widen 1.1 --out $W/run_B_a.png --key run_B
H="--fringe #221616 --floor 158 --steady"
# S: only the passing frames (1, 5) touch row 158; every other frame's lowest pixel is 2-3 px up (the spear butt too)
$P art/tools/headlock.py $W/run_S_a.png --src art/elvis/idle_S.png --box 108,79,138,101 --mane 100,82,128,110,2,1.3,1 \
    --clear 80,78,112,104 --chest 120,112,146,124,0 $H --air 0:2,2:2,3:2,4:2,6:2,7:3 --out art/elvis/run_S.png
# F, B: --thick, so a toe's single bottom pixel may stand on row 159
$P art/tools/headlock.py $W/run_F_a.png --src art/elvis/idle_F.png --box 106,79,135,103 --cut 140,84,120,110,3 \
    --chest 106,103,134,124,0 $H --thick --air 1:8,5:8 --out art/elvis/run_F.png
$P art/tools/headlock.py $W/run_B_a.png --src art/elvis/idle_B.png --box 104,79,140,126 --luma 100 --mend 108,106,138,127,4 \
    $H --thick --air 1:4,5:8 --out art/elvis/run_B.png
$P - <<'EOF'
import json
p = 'art/elvis/manifest.json'; m = json.load(open(p))
for v in 'FSB':
    m['anims']['run_' + v] = {'file': 'run_%s.png' % v, 'frames': 8, 'fps': 12.0, 'loop': True, **({} if v == 'S' else {'below': 8})}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/elvis/manifest.json run_F run_S run_B --row --out docs/progress/2026-10-25_elvis_real_runs.gif
