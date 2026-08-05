public import SwiftUI

public import Tokens

public enum CancelHatch {
    public enum Variant: Hashable, Sendable { case hatch, slash }

    /// How the region is clipped. `.ellipse` makes the slash a diameter chord, which is what the
    /// transient reject ring needs.
    public enum Bounds: Hashable, Sendable { case rect, ellipse }

    /// Which register the mark draws in. A closed enum rather than a colour parameter, so a call site
    /// cannot reach `.rgb` on an `AccentColor` and launder a register (`check-source-hygiene.sh`
    /// check 10).
    public enum Paint: Hashable, Sendable { case chrome, verdict }

    /// Strikes a region as excluded.
    ///
    /// The −45° angle is fixed at every site and is exactly perpendicular to §13.5's `striped` fill, so
    /// the mark never disappears into a striped glyph. Coverage is held below `dotted`'s 22.7 % — see
    /// this file's §2 before changing `spacing` or the weight.
    ///
    /// The context is taken by value; the clip set here does not escape to the caller.
    ///
    /// - Complexity: O(region.width / spacing) for `.hatch`, O(1) for `.slash`.
    public static func draw(
        into context: GraphicsContext,
        region: CGRect,
        variant: Variant,
        bounds: Bounds = .rect,
        paint: Paint = .chrome,
        env: RenderEnv
    ) {
        var ctx = context
        ctx.clip(to: bounds == .ellipse ? Path(ellipseIn: region) : Path(region))

        let ink = paint == .chrome ? env.palette.stroke.secondary : env.palette.accent.cold.rgb
        let weight = C.Ramp.cancelHatchWeight(in: env)  // the substitution's one home
        let style = StrokeStyle(lineWidth: weight, lineCap: .butt)
        let shading = GraphicsContext.Shading.color(ink.color)

        for line in lines(in: region, variant: variant) {
            ctx.stroke(line, with: shading, style: style)
        }
    }
}

extension CancelHatch {
    /// Parallel lines at `C.CancelHatch.angleDegrees`, spaced perpendicular. The `.slash`
    /// variant is a single diameter chord with `slashOvershoot`, which is what an inert ramp
    /// and the transient reject ring both use.
    static func lines(in region: CGRect, variant: Variant) -> [Path] {
        let theta = C.CancelHatch.angleDegrees * .pi / 180
        let axis = CGPoint(x: cos(theta), y: sin(theta))
        let normal = CGPoint(x: -axis.y, y: axis.x)
        let centre = CGPoint(x: region.midX, y: region.midY)
        let reach = (region.width * region.width + region.height * region.height).squareRoot() / 2

        if variant == .slash {
            let half = reach * C.CancelHatch.slashOvershoot
            var path = Path()
            path.move(to: CGPoint(x: centre.x - axis.x * half, y: centre.y - axis.y * half))
            path.addLine(to: CGPoint(x: centre.x + axis.x * half, y: centre.y + axis.y * half))
            return [path]
        }

        let spacing = C.CancelHatch.spacing
        let steps = Int((reach / spacing).rounded(.up))
        return (-steps...steps).map { step in
            let offset = Double(step) * spacing
            let anchor = CGPoint(x: centre.x + normal.x * offset, y: centre.y + normal.y * offset)
            var path = Path()
            path.move(to: CGPoint(x: anchor.x - axis.x * reach, y: anchor.y - axis.y * reach))
            path.addLine(to: CGPoint(x: anchor.x + axis.x * reach, y: anchor.y + axis.y * reach))
            return path
        }
    }
}
