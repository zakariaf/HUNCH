public import Foundation

public import Tokens

/// §6.10's re-entry: a cold launch with a live snapshot lands the player **inside the round**.
///
/// Phase `probing` from the first frame, Bench collapsed, draft intact — and **no dialog and no
/// "Resume?" button anywhere in the path**. The surface re-reads itself over 900 ms in one
/// order, which is the order a player would read it in: what it cost, what was learned, what was
/// contradicted, what is in hand.
public enum ReEntryBeat {

    /// The order matters and is not decorative. Ticks first because the cost is the frame the
    /// rest is read inside; the ribbon second because it is the evidence; the counterexample
    /// third because it is a correction to that evidence and cannot be read before it; the
    /// throat last because it is the only thing the player is about to *act* on.
    public enum Step: String, CaseIterable, Sendable {
        case parTicks
        case ribbon
        case dockedCounterexample
        case throat
    }

    public static let duration = Dur.reEntry

    /// Input is locked for the whole beat, and the phase is `probing` throughout — the lock is
    /// the beat's, not a phase's. A round that arrived in `arming` and waited would be a round
    /// with a loading screen.
    public static let locksInput = true

    /// The onsets are fractions of the beat rather than four more duration tokens: they are one
    /// choreography, and a change to the beat's length has to move all four together or the
    /// throat arrives after the surface has settled.
    public static func onset(of step: Step) -> Duration {
        let fraction: Double =
            switch step {
            case .parTicks: 0
            case .ribbon: 0.24
            case .dockedCounterexample: 0.58
            case .throat: 0.78
            }
        return .milliseconds(Int(Double(duration.milliseconds) * fraction))
    }

    /// **The par crossing is restored, never replayed.** Replaying it would fire §6.9's one
    /// non-verdict event for a crossing that happened before the app was killed — a player
    /// resuming at probe 20 of 23 would watch their par row invert as though they had just
    /// spent the probe that did it.
    public static let restoresParCrossingWithoutReplaying = true
}
