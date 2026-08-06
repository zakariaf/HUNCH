public import Glyphs
public import Laws

/// §4.5's counterexample: the *minimum honest response* to a wrong declaration.
///
/// One glyph, never the law. Revealing the law converts failure into a lookup and trains
/// waiting instead of reasoning; revealing nothing makes the machine feel arbitrary rather
/// than legible-in-principle. A counterexample is evidence — the same currency the whole game
/// trades in — it proves the declaration false, and it does not identify the law.
public enum Counterexample {
    /// A disagreement between the declaration and the hidden law.
    public struct Choice: Hashable, Sendable {
        public let current: Glyph
        /// `nil` in a stateless band; the pair's leading glyph in a contextual one.
        public let previous: Glyph?
        /// True when the hidden law admits it and the declaration rejects it.
        public let isFalseNegative: Bool
    }

    /// §4.5's selection, in order and fully deterministic:
    ///
    /// 1. restrict to glyphs (or ordered pairs) where declared and hidden disagree;
    /// 2. **prefer false negatives** — cases the hidden law admits and the declaration rejects,
    ///    which targets the most common human error, the over-narrow hypothesis;
    /// 3. minimise attribute-space Hamming distance to the nearest glyph already in the ribbon,
    ///    so it lands as "oh, *that* one" rather than as a random glyph;
    /// 4. tie-break by lowest `glyphID`.
    ///
    /// - Returns: `nil` only when the two laws agree everywhere, which the caller has already
    ///   ruled out by deciding the declaration was wrong.
    public static func select(
        declared: Law, hidden: Law, ribbon: [Glyph], seedGlyph: Glyph
    ) -> Choice? {
        let contextual = hidden.table.arity == .contextual || declared.table.arity == .contextual
        let context = ribbon + [seedGlyph]

        var best: Choice?
        var bestKey: (Int, Int, Int)?  // (falseNegativeRank, hamming, glyphID)

        func consider(_ current: Glyph, _ previous: Glyph?) {
            let prev = previous ?? seedGlyph
            let hiddenAdmits = hidden.admits(current, after: prev)
            let declaredAdmits = declared.admits(current, after: prev)
            guard hiddenAdmits != declaredAdmits else { return }

            let isFalseNegative = hiddenAdmits && !declaredAdmits
            let hamming = context.map { hammingDistance($0, current) }.min() ?? 4
            let key = (isFalseNegative ? 0 : 1, hamming, current.id)
            if bestKey == nil || key < bestKey! {
                bestKey = key
                best = Choice(
                    current: current, previous: contextual ? prev : nil,
                    isFalseNegative: isFalseNegative)
            }
        }

        if contextual {
            for previous in Deck.all {
                for current in Deck.all { consider(current, previous) }
            }
        } else {
            for current in Deck.all { consider(current, nil) }
        }
        return best
    }

    /// Attribute-space Hamming distance: how many of the four attributes differ, 0…4.
    ///
    /// Attribute space, not `glyphID` space — two glyphs differing only in hue are distance 1
    /// however far apart their ids are.
    public static func hammingDistance(_ a: Glyph, _ b: Glyph) -> Int {
        var distance = 0
        for attribute in Glyph.Attribute.allCases
        where a.ordinal(of: attribute) != b.ordinal(of: attribute) {
            distance += 1
        }
        return distance
    }
}

private func < (lhs: (Int, Int, Int), rhs: (Int, Int, Int)) -> Bool {
    if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
    if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
    return lhs.2 < rhs.2
}
