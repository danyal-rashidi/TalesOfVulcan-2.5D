# Vulcan, possessed (boss): master sprite

25 Oct 2026 (Task A1). Master: `master.png` (66x89), `master_x4.png`, `palette.png` (32 colours), `touchup.json`.
Candidates side by side at 4x: `candidates_x4.png`.

## References given to Gemini

- `art/_work/boss_ref_game_angle.png` (not committed): a colour render at the game camera (orthographic, 48.59 degrees
  down; front and 30 degrees round), made by `art/tools/render_ref.py` from a copy of the Unreal repo's
  `SourceArt/Vulcan/Vulcan.blend` with `Armature["outfit"] = 1` (boss armour, crown, greatsword) and
  `["possessed"] = 1` (charcoal skin, lava cracks, molten eyes), arms lowered from the A-pose.
- `docs/progress/2026-10-20_vulcan_boss_model.jpg` (Unreal repo): front, side, back and face close-ups (chat 1 only).
- The Elvis candidate `art/elvis/raw/e3_ready_stance.jpeg` as the style and camera reference.

## Prompts

- Chat 1 ("Vulcan Pixel Art Sprite Prompt", render + model sheet + Elvis style): one sprite of the possessed Vulcan
  copying the render's design (stone skin with lava cracks, molten eyes, dark hair and beard, black spiked crown with
  red gems, spiked pauldrons, cuirass with a diagonal strap, war skirt, vambraces, greaves, greatsword point-down in the
  right hand), in image 3's pixel style; camera high above, both eyes readable; flat #FF00FF. Then: "camera clearly
  higher, beard, bigger crown, bigger head".
- Chat 2: gave Gemini b1 as well; it returned b1 unchanged (b3, not used).
- Chat 3 ("Vulcan Pixel Art Sprite Prompt", render + Elvis only): draw Vulcan "using EXACTLY the camera, body
  proportions and pixel style of image 2" (Elvis), front view from above, crown seen from above, short dark beard,
  glowing eyes with a dark centre and a catch-light. Then: red gems on the crown spikes, a little hair at the temples,
  eyes one pixel bigger.

## Candidates (`raw/`)

| Raw | Verdict |
| --- | --- |
| `b1_idle.jpeg` | Strong armour and lava, but the camera is nearly front-on, no beard, a small crown |
| `b2_high_beard.jpeg` | Gemini kept b1 and only added a trace of beard |
| `b3_elvis_camera.jpeg` | A copy of b1 (it had b1 as an input) |
| `b4_style_from_elvis.jpeg` | Higher camera, bigger head, beard, big crown; few red gems |
| `b5_gems_eyes.jpeg` | b4 with red gems on the crown and stronger eyes: **chosen** |

**Why b5:** the crown is the thing Elvis has to strike, and b5's tall black crown with red gems reads at game size,
where b1/b2's thin crown disappears into the hair. It also has the beard, the higher camera and the bigger head that
match Elvis, and the most readable eyes. Lava cracks, spiked pauldrons, the strap, war skirt, vambraces, greaves and
the lava-veined greatsword are all there.

## Clean-up

```
uv run --with pillow --with numpy --with scipy python art/sprites.py art/vulcan_boss/raw/b5_gems_eyes.jpeg \
    --cols 1 --rows 1 --height 88 --touchup art/vulcan_boss/touchup.json --palette art/vulcan_boss/palette.png --out art/vulcan_boss/master.png
```

- `--height 88`: the scale of the first build, kept so the body didn't change. The crown's spikes fill rows 0-3 and
  its rim is row 4, so from the rim to the feet he is 84 px, 4 px taller than human Vulcan. The armour, the boots and
  the C3 ash cover the swap; if it still jumps, rebuild at a smaller height and redraw the head.
