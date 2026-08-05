#!/usr/bin/env node
'use strict';
/*
 * render-all-256.js — render the whole deck at one size and report what the raster
 * actually looks like, as opposed to what the arithmetic says it should.
 *
 *   node render-all-256.js [--size 44] [--scale 2] [--theme dark|light|highContrast]
 *                          [--bold] [--no-bloom] [--out sheet.pgm]
 *
 * Prints: the derived geometry, the required bleed per hue, the measured fill ladder
 * (which is the size-invariance claim of §13.5, checked rather than asserted), and the
 * per-glyph raster extremes. `--out` writes a 16 × 16 contact sheet as a binary PGM.
 */

const path = require('path');
const fs = require('fs');
const R = require(path.join(__dirname, '..', 'references', 'reference-renderer.js'));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
}
const has = (name) => process.argv.includes(`--${name}`);

const S = Number(arg('size', 44));
const scale = Number(arg('scale', 2));
const env = {
  theme: arg('theme', 'dark'),
  boldText: has('bold'),
  bloom: !has('no-bloom'),
};
const out = arg('out', null);

const g = R.geometry(S, env);
const fmt = (v) => (typeof v === 'number' ? v.toFixed(3) : JSON.stringify(v));

console.log(`\nGEOMETRY  S = ${S} pt · theme ${env.theme}${env.boldText ? ' · Bold Text' : ''}${g.bloom ? ' · bloom on' : ' · bloom off'}`);
for (const k of ['R', 'centre', 'indexCentre', 'indexLength', 'bodyWeight', 'indexWeight',
  'pitch', 'dotRadius', 'stripeWeight', 'pipRadius', 'fillInset', 'haloWeight', 'keylineWeight']) {
  console.log(`  ${k.padEnd(16)} ${fmt(g[k])}`);
}
console.log(`  ${'regime'.padEnd(16)} ${S < 48 ? 'weight.bodySm (S < 48)' : 'weight.body (S >= 48)'}`);

// ── Bleed: how far outside the S-box the drawing reaches, per hue ────────────────────
console.log(`\nBLEED   the S-box half-extent is ${(S / 2).toFixed(3)} pt`);
const halfIndex = (g.bloom ? g.haloIndexWeight : g.indexWeight) / 2;
for (const hue of R.HUES) {
  const t = (R.INDEX_ROTATION[hue] * Math.PI) / 180;
  const y = 0.43 * S + (g.indexLength / 2) * Math.abs(Math.sin(t)) + halfIndex * Math.abs(Math.cos(t));
  const x = (g.indexLength / 2) * Math.abs(Math.cos(t)) + halfIndex * Math.abs(Math.sin(t));
  const over = y - S / 2;
  console.log(`  ${hue.padEnd(6)} reaches y ${y.toFixed(3)}  x ${x.toFixed(3)}  ->  ${over > 0 ? `${over.toFixed(3)} pt outside` : 'inside the box'}`);
}
const b = R.bleed(S, env);
console.log(`  required bleed  x ${b.x.toFixed(3)}  y ${b.y.toFixed(3)}   (PHOSPHOR's flat 0.08·S = ${(0.08 * S).toFixed(3)})`);
if (b.y > 0.08 * S + 1e-6) {
  console.log(`  *** 0.08·S CLIPS the halo at this size. Use c.glyph.bleed(side:in:).`);
}

// ── The fill ladder, measured ────────────────────────────────────────────────────────
console.log('\nFILL LADDER   measured ink coverage of the fill register inside the inset silhouette');
console.log('  fill      circle   triangle   square   hexagon    canon');
const CANON = { hollow: 0, dotted: 0.227, striped: 0.386, solid: 1 };
const ladder = {};
for (const fill of R.FILLS) {
  const row = [];
  for (const shape of R.SHAPES) {
    const c = R.measuredFillCoverage({ fill, shape, pips: 'one', hue: 'amber' }, S, { env });
    row.push(c);
  }
  ladder[fill] = row;
  console.log(`  ${fill.padEnd(8)}${row.map((v) => `${(v * 100).toFixed(1).padStart(8)}%`).join('')}   ${(CANON[fill] * 100).toFixed(1)}%`);
}
const gaps = [];
for (let i = 1; i < R.FILLS.length; i += 1) {
  const lo = Math.max(...ladder[R.FILLS[i - 1]]);
  const hi = Math.min(...ladder[R.FILLS[i]]);
  gaps.push({ pair: `${R.FILLS[i - 1]}→${R.FILLS[i]}`, gap: hi - lo });
}
console.log(`  worst-case rung separation (max of lower rung vs min of upper, over all 4 shapes):`);
for (const { pair, gap } of gaps) {
  console.log(`    ${pair.padEnd(18)} ${(gap * 100).toFixed(2)} pp ${gap <= 0 ? '  *** LADDER INVERTED' : ''}`);
}

// ── Dot and stripe sample counts — the §2(c) worry, counted ──────────────────────────
const insetR = g.R - g.fillInset;
const dotsAcross = (2 * insetR) / g.pitch;
console.log(`\nSAMPLE COUNT   inset radius ${insetR.toFixed(2)} pt, pitch ${g.pitch.toFixed(2)} pt`);
console.log(`  dotted: ~${dotsAcross.toFixed(1)} dots across the widest chord, radius ${g.dotRadius.toFixed(2)} pt`);
console.log(`  striped: ~${dotsAcross.toFixed(1)} stripes across, weight ${g.stripeWeight.toFixed(2)} pt`);
if (g.pitch === 5) console.log('  pitch is on its 5 pt FLOOR — the ratio still holds, the sample count does not scale.');

// ── The contact sheet ────────────────────────────────────────────────────────────────
if (out) {
  const first = R.coverageMask(R.DECK[0], S, { env, scale });
  const cell = first.px;
  const sheet = new Uint8Array(cell * 16 * cell * 16);
  const rowBytes = cell * 16;
  for (let id = 0; id < 256; id += 1) {
    const m = R.coverageMask(R.DECK[id], S, { env, scale });
    const ox = (id % 16) * cell;
    const oy = Math.floor(id / 16) * cell;
    for (let y = 0; y < cell; y += 1) {
      sheet.set(m.data.subarray(y * cell, (y + 1) * cell), (oy + y) * rowBytes + ox);
    }
  }
  const header = Buffer.from(`P5\n${rowBytes} ${rowBytes}\n255\n`, 'ascii');
  fs.writeFileSync(out, Buffer.concat([header, Buffer.from(sheet)]));
  console.log(`\nWROTE ${out}  —  16 × 16 contact sheet, ${rowBytes} × ${rowBytes} px, deck order fill→shape→pips→hue`);
}
console.log('');
