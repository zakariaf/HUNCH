import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws

/// The AST is deliberately NARROWER than the BNF in three places, and each narrowing removes a
/// guardrail that would otherwise have to be written and tested: `Subset4` cannot be empty or
/// full, `Contextual` cannot put `prev` on the leading side, and there is no `NOT` case at all.
@Suite("LawNode", .tags(.unit, .presubmission))
struct LawNodeTests {

    @Test("§3.2 forbids the empty and full subsets, so they are unrepresentable")
    func subsetRejectsDegenerateMasks() {
        #expect(Subset4(rawValue: 0) == nil)
        #expect(Subset4(rawValue: 0b1111) == nil)
        #expect(Subset4.all.count == 14)
    }

    /// §5.1's `m5` says 5 of the 14 are scattered. This is the assertion that keeps that
    /// modifier's weight meaningful.
    @Test("Exactly 5 of the 14 subsets are scattered (§5.1 m5)")
    func fiveSubsetsAreScattered() {
        #expect(Subset4.all.count { !$0.isContiguousRun } == 5)
        #expect(Fixture.subset(0b0011).isContiguousRun)  // {1,2}
        #expect(!Fixture.subset(0b0101).isContiguousRun)  // {1,3}
    }

    @Test("The 14 subsets are closed under complement — one of §3.1's five NOT-deleting cases")
    func subsetsAreComplementClosed() {
        for s in Subset4.all {
            #expect(s.complement.rawValue == (0b1111 & ~s.rawValue))
            #expect(s.complement.complement == s)
        }
    }

    @Test("AttributeSet is the five masks with |set| >= 3; CountSet is arity-dependent")
    func aggregateOperandTypes() {
        #expect(AttributeSet.all.count == 5)
        #expect(AttributeSet(rawValue: 0b0011) == nil)  // |set| = 2
        #expect(CountSet.all(over: 3).count == 14)
        #expect(CountSet.all(over: 4).count == 30)
        #expect(CountSet(rawValue: 30, over: 3) == nil)  // outside 1…14 at arity 3
    }

    /// The leaf count is what §5.1's `m1` reads, and it is the only reading that reproduces
    /// §5.2's eight exemplar δ values.
    @Test("Leaf counts are 1 / 1 / 1 / 3 / |attrSet| per §3.4")
    func leafCounts() {
        let atom = LawNode.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100)))
        #expect(atom.leafCount == 1)

        let rel = LawNode.relational(.init(leading: .shape, comparator: .eq, trailing: .pips))
        #expect(rel.leafCount == 1)
        #expect(rel.namedAttributes == [.shape, .pips])  // one leaf, TWO named attributes

        let ctx = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        #expect(ctx.leafCount == 1)

        let guarded = LawNode.guarded(
            .init(
                gate: .hue, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001)))
        #expect(guarded.leafCount == 3)  // gate + then + else, §5.7 outright

        let parity = LawNode.aggregate(
            .parity(.init(attributes: Fixture.attributeSet(0b1111), isOdd: false)))
        #expect(parity.leafCount == 4)  // where MAX_LEAVES = 4 comes from
    }

    @Test("A coupler over two terms is depth 2 and sums their leaves")
    func coupledDepthAndLeaves() {
        let node = LawNode.coupled(
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b1010))),
            .and,
            .atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        #expect(node.depth == 2)
        #expect(node.leafCount == 2)
        #expect(node.structuralFault == nil)
    }

    @Test("A coupler may only join <term>s — a Fork or Tally takes no coupler (§4.2)")
    func couplerOverNonTerm() {
        let fork = LawNode.guarded(
            .init(
                gate: .hue, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001)))
        let bad = LawNode.coupled(
            fork, .and, .atom(.init(attribute: .fill, subset: Fixture.subset(0b0001))))
        #expect(bad.structuralFault == .couplerOverNonTerm)
    }

    @Test("RANK a ⋈ RANK a is constant and therefore outside the grammar (§3.3)")
    func relationalOperandsMustDiffer() {
        let bad = LawNode.relational(.init(leading: .pips, comparator: .lt, trailing: .pips))
        #expect(bad.structuralFault == .relationalOperandsEqual(.pips))
    }

    /// The contextual production is the ONE place equal attributes are legal, because
    /// `RANK pips(cur) > PREV RANK pips` is §5.2's entry-level band-5 law.
    @Test("A contextual term MAY name one attribute twice")
    func contextualMayRepeatAnAttribute() {
        let entry = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        #expect(entry.structuralFault == nil)
    }

    @Test("The duplicate-leaf cap is literally Set(leaves).count == leaves.count (§3.4)")
    func duplicateLeavesAreRejected() {
        let s = Fixture.subset(0b0110)
        let twice = LawNode.coupled(
            .atom(.init(attribute: .hue, subset: s)), .or, .atom(.init(attribute: .hue, subset: s)))
        #expect(twice.structuralFault == .duplicateLeaf)
    }

    /// Both malformed guards ARE rejected — but by an earlier rule than the one named for
    /// them, because the check order is fixed (§3.4) and a guard has three leaves.
    ///
    /// `gate == branch` puts all three on one attribute, so the per-attribute cap fires at
    /// n = 3 > 2. `then == otherwise` makes two identical `(branch, nil, .subset)` leaves, so
    /// the duplicate-leaf cap fires. Under the specified order, `guardGateEqualsBranch` and
    /// `guardBranchesEqual` are therefore **unreachable through `structuralFault`** — see
    /// DECISIONS.md. They are kept because they state the BNF rule the generator builds
    /// against, and because reshuffling the order to reach them would change which fault every
    /// other malformed law reports.
    @Test("A malformed guard is rejected — by the cap that fires first, not by its own name")
    func guardOperandRules() {
        let sameAttr = LawNode.guarded(
            .init(
                gate: .pips, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001)))
        #expect(sameAttr.structuralFault == .tooManyLeavesOnAttribute(.pips, 3))

        let sameBranches = LawNode.guarded(
            .init(
                gate: .hue, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b1100)))
        #expect(sameBranches.structuralFault == .duplicateLeaf)

        // A well-formed guard passes, which is what makes the two rejections meaningful.
        let good = LawNode.guarded(
            .init(
                gate: .hue, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001)))
        #expect(good.structuralFault == nil)
    }

    @Test("The AST round-trips through Codable, including CountSet's arity validation")
    func codableRoundTrip() throws {
        let node = LawNode.aggregate(
            .count(
                .init(
                    attributes: Fixture.attributeSet(0b0111),
                    rankIn: Fixture.subset(0b1100),
                    countIn: Fixture.countSet(0b1100, over: 3))))
        let data = try JSONEncoder().encode(node)
        #expect(try JSONDecoder().decode(LawNode.self, from: data) == node)
    }

    /// A 4-arity count mask must not decode under a 3-attribute set. That is why
    /// `Aggregate.Count` has a hand-written `init(from:)` rather than a synthesized one.
    @Test("Decoding validates CountSet against its sibling attributes field")
    func countSetArityIsValidatedOnDecode() throws {
        let good = LawNode.aggregate(
            .count(
                .init(
                    attributes: Fixture.attributeSet(0b1111),
                    rankIn: Fixture.subset(0b1000),
                    countIn: Fixture.countSet(30, over: 4))))
        var json = String(data: try JSONEncoder().encode(good), encoding: .utf8)!
        // Narrow the set to three attributes; the 4-arity countIn (30) must now be rejected,
        // because 30 is outside 1…14 at arity 3.
        json = json.replacingOccurrences(of: "\"attributes\":15", with: "\"attributes\":7")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LawNode.self, from: Data(json.utf8))
        }
    }
}
