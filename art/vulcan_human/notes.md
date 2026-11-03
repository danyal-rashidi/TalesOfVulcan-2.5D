# Vulcan, human: master sprite

## One body, one skin (1 Nov 2026)

Danyal: his run and walk had a different build and skin tone, with and without the sword. Every stand, walk and run now comes from clips that start on the same pictures, cut at one scale, and every sheet's skin is brought to the stand's tone.

- **Clips:** `D:\SmartRig\spike\web\clips\vulcan_walk_F/S/B.mp4` and `vulcan_armed_walk_F/S/B.mp4`, Seedance 2.0 Mini, 4 s, 480p, 16:9, 2 credits each. Empty-handed prompt, front: "The man walks in place toward the camera in a steady, relaxed, even walk cycle, staying in the centre of the frame as if on a treadmill, both empty hands swinging naturally at his sides. His face, build, belt and clothes stay exactly as they are. Camera completely still. Keep this exact high view, this pixel-art style and this flat green background. No ground, no shadow, no weapon." With the sword, front: "The man walks in place toward the camera in a steady, relaxed, even walk cycle, staying in the centre of the frame as if on a treadmill, his free arm swinging naturally, the sword held firmly in his hand low at his side, never leaving his hand. His face, build, belt and clothes stay exactly as they are. Camera completely still. Keep this exact high view, this pixel-art style and this flat green background. No ground, no shadow." The side and back prompts differ only in the direction.
- **Cut:** `art/tools/anim_into_sheets.py vulcan_human KEY CLIP art/guides/ref_vulcan_human.png 50 0 0.8 loop [steel]`. A loop now passes `--first-height`, so the height is the clip's first frame, standing, and a run and walk from one picture come out the same size. The stands are 1 frame, `1 2.5 whole`, copied to `strips/still_KEY.png`.
- **Then, in order:** `art/tools/armed_idle.py` (the stands), `art/tools/steady_sheets.py vulcan_human` (head lock, and `TONED` brings the skin to one tone), `art/tools/new_sword_sheets.py`. Delete a sheet's copy in `before_steady/` when you recut it, or `steady_sheets.py` goes back to the old one.
- **Measured:** skin about (172, 109, 67) in every stand, walk and run, where it ran up to 185 before. Stands and runs 50-53 px tall in every view; the side sprint leans, at 47-49.
- **Careful in the shell:** don't name a helper `cut`. The first run did, with `| cut -c1-60` inside it, so it called itself until the machine ran out of memory.

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

**The buckle's gold (review fix, 25 Oct evening):** the first `palette.png` (28 colours, median cut) had no gold, so the
lock turned the buckle (rows 45-51, x 24-30) into skin tans: a skin-coloured lump at the waist. Four golds were added
(`#eecb6a`, `#cb9a39`, `#a06a1e`, `#6f4410`, now 32 colours), and `touchup.json` repaints the buckle's 44 pixels from
`h5b`'s own octree shrink (its light, mid, dark and darkest gold mapped to those four), plus two pixels that the lock
would otherwise move (`(6, 22)`, and `(38, 66)`, which snapped to gold). The command above now rebuilds the master
exactly, buckle apart; `idle_F.png` (`breathe.py`) and `art/guides/ref_vulcan_human.png` (the master at 4x on #FF00FF,
at the same place) were rebuilt from it.

`touchup.json`: each eye is 3x2 px on rows 18-19 (x 21-23 and 31-33, symmetric about the nose at x 27): a cream white
`#dac695`, a dark pupil `#331809` 2 px tall and a catch-light `#fff6e0` at its top right, with skin shadow `#b77448`
between the eye and the nose; the brows above (row 17) are the hair's brown `#423127`, so the pupils don't merge into them.

## `kneel_F` and `look_hands_F`, remade low and hunched (C3, review fix, 25 Oct 2026 evening, Higgsfield)

The first build (below) knelt upright, 77 px tall against 80 standing, where its guide is hunched far forward. Remade so
the kneel follows the guide, the same body as the boss's B07 last pose.

- **The guide:** `art/guides/H04_human_kneel_look_hands_F_ref.png`, H03 again with the gold-buckle master:
  `guide_with_ref.py art/vulcan_human/master.png <human_kneel_look_F strip> art/guides/H04_human_kneel_look_hands_F_ref.png
  --scale 6 --master-scale 7` (the strip is `HK Human Kneel` from `pose_strip.py`, F, no prop, cell 256, chunky).
