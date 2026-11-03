# Art tools

Python runs through `uv run --with pillow --with numpy --with scipy python ...` from the project folder.
Blender is `"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"` and takes Windows paths.
In a clone made by Windows git (`core.autocrlf` true) the `make_*.sh` scripts come out with CRLF line ends, which bash
can't run: `tr -d '\r' < art/vulcan_boss/make_runs.sh | bash`.

| Tool | What it does |
| --- | --- |
| `art/sprites.py` | A Gemini strip on magenta -> a sheet: cut into cells, magenta and its rim tint removed, each frame shrunk to the shared scale (block mode colour, not the average, so lava cracks, trims and outlines stay crisp), feet on one line, <= 32 colours or locked to a palette, hand touch-ups, `<out>_x4.png` preview, optional manifest entry. Usage at the top of the file; `--selftest` checks it |
| `guide_pack.py` | A `pose_strip.py` strip -> a compact guide for Gemini: every cell cropped to the same box (hips centred, feet on one line), scaled up, side by side on magenta. Several strips (one move's views) become rows at one scale; `strip.png:0-3` packs only those cells (a wide view as two rows); `--aspect 16:9` pads the picture; `--widen K` draws every cell K times as wide (a broader mannequin, so Gemini paints a broader man); it prints how tall a cell comes out in a 1376 px wide picture. The packed guides for Gemini are in `art/guides/` (`packs.txt` lists each one's rows) |
| `breathe.py` | A still sprite (a master, or one clean Gemini view) -> a 2-frame breathing idle: everything above the belt 1 px lower in frame 1, nothing else changes. Writes the manifest entry |
| `stride.py` | A still stance (or one good Gemini frame) -> a run cycle with no flicker: a JSON recipe cuts parts out by rows and columns, a spear's line, brightness (hair) or colour, and moves each part per frame (legs lifted in turn, knees and boots apart, the body bobbing and swaying, the spear bouncing a frame behind, the hair and cape swinging); parts can come from another sheet (the side run's legs from Gemini's frames, `idle_S`'s head); holes a moved part leaves are filled from the body next to them. Nothing is repainted, every colour must be in `palette.png`, and every frame must keep a foot on the feet line. Recipes: `art/elvis/stride_run_F.json`, `stride_run_S.json`, `stride_run_B.json`; the keys are at the top of the file |
| `headlock.py` | One head for every frame of a Gemini sheet: the idle's own head (and hair) pasted where each frame's head is (found by matching), the frame's own head pixels round it cleared (bright ones and outline scraps; the body next to them fills the holes), so the face, the eyes and the hair are never repainted; `--front X` keeps the side walk's own hair behind the skull, `--luma` takes only the hair from a back view, `--mend` paints out the idle's spear across the hair, `--cut` leaves the idle's spear shaft out of the paste, `--mane` pastes one frame's streaming hair (stretched longer) on every frame and `--clear` removes each frame's own round it, `--chest` pastes one frame's breastplate on every frame (no trim shimmer), `--steady` keeps the head on one column, `--bob-max` lifts a squatting frame (the boss), `--sink` lowers a frame drawn too tall (its feet go under the line: give the key `"below"`), `--floor` puts the feet on a row (`--thick`: a boot, not the spear's butt) and `--air K:N` lifts frame K N px above it (flight frames; the front and back runs' passing frames onto a feet line N rows up), `--fringe` removes the clean-up ring, `--floor-half` counts only the boots for `--floor`, `--align` finds the heads with one of the sheet's own heads (a head redrawn by hand matches badly); it prints each frame's head and feet rows. Recipes: `art/elvis/make_runs.sh`, `make_walks.sh`, `art/vulcan_boss/make_runs.sh`, `make_walks.sh`. `--selftest` checks it |
| `legswap.py` | Front and back runs: each output frame is one frame's body above a row with another frame's legs below it (within W px of the body's centre), mirrored if asked, so the legs alternate where Gemini lifted the same leg in every front figure. Recipe: `art/vulcan_boss/make_runs.sh`. `--selftest` checks it |
| `sprite_doctor.py` | After `steady_sheets.py` and `sprite_consistency.py`: follows each part of the figure from frame to frame and restores any pixel that 3 of the 4 frames either side agree on and this frame alone breaks (shimmer, shading that crawls), removes edge pixels that blip for one frame, specks and pinholes, and tidies 1-2 px shade specks in each frame; the face (found as `steady_sheets.py` finds it), ink and the outline are never touched, and alpha is only ever copied. `--strong` also smooths speckled texture into shading. Writes cleaned copies, `report.json` and before/after GIFs to `art/_work/doctor/` (`doctor_strong/`), never into the game. `--all`, `--selftest` |
| `rekey.py` | A Higgsfield picture whose background came back grey, lilac, pink or a white-pink gradient -> the same picture on flat #FF00FF for `sprites.py`. `--selftest` checks it |
| `band.py` | Cut one row of figures out of a Gemini picture that padded the strip with extra copies above and below: shapes reaching outside rows Y0..Y1 go (touching shapes are split first) |
| `eyes.py` | Eye touch-ups for `sprites.py --touchup`: front frames get the master's own eye pixels where its head matches; `--side` finds the profile eye and draws a pupil and an ice-blue catch-light |
| `gif.py` | Manifest keys -> a 4x GIF for `docs/progress/`, timed by fps and holds, on sand; `--row` plays several side by side; a `"below"` key is drawn that much lower, as the game places it |
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

## Higgsfield (25 Oct 2026, from 08:30: Danyal "go ahead and use it til 0")

- Model `nano_banana_2_1` (Gemini's image model), `resolution` 1k, 1.5 credits a picture, 16:9 comes back 1376x768.
  Upload with `media_upload` (presigned URL), `curl -X PUT -H "Content-Type: image/png" --data-binary @file '<url>'`,
  `media_confirm`; pass the ids as `medias` with role `image_references`, the guide first, the reference second. Ask
  for two of each request in one `generate_image_batch` (2 x 1.5 credits) and keep the better: one of the pair usually
  adds a second spear, a copy of the master or a flipping lock of hair. `jobs_wait`, then `curl` the result URL into
  `art/<c>/raw/`. About 1 in 10 jobs fails (no charge seen); resubmit it.
- The same "repaint image 1" prompt as Gemini's works. A reference picture with all three idles side by side
  (`art/guides/ref_elvis_FSB.png`, "draw him like the figure on the right of image 2") gives the back view his long hair.
- **Real runs (Danyal: "make it so they run and not just take 1 step of a pixel each"):** the full stride of Jog
  Forward with the lean cut to 15 degrees (`HK Run Full`) painted into real runs in every view: strides, the cape and
  hair streaming. What still went wrong, and the fix: Gemini draws a run's passing pose as a deep squat from the front
  and behind (12 px at 80, even with the guide's legs eased) -> `headlock.py --bob-max 4` lifts it into a flight frame;
  the back view comes out slimmer, longer-legged and smaller-headed than `idle_B` every time (4 tries) ->
  `sprites.py --widen 1.36 --height 66`; the first figure can come out bigger than the rest -> `--frame-scale 0:0.93`;
  the eyes are lost and every face differs -> `headlock.py` pastes the idle's head; a free fist swung forward reads as a
  raised fist beside the head from behind (the camera looks over his shoulder at it), even when the prompt says to keep
  it low.
- **The boss's runs (25 Oct, `art/vulcan_boss/make_runs.sh`, guides `B25`-`B27`, `HK Boss Run`):**
  - **One row beats two.** In a 2x4 sheet Gemini drew the second row smaller with shorter legs (its boots 8-12 px higher
    at 86 px, so no one feet line fits both rows). A single row on a 4:1 or 8:1 canvas keeps one ground line and one
    size; at 4:1 Gemini fills the height and the figures touch (a fist or a blade reaches into the next one, which a
    column cut slices), at 8:1 each figure has its own square and `--split shapes` works. 8:1 comes back 2928x352, 4:1
    2064x512, 21:9 1584x672.
  - **8:1 can lose the view or the background:** asked for a side run it drew a three-quarter front view once (say "PURE
    SIDE VIEW, in profile, facing right, his back to the left of the picture"); walks came back as front views or on a
    white-pink gradient. A light purple or dulled magenta background still keys out.
  - **From the front Gemini lifts the same leg** (the one on the sword's side) in nearly every figure, whatever the guide
    and the prompt say (7 of 10, 6 of 6, 5 of 8 in three tries, even with each figure's pose written out). `legswap.py`
    gives the other half of the cycle that frame's legs mirrored (front legs are symmetric).
  - **The greatsword below the boots** (2x4 sheets, a low trailing carry) sets the feet line and the boots float; the
    single-row runs carried it higher and the problem went away. Check the lowest pixel of each frame is a boot.
  - Never give Gemini its own earlier sheet as a third reference (a side run, to show the front run's timing): it
    hands that sheet back unchanged. A different seed drew a different man (bare chest, no beard): reject on sight.
- **After the review of the real runs (25 Oct afternoon):**
  - Gemini paints the build the guide's mannequin has: scaling each guide cell 1.3 times as wide (`guide_pack.py --widen
    1.3`) and giving `idle_B` alone as image 2 ("exactly as broad as image 2 ... a cape down to his ankles") gave a back
    run as broad as `idle_B` with a long cape, where four tries on the plain guide all came out slim.
  - Feet from the high camera: a foot toward the camera is drawn lower on the screen. In a front run the forward foot,
    and in a back run the kicked-back foot, reaches 8 px below the planted passing foot, so "the passing frame floats" is
    the wrong reading: stand the passing frames on a feet line 8 rows up (`headlock.py --air 1:8,5:8`) and give the key
    `"below": 8`. From the side every foot is on one line.
  - A side run's stride as Gemini draws it from the Jog guide sweeps about 27 px a frame under him, twice the ground's
    13 px at 5 m/s and 12 fps, so no planted foot can stay put for two frames: only the passing frames touch the floor,
    the others fly 2-3 px up (`--air`). That stride matches the sprint (7.5 m/s, 20 px a frame at 12 fps, 27 at 9 fps).
  - Gemini repaints the breastplate, the mane and the face in every frame. Paste one of each on every frame
    (`--chest`, `--mane`, the idle's head); only the limbs, the cape and the spear then change.
- **The boss's side run and walk, remade after the review (25 Oct evening, guides `B31`, `B32`):**
  - **Check the feet, not just the poses.** Gemini draws most figures of a strip as one mid-stance pose (the planted boot
    in one place for 3-4 figures, or one wide stance in 7 of 8), whatever the guide and the prompt say. Measure each
    frame's boots on the floor row against his hips: a planted boot must move back about ground speed / fps a frame
    (13 px at 14 fps for the boss's run). Then build the cycle from the figures that do: `sprites.py --pick` in step
    order (contact, passing, flight, reach for a run; heel down, weight on it, passing, reaching for a walk), one step
    drawn twice if needed.
  - **Keep a run's flights:** `--anchor strip` (Gemini draws the figures on one ground line, flights off it), not
    `--anchor body` or `headlock.py --floor`, which put every frame's lowest pixel on the floor, so the contacts jump.
  - **A sword across the legs in the guide becomes a second sword.** Carry it off the legs (`--carry 0.3,-0.85,0.45`
    level behind for a run, `0.3,-0.95,-0.2` trailing low for a walk) and say "ONE greatsword ... never a second blade".
  - **Backgrounds:** 3 of 4 side pictures came back grey, lilac or a white-pink gradient. `rekey.py` puts them on
    magenta (light, unsaturated or pinkish pixels joined to the border, and near-white gaps), then clean up as usual.
  - **A redrawn head (the idle's crown on a back view) is found badly** by `headlock.py`'s matching (7 px off): pass
    `--align` with one of the sheet's own heads at the same spot. A sword tip below the boots: `--floor-half 20`.

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
