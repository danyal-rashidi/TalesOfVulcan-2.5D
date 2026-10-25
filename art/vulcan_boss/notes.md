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
