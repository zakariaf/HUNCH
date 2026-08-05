# T08 — Profile geometry

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | Geometry (PROFILE) · 18 screens (SCREENS / NAVIGATION) — screen 14 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The nineteen `C.Profile.*` members this component declares are L2 and land in `HunchCore/Sources/Tokens/C.swift` with their §11.10 citations; the contour's ink, the fill and the spokes resolve through `RenderEnv` and their High Contrast substitutions are the tokens skill's resolution order, not a branch in the view. |
| `hunch-chrome-and-meta` | Owns this exact component: `references/profile-contour.md` holds the vertex table, the normalisation, the spline-to-Bézier conversion, the ink table, the ban on gridlines and numerals, and the `nonisolated struct ContourShape` shape. It is the spec for this task and must be read in full before the first line. |

## Objective

At the end of this task the portrait exists as a shape: five vertices at `−90° + i·72°` with radii
normalised against the player's own five-axis mean, joined by a closed Catmull–Rom spline converted
to cubic Bézier — never a polygon — with no gridlines, rings, ticks, axis labels or numerals
anywhere on it. A uniform rise across all five axes leaves it pixel-identical, which is what makes
"not a grade" a property of the geometry rather than a rule about copy.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.10 | the card, the centre, `R0`, the five locked angles and their order; the normalisation formula and its day-1 guard; the closed Catmull–Rom spline at tension 0.5 and the reason it is not a polygon; the ink table; the High Contrast substitutions |
| `GAME_DESIGN.md` | §11.11 | **P1–P8**, all eight, made enforceable — P1 (mean-normalised), P2 (no gridlines, rings, ticks or numerals), P4 (no other player's data), P5 (no time series), P6 (never at round end) |
| `GAME_DESIGN.md` | §11.10 | the Day 1 / Week 1 / Month 3 table — the three shapes this geometry must actually produce |
| `GAME_DESIGN.md` | §13.11 | the card holds its geometry and does **not** scale with type; the sigils reflow at AX3; the stat block goes one item per line at AX2 |
| `GAME_DESIGN.md` | §13.1, §13.2 | the accent ration and register segregation — the brass contour is a sanctioned accent site and is not a glyph body, fill, pip, ramp cell or index stroke |
| `GAME_DESIGN.md` | §12.2, §12.3 | screen 14's row and the play key in the instrument bar |
| `hunch-chrome-and-meta` | `references/profile-contour.md` §1–§4, §11, §12 | the whole component: L2 names, the normalisation, the spline code shape, the ink table, the property that must be tested, and the twelve ways to get it wrong |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files. The arithmetic is core, so most of it runs in the
fast suite.

`HunchCore/Tests/ArchiveTests/ProfileGeometryTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Tokens
import HunchTestSupport

@Suite("Profile geometry — §11.10's mean normalisation", .tags(.unit, .presubmission))
struct ProfileGeometryTests {

    private func profile(_ values: [Double], n: Double = 60) -> Profile {
        var p = Profile()
        for (i, axis) in ProfileAxis.allCases.enumerated() {
            p[axis] = Axis(value: values[i], n: n, lastSampleAt: Date(timeIntervalSince1970: 0))
        }
        return p
    }

    // MARK: - P1, the load-bearing rule

    /// §11.11 P1 / §11.10: "A uniform rise across all five axes leaves the shape pixel-identical."
    @Test("a uniform rise across all five axes leaves the shape pixel-identical")
    func uniformRiseLeavesTheShapeIdentical() {
        let base = profile([0.2, 0.5, 0.3, 0.8, 0.4])
        let risen = profile([0.2, 0.5, 0.3, 0.8, 0.4].map { $0 * 1.6 })   // still ≤ 1.0 everywhere
        #expect(zip(base.normalisedRadii(), risen.normalisedRadii())
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
    }

    @Test("scaling by any positive factor is invisible", arguments: [0.25, 0.5, 1.25, 2.0, 4.0])
    func anyUniformScaleIsInvisible(_ factor: Double) {
        let base = profile([0.10, 0.20, 0.15, 0.24, 0.18])
        let scaled = profile([0.10, 0.20, 0.15, 0.24, 0.18].map { min(1, $0 * factor) })
        guard scaled.values.allSatisfy({ $0 < 1.0 }) else { return }      // clipping breaks the ratio
        #expect(zip(base.normalisedRadii(), scaled.normalisedRadii())
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
    }

    @Test("asymmetry IS visible — bending one axis moves exactly one radius up and the rest down")
    func asymmetryIsVisible() {
        let flat = profile([0.5, 0.5, 0.5, 0.5, 0.5])
        let bent = profile([0.5, 0.5, 0.5, 0.9, 0.5])
        let a = flat.normalisedRadii(), b = bent.normalisedRadii()
        #expect(b[3] > a[3])
        #expect(b[0] < a[0])          // the mean rose, so every un-bent axis shortens
    }

    // MARK: - the formula

    @Test("radii follow R0 · clamp(0.55 + 0.45·v/max(0.15, v̄), 0.35, 1.55)")
    func radiusFormula() {
        let p = profile([0.2, 0.4, 0.6, 0.8, 1.0])          // v̄ = 0.6
        let expected = [0.2, 0.4, 0.6, 0.8, 1.0].map { v in
            C.Profile.r0 * min(1.55, max(0.35, 0.55 + 0.45 * v / 0.6))
        }
        #expect(zip(p.normalisedRadii(), expected)
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
    }

    /// §11.10's Day 1 row: all vᵢ = 0, v̄ guarded to 0.15, so every rᵢ = 0.55 · R0.
    @Test("day 1 is a small regular pentagon-spline that reads as unformed, not as zero")
    func dayOneIsARegularPentagon() {
        let radii = Profile().normalisedRadii()
        #expect(radii.allSatisfy { isApproximatelyEqual($0, 0.55 * C.Profile.r0,
                                                        absoluteTolerance: 1e-9) })
        #expect(Set(radii.map { ($0 * 1e6).rounded() }).count == 1)      // all five identical
    }

    @Test("the clamps bind at the extremes and the radius never leaves [0.35·R0, 1.55·R0]")
    func clampsBind() {
        let extreme = profile([0.0, 0.0, 0.0, 0.0, 1.0])
        let radii = extreme.normalisedRadii()
        #expect(radii.allSatisfy { $0 >= 0.35 * C.Profile.r0 - 1e-9 })
        #expect(radii.allSatisfy { $0 <= 1.55 * C.Profile.r0 + 1e-9 })
        #expect(isApproximatelyEqual(radii[4], 1.55 * C.Profile.r0, absoluteTolerance: 1e-9))
    }

    @Test("normalising against R0 or a constant instead of v̄ would let the portrait grow — it does not")
    func theNormaliserIsTheMeanAndNotAConstant() {
        let low = profile([0.1, 0.1, 0.1, 0.1, 0.1])
        let high = profile([0.9, 0.9, 0.9, 0.9, 0.9])
        #expect(zip(low.normalisedRadii(), high.normalisedRadii())
            .allSatisfy { isApproximatelyEqual($0.0, $0.1, absoluteTolerance: 1e-9) })
    }

    // MARK: - the vertices

    @Test("the five vertices sit at −90° + i·72°, clockwise from the top", arguments: 0..<5)
    func vertexAngles(_ i: Int) {
        let expected = (-90.0 + Double(i) * 72.0) * .pi / 180
        #expect(isApproximatelyEqual(ProfileGeometry.angle(forVertex: i), expected,
                                     absoluteTolerance: 1e-12))
    }

    @Test("the vertex order is the axis order — one table, not two")
    func vertexOrderIsTheAxisOrder() {
        #expect(ProfileAxis.allCases.map(\.rawValue) == Array(0..<5))
        #expect(ProfileAxis.induction.rawValue == 0)     // −90°, the top
        #expect(ProfileAxis.tempo.rawValue == 4)         // 198°
    }

    @Test("the top vertex is above the centre in the screen frame (y grows downward)")
    func topVertexIsAbove() {
        let p = ProfileGeometry.point(forVertex: 0, radius: 50, centre: C.Profile.centre)
        #expect(p.y < C.Profile.centre.y)
        #expect(isApproximatelyEqual(p.x, C.Profile.centre.x, absoluteTolerance: 1e-9))
    }
}
```

`Modules/Tests/MetaFeatureTests/ContourShapeTests.swift`:

```swift
import Foundation
import SwiftUI
import Testing
import Archive
import Tokens
import MetaFeature
import ModulesTestSupport

@Suite("ContourShape — a closed spline, never a polygon", .tags(.unit, .presubmission))
struct ContourShapeTests {

    private let radii = [96.0, 72.0, 110.0, 60.0, 88.0]
    private let rect = CGRect(origin: .zero, size: C.Profile.cardSize)

    @Test("the path is five cubic curves and one close — no lines")
    func fiveCurvesNoLines() {
        var curves = 0, lines = 0, closes = 0
        ContourShape(radii: radii, centre: C.Profile.centre)
            .path(in: rect)
            .forEach { element in
                switch element {
                case .curve: curves += 1
                case .line: lines += 1
                case .closeSubpath: closes += 1
                case .move, .quadCurve: break
                }
            }
        #expect(curves == 5)
        #expect(lines == 0)            // a polygon would be five lines — §11.10
        #expect(closes == 1)
    }

    @Test("the path passes through all five vertices")
    func passesThroughTheVertices() {
        let path = ContourShape(radii: radii, centre: C.Profile.centre).path(in: rect)
        for i in 0..<5 {
            let v = ProfileGeometry.point(forVertex: i, radius: radii[i], centre: C.Profile.centre)
            #expect(path.contains(v, eoFill: false) || path.boundingRect.insetBy(dx: -1, dy: -1).contains(v))
        }
    }

    @Test("the shape is nonisolated so it can be exercised without a main actor")
    func shapeIsNonisolated() {
        // Compiles only if `path(in:)` is callable from a nonisolated context.
        let path = ContourShape(radii: radii, centre: C.Profile.centre).path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("animatableData interpolates the five radii, not the whole path")
    func animatableDataIsTheRadii() {
        var shape = ContourShape(radii: radii, centre: C.Profile.centre)
        shape.animatableData = AnimatableVector([1, 2, 3, 4, 5])
        #expect(shape.radii == [1, 2, 3, 4, 5])
    }

    @Test("the portrait draws no gridline, ring, tick, label or numeral — §11.11 P2")
    func noGridlinesNoNumerals() {
        let inventory = ProfileContour.drawnElements(for: .preview)
        #expect(inventory == [.contour, .innerOffset, .fill, .spokes])
        #expect(!inventory.contains(.gridline))
        #expect(!inventory.contains(.ring))
        #expect(!inventory.contains(.tick))
        #expect(!inventory.contains(.numeral))
    }

    @Test("the card does not scale with Dynamic Type — §13.11")
    func cardDoesNotScale() {
        let small = ProfileContour.resolvedCardSize(in: .preview(typeMultiplier: 1.0))
        let ax5 = ProfileContour.resolvedCardSize(in: .preview(typeMultiplier: 3.1))
        #expect(small == ax5)
        #expect(small == C.Profile.cardSize)
    }

    @Test("the portrait does not mirror under RTL — mirroring would swap Retention with Tempo")
    func doesNotMirror() {
        let ltr = ContourShape(radii: radii, centre: C.Profile.centre).path(in: rect)
        let rtl = ProfileContour.path(radii: radii, layoutDirection: .rightToLeft, in: rect)
        #expect(ltr.description == rtl.description)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ProfileGeometryTests`
then `swift test --package-path Modules --filter ContourShapeTests`. `uniformRiseLeavesTheShapeIdentical`
must be watched fail-then-pass specifically: implement the normalisation *wrongly* first — against
`R0` instead of `v̄` — see it fail, and only then write the mean. That is the one bug this whole test
exists for and it is worth thirty seconds to see it caught.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/ProfileGeometry.swift` — `angle(forVertex:)`, `point(forVertex:radius:centre:)`, `Profile.normalisedRadii()` |
| modify | `HunchCore/Sources/Tokens/C.swift` — the nineteen `C.Profile.*` members, each with its §11.10 citation |
| create | `Modules/Sources/MetaFeature/ProfileContour.swift` — `ProfileContour: View` and `nonisolated struct ContourShape: Shape` |
| create | `Modules/Sources/MetaFeature/ProfileView.swift` — screen 14: instrument bar with the play key and the statistics key, the card, the stat block |
| create | `Modules/Sources/HunchUI/AnimatableVector.swift` — five-component `VectorArithmetic`, if E09 has not already added one |
| create | `HunchCore/Tests/ArchiveTests/ProfileGeometryTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/ContourShapeTests.swift` |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — the screen title plus the five stat-block labels (§12.9's 5 keys) |
| modify | `tests.json` — six entries |
| modify | `DECISIONS.md` — the core/`MetaFeature` split for the radius arithmetic |

## Implementation notes

### The split: arithmetic is core, the path is not

```swift
// HunchCore/Sources/Archive/ProfileGeometry.swift
extension Profile {
    /// §11.10: v̄ = mean(v₀…v₄); rᵢ = R0 · clamp(0.55 + 0.45·vᵢ / max(0.15, v̄), 0.35, 1.55)
    public func normalisedRadii(r0: Double = C.Profile.r0) -> [Double]
}
```

`normalisedRadii` is a pure function of five `Double`s and one token. It needs no SwiftUI, so under
`08 §2`'s boundary predicate it is core — which puts P1's property test in the sub-10-second host
suite where it belongs, and makes it impossible to "fix" the normalisation inside a view. Record the
split in `DECISIONS.md`; `profile-contour.md` writes the formula inside the component and this is a
placement refinement of it, not a contradiction.

`ContourShape` — the Bézier conversion — stays in `MetaFeature` because `Shape` is a SwiftUI protocol.
It takes `radii: [Double]` **already normalised and already trembled** and does no arithmetic of its
own beyond the spline.

### The normalisation, and the three ways it dies

```
v̄  = mean(v₀ … v₄)
rᵢ = R0 · clamp(0.55 + 0.45 · vᵢ / max(0.15, v̄), 0.35, 1.55)
```

- **Replacing `v̄` with a constant** makes the portrait grow. `theNormaliserIsTheMeanAndNotAConstant`
  catches it.
- **Clamping against `R0` instead of the ratio** makes it grow differently. The clamp is on the
  *multiplier*, `[0.35, 1.55]`, and `R0` multiplies afterwards.
- **Dropping `max(0.15, v̄)`** divides by zero on day 1. The guard is what makes the day-1 portrait a
  small regular pentagon that reads as *unformed* rather than as a point at the origin, and
  `dayOneIsARegularPentagon` is its test.

### The spline

`profile-contour.md` §3 carries the exact code — a cardinal spline at `C.Profile.splineTension`,
`s = tension / 3`, one `addCurve` per segment with control points from the neighbouring vertices,
then `closeSubpath()`. Take it verbatim; the only thing to add is `animatableData` over the five
radii, which is what makes T10's staggered morph a real interpolation rather than a crossfade between
two static shapes.

**Five `addCurve` calls and zero `addLine` calls.** `fiveCurvesNoLines` is the test, and §11.10's
reason is the doc comment: *"a polygon with vertices reads as a radar chart, and a radar chart reads
as a score."*

`nonisolated struct ContourShape: Shape` — `MetaFeature` takes `.defaultIsolation(MainActor.self)`,
`Shape.path(in:)` is a nonisolated protocol requirement, and a main-actor-pinned shape cannot be
exercised by a `swift test` suite that has no main actor to run on. This is the same ruling
`GlyphShape` already took (E04·T01).

### Ink, and what must not be drawn

`profile-contour.md` §4's table, resolved through `env`: contour `accent.brass` at
`C.Profile.contourWeight` (→ `stroke.primary` under High Contrast), interior fill at
`C.Profile.fillInk` (→ transparent), inner offset contour for depth, five spokes at
`C.Profile.spokeInk`. The brass contour is the screen's one accent (§13.1); the stat block and the
vertex sigils are `stroke.*`.

**Nothing else.** No gridlines, no concentric rings, no ticks, no axis labels, no numerals — §11.10
and §11.11 P2, and `noGridlinesNoNumerals` asserts the drawn-element inventory exactly rather than
hoping. The five 12 % spokes exist only to say *there are five of something*; they are not a scale.

### P6, enforced rather than remembered

> **P6** The portrait is **never shown at round end**. It lives only on the Profile screen, entered
> deliberately. A per-round readout is a grade by any other name. — §11.11

That is a *reachability* claim, so make it one. The epic gate's `ProfileVisibilityTests` is a source
lint: `InscriptionView.swift` may not import `MetaFeature`, may not name `ProfileContour`, `Profile`
or `normalisedRadii`, and no view reachable from the Inscription's body may either. Add it in this
task, next to the geometry it protects.

### The stat block

Five rows, §12.9's five keys: rounds, pages, longest run, Anomaly streak, mean probes/par.
`numeral-readout.md` site 6. **No "highest band" row** — §10.5 forbids surfacing a band number and the
Codex shelves already carry that fact retrospectively. One item per line at AX2 and above (§13.11).

### Day 1, Week 1, Month 3

§11.10's table is three shapes this geometry must actually produce, and each is worth a preview:
day 1 a small regular pentagon at `0.55 · R0`; week 1 radii spread ±15 % with two starved axes; month
3 a player pulled toward Restraint at `r ≈ 148 pt` and away from Tempo at `r ≈ 62 pt`. Build all
three as `Profile.preview` cases in `MetaFeatureTests` and screenshot them into `PROGRESS.md` —
that is the only way anyone will notice if the silhouette stops being legible.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ProfileGeometryTests` green, all nine tests.
- [ ] `swift test --package-path Modules --filter ContourShapeTests` green, all seven tests.
- [ ] `uniformRiseLeavesTheShapeIdentical` was seen to **fail** against an `R0`-normalised implementation before the mean was written, and the transcript is noted in the commit message.
- [ ] `grep -rn "addLine" Modules/Sources/MetaFeature/ProfileContour.swift` returns nothing.
- [ ] `grep -rniE "gridline|concentric|tickmark|axisLabel" Modules/Sources/MetaFeature/` returns nothing.
- [ ] `grep -rn "MetaFeature\|ProfileContour\|normalisedRadii" Modules/Sources/LoomFeature/InscriptionView.swift` returns nothing, and `ProfileVisibilityTests` is green.
- [ ] `Scripts/check-source-hygiene.sh` check 9 passes — every value in `ProfileContour.swift` is a `C.Profile.*` or an `env` accessor.
- [ ] The nineteen `C.Profile.*` members are in `C.swift`, each with a `§11.10` citation, and none of them is an L1 weight, opacity, duration or easing.
- [ ] The three §11.10 silhouettes are screenshotted into `PROGRESS.md`.
- [ ] `tests.json` carries six entries: pixel-identity under uniform rise, the radius formula, the day-1 guard, the clamps, five-curves-no-lines, and P6's unreachability.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes replacing the spline with a polygon "since the control points are derived anyway", reject it and point at §11.10.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T08: Profile geometry — mean-normalised radii and the closed Catmull–Rom contour"`

## Out of scope

- The five vertex sigils and their placement — **T09**.
- Tremble, the 2.4 s morph and the 90-day ghost — **T10**.
- The statistics key in the instrument bar leads to a screen built in **T11**.
- The axis values themselves — **T05**/**T06**.
- The route into `ProfileView` from the Frame's shelf — **E17·T01/T03**.
