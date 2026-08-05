public import SwiftUI

public import Tokens

public enum TickRow {
    public enum Mode: Hashable, Sendable {
        case count(filled: Int, total: Int)
        case crossed(total: Int)
        case cap(remaining: Int, total: Int)
        case silhouette(total: Int)
    }

    /// Draws one tick row, baseline-aligned to the bottom of `frame`.
    ///
    /// `nominalPitch` and `frame.width` are device geometry and come from the host (§6.2): pitch is
    /// `min(nominalPitch, frame.width / total)`, so the row's length stays proportional to `total`
    /// wherever that clamp does not engage — which is everywhere in PROBE and only at DRIFT band 8
    /// otherwise. That proportionality is §10.5's difficulty signal and is the row's whole job.
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(total).
    public static func draw(
        into context: GraphicsContext,
        frame: CGRect,
        mode: Mode,
        nominalPitch: CGFloat,
        layout: LayoutDirection = .leftToRight,
        env: RenderEnv
    ) {
        // `let`: `fill` is non-mutating and this mark sets nothing on the context, so a `var`
        // would be an unmutated variable — `03 W18`, and a Release build failure under
        // `-warnings-as-errors`.
        let ctx = context
        let shading = GraphicsContext.Shading.color(env.palette.stroke.secondary.color)
        let scale = env.artScale  // heights only — never the pitch, see §5
        for bar in bars(
            mode: mode, frame: frame, nominalPitch: nominalPitch,
            scale: scale, layout: layout)
        {
            ctx.fill(Path(bar), with: shading)
        }
    }
}

extension TickRow {
    /// The bars, baseline-aligned to the bottom of `frame`.
    ///
    /// The pitch clamp is §6.2's: `min(nominalPitch, frame.width / total)`. Where it does not
    /// engage — everywhere in PROBE — the row's LENGTH stays proportional to `total`, which is
    /// §10.5's only difficulty signal. `scale` moves heights and never the pitch: scaling the
    /// pitch would make the row longer at large Dynamic Type and turn the signal into a lie.
    static func bars(
        mode: Mode, frame: CGRect, nominalPitch: CGFloat,
        scale: Double, layout: LayoutDirection
    ) -> [CGRect] {
        let total: Int
        switch mode {
        case .count(_, let t), .crossed(let t), .cap(_, let t), .silhouette(let t): total = t
        }
        guard total > 0 else { return [] }

        let pitch = min(nominalPitch, frame.width / CGFloat(total))
        let width: CGFloat = 2  // the tick itself never scales with pitch
        let fullHeight = frame.height * scale
        let dimHeight = fullHeight * 0.45

        return (0..<total).map { index in
            let offset = CGFloat(index) * pitch
            let x =
                layout == .rightToLeft
                ? frame.maxX - offset - width
                : frame.minX + offset
            let height: CGFloat
            switch mode {
            case .count(let filled, _): height = index < filled ? fullHeight : dimHeight
            case .crossed: height = fullHeight  // the par crossing: the row reads as one rule
            case .cap(let remaining, _): height = index < remaining ? dimHeight : 0
            case .silhouette: height = dimHeight  // the unfilled reference row on a Codex page
            }
            return CGRect(x: x, y: frame.maxY - height, width: width, height: height)
        }
    }
}
