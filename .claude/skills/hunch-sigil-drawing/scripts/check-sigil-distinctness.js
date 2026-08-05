#!/usr/bin/env node
/*
 * HUNCH — sigil distinctness harness.
 *
 * THIS FILE IS THE CATALOGUE. `SIGILS` below is the single normative home of every sigil's
 * geometry. The references/*.md files carry meaning, states, VoiceOver, Reduce Motion, High
 * Contrast and the wrongs; they cite keys from here and never restate a coordinate.
 *
 * Coordinates are fractions of the sigil box side U, origin at the box centre, **y down,
 * angles clockwise from East** — the same screen frame the glyph renderer resolved to
 * (hunch-glyph-renderer/references/geometry.md). Stroke widths are ROLE names, mapped to
 * `weight.*` tokens by U; the token VALUES are read from HunchCore at run time, never here.
 *
 *   node check-sigil-distinctness.js                 pairwise matrix over the shipped set
 *   node check-sigil-distinctness.js --new <key>     one candidate against everything shipped
 *   node check-sigil-distinctness.js --keys          print the catalogue keys and exit
 *   node check-sigil-distinctness.js --svg <key>     dump one sigil as SVG for eyeballing
 *   node check-sigil-distinctness.js --json          the whole catalogue as stroke lists —
 *                                                    the fixture SigilCatalogue is tested against
 *   node check-sigil-distinctness.js --t 6.0         provisional T while the glyph skill has none
 *
 * Exit 0 = every pair clears T and every sigil clears the ink and stage budgets.
 * Exit 1 = a violation, with the offending pair or sigil named.
 * Exit 2 = T could not be resolved. Not a pass, not a failure — a missing input.
 */
'use strict';
const fs = require('fs'), path = require('path');

/* ── 1. Modulus — OWNED here, cited by references/sigil-grammar.md, never duplicated ────────── */
const M = {
  stage: 0.90,       // no ink outside this centred fraction of the box
  authorBound: 0.40, // no centre-line beyond this; the difference is stroke half-width headroom
  ring: 0.26,        // the throat quote
  ladderW: 0.60, ladderH: 0.17, ladderCells: 4,
  plateW: 0.44, plateH: 0.30,
  notchW: 0.11,
  inkMin: 0.030, inkMax: 0.34,   // mean coverage at 44 px — sigil-grammar.md §5
};
const THETA = { induction: -90, retention: -18, flexibility: 54, restraint: 126, tempo: 198 };

/* Role → weight token. The one rule: a sigil takes the glyph's own size regime (§13.5). */
const ROLE = U => ({ contour: 'thin', verb: U < 48 ? 'bodySm' : 'body', ghost: 'hairline', bar: U < 48 ? 'body' : 'heavy' });

/* ── 2. Token resolution — read, never restate ──────────────────────────────────────────────── */
const ROOT = process.env.CLAUDE_PROJECT_DIR || path.resolve(__dirname, '../../../..');
const slurp = p => { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } };

function resolveWeights() {
  for (const rel of ['HunchCore/Sources/Tokens/Weight.swift', 'Modules/HunchCore/Sources/Tokens/Weight.swift']) {
    const src = slurp(path.join(ROOT, rel)); if (!src) continue;
    const w = {};
    for (const m of src.matchAll(/static let (hairline|thin|bodySm|body|heavy)\s*(?::[^=]+)?=\s*([0-9.]+)/g)) w[m[1]] = +m[2];
    if (Object.keys(w).length === 5) return { w, src: rel };
  }
  const ref = slurp(path.join(ROOT, '.claude/skills/hunch-design-tokens/references/dimensions-strokes-opacity.md'));
  if (ref) {
    const w = {};
    for (const m of ref.matchAll(/weight\.(hairline|thin|bodySm|body|heavy)\D+?([0-9]+\.[0-9]+)/g)) if (!(m[1] in w)) w[m[1]] = +m[2];
    if (Object.keys(w).length === 5) return { w, src: 'hunch-design-tokens/references/dimensions-strokes-opacity.md' };
  }
  return { w: { hairline: 0.5, thin: 1.0, bodySm: 1.5, body: 3.0, heavy: 4.0 }, src: 'FALLBACK — §13.3 ladder mirrored in this script' };
}

/* The comparison box side. Every pairwise raster is taken here, so it is also the side the
   glyph renderer's pt²-based T is converted against. See COMPARE_U's use in main(). */
const COMPARE_U = 24;

