# Vulcan, human: master sprite

25 Oct 2026 (Task A1). Master: `master.png` (50x81), `master_x4.png`, `palette.png` (32 colours), `touchup.json`.
Candidates side by side at 4x: `candidates_x4.png`.

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
