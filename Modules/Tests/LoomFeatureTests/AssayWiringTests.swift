import Testing

import Bench
import Glyphs
import Laws
import LoomFeature
import ModulesTestSupport
import Rounds

/// The Assay draws the player's **draft**. The one failure this component can have that no
/// screenshot would catch is drawing the *hidden law* instead — which is not a rendering bug but
/// the whole answer, handed over in one picture, on the surface the player is meant to reason on.
@Suite("The Assay is wired to the draft, never to the law", .tags(.unit, .presubmission))
@MainActor
struct AssayWiringTests {

    @Test("With no draft the constellation is all dark, and that is the truth")
    func emptyBenchIsUnsatisfiable() {
        let round = Fixtures.round()
        #expect(round.benchDraft == nil)
        #expect(round.assay.isUnsatisfiable)
        // An empty Bench admits nothing, and the Seal is barred for exactly that (§4.3) — so
        // the all-dark grid is not a placeholder standing in for "nothing yet".
        #expect(round.assay.litCount == 0)
    }

    /// The regression that matters. `openingLaw` admits 64 of the 256 glyphs; if the Assay ever
    /// quoted `round.law` this would light 64 cells with no draft on the Bench at all.
    @Test("The hidden law never reaches the Assay")
    func theLawIsNotTheDraft() {
        let round = Fixtures.round()
        #expect(Assay.live(for: round.law, pinned: round.seedGlyph).litCount == 64)
        #expect(round.assay.litCount == 0)

        round.setBenchDraft(Fixtures.contextualLaw)
        #expect(round.assay.litCount != 64)
        #expect(round.assay.lit == Fixtures.contextualLaw.table.row(after: round.assayPin))
    }

    @Test("The pin defaults to the seed glyph and scrubs to any of the 256")
    func thePinDefaultsToTheSeed() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        #expect(round.assayPin == Fixtures.seedGlyph)

        round.setBenchDraft(Fixtures.contextualLaw)
        let atSeed = round.assay.litCount
        round.pinAssay(to: Deck.glyph(id: 12))
        #expect(round.assayPin == Deck.glyph(id: 12))
        #expect(round.assay.litCount != atSeed)  // the constellation morphs — §4.3's whole point
    }

    /// §4.3's gate, at the round level: the overlay is empty below band 4 even when a draft is
    /// on the Bench and the transcript disagrees with it.
    @Test("The evidence overlay is silent below band 4")
    func evidenceIsGatedByBand() {
        let low = Fixtures.round(band: .literal)
        low.probe(Fixtures.seedGlyph)
        low.endVerdictBeat()
        low.setBenchDraft(Fixtures.contextualLaw)
        #expect(low.assayEvidence.probed.isEmpty)

        let high = Fixtures.round(band: .relational)
        high.probe(Fixtures.seedGlyph)
        high.endVerdictBeat()
        high.setBenchDraft(Fixtures.contextualLaw)
        #expect(high.assayEvidence.probed.isEmpty == false)
    }

    /// The overlay reads the transcript row by row: probe *n*'s context is probe *n−1*'s glyph,
    /// and the seed's for probe 1. Getting that chain wrong flashes contradictions the player
    /// never created.
    @Test("The overlay walks the transcript's own context chain")
    func evidenceFollowsTheContextChain() {
        let round = Fixtures.round(band: .relational)
        let first = Deck.glyph(id: 3)
        round.probe(first)
        round.endVerdictBeat()
        round.probe(Deck.glyph(id: 9))
        round.endVerdictBeat()
        round.setBenchDraft(Fixtures.openingLaw)

        // Pinned at the seed, only probe 1 was judged in this row.
        #expect(round.assayEvidence.probed.count == 1)
        #expect(round.assayEvidence.probed.contains(first.id))

        // Pinned at probe 1's glyph, only probe 2 was.
        round.pinAssay(to: first)
        #expect(round.assayEvidence.probed.count == 1)
        #expect(round.assayEvidence.probed.contains(Deck.glyph(id: 9).id))
    }
}
