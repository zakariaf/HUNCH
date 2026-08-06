public import Glyphs

/// §6.10's leaving rules, as a **total function** over `(mode, probesUsed, intent)`.
///
/// Four actions, each with an explicit effects record, so that no caller can invent a fifth
/// reading of what "leaving" means. The four differ in ways a player can feel — whether a record
/// is written, whether the ladder moves, whether the seed comes back — and every one of those is
/// a place two call sites could quietly disagree.
public enum RoundExit {

    /// What the player did.
    public enum Intent: Hashable, Sendable {
        /// The leading chevron: suspend, one tap, no confirmation.
        case suspend
        /// Leaving the round for good, from the run frame.
        case abandon
    }

    public enum Action: Hashable, Sendable {
        /// Below one probe there is no round to settle: no record, no `Outcome`, and the seed
        /// goes back in the pool. A player who opens a round and leaves has produced no
        /// evidence, and inscribing that would let them leave a fingerprint by doing nothing.
        case discard
        /// One or more probes: `abandoned` at score 0.
        case settleAbandoned
        /// Written to `round-{mode}.json` and resumed exactly where it was left.
        case suspend
        /// SIEVE has no suspend slot: a stream cannot be paused into a file and resumed as the
        /// same stream, so leaving it is leaving it.
        case suspendUnavailable
    }

    /// The effects each action has. Named rather than implied, because "abandon does not move
    /// the ladder" is the kind of rule that is true until somebody adds a call.
    public struct Effects: Hashable, Sendable {
        public var writesRecord: Bool
        /// §10.1: an abandon is an **interruption** signal, not a failure signal. Scoring it as
        /// a loss would let a player farm the adaptive engine downward by quitting hard rounds.
        public var updatesAbility: Bool
        /// The target stays where it was, so the next round is the one this player was owed.
        public var stickyTarget: Bool
        public var returnsSeedToPool: Bool
        public var writesSnapshot: Bool
    }

    public static func action(mode: Mode, probesUsed: Int, intent: Intent) -> Action {
        switch intent {
        case .suspend:
            return mode == .sieve ? .suspendUnavailable : .suspend
        case .abandon:
            return probesUsed == 0 ? .discard : .settleAbandoned
        }
    }

    public static func effects(of action: Action) -> Effects {
        switch action {
        case .discard:
            Effects(
                writesRecord: false, updatesAbility: false, stickyTarget: true,
                returnsSeedToPool: true, writesSnapshot: false)
        case .settleAbandoned:
            Effects(
                writesRecord: true, updatesAbility: false, stickyTarget: true,
                returnsSeedToPool: false, writesSnapshot: false)
        case .suspend:
            Effects(
                writesRecord: false, updatesAbility: false, stickyTarget: true,
                returnsSeedToPool: false, writesSnapshot: true)
        case .suspendUnavailable:
            Effects(
                writesRecord: false, updatesAbility: false, stickyTarget: true,
                returnsSeedToPool: false, writesSnapshot: false)
        }
    }
}
