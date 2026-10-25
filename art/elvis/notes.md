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

## Animations (25 Oct 2026, Task A3)

`P="uv run --with pillow --with numpy --with scipy python"`. Pose guides: `pose_strip.py` jobs as in `art/tools/test_strips.json`
(`HK Run`, `--carry 0.25,0.35,1`) with `"build": "chunky"`, then `guide_pack.py --height 360 --gap 30`, padded onto a 16:9
magenta canvas, uploaded with `master_x4.png` (on magenta) as image 2. Prompts: the "repaint image 1" pattern in
`art/tools/README.md`. Every sheet uses the shared cell 240x160, the palette lock and `--height 80` (the body).

| Sheet | Raw | Made with |
| --- | --- | --- |
| `idle_F` | (the master) | `breathe.py art/elvis/master.png --out art/elvis/idle_F.png --manifest art/elvis/manifest.json --key idle_F`; holds 0.3/0.2 s. `raw/idle_F_g1.jpeg` (4 frames from Gemini) was not used: tall, thin, small-headed copies |
| `run_F` | (the master, as `idle_F` frame 0) | `stride.py art/elvis/stride_run_F.json --manifest art/elvis/manifest.json`: 10 frames at 13 fps, the legs lifted in turn (up to 7 px), the body bobbing 0-2 px, the cape's hem pieces swaying 1 px |
| `run_S` | `raw/run_S_g2.jpeg` (2 rows of 5) | `sprites.py raw/run_S_g2.jpeg --cols 5 --rows 2 --split shapes --anchor head --fps 13 --touchup art/elvis/touchup_run_S.json` (eyes from `eyes.py --side`) |
| `run_B` | (`idle_B` frame 0) | `stride.py art/elvis/stride_run_B.json --manifest art/elvis/manifest.json`: as `run_F`, the boots lifted up to 4 px under the cape, the hem below row 146 swaying 1 px |

The first `run_F` and `run_B` (Gemini's `raw/run_F_g4.jpeg` and `raw/run_B_g1.jpeg`, commits `ec76b02` and `300f881`) were
replaced after review: Gemini repaints the armour in every frame, so it shimmered and the head's outline popped; the
front lost the trim, the ears and the long locks, and the back's hair stopped at the shoulder blades (the idle's
reaches the waist). `touchup_run_F.json` belongs to that first version and is no longer used.
| `idle_S`, `idle_B` | `raw/idle_SB_g1.jpeg` (the stance from the side and from behind) | `sprites.py raw/idle_SB_g1.jpeg --cols 2 --rows 1 --split shapes --anchor body --touchup art/elvis/touchup_idle_S.json`, each cell cropped to its figure, then `breathe.py` on each; holds 0.3/0.2 s |

Not used: `run_F_g1` (the master's pose 8 times), `run_F_g2` (plain guide: tall and thin), `run_F_g3` (no cape, bare
pole), `run_S_g1` (one stance in every frame, and frame 4 has no spear).

### Roll and light combo (25 Oct 2026, from 06:15)

Guides: the roll and light 1-4 jobs of `art/tools/test_strips.json` (light 1 also in F and B) with `"build": "chunky"`,
rendered into `art/_work/a3b/strips/`. Light 1 uses 6 of its 8 poses (cells 0,2,4,5,6,7 = clip frames 46,36,32,26,36,44:
guard, coil, thrust, full lunge, pull back, guard). Packed with `guide_pack.py <F> <B> --height 330 --gap 24 --aspect 16:9`
(F and B as two rows of one picture) and, for the side view, the strip cut into two rows of 3
(`guide_pack.py <S cells 0-2> <S cells 3-5> ...`). Image 2 is `master_x4.png` on magenta, aspect 16:9 in Gemini.

Prompt (light 1 side; the F+B one adds "TOP ROW: seen from the front ... both ice-blue eyes ... BOTTOM ROW: seen from
behind ... his long white hair down his back to his waist"): "Repaint image 1 as a pixel-art sprite sheet of the character
in image 2 (Elvis), for a top-down action game. Keep image 1's canvas and layout exactly: 2 rows of 3 figures, at the same
positions and the same sizes, and trace EVERY pose exactly ... The six figures are one two-handed spear thrust seen from the
side, facing right ...: guard, crouch and coil, thrust, full lunge ..., pull back, guard. Only replace each grey mannequin
with Elvis, drawn in the exact pixel-art style, proportions, colours, dark 1 px outline and details of image 2: ... Flat
#FF00FF magenta background everywhere ... Draw nothing else: no text, no ground, no shadows, no extra figures."

| Sheet | Raw | Made with |
| --- | --- | --- |
| `light1_S` | `raw/light1_S_g1.jpeg` (2 rows of 3; its first figure is a copy of the master, front on) | `sprites.py raw/light1_S_g1.jpeg --cols 3 --rows 2 --split shapes --anchor body --pick 5,1,2,3,1,5 --no-loop --fps 12 --touchup art/elvis/touchup_light1_S.json` (eyes from `eyes.py --side`). The guard (Gemini's last figure) opens and closes the swing, and the coil is reused for the pull back (the guide's poses are the same clip frames), so those pairs are pixel-identical |
| `light1_B` | `raw/light1_FB_g1.jpeg`, bottom row (rows 340 down) | `sprites.py <band> --cols 6 --rows 1 --split shapes --anchor body --scale-frame 0 --pick 0,1,2,3,1,0 --no-loop --fps 12`. `--scale-frame 0`: the raised arm counts as body in the thrust, so the tallest-body scale shrank him to 74 px; the guard is now 80 px, as in `idle_B` |
| `light1_F` | `raw/light1_FB_g1.jpeg`, top row | **Not used (failed review).** Gemini added a front-on copy of the master and drew the six poses smaller, narrower and with a smaller head than the idle; the faces are blank (no eyes); and the spear, thrust toward the camera, runs below the feet line, where the sheet has to cut it (the floor would hide it), so the thrust doesn't read. Remake on its own picture (one row of 6) |

Holds (light 1): the coil +0.08 s (wind-up) and the full lunge +0.1 s (impact); `"active": [2, 3]` (thrust and lunge).
The game stretches a light swing to 0.65 s (`player/elvis.gd`: cancel 0.35 + recovery 0.3), so the hit lands about 0.24 s in.