/* The glyph renderer ships T as an AREA — `C.Glyph.minimumPairwiseInkDifference`, pt² of ink
   difference at S = 44 (hunch-glyph-renderer/references/triple-encoding-proof.md §4). This
   harness measures mean |Δ| in 8-bit levels over the box. They are different units and the
   conversion is exact, so it is done here, once, rather than assumed anywhere:

     pt²diff = sum|Δalpha| · (U/N)²          N = raster side in px, U = box side in pt
     meanL1  = 255 · sum|Δalpha| / N²
     ⇒ meanL1 = 255 · pt²diff / U²

   Reading: the pt² floor is taken as an ABSOLUTE ink area a sigil must differ by at the box
   side it is compared at, which is the stricter of the two readings and the one that matches
   "8.0 pt² of ink difference" literally. Do not silently switch to the scale-invariant
   reading (255·T/44²) without recording it in references/sigil-grammar.md G5. */
const inkAreaToMeanL1 = (ptSquared, U) => 255 * ptSquared / (U * U);

const T_SYMBOL = /(?:minimumPairwiseInkDifference|glyphDistinctnessThreshold)\s*(?::[^=]+)?=\s*([0-9.]+)/;

function resolveT(argv) {
  const flag = argv.indexOf('--t');
  if (flag >= 0 && argv[flag + 1]) {
    return { T: +argv[flag + 1], raw: null, src: 'command line (PROVISIONAL — record it as such)' };
  }
  const convert = (ptSquared, src) =>
    ({ T: inkAreaToMeanL1(ptSquared, COMPARE_U), raw: ptSquared, src });

  for (const rel of ['HunchCore/Sources/Tokens/C.swift', 'Modules/HunchCore/Sources/Tokens/C.swift']) {
    const src = slurp(path.join(ROOT, rel));
    const m = src && src.match(T_SYMBOL);
    if (m) return convert(+m[1], rel);
  }
  for (const rel of ['.claude/skills/hunch-glyph-renderer/references/triple-encoding-proof.md',
    '.claude/skills/hunch-glyph-renderer/references/geometry.md']) {
    const ref = slurp(path.join(ROOT, rel));
    const m = ref && ref.match(T_SYMBOL);
    if (m) return convert(+m[1], rel.replace('.claude/skills/', ''));
  }
  return null;
}

/* ── 3. Primitives and macros. Every macro mirrors a drawing another skill owns; owner named. ── */
const P = {
  line: (a, b, w, o, dash) => ({ k: 'poly', pts: [a, b], w, o: o ?? 1, dash: dash || null }),
  poly: (pts, w, o, closed, dash) => ({ k: 'poly', pts, w, o: o ?? 1, closed: !!closed, dash: dash || null }),
  rect: (c, s, w, o, fill) => ({ k: 'rect', c, s, w, o: o ?? 1, fill: !!fill }),
  circ: (c, r, w, o, fill) => ({ k: 'circle', c, r, w, o: o ?? 1, fill: !!fill }),
  arc: (c, r, a0, a1, w, o) => ({ k: 'arc', c, r, a0, a1, w, o: o ?? 1 }),
  dot: (c, r, o) => ({ k: 'circle', c, r, w: 'contour', o: o ?? 1, fill: true }),
};
const rectPts = (c, s) => [
  [c[0] - s[0] / 2, c[1] - s[1] / 2], [c[0] + s[0] / 2, c[1] - s[1] / 2],
  [c[0] + s[0] / 2, c[1] + s[1] / 2], [c[0] - s[0] / 2, c[1] + s[1] / 2]];

