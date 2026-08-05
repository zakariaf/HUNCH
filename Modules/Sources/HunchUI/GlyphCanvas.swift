import SwiftUI

import Glyphs
import Tokens

nonisolated struct GlyphRenderer {
    let glyph: Glyph
    let side: Double
    let env: RenderEnv

    private static let pipRays: [Double] = [-90, 0, 90, 180]  // N, E, S, W — progressive

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
            halo.stroke(
                silhouette, with: ink,
                style: StrokeStyle(
                    lineWidth: C.Glyph.haloStroke(side: side, in: env), lineJoin: .round))
            halo.stroke(
                index, with: ink,
                style: StrokeStyle(
                    lineWidth: C.Glyph.haloIndexStroke(in: env), lineCap: .butt))
        }

        // PASS C — texture, then the light-theme keyline, then the silhouette.
        drawTexture(into: &context, box: box, bodyCentre: bodyCentre, ink: ink)
        if let keylineWeight = C.Glyph.keylineStroke(side: side, in: env),
            let keyline = env.palette.glyphKeyline
        {
            context.stroke(
                silhouette, with: .color(keyline.color),
                style: StrokeStyle(
                    lineWidth: keylineWeight, lineJoin: .miter, miterLimit: 10))
        }
        context.stroke(
            silhouette, with: ink,
            style: StrokeStyle(
                lineWidth: bodyWeight, lineJoin: .miter, miterLimit: 10))

        // PASS D — pip nodes and their knockout ring, so a node separates from the
        // silhouette stroke and from texture reaching the contour.
        let pipRadius = C.Glyph.pipRadius(side: side)
        for ray in Self.pipRays.prefix(glyph.pips.count) {
            let node = contourHit(degrees: ray, bodyCentre: bodyCentre)
            let knockout = Path(
                ellipseIn: CGRect(
                    x: node.x - pipRadius - 0.5, y: node.y - pipRadius - 0.5,
                    width: 2 * pipRadius + 1, height: 2 * pipRadius + 1))
            context.stroke(knockout, with: ground, lineWidth: C.Glyph.pipKnockoutWeight)
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: node.x - pipRadius, y: node.y - pipRadius,
                        width: 2 * pipRadius, height: 2 * pipRadius)), with: ink)
        }

        // The index stroke is last and is never knocked out: it is the hue channel, and
        // it OVERLAPS the S node — frost's tip lands inside the pip disc on circle and
        // hexagon at every size. Knock out first, ink the hue last. See §5.1.
        context.stroke(
            index, with: ink,
            style: StrokeStyle(
                lineWidth: C.Glyph.indexStroke(in: env), lineCap: .butt))
    }

    private func indexPath(bodyCentre: CGPoint) -> Path {
        // The index register is positioned from the BOX centre, not from `bodyCentre`.
        let centre = CGPoint(
            x: bodyCentre.x,
            y: bodyCentre.y - C.Glyph.centreOffset(side: side)
                + C.Glyph.indexCentreOffset(side: side))
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
            return CGPoint(
                x: bodyCentre.x + direction.x * radius, y: bodyCentre.y + direction.y * radius)
        }
        let apothem = radius * cos(.pi / Double(corners))
        var distance = Double.infinity
        for vertex in angles {
            let normal = (vertex + 180 / Double(corners)) * .pi / 180
            let projection = direction.x * cos(normal) + direction.y * sin(normal)
            if projection > 1e-9 { distance = min(distance, apothem / projection) }
        }
        return CGPoint(
            x: bodyCentre.x + direction.x * distance, y: bodyCentre.y + direction.y * distance)
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
                    dots.addEllipse(
                        in: CGRect(
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
                stripes.move(
                    to: CGPoint(
                        x: anchor.x - axis.x * 2 * reach, y: anchor.y - axis.y * 2 * reach))
                stripes.addLine(
                    to: CGPoint(
                        x: anchor.x + axis.x * 2 * reach, y: anchor.y + axis.y * 2 * reach))
            }
            interior.stroke(
                stripes, with: ink,
                style: StrokeStyle(
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
