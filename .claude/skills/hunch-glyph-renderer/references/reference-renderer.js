'use strict';
/*
 * reference-renderer.js — the executable specification of HUNCH's 256-glyph deck.
 *
 * READ THIS BEFORE PORTING THE RENDERER TO SWIFT. It is not a mockup helper: `geometry()`
 * and `drawList()` are the two functions `GlyphCanvas` must mirror op-for-op, and
 * `coverageMask()` is the rasteriser the two shipped tests in GAME_DESIGN.md §13.5.1 are
 * measured against.
 *
 * Frame: SCREEN coordinates. Origin at the centre of the S-box, +x trailing, +y DOWN,
 * angles clockwise from East. GAME_DESIGN.md §13.5 states its y values in a y-up frame
 * and its angles in the screen frame; both cannot hold, so every GDD y is negated here.
 * See references/geometry.md §1 for the full argument.
 *
 * Everything is derived from (fill, shape, pips, hue, S, env). No path data is authored.
 * No dependencies. Runs under `node` with no package.json.
 */

// ── The deck ────────────────────────────────────────────────────────────────────────
// Canonical order, GAME_DESIGN.md §2: fill → shape → pips → hue, everywhere and forever.

const FILLS = ['hollow', 'dotted', 'striped', 'solid'];
const SHAPES = ['circle', 'triangle', 'square', 'hexagon'];
const PIPS = ['one', 'two', 'three', 'four'];
const HUES = ['amber', 'teal', 'frost', 'rose'];

/** glyphID = fill*64 + shape*16 + pips*4 + hue — 0…255, stable forever (§2). */
function glyphID(g) {
  return FILLS.indexOf(g.fill) * 64 + SHAPES.indexOf(g.shape) * 16
    + PIPS.indexOf(g.pips) * 4 + HUES.indexOf(g.hue);
}

function glyphAt(id) {
  return {
    fill: FILLS[(id >> 6) & 3], shape: SHAPES[(id >> 4) & 3],
    pips: PIPS[(id >> 2) & 3], hue: HUES[id & 3],
  };
}

const DECK = Array.from({ length: 256 }, (_, id) => glyphAt(id));

// Vertex angles in the screen frame, ascending = convex order. Apex-up triangle,
// axis-aligned square, pointy-top hexagon (§13.5).
const VERTEX_ANGLES = {
  circle: null,
  triangle: [-90, 30, 150],
  square: [-135, -45, 45, 135],
  hexagon: [-90, -30, 30, 90, 150, 210],
};
const PIP_RAYS = [-90, 0, 90, 180];                       // N, E, S, W — progressive
const PIP_COUNT = { one: 1, two: 2, three: 3, four: 4 };
const INDEX_ROTATION = { amber: 0, teal: 45, frost: 90, rose: 135 };

const rad = (d) => (d * Math.PI) / 180;

// ── Geometry ────────────────────────────────────────────────────────────────────────

/**
 * Every derived constant, from S and the render environment. This is the function
 * `C.Glyph` mirrors in Swift; see references/geometry.md §2 for the token citations.
 *
 * env: { theme: 'dark'|'light'|'highContrast', boldText, reduceTransparency, lowPower }
 */
function geometry(S, env = {}) {
  const highContrast = env.theme === 'highContrast';
  const boldK = env.boldText ? 1.25 : 1;
  const hcOffset = highContrast ? 0.5 : 0;

  // Resolution order is the token skill's, not ours: SELECT → SCALE → OFFSET → DERIVE.
  const bodyWeight = (S < 48 ? 1.5 : 3.0) * boldK + hcOffset;   // the two size regimes
  const indexWeight = 3.0 * boldK + hcOffset;                   // never thins with S
  const knockoutWeight = 1.0;                                   // opts out of both axes

  const R = 0.37 * S;
  const centre = [0, -0.10 * S];                                // GDD +0.10·S, y-up
  const indexCentre = [0, +0.43 * S];                           // GDD −0.43·S, y-up
  const indexLength = (highContrast ? 0.409 : 0.273) * S;       // substitution, not scale

  const pitch = Math.max(5, 0.22 * R);
  const bloom = env.bloom !== false && !highContrast
    && !env.reduceTransparency && !env.lowPower && S >= 32;

  return {
    S, R, centre, indexCentre, indexLength, indexWeight, bodyWeight, knockoutWeight,
    pitch,
    dotRadius: 0.25 * pitch,
    stripeWeight: 0.386 * pitch,
    pipRadius: Math.max(3, 0.11 * R),
    fillInset: 1.5 * bodyWeight,
    haloWeight: bodyWeight * 3,
    haloIndexWeight: indexWeight * 3,
    haloAlpha: 0.12,
    keylineWeight: env.theme === 'light' ? bodyWeight + 1.0 : null,
    bloom,
    highContrast,
  };
}