const MACRO = {
  /* the ramp, reduced — hunch-bench-instruments/references/ramp.md owns the live drawing */
  ladder(cx, cy, w = M.ladderW, h = M.ladderH, lit = []) {
    const out = [P.rect([cx, cy], [w, h], 'contour')], p = w / M.ladderCells;
    for (let i = 1; i < M.ladderCells; i++) { const x = cx - w / 2 + i * p; out.push(P.line([x, cy - h / 2], [x, cy + h / 2], 'ghost')); }
    for (const i of lit) out.push(P.rect([cx - w / 2 + (i + 0.5) * p, cy], [p * 0.62, h * 0.60], 'contour', 1, true));
    return out;
  },
  /* the attribute header, blank — hunch-bench-instruments/references/attribute-header.md owns it */
  notch: (cx, cy, h = M.ladderH) => [P.rect([cx, cy], [M.notchW, h], 'contour')],
  /* the ghost frame — hunch-shared-marks/references/ghost-frame.md owns the drawing */
  ghostPlate(cx, cy, w = M.plateW, h = M.plateH) {
    return [P.poly(rectPts([cx, cy], [w, h]), 'ghost', 1, true, [0.045, 0.035]),
    P.poly([[cx - w / 2 + 0.075, cy - 0.070], [cx - w / 2 - 0.015, cy], [cx - w / 2 + 0.075, cy + 0.070]], 'ghost')];
  },
  /* the machined bar — hunch-shared-marks/references/machined-bar.md owns the drawing */
  bar: (cx, cy, len) => [P.line([cx - len / 2, cy], [cx + len / 2, cy], 'bar')],
  /* the comparator wedge — hunch-bench-instruments/references/wedge.md owns the six forms */
  wedge: (cx, cy, s = 0.10) => [P.poly([[cx + s * 0.6, cy - s], [cx - s * 0.6, cy], [cx + s * 0.6, cy + s]], 'verb')],
  /* the link arc — hunch-shared-marks/references/link-arc.md owns the drawing */
  linkArc: (cx, cy, r) => [P.arc([cx, cy], r, 180, 360, 'verb'), P.dot([cx - r, cy], 0.055), P.dot([cx + r, cy], 0.055)],
  /* the tick row — hunch-shared-marks/references/tick-row.md owns pitch and the filled/unfilled pair */
  tickRow(cx, cy, n, filled, len = 0.20, pitch = 0.105) {
    const half = (n - 1) * pitch / 2;
    const out = [P.line([cx - half - 0.05, cy + len / 2], [cx + half + 0.05, cy + len / 2], 'ghost')];
    for (let i = 0; i < n; i++) out.push(P.line([cx - half + i * pitch, cy - len / 2], [cx - half + i * pitch, cy + len / 2], i < filled ? 'verb' : 'ghost'));
    return out;
  },
  /* the coupler — hunch-bench-instruments/references/coupler.md owns the three resolved forms */
  couplerAnd: (cx, cy) => [P.dot([cx, cy], 0.062), ...MACRO.bar(cx, cy, 0.17)],
  couplerXor: (cx, cy) => [P.line([cx - 0.065, cy - 0.085], [cx + 0.065, cy + 0.085], 'verb'), P.line([cx - 0.065, cy + 0.085], [cx + 0.065, cy - 0.085], 'verb')],
  couplerOpen: (cx, cy) => [P.circ([cx, cy], 0.062, 'contour')],
  /* the railway switch — hunch-bench-instruments/references/fork.md owns the live drawing */
  fork: (xIn, yIn, xJoin, xEnd, drop, stem) => [
    ...(stem ? [P.line([xIn, yIn - stem], [xIn, yIn], 'verb')] : []),
    P.line([xIn, yIn], [xJoin, yIn], 'verb'),
    P.poly([[xJoin, yIn], [xJoin + 0.12, yIn - drop], [xEnd, yIn - drop]], 'verb'),
    P.poly([[xJoin, yIn], [xJoin + 0.12, yIn + drop], [xEnd, yIn + drop]], 'contour', 0.40)],
};

/* ── 4. THE CATALOGUE ────────────────────────────────────────────────────────────────────────
 * `sites` lists every U this sigil is drawn at, smallest first — the first entry is the
 * legibility floor and is what the harness gates on. Append new entries at the end of their
 * set; never renumber, never repurpose a key.                                                */
