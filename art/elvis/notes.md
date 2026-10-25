# Elvis: master sprite

25 Oct 2026 (Task A1). Master: `master.png` (76x89), `master_x4.png`, `palette.png` (30 colours), `touchup.json`.
Candidates side by side at 4x: `candidates_x4.png`.

## References given to Gemini

`art/_work/elvis_ref_sheet.jpg` (not committed), built from the Unreal repo:
- `docs/refs/concepts/2026-10-24_arena_and_elvis.jpg`: Danyal's 24 Oct concept, Elvis from behind
- `docs/progress/2026-10-24_elvis_look.jpg`: the new look in 3D, front and three-quarter, and face A with pale cool skin

## Prompts (chat "Elvis Pixel Art Sprite Generation")

1. Pixel-art sprite of this exact character: long straight white hair to mid-back, long elf ears, pale cool skin, stern
   young face with ice-blue eyes, blackened plate with silver trim and ornate pauldrons, tattered navy-indigo cape,
   long dark steel spear with a barbed leaf blade. Top-down three-quarter view (camera high above, ~45 degrees down,
   top of the head and shoulders visible, both eyes visible), ~80 px tall, chunky pixels, dark 1 px outline,
   <= 32 colours, hard edges, each eye a dark pupil and a light catch-light, flat #FF00FF background. (1:1)
2. Only one figure, front view, spear upright in his right hand, camera high above. (3:4)
3. Same character, ready stance: spear diagonal across his body, nothing above his head; long white locks forward
   over his shoulders; very readable ice-blue eyes. (3:4)

## Candidates (`raw/`)

| Raw | What | Verdict |
| --- | --- | --- |
| `e1_sheet6.jpeg` | Gemini made a 6-view turnaround (3 front, 3 back) instead of one figure | Lower camera, realistic proportions: the face is ~6 px wide at 80 px and the eyes vanish. Keep its back views for the B animations |
| `e2_front_spear.jpeg` | One figure, spear upright | Good camera and face, but the spear rises far above his head and his long hair doesn't show from the front |
| `e3_ready_stance.jpeg` | One figure, spear diagonal, white locks over the shoulders | **Chosen** |

**Why e3:** it has every detail that identifies him at game size: long white hair (the locks over the shoulders),
pointed ears, blackened plate with silver trim, the navy cape, the barbed spear; the camera is high (top of the head
and shoulder tops visible); the head is big enough for the eyes to read.

## Clean-up

```
uv run --with pillow --with numpy --with scipy python art/sprites.py art/elvis/raw/e3_ready_stance.jpeg \
    --cols 1 --rows 1 --height 88 --touchup art/elvis/touchup.json --palette art/elvis/palette.png --out art/elvis/master.png
```

- `--height 88`: the spear tip sits ~8 px above his head, so his body (top of the hair to the feet) is 80 px.
  Animation strips must use the same scale (the tallest figure in the strip sets it).
- `touchup.json`: Gemini's eyes are ~2 of the shrunken pixels wide and lose their colour in the shrink, so each eye was
  redrawn by hand: a dark navy pupil `#12142b` and an ice-blue catch-light `#9fe3ff` at (35,24)/(36,24) and
  (41,24)/(42,24), with a grey lid line above and clean skin below. Any frame with his face toward the camera needs
  the same treatment.
