# Colosseum Snippet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable Godot 2.5D snippet: Elvis fights the possessed Vulcan in the colosseum, knocks the crown off, and Vulcan turns human (story shots 1-7), with pixel-art sprites made in Gemini.

**Architecture:** Two lanes that never edit the same files.
- **Code lane** (`core/ combat/ player/ boss/ arena/ fx/ ui/ game/ tests/`): built sequentially. Everything is playable with stand-in sprites.
- **Art lane** (`art/`): makes sprite sheets plus a `manifest.json` per character. The code picks up whatever sheets exist and falls back to stand-ins for the rest.

**Tech Stack:** Godot 4.7.2 Standard (GDScript, typed), Blender 5.2 (pose guides), Python via `uv run --with pillow --with numpy --with scipy` (sprite clean-up), Gemini in the Playwright browser (frames).

**Spec:** `docs/superpowers/specs/2026-10-24-colosseum-snippet-design.md`. Read it first, including "Claude's calls overnight". Story: `D:\TalesOfVulkan\TalesOfVulkan\docs\STORY.md` (WSL `/mnt/d/TalesOfVulkan/TalesOfVulkan/docs/STORY.md`).

## Global Constraints

- **Project:** `D:\TalesOfVulkan\TalesOfVulcan25D` (WSL `/mnt/d/TalesOfVulkan/TalesOfVulcan25D`).
- **Godot:** `$GODOT` = `/mnt/d/GODOT/Godot_v4.7.2-stable_win64_console.exe`, always with `--path 'D:\TalesOfVulkan\TalesOfVulcan25D'`.
- **GDScript is fully typed.** A `:=` from a Variant (loop variables, Dictionary or Array reads) is a parse error, so write `var x: int = ...`.
- **Scenes:** text `.tscn`, or built in code. Never binary `.scn` or `.res`.
- **Pixel look:** 640x360 viewport, `stretch/mode="viewport"`, `scale_mode="integer"`, `default_texture_filter=0`, MSAA 0, no TAA or FXAA. `Pixel.PX = 32.0` px per metre, `Pixel.PITCH_DEG = 48.59`, `Pixel.STEP = 0.75`. Everything is drawn with nearest-neighbour.
- **Characters are 80 px tall.** Both eyes must be visible.
- **Sprite PNGs** load with `Image.load_from_file` + `ImageTexture.create_from_image`, keeping the test room's `# shortcut:` comment, so import can't compress them.
- **Tests:** `$GODOT --headless --path 'D:\TalesOfVulkan\TalesOfVulcan25D' res://tests/run_tests.tscn > tests.log 2>&1; echo $?`. Passing means exit `0` and a last line of `TESTS PASSED <n> FAILED 0`. Read only the FAIL lines.
- **Screenshots:** `$GODOT --path 'D:\TalesOfVulkan\TalesOfVulcan25D' [scene] -- shot=D:/TalesOfVulkan/TalesOfVulcan25D/shots frames=30,90 [bot=fight] [fast]`. A window opens for a few seconds. Agents can view the PNGs.
- **Git:** `git.exe` in the project folder, local only. **Never push.** Every commit message ends with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01JhboGJqpKoaj5sR4Jcq8sX
  ```
  If `.git/index.lock` exists, wait 5 s and retry, because both lanes commit. Commit only your own lane's files.
- **The Unreal repo** `/mnt/d/TalesOfVulkan/TalesOfVulkan` is read-only from this project. Blender only ever opens copies, made in `art/_work/`, which is gitignored.
- **Never give Gemini** a Paragon clip or any Fab asset tagged NoAI (the Unreal repo's `SourceArt/Fab/LICENCES.md`). The CC0 motion is `C:\Users\Danye\Downloads\All animations.glb` (WSL `/mnt/c/Users/Danye/Downloads/All animations.glb`).
- **Never read binary files as text.** Logs go to files.
- **Every task that lands** gets an entry at the top of `docs/PROGRESS.md`'s log (date, what, why, where, picture or GIF if visible). Any guess made without Danyal is listed in that entry as "**Claude's call:** ...".

## Review Focus

1. **Keyboard and mouse only, or a controller:** everything works with no controller plugged in. With one, a stick resting at 0.15 doesn't move Elvis (deadzone 0.2). Tested in Task 2.
2. **Button mashing:** repeated attack or roll presses never wedge a state. Stamina never goes below 0. At 0 stamina, rolls and attacks are refused. At most one input is buffered (0.3 s). Tested in Task 2.
3. **Dying at a bad moment** (mid-move, mid-line, while drinking, with fireballs in flight): the restart resets everything (both actors, flasks, stamina, effects, cracks, mood, HUD) exactly once. Once Vulcan kneels he can no longer hurt Elvis. Tested in Task 5.
4. **Missing art:** an animation, direction or whole character with no sheet falls back (S→F, B→F, missing anim→idle→stand-in), warns once and never crashes. Tested in Task 1.
5. **Window size:** full screen at any size keeps a whole-number scale with black bars and no blur. Task 1 tests the project settings, Task 6 takes a screenshot at 2560x1440.

---

## Code lane

### Task 1: Foundation

**Files:**
- Create:
  - `core/pixel.gd`, `core/pixel_camera.gd`
  - `core/feel.gd` (autoload `Feel`), `core/controls.gd` (autoload `Controls`)
  - `core/character_sprite.gd`, `core/sprite.gdshader`
  - `core/shot_driver.gd` (autoload `ShotDriver`)
  - `art/standin/manifest.json`, `art/standin/sheet.png` (copied from `art/vulcan_sheet.png`: 13 cells of 46x81, idle = cell 0, walk = cells 1-12)
  - `tests/run_tests.tscn`, `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_pixel.gd`, `tests/test_sprite.gd`
  - `game/game.tscn`, `game/game.gd` (placeholder: floor, stand-in Elvis walking, camera)
- Modify: `project.godot` (main scene `res://game/game.tscn`, the autoloads, the settings above), `.gitignore` (add `art/_work/`, `tests.log`)

