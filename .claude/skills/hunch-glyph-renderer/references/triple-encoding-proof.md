# triple-encoding-proof.md — T, and what it is a proof of

Contents: [1 The claim](#1-the-claim) · [2 The method](#2-the-method-and-why-single-ink-is-the-adversarial-case) ·
[3 The channel ranking](#3-the-channel-ranking-measured) · [4 T](#4-t) ·
[5 The two shipped tests](#5-the-two-shipped-tests) · [6 What would invalidate it](#6-what-would-invalidate-it)

---

## 1. The claim

§13.5.1: 256 = `fill`(4) × `shape`(4) × `pips`(4) × `hue`(4), and **all four channels are
fully determined by geometry alone**.

| Channel | Achromatic discriminator | Values |
|---|---|---|
| `fill` | ink coverage {0, 22.7, 38.6, 100} % **and** texture kind {none, discrete, linear, area} | 4 |
| `shape` | silhouette corner count {0, 3, 4, 6} | 4 |
| `pips` | count of contour discs {1, 2, 3, 4} at fixed compass rays | 4 |
| `hue` | index-stroke rotation {0°, 45°, 90°, 135°} | 4 |

Therefore a greyscale screenshot preserves all 256 as distinct rasters, a monochromat
reads all 256, and every dichromacy type is unaffected because **no decision in the game
depends on chromatic discrimination**. Canon's worst hue pair is `teal` against `rose`,
and it is resolved entirely by 45° against 135°, a 90° angular separation, the maximum
available.

**Canon's luminances for that pair are wrong, and the correction is stated here rather than
inherited.** §13.5 quotes `teal` at relative luminance 0.291; computed from `Prim.okabeItoTeal`
it is **0.2569**. `Prim.okabeItoRose` is **0.2930**. They differ by 0.036, which is 139
against 147 in 8-bit sRGB — about eight levels apart, not the same pixel value. This is the
same arithmetic slip as §13.2's `hue.teal` dark ratio, which
`hunch-design-tokens/references/palette.md` §2 already records as over-stated: that file's
*measured* ratio against the dark ground implies L = 0.2569 exactly, so canon's ratio column
and canon's luminance column cannot both be true. Every hex stays in `Prim`; recompute
either number with `swift hunch-design-tokens/scripts/check-tokens.swift`, which reads the
hexes from there.

**The correction does not weaken §2's argument; it moves its footing.** Single-ink is the
right model because it is the *adversarial* case, not because the two hues happen to
coincide.

§13.5.1 then makes the claim falsifiable with two tests, the second of which asserts
`pairwise L1 distance ≥ T`, with **`T` never stated anywhere in the GDD**. This file
states it, and states it as a measurement rather than an assertion.

---

## 2. The method, and why single-ink is the adversarial case

`scripts/check-coverage-separation.js` renders all 256 to a **coverage mask** — one ink
level for every register, ground = 0 — and takes the pairwise L1 distance over the raster.

**A single ink level is deliberately the hardest case.** Modelling per-hue luminance would
mean amber (0.4162), frost (0.4050), rose (0.2930) and teal (0.2569) render at four
different grey values, and every pair that differs in `hue` would gain distance for free.
That would be the *observed* model, and it is the wrong one to gate on: the deck must
separate in the case where the hue channel contributes **no** luminance difference at all,
which is exactly what High Contrast does when it collapses all four to `stroke.primary` by
design, and what a monochrome print, a greyscale screenshot and a heavily-compressed
capture approximate. So the honest model is the adversarial one — all four hues at a single
ink level, which is what the coverage mask is. If the deck separates here it separates in
every theme, in every dichromacy, and for a monochromat, with the per-hue luminance
difference left over as unclaimed margin.

Three further choices, each of which makes the measurement harder rather than easier:

- **The raster includes the bleed** (`S · (0.5 + 0.16)` half-box). Clipping to the S-box
  would cut the index-stroke tips, which are precisely the discriminating pixels for the
  `hue` channel — the measurement would then flatter the deck.
- **The environment matrix is measured, not just the dark default.** Six configurations at
  S = 44: dark, dark + Bold Text, dark with bloom off, light, High Contrast, High Contrast
  + Bold Text. The floor is in the last one, and it is 44 % below the dark default.
- **The gate is the minimum over 32,640 pairs, not a percentile.** A deck where one pair
  is indistinguishable is a deck with 255 glyphs.

Units: **pt² of ink difference**, not raw 8-bit L1. §13.5.1 words the test in 8-bit L1 at
44 pt @2×, but that number moves the moment anyone changes the raster or the scale, and
then the constant is silently about a different thing. The two are one multiplication
apart and the script prints both:

```
L1_8bit  =  T_pt²  ×  255  ×  scale²          (8,160 for T = 8.0 pt² at @2×)
```

---

## 3. The channel ranking, measured

Cheapest single-channel change, S = 44 @2×, dark, pt² of ink difference. This is the
answer to "which channel is carrying the least weight", and it is not the one the design
worries about.

| pt² | change | |
|---|---|---|
| **15.95** | `pips` two ↔ three | ← the floor for the whole deck |
| 19.92 | `pips` one ↔ two, three ↔ four | |
| 36.66 | `pips` one ↔ three, two ↔ four | |
| 40.73 | `hue` teal ↔ frost, frost ↔ rose | the cheapest 45° rotation |
| 43.02 | `fill` hollow ↔ dotted | |
| 44.90 | `hue` amber ↔ teal, amber ↔ rose | |
| 48.22 | `hue` amber ↔ frost | |
| 53.46 | `hue` **teal ↔ rose** | canon's feared pair (§1) — measured, the *third* most separated hue pair |
| 57.36 | `pips` one ↔ four | |
| 61.14–156.28 | `fill`, the other five pairs | |
| 215.67–322.80 | `shape`, all six pairs | 14× the floor |

**Three readings.**

1. **`pips` is the weakest channel at 44 pt and above, not `hue`.** The design's stated
   anxiety is teal-versus-rose; the measurement puts that pair at 53.46 pt², three and a
   half times the actual floor. The index stroke is over-engineered for its job, which is
   correct — it is the channel that carries a *total order* and it should be unambiguous —
   but it means any future economy must not come out of `pips`.
2. **The floor is `two ↔ three`, i.e. adding the S node — and the reason is geometric, not
   statistical.** Every limiting pair measured is `hollow / {circle, hexagon} / two↔three /
   frost`, and that is exactly the configuration in which the index stroke already inks the
   place the S node goes: `frost` runs vertically, and its **upper tip** — smaller `y` in the
   screen frame — sits `0.0235·S` below the S node on `circle` and `hexagon` (which alone put
   their S node at full `R`; `geometry.md` §1 fixes the sign convention), and at
   S = 44 that is 1.82 pt against a `pipRadius` of 3.0 — the tip is **inside the disc**.
   Adding the S node there adds the least new ink available anywhere in the deck.
   `geometry.md` §5.1 has the distance table. The first thing to re-measure if
   `pipRadius`, the index length or the `0.43·S` register offset ever move.
3. **`shape` is 14× the floor and could give a great deal away.** It is the channel to
   spend from if a variant ever needs one — never `pips`.

Across sizes, dark theme (`--sweep`):

| S | min pt² | limiting channel | inset ladder | interior ladder |
|---|---|---|---|---|
| 24 | **1.82** | `fill` dotted ↔ striped | ok | INVERTED |
| 36 | 14.69 | `fill` hollow ↔ dotted | ok | ok |
| 44 | 15.95 | `pips` two ↔ three | ok | ok |
| 48 | 12.82 | `pips` two ↔ three | ok | INVERTED |
| 52 | 12.60 | `pips` two ↔ three | ok | INVERTED |
| 72 | 13.85 | `pips` two ↔ three | ok | ok |
| 96 | 24.87 | `pips` two ↔ three | ok | ok |

**The deck is not provably separable at 24 pt.** The `fill` channel collapses there — the
triangle's inset interior has an apothem of 2.19 pt, which holds neither dots nor stripes —
and the interior ink ladder inverts. §13.5's *"identically at every size from 24 pt to
220 pt"* is true of the arithmetic and false of the raster. This is survivable only because
**no shipped site draws a glyph below 36 pt**: the smallest are the SIEVE tail and the ECHO
seed glyph. 24 pt appears in §11.2 as a *rule-tile skeleton* silhouette, which is not a
glyph. Treat 36 pt as the floor of the vocabulary, and if a new site ever wants a glyph
smaller than that, the answer is a different mark, not a shrunken one.

---

## 4. T

**`C.Glyph.minimumPairwiseInkDifference = 8.0` — pt² of ink difference, at S = 44.**
Equivalently 8,160 in §13.5.1's 8-bit L1 units at @2×.

Measured floor per environment, S = 44 @2×:

| Environment | min pt² | margin over T | limiting pair |
|---|---|---|---|
| dark, bloom off | 16.52 | 106 % | `hollow/hexagon/two/frost` vs `…/three/frost` |
| dark | 15.95 | 99 % | `hollow/circle/two/frost` vs `…/three/frost` |
| dark + Bold Text | 13.82 | 73 % | `hollow/circle/two/frost` vs `…/three/frost` |
| light | 13.05 | 63 % | `hollow/hexagon/two/frost` vs `…/three/frost` |
| High Contrast | 10.36 | 29 % | `hollow/circle/two/frost` vs `…/three/frost` |
| **High Contrast + Bold Text** | **8.94** | **12 %** | `hollow/circle/two/frost` vs `…/three/frost` |

High Contrast is the worst case and the reason is worth stating, because it is
counter-intuitive: HC adds `Prim.highContrastStrokeOffset` to every stroke, so the
silhouette under a pip node is already inked and the node's *marginal* contribution falls.
Bold Text multiplies on top of that (`hunch-design-tokens/references/render-env.md` §2 has
the order and both constants). The setting that exists to make marks more legible makes the `pips`
channel measurably less separable — and it is still 12 % clear of T, which is the answer,
but it is the number to watch if either modifier ever grows.

**On the 12 % margin.** T was derived from `reference-renderer.js`, which is an analytic
model of the draw list, not SwiftUI's rasteriser: antialiasing, subpixel coverage rules and
miter handling all differ slightly. So the procedure is:

1. Adopt the Swift test in §5 and run it once. Record the shipped renderer's floor.
2. If it agrees with 8.94 pt² to within a few percent, keep `T = 8.0` and it is ratified.
3. If it does not, **the disagreement between the two rasterisers is the finding** — chase
   it before touching T.
4. Afterwards, never lower T. A failure means the geometry changed.

**`hunch-sigil-drawing` reuses this constant**, because a new sigil that is closer to an
existing mark than two glyphs are to each other is a mark the player cannot learn. The
sigils are drawn at different sizes, so they reuse T as a *ratio of the box*:
`8.0 / 44² = 0.00413 · S²`. That ratio is verified only at S = 44 here; a sigil set at
another size must re-derive its own floor with the same script rather than assume it.

---

## 5. The two shipped tests

§13.5.1 names two, §13.12 gates them as acceptance items 1 and 2. Neither belongs in
`HunchCore`'s 10-second suite — both need a rasteriser — so they live in
`Modules/Tests/HunchUITests/`, and `HunchCore` unit-tests only the arithmetic behind them.

**Test 1 — colour is a pure output substitution.** §13.5.1 words it as
`render(g, monochrome: true)` and `render(g)` producing bit-identical coverage masks. There
is no `monochrome:` parameter in this architecture, and there should not be: monochrome is
a *palette* fact, and a renderer that took a flag would have two code paths to keep in
agreement. The equivalent, stronger claim is that swapping the palette changes no alpha:

```swift
@MainActor @Test(arguments: Deck.all)
func colourNeverMovesGeometry(glyph: Glyph) throws {
    let alphaDark = try alphaMask(glyph, side: 44, env: RenderEnv(theme: .dark))
    let alphaHC = try alphaMask(glyph, side: 44, env: RenderEnv(theme: .highContrast))
    // High Contrast substitutes hue → stroke.primary AND lengthens the index stroke,
    // so the masks differ by exactly that: mask the index register out and compare.
    #expect(alphaDark.excludingIndexRegister == alphaHC.excludingIndexRegister)
}
```

The structural half is cheaper and catches the same class of bug at compile time: the draw
list must read `env.palette` **only** to build a `Shading`. If a `Path` is ever computed
from a colour, that is the defect this test exists to find.

**Test 2 — pairwise separation.**

```swift
@MainActor @Test func deckSeparatesByGeometryAlone() throws {
    for env in RenderEnv.snapshotMatrix {           // the six rows of §4
        let masks = try Deck.all.map { try coverageMask($0, side: 44, scale: 2, env: env) }
        var floor = Double.infinity
        for i in masks.indices {
            for j in masks.index(after: i)..<masks.endIndex {
                floor = min(floor, masks[i].inkDifference(from: masks[j]))   // pt²
            }
        }
        #expect(floor >= C.Glyph.minimumPairwiseInkDifference, "\(env.theme) floor \(floor)")
    }
}
```

`inkDifference(from:)` is `sum |Δalpha| / scale²`, in pt². 32,640 pairs × 13,456 px is
~440 M byte operations per environment — under a second in Swift, and it is a snapshot-tier
test, not a per-commit one.

**Where each thing runs.**

| Assertion | Where | Why there |
|---|---|---|
| `C.Glyph` arithmetic, the resolution order, the bleed formula | `HunchCore` `swift test` | pure `Double`, no simulator, inside the 10 s budget |
| T's value, the channel ranking, the ink ladder | `scripts/check-coverage-separation.js` | design-time; ~85 s for the six-environment gate |
| Tests 1 and 2 against the shipped renderer | `Modules/Tests/HunchUITests` | needs `ImageRenderer`; ratifies the JS number |
| The visual corpus | the DEBUG snapshot gallery | `hunch-swift-testing` owns it |

---

## 6. What would invalidate it

Each of these breaks the proof rather than degrading it, which is why they are `Never`
items in `SKILL.md` rather than tradeoffs:

- **Rounding a glyph corner.** `shape`'s discriminator is corner count. A 2 pt radius on a
  triangle is not a softer triangle, it is a shape with an ambiguous corner count.
- **Thinning the index stroke at small `S`.** The `hue` channel's separation is the swept
  area of a rotating rectangle; halving the width halves it.
- **Shortening the index stroke**, or letting High Contrast's `0.409·S` substitution get
  scaled instead of substituted.
- **Widening the halo past ×3 without moving the fill inset.** `fill-textures.md` §3.
- **Widening the texture or the pips in the halo pass.**
- **Adding a fifth channel to the glyph.** 256 is the deck and it never grows (§2). A fifth
  register would have to come out of the four existing ones' space.
- **Drawing a glyph below 36 pt.** §3 above.
- **Assuming colour carries anything.** Every one of these numbers was measured with the
  four hues as a single ink. If a decision anywhere in the app starts depending on which
  hue is showing *as a colour*, the proof stops being about the shipped game.
