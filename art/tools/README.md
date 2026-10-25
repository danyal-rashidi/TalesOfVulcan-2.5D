# Art tools

Python runs through `uv run --with pillow --with numpy --with scipy python ...` from the project folder.
Blender is `"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"` and takes Windows paths.

| Tool | What it does |
| --- | --- |
| `art/sprites.py` | A Gemini strip on magenta -> a sheet: cut into cells, magenta and its rim tint removed, each frame shrunk to the shared scale (block mode colour, not the average, so lava cracks, trims and outlines stay crisp), feet on one line, <= 32 colours or locked to a palette, hand touch-ups, `<out>_x4.png` preview, optional manifest entry. Usage at the top of the file; `--selftest` checks it |
| `guide_pack.py` | A `pose_strip.py` strip -> a compact guide for Gemini: every cell cropped to the same box (hips centred, feet on one line), scaled up, side by side on magenta. Several strips (one move's views) become rows at one scale; `strip.png:0-3` packs only those cells (a wide view as two rows); `--aspect 16:9` pads the picture; it prints how tall a cell comes out in a 1376 px wide picture. The packed guides for Gemini are in `art/guides/` (`packs.txt` lists each one's rows) |
| `breathe.py` | A still sprite (a master, or one clean Gemini view) -> a 2-frame breathing idle: everything above the belt 1 px lower in frame 1, nothing else changes. Writes the manifest entry |
| `stride.py` | A still stance (or one good Gemini frame) -> a run cycle with no flicker: a JSON recipe cuts parts out by rows and columns, a spear's line, brightness (hair) or colour, and moves each part per frame (legs lifted in turn, knees and boots apart, the body bobbing and swaying, the spear bouncing a frame behind, the hair and cape swinging); parts can come from another sheet (the side run's legs from Gemini's frames, `idle_S`'s head); holes a moved part leaves are filled from the body next to them. Nothing is repainted, every colour must be in `palette.png`, and every frame must keep a foot on the feet line. Recipes: `art/elvis/stride_run_F.json`, `stride_run_S.json`, `stride_run_B.json`; the keys are at the top of the file |
| `band.py` | Cut one row of figures out of a Gemini picture that padded the strip with extra copies above and below: shapes reaching outside rows Y0..Y1 go (touching shapes are split first) |
| `eyes.py` | Eye touch-ups for `sprites.py --touchup`: front frames get the master's own eye pixels where its head matches; `--side` finds the profile eye and draws a pupil and an ice-blue catch-light |
| `gif.py` | Manifest keys -> a 4x GIF for `docs/progress/`, timed by fps and holds, on sand; `--row` plays several side by side |
| `render_ref.py` | Blender, headless: a colour reference of Vulcan at the game camera (orthographic, 48.59 degrees down) from a **copy** of the Unreal repo's `SourceArt/Vulcan/Vulcan.blend`; `--outfit 0/1 --possessed 0..1 --yaw <deg> --out <png>` |

```
cp /mnt/d/TalesOfVulkan/TalesOfVulkan/SourceArt/Vulcan/Vulcan.blend art/_work/Vulcan_copy.blend
"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\Vulcan_copy.blend' \
    --python 'D:\TalesOfVulkan\TalesOfVulcan25D\art\tools\render_ref.py' -- --outfit 1 --possessed 1 --yaw 0 \
    --out 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\boss_ref_F.png' > art/_work/render.log 2>&1
```

The copy's textures are relative (`//textures/...`), so the script points them at the original folder (read only).

## Gemini through the Playwright browser

- In `browser_run_code_unsafe`, clicking "Upload files" opens a chooser the MCP itself takes: end the snippet there and
  answer it with `browser_file_upload`. When the plan's limit is reached, the "Create image" menu item is
  `aria-disabled`.
- The Playwright MCP only uploads from the folder the Claude session started in. For sessions started in the Unreal
  repo that is `/mnt/d/TalesOfVulkan/TalesOfVulkan/.playwright-mcp/` (gitignored there): copy references into
  `.playwright-mcp/a1/` and upload from there.
- Per chat: Upload & tools -> Create image **first** (turning it on drops attached pictures), then Aspect ratio 3:4
  for one standing figure, then Upload files.
- Save the full-size result straight into the project with `browser_run_code_unsafe`: hover the last
  `model-response img`, click the last "Download full size image" button, `download.saveAs('<art/<c>/raw/...>')`.
  The full size is about 896x1200; the image shown in the page is smaller.
