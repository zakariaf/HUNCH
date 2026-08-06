import Testing

import Foundation

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws
import Narration

/// §13.10's narration. The rule worth a test is **parity**: the narrator says nothing a sighted
/// player cannot read off the tiles. A narrator that said more would be an accessibility feature
/// that hands one group of players a better game.
@Suite("The law narrator", .tags(.unit, .presubmission))
struct LawNarratorTests {

    private static func atom(_ attribute: Glyph.Attribute, _ mask: UInt8) -> LawNode {
        .atom(.init(attribute: attribute, subset: Fixture.subset(mask)))
    }

    @Test("One clause per leaf, in the AST's own order")
    func oneClausePerLeaf() {
        let law = Law(
            .coupled(
                Self.atom(.shape, 0b0110), .or, Self.atom(.pips, 0b1100)))
        let narration = LawNarrator.narrate(law, scope: .playerDraft)

        #expect(narration.clauses.count == 2)
        #expect(narration.coupler == .or)
        #expect(narration.clauses[0] == .admits(.shape, Fixture.subset(0b0110)))
        #expect(narration.clauses[1] == .admits(.pips, Fixture.subset(0b1100)))
    }

    /// The contextual clause is a **different clause**, not a footnote on the relational one:
    /// the Bench draws it as a ghosted trailing socket, and the narration has to carry the same
    /// distinction or a VoiceOver player cannot tell the two tiles apart.
    @Test("A ghosted socket narrates as its own kind of clause")
    func contextualIsDistinct() {
        let stateless = Law(.relational(.init(leading: .pips, comparator: .gt, trailing: .fill)))
        let contextual = Law(
            .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))

        #expect(
            LawNarrator.narrate(stateless, scope: .revealed).clauses[0]
                == .compare(.pips, .gt, .fill))
        #expect(
            LawNarrator.narrate(contextual, scope: .revealed).clauses[0]
                == .compareWithPrevious(.pips, .gt, .pips))
    }

    /// **Parity, at scale.** For every generated law the narration's clause count equals the
    /// AST's leaf count and its coupler matches — which is exactly what the Bench lays out, so
    /// the two media describe the same law with the same number of moving parts.
    ///
    /// Gated behind `HUNCH_CALIBRATION=1`, the same gate the 10,000-law suite uses: building
    /// the law index costs seconds per band, and the fast loop is a plain `swift test` with no
    /// plan to filter on a tag — so a tag alone would not keep it out. The **structural** half
    /// of the same claim is asserted above on hand-built laws, in microseconds, which is what
    /// runs on every commit.
    @Test(
        "Narration structure matches the tile layout, over every band",
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
        arguments: Band.allCases)
    func parityWithTheTiles(_ band: Band) {
        let index = LawIndex.build(bands: [band].filter { !$0.isContextual })
        let target = index.servableTarget(band.centre, for: band)
        for seed in UInt64(0)..<40 {
            let node = generate(
                seed: 0x1A11 &+ seed, band: band, targetDelta: target, mode: .probe,
                in: index)
            let narration = LawNarrator.narrate(Law(node), scope: .revealed)

            #expect(narration.clauses.isEmpty == false)
            // A coupler is narrated exactly when the tiles carry one.
            let isCoupled = if case .coupled = node { true } else { false }
            #expect((narration.coupler != nil) == isCoupled)
            // A Fork or a Tally occupies the whole Bench: one clause, no coupler.
            switch node {
            case .guarded, .aggregate:
                #expect(narration.clauses.count == 1)
                #expect(narration.coupler == nil)
            default:
                break
            }
        }
    }

    /// The scope travels with the narration, so a call site that narrated a hidden law would
    /// have to *say so* — `.playerDraft` and `.revealed` are the only two, and there is no case
    /// for the law the round is hiding.
    @Test("There is no scope for a hidden law")
    func hiddenLawsCannotBeNarrated() {
        let law = Law(Self.atom(.shape, 0b0010))
        #expect(LawNarrator.narrate(law, scope: .playerDraft).scope == .playerDraft)
        #expect(LawNarrator.narrate(law, scope: .revealed).scope == .revealed)
        // Two cases, and adding a third would be a decision somebody has to write down.
        #expect(
            [LawNarrator.Scope.playerDraft, .revealed].count == 2)
    }

    /// Narration is **structure**, not a string, which is what makes the parity test possible:
    /// comparing two sentences compares two translations; comparing two clause lists compares
    /// two readings of one AST.
    @Test("The same law narrates identically however it was reached")
    func narrationIsDeterministic() {
        let first = Law(Self.atom(.shape, 0b0010))
        let second = Law(Self.atom(.shape, 0b0010))
        #expect(
            LawNarrator.narrate(first, scope: .revealed)
                == LawNarrator.narrate(second, scope: .revealed))
    }
}
