import Testing

import Glyphs
import HunchTestSupport
import Laws
import Onboarding
import Tokens

/// §12.5's opening round, measured rather than judged.
@Suite("The onboarding ledger", .tags(.unit, .presubmission))
struct OnboardingLedgerTests {

    @Test("Success is the five-way conjunction and nothing else")
    func completionIsFiveConjuncts() {
        var ledger = OnboardingLedger()
        #expect(ledger.isComplete == false)

        ledger.declaredCorrectly = true
        ledger.selfConstructedProbes = 1
        ledger.record(verdict: .admit)
        ledger.record(verdict: .reject)
        ledger.boundAnAttribute = true
        #expect(ledger.isComplete)

        // The three diagnostics are recorded and are not gates: a player who declared correctly
        // must have opened the Bench, so requiring it would add nothing but a way to fail.
        #expect(ledger.openedBench == false)
        #expect(ledger.clearedTheSealBar == false)
        #expect(ledger.nudgesFired == 0)
    }

    @Test("Every conjunct is necessary")
    func eachConjunctMatters() {
        func complete() -> OnboardingLedger {
            var ledger = OnboardingLedger()
            ledger.declaredCorrectly = true
            ledger.selfConstructedProbes = 1
            ledger.sawAdmit = true
            ledger.sawReject = true
            ledger.boundAnAttribute = true
            return ledger
        }
        var missing = complete()
        missing.declaredCorrectly = false
        #expect(missing.isComplete == false)
        missing = complete()
        missing.sawReject = false
        #expect(missing.isComplete == false)
        missing = complete()
        missing.selfConstructedProbes = 0
        #expect(missing.isComplete == false)
        missing = complete()
        missing.boundAnAttribute = false
        #expect(missing.isComplete == false)
    }

    /// A **run**, not a total: nudge 5 fires every two unvaried probes, and a total would fire
    /// it forever after the second one.
    @Test("The unvaried run resets on any variation")
    func unvariedIsARun() {
        var ledger = OnboardingLedger()
        ledger.recordProbe(selfConstructed: true, variedFromPrevious: false)
        ledger.recordProbe(selfConstructed: true, variedFromPrevious: false)
        #expect(ledger.unvariedRun == 2)
        ledger.recordProbe(selfConstructed: true, variedFromPrevious: true)
        #expect(ledger.unvariedRun == 0)
        #expect(ledger.selfConstructedProbes == 3)
    }
}

/// §12.5's elastic cap. The passive path is the failure it closes: a player who probes admits
/// forever never learns that the Loom says no, and loses at the cap to a rule nobody showed them.
@Suite("The elastic cap", .tags(.unit, .presubmission))
struct ElasticCapTests {

    @Test("While no reject has landed the cap cannot end the round")
    func theCapIsSuspended() {
        let cap = ElasticCap(base: Band.literal.cap, isOpeningRound: true)
        #expect(cap.isSuspended)
        #expect(cap.endsRound(atProbe: Band.literal.cap) == false)
        #expect(cap.endsRound(atProbe: 20) == false)
    }

    /// The suspension is not infinite: a player who has taken 24 probes without a single reject
    /// is not being taught by more probes.
    @Test("The suspension hard-stops at probe 24")
    func theHardStop() {
        let cap = ElasticCap(base: Band.literal.cap, isOpeningRound: true)
        #expect(cap.endsRound(atProbe: ElasticCap.hardStop))
        #expect(ElasticCap.hardStop == 24)
    }

    /// §12.5 writes the re-arm as `max(12, probesUsed + 3)`, and 12 **is** `Band.literal.cap` —
    /// reading the base is the difference between a rule and a coincidence that survives until
    /// the cap table moves.
    @Test("The first reject re-arms the cap at max(base, probesUsed + 3)")
    func theFirstRejectReArms() {
        var early = ElasticCap(base: Band.literal.cap, isOpeningRound: true)
        early.record(verdict: .reject, probesUsed: 2)
        #expect(early.isSuspended == false)
        #expect(early.limit == Band.literal.cap)  // base wins when the reject came early

        var late = ElasticCap(base: Band.literal.cap, isOpeningRound: true)
        late.record(verdict: .reject, probesUsed: 15)
        #expect(late.limit == 18)
        #expect(late.endsRound(atProbe: 18))
        #expect(late.endsRound(atProbe: 17) == false)
    }

