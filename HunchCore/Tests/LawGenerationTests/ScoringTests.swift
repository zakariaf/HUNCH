import Testing

import Glyphs

import HunchTestSupport
import LawGeneration
import Laws

/// §6.9 works three rounds arithmetically and states what each must score. Reproducing all
/// three is what makes the formula a transcription rather than an interpretation.
@Suite("Scoring", .tags(.unit, .presubmission))
struct ScoringTests {
    /// §6.9's round A — great: band 5, one declaration at probe 13, correct.
    @Test("Round A — 13 probes against par 23, no strike: 1000 and 3 marks")
    func roundA() {
        #expect(Scoring.score(probesUsed: 13, par: 23, strikes: 0) == 1000)
        #expect(Scoring.marks(probesUsed: 13, par: 23, cap: 37) == 3)  // 0.6 × 23 = 13.8
    }

    /// §6.9's round B — average: band 4, a strike at 17, correct at 24.
    @Test("Round B — 24 probes against par 20 with a strike: 500 and 1 mark")
    func roundB() {
        #expect(Scoring.score(probesUsed: 24, par: 20, strikes: 1) == 500)
        #expect(Scoring.marks(probesUsed: 24, par: 20, cap: 32) == 1)
    }

    /// §6.9's round C — bad: band 6, two strikes, no page.
    @Test("Round C — a second strike scores exactly 0, with no consolation")
    func roundC() {
        // The outcome, not the arithmetic, is what zeroes it: only .inscribed scores.
        let outcome = Scoring.Outcome.broken
        #expect(outcome != .inscribed(marks: 1, fracture: true))
    }

    /// The flat region is deliberate (§6.9), and it is what "probe economy rewarded without
    /// punishing careful play" actually means: the cost curve begins only where the budget ends.
    @Test("The gradient is flat below par and decays only past it")
    func flatBelowPar() {
        for probes in 1...23 {
            #expect(Scoring.score(probesUsed: probes, par: 23, strikes: 0) == 1000)
        }
        #expect(Scoring.score(probesUsed: 24, par: 23, strikes: 0) < 1000)
        #expect(Scoring.score(probesUsed: 46, par: 23, strikes: 0) == 500)
    }

    /// §6.9's decision: the middle threshold does NOT move in to 0.85·par. Pulling it in
    /// re-taxes exactly the careful play the flat gradient protects, and worst at band 8 —
    /// probe 24 of a 29 budget would lose a mark for spending the budget you were given.
    @Test("The mark thresholds are 0.6·par / par / cap, and the middle one does not move")
    func markThresholds() {
        for band in Band.allCases {
            let par = band.par
            let third = Int((0.6 * Double(par)).rounded(.down))
            #expect(Scoring.marks(probesUsed: third, par: par, cap: band.cap) == 3)
            #expect(Scoring.marks(probesUsed: par, par: par, cap: band.cap) == 2)
            #expect(Scoring.marks(probesUsed: par + 1, par: par, cap: band.cap) == 1)
            #expect(Scoring.marks(probesUsed: band.cap, par: par, cap: band.cap) == 1)
        }
        // Band 8 specifically: 24 of a 29 budget must still be 2 marks.
        #expect(Scoring.marks(probesUsed: 24, par: 29, cap: 47) == 2)
    }

    /// §6.11 edge case 1: a declaration at probe 0 must not divide by zero.
    @Test("A 0-probe declaration scores 1000 with 3 marks and never divides by zero")
    func zeroProbeDeclaration() {
        #expect(Scoring.score(probesUsed: 0, par: 7, strikes: 0) == 1000)
        #expect(Scoring.marks(probesUsed: 0, par: 7, cap: 12) == 3)
    }

    /// §6.9's anti-spam arithmetic: patient play is worth 728 expected, spam 391.
    @Test("Declaring early and often forfeits 46 % of expected score (§6.9)")
    func spammingIsDominated() {
        let firstDeclaration = 0.62
        let roundSuccess = 0.80
        let recovery = (roundSuccess - firstDeclaration) / (1 - firstDeclaration)
        expectApproximatelyEqual(recovery, 0.474, absoluteTolerance: 0.001)

        let patient = firstDeclaration * 1000 + (1 - firstDeclaration) * recovery * 600
        let spam = 0.03 * 1000 + 0.97 * firstDeclaration * 600
        expectApproximatelyEqual(patient, 728, absoluteTolerance: 1)
        expectApproximatelyEqual(spam, 391, absoluteTolerance: 1)
        #expect(spam < patient * 0.55)
    }

    @Test("The par crossing fires exactly once, on the probe that fills the last par tick")
    func parCrossing() {
        let par = 23
        let fired = (1...40).filter { Scoring.isParCrossing(probeIndex: $0, par: par) }
        #expect(fired == [23])
    }
}
