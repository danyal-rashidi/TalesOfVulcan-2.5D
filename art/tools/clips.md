# Pose clips for the colosseum snippet

Every animation in the design spec mapped to a pose source: a clip of `All animations.glb` with its frames, or a hand-keyed clip in `hand_keys.json`. `pose_strip.py` renders the grey guide strips Gemini paints over (Task A3).

**Licences.** `All animations.glb` holds 261 Quaternius Universal Animation Library 1+2 clips and 99 MakeHuman poses, all CC0 (the Unreal repo's `SourceArt/Fab/LICENCES.md`, "Animations from All animations.glb"). Nothing here comes from Paragon or any Fab asset tagged NoAI: never add one.

## Rendering a strip

Work on the copy `art/_work/a2/all_animations.glb` (gitignored). `blender.exe` is a Windows program, so give it Windows paths:

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$B" -b --factory-startup --python 'D:\TalesOfVulkan\TalesOfVulcan25D\art\tools\pose_strip.py' -- \
  --source 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\a2\all_animations.glb' \
  --clip "Sword Light D" --frames 46,40,36,34,32,26,36,44 --view S --prop spear --left-grip -0.5 --cell 384 \
  --out 'D:\TalesOfVulkan\TalesOfVulcan25D\art\_work\a2\strips\elvis_light1_S.png' > strip.log 2>&1
grep POSE_STRIP strip.log
```

Each Blender start spends about 30 s importing the GLB. For several strips, list them in a JSON file and pass `--batch <file>` instead; `test_strips.json` is the batch for the checked strips below, plus the statue test: rerun it after changing the tool or `hand_keys.json`.

| Option | Meaning |
| --- | --- |
| `--frames` | Clip frames at 30 fps, 0 = the first. `8` = 8 evenly over the whole clip, end left out (a loop). `4-20/5` = 5 from 4 to 20, ends in. `46,40,36` = exactly those, in that order. |
| `--view` | `F` faces the camera, `B` faces away, `S` faces screen-right (the game mirrors it for left). |
| `--prop` | `none`, `spear` (2.2 m, gripped at 35% from the butt) or `greatsword` (1.85 m). The prop sits in the right fist: blade out of the thumb side. It never goes through the floor: an end that would is tilted up about the grip, keeping its heading, until it rests on the ground (a chop lands along the ground, a planted sword stands on its tip). |
| `--cell` | Square cell size in px. The scale is always 80 px per metre, so the cell only sets how much fits: 256 bare-handed, 384 with a weapon. |
| `--left-grip M` | Puts the left hand on the prop, M metres from the right hand (− toward the pommel or butt), by IK in every frame. Makes a one-handed library clip two-handed. The library's sword clips often fling the right arm beyond the left's reach (0.59 m); then the right hand and the weapon, keeping its angle, are drawn in toward the left shoulder until both hands hold it. |
| `--carry R,F,U` | Holds the prop at a steady angle in his own axes (right, forward, up) instead of turning it with the fist. Use for locomotion, where a pumping fist spins the weapon. |
| `--air 1` | The cell rises with his hips above standing height, so a leap stays in the cell (the game adds the arc). |
| `--yaw DEG` | Swings the camera round him (+ toward his left). The log prints each frame's "hips facing"; passing that value re-centres a clip keyed turned. |

The log line `POSE_STRIP strip ... ok` means every pose fits its cell; `CLIPPED cells [..]` means use a bigger `--cell`. `prop rests on the ground in cells [..]` lists the cells where the prop was tilted up off the floor. A line `IK: ... short of its target` means a hand couldn't reach where it was sent: move the target closer (the arm reaches 0.59 m from the shoulder).

**The look.** The camera is orthographic, 48.59° down like the game's. The body is a clay mannequin of balls and tubes built on the library rig's bones: left limbs darker grey, and a nose bump shows which way he faces. Every cell is centred on the hips, with the ground under them on the same row (62% down). The background is flat #FF00FF with hard edges. The library man is 2 m tall and stands about 125 px high. The 48.59° view squashes him to about two thirds of his front-view height, as the game camera would.

## Hand-keyed clips (`hand_keys.json`)

A hand-keyed clip is named `"HK <name>"` and is a list of key poses, one every `step` frames. Blender interpolates between them, so `--frames` works on it like on any clip. Each pose:

- `"from": [clip, frame]`: the starting pose, any library clip and frame.
- `"hips": [right, forward, up]`: moves the hips (and the whole body) that many metres.
- `"turn": {"Bone": [[axis, degrees], ...]}`: turns a bone and its children about his own axes, parents first. Bone names drop the `mixamorig` prefix: `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`, `LeftArm`, `LeftForeArm`, `LeftHand`, `LeftUpLeg`, `LeftLeg`, `LeftFoot`, and the `Right...` ones.
  - `right`: + raises the front: the head tips back, the torso leans back, a hanging arm swings forward and up.
  - `up`: + turns toward his left.
  - `forward`: + tips his right side down.
  - Turning `RightHand` rolls the prop in his fist: `HK Slam` turns it `right` −90 so the blade chops down.
- `"hand_on": {"Left": ["LeftLeg", [right, forward, up]]}`: IK puts that wrist on a joint plus an offset in metres (for example, the palm on the knee).
- `"left_grip": M`: the left hand onto the prop, as `--left-grip`.
- `"aim": [right, forward, up]`: turns the right fist so the prop points that way. The light attacks key the spear's path with it. Avoid aims along the camera's line of sight (forward and up, or back and down, in F; forward and down, or back and up, in B): the spear shrinks to a stub.
- `"ease": {"to": [clip, frame], "by": 0.5, "bones": [...]}`, or a list of them: turns those bones that share of the way toward a calmer pose (applied first, before `hips` and `turn`). When eased legs straighten, the body moves so the lowest foot stays where the clip had it. `HK Run` eases the jog's stride and lean by half, and its arms fully to Idle's before keying them.
- `"plant": true`: moves the body, after every other key, until its lowest part rests on the ground. The in-place `Roll` floats about 0.9 m through the tuck.
- `"each": {...}`, next to `"step"`: keys that every pose of the clip shares. A pose's own key of the same name replaces it.

## The map

**Status.** **Checked** = rendered and reviewed at 4x at game size on 25 Oct. **Tested** = renders, pose still to refine. **Candidate** = picked from contact sheets of the whole library; render it and confirm before giving it to Gemini. **Hand-keyed** = no library clip fits, so build it in `hand_keys.json` from the key poses listed.

**Views.** Render F, B and S with the same settings unless the row names one view. If a B or F version reads badly (a blade foreshortened toward the camera), fix it with `--yaw` or `--carry` rather than a different clip, so all three views stay the same move.

### Elvis (spear; `--cell 384`)

| Animation | Views | Source | Frames | Prop and options | Status |
| --- | --- | --- | --- | --- | --- |
| idle | F B S | Idle (0-75) | `6` (loop) | spear, `--carry 0.1,0.15,1` (upright, butt near his foot) | Candidate |
| run | F B S | **HK Run**, on Jog Forward 0-25 (8 poses): the spine and legs eased halfway to Idle, the arms keyed with the elbows bent, the left arm swinging from straight down to ahead of him, the right fist carrying the spear steady. The plain clip read as a one-legged hop in F: the far leg hid behind his body in 6 of 8 cells, and the back-swung arm showed above his head. | `0,4,8,12,16,20,24,28` (one per pose, a loop) | spear, `--carry 0.25,0.35,1` | **Checked** (F, S, B; both legs show in every F cell) |
| sprint | F B S | Sprint (0-20) | `6` (loop) | spear, `--carry 0.2,-1,0.15` (trailing behind) | Candidate |
| roll | F B S | **HK Roll**: Roll frames 0, 4, 14, 16, 18, 20, 22, 25, each set down on the ground (`plant`; the in-place clip floats about 0.9 m through the tuck): crouch, push off, hands down, tucked over the shoulder, over, over, sitting up, rising. Frames 26 on are standing up. | `0,4,8,12,16,20,24,28` | `--prop none`: in the fist the spear stabs through him as he turns over. Tell Gemini he keeps the spear close along his right side. | **Checked** (F, S, B) |
| light1 | F B S | Sword Light D (0-50) | `46,40,36,34,32,26,36,44`: its recovery backwards, then forwards = a step-in thrust from guard | spear, `--left-grip -0.5` | **Checked** (light1_S) |
| light2 | F B S | **HK Light2**, a low sweep at the legs, 6 poses on Sword Light D's guard and lunge stances: 1. guard; 2. wind-up, torso turned to his right, the tip low behind his right side; 3. the tip swept low past his front-right; 4. the strike, the tip ahead at knee height, torso turned to his left; 5. follow-through, the tip to his left; 6. guard. Not Sword Light A-C: they swing his hips through about 90° and the spear points every way in turn, a flail at 4x. | `0,4,8,12,16,20` (one per pose; the hit is pose 4) | spear, `--left-grip -0.5` | **Checked** (F, S, B) |
| light3 | F B S | **HK Light3**, a rising cut, 6 poses: 1. guard; 2. he dips into a deep lunge, the tip low behind his right side; 3. the tip low ahead; 4. rising, the tip up and forward; 5. tall, the spear nearly upright; 6. guard. | `0,4,8,12,16,20` (the hit is pose 4) | spear, `--left-grip -0.5` | **Checked** (F, S, B) |
| light4 | F B S | **HK Light4**, the finisher, 6 poses: 1. guard; 2. the spear drawn back over his right shoulder; 3. overhead; 4. cut down into a deep lunge, the tip on the ground ahead and to his left; 5. recover; 6. guard. | `0,4,8,12,16,20` (the hit is pose 4) | spear, `--left-grip -0.5`; B with `--yaw -25` (straight from behind, the impact spear points away from the camera and shrinks to a stub) | **Checked** (F, S, B) |
| lunge (heavy, tapped) | F B S | Sword Light D (0-50) | `0,4,8,10,12,14,24,34`: body turned to coil, then a two-handed lunge thrust, held | spear, `--left-grip -0.5` | Candidate (seen in the contact sheets) |
| charge (heavy, held) | F B S | Overhand Throw (0-40) | `0-12/4`, the last held or looped | spear in the fist (a javelin coil) | Candidate |
| thrust (charge released) | F B S | Overhand Throw (0-40) | `12-30/6` (the release; the fist keeps the spear) | spear | Candidate |
| hurt | F B S | Hit Chest (0-10) | `0-10/4` | spear in the fist | Candidate |
| death | F B S | Death 01 (0-72) | `0-72/8`, the last held | `--prop none` (he drops it; Gemini paints it falling) | Candidate |
| drink | F B S | Drink (0-90) | `10-80/6` | `--prop none` (Gemini paints the flask; the spear isn't in the guide) | Candidate |
| walk (cutscene) | S | Walk Forward (0-40) | `8` (loop) | spear, `--carry 0.1,0.15,1` | Candidate |
| split the crown (cutscene) | F | Mining (0-27; 0 = top of the swing) | `20,24,0,3,6,9,9,15`: lift overhead, drive down, hold, pull free | spear, `--carry 0,0.2,-1` (point down), `--left-grip 0.4` | Candidate |

### Armoured Vulcan (greatsword, two hands = `--left-grip -0.17`; `--cell 384`)

| Animation | Views | Source | Frames | Prop and options | Status |
| --- | --- | --- | --- | --- | --- |
| statue | F | **HK Statue**, pose 1: kneels on the right knee, left palm on the raised left knee, right palm on the right thigh, head bowed, no sword (Danyal's 24 Oct version). Built on Fixing Kneeling 60. | `0,0` (pose 2, head up, is frame 6) | none, `--cell 256` | **Tested** (reads as the kneel; the right palm stops 10 cm short of the thigh, so lower the shoulders a little more) |
| wake | F | Hand-keyed, 7 poses:<br>1. the statue (HK Statue pose 1)<br>2. head lifts (HK Statue pose 2)<br>3. the stone bursts: shoulders flex, arms out from the body (Monster Transformation ~30 as reference)<br>4. rises off the knee (Pick Up Kneeling 40-58)<br>5. stands, right arm raised high, empty hand open (Spreadcore Summoning Pose)<br>6. flame: the greatsword appears in the raised fist<br>7. both hands bring it down to guard (Sword Idle 0, `left_grip` -0.17) | one frame per pose | none for poses 1-5, greatsword for 6-7 | Hand-keyed |
| idle | F B S | Sword Idle (0-50) | `6` (loop) | greatsword, `--left-grip -0.17` (a low two-handed guard) | Candidate |
| walk | F B S | Walk Forward (0-40) | `8` (loop) | greatsword, `--carry 0.3,-0.5,-0.8` (tip trailing near the ground) | Candidate |
| run | F B S | Jog Forward (0-28) | `8` (loop) | greatsword, `--carry 0.3,-0.5,-0.8` | Candidate |
| slam | F B S | **HK Slam**, on Mining (a two-handed overhead swing that faces forward throughout), 8 poses:<br>1. guard (Sword Idle 0)<br>2. rising (Mining 21)<br>3. overhead, the blade up behind his head (Mining 0)<br>4. falling (Mining 3)<br>5. impact: the wrist rolls the blade down, so it lands along the ground ahead (Mining 6)<br>6. held (Mining 12)<br>7. lift (Mining 21)<br>8. guard. Not Sword Heavy D: it spins about 145° (hips facing −99° to +46°), so an F sheet would show him side-on until the impact. | `0,4,8,12,16,20,24,28` (one per pose) | greatsword, `--left-grip -0.17` | **Checked** (slam_F; hips within 18° of the camera in every frame) |
| spell | F B S | Hand-keyed, 5 poses:<br>1. guard (Sword Idle 0)<br>2. the greatsword raised to the sky in the right hand, chest open: the circle forms behind him (Spreadcore Summoning Pose)<br>3. held<br>4. the left hand thrusts forward, palm out: fireballs (Spell Simple Shoot 5-10)<br>5. back to guard | one per pose | greatsword in the fist | Hand-keyed |
| breath | F B S | Hand-keyed on Idle 0, 5 poses:<br>1. guard<br>2. inhale: chest up, head and shoulders back (`Spine` right +12, `Head` right +25), sword lowered to one hand at his side<br>3. lunge the head forward, jaw open (`Spine` right −20, `Neck` right −10, `Head` right +10)<br>4. hold 3 (loops for the breath's 1.2 s)<br>5. recover | one per pose | greatsword in the fist | Hand-keyed |
| dive | F B S | Sword Ground Pound Root Motion (0-35) | `0-35/8`: crouch, leap with the sword up, land, blade along the ground | greatsword, `--left-grip -0.17`, `--air 1`, `--cell 512` (at 384 the blade clips) | Candidate |
| charge | F B S | Sword Dash Root Motion (0-47) | `0-47/8` | greatsword, `--left-grip -0.17` | Candidate |
| slash | F B S | Sword Heavy A (0-22) | `0-22/6` | greatsword, `--left-grip -0.17` | Candidate |
| backswing | F B S | Sword Heavy B (0-15) | `0-15/5` | greatsword, `--left-grip -0.17` | Candidate |
| flinch | F B S | Hit Stomach (0-20) | `0-20/5` | greatsword in the fist | Candidate |
| roar (phase two) | F B S | Monster Transformation (0-67) | `0-67/8` | greatsword in the fist; Spreadcore Arms Up Pose 001 is the peak to aim for | Candidate |
| kneel (at 0 hp) | F | **HK Kneel**: Pick Up Kneeling 0-25 with the right hand kept on the hilt, ahead of his right shoulder (the clip alone reaches the floor, which would bury the blade), and the back straightened a little as he goes down | `0-25/6`, the last held | greatsword, `--carry 0.3,0.2,-1`: the ground rest plants the tip on the floor ahead and to his right, so he leans on the sword | **Checked** (kneel_F) |

### Human Vulcan (no prop; `--cell 256`)

| Animation | Views | Source | Frames | Prop and options | Status |
| --- | --- | --- | --- | --- | --- |
| kneel | F | HK Statue pose 1 (the same kneel, flesh instead of stone; the cutscene cools and burns him into it) | `0,0` | none | Hand-keyed (shares HK Statue) |
| look at his hands | F | Hand-keyed, 3 poses on HK Statue pose 1:<br>1. the kneel<br>2. both hands rise in front of his chest, palms up (`hand_on` both wrists about 0.35 m in front of `Spine2`, ±0.12 to the sides)<br>3. head bowed to them (`Head` right −35). MakeHuman "Elvs What Have I Done" shows the arm shape. | one per pose | none | Hand-keyed |

## The 360 clips

Output of `python3 -I art/tools/list_clips.py art/_work/a2/all_animations.glb`. MakeHuman poses are held poses (1 s, every frame the same).

| # | Clip | Source | Seconds | Frames (30 fps) |
| ---: | --- | --- | ---: | --- |
| 1 | Idle | UAL | 2.50 | 0-75 |
| 2 | T-Pose | UAL | 0.00 | 0-0 |
| 3 | Crawl Backward | UAL | 2.50 | 0-75 |
| 4 | Crawl Enter | UAL | 2.13 | 0-64 |
| 5 | Crawl Exit | UAL | 2.00 | 0-60 |
| 6 | Crawl Forward | UAL | 2.17 | 0-65 |
| 7 | Crawl Idle | UAL | 2.33 | 0-70 |
| 8 | Crawl Left | UAL | 1.27 | 0-38 |
| 9 | Crawl Right | UAL | 1.27 | 0-38 |
| 10 | Crouch Backward | UAL | 2.00 | 0-60 |
| 11 | Crouch Backward Left | UAL | 2.00 | 0-60 |
| 12 | Crouch Backward Right | UAL | 2.00 | 0-60 |
| 13 | Crouch Enter | UAL | 0.83 | 0-25 |
| 14 | Crouch Exit | UAL | 0.83 | 0-25 |
| 15 | Crouch Forward | UAL | 2.00 | 0-60 |
| 16 | Crouch Forward Left | UAL | 2.00 | 0-60 |
| 17 | Crouch Forward Right | UAL | 2.00 | 0-60 |
| 18 | Crouch Idle | UAL | 2.93 | 0-88 |
| 19 | Crouch Left | UAL | 2.00 | 0-60 |
| 20 | Crouch Right | UAL | 2.00 | 0-60 |
| 21 | Dodge Left | UAL | 1.30 | 0-39 |
| 22 | Dodge Left Root Motion | UAL | 1.30 | 0-39 |
| 23 | Dodge Right | UAL | 1.30 | 0-39 |
| 24 | Dodge Right Root Motion | UAL | 1.30 | 0-39 |
| 25 | Double Jump | UAL | 0.90 | 0-27 |
| 26 | Idle Fold Arms | UAL | 2.50 | 0-75 |
| 27 | Idle Lantern | UAL | 2.50 | 0-75 |
| 28 | Idle Look Around | UAL | 4.60 | 0-138 |
| 29 | Idle No | UAL | 2.50 | 0-75 |
| 30 | Idle Paper | UAL | 3.13 | 0-94 |
| 31 | Idle Rail | UAL | 2.50 | 0-75 |
| 32 | Idle Rail Call | UAL | 2.50 | 0-75 |
| 33 | Idle Rock | UAL | 3.13 | 0-94 |
| 34 | Idle Scissors | UAL | 3.13 | 0-94 |
| 35 | Idle Shield | UAL | 2.50 | 0-75 |
| 36 | Idle Shield Break | UAL | 1.07 | 0-32 |
| 37 | Idle Talking | UAL | 2.93 | 0-88 |
| 38 | Idle Talking Phone | UAL | 2.93 | 0-88 |
| 39 | Idle Tired | UAL | 2.30 | 0-69 |
| 40 | Idle To Lay | UAL | 3.00 | 0-90 |
| 41 | Idle Torch | UAL | 1.27 | 0-38 |
| 42 | Jog Backward | UAL | 0.93 | 0-28 |
| 43 | Jog Backward Left | UAL | 0.93 | 0-28 |
| 44 | Jog Backward Right | UAL | 0.93 | 0-28 |
| 45 | Jog Forward | UAL | 0.93 | 0-28 |
| 46 | Jog Forward Lean Left | UAL | 0.93 | 0-28 |
| 47 | Jog Forward Lean Right | UAL | 0.93 | 0-28 |
| 48 | Jog Forward Left | UAL | 0.93 | 0-28 |
| 49 | Jog Forward Right | UAL | 0.93 | 0-28 |
| 50 | Jog Left | UAL | 0.93 | 0-28 |
| 51 | Jog Right | UAL | 0.93 | 0-28 |
| 52 | Jog To Flip | UAL | 1.20 | 0-36 |
| 53 | Jump | UAL | 2.50 | 0-75 |
| 54 | Jump Land | UAL | 1.27 | 0-38 |
| 55 | Jump Start | UAL | 1.33 | 0-40 |
| 56 | Ninja Jump Double | UAL | 0.90 | 0-27 |
| 57 | Ninja Jump Idle | UAL | 2.00 | 0-60 |
| 58 | Ninja Jump Land | UAL | 1.27 | 0-38 |
| 59 | Ninja Jump Start | UAL | 0.97 | 0-29 |
| 60 | Roll | UAL | 1.47 | 0-44 |
| 61 | Roll Root Motion | UAL | 1.47 | 0-44 |
| 62 | Slide | UAL | 2.00 | 0-60 |
| 63 | Slide Exit | UAL | 0.50 | 0-15 |
| 64 | Slide Start | UAL | 0.83 | 0-25 |
| 65 | Sprint | UAL | 0.67 | 0-20 |
| 66 | Sprint Enter | UAL | 0.87 | 0-26 |
| 67 | Sprint Exit | UAL | 1.67 | 0-50 |
| 68 | Sprint Shield | UAL | 0.67 | 0-20 |
| 69 | Swim Forward | UAL | 1.33 | 0-40 |
| 70 | Swim Idle | UAL | 3.33 | 0-100 |
| 71 | Turn 90 Left | UAL | 2.00 | 0-60 |
| 72 | Turn 90 Right | UAL | 2.00 | 0-60 |
| 73 | Turn180 Left Root Motion | UAL | 1.67 | 0-50 |
| 74 | Turn180 Right Root Motion | UAL | 1.67 | 0-50 |
| 75 | Walk | UAL | 1.33 | 0-40 |
| 76 | Walk Backward | UAL | 1.33 | 0-40 |
| 77 | Walk Backward Left | UAL | 1.33 | 0-40 |
| 78 | Walk Backward Right | UAL | 1.33 | 0-40 |
| 79 | Walk Carry | UAL | 2.00 | 0-60 |
| 80 | Walk Formal | UAL | 1.33 | 0-40 |
| 81 | Walk Forward | UAL | 1.33 | 0-40 |
| 82 | Walk Forward Left | UAL | 1.33 | 0-40 |
| 83 | Walk Forward Right | UAL | 1.33 | 0-40 |
| 84 | Walk Left | UAL | 1.33 | 0-40 |
| 85 | Walk Right | UAL | 1.33 | 0-40 |
| 86 | Climb Down | UAL | 1.27 | 0-38 |
| 87 | Climb Enter | UAL | 1.47 | 0-44 |
| 88 | Climb Exit | UAL | 1.47 | 0-44 |
| 89 | Climb Idle | UAL | 2.93 | 0-88 |
| 90 | Climb Ledge | UAL | 0.63 | 0-19 |
| 91 | Climb Ledge Root Motion | UAL | 0.63 | 0-19 |
| 92 | Climb Left | UAL | 0.87 | 0-26 |
| 93 | Climb Left Root Motion | UAL | 0.87 | 0-26 |
| 94 | Climb Right | UAL | 0.87 | 0-26 |
| 95 | Climb Right Root Motion | UAL | 0.87 | 0-26 |
| 96 | Climb Up | UAL | 1.27 | 0-38 |
| 97 | Climb Up 1m Root Motion | UAL | 0.67 | 0-20 |
| 98 | Climb Up 2m Root Motion | UAL | 1.30 | 0-39 |
| 99 | Get Off Wall 2m Root Motion | UAL | 0.63 | 0-19 |
| 100 | Lift Air Fall | UAL | 1.30 | 0-39 |
| 101 | Lift Air Fall Impact | UAL | 0.67 | 0-20 |
| 102 | Lift Air Fall Root Motion | UAL | 0.93 | 0-28 |
| 103 | Lift Air Hit Left | UAL | 0.50 | 0-15 |
| 104 | Lift Air Hit Right | UAL | 0.50 | 0-15 |
| 105 | Lift Air Idle | UAL | 2.00 | 0-60 |
| 106 | Lift Air Root Motion | UAL | 0.47 | 0-14 |
| 107 | Safety Vault Root Motion | UAL | 0.73 | 0-22 |
| 108 | Step Up Root Motion | UAL | 0.67 | 0-20 |
| 109 | Wall Run Jump Left | UAL | 0.73 | 0-22 |
| 110 | Wall Run Jump Right | UAL | 0.73 | 0-22 |
| 111 | Wall Run Left | UAL | 0.73 | 0-22 |
| 112 | Wall Run Right | UAL | 0.73 | 0-22 |
| 113 | Bow Aim Down | UAL | 1.33 | 0-40 |
| 114 | Bow Aim Neutral | UAL | 2.50 | 0-75 |
| 115 | Bow Aim Up | UAL | 1.33 | 0-40 |
| 116 | Bow Notch | UAL | 2.50 | 0-75 |
| 117 | Bow Rapid Shoot | UAL | 0.43 | 0-13 |
| 118 | Bow Shoot | UAL | 0.67 | 0-20 |
| 119 | Hit Chest | UAL | 0.33 | 0-10 |
| 120 | Hit Head | UAL | 0.43 | 0-13 |
| 121 | Hit Knockback | UAL | 0.83 | 0-25 |
| 122 | Hit Knockback Root Motion | UAL | 0.83 | 0-25 |
| 123 | Hit Shoulder Left | UAL | 0.53 | 0-16 |
| 124 | Hit Shoulder Right | UAL | 0.50 | 0-15 |
| 125 | Hit Stomach | UAL | 0.67 | 0-20 |
| 126 | Kick | UAL | 1.10 | 0-33 |
| 127 | Melee Combo | UAL | 2.27 | 0-68 |
| 128 | Melee Hook | UAL | 0.47 | 0-14 |
| 129 | Melee Hook Recovery | UAL | 0.60 | 0-18 |
| 130 | Melee Knee | UAL | 0.87 | 0-26 |
| 131 | Melee Knee Recovery | UAL | 0.23 | 0-7 |
| 132 | Melee Uppercut | UAL | 1.07 | 0-32 |
| 133 | Overhand Throw | UAL | 1.33 | 0-40 |
| 134 | Pistol Aim Down | UAL | 0.17 | 0-5 |
| 135 | Pistol Aim Neutral | UAL | 0.17 | 0-5 |
| 136 | Pistol Aim Up | UAL | 0.17 | 0-5 |
| 137 | Pistol Idle | UAL | 1.67 | 0-50 |
| 138 | Pistol Reload | UAL | 1.67 | 0-50 |
| 139 | Pistol Shoot | UAL | 0.63 | 0-19 |
| 140 | Punch Cross | UAL | 1.00 | 0-30 |
| 141 | Punch Jab | UAL | 0.87 | 0-26 |
| 142 | Punch Kick Enter | UAL | 0.67 | 0-20 |
| 143 | Punch Kick Exit | UAL | 0.67 | 0-20 |
| 144 | Shield Dash Root Motion | UAL | 1.10 | 0-33 |
| 145 | Shield One Shot | UAL | 0.83 | 0-25 |
| 146 | Sword Aerial A | UAL | 0.40 | 0-12 |
| 147 | Sword Aerial A Recovery | UAL | 0.43 | 0-13 |
| 148 | Sword Aerial B | UAL | 0.57 | 0-17 |
| 149 | Sword Aerial Combo | UAL | 1.00 | 0-30 |
| 150 | Sword Aerial Idle | UAL | 1.07 | 0-32 |
| 151 | Sword Attack | UAL | 1.53 | 0-46 |
| 152 | Sword Attack Root Motion | UAL | 1.53 | 0-46 |
| 153 | Sword Attack Standing | UAL | 1.53 | 0-46 |
| 154 | Sword Block | UAL | 1.23 | 0-37 |
| 155 | Sword Dash Root Motion | UAL | 1.57 | 0-47 |
| 156 | Sword Enter | UAL | 1.30 | 0-39 |
| 157 | Sword Exit | UAL | 1.30 | 0-39 |
| 158 | Sword Ground Pound Root Motion | UAL | 1.17 | 0-35 |
| 159 | Sword Heavy A | UAL | 0.73 | 0-22 |
| 160 | Sword Heavy A Recovery | UAL | 1.00 | 0-30 |
| 161 | Sword Heavy B | UAL | 0.50 | 0-15 |
| 162 | Sword Heavy B Recovery | UAL | 0.77 | 0-23 |
| 163 | Sword Heavy C | UAL | 0.70 | 0-21 |
| 164 | Sword Heavy C Recovery | UAL | 0.57 | 0-17 |
| 165 | Sword Heavy Combo | UAL | 4.33 | 0-130 |
| 166 | Sword Heavy D | UAL | 2.33 | 0-70 |
| 167 | Sword Idle | UAL | 1.67 | 0-50 |
| 168 | Sword Light A | UAL | 0.37 | 0-11 |
| 169 | Sword Light A Recovery | UAL | 0.50 | 0-15 |
| 170 | Sword Light B | UAL | 0.43 | 0-13 |
| 171 | Sword Light B Recovery | UAL | 0.57 | 0-17 |
| 172 | Sword Light C | UAL | 0.87 | 0-26 |
| 173 | Sword Light C Recovery | UAL | 0.70 | 0-21 |
| 174 | Sword Light Combo | UAL | 3.40 | 0-102 |
| 175 | Sword Light D | UAL | 1.67 | 0-50 |
| 176 | Sword Regular A | UAL | 0.43 | 0-13 |
| 177 | Sword Regular A Recovery | UAL | 0.97 | 0-29 |
| 178 | Sword Regular B | UAL | 0.53 | 0-16 |
| 179 | Sword Regular B Recovery | UAL | 1.03 | 0-31 |
| 180 | Sword Regular C | UAL | 2.00 | 0-60 |
| 181 | Sword Regular Combo | UAL | 3.00 | 0-90 |
| 182 | Sword Upper Cut Root Motion | UAL | 0.70 | 0-21 |
| 183 | Bandage | UAL | 0.67 | 0-20 |
| 184 | Chest Open | UAL | 1.37 | 0-41 |
| 185 | Consume | UAL | 1.33 | 0-40 |
| 186 | Counter Angry | UAL | 2.00 | 0-60 |
| 187 | Counter Enter | UAL | 1.17 | 0-35 |
| 188 | Counter Exit | UAL | 1.17 | 0-35 |
| 189 | Counter Give | UAL | 4.37 | 0-131 |
| 190 | Counter Idle | UAL | 2.67 | 0-80 |
| 191 | Counter Show | UAL | 4.67 | 0-140 |
| 192 | Drink | UAL | 3.00 | 0-90 |
| 193 | Driving | UAL | 1.67 | 0-50 |
| 194 | Farm Harvest | UAL | 2.50 | 0-75 |
| 195 | Farm Picking Tree | UAL | 2.23 | 0-67 |
| 196 | Farm Plant Seed | UAL | 2.77 | 0-83 |
| 197 | Farm Scattering Seeds | UAL | 1.57 | 0-47 |
| 198 | Farm Watering | UAL | 3.80 | 0-114 |
| 199 | Fish Cast | UAL | 1.83 | 0-55 |
| 200 | Fish Cast Idle | UAL | 2.33 | 0-70 |
| 201 | Fish Overhand Idle | UAL | 2.33 | 0-70 |
| 202 | Fish Reel | UAL | 2.30 | 0-69 |
| 203 | Fish Reel Failed | UAL | 2.77 | 0-83 |
| 204 | Fixing Kneeling | UAL | 5.20 | 0-156 |
| 205 | Ground Sit Enter | UAL | 2.50 | 0-75 |
| 206 | Ground Sit Exit | UAL | 2.17 | 0-65 |
| 207 | Ground Sit Idle | UAL | 1.33 | 0-40 |
| 208 | Interact | UAL | 2.00 | 0-60 |
| 209 | Kip Up | UAL | 1.17 | 0-35 |
| 210 | Lay To Idle | UAL | 1.53 | 0-46 |
| 211 | Mining | UAL | 0.90 | 0-27 |
| 212 | Pick Up Kneeling | UAL | 1.93 | 0-58 |
| 213 | Pick Up Table | UAL | 0.83 | 0-25 |
| 214 | Push | UAL | 2.67 | 0-80 |
| 215 | Push Enter | UAL | 0.67 | 0-20 |
| 216 | Push Exit | UAL | 1.20 | 0-36 |
| 217 | Sitting Enter | UAL | 1.30 | 0-39 |
| 218 | Sitting Exit | UAL | 1.03 | 0-31 |
| 219 | Sitting Idle | UAL | 1.67 | 0-50 |
| 220 | Sitting Idle 02 | UAL | 2.50 | 0-75 |
| 221 | Sitting Idle 03 | UAL | 4.17 | 0-125 |
| 222 | Sitting Nodding | UAL | 2.93 | 0-88 |
| 223 | Sitting Talking | UAL | 2.93 | 0-88 |
| 224 | Tree Chopping | UAL | 0.97 | 0-29 |
| 225 | Celebration | UAL | 4.00 | 0-120 |
| 226 | Crying | UAL | 4.83 | 0-145 |
| 227 | Dance | UAL | 1.00 | 0-30 |
| 228 | Monster Transformation | UAL | 2.23 | 0-67 |
| 229 | Surprise | UAL | 2.47 | 0-74 |
| 230 | Yes | UAL | 2.50 | 0-75 |
| 231 | Zombie Bite | UAL | 1.50 | 0-45 |
| 232 | Zombie Idle | UAL | 1.33 | 0-40 |
| 233 | Zombie Run Backward | UAL | 0.73 | 0-22 |
| 234 | Zombie Run Backward Left | UAL | 0.73 | 0-22 |
| 235 | Zombie Run Backward Right | UAL | 0.73 | 0-22 |
| 236 | Zombie Run Forward | UAL | 0.73 | 0-22 |
| 237 | Zombie Run Forward Left | UAL | 0.73 | 0-22 |
| 238 | Zombie Run Forward Right | UAL | 0.73 | 0-22 |
| 239 | Zombie Run Left | UAL | 0.73 | 0-22 |
| 240 | Zombie Run Right | UAL | 0.73 | 0-22 |
| 241 | Zombie Scratch | UAL | 1.80 | 0-54 |
| 242 | Zombie Spawn | UAL | 2.83 | 0-85 |
| 243 | Zombie Walk Backward | UAL | 1.33 | 0-40 |
| 244 | Zombie Walk Backward Left | UAL | 1.33 | 0-40 |
| 245 | Zombie Walk Backward Right | UAL | 1.33 | 0-40 |
| 246 | Zombie Walk Forward | UAL | 1.33 | 0-40 |
| 247 | Zombie Walk Forward Left | UAL | 1.33 | 0-40 |
| 248 | Zombie Walk Forward Right | UAL | 1.33 | 0-40 |
| 249 | Zombie Walk Left | UAL | 1.33 | 0-40 |
| 250 | Zombie Walk Right | UAL | 1.33 | 0-40 |
| 251 | Back Flip | UAL | 1.93 | 0-58 |
| 252 | Death 01 | UAL | 2.40 | 0-72 |
| 253 | Death 02 | UAL | 2.47 | 0-74 |
| 254 | Spell Double Enter | UAL | 0.63 | 0-19 |
| 255 | Spell Double Exit | UAL | 0.63 | 0-19 |
| 256 | Spell Double Idle | UAL | 2.10 | 0-63 |
| 257 | Spell Double Shoot | UAL | 0.27 | 0-8 |
| 258 | Spell Simple Enter | UAL | 0.53 | 0-16 |
| 259 | Spell Simple Exit | UAL | 0.43 | 0-13 |
| 260 | Spell Simple Idle | UAL | 2.10 | 0-63 |
| 261 | Spell Simple Shoot | UAL | 0.50 | 0-15 |
| 262 | Anrico Sitting 02 | MakeHuman pose | 1.00 | 0-30 |
| 263 | Anrico Sitting 03 | MakeHuman pose | 1.00 | 0-30 |
| 264 | Anrico Sitting 04 | MakeHuman pose | 1.00 | 0-30 |
| 265 | Anrico Sitting 07 | MakeHuman pose | 1.00 | 0-30 |
| 266 | Anrico Sitting 10 | MakeHuman pose | 1.00 | 0-30 |
| 267 | Anrico Standing 10 | MakeHuman pose | 1.00 | 0-30 |
| 268 | Anrico Standing 11 | MakeHuman pose | 1.00 | 0-30 |
| 269 | Benchmark | MakeHuman pose | 1.00 | 0-30 |
| 270 | Blindsaypatten David | MakeHuman pose | 1.00 | 0-30 |
| 271 | Culturalibre Cl Fight 01 | MakeHuman pose | 1.00 | 0-30 |
| 272 | Culturalibre Falling | MakeHuman pose | 1.00 | 0-30 |
| 273 | Culturalibre Floating | MakeHuman pose | 1.00 | 0-30 |
| 274 | Culturalibre Gun | MakeHuman pose | 1.00 | 0-30 |
| 275 | Culturalibre Gun 2 Female | MakeHuman pose | 1.00 | 0-30 |
| 276 | Culturalibre Gun 2 Male | MakeHuman pose | 1.00 | 0-30 |
| 277 | Culturalibre Gun 3 | MakeHuman pose | 1.00 | 0-30 |
| 278 | Culturalibre Neck Grab | MakeHuman pose | 1.00 | 0-30 |
| 279 | Culturalibre Spider Man 2 | MakeHuman pose | 1.00 | 0-30 |
| 280 | Culturalibre Warhammer 01 | MakeHuman pose | 1.00 | 0-30 |
| 281 | Culturalibre Wizard With Sceptre 1 | MakeHuman pose | 1.00 | 0-30 |
| 282 | Culturalibre Wizard With Sceptre 2 | MakeHuman pose | 1.00 | 0-30 |
| 283 | Culturalibre Wizard With Sceptre 3 | MakeHuman pose | 1.00 | 0-30 |
| 284 | Drednicolson Arms Akimbo | MakeHuman pose | 1.00 | 0-30 |
| 285 | Drednicolson Prostrate | MakeHuman pose | 1.00 | 0-30 |
| 286 | Elvs Epic Haute Couture 1 | MakeHuman pose | 1.00 | 0-30 |
| 287 | Elvs Epic Haute Couture 2 | MakeHuman pose | 1.00 | 0-30 |
| 288 | Elvs Gymnastic Pose 1 | MakeHuman pose | 1.00 | 0-30 |
| 289 | Elvs Gymnastic Pose 2 | MakeHuman pose | 1.00 | 0-30 |
| 290 | Elvs Pushups 1 | MakeHuman pose | 1.00 | 0-30 |
| 291 | Elvs Super Him Standing Pose 1 | MakeHuman pose | 1.00 | 0-30 |
| 292 | Elvs Super Him Standing Pose 2 | MakeHuman pose | 1.00 | 0-30 |
| 293 | Elvs What Have I Done | MakeHuman pose | 1.00 | 0-30 |
| 294 | Elvs Yoga Cobra Pose 1 | MakeHuman pose | 1.00 | 0-30 |
| 295 | Elvs Yoga Star Pose 1 | MakeHuman pose | 1.00 | 0-30 |
| 296 | Elvs Yoga Triangle Pose 1 | MakeHuman pose | 1.00 | 0-30 |
| 297 | Fight 01 | MakeHuman pose | 1.00 | 0-30 |
| 298 | Fight 02 | MakeHuman pose | 1.00 | 0-30 |
| 299 | Fight 03 | MakeHuman pose | 1.00 | 0-30 |
| 300 | Fight 04 | MakeHuman pose | 1.00 | 0-30 |
| 301 | Fly 01 | MakeHuman pose | 1.00 | 0-30 |
| 302 | Fly 02 | MakeHuman pose | 1.00 | 0-30 |
| 303 | Gpedroso Boxing | MakeHuman pose | 1.00 | 0-30 |
| 304 | Gpedroso Hadouken | MakeHuman pose | 1.00 | 0-30 |
| 305 | Gpedroso Ninja Focus | MakeHuman pose | 1.00 | 0-30 |
| 306 | Gpedroso Peace And Love | MakeHuman pose | 1.00 | 0-30 |
| 307 | Gpedroso Spider Man | MakeHuman pose | 1.00 | 0-30 |
| 308 | Gpedroso Standing Posing | MakeHuman pose | 1.00 | 0-30 |
| 309 | Gschabau Snorkel Diver 01 | MakeHuman pose | 1.00 | 0-30 |
| 310 | Gym 01 | MakeHuman pose | 1.00 | 0-30 |
| 311 | Henny Cyclist 2 | MakeHuman pose | 1.00 | 0-30 |
| 312 | Henny Cyclist Normal | MakeHuman pose | 1.00 | 0-30 |
| 313 | Henny Cyclist Normal Tough | MakeHuman pose | 1.00 | 0-30 |
| 314 | Henny Cyclist Talking | MakeHuman pose | 1.00 | 0-30 |
| 315 | Henny Cyclist Waving | MakeHuman pose | 1.00 | 0-30 |
| 316 | Henny Pose For A Race Bicycle | MakeHuman pose | 1.00 | 0-30 |
| 317 | Jjones Leaning On Counter Hands Folded | MakeHuman pose | 1.00 | 0-30 |
| 318 | Jjones Sisyphus | MakeHuman pose | 1.00 | 0-30 |
| 319 | Joachip Tennis Serve | MakeHuman pose | 1.00 | 0-30 |
| 320 | Milkman Sit 01a | MakeHuman pose | 1.00 | 0-30 |
| 321 | Milkman Swinging 01 | MakeHuman pose | 1.00 | 0-30 |
| 322 | Mindfront Playing Guitar | MakeHuman pose | 1.00 | 0-30 |
| 323 | Mindfront Sitting In Armchair Holding Wine Glass | MakeHuman pose | 1.00 | 0-30 |
| 324 | Mindfront Standing Holding Wine Glass | MakeHuman pose | 1.00 | 0-30 |
| 325 | Punkduck Cyclist 01 | MakeHuman pose | 1.00 | 0-30 |
| 326 | Punkduck Freestyle 01 | MakeHuman pose | 1.00 | 0-30 |
| 327 | Punkduck Hand On Shoulder 01 | MakeHuman pose | 1.00 | 0-30 |
| 328 | Punkduck Hand On Shoulder 02 | MakeHuman pose | 1.00 | 0-30 |
| 329 | Punkduck Hand On Shoulder 03 | MakeHuman pose | 1.00 | 0-30 |
| 330 | Punkduck Pd Fashion 01 | MakeHuman pose | 1.00 | 0-30 |
| 331 | Punkduck Pd Fashion 02 | MakeHuman pose | 1.00 | 0-30 |
| 332 | Punkduck Pd Fashion Handbag | MakeHuman pose | 1.00 | 0-30 |
| 333 | Punkduck Snorkel Diver 02 | MakeHuman pose | 1.00 | 0-30 |
| 334 | Punkduck Tennis Forehand Volley | MakeHuman pose | 1.00 | 0-30 |
| 335 | Punkduck Tennis Serve Wind Up | MakeHuman pose | 1.00 | 0-30 |
| 336 | Punkduck Tennis Two Handed Backhand | MakeHuman pose | 1.00 | 0-30 |
| 337 | Punkduck Train Departure | MakeHuman pose | 1.00 | 0-30 |
| 338 | Run 01 | MakeHuman pose | 1.00 | 0-30 |
| 339 | Sit 01 | MakeHuman pose | 1.00 | 0-30 |
| 340 | Sohh Posing 1 | MakeHuman pose | 1.00 | 0-30 |
| 341 | Sohh Posing 2 | MakeHuman pose | 1.00 | 0-30 |
| 342 | Sohh Posing 3 | MakeHuman pose | 1.00 | 0-30 |
| 343 | Sohh Posing 4 | MakeHuman pose | 1.00 | 0-30 |
| 344 | Sohh Posing 5 | MakeHuman pose | 1.00 | 0-30 |
| 345 | Sohh Posing 6 | MakeHuman pose | 1.00 | 0-30 |
| 346 | Sohh Sohh Embarrassed | MakeHuman pose | 1.00 | 0-30 |
| 347 | Sohh Standing 1 | MakeHuman pose | 1.00 | 0-30 |
| 348 | Sohh Standing 2 | MakeHuman pose | 1.00 | 0-30 |
| 349 | Spreadcore Arms Up Pose 001 | MakeHuman pose | 1.00 | 0-30 |
| 350 | Spreadcore Summoning Pose | MakeHuman pose | 1.00 | 0-30 |
| 351 | Standing 01 | MakeHuman pose | 1.00 | 0-30 |
| 352 | Standing 02 | MakeHuman pose | 1.00 | 0-30 |
| 353 | Standing 03 | MakeHuman pose | 1.00 | 0-30 |
| 354 | Standing 04 | MakeHuman pose | 1.00 | 0-30 |
| 355 | Standing 05 | MakeHuman pose | 1.00 | 0-30 |
| 356 | Standing 06 | MakeHuman pose | 1.00 | 0-30 |
| 357 | Sweetan 008 Sitting Pose | MakeHuman pose | 1.00 | 0-30 |
| 358 | Tpose | MakeHuman pose | 1.00 | 0-30 |
| 359 | Wolgade Sit On Ground 01 | MakeHuman pose | 1.00 | 0-30 |
| 360 | Xhado 84 Sitting Floor 3 | MakeHuman pose | 1.00 | 0-30 |
