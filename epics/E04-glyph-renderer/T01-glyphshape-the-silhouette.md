# T01 — GlyphShape, the silhouette

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (needs E02's `Glyph` and E03's `Tokens` already on `main`) |
| **Delivers** | §14.1 ART / MOTION → **Glyph geometry** (the `shape` register) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.Glyph` is an **L2** namespace and this task appends its first two members. The skill owns the layering rule (`L2 → L1 → L0`, never a `Prim` from a view), the `env.weight(_:)` resolution order, and `Radius.glyph = 0` — the token that makes "never round a glyph corner" a value rather than a promise. Load it first: the renderer skill assumes its vocabulary. |
| `hunch-glyph-renderer` | Owns the coordinate frame, the four registers and the silhouette. Read `references/geometry.md` §1 (why §13.5 cannot be read literally), §2 (the `C.Glyph` member list), §3 (the vertex table and the apothem identity) and §4 (the compiling `GlyphShape`) before writing a line. Run its Step 0 script first — if it prints `GLYPH RENDERER NOT BUILT YET`, `geometry.md` §4 is the spec and the file is yours to create. |
| `hunch-swift-code` | `GlyphShape` is a new type in a new file in `HunchUI`. The skill owns the boundary predicate (why this file is in `Modules/` and not `HunchCore/`), one-top-level-type-per-file, and the `Glyph.Shape` nesting that stops `Shape` colliding with `SwiftUI.Shape` at every use site. |

## Objective

`GlyphShape` exists as a `SwiftUI.Shape` conformance that draws any of the four silhouettes — circle, triangle, square, hexagon — inscribed in `R = 0.37·S` about `bodyCentre`, in the screen-frame reading of §13.5, with a `radiusScale` parameter so the same polygon serves as the fill clip. Before this task there is no drawing code in the repository at all; after it, the `shape` channel — corner count 0 / 3 / 4 / 6 — is a path you can stroke, clip to and measure.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | the four `Glyph.Shape` values, their rank order, and that corner count is the non-colour encoding of the channel |
| `GAME_DESIGN.md` | §13.5 | `bodyCentre`, `R`, the vertex angles per shape, conventional orientation |
| `GAME_DESIGN.md` | §13.1, §13.3 | miter joins, butt caps, **zero radius always**; rounding a glyph corner is a PR-rejection offence because corner count *is* the channel |
| `GAME_DESIGN.md` | §13.5.1 | corner count {0, 3, 4, 6} is the achromatic discriminator this task must preserve |
| `hunch-glyph-renderer` | `references/geometry.md` §1 | the y-down resolution: every y in §13.5 is negated on the way in |
| `hunch-glyph-renderer` | `references/geometry.md` §2, §3, §4 | the `C.Glyph` members, the apothem table, the paste-ready `GlyphShape` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §3 | the file's home (`Modules/Sources/HunchUI/GlyphShape.swift`), the boundary rule, and the `Glyph.Shape` nesting |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W11, W16, W18 | one top-level type named for the file; caseless enums for namespaces; no unmutated `var` |
| `ios-swift-guide/06-TESTING.md` | T4, T42 | plain `import`, never `@testable`; never `==` on two `Double`s |

Never restate a value the spec owns. `0.37`, `0.10` and the four vertex-angle lists live in `C.Glyph` and `GlyphShape.vertexAngles(for:)` and nowhere else; the tests below assert *relations between resolved values*, not the values.

## TDD — the test comes first

**Step 1 — write the failing tests.** Three files, because three modules are involved.

Create `HunchCore/Tests/GlyphsTests/GlyphChannelTests.swift`:

```swift
import Testing
import Glyphs
import HunchTestSupport

@Suite("Glyph channel discriminators", .tags(.unit, .presubmission))
struct GlyphChannelTests {

    @Test("Corner count is a strictly increasing function of shape rank")
    func cornerCountIsStrictlyIncreasingInRank() {
        let counts = Glyph.Shape.allCases.map(\.cornerCount)
        #expect(counts == counts.sorted())
        #expect(Set(counts).count == Glyph.Shape.allCases.count)
        #expect(Glyph.Shape.circle.cornerCount == 0)
    }

