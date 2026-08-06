public import SwiftUI

public import Glyphs
public import Tokens

/// The leading 44 pt of every ramp — the drawing canon names on five surfaces and never
/// specifies (`attribute-header.md` §1).
///
/// **The header is the attribute's whole ladder drawn at once, in its own register**, in
/// `stroke.secondary`. All four values present means no value is selected, which is why it
/// cannot compete with the four cells beside it, and it makes the header a *legend* for the row
/// rather than a symbol to memorise — §4.1's "there is no attribute emblem to learn", kept.
///
/// Four consequences, and together they satisfy pairwise distinctness by construction: the fill
/// header is the only one with interior ink, the shape header the only one with nested
/// outlines, the pips header the only one with unfilled discs, and the hue header the only one
/// below the body line.
@MainActor
public struct AttributeHeaderView: View {
    public var env: RenderEnv
    public var attribute: Glyph.Attribute

    public init(env: RenderEnv, attribute: Glyph.Attribute) {
        self.env = env
        self.attribute = attribute
    }

    public var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let box = CGRect(
                x: (size.width - side) / 2, y: (size.height - side) / 2,
                width: side, height: side)
            draw(into: context, box: box, side: side)
        }
        .accessibilityHidden(true)  // the ramp container carries the attribute's name (§13.10)
    }

    private func draw(into context: GraphicsContext, box: CGRect, side: Double) {
        // Chrome, never a `hue.*`: the header is a legend, not a glyph, and the token layer's
        // register segregation makes the wrong choice a compile error rather than a review note.
        let ink = GraphicsContext.Shading.color(env.palette.stroke.secondary.color)
        let hairline = StrokeStyle(lineWidth: env.weight(.hairline))
        let bodyCentre = CGPoint(x: box.midX, y: box.midY + C.Glyph.centreOffset(side: side))
        let radius = C.Glyph.radius(side: side)

        switch attribute {
        case .fill:
            // The body circle quartered by two diameters, the four sectors carrying
            // hollow · dotted · striped · solid in rank order, clockwise from the top-leading.
            let body = Path(
                ellipseIn: CGRect(
                    x: bodyCentre.x - radius, y: bodyCentre.y - radius,
                    width: 2 * radius, height: 2 * radius))
            context.stroke(body, with: ink, style: hairline)
            for degrees in [0.0, 90.0] {
                var diameter = Path()
                let radians = degrees * .pi / 180
                let dx = radius * cos(radians)
                let dy = radius * sin(radians)
                diameter.move(to: CGPoint(x: bodyCentre.x - dx, y: bodyCentre.y - dy))
                diameter.addLine(to: CGPoint(x: bodyCentre.x + dx, y: bodyCentre.y + dy))
                context.stroke(diameter, with: ink, style: hairline)
            }
            // Each sector drawn through the renderer's own texture pass, so the header cannot
            // depict a fill the glyph does not draw.
            for (index, fill) in Glyph.Fill.allCases.enumerated() {
                var wedge = context
                wedge.clip(to: sectorPath(centre: bodyCentre, radius: radius, quadrant: index))
                GlyphRenderer(
                    glyph: Glyph(fill: fill, shape: .circle, pips: .one, hue: .amber),
                    side: side, env: env
                )
                .draw(into: &wedge, canvas: box.size, registers: [.fill])
            }

        case .shape:
            // The four silhouettes concentric and inscribed, sharing `bodyCentre`.
            for (index, shape) in Glyph.Shape.allCases.enumerated() {
                let inset = side * 0.09 * Double(index)
                let inner = box.insetBy(dx: inset, dy: inset)
                context.stroke(
                    GlyphShape(shape: shape).path(in: inner), with: ink, style: hairline)
            }

        case .pips:
            // Four compass nodes as UNFILLED rings on a hairline contour, so all four positions
            // show and none is filled — no value is selected.
            var guideContext = context
            guideContext.opacity = C.AttributeHeader.contourGuideInk
            guideContext.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: bodyCentre.x - radius, y: bodyCentre.y - radius,
                        width: 2 * radius, height: 2 * radius)), with: ink, style: hairline)
            let pipRadius = C.Glyph.pipRadius(side: side)
            for degrees in [-90.0, 0, 90, 180] {
                let radians = degrees * .pi / 180
                let node = CGPoint(
                    x: bodyCentre.x + radius * cos(radians),
                    y: bodyCentre.y + radius * sin(radians))
                context.stroke(
                    Path(
                        ellipseIn: CGRect(
                            x: node.x - pipRadius, y: node.y - pipRadius,
                            width: 2 * pipRadius, height: 2 * pipRadius)), with: ink,
                    style: hairline)
            }

        case .hue:
            // A four-spoke fan through the index centre — the whole rotation ladder as one
            // rosette, and the only header below the body line.
            let centre = CGPoint(
                x: box.midX, y: box.midY + C.Glyph.indexCentreOffset(side: side))
            let length = C.AttributeHeader.hueSpokeRatio * side
            for degrees in C.AttributeHeader.hueSpokeDegrees {
                let radians = degrees * .pi / 180
                var spoke = Path()
                spoke.move(
                    to: CGPoint(
                        x: centre.x - length * cos(radians), y: centre.y - length * sin(radians)))
                spoke.addLine(
                    to: CGPoint(
                        x: centre.x + length * cos(radians), y: centre.y + length * sin(radians)))
                context.stroke(spoke, with: ink, style: hairline)
            }
        }
    }

    /// One quadrant of the body circle, clockwise from the top-leading.
    private func sectorPath(centre: CGPoint, radius: Double, quadrant: Int) -> Path {
        var path = Path()
        path.move(to: centre)
        path.addArc(
            center: centre, radius: radius,
            startAngle: .degrees(180 + 90 * Double(quadrant)),
            endAngle: .degrees(270 + 90 * Double(quadrant)), clockwise: false)
        path.closeSubpath()
        return path
    }

}
