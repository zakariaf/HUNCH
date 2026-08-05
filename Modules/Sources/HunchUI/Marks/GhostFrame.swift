public import SwiftUI

public import Tokens

public enum GhostFrame {
    /// Where this frame is being drawn. Present for the snapshot gallery and for call-site clarity;
    /// it deliberately does not change the geometry, because §4.2's diegetic claim depends on every
    /// site drawing the identical mark.
    public enum Role: Hashable, Sendable {
        case socket, marker, pin, seed, depictive
    }

    /// Draws the dashed hollow frame and its backward chevron.
    ///
    /// `box` is the glyph box being marked, in the host's coordinate space. `layout` decides which
    /// edge is leading: the chevron means *earlier in reading order*, so it mirrors under RTL while
    /// the glyph inside it does not (§2).
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(1) — two sub-paths.
    public static func draw(
        into context: GraphicsContext,
        box: CGRect,
        role: Role = .marker,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        // `let`, not `var`: `stroke` is non-mutating, so this mark sets nothing on the context at
        // all. A `var` here is an unmutated variable, and `03 W18` says fix that rather than
        // silence it — with `-warnings-as-errors` in Release it is a build failure (`07 B19`).
        let ctx = context
        let ink = GraphicsContext.Shading.color(env.palette.stroke.secondary.color)

        let frameWeight = env.weight(.thin)
        ctx.stroke(
            Path(box.insetBy(dx: frameWeight / 2, dy: frameWeight / 2)),
            with: ink,
            style: StrokeStyle(lineWidth: frameWeight, dash: C.GhostFrame.dash.map { CGFloat($0) })
        )

        let u = max(C.GhostFrame.chevronFloor, C.GhostFrame.chevronRatio * box.width)
        let mid = box.midY
        let x = { (offset: CGFloat) -> CGFloat in
            layout == .rightToLeft ? box.maxX - offset : box.minX + offset
        }
        var chevron = Path()
        chevron.move(to: CGPoint(x: x(2 * u), y: mid - u))
        chevron.addLine(to: CGPoint(x: x(u), y: mid))
        chevron.addLine(to: CGPoint(x: x(2 * u), y: mid + u))
        ctx.stroke(
            chevron,
            with: ink,
            style: StrokeStyle(lineWidth: env.weight(.bodySm), lineCap: .butt, lineJoin: .miter)
        )
    }
}
