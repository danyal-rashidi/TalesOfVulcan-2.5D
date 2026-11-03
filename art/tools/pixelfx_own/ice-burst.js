// The burst out of ice/ice-shatter (pixelfx a841596) without its block: that one's a 40 px cube bursting, and its rubble and frost line run over a whole boss when five spears land in a row. Here a compact spray of the same shards, ice dust and glints, for a spear's hit, his spear breaking and sealing.
// The burst recipe (a white frame, the ice flung apart as shards with ice dust and glints) is adapted from Sprite Fusion's open-source ice
// (https://www.spritefusion.com/pixel-art-vfx/ice), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Particles, Bits, P, B, Rng, fit, TAU, WHITE } from "../../core/index.js";
import { star } from "../impacts/_lib.js";

export const meta = {
  name: "Ice burst",
  desc: "A cold hit flung apart: a white frame, hard shards thrown away from the blow, ice dust, glints, shards falling to the floor below and winking out.",
  tags: ["ice", "burst", "impact", "directional"],
  size: [232, 112],
  origin: [84, 56],
  duration: 0.8,
  loop: false,
  fps: 20,
  bg: "dark",
  options: { palette: ["#185ce2", "#2aaaff", "#40d6ff", "#d7fcfc", "#ffffff"], floor: 18, seed: 6 },
};

export function create(o) {
  const C = fit(o.palette, 5), R = new Rng(o.seed), floor = () => o.floor;
  const ps = new Particles({ rng: R, ground: floor, sparks: [WHITE, C[3], C[2], C[1]] });
  const bits = new Bits({ ground: floor });
  // chunks big enough to read at the game's 1x, and splinters among them, all lit from the top left
  for (let i = 0; i < 24; i++) {
    const a = R.range(0, TAU), sp = R.range(60, 230), chunk = i % 5 < 3;    // and on from the blow, which comes from the left
    bits.add({ kind: chunk ? B.CHUNK : B.SHARD, x: R.range(-5, 5), y: R.range(-5, 5), vx: Math.cos(a) * sp + R.range(20, 100), vy: Math.sin(a) * sp * 0.8 - R.range(30, 110), g: 0.85, drag: 0.6, bounce: 0.3, life: R.range(0.35, 0.65), a: R.range(0, TAU), va: R.range(-22, 22), s: chunk ? R.range(2, 4.4) : R.range(5, 9), c: C[R.int(2, 3)], ramp: [C[0], C[1], C[2], C[3], WHITE] });
  }
  for (let i = 0; i < 12; i++) {
    const a = R.range(0, TAU), sp = R.range(10, 70);
    ps.spawn(P.VAPOUR, Math.cos(a) * 4, Math.sin(a) * 4, Math.cos(a) * sp + 18, Math.sin(a) * sp, R.range(0.25, 0.45), C[2], R.range(3, 6));
  }
  for (let i = 0; i < 4; i++) ps.spawn(P.STAR, R.range(-20, 26), R.range(-22, 12), R.range(-14, 14), R.range(-14, 8), R.range(0.2, 0.4), WHITE, R.range(1.4, 2.4), R.range(0.05, 0.25));
  const burst = [0, 0.9, 1.7, 2.5, 3.3, 4.1, 5, 5.7].map((a, i) => ({ a: a + R.range(-0.15, 0.15), len: i % 2 ? R.range(10, 14) : R.range(17, 24), w: i % 2 ? 2.2 : 3 }));
  let t = 0;
  return {
    update(dt) {
      t += dt;
      bits.update(dt);
      ps.update(dt);
    },
    draw(p) {
      ps.draw(p, "back");
      if (t < 0.05) star(p, 0, 0, burst, 1, 1, [C[2], C[3], WHITE, WHITE]);
      else if (t < 0.1) star(p, 0, 0, burst, 1.3, 0.6, [C[1], C[2], C[3], WHITE]);
      bits.draw(p);
      ps.draw(p, "front");
    },
  };
}
