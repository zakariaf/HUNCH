public import Glyphs
public import Persistence

/// What the first frame is, decided **from state alone**.
///
/// A launch route that reads a flag someone remembered to set is a launch route that shows the
/// wrong screen the first time somebody forgets. All three answers here are functions of what is
/// on disk, so a player who force-quits mid-round and a player on a fresh install cannot end up
/// in each other's opening.
public enum AppLaunchRoute: Equatable, Sendable {
    /// A live snapshot: open the round. §6.10's resume lands *inside* it — phase `probing` from
    /// the first frame, no dialog, no "Resume?" button anywhere in the path.
    case resumeRound(Mode)
    /// A fresh install: the opening round, **with the Frame skipped**. The first thing anybody
    /// ever sees is a round, not a menu.
    case openingRound
    /// A returning player with nothing suspended.
    case frame

    /// - Parameters:
    ///   - suspended: which modes have a live `round-{mode}.json`.
    ///   - hasPlayed: whether anything at all has been written — the manifest's existence.
    public static func decide(suspended: Set<Mode>, hasPlayed: Bool) -> AppLaunchRoute {
        // PROBE first, then the order modes were introduced: a player with two suspended rounds
        // gets the one the game is *about*, and the choice is deterministic rather than
        // whichever the file system listed first.
        for mode in [Mode.probe, .drift, .echo] where suspended.contains(mode) {
            return .resumeRound(mode)
        }
        return hasPlayed ? .frame : .openingRound
    }
}
