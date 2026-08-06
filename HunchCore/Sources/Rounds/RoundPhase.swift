public import Glyphs
public import Laws

/// §6.1's round state machine.
///
/// Two invariants hold everywhere and remove a whole class of bug: **the model never waits on
/// an animation** — every verdict is computed and committed at t = 0 of its beat sheet and
/// merely *displayed* later, so killing the app mid-animation loses nothing — and **no
/// wall-clock quantity affects score, marks or the Rasch update**.
public enum RoundPhase: Sendable, Equatable {
    /// Law generated or snapshot restored; first frame not yet shown.
    case arming
    /// Dial live, input open — the only open-input phase.
    case probing
    /// 420 ms (320 ms Reduce Motion), input locked, model already committed.
    case adjudicating(Verdict)
    /// Bench up, Dial down, input open.
    case declaring
    /// 640 ms, input locked, verdict already computed and **verdict-blind**: identical in
    /// content and duration whether the declaration was right or wrong, so the answer is not
    /// readable off the clock.
    case sealing
    /// 960 ms, first strike only.
    case counterexample
    case revealing(Outcome)
    /// The round card. Chrome, so text is permitted here.
    case settled(Outcome)
}

/// §6.1's five outcomes. Only `.inscribed` scores.
public enum Outcome: Sendable, Equatable, Hashable {
    case inscribed(marks: Int, fracture: Bool)
    /// The second strike.
    case broken
    /// The cap was reached.
    case exhausted
    /// The player left after at least one probe.
    case abandoned
    /// The stored law failed its integrity hash on resume. Reachable **only** from `arming`:
    /// a voided round is a round the machine declines to vouch for, not a round the player
    /// lost.
    case voided
}

extension Outcome {
    public var isInscribed: Bool {
        guard case .inscribed = self else { return false }
        return true
    }

    /// §10.1: a round is a LOSS if the second strike lands or the cap is reached. An abandon is
    /// an interruption signal, not a failure signal — scoring it as a loss would let a player
    /// farm the adaptive engine downward by quitting hard rounds.
    public var isLoss: Bool {
        switch self {
        case .broken, .exhausted: true
        case .inscribed, .abandoned, .voided: false
        }
    }

    /// Whether this outcome updates the Rasch estimate at all.
    public var updatesAbility: Bool {
        switch self {
        case .inscribed, .broken, .exhausted: true
        case .abandoned, .voided: false
        }
    }
}