**Interfaces (Produces):**
- **`class_name Pixel`** (static):
  - `const PX := 32.0`, `const PITCH_DEG := 48.59`, `const STEP := 0.75`
  - `static func snap(p: Vector3) -> Vector3`: x to 1/PX, z to 1/(PX·sin pitch), y kept, as in `tools/test_room/main.gd`
  - `static func sprite_scale_y() -> float`: 1/cos(pitch)
  - `static func ground(v: Vector2) -> Vector3`: x→x, y→z
- **`class_name PixelCamera extends Camera3D`:** orthographic, size 360/PX, pitch −PITCH_DEG, 30 m back.
  - `func follow(t: Node3D) -> void`; `var lead := Vector3.ZERO`
  - `func focus(at: Vector3, seconds: float) -> void` + `signal focus_done`
  - `func shake(px: float, seconds: float) -> void`: offsets in whole pixels
  - Position is snapped every frame.
- **Autoload `Feel`:**
  - `func hit_stop(seconds: float) -> void`: time_scale 0.05 for real seconds, then restored
  - `func shake(px: float, seconds: float) -> void`: the current PixelCamera
  - `func slow_motion(scale: float, seconds: float) -> void`
- **Autoload `Controls`:** registers its actions in `_ready` with `InputMap.add_action`.
  - Bindings:
    - `move_left/right/up/down`: WASD, arrows, left stick
    - `attack_light`: LMB, J, joy button 2
    - `attack_heavy`: RMB, K, joy 3
    - `roll`: Space, joy 1 (tap rolls, held 0.25 s sprints)
    - `lock_on`: MMB, Q, joy 8
    - `flask_red`: 1, d-pad up 11
    - `flask_green`: 2, d-pad down 12
    - `pause`: Esc, joy 6
    - `confirm`: Enter, E, joy 0
  - `static func move_vector() -> Vector2`: deadzone 0.2, length ≤ 1.
- **`class_name CharacterSprite extends Node3D`:**
  - `func load_character(folder: String) -> void`: reads `res://art/<folder>/manifest.json`; a missing file means the `standin` character, tinted by `func set_tint(c: Color)`
  - `func play(anim: String, facing: Vector2) -> void`: no restart when the same key is already playing
  - `func restart(anim: String, facing: Vector2) -> void`
  - `var character: String`, `var current_key: String` (for example `"run_S"`), `var frame: int`
  - `signal frame_changed(key: String, frame: int)`; `signal finished(key: String)` (non-looping only)
  - `func flash(seconds: float) -> void`
  - `func set_param(name: StringName, value: float) -> void`: shader uniforms `burn` (dissolve to ash) and `cool` (lava orange to grey), 0..1
  - `static func dir_suffix(facing: Vector2) -> String`: `"F"` when y > 0 dominates (toward camera), `"B"` when y < 0 dominates, `"S"` when |x| dominates
  - `static func flipped(facing: Vector2) -> bool`: true when the suffix is S and x < 0 (side sheets face right)
  - The child sprite is a fixed-Y billboard with `pixel_size` 1/PX and scale.y `Pixel.sprite_scale_y()`. It is `top_level`, placed each frame at `Pixel.snap(owner position)`, feet at the origin, alpha-cut discard.
  - Fallback order: `anim_dir` → `anim_F` → (`run`/`walk`/`sprint` → stand-in `walk_F`) → `idle_F` → stand-in `idle_F`. Warn once per missing key.
