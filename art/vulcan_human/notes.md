# Vulcan, human: master sprite

## The redo from the game camera (25 Oct 2026, afternoon, Higgsfield)

The reviewers found the first master (below, `h3`) drawn front-on at eye level, not from the game camera, so he didn't
match Elvis. The new master: `master.png` (56x81), `master_x4.png`, `palette.png` (28 colours), `touchup.json`,
`idle_F.png` (`breathe.py`, holds 0.3/0.2 s like Elvis's). `candidates_x4.png`: the 8 new candidates cleaned to 80 px,
left to right h4a-h4d, h5a, h5b (chosen), h5c, h5d.

Generator: Higgsfield, `nano_banana_2_1` (Gemini's image model), 1k, 3:4, 1.5 credits each, references uploaded.

| Raw | References (in order) | Verdict |
| --- | --- | --- |
| `h4a`, `h4b` | `guides/ref_elvis.png`, `guides/ref_vulcan_human.png` (the old master), the Unreal repo's `docs/refs/vulcan/02_full_body_apose.jpg` | Still front-on, a small head |
| `h4c`, `h4d` | `ref_elvis.png`, `art/_work/human_ref_game_angle.png` (the Blender render at the game camera), `ref_vulcan_human.png` | The right camera, but a head a sixth of his height and a hulking body: at 80 px his face is a dark smear, no eyes |
| `h5a`, `h5b` | `ref_elvis.png`, `ref_vulcan_human.png`, `h4c` (as "the right camera, but the head far too small") | **h5b chosen** |
| `h5c`, `h5d` | `ref_vulcan_human.png`, `ref_elvis.png`: "redraw image 1 from image 2's camera" | Gemini handed back the old front-on sprite |

**Why h5b:** the same high three-quarter view as Elvis: the top of his head and his swept-back near-black hair seen from
above, the tops of his shoulders, short foreshortened legs, the feet from above, and a big head (about a quarter of his
height, like Elvis's), so at 80 px his eyes, brows, beard, the gold lion buckle, the pouch, the wrist and calf wraps and
the sandals all read. Beside the boss (`docs/progress/2026-10-25_human_master_redo.png`) he has the same near-black hair
and beard and the same build under the armour.

```
uv run --with pillow --with numpy --with scipy python art/sprites.py art/vulcan_human/raw/h5b.png --cols 1 --rows 1 \
    --height 80 --quant octree --touchup art/vulcan_human/touchup.json --palette art/vulcan_human/palette.png \
    --out art/vulcan_human/master.png
```

(With no `palette.png` it writes a new one that includes the touch-up colours; every later sheet locks to it.)
`touchup.json`: each eye is 3x2 px on rows 18-19 (x 21-23 and 31-33, symmetric about the nose at x 27): a cream white
`#dac695`, a dark pupil `#331809` 2 px tall and a catch-light `#fff6e0` at its top right, with skin shadow `#b77448`
between the eye and the nose; the brows above (row 17) are the hair's brown `#423127`, so the pupils don't merge into them.

## `kneel_F` and `look_hands_F` (C3, 25 Oct 2026, Higgsfield)

- **The guide:** `HK Human Kneel` in `art/tools/hand_keys.json`: the body of the boss's `HK Kneel` last pose (Pick Up
  Kneeling 25, spine 15; B07's last cell), so the man under the burning armour kneels as the boss does; his right hand
  drops from the hilt to his thigh. Rendered with `pose_strip.py` (F, no prop, cell 256, chunky), then
  `art/tools/guide_with_ref.py art/vulcan_human/master.png <strip> art/guides/H03_human_kneel_look_hands_F_ref.png
  --scale 6 --master-scale 7`: **the master standing at the guide's scale in front of the 6 mannequins.** Without it
  (`H02`, `raw/look_g1*`) Gemini drew the kneel as big as a man standing, so no scale fitted both his height and his
  head and shoulders. With it, the kneeling man has the standing man's head and shoulders, and `--scale-frame 0` on
  the standing figure gives the sheet the master's scale.
- **Raws** (`nano_banana_2_1`, 1k, 4:1): `look_g1a`, `look_g1b` (`H02` + `guides/ref_vulcan_human.png`), `look_g1c`
  (the reference only); `look_g2a`, `look_g2b` (`H03` + the reference), `look_g2c` (`H03` only). **`look_g2a`
  chosen:** the same trousers, calf wraps and sandals in every kneel; `g2b` and `g2c` turned the trousers into shorts
  at the knee. Its 7th figure sits back on both knees (the legs change), so it is left out: the move ends on the 6th
  figure, his head up and his eyes open, his hands still raised.
- **Clean-up** (the standing figure sets the scale, then is cut off):
  ```
  P="uv run --with pillow --with numpy --with scipy python"
  cp art/vulcan_human/manifest.json art/_work/man_tmp.json
  $P art/sprites.py art/vulcan_human/raw/look_g2a.png --cols 7 --rows 1 --split shapes --anchor body --height 80 \
      --scale-frame 0 --quant octree --palette art/vulcan_human/palette.png \
      --touchup art/vulcan_human/touchup_look_hands.json --out art/_work/look7.png --manifest art/_work/man_tmp.json \
      --key tmp --no-loop
  $P -c "from PIL import Image; s = Image.open('art/_work/look7.png'); \
      s.crop((128, 0, 768, 96)).save('art/vulcan_human/look_hands_F.png'); \
      s.crop((128, 0, 256, 96)).save('art/vulcan_human/kneel_F.png')"
  ```
  Body heights at that scale: standing 80, kneeling 77-78 (Gemini's kneel is still tall: the head stays upright so the
  face reads). `touchup_look_hands.json` (frames 5 and 6 of the 7-frame build): the open eyes redrawn as the master's
  (3x2 each, a cream white, a pupil 2 px tall, a catch-light at its top right), where Gemini drew wide 4 px whites.
  The bowed frames keep Gemini's downcast eyes.
- **The move:** `kneel_F` = `look_hands_F`'s first frame (knelt and spent, head bowed, right hand on the thigh, left arm
  by the raised knee). `look_hands_F`: 5 frames at 4 fps, holds 0.3 s on the kneel, 0.8 s on the hands at his chest
  (he looks at them), 0.5 s on the last (head up): the right hand comes to his belly, both hands rise palms up, he
  stares at them, then looks up. It doesn't loop, so the last frame stays through the two lines.

## The first master (25 Oct 2026, night, Task A1; replaced)

Master: `master.png` (50x81), `palette.png` (32 colours), `touchup.json`.

## References given to Gemini

- `docs/refs/vulcan/02_full_body_apose.jpg` (Unreal repo): his master picture.
- `art/_work/human_ref_game_angle.png` (not committed): `art/tools/render_ref.py` on a copy of `Vulcan.blend`,
  `outfit 0`, `possessed 0`, at the game camera.
- `art/vulcan_sheet.png`'s first frame at 8x on magenta: the 24 Oct front-on sprite, for continuity (chat 1 only).
- The Elvis candidate `art/elvis/raw/e3_ready_stance.jpeg` as the style and camera reference.

## Prompts

- Chat 1 ("Vulcan Pixel Art Sprite Specification", all four images): one sprite of Vulcan as a man, his face and
  outfit copied from the master picture (bare chest, tan skin, chest hair, short dark hair swept back, full dark beard,
  wrist wraps, belt with a golden lion-head buckle and a pouch, baggy dark brown trousers, cream calf wraps, sandals),
  camera high above, both eyes with a white, a dark pupil and a catch-light, in image 4's pixel style; flat #FF00FF.
  Then: "the camera HIGHER".
- Chat 2 ("Vulcan Pixel Art Game Sprite", Elvis + render + master picture): "a NEW sprite using EXACTLY the camera,
  body proportions and pixel style of image 1" with the same description.

## Candidates (`raw/`)

| Raw | Verdict |
| --- | --- |
| `h1_relaxed.jpeg` | The right man and outfit, lion buckle and wraps; a moderate camera, smaller head |
| `h2_higher.jpeg` | Gemini kept h1 almost unchanged |
| `h3_elvis_camera.jpeg` | Bigger head, short legs, a big gold lion buckle, large readable eyes: **chosen** |

**Why h3:** at 80 px his eyes (a white and a dark pupil each), brows, beard and the gold lion buckle all read, and his
proportions and camera match Elvis and the boss, so the C3 swap from the boss sprite to this one doesn't jump.
He reads as the man in the master picture and the 24 Oct sprite.

## Clean-up

```
uv run --with pillow --with numpy --with scipy python art/sprites.py art/vulcan_human/raw/h3_elvis_camera.jpeg \
    --cols 1 --rows 1 --height 80 --quant octree --touchup art/vulcan_human/touchup.json --palette art/vulcan_human/palette.png --out art/vulcan_human/master.png
```

- `--quant octree`: with the default median cut the gold buckle turned brown and the eye whites merged into the skin.
  Use `--quant octree` for every human Vulcan sheet.
- `touchup.json` (after the 25 Oct review): Gemini's eyes came through as one cream pixel at the outer corner and an
  outline-black pupil that merged with the black brows, so he looked squinting. Each eye (row 11, x 20-22 and 26-28)
  is now a cream white `#d2c498`, a dark brown pupil `#2e1915` and a catch-light `#fff6e0`. The brows above (row 10)
  are the hair's brown `#423128`, and the pixels beside the nose are skin shadow, so the eyes stand apart.
  `#fff6e0` was appended to `palette.png` (31 -> 32 colours), because the palette lock snaps touch-up colours to the
  palette.
