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
| Engine | Godot 4.7.2 Standard (GDScript) at `D:\GODOT`, in local git (never pushed). Start: `play.bat` or the desktop shortcut "Tales of Vulcan 2.5D"; F11 or Alt+Enter for full screen. 144 fps on the RX 9070 (vsync), 1530 without | — |
| Look | Drawn at 640x360 and scaled up by a whole number with no smoothing: 3x in the 1920x1080 window, 4x full screen at 2560x1440. Camera looks down at 48.6° with a slight lead; blocks 32 px per metre; camera and sprites snap to whole pixels, and the fighters are drawn between physics steps so they move every frame at 144 Hz | Danyal plays it |
| Master sprites | Elvis, possessed Vulcan and human Vulcan, 80 px (25 Oct): Gemini, seen from the high camera, eyes redrawn by hand, in `art/<c>/master.png`. After review, the boss's head (crown ring seen from above, near-black hair and beard like human Vulcan's) and human Vulcan's eyes were redrawn by hand | Danyal checks them; then the pose-guide tool (Task A2) and the animations |
| Animations | Elvis's idle and run in all three views, and light 1 from the side and from behind (25 Oct). The runs were rebuilt after the art review from parts that are never repainted, so nothing flickers: the side run keeps one head (with his long hair) and one upper body, only its legs are Gemini's; the front and back runs bob, sway, bounce the spear, bend the knee and swing the cape. All three characters have a manifest; the boss and human Vulcan stand as their masters for every move. Every remaining pose guide is rendered and packed: 48 pictures in `art/guides/`, one Gemini request each, listed with their prompts in `art/tools/gemini_queue.md`. Front attacks may draw below the feet (`"below"`) | Gemini, when its window resets: `art/tools/gemini_queue.md` from the top (human Vulcan's master redo, then Elvis's roll and light 1-4, then the boss) |
| Levels | One test room (stone, raised blocks, pillars, lava) | — |
| Colosseum snippet code | All 6 tasks done (25 Oct): pixel camera, sprites with fallback, controls, test runner; Elvis's moves, hits, health, stamina and flasks; the colosseum with its moods and floor cracks, and 14 effects; Vulcan's statue, wake, moves, poise, phase two and kneel; the HUD, the pause menu, C1, the fight with its restart, C3 to the title card, and a bot; the feel and speed pass (58 tests pass). `play.bat` plays the whole snippet | Danyal plays it (`docs/NEXT.md`); the code takes each new sheet as the art lane adds it |

## Log