/** Half-width the drawing actually reaches beyond the S-box, per hue. See geometry.md §6. */
function bleed(S, env = {}) {
  const g = geometry(S, env);
  const halfIndex = (g.bloom ? g.haloIndexWeight : g.indexWeight) / 2;
  // A round halo join reaches half its width; a miter join on the triangle's 60° corner
  // reaches (W/2) / sin 30° = W, the worst of the four shapes.
  const bodyReach = g.bloom ? g.haloWeight / 2 : g.bodyWeight;
  const L2 = g.indexLength / 2;
  let maxY = 0.47 * S + bodyReach;                              // silhouette, top edge
  let maxX = 0.37 * S + bodyReach;
  for (const hue of HUES) {
    const t = rad(INDEX_ROTATION[hue]);
    maxY = Math.max(maxY, 0.43 * S + L2 * Math.abs(Math.sin(t)) + halfIndex * Math.abs(Math.cos(t)));
    maxX = Math.max(maxX, L2 * Math.abs(Math.cos(t)) + halfIndex * Math.abs(Math.sin(t)));
  }
  return { x: Math.max(0, maxX - S / 2), y: Math.max(0, maxY - S / 2) };
}

// Regular convex polygons are represented by their edge normals and one apothem, because
// offsetting such a polygon is a change of apothem — which makes the miter-joined stroke
// band exact rather than approximated.
function polyForm(shape, R) {
  const angles = VERTEX_ANGLES[shape];
  if (!angles) return null;
  const n = angles.length;
  const apothem = R * Math.cos(Math.PI / n);
  const normals = angles.map((a) => {
    const m = rad(a + 180 / n);
    return [Math.cos(m), Math.sin(m)];
  });
  return { n, apothem, normals, vertices: angles.map((a) => [R * Math.cos(rad(a)), R * Math.sin(rad(a))]) };
}

/** Where the ray from `centre` at `deg` meets the silhouette centre-line. */
function contourHit(shape, geo, deg) {
  const d = [Math.cos(rad(deg)), Math.sin(rad(deg))];
  const [cx, cy] = geo.centre;
  const form = polyForm(shape, geo.R);
  if (!form) return [cx + d[0] * geo.R, cy + d[1] * geo.R];
  let t = Infinity;
  for (const nv of form.normals) {
    const dn = d[0] * nv[0] + d[1] * nv[1];
    if (dn > 1e-9) t = Math.min(t, form.apothem / dn);
  }
  return [cx + d[0] * t, cy + d[1] * t];
}

// ── The draw list ───────────────────────────────────────────────────────────────────

/**
 * Every primitive, in draw order, for one glyph. The Swift `GlyphCanvas` emits this same
 * sequence into a `GraphicsContext`; the rasteriser below interprets it. Two consumers,
 * one description — which is what makes "the JS and the Swift draw the same glyph" a
 * checkable claim rather than a hope.
 *
 * Passes (DIRECTION-A-PHOSPHOR.md §2): A bed (per REGION, never here), B halo,
 * C ink, D knockout.
 */