const SIGILS = {
  /* ── mode sigils · §12.4 · Codex strip 22 · instrument bar 24 · play key 44 · rack key 72 ── */
  'mode.probe': {
    set: 'mode', sites: [22, 24, 44, 72], verb: 'enter',
    parts: [P.circ([0.08, 0], M.ring, 'verb'), P.line([-0.395, 0], [0.028, 0], 'verb')],
  },
  'mode.drift': {
    set: 'mode', sites: [22, 24, 44, 72], verb: 'stack',
    parts: [P.rect([-0.10, -0.09], [0.42, 0.28], 'contour'), ...MACRO.ghostPlate(0.10, 0.09, 0.42, 0.28)],
  },
  'mode.echo': {
    set: 'mode', sites: [22, 24, 44, 72], verb: 'repeat',
    parts: [P.circ([0.14, 0], 0.17, 'verb'),
    P.arc([0.14, 0], 0.28, 110, 250, 'contour', 1.00), P.arc([0.14, 0], 0.35, 110, 250, 'contour', 0.55), P.arc([0.14, 0], 0.42, 110, 250, 'contour', 0.30)],
  },
  'mode.sieve': {
    set: 'mode', sites: [22, 24, 44, 72], verb: 'cross',
    parts: [P.line([-0.395, 0.04], [-0.22, 0.04], 'contour'), P.line([-0.08, 0.04], [0.08, 0.04], 'contour'), P.line([0.22, 0.04], [0.395, 0.04], 'contour'),
    P.line([-0.15, -0.375], [-0.15, 0.345], 'verb'), P.line([0.15, -0.375], [0.15, 0.345], 'verb'),
    P.line([0, -0.375], [0, 0.005], 'verb'), P.dot([0, 0.04], 0.058)],
  },

  /* ── family sigils · §5.2 families, §11.2 shelves · shelf divider 24 · shelf plate 44 ─────── */
  'family.literal': {
    set: 'family', band: 1, sites: [24, 44], verb: 'one',
    parts: [...MACRO.notch(-0.345, 0, 0.18), ...MACRO.ladder(0.055, 0, 0.60, 0.18, [1])],
  },
  'family.pair': {
    set: 'family', band: 2, sites: [24, 44], verb: 'and',
    parts: [...MACRO.notch(-0.345, -0.19, 0.15), ...MACRO.ladder(-0.005, -0.19, 0.52, 0.15, [2, 3]),
    ...MACRO.notch(-0.345, 0.19, 0.15), ...MACRO.ladder(-0.005, 0.19, 0.52, 0.15, [2, 3]),
    P.line([0.325, -0.19], [0.325, 0.19], 'contour'), ...MACRO.couplerAnd(0.325, 0)],
  },
  'family.exclusive': {
    set: 'family', band: 3, sites: [24, 44], verb: 'cross',
    parts: [...MACRO.notch(-0.345, -0.19, 0.15), ...MACRO.ladder(-0.005, -0.19, 0.52, 0.15, [0, 1]),
    ...MACRO.notch(-0.345, 0.19, 0.15), ...MACRO.ladder(-0.005, 0.19, 0.52, 0.15, [2, 3]),
    P.line([0.325, -0.19], [0.325, 0.19], 'contour'), ...MACRO.couplerXor(0.325, 0)],
  },
  'family.relational': {
    set: 'family', band: 4, sites: [24, 44], verb: 'compare',
    parts: [P.rect([-0.26, 0], [0.28, 0.26], 'contour'), ...MACRO.notch(-0.26, 0, 0.14), ...MACRO.wedge(0, 0, 0.11),
    P.rect([0.26, 0], [0.28, 0.26], 'contour'), ...MACRO.notch(0.26, 0, 0.14)],
  },
  'family.contextual': {
    set: 'family', band: 5, sites: [24, 44], verb: 'compare-back',
    parts: [P.rect([-0.26, -0.09], [0.28, 0.24], 'contour'), ...MACRO.notch(-0.26, -0.09, 0.13), ...MACRO.wedge(0, -0.09, 0.10),
    ...MACRO.ghostPlate(0.26, -0.09, 0.28, 0.24), P.arc([0, 0.03], 0.26, 0, 180, 'verb')],
  },
  'family.guarded': {
    set: 'family', band: 6, sites: [24, 44], verb: 'split',
    parts: [P.rect([-0.345, -0.30], [0.15, 0.15], 'contour', 1, true), ...MACRO.fork(-0.345, -0.02, -0.19, 0.38, 0.17, 0.20)],
  },
  'family.composite': {
    set: 'family', band: 7, sites: [24, 44], verb: 'and-unlike',
    parts: [P.rect([-0.32, -0.20], [0.17, 0.17], 'contour'), ...MACRO.wedge(-0.15, -0.20, 0.075), P.rect([0.02, -0.20], [0.17, 0.17], 'contour'),
    ...MACRO.ladder(-0.13, 0.20, 0.46, 0.15, [2, 3]),
    P.line([0.28, -0.20], [0.28, 0.20], 'contour'), ...MACRO.couplerOpen(0.28, 0)],
  },
  'family.systemic': {
    set: 'family', band: 8, sites: [24, 44], verb: 'count',
    parts: [P.line([-0.385, -0.31], [-0.385, 0.31], 'verb'),
    ...[-0.27, -0.09, 0.09, 0.27].flatMap(y => [P.line([-0.385, y], [-0.33, y], 'ghost'), P.rect([-0.255, y], [0.15, 0.13], 'contour')]),
    ...MACRO.ladder(0.155, 0, 0.38, 0.15, [2, 3])],
  },

  /* ── Profile vertex sigils · §11.11 P3 names the idiom, §11.10 fixes θ · U 24 in a 44 rect ── */
  'profile.induction': {
    set: 'profile', sites: [24], verb: 'one', rotate: THETA.induction,
    parts: [...MACRO.notch(-0.335, 0, 0.16), ...MACRO.ladder(0.045, 0, 0.54, 0.16, [1, 2])],
  },
  'profile.retention': {
    set: 'profile', sites: [24], verb: 'return', rotate: THETA.retention,
    parts: MACRO.linkArc(0, 0.10, 0.26),
  },
  'profile.flexibility': {
    set: 'profile', sites: [24], verb: 'split', rotate: THETA.flexibility,
    parts: MACRO.fork(-0.36, 0, -0.06, 0.33, 0.18, 0),
  },
  'profile.restraint': {
    set: 'profile', sites: [24], verb: 'bar', rotate: THETA.restraint,
    parts: [P.rect([0, 0], [M.plateW, M.plateH], 'contour'), ...MACRO.bar(0, 0, M.plateW + 0.16)],
  },
  'profile.tempo': {
    set: 'profile', sites: [24], verb: 'count', rotate: THETA.tempo,
    parts: MACRO.tickRow(0, 0, 7, 4),
  },

  /* ── Codex facet stamps · §11.2 facet bar, 5 stamps at 44 · U 24 in a 44 key ──────────────
   * The MODE facet has no drawing of its own: it displays mode.probe / drift / echo / sieve,
   * or facet.mode.off. That is why there are five stamps and only four keys here.           */
  'facet.mode.off': { set: 'facet', sites: [24], verb: 'contain', parts: [P.circ([0, 0], M.ring, 'contour')] },
  'facet.unfractured': {
    set: 'facet', sites: [24], verb: 'contain',
    parts: [P.poly(rectPts([0, 0], [0.60, 0.46]), 'contour', 1, true), P.dot([-0.30, -0.23], 0.050)],
  },
  'facet.anomaly': {
    set: 'facet', sites: [24], verb: 'double',
    parts: [P.arc([0, 0], 0.28, 110, 70, 'contour'), P.arc([0, 0], 0.37, 110, 70, 'contour')],
  },
  'facet.attributes': {
    set: 'facet', sites: [24], verb: 'quad',
    parts: [[-0.15, -0.14], [0.15, -0.14], [-0.15, 0.14], [0.15, 0.14]].map(c => P.rect(c, [0.24, 0.20], 'contour')),
  },
  'facet.threeMarks': {
    set: 'facet', sites: [24], verb: 'count',
    parts: [-0.145, 0, 0.145].map(x => P.line([x, -0.17], [x, 0.17], 'verb')),
  },
};

