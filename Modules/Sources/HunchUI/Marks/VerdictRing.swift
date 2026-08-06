public import SwiftUI

public import Glyphs  // Verdict
public import Tokens  // RenderEnv, StrokeWeight, C

public enum VerdictRing {
    public enum Role: Hashable, Sendable { case transient, settled }

    public enum Day: Hashable, Sendable { case clean, fractured, failed, absent, awaiting, locked }

    public enum State: Hashable, Sendable {
        case admit
        case reject
        /// An adjacent repeat, drawn as ONE unit. Both verdicts, because §6.6 layer 4's whole
        /// point is the case where they DIFFER: same glyph, same context-free reading, two
        /// answers. A single `admitted: Bool` cannot say that, and the split ring is the game's
        /// clearest wordless statement of contextuality.
        case twin(first: Verdict, second: Verdict)
        case counterexample(loomAdmits: Bool)
        case restrike(count: Int)
        case day(Day)
    }

    /// Draws one verdict ring concentric with a glyph body.
    ///
    /// `centre` and `bodyRadius` come from `GlyphGeometry`; this function never derives them from a
    /// box side, because `0.37 · S` has exactly one home and it is not here.
    ///
    /// `progress` is the host's animation clock, 0 at the verdict frame and 1 at rest. It is ignored
    /// when `role` is `.settled`, which is also what a Reduce Motion host passes (§13.7.4).
    ///
    /// The context is taken by value: clip, opacity and transform are set on a local copy and do not
    /// escape to the caller.
    ///
    /// - Complexity: O(1) — at most six sub-paths.
    public static func draw(
        into context: GraphicsContext,
        centre: CGPoint,
        bodyRadius: CGFloat,
        state: State,
        role: Role = .settled,
        progress: Double = 1,
        env: RenderEnv
    ) {
        var ctx = context
        for ring in rings(
            for: state, role: role, progress: progress, bodyRadius: bodyRadius, env: env)
        {
            ctx.opacity = ring.ink
            ctx.stroke(
                arcs(centre: centre, ring: ring, env: env),
                with: .color(ring.accent.rgb.color),
                style: StrokeStyle(
                    lineWidth: ring.weight, lineCap: .butt, dash: ring.dash.map { CGFloat($0) })
            )
        }
        if case .reject = state, role == .transient {
            let r = bodyRadius * C.CancelHatch.slashOvershoot
            CancelHatch.draw(
                into: context,
                region: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r),
                variant: .slash,
                bounds: .ellipse,
                paint: .verdict,
                env: env
            )
        }
    }
}

extension VerdictRing {
    /// One stroked ring. Several states draw more than one — a twin draws a doubled ring, a
    /// counterexample draws two carrying opposite verdicts, a re-strike draws up to five.
    struct Ring {
        var radiusScale: Double
        var weight: Double
        var ink: Double
        var accent: AccentColor
        var dash: [Double] = []
        /// Degrees of gap, centred on due north. `0` is a closed ring. The SPLIT ring — half
        /// open, half closed on one drawing of one glyph — is §6.6's rendered contradiction.
        var gapDegrees: Double = 0
        var splitHalves: Bool = false
    }

