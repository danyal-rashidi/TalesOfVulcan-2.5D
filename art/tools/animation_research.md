<!-- 2026-11-06 web research: six searches (105 items) ranked for this pipeline. Licences and prices as found; re-check before relying on one. -->
# Animation pipeline research: ranked report

Scope: the problems are jumbled fast attacks (cape and arms) at 8-16 px, body proportions and look drifting between moves, tone crawl between frames, and an AI look. The game is commercial, and the hardware is an RTX 3060 12 GB with 24 GB of WSL memory. Duplicates are merged. I re-checked four claims at the source and marked each "(checked)".

---

## 1. Do first

### 1. Cut attacks to key poses and give each frame its own hold time
- **What:** keep about 6 drawings per attack: anticipation, smear, follow-through and recover. Throw away the rest of the Seedance frames and give each kept frame a different duration. Starting times:
  - Sword: 100/50/50/50/100/50 ms. Spear: 200/50/50/50/150/50. Hammer: 250/50/50/50/300/100.
  - Sources: https://www.slynyrd.com/blog/2025/5/23/pixelblog-56-top-down-character-attack-animation and https://lost-worlds.neocities.org/blog/2024/10/20/fire-emblem-animation/ (Fire Emblem: anticipation held about 10 ticks at 60 fps, contact 8 or more, swing 1-1-2).
  - Dead Cells shipped this: key poses with as few frames as possible, "Never in-between", and VFX carries the impact. https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-
  - Guilty Gear Xrd did the same with limited animation: every frame is a key and smooth in-betweening was dropped. https://gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The
