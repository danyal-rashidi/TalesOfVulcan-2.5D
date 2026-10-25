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
| Vulcan sprite | 80 px tall (64 lost his eyes), made in Gemini from his master picture, cleaned by `art/sprites.py` | Redo the master sprite from the high camera angle, asking for 80 px with clear eyes |
| Animations | Idle; a 12-frame walk toward the camera that barely moves its legs | Blender pose strip as a guide for Gemini; then side and back views |
| Levels | One test room (stone, raised blocks, pillars, lava) | — |
| Colosseum snippet code | Task 1 of 6 done: pixel camera, sprites with fallback, controls, test runner (7 tests pass). `play.bat` now opens the placeholder game | Task 2: combat and Elvis |

## Log

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
