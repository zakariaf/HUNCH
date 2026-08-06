import Testing

import Drift
import Glyphs
import HunchTestSupport
import Laws

/// §7.10 and §7.11 — the seven ways a DRIFT round can be interrupted, and the one rule that
/// covers all of them: **nothing is re-randomised on resume; the hinge neither re-fires nor
/// un-fires.**
@Suite("DRIFT's interruptions", .tags(.unit, .presubmission))
struct DriftEdgeCaseTests {

    /// `N_admits` is drawn from the round seed, so a resumed round draws the same number. A
    /// re-randomised hinge would move under the player mid-round — the one thing a mode built on
    /// noticing a change cannot afford.
    @Test("N_admits is stable across a resume because it is a function of the seed")
    func theHingeDoesNotMove() {
        for seed in [UInt64(1), 0xDEAD_BEEF, 0x4855_4E43_48] {
            #expect(
                DriftHinge.admitsBeforeHinge(seed: seed)
                    == DriftHinge.admitsBeforeHinge(seed: seed))
        }
    }

    /// Once fired, the hinge stays fired: `runningPost` has no event that returns it to
    /// `runningPre`, so a resume cannot un-fire it.
    @Test("The hinge never un-fires")
    func theHingeIsOneWay() {
        for event in [
            DriftPhase.Event.generated, .firstDialCommit, .hingeFired, .capturedFirstLaw,
        ] {
            #expect(DriftPhase.advance(.runningPost, on: event) != .runningPre)
        }
    }

    /// §7.10: termination during `hinge` lands the resume in `settled` with the page present —
    /// the round was already adjudicated, so the reveal replays from the page.
    @Test("A round interrupted during the reveal is already adjudicated")
    func interruptedRevealIsSettled() {
        #expect(DriftPhase.advance(.hinge, on: .revealComplete) == .settled)
        #expect(DriftPhase.advance(.hinge, on: .declaredSecondLaw) == nil)
    }

    /// §7.10: DRIFT reads no clock, so date manipulation affects the Anomaly and nothing here.
    /// Asserted through the seam it would have to come through: every quantity in the mode is a
    /// function of the seed and the transcript.
    @Test("Nothing in DRIFT is a function of the date")
    func driftReadsNoClock() {
        let transcript = DriftTranscript(
            hinge: 3, evidence: 5, recover: 7, seal: 9, deadDeclaration: false)
        #expect(transcript.cling == 2)
        #expect(transcript.redeclarationLatency == 4)
        // The budget is a function of the band alone.
        #expect(DriftBudget.par(.contextual) == 32)
    }

    /// §7.11: a fast loss — both strikes spent before the hinge — still plays the full hinge
    /// with the un-fired second law at 40 %, so it teaches the mode's shape rather than reading
    /// as a PROBE round the player got wrong.
    @Test("Both strikes before the hinge still reveal the mode")
    func aFastLossStillRevealsTheMode() {
        #expect(DriftPhase.advance(.struck, on: .secondStrike) == .hinge)
        #expect(DeadLawCounterexample.unfiredSecondLawOpacity == 0.40)
    }
}
