# T05 — GlyphCanvas, size regimes and bloom

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T02, T03, T04 |
| **Delivers** | §14.1 ART / MOTION → **Glyph geometry** (the assembled four-pass renderer) · §14.1 ART / MOTION → **Bloom** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `Opacity.halo` and `Opacity.bloomBed` are L1 and must not be retyped as numbers; `env.isBloomEnabled` and `env.isBloomBedEnabled` are **derived predicates** and a view that re-derives either from `theme` is the bug the predicate exists to stop. The skill also owns the size-regime rule: `S` selects the weight, and Dynamic Type reaches weight exactly once, through geometry. |
| `hunch-glyph-renderer` | `references/bloom-and-squash.md` is the whole task: the four passes and their fixed order, why pass A is per *region* and never per glyph, the 1.5 × coupling, the exclusion matrix, and `.scaleEffect` versus a new `S`. `references/geometry.md` §6 owns the bleed derivation and §4 owns the assembled `GlyphCanvas`. |

## Objective

`GlyphRenderer.draw(into:canvas:)` emits the four passes in the one order that is correct — halo, ink, pip knockout, index stroke — with the silhouette dropping to `bodySm` below 48 pt while the index stroke does not follow it, and `GlyphCanvas` wraps it in a frame that reserves the bleed the drawing actually needs. `BloomedRegion` ships beside it so a glyph-bearing region — the throat, the ribbon, the SIEVE tail — can add the blurred bed as **one** offscreen layer for all its glyphs, and the exclusion matrix (light theme, Reduce Transparency, High Contrast, Low Power, S < 32, the Assay always) is expressed in predicates rather than in scattered `if theme ==` branches.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.5 | the double stroke at `3 × weight` and 12 % opacity; the blur is `addFilter(.blur)` around a `drawLayer` and is applied **once per glyph-bearing region, never once per glyph**, at `radius: 0.062·S`; the Assay is excluded entirely; both off under Reduce Transparency and High Contrast |
| `GAME_DESIGN.md` | §13.3 | `bodySm` 1.5 pt below 48 pt, `body` 3.0 pt at or above it |
| `GAME_DESIGN.md` | §13.11 | Reduce Transparency kills bloom; Bold Text scales stroke weights ×1.25; High Contrast adds +0.5 pt |
| `GAME_DESIGN.md` | §13.1 | luminance is the only depth cue: no shadow, no elevation, no material |
| `hunch-glyph-renderer` | `references/bloom-and-squash.md` §§1–7 | the pass table, the per-region rule, the coupling, the matrix, the `BloomedRegion` Swift, squash vs a new `S` |
| `hunch-glyph-renderer` | `references/geometry.md` §6 | the four bleed terms and the two regimes where a flat `0.08·S` under-covers |
| `hunch-design-tokens` | `references/render-env.md` §3 | `isBloomEnabled`, `isBloomBedEnabled` and the rest of the predicate table |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Append to `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift`:

