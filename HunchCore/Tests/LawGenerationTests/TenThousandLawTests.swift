import Foundation
import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws

/// The brief's invariant 1: *"Generate 10,000 laws per difficulty band and assert: every law is
/// satisfiable and falsifiable by at least one glyph in the deck; no law is trivially
/// always-true or always-false; no two structurally identical laws are emitted as different;
/// the declaration UI can express every generated law."*
///
/// Gated behind `HUNCH_CALIBRATION=1`: 60,000 generations with full guardrail evaluation is
/// minutes, and the fast loop is a plain `swift test` with no plan to filter on a tag.
@Suite("The 10,000-law suite", .tags(.integration, .nightly))
struct TenThousandLawTests {
    static let statelessBands: [Band] = [
        .literal, .pair, .exclusive, .relational, .guarded, .systemic,
    ]

    @Test(
        "10,000 laws per band satisfy every invariant the brief names",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
        arguments: statelessBands)
    func tenThousandLaws(_ band: Band) {
        let index = LawIndex.build(bands: Self.statelessBands)
        let lower = index.lowerExtensions(for: band)
        let target = index.servableTarget(band.centre, for: band)

        var emitted = LawSet()
        var distinctNodes = Set<String>()
        var fallbacks = 0

        for i in 0..<Corpora.lawsPerBand {
            let seed = Corpora.seed(band: band.rawValue, index: i)
            let report = generateReporting(
                seed: seed, band: band, targetDelta: target, mode: .probe, avoid: [], in: index)
            let node = report.law
            let law = Law(node)
            if report.usedAnchor { fallbacks += 1 }

            // Grammar-valid, and in RNF — so "no two structurally identical laws are emitted as
            // different" is a property of the node, not of a later comparison.
            #expect(node.structuralFault == nil, "band \(band.rawValue) index \(i): not valid")
            #expect(node == node.renderedNormalForm, "band \(band.rawValue) index \(i): not RNF")

            // Satisfiable and falsifiable by at least one glyph — G1, G2.
            #expect(law.table.isSatisfiable, "band \(band.rawValue) index \(i): unsatisfiable")
            #expect(law.table.isFalsifiable, "band \(band.rawValue) index \(i): unfalsifiable")
            #expect(!law.table.isConstant)

            // Never trivially always-true or always-false: the admit window is much tighter
            // than mere non-constancy.
            #expect(
                band.admitWindow.contains(law.table.admitRate),
                "band \(band.rawValue) index \(i): p = \(law.table.admitRate) outside G3")

            // In its own band, which is what the Rasch model cannot survive being wrong.
            #expect(
                band.difficultyRange.contains(Difficulty.of(law, in: band)),
                "band \(band.rawValue) index \(i): outside its band")

            // Not secretly easier — G4 against the strictly lower bands.
            #expect(!lower.contains(law.table), "band \(band.rawValue) index \(i): G4")

            emitted.insert(law.table)
            distinctNodes.insert("\(node)")
        }

        // "No two structurally identical laws are emitted as different": every distinct NODE
        // must be a distinct EXTENSION. Emission repeats — the band has finitely many laws —
        // but a repeat must be the same node, not a second spelling.
        #expect(
            distinctNodes.count == emitted.count,
            "band \(band.rawValue): \(distinctNodes.count) node spellings for \(emitted.count) laws"
        )

        let rate = Double(fallbacks) / Double(Corpora.lawsPerBand)
        #expect(
            rate <= Generation.fallbackBudget,
            "band \(band.rawValue) fell back at \(rate), budget is 2 %")
    }
}