- Default `--quant median`: keeps the thin bright lava cracks (octree dulls them).
- `palette.png` is the first build's 29 colours plus three added by hand for the head: `#6e4429` (now only 9 body
  pixels the lock snaps to it), `#9aa0a6` (the crown's lit iron edge; it replaced the old beard brown `#94603a`) and
  `#5b6268` (the lit face). The palette lock snaps every touch-up colour to the nearest palette colour, so a new colour
  has to be in `palette.png` first. Swapping `#94603a` for `#9aa0a6` changed no body pixel (checked).
- `touchup.json` (rows 0-26, x 23-41): the whole head is drawn by hand, because Gemini drew it front-on: a flat-topped
  box of a crown with no hair under it, and a dark beard that vanished into the charcoal skin. Redone after the second
  25 Oct review, which found the 1 px black crown lost in the outline and the brown hair and beard unlike human Vulcan's.
  Edit the JSON directly: it is `[frame, x, y, colour]` per pixel, one row of the head per line.
  - The crown is black iron (`#111213`), a ring seen from above (an ellipse x 23-41, rows 4-13) around the top of his
    head. Its far half has a 1 px lit rim (`#9aa0a6`) on its outer edge; its near half, the front band, has the lit
    rim along its top edge, where it meets the hair, with three red gems on it. Five spikes stand on the back arc, each
    a lit column and a black one with a red tip: the centre one tallest (tip row 0), then rows 1 and 3.
  - Inside the ring, the top of his head: near-black hair (`#2e201d`, shadow `#1d1819`, strands `#493129`), the boss
    palette's matches for human Vulcan's `#241a13`, `#1b140d` and `#423128`.
  - The face is a lighter stone grey (`#5b6268`) than the armour, so it doesn't read as a dark mask, with near-black
    hair at the temples running into a full near-black beard and moustache in the same three colours. That beard and
    hair are what tie him to human Vulcan.
  - The eyes are unchanged from the first touch-up: a molten iris `#fdde50`, a dark pupil `#2b0a04` and a pale
    catch-light `#fff6c8` on row 16, with a dark brow above and an orange glow `#ea5413` below.
  - Two raw red specks beside the spike tips, (29,1) and (26,3), are covered as tip outlines (a touch-up can't clear a
    pixel), mirrored at (35,1) and (38,3).
  - Animation strips: Gemini gets this master, so check at 8x that every frame keeps the ring's lit rims, the spikes,
    the near-black hair and the beard.

# Runs (run_F, run_S, run_B): 25 Oct 2026, Higgsfield

Built by `make_runs.sh` (every command, in order). 8 frames each, 14 fps, loop.

- **Guides:** `HK Boss Run` (`art/tools/hand_keys.json`): Jog Forward with the spine and legs eased only 30% toward
  Idle, the free arm swinging from behind him to chest height ahead, the sword fist swinging opposite, the greatsword
  carried at `--carry 0.3,-0.5,-0.8`. Packed one row each: `art/guides/B25_boss_run_F.png` (8:1),
  `B26_boss_run_S.png` (8:1), `B27_boss_run_B.png` (4:1) (`packs.txt`). Image 2 is `art/guides/ref_vulcan_boss.png`.
- **Side, remade after the review (25 Oct evening):** `art/guides/B31_boss_run_S.png` (8:1), the same `HK Boss Run`
  with the greatsword carried level behind him, off his legs (`--carry 0.3,-0.85,0.45`, `guide_jobs.json`). Prompt: the
  queue's "Repaint image 1" one, plus "PURE SIDE VIEW ... facing right", the legs copying the mannequins' (one boot
  planted while the other swings through, the planted boot further back in each next figure, some figures with both
  boots off the ground, the feet in a different place in every figure) and "ONE greatsword ... never a second blade,
  never a blade across his legs". Two pictures: `raw/run_S_h6.png` kept (one level sword in every frame, a real run;
  on a white-pink gradient, so `art/tools/rekey.py` puts it on magenta first), `run_S_h5` dropped (the sword missing in
  one frame, level in another). The old side run (`raw/run_S_h4.png`, B26) is no longer used: its sword crossed his legs
  for 3 frames and its planted boot held still for 3 frames, then the contacts jumped.
- **Raws kept:** `raw/run_S_h6.png` (above), `raw/run_B_h2.png` (4:1, a clean back cycle: left leg up, passing, right
  leg up, passing, the free arm swinging up and the sword swinging), `raw/run_F_h6.png` (8:1; Gemini drew 10 figures).
