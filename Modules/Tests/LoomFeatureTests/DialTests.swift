import Testing

import Glyphs
import LoomFeature
import ModulesTestSupport

/// §4.1's three mitigations, which are what make the modal probe one or two taps: the Dial
/// retains the last probe, a ribbon tile loads wholesale, and the twin key re-feeds the throat.
/// All three are model behaviour and are asserted here with no view in sight.
@Suite("The Dial composes, retains and adopts", .tags(.unit, .presubmission))
@MainActor
struct DialTests {

    @Test("At probe 0 the Dial is preloaded with the seed glyph, so probe 1 is one tap")
    func preloadedWithTheSeed() {
        let round = Fixtures.round()
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.probesUsed == 0)
    }

    @Test("Single-select: a tap moves that ramp's selection and nothing else")
    func singleSelectMovesOneRamp() {
        let round = Fixtures.round()
        let before = round.draft
        round.select(.shape, rank: 4)
        #expect(round.draft.shape.rank == 4)
        #expect(round.draft.fill == before.fill)
        #expect(round.draft.pips == before.pips)
        #expect(round.draft.hue == before.hue)
        #expect(round.lastTouched == .shape)
    }

    @Test("The Dial retains the last probe: the default action is a minimal edit")
    func retainsTheLastProbe() {
        let round = Fixtures.round()
        let probed = Deck.glyph(id: 137)
        round.select(.fill, rank: probed.fill.rank)
        round.select(.shape, rank: probed.shape.rank)
        round.select(.pips, rank: probed.pips.rank)
        round.select(.hue, rank: probed.hue.rank)

        round.probeDraft()
        round.endVerdictBeat()

        // Still there — one tap away from the next experiment.
        #expect(round.draft == probed)
    }

    @Test("Ribbon-load adopts a glyph wholesale and leaves the last-touched attribute alone")
    func ribbonLoadAdoptsWholesale() {
        let round = Fixtures.round()
        round.select(.hue, rank: 3)
        round.probeDraft()
        round.endVerdictBeat()
        round.select(.fill, rank: 2)
        let touched = round.lastTouched

        round.load(ribbonIndex: 0)  // index 0 is the seed tile

        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.lastTouched == touched)  // nothing was *touched* — DECISIONS 44
        #expect(round.changedRegister == nil)  // wholesale is not a single-register edit
        #expect(round.loadedIndex == 0)
    }

    @Test("Probe n is ribbon index n, because index 0 is the seed")
    func probesFollowTheSeedInTheIndex() {
        let round = Fixtures.round()
        let first = Deck.glyph(id: 3)
        round.probe(first)
        round.endVerdictBeat()

        round.load(ribbonIndex: 1)
        #expect(round.draft == first)
        round.load(ribbonIndex: 0)
        #expect(round.draft == Fixtures.seedGlyph)
    }

    @Test("Loading out of range is a no-op, not a crash")
    func outOfRangeLoadIsIgnored() {
        let round = Fixtures.round()
        let before = round.draft
        round.load(ribbonIndex: 99)
        round.load(ribbonIndex: -1)
        #expect(round.draft == before)
        #expect(round.loadedIndex == nil)
    }

    /// The ribbon's `loaded` state has to stop being true the moment the Dial stops showing
    /// that tile, or the ribbon points at a tile the throat no longer holds.
    @Test("Any edit clears the loaded tile")
    func editingClearsTheLoadedIndex() {
        let round = Fixtures.round()
        round.load(ribbonIndex: 0)
        #expect(round.loadedIndex == 0)
        round.select(.pips, rank: 4)
        #expect(round.loadedIndex == nil)
    }
}
