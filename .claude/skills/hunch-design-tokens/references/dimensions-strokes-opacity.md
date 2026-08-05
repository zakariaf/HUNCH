# dimensions-strokes-opacity.md — L1 lengths, weights and opacities

Contents: [1 Stroke weight](#1-stroke-weight) · [2 The resolved matrix](#2-the-resolved-matrix) ·
[3 Space and length](#3-space-and-length) · [4 Radius](#4-radius) · [5 Opacity](#5-opacity) ·
[6 What is not here](#6-what-is-not-here) · [7 Adding one](#7-adding-one)

---

## 1. Stroke weight

Five tokens, §13.3 verbatim. `base` is the value at Large with no accessibility setting on.

| Token | base pt | Applied to |
|---|---|---|
| `weight.hairline` | 0.5 | chrome rules, the Assay's 16×16 grid, empty-rail outline, plate frames |
| `weight.thin` | 1.0 | ramp cell borders, rule-tile frames, pip knockout ring |
| `weight.bodySm` | 1.5 | glyph body below S = 48, fill hatch at small sizes |
| `weight.body` | 3.0 | glyph body at S ≥ 48, index stroke (always), wedge, coupler strands |
| `weight.heavy` | 4.0 | the machined bar across a barred Seal, the AND welded bar |

**All five respond to Bold Text.** §13.11's prose scopes the ×1.25 step to "glyph and rule-tile
stroke weights", but its worked examples include `hairline` — which by §13.3 is chrome-only. The
examples are the operative version, because they are the numbers. Two consequences force the
all-five reading:

- **Eligibility is a property of the token, not of the site.** `weight.hairline` draws both a chrome
  divider and the Assay grid. If it stepped at one site and not the other it would not be a token.
- **The ladder has to stay a ladder.** If `weight.body` stepped to 3.75 while `weight.heavy` held at
  4.0, the gap that makes the AND welded bar read as heavier than a body stroke would collapse from
  1.0 pt to 0.25 pt. Under Bold Text the whole scale moves together or the scale stops meaning
  anything.

`respondsToBoldText` stays on the token anyway, defaulting to `true`, because L2 weights need to
opt out: the pip knockout ring is a 1 pt geometric separator that must stay 1 pt or it eats the pip.

---

## 2. The resolved matrix

`env.weight(_:)` is the only way to read a weight. The four environment states, computed:

| Token | neither | Bold Text | High Contrast | **both** |
|---|---|---|---|---|
| `weight.hairline` | 0.500 | 0.625 | 1.000 | **1.125** |
| `weight.thin` | 1.000 | 1.250 | 1.500 | **1.750** |
| `weight.bodySm` | 1.500 | 1.875 | 2.000 | **2.375** |
| `weight.body` | 3.000 | 3.750 | 3.500 | **4.250** |
| `weight.heavy` | 4.000 | 5.000 | 4.500 | **5.500** |

`weight.body` under both is **4.25**, not 4.375. Every column is strictly increasing top to bottom,
which is the property the order was chosen to preserve. All ten values are exact in binary
(1.25 = 5/4), so tests may use `==` rather than a tolerance.

**Derived, stage 4 — computed from the resolved value and never modified again:**

| Derived | Rule | Example at S ≥ 48, Bold Text on |
|---|---|---|
| halo (bloom pass B) | `resolved × 3` | 3.75 × 3 = 11.25 |
| light-theme keyline | `resolved + 1.0` | 3.75 + 1.0 = 4.75 |

**Substitutions terminate resolution.** Where §13.11 states an explicit High Contrast weight, take
it verbatim and stop: `c.ramp.cancelHatchWeight` is 1.0 → **2.0** under High Contrast, not 2.5. The
`+0.5` offset applies to L1 `weight.*`; a component weight that already has a stated High Contrast
value has been resolved by that statement.

---

## 3. Space and length

4 pt base, nine steps, §13.3 verbatim. Named for their point value: the scale is a **grid**, not a
semantic ramp, and `space.cozy` would assign meaning the GDD never assigned. Semantic spacing is
L2 — `c.settingsRow.labelInset = Space.s16`.

| Token | pt | | Token | pt |
|---|---|---|---|---|
| `space.s4` … `space.s64` | 4 · 8 · 12 · 16 · 20 · 24 · 32 · 44 · 64 | | `space.marginOuter` | 16 |
| `space.columnContent` | 343 | | `space.targetMin` | 44 |
| `space.ruleInset` | 16 | | `space.boundaryAbove` / `space.boundaryBelow` | 24 / 16 |

`columnContent` 343 is canon's Dial arithmetic on the 375 pt reference device:
`45 + 4 × 70 + 3 × 6 = 343`, with §13.3's 1 pt rounding absorbed by the header.

**Nothing here is scaled by Dynamic Type.** Text grows, containers reflow, and
`minimumScaleFactor` is 1.0 everywhere (§13.4). Only *art* scales, by `env.artScale`, applied at
the drawing site to a length — never to a weight, and never past 1.35.

A **rule** is `weight.hairline` in `stroke.hairline`, inset `space.ruleInset` on both sides. A
**section boundary** is that same rule with `space.boundaryAbove` of air above and
`space.boundaryBelow` below. There is no third rule weight in chrome: a heavier line always means
state.

---

## 4. Radius

| Token | pt | Note |
|---|---|---|
| `radius.glyph` | **0** | always. Corner count is the `shape` channel; rounding erodes it, and §13.1 makes it a PR-rejection offence |
| `radius.chrome` | 2 | continuous corner curve; nothing else in chrome exceeds it |
| `radius.sheet` | 12 | the Bench sheet's **top** corners only |

Caps and joins are geometry, not tokens, but they travel with radius and are absolute: glyph
geometry uses **miter joins and butt caps** so a 45° index stroke has an honest length; chrome uses
round caps.

---

## 5. Opacity

Opacity has **no multiplicative axis**. High Contrast *substitutes* an opacity; it never scales one.

| L1 token | Value | Use |
|---|---|---|
| `opacity.halo` | 0.12 | bloom pass B, the widened stroke |
| `opacity.bloomBed` | 0.35 | bloom pass A, the blurred region clone — dark theme only |
| `opacity.disabled` | 0.35 | any disabled control |
| `opacity.pressed` | 0.70 | any control while the finger is down, where a ground step is not available |
| `opacity.scrimFlat` / `opacity.scrimBlurred` | 0.85 / 0.60 | read through `Opacity.scrim(in:)`, which picks by Reduce Transparency |
| `opacity.impressionOuter` … `impressionFaint` | 1.00 · 0.55 · 0.30 · 0.14 | the light theme's impression ladder — see `light-theme.md` §3 |

**Seven of PHOSPHOR §1.4's opacities are component-scoped and move to L2.** They were L1-shaped in
the direction document because it had no L2. Nothing is lost; the mapping is authoritative:

| PHOSPHOR name | Owned name | Owning skill |
|---|---|---|
| `opacity.assayLit` 0.92 | `c.assay.litInk` | `hunch-bench-instruments` |
| `opacity.cellUnlit` 0.25 / HC 0.40 | `C.Ramp.cellUnlitInk(in:)` | `hunch-bench-instruments` |
| `opacity.cellInert` 0.30 | `C.Ramp.inertInk` | `hunch-bench-instruments` |
| `opacity.ribbonDim` 0.20 | `c.ribbon.revealBeat1Ink` | `hunch-motion-and-feedback` |
| `opacity.lawGhost` 0.40 | `c.reveal.lawGhostInk` | `hunch-motion-and-feedback` |
| `opacity.railPulse` 0.50 → 1.00 | `c.seal.railPulse` | `hunch-bench-instruments` |
| `opacity.hairlinePulse` 0.60 → 1.00 | `c.ruleTile.emptyRailPulse` | `hunch-bench-instruments` |

The two `Ramp` members ship in `C.swift` today as worked examples of the substitution rule; the rest
are created by their owning skill and must reference L1, never `Prim`.

---

## 6. What is not here

**Named component dimensions are L2 and belong to the component skills.** This skill owns the layer,
the naming rule and the resolution order — not the members. Do not add any of these here:

| Member | Owner |
|---|---|
| `C.Glyph.radius(side:)` · `C.Glyph.bleed(side:in:)` · `C.Glyph.pitch(side:)` · `C.Glyph.pipRadius(side:)` — the whole derivation, and the shipped-site inventory that lists which `S` each host passes | `hunch-glyph-renderer` |
| `C.Throat.glyphSide` / `glyphSideLarge` · `C.Assay.cellSide(_:)` · `C.Ramp.*` cell rects · `C.Bench.handle` · palette-stamp rects | `hunch-bench-instruments` |
| `C.Key.rect(_:in:)` · shelf plate · instrument bar band | `hunch-chrome-and-meta` |

**Deliberately no numbers in that table.** Its job is to say *who owns them*, not what they are —
a value written twice is a value that will be edited once. Two of the numbers that used to sit here
were already stale: `bleed.glyph = 0.08·S` is **rejected** by `hunch-glyph-renderer` (it under-covers
for `32 ≤ S < 59.5` with bloom on and at every size under High Contrast; there is a shipped
regression test that fails if anyone reintroduces it), and a flat `glyph.throat` 96 omits the Pro Max
128. Read the owning member; never quote a site size from here.

Also absent, permanently: elevation, shadow and material scales (§13.1 — luminance in dark,
impression in light, and nothing else); hover, pointer and keyboard-focus state layers (touch only);
and semantic status colours (`accent.*` are **verdicts**, not success/warning/error).

---

## 7. Adding one

1. Is it meaningful to more than one component? If not, it is L2 and belongs to that component's
   skill, not here.
2. Weight: add to `StrokeWeight`'s statics, decide `respondsToBoldText`, and extend §2's matrix with
   all four columns computed — not estimated.
3. Length or radius: add to `Space` or `Radius`, and say in one clause what it is applied to.
4. Opacity: state whether High Contrast substitutes a different value. If it does, the token is a
   function of `RenderEnv`, not a constant.
5. `swift ../scripts/check-tokens.swift` must exit 0, and the arithmetic test suite in
   `tokens-swift-layout.md` §6 must still pass.
