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
