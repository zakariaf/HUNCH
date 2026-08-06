public import Foundation

public import Glyphs
public import Laws

/// §10.5's cold start: **five galloping rounds**, then one seeding.
///
/// The gallop is bands 1, 2, 4, 6, 8 — round 1 is band 1 unconditionally and each win advances
/// to the next rung. Worst-case seeding error is ±1 band, and `K = 0.900` for the next four
/// rounds removes it in about three, so calibration costs at most five rounds and is over in
/// one sitting.
public enum Calibration {

    /// The rungs, in order. Not consecutive bands: a five-round calibration that walked 1…5
    /// would only ever discover a beginner, and the whole point is to place a returning expert
    /// as fast as a first-time player.
    public static let gallop: [Band] = [.literal, .pair, .relational, .guarded, .systemic]

    public static let rounds = 5

    /// - Parameter round: 1-based.
    public static func band(forRound round: Int) -> Band {
        gallop[min(gallop.count - 1, max(0, round - 1))]
    }

    /// The seeding on the first loss.
    ///
    /// `b_est = (marks >= 2) ? b − 1 : max(1, b − 2)` — **probe economy breaks the tie**: a
    /// player who won the previous rung on three marks was not scraping it, so their true level
    /// is nearer that rung than one who spent their whole cap.
    public static func estimatedBand(lostAt band: Band, previousMarks: Int) -> Int {
        previousMarks >= 2 ? max(1, band.rawValue - 1) : max(1, band.rawValue - 2)
    }

    /// `core = (b_est − 4.5) + ln 4` — the band's centre plus the target offset, so the first
    /// served round after calibration lands at the middle of the band the player just proved.
    public static func seededCore(estimatedBand: Int) -> Double {
        (Double(estimatedBand) - 4.5) + Ability.targetOffset
    }

    /// A player who wins all five is placed at band 8 permanently.
    public static let allWinsCore = seededCore(estimatedBand: 8)

    /// §10.5's reset. `core` goes back to **undefined**, not to `0.0`: zeroing it would serve
    /// band 3 immediately and skip calibration entirely, which is the precise cold-start failure
    /// the section's first decision exists to prevent.
    public static func reset(_ state: inout ServingState) {
        state = ServingState()
    }
}

/// §10.7's exact triggers, as a table rather than as scattered `if`s.
public enum AntiFrustration {

    public enum Response: Equatable, Sendable {
        case none
        /// One full band.
        case relief(Double)
        /// The band shifts and `targetδ` is re-derived to the new band's centre.
        case shiftFamily
        /// At the floor the **tooling** opens, because the difficulty cannot close further:
        /// serve the family's deterministic anchor and unlock the Assay evidence overlay
        /// permanently for that player.
        case floorRescue
    }

    public static func response(
        consecutiveLosses: Int, band: Band, mode: Mode, repeatsFamily: Bool
    ) -> Response {
        if consecutiveLosses >= 3, band.rawValue == ServingPolicy.minBand(mode) {
            return .floorRescue
        }
        if consecutiveLosses >= 3 { return .relief(2.00) }
        if consecutiveLosses >= 2 { return .relief(1.00) }
        if consecutiveLosses >= 1, repeatsFamily { return .shiftFamily }
        return .none
    }

    /// **No cap relief, ever, and no par relief, ever.** Par feeds Tempo and cap feeds the
    /// failure signal the estimator needs; softening either silently would make the model
    /// unidentifiable and the Profile a lie.
    public static let relievesCap = false
    public static let relievesPar = false
}
