import SwiftUI

import Glyphs
import Tokens

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
            return Path(
                ellipseIn: CGRect(
                    x: centre.x - radius, y: centre.y - radius, width: 2 * radius,
                    height: 2 * radius))
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
