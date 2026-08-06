public import Foundation

/// §9.6's scoring. Its shape carries one correction the design makes explicitly: **`ratio` is
/// normalised over resolved glyphs, not over all `N`.**
public enum SieveScoring {

    public enum Outcome: String, Hashable, Sendable {
        case hit
        case correctPass
        case miss
        case foul
    }

    public static func points(_ outcome: Outcome) -> Double {
        switch outcome {
        case .hit: 10
        case .correctPass: 3
        case .miss: 0
        case .foul: -8
        }
    }

    public struct Result: Equatable, Sendable {
        public let ratio: Double
        public let completion: Double
        public let yield: Double
        public let score: Int
        public let marks: Int
        public let foulsOutsideTell: Int
        public let sieved: Bool

        /// Success for the Rasch update iff **sieved and `ratio ≥ 0.80`**.
        public var isSuccess: Bool { sieved && ratio >= 0.80 }
        /// §9.6: a run sieved at `ratio ≥ 0.92` inscribes a Codex page — won by demonstration
        /// rather than declaration — which then enters ECHO's pool.
        public var inscribes: Bool { sieved && ratio >= 0.92 }
    }

    public struct Resolved: Equatable, Sendable {
        public let outcome: Outcome
        public let lawful: Bool
        public let weight: Double
        public let inTell: Bool

        public init(outcome: Outcome, lawful: Bool, weight: Double, inTell: Bool) {
            self.outcome = outcome
            self.lawful = lawful
            self.weight = weight
            self.inTell = inTell
        }
    }

    /// - Parameter length: the stream's full `N`.
    ///
    /// With `ideal` summed over all `N` the unresolved glyphs sit in the denominator
    /// contributing nothing to the numerator, so completion is already inside `ratio` and
    /// multiplying by it again **squares the penalty**: a flawless player fouling out at glyph
    /// 20 of 76 scored ≈ 69, about four times harsher than the mode's own edge-case table
    /// claims — and at band 6 with `s = 3` the window is 226 ms, so fouling out is the mode's
    /// most common bad outcome and was its most mispriced one. `ratio` measures accuracy,
    /// `completion` measures reach, each charged exactly once.
    public static func score(resolved: [Resolved], length: Int) -> Result {
        let raw = resolved.reduce(0.0) { $0 + $1.weight * points($1.outcome) }
        let ideal = resolved.reduce(0.0) { $0 + $1.weight * ($1.lawful ? 10 : 3) }
        let ratio = ideal <= 0 ? 0 : max(0, raw) / ideal
        let completion = length <= 0 ? 0 : Double(resolved.count) / Double(length)
        let yield = ratio * completion
        let fouls = resolved.count { $0.outcome == .foul && !$0.inTell }
        let sieved = resolved.count == length

        // Marks are read off `yield`, not `ratio`, so reach is charged to the mark as well as
        // to the score. On a sieved run `completion = 1` and `yield == ratio`, so the
        // thresholds are exactly the completed-run thresholds they were calibrated as.
        let marks: Int =
            if yield >= 0.92, fouls == 0 {
                3
            } else if yield >= 0.80 {
                2
            } else if yield >= 0.60 {
                1
            } else {
                0
            }

        return Result(
            ratio: ratio, completion: completion, yield: yield,
            score: Int((1_000 * yield).rounded(.toNearestOrAwayFromZero)), marks: marks,
            foulsOutsideTell: fouls, sieved: sieved)
    }

    /// §9.5: **misses never end a run; three fouls do.** A miss is caution and a foul is a false
    /// claim, and punishing claims while tolerating caution is what stops the mode degenerating
    /// into mashing.
    public static let foulLimit = 3
}
