public import Glyphs

/// §12.3's route graph — **nine destinations, and a worst case of two taps to a live probe
/// surface.**
///
/// A back-stack you can get lost in is the failure mode of menu-driven design, and this app has
/// nine destinations. The rule is not a preference: it is what lets every screen carry a play
/// key instead of a breadcrumb.
public enum Route: String, CaseIterable, Hashable, Sendable {
    case round
    case inscription
    case frame
    case codexRoot
    case codexShelf
    case codexPage
    case anomaly
    case profile
    case statistics
    case settings
    case about
    case assayInspector
    case resetAlert
    case sievePause
}

extension Route {
    /// Taps from this screen to a live probe surface, per §12.3's table.
    ///
    /// The Codex's three levels cost **nothing** precisely because every one of them carries the
    /// play key — a drill-down through a spatial hierarchy the player can see the whole of, not
    /// a menu tree.
    public var distanceToPlay: Int {
        switch self {
        case .round: 0
        case .inscription, .frame, .codexRoot, .codexShelf, .codexPage, .anomaly, .profile,
            .statistics, .settings, .sievePause:
            1
        // Dismiss, then the play key.
        case .about, .assayInspector, .resetAlert: 2
        }
    }

    /// §12.3: `NavigationStack` is used **twice** — in the Codex and in Settings → About.
    /// Everything else is a full-surface transition or a sheet, which is why there is no
    /// back-stack to get lost in.
    public var isPushed: Bool {
        switch self {
        case .codexShelf, .codexPage, .about, .statistics: true
        default: false
        }
    }

    public static let maximumDistanceToPlay = 2
}

/// §9.10's unlock row — **the single source for mode unlocks.** No other section states a
/// threshold; every other one cross-references here.
public enum ModeGate {

    /// The three numbers are not arbitrary, and each has a different *kind* of reason.
    public enum Requirement: Equatable, Sendable {
        case none
        /// DRIFT: a page at band ≥ 3 — the mode's **own floor**. You have met a law whose family
        /// DRIFT can actually edit, and a page-count gate would unbar a mode whose serving path
        /// then has to clamp the player up two bands on their first round.
        case pageAtBand(Int)
        /// ECHO and SIEVE: a page count.
        case pages(Int)
    }

    public static func requirement(for mode: Mode) -> Requirement {
        switch mode {
        case .probe: .none
        case .drift: .pageAtBand(3)
        case .echo: .pages(5)
        case .sieve: .pages(8)
        }
    }

    /// ECHO's five is the smallest number satisfying `unlockThreshold ≥ minimumPoolSize + 2`:
    /// the pool has a functional floor of three members and a blind primer can drop two, so
    /// unlocking at exactly three would hand the player a lit key over an unusable pool.
    public static let echoPoolFloor = 3
    public static let echoBlindPrimerDrop = 2

    public static func isUnlocked(_ mode: Mode, pages: Int, highestPageBand: Int) -> Bool {
        switch requirement(for: mode) {
        case .none: true
        case .pageAtBand(let band): highestPageBand >= band
        case .pages(let count): pages >= count
        }
    }
}
