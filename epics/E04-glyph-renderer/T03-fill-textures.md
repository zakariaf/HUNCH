# T03 — Fill textures

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 ART / MOTION → **Glyph geometry** (the `fill` register) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The fill inset is derived from the **already-resolved** body weight (`1.5 × env.weight(...)`), which is stage 4 of the resolution order — derive-from-resolved, never scale a scaled value. The skill owns that order and the rule that `pitch`, `dotRadius` and `stripeWeight` are ratios and therefore L2, not L1. |
| `hunch-glyph-renderer` | Owns the `fill` register. `references/fill-textures.md` is the whole task: the three patterns, why coverage is pitch-invariant as a ratio and not as a raster, the clip, the measured table at every size, and the anchor rule. `references/bloom-and-squash.md` §3 owns the 1.5 × coupling between the inset and the halo. |

## Objective

The three drawn textures — `dotted`, `striped`, `solid` — render clipped to the silhouette inset `1.5 × bodyWeight`, with every dimension pinned to one pitch so the ink ladder 0 → 22.7 → 38.6 → 100 % is a property of the pattern and not of the size, and both lattices anchored at `bodyCentre` so a resized glyph is the same glyph. Before this task the `fill` channel does not exist; after it, the channel is drawn **and measured by rasterisation** at 24, 44, 96 and 220 pt, which is the only honest way to check a value that is a statistic of a drawing rather than a countable feature.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | `fill` rank 1–4 as monotone ink density; the fill register is the interior of the body |
| `GAME_DESIGN.md` | §13.5 | `pitch = max(5 pt, 0.22·R)`, `dotRadius = 0.25·pitch`, `stripeWeight = 0.386·pitch`, the clip inset `1.5 × bodyWeight`, the coverage table, stripes at +45° |
| `GAME_DESIGN.md` | §13.5.1 | the `fill` discriminator is coverage **and** texture kind {none, discrete, linear, area} — two channels, not one |
| `GAME_DESIGN.md` | §13.1 | no gradient and no bitmap inside a glyph body: the fill register is game state and must be a flat pattern |
| `hunch-glyph-renderer` | `references/fill-textures.md` §§1–6 | the arithmetic, the clip, the measured envelope per size, the anchor rule, and the six ways to break it |
| `hunch-glyph-renderer` | `references/bloom-and-squash.md` §3 | why `fillInset` and the ×3 halo are locked to each other |
| `hunch-glyph-renderer` | `references/triple-encoding-proof.md` §3 | why the *mean* is the wrong statistic and the pairwise raster distance is the right one |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Append to `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift`:

