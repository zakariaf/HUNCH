/// **L1 type.** Seven roles, §13.4 verbatim. Tracking is stored in **em** and applied
/// as `scaledSize × trackingEm`; fixed-point tracking collapses at AX5.
public struct TypeRole: Hashable, Sendable {
    public enum Face: Hashable, Sendable { case sans, mono }
    public enum Width: Hashable, Sendable { case standard, condensed }

    public enum Weight: Int, Comparable, Hashable, Sendable {
        case regular, medium, semibold, bold

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Bold Text steps one notch and clamps at `bold` (§13.11).
        public var bolder: Weight { Weight(rawValue: rawValue + 1) ?? .bold }
    }

    /// The Dynamic Type style the role declares `relativeTo:` (§13.4).
    public enum TextStyle: Hashable, Sendable {
        case largeTitle, title2, subheadline, body, footnote, caption, caption2
    }

    public let size: Double
    public let weight: Weight
    public let width: Width
    public let trackingEm: Double
    public let face: Face
    public let textStyle: TextStyle
    /// Uppercased through `String.uppercased(with: locale)` — never a display transform
    /// and never the font's small-caps feature.
    public let isUppercased: Bool

    public func resolved(in env: RenderEnv) -> TypeRole {
        guard env.isBoldTextEnabled else { return self }
        return TypeRole(
            size: size, weight: weight.bolder, width: width, trackingEm: trackingEm,
            face: face, textStyle: textStyle, isUppercased: isUppercased)
    }

    /// Tracking in points, for a size already scaled by Dynamic Type.
    public func tracking(atScaledSize scaledSize: Double) -> Double { scaledSize * trackingEm }
}

extension TypeRole {
    public static let display = TypeRole(
        size: 28, weight: .semibold, width: .condensed, trackingEm: 0.06,
        face: .sans, textStyle: .largeTitle, isUppercased: false)
    public static let title = TypeRole(
        size: 20, weight: .semibold, width: .condensed, trackingEm: 0.08,
        face: .sans, textStyle: .title2, isUppercased: false)
    public static let section = TypeRole(
        size: 13, weight: .medium, width: .condensed, trackingEm: 0.14,
        face: .sans, textStyle: .caption, isUppercased: true)
    public static let body = TypeRole(
        size: 17, weight: .regular, width: .standard, trackingEm: 0,
        face: .sans, textStyle: .body, isUppercased: false)
    public static let caption = TypeRole(
        size: 13, weight: .regular, width: .standard, trackingEm: 0.01,
        face: .sans, textStyle: .footnote, isUppercased: false)
    /// Every number, always. SF Mono, `monospacedDigit`.
    public static let numeral = TypeRole(
        size: 15, weight: .regular, width: .standard, trackingEm: 0,
        face: .mono, textStyle: .subheadline, isUppercased: false)
    public static let micro = TypeRole(
        size: 11, weight: .medium, width: .condensed, trackingEm: 0.16,
        face: .sans, textStyle: .caption2, isUppercased: true)
}
