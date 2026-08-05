# T02 — Contour pips

| | |
|---|---|
| **Epic** | E04 — Glyph renderer and the shared marks |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 ART / MOTION → **Glyph geometry** (the `pips` register) · §14.1 LOCALIZATION → **RTL** (the half that says pip accretion is game state and never mirrors) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | The knockout ring's ink is `ground.base` and the node's ink is the glyph's own `HueColor` — this task creates the one `Glyph.Hue → HueColor` mapping in the app, and the register split (`HueColor` vs `AccentColor` as distinct types) is what makes "an accent may never touch a pip" a compile error. It also owns why `pipKnockoutWeight` is *not* a `StrokeWeight`. |
| `hunch-glyph-renderer` | Owns the pip register. `references/geometry.md` §5 has the ray/convex support-function intersection, the knockout-is-a-stroke rule and §5.1's distance table — the S node and the index stroke overlap on two of the four shapes, which is what forces the draw order for the whole epic. |
| `hunch-swift-code` | `GlyphCanvas.swift` is created here and grows for three more tasks; the skill owns file placement, the one-type-per-file rule and the `nonisolated` requirement on a renderer that must be exercised without a main actor. |

## Objective

`GlyphRenderer` exists in `Modules/Sources/HunchUI/GlyphCanvas.swift` and draws a silhouette plus `pips.count` contour nodes, each sitting exactly where the ray from `bodyCentre` at θ ∈ {−90° N, 0° E, +90° S, 180° W} meets the silhouette centre-line, filled progressively N → E → S → W, each a hue disc of radius `max(3 pt, 0.11·R)` inside a 1 pt `ground` knockout ring. Before this task nothing in the app strokes anything; after it the `pips` channel — the deck's measured weakest channel at 44 pt and above — is drawn, separated from the body stroke and from any texture that reaches the contour.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §2 | `one = {N}` … `four = {N,E,S,W}`; node radius `0.11 × glyphRadius` floored at 3 pt; the decision that pips sit **on** the contour, not inside the body; "RTL: layout mirrors, glyphs never do" |
| `GAME_DESIGN.md` | §13.5 | the ray definition, the four θ, the 1 pt `ground` knockout ring, where the N node lands per shape |
| `GAME_DESIGN.md` | §13.5.1 | `pips` = count of contour discs at fixed compass rays, one of the four achromatic discriminators |
| `GAME_DESIGN.md` | §12.8 | RTL: the index stroke and pip accretion are game state |
| `hunch-glyph-renderer` | `references/geometry.md` §5, §5.1 | the support-function `contourHit`, the knockout-as-a-stroke rule, the frost-tip overlap table |
| `hunch-glyph-renderer` | `references/bloom-and-squash.md` §1 | pass D's ring is `C.Glyph.pipKnockoutWeight`, **not** `weight.thin`, and why the two are not the same number |
| `hunch-design-tokens` | `references/tokens-swift-layout.md` §4 | the `Glyph.Hue → HueColor` switch is owned by exactly one function, in `HunchUI/GlyphCanvas.swift`, so `Tokens` never depends on `Glyphs` |
| `ios-swift-guide/06-TESTING.md` | T4, T42 | plain `import`; never `==` on two `Double`s |

## TDD — the test comes first

**Step 1 — write the failing tests.**

Append to `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift`:

```swift
    /// The node has a hard 3 pt floor, so it stays visible at the smallest shipped site
    /// (the 36 pt SIEVE tail), and is proportional above the size where the floor releases.
    @Test("Pip radius is floored and otherwise proportional",
          arguments: [24.0, 36, 44, 52, 96, 220])
    func pipRadiusIsFlooredAndOtherwiseProportional(side: Double) {
        let radius = C.Glyph.pipRadius(side: side)
        #expect(radius >= 3)
        let proportional = C.Glyph.pipRadius(side: 1) * side
        #expect(isApproximatelyEqual(radius, max(3, proportional), absoluteTolerance: 1e-9))
    }

    /// The knockout is a geometric separator, not a design weight: it opts out of Bold
    /// Text and of the High Contrast offset, because 1 pt is what keeps the node visible
    /// at all and a ring that grew would eat the frost index tip (geometry.md §5.1).
    @Test("The pip knockout weight is a geometric separator, not a design weight")
    func thePipKnockoutWeightIsAGeometricSeparator() {
        let plain = RenderEnv()
        let loud = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        // It coincides with `weight.thin` in the dark default and diverges the moment
        // either accessibility axis is on — which is exactly why it may not BE that token.
        #expect(isApproximatelyEqual(C.Glyph.pipKnockoutWeight, plain.weight(.thin),
                                     absoluteTolerance: 1e-9))
        #expect(C.Glyph.pipKnockoutWeight < loud.weight(.thin))
        // Small enough that the node keeps its area at the smallest shipped site, 36 pt.
        #expect(C.Glyph.pipKnockoutWeight < C.Glyph.pipRadius(side: 36) / 2)
    }
```

