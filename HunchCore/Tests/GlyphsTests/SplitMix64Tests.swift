import Testing

import Glyphs
import HunchTestSupport

/// Reference vectors, not a golden order (06 T42). SplitMix64's outputs for seed 0 are published
/// with the algorithm, so this suite compares against a foreign artefact rather than against
/// whatever this implementation happened to produce on the day it was written — which is the
/// difference between a known-answer test and a change detector.
@Suite("SplitMix64", .tags(.unit, .presubmission))
struct SplitMix64Tests {
    @Test("Reproduces the published vectors for seed 0")
    func referenceVectors() {
        var rng = SplitMix64(seed: 0)
        #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
        #expect(rng.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(rng.next() == 0x06C4_5D18_8009_454F)
    }

    /// The finaliser maps 0 to 0 — every step is a xor-shift or a multiply, and all of them fix
    /// zero. That is exactly why the gamma is added to the state BEFORE the finaliser runs: an
    /// implementation that finalised first would return 0 forever from seed 0 and look fine on
    /// every other seed. This assertion is the one that catches the transposition.
    @Test("The finaliser fixes zero, which is why the gamma is added first")
    func finaliserFixesZero() {
        #expect(SplitMix64.mix(0) == 0)
        #expect(SplitMix64.mix(SplitMix64.gamma) == 0xE220_A839_7B1D_CDAF)
    }

    @Test("A copy advances independently — the generator is a value, not a reference")
    func valueSemantics() {
        var original = SplitMix64(seed: 0x48_554E_4348)
        var copy = original
        _ = copy.next()
        _ = copy.next()
        #expect(original.next() == 0xDFB8_B157_4CD4_1C48)
    }

    @Test("Two generators from one seed produce the same stream")
    func sameSeedSameStream() {
        var first = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        var second = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        let a = (0..<256).map { _ in first.next() }
        let b = (0..<256).map { _ in second.next() }
        #expect(a == b)
        #expect(Set(a).count == 256)  // no immediate short cycle
    }

    @Test("Different seeds diverge on the first draw")
    func differentSeedsDiverge() {
        var first = SplitMix64(seed: 0)
        var second = SplitMix64(seed: 1)
        #expect(first.next() != second.next())
    }

    /// The shape every consumer must use: randomness is a PARAMETER, threaded by `inout`
    /// (08 §4 consequence 2, N15's preposition row). If this stops compiling because someone
    /// stored an RNG somewhere, that is the bug.
    @Test("Threading the generator through `using:` reproduces a draw sequence")
    func randomnessIsAParameter() {
        func draw(_ count: Int, using rng: inout some RandomNumberGenerator) -> [Int] {
            (0..<count).map { _ in Int.random(in: 0..<256, using: &rng) }
        }
        var first = SplitMix64(seed: 0xDEAD_BEEF)
        var second = SplitMix64(seed: 0xDEAD_BEEF)
        #expect(draw(64, using: &first) == draw(64, using: &second))
    }
}
