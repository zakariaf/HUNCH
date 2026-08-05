import Testing

import Glyphs
import HunchTestSupport

/// `Deck.all` is index-aligned with `Glyph.id`, and every mask, the Assay's 16×16 grid and
/// every brute-force walk in the project depends on that. The construction and the id are
/// built independently — `all` from the four `allCases`, `id` from a shift-and-or — so this
/// suite compares two derivations rather than restating one.
@Suite("Deck", .tags(.unit, .presubmission))
struct DeckTests {
    @Test("The deck is exactly 256 glyphs and never grows (§2, §5.7)")
    func deckSize() {
        #expect(Deck.all.count == 256)
    }

    @Test("all[i].id == i — the alignment every bitboard indexes by")
    func allIsIndexAligned() {
        for (index, glyph) in Deck.all.enumerated() {
            #expect(glyph.id == index)
        }
    }

    @Test("Every glyph appears exactly once")
    func deckIsAPermutation() {
        #expect(Set(Deck.all).count == 256)
    }

    @Test("glyph(id:) round-trips for all 256")
    func roundTrip() {
        for id in 0..<256 {
            #expect(Deck.glyph(id: id).id == id)
        }
    }

    @Test("The order is canonical fill → shape → pips → hue: hue varies fastest, fill slowest")
    func deckIsCanonicallyOrdered() {
        // Consecutive ids differ only in hue within a block of four.
        #expect(Deck.all[0].hue == .amber)
        #expect(Deck.all[1].hue == .teal)
        #expect(Deck.all[0].pips == Deck.all[1].pips)
        // Pips turns over every 4, shape every 16, fill every 64.
        #expect(Deck.all[4].pips != Deck.all[0].pips)
        #expect(Deck.all[16].shape != Deck.all[0].shape)
        #expect(Deck.all[64].fill != Deck.all[0].fill)
        #expect(Deck.all[63].fill == Deck.all[0].fill)
    }
}
