// impacts/ground-slam (pixelfx a841596) drawn for this game's camera, which looks down 48.59 degrees where pixelfx looks along the floor: its flat ring and straight line of dust read as a different game here, so the ring and dust run round a floor circle 0.75 as deep as it is wide, and rocks come down all over it.
// The rocks, grit, rolling floor dust and dust column are adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Particles, Bits, P, B, GRAVITY, Rng, fit, band, clamp, smooth, ease, loopNoise, TAU, WHITE, hex } from "../../core/index.js";
import { stone, star, makeCracks, drawCracks, rock, rockShape, SOOT } from "../impacts/_lib.js";

export const meta = {
  name: "Hammer impact",
  desc: "A giant hammer's head meets the floor: a white flash, a ring of force racing to the blow's edge, cracks, rocks thrown all round, dust rolling after the ring; fire when asked.",
  tags: ["impact", "ground", "hammer"],
  size: [260, 240],
  origin: [130, 150],
  duration: 1.4,
  loop: false,
  fps: 30,
  bg: "ground",
  options: { palette: ["#7a5c34", "#a88a58", "#cab89c", "#e2d4ba", "#fff6d6", "#fff6d6", "#ffffff"], stone: "#a88a58", dust: "#e2d4ba", dustLit: "#fff6d6", dustShade: "#cab89c", reach: 90, burn: false, seed: 5 },
};

const WAVE = 0.3, DEEP = 0.75; // seconds for the ring to reach the blow's edge; screen px of depth to a px of width
const BURN = 1.2; // seconds a burning ring lasts: it races out, burns on at the edge, then chars away in pieces. Claude's call

