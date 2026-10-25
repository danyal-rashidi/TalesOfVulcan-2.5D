# Tales of Vulcan 2.5D: Progress Log

Oct 24, 2026 · @Danyal

The 2.5D pixel-art version of Tales of Vulcan, in the style of Alabaster Dawn, with the same story as the Unreal game (`D:\TalesOfVulkan\TalesOfVulkan`, which stays as it is). Every change is recorded here as it is made, newest first, so Danyal can follow the game being built.

## Rules for whoever builds the game

- **Every entry has:** the date, what changed in one or two plain sentences, why, and where it lives (file or folder path).
- **Show it.** Anything you can see gets a picture in `docs/progress/`; anything that moves gets a GIF.
- **Newest entry at the top.** Never delete old entries. If something is undone, add a new entry saying what and why.
- **Keep the status table below up to date.**

## Where things stand

| Part | Status | Next step |
| --- | --- | --- |
| Story | Same as the Unreal game: `D:\TalesOfVulkan\TalesOfVulkan\docs\STORY.md` | — |
| Engine | Godot 4.7.2 Standard (GDScript) at `D:\GODOT`. Start: `play.bat` or the desktop shortcut "Tales of Vulcan 2.5D" | Put the project in git |
| Look | Drawn at 640x360, scaled up 3x with no smoothing; camera looks down at 48.6°; blocks 32 px per metre; camera and sprites snap to whole pixels | Settle once the master sprite has the high view |
| Master sprites | Elvis, possessed Vulcan and human Vulcan, 80 px (25 Oct): Gemini, seen from the high camera, eyes redrawn by hand, in `art/<c>/master.png`. After review, the boss's head (crown ring seen from above, near-black hair and beard like human Vulcan's) and human Vulcan's eyes were redrawn by hand | Danyal checks them; then the pose-guide tool (Task A2) and the animations |
| Animations | Pose guides ready (25 Oct): `art/tools/pose_strip.py` renders grey pose strips from the CC0 motion library at the game's camera, and every animation is mapped to a clip or hand-keyed poses in `art/tools/clips.md` (18 strips checked, among them Elvis's run, roll and light 1-4) | Task A3: Gemini paints each strip over the master, most-seen animations first |
| Levels | One test room (stone, raised blocks, pillars, lava) | — |
| Colosseum snippet code | Task 1 of 6 done: pixel camera, sprites with fallback, controls, test runner (7 tests pass). `play.bat` now opens the placeholder game | Task 2: combat and Elvis |

## Log

