import Foundation
import Testing

import Glyphs
import HunchTestSupport

/// `id` is on disk in every snapshot and every Codex page (§6.10), so its packing is frozen.
/// These assertions are what make "changing the packing invalidates saved games" enforceable.
@Suite("Glyph", .tags(.unit, .presubmission))
struct GlyphTests {
    @Test("id packs fill*64 + shape*16 + pips*4 + hue — §2, frozen")
    func idPacking() {
        #expect(Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber).id == 0)
        #expect(Glyph(fill: .solid, shape: .hexagon, pips: .four, hue: .rose).id == 255)
        // §12.5's forced onboarding seed glyph: hollow triangle, two pips, frost.
        #expect(Glyph(fill: .hollow, shape: .triangle, pips: .two, hue: .frost).id == 22)
        // canon §13.5.1's decisive quartet — striped triangle, two pips, all four hues.
        #expect(Glyph(fill: .striped, shape: .triangle, pips: .two, hue: .amber).id == 0x94)
        #expect(Glyph(fill: .striped, shape: .triangle, pips: .two, hue: .rose).id == 0x97)
    }

    @Test("Every id in 0..<256 is produced exactly once")
    func idIsABijection() {
        var seen = Set<Int>()
        for f in Glyph.Fill.allCases {
            for s in Glyph.Shape.allCases {
                for p in Glyph.Pips.allCases {
                    for h in Glyph.Hue.allCases {
                        seen.insert(Glyph(fill: f, shape: s, pips: p, hue: h).id)
                    }
                }
            }
        }
        #expect(seen.count == 256)
        #expect(seen.min() == 0)
        #expect(seen.max() == 255)
    }

    @Test("rank is 1-based and strictly increasing in the ordinal")
    func rankIsOneBased() {
        #expect(Glyph.Fill.hollow.rank == 1)
        #expect(Glyph.Fill.solid.rank == 4)
        #expect(Glyph.Shape.circle.rank == 1)
        #expect(Glyph.Hue.rose.rank == 4)
        // §2's ink-density and corner-count ladders are the ordinal order.
        #expect(Glyph.Fill.allCases.map(\.rank) == [1, 2, 3, 4])
    }

    @Test("ordinal(of:) reads each register independently")
    func ordinalReadsEachRegister() {
        let g = Glyph(fill: .striped, shape: .square, pips: .three, hue: .teal)
        #expect(g.ordinal(of: .fill) == 2)
        #expect(g.ordinal(of: .shape) == 2)
        #expect(g.ordinal(of: .pips) == 2)
        #expect(g.ordinal(of: .hue) == 1)
        #expect(g.rank(of: .hue) == 2)
    }

    @Test("Attribute.allCases is the canonical fill → shape → pips → hue order (§2)")
    func canonicalAttributeOrder() {
        #expect(Glyph.Attribute.allCases == [.fill, .shape, .pips, .hue])
    }

    @Test("Codable round-trips through one byte per attribute")
    func codableRoundTrip() throws {
        let g = Glyph(fill: .dotted, shape: .hexagon, pips: .four, hue: .frost)
        let data = try JSONEncoder().encode(g)
        #expect(try JSONDecoder().decode(Glyph.self, from: data) == g)
    }
}
