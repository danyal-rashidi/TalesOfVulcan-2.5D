# Next: where the 2.5D game stands

25 Oct 2026, morning · for Danyal

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
   | Lock on | middle click or Q | right stick click |
   | Red flask (heals 40%) / green flask (stamina) | 1 / 2 | d-pad up / down |
   | Pause (Resume, Restart fight, Quit) | Esc | Start |
   | Next line | Enter or E | A |

3. What to look at, in this order:
   - **How Elvis moves:** the run, the roll, the turn between front, side and back. It should feel smooth, not floaty. The roll and most attacks have no sheet yet, so he slides in his idle for those (see "Which art is real"): judge their timing and distance, not their look.
   - **The fight's weight:** the hit-stop, the white flash and the shake when a blow lands, and his wind-up marks on the floor.
   - **C1,** which starts as soon as the game opens (the breach is inside the statue's 12 m).
   - **C3:** you need to beat him (600 hp) to see it. To skip the fight, run this in PowerShell (what Windows Terminal opens); after C1 the bot plays Elvis and Vulcan drops to his knees at once:
     `& "D:\GODOT\Godot_v4.7.2-stable_win64.exe" --path D:\TalesOfVulkan\TalesOfVulcan25D -- bot=unmask`
     In Command Prompt (cmd), leave out the `& ` at the start.
     (`bot=fight` lets you watch the bot fight him.)

## Which art is real

- **Real, from Gemini and cleaned by hand:** the three master sprites (Elvis, the possessed Vulcan, human Vulcan); Elvis's idle, run and walk from the front, the side and the back; his first light swing from the side and from behind; human Vulcan's kneel and look at his hands in C3 (his master redrawn from the game camera, 25 Oct afternoon); the possessed Vulcan's run and walk from the front, the side and the back (25 Oct afternoon).
- **Still the master, standing:** every other move of the possessed Vulcan (the statue is his master drawn as stone; the wake, slam, spell, breath, dive, charge, slash, flinch, roar and kneel all show him standing).
- **Elvis without his own sheet yet** shows his idle (or his run, for walking and sprinting): the roll, the front light swing, light 2-4, the lunge, the charged thrust, drinking, being hurt, dying and splitting the crown. He shows the idle for the way he faces (front, side or back) and slides through the move standing: a roll is his idle gliding 3.5 m, and a heavy is his idle lunging forward.
- **Drawn in code, final for now:** the arena, all 14 effects, the crown and the sword in C3, the HUD.
- The old stand-in sheet is only used if a character's manifest goes missing.

## Questions for you

Each was settled with a best guess overnight ("**Claude's call**" in `docs/PROGRESS.md`). Say which to change:

1. **The three masters**: Claude picked them ("You pick, keep going"). Elvis has face A (pale cool skin, ice-blue eyes) from the 24 Oct face sheet; the Unreal game still has three faces waiting for you.
2. **The statue and wake** follow your 24 Oct Unreal version (he kneels with no sword; the flame forms it), not STORY.md's older one.
3. **The ending** stops after shot 7's two lines, fading to "Tales of Vulcan / To be continued". Shot 8 (the gate, the hand) is left out.
4. **4 red flasks** (Unreal's tuning; STORY.md says 3) and 2 green.
5. **Vulcan's size**: his own 1.90 m, not a giant.
6. **Up close he only slashes** (with a backswing half the time), as the plan's distance bands say; Unreal mixes the slam and the others in up close.
7. **Elvis's runs and walk** (remade 25 Oct afternoon, Higgsfield): real strides in all three views, the free arm and spear swinging, the cape and hair streaming; his idle's own head is on every frame, so his face and hair don't change, and one breastplate, so the armour doesn't shimmer. Since the review: from the side one long streaming mane in every frame, and only the passing frames touch the ground (the others fly 2-3 px, so no foot slides); from the front and from behind the passing frames stand on the ground and the forward foot reaches toward the camera; the back run is as broad as his back idle, with the long cape. Is that the run you want?
8. **Timing**: with the art's holds, his light hit lands about 0.24 s into the swing, later than Unreal's 0.05-0.20 s.
9. **Full screen**: F11 and Alt+Enter, and the game still opens in a window. Should it open full screen?
10. **Gemini's budget**: about 9-10 pictures per 5-hour window, and roughly 60 animations are left, so the art takes several windows. Keep going with Gemini only?

## Fix WSL first

WSL's D: drive broke at about 06:23 (`/mnt/d` gives "Input/output error"; Windows still sees D:). The agents worked around it on clones in `C:\Users\Danye\AppData\Local\Temp`. When no agents are running, open a Windows terminal (PowerShell or cmd), run `wsl --shutdown`, then restart Claude Code.

## Next for the builders

- **Art lane** (Task A3, when Gemini resets at 10:07): work down `art/tools/gemini_queue.md` from the top: human Vulcan's master redo, Elvis's roll and light 1-4, the boss's idle, walk and slam, then the rest. Each line has the two pictures to attach (`art/guides/`), the exact prompt and the clean-up. 49 requests, about five windows. Front strikes that dip below the feet use `"below"` (the Task 6 entry in `docs/PROGRESS.md`). A kneeling `statue_F` or `kneel_F` needs its crown row passed to the code (`Vulcan.HEAD`).
- **Code:** paint a few floor cracks in advance (each takes about 8 ms, a dropped frame at 144 Hz). Otherwise wait for Danyal's answers above.
