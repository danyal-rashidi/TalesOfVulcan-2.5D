# Colosseum snippet: design

24 Oct 2026 · for Danyal

## Intent

The first playable piece of Tales of Vulcan 2.5D: Elvis fights the possessed Vulcan in the colosseum, knocks the Ember Crown off his head, and watches him turn into a man. It proves on the game's most important moment that the look (Alabaster Dawn), the animation (Blasphemous weight) and the movement (smooth) work together, before anything else is built.

The story is fixed and lives in the Unreal game's repo: `D:\TalesOfVulkan\TalesOfVulkan\docs\STORY.md`, sections **Prologue: the tutorial** (steps 3 to 6, Elvis's moves, "If Elvis dies") and **Cutscene: the unmasking** (shots 1 to 7). Read those first; this document only says how the 2.5D version does them.

## What Danyal decided

- A second version of the game in 2.5D pixel art, seen **from above like Alabaster Dawn** ("above cause of the 3d movement"), with the same story. The Unreal game stays untouched.
- Engine: **Godot 4.7.2 Standard, GDScript**, at `D:\GODOT\Godot_v4.7.2-stable_win64.exe`. Project: `D:\TalesOfVulkan\TalesOfVulcan25D` (the test room is already there).
- The fight should feel like what the story says. Fighting is **animated like Blasphemous**: heavy, readable, detailed. **Movement feels smooth.**
- The snippet runs from the colosseum fight until the crown drops and Vulcan turns human.
- **Claude makes every sprite frame in Gemini, through the browser**: the Playwright browser in WSL, already signed in to Danyal's Google account. Not Higgsfield, not Danyal by hand.
- **Eyes and details must show** ("make sure we can see eyes and details matter here"). Characters are **80 px tall**; at 64 px the eyes were lost.

## Claude's calls overnight (25 Oct; Danyal: "best guess, write it down")

Danyal was asleep. These were settled from the project's own records and must be listed in `docs/PROGRESS.md` for him to check:

1. **The poses come only from CC0 motion.**
   - Use `C:\Users\Danye\Downloads\All animations.glb`: 360 clips on a 52-bone rig, Quaternius's Universal Animation Library 1 and 2 plus MakeHuman poses, all CC0 according to the Unreal repo's `SourceArt/Fab/LICENCES.md`.
   - Moves that library lacks, like the spear combo and the greatsword chop, are keyed by hand in Blender.
   - **Never use Paragon or any other clip tagged NoAI on Fab as an input to Gemini.** Epic's terms forbid NoAI assets as inputs to generative AI.
   - The Unreal C++ timings stay a starting point only; the 2.5D frames and their holds set the final timing.
2. **The statue and wake follow Danyal's latest version (24 Oct, Unreal game), not STORY.md's older one.**
   - The stone Vulcan kneels on the plinth with no sword (the kneel with his hand on his knee).
   - Lightning wakes him, he raises an empty hand, and a burst of flame forms the greatsword.
   - After a death or restart he is already awake and armed.
3. **The snippet ends after shot 7's two lines**, fading to a title card. Shot 8 (the gate, the hand, control passing to Vulcan) is not in it, so the hand-offer animations are dropped.
4. **4 red flasks**, matching the Unreal game's current tuning (STORY.md says 3). 2 green.
5. **Boss size:** his own size (1.90 m), not a giant. The armour and crown make him read bigger.
6. **Elvis's face** is undecided in the Unreal game, where three faces are waiting for Danyal. The master sprite takes the face that fits the 24 Oct concept; Danyal may swap it.

## Goals

1. One run from Elvis entering the arena to human Vulcan saying "Who... am I?", playable start to finish.
2. Story step 3, the statue: the stone Vulcan kneels on the plinth. When Elvis comes within 12 m, the crown glows, the storm rolls in, the sun turns red and lightning bursts the statue (C1). Vulcan rises and summons his greatsword from a burst of flame.
3. Step 4, the fight. Each big attack once in order, then mixed:
   - the sword slam (an overhead chop whose fire blade lands along the ground)
   - the spell (a magic circle behind him fires fireballs)
   - the molten breath
   - the magma dive
   - then charges, and close slashes with backswings.

   His blows break the floor. Light hits wear down his poise before he flinches.
4. Step 5, phase two at half health: the crown flares, he is faster, and the text line *"Strike the crown."*
5. Step 6, the finish: when phase two's health is gone he kneels, and a heavy blow knocks the crown off.
6. The unmasking, shots 1 to 7, in the arena with the game's sprites:
   - the crown rings and flies
   - his cracks cool, the armour burns to ash, the sword falls
   - Elvis splits the crown, its red light flees north, the storm clears
   - the two lines
7. Elvis's moves: a 4-hit light combo, a heavy that lunges when tapped and does a charged thrust when held, a 3.5 m roll, sprint, lock-on, stamina, and flasks (4 red heal 40% each, 2 green refill stamina). If he dies, he restarts at the arena entrance with Vulcan at full health.
8. Keyboard and mouse, and a controller.
9. 60 fps, which is trivial at this resolution.

## Non-goals

- The desert crossing, the approach, the long walk, Cinerea.
- Jumping and the plunge attack: the story says the plunge isn't built yet, and a top-down game has no jump here.
- Crouch, crawl, wall-run and the lantern.
- Voice, saving, settings and menus beyond pause and restart.
- 8 facing directions: 3 drawn ones (front, back, side mirrored) for now.
- Music.

