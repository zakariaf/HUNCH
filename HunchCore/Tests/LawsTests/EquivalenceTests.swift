import Testing

import Glyphs
import HunchTestSupport
import Laws

@Suite("Equivalence, dead terms and liveness", .tags(.unit, .presubmission))
struct EquivalenceTests {

    /// §4.5's promise to the player: a differently-spelled declaration that means the same law
    /// is CORRECT. Rejecting an equivalent phrasing would punish the player for the grammar
    /// rather than for the induction.
    @Test("Two spellings of one law are the same law (§4.5)")
    func spellingIsIrrelevant() {
        // "shape ∈ {triangle,square,hexagon}" vs the complement of "shape ∈ {circle}".
        let a = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b1110))))
        let b = Law(
            LawNode.atom(.init(attribute: .shape, subset: Fixture.subset(0b0001))).complemented)
        #expect(a.isSameLaw(as: b))
        #expect(a.key == b.key)

        // "pips ∈ {3,4}" — the player who thinks "pips >= 3" lights the same two cells.
        let c = Law(.atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        #expect(!a.isSameLaw(as: c))
    }

    /// §3.6's cross-arity rule: a stateless declaration is judged against a contextual hidden
    /// law by lifting.
    @Test("Comparison happens at the larger arity")
    func crossArityComparison() {
        let stateless = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
        let lifted = LawTable(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
            .lifted()
        #expect(LawTable.equalInCommonSpace(stateless.table, lifted))
    }

    @Test("LawKey is stable across recomputation and folds through SplitMix64")
    func lawKeyIsStable() {
        let law = Law(.relational(.init(leading: .shape, comparator: .eq, trailing: .pips)))
        #expect(law.key == Law(law.node).key)
        #expect(law.key.rawValue != 0)
    }

    /// A bucket collision is unreachable by chance, so it is forced — an unreachable branch is
    /// an untested branch, and the full compare is what §3.6 requires on collision.
    @Test("LawSet resolves a forced bucket collision by full compare")
    func lawSetHandlesCollisions() {
        var set = LawSet()
        let a = LawTable(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0001))))
        let b = LawTable(.atom(.init(attribute: .hue, subset: Fixture.subset(0b1000))))
        let collide = LawKey(rawValue: 42)
        // Bound out of the macro: #expect cannot call a mutating member on its captured value.
        let first = set.insert(a, forcedKey: collide)
        let second = set.insert(b, forcedKey: collide)  // same bucket, different law
        let third = set.insert(a, forcedKey: collide)  // same bucket, SAME law
        #expect(first)
        #expect(second)
        #expect(!third)
        #expect(set.count == 2)
        #expect(set.contains(a, forcedKey: collide))
    }

    /// Both substitutions are required, and each catches a case the other cannot.
    @Test("A subsumed AND is caught by the ⊤ rebuild")
    func subsumedAndIsDead() {
        // shape ∈ {circle} AND shape ∈ {circle,triangle} — the second term does nothing.
        let node = LawNode.coupled(
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b0001))), .and,
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b0011))))
        #expect(!Law(node).deadLeaves.isEmpty)
    }

    @Test("A live two-term law has no dead leaves")
    func liveLawHasNoDeadLeaves() {
        let node = LawNode.coupled(
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b1010))), .and,
            .atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        #expect(Law(node).deadLeaves.isEmpty)
    }

    /// THE TRAP. Permuting `cur` and `prev` together leaves an equality law invariant, so
    /// `pips` would read as dead and G6 would delete §3.3's entry-level contextual law — the
    /// one the design says "must exist".
    @Test("An equality contextual law keeps its attribute LIVE (the independence trap)")
    func equalityContextualLawIsLive() {
        let law = Law(.contextual(.init(current: .pips, comparator: .eq, previous: .pips)))
        #expect(law.pivotalAttributes.contains(.pips))
        #expect(law.hasLiveNamedAttributes)
    }

    @Test("Pivotal attributes are exactly the ones the law depends on")
    func pivotalAttributes() {
        let atom = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
        #expect(atom.pivotalAttributes == [.fill])
        #expect(atom.hasLiveNamedAttributes)

        let rel = Law(.relational(.init(leading: .shape, comparator: .lt, trailing: .pips)))
        #expect(rel.pivotalAttributes == [.shape, .pips])
        #expect(rel.hasLiveNamedAttributes)

        let parity = Law(
            .aggregate(
                .parity(
                    .init(
                        attributes: Fixture.attributeSet(0b1111), isOdd: false))))
        #expect(parity.pivotalAttributes.count == 4)
    }
}