```swift
    /// The three pattern dimensions are fixed ratios of one pitch, which is what makes
    /// the coverage ratio cancel: `dotted = π·0.0625/0.866` and `striped = w/pitch`, both
    /// independent of pitch. Asserted as ratios so the identity survives a pitch change.
    @Test("Every pattern dimension is a fixed ratio of the pitch",
          arguments: [24.0, 44, 96, 220])
    func everyPatternDimensionIsAFixedRatioOfThePitch(side: Double) {
        let pitch = C.Glyph.pitch(side: side)
        let unitDot = C.Glyph.dotRadius(side: 24) / C.Glyph.pitch(side: 24)
        let unitStripe = C.Glyph.stripeWeight(side: 24) / C.Glyph.pitch(side: 24)
        #expect(isApproximatelyEqual(C.Glyph.dotRadius(side: side) / pitch,
                                     unitDot, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(C.Glyph.stripeWeight(side: side) / pitch,
                                     unitStripe, absoluteTolerance: 1e-12))
    }

    /// The 5 pt floor binds below S ≈ 61.4 — every shipped site except the throat and the
    /// Codex hero — and above it the pitch is proportional to R.
    @Test("Pitch is floored at the small end and proportional above it")
    func pitchIsFlooredAtTheSmallEndAndProportionalAboveIt() {
        #expect(isApproximatelyEqual(C.Glyph.pitch(side: 24), C.Glyph.pitch(side: 44),
                                     absoluteTolerance: 1e-12))          // both floored
        #expect(C.Glyph.pitch(side: 220) > C.Glyph.pitch(side: 96))      // both proportional
    }

    /// The nominal ladder is what the ratios buy, and it is the one place the two numbers
    /// §13.5 states are recomputed rather than restated.
    @Test("The nominal coverage ladder is monotone and pitch-free")
    func theNominalCoverageLadderIsMonotoneAndPitchFree() {
        let pitch = C.Glyph.pitch(side: 96)
        let dotted = .pi * pow(C.Glyph.dotRadius(side: 96), 2)
            / (pitch * pitch * (3.0 as Double).squareRoot() / 2)
        let striped = C.Glyph.stripeWeight(side: 96) / pitch
        #expect(0 < dotted && dotted < striped && striped < 1)
    }

    /// The inset is derived from the RESOLVED weight, so it steps with the regime — and
    /// the interior therefore SHRINKS as the glyph crosses 48 pt. Counter-intuitive,
    /// correct, and the reason the ink ladder is measured per size rather than once.
    @Test("The fill inset is 1.5 × the resolved body weight, and the interior shrinks at 48")
    func theFillInsetTracksTheResolvedBodyWeight() {
        let env = RenderEnv()
        for side in [36.0, 44, 48, 96] {
            #expect(isApproximatelyEqual(
                C.Glyph.fillInset(side: side, in: env),
                1.5 * C.Glyph.bodyStroke(side: side, in: env),
                absoluteTolerance: 1e-12))
        }
        func insetRadius(_ side: Double) -> Double {
            C.Glyph.radius(side: side) * C.Glyph.fillClipScale(cornerCount: 0, side: side, in: env)
        }
        #expect(insetRadius(44) > insetRadius(48))
    }

    /// Offsetting a regular polygon is a change of apothem, so the clip is the same
    /// polygon at another scale — exact, not an approximation of a path inset.
    @Test("The fill clip scale is an exact apothem offset",
          arguments: [0, 3, 4, 6])
    func theFillClipScaleIsAnExactApothemOffset(corners: Int) {
        let env = RenderEnv()
        let side = 96.0
        let radius = C.Glyph.radius(side: side)
        let apothem = radius * (corners == 0 ? 1 : cos(.pi / Double(corners)))
        let scale = C.Glyph.fillClipScale(cornerCount: corners, side: side, in: env)
        #expect(isApproximatelyEqual(
            apothem * scale, apothem - C.Glyph.fillInset(side: side, in: env),
            absoluteTolerance: 1e-9))
        #expect(scale > 0 && scale < 1)
    }
```