Create `Modules/Tests/HunchUITests/GlyphPipTests.swift`:

```swift
import Testing
import SwiftUI
import Glyphs
import Tokens
import ModulesTestSupport
import HunchUI

@Suite("Contour pips", .tags(.unit, .presubmission))
struct GlyphPipTests {

    private static let side = 44.0
    private static let box = CGRect(x: 0, y: 0, width: side, height: side)

    private var centre: CGPoint {
        CGPoint(x: Self.box.midX, y: Self.box.midY + C.Glyph.centreOffset(side: Self.side))
    }

    /// Every node sits ON the silhouette centre-line — not inside it, not outside it.
    /// Verified against SwiftUI's own `Path.contains`, which is an implementation
    /// independent of the support function the renderer uses: a point 1 % inside the ray
    /// must be in the path and a point 1 % outside it must not.
    @Test("Every node lands on the silhouette",
          arguments: Glyph.Shape.allCases, Glyph.Pips.allCases)
    func everyNodeLandsOnTheSilhouette(shape: Glyph.Shape, pips: Glyph.Pips) {
        let radius = C.Glyph.radius(side: Self.side)
        let silhouette = GlyphShape(shape: shape).path(in: Self.box)
        for node in GlyphRenderer.contourNodes(
            shape: shape, pips: pips, bodyCentre: centre, radius: radius
        ) {
            func along(_ factor: Double) -> CGPoint {
                CGPoint(x: centre.x + (node.x - centre.x) * factor,
                        y: centre.y + (node.y - centre.y) * factor)
            }
            #expect(hypot(node.x - centre.x, node.y - centre.y) <= radius + 1e-6)
            #expect(silhouette.contains(along(0.99)))
            #expect(!silhouette.contains(along(1.01)))
        }
    }

    /// Accretion is nested, not arranged: `three` is `two` plus one node, which is what
    /// makes the count pre-attentive rather than counted (§2's decision).
    @Test("Pip accretion is a prefix, in N → E → S → W order",
          arguments: Glyph.Shape.allCases)
    func pipAccretionIsAPrefix(shape: Glyph.Shape) {
        let radius = C.Glyph.radius(side: Self.side)
        let sets = Glyph.Pips.allCases.map {
            GlyphRenderer.contourNodes(shape: shape, pips: $0, bodyCentre: centre, radius: radius)
        }
        for (index, nodes) in sets.enumerated() {
            #expect(nodes.count == Glyph.Pips.allCases[index].count)
            if index > 0 { #expect(Array(nodes.prefix(sets[index - 1].count)) == sets[index - 1]) }
        }
        // N is the topmost node in the screen frame; W is the leading one. Both are false
        // under a y-up reading and under a mirrored ray table.
        let four = sets[3]
        #expect(four[0].y < centre.y)
        #expect(four[1].x > centre.x)
        #expect(four[2].y > centre.y)
        #expect(four[3].x < centre.x)
    }

    /// On `triangle` and `hexagon` the N ray passes exactly through a vertex. A
    /// segment-intersection implementation has a degenerate case here; the support
    /// function does not, and this is the test that tells the two apart.
    @Test("The N ray hits a vertex on triangle and hexagon, and an edge elsewhere")
    func theNorthRayHitsAVertexOnTriangleAndHexagon() {
        let radius = C.Glyph.radius(side: Self.side)
        func north(_ shape: Glyph.Shape) -> CGPoint {
            GlyphRenderer.contourNodes(
                shape: shape, pips: .one, bodyCentre: centre, radius: radius)[0]
        }
        for shape in [Glyph.Shape.triangle, .hexagon, .circle] {
            #expect(isApproximatelyEqual(hypot(north(shape).x - centre.x,
                                               north(shape).y - centre.y),
                                         radius, absoluteTolerance: 1e-6))
        }
        let squareReach = hypot(north(.square).x - centre.x, north(.square).y - centre.y)
        #expect(isApproximatelyEqual(squareReach, radius * cos(.pi / 4), absoluteTolerance: 1e-6))
    }

    /// The knockout is a STROKE over the annulus `pipRadius … pipRadius + 1`, so the body
    /// stroke survives under the node. A `ground` disc of `pipRadius + 1` would draw the
    /// same picture and erase the silhouette beneath, which is what the ring exists to
    /// preserve. Rasterised, because this is a claim about pixels.
    @MainActor
    @Test("A ground ring separates the node from the body stroke", .tags(.snapshot))
    func aGroundRingSeparatesTheNodeFromTheBodyStroke() throws {
        let env = RenderEnv()
        let glyph = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber)
        let mask = try coverageMask(glyph, side: 96, env: env)
        let radius = C.Glyph.radius(side: 96)
        let node = CGPoint(x: 0, y: -radius)                 // N, relative to bodyCentre
        let pip = C.Glyph.pipRadius(side: 96)
        #expect(mask.coverage(atBodyOffset: node, side: 96, env: env) > 0.9)               // ink
        #expect(mask.coverage(atBodyOffset: CGPoint(x: 0, y: node.y + pip + 0.5),
                              side: 96, env: env) < 0.1)                                   // ground
        #expect(mask.coverage(atBodyOffset: CGPoint(x: 0, y: node.y + pip + 2.5),
                              side: 96, env: env) > 0.5)   // body stroke, still there
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter GlyphGeometryTests
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/GlyphPipTests
```