```swift
    /// The regime is a RULE, not a token: `S` selects the weight and it steps at 48.
    @Test("The body weight steps at 48 pt and the index stroke does not")
    func theBodyWeightStepsAt48() {
        let env = RenderEnv()
        #expect(C.Glyph.bodyStroke(side: 47.99, in: env) < C.Glyph.bodyStroke(side: 48, in: env))
        #expect(isApproximatelyEqual(C.Glyph.bodyStroke(side: 48, in: env),
                                     C.Glyph.indexStroke(in: env), absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(C.Glyph.bodyStroke(side: 220, in: env),
                                     C.Glyph.bodyStroke(side: 48, in: env),
                                     absoluteTolerance: 1e-9))
    }

    /// The halo is derived from the ALREADY-RESOLVED weight — stage 4 of the resolution
    /// order — so it is ×3 of whatever Bold Text and High Contrast produced, never a
    /// separately-resolved token.
    @Test("The halo is exactly three times the resolved stroke",
          arguments: [RenderEnv(), RenderEnv(isBoldTextEnabled: true),
                      RenderEnv(theme: .highContrast, isBoldTextEnabled: true)])
    func theHaloIsThreeTimesTheResolvedStroke(env: RenderEnv) {
        #expect(isApproximatelyEqual(C.Glyph.haloStroke(side: 96, in: env),
                                     3 * C.Glyph.bodyStroke(side: 96, in: env),
                                     absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(C.Glyph.haloIndexStroke(in: env),
                                     3 * C.Glyph.indexStroke(in: env),
                                     absoluteTolerance: 1e-9))
    }

    /// Two independent gates: the environment half is RenderEnv's, the `S >= 32` half is
    /// geometry and is ours. Below 32 a 3 × 1.5 pt halo is half the body radius and stops
    /// being a glow.
    @Test("Bloom is gated on the environment AND on the size")
    func bloomIsGatedOnTheEnvironmentAndOnTheSize() {
        #expect(C.Glyph.isBloomed(side: 44, in: RenderEnv()))
        #expect(!C.Glyph.isBloomed(side: 24, in: RenderEnv()))
        for env in [RenderEnv(theme: .highContrast),
                    RenderEnv(isReduceTransparencyEnabled: true),
                    RenderEnv(isLowPowerModeEnabled: true)] {
            #expect(!C.Glyph.isBloomed(side: 96, in: env))
        }
        // Reduce Motion is NOT a bloom setting. Conflating the two is the most common way
        // the play surface ends up wrong for the wrong player.
        #expect(C.Glyph.isBloomed(side: 96, in: RenderEnv(isReduceMotionEnabled: true)))
    }

    /// A flat 8 % bleed is not enough — it clips teal and rose for 32 <= S < 59.5 and
    /// clips frost under High Contrast at every size. Guards the regression, not the
    /// constant: reintroduce `0.08 · S` and this fails everywhere it should.
    @Test("A flat 8 % bleed is not enough", arguments: [36.0, 44, 52, 96, 220])
    func theFlatEightPercentBleedIsNotEnough(side: Double) {
        let hc = C.Glyph.bleed(side: side, in: RenderEnv(theme: .highContrast))
        #expect(hc.y > 0.08 * side)
        #expect(isApproximatelyEqual(hc.x, 0, absoluteTolerance: 1e-9))
        if (32.0..<59.5).contains(side) {
            #expect(C.Glyph.bleed(side: side, in: RenderEnv()).y > 0.08 * side)
        }
    }
```

Create `Modules/Tests/HunchUITests/GlyphCanvasTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("GlyphCanvas and bloom", .tags(.snapshot, .presubmission))
@MainActor
struct GlyphCanvasTests {

    /// THE draw-order test. `frost`'s upper tip lands inside the S pip disc on `circle`
    /// and `hexagon` at every shipped size (geometry.md §5.1). If the index stroke is
    /// drawn before pass D's knockout, a `ground` ring cuts a notch out of the hue channel
    /// on a quarter of the deck — and nothing errors.
    @Test("The pip knockout runs before the index stroke",
          arguments: [Glyph.Shape.circle, .hexagon], [44.0, 96.0])
    func thePipKnockoutRunsBeforeTheIndexStroke(shape: Glyph.Shape, side: Double) throws {
        let env = RenderEnv()
        let glyph = Glyph(fill: .hollow, shape: shape, pips: .three, hue: .frost)
        let mask = try coverageMask(glyph, side: side, env: env)
        // The tip sits 0.0235·S below the S node in the screen frame — inside the disc.
        let tip = CGPoint(x: 0, y: C.Glyph.radius(side: side) + 0.0235 * side)
        #expect(mask.coverage(atBodyOffset: tip, side: side, env: env) > 0.85)
    }

    /// The frame reserves what the drawing actually reaches, on both axes, in every
    /// environment. `.clipped()` anywhere between a host and the Canvas cuts the tip of
    /// the hue channel and nothing errors.
    @Test("No ink reaches the edge of the reserved frame",
          arguments: [RenderEnv(), RenderEnv(theme: .highContrast), RenderEnv(theme: .light)])
    func noInkReachesTheEdgeOfTheReservedFrame(env: RenderEnv) throws {
        for hue in Glyph.Hue.allCases {
            let mask = try coverageMask(Glyph(fill: .solid, shape: .triangle, pips: .four, hue: hue),
                                        side: 96, env: env)
            #expect(mask.maximumCoverageOnBorder() < 0.02)
        }
    }

    /// Pass B widens the body outline and the index stroke ONLY. Widening the texture or
    /// the pips would raise measured ink coverage and compress the rung the greyscale
    /// proof rests on.
    @Test("The halo widens the outline and the index stroke and nothing else")
    func theHaloWidensTheOutlineAndTheIndexStrokeOnly() throws {
        let bloomed = RenderEnv()
        let flat = RenderEnv(isReduceTransparencyEnabled: true)
        let glyph = Glyph(fill: .dotted, shape: .square, pips: .two, hue: .teal)
        let withBloom = try coverageMask(glyph, side: 96, env: bloomed)
            .meanCoverage(overFillClipOf: .square, side: 96, env: bloomed)
        let withoutBloom = try coverageMask(glyph, side: 96, env: flat)
            .meanCoverage(overFillClipOf: .square, side: 96, env: flat)
        #expect(isApproximatelyEqual(withBloom, withoutBloom, absoluteTolerance: 0.01))
    }

    /// The blurred bed is dark-only and is one layer for a whole region. `BloomedRegion`
    /// is the only place `.blur` appears in the app's glyph path.
    @Test("The bloom bed is dark-only")
    func theBloomBedIsDarkOnly() {
        #expect(RenderEnv().isBloomBedEnabled)
        #expect(!RenderEnv(theme: .light).isBloomBedEnabled)
        #expect(!RenderEnv(theme: .highContrast).isBloomBedEnabled)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter GlyphGeometryTests
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GlyphCanvasTests
```

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then do the one calibration this task owes: render the throat at 96 pt beside `design/mockup-phosphor.html`'s and **record the result in `DECISIONS.md`**. CSS `blur()` takes the Gaussian standard deviation; SwiftUI's `blur(radius:)` and `GraphicsContext.BlurOptions` are documented only as "the radial size of the blur" and Apple does not state the relationship to σ. `0.062 · S` is the *mockup's* calibration, so compare once and write down what you found rather than assuming the units agree.

