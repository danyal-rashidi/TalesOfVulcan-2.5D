// One stamp of the aura behind a giant ice spear. ice/ice-lance (pixelfx a841596) bakes its wake straight behind it, but these spears track and turn, so the same wake is left in the world a stamp at a time and curves with the flight.
// The frost puffs are ice-lance's, and its recipe is adapted from Sprite Fusion's open-source energy bolt
// (https://www.spritefusion.com/pixel-art-vfx/energy), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, Rng, TAU } from "../../core/index.js";

export const meta = {
  name: "Ice wake",
  desc: "One stamp of a spear's wake: a hard knot of frost that cools from cyan to deep blue, shrinks and breaks up into drifting crystals.",
  tags: ["ice", "wake", "trail"],
  size: [60, 60],
  origin: [30, 30],
  duration: 0.6,
  loop: false,
  fps: 20,
  bg: "dark",
  options: { palette: ["#185ce2", "#2aaaff", "#40d6ff", "#d7fcfc", "#ffffff"], seed: 3 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 5), D = meta.duration, k = t / D, R = new Rng(o.seed);
  if (k >= 1) return;
  // young, a hard knot with a hot middle and a glint, so stamps overlapping make a mottled ribbon; it cools and shrinks fast, so the ribbon tapers
  const col = k < 0.2 ? C[1] : C[0], core = k < 0.1 ? C[3] : k < 0.25 ? C[2] : k < 0.42 ? C[1] : C[0];
  for (let i = 0; i < 3; i++) {
    const a = R.range(0, TAU), far = R.range(1, 2.5), big = R.range(3, 4.6) * (1 - k / 0.62);
    if (big >= 0.8) p.disc(Math.cos(a) * far, Math.sin(a) * far, big, col, () => 1);
    if (big >= 2.2) p.disc(Math.cos(a) * far * 0.5, Math.sin(a) * far * 0.5, big - 1.5, core, () => 1);    // a hot middle with a deep blue edge, so the ribbon isn't one flat colour
  }
  if (k < 0.15) p.px(R.range(-2, 2), R.range(-2, 2), C[4]);
  // then it breaks up into crystals drifting apart, not a sausage: little diamonds with a lit corner, winking out
  for (let i = 0; i < 7; i++) {
    const a = R.range(0, TAU), sp = R.range(14, 40), late = R.range(0.2, 0.45), life = R.range(0.35, 0.55), r = R.range(0, 1) < 0.4 ? 2 : 1, born = R.range(0, TAU);
    if (k < late || k > late + life || (k > late + life * 0.7 && Math.floor(t * 40 + born) % 2)) continue;
    const age = (k - late) * D, x = Math.cos(a) * (3 + sp * age), y = Math.sin(a) * (3 + sp * age);
    for (const [dx, dy] of r === 2 ? [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]] : [[0, 0]]) p.px(x + dx, y + dy, i % 3 ? C[1] : C[2]);
    if (r === 2) p.px(x - 1, y - 1, C[3]);
  }
}
