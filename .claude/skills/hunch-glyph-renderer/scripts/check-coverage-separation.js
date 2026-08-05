#!/usr/bin/env node
'use strict';
/*
 * check-coverage-separation.js — determines and then guards T, the pairwise distinctness
 * constant that GAME_DESIGN.md §13.5.1 asserts ("T asserted as a shipped constant") and
 * never states.
 *
 *   node check-coverage-separation.js                 # the §13.5.1 gate: 44 pt, 6 envs
 *   node check-coverage-separation.js --t 8.0         # assert a specific T
 *   node check-coverage-separation.js --size 96       # one size, one env, diagnostics
 *   node check-coverage-separation.js --sweep         # the size table
 *
 * T IS IN pt² OF INK DIFFERENCE, not in raw 8-bit L1 sum. §13.5.1 words the test in
 * 8-bit L1 at 44 pt @2×, but that number moves if anyone changes the raster or the
 * scale, and then the constant is silently about a different thing. The two are one
 * multiplication apart and the script prints both:
 *
 *     L1_8bit = T_pt2 · 255 · scale²        (8,160 for T = 8.0 pt² at @2×)
 *
 * METHOD. Render all 256 to a COVERAGE mask — one ink level for every register, ground
 * = 0 — and take the pairwise L1 distance. A single ink level is the adversarial case:
 * canon's worst pair is teal L 0.291 against rose L 0.293, which ARE the same pixel
 * value in greyscale, so a per-hue luminance raster only ever makes the numbers larger.
 * If the deck separates here it separates in every theme, for every dichromacy, and for
 * a monochromat. See references/triple-encoding-proof.md.
 */

const path = require('path');
const R = require(path.join(__dirname, '..', 'references', 'reference-renderer.js'));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
}
const has = (name) => process.argv.includes(`--${name}`);

const SCALE = Number(arg('scale', 2));
const SAMPLES = Number(arg('samples', 4));
const T_DEFAULT = 8.0;                       // pt² at S = 44. See references/triple-encoding-proof.md §4.
const T = Number(arg('t', T_DEFAULT));

const name = (g) => `${g.fill}/${g.shape}/${g.pips}/${g.hue}`;
const differing = (a, b) => ['fill', 'shape', 'pips', 'hue'].filter((k) => a[k] !== b[k]);
const toPt2 = (l1) => l1 / (255 * SCALE * SCALE);

/** Minimum pairwise L1 over the deck, with a sum-difference lower bound to skip pairs. */
function analyse(S, env) {
  const masks = R.DECK.map((g) => R.coverageMask(g, S, { env, scale: SCALE, samples: SAMPLES }).data);
  const sums = masks.map((m) => { let s = 0; for (let k = 0; k < m.length; k += 1) s += m[k]; return s; });
  let min = Infinity, pair = null;
  const channel = {};
  for (let i = 0; i < 256; i += 1) {
    for (let j = i + 1; j < 256; j += 1) {
      const bound = Math.abs(sums[i] - sums[j]);          // L1 >= |sum difference|
      const d = differing(R.DECK[i], R.DECK[j]);
      const key = d.length === 1 ? `${d[0]}: ${R.DECK[i][d[0]]} vs ${R.DECK[j][d[0]]}` : null;
      if (bound >= min && key === null) continue;
      let sum = 0;
      const a = masks[i], b = masks[j];
      for (let k = 0; k < a.length; k += 1) sum += Math.abs(a[k] - b[k]);
      if (sum < min) { min = sum; pair = [i, j]; }
      if (key && (!(key in channel) || sum < channel[key])) channel[key] = sum;
    }
  }
  return { min, pair, channel, px: Math.round(2 * S * (0.5 + 0.16) * SCALE) };
}

/** The four-rung ink ladder, in both readings. Returns the inversions found. */
function ladder(S, env) {
  const rows = {};
  const bad = [];
  for (const region of ['inset', 'interior']) {
    rows[region] = R.FILLS.map((fill) => R.SHAPES.map((shape) =>
      R.measuredFillCoverage({ fill, shape, pips: 'one', hue: 'amber' }, S, { env, region })));
    for (let k = 1; k < 4; k += 1) {
      if (Math.min(...rows[region][k]) <= Math.max(...rows[region][k - 1])) {
        bad.push(`${region}: ${R.FILLS[k - 1]} → ${R.FILLS[k]}`);
      }
    }
  }
  return { rows, bad };
}

const ENVS = [
  ['dark', { theme: 'dark' }],
  ['dark + Bold Text', { theme: 'dark', boldText: true }],
  ['dark, bloom off', { theme: 'dark', bloom: false }],
  ['light', { theme: 'light' }],
  ['High Contrast', { theme: 'highContrast' }],
  ['High Contrast + Bold', { theme: 'highContrast', boldText: true }],
];