## Files

| Action | Path |
|---|---|
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift` — assemble the four passes in order; add the `GlyphCanvas` view with `C.Glyph.bleed` |
| create | `Modules/Sources/HunchUI/BloomedRegion.swift` — pass A, one offscreen layer per region |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `haloIndexStroke(in:)`, `isBloomed(side:in:)`, `bleed(side:in:)`, `bloomBlurRadius(side:)` |
| modify | `Modules/Tests/HunchUITests/Support/CoverageMask.swift` — add `maximumCoverageOnBorder()` |
| create | `Modules/Tests/HunchUITests/GlyphCanvasTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — add checks 13 and 14 |
| modify | `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` |
| modify | `DECISIONS.md` — record the blur-radius calibration against the mockup |

## Implementation notes

### The four passes, in the one correct order

| Pass | What | Geometry | Paint | Where it lives |
|---|---|---|---|---|
| **A — bed** | a clone of *the whole region's* marks, blurred | one offscreen layer **per glyph-bearing region** | `blur(0.062·S)`, `Opacity.bloomBed`, `.plusLighter` | `BloomedRegion`, **not** `GlyphRenderer` |
| **B — halo** | the glyph's stroked registers re-stroked wide | body outline + index stroke **only**, at ×3, round join | own hue at `Opacity.halo` | `GlyphRenderer` |
| **C — ink** | the mark | texture (clipped), light-theme keyline, silhouette, index stroke | own hue, opacity 1, miter join, butt cap, zero radius | `GlyphRenderer` |
| **D — knockout** | pip separation | disc `r = pipRadius + 0.5` stroked at `pipKnockoutWeight` | `ground` | `GlyphRenderer` |

The index stroke is emitted **after** pass D, which is why the C/D split in the table is not the emission order — read `geometry.md` §4's `draw` as normative: halo → texture → keyline → silhouette → knockout+discs → index stroke. A reviewer should check this order in any PR that touches drawing.

**Pass B excludes the fill texture and the pips, deliberately.** Widening a dot lattice at ×3 would raise its measured ink coverage toward 100 % and delete the rung `triple-encoding-proof.md` rests on. The texture and the pips take their glow from pass A only, which is a blur of the composited region and therefore does not change any register's coverage *relative to any other's*.

**Pass D's ring is `C.Glyph.pipKnockoutWeight`, not `weight.thin`.** Same number in the dark theme, different thing: `weight.thin` is an L1 design weight that picks up Bold Text and the High Contrast offset; the knockout is a geometric separator that opts out of both.

### The size regime