Create `Modules/Tests/HunchUITests/GlyphFillTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Fill textures", .tags(.snapshot, .presubmission))
@MainActor
struct GlyphFillTests {

    /// §13.5 claims the ladder holds "identically at every size from 24 pt to 220 pt".
    /// That is true of the arithmetic and only approximately true of the raster, so the
    /// shipped assertion is **strict monotonicity of measured ink over the fill clip** at
    /// the four sizes §14.1 names — not equality with 22.7 and 38.6.
    @Test("The inset ink ladder is strictly monotone at every size",
          arguments: [24.0, 44, 96, 220], Glyph.Shape.allCases)
    func theInsetInkLadderIsStrictlyMonotone(side: Double, shape: Glyph.Shape) throws {
        let env = RenderEnv()
        let coverages = try Glyph.Fill.allCases.map { fill in
            try coverageMask(Glyph(fill: fill, shape: shape, pips: .one, hue: .amber),
                             side: side, env: env)
                .meanCoverage(overFillClipOf: shape, side: side, env: env)
        }
        #expect(coverages == coverages.sorted())
        #expect(zip(coverages, coverages.dropFirst()).allSatisfy { $1 - $0 > 0.02 })
        #expect(coverages[0] < 0.005)                                  // hollow is empty
        #expect(coverages[3] > 0.95)                                   // solid is full
    }

    /// The halo's half-width is `1.5 × bodyWeight` and the fill inset is the same number,
    /// so the halo's inner edge lands exactly on the clip boundary and deposits nothing
    /// inside it. This is the constraint that keeps the 0 → 22.7 % rung alive under bloom
    /// (bloom-and-squash.md §3), and it is a coincidence you must not break.
    @Test("Bloom deposits no ink inside a hollow glyph's fill clip",
          arguments: [36.0, 44, 96, 220])
    func bloomDepositsNoInkInsideAHollowFillClip(side: Double) throws {
        let glyph = Glyph(fill: .hollow, shape: .hexagon, pips: .one, hue: .frost)
        for env in [RenderEnv(), RenderEnv(theme: .dark, isReduceTransparencyEnabled: true)] {
            let coverage = try coverageMask(glyph, side: side, env: env)
                .meanCoverage(overFillClipOf: .hexagon, side: side, env: env)
            #expect(coverage < 0.005)
        }
    }

    /// Both lattices are anchored at `bodyCentre`: row 0 and stripe 0 pass through it.
    /// A lattice phased off a loop start moves with R, so the same `fill` would render
    /// differently at two sizes and stop being a value (fill-textures.md §5).
    @Test("Both lattices are anchored at the body centre", arguments: [44.0, 96, 220])
    func bothLatticesAreAnchoredAtTheBodyCentre(side: Double) throws {
        let env = RenderEnv()
        for fill in [Glyph.Fill.dotted, .striped] {
            let mask = try coverageMask(
                Glyph(fill: fill, shape: .circle, pips: .one, hue: .amber),
                side: side, env: env)
            #expect(mask.coverage(atBodyOffset: .zero, side: side, env: env) > 0.9)
        }
    }

    /// Texture KIND is a second discriminator and it is not redundant (§13.5.1): a viewer
    /// who cannot tell 22.7 % from 38.6 % can still tell dots from lines. Read off the
    /// raster as connected ink runs along two scans through `bodyCentre` — `striped` is
    /// one unbroken run along its own +45° axis and many across it, `dotted` is many on
    /// every axis, `solid` is one on every axis. This also re-proves the anchor: the
    /// +45° scan is unbroken only because stripe 0 passes through `bodyCentre`.
    @Test("Texture kind is readable from the raster", arguments: [44.0, 96, 220])
    func textureKindIsReadableFromTheRaster(side: Double) throws {
        let env = RenderEnv()
        func runs(_ fill: Glyph.Fill, at degrees: Double) throws -> Int {
            try coverageMask(Glyph(fill: fill, shape: .square, pips: .one, hue: .amber),
                             side: side, env: env)
                .inkRunCount(alongScanThroughBodyCentreAt: degrees, side: side, env: env)
        }
        let stripedAlong = try runs(.striped, at: 45)
        let stripedAcross = try runs(.striped, at: -45)
        let dottedAlong = try runs(.dotted, at: 45)
        let dottedAcross = try runs(.dotted, at: 0)
        #expect(stripedAlong == 1)
        #expect(stripedAcross > 3)
        #expect(dottedAlong > 3)
        #expect(dottedAcross > 3)
        #expect(try runs(.solid, at: 45) == 1)
        #expect(try runs(.solid, at: -45) == 1)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter GlyphGeometryTests
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GlyphFillTests
```

The arithmetic suite must fail on missing `C.Glyph.pitch` / `dotRadius` / `stripeWeight` / `fillInset` / `fillClipScale`; the raster suite on a missing texture pass and the two new `CoverageMask` helpers.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then run the design-time cross-check and reconcile:

```bash
node .claude/skills/hunch-glyph-renderer/scripts/render-all-256.js --size 44
node .claude/skills/hunch-glyph-renderer/scripts/render-all-256.js --size 220
```

and compare the printed ink ladder against `fill-textures.md` §4's table. A disagreement between the analytic model and the shipped rasteriser is a **finding to chase**, not a number to adjust.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift` — `drawTexture(into:box:bodyCentre:ink:)` |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `pitch`, `dotRadius`, `stripeWeight`, `fillInset`, `fillClipScale` |
| modify | `Modules/Tests/HunchUITests/Support/CoverageMask.swift` — add `meanCoverage(overFillClipOf:side:env:)` and `inkRunCount(alongScanThroughBodyCentreAt:side:env:)` |
| create | `Modules/Tests/HunchUITests/GlyphFillTests.swift` |
| modify | `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` |
| modify | `DECISIONS.md` — record that coverage is asserted over the fill clip, never over the silhouette interior |

## Implementation notes

### The three patterns

| Value | Geometry | Nominal | Kind |
|---|---|---|---|
| `hollow` | nothing — return early | 0 % | none |
| `dotted` | hex-packed discs, radius `dotRadius`, spacing `pitch`, row height `pitch·√3/2` | 22.7 % | discrete |
| `striped` | parallel lines at **+45° in the screen frame**, width `stripeWeight`, spacing `pitch` | 38.6 % | continuous, linear |
| `solid` | fill the clip | 100 % | continuous, area |

