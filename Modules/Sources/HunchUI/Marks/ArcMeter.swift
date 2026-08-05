public import SwiftUI

public import Tokens

public enum ArcMeter {
    // Equatable, not Hashable: `custom(Path)` makes Hashable unsynthesizable, and nothing
    // keys a dictionary by a track.
    public enum Track: Equatable, Sendable {
        case ring(in: CGRect)
        case border(of: CGRect, cornerRadius: CGFloat)
        case custom(Path)
    }

    public enum Scale: Hashable, Sendable { case linear, logarithmic }

    public enum Style: Hashable, Sendable {
        case shelfFill, keyBorder, rollover, streak(accented: Bool), streamProgress
    }

    /// Draws a track and fills the leading `fraction` of it, clockwise from 12 o'clock.
    ///
    /// `value` and `total` are the raw counts; `scale` decides how they become a fraction, so a call
    /// site never computes a logarithm and the `|H| ≤ 512` rule (§11.2) is expressed once, here.
    ///
    /// The context is taken by value; nothing set here escapes to the caller.
    ///
    /// - Complexity: O(1), or O(24) for `.rollover`.
    public static func draw(
        into context: GraphicsContext,
        track: Track,
        value: Double,
        total: Double,
        scale: Scale = .linear,
        style: Style,
        env: RenderEnv
    ) {
        // `let`: `stroke` is non-mutating and this mark sets nothing on the context, so a `var`
        // would be an unmutated variable — `03 W18`, and a Release build failure under
        // `-warnings-as-errors`.
        let ctx = context
        let path = trackPath(track)
        let f = fraction(value: value, total: total, scale: scale, style: style)

        ctx.stroke(
            path,
            with: .color(env.palette.stroke.hairline.color),
            style: StrokeStyle(lineWidth: env.weight(.hairline), lineCap: .butt)
        )
        if case .logarithmic = scale {
            for notch in notches(on: path, total: total) {
                ctx.stroke(
                    notch,
                    with: .color(env.palette.stroke.secondary.color),
                    style: StrokeStyle(lineWidth: env.weight(.hairline), lineCap: .butt))
            }
        }
        guard f > 0 else { return }
        let shading = GraphicsContext.Shading.color(fillInk(style, in: env).color)
        let weight = fillWeight(style, in: env)
        for segment in segments(of: path, fraction: f, style: style) {
            ctx.stroke(
                segment, with: shading, style: StrokeStyle(lineWidth: weight, lineCap: .butt))
        }
    }
}

extension ArcMeter {
    static func trackPath(_ track: Track) -> Path {
        switch track {
        case .ring(let rect):
            var p = Path()
            p.addEllipse(in: rect)
            return p
        case .border(let rect, let radius):
            return Path(roundedRect: rect, cornerRadius: radius)
        case .custom(let path):
            return path
        }
    }

    /// `value` and `total` are raw counts; this is the only place a logarithm is taken, so the
    /// `|H| ≤ 512` rule (§11.2) — slot-map shelves fill linearly, accretion shelves fill on a
    /// log scale — is expressed once rather than at every call site.
    static func fraction(value: Double, total: Double, scale: Scale, style: Style) -> Double {
        guard total > 0, value > 0 else { return 0 }
        switch scale {
        case .linear:
            return min(1, value / total)
        case .logarithmic:
            return min(1, log2(1 + value) / log2(1 + total))
        }
    }

    /// The inscribed notches on a log-scaled shelf arc — §11.4's n ∈ {8, 32, 128, 512, …}.
    /// Without them a log fill is unreadable: the first eight pages and the next five hundred
    /// occupy similar arcs.
    static func notches(on path: Path, total: Double) -> [Path] {
        guard total > 0 else { return [] }
        let marks: [Double] = [8, 32, 128, 512, 2_048, 8_192].filter { $0 < total }
        return marks.compactMap { mark in
            let f = log2(1 + mark) / log2(1 + total)
            guard
                let point =
                    path.trimmedPath(from: max(0, f - 0.004), to: min(1, f + 0.004))
                        .cgPath.isEmpty
                    ? nil : path.trimmedPath(from: max(0, f - 0.004), to: min(1, f + 0.004))
            else { return nil }
            return point
        }
    }

    static func fillInk(_ style: Style, in env: RenderEnv) -> AccentColor {
        switch style {
        case .streak(let accented): accented ? env.palette.accent.brass : env.palette.accent.cold
        case .shelfFill, .keyBorder, .rollover, .streamProgress: env.palette.accent.brass
        }
    }

    static func fillWeight(_ style: Style, in env: RenderEnv) -> Double {
        switch style {
        case .keyBorder, .streamProgress: env.weight(.thin)
        case .shelfFill, .rollover, .streak: env.weight(.bodySm)
        }
    }

    /// `.rollover` is the Anomaly's 24-segment day arc — one segment per UTC hour, so the
    /// player can see how far into the day they are without a numeral. Everything else is one
    /// continuous trimmed run.
    static func segments(of path: Path, fraction f: Double, style: Style) -> [Path] {
        guard case .rollover = style else {
            return [path.trimmedPath(from: 0, to: f)]
        }
        let lit = Int((f * 24).rounded(.down))
        guard lit > 0 else { return [] }
        return (0..<lit).map { hour in
            let a = Double(hour) / 24 + 0.004
            let b = Double(hour + 1) / 24 - 0.004
            return path.trimmedPath(from: a, to: b)
        }
    }
}