    static func rings(
        for state: State, role: Role, progress: Double, bodyRadius: CGFloat, env: RenderEnv
    ) -> [Ring] {
        let brass = env.palette.accent.brass
        let cold = env.palette.accent.cold
        let body = env.weight(.body)
        let hair = env.weight(.bodySm)
        // Differentiate Without Colour doubles the reject gap (§13.11), which is the whole
        // reason the gap is a parameter rather than a constant.
        let rejectGap =
            env.isDifferentiateWithoutColorEnabled
            ? C.VerdictRing.rejectGapDegreesDifferentiated : C.VerdictRing.rejectGapDegrees
        // The expansion the throat's well is sized against. One home (`C.VerdictRing`), two
        // readings: admit expands to it, reject contracts from it.
        let expansion = C.VerdictRing.transientAdmitRadius

        switch state {
        case .admit:
            // Admit COMPLETES and blooms outward. Transient expands with progress; settled
            // sits at the body. Closed at every moment — closure is the channel.
            let scale = role == .transient ? 1.0 + (expansion - 1) * progress : 1.0
            let ink = role == .transient ? 1.0 - 0.6 * progress : 1.0
            return [Ring(radiusScale: scale, weight: body, ink: ink, accent: brass)]

        case .reject:
            // Reject CONTRACTS and BREAKS. The direction and the closure are the achromatic
            // signal; the cancel stroke is drawn by the caller.
            let scale = role == .transient ? expansion - (expansion - 1) * progress : 1.0
            return [
                Ring(
                    radiusScale: scale, weight: hair, ink: 1, accent: cold,
                    gapDegrees: rejectGap)
            ]

        case .twin(let first, let second):
            // A twin draws as ONE unit under a doubled ring, so it never reads as a fresh
            // discovery. When the two verdicts differ the ring draws SPLIT — one half open,
            // one half closed, on a single drawing of a single glyph (§6.6 layer 4).
            // Agreeing: one accent, one closure, read as a single reinforced verdict. Differing:
            // the outer ring is HALF open — 180°, not the reject gap — so the contradiction is a
            // shape rather than a colour, and the inner ring keeps the first verdict's accent.
            let differ = first != second
            let inner = first == .admit ? brass : cold
            let outer = second == .admit ? brass : cold
            return [
                Ring(radiusScale: 1.0, weight: body, ink: 1, accent: inner),
                Ring(
                    radiusScale: 1.16, weight: hair, ink: 1, accent: outer,
                    gapDegrees: differ ? 180 : (second == .admit ? 0 : rejectGap)),
            ]

        case .counterexample(let loomAdmits):
            // TWO rings, one glyph, opposite states. Inner is the declaration's verdict, outer
            // is the Loom's, and they carry DISTINCT DASH PATTERNS so the contradiction is
            // separable without colour and without memory (§13.11).
            return [
                Ring(
                    radiusScale: 1.0, weight: body, ink: 1,
                    accent: loomAdmits ? cold : brass, dash: [4, 3]),
                Ring(
                    radiusScale: 1.22, weight: body, ink: 1,
                    accent: loomAdmits ? brass : cold),
            ]

        case .restrike(let count):
            // Up to five concentric rings on the rim, then one filled ring meaning 5+.
            let n = min(count, 5)
            return (0..<n).map {
                Ring(radiusScale: 1.0 + 0.10 * Double($0), weight: hair, ink: 1, accent: brass)
            }

        case .day(let day):
            switch day {
            case .clean: return [Ring(radiusScale: 1, weight: body, ink: 1, accent: brass)]
            case .fractured:
                return [
                    Ring(
                        radiusScale: 1, weight: body, ink: 1, accent: brass,
                        gapDegrees: 18)
                ]
            case .failed:
                return [
                    Ring(
                        radiusScale: 1, weight: hair, ink: 1, accent: cold,
                        gapDegrees: rejectGap)
                ]
            case .absent:
                return [
                    Ring(
                        radiusScale: 1, weight: hair, ink: 1, accent: cold,
                        dash: [2, 3])
                ]
            case .awaiting: return [Ring(radiusScale: 1, weight: hair, ink: 0.55, accent: brass)]
            case .locked: return [Ring(radiusScale: 1, weight: body, ink: 1, accent: cold)]
            }
        }
    }

    /// A closed circle, or an arc with `gapDegrees` removed at due north. `splitHalves` draws
    /// the two semicircles separately so one can be open while the other is closed.
    static func arcs(centre: CGPoint, ring: Ring, env: RenderEnv) -> Path {
        var path = Path()
        let r = ring.radiusScale
        guard ring.gapDegrees > 0 else {
            path.addEllipse(
                in: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
            return path
        }
        let half = ring.gapDegrees / 2
        path.addArc(
            center: centre, radius: r,
            startAngle: .degrees(-90 + half), endAngle: .degrees(270 - half),
            clockwise: false)
        return path
    }
}
