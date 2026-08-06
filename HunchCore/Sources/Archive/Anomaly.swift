public import Foundation

public import Glyphs
public import Laws

/// §11.6's Anomaly: **one law per UTC day, identical for every player on Earth, with zero
/// server.**
///
/// This is the single normative derivation. §10.6 states the same constants and cites this
/// block rather than restating it, because a globally shared law with two derivations is a coin
/// flip at implementation time.
public enum Anomaly {

    /// "HUNCHANO" — frozen forever. Changing it changes every Anomaly that has ever existed.
    public static let salt: UInt64 = 0x4855_4E43_4841_4E4F

    /// Days since 1970-01-01T00:00:00Z, floor semantics.
    ///
    /// **The day index, never a formatted string.** Formatting drags in `Calendar` and `Locale`,
    /// which vary by device — Buddhist calendar, Islamic calendar, `ar-SA` defaults — and would
    /// silently give two players different Anomalies. Unix time has no leap seconds, so this
    /// arithmetic is total: proleptic, monotone, one integer.
    public static func utcDayIndex(_ time: TimeInterval) -> Int64 {
        let seconds = Int64(time.rounded(.down))
        return seconds >= 0 ? seconds / 86_400 : (seconds - 86_399) / 86_400
    }

    /// SplitMix64's finaliser over `day + salt`.
    public static func seed(day: Int64) -> UInt64 {
        var z = UInt64(bitPattern: day) &+ salt
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public struct Parameters: Equatable, Sendable {
        public let day: Int64
        public let seed: UInt64
        public let band: Band
        public let targetDelta: Double
    }

    /// `band = 4 + Int(seed % 4)` uses the **low** bits deliberately: it sits next to the
    /// finaliser, whose last step is `z ^ (z >> 31)`, so the low word has already avalanched and
    /// no shift is needed. Any variant spelling — `(seed >> 32) % 4` — selects a different band
    /// from the same day and is therefore **wrong**, not merely different.
    public static func parameters(day: Int64) -> Parameters {
        let seed = seed(day: day)
        let band = Band(rawValue: 4 + Int(seed % 4)) ?? .relational
        var rng = SplitMix64(seed: seed)
        let jitter = Double(rng.next() % 1_001) / 10_000.0 - 0.05
        let target = 0.125 * Double(band.rawValue - 1) + 0.0625 + jitter
        return Parameters(day: day, seed: seed, band: band, targetDelta: target)
    }

    /// §11.6: the Anomaly is always **PROBE**. ECHO's law is "the law you learned last round",
    /// which has no referent for a standalone daily; SIEVE would make a shared law a reflex
    /// contest; DRIFT's swap point is seed-derived and would work, but makes the day's *par*
    /// incomparable between players. PROBE is the only mode where "how few probes" means the
    /// same thing to everyone.
    public static let mode = Mode.probe

    /// §11.6: it does **not** feed the Rasch estimate. It is served off-ladder at a band up to
    /// three above the player's, and §5.3 is explicit that off-band results poison the estimate.
    /// It does inscribe Codex pages, and it feeds Profile axes at half weight.
    public static let updatesAbility = false
    public static let profileWeight = 0.5

    /// §11.7: one attempt per UTC day. The two strikes already are the second chance; unlimited
    /// retries make the shared law and the streak meaningless.
    public static let attemptsPerDay = 1
}

/// §11.7's high-water rule — **the entire anti-cheat, and honest about what it can and cannot
/// do.**
///
/// It cannot stop a determined player from setting their clock back. What it can do is make the
/// cheat worthless: the ledger only ever moves forward, so a day already claimed cannot be
/// claimed again, and a clock set backward simply finds nothing to play.
public struct AnomalyLedger: Codable, Equatable, Sendable {
    /// The highest day index ever seen. **Never decreases.**
    public private(set) var highWaterDay: Int64
    public private(set) var claimedDays: Set<Int64>

    public init(highWaterDay: Int64 = 0, claimedDays: Set<Int64> = []) {
        self.highWaterDay = highWaterDay
        self.claimedDays = claimedDays
    }

    /// - Returns: whether today's Anomaly may be played.
    public func isAvailable(day: Int64) -> Bool {
        day >= highWaterDay && !claimedDays.contains(day)
    }

    public mutating func observe(day: Int64) {
        highWaterDay = max(highWaterDay, day)
    }

    public mutating func claim(day: Int64) {
        observe(day: day)
        claimedDays.insert(day)
    }

    /// §11.13: **all five resets leave the ledger byte-identical.** The streak is the one thing
    /// in the game a reset cannot launder, which is what makes it mean anything at all.
    public static let survivesEveryReset = true
}

/// §10.6's grants — what an Anomaly round hands the player that an ordinary round does not, and
/// what it deliberately withholds.
public enum AnomalyGrants {

    /// The Anomaly unlocks the **full palette** for its round, exactly as calibration does, and
    /// reverts when it ends. It is served off-ladder at a band up to three above the player's,
    /// so the palette ceiling — which tracks `maxBandEverServed` — would otherwise hand them a
    /// toolbox that cannot state the law they were given.
    public static let unlocksFullPalette = true

    /// §4.3's evidence overlay opens for the Anomaly at any band. The gate exists because a free
    /// consistency check trivialises the low bands; a once-a-day off-ladder round at band 4–7 is
    /// not a low band, and the player has no ladder position to protect there anyway.
    public static let unlocksAssayEvidence = true

    /// **The isolation, and it runs both ways.** The Anomaly does not read the player's history
    /// — the generator is called with an empty `avoid` set, which is how G9 is switched off
    /// without a special case — and it does not write to it either.
    public static let readsNoveltyHistory = false
    public static let writesNoveltyHistory = false

    /// It **does** inscribe. A page found on the Anomaly is a page, and marking it with the
    /// doubled rim is the whole record of having been there.
    public static let inscribesCodexPage = true
}