- **Manifest format:**
  ```json
  {"cell": [w, h], "anims": {"idle_F": {"file": "idle_F.png", "frames": 6, "fps": 8, "loop": true, "holds": {"3": 0.1}}}}
  ```
  Frames run left to right in one row; `holds` adds seconds to a frame index.
- **Autoload `ShotDriver`:** reads the user args `shot=<dir>`, `frames=a,b,c`, `fast`, `bot=<name>`. It saves `shot_<frame>.png` at those frames and quits after the last one. Exposes `var fast: bool`, `var bot: String`.
- **`class_name TestCase extends Node`:**
  - `func check(cond: bool, what: String) -> void`
  - `func near(a: float, b: float, eps: float, what: String) -> void`
  - The runner loads every `res://tests/test_*.gd`, adds it as a child and awaits each `test_*` method. It prints `PASS file::test` or `FAIL file::test: what`, then `TESTS PASSED n FAILED m`, and quits with `m`.

- [ ] **Step 1:** Write `tests/test_pixel.gd`:
  - `test_snap_x`: `snap(Vector3(0.017,0,0)).x == 0.03125`
  - `test_snap_z`: `near(snap(Vector3(0,0,0.03)).z, 1.0/24.0, 1e-6)`
  - `test_scale_y`: `near(sprite_scale_y(), 1.5126, 0.001)`
  - `test_project_settings`: viewport 640x360, stretch mode `"viewport"`, scale mode `"integer"`, `default_texture_filter == 0`

  Write `tests/test_sprite.gd`:
  - `test_dir_suffix`: (0,1)→F, (0,-1)→B, (1,0)→S not flipped, (-1,0)→S flipped, (0.6,0.8)→F
  - `test_missing_character_falls_back`: `load_character("nope")`, `play("roll", Vector2.DOWN)` → `current_key != ""`, a texture is set, no error
  - `test_missing_direction_falls_back`: the stand-in only has F, so `play("idle", Vector2.UP)` gives `current_key == "idle_F"`
- [ ] **Step 2:** Run the tests: expect a non-zero exit, because the classes are missing.
- [ ] **Step 3:** Implement the files above. Port the snapping, billboard and pixel maths from `tools/test_room/main.gd`. `game/game.tscn` shows a flat stone floor and a stand-in Elvis (blue tint) walking with `Controls.move_vector()`, followed by the PixelCamera.
- [ ] **Step 4:** Run the tests, expecting `FAILED 0`. Take a screenshot with `frames=30` and check it's crisp, with the stand-in on screen.
- [ ] **Step 5:** Commit: "Foundation: pixel camera, sprites with fallback, controls, test runner". Then add the PROGRESS entry.

### Task 2: Combat core and Elvis

**Files:**
- Create:
  - `combat/hit_info.gd`, `combat/hitbox.gd`, `combat/hurtbox.gd`, `combat/health.gd`, `combat/stamina.gd`, `combat/actor.gd`
  - `player/flasks.gd`, `player/elvis.gd`, `player/elvis.tscn`
  - `tests/test_combat.gd`, `tests/test_elvis.gd`
- Modify: `game/game.gd` (spawns `elvis.tscn`)

