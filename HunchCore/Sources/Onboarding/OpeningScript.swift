public import Foundation

public import Tokens

/// §12.5's opening script: **fourteen beats, 0 through 13**, each revealing exactly one
/// affordance and each triggered by the act the previous one taught.
///
/// The script is data because its two hard rules are structural, not behavioural: each beat
/// reveals *one* thing, and a second opening round re-arms from **beat 6** so that beats 0–5 —
/// the ones that teach what a probe is — never play again for a player who already knows.
public enum OpeningScript {

    /// What makes a beat happen. A beat triggered by *time alone* is a beat that plays over a
    /// player who is already doing something else, which is why only three of the fourteen are.
    public enum Trigger: Equatable, Sendable {
        case launch
        case elapsed(Duration)
        case act(String)
        /// Beat 7: probe 4 **or** 25 s after beat 6, whichever comes first — a player who is
        /// probing productively is not interrupted, and a player who has stalled is not left.
        case actOrElapsed(String, Duration)
        case ledgerComplete
    }

    public struct Beat: Equatable, Sendable {
        public let index: Int
        public let trigger: Trigger
        /// The single affordance this beat reveals. One per beat, and the test asserts it.
        public let reveals: String

        public init(index: Int, trigger: Trigger, reveals: String) {
            self.index = index
            self.trigger = trigger
            self.reveals = reveals
        }
    }

    /// The beat a *second* opening round starts from. Beats 0–5 teach what a probe is; replaying
    /// them for a player who has already probed is the game explaining something they just did.
    public static let reArmBeat = 6

    public static let beats: [Beat] = [
        Beat(index: 0, trigger: .launch, reveals: "the throat, the seed glyph, the ribbon socket"),
        Beat(index: 1, trigger: .elapsed(.milliseconds(1_200)), reveals: "the PROBE key"),
        Beat(index: 2, trigger: .act("probe"), reveals: "the first verdict — an admit"),
        Beat(index: 3, trigger: .elapsed(.milliseconds(400)), reveals: "the shape ramp"),
        Beat(index: 4, trigger: .act("selectCell"), reveals: "the throat morphing one register"),
        Beat(index: 5, trigger: .act("probe"), reveals: "a reject, and the par row"),
        Beat(index: 6, trigger: .ledgerComplete, reveals: "the remaining three ramps"),
        Beat(
            index: 7, trigger: .actOrElapsed("probe4", .seconds(25)),
            reveals: "the Bench handle"),
        Beat(index: 8, trigger: .act("openBench"), reveals: "the Bench and one palette stamp"),
        Beat(index: 9, trigger: .act("stamp"), reveals: "an unbound Ramp on rail 1"),
        Beat(index: 10, trigger: .act("bindAttribute"), reveals: "the bound ramp, inert"),
        Beat(index: 11, trigger: .act("lightCell"), reveals: "the Assay and the unbarred Seal"),
        Beat(index: 12, trigger: .act("seal"), reveals: "the law reveal"),
        Beat(
            index: 13, trigger: .act("inscription"),
            reveals: "the Frame key, lit for the first time"),
    ]

    /// §12.5: the Frame does not exist for a player who has not finished a round. It lights at
    /// beat 13 and not before — a menu offered to somebody who has never played is a menu of
    /// things that mean nothing.
    public static let frameUnlocksAt = 13

    public static func beats(from index: Int) -> [Beat] {
        beats.filter { $0.index >= index }
    }
}
