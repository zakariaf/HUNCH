import Testing

import Glyphs
import Laws
import LoomFeature
import ModulesTestSupport

/// §6.5's input policy, which is one of three clocks and the only one that gates a tap. The
/// other two — commit at t = 0, and decoration that outlives the lock by design — are asserted
/// elsewhere; the confusion between them is where the bugs in this area live.
@Suite("The 420 ms verdict beat", .tags(.unit, .presubmission))
struct VerdictBeatTests {

    @Test("The input lock is 420 ms, and 320 ms under Reduce Motion")
    func inputLock() {
        #expect(VerdictBeat(reduceMotion: false).inputLock == .milliseconds(420))
        #expect(VerdictBeat(reduceMotion: true).inputLock == .milliseconds(320))
    }

    @Test("The adjudication hold is 260 ms in both motion modes")
    func holdSurvivesReduceMotion() {
        #expect(VerdictBeat(reduceMotion: false).adjudicationHold == .milliseconds(260))
        #expect(VerdictBeat(reduceMotion: true).adjudicationHold == .milliseconds(260))
    }

    @Test("Travel is what is left of the lock, and compresses to 180 ms for a queued probe")
    func travel() {
        let beat = VerdictBeat(reduceMotion: false)
        #expect(beat.travel(queued: false) == beat.inputLock - beat.adjudicationHold)
        #expect(beat.travel(queued: true) == .milliseconds(180))
    }

    /// Reduce Motion shortens the *travel*, never the hold: the 260 ms is a legibility budget,
    /// not an animation, so it is the one part of the beat that must not move.
    @Test("Reduce Motion takes its 100 ms out of the travel")
    func reduceMotionShortensTravelOnly() {
        let plain = VerdictBeat(reduceMotion: false)
        let reduced = VerdictBeat(reduceMotion: true)
        #expect(reduced.adjudicationHold == plain.adjudicationHold)
        #expect(reduced.travel(queued: false) == plain.travel(queued: false) - .milliseconds(100))
    }

    /// §6.5's decision, asserted rather than trusted: *variable latency is a side channel*.
    @Test(
        "The hold does not depend on the verdict, the band, or whether the law is contextual",
        arguments: Band.allCases)
    func theHoldIsConstant(_ band: Band) {
        let beat = VerdictBeat(reduceMotion: false)
        for verdict in [Verdict.admit, .reject] {
            #expect(beat.adjudicationHold(for: verdict, band: band) == beat.adjudicationHold)
        }
    }

    /// The stronger version of the same claim: the type has nothing to condition on. An
    /// "optimisation" that made the hold depend on the law would have to widen this value
    /// first, which is a change nobody makes by accident.
    @Test("VerdictBeat is a function of the motion setting alone")
    func theBeatKnowsNothingElse() {
        #expect(VerdictBeat(reduceMotion: false) == VerdictBeat(reduceMotion: false))
        #expect(VerdictBeat(reduceMotion: false) != VerdictBeat(reduceMotion: true))
    }
}
