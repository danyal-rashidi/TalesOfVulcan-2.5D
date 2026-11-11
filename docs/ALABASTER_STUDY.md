# What the game is missing next to Alabaster Dawn

1 Nov 2026, night · for Danyal. The page with the pictures: https://claude.ai/artifact/PGsGv6EbjPAQGxyg9TiNoP

The game has a good skeleton and is missing four layers that Alabaster Dawn has everywhere: sound, color and light, height, and depth in its fights. Most of the fixes need no new sprites. Nothing here has been built yet.

Limits: Claude hasn't played Alabaster Dawn. The evidence is 14 store screenshots, 2 trailers, 4 full reviews, 20 Steam player reviews, its wiki and the developers' posts, and screenshots and trailers flatter it. The measurements are rough, so read them as direction. Six of the screenshots are in `docs/refs/alabaster_dawn/` as local references; they're Radical Fish's art, so don't ship or share them.

## The four missing layers

1. **Sound.** 0 sound files and no code that plays sound. Reviewers single out its "weighty" swings and its sound cues.
2. **Color and light.** On screenshots, Alabaster Dawn vs ours: color variety 3.00 vs 0.64, shadow color shift from lit color 58° vs 7°, saturation 0.37 vs 0.53, busyness 0.22 vs 0.43. It's less saturated than we are and looks far more colorful, because it uses many color families in calm, large shapes, with blue or purple shadows.
3. **Height.** Ours is one flat plane with props spread evenly. Its world is stacked cliffs and layered ground, with props in clumps round a focal point.
4. **Depth and size in fights.** It has dash, back step, guard, a timed parry, a break bar on every enemy, 6 weapons so far with 8 planned, elements and finishers, and 47 listed enemies. We have a roll, one sword moveset, 1 working skill of 30 listed, 3 small enemies on one script and 1 boss. Our hit-stop is good, but normal swings have no effect, there are no damage numbers, and a light hit on a small enemy barely shakes the screen (1 px for 0.1 s, most of it spent inside the 0.07 s hit-stop). In the boss fight the `blood` mood turns the whole arena one red, with Vulcan dark on dark.

Also: 52% of Vulcan's pixels are near-black and he has 14 colors, and the approved look's maroon outline isn't on these sheets (a palette-only test: `docs/progress/2026-11-01_study_sprite_palette_test.png`). Dialogue is a small portrait and a box in Godot's default font with smoothing off (`Hud.pixel_font`), where Alabaster Dawn uses large portraits and speech bubbles.

## The experiment

The real game with a temporary overlay, not saved into the game: `docs/progress/2026-11-01_study_light_ground_experiment.png`.

| Measured | Now | + light | + ground | Alabaster Dawn |
| --- | --- | --- | --- | --- |
| Color variety | 0.64 | 1.73 | 1.86 | 3.00 |
| Busyness | 0.43 | 0.40 | 0.37 | 0.22 |
| Large-scale light and dark | 0.081 | 0.101 | 0.107 | 0.102 |

- About 15 lines of full-screen shader (cool the darks towards (0.34, 0.27, 0.50), a warm pool of light, cooler at the edges) did most of it.
- Calmer sand helps. The ground patches made in code look like stains, so layered ground needs painted tiles with real edges.
- Busyness barely moved because the cobbles dominate. They need much lower contrast.

## The plan, in order

Each batch stands on its own. Credits are estimates at 1 a picture, 2 a clip.

Status on 2 Nov 2026: Batch 1 is built except sound, which Danyal is making. Item 6 changed: Danyal asked for the outline to go, so the maroon line is off by default (`PAL_LINE_ON` in `core/palette.gdshaderinc`) and the shading shift stays. Batches 2 to 4 aren't started, except that hills (part of item 11's height) are in.

**Batch 1: make it feel alive**
1. Sound: sword, hits, footsteps, roll, menus, wind, one music track per area. Not priced yet; free packs are the fallback.
2. Hit effects: a slash arc on every swing, damage numbers, a little shake on small enemies, speed lines on finishers.
3. A real pixel font.
4. Light and color per area: the experiment, built properly.
5. Calm the ground: no sand speckle, much less cobble contrast.
6. Sprite palette pass: maroon line and color-shifted shading on every character, tuned so clothes keep their detail.
7. The boss arena's light: keep the red storm feeling, with the ground darker and Vulcan lit.

