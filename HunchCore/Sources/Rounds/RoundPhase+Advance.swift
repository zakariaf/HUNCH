public import Glyphs

/// What happens *to* a round. One case per trigger column in §6.1's transition table.
///
/// Events carry only what the destination phase needs and cannot recompute: a verdict, a seal
/// result, a probe count. They never carry a duration — the table's durations belong to the
/// beat that *sends* the event, not to the machine that receives it.
public enum RoundEvent: Sendable, Equatable {
    /// A fresh round's first frame was committed, or a resumed round's stored law passed its
    /// integrity hash. Both rows of §6.1 arrive at `probing`, so they are one event.
    case armed

    /// A resumed round's stored law failed its integrity hash. The only route to `.voided`.
    case integrityCheckFailed

    /// A probe was committed. The verdict was computed at t = 0 and is carried, not recomputed.
    case verdict(Verdict)

    /// The current phase's input lock expired. One event for three rows — `adjudicating`,
    /// `counterexample` and `revealing` each have exactly one destination, fixed by the source
    /// phase alone, so naming three events would be naming the same fact three times.
    case beatCompleted

    /// The **cap-th** probe's adjudication beat completed. Distinct from `beatCompleted`
    /// because §6.11 case 4 delivers that verdict in full and only then ends the round; the
    /// difference is invisible to the phase and must therefore be in the event.
    case capReached

    /// Bench handle tap, upward drag, or the Bench key.
    case benchOpened

    /// The Dial key from the Bench. §6.7: the draft survives, which is the caller's business.
    case benchDismissed

    /// The Seal was pressed unbarred. The declaration is judged at this instant; the 640 ms
    /// hold that follows is verdict-blind, which is why the result is *not* carried here.
    case sealPressed

    /// The 640 ms hold expired and the already-computed result is revealed.
    case sealResolved(SealResult)

    /// The player left from the run frame. At zero probes there is no round to settle (§6.10),
    /// so the count is what decides between `settled(.abandoned)` and no transition at all.
    case abandoned(probesUsed: Int)
}

/// The judgement of one declaration, computed when the Seal is pressed and revealed 640 ms
/// later. Three outcomes, not two: §6.1 sends a first strike to `counterexample` and a second
/// to `revealing(.broken)`, so the strike count is part of the result, not a separate event.
public enum SealResult: Sendable, Equatable {
    case correct(marks: Int, fracture: Bool)
    case wrongFirstStrike
    case wrongSecondStrike
}

extension RoundPhase {
    /// §6.1's transition table as a pure function — **the only writer of a phase anywhere.**
    ///
    /// - Returns: the destination phase, or `nil` when the event is refused in this phase.
    ///   Refusal is not an error and never traps: every input lock in the game *is* a refused
    ///   transition (`probing` is the only open-input phase), so a tap arriving one frame into
    ///   the adjudication beat has to be dropped silently, exactly here.
    ///
    /// Written as a switch over the phase with an exhaustive inner switch over the event, and
    /// no `default:` anywhere (`W29`): adding a phase breaks this function, and adding an
    /// event breaks all eight arms — which is the review that a new event needs.
    public static func advance(_ phase: RoundPhase, on event: RoundEvent) -> RoundPhase? {
        switch phase {
        case .arming:
            switch event {
            case .armed: .probing
            case .integrityCheckFailed: .settled(.voided)
            case .verdict, .beatCompleted, .capReached, .benchOpened, .benchDismissed,
                .sealPressed, .sealResolved, .abandoned:
                nil
            }

        case .probing:
            switch event {
            case .verdict(let verdict): .adjudicating(verdict)
            case .benchOpened: .declaring
            // §6.10: at zero probes the round is discarded outright — no record, no `Outcome`.
            // `nil` is exactly that, and it is why the count travels with the event.
            case .abandoned(let probesUsed): probesUsed >= 1 ? .settled(.abandoned) : nil
            case .armed, .integrityCheckFailed, .beatCompleted, .capReached, .benchDismissed,
                .sealPressed, .sealResolved:
                nil
            }

        case .adjudicating:
            switch event {
            case .beatCompleted: .probing
            case .capReached: .revealing(.exhausted)
            case .armed, .integrityCheckFailed, .verdict, .benchOpened, .benchDismissed,
                .sealPressed, .sealResolved, .abandoned:
                nil
            }

        case .declaring:
            switch event {
            case .benchDismissed: .probing
            case .sealPressed: .sealing
            case .abandoned(let probesUsed): probesUsed >= 1 ? .settled(.abandoned) : nil
            case .armed, .integrityCheckFailed, .verdict, .beatCompleted, .capReached,
                .benchOpened, .sealResolved:
                nil
            }

        case .sealing:
            switch event {
            case .sealResolved(.correct(let marks, let fracture)):
                .revealing(.inscribed(marks: marks, fracture: fracture))
            case .sealResolved(.wrongFirstStrike): .counterexample
            case .sealResolved(.wrongSecondStrike): .revealing(.broken)
            case .armed, .integrityCheckFailed, .verdict, .beatCompleted, .capReached,
                .benchOpened, .benchDismissed, .sealPressed, .abandoned:
                nil
            }

        case .counterexample:
            switch event {
            case .beatCompleted: .probing
            case .armed, .integrityCheckFailed, .verdict, .capReached, .benchOpened,
                .benchDismissed, .sealPressed, .sealResolved, .abandoned:
                nil
            }

        case .revealing(let outcome):
            switch event {
            // Beat completed or tapped to skip: the outcome was decided before the reveal
            // began, so skipping cannot change it and the two triggers are one event.
            case .beatCompleted: .settled(outcome)
            case .armed, .integrityCheckFailed, .verdict, .capReached, .benchOpened,
                .benchDismissed, .sealPressed, .sealResolved, .abandoned:
                nil
            }

        // Terminal. NEXT and the run frame arm a *new* round; they do not leave this one.
        case .settled:
            switch event {
            case .armed, .integrityCheckFailed, .verdict, .beatCompleted, .capReached,
                .benchOpened, .benchDismissed, .sealPressed, .sealResolved, .abandoned:
                nil
            }
        }
    }

    /// Whether the player may touch the Dial. §6.1: `probing` and `declaring` are the open
    /// phases; every other phase is a locked window with a beat running over it.
    public var acceptsInput: Bool {
        switch self {
        case .probing, .declaring: true
        case .arming, .adjudicating, .sealing, .counterexample, .revealing, .settled: false
        }
    }

    /// The outcome this phase carries, if it carries one. Read rather than stored, so a round
    /// cannot hold an outcome that disagrees with its phase.
    public var outcome: Outcome? {
        switch self {
        case .revealing(let outcome), .settled(let outcome): outcome
        case .arming, .probing, .adjudicating, .declaring, .sealing, .counterexample: nil
        }
    }
}
