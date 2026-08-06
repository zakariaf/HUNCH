public import Foundation

public import Glyphs
public import Laws

/// §9.3's speed curve and §9.4's stream composition.
///
/// The rate ramps in **glyph index, not wall-clock**, so a run is reproducible from its seed and
/// unaffected by a dropped frame — which is the difference between a timed mode and a mode that
/// punishes a slow phone.
public struct SieveStream: Equatable, Sendable {

    /// §9.2: fixed at every speed, and the reason **at most one glyph is ever actionable**.
    public static let pitch = 132.0
    /// The gate's height; a glyph is actionable while its centre is within ±44 pt of the centre
    /// line, which is 88 pt of travel.
    public static let gateHeight = 88.0
    public static let previewDistance = 340.0

    public struct BandCurve: Equatable, Sendable {
        public let band: Band
        public let startRate: Double
        public let endRate: Double
        public let length: Int
        public let tell: Int
        public let body: Int
        public let runOut: Int
    }

    /// §9.3's table. **SIEVE serves law bands 1–6 only**: band 7 demands holding two conceptual
    /// layers and band 8 demands ruling out every simpler family first, and neither is learnable
    /// from a passive stream in 45 seconds. Ability above band 6 is absorbed by the **tempo
    /// step**, not by the law.
    public static let curves: [BandCurve] = [
        BandCurve(
            band: .literal, startRate: 1.00, endRate: 1.60, length: 60, tell: 12, body: 33,
            runOut: 15),
        BandCurve(
            band: .pair, startRate: 1.10, endRate: 1.75, length: 64, tell: 12, body: 36, runOut: 16),
        BandCurve(
            band: .exclusive, startRate: 1.20, endRate: 1.90, length: 68, tell: 12, body: 39,
            runOut: 17),
        BandCurve(
            band: .relational, startRate: 1.30, endRate: 2.05, length: 72, tell: 12, body: 42,
            runOut: 18),
        BandCurve(
            band: .contextual, startRate: 1.40, endRate: 2.20, length: 76, tell: 12, body: 45,
            runOut: 19),
        BandCurve(
            band: .guarded, startRate: 1.45, endRate: 2.35, length: 80, tell: 12, body: 48,
            runOut: 20),
    ]

    public static func curve(for band: Band) -> BandCurve? {
        curves.first { $0.band == band }
    }

    /// `s ∈ {0,1,2,3}` adds `0.20·s` to **both** ends of the ramp.
    public static let tempoStepRate = 0.20
    public static let tempoSteps = 0...3

    public let curve: BandCurve
    public let tempoStep: Int

    public init(curve: BandCurve, tempoStep: Int = 0) {
        self.curve = curve
        self.tempoStep = min(3, max(0, tempoStep))
    }

    public var startRate: Double { curve.startRate + SieveStream.tempoStepRate * Double(tempoStep) }
    public var endRate: Double { curve.endRate + SieveStream.tempoStepRate * Double(tempoStep) }

    /// `r(n) = r₀ + (r₁ − r₀) · n / N`, glyphs per second.
    public func rate(at index: Int) -> Double {
        startRate + (endRate - startRate) * Double(index) / Double(curve.length)
    }

    /// `window(n) = 88 / v(n) = 0.667 / r(n)`, seconds actionable.
    public func actionableWindow(at index: Int) -> Double {
        SieveStream.gateHeight / (rate(at: index) * SieveStream.pitch)
    }

    public func preview(at index: Int) -> Double {
        SieveStream.previewDistance / (rate(at: index) * SieveStream.pitch)
    }

    /// §9.4's three reaches, **defined by subtraction so they partition the stream exactly**.
    /// The body is the remainder and not a percentage: 12 + 0.60·N + 0.25·N equals N only at
    /// N = 80, so every band but 6 was over-subscribed — band 1 by three glyphs.
    public enum Reach: String, CaseIterable, Equatable, Sendable {
        case tell, body, runOut

        /// §9.6: a tell glyph is weighted half. The player cannot have learned the law yet.
        public var weight: Double { self == .tell ? 0.5 : 1.0 }
    }

    public func reach(at index: Int) -> Reach {
        if index < curve.tell { return .tell }
        if index < curve.tell + curve.body { return .body }
        return .runOut
    }

    /// **Fouls do not accrue during the tell.** A false positive in the first twelve still
    /// resolves visibly — that is how the player learns — but costs no foul. Punishing an
    /// unlearnable prefix would be dishonest.
    public func accruesFouls(at index: Int) -> Bool { reach(at: index) != .tell }
}