They must fail on missing `C.Glyph.pipRadius`, `GlyphRenderer` and `coverageMask` — not on a compile error in the test's own arithmetic.

**Step 3 — implement.** Files below. The raster helper is part of this task because it is the first test that needs pixels; T06 extends it, it does not rewrite it.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/GlyphCanvas.swift` — `GlyphRenderer` with the silhouette, the pips and the knockout; the `Palette.Hue` subscript |
| modify | `HunchCore/Sources/Tokens/C.swift` — append `C.Glyph.pipRadius(side:)` and `C.Glyph.pipKnockoutWeight` |
| create | `Modules/Tests/HunchUITests/Support/CoverageMask.swift` — the rasteriser the epic's pixel claims are made against |
| create | `Modules/Tests/HunchUITests/GlyphPipTests.swift` |
| modify | `HunchCore/Tests/TokensTests/GlyphGeometryTests.swift` |

## Implementation notes

### `contourHit` — the support function, not a segment walk

Node `k` sits where the ray from `bodyCentre` at θ_k meets the silhouette **centre-line**. Use the support-function form of ray/convex intersection:

```
t = min over edge normals n with (d · n) > 0 of  apothem / (d · n)
```

It is branch-free per edge, exact, and it reuses the same apothem the fill clip (T03) and the stroke band already use. A segment-intersection version has to handle the case where the ray passes exactly through a vertex — which is not hypothetical: on `triangle` and `hexagon` the N ray does exactly that, and on `hexagon` so does the S ray. `geometry.md` §4's `contourHit` is the implementation; expose the node list as a `public static func` so the tests above can address it without `@testable`:

```swift
/// The contour nodes for `pips`, in accretion order N → E → S → W (§2, §13.5).
/// Exposed because the accretion order and the ray table are game state, and a test
/// that could only see them through a raster could not tell a mirrored table from a
/// correct one.
public static func contourNodes(
    shape: Glyph.Shape, pips: Glyph.Pips, bodyCentre: CGPoint, radius: Double
) -> [CGPoint]
```

`pipRays` stays `private static let [-90, 0, 90, 180]` inside `GlyphRenderer` and is consumed as `.prefix(glyph.pips.count)`.

### The knockout is a stroke, and the order it implies

```swift
let knockout = Path(ellipseIn: CGRect(
    x: node.x - pipRadius - 0.5, y: node.y - pipRadius - 0.5,
    width: 2 * pipRadius + 1, height: 2 * pipRadius + 1))