function drawList(glyph, geo) {
  const ops = [];
  const { centre, R, bodyWeight, indexWeight } = geo;
  const form = polyForm(glyph.shape, R);
  const silhouette = form
    ? { kind: 'polygon', centre, apothem: form.apothem, normals: form.normals }
    : { kind: 'circle', centre, radius: R };

  const u = [Math.cos(rad(INDEX_ROTATION[glyph.hue])), Math.sin(rad(INDEX_ROTATION[glyph.hue]))];
  const h = geo.indexLength / 2;
  const indexSegment = {
    a: [geo.indexCentre[0] - u[0] * h, geo.indexCentre[1] - u[1] * h],
    b: [geo.indexCentre[0] + u[0] * h, geo.indexCentre[1] + u[1] * h],
  };

  // PASS B — halo. Body outline and index stroke only. The fill texture and the pips are
  // deliberately excluded: widening a dot pattern raises measured ink coverage and
  // corrupts the fill ladder the greyscale proof rests on.
  if (geo.bloom) {
    ops.push({ pass: 'B', op: 'strokeOutline', geom: silhouette, weight: geo.haloWeight, join: 'round', alpha: geo.haloAlpha, paint: 'ink' });
    ops.push({ pass: 'B', op: 'strokeSegment', seg: indexSegment, weight: geo.haloIndexWeight, cap: 'butt', alpha: geo.haloAlpha, paint: 'ink' });
  }

  // PASS C — the mark. Fill texture first, clipped to the inset silhouette, then the
  // silhouette itself so the keyline sits over the texture's cut edge.
  if (glyph.fill !== 'hollow') {
    const clip = form
      ? { kind: 'polygon', centre, apothem: form.apothem - geo.fillInset, normals: form.normals }
      : { kind: 'circle', centre, radius: R - geo.fillInset };
    if (glyph.fill === 'solid') {
      ops.push({ pass: 'C', op: 'fillRegion', geom: clip, alpha: 1, paint: 'ink' });
    } else if (glyph.fill === 'dotted') {
      ops.push({ pass: 'C', op: 'fillDotLattice', clip, anchor: centre, pitch: geo.pitch, radius: geo.dotRadius, alpha: 1, paint: 'ink' });
    } else {
      ops.push({ pass: 'C', op: 'fillStripes', clip, anchor: centre, pitch: geo.pitch, weight: geo.stripeWeight, degrees: 45, alpha: 1, paint: 'ink' });
    }
  }
  if (geo.keylineWeight != null) {
    // Light theme only: a stroke.primary keyline UNDER the hue, so the silhouette edge
    // reads 15.6 : 1 while Okabe–Ito stays verbatim (§13.2). Colour, not geometry.
    ops.push({ pass: 'C', op: 'strokeOutline', geom: silhouette, weight: geo.keylineWeight, join: 'miter', alpha: 1, paint: 'keyline' });
  }
  ops.push({ pass: 'C', op: 'strokeOutline', geom: silhouette, weight: bodyWeight, join: 'miter', alpha: 1, paint: 'ink' });

  // PASS D — pips and their knockout. Drawn after the body so the ring separates the node
  // from the silhouette stroke and from fill texture reaching the contour.
  for (let i = 0; i < PIP_COUNT[glyph.pips]; i += 1) {
    const c = contourHit(glyph.shape, geo, PIP_RAYS[i]);
    ops.push({ pass: 'D', op: 'strokeDisc', centre: c, radius: geo.pipRadius + 0.5, weight: geo.knockoutWeight, alpha: 1, paint: 'ground' });
    ops.push({ pass: 'D', op: 'fillDisc', centre: c, radius: geo.pipRadius, alpha: 1, paint: 'ink' });
  }

  // The index stroke is last and is never knocked out: it is the hue channel, and it
  // OVERLAPS the S node. Frost's tip lands inside the pip disc on circle and hexagon at
  // every size (1.82 pt from the node centre at S = 44, against pipRadius 3.0); teal and
  // rose reach inside the knockout ring at S <= 44. Knock out first, ink the hue last.
  ops.push({ pass: 'C', op: 'strokeSegment', seg: indexSegment, weight: indexWeight, cap: 'butt', alpha: 1, paint: 'ink' });
  return ops;
}

// ── Rasteriser ──────────────────────────────────────────────────────────────────────
// Produces a COVERAGE mask: one ink level for every register, ground = 0. Colour is not
// modelled, deliberately — see references/triple-encoding-proof.md §2 for why the
// single-ink raster is the adversarial case and a per-hue luminance raster is weaker.

function insideRegion(geom, x, y) {
  if (geom.kind === 'circle') {
    const dx = x - geom.centre[0], dy = y - geom.centre[1];
    return dx * dx + dy * dy <= geom.radius * geom.radius;
  }
  const dx = x - geom.centre[0], dy = y - geom.centre[1];
  for (const nv of geom.normals) if (dx * nv[0] + dy * nv[1] > geom.apothem) return false;
  return true;
}

function offsetRegion(geom, delta) {
  return geom.kind === 'circle'
    ? { kind: 'circle', centre: geom.centre, radius: geom.radius + delta }
    : { kind: 'polygon', centre: geom.centre, apothem: geom.apothem + delta, normals: geom.normals };
}