- **Tried and dropped** (not kept): side 2x4 (row 2 smaller, boots 8-12 px higher), side 4:1 (figures touching), side
  8:1 once in a three-quarter view; front 2x4 (twice almost standing, once a deep squat every other frame), front
  4:1 and 21:9 (touching, once another man), front 8:1 three times with the same leg lifted.
- **Clean-up:** `sprites.py --anchor body --height 90` (his tallest running frame 90 px from the crown's spikes to
  the boots; the standing master is 88), `--widen 1.1` from the front and `--widen 1.25` from behind (Gemini's front and
  back figures came out narrower at the pauldrons than the master: 55 and 45 px against 63). From the front the frames
  are Gemini's 9, 0, 3, 4, 8, 8, 9, 5: frames 3 and 4 take the legs of 1 and 9 mirrored (`legswap.py`), so the cycle
  goes left leg up, up, passing, right leg up, up, up, passing, left leg rising; frames 5 and 6 are bodies 8 and 9 on
  the legs of 3 and 4 (Gemini's figure 6 laid the sword across his legs, a pop the review found), so the sword swings
  out, high, down, and stays low for 5 frames.
- **Side clean-up:** `rekey.py`, then `sprites.py --anchor strip` (each figure keeps the height Gemini drew it at, so
  the flights stay off the floor) `--pick 7,5,6,4,7,5,6,4`: Gemini's figures 7, 5, 6, 4 are contact (the front boot
  down 22 px ahead of his hips), passing (that boot 13 px further back, under him), flight and reach, one step; the
  other four figures are mid-stance poses with the planted boot in one place, which skated. The step is drawn twice.
  After `headlock.py` the contact and passing boots sit on row 189 and the flights 4 px above it (2 px higher than
  drawn), so his head bobs 2 px.
- **Back, frame 1:** Gemini left both fists empty; frame 0's greatsword (right of x 163, from row 151 down) is pasted
  into his right fist 3 px higher (`make_runs.sh`). **Back, frame 5:** its sword tip was the lowest pixel, so the
  boots floated 2 px; `headlock.py --floor-half 20` now only counts the columns near his head, and the tip sits on rows
  190-191 under the boots.
