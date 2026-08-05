# geometry.md — the coordinate frame, `C.Glyph`, and the compiling renderer

Contents: [1 The frame](#1-the-frame-and-why-1355-cannot-be-read-literally) ·
[2 `C.Glyph`](#2-cglyph--the-l2-members-this-skill-owns) ·
[3 `shape`](#3-shape--the-silhouette) · [4 The Swift](#4-the-swift) ·
[5 `pips`](#5-pips--contour-nodes) · [6 The bleed](#6-the-bleed) ·
[7 `hue`](#7-hue--the-index-stroke) · [8 Testing it](#8-testing-it) ·
[9 What would be wrong](#9-what-would-be-wrong)

Everything in §4 typechecks under `swiftc -swift-version 6 -strict-concurrency=complete`
against SwiftUI on Swift 6.3.3, and every derived value in §2 was compared digit-for-digit
against `reference-renderer.js` at S = 24 / 36 / 44 / 48 / 52 / 96 / 220 × {dark, High
Contrast} × {normal, Bold Text}. Paste it as-is.

---

## 1. The frame, and why §13.5 cannot be read literally

**Screen coordinates. Origin at the centre of the S-box, +x trailing, +y down, angles
clockwise from East.**

GAME_DESIGN.md §13.5 is internally inconsistent, and the inconsistency is invisible until
something renders. It states *positions* in a y-up frame and *angles* in the screen frame:

| §13.5 says | Reading it y-up gives | Reading it y-down gives |
|---|---|---|
| `bodyCentre = (0, +0.10·S)` | body sits above the box centre | body sits below the box centre |
| index register at `y = −0.43·S`, "**below** the body" | index sits **above** the body — contradiction | index sits below the body ✓ |
| triangle vertices at `−90°, +30°, +150°` ("apex up") | apex points **down** — contradiction | apex points up ✓ |
| pip rays `θ = {−90° N, 0° E, +90° S, 180° W}` | N lands at the **bottom** — contradiction | N lands at the top ✓ |

Three of the four sentences are false under the y-up reading and all four are true under
the y-down reading with every stated y negated. So:

```
bodyCentre  = (0, −0.10 · S)        §13.5's +0.10·S, negated
indexCentre = (0, +0.43 · S)        §13.5's −0.43·S, negated
angles       unchanged              they were already screen-frame
```

`DIRECTION-A-PHOSPHOR.md` §5 reached the same resolution independently, which is the
strongest evidence available that it is the intended reading rather than a convenience.

**This costs nothing in Swift.** `Path`, `GraphicsContext` and `CGRect` are all y-down
already, so the negation happens once, in `C.Glyph.centreOffset(side:)`, and no drawing
code ever thinks about it again. The only place the y-up numbers may appear is in a
comment citing §13.5.

**A glyph is monochrome in its own hue.** Body stroke, texture, pip nodes and index
stroke all take the same `HueColor` (`env.palette.hue[glyph.hue]`), or `stroke.primary`
under High Contrast — which the palette already substitutes, so the renderer never
branches on theme for colour. One colour per glyph is what makes fill density a pure
ink-coverage signal, independent of which hue is showing.

---

## 2. `C.Glyph` — the L2 members this skill owns

These append to the `C.Glyph` namespace in `HunchCore/Sources/Tokens/C.swift`.
`bodyStroke`, `keylineStroke` and `haloStroke` already ship there; the rest are new here.

**Nothing below is a colour, an opacity or a duration.** Every one is a ratio of `S`, a
count, or a call into `env.weight(_:)`. If a member of `C.Glyph` ever needs a hex or a
millisecond, it is in the wrong namespace — see `hunch-design-tokens`.

`C.Glyph` lives in the `Tokens` target, which is **a leaf with no dependencies**. That is
why `fillClipScale` takes a `cornerCount: Int` rather than a `Glyph.Shape`: importing the
`Glyphs` target into `Tokens` to spell one parameter would invert the dependency arrow and
cost `swift test` its host-testability.

```swift
public enum C {
    public enum Glyph {
        // ── Lengths, all ratios of the box side S (§13.5) ──────────────────
        public static func radius(side S: Double) -> Double { 0.37 * S }
        /// Signed y offset of `bodyCentre` from the box centre, **screen frame**.
        /// §13.5 writes `+0.10·S` in a y-up frame; this is that value negated.
        public static func centreOffset(side S: Double) -> Double { -0.10 * S }
        /// Signed y offset of the index register. §13.5's `−0.43·S`, negated.
        public static func indexCentreOffset(side S: Double) -> Double { 0.43 * S }
        /// High Contrast *substitutes* the longer stroke; it is never also scaled.
        public static func indexLength(side S: Double, in env: RenderEnv) -> Double {
            (env.theme == .highContrast ? 0.409 : 0.273) * S
        }
        public static func pitch(side S: Double) -> Double { max(5, 0.22 * radius(side: S)) }
        public static func dotRadius(side S: Double) -> Double { 0.25 * pitch(side: S) }
        public static func stripeWeight(side S: Double) -> Double { 0.386 * pitch(side: S) }
        public static func pipRadius(side S: Double) -> Double { max(3, 0.11 * radius(side: S)) }

        // ── Weights ────────────────────────────────────────────────────────
        public static func bodyStroke(side S: Double, in env: RenderEnv) -> Double {
            env.weight(S < 48 ? .bodySm : .body)
        }
        /// Never `bodySm`: the hue channel is the heaviest non-colour mark on the glyph.
        public static func indexStroke(in env: RenderEnv) -> Double { env.weight(.body) }
        public static func keylineStroke(side S: Double, in env: RenderEnv) -> Double? {
            guard env.palette.glyphKeyline != nil else { return nil }
            return bodyStroke(side: S, in: env) + 1.0
        }
        public static func haloStroke(side S: Double, in env: RenderEnv) -> Double {
            bodyStroke(side: S, in: env) * 3
        }
        public static func haloIndexStroke(in env: RenderEnv) -> Double { indexStroke(in: env) * 3 }
        /// A geometric separator, not a design weight: it opts out of Bold Text and of
        /// the High Contrast offset, because 1 pt is what keeps the node visible at all.
        public static let pipKnockoutWeight = 1.0

        // ── Derived regions ────────────────────────────────────────────────
        /// The fill clip is inset `1.5 × bodyWeight` from the silhouette centre-line,
        /// which is exactly the halo half-width — see bloom-and-squash.md §3.
        public static func fillInset(side S: Double, in env: RenderEnv) -> Double {
            1.5 * bodyStroke(side: S, in: env)
        }
        /// Scale factor about `bodyCentre` that turns the silhouette into the fill clip.
        /// Offsetting a regular polygon is a change of apothem, so this is exact.
        public static func fillClipScale(cornerCount n: Int, side S: Double, in env: RenderEnv) -> Double {
            let apothem = radius(side: S) * (n == 0 ? 1 : cos(.pi / Double(n)))
            return max(0, (apothem - fillInset(side: S, in: env)) / apothem)
        }

        // ── Bloom and layout ───────────────────────────────────────────────
        /// The `S >= 32` half of the bloom gate. The environment half is `env.isBloomEnabled`.
        public static func isBloomed(side S: Double, in env: RenderEnv) -> Bool {
            env.isBloomEnabled && S >= 32
        }
        /// How far outside the S-box the drawing reaches, per axis. The four terms are
        /// frost (90°), {teal, rose} (45°/135°), amber (0°) and the silhouette; §6
        /// derives them. A flat `0.08 · S` clips {teal, rose} for `32 <= S < 59.5` and
        /// clips frost under High Contrast at every size.
        public static func bleed(side S: Double, in env: RenderEnv) -> (x: Double, y: Double) {
            let bloomed = isBloomed(side: S, in: env)
            let halfIndex = (bloomed ? haloIndexStroke(in: env) : indexStroke(in: env)) / 2
            // A round halo join reaches half its width; a miter join on the triangle's
            // 60° corner reaches `(W/2) / sin 30°` = W, the worst of the four shapes.
            let bodyReach = bloomed ? haloStroke(side: S, in: env) / 2 : bodyStroke(side: S, in: env)
            let halfLength = indexLength(side: S, in: env) / 2
            let diagonal = 0.5.squareRoot()
            let register = indexCentreOffset(side: S)
            let y = max(
                register + halfLength,                              // frost, 90°
                register + (halfLength + halfIndex) * diagonal,     // teal and rose
                register + halfIndex,                               // amber, 0°
                0.47 * S + bodyReach)                               // the silhouette
            let x = max(
                halfLength,                                         // amber, 0°
                (halfLength + halfIndex) * diagonal,                // teal and rose
                halfIndex,                                          // frost, 90°
                radius(side: S) + bodyReach)                        // the silhouette
            return (x: max(0, x - S / 2), y: max(0, y - S / 2))
        }

        /// §13.5.1's shipped constant: the minimum pairwise ink difference over the deck,
        /// in pt² at S = 44. Measured, not asserted — `check-coverage-separation.js`.
        public static let minimumPairwiseInkDifference = 8.0
    }
}
```

Derived values at the sizes that actually ship, dark theme, no Bold Text:

| S | site | `R` | body W | index W | `indexLength` | `pitch` | `pipRadius` | `fillInset` | bloom |
|---|---|---|---|---|---|---|---|---|---|
| 36 | SIEVE tail, ECHO seed | 13.32 | 1.5 | 3.0 | 9.828 | 5.000 | 3.000 | 2.25 | on |
| 44 | ribbon tile, ECHO rail/primer, Codex thumb | 16.28 | 1.5 | 3.0 | 12.012 | 5.000 | 3.000 | 2.25 | on |
| 52 | ECHO tray | 19.24 | **3.0** | 3.0 | 14.196 | 5.000 | 3.000 | **4.50** | on |
| 72 | SIEVE lane | 26.64 | 3.0 | 3.0 | 19.656 | 5.861 | 3.000 | 4.50 | on |
| 96 | throat (SE) | 35.52 | 3.0 | 3.0 | 26.208 | 7.814 | 3.907 | 4.50 | on |
| 128 | throat (Pro Max, Frame) | 47.36 | 3.0 | 3.0 | 34.944 | 10.419 | 5.210 | 4.50 | on |
| 220 | Codex hero | 81.40 | 3.0 | 3.0 | 60.060 | 17.908 | 8.954 | 4.50 | on |

Note the two discontinuities at S = 48, both consequences of the regime switch and both
correct: the body weight doubles, and because `fillInset = 1.5 × bodyWeight` **the fill
region shrinks as the glyph grows** — inset radius 14.03 pt at S = 44, 13.26 pt at S = 48.
`fill-textures.md` §4 measures what that does to the ink ladder.

---

## 3. `shape` — the silhouette

Regular polygons inscribed in `R`, conventional orientation, **miter joins, zero radius,
butt caps, always** (§13.3). Corner count is the achromatic discriminator: rounding a
corner erodes the channel, which is why §13.1 makes it a PR-rejection offence.

| Value | Rank | Screen-frame vertex angles | Corners | Apothem | Where the N pip lands |
|---|---|---|---|---|---|
| `circle` | 1 | — | 0 | `R` | mid-arc |
| `triangle` | 2 | −90, +30, +150 | 3 | `R·cos 60° = 0.500·R` | on the apex vertex |
| `square` | 3 | −135, −45, +45, +135 | 4 | `R·cos 45° = 0.707·R` | mid-edge |
| `hexagon` | 4 | −90, −30, +30, +90, +150, +210 | 6 | `R·cos 30° = 0.866·R` | on a vertex |

The angles are listed ascending, which for all three polygons is also convex order — so
they can be walked straight into a `Path` with no sort and no winding check.

**Offsetting a regular polygon is a change of apothem, not a general polygon offset.**
That single fact does three jobs: it makes `fillClipScale` exact, it lets the reference
rasteriser model the miter-joined stroke band as the difference of two scaled polygons
rather than as a distance field, and it means a "shrink the silhouette by δ" operation
anywhere in the app is `radiusScale = (apothem − δ) / apothem`, never a `Path` inset.

---

## 4. The Swift

Two files: `GlyphShape.swift` (the silhouette as a `Shape`, reusable as a clip or a mask)
and `GlyphCanvas.swift` (the four passes). Both live in `Modules/Sources/HunchUI/`, per
`08-APPLIED-TO-HUNCH.md` §1.

`nonisolated` on both types is load-bearing: the UI targets take
`.defaultIsolation(MainActor.self)`, `Shape.path(in:)` is a nonisolated requirement, and
a `GlyphRenderer` that is pinned to the main actor cannot be exercised by a
`swift test` suite that has no main actor to run on.

```swift
// ───────────────────────── Modules/Sources/HunchUI/GlyphShape.swift ────
import SwiftUI
import HunchCore

nonisolated struct GlyphShape: SwiftUI.Shape {
    let shape: Glyph.Shape
    /// Scales `R` about `bodyCentre` only, never about the rect centre. `1` is the
    /// silhouette centre-line; the fill clip is the same polygon at another scale.
    var radiusScale: Double = 1

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.midY + C.Glyph.centreOffset(side: side))
        let radius = C.Glyph.radius(side: side) * radiusScale
        guard let angles = Self.vertexAngles(for: shape) else {
            return Path(ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
        }
        var path = Path()
        for (index, degrees) in angles.enumerated() {
            let point = Self.point(on: centre, radius: radius, degrees: degrees)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Screen-frame vertex angles, ascending — which for these four is also convex order.
    /// `nil` is the circle: a polygon with no vertices, corner count 0.
    static func vertexAngles(for shape: Glyph.Shape) -> [Double]? {
        switch shape {
        case .circle: nil
        case .triangle: [-90, 30, 150]
        case .square: [-135, -45, 45, 135]
        case .hexagon: [-90, -30, 30, 90, 150, 210]
        }
    }

    static func point(on centre: CGPoint, radius: Double, degrees: Double) -> CGPoint {
        let theta = degrees * .pi / 180
        return CGPoint(x: centre.x + radius * cos(theta), y: centre.y + radius * sin(theta))
    }
}
```

```swift
// ──────────────────────── Modules/Sources/HunchUI/GlyphCanvas.swift ────
import SwiftUI
import HunchCore

nonisolated struct GlyphRenderer {
    let glyph: Glyph
    let side: Double
    let env: RenderEnv

    private static let pipRays: [Double] = [-90, 0, 90, 180]   // N, E, S, W — progressive

    private static func indexRotation(_ hue: Glyph.Hue) -> Double {
        switch hue {
        case .amber: 0
        case .teal: 45
        case .frost: 90
        case .rose: 135
        }
    }

    /// Draws one glyph centred in `canvas`, in the four-pass order of
    /// DIRECTION-A-PHOSPHOR.md §2. Pass A, the blurred bed, is **not** here: it is one
    /// offscreen layer per glyph-bearing region and belongs to the region's view.
    func draw(into context: inout GraphicsContext, canvas: CGSize) {
        let box = CGRect(
            x: (canvas.width - side) / 2, y: (canvas.height - side) / 2,
            width: side, height: side)
        let bodyCentre = CGPoint(x: box.midX, y: box.midY + C.Glyph.centreOffset(side: side))
        let ink = GraphicsContext.Shading.color(env.palette.hue[glyph.hue].color)
        let ground = GraphicsContext.Shading.color(env.palette.ground.base.color)
        let silhouette = GlyphShape(shape: glyph.shape).path(in: box)
        let index = indexPath(bodyCentre: bodyCentre)
        let bodyWeight = C.Glyph.bodyStroke(side: side, in: env)

        // PASS B — halo. Body outline and index stroke only: widening the texture or the
        // pips would raise measured ink coverage and compress the `fill` ladder.
        if C.Glyph.isBloomed(side: side, in: env) {
            var halo = context
            halo.opacity = Opacity.halo
            halo.stroke(silhouette, with: ink, style: StrokeStyle(
                lineWidth: C.Glyph.haloStroke(side: side, in: env), lineJoin: .round))
            halo.stroke(index, with: ink, style: StrokeStyle(
                lineWidth: C.Glyph.haloIndexStroke(in: env), lineCap: .butt))
        }

        // PASS C — texture, then the light-theme keyline, then the silhouette.
        drawTexture(into: &context, box: box, bodyCentre: bodyCentre, ink: ink)
        if let keylineWeight = C.Glyph.keylineStroke(side: side, in: env),
           let keyline = env.palette.glyphKeyline {
            context.stroke(silhouette, with: .color(keyline.color), style: StrokeStyle(
                lineWidth: keylineWeight, lineJoin: .miter, miterLimit: 10))
        }
        context.stroke(silhouette, with: ink, style: StrokeStyle(
            lineWidth: bodyWeight, lineJoin: .miter, miterLimit: 10))

        // PASS D — pip nodes and their knockout ring, so a node separates from the
        // silhouette stroke and from texture reaching the contour.
        let pipRadius = C.Glyph.pipRadius(side: side)
        for ray in Self.pipRays.prefix(glyph.pips.count) {
            let node = contourHit(degrees: ray, bodyCentre: bodyCentre)
            let knockout = Path(ellipseIn: CGRect(
                x: node.x - pipRadius - 0.5, y: node.y - pipRadius - 0.5,
                width: 2 * pipRadius + 1, height: 2 * pipRadius + 1))
            context.stroke(knockout, with: ground, lineWidth: C.Glyph.pipKnockoutWeight)
            context.fill(Path(ellipseIn: CGRect(
                x: node.x - pipRadius, y: node.y - pipRadius,
                width: 2 * pipRadius, height: 2 * pipRadius)), with: ink)
        }

        // The index stroke is last and is never knocked out: it is the hue channel, and
        // it OVERLAPS the S node — frost's tip lands inside the pip disc on circle and
        // hexagon at every size. Knock out first, ink the hue last. See §5.1.
        context.stroke(index, with: ink, style: StrokeStyle(
            lineWidth: C.Glyph.indexStroke(in: env), lineCap: .butt))
    }

    private func indexPath(bodyCentre: CGPoint) -> Path {
        // The index register is positioned from the BOX centre, not from `bodyCentre`.
        let centre = CGPoint(
            x: bodyCentre.x,
            y: bodyCentre.y - C.Glyph.centreOffset(side: side) + C.Glyph.indexCentreOffset(side: side))
        let theta = Self.indexRotation(glyph.hue) * .pi / 180
        let half = C.Glyph.indexLength(side: side, in: env) / 2
        let delta = CGPoint(x: cos(theta) * half, y: sin(theta) * half)
        var path = Path()
        path.move(to: CGPoint(x: centre.x - delta.x, y: centre.y - delta.y))
        path.addLine(to: CGPoint(x: centre.x + delta.x, y: centre.y + delta.y))
        return path
    }

    /// Where the ray from `bodyCentre` at `degrees` meets the silhouette centre-line.
    /// On `triangle` and `hexagon` the N node lands on a vertex, on `square` and
    /// `circle` mid-edge; both are distinct silhouette bumps (§13.5).
    private func contourHit(degrees: Double, bodyCentre: CGPoint) -> CGPoint {
        let theta = degrees * .pi / 180
        let direction = CGPoint(x: cos(theta), y: sin(theta))
        let radius = C.Glyph.radius(side: side)
        let corners = glyph.shape.cornerCount
        guard corners > 0, let angles = GlyphShape.vertexAngles(for: glyph.shape) else {
            return CGPoint(x: bodyCentre.x + direction.x * radius, y: bodyCentre.y + direction.y * radius)
        }
        let apothem = radius * cos(.pi / Double(corners))
        var distance = Double.infinity
        for vertex in angles {
            let normal = (vertex + 180 / Double(corners)) * .pi / 180
            let projection = direction.x * cos(normal) + direction.y * sin(normal)
            if projection > 1e-9 { distance = min(distance, apothem / projection) }
        }
        return CGPoint(x: bodyCentre.x + direction.x * distance, y: bodyCentre.y + direction.y * distance)
    }

    private func drawTexture(
        into context: inout GraphicsContext, box: CGRect, bodyCentre: CGPoint,
        ink: GraphicsContext.Shading
    ) {
        guard glyph.fill != .hollow else { return }
        let scale = C.Glyph.fillClipScale(cornerCount: glyph.shape.cornerCount, side: side, in: env)
        let clip = GlyphShape(shape: glyph.shape, radiusScale: scale).path(in: box)
        if glyph.fill == .solid {
            context.fill(clip, with: ink)
            return
        }
        var interior = context
        interior.clip(to: clip)
        let reach = C.Glyph.radius(side: side)
        let pitch = C.Glyph.pitch(side: side)

        if glyph.fill == .dotted {
            // Hex packing anchored at `bodyCentre`, never at the clip's bounding box: a
            // lattice phased off a loop start moves with R and stops being a token.
            let dotRadius = C.Glyph.dotRadius(side: side)
            let rowHeight = pitch * (3.0 as Double).squareRoot() / 2
            var dots = Path()
            let rows = Int((reach / rowHeight).rounded(.up)) + 1
            let columns = Int((reach / pitch).rounded(.up)) + 1
            for row in -rows...rows {
                let y = bodyCentre.y + Double(row) * rowHeight
                let offset = row.isMultiple(of: 2) ? 0 : pitch / 2
                for column in -columns...columns {
                    let x = bodyCentre.x + offset + Double(column) * pitch
                    dots.addEllipse(in: CGRect(
                        x: x - dotRadius, y: y - dotRadius,
                        width: 2 * dotRadius, height: 2 * dotRadius))
                }
            }
            interior.fill(dots, with: ink)
        } else {
            // Parallel lines at +45° in the screen frame, anchored at `bodyCentre`.
            let axis = CGPoint(x: 0.5.squareRoot(), y: 0.5.squareRoot())
            let normal = CGPoint(x: -axis.y, y: axis.x)
            var stripes = Path()
            let count = Int((2 * reach / pitch).rounded(.up)) + 1
            for step in -count...count {
                let offset = Double(step) * pitch
                let anchor = CGPoint(
                    x: bodyCentre.x + normal.x * offset, y: bodyCentre.y + normal.y * offset)
                stripes.move(to: CGPoint(
                    x: anchor.x - axis.x * 2 * reach, y: anchor.y - axis.y * 2 * reach))
                stripes.addLine(to: CGPoint(
                    x: anchor.x + axis.x * 2 * reach, y: anchor.y + axis.y * 2 * reach))
            }
            interior.stroke(stripes, with: ink, style: StrokeStyle(
                lineWidth: C.Glyph.stripeWeight(side: side), lineCap: .butt))
        }
    }
}

/// A glyph as a view. It is a **picture**: it declares no accessibility of its own, so a
/// ramp of four does not put four unlabelled elements in the rotor. The host names it
/// (§13.10) — see `hunch-accessibility` for the element table.
struct GlyphCanvas: View {
    let glyph: Glyph
    let side: Double
    let env: RenderEnv

    var body: some View {
        let bleed = C.Glyph.bleed(side: side, in: env)
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            GlyphRenderer(glyph: glyph, side: side, env: env).draw(into: &context, canvas: size)
        }
        .frame(width: side + 2 * bleed.x, height: side + 2 * bleed.y)
        .accessibilityHidden(true)
    }
}
```

Two members this assumes live in the `Glyphs` target beside `Glyph` itself, because both
are model facts rather than drawing facts and both are wanted by tests and by VoiceOver:

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

---

## 5. `pips` — contour nodes

Node `k` sits **where the ray from `bodyCentre` at θ_k meets the silhouette centre-line**,
θ = {−90° N, 0° E, +90° S, 180° W}, filled progressively N → E → S → W (§2, §13.5). The
progression is what makes the count pre-attentive: `three` is `two` plus a node, so the
four states are nested silhouettes rather than four arrangements to be counted.

`contourHit` uses the support-function form of ray/convex intersection —
`t = min over edge normals with d·n > 0 of apothem / (d·n)` — rather than looping over
segments. It is branch-free per edge, exact, and it reuses the same apothem the fill clip
and the stroke band already use. A segment-intersection version has to handle the
degenerate case where the ray passes exactly through a vertex, which is not hypothetical:
on `triangle` and `hexagon` the N ray does exactly that.

**The knockout is a stroke, not a second fill.** `strokeDisc(r: pipRadius + 0.5, w: 1)`
paints `ground` over the annulus `pipRadius … pipRadius + 1`, and the hue disc of exactly
`pipRadius` is then filled inside it. Drawing a `ground` disc of `pipRadius + 1` and a hue
disc of `pipRadius` would give the same picture and would erase the body stroke under the
node as well, which is what the ring exists to preserve.

`pipKnockoutWeight` is 1.0 and **opts out of Bold Text and of the High Contrast offset**.
It is not a design weight; it is the separation that keeps the node from merging into the
silhouette. At S = 36 the node is `pipRadius` 3.0 against a `bodySm` 1.5 stroke, so a ring
that grew to 1.25 or 1.5 pt would take a fifth of the node's visible area.

### 5.1 The S node and the index stroke overlap, and that fixes the draw order

The S ray at +90° and the index register are the two closest things on the glyph, and on
two of the four shapes they intersect. The S node sits at `y = −0.10·S + t`, where `t` is
the ray's reach:

| shape | S-ray reach | S node `y` | why |
|---|---|---|---|
| `circle` | `R` | `0.270·S` | — |
| `hexagon` | `R` | `0.270·S` | the hexagon **has a vertex at +90°**, so the ray hits it, not an edge |
| `square` | `0.7071·R` | `0.162·S` | mid-edge |
| `triangle` | `0.5·R` | `0.085·S` | mid-edge, and the apothem is only half `R` |

`frost`'s stroke runs vertically, so its **upper tip (smaller y) sits at
`0.43·S − 0.1365·S = 0.2935·S`, i.e. `0.0235·S` below the S node at `0.270·S` in the screen frame**
(§1: +y down, so "below" means *larger y*, and the upper tip is the one nearer the top of the box).
Its lower tip is at `0.43·S + 0.1365·S = 0.5665·S`, which is the number §6's bleed table uses.
Distance from the node centre to the nearest butt corner of the index stroke, dark theme:

| S | `pipRadius` | ring | `amber` | `teal` / `rose` | `frost` |
|---|---|---|---|---|---|
| 36 | 3.00 | 4.00 | 6.50 | **2.71 in the disc** | **1.72 in the disc** |
| 44 | 3.00 | 4.00 | 8.17 | **3.63 in the ring** | **1.82 in the disc** |
| 48 | 3.00 | 4.00 | 9.01 | 4.09 clear | **1.88 in the disc** |
| 96 | 3.91 | 4.91 | 19.07 | 9.63 clear | **2.71 in the disc** |

(`triangle` and `square` are clear at every size and every hue — their S node is far up
inside the box.)

**Three consequences, all of them load-bearing.**

1. **The draw order is forced.** Pass D's `ground` knockout ring must run *before* the
   index stroke, or it cuts a notch out of the hue channel on every `circle` and `hexagon`
   glyph with three or four pips and a frost index. The index stroke is drawn last for this
   reason and no other.
2. **It is why `pips two ↔ three` is the deck's floor.** Adding the S node to a
   circle-or-hexagon frost glyph adds the least *new* ink of any single-channel change,
   because the index stroke already inked that area. `triple-encoding-proof.md` §3.
3. **It is why the pip knockout must stay 1.0 pt.** A ring that scaled with Bold Text would
   eat further into the frost tip at exactly the sizes where the overlap is deepest.

This is a tension in the design, not a defect: the measured floor is still 12 % clear of T
in the worst environment. But it is the first thing to re-measure if `pipRadius`, the index
length, or `0.43·S` ever move.

---

## 6. The bleed

**The drawing overflows the S-box on the y axis at every size, and never on the x axis.**
`bleed(side:in:)` returns both anyway, because a caller that pads only y is one High
Contrast change away from being wrong.

The four terms, from the stroke rectangle's corners at `(±L/2 along u) ± (halfIndex along
n)` where `u` is the index rotation and `n` its normal:

| Hue | rotation | max \|y\| | max \|x\| |
|---|---|---|---|
| `amber` | 0° | `0.43·S + halfIndex` | `L/2` |
| `teal`, `rose` | 45°, 135° | `0.43·S + (L/2 + halfIndex)·√½` | `(L/2 + halfIndex)·√½` |
| `frost` | 90° | `0.43·S + L/2` | `halfIndex` |
| silhouette | — | `0.47·S + bodyReach` | `0.37·S + bodyReach` |

`halfIndex` is half the *drawn* index weight — `1.5 × indexWeight` when bloomed, else
`0.5 ×`. `bodyReach` is `1.5 × bodyWeight` for the round-joined halo, and `bodyWeight` for
the miter-joined ink, because a miter on the triangle's 60° corner reaches `(W/2)/sin 30°`
= `W`, the worst of the four shapes.

**PHOSPHOR §1.2's flat `bleed.glyph = 0.08·S` under-covers in two regimes.** Measured:

| S | dark, bloom on | `0.08·S` | High Contrast | `0.08·S` |
|---|---|---|---|---|
| 24 | 1.697 | 1.920 ✓ | 3.228 | 1.920 ✗ |
| 36 | **4.137** | 2.880 ✗ | 4.842 | 2.880 ✗ |
| 44 | **4.349** | 3.520 ✗ | 5.918 | 3.520 ✗ |
| 52 | **4.561** | 4.160 ✗ | 6.994 | 4.160 ✗ |
| 96 | 6.384 | 7.680 ✓ | 12.912 | 7.680 ✗ |
| 220 | 14.630 | 17.600 ✓ | 29.590 | 17.600 ✗ |

- **Dark and light, bloom on:** teal and rose govern, and `0.0265·S + 0.7071·halfIndex`
  exceeds `0.08·S` for `32 ≤ S < 59.5`. That band contains the ribbon tile, the ECHO rail,
  the ECHO primer and the Codex thumbnail at 44, the ECHO tray at 52, and the SIEVE tail
  and ECHO seed at 36 — five of the eight shipped sites.
- **High Contrast, every size:** the index stroke substitutes to `0.409·S`, so frost needs
  `0.1345·S`. At the throat that is 12.9 pt against 7.7; at the Codex hero, 29.6 against
  17.6. Clipping the tip of the *hue channel* under the setting that exists to make the
  hue channel readable is the worst version of this bug.

The consequence for layout is not just padding: a ribbon of 44 pt tiles laid out at 44 pt
pitch will have adjacent glyphs' index strokes overlap unless the tile pitch accounts for
the bleed, and `.clipped()` anywhere on the path from the tile to the `Canvas` will cut
the tip instead.

---

## 7. `hue` — the index stroke

One straight stroke of weight `weight.body`, centred at `(0, +0.43·S)`, length `0.273·S`
(High Contrast `0.409·S`), rotated by rank: `amber` 0°, `teal` 45°, `frost` 90°,
`rose` 135° (§13.5). At S = 44 those lengths are exactly canon's 12 / 18 pt.

Three properties, each of which is load-bearing and each of which is easy to lose:

1. **It never thins with the silhouette.** At S < 48 the body drops to `weight.bodySm` and
   the index stroke stays at `weight.body`, making it the heaviest non-colour mark on the
   glyph — deliberately, because it *is* the hue channel and colour is the redundant copy.
2. **Butt caps, so a 45° stroke has an honest length.** Round caps would add
   `indexWeight` to teal and rose and nothing to amber and frost, which would make the
   *length* of the stroke a fifth channel that nobody specified.
3. **A 135° sweep, not a cycle.** 0 → 45 → 90 → 135 is a total order the eye can rank;
   0 → 90 → 180 → 270 would make rank 1 and rank 4 the same line. This is why RTL mirrors
   layout and never mirrors a glyph: mirroring would swap `teal` and `rose` in Arabic,
   which is a change of game state, not of reading direction (§2).

The High Contrast lengthening is a **substitution** in the token skill's resolution order
— `0.409·S` terminates resolution and is never also scaled by Bold Text or offset by
`Prim.highContrastStrokeOffset`. That offset applies to the *weight*, which is a different
axis (`hunch-design-tokens/references/render-env.md` §2).

---

## 8. Testing it

Host-testable, no simulator, inside the 10-second `swift test` budget — `C.Glyph` is pure
arithmetic over `Double` and `RenderEnv`:

Three rules from `hunch-swift-testing` bind here and are easy to get wrong in a geometry suite:
**plain `import`, never `@testable`** (`06 T4` — every member below is already `public`);
**never `==` on two `Double`s**, so `isApproximatelyEqual` from `HunchTestSupport` carries every
comparison (`06 T42`, `08 §7.9`); and **no restated token values** — the assertions are stated as
*relations between resolved values*, so they still hold if `weight.body` or Bold Text's multiplier
ever moves.

```swift
import Testing
import Tokens
import HunchTestSupport

@Suite("C.Glyph arithmetic", .tags(.unit, .presubmission))
struct GlyphGeometryTests {
    @Test("The index stroke never thins with the silhouette",
          arguments: [24.0, 36, 44, 47.9, 48, 52, 96, 128, 220])
    func indexStrokeNeverThinsWithTheSilhouette(side: Double) {
        let env = RenderEnv()
        #expect(isApproximatelyEqual(C.Glyph.indexStroke(in: env), env.weight(.body),
                                     absoluteTolerance: 1e-9))
        if side < 48 {
            #expect(C.Glyph.bodyStroke(side: side, in: env) < C.Glyph.indexStroke(in: env))
        }
    }

    @Test("High Contrast substitutes the index LENGTH and never also scales it")
    func highContrastSubstitutesTheIndexLength() {
        let plainHC = RenderEnv(theme: .highContrast)
        let boldHC = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)
        // Substitution terminates resolution: Bold Text moves the weight and not the length.
        #expect(isApproximatelyEqual(C.Glyph.indexLength(side: 44, in: boldHC),
                                     C.Glyph.indexLength(side: 44, in: plainHC),
                                     absoluteTolerance: 1e-9))
        #expect(C.Glyph.indexStroke(in: boldHC) > C.Glyph.indexStroke(in: plainHC))
        #expect(isApproximatelyEqual(C.Glyph.indexStroke(in: boldHC), boldHC.weight(.body),
                                     absoluteTolerance: 1e-9))
    }

    @Test("A flat 8 % bleed is not enough", arguments: [36.0, 44, 52, 96, 220])
    func theFlatEightPercentBleedIsNotEnough(side: Double) {
        // Guards the regression, not the constant: if someone reintroduces `0.08 · S`,
        // this fails at every High Contrast size and at the three small dark ones.
        let hc = C.Glyph.bleed(side: side, in: RenderEnv(theme: .highContrast))
        #expect(hc.y > 0.08 * side)
        #expect(isApproximatelyEqual(hc.x, 0, absoluteTolerance: 1e-9))
    }
}
```

The raster-level claims — the deck's pairwise separation, the ink ladder, the bit-identical
monochrome mask — are not unit tests. They belong to the DEBUG snapshot gallery and to
`check-coverage-separation.js`; `triple-encoding-proof.md` §5 says what each one asserts
and where it runs.

---

## 9. What would be wrong

Each of these compiles, renders something plausible, and breaks a claim made elsewhere in the
library. They are ordered by how long they would survive review.

- **Reading §13.5's y values without negating them.** §1. Three of its four sentences become false,
  the triangle points down and the N pip lands at the bottom — and nothing errors, because every
  number is still in range. This is the defect the whole of §1 exists to prevent.
- **Writing "the lower tip" for the tip at `0.2935·S`, or any other sentence whose sign only makes
  sense y-up.** §5.1. Both halves of such a sentence can be individually true while the label
  contradicts the frame, which is the hardest kind of error to see.
- **Centring the glyph on the rect's centre instead of `bodyCentre`.** Every pip and the index
  register move together, so the drawing still looks like a glyph. It is a different glyph.
- **A literal in `C.Glyph`.** Every member is a ratio of `S`, a count, or a call into
  `env.weight(_:)`. A hex, an opacity or a millisecond there means the value is in the wrong
  namespace — `hunch-design-tokens` owns all three, and `check-source-hygiene.sh` check 9 fails on
  the first two.
- **Rounding a corner, or giving `radius.glyph` any value but zero.** Corner count *is* the `shape`
  channel (§3, `triple-encoding-proof.md` §6).
- **Drawing the index stroke before pass D's knockout ring.** §5.1: a `ground` ring cuts a notch out
  of the hue channel on every `circle`/`hexagon` glyph with three or four pips and a frost index —
  a quarter of the deck, and only in the one register the colourblind case rests on.
- **Scaling `pipKnockoutWeight` with Bold Text or the High Contrast offset.** §5. It is a geometric
  separator, not a design weight, and it eats the frost tip at exactly the sizes where the overlap is
  deepest.
- **Padding a layout with a flat `0.08 · S`, or with only the y component.** §6. It clips teal and
  rose for `32 ≤ S < 59.5` and clips frost under High Contrast at every size. `bleed(side:in:)`
  returns both axes precisely so a caller cannot pad one.
- **`.clipped()` anywhere between the host and the `Canvas`.** The tip is cut and nothing errors.
- **A segment-intersection `contourHit`.** The N ray passes exactly through a vertex on `triangle`
  and `hexagon`; the support-function form has no degenerate case to get wrong (§5).
- **Anchoring either lattice at the clip's bounding box.** `fill-textures.md` §5: the pattern then
  moves with `R`, and `fill` stops being a value.
- **`@testable import` or `==` on a `Double` in the suite above.** `06 T4`, `06 T42`. Both pass
  today and both are the reason a later refactor reports a failure the test cannot explain.
