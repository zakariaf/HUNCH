import Testing

import Bench
import Feedback
import Glyphs
import LawGeneration
import Laws
import LoomFeature
import ModulesTestSupport
import Rounds

/// §4.5's judgement and §4.5's two strikes. The property that matters most is the one a
/// syntactic comparison would fail: a player who spells the same law differently is **right**.
@Suite("Declaring", .tags(.unit, .presubmission))
@MainActor
struct DeclarationTests {

    /// `shape ∈ {triangle}` spelled as the complement of the other three. Same extension,
    /// different AST, different tile arrangement — and §4.5 says purely semantic.
    private static let equivalentSpelling = Law(
        .atom(.init(attribute: .shape, subset: Fixtures.subset(0b0010))))

    @Test("A barred Seal moves nothing and says nothing")
    func barredSealIsSilent() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)
        round.openBench()

        #expect(round.isSealBarred)
        #expect(round.seal() == .empty)
        #expect(round.phase == .declaring)
        #expect(round.strikes == 0)
        #expect(recorder.cues.isEmpty)  // no error text, no error state, and no error sound
    }

    /// The Bench's one genuine over-reach (§4.4): a draft whose extension is constant. The Assay
    /// is already showing it as all-lit; the bar is the same fact on the key.
    @Test("A constant draft is barred")
    func constantDraftIsBarred() {
        let round = Fixtures.round()
        round.setBenchDraft(
            Law(
                .coupled(
                    .atom(.init(attribute: .shape, subset: Fixtures.subset(0b0111))), .or,
                    .atom(.init(attribute: .shape, subset: Fixtures.subset(0b1100))))))
        #expect(round.sealBarReason == .constantExtension)
        #expect(round.assay.isTautology)
    }

    /// §4.5's whole claim. Rejecting an equivalent phrasing would punish the player for the
    /// grammar rather than for the induction.
    @Test("Spelling does not matter — extension equality decides")
    func spellingIsIrrelevant() {
        let round = Fixtures.round()
        round.setBenchDraft(Self.equivalentSpelling)
        #expect(round.seal() == nil)
        #expect(round.phase == .sealing)

        round.resolveSeal()
        #expect(round.strikes == 0)
        #expect(round.phase == .revealing(.inscribed(marks: round.marks, fracture: false)))
        round.endReveal()
        #expect(round.outcome?.isInscribed == true)
    }

    /// §6.8: the hold is **verdict-blind** — identical in content and duration either way, so
    /// the answer is not readable off the clock.
    @Test("The sealing hold is the same phase whatever the verdict")
    func theHoldIsVerdictBlind() {
        let right = Fixtures.round()
        right.setBenchDraft(Self.equivalentSpelling)
        right.seal()

        let wrong = Fixtures.round()
        wrong.setBenchDraft(Fixtures.contextualLaw)
        wrong.seal()

        #expect(right.phase == .sealing)
        #expect(wrong.phase == .sealing)
        #expect(right.phase == wrong.phase)
    }

    /// Two strikes, overruling the brief: a counterexample is pedagogically worthless if you
    /// cannot act on it. The first wrong declaration reveals one and the round **continues**.
    @Test("The first strike reveals a counterexample and the round continues")
    func firstStrikeContinues() {
        let round = Fixtures.round()
        round.probe(Deck.glyph(id: 0))
        round.endVerdictBeat()
        round.setBenchDraft(Fixtures.contextualLaw)

        round.seal()
        round.resolveSeal()

        #expect(round.strikes == 1)
        #expect(round.phase == .counterexample)
        #expect(round.counterexample != nil)
        #expect(round.outcome == nil)

        round.dismissCounterexample()
        #expect(round.phase == .probing)
        #expect(round.canDeclare)
        #expect(round.probesUsed == 1)  // the probe count keeps running
    }

    @Test("The second strike ends the round and a third declaration is impossible")
    func secondStrikeEndsIt() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.contextualLaw)

        round.seal()
        round.resolveSeal()
        round.dismissCounterexample()

        round.seal()
        round.resolveSeal()
        #expect(round.strikes == 2)
        #expect(round.phase == .revealing(.broken))

        round.endReveal()
        #expect(round.outcome == .broken)
        #expect(round.canDeclare == false)
        #expect(round.seal() == .empty)  // terminal: `settled` has no outgoing row in §6.1
        #expect(round.strikes == 2)
    }

    /// A round won after a strike is **fractured**: it scores, and the page carries the mark.
    @Test("A correct declaration after a strike is inscribed with a fracture")
    func fractureIsRecorded() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.contextualLaw)
        round.seal()
        round.resolveSeal()
        round.dismissCounterexample()

        round.setBenchDraft(Self.equivalentSpelling)
        round.seal()
        round.resolveSeal()
        #expect(round.phase == .revealing(.inscribed(marks: round.marks, fracture: true)))
    }

    /// §4.5: one glyph, never the law — and preferring a false negative targets the most common
    /// human error, the over-narrow hypothesis.
    @Test("The counterexample is a glyph the two laws disagree about")
    func theCounterexampleDisagrees() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.contextualLaw)
        round.seal()
        round.resolveSeal()

        let choice = round.counterexample
        #expect(choice != nil)
        if let choice {
            let previous = choice.previous ?? round.seedGlyph
            #expect(
                round.law.admits(choice.current, after: previous)
                    != Fixtures.contextualLaw.admits(choice.current, after: previous))
        }
    }

    /// §6.11 case 11: the Seal is edge-triggered and never queues. A queued second declaration
    /// would spend the round's second strike on a press made before the first one resolved.
    @Test("The Seal is refused while the input lock is held")
    func theSealDoesNotQueue() {
        let round = Fixtures.round()
        round.setBenchDraft(Self.equivalentSpelling)
        round.probe(Fixtures.seedGlyph)  // locks the gate

        #expect(round.seal() == .empty)
        #expect(round.phase != .sealing)
        #expect(round.strikes == 0)
    }
}

