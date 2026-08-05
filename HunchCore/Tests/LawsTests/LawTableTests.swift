import Testing

import Glyphs
import HunchTestSupport
import Laws

/// §3.6 makes the extension the canonical form, so these tables ARE the laws. Everything here
/// is checked against a brute-force walk over the universe rather than against another table
/// expression, so a test cannot inherit a bug from the resolver it checks.
@Suite("LawTable", .tags(.unit, .presubmission))
struct LawTableTests {

    @Test("An atom resolves to its mask, checked glyph by glyph")
    func atomResolves() {
        let node = LawNode.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100)))  // striped
        let table = LawTable(node)
        #expect(table.arity == .stateless)
        #expect(table.popCount == 64)
        #expect(table.admitRate == 0.25)
        for g in Deck.all {
            #expect(table.admits(g, after: g) == (g.fill == .striped))
        }
    }

    @Test("A guard is (gate & then) | (~gate & otherwise), checked glyph by glyph")
    func guardResolves() {
        // §5.2's band-6 exemplar: IF hue IS amber THEN pips ∈ {3,4} ELSE pips ∈ {1}
        let node = LawNode.guarded(
            .init(
                gate: .hue, gateValue: 0, branch: .pips,
                then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001)))
        let table = LawTable(node)
        for g in Deck.all {
            let expected = g.hue == .amber ? (g.pips.rank >= 3) : (g.pips == .one)
            #expect(table.admits(g, after: g) == expected)
        }
        // §5.2 publishes p = .313 for this exemplar.
        expectApproximatelyEqual(table.admitRate, 0.313, absoluteTolerance: 0.001)
    }

    @Test("A contextual law resolves over ordered pairs and is not secretly stateless (G7)")
    func contextualResolves() {
        // §5.2's band-5 entry-level law: RANK pips(cur) > PREV RANK pips
        let node = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        let table = LawTable(node)
        #expect(table.arity == .contextual)
        #expect(table.universeSize == 65_536)
        #expect(!table.isSecretlyStateless)
        for prev in stride(from: 0, to: 256, by: 31) {
            for cur in stride(from: 0, to: 256, by: 29) {
                let p = Deck.glyph(id: prev)
                let c = Deck.glyph(id: cur)
                #expect(table.admits(c, after: p) == (c.pips.rank > p.pips.rank))
            }
        }
        // §5.2 publishes p = .375 for this law.
        expectApproximatelyEqual(table.admitRate, 0.375, absoluteTolerance: 0.001)
    }

    @Test("A coupler over mixed arities lifts the stateless side (§3.6)")
    func mixedArityCoupling() {
        let ctx = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        let atom = LawNode.atom(.init(attribute: .shape, subset: Fixture.subset(0b1010)))
        let table = LawTable(.coupled(ctx, .and, atom))
        #expect(table.arity == .contextual)
        for prev in stride(from: 0, to: 256, by: 37) {
            for cur in stride(from: 0, to: 256, by: 41) {
                let p = Deck.glyph(id: prev)
                let c = Deck.glyph(id: cur)
                let expected =
                    c.pips.rank > p.pips.rank
                    && [Glyph.Shape.triangle, .hexagon].contains(c.shape)
                #expect(table.admits(c, after: p) == expected)
            }
        }
    }

    @Test("An aggregate resolves; §5.2's band-8 parity exemplar admits exactly half the deck")
    func aggregateResolves() {
        let node = LawNode.aggregate(
            .parity(.init(attributes: Fixture.attributeSet(0b1111), isOdd: false)))
        let table = LawTable(node)
        #expect(table.popCount == 128)
        #expect(table.admitRate == 0.5)
    }

    @Test("Constant tables are detected — §3.4 step 5's fold and the Seal's bar")
    func constants() {
        let always = LawTable(stateless: .full)
        let never = LawTable(stateless: .empty)
        #expect(always.isConstant && !always.isFalsifiable)
        #expect(never.isConstant && !never.isSatisfiable)
    }

    @Test("There are exactly 16 marginals, and they average to the admit rate")
    func marginalsShape() {
        let node = LawNode.atom(.init(attribute: .shape, subset: Fixture.subset(0b0110)))
        let table = LawTable(node)
        let m = table.marginals
        #expect(m.count == 16)
        // Each attribute's four marginals average to p, because its four values partition
        // the universe evenly.
        for attribute in 0..<4 {
            let slice = m[(attribute * 4)..<(attribute * 4 + 4)]
            expectApproximatelyEqual(
                slice.reduce(0, +) / 4, table.admitRate, absoluteTolerance: 1e-12)
        }
    }
}