**Interfaces:**
- **Consumes:** `Pixel`, `PixelCamera`, `Feel`, `Controls`, `CharacterSprite` (Task 1).
- **Produces:**
  - **`class_name HitInfo extends RefCounted`:** `damage: float`, `poise: float`, `knockback: float` (m), `heavy: bool`, `source: Node3D`, `at: Vector3`
  - **`class_name Hitbox extends Area3D`:**
    - `const TEAM_PLAYER := 0`, `const TEAM_BOSS := 1`, `@export var team: int`
    - `func activate(info: HitInfo, seconds: float) -> void`: each Hurtbox is hit at most once per activation
    - `func deactivate() -> void`, `func is_active() -> bool`
    - `signal landed(target: Hurtbox, info: HitInfo)`
  - **`class_name Hurtbox extends Area3D`:** `@export var team: int`, `var invulnerable := false`, `signal hurt(info: HitInfo)`
  - **`class_name Health extends Node`:**
    - `@export var max_hp := 100.0`, `var hp: float`
    - `signal changed(hp: float, max_hp: float)`; `signal died` (once)
    - `func take(amount: float)`, `func heal(amount: float)`, `func reset()`, `func ratio() -> float`
  - **`class_name Stamina extends Node`:**
    - `@export var max_value := 100.0`, `@export var regen_per_s := 30.0`, `@export var regen_delay := 0.6`
    - `var in_combat := true`: regen ×3 when false
    - `var value: float`
    - `func spend(cost: float) -> bool`: false when value ≤ 0, otherwise subtract and clamp at 0
    - `func refill()`; `signal changed(value: float, max_value: float)`
  - **`class_name Flasks extends Node`:**
    - `var red := 4`, `var green := 2`, `const RED_HEAL := 0.4`
    - `func drink_red(h: Health) -> bool`, `func drink_green(s: Stamina) -> bool`, `func refill()`
    - `signal changed(red: int, green: int)`
  - **`class_name Actor extends CharacterBody3D`:**
    - `var sprite: CharacterSprite`, `var facing := Vector2.DOWN`, `var scripted := false`
    - `func move_to(at: Vector3, speed: float) -> void` + `signal arrived`
    - `func play_once(anim: String) -> void`: await `sprite.finished`
    - Children named `Health`, `Hurtbox`, `Sprite`.
  - **`class_name Elvis extends Actor`:**
    - `enum State {MOVE, ROLL, LIGHT, LUNGE, CHARGE, THRUST, DRINK, HURT, DEAD}`, `var state: State`, `var combo_index: int`
    - `var lock_target: Node3D`, `var input_enabled := true`
    - Children `Stamina`, `Flasks`, `Hitbox`.
    - `func reset_to(at: Vector3) -> void`: full health, stamina and flasks, state MOVE, facing up
  - **Elvis constants** (use the Unreal value instead wherever the Unreal repo's `Source/TalesOfVulkan/TalesOfVulkanCharacter.cpp`, `CombatTest*.{cpp,inl}`, `StaminaComponent.*` or `FlaskComponent.*` has one, converting cm to m and noting the source in a comment):

    | Constant | Value |
    | --- | --- |
    | `RUN_SPEED` | 4.5 |
    | `SPRINT_SPEED` | 7.0 |
    | `ACCEL` | 30.0 |
    | `DECEL` | 40.0 |
    | `ROLL_DISTANCE` | 3.5 |
    | `ROLL_TIME` | 0.55 |
    | i-frames | 0.05-0.40 s |
    | Costs | roll 20, light 12, lunge 25, thrust 35, sprint 15/s |
    | `COMBO_MAX` | 4 |
    | `BUFFER` | 0.3 s |
    | Heavy | tap < 0.35 s = lunge 2 m; hold ≥ 0.35 s = charge, release = thrust |
    | Damage | light 8, lunge 18, thrust 30 |

    Lunge and thrust set `heavy = true`.
  - **When a hit lands:**
    - `Feel.hit_stop(0.07)` light, 0.09 heavy
    - `Feel.shake(1, 0.1)` light, `(3, 0.2)` heavy
    - the target's `sprite.flash(0.08)` and knockback
  - **Lock-on:** `lock_on` toggles the nearest Actor on the other team within 15 m. While locked, Elvis faces the target except when rolling or sprinting.

- [ ] **Step 1:** Write the failing tests.

  `tests/test_combat.gd`:
  - `test_health_clamps_and_dies_once`: take 150 of 100 → hp 0, `died` once; a second take doesn't emit again
  - `test_stamina_refuses_at_zero`: `spend(100)` true, value 0; `spend(1)` false
  - `test_stamina_regen_triple_out_of_combat`: 1.6 s simulated: in combat +30, out of combat clamped to +90
  - `test_flasks`: `drink_red` heals 40 of 100, red is 3; at 0, false
  - `test_hitbox_hits_once_per_activation`: overlapping for 3 physics frames → `landed` once

  `tests/test_elvis.gd` (a flat StaticBody floor, real physics frames):
  - `test_roll_distance`: `near(displacement, 3.5, 0.15)`
  - `test_roll_iframes`: invulnerable at 0.2 s, not at 0.5 s
  - `test_accel_smooth`: speed < RUN_SPEED after 1 frame of input; `near(speed, 4.5, 0.1)` after 0.5 s
  - `test_mash_attack`: 20 `attack_light` presses within 1 s via `Input.action_press`/`action_release` → `combo_index ≤ 4`, stamina ≥ 0, back to MOVE ≤ 2.5 s after the last press
  - `test_deadzone`: joy axis 0.15 → `Controls.move_vector() == Vector2.ZERO`
- [ ] **Step 2:** Run them and confirm they fail.
- [ ] **Step 3:** Implement. Elvis plays `idle`, `run`, `sprint`, `roll`, `light1`-`light4`, `lunge`, `charge`, `thrust`, `drink`, `hurt` and `death` on `CharacterSprite`, which falls back to the stand-in where needed. Hitbox timing follows the animation frame when a sheet exists, otherwise fixed times.
- [ ] **Step 4:** Run the tests, expecting `FAILED 0`. Take screenshots of a roll and an attack.
- [ ] **Step 5:** Commit and add the PROGRESS entry.

### Task 3: The arena and effects

**Files:**
- Create:
  - `arena/arena.gd`, `arena/arena.tscn`
  - `fx/fx.gd` (autoload `Fx`) and one script per effect kind under `fx/`
  - `tests/test_arena.gd`, `tests/test_fx.gd`
- Modify: `game/game.tscn` (uses the Arena)

**Interfaces:**
- **Consumes:** Task 1 and Task 2 (`Hitbox`, `HitInfo`).
- **Produces:**
  - **`class_name Arena extends Node3D`:** `const RADIUS := 11.0`
    - `func entrance() -> Vector3`: the south breach, inside the floor
    - `func plinth() -> Vector3`: the centre
    - `func gate() -> Vector3`: north
    - `func crack(at: Vector3, radius: float) -> void`: glowing floor cracks that cool over 6 s; at most 24 kept
    - `func clear_cracks() -> void`, `func crack_count() -> int`
    - `func set_mood(mood: StringName, seconds: float) -> void`: `&"calm"` dusty day, `&"storm"` dark grey-purple, `&"blood"` red sun and red ambient, `&"clear"` warm sunlight
    - `var sun: DirectionalLight3D`, `func lightning_flash() -> void`
    - Walls are arches seen from above (front faces drawn like the test room's), with a round collision wall and a plinth collider.
  - **Autoload `Fx`:**
    - `func spawn(kind: StringName, at: Vector3, dir := Vector3.ZERO, team := Hitbox.TEAM_BOSS, info: HitInfo = null) -> Node3D`
    - `func clear_all() -> void`
    - `func count() -> int`
    - **Kinds:**
      - `&"fire_blade"`: a line of fire 6 m along `dir`, with a hitbox
      - `&"fireball"`: 7 m/s along `dir`, with a hitbox, bursts on contact or after 3 s
      - `&"spell_circle"`: 1.6 s
      - `&"breath"`: a 60° cone, 5 m, 1.2 s, its hitbox ticking every 0.3 s
      - `&"dive_impact"`: a 3 m ring, with a hitbox
      - `&"lightning"`
      - `&"statue_burst"`
      - `&"flame_summon"`
      - `&"crown_glow"`
      - `&"crown_light"`: a red streak flying along `dir` for 2 s
      - `&"ash"`, `&"sparks"`, `&"dust"`, `&"embers"`
    - **Style:** pixel art: unshaded, nearest-filtered, posterized textures made in code, palette matching the room.

- [ ] **Step 1:** Write the failing tests.

  `tests/test_arena.gd`:
  - `test_entrance_inside`: `RADIUS-3 < entrance distance from centre < RADIUS`
  - `test_cracks_capped`: 30 `crack()` calls → `crack_count() ≤ 24`
  - `test_mood_blood_is_red`: `set_mood(&"blood", 0)` → `sun.light_color.r > 1.5 * sun.light_color.g`

  `tests/test_fx.gd`:
  - `test_spawn_every_kind`: each kind returns non-null; after `clear_all()`, `count() == 0`
  - `test_fireball_speed`: `near(moved, 3.5, 0.3)` after 0.5 s
- [ ] **Step 2:** Run them and confirm they fail.
- [ ] **Step 3:** Implement. Start from `tools/test_room/main.gd`'s room building, textures and lights.
- [ ] **Step 4:** Run the tests, expecting `FAILED 0`. Take 4 screenshots, one per mood, plus one showing every effect.
- [ ] **Step 5:** Commit and add the PROGRESS entry.

### Task 4: Vulcan, the boss

**Files:**
- Create: `boss/moves.gd`, `boss/brain.gd`, `boss/vulcan.gd`, `boss/vulcan.tscn`, `tests/test_brain.gd`, `tests/test_vulcan.gd`
- Modify: `game/game.gd` (spawns Vulcan on the plinth as a statue)

**Interfaces:**
- **Consumes:** Tasks 1-3 (`Actor`, `Health`, `Hitbox`, `Hurtbox`, `HitInfo`, `Arena.crack`, `Fx.spawn`, `Feel`).
- **Produces:**
  - **`class_name VulcanMoves`:**
    - `const MOVES: Dictionary`: StringName → `{windup, active, recover, damage, poise, range, anim}` for `&"slam"`, `&"spell"`, `&"breath"`, `&"dive"`, `&"charge"`, `&"slash"`, `&"backswing"`.
    - Values come from the Unreal `BossVulcan.h` / `BossVulcanMoves.cpp` / `BossVulcanBrain.cpp` (cm→m). Each value gets a comment naming its source.
  - **`class_name VulcanBrain extends RefCounted`:**
    - `func _init(seed_: int = 1)`: seeded RandomNumberGenerator
    - `const OPENING: Array[StringName] = [&"slam", &"spell", &"breath", &"dive"]`
    - `var phase := 1`
    - `func next_move(dist: float) -> StringName`: the opening first, in order
    - `func reset()`
    - `func speed_scale() -> float`: 1.0 in phase 1, Unreal's phase-two value (or 1.3) in phase 2
    - **After the opening:**
      - dist < 3 → `&"slash"`, followed 60% of the time by `&"backswing"` on the next call
      - 3 ≤ dist < 7 → slam, breath or slash
      - dist ≥ 7 → charge, spell or dive
      - Never the same big move (slam, spell, breath, dive) twice in a row.
  - **`class_name Vulcan extends Actor`:**
    - `@export var max_hp` (Unreal value, else 600)
    - State: `var awake := false`, `var armed := false`, `var phase := 1`, `var kneeling := false`, `var arena: Arena`, `var target: Node3D`, `var brain: VulcanBrain`
    - Signals: `woke`, `phase_two`, `knelt`, `crown_struck`
    - `func set_statue(on: bool)`: kneeling stone, unarmed; uses the `statue` sprite or the stand-in tinted grey
    - `func wake_scripted() -> void`: C1 awaits it. The burst, rising, then `Fx flame_summon` at the hand, which arms him.
    - `func start_fight(t: Node3D)`
    - `func reset_fight(at: Vector3)`: full hp, phase 1, awake, armed, not kneeling, brain reset
    - **Poise:** `POISE_MAX` (Unreal value, else 40). Light hits wear it down; at 0 he flinches (0.8 s).
    - **Phase two:** at hp ≤ 50%, emits `phase_two` once, roars, and his speed and animation fps scale by `speed_scale()`.
    - **At 0 hp he never dies:** he kneels, stops all attacks, calls `Fx.clear_all()` and emits `knelt`.
    - **While kneeling:** a heavy `HitInfo` emits `crown_struck` once; a light one only spawns sparks.
    - Slam, dive and slash impacts call `arena.crack(at, r)`.
    - Hits on Elvis go through Fx or his own Hitbox, with `Feel` on heavy blows.
  - **Sprite keys:** `statue`, `wake`, `idle`, `walk`, `run`, `slam`, `spell`, `breath`, `dive`, `charge`, `slash`, `backswing`, `flinch`, `roar`, `kneel`.

- [ ] **Step 1:** Write the failing tests.

  `tests/test_brain.gd`:
  - `test_opening_order`: the first 4 calls at any distance → slam, spell, breath, dive
  - `test_close_slash`: after the opening, `next_move(2.0)` is slash or backswing
  - `test_no_repeat_big_move`: 300 calls at seeded random distances → no big move twice in a row
  - `test_phase_two_faster`: phase 2 → `speed_scale() > 1.0`

  `tests/test_vulcan.gd`:
  - `test_phase_two_at_half`: hp to 50% → `phase_two` once, phase 2
  - `test_kneel_not_die`: hp to 0 → kneeling, `knelt` once, node still valid
  - `test_light_on_kneel_does_nothing`: no `crown_struck`
  - `test_heavy_on_kneel_strikes_crown_once`: the second heavy doesn't emit again
  - `test_reset_fight`: after kneeling, reset → hp full, phase 1, kneeling false, armed true
- [ ] **Step 2:** Run them and confirm they fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests, expecting `FAILED 0`. Take screenshots of each opening move's telegraph.
- [ ] **Step 5:** Commit and add the PROGRESS entry.

### Task 5: HUD, game flow, cutscenes, bot

**Files:**
- Create: `ui/hud.gd`, `ui/hud.tscn`, `game/c1_wake.gd`, `game/c3_unmasking.gd`, `game/crown.gd`, `game/sword_prop.gd`, `game/bot.gd`, `tests/test_flow.gd`
- Modify: `game/game.gd`, `game/game.tscn`

**Interfaces:**
- **Consumes:** Tasks 1-4.
- **Produces:**
  - **`class_name Hud extends CanvasLayer`:**
    - `func bind(e: Elvis, v: Vulcan) -> void`: health, stamina and flask counts, plus the boss bar with his name and health. **Claude's call:** the bar reads "Vulcan".
    - `func show_boss_bar(on: bool)`
    - `func say(speaker: String, text: String) -> void` + `signal line_done`: advances on `confirm`, or by itself after 2.5 s + 0.05 s per character (0.1 s in fast mode); `var last_line: String`
    - `func fade(to_black: bool, seconds: float) -> void` + `signal fade_done`
    - `func title_card(title: String, sub: String) -> void`
    - Pause menu (Resume / Restart fight / Quit) + `signal restart_requested`
    - Text is crisp at 640x360: no antialiasing, readable.
  - **`class_name Game extends Node3D`:**
    - `enum Flow {ENTER, WAKE, FIGHT, UNMASK, END}`, `var flow: Flow`, `signal flow_changed(flow: Flow)`
    - `var fast: bool`, from `ShotDriver.fast`; `var restarts: int`
    - Children: `Arena`, `Elvis`, `Vulcan`, `Camera` (PixelCamera), `Hud`
    - `func restart_fight() -> void`
    - **The flow:**
      - ENTER: Elvis starts at `arena.entrance()`.
      - Within 12 m of the plinth → WAKE (C1) → FIGHT.
      - `phase_two` → `hud.say("Vulcan", "Strike the crown.")`. The fight doesn't pause.
      - `knelt` → wait for `crown_struck` → UNMASK (C3) → END.
      - Elvis dies → fade → `restart_fight()` (Elvis `reset_to(entrance)`, `vulcan.reset_fight(plinth)`, `Fx.clear_all()`, `arena.clear_cracks()`, mood `&"blood"`, HUD rebound) → fade back. It happens exactly once per death, and C1 doesn't play again.
  - **`class_name C1Wake`, `static func run(g: Game) -> void`:**
    - Input off.
    - Camera focuses on the plinth.
    - `Fx crown_glow`; mood `&"storm"` for 2 s, then `&"blood"` for 1.5 s.
    - `Fx lightning` and `arena.lightning_flash()`; `Fx statue_burst`.
    - `vulcan.wake_scripted()` (rise, then flame summons the sword).
    - Boss bar on, input on.
    - In fast mode every wait is ×0.05.
  - **`class_name C3Unmasking`, `static func run(g: Game) -> void`:** STORY shots 1-7.
    1. `Feel.slow_motion(0.25, 1.5)`. The crown flies off on an arc, spinning, trailing embers, and lands.
    2. Vulcan kneels; `set_param(&"cool", 0→1)` over 2.5 s.
    3. `set_param(&"burn", 0→1)` over 3 s with `Fx ash`, then `vulcan.sprite.load_character("vulcan_human")`.
    4. The sword prop falls.
    5. Elvis `move_to` the crown, plays `split`, `Fx crown_light` north.
    6. Mood `&"clear"` over 3 s.
    7. Vulcan `look_hands`. `say("Vulcan", "Who... am I?")`, then `say("Elvis", "Whoever you were, you're free.")`. Fade, then `title_card("Tales of Vulcan", "To be continued")`.

    Fast mode works as in C1.
  - **`class_name Bot extends Node`** (active when `ShotDriver.bot == "fight"`): Elvis walks to Vulcan, locks on, attacks with light hits, rolls away from wind-ups within 4 m, drinks red below 35%, and uses a heavy when Vulcan kneels.

- [ ] **Step 1:** Write the failing tests in `tests/test_flow.gd`. Each instances `game.tscn` with `fast = true`.
  - `test_c1_within_12m`: Elvis at 11.5 m → FIGHT within 3 s, Vulcan awake and armed
  - `test_phase_two_line`: Vulcan hp to 50% → `hud.last_line == "Strike the crown."`
  - `test_death_restart_resets_everything`:
    - Setup: in FIGHT, 3 fireballs alive, 2 cracks, one red drunk, Vulcan at 70%; then kill Elvis.
    - Afterwards: `restarts == 1`, Elvis full at the entrance, flasks 4/2, Vulcan full, awake, armed, phase 1, `Fx.count() == 0`, `crack_count() == 0`, flow FIGHT.
  - `test_kneel_stops_attacks`: after `knelt`, no active boss Hitbox and `Fx.count() == 0` for 2 s
  - `test_full_run_reaches_end`: hp to 0 → kneel → heavy HitInfo → flow passes UNMASK and reaches END within 10 s; `vulcan.sprite.character == "vulcan_human"`
- [ ] **Step 2:** Run them and confirm they fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests, expecting `FAILED 0`. Take screenshots with `bot=fight` across the fight, plus C1 and C3 key frames.
- [ ] **Step 5:** Commit and add the PROGRESS entry.

### Task 6: Integration, feel, speed, hand-off (after the art lane)

**Files:**
- Modify: whatever the review finds
- Create: `tests/test_art.gd`, `docs/NEXT.md`, and GIFs and pictures in `docs/progress/`

- [ ] **Step 1:** `tests/test_art.gd::test_manifests_valid`: every `art/*/manifest.json` loads, each listed sheet exists, and its size is exactly `frames × cell`. Run all the tests.
- [ ] **Step 2:** Play windowed with `bot=fight` for 20 s and print the average fps to a log: it must be ≥ 60. Take a screenshot at 2560x1440 (`--resolution 2560x1440`) and confirm whole-pixel scaling.
- [ ] **Step 3:** The feel pass:
  - Watch the bot fight in screenshots taken every 10 frames for 4 s.
  - Check the hit-stop, shake and flash. Movement must not jitter.
  - Tune the numbers and note the changes.
- [ ] **Step 4:** Update `docs/PROGRESS.md` (status table, entries, every "Claude's call") and write `docs/NEXT.md`: where it stands, what Danyal should look at first, the open questions.
- [ ] **Step 5:** Commit.

---

## Art lane

### Task A1: Master sprites (Elvis, armoured Vulcan, human Vulcan)

**Files:**
- Create:
  - `art/<c>/master.png` (80 px tall, transparent background)
  - `art/<c>/master_x4.png`
  - `art/<c>/palette.png` (≤ 32 colours, 1 px per colour)
  - `art/<c>/raw/*` (Gemini originals)
  - `art/<c>/notes.md` (references, prompt, candidates, why this one)

  `<c>` is `elvis`, `vulcan_boss` or `vulcan_human`. Also create `art/tools/README.md`.
- Modify: `art/sprites.py`. Generalise its arguments to `sprites.py <strip> --cols C --rows R --height 80 [--palette P] --out <png> [--manifest M --key K --fps F --loop|--no-loop]`. Keep the magenta and tint removal, and add the palette lock.

**References** (Unreal repo, read-only; copies go in `art/_work/`):
- Elvis: `docs/refs/concepts/2026-10-24_arena_and_elvis.jpg` (the new look).
- Human Vulcan: `docs/refs/vulcan/02_full_body_apose.jpg`, plus `art/vulcan_sheet.png` for continuity.
- Armoured Vulcan: a colour render from a COPY of `SourceArt/Vulcan/Vulcan.blend`, boss outfit and possessed skin (see `SourceArt/Scripts/vulcan_boss.py`; the armour is Danyal's own Tripo pieces), seen from the game's camera angle.

**Gemini:** the Playwright browser is already signed in to Danyal's account. Upload the references and save the images. Earlier sessions saved Gemini images under the Unreal repo's `.playwright-mcp/`, so search its docs and notes for how. Each prompt asks for:
- a top-down three-quarter view, camera high above looking down about 45°, the top of the head and shoulders visible
- 80 px tall, both eyes clearly drawn (dark pupil and a light catch)
- a dark 1 px outline, ≤ 32 colours, hard pixel edges
- a flat #FF00FF background, nothing else in the image

**Process:**
- [ ] **Step 1:** Make at least 3 candidates per character. Clean each to 80 px.
- [ ] **Step 2:** The review gate, at 4x. Both eyes visible, the camera angle right, details present (Vulcan: lion buckle, wraps, beard; the boss: crown, lava cracks, armour; Elvis: long white hair, plate armour, cut navy cape, spear), and he reads as the same man as the reference. Pick the best one and note why.
- [ ] **Step 3:** Commit `art/<c>/` and add a PROGRESS entry with the three masters side by side at 4x. Mark it "**Claude's call:** master chosen by Claude (Danyal: 'You pick, keep going')".

If Gemini refuses or hits a daily limit, stop the lane and write it into PROGRESS and `art/tools/README.md`.

### Task A2: The pose-guide tool and clip catalogue

**Files:**
- Create: `art/tools/pose_strip.py` (Blender 5.2, headless), `art/tools/list_clips.py`, `art/tools/clips.md`

**What it does:** `"/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python art/tools/pose_strip.py -- --source <glb|blend copy> --clip <name> --frames <n or list> --view F|B|S --prop none|spear|greatsword --out <png> --cell 256` renders one strip:
- one frame per pose, at the game camera angle (orthographic, 48.59° down)
- a grey clay body, an optional grey prop held in the right hand
- a flat #FF00FF background
- the same scale and the feet on the same line in every frame

`clips.md` maps every animation in the spec's list to a clip in `All animations.glb` (with its frame range), or to "hand-keyed", listing the key poses in words.

- [ ] **Step 1:** List the 360 clips into `clips.md`.
- [ ] **Step 2:** Render the strips for Elvis `run_F`, `run_S` and `light1_S`, and for Vulcan `slam_F`. Check the poses read clearly at 4x.
- [ ] **Step 3:** Commit and add the PROGRESS entry.

### Task A3: Animations, in priority order

For each animation:
1. Render the pose strip (A2).
2. Give Gemini the master plus the pose strip: "this exact character, in these exact poses, same size, same palette".
3. Clean it with `sprites.py --palette art/<c>/palette.png`.
4. Review at 4x: same character in every frame, eyes visible, details present, motion readable. If it fails, make it again, up to 3 times. If it still fails, keep the best and note why.
5. Add it to `art/<c>/manifest.json`, with holds on the wind-up and impact frames.
6. Make a GIF in `docs/progress/` and commit.

**Priority order:**
1. Elvis: idle, run, roll, light1-4 (F/B/S)
2. Vulcan boss: idle, walk, slam (F/B/S); statue F, wake F, kneel F
3. Vulcan boss: slash, backswing, spell, breath, dive, charge (F/B/S), flinch, roar
4. Elvis: lunge, charge, thrust, hurt, death, drink, sprint (F/B/S); split F
5. Human Vulcan: kneel F, look_hands F

When the night's time or Gemini's limit runs out, log what's done and what's left in PROGRESS.