`C.Glyph.bodyStroke(side:in:)` already ships from E03 and is the rule: `env.weight(S < 48 ? .bodySm : .body)`. Shipped sites, all in the small regime except the throat and the Codex hero: SIEVE tail and ECHO seed 36 · ribbon tile, ECHO rail, ECHO primer, Codex thumbnail 44 · ECHO tray 52 · SIEVE lane 72 · throat 96 (SE) / 128 (Pro Max) · Codex hero 220.

Two discontinuities at S = 48, both consequences of the step and both correct: the body weight doubles, and because `fillInset = 1.5 × bodyWeight` **the fill region shrinks as the glyph grows** — inset radius 14.03 pt at S = 44 against 13.26 at S = 48. That is why T03 measures the ink ladder per size rather than asserting it once.

### The bleed

**The drawing overflows the S-box on the y axis at every size, and never on the x axis.** `bleed(side:in:)` returns both anyway, because a caller that pads only y is one High Contrast change away from being wrong. Paste `geometry.md` §2's implementation; the four terms come from the stroke rectangle's corners at `(±L/2 along u) ± (halfIndex along n)`:

| Hue | rotation | max \|y\| | max \|x\| |
|---|---|---|---|
| `amber` | 0° | `0.43·S + halfIndex` | `L/2` |
| `teal`, `rose` | 45°, 135° | `0.43·S + (L/2 + halfIndex)·√½` | `(L/2 + halfIndex)·√½` |
| `frost` | 90° | `0.43·S + L/2` | `halfIndex` |
| silhouette | — | `0.47·S + bodyReach` | `0.37·S + bodyReach` |

`halfIndex` is half the *drawn* index weight — `1.5 × indexWeight` when bloomed, else `0.5 ×`. `bodyReach` is `1.5 × bodyWeight` for the round-joined halo and `bodyWeight` for the miter-joined ink, because a miter on the triangle's 60° corner reaches `(W/2)/sin 30° = W`, the worst of the four shapes.

`DIRECTION-A-PHOSPHOR.md` §1.2's flat `bleed.glyph = 0.08·S` under-covers in two regimes: dark and light with bloom on for `32 ≤ S < 59.5` (which contains five of the eight shipped sites), and **High Contrast at every size**, where frost needs `0.1345·S`. The layout consequence is not just padding — a ribbon of 44 pt tiles at 44 pt pitch has adjacent index strokes overlapping unless the pitch accounts for the bleed, and `.clipped()` anywhere on the path from the tile to the `Canvas` cuts the tip instead.

### `BloomedRegion` — pass A, once per region

**The halo is free and the blur is not.** The halo is two extra `stroke` calls into the same layer. The blur is an explicit offscreen layer: inside a `Canvas` the only way to blur drawn geometry is `addFilter(.blur(radius:))` around a `drawLayer { }`, exactly as `.blur()` is as a view modifier. So pass A is applied once per glyph-bearing region — **three layers per frame, not up to sixteen**.

Ship `bloom-and-squash.md` §5's `BloomedRegion<Content: View>` verbatim, and the `Canvas`-internal `addFilter` + `drawLayer` form as a doc comment on it so E08's ribbon has the shape to hand. The region's radius uses the **region's** `S`, not each tile's: a region with one radius is the entire point.

| Region | `S` | radius |
|---|---|---|
| throat | 96 / 128 | 5.95 / 7.94 |
| ribbon | 44 | 2.73 |
| SIEVE tail | 36 | 2.23 |
| SIEVE lane | 72 | 4.46 |
| **the Assay** | 3.5–23 | **excluded, always** |

Put `bloomBlurRadius(side:) = 0.062 * S` in `C.Glyph` so the number has one home and the regions in E08 and E14 call it rather than typing it.

### The exclusion matrix, as predicates

| Condition | Pass A | Pass B | Predicate |
|---|---|---|---|
| default, dark | on | on | — |
| light theme | **off** | on | `env.isBloomBedEnabled` is dark-only |
| Reduce Transparency / High Contrast / Low Power | off | off | `env.isBloomEnabled` |
| `S < 32` | off | off | `C.Glyph.isBloomed(side:in:)` — **the geometry half, ours** |
| the Assay, any size, any state | **off** | **off** | its drawing code never calls either |
| Reduce Motion | **unaffected** | **unaffected** | Reduce Motion freezes the shader's `t`; it does not touch bloom |

