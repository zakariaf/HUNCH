---
name: hunch-glyph-renderer
description: "Generates the 256-glyph deck from (fill, shape, pips, hue, size) — silhouette corner count, contour pip nodes, interior texture coverage, the index stroke that carries hue — and owns the screen-frame coordinate convention, the two size regimes and the greyscale distinctness proof. Use for anything touching a glyph, the deck, GlyphShape, GlyphCanvas, or any SwiftUI Shape or Canvas that draws a glyph — bloom over one, or how a mark reads at 24, 44, 96 or 220 pt. Not for ramp cells, ribbon tiles or Assay cells that merely contain a glyph — those are the bench skill."
allowed-tools: Read, Grep, Glob, Bash(node ${CLAUDE_SKILL_DIR}/scripts/*), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "glyph geometry, the four registers, the two size regimes, the four-pass draw order, the distinctness constant T"
---

## Step 0 — read the renderer as it exists right now

**Before anything else, run `bash ${CLAUDE_SKILL_DIR}/scripts/current-state.sh`.** It lists the
`Glyph*.swift` symbols and the shipped `C.Glyph` members. **Trust that listing over every table
below it**: if it prints symbols and a reference file disagrees, the Swift wins and the reference
file is the bug. If it prints `GLYPH RENDERER NOT BUILT YET`, `references/geometry.md` §4 is the
spec and the file is yours to create.

## The coordinate frame — resolve this before drawing anything

**Screen coordinates. Origin at the centre of the S-box, +x trailing, +y DOWN, angles clockwise from East. Every y value in GAME_DESIGN.md §13.5 is negated on the way in.** So `bodyCentre = (0, −0.10·S)` and the index register sits at `(0, +0.43·S)`.

§13.5 states its positions in a y-up frame (`bodyCentre = +0.10·S`, index at `−0.43·S`, "below the body") and its angles in the screen frame (N = −90°, triangle apex-up at −90°). Both cannot hold at once. Read it y-up and the triangle points down, the N pip lands at the bottom and the index stroke floats above the body. The negation is the only reading under which every sentence of §13.5 is simultaneously true, and it is what `references/reference-renderer.js` implements and what `DIRECTION-A-PHOSPHOR.md` §5 independently arrived at. Ported to Swift this is free — SwiftUI's `Path` is already y-down.

## The four registers

Spatially disjoint by construction (§2), which is what makes each channel readable with the other three removed. **A glyph is monochrome in its own hue**: body, texture, pips and index stroke all take one `HueColor` (§13.5).

| Register | Geometry | Where the constants live | Where the colour lives |
|---|---|---|---|
| `shape` — outer silhouette | regular polygon inscribed in `R = 0.37·S`, corner count 0 / 3 / 4 / 6 | `geometry.md` §3 (§13.5) | `env.palette.hue.*` |
| `pips` — contour nodes | discs on the ray from `bodyCentre` at −90° / 0° / +90° / 180°, progressive N→E→S→W | `geometry.md` §5 (§2, §13.5) | same hue; knockout is `ground` |
| `fill` — interior texture | clipped to the silhouette inset `1.5 × bodyWeight`, pitch-pinned | `fill-textures.md` (§13.5) | same hue |
| `hue` — index stroke | one segment at `(0, +0.43·S)`, length `0.273·S`, rotated 0° / 45° / 90° / 135° | `geometry.md` §7 (§13.5) | same hue |

Every colour, weight, opacity and duration named above resolves through `hunch-design-tokens`. This skill states no hex, no `lineWidth` number and no `.opacity` literal — it states *where on the glyph* and *how big relative to `S`*.

## To draw a glyph

1. **Take `(glyph, side S, RenderEnv)` and nothing else.** The renderer is a pure function. No `@State`, no clock, no animation inside it — a glyph that animates itself cannot be snapshot-tested and cannot be composed into the Assay's 256 cells.
2. **Derive, never hardcode.** `C.Glyph.*` in `HunchCore/Sources/Tokens/C.swift` owns the derivation; `geometry.md` §2 is the full member list. `bodyStroke`, `keylineStroke` and `haloStroke` already ship there.
3. **Emit the four passes in order** — B halo, C ink (texture, then keyline in the light theme, then silhouette), D pip knockout, then the index stroke last. `reference-renderer.js`'s `drawList()` is that sequence, op for op.
4. **Reserve the bleed.** The drawing overflows the S-box: frost's index stroke reaches `y = 0.5665·S`. Lay it out with `C.Glyph.bleed(side:in:)` and `.clipped()` nowhere near it.
5. **Hide it from VoiceOver.** `GlyphCanvas` is a picture; its *host* carries the label (§13.10). See the accessibility table below.
6. **Check it.** `node ${CLAUDE_SKILL_DIR}/scripts/render-all-256.js --size 44` prints the derived geometry, the required bleed per hue and the measured ink ladder for one size. `check-coverage-separation.js` is the §13.5.1 gate.

## The two size regimes

`S < 48` → `env.weight(.bodySm)` for the silhouette; `S ≥ 48` → `env.weight(.body)`. **The index stroke is always `env.weight(.body)`** even when the silhouette thins — the hue channel is deliberately the heaviest non-colour mark on the glyph (§13.5).

The regime is a *rule*, not a token: `C.Glyph.bodyStroke(side:in:)`. Shipped sites, all in the small regime except the throat and the Codex hero: SIEVE tail and ECHO seed 36 · ribbon tile, ECHO rail, ECHO primer, Codex thumbnail 44 · ECHO tray 52 · SIEVE lane 72 · throat 96 (SE) / 128 (Pro Max) · Codex hero 220. Ramp cells draw a glyph inside a 70 × 48 or 56 × 44 cell; the cell is the bench skill's, the glyph in it is this one's.

## States and variants

| State | What changes | Owner |
|---|---|---|
| plain | — | here |
| bloomed | passes A and B are added | here (`bloom-and-squash.md`) |
| ghosted | the glyph draws unchanged; a dashed frame and backward chevron are laid over it | `hunch-shared-marks` |
| eliminated | the glyph draws unchanged at `C.Ramp.cellUnlitInk(in:)` under a cancel hatch | `hunch-bench-instruments` |
| admit / reject animating | the glyph does not animate; a ring and a scale are applied by its host | `hunch-motion-and-feedback` |
| monochrome | not a parameter — swapping the palette must leave every alpha unchanged (§13.5.1 test 1) | here (`triple-encoding-proof.md` §5) |

**Accessibility, all three settings.** VoiceOver: the glyph is `.accessibilityHidden(true)`; the host declares traits and reads `GLYPH_LABEL`, one localized format string with four interpolations in canonical `fill → shape → pips → hue` order, the `pips` interpolation itself a plural-aware String Catalog entry (§13.10). Reduce Motion: **nothing** — the renderer has no time axis; substitutions belong to `hunch-motion-and-feedback`. High Contrast: `env` substitutes hue → `stroke.primary` and the index stroke lengthens `0.273·S → 0.409·S`; that lengthening is *geometry* and is this skill's, and it is a substitution — never also scaled.

## Where the detail lives

| Read this | When |
|---|---|
| `references/geometry.md` | before writing or editing `GlyphShape` / `GlyphCanvas` — the full `C.Glyph` member list, the compiling renderer, vertex angles, pip ray intersection, the bleed derivation |
| `references/fill-textures.md` | when a fill looks wrong at a size, or before touching pitch, dot radius, stripe weight or the inset |
| `references/triple-encoding-proof.md` | before changing any register's geometry, and whenever `T` or the greyscale claim is in question |
| `references/bloom-and-squash.md` | when bloom, the halo, the blurred bed or an offscreen layer is involved — including "why is the Assay never bloomed" |
| `references/reference-renderer.js` | when porting to Swift, or to settle what the geometry actually does — it runs |

`node ${CLAUDE_SKILL_DIR}/scripts/render-all-256.js [--size 44] [--theme …] [--bold] [--no-bloom] [--out sheet.pgm]` — derived geometry, per-hue bleed, measured ink ladder, 16 × 16 contact sheet.
`node ${CLAUDE_SKILL_DIR}/scripts/check-coverage-separation.js` — the §13.5.1 gate at 44 pt across six environments (~85 s; design-time and CI, not a unit test). `--sweep` for the size table, `--size N` for one configuration.

## Gotchas

- **`bleed.glyph = 0.08·S` clips the glyph in two regimes, and only on the y axis.** With bloom on it clips teal and rose for `32 ≤ S < 59.5` — 4.35 pt needed against 3.52 at S = 44, which is the ribbon tile, the Codex thumbnail, the ECHO rail and (at 36) the SIEVE tail and ECHO seed. Under **High Contrast it clips frost at every size**, because the index stroke substitutes to `0.409·S` and frost needs `0.1345·S` — 12.9 pt against 7.7 at the throat, 29.6 against 17.6 at the Codex hero. Use `C.Glyph.bleed(side:in:)`; `geometry.md` §6 derives it and the x component is always 0.
- **The interior *shrinks* when the glyph crosses S = 48.** `fillInset = 1.5 × bodyWeight` and the weight steps 1.5 → 3.0, so the inset radius goes 14.03 pt at S = 44 to 13.26 pt at S = 48. The fill texture has less room on a larger glyph. Expected, not a bug — but it is why the ink ladder is measured per size rather than asserted once.
- **`fill` coverage is pitch-invariant as a *ratio* and not as a *raster*.** Measured `dotted` across shapes and sizes is 17–31 % against a nominal 22.7 %, because `pitch` floors at 5 pt and only ~3–6 dots span the inset chord below S ≈ 60. The ladder never inverts in the inset reading, at any size, with bloom on or off; it inverts in the *interior* reading at S = 24, 48 and 52 — which is the sign that the mean is the wrong statistic and §13.5.1's pairwise raster distance is the right one. `fill-textures.md` §4 has the table.
- **The halo does not corrupt the fill ladder, and the reason is a coincidence you must not break.** The halo half-width is `1.5 × bodyWeight` and the fill inset is also `1.5 × bodyWeight`, so the halo's inner edge lands exactly on the clip boundary and deposits nothing inside it — measured 0.0 % for `hollow` with bloom on at every size. Widen the halo past ×3 without moving the inset and PHOSPHOR §6.4's failure becomes real.
- **The pip knockout must run before the index stroke, because the two registers touch.** `frost`'s stroke tip lands *inside* the S pip disc on `circle` and `hexagon` at every size — 1.82 pt from the node centre at S = 44 against a `pipRadius` of 3.0. Reorder the draw calls and a `ground` ring cuts a notch out of the hue channel on a quarter of the deck. It is also why `pips two ↔ three` is the deck's distinctness floor. `geometry.md` §5.1.
- **The lattice is anchored at `bodyCentre`, not at the clip's bounding box.** Phasing the dot rows off a loop start makes the pattern move with `R`, so the same fill renders differently at two sizes and stops being a token.
- **Reduce Motion does not disable bloom.** Reduce Transparency, High Contrast and Low Power Mode do (`env.isBloomEnabled`), plus this skill's `S ≥ 32` geometry gate. Conflating the two settings is the most common way the play surface ends up wrong for the wrong player.
- **`pips` is the weakest channel at 44 pt and above; `fill` is the weakest at 36 and below.** Measured minimum pairwise difference at 44 pt is 8.94 pt² (High Contrast + Bold Text) against T = 8.0 — a 12 % margin, and High Contrast is the worst environment precisely because thickening every stroke shrinks a pip's *marginal* contribution. At 24 pt the floor collapses to 1.82 pt² and the deck stops being provably separable, which is survivable only because no shipped site draws a glyph below 36 pt. §13.5's "identically at every size from 24 pt to 220 pt" is true of the arithmetic and false of the raster.

## Never

- Never centre the glyph on the rect's centre. `bodyCentre` is `0.10·S` above it, and using the rect centre silently moves all four pips and the index register.
- Never round a glyph corner. Corner count *is* the `shape` channel; `radius.glyph` is 0 always, joins are miter, caps are butt (§13.1 makes it a PR-rejection offence).
- Never let `accent.*` reach a glyph body, texture, pip or index stroke, and never let `hue.*` reach chrome. The registers are distinct Swift types; laundering one through `.rgb` defeats the type split.
- Never thin the index stroke with the silhouette, and never scale its High Contrast length — `0.409·S` is a substitution that terminates resolution.
- Never widen the fill texture or the pips in the halo pass. Only the body outline and the index stroke are re-stroked; widening a dot pattern raises measured ink coverage and compresses the rung the greyscale proof rests on.
- Never blur per glyph. The bed is one offscreen layer per glyph-bearing *region* — throat, ribbon, tail — and the Assay is excluded at every size and in every state.
- Never give a glyph an accessibility label, a gradient, a texture inside its body, an image asset, or an `SF Symbol`. The fill register is game state and must be a flat pattern; there is no bitmap anywhere in the deck.
- Never lower `T` to make a test pass. T guards the one claim the accessibility case rests on; a failure means the geometry changed.