The two nominal numbers are *derived*, not chosen — `π · 0.0625 / 0.866 = 0.2267` and `0.386 · pitch / pitch = 0.386` — and `pitch` cancels in both, which is why the coverage ratio is exactly size-invariant in the continuum. Paste `geometry.md` §4's `drawTexture` and read `fill-textures.md` §1–§2 for the derivation.

**Never "simplify" `dotted` into a lighter `striped`.** Coverage alone is a scalar and scalars get compressed; kind is categorical and survives any amount of compression. §13.5.1 lists both, and the test above asserts both.

### The clip

```swift
let scale = C.Glyph.fillClipScale(cornerCount: glyph.shape.cornerCount, side: side, in: env)
let clip = GlyphShape(shape: glyph.shape, radiusScale: scale).path(in: box)
```

Because offsetting a regular polygon is a change of apothem, the clip is T01's polygon at another radius scale — exact, and one `GlyphShape`, not a `Path` inset. `fillClipScale` is:

```swift
public static func fillClipScale(cornerCount n: Int, side S: Double, in env: RenderEnv) -> Double {
    let apothem = radius(side: S) * (n == 0 ? 1 : cos(.pi / Double(n)))
    return max(0, (apothem - fillInset(side: S, in: env)) / apothem)
}
```

`fillClipScale` takes `cornerCount: Int` and not a `Glyph.Shape` because `Tokens` is a leaf target with no dependencies; importing `Glyphs` to spell one parameter would invert the dependency arrow and cost `swift test` its host-testability.

**`1.5 × bodyWeight` is not a taste value.** It is exactly the halo's half-width, since pass B strokes at `3 × bodyWeight` with a round join. The halo's inner edge therefore lands precisely on the clip boundary and deposits nothing inside it — which is why `hollow` measures 0.0 % with bloom on at every size, in every theme. **If the halo ever widens past ×3, `fillInset` must widen with it in the same commit**, or `DIRECTION-A-PHOSPHOR.md` §6.4's failure ("bloom actively attacks the `fill` ladder") stops being hypothetical.

### The anchor rule

**Row `j = 0` passes through `bodyCentre`; stripe `m = 0` passes through `bodyCentre`.** Never the clip's bounding box, and never a loop start.

`DIRECTION-A-PHOSPHOR.md` §5's loop starts its rows at `C[1] − r` and steps by `dy`, so row parity and sub-pitch phase both depend on `r`, which depends on `R`, which depends on `S`. Two glyphs of the same `fill` at two sizes would then carry differently-phased lattices — the pattern would move when the mark is resized, and `fill` would stop being a value and start being a value-plus-a-size. The test above pins it with one assertion: the pixel at `bodyCentre` is ink for `dotted` and for `striped`, at every size.

For stripes the same rule reads `t = (p − bodyCentre) · n`, then `|t − round(t/pitch)·pitch| ≤ stripeWeight/2`.

**`striped` runs at +45°, the same angle as `teal`'s index stroke.** That is not a collision — the registers are spatially disjoint, the index register is below the body and the texture is inside it, and no ray of the drawing contains both. It *is* the reason the cancel hatch (T08) must run at −45°: perpendicular, or it vanishes into a striped mark.

### Measured, and which region is quoted

`fill-textures.md` §4 measures two regions and only one of them supports the claim:

- **inset** — the fill clip itself. This is the region the `fill` register paints and it is what "22.7 %" is a claim about. **The inset ladder never inverts, at any size, with bloom on or off.** Worst rung is `dotted → striped` at S = 52: 30.6 % against 37.5 %.
- **interior** — everything inside the silhouette centre-line, so the body stroke's inner half is counted. **This ladder inverts at S = 24, 48 and 52**, where the stroke is heaviest relative to `R`: at S = 48 `hollow`'s interior reads 36.4 % — all of it rim — against `dotted`'s 32.0 %.

Which means **the mean is the wrong statistic**, and §13.5.1 already knew that: the shipped separation test is a pairwise L1 over the raster (T06), and L1 is spatially sensitive — at S = 48 `hollow` and `dotted` differ by 23.41 pt² of ink even though their interior means differ by 4 pp, because `hollow`'s ink is all at the rim and `dotted`'s is spread.