- **Raws** (`nano_banana_2_1`, 1k, 4:1): `look_g3a`, `look_g3b` (H04 + `guides/ref_vulcan_human.png`), `look_g3c` (H04
  only). The prompt is H03's with the kneel spelled out: "he kneels LOW and HUNCHED, exhausted: one knee on the
  ground, the other foot planted, his back bent far forward, his shoulders slumped, his head hanging low in front of
  his chest. Each kneeling figure is only about two thirds as tall as the standing man: the top of his head is level
  with the standing man's chin ... kneeling only makes him shorter", then the 6 poses in order. **`look_g3a` chosen:**
  the only one drawn from the guide's camera (front and above, like the master), its first kneel hunched as low as the
  mannequin's, head hanging so the top of his hair shows. `g3b` knelt upright again; `g3c` turned him three-quarters
  to the side. `look_g3a_e1`, `_e2`: two edits of `g3a` asking for its last figure at the 6th figure's height with his
  head up; Gemini drew it as tall both times, so they are not used.
- **Clean-up:**
  ```
  P="uv run --with pillow --with numpy --with scipy python"
  python3 -c "import json; t = json.load(open('art/vulcan_human/touchup.json')); \
      json.dump([v for v in t if v[2] < 32 and 15 <= v[1] < 40], open('art/_work/human_eyes_touchup.json', 'w'))"
  $P art/tools/eyes.py art/_work/look7.png --cell 128 96 --master art/vulcan_human/master.png \
      --master-touchup art/_work/human_eyes_touchup.json --head 15 0 40 32 --frames 6 \
      --out art/vulcan_human/touchup_look_hands.json      # run once on a build without --touchup first
  cp art/vulcan_human/manifest.json art/_work/man_tmp.json
  $P art/sprites.py art/vulcan_human/raw/look_g3a.png --cols 7 --rows 1 --split shapes --anchor body --height 80 \
      --scale-frame 0 --quant octree --palette art/vulcan_human/palette.png \
      --touchup art/vulcan_human/touchup_look_hands.json --out art/_work/look7.png --manifest art/_work/man_tmp.json \
      --key tmp --no-loop
  $P -c "from PIL import Image; s = Image.open('art/_work/look7.png'); \
      s.crop((128, 0, 896, 96)).save('art/vulcan_human/look_hands_F.png'); \
      s.crop((128, 0, 256, 96)).save('art/vulcan_human/kneel_F.png')"
  ```
  (`eyes.py` takes only the eye and brow touch-ups: the buckle's are outside the head box.) Body heights at the
  standing man's scale: standing 80, then 60, 67, 73, 70, 73, 80. `touchup_look_hands.json`: the master's eyes on the
  last frame (head up), where Gemini drew flat 4 px whites; the bowed frames keep Gemini's downcast eyes.
- **The move:** `kneel_F` = `look_hands_F`'s first frame: knelt and spent, 60 px tall (0.75 of standing, the guide's
  0.65-0.75), bent far over his knee, his head hanging so only his hair shows, his right arm hanging by the knee.
  `look_hands_F`: 6 frames at 4 fps, holds 0.3 s on the kneel, 0.8 s on the stare (frame 3), 0.5 s on the last: the
  right hand to his belly, both hands rise palms up, he stares at them, straightens a little, then lifts his head and
  looks at the viewer, eyes open. It doesn't loop, so the last frame stays through the two lines.
- **Why the last frame is as tall as he stands:** from this camera an upright kneel is nearly a stand. The front thigh
  points at the camera and so runs down the screen, and the camera shows the head from above either way: a rough
  estimate at the game's 48.6° camera puts a man kneeling upright on one knee at nearly all of his standing height on
  screen (Gemini drew him at 77-80 px every time). Only the hunch (his head
  down over his knee) makes the kneel low, so the first frame, the one the boss's kneel must match, is the low one.

## The first `kneel_F` and `look_hands_F` (C3, 25 Oct 2026, Higgsfield; replaced)

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

## Shrunk to 60% (30 Oct 2026)

Every sheet was shrunk to stand on blue Elvis's scale: `uv run --with pillow --with numpy python art/tools/shrink_sheets.py art/vulcan_human 0.6`. The cell is now 81x60. The recipes above make the full-size sheets, which are in git before this change; the tool refuses to shrink twice.

## Playable, from clips (31 Oct 2026)

