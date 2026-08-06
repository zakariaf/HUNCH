public import Glyphs
public import Laws

/// §12.6's five destructive actions, and the exact file set each touches.
///
/// One type so the reset map can be enumerated, alerted and tested once, rather than
/// rediscovered at five call sites.
public enum ResetAction: String, CaseIterable, Sendable {
    case clearStatistics
    case clearCodex
    case resetProfile
    case resetLadder
    case resetEverything

    /// Files this action deletes outright.
    public var deletes: Set<StoreFile> {
        switch self {
        case .clearStatistics: []
        case .clearCodex: Set(Band.allCases.map(StoreFile.codexShelf))
        case .resetProfile: []
        case .resetLadder: []
        case .resetEverything:
            // Everything EXCEPT the anomaly ledger and its sidecar.
            Set(StoreFile.allCases).subtracting(Self.resetImmune)
        }
    }

    /// Files this action rewrites to a default rather than removing.
    public var rewrites: Set<StoreFile> {
        switch self {
        case .clearStatistics: [.statistics]
        case .clearCodex: [.codexIndex]
        case .resetProfile: [.profile]
        case .resetLadder: [.ladder]
        case .resetEverything: []
        }
    }

    /// **No reset path of any kind touches these.**
    ///
    /// That is not a courtesy to the ledger, it is the whole anti-cheat: `highWaterDay` is the
    /// only thing standing between the daily Anomaly and the device clock, and a reset that
    /// cleared it would *be* the exploit. Only deleting the app clears it, which also clears
    /// everything else — a fair floor (§11.7).
    public static let resetImmune: Set<StoreFile> = [.anomaly, .anomalyHighWater]

    /// §11.12: clearing the Codex re-locks the page-gated modes but does **not** touch the
    /// palette ceiling, which lives in `ServingState` inside `ladder.json`.
    public var affectsPaletteCeiling: Bool {
        self == .resetLadder || self == .resetEverything
    }
}