    @Test("An admit never moves the cap, and a second reject never moves it again")
    func onlyTheFirstRejectMoves() {
        var cap = ElasticCap(base: Band.literal.cap, isOpeningRound: true)
        cap.record(verdict: .admit, probesUsed: 9)
        #expect(cap.isSuspended)
        cap.record(verdict: .reject, probesUsed: 10)
        #expect(cap.limit == 13)
        cap.record(verdict: .reject, probesUsed: 20)
        #expect(cap.limit == 13)
    }

    @Test("Outside the opening round nothing is ever suspended", arguments: Band.allCases)
    func ordinaryRoundsAreRigid(_ band: Band) {
        var cap = ElasticCap(base: band.cap, isOpeningRound: false)
        #expect(cap.isSuspended == false)
        cap.record(verdict: .reject, probesUsed: band.cap - 1)
        #expect(cap.limit == band.cap)
        #expect(cap.endsRound(atProbe: band.cap))
    }
}

/// §12.5's five nudges. The hard floor — *this control exists and is pressable*, never a value —
/// is enforced by the type rather than by review.
@Suite("The nudge scheduler", .tags(.unit, .presubmission))
struct NudgeSchedulerTests {

    private func observation(
        idle: Double = 0, probes: Int = 0, par: Int = 7, bench: Bool = false,
        barred: Int = 0, unvaried: Int = 0, voiceOver: Bool = false
    ) -> NudgeScheduler.Observation {
        NudgeScheduler.Observation(
            idleSeconds: idle, probesUsed: probes, par: par, openedBench: bench,
            barredSealPresses: barred, unvariedRun: unvaried, isVoiceOverRunning: voiceOver)
    }

    /// No nudge can name a glyph, an attribute or a rank — there is no case that could carry
    /// one. That is the floor made structural rather than reviewed.
    @Test("A nudge points at a control and can say nothing else")
    func theHardFloorIsStructural() {
        #expect(NudgeScheduler.Target.allCases.count == 5)
        for kind in NudgeScheduler.Kind.allCases {
            #expect(NudgeScheduler.Target.allCases.contains(kind.target))
        }
    }

    @Test("Twelve seconds idle breathes the PROBE key")
    func idleFires() {
        var scheduler = NudgeScheduler()
        scheduler.update(observation(idle: 11))
        #expect(scheduler.pending == nil)
        scheduler.update(observation(idle: 12))
        #expect(scheduler.pending == .idle)
        #expect(scheduler.pending?.target == .probeKey)
    }

    /// Suppression is at the scheduler and not in the animation: a suppressed animation still
    /// consumes its budget, so the player who turns VoiceOver off later finds them spent.
    @Test("Under VoiceOver nothing fires and no budget is spent")
    func voiceOverSuppressesEntirely() {
        var scheduler = NudgeScheduler()
        for _ in 0..<10 { scheduler.update(observation(idle: 60, voiceOver: true)) }
        #expect(scheduler.pending == nil)
        #expect(scheduler.totalFired == 0)

        scheduler.update(observation(idle: 60))
        #expect(scheduler.pending != nil)
    }

    @Test("Each kind has its own budget and stops when it is spent")
    func budgetsArePerKind() {
        var scheduler = NudgeScheduler()
        for _ in 0..<C.Nudge.barredSealBudget {
            scheduler.update(observation(barred: C.Nudge.barredSealBudget))
        }
        #expect(scheduler.pending == .barredSeal)
        scheduler.update(observation(barred: C.Nudge.barredSealBudget))
        #expect(scheduler.pending == nil)  // spent

        // …and a different situation still has its own budget.
        scheduler.update(observation(idle: 30))
        #expect(scheduler.pending == .idle)
    }

    /// The most specific situation wins, and the global dim is last because it says the least.
    @Test("Priority runs from the most specific situation to the least")
    func priorityIsSpecificFirst() {
        var scheduler = NudgeScheduler()
        scheduler.update(
            observation(idle: 120, probes: 9, bench: false, barred: 3, unvaried: 4))
        #expect(scheduler.pending == .barredSeal)
    }

    @Test("At most one nudge is pending at a time")
    func oneAtATime() {
        var scheduler = NudgeScheduler()
        scheduler.update(observation(idle: 120, probes: 9, unvaried: 4))
        #expect(scheduler.pending != nil)
        scheduler.update(observation())
        #expect(scheduler.pending == nil)
    }
}