## Anti-goals (a failure even if it works)

- Faces without eyes, or mushy detail at game size.
- A character that changes from frame to frame: hair, beard, buckle, crown, armour or colours flickering.
- Movement that feels floaty or stiff. Attacks without weight.
- Blurry or swimming pixels: any smoothing, any scale that isn't a whole number, sprites or the camera off the pixel grid.
- A fight that doesn't read as the story's fight.

## The look (settled in the test room, `main.gd`)

- The world is drawn at 640x360 and scaled up 3x with nearest-neighbour.
- Orthographic camera, looking down at 48.59°. The ground is 32 px per metre, so a 1 m tile top is 24 px on screen.
- Sprites are fixed-Y billboards, scaled by 1/cos(pitch) so each texel is one screen pixel.
- The camera and sprites snap to whole pixels.
- Textures are posterized and nearest-filtered. Sun shadows are on.

**The arena:** a round sand-and-stone floor, walls of arches seen from above, the plinth at the centre, the gate in the north wall and the breach where Elvis enters. The storm turns the light blood-red, and floor cracks glow where his blows land.

## The art pipeline

1. **Master sprites first:** Elvis, armoured Vulcan and human Vulcan, each 80 px tall and seen from the game's camera angle (high above, the top of the head and shoulders visible). Each eye must be clearly drawn.
   - Sources: Vulcan's master picture is `docs/refs/vulcan/02_full_body_apose.jpg` in the Unreal repo. Elvis's new look is `docs/refs/concepts/2026-10-24_arena_and_elvis.jpg`.
   - The armoured boss is rendered as a reference from `SourceArt/Vulcan/Vulcan.blend` (the `Boss_*` meshes; always work on a copy).
   - **Danyal approves the three masters before any animation is made.**
2. **Every animation:**
   - Render a grey pose-guide strip in Blender at the game's camera angle, one frame per pose. The motion comes from the CC0 library or hand keys (call 1 above); the body can be the library's own rig or that character's rig (`Vulcan.blend`, `SourceArt/Elvis/Elvis.blend`, always on a copy). Neither `.blend` has any animation of its own.
   - Give Gemini the master sprite plus the pose strip: "paint this character in these exact poses", on a flat #FF00FF background.
3. **Clean-up:** `art/sprites.py` cuts the strip into frames, removes the magenta and its tint, shrinks to 80 px, keeps one palette per character and lines the feet up. Its grid size is an argument.
4. **The review gate:** Claude looks at every strip at 4x before it goes in. Same character in every frame, both eyes visible, details present, motion readable. Strips that fail are made again. Danyal sees each approved animation as a GIF in `docs/PROGRESS.md`.
5. **Effects:** the fire blade, fireballs, breath, dive, cracks, lightning, the crown's light and the ash. Godot particles and shaders in the same pixel style, or Gemini strips; the builder chooses per effect.

## Animations needed (about 30; F/B/S = front, back, side)

| Who | Animations |
| --- | --- |
| Elvis | idle, run, sprint, roll, light 1-4, heavy lunge, charged thrust (charge and release), hurt, death, drink: F/B/S. Cutscene: walk, split the crown: one view each |
| Armoured Vulcan | statue (kneeling, still), wake (stone bursts, rises, summons the sword from flame), idle, walk, run, sword slam, spell cast, breath, dive (leap and land), slash with backswing, flinch, phase-two roar, kneel: F/B/S where he moves; one view for the cutscene moments |
| Human Vulcan | kneel, look at his hands: one view each |

## How it should feel

- **Movement:** acceleration and deceleration instead of instant starts and stops; 8-way input; facing that turns smoothly; the camera follows with a slight lead, snapped to pixels.
- **The roll** has invulnerable frames.
- **Blasphemous weight:**
  - wind-up frames held a little longer
  - smear frames on swings
  - hit-stop of about 60 to 90 ms
  - screen shake on heavy blows
  - a white flash on the one hit
  - knockback
  - impact frames held
- **Numbers:** the Unreal game already tuned damage, poise, timings and stamina costs. Its C++ (`Source/TalesOfVulkan/BossVulcan*.cpp`, `CombatTest.cpp`, `StaminaComponent`, `FlaskComponent`) is the starting point, converted to 2.5D distances.

## Build order

1. Put the project in local git (never pushed without Danyal) and log in `docs/PROGRESS.md` as each step lands.
2. **Code with stand-in sprites:** the arena, Elvis's movement and moves, the boss and his moves in order then mixed, health, stamina and flask HUD, phase two, death and restart, a cutscene player with text boxes. Playable before any new art exists.
3. The three master sprites, for Danyal's approval.
4. Animations, most seen first: Elvis's run and attacks, Vulcan's idle and slam, and so on.
5. The C1 wake and the C3 unmasking with real sprites.

## Left to the builder

- Exact frame counts.
- The HUD's look: simple, in the Alabaster Dawn spirit.
- The effect technique for each effect.
- The arena's layout details.
- Reusing sound effects from the Unreal game's `SourceArt/Audio` where they fit.
- Tuning the numbers.
- How the code is split into scenes and scripts. Keep scenes as text files.