- **Pipeline step:** add frame selection plus a duration list to the sheet export. In Godot, use `SpriteFrames.add_frame(anim, tex, duration)` (https://docs.godotengine.org/en/stable/classes/class_spriteframes.html) instead of a fixed fps.
- **Gain:** the largest of any item here for jumbled attacks, and no new art is needed. The eye only settles on held frames, so the 1-2 messy swing frames stop being noticed.
- **Risk:** low. Too much anticipation feels like input lag, and too much recovery feels sticky (Slynyrd 9).

### 2. One on-palette smear frame in place of the 2-4 jumbled swing frames
- **What:** generate one smear per swing in numpy. Measure how far the cape or arm moved between the anticipation key and the follow-through key (centroid shift), then draw a stretch trail along the arc, coloured from that material's palette ramp. Don't add a smear to anticipation or recover frames.
- **Sources:** the method follows MalloyTheDev's smear_frame tool (https://glama.ai/mcp/servers/MalloyTheDev/aseprite-mcp). It has no licence, so reimplement it rather than copy it. The craft rules are at https://slynyrd.com/blog/2018/9/8/pixelblog-9-melee-attacks ("A single smear frame is usually enough", and it follows the natural arc).
- **Pipeline step:** new step in sprite_doctor, run after key selection (item 1) and before the outline pass.
- **Gain:** fast motion that reads as hand-drawn instead of noise.
- **Risk:** medium. A bad arc looks worse than the noise it replaces. Keep a hand-painted fallback for the 2-3 worst attacks.

### 3. PixelOE outline expansion before the shrink, then compare downscalers
- **What:** run PixelOE's contrast-weighted erode/dilate on the full-size frame so thin cape and arm strokes get thicker before the 46-54 px shrink. Then compare its `contrast` and `k-centroid` modes, and unfake's `dominant` mode with `fixed_palette`, against our own shrink on attack frames.
  - PixelOE: https://github.com/KohakuBlueleaf/PixelOE. `pip install pixeloe`, Apache-2.0 (checked). It has a separate `pixeloe.outline` CLI command and an OutlineExpansion ComfyUI node, so outline expansion can feed our own shrink. Turn off its colour matching (`--no_color_matching`), because our palette lock runs afterwards.
  - unfake: https://github.com/painebenjamin/unfake.py. MIT, takes a fixed palette (`--palette file.txt`) (checked).
  - K-Centroid idea: https://github.com/Astropulse/pixeldetector (MIT). Each output cell takes the colour of its main cluster (k-means with 2 centroids), never a mud average. About 10 lines of numpy if we want it inside our own shrink.
- **Pipeline step:** replaces or sits in front of the shrink.
- **Gain:** thin dark strokes survive as solid 1-2 px shapes instead of speckle. This is the root cause of the jumble.
- **Risk:** low to medium. Outlines get heavier overall, which changes the look against the master, so tune the expansion strength per move.

### 4. Palette fitted per move, with frame-to-frame hysteresis and ramp-constrained snapping
- **What:**
  - (a) Fit or confirm the palette and skin match once per move (or per character), never per frame. This is the design of proper-pixel-art (https://github.com/KennethJAllen/proper-pixel-art) and Super Pyxelate's Vid mode (https://github.com/sedthh/pyxelate).
  - (b) Hysteresis, after Roytman & Gotsman 1995 (https://researchwith.njit.edu/en/publications/dynamic-color-quantization-of-video-sequences/): carry the previous frame's palette index forward along the flow, and switch only if the new colour wins by a margin. Pyxelate's keyframe/sensitivity scheme is the same idea for still areas.
  - (c) Snap each pixel to the nearest step on its own material ramp, not to the nearest colour in the whole palette, so skin cannot flip to cape colours. Ramp rules: https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes
- **Pipeline step:** changes to the existing palette and skin-tone step. It is a few lines, with no new dependency.
- **Gain:** the main fix for tone crawl, especially on the still torso and head while the arms move.
- **Risk:** hysteresis can freeze a wrong colour on parts that move. Turn it off where the flow is uncertain (item 6) or the motion is large.

### 5. Deflicker the full-size clip before shrinking
- **What:** cheap baseline first: ffmpeg `deflicker` (moving average, size 2-129) on the cut full-size frames (https://ffmpeg.org/ffmpeg-filters.html). If crawl survives that, use All-In-One-Deflicker (https://github.com/ChenyangLEI/All-In-One-Deflicker):
  - Apache-2.0 code, about 3 GB of GPU memory, 200 frames or fewer.
  - Its README names AI-generated video and old cartoons among the flicker types it was tested on.
  - It wants a conda env with torch 1.12 and CUDA 11. Check the terms on the separately downloaded weights.
- **Pipeline step:** new step between cutting frames and shrinking.
- **Gain:** brightness pulsing never reaches the palette step, so there are fewer near-tie palette picks.
- **Risk:** low. Never run it on 48 px sheets.

### 6. Swap the hand-written scipy flow for OpenCV DIS now, then SEA-RAFT
- **What:**
  - OpenCV DIS: `cv2.DISOpticalFlow_create(PRESET_MEDIUM)`, from `pip install opencv-python`, Apache-2.0, CPU. https://github.com/opencv/opencv/blob/4.x/modules/video/include/opencv2/video/tracking.hpp
  - SEA-RAFT next: BSD-3, fits the 3060, and outputs a per-pixel uncertainty map. https://github.com/princeton-vl/SEA-RAFT
  - GMFlow from UniMatch (MIT, https://github.com/autonomousvision/unimatch) is the alternative to SEA-RAFT. It had the lowest error on cartoons in AnimeRun.
- **Pipeline step:** replaces the flow in key-frame shape carrying and in walk in-betweens. Compute flow on full-size frames, then shrink the flow field. Where uncertainty is high, fall back to the key frame.
- **Gain:** steadier carried shapes on walks and idles.
- **Risk:** AnimeRun (https://lisiyao21.github.io/projects/AnimeRun) measured about 30 px error on motion above 50 px and about 8x the error in occluded areas. Fast attacks are exactly that case, so flow will not fix them. Items 1 and 2 have to.

### 7. Pin identity at generation: Seedance 2.0 first-last frame plus reference-to-video
- **What:** for each re-generated move:
  - Give two on-model key poses as the first and last frame, which pins proportions at both ends.
  - Or use R2V with the master character sheet (front, three-quarter and profile, full body, neutral light) as the subject reference, and a rig render as the motion reference.
  - Put the same "Character DNA" text block in every prompt and change only the action.
  - Sources: https://docs.comfy.org/tutorials/api-nodes/bytedance/seedance-2-0 and https://byteplus.com/en/topic/578660
- **Pipeline step:** replaces plain image-to-video from one start picture.
- **Gain:** the direct fix for squat runs and the bigger head. It costs less than any local video model.
- **Risk:** it costs credits. Check the Higgsfield balance and ask before spending. I did not check whether Higgsfield exposes the Seedance 2.0 FLF/R2V modes.

### 8. Game-side cover in Godot
- **Lighting:** use our normal maps through CanvasTexture, with a ~15-line custom `light()` that bands N·L into 2-3 steps mapped to palette ramps, and floor `LIGHT_VERTEX` to the pixel grid (https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html, https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html). Write it ourselves: commenters on the ready-made rim-light shaders say they break in Godot 4.
- **Outline:** a 1 px in-engine outline from the CC0 Occlusion Outline shader (https://godotshaders.com/shader/occlusion-outline-for-godot-4/), which also shows the player behind houses.
- **Scaling:** integer scale with viewport stretch (https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).
- **Palette swap:** KoBeWi palette swap, MIT (https://github.com/KoBeWi/Godot-Palette-Swap-Shader), for hit flash and tints, and to fix one off tone across every frame at once.
- **Gain:** the same light and the same outline on every frame mask leftover crawl and ragged edges. Banded light reads as hand shading.
- **Risk:** low. Check the green channel of our Depth Anything normals: Godot expects X+ Y+ Z+.

---

## 2. Worth a test (ranked)

1. **Wan2.1-Fun-V1.1-1.3B-Control**, driven by 3D rig depth or pose plus the master picture. https://huggingface.co/alibaba-pai/Wan2.1-Fun-V1.1-1.3B-Control
   - Apache-2.0. VideoX-Fun lists the RTX 3060 12G as a verified GPU. The model is 19 GB on disk and the library wants about 60 GB free.
   - It is the best local route to "the skeleton sets the proportions, the picture sets the look" for every move.
2. **ToonCrafter** for attack in-betweens between two approved keys. https://github.com/Doubiiu/ToonCrafter
   - Code is Apache-2.0, and the Hugging Face card (https://huggingface.co/Doubiiu/ToonCrafter) says the weights are Apache-2.0. Output is 512x320, up to 16 frames.
   - The official model needs 24-27 GB. Kijai's fp16 ComfyUI checkpoint is listed at 12 GB, and the README says the community got it to about 10 GB (checked). It is tight on the 3060.
   - Sketch guidance: https://github.com/mattyamonaca/ToonCrafter_with_SketchGuidance (Apache-2.0, fp16 copy at https://huggingface.co/svjack/ToonCrafter_with_SketchGuidance_fp16).
   - Licence flag: the DynamiCrafter base terms need a check. The kijai wrapper quotes "personal/research/non-commercial".
3. **Practical-RIFE 4.25** (https://github.com/hzwer/Practical-RIFE) for walk and idle in-betweens at full size. The licence is MIT, models included, and the author says anime scenes improved.
   - If RIFE breaks on large gaps: FILM (https://github.com/google-research/frame-interpolation, Apache, archived) or GMFSS_Fortuna (https://github.com/98mxr/GMFSS_Fortuna, MIT code, weight terms unstated).
   - Side-by-side harness: https://github.com/Fannovel16/ComfyUI-Frame-Interpolation (MIT pack; each model keeps its own licence).
4. **Qwen-Image-Edit-2509 in 4-bit through Nunchaku**, to repair off-model key frames and make on-model start and end pictures for item 7. https://huggingface.co/Qwen/Qwen-Image-Edit-2509 and https://github.com/nunchaku-tech/nunchaku
   - Apache-2.0. Not tested on a 3060.
5. **EbSynth** to push one hand-fixed key onto its neighbours at full size. https://github.com/jamriska/ebsynth
   - The code is public domain and has a CUDA backend.
   - The PatchMatch patent US 8,861,869 (Adobe) is listed as active, with expected expiry on 2030-08-16 (checked on Google Patents). Making assets offline is the lower-risk case, but get a legal opinion before relying on it.
   - Reimplement the keyframe blending ourselves. Rerender's video_blend.py is non-commercial.
6. **Content-adaptive downscaling** (Kopf, Shamir, Peers 2013, https://johanneskopf.de/publications/downscaling/): port the pseudocode to numpy and warm-start each frame from the previous one along the flow.
   - Quick proxy first: unfake's `content-adaptive` mode. Its README cites Kopf-Lischinski 2011 "Depixelizing", but the link goes to a downscaling page (checked), so it is unclear which method it follows.
7. **VACE 1.3B masked video-to-video**, to repaint only the cape and arm region of a clip. https://github.com/ali-vilab/VACE
   - Apache-2.0. Avoid the VACE-LTX variant (RAIL-M).
8. **Character LoRA.** https://github.com/kohya-ss/musubi-tuner (Apache-2.0; image LoRAs fit in 12 GB, video LoRAs are borderline) or https://github.com/ostris/ai-toolkit (MIT; never train on FLUX.1-dev).
9. **Pixel Art XL LoRA** added to the existing SDXL + ControlNet + IP-Adapter pose-guided recipe. https://huggingface.co/nerijs/pixel-art-xl (CreativeML OpenRAIL-M).
   - Base stack, all Apache-2.0: https://github.com/tencent-ailab/IP-Adapter, https://huggingface.co/xinsir/controlnet-union-sdxl-1.0 and https://github.com/IDEA-Research/DWPose
10. **Video Stream Consistency**, which takes the original and processed versions and outputs a steady video, with a strength setting. https://github.com/MaxReimann/video-stream-consistency
    - GPL-2.0, so use it only as an offline tool. It needs a C++/CUDA/Qt build.
    - Lai 2018 (https://github.com/phoenix104104/fast_blind_video_consistency, MIT) does the same job but pins PyTorch 0.4 and FlowNet2. Treat it as a port, not a tool.
11. **Layered Neural Atlases** (https://github.com/ykasten/layered-neural-atlases, MIT): colour-match one atlas to the master per walk or idle. It breaks on attacks.
12. **Wan2.2-Animate-14B, QuantStack GGUF Q4_K_S at 10.6 GB** (https://huggingface.co/Wan-AI/Wan2.2-Animate-14B, https://huggingface.co/QuantStack/Wan2.2-Animate-14B-GGUF), run through https://github.com/kijai/ComfyUI-WanVideoWrapper with block swap.
    - Apache-2.0. Slow, with no 3060 timing anywhere.
13. **Index-AniSora V3.1**, the 12 GB build on ModelScope, which can pin the first, middle and last frames. https://github.com/bilibili/Index-anisora (Apache-2.0 since mid-2025; check the specific checkpoint's card).
14. **FLUX.2-klein-4B with the pixel-art LoRA**, to repaint a bad frame on-model. https://huggingface.co/limbicnation/pixel-art-lora
    - Both are Apache-2.0. It needs about 13 GB, so CPU offload. Use only the 4B model; the 9B is non-commercial.
15. **Line-art in-betweening for attacks**, all MIT: https://github.com/Tian-one/tps-inbetween, https://github.com/none-master/SAIN and https://github.com/xiaoyu258/Inbetweening (two colour keys plus our sketch of the middle pose).
    - Skeleton-driven: https://github.com/kbrodt/inbetweening. Code is MIT, the weights have no licence.
16. **AnimeInterp** (https://github.com/lisiyao21/AnimeInterp, MIT, PyTorch 0.4-1.1). Its idea of matching flat colour regions between frames could replace per-pixel flow inside our tool.
    - EISAI (https://github.com/ShuhongChen/eisai-anime-interpolator) is AGPL, offline use only. Its LPIPS-plus-line-chamfer metric is worth adding to the consistency check.
17. **SVD-based models: weights are free only under US$1M a year in revenue** (Stability Community Licence, https://stability.ai/community-license-agreement).
    - AniDoc (https://github.com/yihao-meng/AniDoc, about 14 GB) repaints frames from line art in the master's colours.
    - MimicMotion (https://github.com/Tencent/MimicMotion) is pose-driven.
18. **Sprite Sheet Diffusion** (https://github.com/chenganhsieh/Sprite-Sheet-Diffusion): MIT code, CC0 data, an SD1.5 base and about 16 GB. Mainly useful as a fine-tune template.
    - Its base, https://github.com/MooreThreads/Moore-AnimateAnyone, is Apache-2.0 and ships training code.
19. **Laigter normal maps** (https://github.com/azagaya/laigter, GPL-3.0 tool), blended with Depth Anything Small for crisp edge bevels. The claim that its output maps are ours to use is unverified (from itch.io comments).
20. **SMEAR Blender add-on** (https://github.com/MoStyle/SMEAR, GPL, offline). Render one smear in-between from the 3D Vulcan rig as a shape guide for item 2.
21. **Phantom 1.3B** (https://github.com/Phantom-video/Phantom, Apache-2.0), for a new move with no rig render. Low priority.

---

## 3. Pay services

- **PixelLab** (https://www.pixellab.ai/pixellab-api, https://www.pixellab.ai/docs/tools/animate-with-skeleton)
  - API, estimated per call: animate-with-text-v3 $0.022 (32 px, 4 frames) to $0.042 (128 px, 16 frames); skeleton-v3 $0.044-0.062; estimate-skeleton $0.005; 8-rotations-v3 at 64 px $0.034; interpolation-v2 $0.08; pixminimax $0.023-0.079.
  - Plans, from a third-party guide and unverified: Apprentice $12, Artisan $24, Architect $50 a month, plus a 40-generation trial.
  - ToS (https://www.pixellab.ai/termsofservice): you own the output, commercial use is OK, and you may not train other models on it.
  - "Freeze 2, generate 1" works as a pixel-level in-betweener for a broken swing frame, and it has a "fixed head" option.
  - Canvas sizes are 16/32/64/128/256 px square, so pad our sprites to 64.
  - MCP: `claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H 'Authorization: Bearer TOKEN'`.
  - Best paid fallback for the 2-3 attacks that the filters can't fix.
- **Retro Diffusion API** (https://github.com/Retro-Diffusion/api-examples, https://replicate.com/retro-diffusion/rd-animation/readme)
  - Prices: advanced animation $0.14, custom_action or subtle_motion $0.25, rotate $0.10, prompt animations $0.07-0.25. The Aseprite extension is $65 ($20 Lite) and can't animate.
  - `four_angle_walking` outputs native 48 px.
  - Sources conflict on whether `input_image` is used as the start frame; Scenario's docs say it is not, so expect drift from the master.
  - Commercial terms are not verified. Read the retrodiffusion.ai ToS first.
- **Seedance 2.0 FLF/R2V** (item 7), through Higgsfield, BytePlus or ComfyUI API nodes. Pay in credits; I have no prices. Check output terms per provider.
- **Kling 3.0 Element Library** (https://kling.ai/quickstart/klingai-element-library-3-user-guide): bind 2-4 character pictures to the start and end frames. Multi-view costs 5 credits after 3 free uses a day. Commercial terms not checked.
- **ToonComposer** (https://github.com/TencentARC/ToonComposer, MIT plus Apache Wan): about 57 GB, so only on the Hugging Face Space or a rented GPU.

---

## 4. Craft rules (turn into checks or tool steps)

1. **Attack budget:** about 6 drawings. If more than 8 distinct frames go into one attack, flag the sheet. Sources: Slynyrd 56, Fire Emblem (14 drawings make 43 ticks).
2. **Uneven timing is required:** reject an attack whose frame durations are all equal ("floaty"). Hold the anticipation about 150-250 ms and the contact or follow-through about 100-300 ms. Show smears for 17-50 ms.
3. **Never in-between:** add frames only before or after a key, never in the middle of a swing (Dead Cells).
4. **Smear:** one per swing, along the arc. Use palette ramp gradation, no new hues, and none on anticipation or recover frames.
5. **Follow-through:** one frame at full reach, 1 px further into the target, held longer. After recovery, overshoot by shifting the stance 1 px for one frame.
6. **Each key is its own drawing:** correct head size and squash on each key on its own, and let the consistency check correct per key instead of trusting smooth motion (Guilty Gear Xrd).
7. **Weapon in the same hand, same poses across directions:** add a check across the front, side and back sheets.
8. **Sub-pixel motion only on idle and slow bob:** one ramp step of edge blending, never on the eyes or face, never a new hue (https://tinywarriorgames.com/?p=434). Add this as a guard in the in-between step.
9. **Outline checks:** 1 px thick, so flag doubled spots. Staircase run lengths should change by about 1 per step (5-4-3-2-1). Recolour an orphan pixel to its most common neighbour, the Adopt Pixels rule (https://tinywarriorgames.com/2018/12/07/game-development-pixel-line-art-cleanup/, https://astropulse.itch.io/adopt-pixels).
10. **Palette ramps:** about 9 swatches, a hue shift of at most +20° per step, saturation peaking mid-ramp, and never high saturation together with high brightness. Snap per material ramp. Tool: https://github.com/chickensoft-games/PalettePainter (MIT).
11. **Palette per move or character, never per frame.** Hysteresis on index changes (item 4).
12. **Pixelate after animating:** keep start pictures at full resolution. This comes from https://marcovolino.github.io/docs/posters/2025-wong-cvmp.pdf; its conclusion is from a search snippet and was never read in full.
13. **Godot:** Nearest filter, integer scale, viewport stretch, pixel-snapped light, normal maps in X+ Y+ Z+.
14. **Hand touch-up of attack keys is normal:** Dead Cells, Eastward (https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures), Blasphemous and Owlboy all touch up or hand-draw keys, and none found a fully automatic fix. Study reference only: https://saint11.art/blog/pixel-art-tutorials/ (no reuse licence).
15. **Hand-fix tools:**
    - Aseprite CLI (https://www.aseprite.org/docs/cli/): `Frame.duration` and RotSprite, scripted from Python.
    - Tween extensions (https://community.aseprite.org/t/extension-tweencel-tweening-and-animation-control-for-aseprite/24229): Tweencel, Easy Interpolation and The Tween Machine.
    - https://github.com/letsagents/aseprite-mcp (MIT).

---

## 5. Skip

**Non-commercial licences:**
- Make Your Own Sprites (https://github.com/WuZongWei6/Pixelization)
- Rerender-A-Video / FRESCO video_blend (https://github.com/williamyang1991/Rerender_A_Video): S-Lab licence
- BasicPBC (https://github.com/ykdai/BasicPBC): S-Lab licence; keep the "same region, same colour" idea only
- CoTracker3 (https://github.com/facebookresearch/co-tracker): CC-BY-NC
- AnimeInbet (https://github.com/lisiyao21/AnimeInbet)
- UniAnimate and UniAnimate-DiT (https://github.com/ali-vilab/UniAnimate-DiT)
- AnimeRun dataset: CC-BY-NC; reading its findings is fine
- Mystic07 spritesheet LoRA (https://huggingface.co/Mystic07/flux-lora-spritesheet), deAPI pixelartdotfluxlora, FLUX.1-dev, FLUX.2-klein 9B
- Scenario and Leonardo free tiers

**No licence (reimplement the idea at most):**
- Deep Video Prior (https://github.com/ChenyangLEI/deep-video-prior)
- Few-Shot Patch-Based Training (https://github.com/OndrejTexler/Few-Shot-Patch-Based-Training): the authors ask commercial users to reimplement it
- Bonneel blindconsistency
- SketchBetween (https://github.com/ribombee/SketchBetween): also no code or weights
- MalloyTheDev smear_frame: its idea is used in item 2
- AyushRai09 Kopf Matlab port
- Astropulse sd-palettize

**No weights:** Deep Unsupervised Pixelization (csqiangwen).

**Too heavy or too slow for 12 GB:**
- SD-piXL (https://github.com/AlexandreBinninger/SD-piXL): hours per frame, about 24 GB
- ToonComposer locally: 57 GB
- Wan2.1 FLF2V 14B locally (https://huggingface.co/Wan-AI/Wan2.1-FLF2V-14B-720P-Diffusers): use Seedance FLF instead
- Wan2.2 Pixel Animate LoRA (https://huggingface.co/styly-agents/Wan2-2-pixel-animate): 14B MoE, and the source of its 226 training clips is not stated

**Built for fake pixel art on a grid, but our frames are video:**
- Sprite Fusion Pixel Snapper (https://github.com/Hugo-Dz/spritefusion-pixel-snapper)
- Retro Diffusion pixel-art-fixer (https://github.com/Retro-Diffusion/pixel-art-fixer, wiki https://github.com/Retro-Diffusion/pixel-art-fixer/wiki)
- pixeldetector's restore mode
- proper-pixel-art's grid detection and unfake's scale detection

Their palette ideas are already in items 3-4.

**Weak or superseded:**
- Super Pyxelate as a tool: pins scikit-learn 0.24 and Python 3.9; its Vid idea is in item 4
- Pixelated Image Abstraction (https://cragl.cs.gmu.edu/pixelate/): GPL, single image, little gain
- SD_PixelArt_SpriteSheet_Generator (https://huggingface.co/Onodofthenorth/SD_PixelArt_SpriteSheet_Generator): unknown parent models, needs img2img fiddling
- Lai 2018 as a drop-in: PyTorch 0.4 and FlowNet2
- Retro Diffusion rd-animation via Replicate (https://replicate.com/blog/retro-diffusions-pixel-art-models-are-now-on-replicate): same model as the RD API in section 3; terms unchecked

---

I re-checked only four claims at the source: the PixelOE and unfake READMEs, ToonCrafter's VRAM figures and the EbSynth patent status. Every other licence, price and VRAM figure comes from the research findings as given. The two biggest risks: get a legal opinion on the PatchMatch patent before relying on EbSynth, and check the DynamiCrafter base terms before shipping ToonCrafter output. I did not split the game files; that was not part of this step.