**Batch 2: make fights worth learning**
8. A timed parry and a visible break bar on every enemy.
9. Three real enemy types, such as a charger, a spitter and a shielded enemy, each with a clear warning. About 12-24 credits.
10. Saving. Built 10 Nov: Cinerea saves at each beat (the walk in, the tomb, Cassia, the town gate, leaving her shop) to `user://save.cfg`, and the title's Continue picks up at that beat's checkpoint. It keeps his things, money, memories, skills, map and trust, and which beats are done. It doesn't keep health or flasks (full again, as at a respawn), a fight he was in, the foes he killed on the road, or who he has talked to. The prologue and the colosseum aren't saved.

**Batch 3: build the world up**
11. One test area with height: a small canyon with mesa cliffs, ledges and automatic jumps. The biggest job here: about 140 lines across 61 scripts assume flat ground or touch height. The world is already real 3D, which helps.
12. Painted ground tiles: packed earth, gravel, scrub, oasis green, ember-burned ground. About 8 credits.
13. Clumps and landmarks: curve the road, group props, one thing to look at per screen.
14. Secrets and a first small dungeon built round the Hammer: the aimed leap crosses gaps, and it can smash cracked walls.

**Batch 4: make the story land**
15. Big portraits and speech bubbles: 13 speakers, three expressions each, about 39 credits.
16. Title, options and game-over screens.

## Danyal's calls

| Question | Claude's recommendation |
| --- | --- |
| Add a parry? It changes how fights play. | Yes. It's the biggest source of depth in their combat. |
| Rebuild the world with height? | Test one canyon first, after batches 1 and 2. |
| The town mixes half-timbered houses with adobe in a Roman desert. | Move towards one look per town. Left alone because it comes from Danyal's town picture. |

## Keep

The story hook (the unmasking, "Who... am I?"), the prologue's look, the combat base (hit-stop, 0.45 s input buffer, roll cancels, boss floor warnings, a second phase), footprints and bending grass, and the picture-to-clip-to-sprite pipeline.

## Don't copy

What its players complain about: repetitive environments and "kill X of Y" quests, the same story loop per region, generic skill trees ("Str + 6"), 6-8 enemies attacking at once, floor warnings that don't match the hit, hard-to-read cliff edges, an easy first boss, tutorials you can't see again.

## Small bugs found

- Restart in the Cinerea pause menu only unpauses: `Hud.restart_requested` has a listener in `game/game.gd` only.
- Embers show on the HUD but nothing awards them (`game/journey.gd`), so the Memory Paths can't be paid for.
- The town has no ending.

## Sources

- Steam: https://store.steampowered.com/app/3110760/Alabaster_Dawn/ and https://steamcommunity.com/app/3110760/negativereviews/?browsefilter=toprated
- Wiki: https://alabasterdawn.wiki.gg/wiki/Growth_Chart and https://alabasterdawn.wiki.gg/wiki/Enemies
- Reviews: https://game8.co/reviews/alabaster-dawn/alabaster-dawn-review-early-access , https://powerupgaming.co.uk/2026/05/12/alabaster-dawn-early-access-review/ , https://www.thegeeklygrind.com/all-posts/alabaster-dawn-early-access-review , https://www.vrkutak.com/2026/recenzije/alabaster-dawn-early-access-review/
- Previews: https://www.rpgfan.com/2025/09/18/alabaster-dawn-gorgeous-pixel-art-rpg/ , https://www.rpgfan.com/2026/05/04/alabaster-dawn-hands-on-preview/ , https://noisypixel.net/alabaster-dawn-impressions-rpg-demo-review/ , https://www.invenglobal.com/articles/21925/alabaster-dawn-an-evolution-inheriting-the-dna-of-crosscode
- Developers: https://www.radicalfishgames.com/?p=7964 , https://www.radicalfishgames.com/?p=8243 , https://www.radicalfishgames.com/?p=8345 , https://www.radicalfishgames.com/?p=1168