- **Heads:** `headlock.py` pastes one head per view where each frame's head is: from the front the idle's own (box
  134,102,152,127 of `idle_F.png`); from the side `head_S.png` (box 139,100,158,123), the side walk's frame 1 (its
  crown the closest to the idle's), with the spike tips and the band's gems red again (the shrink had made them brown);
  from behind `head_B.png` (box 131,98,153,118), the back run's frame 3 hair under the idle's own crown (ring, five
  spikes with red tips, the band's gems), found in each frame with Gemini's own frame-3 head (`--align`), since the
  redrawn head matches badly. Both are built by `make_runs.sh`. The side and back walks wear the same heads, so his
  head never changes from walk to run. `--floor 189` (the idle's feet row), `--bob-max 4` (front and back).
- **Checked:** every colour in `palette.png`, alpha only on or off, no magenta, the sheet sizes; front and back: every
  frame's lowest boot on row 189 (back frame 1 lifted 2 px, a flight frame); side: the contact and passing boots on
  row 189, the planted boot 166 then 154 (12 px), the flights 4 px up; the head the same pixels in every frame of a
  view. At 1x, 3x and 4x next to `idle_F`.
- **fps:** 14 in every view (was 13): from the side the planted boot moves 12 px from contact to passing, 168 px/s at
  14 fps, his pace (5.28 m/s at 32 px/m = 169 px/s; at his approach, 5.8 m/s, it slips 10%). A step takes 0.29 s.
  Phase two speeds both his run and the sprite by the same 1.3.
- **Known:** the armour's lava cracks are Gemini's per frame, so they shimmer a little (the head is locked, the body is
  not frozen). From the side the same leg leads both steps (one step drawn twice); in his dark armour at 90 px the near
  and far leg look alike.

# Walks (walk_F, walk_S, walk_B): 25 Oct 2026, Higgsfield

Built by `make_walks.sh`, after `make_runs.sh`. A heavy walk, one cycle in 0.8 s: `walk_F` 4 frames at 5 fps,
`walk_S` and `walk_B` 8 frames at 10 fps, loop. From the side the planted boot moves about 9 px a frame, so the feet keep
up at about 90 px/s (2.8 m/s); he walks below `Vulcan.RUN_FROM` (4.5 m/s). The fight never walks him yet (his pace and
approach speeds are both above `RUN_FROM`, so he always runs); the walks are for cutscenes and slow approaches.

- **Side, remade after the review (25 Oct evening):** the old `walk_S` (`raw/walk_S_h5.png`, B29) held two greatswords
  in frames 5-6 (the guide's blade crossing his legs and Gemini's own trailing one) and stood in one wide stance in 7
  of 8 frames, so the feet never travelled. New guide `art/guides/B32_boss_walk_S.png` (8:1): Walk Forward with the
  blade trailing flatter behind him (`--carry 0.3,-0.95,-0.2`). Prompt as the side run's, for "a slow, heavy WALK cycle,
  two steps": the heel landing ahead, the weight rolling over it, the back leg swinging through, two figures with the
  legs passing, never the same stance twice, ONE greatsword. Two pictures: `raw/walk_S_h7.png` kept (one sword in every
  frame; a grey background, `rekey.py`), `walk_S_h8` dropped (two swords again in its last 3 figures). Clean-up:
  `--pick 5,7,2,4,1,7,2,4`: Gemini's 5 (heel down ahead), 7 (weight on it), 2 (passing), 4 (reaching), then 1 (the
  other heel down) and the same three. The planted boot moves back 15, 14 and 8 px, then holds one frame as the back
  toe while the other heel lands (a 9 px slide at the end of each step).
- **Front sword:** the review found the greatsword at one angle in all 4 frames. Its blade (left of x 126, from row
  152 down) now turns about his fist 10 degrees out on frame 0 and 10 in on frame 2 (each boot's step), straight on the
  passing frames: the tip swings about 6 px each way (`make_walks.sh`, nearest pixel, drawn only where nothing else is).
- **Back head:** the walk's own head was a flat dark block under the crown (a helmet); it now wears `head_B.png`'s
  crown and hair, placed 1 px right and 2 px up of the run's to sit on the walk's own crown (`head_B_walk.png` in
  `art/_work/boss_walks/`), found in each frame with the walk's own frame-0 head (`--align`).

- **Guides:** Walk Forward (CC0), the greatsword carried low (`--carry 0.3,-0.5,-0.8`, from the front
  `0.5,0.25,-0.85` so the blade shows beside him): `art/guides/B28_boss_walk_F.png` (4 poses: a boot lifted, passing,
  the other boot lifted, passing), `B29_boss_walk_S.png` (8:1), `B30_boss_walk_B.png` (4:1).
- **Raws kept:** `raw/walk_F_h3.png` (16:9, 4 figures: the cleanest front figures of the batch, the master's build;
  the lift is small, 7-9 px, as a slow walk's is), `raw/walk_S_h7.png` (above; `walk_S_h5.png` is the old one, no
  longer used), `raw/walk_B_h3.png` (4:1).
- **Tried and dropped:** front 2x4 and 8:1 (standing still, once on a gradient), side 2x4 (row 2 smaller, the blade
  below the boots), side 8:1 and 4:1 (front or three-quarter views, figures touching, a two-tone background), back
  8:1 (a white-pink gradient), back 4:1 seed 4242 (figures touching, the legs hardly moving).
- **Clean-up:** as the runs (`--height 90`, the back `--widen 1.08`, its frames 6 and 7 rebuilt with `legswap.py` so
  each boot lifts three frames in turn), then `headlock.py`: the idle's head from the front, `head_S.png` from the side
  and `head_B.png` from behind (the runs' heads, so walking into a run never changes his head). Feet on row 189 (front
  and back: only the boots count, `--floor-half 20`), `--bob-max 4`.
- **Checked:** every colour in `palette.png`, alpha only on or off, no magenta, every frame's lowest boot on row 189,
  one sword in every side frame, heads within 4 px. At 1x, 3x and 4x next to `idle_F` and the runs.