// ── --sweep: the size table ─────────────────────────────────────────────────────────
if (has('sweep')) {
  console.log(`\nSIZE SWEEP — dark theme, @${SCALE}x. T is defined at 44 pt; this table is diagnostic.\n`);
  console.log('    S    min pt²   limiting channel                 inset ladder   interior ladder');
  for (const S of [24, 36, 44, 52, 72, 96]) {
    const env = { theme: 'dark' };
    const a = analyse(S, env);
    const l = ladder(S, env);
    const worst = Object.keys(a.channel).sort((x, y) => a.channel[x] - a.channel[y])[0];
    const insetBad = l.bad.filter((b) => b.startsWith('inset')).length;
    const interiorBad = l.bad.filter((b) => b.startsWith('interior')).length;
    console.log(`  ${String(S).padStart(3)}   ${toPt2(a.min).toFixed(2).padStart(7)}   ${worst.padEnd(30)}   ${insetBad ? 'INVERTED' : '      ok'}       ${interiorBad ? 'INVERTED' : 'ok'}`);
  }
  console.log('');
  process.exit(0);
}

// ── --size: one configuration, verbose ──────────────────────────────────────────────
if (process.argv.includes('--size')) {
  const S = Number(arg('size', 44));
  const env = { theme: arg('theme', 'dark'), boldText: has('bold'), bloom: !has('no-bloom') };
  const geo = R.geometry(S, env);
  const a = analyse(S, env);
  const l = ladder(S, env);
  console.log(`\nS = ${S} pt @${SCALE}x · ${env.theme}${env.boldText ? ' · Bold Text' : ''} · bloom ${geo.bloom ? 'on' : 'off'} · raster ${a.px}²`);
  console.log(`\nMIN PAIRWISE  ${toPt2(a.min).toFixed(2)} pt²  (L1 ${a.min.toLocaleString()})`);
  console.log(`  ${name(R.DECK[a.pair[0]])}  vs  ${name(R.DECK[a.pair[1]])}`);
  console.log('\nCHEAPEST SINGLE-CHANNEL CHANGE, pt²');
  for (const k of Object.keys(a.channel).sort((x, y) => a.channel[x] - a.channel[y])) {
    console.log(`  ${toPt2(a.channel[k]).toFixed(2).padStart(8)}   ${k}`);
  }
  console.log('\nINK LADDER, % of region');
  for (const region of ['inset', 'interior']) {
    console.log(`  ${region.padEnd(9)}${R.FILLS.map((f, k) => `${f} ${(Math.min(...l.rows[region][k]) * 100).toFixed(1)}–${(Math.max(...l.rows[region][k]) * 100).toFixed(1)}%`).join('  ·  ')}`);
  }
  if (l.bad.length) console.log(`  *** INVERTED: ${l.bad.join(' · ')}`);
  console.log('');
  process.exit(0);
}

// ── default: the §13.5.1 gate ───────────────────────────────────────────────────────
const S = 44;
console.log(`\n§13.5.1 GATE — all 256 glyphs, S = 44 pt @${SCALE}x, six render environments`);
console.log(`T = ${T.toFixed(2)} pt² of ink difference  (= L1 ${Math.round(T * 255 * SCALE * SCALE).toLocaleString()} in 8-bit units at this scale)\n`);
console.log('  environment              min pt²   margin   limiting pair                                       inset ladder');
let failed = false;
for (const [label, env] of ENVS) {
  const a = analyse(S, env);
  const l = ladder(S, env);
  const pt2 = toPt2(a.min);
  const insetBad = l.bad.filter((b) => b.startsWith('inset'));
  const ok = pt2 >= T && insetBad.length === 0;
  if (!ok) failed = true;
  const margin = `${(((pt2 / T) - 1) * 100).toFixed(0)}%`;
  console.log(`  ${ok ? ' ' : '!'} ${label.padEnd(22)} ${pt2.toFixed(2).padStart(6)}   ${margin.padStart(6)}   ${(name(R.DECK[a.pair[0]]) + ' vs ' + name(R.DECK[a.pair[1]])).padEnd(50)} ${insetBad.length ? 'INVERTED' : 'ok'}`);
}
console.log('');
console.log(failed
  ? 'FAIL — a pair is closer than T, or an ink rung inverted. Fix the geometry, do not lower T.'
  : 'PASS — every pair in the deck separates by geometry alone, in every environment.');
process.exit(failed ? 1 : 0);