/* ── 5. Rasteriser — analytic coverage, zero dependencies ───────────────────────────────────── */
const clamp01 = v => v < 0 ? 0 : v > 1 ? 1 : v;
const rot = (p, d) => { const a = d * Math.PI / 180, c = Math.cos(a), s = Math.sin(a); return [p[0] * c - p[1] * s, p[0] * s + p[1] * c]; };
const ptOn = (q, a) => [q.c[0] + q.r * Math.cos(a * Math.PI / 180), q.c[1] + q.r * Math.sin(a * Math.PI / 180)];
const norm360 = a => ((a % 360) + 360) % 360;
const sdSeg = (p, a, b) => { const vx = b[0] - a[0], vy = b[1] - a[1], wx = p[0] - a[0], wy = p[1] - a[1], l2 = vx * vx + vy * vy; const t = l2 < 1e-12 ? 0 : Math.max(0, Math.min(1, (wx * vx + wy * vy) / l2)); return Math.hypot(wx - vx * t, wy - vy * t); };
/* Butt caps at the two open ends, miter-ish joins between — PHOSPHOR §2 pass C is butt cap,
   miter join, zero radius. A round-cap rasteriser overstates every stroke by half a weight
   and would let a sigil that actually overruns its stage pass the stage check. */
function sdPolyButt(p, pts, closed) {
  const ring = closed ? [...pts, pts[0]] : pts; let d = Infinity;
  for (let i = 0; i < ring.length - 1; i++) {
    const a = ring[i], b = ring[i + 1], vx = b[0] - a[0], vy = b[1] - a[1], wx = p[0] - a[0], wy = p[1] - a[1], l2 = vx * vx + vy * vy;
    if (l2 < 1e-14) continue;
    let t = (wx * vx + wy * vy) / l2;
    if (t < 0) { if (!closed && i === 0) continue; t = 0; }
    if (t > 1) { if (!closed && i === ring.length - 2) continue; t = 1; }
    d = Math.min(d, Math.hypot(wx - vx * t, wy - vy * t));
  }
  return d;
}
const sdBox = (p, c, s) => { const dx = Math.abs(p[0] - c[0]) - s[0] / 2, dy = Math.abs(p[1] - c[1]) - s[1] / 2; return Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0); };
const inArc = (p, c, a0, a1) => { const th = norm360(Math.atan2(p[1] - c[1], p[0] - c[0]) * 180 / Math.PI); let d = norm360(a1) - norm360(a0); if (d < 0) d += 360; let t = th - norm360(a0); if (t < 0) t += 360; return t <= d; };

function dash(pts, closed, on, off) {
  const ring = closed ? [...pts, pts[0]] : pts, segs = []; let phase = 0, drawing = true, acc = [];
  for (let i = 0; i < ring.length - 1; i++) {
    let a = ring[i]; const b = ring[i + 1];
    let len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (len < 1e-12) continue;
    const ux = (b[0] - a[0]) / len, uy = (b[1] - a[1]) / len;
    while (len > 1e-9) {
      const step = Math.min((drawing ? on : off) - phase, len), c = [a[0] + ux * step, a[1] + uy * step];
      if (drawing) { if (!acc.length) acc.push(a); acc.push(c); }
      a = c; len -= step; phase += step;
      if (phase >= (drawing ? on : off) - 1e-9) { if (drawing && acc.length) { segs.push(acc); acc = []; } drawing = !drawing; phase = 0; }
    }
  }
  if (acc.length) segs.push(acc);
  return segs;
}

