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
| `run_F`, `run_S`, `run_B` (real runs, 25 Oct, from 08:40) | `raw/run_F_h3.png`, `raw/run_S_h1.png`, `raw/run_B_h6.png` (Higgsfield `nano_banana_2_1`, 1k, 16:9, 2 rows of 4) | `art/elvis/make_runs.sh` (all the commands). Guides: `HK Run Full` in `art/tools/hand_keys.json` (Jog Forward's full stride, the lean cut to about 15 degrees, the free arm swinging behind and ahead, the spear rocking with the fist; the passing poses' legs eased 50% for F and B), packed as `art/guides/E25_elvis_run_S.png`, `E26_elvis_run_F.png`, `E27_elvis_run_B.png` (E25 was rendered with the first arm keys, the free arm swung up to 60 degrees and no eased passing poses; `HK Run Full` now holds the lower arm and eased poses of E26-E27, so re-rendering E25 gives a slightly calmer arm); image 2 `art/guides/ref_elvis_FSB.png` (the master, `idle_S` and `idle_B` side by side at 4x). Clean-up: `sprites.py` (palette lock; F: frame 0 drawn 7% bigger, `--frame-scale 0:0.93`; B: drawn slimmer and longer-legged than `idle_B`, `--height 66 --widen 1.36 --lowest`), then `art/tools/headlock.py`: the idle's own head (side: head and face, the hair behind the skull stays Gemini's streaming hair; back: the whole hair to the waist, the idle's spear across it mended) pasted where each frame's head is, the frame moved sideways so the head keeps one column, the `#221616` fringe removed, the feet back on row 158; F and B's passing frames, which Gemini draws as a 12 px squat, lifted to a 4 px bob (their feet leave the floor 6-8 px, a flight frame). 8 frames at 12 fps in all three views: the side view's planted foot travels about 61 px over 5 frames, 12 px a frame = 145 px/s at 12 fps, against the ground's 160 (5 m/s x 32 px) |
| `walk_F`, `walk_S`, `walk_B` (25 Oct; C3's walk at 2 m/s) | `raw/walk_F_h2.png`, `raw/walk_S_h2.png`, `raw/walk_B_h1.png` | `art/elvis/make_walks.sh`. Guides `HK Walk Full` (Walk Forward's own stride and free arm, the spear carried as in the run), `art/guides/E28_elvis_walk_S.png`, `E29_elvis_walk_F.png`, `E30_elvis_walk_B.png`. The same clean-up as the runs; F: frames 2, 4 and 6 drawn at other sizes, `--frame-scale 2:1.08,4:0.96,6:1.04`; B: slimmer than `idle_B` (`--widen 1.29`), and its passing frames stand 8 px taller than its contact frames, so `headlock.py --sink 1` lowers them under the feet line and the key has `"below": 4` (feet line row 154). 8 frames at 9 fps: the side view's planted foot moves about 7 px a frame, 63 px/s, against the walk's 64 |
| (old) `run_F` | (the master, as `idle_F` frame 0) | **Replaced 25 Oct by the real runs above** (Danyal: "make it so they run and not just take 1 step of a pixel each"); `stride_run_*.json` are no longer used. Was: `stride.py art/elvis/stride_run_F.json --manifest art/elvis/manifest.json` (since the 25 Oct art review): 10 frames at 13 fps. The body bobs 0-2 px and sways 1 px toward the planted foot; the spear (blade and butt) bounces a frame behind the body; each leg is a knee (rows 144-149, drawn over the hem, 1 px lower when it comes forward) and a boot (row 150 down, lifted up to 7 px behind the knee and 2 px in toward the middle); the cape's sides swing 1 px a frame behind |
| `run_S` | `raw/run_S_g2.jpeg` (2 rows of 5) -> `raw/run_S_g2_frames.png` (its first clean-up, kept as the legs' source) | `stride.py art/elvis/stride_run_S.json`: the upper body is Gemini frame 5 with its head erased and `idle_S`'s head, long hair and front lock pasted on (5 px ahead), so the head never changes; the hair streams 2-3 px back at its tips; the spear and front hands bounce a frame behind; the legs and cape hem come from one Gemini frame each, in step order (contact 5, down 1, passing 6, push 8, reach 4, then 7, 2, 6, 3, 9), lined up on frame 5 and dropped onto the feet row; strokes under 3 px (a stray spear butt, dotted outlines) dropped; the `#221616` fringe the first clean-up left round every outline deleted or made outline black. Was: `sprites.py raw/run_S_g2.jpeg --cols 5 --rows 2 --split shapes --anchor head --fps 13 --touchup art/elvis/touchup_run_S.json` (no longer used) |
| `run_B` | (`idle_B` frame 0) | `stride.py art/elvis/stride_run_B.json`: as `run_F` (the same bob, sway and phase, mirrored since his left is on the left from behind); the spear blade and the shaft across his back bounce a frame behind; the hair's tips swing 1 px; the boots lift up to 6 px and come in front of the cape while kicked back; the cape's middle swings 1 px and its hem 2 px, a frame behind |

The first `run_F` and `run_B` (Gemini's `raw/run_F_g4.jpeg` and `raw/run_B_g1.jpeg`, commits `ec76b02` and `300f881`) were
replaced after review: Gemini repaints the armour in every frame, so it shimmered and the head's outline popped; the
front lost the trim, the ears and the long locks, and the back's hair stopped at the shoulder blades (the idle's
reaches the waist). `touchup_run_F.json` belongs to that first version and is no longer used.
The second versions (25 Oct, the review after them): the side run repainted and jittered his head every frame (the eye
moved 5 px sideways), its hair stopped at the shoulders, its feet floated 2-5 px above row 158 in 9 of 10 frames, and a
maroon `#221616` fringe (10% of its pixels) edged every outline; the front and back runs only lifted their legs. All
three are now `stride.py` recipes on the same cycle; `touchup_run_S.json` is no longer used either (the eye is
`idle_S`'s own).
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
