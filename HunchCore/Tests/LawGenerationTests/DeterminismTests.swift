import Foundation
import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws

/// The brief's hard requirement: *"The same `(seed, mode, difficulty)` must produce a
/// byte-identical puzzle across runs and across processes."*
///
/// In-process repeatability is necessary and not sufficient — a `Hasher`-seeded set, an
/// `ObjectIdentifier` ordering or a `Dictionary` iteration would all reproduce inside one
/// process and diverge across two. So the real assertion is a COMMITTED GOLDEN: a file
/// generated in one process and compared in another, which is the only shape of test that can
/// fail on a per-process seed.
@Suite("Determinism", .tags(.integration))
struct DeterminismTests {
    static let statelessBands: [Band] = [
        .literal, .pair, .exclusive, .relational, .guarded, .systemic,
    ]

    struct GoldenEntry: Codable, Hashable {
        let band: Int
        let seed: String  // hex, so the JSON has no Int64 rounding surprises
        let mode: String
        let node: LawNode
        let key: String
    }

    static func goldenURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/determinism-seeds-v1.json")
    }

    /// Regenerate with `HUNCH_RECORD_GOLDEN=1`. That is a deliberate act with a DECISIONS.md
    /// entry, exactly like re-recording a snapshot — never a way to make a red test green.
    static func entries(in index: LawIndex) -> [GoldenEntry] {
        var out: [GoldenEntry] = []
        for band in statelessBands {
            let target = index.servableTarget(band.centre, for: band)
            for mode in Mode.allCases {
                for i in 0..<8 {
                    let seed = Corpora.seed(band: band.rawValue, index: i)
                    let node = generate(
                        seed: seed, band: band, targetDelta: target, mode: mode, in: index)
                    out.append(
                        GoldenEntry(
                            band: band.rawValue,
                            seed: String(seed, radix: 16),
                            mode: mode.wordmark,
                            node: node,
                            key: String(Law(node).key.rawValue, radix: 16)))
                }
            }
        }
        return out
    }

    @Test(
        "The committed golden reproduces exactly — the cross-process assertion",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func goldenReproduces() throws {
        let index = LawIndex.build(bands: Self.statelessBands)
        let fresh = Self.entries(in: index)
        let url = Self.goldenURL()

        if ProcessInfo.processInfo.environment["HUNCH_RECORD_GOLDEN"] == "1" {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(fresh).write(to: url)
            Issue.record("golden re-recorded — this must be a deliberate act, not a green-run fix")
            return
        }

        let data = try Data(contentsOf: url)
        let golden = try JSONDecoder().decode([GoldenEntry].self, from: data)
        #expect(
            golden.count == fresh.count,
            "the golden has \(golden.count) rows, fresh has \(fresh.count)")
        for (recorded, generated) in zip(golden, fresh) {
            #expect(
                recorded == generated,
                "band \(recorded.band) seed \(recorded.seed) \(recorded.mode) diverged")
        }
    }

    /// The index itself must be deterministic, since the generator samples from it by position.
    /// A `Set`- or `Dictionary`-ordered enumeration would reproduce in-process and diverge
    /// across two.
    @Test(
        "The law index is order-stable across builds",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func indexIsOrderStable() {
        let a = LawIndex.build(bands: Self.statelessBands)
        let b = LawIndex.build(bands: Self.statelessBands)
        for band in Self.statelessBands {
            #expect(
                a.forms(for: band).map { "\($0)" } == b.forms(for: band).map { "\($0)" },
                "band \(band.rawValue)'s form order is not stable")
        }
    }

    /// SplitMix64's stream is the floor everything else stands on.
    @Test("The RNG stream is identical from one seed, across instances")
    func rngStreamIsStable() {
        var a = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        var b = SplitMix64(seed: 0xC0FF_EE00_0000_0001)
        #expect((0..<512).map { _ in a.next() } == (0..<512).map { _ in b.next() })
    }
}