function expand(sig) {
  let parts = sig.parts;
  if (sig.rotate) parts = parts.map(q => {
    const r = { ...q };
    if (q.k === 'rect') { r.k = 'poly'; r.pts = rectPts(q.c, q.s).map(p => rot(p, sig.rotate)); r.closed = true; delete r.c; delete r.s; if (q.fill) { r.k = 'fillpoly'; } }
    else { if (q.c) r.c = rot(q.c, sig.rotate); if (q.pts) r.pts = q.pts.map(p => rot(p, sig.rotate)); if (q.k === 'arc') { r.a0 = q.a0 + sig.rotate; r.a1 = q.a1 + sig.rotate; } }
    return r;
  });
  const out = [];
  for (const q of parts) {
    if (q.dash && q.pts) for (const seg of dash(q.pts, q.closed, q.dash[0], q.dash[1])) out.push({ ...q, pts: seg, closed: false, dash: null });
    else out.push(q);
  }
  return out;
}

function raster(sig, U, px, W) {
  const N = px, buf = new Float64Array(N * N), pxN = 1 / N, role = ROLE(U), prims = expand(sig);
  for (const q of prims) {
    const hw = (W[role[q.w]] ?? W.thin) / (2 * U);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const p = [(x + 0.5) / N - 0.5, (y + 0.5) / N - 0.5];
      let cov = 0;
      if (q.k === 'poly') {
        cov = clamp01(0.5 + (hw - sdPolyButt(p, q.pts, q.closed)) / pxN);
      } else if (q.k === 'fillpoly') {
        let inside = false, d = Infinity; const n = q.pts.length;
        for (let i = 0, j = n - 1; i < n; j = i++) {
          const a = q.pts[i], b = q.pts[j];
          if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
          d = Math.min(d, sdSeg(p, a, b));
        }
        cov = clamp01(0.5 + (inside ? d : -d) / pxN);
      } else if (q.k === 'rect') {
        const sd = sdBox(p, q.c, q.s);
        cov = q.fill ? clamp01(0.5 - sd / pxN) : clamp01(0.5 + (hw - Math.abs(sd)) / pxN);
      } else if (q.k === 'circle') {
        const sd = Math.hypot(p[0] - q.c[0], p[1] - q.c[1]) - q.r;
        cov = q.fill ? clamp01(0.5 - sd / pxN) : clamp01(0.5 + (hw - Math.abs(sd)) / pxN);
      } else if (q.k === 'arc') {
        cov = inArc(p, q.c, q.a0, q.a1)   // butt caps: outside the span the arc simply stops
          ? clamp01(0.5 + (hw - Math.abs(Math.hypot(p[0] - q.c[0], p[1] - q.c[1]) - q.r)) / pxN) : 0;
      }
      if (cov > 0) { const i = y * N + x; buf[i] = 1 - (1 - buf[i]) * (1 - cov * q.o); }
    }
  }
  return buf;
}

/* ── 6. Metrics ─────────────────────────────────────────────────────────────────────────────── */
const l1 = (a, b) => { let s = 0; for (let i = 0; i < a.length; i++) s += Math.abs(a[i] - b[i]); return 255 * s / a.length; };
const ink = a => { let s = 0; for (let i = 0; i < a.length; i++) s += a[i]; return s / a.length; };
function offStage(buf, N) {
  const lo = (0.5 - M.stage / 2) * N, hi = (0.5 + M.stage / 2) * N; let worst = 0;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) if (x < lo || x + 1 > hi || y < lo || y + 1 > hi) worst = Math.max(worst, buf[y * N + x]);
  return worst;
}

