# Next: where the 2.5D game stands

10 Nov 2026 · for Danyal

## Start here: 10 Nov, Elvis's attack timing, swoosh and parry

Blue Elvis only; nothing else changed. His six attacks keep their pictures and their length, but the frames are no longer even: the wind-up holds, the swing is 45 ms, the hit holds longest (`fps` 25 and `holds` in `art/elvis_blue/manifest.json`). Light 3 has a swoosh behind the spearhead on its first hit frame (side and front; the back view already paints a blur). The parry has its own clip, `parry_{S,L,F,B}`: 6 frames, the block is up at 0.08 s and held to 0.4 s, 0.6 s in all. Vulcan as the player still braces in his charge stance. The old Light 3 sheets and manifest are in `art/_work/backup_2026-11-10_swoosh_parry/`. Nobody has seen it in play yet. 304 tests pass.

## 10 Nov, three kinds of enemy

The road's enemies are no longer one hunter in three bodies (study item 9).

**Charger** (two of the five road jackals): it pulls up 5 m off, a red line lies along its path for 0.7 s, then it runs the line without turning. Step off the line, or parry it (Shift): a parry breaks it, and a miss leaves it standing open for 1.2 s.

**Spitter** (all four scorpions): it comes no nearer than 6 m and lobs venom at where you stand, every 2.5 s. A red ring shows where it lands for 0.8 s. It can't be parried: walk or roll out. Walk up to it and it stings as before.

**Guard** (one of the three raiders at the cart, the one standing apart): blows from the front spark off his sword and do no damage, and each fills his break bar half as much as a blow that lands. Hit him from behind, in the 0.8 s after his own slash, or parry the slash (0.6 s wind-up): one parry breaks him for 2 s.

The jackal by the tomb and three road jackals are as before. Numbers to try are at the top of `enemy/charger.gd`, `enemy/spitter.gd`, `enemy/venom.gd` and `enemy/guard.gd`; which jackals charge is `CHARGERS` in `game/cinerea.gd`. No new art: the marks are Vulcan's ember ones, so the venom's ring is red, the glob is a small green ball drawn in code, and the guard has no blocking pose. Nobody has played it by hand yet. 304 tests pass.

## 10 Nov, saving

The game saves now (study item 10). Once a game has reached Cinerea, the title shows **Continue** above New Game and starts on it: it skips the prologue and the colosseum and puts Vulcan back in Cinerea, at the last beat he finished. New Game plays from the prologue as before and leaves the old save alone until he wakes on the road, which replaces it.

It saves on its own, five times: when the long walk in ends, when he has opened the tomb, when Cassia throws him his pay, when he comes through the town's north gate, and each time he leaves her shop. There is no save menu, and quitting doesn't save. Each save puts him back at a fixed spot for its beat (on the road, at the tomb, where he stood for Cassia, inside the gate, at her stall), not where he stood when you quit. The file is `user://save.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Tales of Vulcan 2.5D\save.cfg`; delete it to lose the Continue.

It keeps his bag, what he wears, drachma, embers, memories, the skills on F and Q, the map, trust, and which beats are done (the tomb, Cassia, the town). It doesn't keep his health or flasks (they're full, as after dying), a fight he was in (quit during the raiders and the lake scene plays again), the road's dead jackals and scorpions (they're back), or who he has talked to (first talks play again, so trust answers can be given twice). The fire hammer isn't saved, so `play_fire_hammer.bat` still works. Tests, bots, shots and `play_cinerea.bat` never write the save; Claude's call, so a quick road check can't wipe a real playthrough. The title's rows sit 4 px higher so four fit under the logo. Nobody has played it by hand yet. 293 tests pass.

## 7 Nov, the parry

Elvis can parry, and so can Vulcan in Cinerea once he has a sword. Press **Shift** (**RB** on a controller) just before a blow lands. He braces, the blow glances off with a long hit-stop, a white flash and sparks, and he takes nothing. It works on Vulcan's slash, backswing and charge, in both phases, and on the jackals', scorpions' and raiders' bites and slashes. Fire, the slam's blade, the dive's landing and the fireballs can't be parried: roll those. A blow from behind can't be parried either. Pressed too early he stands open for 0.4 s and can't even roll, so mashing it gets him hit. On a controller RB no longer opens the inventory in play (Back does); it still turns its pages.

Every enemy has a break bar now: a thin gold bar under Vulcan's health, and a small one under any other enemy's once you've hit or parried it. It fills as you wear them down, and a parry fills it about four times faster than a hit. When it's full they're broken for 2 s: they stagger, can't attack, and take half again as much damage (the numbers turn big and gold). Then it empties and starts over.