    @Test("Pip count is a strictly increasing function of pips rank")
    func pipCountIsStrictlyIncreasingInRank() {
        let counts = Glyph.Pips.allCases.map(\.count)
        #expect(counts == counts.sorted())
        #expect(Set(counts).count == Glyph.Pips.allCases.count)
        #expect(counts.allSatisfy { (1...4).contains($0) })
    }
}
```

Create `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift`:

```swift
import Testing
import Tokens
import HunchTestSupport

@Suite("C.Glyph arithmetic", .tags(.unit, .presubmission))
struct GlyphGeometryTests {

    /// The body radius is a fixed ratio of the box side, so a glyph resized is the same
    /// glyph. Asserted as a ratio between two sizes rather than against 0.37, so the test
    /// still holds if the ratio ever moves and still fails if the derivation stops being
    /// linear in S.
    @Test("The body radius is linear in the box side", arguments: [24.0, 36, 44, 48, 96, 220])
    func bodyRadiusIsLinearInTheBoxSide(side: Double) {
        let unit = C.Glyph.radius(side: 1)
        #expect(isApproximatelyEqual(
            C.Glyph.radius(side: side), unit * side, absoluteTolerance: 1e-9))
        #expect(C.Glyph.radius(side: side) < side / 2)   // the silhouette fits its box
    }

    /// §13.5 states `bodyCentre = (0, +0.10·S)` in a y-up frame. In the screen frame the
    /// offset is negative — the body sits ABOVE the box centre — and this sign is the one
    /// thing three of §13.5's four sentences depend on (geometry.md §1).
    @Test("The body centre sits above the box centre in the screen frame",
          arguments: [24.0, 44, 96, 220])
    func theBodyCentreSitsAboveTheBoxCentre(side: Double) {
        #expect(C.Glyph.centreOffset(side: side) < 0)
        #expect(isApproximatelyEqual(
            C.Glyph.centreOffset(side: side),
            C.Glyph.centreOffset(side: 1) * side,
            absoluteTolerance: 1e-9))
    }

    /// A glyph corner is never rounded: corner count IS the shape channel (§13.1).
    @Test("The glyph corner radius token is zero")
    func theGlyphCornerRadiusIsZero() {
        #expect(Radius.glyph == 0)
    }
}
```

Create `Modules/Tests/HunchUITests/GlyphShapeTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI            // plain import, never @testable (06 T4) — every member below is public

@Suite("GlyphShape", .tags(.unit, .presubmission))
struct GlyphShapeTests {

    private static let box = CGRect(x: 10, y: 20, width: 44, height: 44)

