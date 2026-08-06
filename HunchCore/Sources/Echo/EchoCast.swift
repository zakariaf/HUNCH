public import Glyphs
public import Laws

/// §8.3's cast: `L` glyphs emitted into the throat at fixed cadence, **with no verdicts**.
///
/// Two construction invariants, and both are load-bearing rather than tidy: the cast glyphs are
/// **pairwise distinct**, so the tray is a set and no duplicate-identity ambiguity can arise; and
/// **exactly `A` of the `L` are lawful, by construction** — `A` is never displayed, anywhere, at
/// any point, because knowing it turns the recall into a counting problem.
public enum EchoCast {

    public struct Built: Equatable, Sendable {
        public let glyphs: [Glyph]
        /// The lawful indices, in cast order. This is `truth` in §8.7's scoring.
        public let lawful: [Int]
    }

    /// - Parameter seedGlyph: primes position 0, so a contextual member is evaluable from the
    ///   first glyph — the chain is what makes ECHO's ordering component meaningful at all.
    ///
    /// - Returns: `nil` when the law cannot supply `A` lawful or `L − A` unlawful *distinct*
    ///   glyphs at this context — which is a real case at an extreme admit rate, and the caller's
    ///   answer is to reselect, never to relax the invariants.
    public static func build(
        law: Law, load: EchoLoad, seedGlyph: Glyph, seed: UInt64
    ) -> Built? {
        var rng = SplitMix64(seed: seed)
        var order = Array(0..<256)
        // Fisher–Yates through the threaded RNG: the cast is a pure function of the seed, so a
        // round is reproducible from its record and a bug in it can be replayed.
        for index in stride(from: order.count - 1, to: 0, by: -1) {
            let pick = Int(rng.next() % UInt64(index + 1))
            order.swapAt(index, pick)
        }

        var glyphs: [Glyph] = []
        var lawful: [Int] = []
        var context = seedGlyph
        var lawfulRemaining = load.lawfulCount
        var unlawfulRemaining = load.castLength - load.lawfulCount

        for id in order {
            guard glyphs.count < load.castLength else { break }
            let glyph = Deck.glyph(id: id)
            let admits = law.admits(glyph, after: context)
            if admits, lawfulRemaining > 0 {
                lawful.append(glyphs.count)
                lawfulRemaining -= 1
            } else if !admits, unlawfulRemaining > 0 {
                unlawfulRemaining -= 1
            } else {
                continue
            }
            glyphs.append(glyph)
            context = glyph
        }

        guard glyphs.count == load.castLength, lawful.count == load.lawfulCount else {
            return nil
        }
        return Built(glyphs: glyphs, lawful: lawful)
    }

    /// §8.3: the tray re-presents all `L` cast glyphs in **canonical `glyphID` order** — the
    /// Assay's order, therefore already spatially familiar. Not cast order, which would give the
    /// answer away, and not shuffled, which would make the index arbitrary.
    public static func trayOrder(_ glyphs: [Glyph]) -> [Glyph] {
        glyphs.sorted { $0.id < $1.id }
    }
}
