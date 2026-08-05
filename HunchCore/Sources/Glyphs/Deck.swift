/// The deck: all 256 glyphs, in the canonical `fill → shape → pips → hue` order of §2.
///
/// A caseless enum, so there is nothing to instantiate (`W16`). `all` is a `static let` of
/// immutable `Sendable` values — rung 1 of `05 R50` — and is deliberately not injectable:
/// there is no second deck, and the brief's singleton ban is about substitutable mutable
/// state, of which this has none.
public enum Deck {

    /// Every glyph, ordered so that `all[i].id == i`.
    public static let all: [Glyph] = Glyph.Fill.allCases.flatMap { fill in
        Glyph.Shape.allCases.flatMap { shape in
            Glyph.Pips.allCases.flatMap { pips in
                Glyph.Hue.allCases.map { hue in
                    Glyph(fill: fill, shape: shape, pips: pips, hue: hue)
                }
            }
        }
    }

    /// The glyph with `id`.
    ///
    /// - Complexity: O(1). `all` is built in `glyphID` order, so this is an array subscript
    ///   and never a search — which is what lets the evaluator, the Assay and every
    ///   brute-force test address the deck by bit position.
    /// - Precondition: `id` is in `0..<256`.
    public static func glyph(id: Int) -> Glyph {
        precondition(all.indices.contains(id), "glyphID \(id) is outside 0…255")
        return all[id]
    }
}