    private func bodyCentre(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY + C.Glyph.centreOffset(side: min(rect.width, rect.height)))
    }

    /// The polygon has exactly `cornerCount` distinct vertices, and every one of them is
    /// exactly `R` from `bodyCentre` — which is what "inscribed in R" means and what a
    /// hand-tuned vertex list would silently break.
    @Test("Every vertex is inscribed in R about the body centre",
          arguments: Glyph.Shape.allCases.filter { $0.cornerCount > 0 })
    func everyVertexIsInscribedInR(shape: Glyph.Shape) throws {
        let radius = C.Glyph.radius(side: Self.box.width)
        let centre = bodyCentre(in: Self.box)
        let angles = try #require(GlyphShape.vertexAngles(for: shape))
        #expect(angles.count == shape.cornerCount)
        #expect(Set(angles.map { Int($0) }).count == shape.cornerCount)
        for degrees in angles {
            let point = GlyphShape.point(on: centre, radius: radius, degrees: degrees)
            #expect(isApproximatelyEqual(hypot(point.x - centre.x, point.y - centre.y),
                                         radius, absoluteTolerance: 1e-9))
        }
    }

    /// Conventional orientation, stated as three consequences a wrong frame breaks:
    /// the triangle's apex is at the TOP of the box, the square is axis-aligned, and the
    /// hexagon is pointy-top. All three are false under the naive y-up reading of §13.5.
    @Test("Conventional orientation holds in the screen frame")
    func conventionalOrientationHoldsInTheScreenFrame() throws {
        let centre = bodyCentre(in: Self.box)
        let radius = C.Glyph.radius(side: Self.box.width)
        func points(_ shape: Glyph.Shape) throws -> [CGPoint] {
            try #require(GlyphShape.vertexAngles(for: shape))
                .map { GlyphShape.point(on: centre, radius: radius, degrees: $0) }
        }

        let triangle = try points(.triangle)
        let apex = try #require(triangle.min { $0.y < $1.y })
        #expect(isApproximatelyEqual(apex.x, centre.x, absoluteTolerance: 1e-9))   // apex up
        #expect(apex.y < centre.y)

        let square = try points(.square)
        #expect(square.allSatisfy {                                                // axis-aligned
            !isApproximatelyEqual($0.x, centre.x, absoluteTolerance: 1e-6)
                && !isApproximatelyEqual($0.y, centre.y, absoluteTolerance: 1e-6)
        })

        let hexagon = try points(.hexagon)
        let top = try #require(hexagon.min { $0.y < $1.y })
        #expect(isApproximatelyEqual(top.x, centre.x, absoluteTolerance: 1e-9))    // pointy-top
    }

    /// The path is centred on `bodyCentre`, not on the rect centre. Getting this wrong
    /// still draws a plausible glyph — a different one, with all four pips and the index
    /// register moved together.
    @Test("The path is centred on the body centre, never on the rect centre",
          arguments: Glyph.Shape.allCases)
    func thePathIsCentredOnTheBodyCentre(shape: Glyph.Shape) {
        let bounds = GlyphShape(shape: shape).path(in: Self.box).boundingRect
        let centre = bodyCentre(in: Self.box)
        #expect(isApproximatelyEqual(bounds.midX, centre.x, absoluteTolerance: 1e-6))
        #expect(isApproximatelyEqual(bounds.midY, centre.y, absoluteTolerance: 1e-6))
        #expect(bounds.midY < Self.box.midY)
    }

    /// `radiusScale` is the ONLY way to shrink a silhouette anywhere in the app, because
    /// offsetting a regular polygon is a change of apothem and therefore exact (§3).
    @Test("radiusScale scales about the body centre and nothing else",
          arguments: Glyph.Shape.allCases)
    func radiusScaleScalesAboutTheBodyCentre(shape: Glyph.Shape) {
        let full = GlyphShape(shape: shape).path(in: Self.box).boundingRect
        let half = GlyphShape(shape: shape, radiusScale: 0.5).path(in: Self.box).boundingRect
        #expect(isApproximatelyEqual(half.midX, full.midX, absoluteTolerance: 1e-6))
        #expect(isApproximatelyEqual(half.midY, full.midY, absoluteTolerance: 1e-6))
        #expect(isApproximatelyEqual(half.width, full.width / 2, absoluteTolerance: 1e-6))
    }

    /// A non-square rect must not stretch the mark: `side = min(width, height)`.
    @Test("A non-square rect yields a square silhouette")
    func aNonSquareRectYieldsASquareSilhouette() {
        let wide = CGRect(x: 0, y: 0, width: 120, height: 44)
        let bounds = GlyphShape(shape: .square).path(in: wide).boundingRect
        #expect(isApproximatelyEqual(bounds.width, bounds.height, absoluteTolerance: 1e-6))
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter GlyphChannelTests
swift test --package-path HunchCore --filter GlyphGeometryTests
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GlyphShapeTests
```

Confirm each fails on a **missing symbol** — `cornerCount`, `C.Glyph.radius`, `GlyphShape` — not on a malformed test. A geometry test that passes before any geometry exists is testing nothing.

> If `Modules/Package.swift` (E03·T06) declares `.macOS(.v15)` alongside `.iOS(.v18)`, `swift test --package-path Modules --filter GlyphShapeTests` is the faster loop and gives the same result — `GlyphShape` touches no iOS-only API. Use it while iterating and the `xcodebuild` line before committing.

**Step 3 — implement** the minimum that turns them green. Files below.

**Step 4 — green, then refactor** with the tests as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/GlyphShape.swift` |
| modify | `HunchCore/Sources/Glyphs/Glyph.swift` — append the `Glyph.Shape.cornerCount` and `Glyph.Pips.count` extensions |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `C.Glyph.radius(side:)` and `C.Glyph.centreOffset(side:)` |
| create | `HunchCore/Tests/GlyphsTests/GlyphChannelTests.swift` |
| create | `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` |
| create | `Modules/Tests/HunchUITests/GlyphShapeTests.swift` |
| modify | `DECISIONS.md` — record the y-down reading of §13.5 |

## Implementation notes

### The coordinate frame, and why this is the first thing in the file

**Screen coordinates. Origin at the centre of the S-box, +x trailing, +y down, angles clockwise from East.** §13.5 states its *positions* in a y-up frame and its *angles* in the screen frame, and both cannot hold at once. `geometry.md` §1 has the four-row table; the summary is that three of §13.5's four sentences are false under the y-up reading — the triangle points down, the N pip lands at the bottom, the index stroke floats above the body — and all four are true under the y-down reading with every stated y negated:

```
bodyCentre  = (0, −0.10 · S)     §13.5's +0.10·S, negated
indexCentre = (0, +0.43 · S)     §13.5's −0.43·S, negated   (T04's concern)
angles       unchanged           they were already screen-frame
```

`DIRECTION-A-PHOSPHOR.md` §5 reached the same resolution independently. Costs nothing in Swift: `Path`, `GraphicsContext` and `CGRect` are all y-down already, so the negation happens once, in `C.Glyph.centreOffset(side:)`, and no drawing code thinks about it again. The only place the y-up numbers may appear is a comment citing §13.5.

**Record this in `DECISIONS.md`** as a spec-conflict resolution, with the four-row table and the citation of both §13.5 and PHOSPHOR §5. It is not an implementation detail: every later drawing task inherits the frame, and a reader who finds §13.5's `+0.10·S` in the GDD and the negated value in the code needs the entry to tell them which is authoritative.

### `C.Glyph`, the two members this task adds

Append to the `C.Glyph` namespace E03·T04 already opened in `HunchCore/Sources/Tokens/C.swift` (where `bodyStroke`, `keylineStroke` and `haloStroke` already ship). Nothing here is a colour, an opacity or a duration — every member is a ratio of `S`, a count, or a call into `env.weight(_:)`:

```swift
public static func radius(side S: Double) -> Double { 0.37 * S }

/// Signed y offset of `bodyCentre` from the box centre, **screen frame**.
/// §13.5 writes `+0.10·S` in a y-up frame; this is that value negated. See
/// DECISIONS.md, "The screen-frame reading of §13.5".
public static func centreOffset(side S: Double) -> Double { -0.10 * S }
```

`C.Glyph` lives in the `Tokens` target, which is a **leaf with no dependencies**. That is why later members take a `cornerCount: Int` rather than a `Glyph.Shape`: importing `Glyphs` into `Tokens` to spell one parameter would invert the dependency arrow and cost `swift test` its host-testability (`geometry.md` §2).

### The two model facts that go in `Glyphs`, not in `HunchUI`

```swift
extension Glyph.Shape {
    /// The achromatic discriminator for this channel (§13.5.1). `circle` is 0.
    public var cornerCount: Int {
        switch self {
        case .circle: 0
        case .triangle: 3
        case .square: 4
        case .hexagon: 6
        }
    }
}

extension Glyph.Pips {
    public var count: Int { rawValue + 1 }
}
```

Both are model facts rather than drawing facts, both are wanted by tests and by VoiceOver (E19·T02's glyph label reads a pip *count*), and putting them in `HunchUI` would mean the accessibility layer imports the renderer to say "three pips". They go beside `Glyph` in `HunchCore/Sources/Glyphs/Glyph.swift`.

`Glyph.Pips.count` assumes the enum is `Int`-backed with `one = 0`; if E02·T01 shipped it differently, write the four-arm `switch` instead — do **not** change the enum's raw values, which `glyphID = fill*64 + shape*16 + pips*4 + hue` depends on.

### `GlyphShape` itself

Paste `geometry.md` §4's first block. Four things in it are load-bearing and none is obvious:

1. **`nonisolated struct GlyphShape: SwiftUI.Shape`.** `HunchUI` carries `.defaultIsolation(MainActor.self)` (08 §4), `Shape.path(in:)` is a nonisolated protocol requirement, and a shape pinned to the main actor cannot be exercised by a package test suite with no main actor to run on. The `SwiftUI.` qualification on the conformance is what stops the compiler resolving `Shape` to `Glyph.Shape` at that line.
2. **`side = min(rect.width, rect.height)`.** The mark never stretches; a 120 × 44 rect draws a 44 pt glyph centred in it.
3. **`vertexAngles(for:)` returns `nil` for the circle** — a polygon with no vertices, corner count 0 — and the ellipse branch is the only place `addEllipse` is legal in this file. The angles are listed **ascending, which for all three polygons is also convex order**, so they walk straight into a `Path` with no sort and no winding check.
4. **`radiusScale` scales about `bodyCentre`, never about the rect centre.** T03's fill clip is this same polygon at another scale, and that identity is exact only because *offsetting a regular polygon is a change of apothem*. That one fact does three jobs across the epic: it makes `fillClipScale` exact, it lets the reference rasteriser model the miter-joined stroke band as the difference of two scaled polygons, and it means "shrink a silhouette by δ" anywhere in the app is `radiusScale = (apothem − δ) / apothem`, never a `Path` inset.

The apothem table you will need in T02 and T03, from `geometry.md` §3 — do not re-derive it per call site, compute it as `R · cos(π / n)`:

| Value | Corners | Apothem | Where the N pip lands |
|---|---|---|---|
| `circle` | 0 | `R` | mid-arc |
| `triangle` | 3 | `0.500·R` | on the apex vertex |
| `square` | 4 | `0.707·R` | mid-edge |
| `hexagon` | 6 | `0.866·R` | on a vertex |

### Stroke style is not this file's business — but the rule is

`GlyphShape` returns a `Path`. The join, cap and radius are set by whoever strokes it, and for a glyph they are **miter join, butt cap, zero radius, always** (§13.3). T02 is where the first `stroke` call lands; write the rule into the doc comment here so the next reader finds it at the declaration:

```swift
/// Stroked with `lineJoin: .miter`, `lineCap: .butt` and `Radius.glyph` (zero), always.
/// Corner count *is* the `shape` channel (§13.5.1) and a rounded corner erodes it —
/// §13.1 makes it a PR-rejection offence on sight.
```

### On `@testable import`

`06 T4` bans it. Every member the tests touch (`GlyphShape`, `vertexAngles(for:)`, `point(on:radius:degrees:)`) must therefore be `public`. `geometry.md` §4 declares the two statics without an access modifier because it is showing a single file; make them `public static` when you paste. If a member does not want to be public, the test wants a different assertion, not a different import.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphChannelTests` green; `Glyph.Shape.allCases.map(\.cornerCount) == [0, 3, 4, 6]` holds by construction of the rank order.
- [ ] `swift test --package-path HunchCore --filter GlyphGeometryTests` green, and `C.Glyph.centreOffset(side:)` returns a **negative** number at every size.
- [ ] `xcodebuild test … -only-testing:HunchUITests/GlyphShapeTests` green: six suites, every vertex inscribed in `R`, apex-up / axis-aligned / pointy-top all asserted in the screen frame.
- [ ] `grep -n 'radiusScale' Modules/Sources/HunchUI/GlyphShape.swift` shows it applied to `radius` only — no second scaling of the centre.
- [ ] `grep -rn 'cornerRadius\|RoundedRectangle\|\.continuous' Modules/Sources/HunchUI/GlyphShape.swift` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` passes — no hex, no numeric `lineWidth:`, no literal opacity in the new files (checks 9 and 10).
- [ ] `DECISIONS.md` has an entry titled for the screen-frame reading of §13.5 carrying `geometry.md` §1's four-row table and citing both §13.5 and `DIRECTION-A-PHOSPHOR.md` §5.
- [ ] The fast suite is still under 10 s: `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T01: GlyphShape — the four silhouettes in the screen frame, inscribed in R"`

## Out of scope

- **Contour pips and the knockout ring** — T02. `GlyphShape` returns a silhouette path and knows nothing about nodes on it.
- **The fill clip and the three textures** — T03. This task ships `radiusScale`; T03 ships `fillClipScale(cornerCount:side:in:)` that computes what to pass it.
- **The index stroke** — T04. It is not part of the silhouette and it is not inside the box.
- **`GlyphRenderer`, `GlyphCanvas`, any `stroke` call, the halo and the bleed** — T02 opens the file, T05 finishes it.
- **`Glyph`, `Deck`, `glyphID`, the four nested enums** — E02·T01–T02, already on `main`.
- **`Radius.glyph`, `StrokeWeight`, `Palette`** — E03. This task reads them; it declares none of them.
- **Anything in `Marks/`** — T07 and T08.