**Record the ruling in `DECISIONS.md`:** *coverage is quoted and asserted over the fill clip; the silhouette interior is not the region the `fill` register paints, and its ladder inverts at three sizes.* Without the entry the next person to measure "the fill" measures the interior, finds an inversion, and files a bug against correct geometry.

The measured envelope you are checking against, dark theme, bloom on, min–max over the four shapes (`fill-textures.md` §4):

| S | `hollow` | `dotted` | `striped` | `solid` |
|---|---|---|---|---|
| 24 | 0.0 | 19.1–25.5 | 39.9–42.5 | 100.0 |
| 44 | 0.0 | 21.4–27.2 | 37.6–39.7 | 100.0 |
| 96 | 0.0 | 21.5–23.4 | 37.9–39.2 | 100.0 |
| 220 | 0.0 | 22.0–25.9 | 38.6–39.2 | 100.0 |

`dotted` runs 17–31 % against a nominal 22.7 because a lattice of 3–6 samples across the chord is coarse, not because the geometry drifts. That is why the shipped assertion is monotonicity with a margin, not equality with the nominal — and why the test asserts a ≥ 2 pp gap between adjacent rungs rather than a point value.

### The two `CoverageMask` helpers this task adds

```swift
/// Mean coverage over the fill clip — the region the `fill` register paints. NOT the
/// silhouette interior, whose ladder inverts at S = 24, 48 and 52 (DECISIONS.md).
func meanCoverage(overFillClipOf shape: Glyph.Shape, side: Double, env: RenderEnv) -> Double

/// Connected runs of ink along a scan at `degrees` through `bodyCentre`, clipped to the
/// fill clip — the achromatic reading of texture *kind* {discrete, linear, area} (§13.5.1).
func inkRunCount(
    alongScanThroughBodyCentreAt degrees: Double, side: Double, env: RenderEnv
) -> Int
```

Both build their region from `GlyphShape(shape:radiusScale:)` and `C.Glyph.fillClipScale` — the same symbols the renderer uses, so a change to the clip moves the measurement with it rather than silently invalidating it.

### What breaks it

Read `fill-textures.md` §6 in full before touching a number. The short list: widening the texture in the halo pass; a gradient or bitmap inside the body; insetting by a constant instead of `1.5 × bodyWeight`; filling the clip and then stroking the silhouette in `ground` to fake the gap (it reads identically in dark and wrongly on `ground.raised`, where the Codex page and the ECHO tray both sit); changing `dotRadius` or `stripeWeight` "to make it read better at one size"; and scaling the pattern by `env.artScale`, which double-scales it because `pitch` already derives from `S`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphGeometryTests` green, including all five new cases.
- [ ] `xcodebuild test … -only-testing:HunchUITests/GlyphFillTests` green: the inset ladder is strictly monotone with a ≥ 2 pp margin at 24, 44, 96 and 220 pt on all four shapes.
- [ ] `hollow` measures < 0.5 % inside the fill clip **with bloom on** at every tested size — the 1.5 × coupling holds.
- [ ] The pixel at `bodyCentre` is ink for `dotted` and `striped` at 44, 96 and 220 pt — the lattices are anchored.
- [ ] `node .claude/skills/hunch-glyph-renderer/scripts/render-all-256.js --size 44` agrees with the shipped measurement to within the §4 envelope; any disagreement is written into the PR body with its explanation.
- [ ] `grep -rn 'Gradient\|Image(\|artScale' Modules/Sources/HunchUI/GlyphCanvas.swift` returns nothing.
- [ ] `DECISIONS.md` carries the inset-versus-interior ruling with the S = 48 worked example.
- [ ] `bash Scripts/check-source-hygiene.sh` passes.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T03: fill textures — pitch-pinned lattices anchored at bodyCentre, ladder measured by raster"`

## Out of scope

- **Pass B's halo** — T05. This task's inset is *coupled* to it and the coupling is asserted here; the halo itself is drawn there.
- **The index stroke** — T04, and it lives outside the clip entirely.
- **The pairwise L1 separation and `T`** — T06. This task asserts the ladder; T06 asserts the deck.
- **The cancel hatch's −45° and its coverage budget against `dotted`'s 22.7 %** — T08. The constraint originates here and is enforced there.
- **The Codex extension thumbnail's four ink densities** — E15·T03. It *reuses* the fill ladder to project a contextual law and is not a glyph.
- **`env.artScale`** — the host multiplies `S`; the renderer re-derives. Nothing in this file reads it.