/* ── 7. CLI ─────────────────────────────────────────────────────────────────────────────────── */
function main() {
  const argv = process.argv.slice(2), keys = Object.keys(SIGILS);
  if (argv.includes('--keys')) { console.log(keys.join('\n')); return 0; }
  if (argv.includes('--json')) { console.log(toJSON()); return 0; }

  const { w: W, src: wsrc } = resolveWeights();
  console.error(wsrc.startsWith('FALLBACK')
    ? 'warning: stroke weights ' + wsrc + '. Re-run once HunchCore/Sources/Tokens/Weight.swift exists.'
    : 'weights from ' + wsrc);

  const s = argv.indexOf('--svg');
  if (s >= 0) { console.log(toSVG(argv[s + 1], 240, W)); return 0; }

  const t = resolveT(argv);
  if (!t) {
    console.error('T unresolved. This harness reuses the glyph renderer\'s pairwise-distinctness\n' +
      'constant (§13.5.1) and will not invent one. Either ship\n' +
      '  HunchCore/Sources/Tokens/C.swift  ->  C.Glyph.minimumPairwiseInkDifference\n' +
      'or pass --t <value> for a provisional run and record in the reference file that it was provisional.');
    return 2;
  }
  console.error(t.raw === null
    ? `T = ${t.T} (mean |Delta|, 8-bit levels) from ${t.src}`
    : `T = ${t.T.toFixed(3)} (mean |Delta|, 8-bit levels) = 255 * ${t.raw} pt^2 / ${COMPARE_U}^2, from ${t.src}`);

  const only = argv.indexOf('--new') >= 0 ? argv[argv.indexOf('--new') + 1] : null;
  if (only && !SIGILS[only]) { console.error(`unknown sigil "${only}" — run --keys`); return 1; }

  let fail = 0;
  for (const k of keys) {
    const b = raster(SIGILS[k], SIGILS[k].sites[0], 44, W), cov = ink(b), off = offStage(b, 44);
    if (cov < M.inkMin || cov > M.inkMax) { console.log(`INK   ${k.padEnd(20)} coverage ${cov.toFixed(3)} outside [${M.inkMin}, ${M.inkMax}]`); fail++; }
    if (off > 0.10) { console.log(`STAGE ${k.padEnd(20)} ${(off * 100).toFixed(0)}% ink outside the ${M.stage} stage`); fail++; }
  }

  /* sigil-grammar.md §3 mirrors M so a reader can see the moduli without opening this file.
     A mirror nobody checks is a second source of truth, so it is checked. */
  const gram = slurp(path.join(__dirname, '../references/sigil-grammar.md')) || '';
  const mirrored = {};
  for (const m of gram.matchAll(/^\|\s*`(\w+)`\s*\|\s*([0-9]*\.?[0-9]+)\s*\|/gm)) mirrored[m[1]] = +m[2];
  for (const [k, v] of Object.entries(mirrored)) {
    if (!(k in M)) { console.log(`MOD   sigil-grammar.md names "${k}", which is not in M`); fail++; }
    else if (Math.abs(M[k] - v) > 1e-9) { console.log(`MOD   ${k.padEnd(20)} M = ${M[k]}, sigil-grammar.md says ${v}`); fail++; }
  }
  for (const k of ['stage', 'authorBound', 'ring', 'ladderW', 'ladderH', 'plateW', 'plateH', 'notchW', 'inkMin', 'inkMax'])
    if (!(k in mirrored)) { console.log(`MOD   ${k.padEnd(20)} is in M but missing from sigil-grammar.md §3`); fail++; }

  /* The write-back gate. A drawing that exists only here is a drawing nobody can find in six
     months, which is the whole failure this skill exists to prevent.
     Ownership is declared by a drawings-table row whose first cell is the backticked key.
     Mentions anywhere else are cross-references and are wanted, not counted. */
  const refDir = path.join(__dirname, '../references');
  const refs = (fs.existsSync(refDir) ? fs.readdirSync(refDir) : []).filter(f => f.endsWith('.md'))
    .map(f => ({ f, body: slurp(path.join(refDir, f)) || '' }));
  for (const k of keys) {
    const owns = new RegExp('^\\|\\s*`' + k.replace(/\./g, '\\.') + '`\\s*\\|', 'm');
    const hits = refs.filter(r => owns.test(r.body));
    if (!hits.length) { console.log(`DOC   ${k.padEnd(20)} owned by no references/ file — add a drawings-table row "| \`${k}\` | ... |"`); fail++; }
    else if (hits.length > 1) { console.log(`DOC   ${k.padEnd(20)} claimed by ${hits.map(h => h.f).join(', ')} — one owner per sigil`); fail++; }
  }

  const pairs = [];
  for (let i = 0; i < keys.length; i++) for (let j = i + 1; j < keys.length; j++) {
    if (only && keys[i] !== only && keys[j] !== only) continue;
    pairs.push([l1(raster(SIGILS[keys[i]], COMPARE_U, 44, W), raster(SIGILS[keys[j]], COMPARE_U, 44, W)), keys[i], keys[j]]);
  }
  pairs.sort((a, b) => a[0] - b[0]);
  console.log(`\nclosest pairs, rendered at U = ${COMPARE_U} into 44 px (mean |Delta|, 8-bit levels):`);
  for (const [d, a, b] of pairs.slice(0, 8)) console.log(`  ${d.toFixed(2).padStart(7)}  ${a}  x  ${b}${d < t.T ? '   <-- BELOW T' : ''}`);
  const bad = pairs.filter(p => p[0] < t.T);
  for (const [d, a, b] of bad) console.log(`FAIL  ${a} and ${b} differ by ${d.toFixed(2)} < T ${t.T.toFixed(3)}`);
  fail += bad.length;

  console.log(fail ? `\n${fail} violation(s).` : `\nOK - ${keys.length} sigils, ${pairs.length} pairs, all clear T = ${t.T.toFixed(3)}.`);
  return fail ? 1 : 0;
}

