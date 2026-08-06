public import Laws

/// §6.9's scoring, and the three Seal-mark thresholds.
///
/// Every quantity here is a probe COUNT. No wall-clock quantity affects score, marks or the
/// Rasch update in PROBE (§6.1): `Tempo` is `probes / par`, not seconds, so a round can be
/// paused for a week without consequence.
public enum Scoring {
    /// A round's outcome. Only `.inscribed` scores; `broken`, `exhausted`, `abandoned` and
    /// `voided` all score exactly zero — score is the Codex's currency and a loss inscribes no
    /// page, so a consolation score would make the page count and the score total disagree.
    public enum Outcome: Hashable, Sendable {
        case inscribed(marks: Int, fracture: Bool)
        case broken
        case exhausted
        case abandoned
        case voided
    }

    /// §6.9's three-mark threshold as a fraction of par, named because **two** rules key off it:
    /// the third Seal mark, and §6.6's breath — the hint that starts once a round has passed the
    /// point where three marks are still reachable. Writing `0.6` in a feature module would give
    /// a locked constant a second home, which is what §5.7 exists to prevent.
    public static let threeMarkFraction = 0.6

    /// §6.9's formula, evaluated multiply-then-round-once so a strike never produces a
    /// fractional intermediate.
    public static func score(probesUsed: Int, par: Int, strikes: Int) -> Int {
        let probes = max(1, probesUsed)  // guards a 0-probe declaration
        let economy = min(1.0, Double(par) / Double(probes))
        let penalty = strikes >= 1 ? 0.6 : 1.0
        return Int((1000.0 * economy * penalty).rounded(.toNearestOrAwayFromZero))
    }

    /// 3 at `≤ 0.6·par`, 2 at `≤ par`, 1 at `≤ cap`.
    ///
    /// The gradient is FLAT below par and that is the point: `min(1, par/probes)` pays a full
    /// 1000 for any probe count at or under par, so a careful player who uses their whole
    /// budget is not taxed for it. Extreme economy is recognised categorically, by the third
    /// mark, not continuously.
    public static func marks(probesUsed: Int, par: Int, cap: Int) -> Int {
        let probes = max(1, probesUsed)
        if Double(probes) <= threeMarkFraction * Double(par) { return 3 }
        if probes <= par { return 2 }
        return 1
    }

    /// The probe at which the par row inverts and the cap row begins emptying — §6.9's par
    /// crossing, the round's one non-verdict event.
    public static func isParCrossing(probeIndex: Int, par: Int) -> Bool { probeIndex == par }
}
