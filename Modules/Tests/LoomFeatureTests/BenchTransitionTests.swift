import Testing

import Glyphs
import HunchUI
import LoomFeature
import ModulesTestSupport
import Rounds
import Tokens

/// §6.7's three equivalent entries, its zero cost, and the one thing it promises about the
/// draft: backing out preserves it **verbatim**.
@Suite("Entering and leaving the Bench", .tags(.unit, .presubmission))
@MainActor
struct BenchTransitionTests {

    @Test("The Bench is available from probe 0, with no gate")
    func availableFromProbeZero() {
        let round = Fixtures.round()
        round.openBench()
        #expect(round.phase == .declaring)
        #expect(round.probesUsed == 0)
    }

    /// §6.7: opening, editing, expanding and closing all cost zero probes. The Bench is a place
    /// to think, and a place to think that costs evidence is a place nobody thinks in.
    @Test("Opening and closing costs nothing")
    func costsNothing() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        round.endVerdictBeat()
        let spent = round.probesUsed

        for _ in 0..<5 {
            round.openBench()
            round.closeBench()
        }
        #expect(round.probesUsed == spent)
    }

    /// §6.7: "the draft is preserved verbatim". A player opens the Bench *to test a specific
    /// draft*, so discarding it on the way back would make the trip pointless.
    @Test("Backing out preserves the draft verbatim")
    func draftSurvivesTheRoundTrip() {
        let round = Fixtures.round()
        round.select(.pips, rank: 4)
        round.select(.hue, rank: 2)
        let draft = round.draft
        let touched = round.lastTouched

        round.openBench()
        round.closeBench()

        #expect(round.draft == draft)
        #expect(round.lastTouched == touched)
        #expect(round.acceptsInput)
    }

    /// §6.1: `declaring` is an open-input phase. The Bench is not a modal that locks the round.
    @Test("The Bench is an open-input phase")
    func benchAcceptsInput() {
        let round = Fixtures.round()
        round.openBench()
        #expect(round.acceptsInput)
    }

    /// The Bench cannot be opened inside the verdict beat: §6.1 has no `adjudicating →
    /// declaring` row, and a Bench that opened over a landing verdict would hide the evidence
    /// the player just paid for.
    @Test("The Bench cannot be opened during the verdict beat")
    func refusedInsideTheBeat() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        round.openBench()
        #expect(round.phase != .declaring)
    }
}

/// §13.7.3's drag, as a value: follows the finger, resolves by velocity, and is *replaced*
/// rather than shortened under Reduce Motion.
@Suite("The Bench drawer", .tags(.unit, .presubmission))
struct BenchDrawerTests {

    @Test("The drawer follows the finger rather than a Bool")
    func followsTheFinger() {
        var drawer = BenchDrawer()
        #expect(drawer.progress == 0)
        drawer.dragOffset = -C.Bench.travel / 2
        #expect(abs(drawer.progress - 0.5) < 0.001)
        drawer.dragOffset = -C.Bench.travel * 2
        #expect(drawer.progress == 1)  // clamped, never rubber-banded past its own travel
    }

    /// A flick and a slow drag are both "open" and neither is the other: the flick threshold is
    /// a third of the travel on *predicted* end, the drag threshold half of it on actual.
    @Test("A flick commits at a third of the travel; a slow drag needs half")
    func resolvesByVelocity() {
        #expect(
            BenchDrawer.resolves(
                translation: -20, predictedEnd: -C.Bench.travel * 0.4, isOpen: false))
        #expect(
            BenchDrawer.resolves(translation: -20, predictedEnd: -20, isOpen: false) == false)
        #expect(
            BenchDrawer.resolves(
                translation: -C.Bench.travel * 0.6, predictedEnd: -C.Bench.travel * 0.6,
                isOpen: false))
    }

    @Test("Closing resolves in the opposite direction")
    func closingIsSymmetric() {
        #expect(
            BenchDrawer.resolves(
                translation: 20, predictedEnd: C.Bench.travel * 0.4, isOpen: true))
        #expect(
            BenchDrawer.resolves(
                translation: -C.Bench.travel, predictedEnd: -C.Bench.travel, isOpen: true)
                == false)
    }

    /// §13.7.4: the gesture is **replaced**, not shortened. A 40 ms drag is still a drag and is
    /// the named failure mode — the motion is there, just too fast to read.
    @Test("Reduce Motion replaces the gesture with a button")
    func reduceMotionReplacesTheGesture() {
        #expect(BenchDrawer.affordance(reduceMotion: false) == .drag)
        #expect(BenchDrawer.affordance(reduceMotion: true) == .button)
        // The tap clock is not the drag's settle, and neither is a copy of the other.
        #expect(C.Bench.tapTransition == .milliseconds(380))
        #expect(Dur.sheet == .milliseconds(320))
        #expect(C.Bench.tapTransition != Dur.sheet)
    }
}