/* ── 8. The parity dump ──────────────────────────────────────────────────────────────────────
 * `SigilCatalogue.strokes(for:)` in HunchCore is a hand-written Swift copy of this catalogue,
 * and a substring match on the key proves nothing about the coordinates. This emits the whole
 * catalogue in the shape `SigilStroke` decodes, rotation already applied and dashes already
 * expanded, so the Swift can be asserted equal to it point for point:
 *
 *   node check-sigil-distinctness.js --json > HunchCore/Tests/SigilsTests/Fixtures/sigils.json
 *
 * Round every coordinate to 6 dp so the fixture is byte-stable across Node versions; the
 * rotation arithmetic is the only place irrational values enter, and 1e-6 of a box side is
 * 24 nm at the largest site. Keys are emitted in catalogue order, never sorted — the order
 * IS the append-only contract of §4.                                                        */
const r6 = v => Math.round(v * 1e6) / 1e6;
const pt6 = p => ({ x: r6(p[0]), y: r6(p[1]) });

function toJSON() {
  const out = { unit: 'fractions of the box side U, origin at centre, y down, angles cw from East', sigils: {} };
  for (const [key, sig] of Object.entries(SIGILS)) {
    out.sigils[key] = {
      set: sig.set, sites: sig.sites, verb: sig.verb,
      rotate: sig.rotate ?? 0,
      strokes: expand(sig).map(q => {
        const base = { role: q.w, opacity: r6(q.o ?? 1) };
        if (q.k === 'poly') return { ...base, form: 'polyline', closed: !!q.closed, points: q.pts.map(pt6) };
        if (q.k === 'fillpoly') return { ...base, form: 'filledPolygon', points: q.pts.map(pt6) };
        if (q.k === 'rect') return { ...base, form: 'rect', filled: !!q.fill, centre: pt6(q.c), size: pt6(q.s) };
        if (q.k === 'circle') return { ...base, form: 'circle', filled: !!q.fill, centre: pt6(q.c), radius: r6(q.r) };
        return { ...base, form: 'arc', centre: pt6(q.c), radius: r6(q.r), from: r6(q.a0), to: r6(q.a1) };
      }),
    };
  }
  return JSON.stringify(out, null, 2);
}

function toSVG(key, size, W) {
  const g = SIGILS[key]; if (!g) return `<!-- unknown ${key} -->`;
  const U = g.sites[0], k = size / U, role = ROLE(U), o = [], A = ([x, y]) => `${(x * size).toFixed(2)},${(y * size).toFixed(2)}`;
  for (const q of expand(g)) {
    const sw = ((W[role[q.w]] ?? W.thin) * k).toFixed(2), op = q.o;
    if (q.k === 'poly') o.push(`<polyline points="${q.pts.map(A).join(' ')}${q.closed ? ' ' + A(q.pts[0]) : ''}" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="butt" opacity="${op}"/>`);
    else if (q.k === 'fillpoly') o.push(`<polygon points="${q.pts.map(A).join(' ')}" fill="currentColor" opacity="${op}"/>`);
    else if (q.k === 'rect') { const x = ((q.c[0] - q.s[0] / 2) * size).toFixed(2), y = ((q.c[1] - q.s[1] / 2) * size).toFixed(2), w = (q.s[0] * size).toFixed(2), h = (q.s[1] * size).toFixed(2); o.push(q.fill ? `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="currentColor" opacity="${op}"/>` : `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="none" stroke="currentColor" stroke-width="${sw}" opacity="${op}"/>`); }
    else if (q.k === 'circle') o.push(`<circle cx="${(q.c[0] * size).toFixed(2)}" cy="${(q.c[1] * size).toFixed(2)}" r="${(q.r * size).toFixed(2)}" ${q.fill ? 'fill="currentColor"' : `fill="none" stroke="currentColor" stroke-width="${sw}"`} opacity="${op}"/>`);
    else if (q.k === 'arc') { const a = ptOn(q, q.a0), b = ptOn(q, q.a1); let sw2 = norm360(q.a1) - norm360(q.a0); if (sw2 < 0) sw2 += 360; o.push(`<path d="M ${A(a)} A ${(q.r * size).toFixed(2)} ${(q.r * size).toFixed(2)} 0 ${sw2 > 180 ? 1 : 0} 1 ${A(b)}" fill="none" stroke="currentColor" stroke-width="${sw}" opacity="${op}"/>`); }
  }
  /* Eyeballing dump only. The ink is deliberately NOT a token value: on device a sigil draws in
     `stroke.secondary` (idle) or `stroke.primary` (lit) over `ground.base`, resolved through
     `RenderEnv` — hunch-design-tokens owns all three and no hex belongs in this file. */
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="${-size / 2} ${-size / 2} ${size} ${size}" color="white" style="background:black">${o.join('')}</svg>`;
}

if (require.main === module) process.exit(main());
module.exports = { SIGILS, M, THETA, MACRO, ROLE, COMPARE_U, inkAreaToMeanL1, raster, l1, ink, toSVG, toJSON };