/// §6.8's two decisions about what a strike must *not* do. Both are about protecting the
/// player's own context from their failure.
@Suite("What a strike does not touch", .tags(.unit, .presubmission))
@MainActor
struct StrikeConsequenceTests {

    /// The counterexample is **not a probe**: it does not increment the count, and it does not
    /// become `prev`. A player's carefully arranged context has nothing to do with the law they
    /// got wrong.
    @Test("A strike leaves the probe count and the context untouched")
    func theCounterexampleIsNotAProbe() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        round.probe(Deck.glyph(id: 40))
        round.endVerdictBeat()
        let context = round.previousGlyph
        let used = round.probesUsed

        round.setBenchDraft(Fixtures.openingLaw)
        round.seal()
        round.resolveSeal()
        round.dismissCounterexample()

        #expect(round.counterexample != nil)
        #expect(round.probesUsed == used)
        #expect(round.previousGlyph == context)
        #expect(round.ribbon.probes.count == used)
    }

    /// §6.8: the Bench auto-collapses and there is **no forced probe** before re-declaring.
    /// Evidence is acted on by probing, so return the player to the Dial — but a player who
    /// reads their error straight off the counterexample has done the reasoning, and a
    /// mandatory-probe gate would be another rule taught by refusal.
    @Test("After a strike the Bench collapses and the player may declare again immediately")
    func noForcedProbeBeforeRedeclaring() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.contextualLaw)
        round.seal()
        round.resolveSeal()
        round.dismissCounterexample()

        #expect(round.phase == .probing)  // the Dial, not the Bench
        #expect(round.probesUsed == 0)

        round.setBenchDraft(Fixtures.subsetLaw)
        #expect(round.seal() == nil)  // no gate, no forced probe
    }

    /// The draft survives a strike: the player edits what they had rather than rebuilding it.
    @Test("The Bench draft survives the strike")
    func draftSurvivesAStrike() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.contextualLaw)
        round.seal()
        round.resolveSeal()
        round.dismissCounterexample()
        #expect(round.benchDraft == Fixtures.contextualLaw)
    }
}