The environment half and the geometry half are separate on purpose: `RenderEnv` owns "has this player asked for less", this skill owns "is the mark big enough for a halo to be a halo".

**Why the Assay is excluded at every size and in every state:** its cells are 3.5–9.5 pt and carry no stroke to widen, and during the correct-declaration reveal it floods 256 cells at 1.6 ms/cell on top of the throat and the ribbon — precisely the frame that cannot afford a fourth offscreen layer against the ≤ 0.4 ms/frame shader budget.

### Two hygiene checks, added here because this is where the mistake becomes possible

Append to `Scripts/check-source-hygiene.sh`, in the same style as checks 9 and 10:

```bash
# 13. Bloom is one offscreen layer per glyph-bearing REGION, never one per glyph.
#     Owner: hunch-glyph-renderer. `GlyphRenderer` may not blur; `BloomedRegion` is the
#     only file in the glyph path that may.
grep -rn 'addFilter(.blur\|\.blur(radius' Modules/Sources --include='*.swift' \
  | grep -v 'BloomedRegion.swift' && fail "blur outside BloomedRegion"

# 14. The Assay is excluded from bloom entirely, at every size and in every state (§13.5).
grep -rln 'BloomedRegion' Modules/Sources --include='*Assay*.swift' \
  && fail "the Assay may never be bloomed"
```

Check 14 matches nothing today — `AssayCanvas` arrives in E09 — and that is the point: it is a tripwire planted before the file exists, at the cost of two lines.

### `.scaleEffect` versus a new `S`

Write the rule into `BloomedRegion.swift`'s doc comment because E08 and E09 will both need it and both can get it wrong:

**`.scaleEffect` for motion, a new `S` for size.** Using a new `S` for the admit pulse would step the stroke weight mid-animation at any site near 48 pt and re-phase the dot lattice every frame — the texture would crawl. Using `.scaleEffect` for Dynamic Type would freeze a 44 pt glyph in the `bodySm` regime at AX5, so a player asking for larger art gets a 59 pt glyph with a 2 pt stroke and a lattice pitched for a mark two-thirds the size. And the bleed changes when `S` changes: a host that re-renders at `S × artScale` must re-read `C.Glyph.bleed(side:in:)` with the new side.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphGeometryTests` green, including the four new cases.
- [ ] `xcodebuild test … -only-testing:HunchUITests/GlyphCanvasTests` green — in particular the frost-tip assertion at 44 and 96 pt on `circle` and `hexagon`, which is the draw-order proof.
- [ ] Fill-clip coverage of a `dotted` glyph is within 1 pp with bloom on and off — pass B touched neither the texture nor the pips.
- [ ] No ink lands on the border of the reserved frame in dark, light or High Contrast, for all four hues.
- [ ] `bash Scripts/check-source-hygiene.sh` passes, and a planted `.blur(radius: 4)` in `GlyphCanvas.swift` fails check 13.
- [ ] `grep -rn 'isReduceMotionEnabled' Modules/Sources/HunchUI/GlyphCanvas.swift Modules/Sources/HunchUI/BloomedRegion.swift` returns nothing — Reduce Motion is not a bloom setting.
- [ ] `DECISIONS.md` records the blur-radius calibration: what `0.062 · S` produced in SwiftUI against the mockup, and whether the constant stands.
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T05: the four passes in order, the 48 pt regime, the bleed, and one bloom layer per region"`

## Out of scope

- **Wiring `BloomedRegion` into a real throat, ribbon or tail** — E08·T03, E08·T05, E14·T02. This task ships the component and the radii table; it hosts nothing.
- **The Assay itself** — E09·T05. This task ships only the tripwire that stops it ever being bloomed.
- **`loomGrain`** — E20·T07. The shader is a separate `colorEffect` over the play surface and has nothing to do with bloom; the two are conflated constantly and are gated by different predicates.
- **Every animation** — the admit scale, the reject shudder, the verdict rings, the reveal's gather — E08·T06, E09·T10, E20·T08. The renderer has no time axis and must not grow one: a glyph that animates itself cannot be snapshot-tested and cannot be drawn 256 times into the Assay.
- **`env.artScale` application** — the drawing site multiplies `S`; this file never reads it.
- **The pairwise separation measurement** — T06, which consumes everything this task assembles.
