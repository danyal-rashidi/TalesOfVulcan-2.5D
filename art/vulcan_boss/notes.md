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

Built by `make_runs.sh` (every command, in order). 8 frames each, 13 fps, loop.

- **Guides:** `HK Boss Run` (`art/tools/hand_keys.json`): Jog Forward with the spine and legs eased only 30% toward
  Idle, the free arm swinging from behind him to chest height ahead, the sword fist swinging opposite, the greatsword
  carried at `--carry 0.3,-0.5,-0.8`. Packed one row each: `art/guides/B25_boss_run_F.png` (8:1),
  `B26_boss_run_S.png` (8:1), `B27_boss_run_B.png` (4:1) (`packs.txt`). Image 2 is `art/guides/ref_vulcan_boss.png`.
- **Raws kept:** `raw/run_S_h4.png` (8:1, a pure side view with full strides; the sword rides up behind him for 5
  frames and swings down ahead for 3), `raw/run_B_h2.png` (4:1, a clean back cycle: left leg up, passing, right leg
  up, passing, the free arm swinging up and the sword swinging), `raw/run_F_h6.png` (8:1; Gemini drew 10 figures).
- **Tried and dropped** (not kept): side 2x4 (row 2 smaller, boots 8-12 px higher), side 4:1 (figures touching), side
  8:1 once in a three-quarter view; front 2x4 (twice almost standing, once a deep squat every other frame), front
  4:1 and 21:9 (touching, once another man), front 8:1 three times with the same leg lifted.
- **Clean-up:** `sprites.py --anchor body --height 90` (his tallest running frame 90 px from the crown's spikes to
  the boots; the standing master is 88), `--widen 1.1` from the front and `--widen 1.25` from behind (Gemini's front and
  back figures came out narrower at the pauldrons than the master: 55 and 45 px against 63). From the front the frames
  are Gemini's 9, 0, 3, 4, 8, 6, 4, 5, and frames 3 and 4 take the legs of 1 and 9 mirrored (`legswap.py`), so the
  cycle goes left leg up, up, passing, right leg up, up, up, passing, left leg
  rising. Then `headlock.py`: from the front the idle's own head (the master's crown ring, eyes and beard, box
  134,102,152,127 of `idle_F.png`), from the side and from behind the cleanest Gemini head of the sheet (side frame 1,
  back frame 3), pasted where each frame's head is; `--floor 189` (the idle's feet row), `--bob-max 4`.
- **Checked:** every colour in `palette.png`, alpha only on or off, every frame's lowest pixel on row 189 (back frame 1
  lifted 2 px, a flight frame), the head bob within 4 px from the front and behind and 5 px from the side, the head the
  same pixels in every frame of a view. At 1x, 3x and 4x next to `idle_F`.
- **fps:** a step is about 55 px (heel to heel in the side frames) and he runs at 5.3-5.8 m/s (176 px/s), so a cycle
  of two steps takes about 0.63 s: 8 frames at 13 fps. Phase two speeds both his run and the sprite by the same 1.3.
- **Known:** the armour's lava cracks are Gemini's per frame, so they shimmer a little (the head is locked, the body is
  not frozen); the back view's crown has no red gems (its source frame had none).

# Walks (walk_F, walk_S, walk_B): 25 Oct 2026, Higgsfield

Built by `make_walks.sh`. A heavy walk, one cycle in 0.8 s (about 2 m/s): `walk_F` 4 frames at 5 fps, `walk_S` and
`walk_B` 8 frames at 10 fps, loop. The fight never walks him yet (his pace and approach speeds are both above
`Vulcan.RUN_FROM`, so he always runs); the walks are for cutscenes and slow approaches.

- **Guides:** Walk Forward (CC0), the greatsword carried low (`--carry 0.3,-0.5,-0.8`, from the front
  `0.5,0.25,-0.85` so the blade shows beside him): `art/guides/B28_boss_walk_F.png` (4 poses: a boot lifted, passing,
  the other boot lifted, passing), `B29_boss_walk_S.png` (8:1), `B30_boss_walk_B.png` (4:1).
- **Raws kept:** `raw/walk_F_h3.png` (16:9, 4 figures: the cleanest front figures of the batch, the master's build;
  the lift is small, 7-9 px, as a slow walk's is), `raw/walk_S_h5.png` (8:1, a profile walk, the blade trailing behind
  him and swinging forward at the end), `raw/walk_B_h3.png` (4:1).
- **Tried and dropped:** front 2x4 and 8:1 (standing still, once on a gradient), side 2x4 (row 2 smaller, the blade
  below the boots), side 8:1 and 4:1 (front or three-quarter views, figures touching, a two-tone background), back
  8:1 (a white-pink gradient), back 4:1 seed 4242 (figures touching, the legs hardly moving).
- **Clean-up:** as the runs (`--height 90`, the back `--widen 1.08`, its frames 6 and 7 rebuilt with `legswap.py` so
  each boot lifts three frames in turn), then `headlock.py`: the idle's head from the front; from the side and behind
  the walk's own first frame (its heads differ from the run's: a profile turned a little more, the back of the head a
  dark block under the crown, so a run's head would not fit). Feet on row 189, `--bob-max 4`.
- **Checked:** every colour in `palette.png`, alpha only on or off, every frame's lowest pixel (a boot) on row 189,
  heads within 4 px. At 1x, 3x and 4x next to `idle_F` and the runs.
- **Known:** from behind the walk's head (a block) differs from the run's (hair), so a walk turning into a run from
  behind changes the back of his head.
