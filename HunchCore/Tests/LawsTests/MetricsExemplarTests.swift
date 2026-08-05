import Testing

import Glyphs
import HunchTestSupport
import Laws

/// §5.2 publishes eight exemplar laws with their `p` and their δ, and §5.1's modifier table is
/// what turns one into the other. This suite reconstructs the five metrics for each and checks
/// them against the published decomposition — which is the only way to know the modifiers were
/// read correctly, because a wrong `marginalDeficit` is INVISIBLE: it produces a plausible
/// number for every law and the wrong band for some of them.
@Suite("§5.2 exemplar metrics", .tags(.unit, .presubmission))
struct MetricsExemplarTests {

    /// Band 1 — `fill ∈ {striped}`. An atom must score deficit 0: vary that attribute and the
    /// lamp answers, which is exactly what band 1 teaches.
    @Test("Band 1 LITERAL — p .250, deficit 0, 1 leaf, 3 free, 0 scattered")
    func bandOne() {
        let law = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
        expectApproximatelyEqual(law.admitRate, 0.250, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 0.000, absoluteTolerance: 0.001)
        #expect(law.leafCount == 1)
        #expect(law.freeAttributeCount == 3)
        #expect(law.scatteredSubsetCount == 0)
    }

    /// Band 2 — `shape ∈ {triangle,hexagon} AND pips ∈ {three,four}`. The shape subset is
    /// scattered (ranks 2 and 4), which is §5.1's `m5`.
    @Test("Band 2 PAIR — p .250, deficit .2857, 2 leaves, 2 free, 1 scattered")
    func bandTwo() {
        let law = Law(
            .coupled(
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b1010))),
                .and,
                .atom(.init(attribute: .pips, subset: Fixture.subset(0b1100)))))
        expectApproximatelyEqual(law.admitRate, 0.250, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 0.2857, absoluteTolerance: 0.001)
        #expect(law.leafCount == 2)
        #expect(law.freeAttributeCount == 2)
        #expect(law.scatteredSubsetCount == 1)
    }

    /// Band 3 — `shape ∈ {circle,triangle} XOR fill ∈ {hollow,dotted}`. §5.2 proves this is a
    /// THEOREM, not a guardrail: an XOR's marginals are {p_T, 1 − p_T}, so all sixteen equal p
    /// exactly when both subsets have size 2. Deficit is therefore exactly 1.
    @Test("Band 3 EXCLUSIVE — p .500, deficit 1.000, and every marginal is exactly .500")
    func bandThree() {
        let law = Law(
            .coupled(
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b0011))),
                .xor,
                .atom(.init(attribute: .fill, subset: Fixture.subset(0b0011)))))
        expectApproximatelyEqual(law.admitRate, 0.500, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 1.000, absoluteTolerance: 0.001)
        for marginal in law.table.marginals {
            expectApproximatelyEqual(marginal, 0.500, absoluteTolerance: 1e-12)
        }
        #expect(law.leafCount == 2)
        #expect(law.scatteredSubsetCount == 0)
    }

    /// Band 4 — `RANK shape == RANK pips`. §5.2: "no value predicts anything", deficit 1.0.
    /// One leaf, two named attributes.
    @Test("Band 4 RELATIONAL — p .250, deficit 1.000, 1 leaf, 2 free")
    func bandFour() {
        let law = Law(.relational(.init(leading: .shape, comparator: .eq, trailing: .pips)))
        expectApproximatelyEqual(law.admitRate, 0.250, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 1.000, absoluteTolerance: 0.001)
        #expect(law.leafCount == 1)
        #expect(law.freeAttributeCount == 2)
    }

    /// Band 5 — `RANK pips(cur) > PREV RANK pips`. The admit rate is over 65,536 PAIRS.
    @Test("Band 5 CONTEXTUAL — p .375 over ordered pairs, not over 256")
    func bandFive() {
        let law = Law(.contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
        expectApproximatelyEqual(law.admitRate, 0.375, absoluteTolerance: 0.001)
        #expect(law.table.universeSize == 65_536)
        #expect(law.leafCount == 1)
    }

    /// Band 6 — `IF hue IS amber THEN pips ∈ {3,4} ELSE pips ∈ {1}`. Three leaves, which
    /// §5.7 states outright.
    @Test("Band 6 GUARDED — p .313, 3 leaves, 2 free")
    func bandSix() {
        let law = Law(
            .guarded(
                .init(
                    gate: .hue, gateValue: 0, branch: .pips,
                    then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001))))
        expectApproximatelyEqual(law.admitRate, 0.313, absoluteTolerance: 0.001)
        #expect(law.leafCount == 3)
        #expect(law.freeAttributeCount == 2)
    }

    /// Band 7 — `RANK hue(cur) == PREV RANK hue XOR RANK shape < RANK pips`. Two conceptual
    /// layers, and the arities differ, so the stateless side lifts.
    @Test("Band 7 COMPOSITE — p .438, contextual arity, 2 leaves")
    func bandSeven() {
        let law = Law(
            .coupled(
                .contextual(.init(current: .hue, comparator: .eq, previous: .hue)),
                .xor,
                .relational(.init(leading: .shape, comparator: .lt, trailing: .pips))))
        expectApproximatelyEqual(law.admitRate, 0.438, absoluteTolerance: 0.001)
        #expect(law.table.arity == .contextual)
        #expect(law.leafCount == 2)
    }

    /// Band 8 — `PARITY {fill,shape,pips,hue} IS even`. §5.2: enforced by SYMMETRY, and the
    /// parity sub-family has deficit 1.0 because every counted attribute has identical
    /// marginals.
    @Test("Band 8 SYSTEMIC — p .500, deficit 1.000, 4 leaves, 0 free")
    func bandEight() {
        let law = Law(
            .aggregate(.parity(.init(attributes: Fixture.attributeSet(0b1111), isOdd: false))))
        expectApproximatelyEqual(law.admitRate, 0.500, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 1.000, absoluteTolerance: 0.001)
        #expect(law.leafCount == 4)
        #expect(law.freeAttributeCount == 0)
    }

    /// §5.2's counter-example to "band 8 means flat marginals": a COUNT law is a legitimate
    /// band-8 law whose marginal is NOT flat. Marginal deficit positions a law inside band 8
    /// through `m2`; it does not gate entry to it.
    @Test("Band 8 COUNT — p .500 with deficit .286, which is why flatness is not the gate")
    func bandEightCountIsNotFlat() {
        let law = Law(
            .aggregate(
                .count(
                    .init(
                        attributes: Fixture.attributeSet(0b0111),  // fill, shape, pips
                        rankIn: Fixture.subset(0b1100),  // ranks 3, 4
                        countIn: Fixture.countSet(0b1100, over: 3)))))
        expectApproximatelyEqual(law.admitRate, 0.500, absoluteTolerance: 0.001)
        expectApproximatelyEqual(law.marginalDeficit, 0.286, absoluteTolerance: 0.005)
    }
}