Phase two can be beaten now: up close he only slashes, and every slash and backswing can be parried. The bot that lost at every speed now parries them and wins with 35 to 70 hp and two or three red flasks left (`tests/test_parry.gd`). Phase one plays as before if you never parry, only with a longer break.

Numbers to try: `PARRY_WINDOW` 0.2 s, `PARRY_RECOVER` 0.4 s and `PARRY_POISE` 35 at the top of `player/elvis.gd`; `BREAK_TIME` 2 s and `BREAK_DAMAGE` 1.5 in `combat/actor.gd`; a jackal's `POISE` 30 in `enemy/jackal.gd`. He has no parry animation yet: he holds the start of his charge stance. A real parry clip is a later art job. Nobody has played it by hand yet. 286 tests pass.

## 3 Nov, a title menu and a dev mode

`play.bat` and the shortcut **"Tales of Vulcan 2.5D"** now open on a title: the logo over the desert and the far colosseum, with New Game (the prologue, as before), Settings and Quit. Settings has full screen, window size, the camera's starting zoom and the controls; they are kept in `user://settings.cfg`. `start=`, `bot=` and shot runs skip the title, so `play_cinerea.bat` and every bot work as before (`start=settings` opens the settings page).

**F1** opens the dev panel in any build (`core/dev.gd`), for building quests: Jump (every named place on the road and in the town, the colosseum, Ctrl+click the ground to go there), Cheats (god mode, one-hit kills, no cooldowns, infinite stamina, fast walk, through walls, the info overlay) and Journey (items, drachma, embers, memories, skills on F and Q, trust, the fire hammer, reset). The overlay stays up with the panel shut: fps, scene, where he is, his health and stamina, Journey, and the 5 nearest people or enemies. `dev=open` opens it at start. Jumps don't wait for a running cutscene or talk, and jumping to the cart or the lake after the tomb still starts the raiders there.

