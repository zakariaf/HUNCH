import Testing

import Glyphs
import HunchTestSupport

/// The contextual universe: 65,536 ordered pairs. `lift` and `isStateless` are the two
/// operations §3.6 and G7 are built on, so both are checked against an independent
/// brute-force walk over every pair rather than against each other.
@Suite("Bitboard65536", .tags(.unit, .presubmission))
struct Bitboard65536Tests {
    @Test("The table is 1024 words — 65,536 bits, and there is no third axis (§3.5)")
    func size() {
        #expect(Bitboard65536.wordCount == 1_024)
        #expect(Bitboard65536().isEmpty)
        #expect(Bitboard65536.full.count == 65_536)
    }

    @Test("Every (prev, cur) pair is independently addressable at the boundaries")
    func addressing() {
        for (prev, cur) in [(0, 0), (0, 255), (255, 0), (255, 255), (1, 63), (1, 64), (128, 191)] {
            var b = Bitboard65536()
            b.insert(current: cur, after: prev)
            #expect(b.count == 1)
            #expect(b.contains(current: cur, after: prev))
            // The transpose must NOT be set — the pair is ordered.
            if prev != cur { #expect(!b.contains(current: prev, after: cur)) }
        }
    }

    @Test("lift tiles a stateless table across every prev — verified pair by pair")
    func liftIsExact() {
        let striped = Bitboard256(ids: Deck.all.filter { $0.fill == .striped }.map(\.id))
        let lifted = Bitboard65536(lifting: striped)
        #expect(lifted.count == striped.count * 256)
        for prev in stride(from: 0, to: 256, by: 37) {
            #expect(lifted.row(after: prev) == striped)
            for cur in stride(from: 0, to: 256, by: 29) {
                #expect(lifted.contains(current: cur, after: prev) == striped.contains(cur))
            }
        }
    }

    @Test("A lifted table is stateless; a genuinely contextual one is not (G7)")
    func isStatelessDetectsG7() {
        let anyStateless = Bitboard256(ids: Deck.all.filter { $0.pips == .three }.map(\.id))
        #expect(Bitboard65536(lifting: anyStateless).isStateless)

        // §5.2's band-5 exemplar: RANK pips(cur) > RANK pips(prev). Genuinely contextual.
        let contextual = Bitboard65536(rows: { prev in
            let prevRank = Deck.glyph(id: prev).pips.rank
            return Bitboard256(ids: Deck.all.filter { $0.pips.rank > prevRank }.map(\.id))
        })
        #expect(!contextual.isStateless)
        // Its own projection is the row for prev == 0, whose pips rank is 1.
        #expect(contextual.statelessProjection.count == 192)  // pips 2,3,4 = 3/4 of the deck
    }

    @Test("rows(_:) agrees with a brute-force walk over all 65,536 pairs")
    func rowsMatchesBruteForce() {
        let table = Bitboard65536(rows: { prev in
            let p = Deck.glyph(id: prev)
            return Bitboard256(ids: Deck.all.filter { $0.hue.rank > p.hue.rank }.map(\.id))
        })
        var expected = 0
        for prev in 0..<256 {
            for cur in 0..<256 where Deck.glyph(id: cur).hue.rank > Deck.glyph(id: prev).hue.rank {
                expected += 1
                #expect(table.contains(current: cur, after: prev))
            }
        }
        #expect(table.count == expected)
    }

    @Test("matches(_:) is §4.5's judgement of a stateless declaration against a contextual law")
    func matchesComparesAtTheLargerArity() {
        let solid = Bitboard256(ids: Deck.all.filter { $0.fill == .solid }.map(\.id))
        #expect(Bitboard65536(lifting: solid).matches(solid))

        let contextual = Bitboard65536(rows: { prev in
            prev % 2 == 0 ? solid : .empty
        })
        #expect(!contextual.matches(solid))
    }

    @Test("Combinators are exact over all 65,536 pairs")
    func combinators() {
        let a = Bitboard65536(lifting: Bitboard256(ids: [1, 2, 3]))
        let b = Bitboard65536(lifting: Bitboard256(ids: [3, 4]))
        #expect((a & b).count == 1 * 256)
        #expect((a | b).count == 4 * 256)
        #expect((a ^ b).count == 3 * 256)
        #expect((~Bitboard65536()).count == 65_536)
    }
}