context.stroke(knockout, with: ground, lineWidth: C.Glyph.pipKnockoutWeight)
context.fill(Path(ellipseIn: /* r = pipRadius, centred on node */), with: ink)
```

Stroking the annulus `pipRadius … pipRadius + 1` in `ground` and then filling the hue disc of exactly `pipRadius` inside it paints the same picture as a `ground` disc of `pipRadius + 1` under a hue disc — except that the disc version also erases the body stroke passing under the node, which is precisely what the ring exists to preserve.

**`pipKnockoutWeight` is `1.0` and opts out of Bold Text and of the High Contrast offset.** It is not a design weight; it is the separation that keeps the node from merging into the silhouette. At S = 36 the node is 3.0 pt against a `bodySm` 1.5 pt stroke, so a ring that grew to 1.25 or 1.5 pt would take a fifth of the node's visible area. Spell it `public static let pipKnockoutWeight = 1.0` in `C.Glyph` — **never** `env.weight(.thin)`, which is the same number in the dark theme today and a different number under either accessibility setting.

### §5.1 — the S node and the index stroke overlap, and it fixes the draw order for the whole epic

The S ray at +90° and the index register are the two closest things on the glyph, and on `circle` and `hexagon` — which alone put their S node at full `R` — they intersect. `frost` runs vertically and its upper tip sits `0.0235·S` from the S node; at S = 44 that is **1.82 pt from the node centre against a `pipRadius` of 3.0** — the tip is *inside the disc*. `teal` and `rose` reach inside the knockout ring at S ≤ 44.

Three consequences, all load-bearing:

1. **Pass D's `ground` knockout must run before the index stroke.** Otherwise the ring cuts a notch out of the hue channel on every circle-or-hexagon glyph with three or four pips and a frost index — a quarter of the deck, in the one register the whole colourblind case rests on. T04 adds the index stroke; T05 fixes the order and tests it. Write the comment now, at the end of pass D, so the next task cannot miss it.
2. **It is why `pips two ↔ three` is the deck's separation floor** (`triple-encoding-proof.md` §3): adding the S node to a circle-or-hexagon frost glyph adds the least new ink of any single-channel change anywhere in the deck.
3. **It is why `pipKnockoutWeight` must stay 1.0.** A ring that scaled with Bold Text would eat further into the frost tip at exactly the sizes where the overlap is deepest.

If `pipRadius`, the index length or the `0.43·S` register offset ever move, this is the first thing to re-measure.

### The one `Glyph.Hue → HueColor` mapping in the app

`Tokens` is a leaf with **no dependencies** and deliberately does not import `Glyphs`, even though `Palette.Hue` mirrors `Glyph.Hue`'s four cases. The mapping is one four-arm `switch` owned by exactly one function, here:

```swift
extension Palette.Hue {
    /// The one `Glyph.Hue → HueColor` mapping in the app. `Tokens` is a leaf target and
    /// does not import `Glyphs`; this is the switch that buys that, and it lives here
    /// because `HunchUI` already imports both (tokens-swift-layout.md §4).
    public subscript(_ hue: Glyph.Hue) -> HueColor {
        switch hue {
        case .amber: amber
        case .teal: teal
        case .frost: frost
        case .rose: rose
        }
    }
}
```

A glyph is **monochrome in its own hue**: body stroke, texture, pip nodes and index stroke all take `env.palette.hue[glyph.hue]` — or `stroke.primary` under High Contrast, which `Palette` already substitutes, so the renderer never branches on theme for colour. One colour per glyph is what makes fill density a pure ink-coverage signal, independent of which hue is showing.

The knockout takes `env.palette.ground.base`. Not `ground.sunken`, not the host's backdrop: the node must knock out to the room, and the throat's vignette and the Codex page's `ground.raised` are the host's business.

### RTL — the half this task owns

`GlyphRenderer` takes `(glyph, side, RenderEnv)` **and nothing else**. There is no `layout: LayoutDirection` parameter, and that absence is the specification: layout mirrors, glyphs never do. The pip ray table is fixed in the screen frame, the accretion order is fixed N → E → S → W, and both are game state — a mirrored ray table would move the E and W nodes in Arabic, which is a different glyph, not a different reading direction (§2, §12.8). T04 adds the raster-level RTL identity test for the whole glyph; this task's guard is structural, and `/code-review` should reject any parameter that would let a caller mirror it.

### `CoverageMask` — the epic's rasteriser

One test-support file, used by T02, T03, T04, T05, T06 and T09. It reduces a rendered glyph to **one ink level per pixel**, normalised by that glyph's own resolved ink:

```swift
import CoreGraphics
import SwiftUI
import Glyphs
import Tokens
import HunchUI

