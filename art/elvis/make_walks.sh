#!/bin/bash
# Elvis's walk (25 Oct 2026; C3, at 2 m/s): Higgsfield nano_banana_2_1 sheets -> walk_F/S/B. Run from the project folder.
# Raws: art/elvis/raw/walk_{S_h2,F_h2,B_h1}.png, painted over the HK Walk Full guides (art/guides/E28-E30) with
# art/guides/ref_elvis_FSB.png. Intermediates go to art/_work/walks/ (gitignored). The steps are make_runs.sh's.
set -e
P="uv run --with pillow --with numpy --with scipy python"
W=art/_work/walks; mkdir -p $W
cp art/elvis/manifest.json $W/m.json
C="--cols 4 --rows 2 --split shapes --anchor body --palette art/elvis/palette.png --manifest $W/m.json --fps 9"
$P art/sprites.py art/elvis/raw/walk_S_h2.png $C --height 80 --out $W/walk_S_a.png --key walk_S
# F: Gemini drew frames 2, 4 and 6 at other sizes than the rest
$P art/sprites.py art/elvis/raw/walk_F_h2.png $C --height 80 --frame-scale 2:1.08,4:0.96,6:1.04 --out $W/walk_F_a.png --key walk_F
# B: slimmer than idle_B, as in the run; its passing frames stand 8 px taller, so they sink under the feet line ("below": 4)
$P art/sprites.py art/elvis/raw/walk_B_h1.png $C --lowest --height 84 --widen 1.29 --out $W/walk_B_a.png --key walk_B
H="--fringe #221616 --steady"
$P art/tools/headlock.py $W/walk_S_a.png --src art/elvis/idle_S.png --box 108,79,138,101 --front 114 $H --floor 158 --out art/elvis/walk_S.png
$P art/tools/headlock.py $W/walk_F_a.png --src art/elvis/idle_F.png --box 106,79,135,103 $H --floor 158 --out art/elvis/walk_F.png
$P art/tools/headlock.py $W/walk_B_a.png --src art/elvis/idle_B.png --box 104,79,140,126 --luma 100 --mend 108,106,138,127,4 \
    $H --floor 154 --sink 1 --out art/elvis/walk_B.png
$P - <<'EOF'
import json
p = 'art/elvis/manifest.json'; m = json.load(open(p))
for v in 'FSB':
    m['anims']['walk_' + v] = {'file': 'walk_%s.png' % v, 'frames': 8, 'fps': 9.0, 'loop': True, **({'below': 4} if v == 'B' else {})}
json.dump(m, open(p, 'w'), indent=1)
EOF
$P art/tools/gif.py art/elvis/manifest.json walk_F walk_S walk_B --row --out docs/progress/2026-10-25_elvis_walks.gif
