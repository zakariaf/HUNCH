public import SwiftUI

public import Tokens

public enum LinkArc {
    public enum Kind: Hashable, Sendable {
        case arc
        /// A row wrap. `drop` is the vertical distance to the next row's attachment point.
        case elbow(drop: CGFloat)
    }

    public enum Role: Hashable, Sendable { case structural, depictive }

    /// Joins two attachment points, asserting that they are adjacent in the chain.
    ///
    /// `a` and `b` are points, never tile indices: the same mark joins two ribbon tiles 6 pt apart and
    /// two 96 pt counterexample glyphs, and a grid-aware signature would fit only the first.
    ///
    /// `progress` trims the path for the 120 ms draw-on of §6.5's 260–420 ms window; a Reduce Motion
    /// host passes 1 and crossfades instead (§13.7.4, "ribbon tile slide-in").
    ///
    /// The context is taken by value; the opacity set here does not escape to the caller.
    ///
    /// - Complexity: O(1) — one sub-path.
    public static func draw(
        into context: GraphicsContext,
        from a: CGPoint,
        to b: CGPoint,
        kind: Kind = .arc,
        role: Role = .structural,
        progress: Double = 1,
        opacity: Double = 1,
        env: RenderEnv
    ) {
        guard progress > 0 else { return }
        var ctx = context
        ctx.opacity = opacity

        let ink =
            role == .structural
            ? env.palette.stroke.hairline
            : env.palette.stroke.secondary

        ctx.stroke(
            path(from: a, to: b, kind: kind).trimmedPath(from: 0, to: progress),
            with: .color(ink.color),
            style: StrokeStyle(lineWidth: env.weight(.thin), lineCap: .round, lineJoin: .round)
        )
    }
}

extension LinkArc {
    /// The geometry. An `.arc` bows toward the reading direction by a fixed fraction of the
    /// span, so adjacency reads as a chain rather than as two tiles that happen to touch; a
    /// `.returnElbow` is the wrap at a row end, which must not be mistaken for adjacency and
    /// therefore turns a corner instead of bowing.
    static func path(from a: CGPoint, to b: CGPoint, kind: Kind) -> Path {
        var path = Path()
        path.move(to: a)
        switch kind {
        case .arc:
            let dx = b.x - a.x
            let dy = b.y - a.y
            // Bow perpendicular to the span. 0.18 reproduces the PHOSPHOR ribbon at a 50 pt
            // pitch and stays legible down to the sheet's 45 pt cell.
            let bow = 0.18
            let control = CGPoint(x: a.x + dx / 2 - dy * bow, y: a.y + dy / 2 + dx * bow)
            path.addQuadCurve(to: b, control: control)
        case .elbow(let drop):
            // A row wrap: down, across, down. Right-angled and never a curve, because a wrap
            // must NOT read as adjacency — the arc is what means "these two are neighbours".
            let mid = a.y + drop / 2
            path.addLine(to: CGPoint(x: a.x, y: mid))
            path.addLine(to: CGPoint(x: b.x, y: mid))
            path.addLine(to: b)
        }
        return path
    }
}