For the road into Cinerea he has runs with and without the iron sword, a sword swing and a roll, from the front, the side and the back; `build_sheets.py` makes `strips/` and `sheets.json`, then `sheets_for_game.py art/vulcan_human`. The clips and start pictures are in `D:\SmartRig\spike\cinerea\`, made the way `art/elvis_blue/notes.md` says. His standing frames with the sword are one picture each, breathing in code. "_spear" in the sheet names is Elvis's word for the weapon in hand, because they share `player/elvis.gd`. Borrowed, for lack of credits: drink and death show him standing.

Armed idle: after `art/tools/anim_into_sheets.py` remakes `idle_spear_*`, run `art/tools/steel_blade.py`, or its blade goes rust-brown (1 Nov 2026).

Armed stand (1 Nov 2026): `art/tools/armed_idle.py` makes `idle_spear_F/S/B`, one clean picture per view with only the breath moving, because the clips flickered (eyes, pale specks). Don't remake those keys with `anim_into_sheets.py`; `steel_blade.py` is no longer needed for them. After it, run `art/tools/new_sword_sheets.py`.

Order after changing his sheets (1 Nov 2026): `armed_idle.py`, `attack_clips.py`, `smaller_head.py` (it runs `steady_sheets.py vulcan_human` first, which starts from `before_steady/`: delete a sheet's copy there when you remake that sheet), `new_sword_sheets.py`. `smaller_head.py` also rebuilds his drink and death from his stand.

Attacks (1 Nov 2026): `art/tools/attack_clips.py` cuts `light1_*`, `light2_*` and `heavy_*`, every view with its own left-facing sheet, from 12 clips (`D:\SmartRig\spike\web\clips\vulcan_light1_*`, `vulcan_light2_*`, `vulcan_heavy_*`). It lists the hand-picked frames of each and does everything to them itself: the same cutter and palette as his other sheets with the steel kept, rust out of the blade, a drawn point where the clip's edge cut a blade's tip (the tool stops if a picked frame touches the clip's edge and isn't in `FINISH`), shades kept frame to frame, his approved head from `smaller_head.py` on every frame with hands and blade in front of it (`FRONT` lists, by eye, what the clip has across the old head in each frame; `smaller_head.py`'s `Head.cleared` never erases that), and feet that haven't moved kept on the same pixels. `steady_sheets.py` and `smaller_head.py` leave those sheets alone. The model bakes blood, sparks and white arcs in while the blade moves, so those frames are never picked, and the blade's way through its cut borrows clean frames of the same arm from elsewhere in the clip. The sheets are taller than the cell and wider ("w": 104), so no blade is cropped, with the feet on the feet line. `lunge_*`, `thrust_*` and `charge_*` are all `heavy_*.png`: the whole of it, from its overhead frame, and up to it. Each sheet's "arc" is where its blade's tip goes, drawn by `fx/slash.gd`. The vote-down that cuts a clip can lose a hand and hilt held across his body: choose another frame of the clip where they show, rather than painting them (the hand-painted `PATCH` gave him a square fist, a black ball for a knee and a painted-out head, and went on 2 Nov 2026). Its "active" frames open as the blade arrives, never while it's still raised. Facing left, the clips hold the sword forward in his far hand and his stand has it across his shins, so `into_stand` ends each left swing on the stand itself with the sword on its way; his run has it in the near hand too, so only a recut of his stand and run together could remove that last jump. His hit reaction is real clips, cut by `art/tools/hurt_clips.py` before `smaller_head.py`: seven clips, 14 credits (1 Nov 2026). The model drew blood on impact even when told not to, so that tool lists the clean frames of each clip. His real run: `sprint_*`, cut with `anim_into_sheets.py ... loop`. Facing left: `*_spear_L`, its own clips from `D:\\SmartRig\\spike\\web\\vulcan_armed_L.png`, no mirror. Review fixes (2 Nov 2026): the cut is tidied (`tidied`: specks, one dark in his trousers) and pinholes shut; recovery frames take the stand's shades only where a whole patch lies as the stand does; a head with arms round it has a brown shadow, not sand, between them (`round_head`); left-view first and last frames are his stand with the blade in its far fist (`into_stand`). He swings where he stands: his clips step within the sheet with the other foot planted, so `player/elvis.gd` doesn't move him in a swing at all (a list of "steps" frames made the ground jump). Shades carry over only between frames of one pose (`kept_shades`): from another pose they turned arms and legs to speckle. A gap by his head bigger than a chink stays open, as a real gap; brown there read as a hood. Light 2 pressed in light 1's recovery runs from `light2_late_*.png`, which goes back down those same frames and joins light 2 past its low pose, so he doesn't drop back into that crouch. Light 1 pressed with light 2's sword still high plays `light1_on_*`, the same sheet from its raised frame, skipping his stand. Light 1 from behind with the sword up has its blade drawn from guard to tip (`WHOLE_BLADE`): the cut eats it in every frame of the clip. Facing left with the sword up, his free arm is pick 9's (`BORROW`). `hammer_blow_S` frames 0-2 get the far arm back from `before_steady` (`BEHIND` in `smaller_head.py`).

Attacks and Hammer Blow (2 Nov 2026): `heavy_F` frame 3 now uses clip frame 41 and `heavy_L` frame 3 uses clip frame 29, because the old frames were a tangle on his head. Head stamps skip upside-down roll frames. `art/tools/hammer_aura.py` and `fx/hammer_aura.gd` (`HANDS`, `ANGLES`, `HIT`) are measured off `hammer_blow_S`, so re-measure them if that sheet is regenerated from new frames. Left-facing Hammer Blow is still a mirror of `hammer_blow_S`. The sword still jumps on left-facing swings, and only recutting his left stand and run together can fix it.
