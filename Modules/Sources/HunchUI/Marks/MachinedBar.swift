public import SwiftUI

public import Tokens

public enum MachinedBar {
    /// Draws the machined bar across a barred control.
    ///
    /// `key` is the control's frame in the host's coordinate space. `retraction` is 0 at rest and 1
    /// when the bar has cleared the trailing edge; reveal beat 0 drives it over 90 ms with
    /// `Easing.easeIn` (§13.7.1). The bar owns no clock.
    ///
    /// The context is taken by value; the clip set here does not escape to the caller.
    ///
    /// - Complexity: O(1) — one sub-path.
    public static func draw(
        into context: GraphicsContext,
        key: CGRect,
        retraction: Double = 0,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        guard retraction < 1 else { return }
        var ctx = context

        let overhang = C.MachinedBar.overhangRatio * key.width
        ctx.clip(to: Path(key.insetBy(dx: -overhang, dy: 0)))

        let travel = retraction * (key.width + 2 * overhang)
        let dx = layout == .rightToLeft ? travel : -travel  // trailing edge, either way
        var bar = Path()
        bar.move(to: CGPoint(x: key.minX - overhang - dx, y: key.midY))
        bar.addLine(to: CGPoint(x: key.maxX + overhang - dx, y: key.midY))

        ctx.stroke(
            bar,
            with: .color(env.palette.accent.cold.rgb.color),
            style: StrokeStyle(lineWidth: env.weight(.heavy), lineCap: .butt)
        )
    }
}
