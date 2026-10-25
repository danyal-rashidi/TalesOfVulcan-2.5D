# Vulcan, possessed (boss): master sprite

25 Oct 2026 (Task A1). Master: `master.png` (66x89), `master_x4.png`, `palette.png` (29 colours), `touchup.json`.
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

- `--height 88`: the crown's spikes add ~8 px, so the man himself is 80 px like human Vulcan (the same man after C3).
- Default `--quant median`: keeps the thin bright lava cracks (octree dulls them).
- `touchup.json`: each eye redrawn as a molten iris `#fdde50`, a dark pupil `#2b0a04` and a pale catch-light
  `#fff6c8` (row 16), with a dark brow above and an orange glow `#ea5413` below.