- Gemini edits the image it just made: a follow-up in the same chat changes little (good for small fixes, like red
  gems on the crown). For a real redraw (a higher camera, new proportions) start a new chat. Never give it an earlier
  pixel version as a reference: it hands it back unchanged.
- Giving a finished sprite of another character as "copy its camera, proportions and pixel style, not its
  character" is what got the high camera and the big readable heads.
- Gemini's eyes are 1-2 shrunken pixels and usually lose their colour in the shrink: check every face at 8x and
  redraw the eyes with `--touchup` (each eye a dark pupil and a light catch-light).
- Animation strips: `sprites.py --anchor body --height 80` (80 = the body, the spear left out). The default places each
  frame by its box, so a stride or a spear that changes the box makes the body jump.
- A 4-frame strip at 16:9 (25 Oct, `elvis/raw/idle_F_g1.jpeg`): Gemini filled the whole height with tall, thin figures
  (head about a fifth of his height, where the master's is about a quarter, and a narrower body) that touched and
  overlapped each other. Tell it how big each figure is and to leave magenta all round each one.
- **What works for animation strips (25 Oct, Elvis's run):**
  - Render the guide with `"build": "chunky"` (`pose_strip.py`): Gemini paints over the guide's build, and the library
    man is tall and thin, so a plain guide gives a tall, thin Elvis with a small head.
  - `guide_pack.py`, then pad the strip onto a 16:9 magenta canvas, so the frames keep the canvas's layout.
  - Image 1 = the padded guide, image 2 = the master (`master_x4.png` on magenta). Prompt: "Repaint image 1 as a
    pixel-art sprite strip of <name>: keep image 1's canvas, its single row of N figures at the same positions and sizes,
    and trace EVERY pose exactly ... only replace each grey mannequin with <name>, drawn in the exact pixel-art style,
    proportions, colours, dark 1 px outline and details of image 2: <the details> ... Draw nothing else." Asking instead
    for "this character in these poses" made it copy the master's pose 8 times.
  - It still adds extra copies of the master around the strip (`band.py` cuts the strip out), or redraws the strip as 2
    rows (`sprites.py --rows 2`). Spear blades that reach over the next frame need `--split shapes`.
  - A detail it dropped (the cape, the spear's blade) comes back with one follow-up in the same chat; that follow-up
    also dulled the magenta to `#d95ac4`, which the clean-up still removes.
  - Then `sprites.py --anchor head` (head level, `--bob` for a designed bob; Gemini's own heights jump by up to 15 px),
    `eyes.py` for the eyes, and rebuild with `--touchup`. Each sheet's commands: `art/elvis/notes.md`.
  - Gemini repaints every frame, so dark armour shimmers from frame to frame and a level head's outline pops, and it
    drops details the master has (trim, ears, hair length). Where the upper body barely moves (Elvis's front and back
    runs), `stride.py` from the idle's frame 0 is cleaner than any Gemini strip; keep Gemini for poses that really
    change the body (the side run, attacks, rolls).
- **Attack strips (25 Oct, Elvis's light 1):**
  - Two views in one picture: `guide_pack.py <F strip> <B strip> <out> --aspect 16:9` stacks them as two rows at one
    scale. The back row came out well (6 poses traced, hair to the waist, cape); the front row did not (see below). A wide
    side view (the spear held level) fits better as 2 rows of 3: cut the strip with a cell pick and stack the halves.
  - Gemini often puts a front-on copy of the master as the first figure (both pictures did): number the poses in the
    prompt and drop the copy with `--pick`; the guard at the strip's end can open the swing too.
  - Front view thrusts don't work yet: from the high camera a spear thrust toward the viewer runs **below his feet**, and
    the sheet must cut everything below the feet line (the floor hides it), so the thrust doesn't read. Gemini also drew
    the front row smaller and narrower than the master, with blank faces. Next try: the front view alone (one row), and
    aim the thrust a little to his side so the spear stays above the feet line.
  - A raised arm and spear count as body, so the tallest-body scale shrank the back view to 74 px: use
    `sprites.py --scale-frame <guard frame>` so the guard stands 80 px like the idle (every run prints the body heights).
  - Reuse identical guide poses (guard at both ends, coil and pull back) with `--pick` so those frames are pixel-identical.
- Once `palette.png` exists, the lock snaps touch-up colours to the nearest palette colour: append a new colour to
  `palette.png` before using it in `touchup.json` (32 at most).
- **What made frames flicker, and what fixed it (25 Oct, the art review of the runs):**
  - Gemini repaints every frame. A head or chest painted 10 times differs in hundreds of pixels (1000-1400 per frame
    pair in the side run above the hips), and `--anchor head` only lines the boxes up: the eye still moved 5 px
    sideways. At game size that is flicker. Fix: build the frame from parts that are never repainted. One head
    (the idle's), one upper body (one good Gemini frame), moved whole by the bob; only the legs come from Gemini's
    frames, which move anyway (`stride.py`, `art/elvis/stride_run_S.json`): 100-280 pixels change per pair, all of
    them moves.
  - The magenta clean-up can leave a 1 px ring in one dark colour round every outline (`#221616` in Elvis's palette,
    10% of the side run). `stride.py`'s `"fringe"` deletes it where an outline is already inside it and makes it outline
    black elsewhere. Check each new sheet for one colour hugging the outline.
  - Feet: `--anchor head` keeps the head level, so Gemini's leg lengths decide where the feet land (2-5 px above the
    floor in 9 of 10 frames). Drop the legs onto the feet row per frame (`"feet": true`) and let the bob move the body.
  - A run made only by lifting the legs under a still body reads as sliding. What makes it read at game size, all from
    the stance's own pixels: the bob (0-2 px), a 1 px sway toward the planted foot, the spear bouncing a frame after the
    body (`"lag": 1`), the knee and boot as separate parts (the boot rises behind the knee), the lifted foot moving in
    toward the middle, the cape and hair swinging a frame behind. From behind, a boot kicked back is drawn in front of the
    cape (`"under"` per frame).
  - All three views share one cycle (10 frames at 13 fps, the same bob and phase), so turning keeps the step.
- **Pose guides (25 Oct, after the art review):** a clip that turns his hips makes Gemini paint him turning. The log's
  "hips facing" shows it; pass `yaw` as a list (one per frame) to re-centre those frames, keeping about 35 degrees of the
  twist (`art/tools/guide_jobs.json`: the boss's slash, backswing, charge and dive, Elvis's lunge). A blade that ends
  straight ahead hides behind him from behind: turn his chest (HK Slam) or swing the camera for that frame (light 4
  from behind). From the high front camera a spear thrust at the camera is a stub or runs below his feet: the front
  thrusts have their own keys (`HK Light1 F`, `HK Lunge F`, `HK Charge F`, `HK Thrust F`), aimed ahead and to his left
  like his front idle's spear. Gemini paints what the guide shows at the size it shows it: keep every standing figure
  at least about 190 px tall in a 1376 px wide picture (`guide_pack.py` prints the cell size; split a move into more
  pictures rather than shrink it).

## Limits seen

25 Oct 2026, Task A1: 11 images in 6 chats, no refusal, no rate limit, no daily cap message.
25 Oct 2026, 02:24 PDT, Task A3 (Elvis idle and run): the first image of the batch hit the plan's limit. Under the
prompt box: "Your limit resets at 5:07 a.m." with "See usage"; https://gemini.google.com/usage showed **Current usage
100% used, resets at 5:07 a.m.** and **Weekly limit 10% used, resets Oct 29 at 6:07 p.m.** The current-usage bar is a
rolling window shared with everything else on Danyal's account that night (A1's 11 images came earlier), so check
`/usage` before a batch, and expect only a handful of images per window. No refusal.
25 Oct 2026, 05:07-05:40 PDT, Task A3: after the reset, 8 images took the window from 0% to 84% (about 10.5% each, so
about 9 images per 5-hour window); the weekly limit went from 10% to 15%. No refusal.
25 Oct 2026, 06:11-06:25 PDT, Task A3 (Elvis roll and light combo): the window was still at 84% from the batch before.
2 images took it to 95%, then 100% ("Current usage 100% used, resets at 10:07 a.m."; weekly 15%). In a fresh chat the
"Create image" item is `aria-disabled` and the page says "Your limit resets at 10:07 a.m.". No refusal. The batch stopped
there: roll (F, S, B), light1_F and light 2-4 (F, S, B) wait for the reset.

## When a Gemini chat runs out

Danyal, 25 Oct 2026: "just use a new gemini chat each time if it runs out". If a chat refuses, stops making images, says a limit is reached, or gets slow and confused, open a new chat (New chat) and carry on, re-uploading the master and the pose strip. Report the lane as blocked only if several fresh chats in a row also refuse.