export function create(o) {
  const C = fit(o.palette, 7), st = stone(o.stone), REACH = o.reach, R = new Rng(o.seed), D = meta.duration;
  const dust = hex(o.dust), dustLit = hex(o.dustLit), shade = hex(o.dustShade), HOT = [WHITE, C[5], C[4], C[3]];
  const ps = new Particles({ rng: R });
  // sand and paler, never dark: this is what comes off a desert floor. Burning, it's lit by the fire, or the blow reads as the plain one once the first flames are gone
  const puff = () => (o.burn ? hex(C[R.int(2, 3)]) : R.pick([dustLit, dust, dust, shade]));
  // rocks and grit land on rows of floor from far to near: the floor here isn't one line
  const rows = [-46, -24, -4, 18, 40].map((y) => ({ y, grit: new Particles({ rng: R, ground: () => y, sparks: [C[6], C[5], C[4], C[3]] }), bits: new Bits({ ground: () => y }) }));
  const cracks = makeCracks(R, 12, { len: [26, 70], dive: 1.5, maxY: 60, forks: 0.8, x0: [2, 9] });
  for (const c of cracks) {
    const k = R.chance(0.5) ? DEEP : -DEEP; // toward the camera and away from it
    for (const path of [c.pts, ...c.kids]) for (const q of path) q[1] *= k;
  }
  const front = (t) => 8 + (REACH - 8) * ease.outCubic(clamp(t / WAVE));
  const heat = (t) => Math.pow(clamp(1 - t / 0.5), 1.4);
  const burst = [
    { a: -0.07, len: R.range(38, 46), w: 2.2 }, { a: Math.PI + 0.07, len: R.range(38, 46), w: 2.2 },
    { a: 0.5, len: R.range(18, 24), w: 1.8 }, { a: Math.PI - 0.5, len: R.range(18, 24), w: 1.8 },
    { a: -0.5, len: R.range(18, 24), w: 1.8 }, { a: -Math.PI + 0.5, len: R.range(18, 24), w: 1.8 },
    { a: -Math.PI / 2 + R.range(-0.15, 0.15), len: R.range(30, 38), w: 2.2 },
  ];

  const toRow = (y) => -Math.sqrt(2 * GRAVITY * (Math.max(0, -y) + R.range(20, 70))); // the speed that clears the head and comes down on row y
  for (const row of rows) {
    // rocks erupt from the head and come down on this row
    for (let i = 0; i < 4; i++) {
      const s = R.chance(0.4) ? 4 : R.int(2, 3), x = R.range(-14, 14);
      row.bits.add({ kind: B.CHUNK, x, y: -2, vx: x * R.range(3, 9), vy: toRow(row.y), g: 1, drag: 0.4, bounce: 0.3, life: R.range(0.8, 1.15), a: R.range(0, TAU), va: R.range(-14, 14), s, pts: rockShape(R), pvy: 0 });
    }
    // grit that bounces once and settles
    for (let i = 0; i < 16; i++) {
      const x = R.range(-1, 1);
      row.grit.spawn(P.GRIT, x * 8, -1, x * R.range(60, 170), toRow(row.y), R.range(0.5, 1), R.pick([st.light, st.body, st.lip]), R.chance(0.35) ? 2 : 1);
    }
    for (let i = 0; i < 5; i++) {
      const a = -Math.PI / 2 + R.range(-1.2, 1.2), sp = R.range(180, 420);
      row.grit.spawn(P.SPARK, R.range(-5, 5), -1, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.18, 0.4), WHITE, 1);
    }
  }
  // the dust: a short column off the head, lit on top
  for (let i = 0; i < 26; i++)
    ps.spawn(P.DUST, R.range(-12, 12), -R.range(2, 14), R.range(-40, 40), -R.range(60, 340), R.range(0.5, 0.95), puff(), R.range(4, 8.5), R.range(0.01, 0.1));
  // and when it burns, fire goes up with it
  if (o.burn) for (let i = 0; i < 26; i++) {
    const a = R.range(0, TAU), r = R.range(0, 16);
    ps.spawn(P.FIRE, Math.cos(a) * r, Math.sin(a) * r * DEEP, Math.cos(a) * R.range(10, 60), Math.sin(a) * R.range(5, 30) - R.range(30, 110), R.range(0.3, 0.7), 0, R.range(1.6, 3.4), R.range(0, 0.1));
  }

  let t = 0, acc = R.next(), acc2 = R.next(), acc3 = 0;
  const ring = (p, near) => {
    if (o.burn) {
      const u = clamp(t / BURN), gone = clamp((u - 0.5) / 0.5);
      if (u < 1) band(p, 0, 0, front(t), DEEP, 13 - 8 * u, 1.1, u < 0.5 ? [C[1], C[2], C[3], C[4]] : [C[0], C[1], C[1], C[2]], (g) => Math.sin(g) > 0 === near && loopNoise(g / TAU, 4, 7) > gone * 1.6 - 0.8, t < 0.05);
      return;
    }
    const u = clamp(t / (WAVE + 0.16));
    if (u >= 1) return;
    band(p, 0, 0, front(t), DEEP, Math.max(1.5, 7 * Math.pow(1 - u, 0.8)), u < 0.6 ? 1.1 : (1 - u) / 0.4, u < 0.45 ? [C[3], C[4], C[5], C[6]] : [st.body, st.light, C[4], C[5]], (g) => Math.sin(g) > 0 === near, t < 0.05);
  };

  return {
    update(dt) {
      t += dt;
      // dust kicked up behind the racing ring
      const u = clamp(t / WAVE);
      if (u > 0.5 && u < 1) {    // only near the edge, so it's a bank rolling after the ring, not spots all over the disc
        const fr = front(t);
        for (acc += dt * 900; acc > 1; acc--) {
          const a = R.range(0, TAU), ca = Math.cos(a), sa = Math.sin(a), r = fr - R.range(0, 8);
          ps.spawn(P.DUST, ca * r, sa * r * DEEP, ca * R.range(10, 70), sa * R.range(8, 50) - R.range(8, 40), R.range(0.5, 0.85), puff(), R.range(6, 10));
          if (o.burn && R.chance(0.3)) ps.spawn(P.FIRE, ca * r, sa * r * DEEP, ca * 20, -R.range(10, 50), R.range(0.2, 0.42), 0, R.range(1.2, 2.6));
        }
      }
      // flames stand on the ring for as long as it's whole
      if (o.burn && t < 0.8) for (acc3 += dt * 90; acc3 > 1; acc3--) {
        const a = R.range(0, TAU), r = front(t) - R.range(0, 7);
        ps.spawn(P.FIRE, Math.cos(a) * r, Math.sin(a) * r * DEEP, Math.cos(a) * R.range(0, 14), -R.range(14, 46), R.range(0.25, 0.45), 0, R.range(3, 5.5));
      }
      if (o.burn) for (acc2 += dt * 22; acc2 > 1; acc2--) if (t < 0.7) ps.spawn(P.EMBER, R.range(-40, 40), R.range(-28, 28), R.range(-12, 12), -R.range(30, 80), R.range(0.3, 0.6), C[R.int(4, 5)], 1);
      ps.update(dt);
      for (const row of rows) {
        row.bits.update(dt);
        row.grit.update(dt);
      }
    },
    drawBack(p) {
      const fade = 1 - smooth(D - 0.5, D - 0.1, t), H = heat(t);
      drawCracks(p, cracks, (c) => c.len * ease.outCubic(clamp((t - c.t0) / 0.1)), (d) => H * clamp(1.2 - d / 50), HOT, o.burn ? SOOT : C[0], st.light, fade);
      ring(p, false);
    },
    draw(p) {
      ps.draw(p, "back");
      for (const row of rows) {
        for (const b of row.bits.list) rock(p, b, st);
        row.grit.draw(p);
      }
      ps.draw(p, "front");
      ring(p, true);
      if (t < 0.04) {
        p.ellipse(0, 0, 34, 34 * DEEP, (d) => (d > 0.8 ? C[4] : d > 0.5 ? C[6] : WHITE));
        star(p, 0, -1, burst, 1.2, 1, [C[4], C[6], WHITE, WHITE]);
      } else if (t < 0.08) star(p, 0, -1, burst, 1.5, 0.5, [C[3], C[5], C[6], WHITE]);
    },
  };
}
