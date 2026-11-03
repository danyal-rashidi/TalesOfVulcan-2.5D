# Blue Elvis

30 Oct 2026. The game's Elvis since then: the blue ice Elvis from the Meshy model (`C:\Users\Danye\Downloads\All animations.glb`), redrawn in the Alabaster Dawn style. 48 px tall when running, 54 px standing, the same size of head; 16 colours, dark outline (14,22,40). The old Elvis stays in `art/elvis`, no longer used. Danyal's calls: "absolutely perfect" for the side run, "That is perfect" for all three views, 48 px with Vulcan shrunk to 60%, an ice spear only in attacks, and every spear attack lunges him forward.

The sources live in `D:\SmartRig\spike\elvis\ad\`: the master `blue_g.png`, the Alabaster Dawn screenshot `style_ref.png`, the first runs in `v2\` and everything since in `v3\`. They are not in this repo.

## What exists

`sheets.json` lists every sheet; `strips/` holds what `video_to_sprites.py` made. Only front, side and back are used (`CharacterSprite.dir_suffix`); the side sheet faces right and the game flips it, except that with the spear he has his own left-facing sheets (`*_L`).

| Move | Views | Start picture (Higgsfield job) | Notes |
| --- | --- | --- | --- |
| run | F S B | F 6a297c60-cbb6-45c6-a830-16fe30d5d7e7, S 672587e0-56d0-4a01-9c8c-6c388ef78313, B 42f2923d-25c1-49a7-bddd-22ba16228715 | the loop the script finds, `--height 48`; walking and sprinting play it |
| idle | F S B | F 559cb54e-fbe3-4351-96c5-45f90afe5f22, S dfe03692-7b38-4a34-b77b-8198a5e2ee59, B 3541a42f-81cb-4b72-8263-1679b76c4881 | `--whole 8 --height 54`, 8 frames at 4 fps |
| roll, hurt, drink, death | F S B | the idle pictures | `--once 8 --height 54`. Drink adds the flask's red: `--add 214,40,52 255,120,110 120,16,30`. `hurt_F` and `hurt_S` lost frame 1 by hand: the video model drew a white spark line across him |
| light 1-4, lunge, thrust | F S B | guard: F c628044e-2451-46b5-8d0f-e5fc0211b32c, S bf5d061b-6f05-4466-8b28-87bb4d82b7c9, B 196588e1-065f-4b3f-afe3-9fecd9d006e2 | `--once 8 --height 50`, start and end image both the guard. Hit frames and holds are in `sheets.json`, chosen by eye from the strips |
| charge | F S B | the guards | `--once 8 --height 50`, start image only, 6 fps (about `FULL_CHARGE` long); he holds the last frame |
| split | F only (he faces the camera, `C3Unmasking`) | guard F | `--once 8 --height 50` |

| idle, run, roll, hurt, drink, death with the spear (`*_spear`) | F S B | stand: F 92d4aa30-4fe3-460d-8349-5924aa576b96, S b4aaacf2-90b9-430f-b85e-f63d0b055cf2, B e5bf3936-a31b-49c7-8661-5e61c8dd1852; run: F 3e733b3e-b44f-404d-8c4e-f700c296cb13, S 4d9c2ce2-4a67-431b-8caf-c82168a703d9, B df3ee547-3e28-4744-a82a-4baa83ff842a | as the sets without it; a death also `--keep-pieces 6`, so the spear he drops stays |
| equip, unequip | F S B | start image the empty-handed idle, end image the idle with the spear | `--once 8 --height 54`; `unequip` is the same frames backwards |
| drink_walk, drink_walk_spear | F S B | the run's start picture, no end image | `--whole 16 --height 48 --keep-pieces 6`, plus the flask's red |
| ice_snap, his F ability | F S B, then L | the guards (`D:/SmartRig/spike/elvis/ad/v3/guard_*_a.png`), start and end image | `art/tools/ice_snap_clips.py`: picks 12 frames of each clip (`D:/SmartRig/spike/web/clips/elvis_ice_snap_*.mp4`, 480p, 2 credits each), `below=4` because the halves reach below his feet, far_hand_sheets.py for L, and steady_sheets.py on these sheets only: a whole-folder steady run undoes hand-finished rolls. "active" names the snap and the seal, fx/ice_volley.gd reads them. The clip's end has the spear whole again, so he reforms it himself |
| every move with the spear, facing left (`*_L`) | L | none, made from the side sheets | `art/tools/far_hand_sheets.py`. The side sheets have the spear in his right hand, the back one, so a mirror would change hands; facing left his right hand is the front one. Stand, run, hurt and equip use the mirrored empty-handed sheet with the spear behind him through the front fist. Attacks, roll, death and drinks are the mirrored spear sheet with the spear rubbed out where it crosses him. No credits. Without the spear the game still mirrors the side sheet |

Every move the game asks for has a sheet. Walking and sprinting play the run. The `*_spear` sheets show while the spear is out (`Elvis.spear_out`, `Elvis._look`); the attacks and the split always have it.

## Recipe (price-check first; 548.45 credits on 30 Oct after Danyal bought 500)

1. Start picture, 3 credits for two: `nano_banana_2_1`, 1k, 16:9. References: the master, the same view's approved picture for the camera (the run's start picture), `style_ref.png`. Describe him in full, then the pose, then: "Camera: HIGH camera looking down about 45 degrees, exactly the camera height of image 2, top of the head and shoulders visible, feet tuck under the body. One full figure, centred ... No shadow, no ground, no text. Flat solid green #00B140 background everywhere."
2. Clip, 4 credits for 4 s: `seedance_2_0_mini`, 720p, 16:9, no audio, decline the "IN THE DARK" preset. Give the same picture as start image and end image and he returns to his pose, so an idle loops and an attack ends in guard (a death has a start image only). End each prompt with "Camera completely still. Keep this exact high view, this pixel-art style and this flat green background. No ground, no shadow, no extra effects." What works: "curls into a tight ball ... tumbles one full somersault" for a roll (a "forward roll" breaks up); "We see only the character's back the whole time ... He NEVER turns around" for the back view; a spear attack needs "explodes forward in one huge lunge: his front foot takes a long stride far ahead, his back leg straightens behind him". Three prompts that went wrong: "his chest turns away" spins him around (say "always faces the camera and never turns ... only sinks lower"); a spear aimed straight at the camera swells into a giant shard (say "angled down and to the left of the picture so that it stays long and thin"); it draws an ice crescent on low sweeps whatever you say, which reads as the spear's trail. Walking while doing something needs a start picture in mid-stride and no end image: from the standing picture to itself he stood still however the prompt asked him to walk.
3. Sprites, from the SmartRig repo: `uv run --with imageio-ffmpeg python /mnt/d/SmartRig/spike/elvis/ad/video_to_sprites.py VIDEO /mnt/d/SmartRig/spike/elvis/ad/blue_g.png OUT [--once N | --whole N] [--height H]`. Copy `OUT_strip.png` into `strips/` and add it to `sheets.json`.
4. Game sheets: `uv run --with pillow --with numpy python /mnt/d/SmartRig/spike/elvis/ad/sheets_for_game.py art/elvis_blue` rewrites every sheet and the manifest: one shared cell, the head on its centre column, the feet at the bottom.

5. Left-facing sheets, after step 4 because it rewrites the manifest: `uv run --with pillow --with numpy python art/tools/far_hand_sheets.py art/elvis_blue`.

6. Clean-up, the last step for every character (Danyal chose the strong doctor for all of them on 3 Nov, so they all look alike): `uv run --with pillow --with numpy --with scipy python art/tools/sprite_doctor.py art/elvis_blue NEW_ANIM ... --strong` on the new or remade moves only (a sheet already cleaned would be cleaned twice), after `steady_sheets.py` and `sprite_consistency.py` if the folder uses them. Look at `art/_work/doctor_strong/elvis_blue/*_before_after.gif`, copy the cleaned sheets from there into `art/elvis_blue/`, then remake their light maps with `normal_sheets.py` (their alpha must match the sprite's). Always `--strong`, never the gentle default, or new moves won't match the old.

**Sizes:** set `--height` so his head matches the run's, about 11 px across: 54 for standing, 50 for the crouched guard. A new first pose needs a test shrink before it gets a clip.

**Limits seen:** only about 6 clips render at once. Past that the batch tool answers "Out of credits" (no charge, the balance is fine) and `generate_video` answers 429 `rate_limit_reached`. Wait for clips to finish, and don't resubmit one that was accepted.

**The lunge:** `Elvis.ATTACKS[...]["step"]` is the distance. With hit frames in the sheet it runs from the frame before them to their end (`Elvis._begin`).
