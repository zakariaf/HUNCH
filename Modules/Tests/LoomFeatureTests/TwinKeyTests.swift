import Testing

import Glyphs
import LawGeneration
import Laws
import LoomFeature
import ModulesTestSupport
import Rounds

/// §4.1's third mitigation, and the experiment that detects statefulness at all: same glyph,
/// different verdict. Everything about the twin key is what it *does not* do — no guard, no
/// refund, no cooldown, no cap exemption.
@Suite("The twin key", .tags(.unit, .presubmission))
@MainActor
struct TwinKeyTests {

    @Test("Twin re-feeds the throat glyph unchanged and costs exactly one probe")
    func twinRefeedsTheDraft() {
        let round = Fixtures.round()
        round.select(.hue, rank: 4)
        let draft = round.draft

        round.probe(draft)
        round.landVerdict()
        round.endVerdictBeat()
        round.probeTwin()

        #expect(round.probesUsed == 2)
        #expect(round.ribbon.probes[1].glyph == draft)
        #expect(round.draft == draft)  // unchanged: the twin does not edit
        #expect(round.ribbon.probes[1].isTwin)
    }

    /// §6.3's "probe 1 defaults to a twin-of-seed" and §6.11 case 2's "the seed never gains a
    /// verdict ring" reconcile here: the *default action* is a twin of the seed; the *ribbon
    /// marking* needs two adjacent probes, and the seed is not one.
    @Test("Twin at probe 0 probes the seed glyph and is not marked as a twin")
    func twinAtProbeZero() {
        let round = Fixtures.round()
        round.probeTwin()
        #expect(round.probesUsed == 1)
        #expect(round.ribbon.probes[0].glyph == Fixtures.seedGlyph)
        #expect(round.ribbon.probes[0].isTwin == false)  // no adjacent *probe* to be a twin of
    }

    @Test("Twin is never blocked and never refunded — there is no repeat guard")
    func noRepeatGuard() {
        let round = Fixtures.round()
        for expected in 1...5 {
            round.probeTwin()
            #expect(round.probesUsed == expected)
            round.landVerdict()
            round.endVerdictBeat()
        }
        #expect(round.isTwinAvailable)  // still live after five in a row
    }

    @Test("The twin key is available in every band, from probe 0", arguments: Band.allCases)
    func availableEverywhere(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.isTwinAvailable)
    }

    @Test("A twin shares the single input slot with the PROBE key")
    func twinUsesTheSameQueue() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)  // locks
        round.probeTwin()  // queued
        round.probeTwin()  // dropped
        round.landVerdict()
        round.endVerdictBeat()
        #expect(round.probesUsed == 2)
    }

    @Test("The twin stops being available once the cap is spent")
    func unavailableAtTheCap() {
        let round = Fixtures.round()
        while round.probesUsed < round.cap {
            round.probeTwin()
            round.endVerdictBeat()
        }
        #expect(round.isTwinAvailable == false)
        #expect(round.probeTwin() == nil)
        #expect(round.probesUsed == round.cap)
    }
}

/// §6.6 layer 3. A predicate over the probe count, not a timer — so it cannot drift with the
/// frame rate, needs no clock to test, and cannot be observed to differ between bands.
@Suite("The breath", .tags(.unit, .presubmission))
@MainActor
struct BreathTests {

    @Test("It fires past 0.6·par on the same rule in every band", arguments: Band.allCases)
    func sameRuleEveryBand(_ band: Band) {
        let round = Fixtures.round(band: band)
        let threshold = Int((Scoring.threeMarkFraction * Double(band.par)).rounded(.down))

        while round.probesUsed < threshold {
            round.probe(Deck.glyph(id: round.probesUsed % 256))
            round.landVerdict()
            round.endVerdictBeat()
            #expect(round.isBreathing == false)
        }
        round.probe(Deck.glyph(id: 9))
        round.landVerdict()
        round.endVerdictBeat()
        #expect(round.isBreathing)
    }

    /// It stops on first *use*, not on first success: its job is to teach that the key exists,
    /// and pressing it has done that whatever the verdict was.
    @Test("It stops permanently on first use, and does not come back")
    func stopsForever() {
        let round = Fixtures.round(band: .literal)
        while !round.isBreathing, round.probesUsed < round.cap - 2 {
            round.probe(Deck.glyph(id: 3))
            round.landVerdict()
            round.endVerdictBeat()
        }
        #expect(round.isBreathing)

        round.probeTwin()
        #expect(round.isBreathing == false)
        round.landVerdict()
        round.endVerdictBeat()
        #expect(round.isBreathing == false)
    }

    /// Latched on the press: a player who presses twin and immediately backgrounds the app must
    /// not find the hint waiting for them again on resume.
    @Test("The latch is on the press, not on the verdict")
    func latchedOnThePress() {
        let round = Fixtures.round(band: .literal)
        while !round.isBreathing {
            round.probe(Deck.glyph(id: 3))
            round.endVerdictBeat()
        }
        round.probeTwin()  // pressed; the beat has not landed
        #expect(round.isBreathing == false)
    }

    /// The rule is the *same* in every band, which is what stops it leaking contextuality — a
    /// breath that only appeared at bands 5 and 7 would announce the family for free.
    @Test("The threshold is the three-mark fraction and comes from HunchCore")
    func thresholdIsScoringS() {
        for band in Band.allCases {
            let threshold = Scoring.threeMarkFraction * Double(band.par)
            #expect(
                Round.breathes(
                    probesUsed: Int(threshold.rounded(.down)), par: band.par,
                    twinEverUsed: false) == false)
            #expect(
                Round.breathes(
                    probesUsed: Int(threshold.rounded(.down)) + 1, par: band.par,
                    twinEverUsed: false))
        }
    }
}