function distanceToOutline(geom, x, y) {
  if (geom.kind === 'circle') {
    const dx = x - geom.centre[0], dy = y - geom.centre[1];
    return Math.abs(Math.hypot(dx, dy) - geom.radius);
  }
  // Regular polygon: min distance to any edge segment. Exact for a round join.
  const n = geom.normals.length;
  const R = geom.apothem / Math.cos(Math.PI / n);
  const step = (2 * Math.PI) / n;
  const base = Math.atan2(geom.normals[0][1], geom.normals[0][0]) - Math.PI / n;
  let best = Infinity;
  for (let i = 0; i < n; i += 1) {
    const a0 = base + i * step, a1 = base + (i + 1) * step;
    const px = geom.centre[0] + R * Math.cos(a0), py = geom.centre[1] + R * Math.sin(a0);
    const qx = geom.centre[0] + R * Math.cos(a1), qy = geom.centre[1] + R * Math.sin(a1);
    best = Math.min(best, distanceToSegment(x, y, px, py, qx, qy));
  }
  return best;
}

function distanceToSegment(x, y, px, py, qx, qy) {
  const ex = qx - px, ey = qy - py;
  const len2 = ex * ex + ey * ey;
  let t = len2 === 0 ? 0 : ((x - px) * ex + (y - py) * ey) / len2;
  t = t < 0 ? 0 : t > 1 ? 1 : t;
  return Math.hypot(x - (px + ex * t), y - (py + ey * t));
}

function opCovers(op, x, y) {
  switch (op.op) {
    case 'strokeOutline': {
      if (op.join === 'miter') {
        // Offsetting a regular convex polygon is a change of apothem, so the miter band
        // is exact. A distance test would round the triangle's 60° corners.
        return insideRegion(offsetRegion(op.geom, op.weight / 2), x, y)
          && !insideRegion(offsetRegion(op.geom, -op.weight / 2), x, y);
      }
      return distanceToOutline(op.geom, x, y) <= op.weight / 2;
    }
    case 'fillRegion':
      return insideRegion(op.geom, x, y);
    case 'fillDisc':
      return Math.hypot(x - op.centre[0], y - op.centre[1]) <= op.radius;
    case 'strokeDisc': {
      const d = Math.hypot(x - op.centre[0], y - op.centre[1]);
      return Math.abs(d - op.radius) <= op.weight / 2;
    }
    case 'strokeSegment': {
      // Butt cap: no extension past either end, so a 45° stroke has an honest length.
      const ex = op.seg.b[0] - op.seg.a[0], ey = op.seg.b[1] - op.seg.a[1];
      const len = Math.hypot(ex, ey);
      const ux = ex / len, uy = ey / len;
      const dx = x - op.seg.a[0], dy = y - op.seg.a[1];
      const along = dx * ux + dy * uy;
      if (along < 0 || along > len) return false;
      return Math.abs(-dx * uy + dy * ux) <= op.weight / 2;
    }
    case 'fillDotLattice': {
      if (!insideRegion(op.clip, x, y)) return false;
      // Hex packing anchored at the BODY CENTRE, not at the clip's bounding box: a
      // lattice phased off the loop start would move with R and stop being a token.
      const dy = (op.pitch * Math.sqrt(3)) / 2;
      const jr = Math.round((y - op.anchor[1]) / dy);
      for (let j = jr - 1; j <= jr + 1; j += 1) {
        const rowY = op.anchor[1] + j * dy;
        const xoff = (((j % 2) + 2) % 2) === 1 ? op.pitch / 2 : 0;
        const ir = Math.round((x - op.anchor[0] - xoff) / op.pitch);
        for (let i = ir - 1; i <= ir + 1; i += 1) {
          const cx = op.anchor[0] + xoff + i * op.pitch;
          if (Math.hypot(x - cx, y - rowY) <= op.radius) return true;
        }
      }
      return false;
    }
    case 'fillStripes': {
      if (!insideRegion(op.clip, x, y)) return false;
      const t = rad(op.degrees);
      const nx = -Math.sin(t), ny = Math.cos(t);
      const s = (x - op.anchor[0]) * nx + (y - op.anchor[1]) * ny;
      const k = s - Math.round(s / op.pitch) * op.pitch;
      return Math.abs(k) <= op.weight / 2;
    }
    default:
      throw new Error(`unknown op ${op.op}`);
  }
}

/**
 * @returns {{data: Uint8Array, px: number, halfBox: number, ptPerPx: number}}
 * `data` is row-major, 0 = ground, 255 = full ink.
 */
