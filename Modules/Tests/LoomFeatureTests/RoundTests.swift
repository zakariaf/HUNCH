import Testing

import Glyphs
import LawGeneration
import Laws
import LoomFeature
import ModulesTestSupport
import Rounds

/// `Round` is allowed to exist because §6.1's machine has to be somewhere a view can watch it.
/// These tests are the receipt for the other half of that bargain: everything it does is a
/// delegation, and every expectation below is written against `HunchCore`'s answer rather than
/// against a number copied out of the design.
@Suite("Round — the screen-scoped machine", .tags(.unit, .presubmission))
@MainActor
struct RoundTests {

    @Test("A fresh round is probing, empty, and already holding the seed glyph")
    func freshRound() {
        let round = Fixtures.round()
        #expect(round.phase == .probing)
        #expect(round.probesUsed == 0)
        #expect(round.ribbon.probes.isEmpty)
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.strikes == 0)
        #expect(round.outcome == nil)
    }

    @Test("The verdict is committed synchronously, at t = 0 of the beat")
    func verdictCommitsBeforeAnyAnimation() {
        let round = Fixtures.round()
        let triangle = Deck.glyph(id: 22)

        round.probe(triangle)

        // The model never waits on an animation (§6.1). One statement later the probe is in.
        #expect(round.probesUsed == 1)
        #expect(round.ribbon.probes.count == 1)
        #expect(round.ribbon.probes[0].glyph == triangle)
        let expected = Verdict(
            admits: Fixtures.openingLaw.admits(triangle, after: Fixtures.seedGlyph))
        #expect(round.ribbon.probes[0].verdict == expected)
        #expect(round.phase == .adjudicating(expected))
    }

    @Test("`prev` is the previously probed glyph, regardless of that probe's verdict")
    func previousIsTheLastProbedGlyph() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        let first = Deck.glyph(id: 0)
        let second = Deck.glyph(id: 200)

        round.probe(first)
        round.endVerdictBeat()
        round.probe(second)

        let law = Fixtures.contextualLaw
        #expect(
            round.ribbon.probes[0].verdict
                == Verdict(admits: law.admits(first, after: Fixtures.seedGlyph)))
        #expect(
            round.ribbon.probes[1].verdict == Verdict(admits: law.admits(second, after: first)))
        // `first` was rejected — `pips(0) > pips(seed)` is false — and is `prev` all the same.
        #expect(round.ribbon.probes[0].verdict == .reject)
        #expect(round.previousGlyph == second)
    }

    @Test("Score and marks are read from HunchCore, never recomputed on the screen")
    func scoringDelegates() {
        let round = Fixtures.round()
        for _ in 0..<3 {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        #expect(
            round.score
                == Scoring.score(probesUsed: round.probesUsed, par: round.par, strikes: 0))
        #expect(
            round.marks
                == Scoring.marks(probesUsed: round.probesUsed, par: round.par, cap: round.cap))
    }

    @Test(
        "The cap-th verdict resolves in full, then the round is exhausted",
        arguments: [Band.literal, Band.contextual, Band.systemic])
    func capEndsTheRoundAfterTheVerdict(_ band: Band) {
        let round = Fixtures.round(band: band)

        for index in 0..<round.cap {
            round.probe(Deck.glyph(id: index % 256))
            // A paid-for bit is never withheld: the cap-th probe is recorded like any other.
            #expect(round.ribbon.probes.count == index + 1)
            #expect(round.phase == .adjudicating(round.ribbon.probes[index].verdict))
            round.endVerdictBeat()
        }

        #expect(round.probesUsed == round.cap)
        #expect(round.phase == .revealing(.exhausted))
        #expect(round.outcome == .exhausted)
    }

    @Test("Probing is refused once the round has left `probing`")
    func probingIsRefusedOutsideProbing() {
        let round = Fixtures.round(band: .literal)
        for _ in 0..<round.cap {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        let settled = round.probesUsed

        #expect(round.probe(Fixtures.seedGlyph) == nil)
        #expect(round.probesUsed == settled)
    }

    /// The input lock is a *refused probe*, not a disabled button: the beat only sets a phase,
    /// so if the model accepted a tap here every animation would be a race. §6.5 honours ONE
    /// such tap at the unlock — the single slot is `InputGate`'s and is tested there; this is
    /// the round-level consequence, which is that the probe count never moves early.
    @Test("A probe arriving inside the adjudication beat waits for the unlock")
    func probeInsideTheBeatIsQueued() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)

        #expect(round.probe(Deck.glyph(id: 7)) == nil)  // not refused — deferred
        #expect(round.probesUsed == 1)
        #expect(round.acceptsInput == false)

        round.endVerdictBeat()
        // The queued tap opened its own beat, so input is locked again and the probe is in.
        #expect(round.probesUsed == 2)
        #expect(round.ribbon.probes[1].glyph == Deck.glyph(id: 7))
        #expect(round.acceptsInput == false)

        round.endVerdictBeat()
        #expect(round.acceptsInput)
    }

    /// §6.11 case 3: the twin is the most informative probe in the game under
    /// previously-probed semantics, so it is never blocked and never refunded.
    @Test("A twin is a probe like any other — never blocked, never refunded")
    func twinIsNeverBlocked() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        round.probeDraft()
        round.endVerdictBeat()
        let after = round.probeTwin()

        #expect(after != nil)
        #expect(round.probesUsed == 2)
        #expect(round.ribbon.probes[1].isTwin)
        #expect(round.ribbon.probes[0].glyph == round.ribbon.probes[1].glyph)
    }

    /// §6.3: the throat survives its own probe, which is what makes a twin one tap and a
    /// controlled variation one flick.
    @Test("The draft survives a probe, and a ribbon-load replaces it wholesale")
    func draftSurvivesAProbe() {
        let round = Fixtures.round()
        let glyph = Deck.glyph(id: 99)

        round.probe(glyph)
        #expect(round.draft == glyph)

        round.endVerdictBeat()
        round.setDraft(Fixtures.seedGlyph)
        #expect(round.draft == Fixtures.seedGlyph)
    }

    @Test("The throat cannot be edited while input is locked")
    func draftIsLockedWithTheInput() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        round.setDraft(Deck.glyph(id: 3))
        #expect(round.draft == Fixtures.seedGlyph)
    }

    /// §6.10: below one probe there is no round to settle. Abandoning at probe 0 must not
    /// inscribe a loss-shaped row for a round that produced no evidence.
    @Test("Abandoning before probe 1 is not a transition at all")
    func abandoningAtProbeZeroSettlesNothing() {
        let round = Fixtures.round()
        round.abandon()
        #expect(round.phase == .probing)
        #expect(round.outcome == nil)

        round.probe(Fixtures.seedGlyph)
        round.endVerdictBeat()
        round.abandon()
        #expect(round.outcome == .abandoned)
    }

    /// §6.9's par crossing — the round's one non-verdict event. Read off the probe count, so
    /// it cannot drift away from the ribbon the way a stored flag would.
    @Test("The par crossing is read from the probe count")
    func parCrossingIsDerived() {
        let round = Fixtures.round()
        #expect(round.par == Band.literal.par)

        for _ in 0..<round.par {
            #expect(round.hasCrossedPar == false)
            #expect(round.probesPastPar == 0)
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }

        #expect(round.hasCrossedPar)
        round.probe(Fixtures.seedGlyph)
        #expect(round.probesPastPar == 1)
        #expect(round.probesRemaining == round.cap - round.par - 1)
    }
}