### 25 Oct 2026: Elvis's pose guides after review (run, roll, light 2-4)
- **What:** a review found that three of Elvis's first animations had guides that would mislead Gemini. All three are now hand-keyed and checked at 4x at game size, in the front, side and back views.
  - **Run:** from the front, the far leg hid behind his body in 6 of 8 frames, and the arm swinging back showed above his head, so he looked like he was hopping and waving. The jog's stride and forward lean are now halved, his left arm swings bent from his side to ahead of him and never behind his back, and his right fist carries the spear steady. Both legs show in every front frame.
  - **Roll:** the spear, held in his fist, stabbed through his body as he turned over, and the last two frames were already standing. The library's roll also floats about 0.9 m off the floor through the tuck. Each pose is now set down on the ground, the frames run from the crouch to the moment he rises, and the guide has no spear.
  - **Light 2-4:** they came from the library's sword combo, which spins his hips through about 90° and points the spear every way in turn: a flail. Each hit is now keyed by hand on light 1's stances, with the spear's path set pose by pose. Light 2 is a low sweep at the legs, light 3 a rising cut, and light 4 a cut over the shoulder down into a lunge with the tip on the ground.
  - **The tool:** key poses can now aim the weapon, ease a clip toward a calmer pose (keeping the feet on the ground), and set the body down on the floor. The checked guides that were not changed (light 1, the boss's slam and kneel, the statue) come out byte-identical.
- **Why:** run, roll and light 1-4 are the first animations Task A3 paints. Gemini is told to copy the poses exactly, so a pose that reads wrong becomes an animation that reads wrong.
- **Where:**
  - `art/tools/pose_strip.py`: the new key options `aim`, `ease`, `plant` and `each`.
  - `art/tools/hand_keys.json`: "HK Run", "HK Roll", "HK Light2", "HK Light3", "HK Light4".
  - `art/tools/clips.md`: the run, roll and light 2-4 rows, now **Checked**, and the new key options.
  - `art/tools/test_strips.json`: the batch of all 20 checked strips.
- **Checked:** the batch renders all 20 strips with nothing clipped.
- **Claude's call:** light 2-4 are a low sweep, a rising cut and an over-the-shoulder cut into a lunge. The clip map already named a sweep, a rising cut and a lunging finisher, and the Unreal game's staff combo has the same kind of moves. The Unreal swings are Paragon clips, which must never go to Gemini, so these are keyed from scratch. Each hit holds the spear in a different place (light 1 at chest height ahead, light 2 at knee height, light 3 upright, light 4 on the ground), so the four read apart even in still frames.
- **Claude's call:** the roll is the library's only roll, a dive roll, kept on the ground. The guide shows no spear: tell Gemini he keeps the spear close along his right side.
- **Claude's call:** the run's shorter stride is used in all three views, not only the front one, so every view shows the same move.
- **Claude's call:** light 4's back view is turned 25°. Straight from behind, the spear at the impact points away from the camera and shrinks to a stub.

![Pose guides at game size: the run from the front, the roll from the side, and light 2, 3 and 4 from the side](progress/2026-10-25_pose_guides_review2.png)

### 25 Oct 2026: the boss's crown and beard after a second review
- **What:** a second review of the masters found two problems with the possessed Vulcan's hand-drawn head, and the head is drawn again.
  - **Crown:** its 1 px black ring and spikes merged with the outline and the hair, so at game size it showed as five red dots and a dark headband. It is now a thicker black-iron ring seen from above, with a 1 px lit rim along its far edge and along the front band's top edge. Five spikes stand on the back arc, each with a lit side, a black side and a red tip; the tallest is in the middle. Three red gems sit on the front band.
  - **Hair and beard:** they were warm mid-brown, while human Vulcan's are near-black, so the head jumped from orange-brown to black at C3, and the brown wrapped the grey face like a fur hood. Both are now near-black, in the boss palette's matches for human Vulcan's colours, with a few dark-brown strands.
  - The face, the molten eyes, the body and the size are unchanged. Elvis and human Vulcan are unchanged.
- **Why:** the crown is the thing Elvis has to strike, so it must read in play. The boss also has to read as the same man as human Vulcan when the crown drops.
- **Where:**
  - `art/vulcan_boss/touchup.json`: the head, rows 0-26.
  - `art/vulcan_boss/palette.png`: the old beard brown `#94603a` is replaced by the crown's lit edge `#9aa0a6` (still 32 colours).
  - `master.png` and `master_x4.png` were rebuilt with the command in `art/vulcan_boss/notes.md`, which explains the new head.
- **Checked:**
  - No body pixel changed.
  - Every pixel is fully opaque or fully clear, with no magenta, as one connected shape.
  - Every colour is in the palette.
  - `master_x4.png` is an exact 4x, and the size is still 66x89.
  - `sprites.py --selftest` passes.
- **Claude's call:** the crown's lit edge is a cool light grey, a new colour, rather than ember orange. Grey reads against both the sand and the near-black hair, and keeps the crown black iron. The orange is kept for the crown's glow effects later.
- **Claude's call:** the boss's hair and beard are near-black like human Vulcan's. This replaces the earlier call to make them mid-brown so they would show against the charcoal skin. The lighter grey face now does that job.

![The three masters at 4x after the second review](progress/2026-10-25_masters_review2_x4.png)

### 25 Oct 2026: pose guides after review (the boss's slam and kneel)
- **What:** a review of the pose-guide tool found two guides that would mislead Gemini, and both are remade.
  - **Slam:** the old clip, "Sword Heavy D", spins about 145° through the wind-up, so the front sheet showed the boss side-on until the impact. The new slam is hand-keyed on the library's two-handed "Mining" swing, which faces the camera throughout: guard, raise, overhead, chop, the blade landing on the ground ahead, held, lift, guard.
  - **Kneel:** the blade went about 1 m through the floor, because the clip reaches the right hand down to the ground. Now his right hand stays on the hilt ahead of his shoulder, and the sword is planted on its tip beside him, so he leans on it as he goes down.
  - **The tool:** a weapon can no longer pass through the floor. If an end would, the weapon tilts up about the hand until that end rests on the ground, and the log lists those frames. The checked guides for Elvis's run and light 1 are unchanged.
- **Why:** the slam is the boss's most-seen attack, and the kneel is the moment before the crown is struck. A wrong guide becomes a wrong animation.
- **Where:**
  - `art/tools/pose_strip.py`: the ground rule.
  - `art/tools/hand_keys.json`: the hand-keyed clips "HK Slam" and "HK Kneel".
  - `art/tools/clips.md`: the slam and kneel rows; both now **Checked**.
  - `art/tools/test_strips.json`: the five checked strips.
- **Checked:** the batch renders with nothing clipped.
  - In the slam, his hips stay within 18° of the camera in every frame.
  - The slam's blade rests on the ground in the impact frames, and the kneel's sword rests on its tip in the last three.
  - Both read at game size at 4x.
- **Claude's call:** the slam is built on the library's mining swing, a pickaxe chop, rather than a sword clip, because no sword clip in the library chops overhead while facing the camera. His wrists roll the blade down for the impact.
- **Claude's call:** at 0 hp the boss leans on his planted greatsword with one hand on the hilt, its tip on the floor ahead and to his right, and his head bowed.

![The boss's new pose guides, front view: the slam (top) and the kneel at 0 hp (bottom)](progress/2026-10-25_pose_strip_slam_kneel_F.png)

### 25 Oct 2026: master fixes after review (the boss's head, human Vulcan's eyes)
- **What:** a review of the three masters found two problems. The possessed Vulcan's head was drawn front-on: a flat-topped box of a crown, no hair, and a dark beard lost in the charcoal skin. Human Vulcan squinted: no catch-light, and black pupils merged with his brows. Both were fixed by hand, pixel by pixel, at game size. Elvis passed and is unchanged.
  - **Boss:** the crown is now a ring seen from above, around the top of his head. Its back arc and tall red-tipped spikes stand behind the hair, and the front band dips over the forehead with three red gems. Inside the ring is dark brown hair swept back, as on human Vulcan. Brown hair at the temples runs into a full mid-brown beard. The face is a lighter stone grey, so the molten eyes, nose and brows read. The body is unchanged.
  - **Human Vulcan:** each eye is now a cream white, a dark brown pupil and a bright catch-light, under brows in his hair's brown.
- **Why:** every animation is painted from these masters, so a front-on crown and a faceless boss would carry into all of them. The boss also has to read as the same man as human Vulcan when the crown drops (C3).
- **Where:**
  - `art/vulcan_boss/touchup.json`: the whole head, rows 0-26. Its `palette.png` gained 3 colours (32 now).
  - `art/vulcan_human/touchup.json` (new). Its `palette.png` gained 1 colour (32 now).
  - Both `master.png` and `master_x4.png` were rebuilt with the commands in each `notes.md`.
  - `art/tools/README.md` has a new gotcha: append a touch-up colour to `palette.png` first, or the lock snaps it to the nearest colour.
- **Checked:**
  - Every pixel is fully opaque or fully clear.
  - Each sprite is one connected shape, with no magenta.
  - The outline is 94-100% dark.
  - Every colour is in the palette.
  - The sizes are unchanged: boss 66x89, human 50x81.
- **Claude's call:** the boss's head was drawn by hand at 80 px rather than made again in Gemini. Gemini drew the crown front-on even when chat 3 asked for it seen from above, and a follow-up in the same chat changes little. Gemini will still paint the animations from this master.
- **Claude's call:** the boss's hair and beard are a warm mid-brown (`#6e4429`), lighter than human Vulcan's near-black beard, so they show against the charcoal skin.
- **Claude's call:** the boss keeps the first build's scale. With the top of his hair now visible, he measures 84 px from hair to feet, 4 px taller than human Vulcan. The armour, the boots and the C3 ash cover the swap.

![The three masters at 4x after the fixes](progress/2026-10-25_masters_fixed_x4.png)

### 25 Oct 2026: the pose-guide tool and the clip map
- **What:** a Blender tool that turns the free (CC0) motion library into grey pose guides for Gemini. Each guide is a strip of poses, one per cell: a clay mannequin seen from the game's camera on flat magenta, holding the character's weapon. Every animation in the snippet now has a pose source: a library clip and its frames, or hand-keyed poses described in words, plus the prop it needs (Elvis's spear, the boss's greatsword). Four test strips were rendered and checked at 4x at game size: Elvis's run (front and side), his first light attack (side) and the boss's sword slam (front).
- **Why:** Task A2 of the colosseum plan. Gemini keeps a motion consistent when it has a pose to paint over.
- **Where:**
  - `art/tools/pose_strip.py`: the renderer, for one strip or a batch.
  - `art/tools/list_clips.py`: lists the library's 360 clips.
  - `art/tools/clips.md`: how to use the tool, the animation map and the clip list.
  - `art/tools/hand_keys.json`: hand-keyed clips (the statue so far).
  - `art/tools/test_strips.json`: the four checked strips.
  - The work copy of the library is in `art/_work/a2/` (not in git).
- **Seen:**
  - The library's own body is an old Elvis in a long cape that hides every pose, so the guide uses a mannequin of balls and tubes on the same bones. His left limbs are darker and a nose shows which way he faces.
  - The library's sword moves are one-handed and often swing the right arm out of the left hand's reach. The tool puts the left hand on the weapon, drawing the hands together when needed, so the slam and the spear thrust are two-handed.
- **Claude's call:** the spear combo and the slam come from the library's sword clips, with the weapon swapped and both hands on it, rather than being keyed by hand as the design said, because they read clearly at 4x.
  - Light 1 is "Sword Light D" played back from its recovery: a step-in thrust from guard.
  - The slam is "Sword Heavy D". (Replaced the same day: see "pose guides after review" above.)
  - Light 2-4 were "Sword Light A, B and C". Only light 1 had been checked, and the others read as a flail. (Replaced the same day: light 2-4, the run and the roll are hand-keyed; see "Elvis's pose guides after review" above.)
  - Moves with no good clip stay hand-keyed: the wake, the spell, the breath, and human Vulcan looking at his hands. clips.md lists their key poses.
- **Claude's call:** the guide's weapons are stand-in shapes, a 2.2 m spear and a 1.85 m greatsword. Gemini takes their real look from the masters.
- **Claude's call:** every strip has the same scale, 80 px per metre (the library man stands about 125 px), and the ground on the same row in every cell. Strips with a weapon use 384 px cells so the blade fits.
- **Claude's call:** on the run, the spear is held at a steady, nearly upright angle instead of following his pumping fist, which spun it around.
- **Claude's call:** the guides use the game's true 48.59° view, which squashes a standing man to about two thirds of his front-view height. If Gemini copies the squash and the characters come out shorter than their masters, render the guides at a lower angle.
- **Claude's call:** the statue's kneel follows your 24 Oct Unreal version: on the right knee, left palm on the raised knee, right palm on the thigh, no sword. It is built on the CC0 clip "Fixing Kneeling", because the Unreal kneel came from Paragon, which must never go to Gemini. Its arms still need a little tuning.

![Elvis's light 1 pose guide, side view: guard, coil, two-handed thrust, retract](progress/2026-10-25_pose_strip_light1_S.png)

### 25 Oct 2026: the three master sprites (Elvis, possessed Vulcan, human Vulcan)
- **What:** one master sprite per character, made in Gemini and cleaned to game size: Elvis in his 24 Oct look, the possessed Vulcan in his armour and crown, and Vulcan as a man. All three are seen from the game's high camera (top of the head and shoulders visible), and each eye reads at game size as a dark pupil beside a light pixel. 11 Gemini images in 6 chats, at least 3 candidates each, compared at 4x.
- **Why:** Task A1 of the colosseum plan. Every animation will be painted from these, so they fix each character's look, size and palette.
- **Where:** `art/elvis/`, `art/vulcan_boss/`, `art/vulcan_human/`: `master.png`, `master_x4.png`, `palette.png`, `raw/` (Gemini's originals), `candidates_x4.png`, `notes.md` (references, prompts, why this one). `art/sprites.py` now takes `<strip> --cols --rows --height [--palette] --out [--manifest --key --fps --loop] [--touchup] [--quant]`. The boss's colour reference is rendered from a copy of `Vulcan.blend` by `art/tools/render_ref.py`. How to drive Gemini: `art/tools/README.md`.
- **Seen:** at 80 px Gemini's eyes shrink to 1-2 pixels and fade into the skin, so Elvis's and the boss's eyes were redrawn pixel by pixel (`touchup.json`). Averaging each block also dulled the lava cracks and lost the gold buckle, so the shrink now keeps each block's most common colour.
- **Claude's call:** masters chosen by Claude (Danyal: "You pick, keep going"). Elvis: the ready stance with the spear across his body, because it shows his long white hair. Boss: the version with a tall black crown and red gems, because the crown is what Elvis strikes and it must read. Human: the version whose head and camera match the other two.
- **Claude's call:** Elvis has face A with pale cool skin and ice-blue eyes, from the 24 Oct face sheet. Swap it if you pick another face.
- **Claude's call:** "80 px tall" means the body from the top of the head to the feet. Elvis's spear tip and the boss's crown spikes stick up about 8 px more, so those two masters are 89 px high.
- **Claude's call:** the boss's crown is taller than the 3D model's spiked circlet, and his hair barely shows under it, so it reads at 80 px. (Replaced the same day: see "master fixes after review" above.)
- **Claude's call:** the browser can only upload from the Unreal repo's `.playwright-mcp/` folder (gitignored there), so reference copies were put in `.playwright-mcp/a1/`. Nothing tracked in the Unreal repo changed.

![The three masters at 4x](progress/2026-10-25_masters_x4.png)

### 25 Oct 2026: the foundation of the colosseum snippet
- **What:** the shared base every later part builds on. A camera and sprites locked to the pixel grid (the test room's maths, now in one place); a sprite player that reads each character's `manifest.json` and never crashes on missing art; all the controls for keyboard, mouse and controller; hit-stop, shake and slow motion; a screenshot driver; and a test runner (7 tests, all passing). `play.bat` now opens a placeholder: a stone floor and a blue stand-in Elvis (Vulcan's old sheet, tinted) you walk with WASD, arrows or the left stick.
- **Why:** Task 1 of the colosseum plan (`docs/superpowers/plans/2026-10-25-colosseum-snippet.md`), so the combat, arena, boss and cutscenes can be built on it.
- **Where:** `core/` (`pixel.gd`, `pixel_camera.gd`, `character_sprite.gd`, `sprite.gdshader`, autoloads `feel.gd`, `controls.gd`, `shot_driver.gd`), `tests/`, `game/`, `art/standin/`, `project.godot`.
- **For the builders:** after adding a new `class_name`, run Godot once with `--headless --import`, or the other scripts can't see the class. Tests: `res://tests/run_tests.tscn`; any engine or script error during a test fails it, warnings don't.
- **Claude's call:** the stand-in manifest has an extra optional `"start"` field (cells to skip), because idle and walk share one sheet. Task 6's manifest test must allow it.
- **Claude's call:** `play()` starts a one-shot animation again if it has already finished, so code waiting for `finished` can't get stuck; a key that is still playing is left alone.
- **Claude's call:** exact diagonals show the front or back view, not the side.
- **Claude's call:** hit-stop, shake, slow motion and the white flash are timed in real seconds, so they still run during a hit-stop.
- **Claude's call:** sprites are unshaded, as in the test room, so the storm and blood-red lighting won't tint the characters on its own. The arena task can tint them if it needs to.

![The placeholder: stand-in Elvis on the stone floor, 3x](progress/2026-10-25_foundation.png)
![Walking, 8x: one texel per screen pixel, no blur](progress/2026-10-25_foundation_crop_x8.png)

### 24 Oct 2026: Vulcan has eyes again (80 px instead of 64)
- **What:** Vulcan's sprite is now 80 px tall instead of 64. Gemini's eyes are 1-2 of its pixels wide, so shrinking to 64 averaged them into the skin; at 80 px they show. Keeping the darkest pixel per block was tried too: it brings eyes back at 64 but blackens the face.
- **Why:** Danyal: "he kind of doesnt have eyes anymore".
- **Where:** `art/vulcan_sheet.png` (cells 46x81), `main.gd` (`CELL`), `art/sprites.py` (height is an argument; the optional dark-detail shrink stays off).

![Faces: 64 px, 64 px keeping dark pixels, 80 px](progress/2026-10-24_eyes_compare.png)
![80 px in the room](progress/2026-10-24_eyes_80px.png)

### 24 Oct 2026: the pink edge is gone from Vulcan's sprite
- **What:** a few edge colours had picked up the magenta background (about 900 pixels over 13 frames); the clean-up now turns them warm brown. 0 pinkish pixels left.
- **Why:** Danyal saw pink pixels around him in the room.
- **Where:** `art/sprites.py`, `art/vulcan_sheet.png`.

![The sprite sheet, 4x](progress/2026-10-24_vulcan_sheet.png)

### 24 Oct 2026: the test room
- **What:** a Godot project with one room built in code: stone floor, raised blocks and pillars with brick fronts, two glowing lava pools, sun shadows, and Vulcan walking with arrows or WASD.
- **Why:** to see the size and camera angle in a real scene before making more sprites.
- **Where:** `main.gd` (the whole room), `project.godot`, `play.bat`.
- **Seen:** he suits the room, but he's drawn straight from the front while the ground is seen from above, so he looks flat-on; the walk is weak; he only faces the camera.

![The test room](progress/2026-10-24_test_room.png)

### 24 Oct 2026: first Gemini sprite test
- **What:** Danyal made Vulcan's master sprite and a walk strip in Gemini. He stays the same person in all 12 frames; the legs barely move.
- **Why:** to find out whether Gemini can make animation frames that match.
- **Where:** `D:\TalesOfVulkan\PixelTest\` (frames cut and aligned), prompts in this session.

![Gemini's walk, cut and aligned](progress/2026-10-24_gemini_walk_raw.gif)

### 24 Oct 2026: a second, 2.5D version of the game
- **What:** Danyal decided to make Tales of Vulcan again in 2.5D pixel art, styled like Alabaster Dawn (top-down slanted view, 32-bit-style sprites on 3D block ground), in Godot. Same story; the Unreal game is kept.
- **Why:** he likes the Alabaster Dawn look, and 2.5D avoids the 3D grind (meshes, hair, camera).
- **Where:** this folder, `D:\TalesOfVulkan\TalesOfVulcan25D`.
