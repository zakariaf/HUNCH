import Testing

import Glyphs
import HunchTestSupport

/// §3.6 makes the extension the canonical form of a law — syntax is never compared — so these
/// operators ARE the semantics of AND, OR and XOR over laws. Every combinator is checked
/// against a brute-force walk over `Deck.all` rather than against another bitboard expression.
@Suite("Bitboard256", .tags(.unit, .presubmission))
struct Bitboard256Tests {
    @Test("empty and full are the two constant tables §3.4 step 5 folds")
    func constants() {
        #expect(Bitboard256.empty.count == 0)
        #expect(Bitboard256.empty.isEmpty)
        #expect(Bitboard256.full.count == 256)
        #expect(!Bitboard256.full.isEmpty)
        #expect(~Bitboard256.empty == .full)
        #expect(~Bitboard256.full == .empty)
    }

    @Test("Every one of the 256 bits is independently addressable")
    func everyBitRoundTrips() {
        for id in 0..<256 {
            var b = Bitboard256()
            b.insert(id)
            #expect(b.count == 1)
            #expect(b.contains(id))
            for other in 0..<256 where other != id {
                #expect(!b.contains(other))
            }
        }
    }

    @Test("init(ids:) agrees with repeated insert, and is idempotent")
    func initFromIDs() {
        let ids = [0, 1, 63, 64, 127, 128, 191, 192, 255]
        let b = Bitboard256(ids: ids)
        #expect(b.count == ids.count)
        for id in ids { #expect(b.contains(id)) }
        #expect(Bitboard256(ids: ids + ids) == b)
    }

    @Test("Word boundaries — 63/64 and 191/192 are where an off-by-one lands")
    func wordBoundaries() {
        var b = Bitboard256()
        b.insert(63)
        #expect(b.word(at: 0) == 1 << 63)
        #expect(b.word(at: 1) == 0)
        b.insert(64)
        #expect(b.word(at: 1) == 1)
        #expect(b.count == 2)
    }

    @Test("AND, OR and XOR agree with a brute-force walk over the deck")
    func combinatorsMatchBruteForce() {
        // Two real predicates over the deck rather than random words.
        let striped = Bitboard256(ids: Deck.all.filter { $0.fill == .striped }.map(\.id))
        let triangle = Bitboard256(ids: Deck.all.filter { $0.shape == .triangle }.map(\.id))

        let and = striped & triangle
        let or = striped | triangle
        let xor = striped ^ triangle
        for g in Deck.all {
            let s = g.fill == .striped
            let t = g.shape == .triangle
            #expect(and.contains(g.id) == (s && t))
            #expect(or.contains(g.id) == (s || t))
            #expect(xor.contains(g.id) == (s != t))
        }
        #expect(and.count == 16)  // 1 fill × 1 shape × 4 pips × 4 hues
        #expect(or.count == 64 + 64 - 16)
        #expect(xor.count == or.count - and.count)
    }

    @Test("Complement is exact over all 256, not merely over the set bits")
    func complementIsExact() {
        let b = Bitboard256(ids: Deck.all.filter { $0.hue == .amber }.map(\.id))
        #expect(b.count == 64)
        #expect((~b).count == 192)
        for g in Deck.all {
            #expect((~b).contains(g.id) == (g.hue != .amber))
        }
    }

    @Test("Equality of tables is equality of laws (§3.6) — two spellings, one extension")
    func equalitySpansSpellings() {
        // "shape is not circle" and "shape is triangle, square or hexagon" are one law.
        let notCircle = ~Bitboard256(ids: Deck.all.filter { $0.shape == .circle }.map(\.id))
        let theOtherThree = Bitboard256(
            ids: Deck.all.filter { [.triangle, .square, .hexagon].contains($0.shape) }.map(\.id))
        #expect(notCircle == theOtherThree)
        #expect(notCircle.hashValue == theOtherThree.hashValue)
    }
}