The sprite doctor now keeps frames that were the same in the originals the same after cleaning (a swing ending on his stand, light 2 starting on light 1's pose, parked Fortuna). All the sheets were rebuilt from the originals and the light maps rebaked. 274 tests pass.

## 2 Nov, the whole list is in

Everything from your last list is in the game: outlines off, the hammer formed from his hand and landing in front of him, Elvis's ice F and the slow, Vulcan's scarier halfway point with camera shake and the flaming sword, 30 s cooldowns with a countdown, and pixelfx effects. Footage, what's still wrong and how to change each choice: https://claude.ai/artifact/ARhGhAmqY6pEda7ZkgHKMy

Nobody has played it by hand yet, only bots. What most needs your judgement is whether phase two can be beaten (the bot loses at every speed) and how the shake feels.

Later on 2 Nov, lighting: the characters now take real light from baked normal maps, and the sword aura, the burning hammer, Vulcan's phase two and Cinerea's braziers, altar and lanterns each throw a small light in hard rings. The HD-2D pass from Lumina's ideas adds bloom, warm highlights and haze behind you. Its tilt-shift blur is switched off because it smeared the pixels. The sun only shows faintly on the characters so far, and Elvis is dull in the blood mood. Pictures and what's still wrong are in the top entry of `docs/PROGRESS.md`. Nothing is committed yet.

Next up, once you've played: the sword jump on left-facing swings, which needs his left stand and run recut; the near-black floor cracks on the bright desert; and sound, which you are making yourself. Then Batch 2 of the study.

## The Alabaster Dawn study

`docs/ALABASTER_STUDY.md` (with pictures: https://claude.ai/artifact/PGsGv6EbjPAQGxyg9TiNoP) says what the game is missing next to Alabaster Dawn, and an ordered plan. Batch 1 is built except sound, which is yours. Batch 2 comes next.

## 1 Nov, later: your last list is done

Cassia's door, her feet, the road, his one body and skin, Hammer Blow aimed by holding F, and the smoother grass are all in. To see them, use the shortcut **"Tales of Vulcan Cinerea"**: take the memory at the tomb to learn Hammer Blow, try it on the jackals, and kill the bandits at the carriage for her door. Quests and Varro's fight are next. Higgsfield has 1,745.45 credits left, on Plus. The top entry of `docs/PROGRESS.md` has the details.

## 1 Nov: the whole road plays in order

`play.bat`, or the shortcut **"Tales of Vulcan 2.5D"**, now opens on the prologue (since 3 Nov, after the title's New Game; Esc skips it) and runs: the crossing, the fight, the unmasking, The Long Walk through the sandstorm, the grave, the jackals and scorpions, the lake and the bandits, Cassia, the town. `play_cinerea.bat` and the shortcut **"Tales of Vulcan Cinerea"** still start at The Long Walk. The top entry of `docs/PROGRESS.md` has it all.

## 31 Oct: Cinerea has its village

`play_cinerea.bat`, or the desktop shortcut **"Tales of Vulcan Cinerea"**, skips the colosseum fight and now runs on past the road into the walled town, with talking, answers and portraits. Killing the raiders at her cart plays Cassia's scene, and the Hammer memory at the tomb is a still picture. Cassia's stall is a working shop ("I'm buying." or "I'm selling."). Quests, Varro's fight and the other regions are next; the top entry of `docs/PROGRESS.md` has the details, `docs/art_list.json` has the prompts left and `art/tools/npc_sheets.py` and `sheet_to_props.py` turn new clips and sheets into game art.

## 30 Oct: blue Elvis is in the game

Elvis is now the blue ice Elvis, 48 px tall, and both Vulcans were shrunk to 60% to match. He has every move from the front, the side and the back: idle, run, roll, hurt, drink (standing and walking), death, light 1-4 with an ice spear, the heavy lunge, the charge and the charged thrust, and the blow that splits the crown from the front. R puts the spear away or draws it (d-pad right on a controller); with it away he can't attack. Every spear attack lunges him forward (`Elvis.ATTACKS`, "step"); try whether the distances feel right. Walking and sprinting play the run.

The possessed Vulcan has every move too, and the colosseum is in ruins with props lying about, so the prologue is drawn from end to end. The recipe and limits are in `art/elvis_blue/notes.md`. 

The road into Cinerea is the first of the game proper: start it with `play_cinerea.bat`, or beat the fight and press E on the title card. It has looting at the legionary's tomb, the memory of The Hammer, the inventory, the Memory Paths and the world map (I opens them, Tab turns the page), and jackals with his sword. What it leaves out is in the top entry of `docs/PROGRESS.md`. Only 5.45 Higgsfield credits are left, enough for one more clip; the village, Cassia and his other moves need more.

Danyal's rough looks for the skill tree (Memory Paths), the inventory and the world map are in `docs/refs/ui/` (31 Oct). They are guides, not exact specs. Where they differ from `STORY.md` the story's names and skills stand until Danyal says otherwise.

## Where it stands

The colosseum snippet plays from start to end: Elvis comes in at the breach, the statue wakes (C1), the fight with its four opening moves and the mix after them, "Strike the crown." at half health, the kneel, the heavy blow on the crown, the unmasking (C3, shots 1-7), the two lines and the title card. If Elvis dies, everything resets behind a fade and the fight starts again with Vulcan awake.

The code is finished for this snippet (all 6 tasks, 58 tests pass). It runs at 144 fps on your RX 9070 (your screen's limit; 1530 fps without vsync). The art is not finished: Gemini's 5-hour limit stopped the night's batch (it resets at 10:07 a.m.). Until each sheet exists, the game shows what it has (below).

## Play it first

1. Start it with the desktop shortcut **"Tales of Vulcan 2.5D"**, or `play.bat` in `D:\TalesOfVulkan\TalesOfVulcan25D`. It opens in a 1920x1080 window. **F11** (or Alt+Enter) switches to full screen, which is exactly 4x on your 2560x1440 screen.
2. The controls (keyboard and mouse, or a controller):

   | Action | Keyboard and mouse | Controller |
   | --- | --- | --- |
   | Move | WASD or arrows | left stick |
   | Light attack (4-hit combo) | left click or J | X |
   | Heavy: tap to lunge, hold to charge a thrust | right click or K | Y |
   | Roll; hold to sprint | Space | B |
   | Parry: press just before a blow lands | Shift or C | RB |
   | Lock on | left click an enemy (middle click lets go) | right stick click |
   | Skills, from Cinerea on (E in the Memory Paths sets them): hold to choose where, let go to go | F, Q | right trigger, left trigger |
   | Draw or put away the spear | R | d-pad right |
   | Inventory, Memory Paths, map (from Cinerea on) | I, Tab turns the page | Back, RB turns the page |
   | Red flask (heals 40%) / green flask (stamina) | 1 / 2 | d-pad up / down |
   | Pause (Resume, Restart fight, Quit) | Esc | Start |
   | Finish a line's fade, then next line | Enter or E | A |
   | Zoom the camera | mouse wheel, or + and - | LB in, d-pad left out |
   | Pick an answer to someone | W/S or 1-3, then E or click | stick, then A |
   | Dev panel: jump anywhere, cheats, Journey state, info overlay (Ctrl+click the ground to go there) | F1 | |

3. What to look at, in this order:
   - **How Elvis moves:** the run, the roll, the turn between front, side and back. It should feel smooth, not floaty. All his moves have sheets now (see "Which art is real"): judge their timing and distance, not their look.
   - **The fight's weight:** the hit-stop, the white flash and the shake when a blow lands, and his wind-up marks on the floor.
   - **C1,** which starts as soon as the game opens (the breach is inside the statue's 12 m).
   - **C3:** you need to beat him (600 hp) to see it. To skip the fight, run this in PowerShell (what Windows Terminal opens); after C1 the bot plays Elvis and Vulcan drops to his knees at once:
     `& "D:\GODOT\Godot_v4.7.2-stable_win64.exe" --path D:\TalesOfVulkan\TalesOfVulcan25D -- bot=unmask`
     In Command Prompt (cmd), leave out the `& ` at the start.
     (`bot=fight` lets you watch the bot fight him.)

## Which art is real

- **Real, from Higgsfield clips:** every move of blue Elvis (30-31 Oct).
- **Real, from Gemini and cleaned by hand, at 60% since 30 Oct:** the possessed Vulcan's and human Vulcan's masters; human Vulcan's kneel and look at his hands in C3 (his master redrawn from the game camera, 25 Oct afternoon); the possessed Vulcan's run and walk from the front, the side and the back (25 Oct afternoon).
- **Real, from Higgsfield clips:** every move of the possessed Vulcan but his runs and walks (31 Oct).
- **Elvis:** walking and sprinting play his run; nothing else is missing.
- **Drawn in code, final for now:** the arena, all 14 effects, the crown and the sword in C3, the HUD.
- The old stand-in sheet is only used if a character's manifest goes missing.

## Questions for you

Each was settled with a best guess overnight ("**Claude's call**" in `docs/PROGRESS.md`). Say which to change:

1. (Elvis's part is out of date since 30 Oct: he is the blue Elvis.) **The three masters**: Claude picked them ("You pick, keep going"). Elvis has face A (pale cool skin, ice-blue eyes) from the 24 Oct face sheet; the Unreal game still has three faces waiting for you.
2. **The statue and wake** follow your 24 Oct Unreal version (he kneels with no sword; the flame forms it), not STORY.md's older one.
3. **The ending** stops after shot 7's two lines, fading to the "Tales of Vulcan" card, where E goes on to Cinerea. Shot 8 (the gate, the hand) is left out.
4. **4 red flasks** (Unreal's tuning; STORY.md says 3) and 2 green.
5. **Vulcan's size**: his own 1.90 m, not a giant.
6. **Up close he only slashes** (with a backswing half the time), as the plan's distance bands say; Unreal mixes the slam and the others in up close.
7. (Out of date since 30 Oct: this is the old Elvis's art.) **Elvis's runs and walk** (remade 25 Oct afternoon, Higgsfield): real strides in all three views, the free arm and spear swinging, the cape and hair streaming; his idle's own head is on every frame, so his face and hair don't change, and one breastplate, so the armour doesn't shimmer. Since the review: from the side one long streaming mane in every frame, and only the passing frames touch the ground (the others fly 2-3 px, so no foot slides); from the front and from behind the passing frames stand on the ground and the forward foot reaches toward the camera; the back run is as broad as his back idle, with the long cape. Is that the run you want?
8. (Since 31 Oct his light hits land 0.14-0.21 s in, from each sheet's hit frames.) **Timing**: with the art's holds, his light hit lands about 0.24 s into the swing, later than Unreal's 0.05-0.20 s.
9. **Full screen**: F11 and Alt+Enter, and the game still opens in a window. Should it open full screen?
10. **Gemini's budget**: about 9-10 pictures per 5-hour window, and roughly 60 animations are left, so the art takes several windows. Keep going with Gemini only?

## Fix WSL first

WSL's D: drive broke at about 06:23 (`/mnt/d` gives "Input/output error"; Windows still sees D:). The agents worked around it on clones in `C:\Users\Danye\AppData\Local\Temp`. When no agents are running, open a Windows terminal (PowerShell or cmd), run `wsl --shutdown`, then restart Claude Code.

## Next for the builders

- **Art lane** (the queue's Elvis lines are out of date: he is made from clips now, `art/elvis_blue/notes.md`; a new Vulcan sheet must be drawn at the shrunk size, cell 177x117) (Task A3, when Gemini resets at 10:07): work down `art/tools/gemini_queue.md` from the top: human Vulcan's master redo, Elvis's roll and light 1-4, the boss's idle, walk and slam, then the rest. Each line has the two pictures to attach (`art/guides/`), the exact prompt and the clean-up. 49 requests, about five windows. Front strikes that dip below the feet use `"below"` (the Task 6 entry in `docs/PROGRESS.md`). A kneeling `statue_F` or `kneel_F` needs its crown row passed to the code (`Vulcan.HEAD`).
- **Code:** paint a few floor cracks in advance (each takes about 8 ms, a dropped frame at 144 Hz). Otherwise wait for Danyal's answers above.