/// A rasterised mark reduced to coverage: 0 = ground, 255 = full ink.
///
/// Normalising by the mark's **own** resolved ink is what makes this the adversarial
/// single-ink model of `triple-encoding-proof.md` §2: every hue renders at one level, so
/// a pair of glyphs differing only in `hue` gains no distance for free. If the deck
/// separates here it separates in every theme, in every dichromacy and for a monochromat.
struct CoverageMask: Sendable {
    let pixels: Int          // per side
    let scale: Double        // px per pt
    let samples: [UInt8]     // row-major, `pixels * pixels`

    /// Σ|Δcoverage| over the raster, in **pt²** — the unit T is stated in.
    func inkDifference(from other: CoverageMask) -> Double
    func coverage(atBodyOffset offset: CGPoint, side: Double, env: RenderEnv) -> Double
}

@MainActor
func coverageMask(
    _ glyph: Glyph, side: Double, scale: Double = 2,
    env: RenderEnv, layout: LayoutDirection = .leftToRight
) throws -> CoverageMask
```

Four decisions inside it, each of which makes the measurement harder rather than easier:

- **The frame is `1.32 · side` square** — `S · (0.5 + 0.16)` each way. Clipping to the S-box would cut the index-stroke tips, which are precisely the discriminating pixels for the `hue` channel, and the measurement would then flatter the deck. T05's `C.Glyph.bleed(side:in:)` must fit inside it; T06 asserts that it does.
- **The backdrop is opaque `env.palette.ground.base`**, because the knockout ring paints `ground` and a transparent backdrop would make it invisible.
- **Coverage is `(L(pixel) − L(ground)) / (L(ink) − L(ground))`, clamped to 0…1**, with `L` the sRGB relative luminance `RGB8` already computes for `check-tokens.swift`. In the light theme the keyline is darker than the hue and clamps to 1; that is correct — it is ink.
- **`ImageRenderer` with `.scale = 2`**, rendering `GlyphCanvas` inside a `Color(ground)` `ZStack` at a fixed frame, with `.environment(\.layoutDirection, layout)`. It is `@MainActor`, so every raster test is `@MainActor` too (`06 T9`).

Keep it in `Modules/Tests/HunchUITests/Support/`. It must never ship: it is test support for the `Modules` package and is not a target anything else names.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GlyphGeometryTests` green, including the two new pip cases.
- [ ] `xcodebuild test … -only-testing:HunchUITests/GlyphPipTests` green — four suites over all 16 shape × pips combinations.
- [ ] `grep -n 'pipKnockoutWeight' HunchCore/Sources/Tokens/C.swift` shows a `public static let` with no `env` parameter; `grep -rn 'weight(.thin)' Modules/Sources/HunchUI/GlyphCanvas.swift` returns nothing.
- [ ] `grep -n 'LayoutDirection' Modules/Sources/HunchUI/GlyphCanvas.swift` returns nothing — the renderer cannot be mirrored because it cannot be told about direction.
- [ ] `grep -rn 'case .amber' Modules/Sources/HunchUI/ HunchCore/Sources/ --include='*.swift' | wc -l` is 1 — one `Glyph.Hue` switch in the app.
- [ ] The knockout raster assertion holds at 96 pt: ink at the node, ground one ring-width out, body stroke beyond it.
- [ ] `bash Scripts/check-source-hygiene.sh` passes (checks 9 and 10 — no literal weight, no register laundering).
- [ ] Fast suite still under 10 s.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E04/T02: contour pips on the ray, N→E→S→W, with the 1 pt ground knockout"`

## Out of scope

- **The index stroke** — T04. This task writes the *comment* that fixes the draw order; T05 writes the order and the test that proves it.
- **Fill textures and the fill clip** — T03. A pip is drawn over whatever texture reached the contour, and the knockout is what separates them; the texture itself is T03's.
- **Pass B's halo** — T05. **Never widen the pips in the halo pass**: it raises measured ink coverage and compresses the rung the greyscale proof rests on.
- **The `GlyphCanvas` View, the bleed, the size regime** — T05.
- **The pairwise separation measurement that names `pips two ↔ three` as the floor** — T06.
- **VoiceOver's pip count in the glyph label** — E19·T02. `Glyph.Pips.count` ships from T01 for it; the label does not.
- **Ramp cells, ribbon tiles or anything that contains a glyph** — E08, E09 (`hunch-bench-instruments`).
