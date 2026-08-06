import Testing

import Glyphs
import HunchTestSupport
import Rounds

/// §6.1's transition table, read back one row at a time.
///
/// The table is the round's whole grammar of legal moves, and `advance` is the only writer of a
/// phase in the app — so every row here is load-bearing twice: once as behaviour, and once as
/// the proof that nothing else needs an `if` to move a round along.
@Suite("The round's phase machine", .tags(.unit, .presubmission))
struct RoundPhaseTests {

    /// Every row of §6.1, in the order the table states them.
    static let table: [(from: RoundPhase, event: RoundEvent, to: RoundPhase)] = [
        (.arming, .armed, .probing),
        (.arming, .integrityCheckFailed, .settled(.voided)),
        (.probing, .verdict(.admit), .adjudicating(.admit)),
        (.probing, .verdict(.reject), .adjudicating(.reject)),
        (.probing, .benchOpened, .declaring),
        (.probing, .abandoned(probesUsed: 1), .settled(.abandoned)),
        (.adjudicating(.admit), .beatCompleted, .probing),
        (.adjudicating(.reject), .capReached, .revealing(.exhausted)),
        (.declaring, .benchDismissed, .probing),
        (.declaring, .sealPressed, .sealing),
        (.declaring, .abandoned(probesUsed: 4), .settled(.abandoned)),
        (
            .sealing, .sealResolved(.correct(marks: 3, fracture: false)),
            .revealing(.inscribed(marks: 3, fracture: false))
        ),
        (.sealing, .sealResolved(.wrongFirstStrike), .counterexample),
        (.sealing, .sealResolved(.wrongSecondStrike), .revealing(.broken)),
        (.counterexample, .beatCompleted, .probing),
        (.revealing(.broken), .beatCompleted, .settled(.broken)),
        (.revealing(.exhausted), .beatCompleted, .settled(.exhausted)),
    ]

    @Test("Every row of §6.1's transition table", arguments: table)
    func tableRow(_ row: (from: RoundPhase, event: RoundEvent, to: RoundPhase)) {
        #expect(RoundPhase.advance(row.from, on: row.event) == row.to)
    }

    /// §6.10: abandoning before probe 1 discards the round outright — no record, no `Outcome`.
    /// A `settled(.abandoned)` here would inscribe a loss-shaped row for a round that produced
    /// no evidence, and would let a player leave a fingerprint by opening and leaving.
    @Test("Abandoning at zero probes is not a transition at all")
    func abandonAtZeroProbesIsNotATransition() {
        #expect(RoundPhase.advance(.probing, on: .abandoned(probesUsed: 0)) == nil)
        #expect(RoundPhase.advance(.declaring, on: .abandoned(probesUsed: 0)) == nil)
    }

    /// The negative half, and the one that matters most: every input lock in the game *is* a
    /// refused transition, so a tap landing one frame into a beat has to vanish here.
    @Test(
        "A probe is refused in every phase but `probing`",
        arguments: [
            RoundPhase.arming, .adjudicating(.admit), .declaring, .sealing, .counterexample,
            .revealing(.broken), .settled(.broken),
        ])
    func probeRefusedOutsideProbing(_ phase: RoundPhase) {
        #expect(RoundPhase.advance(phase, on: .verdict(.admit)) == nil)
    }

    @Test("`settled` is terminal — no event leaves it")
    func settledIsTerminal() {
        let events: [RoundEvent] = [
            .armed, .integrityCheckFailed, .verdict(.admit), .beatCompleted, .capReached,
            .benchOpened, .benchDismissed, .sealPressed,
            .sealResolved(.correct(marks: 1, fracture: false)), .abandoned(probesUsed: 9),
        ]
        for event in events {
            #expect(RoundPhase.advance(.settled(.exhausted), on: event) == nil)
        }
    }

    /// `.voided` is reachable **only** from `arming`, and only on a resume — a voided round is
    /// one the machine declines to vouch for, not one the player lost. If any other phase could
    /// produce it, a live round could be silently erased mid-play.
    @Test("Nothing inside a live round can produce `.voided`")
    func voidedIsReachableOnlyFromArming() {
        let live: [RoundPhase] = [
            .probing, .adjudicating(.admit), .declaring, .sealing, .counterexample,
            .revealing(.broken), .settled(.broken),
        ]
        for phase in live {
            #expect(RoundPhase.advance(phase, on: .integrityCheckFailed) == nil)
        }
        #expect(RoundPhase.advance(.arming, on: .integrityCheckFailed) == .settled(.voided))
    }

    /// The cap-th verdict is delivered in full and *then* the round ends (§6.11 case 4). The
    /// distinction lives in the event, not the phase, so this is where it can be checked.
    @Test("`capReached` and `beatCompleted` differ only after the last verdict")
    func capReachedEndsTheRoundAfterTheBeat() {
        #expect(RoundPhase.advance(.adjudicating(.admit), on: .beatCompleted) == .probing)
        #expect(
            RoundPhase.advance(.adjudicating(.admit), on: .capReached) == .revealing(.exhausted))
    }

    @Test("`probing` and `declaring` are the only phases that accept input")
    func onlyTwoPhasesAcceptInput() {
        let open: [RoundPhase] = [.probing, .declaring]
        let locked: [RoundPhase] = [
            .arming, .adjudicating(.admit), .sealing, .counterexample, .revealing(.broken),
            .settled(.broken),
        ]
        for phase in open { #expect(phase.acceptsInput) }
        for phase in locked { #expect(!phase.acceptsInput) }
    }

    @Test("A phase carries its outcome rather than a round storing one beside it")
    func outcomeIsReadFromThePhase() {
        #expect(RoundPhase.settled(.broken).outcome == .broken)
        #expect(RoundPhase.revealing(.exhausted).outcome == .exhausted)
        #expect(RoundPhase.probing.outcome == nil)
        #expect(RoundPhase.adjudicating(.admit).outcome == nil)
    }
}