### 25 Oct 2026: a move without a sheet keeps the way Elvis faces (Task 6 review fix)
- **What:** when a move has no sheet of its own, Elvis now shows his idle for the way he faces (back, side or front), not always his front idle. Before, every roll, heavy, light 2-4, drink, hurt and death turned him to face the camera; in C3 his heavy on the kneeling Vulcan showed his face while the crown flew, though he stands facing Vulcan. A real character now falls back `anim_dir → anim_F → idle_dir → idle_F → stand-in idle_F`.
- **Why:** the Task 6 reviewer saw him flip to the front in C3 (shots 1-4) and in the bot's fight.
- **Where:** `core/character_sprite.gd` (`_resolve`); new checks in `tests/test_sprite.gd` (a lunge facing back plays `idle_B`; a roll to the left plays `idle_S`, mirrored). `docs/NEXT.md` now says what a move without a sheet looks like.
- **Checked:** 58 tests pass. `bot=unmask fast` frames 240 and 300 (the heavy and the recoil): his back to the camera, facing Vulcan; the log shows `lunge_B` and `charge_B` using `idle_B`. `bot=fight` frames 660-720: his back, facing the statue.
- **Claude's call:** the move's own front sheet still comes before the idle of his view (the plan's order). So if `light2_F` comes before `light2_B`, a light 2 facing back shows the front swing until `light2_B` exists.

![Elvis's heavy on the kneeling Vulcan and his recoil in C3, now with his back to the camera, facing Vulcan](progress/2026-10-25_task6_review_facing.png)

### 25 Oct 2026: Elvis's runs fixed (no flicker, they read as runs), every remaining pose guide made, and the Gemini queue (art review fix, Task A3)
- **What:**
  - **The side run** no longer repaints his head. Its upper body is one of Gemini's frames, kept still; its head is replaced by `idle_S`'s own head with his long hair down his back, so the head and hair are the same pixels in every frame (and the same as when he stands). His hair now reaches his mid-back and streams a little at the tips. Only the legs and the cape's hem come from Gemini's ten frames, put in step order (contact, down, passing, push, reach) and dropped onto the floor line, so a foot is on row 158 in every frame. The maroon `#221616` edge round every outline (a clean-up left-over, 10% of the old sheet) is gone. The spear and his front hand bounce a frame after his body.
  - **The front and back runs** now read as runs: his body bobs and sways a pixel toward the foot he is on, the spear bounces a frame after him, each knee comes forward while its boot lifts behind it and moves in toward the middle, and the cape swings a frame behind. From behind, the hair's tips swing, the cape's hem swings 2 px, and a boot kicked back comes up in front of the cape. Every pixel is still the idle's own, only moved.
  - All three runs are the same run: 10 frames at 13 fps, the same bob and the same step.
  - **Every pose guide Gemini still has to paint** is rendered (74 strips, all in the chunky build), and the known problems are fixed (picture below): the boss's guard is his master's stance, not the library's side-on fencing stance; his slam lands ahead and to his right, so the blade shows from behind (it was hidden in cells 5-6); the dive and light 4 from behind no longer start side-on; the clips that spin (the slash turns 230°, the backswing, the charge, the lunge) are turned back frame by frame, keeping 35° of twist; the front thrusts (light 1, the lunge, the charged thrust) aim ahead and to his left like his front idle's spear, not at the camera. New hand-keyed moves: the boss's spell, breath and wake, human Vulcan looking at his hands, Elvis's held charge and its released thrust (the library's javelin throw pointed the spear every way and stabbed the ground).
  - **Packed for Gemini:** 48 pictures in `art/guides/`, 2 or 3 rows each, every standing figure at least about 190 px tall when Gemini paints the picture 1376 px wide. Fewer, fuller pictures shrank the figures to 70-150 px, too small for faces at 80 px.
  - **`art/tools/gemini_queue.md`:** the 49 requests in order (human Vulcan's master redo, then the plan's order), each with the two pictures to attach, the exact prompt, what should come back, how to clean it and the manifest values. About five Gemini windows.
- **Why:** the art review: the side run's head jittered and was repainted every frame, its hair was too short, its feet floated and the maroon edge dominated it; the front and back runs didn't read as runs at game size. Gemini's limit is reached until 10:07, so the guides and the queue are ready for the next windows.
- **Checked:**
  - Above the hips, 100-280 pixels change between frames of the side run, all of them moves (the hair, the spear); the old sheet changed 1000-1400, all repaints. The eye is on column 136 in every frame (it moved over 5 px). The lowest pixel of every frame of all three runs is row 158. Every colour is in `palette.png`; alpha is only on or off; both eyes in every front frame.
  - The runs at 1x, 2x, 3x and 4x; the guides in every view at game size. The tests pass (58).
- **Where:** `art/elvis/run_F.png`, `run_S.png`, `run_B.png` and their recipes `stride_run_F.json`, `stride_run_S.json`, `stride_run_B.json`; Gemini's cleaned side-run frames kept as the legs' source, `art/elvis/raw/run_S_g2_frames.png`; `art/elvis/notes.md`. Tools: `art/tools/stride.py` (parts from other sheets, regions by line, brightness or colour, sway, lag, knee and boot, per-frame layering, the fringe clean-up, hole filling), `pose_strip.py` (a yaw per frame), `guide_pack.py` (cell picks, the size check), `hand_keys.json`, `guide_jobs.json` (every guide), `clips.md` (each row's guide). The guides: `art/guides/` (`packs.txt`, and `ref_*.png`, each master on magenta). The queue: `art/tools/gemini_queue.md`. Lessons: `art/tools/README.md`.
- **Lessons (what made frames flicker, what fixed it):** Gemini repaints every frame, so a head or chest painted ten times shimmers and pops even when every box is lined up. Frames built from parts that are never repainted don't: one head and one upper body moved by the bob, only the moving legs from Gemini. A run made by lifting the legs under a still body reads as sliding; the bob, a sway, the weapon a frame late, the knee and boot apart and the cape swinging make it read. Check each new sheet for a single colour hugging the outline. More in `art/tools/README.md` and at the top of the queue.
- **Claude's call:** the side run's head is `idle_S`'s, as the review suggested, held upright with the hair streaming only at its tips, rather than Gemini's head leaning into the run. It matches the idle, so turning from standing to running doesn't change his head.
- **Claude's call:** a foot is on the floor line in every frame of every run, so there is no frame with both feet off the ground; the bob gives the lift.
- **Claude's call:** in the back run a boot kicked back is drawn over the cape (it comes toward the camera), and the spear is moved whole across his back with the gaps filled from the hair and cape beside it.
- **Claude's call:** the boss's guard, the start and end of his moves, is his master's stance (the greatsword in his right hand at his side, tip down), so every sheet starts from his idle.
- **Claude's call:** the front thrusts aim about 40° to his left, like the front idle's spear, so the spear shows instead of pointing at the camera. The side and back views keep the straight thrust.
- **Claude's call:** the slam's chest turns 25° to his right for the impact, in every view, so its blade shows from behind; the fire blade still runs straight ahead in the game (about 25° apart).
- **Claude's call:** walks from the front and from behind, and the boss's front idle, are made from the idles with `stride.py` and `breathe.py` (no Gemini); only the side walks go to Gemini. The statue is the wake's first frame and human Vulcan's kneel the first frame of his look at his hands.
- **Claude's call:** human Vulcan's master redo is first in the queue, with Elvis's master as the camera and style reference and his own master picture and game-camera render for the man (his current master is seen from lower than Elvis's and the boss's). His kneel and look at his hands wait for it.
- **Left as it is:** the idles (front, side, back) and the master keep their few `#221616` edge pixels (48-115 per frame); the run's head has them cleaned, so a few edge pixels change as he starts to run. From behind, the boots are mostly under the cape, so the back run reads mostly by the bob, the cape and the hair. `light2_F`, `light4_F` and the boss's `dive_F` dip below his feet in their strikes: build them with `"below"`.
- **Not checked:** the runs in the moving game (only the sheets, the frame strips and the GIF).

![Elvis's runs after the fix: front, side, back, 4x](progress/2026-10-25_elvis_runs_fixed.gif)
![The guide problems the review found, before and after](progress/2026-10-25_guides_fixed.png)

### 25 Oct 2026: smooth on a 144 Hz screen, a camera that leads, full screen at 4x, the reviewers' polish (Task 6)
- **What:**
  - **Smooth on Danyal's screen.** His screen runs at 144 Hz, but the game moves things 60 times a second, so the fighters jumped up to 3 px every second or third frame. Elvis and Vulcan are now drawn where they are between physics steps (Godot's physics interpolation), still snapped to whole pixels: a run moves one pixel a frame, and the camera moves with him. Effects, the camera and the arena snap themselves as before and are not interpolated.
  - **The camera leads** (the spec's "slight lead"): 0.75 m ahead of Elvis at a run, or a quarter of the way toward the foe he is locked on to (at most 2 m), eased in over about half a second, in whole pixels.
  - **Full screen: F11 or Alt+Enter.** It uses exclusive full screen, because Windows' borderless full screen is 2 px short (2560x1438) and drops a 2560x1440 screen from 4x to 3x.
  - **Front attacks can draw below the feet.** A manifest key may say `"below": N`: the cell's bottom N rows are below his feet line. The sprite moves N px toward the camera, so those rows stand over the floor and his feet stay on the same screen pixel.
  - **The statue stood 0.87 m above the plinth.** On the first physics frame Elvis's body was still at the origin, inside the statue, and pushed him up. The stone no longer slides. (Seen in the C1 screenshots.)
  - **C1** frames the crown at the top and Elvis at the bottom, and the crown's glow sits on the crown, not on his face: `Vulcan.HEAD` went from 3.5 m to 4.0 m, measured on the master (the crown is rows 102-114 of the 192 px cell). The crown flies off C3 from there too.
  - **The HUD:** a spoken line has a dark plate under it, so the bronze name reads on the sand. Elvis's bars and flasks are hidden in C3.
  - **Vulcan no longer turns into the stand-in when he walks.** With no walk or run sheet, the boss played the old human-Vulcan sheet tinted red. A character with its own art now glides in its own idle until its walk exists (Review Focus 4's order: a missing animation, then idle, then the stand-in).
  - **The bot** drops its roll-away and press timers when Elvis dies or a cutscene plays.
  - **No GDScript warnings** an editor would show (checked with every default warning turned into an error): integer division in `game/crown.gd` and `core/character_sprite.gd`, the `hurt` signal (Hitbox emits it), the local `gate` in `arena/arena.gd`, and `Controls.move_vector()`, no longer static because it is called on the autoload.
  - **Tests: 58 pass, up from 55.** New: `test_art.gd::test_manifests_valid` (every `art/*/manifest.json` loads, every sheet exists, is one cell tall and at least (start + frames) cells wide), the `"below"` placement, the camera lead. New checks: the statue's height, no fight HUD in C3, a character with no run plays its own idle.
- **Why:** Task 6 of the colosseum plan, plus the reviewers' open polish.
- **Checked:**
  - **Speed:** windowed 1920x1080, `bot=fight`, 20 s, no `--fixed-fps`: **143.7 fps average**, the screen's 144 Hz (vsync), on the RX 9070. With vsync off it runs at 1530 fps. After start-up the worst frame is about 24 ms, once, as C1's lightning strikes; each floor crack takes about 8 ms to paint, one dropped frame at 144 Hz.
  - **Scaling,** on the real screen (ShotDriver's new `screen` capture): exclusive full screen at 2560x1440 is exactly 4x, every 4x4 block one colour, no bars. Borderless full screen (2560x1438) and a 2560x1440 window (Windows shrinks it to 2560x1421) are exactly 3x with black bars. No blur in any of them.
  - **Feel,** at 60 fps every 10 frames over 4 s of the bot's fight, then frame by frame around a hit: a light hit holds both fighters for 4 frames (0.07 s), Vulcan flashes white for 4 frames and the camera shakes 1 px; heavy blows hold 0.09 s and shake 3 px. Elvis is knocked back by slashes and fire; Vulcan takes none, as in Unreal. These read right, so no number changed. Movement, logged frame by frame at 144 Hz: Elvis's sprite and the camera step one pixel together on nearly every frame.
  - C1, the fight and C3 to the title card in screenshots; `bot=fx` and `bot=moves` still run.
- **Where:** `project.godot` (physics interpolation), `combat/actor.gd`, `core/character_sprite.gd` (`below`, interpolation, the fallback), `core/pixel_camera.gd`, `core/controls.gd` (`fullscreen`), `core/shot_driver.gd` (`fps=<s>`, `screen`), `fx/fx.gd`, `game/game.gd` (the lead), `game/c1_wake.gd`, `game/c3_unmasking.gd`, `game/bot.gd`, `game/crown.gd`, `boss/vulcan.gd`, `player/elvis.gd`, `ui/hud.gd`, `arena/arena.gd`, `combat/hurtbox.gd`; tests in `tests/test_art.gd`, `test_sprite.gd`, `test_flow.gd`. Hand-off: `docs/NEXT.md`.
- **For the art lane:**
  - **`"below": N`** (for example `light1_F`): draw the frame with his feet N rows higher in the cell than usual (Elvis's feet on row 158 − N instead of 158), so the spear has the bottom N rows, and add `"below": N` to that key. Keep N to what the spear needs, at most about 30: the sprite also moves N/24 m nearer the camera, so a foe standing less than that in front of him would be drawn behind him.
  - **The crown's height** (`Vulcan.HEAD`, 4.0 m) fits the standing master. A kneeling `statue_F` or `kneel_F` puts the crown lower; give its row to the code so the C1 glow and the C3 crown start there.
- **Claude's call:** physics interpolation for the two fighters only, so a 144 Hz screen is smooth. The cost is that they are drawn up to one physics step (17 ms) behind where they are.
- **Claude's call:** the lead's numbers: 0.75 m at a run, a quarter of the way to the lock target, at most 2 m, easing at 2.5 per second.
- **Claude's call:** F11 and Alt+Enter for full screen, exclusive, so a 1440p screen gets 4x. The game still opens in a 1920x1080 window.
- **Claude's call:** a dark plate under the line, not a lighter name colour, so the name and the words read on sand, blood-red floor and storm alike.
- **Claude's call:** a character with its own art never borrows the stand-in's walk. This changes Task 1's fallback, where run and walk went to the stand-in before idle.
- **Claude's call:** the hit-stop, shake and flash numbers stay as they are (0.07/0.09 s, 1/3 px, 0.08 s).
- **Left as it is:**
  - Each floor crack is painted in GDScript (about 8 ms). Painting a few in advance would remove the dropped frame.
  - The bot rolls away from Vulcan, which along the slam's fire line keeps it in the fire. Danyal plays better than that.
  - Alt+Enter also moves a spoken line on, because Enter is `confirm`.
- **For Danyal:** WSL's D: drive is still broken (since about 06:23). This was done through Windows on a clone in `C:\Users\Danye\AppData\Local\Temp\tv25d_code`.

![C1 frames the stone Vulcan with his crown glowing and Elvis at the breach; C3's last line on its dark plate, with no fight HUD](progress/2026-10-25_task6_c1_c3.png)
![A light hit, one frame at a time at 60 fps (2x): the thrust, four frames of hit-stop with Vulcan flashing white, then on](progress/2026-10-25_task6_hit_frames.png)
![Full screen at 2560x1440, a 320 px crop at 1:1: every game pixel is exactly 4x4 screen pixels](progress/2026-10-25_fullscreen_4x.png)

### 25 Oct 2026: fast mode and the earlier screenshot runs work in the game; the bot drinks; the restart tested at bad moments (Task 5 review)
- **What:**
  - **`fast` and `bot=` now take effect in the game.** ShotDriver read the command line in `_ready`, which runs after the main scene is built, so the Game's and the HUD's `fast` and the switch to the old runs were always off. Fast did nothing, and `bot=fx`, `moves`, `calm|storm|blood|clear`, `boss` and `slam|spell|breath|dive` played the normal C1 instead. The Task 5 entry's "The earlier screenshot runs still work" and "Fast mode scales every cutscene wait" were not true until now. ShotDriver reads its args in `_init`.
  - **The bot drinks.** Below 35% health it backs off and drinks red whenever Vulcan isn't winding up or striking, which is mostly right after a roll, pressing every 0.3 s. Before, it waited until it was 4 m clear, which never happened, because he outruns Elvis.
  - **The restart is tested at bad moments.** Elvis now dies mid-drink, with a line showing, three fireballs in flight, two cracks and the storm mood, so the blood-sun check proves the reset. After the restart the test also checks the HUD: no line, the boss bar on, both trails full. A new test kills him mid-swing while Vulcan winds up: both moves are dropped and the restart happens once. The full-run test now checks both C3 lines, in order.
- **Why:** the Task 5 review found fast mode and the old runs broken (high), and two medium issues: Review Focus 3 only partly tested, and the bot never drinking.
- **Checked:**
  - 55 tests pass.
  - Screenshots at 60 fps: `bot=fx` shows every effect at frame 400 again. `bot=unmask fast` is in the fight by 2 s and on the title card by 10 s.
  - A 60 s `bot=fight` run: it drank 5 times over two lives (4 → 3 → 2), each press read at once.
- **Where:** `core/shot_driver.gd`, `game/bot.gd`, `tests/test_flow.gd`.
- **For Danyal:** WSL's D: drive still gives I/O errors. This was done through Windows (`cmd.exe`, `git.exe`, Godot) on copies in `C:\Users\Danye\AppData\Local\Temp\t5fix`.
- **Claude's call:** the bot drinks whenever Vulcan isn't winding up or striking, not only from 4 m away. Otherwise the plan's "drinks red below 35%" never happens. A blow before the gulp breaks the drink off and Elvis keeps the flask, as in Unreal.

![The bot 20 s into a fight: one red drunk (3 left), its health back up](progress/2026-10-25_bot_drinks.png)
![bot=fx again: every effect at its height](progress/2026-10-25_fx_run_fixed.png)

### 25 Oct 2026: Elvis's first light swing from the side and from behind; Gemini's limit stops the batch (Task A3)
- **What:** `light1_S` and `light1_B`, 6 frames each: guard, coil, thrust, full lunge, pull back, guard. Gemini painted them over chunky pose guides, given the master, and they were cleaned to 80 px in his palette with his feet on one line. The coil (the wind-up) is held 0.08 s longer and the full lunge (the impact) 0.1 s longer; the spear hits on frames 2-3 (`"active": [2, 3]`). From the side, each frame has his eye redrawn: a dark pupil and an ice-blue catch-light. The guard that opens and closes the swing is the same frame, and so are the coil and the pull back, so those never flicker.
- **Why:** Task A3, priority 1 (Elvis's roll and light combo).
- **Stopped by Gemini's limit:** the 5-hour window was still at 84% from the batch before. Two pictures took it to 100% at 06:25 ("resets at 10:07 a.m.", weekly 15%); in a fresh chat "Create image" is greyed out. Not made yet: the roll (F, S, B), `light1_F`, and light 2-4 (F, S, B). Their guides are rendered (`art/_work/a3b/`, not committed).
- **`light1_F` failed review and is left out:** Gemini drew the front row smaller and narrower than his idle, with blank faces, plus an extra copy of the master. From the high camera the spear, thrust toward you, runs below his feet, and the sheet has to cut everything below the feet line, so the thrust doesn't read. Facing down, Elvis shows his front idle during the swing until it is remade (the game warns once).
- **Checked:** both sheets at 4x next to his idles, the faces at 10x; every colour from `palette.png`; the guard stands 80 px tall like the idles. The tests pass (54), run from Windows; the only warning is the missing `light1_F`.
- **Where:** `art/elvis/light1_S.png`, `light1_B.png`, `touchup_light1_S.json`, `manifest.json`, `notes.md` (commands and prompts), Gemini's originals `raw/light1_S_g1.jpeg` and `raw/light1_FB_g1.jpeg`. Tools: `art/tools/guide_pack.py` now stacks several strips as rows at one scale (`--aspect 16:9`); `art/sprites.py --scale-frame` lets the guard set the scale (a raised arm counted as body and shrank him to 74 px). Lessons and the limit: `art/tools/README.md`.
- **For the builders:** a front-view thrust needs the sprite to draw below its feet: the spear points at the camera, so on screen it falls below the feet line, where the floor hides a billboard. A manifest value for rows below the feet, with the sprite drawn over the floor there, would let the front attacks show their spear (Task 6).
- **For Danyal:** at about 06:23 WSL lost the D: drive (`/mnt/d` gives "Input/output error"; Windows still sees D:). This entry and the commit were made through Windows git and copies in WSL's `/tmp`. `wsl --shutdown` and reopening the terminal should bring it back.
- **Claude's call:** light 1 uses 6 of the guide's 8 poses (clip frames 46, 36, 32, 26, 36, 44).
- **Claude's call:** with the holds, the hit lands about 0.24 s into the 0.65 s swing, later than Unreal's 0.05-0.20 s; the frames set the timing, as the spec says.
- **Claude's call:** the swing's guard holds the spear level, as in the guide, not low across his body as in the idle, so the swing starts with a quick change of grip.
- **Claude's call:** two views in one Gemini picture (front and back as two rows), and the side view as 2 rows of 3, so the batch fits in about 10 pictures. The back row came out well; the front row didn't (above).

![Light 1 from the side and from behind, 4x](progress/2026-10-25_elvis_light1_SB.gif)
![Every frame of light 1, side (top) and back, 2x](progress/2026-10-25_elvis_light1_frames.png)

### 25 Oct 2026: the whole snippet plays, from the breach to "To be continued" (Task 5)
- **What:**
  - **The HUD**, in whole pixels at 640x360 in the Unreal HUD's colours: Elvis's health (red) and stamina (green) top left, his red and green flasks with their counts under them. Vulcan's name and bar are at the bottom, with a tick at the half where phase two starts. A gold trail drains behind a bar after a blow. Lines show above his bar, the speaker's name over the words. There is a fade to black, a title card, and a pause menu on Esc or Start (Resume, Restart fight, Quit). Text is drawn with no smoothing: 3 colours at 4x.
  - **The flow:** Elvis comes in at the breach. Within 12 m of the statue, **C1** plays: the camera goes to the stone Vulcan, the crown glows, the storm rolls in (2 s), the sun turns red (1.5 s), lightning bursts the stone, he rises and the flame forms his sword. Then the camera comes back to Elvis, the boss bar shows and the fight starts. At half health he roars and the line "Strike the crown." shows; the fight goes on. When Elvis dies, everything is reset behind a fade to black: both fighters, flasks, stamina, effects, cracks, the blood sun and the HUD, once. C1 never plays again.
  - **C3, the unmasking**, once a heavy blow lands on the kneeling Vulcan:
    1. In slow motion the crown flies off, spinning and trailing embers, and lands in the sand, still beating red. Elvis recoils from the blow.
    2. The lava in Vulcan's cracks cools to grey.
    3. The armour burns away texel by texel, shedding ash, and the man is under it.
    4. The greatsword tips over and lands flat with a clang.
    5. Elvis walks to the crown and splits it; its red light flees north.
    6. The storm clears to warm sunlight.
    7. Vulcan looks at his hands. "Who... am I?" "Whoever you were, you're free." Fade, "Tales of Vulcan / To be continued".
  - **The bot** (`bot=fight`) plays Elvis through the real controls. It walks up, locks on and swings, rolls away from wind-ups within 4 m, backs off to drink below 35% and uses a heavy when he kneels. `bot=unmask` also takes all his health at the start of the fight, so it goes straight on to C3.
  - **Tests:** 54 pass, up from 48. The plan's 5 flow tests are in, plus one more: at 12.5 m nothing happens. A sprite test also checks the new walk fallback (below).
- **Why:** Task 5 of the colosseum plan: the snippet is now one run, start to end.
- **Checked:** screenshots at 60 fps: C1 frame by frame; 48 s of the bot's fight (it died once at about 19 s and the restart faded through black); C3 with `bot=unmask` to the title card; the pause menu. Text, bars and the menu are crisp at 4x.
- **Where:**
  - `ui/hud.gd`, `ui/hud.tscn` (`Hud`).
  - `game/game.gd`, `game/game.tscn` (`Game`, which now holds Arena, Elvis, Vulcan, Camera and Hud as scene children).
  - `game/c1_wake.gd` (`C1Wake`), `game/c3_unmasking.gd` (`C3Unmasking`), `game/crown.gd` (`Crown`), `game/sword_prop.gd` (`SwordProp`), `game/bot.gd` (`Bot`).
  - `core/character_sprite.gd` (the walk fallback), `tests/test_flow.gd`, `tests/test_sprite.gd`.
- **For the builders:**
  - **Additions to the plan's interfaces:**
    - `Game`: the `arena`, `elvis`, `vulcan`, `camera` and `hud` vars; `scaled(seconds)` (x0.05 when fast); `wait(seconds)`, which awaits `scaled(seconds)` on a tween of the Game's, so pausing stops it and freeing the Game drops it. Also the consts `WAKE_DISTANCE`, `FAST`, `DEATH_BEAT`, `DEATH_FADE`.
    - `Hud.fast` (Game sets it) and `Hud.pixel_font()`.
    - `Crown`: `fly(from, to, seconds)`, `split()`, `signal landed`. It extends `FxEffect` for its sprite and light, but lives under the Game, so `Fx.count()` doesn't see it.
    - `SwordProp`: `drop(seconds)` (await it) and `signal fell`.
    - `bot=unmask`.
  - **A test that instances `game.tscn`** can still move Elvis before the first physics frame. That is how `test_c1_within_12m` puts him at 12.5 m and then at 11.5 m.
  - **The earlier screenshot runs still work** (`moves`, `fx`, `calm|storm|blood|clear`, `boss`, `slam|spell|breath|dive`). They skip the flow, and only they bring the training dummy.
  - **Fast mode** scales every cutscene wait, fade and walk; the characters' one-shots (`split`, `look_hands`) keep their own speed.
- **Claude's call:**
  - **C1 starts the moment the game opens.** The entrance is 9.5 m from the plinth, inside the story's 12 m, so ENTER lasts one frame. C1's first 1.5 s (the camera going to the statue, the crown still dull) stands in for "Elvis stops in the sand".
  - **Timings the plan doesn't give:**
    - C1: 1.5 s for the camera to reach the statue, a 0.6 s beat once the sword is formed, 0.8 s back to Elvis.
    - Death: 1.2 s of his death, then 0.8 s to black and 0.8 s back.
    - C3: the crown flies for 1 s of game time (about 2.1 s on screen with the slow motion), lands 2.5 m from Vulcan off to one side, on a 1.5 m arc, spinning 2.5 turns a second. The sword tips over in 0.45 s. Elvis walks at 2 m/s (Unreal's walk to the crown takes 2.7 s, `UnmaskCutscene.cpp` WalkAt to SlamAt). There are 0.5 s beats between shots and a 1.5 s fade at the end.
  - **Elvis recoils 3.6 m** while the crown flies, still facing Vulcan. Otherwise his sprite, in front, hides the kneeling man through shots 2-4.
  - **Elvis stands just north of the crown to split it, facing the camera**, as the art lane will draw `split` (front only), with the crown in front of his feet. The crown splits as his `split` one-shot ends, so its last frame should be the blow.
  - **The armour burns off the man:** human Vulcan kneels one pixel row behind the burning boss sprite, so he shows through texel by texel (STORY.md: "under it is skin"). Then the boss sprite becomes `vulcan_human`.
  - **The sword prop is three unshaded boxes** (the blade with a lava seam, the guard, the grip), not a sprite. It tips toward the camera so it lands flat, face up. Upright it is only 34 px tall: 3D heights are drawn at 21 px a metre, the sprites at about 42.
  - **The HUD:**
    - It uses Unreal's colours (`GameHUDWidget.cpp`, `BossHud.cpp`): parchment text, bronze frames, health red, ember red for him, a gold trail, stamina green.
    - The font is Godot's own, with no smoothing and light hinting, at 12 and 10 px: the other sizes and hintings spaced the letters unevenly.
    - A dark edge round each bar, or it vanishes on the blood-red floor.
    - The trail waits 0.5 s, then drains 60% of the bar a second. The fade steps in eighths.
    - The bar reads "Vulcan" (the plan's call). The title card reads "Tales of Vulcan" over "To be continued".
  - **Walk and sprint fall back to the character's own run before the stand-in.** Elvis's cutscene walk and his sprint now show him running, not the old human Vulcan sheet tinted blue. This changes Task 1's fallback order. Vulcan has no run yet, so he still uses the stand-in.
  - **"Restart fight" in the pause menu only works during the fight.** Elsewhere it just resumes.
  - **Stamina counts as out of combat** (refilling 3x as fast) until the fight starts (STORY.md).
  - **The bot** rolls 0.3 s before a blow lands, inside the roll's i-frames, and runs off for 0.8 s.
- **Left as it is:**
  - The boss sprite still has its crown on while the prop crown flies, until he burns away; a crownless `kneel` sheet would fix it.
  - Until the art lane's `kneel` and `look_hands` sheets exist, both Vulcans stand through C3.
  - The bot rarely wins (it took about 10% of his 600 hp in 48 s), so use `bot=unmask` to see C3.
  - No cutscene bars, no sounds. C2 is the plan's line, not a cutscene.

![C1, the fight and C3: the crown glows; lightning bursts the stone; the flame forms the sword; the bot fights him (trail on his bar); the crown flies as Elvis recoils; the armour burns off the man; the man, the fallen sword and the crown beside Elvis; "Who... am I?" in the sunlight](progress/2026-10-25_flow_c1_fight_c3.png)
![The HUD in the fight, and the pause menu (2x)](progress/2026-10-25_hud_pause.png)

### 25 Oct 2026: Elvis's front and back runs no longer flicker (Task A3 review fix)
- **What:** the front and back runs are rebuilt from his idle stance. Above the waist every frame is now the idle's own pixels, moved only by the bob, so nothing shimmers or pops. The run keeps the master's silver trim, ears, eyes and long locks in front, and the hair to the waist from behind. Turning from idle to run no longer looks like a change of costume. Only the legs move (lifted in turn, up to 7 px in front and 4 px from behind), plus a 0-2 px bob and a 1 px sway of the cape's hem. One foot is on the floor line in every frame. Both runs are now 10 frames at 13 fps (0.77 s a cycle), the same as the side run, so his steps keep their pace when he turns.
- **Why:** the review of the entry below. Gemini repainted the armour in every frame, so it flickered as dark speckle and the head's outline changed (high). The front run had lost the trim, ears and long locks, the back run's hair stopped at the shoulder blades, and the left steps floated 3-7 px above the floor (medium). With Gemini at 84% until 10:07, a redraw would have brought the same repainting back.
- **Checked:** every frame of both sheets: above the hem it equals the idle shifted by the bob, the lowest pixel is on row 158, light pixels 359-360 in front (the master has 360) and 664 from behind (the same as `idle_B`), both eyes in every front frame, every colour from `palette.png`, alpha only on or off. The tests pass (48). The one failure in the run is the code lane's unfinished `tests/test_flow.gd` (Task 5, `Game` not written yet).
- **Where:** `art/elvis/run_F.png`, `run_B.png`, the recipes `stride_run_F.json` and `stride_run_B.json`, `manifest.json`; the new tool `art/tools/stride.py`; `art/elvis/notes.md`, `art/tools/README.md`. Gemini's first versions stay in `art/elvis/raw/` (`run_F_g4`, `run_B_g1`).
- **Claude's call:** in front and from behind, he runs holding the spear across his body as he stands, and his upper body doesn't change. The legs, bob and cape do the running. A run with the arms and spear moving would need a Gemini strip whose legs and arms are pasted onto this body, not a full repaint. The side run stays Gemini's, which the review passed.
- **Claude's call:** the cadence of the side run (0.77 s) for all three views, rather than the 0.6 s and 0.67 s from before.
- **Not checked:** the runs in the moving game (only the sheets and GIFs).

![Elvis's idle and run, every frame, 2x](progress/2026-10-25_elvis_idle_run_sheet.png)
![Run: front, side, back, 4x](progress/2026-10-25_elvis_run_FSB.gif)

### 25 Oct 2026: Elvis runs in all three views, and his idle turns with him
- **What:**
  - Elvis's run from the front (6 frames), the side (10) and the back (8), and his idle from the side and the back. With the front idle from earlier tonight, he has an idle and a run for every direction. The game picks the view from where he faces and mirrors the side view for left.
  - Gemini painted every frame over a grey pose guide, given the master. The frames were then cleaned to 80 px in his own palette. The eyes were redrawn on every front and side frame: in front, the master's own eyes are placed on each face; from the side, a dark pupil and an ice-blue catch-light. His head stays level as he runs, and his feet stay on one line.
- **Why:** Task A3, priority 1: idle and run are what you see most.
- **Seen (what made it work):**
  - Gemini copies the guide's build. The library mannequin is a tall, thin man, so the first front run came out tall and thin, with a small head and no cape. The pose tool has a new **chunky** build (a bigger head, broad pauldrons, heavy hands and boots, shorter legs). Over it, Gemini's Elvis matches the master.
  - Ask it to "repaint image 1" (the guide) with the master as image 2. Asking for "this character in these poses" made it copy the master's standing pose 8 times.
  - It often pads the picture with extra copies of the master around the strip. `band.py` cuts the strip out.
  - The first chunky front run had no cape and a bare pole for a spear. One follow-up in the same chat added both.
  - The first side run kept one stance in all 8 frames. The second try, which asked it to trace the guide's legs, alternates them.
- **Checked:** every sheet at 4x, and the eyes at 8x. Every sheet is exactly frames x cell wide. The tests pass (48). In the game, Elvis now stands in the colosseum as himself.
- **Where:**
  - `art/elvis/`: `run_F.png`, `run_S.png`, `run_B.png`, `idle_S.png`, `idle_B.png`, `manifest.json`, the eye touch-ups `touchup_run_F.json`, `touchup_run_S.json`, `touchup_idle_S.json`, and every Gemini original in `raw/` (`run_F_g1`-`g4`, `run_S_g1`-`g2`, `run_B_g1`, `idle_SB_g1`).
  - `art/tools/pose_strip.py`: `"build": "chunky"`. The plain build is unchanged.
  - `art/sprites.py`: `--anchor head` with `--bob`, `--anchor strip`, `--pick` and `--split shapes`.
  - New tools: `art/tools/band.py` (cut one row out of a padded picture) and `art/tools/eyes.py` (the eyes, front and side).
  - How each sheet was made: `art/elvis/notes.md`. Lessons and limits: `art/tools/README.md`.
- **Gemini:** 9 images tonight: 1 before the limit, then 8 after it reset at 05:07. It is at 84% now and resets at 10:07 a.m. Each image costs about a tenth of the 5-hour window, and the weekly limit is at 15%.
- **Claude's call:** the front run uses 6 of Gemini's 8 frames. It drew frames 2 and 6 so crouched that his head dropped 13-15 px, a hop at game size.
- **Claude's call:** the head is kept level through the run, with a 1 px bob in front and none from the side or back. Gemini's own heights jumped by up to 15 px between frames. His feet now lift a few pixels in the airborne frames.
- **Claude's call:** the front run keeps the cape over his legs, as you'd see it running toward you. The legs show below the hem and alternate there. Without the cape (the try before) the legs read better but a key detail was missing.
- **Claude's call:** the side and back idles come from one Gemini picture of the stance from both sides, and breathe like the front one. From the side he holds the spear low and pointing ahead. Held across his body as in the front stance, it would cover his face from the side.
- **Claude's call:** in the back idle the spear crosses over his back, as Gemini drew it, rather than being hidden in front of him.
- **Claude's call:** frame rates: run 10 fps in front (0.6 s a cycle), 13 from the side (0.77 s), 12 from the back (0.67 s). The idle breathes once every 1.3 s.
- **Left as it is:** the armour's shading shimmers a little from frame to frame in the runs, because Gemini redraws every frame. In front, the cape hides most of the stride.

![Elvis's idle and run, every frame, 2x](progress/2026-10-25_elvis_idle_run_sheet.png)
![Run: front, side, back, 4x](progress/2026-10-25_elvis_run_FSB.gif)
![Idle: front, side, back, 4x](progress/2026-10-25_elvis_idle_FSB.gif)

### 25 Oct 2026: Vulcan's breath starts close enough to reach (Task 4 review fix)
- **What:** Vulcan now walks up to 4.8 m before he breathes fire, not 6 m. From 6 m the fire fell short: it reaches 5.45 m from him (5 m of fire from his mouth), so the third opening move missed Elvis every time.
- **Why:** the Task 4 review. The 6 m came from Unreal, where the fire is 7 m long.
- **Where:** `boss/moves.gd` (breath `range`), `tests/test_fx.gd` (`test_breath_reaches_from_its_range`: Elvis 0.5 m beyond that range is still burned; it fails at 6 m).
- **Claude's call:** 4.8 m, which leaves about 1 m for Elvis to step back during the wind-up and still be burned. The fire stays the plan's 5 m.

### 25 Oct 2026: Vulcan's sword follows the sheet's hit frames at both ends (Task 4 review fix)
- **What:** when one of Vulcan's sheets names its hit frames (`"active": [first, last]`), his sword (slash, backswing, charge) now stops hitting once the sheet passes the last one, as Elvis's does. If the first hit frame is past the sheet's end, he no longer waits in the wind-up forever: he strikes when the fixed blow would have ended. 47 tests pass (new: `test_hit_frames`, which fails on the old code).
- **Why:** the Task 4 review: the window's last frame was ignored, and a bad first frame would wedge the fight.
- **Where:** `boss/vulcan.gd` (`_tick_attack`), `tests/test_vulcan.gd`.
- **Claude's call:** the hit frames only end his own sword. The blows that are effects (slam blade, breath, spell volley, dive) keep the fixed times taken from Unreal, and so does the blow's length: the charge keeps moving to the end of its time even after the sword stops hitting.

### 25 Oct 2026: Vulcan, the boss (Task 4)
- **What:**
  - **The statue:** Vulcan kneels on the plinth as grey stone. Until the art lane's `statue` sheet exists, his master is drawn as stone. `wake_scripted()` breaks the stone off. He rises, raises his empty hand, the flame forms his sword (now he is armed), and he steps down off the plinth.
  - **The fight:** he picks a move, walks up to its range, turns to face Elvis, winds up, strikes, then stands open.
    - The opening comes first, in order: slam, spell, breath, dive.
    - Then a mix by distance. Up close (under 3 m) he slashes, and half the time a backswing follows. At middle range he slams, breathes or slashes. Far off (7 m and more) he charges, casts or dives.
    - He never makes the same big move twice running.
  - **Wind-up marks:** while he winds up, a red mark grows on the floor where the blow will land: the slam's strip, the breath's wedge, the charge's lane, and the dive's ring, which follows Elvis until he commits. The spell's circle appears behind him and its 4 fireballs come from it. Slams, dives and slashes crack the floor. A heavy blow that lands on Elvis brings hit-stop and shake.
  - **Poise:** blows wear it down from 100, and at 0 he flinches for 0.75 s. During his wind-ups and blows a hit costs half as much poise and can't break it. It refills 4 s after the last blow.
  - **Phase two at half health:** the crown flares and he roars for 2 s, untouchable. From then on he is 1.35x faster, pauses less and hits 15% harder.
  - **At 0 hp he kneels and never dies.** His attacks stop and every effect is cleared. Light hits only spark; the first heavy hit emits `crown_struck`, once.
  - **Tests:** 46 pass, up from 34. The plan's 9 are joined by 3 more: the brain plays the same fight again after `reset()`; the wake returns with him armed and on the floor; the fight opens with a slam whose fire lands once.
- **Why:** Task 4 of the colosseum plan. The cutscenes and the game flow (Task 5) drive him.
- **Where:**
  - `boss/moves.gd` (`VulcanMoves`), `boss/brain.gd` (`VulcanBrain`), `boss/vulcan.gd` and `boss/vulcan.tscn` (`Vulcan`).
  - `fx/telegraph.gd` (`FxTelegraph`, the marks), `core/sprite.gdshader` (the `stone` look), `player/elvis.gd` (burns don't stun him).
  - `game/game.gd`: the statue on the plinth. `bot=boss` wakes him at once to fight you. `bot=slam|spell|breath|dive` freezes that move late in its wind-up.
  - `tests/test_brain.gd`, `tests/test_vulcan.gd`.
- **For the builders:**
  - **Additions to the plan's interfaces:**
    - `Vulcan.Mode` and `var mode`, `var move`: the bot rolls when `mode == Vulcan.Mode.WINDUP`.
    - `var fast`: the wake's waits run at x0.05. It defaults to `ShotDriver.fast`, so Game should set it from its own `fast`.
    - The `hitbox` child.
    - `VulcanMoves.HEAVY_PUSH` (4.5 m/s); `MOVES` also has `commit`, `turn` and `push`.
    - The Fx kind `&"telegraph"`, shaped by `FxTelegraph.mark()`, and the sprite shader's `stone`.
  - **Instancing `vulcan.tscn` gives the statue.**
  - **The wake:** `wake_scripted()` emits `woke` as it starts and doesn't spawn `statue_burst`, because the plan's C1 does. Nothing can hurt him until it returns.
  - **Resetting:** `reset_fight(at)` puts `at` on the floor and off the plinth, so `reset_fight(arena.plinth())` stands him 1 m south of it. He keeps his `target` and attacks again 0.8 s later, starting with the opening. `start_fight(t)` is what starts him attacking.
  - **Hits:** he takes no knockback (Unreal's boss takes none). Elvis's hurt stun now needs `knockback > 0`, so the breath's burns hurt him without stunlocking him (Task 3's suggestion, and Unreal's rule).
- **Claude's call:**
  - **Unreal's values, not the plan's** (`BossVulcan.h`, `BossVulcan.cpp`, `BossVulcanBrain.cpp`):
    - poise 100 (plan 40);
    - flinch 0.75 s (plan 0.8);
    - backswing after a slash 50% of the time, 75% in phase two (plan 60%);
    - phase two 1.35x (PhaseTwoRate).
  - **Move timings** come from Unreal's clip times and play-rate curves, worked out as its `RealSeconds()` does. For example, the slam is a 0.82 s wind-up, a 0.16 s chop and 0.79 s open.
  - **From Unreal where the plan has no number:** pauses of 0.5-1.2 s (x0.6 in phase two), x1.15 damage in phase two, a 5.8 m/s approach, 200°/s turning, each move's range and turn rate, 4 fireballs 0.3 s apart, the dive's 2.4 m height, the dive mark following at 5.5 m/s, and the wake's beats.
  - **My own numbers:**
    - The charge, which Unreal doesn't have: a 0.6 s wind-up, then a 7 m rush at 10 m/s from up to 8 m away, 20 damage, a heavy blow.
    - The roar lasts 2 s. Unreal's phase shift lasts 3.8 s, but that includes a kneel and a rise.
    - The fireballs fly at 1.2 m, clear of the plinth's top. The breath starts 0.45 m ahead of him.
  - **Phase two speeds up his walk and run too** (the plan: "his speed"); Unreal only speeds up his clips. Approaching, he is then faster than Elvis's sprint.
  - **Up close he only slashes**, as the plan's distance bands say. Unreal still mixes in the slam and the others up close. Danyal may prefer the mix.
  - **Marks on the floor during wind-ups:** not in the plan, but Unreal has the strip, the wedge and the dive mark. Without them the stand-in's wind-up shows nothing.
  - **The wake's order is the plan's:** he rises, the flame forms the sword, then he steps down. Unreal's 24 Oct version summons the sword while he still kneels, then rises.
  - **The boss's stand-in is tinted lava red.** He has no walk or run sheet yet, so he falls back to the old human Vulcan sheet, which otherwise looks like the unmasked man.
  - **Left out:** the slam's 8 s cooldown (the brain has no clock, and "never twice running" does the job), phase two's fifth fireball, and the breath slowly turning after Elvis (8°/s).
- **Not done:** sounds.

![The four opening moves late in their wind-ups: the slam's strip, the spell's circle behind him, the breath's wedge, the dive's ring round Elvis](progress/2026-10-25_vulcan_telegraphs.png)
![The slam lands: the mark, the fire blade striking Elvis, the blade burning (2x)](progress/2026-10-25_vulcan_slam.png)
![The stone statue on the plinth (3x; his master in stone until the statue sheet exists)](progress/2026-10-25_vulcan_statue.png)

### 25 Oct 2026: the effects light the floor in hard rings (Task 3 review fix)
- **What:** the glows of the effects (lightning, dive, fire blade, breath, spell circle, fireball and the rest) used to paint smooth gradients on the floor and walls. Now they land in hard rings, each twice as bright as the one outside it, with nothing beyond the faintest ring. The sun and the moods look the same as before. The effects screenshot went from 34,499 colours to 5,010; without effects the arena has about 1,100. 34 tests pass.
- **Why:** the Task 3 review: the effects must be pixel art, and the spec's anti-goal is "any smoothing". This was listed under "Not done" in the entry below.
- **Where:** `arena/lit.gdshader` (new), used by every floor, wall and plinth material in `arena/arena.gd`; a comment in `fx/effect.gd`. The effects' lights keep their strengths and reaches.
- **Claude's call:** stepped light instead of weaker or no lights, so the fire still lights the arena. Steps are powers of two, rounded to the nearest, and the faintest is 1/16 of full. The arena's lighting is now plain Lambert with no direct shine, where Godot's default material used a slightly different diffuse model and a faint highlight; at roughness 1 the difference is too small to see in the mood screenshots.

![Before and after: the lightning, statue burst and flame summon glows on the floor (2x)](progress/2026-10-25_fx_lights_stepped.png)

### 25 Oct 2026: the colosseum and the fight's effects (Task 3)
- **What:**
  - **The arena:** `play.bat` now opens in the colosseum.
    - The floor is round, 22 m across: sand with stone paving round the plinth and along the wall.
    - The wall is tall to the north, with 28 arches and the gate in the middle. It crumbles round the sides and is low ruins to the south, where Elvis comes in through the breach.
    - Rubble fills the breach: the wall's collider is closed all the way round.
    - The plinth is a 3 m stone block, 0.75 m high, at the centre.
    - Everything is built in code, one texel per screen pixel, as in the test room.
  - **Moods:** calm (a dusty day), storm (dark grey-purple), blood (a red sun) and clear (warm gold), each blending over any number of seconds. The lightning flash is a light of its own, so it never upsets a blend.
  - **Floor cracks:** they glow white-hot, then yellow, orange and dark red, and go cold in 6 s. Each one is a new jagged pattern with a dark broken edge. At most 24 are kept.
  - **Effects:** `Fx.spawn()` makes 14 kinds:
    - fire blade, fireball, spell circle, breath and dive landing, which all hit;
    - lightning, statue burst, flame summon, crown glow and crown light;
    - ash, sparks, dust and embers.

    The fire is drawn on the floor's pixel grid: hard colour steps, redrawn 12 times a second like hand-drawn frames. Particles are small squares of solid colour.
  - **Tests:** 34 pass, up from 25. The plan's five are joined by four more:
    - a fireball hits once and bursts;
    - the breath burns 4 times in 1.2 s;
    - `clear_all()` stops every blow at once;
    - nobody walks out through the breach or through the plinth.
- **Why:** Task 3 of the colosseum plan. The boss (Task 4) and the cutscenes (Task 5) use these.
- **Where:**
  - `arena/arena.gd`, `arena/arena.tscn`, `arena/crack.gdshader`.
  - `fx/fx.gd` (the autoload `Fx`), `fx/effect.gd` (the base class `FxEffect`), `fx/ground_fire.gdshader`, and one script per kind in `fx/`.
  - `tests/test_arena.gd`, `tests/test_fx.gd`.
  - `game/game.tscn` holds the Arena; `game/game.gd` puts Elvis at the entrance. The screenshot options `bot=calm|storm|blood|clear` show a mood, and `bot=fx` freezes every effect at its height.
- **For the builders:**
  - **Additions to the plan's interfaces:**
    - `class_name FxEffect`: what `Fx.spawn()` returns. Its `hitbox` is public, so connect to `hitbox.landed` for `Feel`. It also has `life`, `age` and `end()`.
    - Rotating an effect turns its fire and its hitbox together, so the breath can follow him as he turns.
    - Arena constants: `WALL`, `TALL`, `PLINTH` (half its side), `PLINTH_H`, `MAX_CRACKS`, `COOL_TAU`.
  - **The plinth:** `plinth()` is the middle of its top, 0.75 m up, where the statue kneels. Actors float with no gravity, so Vulcan stays 0.75 m up until something puts him back at y 0. His wake should step or leap him down. `reset_fight()` should get a floor point, for example `Vector3(0, 0, Arena.PLINTH + 1.0)`.
  - **The wake distance:** `entrance()` is 9.5 m from the plinth, inside the plan's 12 m wake distance, so C1 would start the moment the game does (Task 5).
  - **The breath:** it burns every 0.3 s (the plan), but Elvis's hurt stun lasts 0.4 s, so he can't roll out of it. Unreal's burns have no push and skip his hit reaction. Suggestion for Task 4: no HURT state when `knockback == 0`.
  - **Hits:** with `info` null, a hitting kind uses the Unreal attack's damage and push, and its `source` is the effect itself, so knockback pushes away from the fire. Pass Vulcan's own `HitInfo` to change that. Fireballs also burst on the walls and the plinth.
  - **Where effects live:** under the `Fx` autoload, not in the game scene. Freeing the scene leaves them running, so call `Fx.clear_all()` on a restart.
  - **A Godot catch:** a particle burst started during a physics frame, before its settings are in, fires every particle at the same spot (one dot). `FxEffect` starts its emitters only after `_build()`, so make new particles with `_particles()`.
  - The arena stays at the world origin.
- **Claude's call:**
  - **The plan's sizes and times, not Unreal's:** fire blade 6 m (Unreal 5.4), breath a 60° cone 5 m long for 1.2 s with a burn every 0.3 s (Unreal 48°, 7 m, 2.4 s, 0.9 s), dive 3 m (Unreal 3.3), fireball 7 m/s (Unreal 7.6). The plan already fits them to this smaller arena. Unreal's numbers are in the comments.
  - **From Unreal where the plan has no number:**
    - The blade's width (1.5 m), the fireball's radius (0.3 m), the spell circle's size (2.5 m across) and the breath's height (2.3 m).
    - Each attack's damage and push.
    - The cracks' cooling (time constant 2.2 s).
    - The light colours: the red sun, the lightning, the storm's sky light, the clear's gold, the day's sun and sky.
  - **My own numbers:**
    - The blade hurts for 0.25 s and the dive landing for 0.2 s.
    - The crown glow lasts 4 s. The crown light flies at 9 m/s, rising 1.5 m/s.
    - Cold cracks stay as dark scars until there are more than 24 or `clear_cracks()` runs (Unreal fades them after 20 s).
  - **The magic circle lies on the floor.** Unreal's stands upright behind him, but from above it would hide him whenever he faces north.
  - **The plinth is square**, so its faces are pixel-exact, as in the test room.
  - **The wall:** tall arches to the north, broken down to the south so Elvis is never hidden behind it near the breach. The breach looks open, but the collider closes it.
- **Not done:** sounds, and a seating tier beyond the wall (it is plain sand out there). The lights of the effects light the floor with smooth falloffs, not hard steps.

![The four moods: calm, storm, blood and clear, with two cracks cooling](progress/2026-10-25_arena_moods.png)
![Every effect frozen at its height: lightning, statue burst, flame summon, crown glow and light, fire blade, breath, spell circle, fireball, dive landing, sparks, embers, dust, and ash off the dummy (2x)](progress/2026-10-25_arena_effects.png)
![The south breach and its rubble, where Elvis comes in (2x)](progress/2026-10-25_arena_entrance.png)

### 25 Oct 2026: a one-shot animation always ends (second Task 2 review fix)
- **What:** `Actor.play_once()` used to wait forever unless the caller had set `scripted` first. The actor's own `_tick()` played idle or run every frame, which replaced the one-shot before it could end. Now `play_once()` holds `_tick()` off until its animation ends, and it leaves `scripted` as the caller had it. A new test plays `walk` on the training dummy without `scripted`. It failed before the fix (still waiting after 4 s) and passes now. 25 tests pass.
- **Why:** the second review of Task 2 found it. It only worked for Elvis because every move he lacks art for falls back to the same idle_F. Once his split sheet exists, cutscene C3 (which only turns his input off) would hang, and so would the boss's `wake_scripted()` in C1 (Task 4).
- **Where:** `combat/actor.gd` (`play_once`, `_physics_process`), `tests/test_combat.gd`.
- **For the builders:** don't call `play_once()` during a `move_to()`; await `arrived` first, because the walk plays "walk" every frame. A hit that plays the hurt animation also ends a `play_once()` early.
- **Claude's call:** a private counter instead of setting `scripted` for the call. That way a cutscene that sets `scripted` while a one-shot plays doesn't get it switched back off when the one-shot ends.

### 25 Oct 2026: Elvis's swings always land before the next one starts (Task 2 review fixes)
- **What:**
  - **The fix:** mashing light used to cut each swing off at its cancel point (0.35 s). On a sheet whose hit frames come later, the swing was gone before it could hit. Now a press made during a swing waits until the swing's hit is over, as well as the cancel point. The roll still cuts in at any moment. Nothing changes for the stand-in or for any sheet whose hit frames end before the cancel point.
  - **Tests:** 24 pass, up from 19. Five tests are new and one is stronger:
    - Mashing the roll.
    - A roll, a light and a heavy are each refused at 0 stamina.
    - One press is held, and a newer press replaces it.
    - A press is dropped after 0.45 s.
    - Mashing on a fake sheet with late hit frames (hit frames 4-5 of 6, a manifest put into `CharacterSprite`'s cache, with no `art/` file touched). It failed before the fix (1 hit from 4 swings) and passes now.
    - The light mash now starts at 45 stamina, so it really reaches 0.
- **Why:** the independent review of Task 2 found both problems. Task A3 adds holds before the strike, so the real attack sheets would have hit this.
- **Where:** `player/elvis.gd` (`_accepts`) and `tests/test_elvis.gd`.
- **Claude's call:**
  - **Fix, not a warning:** the review offered a warning as the lighter option. I fixed it instead, because a swing that never lands is a bug the player would feel.
  - **The trade-off:** a press made early in a swing whose hit frames run to the end of the sheet can expire (0.45 s) before the swing ends. A player who is mashing presses again, so the next swing still comes.

### 25 Oct 2026: Elvis fights: moves, hits, health, stamina, flasks
- **What:** Elvis is playable on the placeholder floor, with a training dummy (the old Vulcan sheet) to hit.
  - **Moves:** he runs and sprints with smooth starts, stops and turns. He rolls 3.5 m, untouchable from 0.05 to 0.40 s into it, and the roll can cut short any attack.
  - **Attacks:** a 4-hit light combo, plus a heavy: tapped it is a 2 m lunge, held it is a charge, and letting go thrusts, up to twice as hard after 1.2 s.
  - **Flasks and lock-on:** 4 red (heal 40%) and 2 green (refill stamina). A hit before the gulp breaks the drink off, and he keeps the flask. Lock-on picks the nearest enemy within 15 m.
  - **Rules:** one press is remembered while he is busy, and a newer press replaces it. At 0 stamina, rolls and attacks are refused.
  - **When a hit lands:** hit-stop, screen shake, a white flash on the target and knockback.
- **Why:** Task 2 of the colosseum plan. The boss, the arena and the cutscenes are built on these pieces.
- **Where:**
  - `combat/`: `hit_info.gd`, `hitbox.gd`, `hurtbox.gd`, `health.gd`, `stamina.gd`, `actor.gd`, `dummy.tscn`.
  - `player/`: `elvis.gd`, `elvis.tscn`, `flasks.gd`.
  - `core/character_sprite.gd`: adds `speed_scale`, `play_timed()` and `active_window()`.
  - `game/game.gd`: Elvis and the dummy. `bot=moves` plays a combo, a charged thrust and a roll for screenshots.
  - `tests/test_combat.gd`, `tests/test_elvis.gd`, `tests/test_sprite.gd`: 19 tests pass.
- **For the builders:**
  - **Additions to the plan's interfaces:**
    - `Actor.take_hit(info)` is what a Hurtbox's `hurt` calls (damage, flash, knockback). Override it for a reaction and call `super`.
    - `Actor._tick(delta)` is where a subclass acts. It doesn't run while `scripted` or while walking a `move_to`.
    - `Actor._slide(v, delta)` moves the actor with its knockback added.
    - `Elvis.stamina`, `.flasks` and `.hitbox` are the child nodes. `Hurtbox.LAYER` is physics layer 5.
    - `combat/dummy.tscn` is a team-boss Actor.
  - **Sprites:**
    - `play_timed(anim, facing, seconds)` ignores `speed_scale`: the seconds are the caller's, with any speed-up already in them. With 0 seconds the art keeps its own speed.
    - `Actor.play_once()` uses `play_timed(..., 0)`, so it ends even when the art falls back to a looping idle.
  - **Hits:**
    - An attack's hitbox follows the sheet's `"active": [first, last]` frames when the sheet has them, and fixed times otherwise.
    - `HitInfo.poise` already doubles a heavy blow (Unreal's HeavyPoiseScale), so the boss shouldn't double it again.
  - **Movement:** actors use Godot's floating motion (no gravity), so they need no floor collider.
- **Claude's call:** every number comes from the Unreal C++ wherever it has one, with the source in a comment. This differs from the plan's table in these places:
  - **Speed:** run 5.0 m/s (plan 4.5) and sprint 7.5 m/s (plan 7.0).
  - **Roll:** 0.6 s long (plan 0.55).
  - **Stamina:** 150 with a 1 s regen delay (plan 100 and 0.6 s). The `Stamina` class keeps the plan's defaults and Elvis sets Unreal's.
  - **Costs:** light 15 (plan 12). Lunge and charge 30, the charge's paid once as it begins (plan 25 and 35).
  - **Damage:** light 8/8/10/14 and lunge 30 (plan 8 and 18). The thrust is 30, rising to 60 after a full charge.
  - **Heavy:** held 0.2 s it becomes a charge (plan 0.35 s).
  - **Press buffer:** 0.45 s (plan and review focus 0.3 s). This is Unreal's AttackInputWindow: a swing's cancel point (0.35 s) plus its hit-stop must fit inside it, or a press made as a swing starts is lost. It still holds only one press.
  - The accel test checks against `RUN_SPEED` rather than the literal 4.5.
- **Claude's call:** kept the plan's own values where Unreal has nothing comparable:
  - Acceleration 30 and deceleration 40 m/s². Unreal's braking adds ground friction, which a single number can't copy.
  - The lunge's 2 m step. Unreal's lunge clip travels only 0.29 m.
  - The 0.05-0.40 s i-frames. Unreal makes the whole roll untouchable.
  - Hit-stop 0.07 s on a light hit, 0.09 s on a heavy one.
- **Claude's call:**
  - The roll comes on releasing the button, because a hold of 0.25 s sprints.
  - Being hit stuns him for 0.4 s.
  - Knockback is Unreal's push speed braked to a stop (0.04 m for most light hits, 0.9 m for heavy ones).
  - The roll cuts any attack short, as Danyal chose for the Unreal game on 23 Oct.
- **Not done:** the camera's lead, Unreal's longer regen wait after the bar is emptied, and a cooldown between rolls.

![Elvis's charged thrust lands on the training dummy: the white flash](progress/2026-10-25_elvis_thrust.png)
![The bot's sequence: lock on, four light hits, a charged thrust, a roll (Elvis has only his front idle so far, so every move shows it)](progress/2026-10-25_elvis_combat.gif)

### 25 Oct 2026: the game shows the real characters; Elvis's idle (front)
- **What:**
  - Elvis, the possessed Vulcan and human Vulcan each have a `manifest.json` now, with their master sprite as a still `idle_F`, so the game draws the real characters instead of the stand-in. Each one stays until a real idle replaces it.
  - Elvis's front idle is a breathing loop on his master: everything above his hips sinks 1 px and rises again, about 1.3 s a breath. Nothing else moves, so his eyes, hair and armour stay exactly as drawn and nothing flickers.
  - Gemini's plan limit was reached on the batch's first image (02:24): "Current usage 100% used, resets at 5:07 a.m.". The rest of the batch (idle side and back, run front, side and back) waits for the reset.
- **Why:** Task A3 of the colosseum plan, priority 1 (Elvis's idle and run).
- **Where:**
  - `art/<c>/manifest.json`, `art/<c>/idle_F.png` for all three; Elvis's `raw/idle_F_g1.jpeg` (Gemini's try, not used).
  - `art/sprites.py`: `--anchor body` places each frame by the body, not the box, so a stride or a spear never makes him jump; strip frames are cut at the emptiest column between them.
  - New tools in `art/tools/`: `guide_pack.py` (a compact pose guide for Gemini), `breathe.py` (the breathing idle), `gif.py` (the GIFs here). `README.md` has the limit and the lessons.
- **Seen:** given the master and a 4-frame idle guide, Gemini drew four near-identical copies that filled the whole picture: taller and thinner than the master, with a smaller head, and touching each other. At 80 px his face shrank and the eyes faded. The master itself already is the idle pose, so the idle is built on it instead.
- **Claude's call:** the idle stance is the master's (spear held low across his body), not the library's relaxed idle with one knee bent.
- **Claude's call:** the idle breathes by moving the master's own pixels (1 px), not by Gemini redrawing each frame: four redrawn frames differ in hundreds of small pixels and shimmer at game size.
- **Claude's call:** the cell is shared by all of a character's sheets, so it is set generously now: Elvis 240x160 (room for the spear thrusts and overhead cuts), the boss 288x192, human Vulcan 128x96. The boss's and human Vulcan's can still change freely while they only have the 1-frame idle.

![Elvis's front idle at 4x: breathing on the master](progress/2026-10-25_elvis_idle_F.gif)

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
