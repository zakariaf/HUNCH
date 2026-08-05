import Testing

import HunchTestSupport

/// `Corpora.seed` is the repro handle every generated-corpus failure quotes, so its derivation
/// is frozen: changing it silently invalidates every recorded failure in the project's history.
@Suite("Corpora", .tags(.unit, .presubmission))
struct CorporaTests {
    @Test("The derivation is frozen — changing it is a DECISIONS.md act, not a refactor")
    func derivationIsFrozen() {
        // Vectors recorded at E01·T05. If these change, every previously recorded repro
        // (band, index) now points at a different law.
        #expect(Corpora.seed(band: 1, index: 0) == 0xE6AA_C108_7DE6_1679)
    }

    @Test("Different bands give different streams")
    func bandsDiverge() {
        #expect(Corpora.seed(band: 1, index: 0) != Corpora.seed(band: 2, index: 0))
    }

    @Test("The same (band, index) is stable across calls")
    func isDeterministic() {
        #expect(Corpora.seed(band: 5, index: 42) == Corpora.seed(band: 5, index: 42))
    }

    @Test("Successive indices differ")
    func indicesDiverge() {
        let drawn = (0..<64).map { Corpora.seed(band: 3, index: $0) }
        #expect(Set(drawn).count == 64)
    }

    @Test("The corpus size is the brief's invariant-1 count")
    func corpusSize() {
        #expect(Corpora.lawsPerBand == 10_000)
    }
}