function coverageMask(glyph, S, opts = {}) {
  const env = opts.env || {};
  const scale = opts.scale || 2;
  const bleedFactor = opts.bleedFactor != null ? opts.bleedFactor : 0.16;
  const ss = opts.samples || 4;
  const geo = geometry(S, env);
  const ops = drawList(glyph, geo);

  const halfBox = S * (0.5 + bleedFactor);
  const px = Math.round(2 * halfBox * scale);
  const ptPerPx = (2 * halfBox) / px;
  const acc = new Float32Array(px * px);
  const sub = ptPerPx / ss;

  for (const op of ops) {
    for (let row = 0; row < px; row += 1) {
      const y0 = -halfBox + row * ptPerPx;
      for (let col = 0; col < px; col += 1) {
        const x0 = -halfBox + col * ptPerPx;
        let hits = 0;
        for (let sy = 0; sy < ss; sy += 1) {
          const y = y0 + (sy + 0.5) * sub;
          for (let sx = 0; sx < ss; sx += 1) {
            if (opCovers(op, x0 + (sx + 0.5) * sub, y)) hits += 1;
          }
        }
        if (hits === 0) continue;
        const a = (hits / (ss * ss)) * op.alpha;
        const i = row * px + col;
        // `ground` is a knockout: it paints 0, it does not blend toward it.
        acc[i] = op.paint === 'ground' ? acc[i] * (1 - a) : acc[i] * (1 - a) + a;
      }
    }
  }

  const data = new Uint8Array(px * px);
  for (let i = 0; i < data.length; i += 1) data[i] = Math.round(255 * Math.min(1, acc[i]));
  return { data, px, halfBox, ptPerPx };
}

/**
 * Mean ink inside a region of the body, 0…1. This is the number the `fill` ladder is a
 * claim about, and WHICH REGION decides whether the claim survives bloom:
 *
 *   region 'inset'    — the fill clip itself, apothem − 1.5·bodyWeight. The halo's half
 *                       width IS 1.5·bodyWeight, so the halo's inner edge coincides with
 *                       this boundary exactly and deposits nothing inside it. The ladder
 *                       is 0 / 22.7 / 38.6 / 100 here, bloom or no bloom.
 *   region 'interior' — everything inside the silhouette centre-line. The halo's inner
 *                       half and the body stroke's inner half both land here, so
 *                       `hollow` is not 0 and the 0 → 22.7 step really is compressed.
 *
 * Passes B and C only: pips and the index stroke are other registers and are scored by
 * their own channels.
 */
function measuredFillCoverage(glyph, S, opts = {}) {
  const env = opts.env || {};
  const geo = geometry(S, env);
  const form = polyForm(glyph.shape, geo.R);
  const inset = form
    ? { kind: 'polygon', centre: geo.centre, apothem: form.apothem - geo.fillInset, normals: form.normals }
    : { kind: 'circle', centre: geo.centre, radius: geo.R - geo.fillInset };
  const interior = form
    ? { kind: 'polygon', centre: geo.centre, apothem: form.apothem, normals: form.normals }
    : { kind: 'circle', centre: geo.centre, radius: geo.R };
  const region = opts.region === 'interior' ? interior : inset;
  const ops = drawList(glyph, geo).filter((o) => o.pass === 'B'
    || (o.pass === 'C' && o.paint === 'ink'));

  const ss = opts.samples || 6;
  const n = Math.ceil(2 * geo.R * (opts.scale || 4));
  const step = (2 * geo.R + 4) / n;
  let inside = 0, ink = 0;
  for (let row = 0; row < n; row += 1) {
    for (let col = 0; col < n; col += 1) {
      const x0 = geo.centre[0] - geo.R - 2 + col * step;
      const y0 = geo.centre[1] - geo.R - 2 + row * step;
      for (let sy = 0; sy < ss; sy += 1) {
        for (let sx = 0; sx < ss; sx += 1) {
          const x = x0 + ((sx + 0.5) / ss) * step;
          const y = y0 + ((sy + 0.5) / ss) * step;
          if (!insideRegion(region, x, y)) continue;
          inside += 1;
          let v = 0;
          for (const op of ops) if (opCovers(op, x, y)) v = v * (1 - op.alpha) + op.alpha;
          ink += v;
        }
      }
    }
  }
  return inside === 0 ? 0 : ink / inside;
}

module.exports = {
  FILLS, SHAPES, PIPS, HUES, DECK, VERTEX_ANGLES, PIP_RAYS, PIP_COUNT, INDEX_ROTATION,
  glyphID, glyphAt, geometry, bleed, polyForm, contourHit, drawList,
  coverageMask, measuredFillCoverage,
};
