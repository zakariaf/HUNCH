import Foundation
import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws

/// The generator's contract is DETERMINISM: the same request must produce a byte-identical
/// puzzle across runs and across processes (the brief's hard requirement). Everything else —
/// the guardrails, the band fidelity, the fallback budget — is what makes the output a
/// *playable* law rather than merely a reproducible one.
@Suite("Generator", .tags(.integration))
struct GeneratorTests {
    /// The stateless bands only: the contextual index is minutes to build.
    static let statelessBands: [Band] = [
        .literal, .pair, .exclusive, .relational, .guarded, .systemic,
    ]

    @Test(
        "The same (seed, band, targetδ, mode) is byte-identical across calls",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func deterministic() {
        let index = LawIndex.build(bands: Self.statelessBands)
        for band in Self.statelessBands {
            for seed in [UInt64(0), 0xDEAD_BEEF, 0xC0FF_EE00_0000_0001] {
                let a = generate(
                    seed: seed, band: band, targetDelta: band.centre, mode: .probe, in: index)
                let b = generate(
                    seed: seed, band: band, targetDelta: band.centre, mode: .probe, in: index)
                #expect(a == b, "\(band) seed \(seed) is not reproducible")
            }
        }
    }

    /// Different modes must give different puzzles from one seed — that is what `Mode.salt` is
    /// for, and a salt that did not reach the RNG would be silently invisible.
    @Test(
        "The mode salt reaches the stream",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func modeSaltMatters() {
        let index = LawIndex.build(bands: [.pair])
        let laws = Mode.allCases.map {
            generate(seed: 42, band: .pair, targetDelta: Band.pair.centre, mode: $0, in: index)
        }
        #expect(Set(laws.map { "\($0)" }).count > 1)
    }

    /// Every emitted law is grammar-valid, in its own band, and clears the generation set. A
    /// law outside its band poisons the Rasch estimate, which is the one disagreement the
    /// adaptive model cannot survive.
    @Test(
        "Every emitted law is in its own band and clears every non-request guardrail",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func emittedLawsAreValid() {
        let index = LawIndex.build(bands: Self.statelessBands)
        for band in Self.statelessBands {
            var fallbacks = 0
            let trials = 200
            // The target must be clamped into what the band can REACH, not its nominal
            // range — see LawIndex.achievableDifficultyRange.
            let target = index.servableTarget(band.centre, for: band)
            for i in 0..<trials {
                let report = generateReporting(
                    seed: UInt64(i), band: band, targetDelta: target,
                    mode: .probe, avoid: [], in: index)
                let law = Law(report.law)
                #expect(report.law.structuralFault == nil)
                #expect(
                    Guardrail.clearsGenerationSet(
                        law, in: band, excluding: index.lowerExtensions(for: band)))
                #expect(band.difficultyRange.contains(Difficulty.of(law, in: band)))
                if report.usedAnchor { fallbacks += 1 }
            }
            let rate = Double(fallbacks) / Double(trials)
            #expect(
                rate <= Generation.fallbackBudget,
                "\(band) fell back \(fallbacks)/\(trials) = \(rate), budget is 2 %")
        }
    }

    @Test("Every band's anchor is grammar-valid, in its own band, and clears the generation set")
    func anchorsAreValid() {
        for band in Band.allCases {
            let node = band.anchor
            #expect(node.structuralFault == nil, "\(band) anchor is not grammar-valid")
            let law = Law(node)
            #expect(law.table.isSatisfiable && law.table.isFalsifiable)
            #expect(band.admitWindow.contains(law.table.admitRate), "\(band) anchor outside G3")
            #expect(law.deadLeaves.isEmpty, "\(band) anchor has a dead leaf")
            #expect(law.hasLiveNamedAttributes, "\(band) anchor has a dead attribute")
            #expect(
                band.difficultyRange.contains(Difficulty.of(law, in: band)),
                "\(band) anchor is outside its own band")
            if band.isContextual {
                #expect(!law.table.isSecretlyStateless, "\(band) anchor is secretly stateless")
            }
        }
    }

    @Test("Sampling is unbiased and integer-only")
    func samplingIsUnbiased() {
        var rng = SplitMix64(seed: 0xA5A5_A5A5)
        var counts = [Int](repeating: 0, count: 7)
        for _ in 0..<70_000 { counts[Sampling.uniform(below: 7, using: &rng)] += 1 }
        for count in counts {
            #expect(abs(count - 10_000) < 500, "bucket \(count) is off a 10,000 expectation")
        }
        var rng2 = SplitMix64(seed: 1)
        var weighted = [Int](repeating: 0, count: 3)
        for _ in 0..<60_000 {
            weighted[Sampling.weightedIndex([1, 2, 3], using: &rng2)] += 1
        }
        #expect(abs(weighted[0] - 10_000) < 500)
        #expect(abs(weighted[2] - 30_000) < 700)
    }
}
