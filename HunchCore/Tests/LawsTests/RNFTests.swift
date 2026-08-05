import Testing

import Glyphs
import HunchTestSupport
import Laws

/// RNF guarantees *one law, one tile layout, forever* — and is explicitly NOT the equivalence
/// test (§3.4's closing line). Both halves are asserted here, because widening RNF into
/// equivalence would silently break G10's node-identity promise.
@Suite("RNF", .tags(.unit, .presubmission))
struct RNFTests {
    static func sub(_ raw: UInt8) -> Subset4 { Subset4(rawValue: raw)! }  // swift-format-ignore: NeverForceUnwrap
    static func attrs(_ raw: UInt8) -> AttributeSet { AttributeSet(rawValue: raw)! }  // swift-format-ignore: NeverForceUnwrap

    /// §3.1's nine identities, checked at the EXTENSION level — the strongest form: the
    /// complement must admit exactly what the original rejects.
    @Test("Every complement identity holds over the whole universe (§3.1)")
    func complementIdentities() {
        let cases: [LawNode] = [
            .atom(.init(attribute: .fill, subset: Self.sub(0b0100))),
            .relational(.init(leading: .shape, comparator: .lt, trailing: .pips)),
            .contextual(.init(current: .pips, comparator: .gte, previous: .hue)),
            .coupled(
                .atom(.init(attribute: .shape, subset: Self.sub(0b0011))), .and,
                .atom(.init(attribute: .pips, subset: Self.sub(0b1100)))),
            .coupled(
                .atom(.init(attribute: .shape, subset: Self.sub(0b0011))), .or,
                .atom(.init(attribute: .pips, subset: Self.sub(0b1100)))),
            .coupled(
                .atom(.init(attribute: .shape, subset: Self.sub(0b0011))), .xor,
                .atom(.init(attribute: .fill, subset: Self.sub(0b0011)))),
            .guarded(
                .init(
                    gate: .hue, gateValue: 0, branch: .pips,
                    then: Self.sub(0b1100), otherwise: Self.sub(0b0001))),
            .aggregate(
                .count(
                    .init(
                        attributes: Self.attrs(0b0111), rankIn: Self.sub(0b1100),
                        countIn: CountSet(rawValue: 0b1100, over: 3)!))),  // swift-format-ignore: NeverForceUnwrap
            .aggregate(.parity(.init(attributes: Self.attrs(0b1111), isOdd: false))),
        ]
        for node in cases {
            let table = LawTable(node)
            let complement = LawTable(node.complemented)
            #expect(
                complement.popCount == table.universeSize - table.popCount,
                "complement of \(node) has the wrong population")
            #expect(
                node.complemented.complemented.normalisedForCompare == node.normalisedForCompare)
        }
    }

    /// complement is NEGATION (lt → gte); flipped is OPERAND TRANSPOSITION (lt → gt). Two
    /// different functions, both involutions, both needed — and confusing them is silent.
    @Test("Comparator.complemented and .flipped are different functions")
    func complementIsNotFlip() {
        #expect(Comparator.lt.complemented == .gte)
        #expect(Comparator.lt.flipped == .gt)
        #expect(Comparator.eq.complemented == .neq)
        #expect(Comparator.eq.flipped == .eq)
    }

    @Test("Step 3: relational operands sort into canonical order, comparator flipped")
    func relationalOrientation() {
        // pips (2) before shape (1) is out of order.
        let reversed = LawNode.relational(.init(leading: .pips, comparator: .lt, trailing: .shape))
        let rnf = reversed.renderedNormalForm
        #expect(rnf == .relational(.init(leading: .shape, comparator: .gt, trailing: .pips)))
        // …and the extension is unchanged, which is what makes it a normalisation.
        #expect(LawTable(rnf) == LawTable(reversed))
    }

    @Test("Step 4: two atoms on one attribute merge by set algebra (§3.4)")
    func sameAttributeMerge() {
        let a = LawNode.atom(.init(attribute: .pips, subset: Self.sub(0b1110)))  // {2,3,4}
        let b = LawNode.atom(.init(attribute: .pips, subset: Self.sub(0b1100)))  // {3,4}
        #expect(
            LawNode.coupled(a, .and, b).renderedNormalForm
                == .atom(.init(attribute: .pips, subset: Self.sub(0b1100))))
        #expect(
            LawNode.coupled(a, .or, b).renderedNormalForm
                == .atom(.init(attribute: .pips, subset: Self.sub(0b1110))))
        #expect(
            LawNode.coupled(a, .xor, b).renderedNormalForm
                == .atom(.init(attribute: .pips, subset: Self.sub(0b0010))))
    }

    /// The merge is what stops a band-2 skeleton shipping a band-1 extension, which is what
    /// T08's band-2 count depends on.
    @Test("The merge unmasks a two-term law as a one-term law")
    func mergeUnmasksLowerBands() {
        let a = LawNode.atom(.init(attribute: .hue, subset: Self.sub(0b0011)))
        let b = LawNode.atom(.init(attribute: .hue, subset: Self.sub(0b0111)))
        let merged = LawNode.coupled(a, .and, b).renderedNormalForm
        #expect(merged.leafCount == 1)  // was 2
    }

    /// A Bridge on the same attribute pair must NOT merge. `>` OR `==` is `>=` as an
    /// EXTENSION, and RNF is not the equivalence test — merging it would widen RNF into
    /// equivalence and break G10's node-identity promise.
    @Test("A same-attribute Bridge pair does not merge, even though its extension would")
    func bridgePairsDoNotMerge() {
        let gt = LawNode.contextual(.init(current: .pips, comparator: .gt, previous: .pips))
        let eq = LawNode.contextual(.init(current: .pips, comparator: .eq, previous: .pips))
        let node = LawNode.coupled(gt, .or, eq)
        let rnf = node.renderedNormalForm
        #expect(rnf.leafCount == 2, "RNF must not collapse this to a single >= term")
        // …even though the extension IS >=.
        let gte = LawNode.contextual(.init(current: .pips, comparator: .gte, previous: .pips))
        #expect(LawTable(rnf) == LawTable(gte))
    }

    /// One law, one layout: every spelling of a commutative shape normalises to one node.
    @Test("Transposed operands normalise to one identical node")
    func oneLawOneLayout() {
        let x = LawNode.atom(.init(attribute: .shape, subset: Self.sub(0b0011)))
        let y = LawNode.atom(.init(attribute: .pips, subset: Self.sub(0b1100)))
        for coupler in Coupler.allCases {
            #expect(
                LawNode.coupled(x, coupler, y).renderedNormalForm
                    == LawNode.coupled(y, coupler, x).renderedNormalForm)
        }
    }

    /// The sort key must be stable ACROSS PROCESSES — it is stored on disk. `hashValue` is
    /// seeded per process and would silently relay out every saved Bench draft.
    @Test("The sort key is deterministic and total")
    func sortKeyIsDeterministic() {
        let nodes: [LawNode] = [
            .atom(.init(attribute: .fill, subset: Self.sub(0b0001))),
            .atom(.init(attribute: .hue, subset: Self.sub(0b1000))),
            .relational(.init(leading: .fill, comparator: .eq, trailing: .shape)),
            .contextual(.init(current: .pips, comparator: .gt, previous: .pips)),
        ]
        let keys = nodes.map { LawNode.sortKey($0) }
        #expect(Set(keys.map { "\($0)" }).count == nodes.count)
        // Re-deriving gives the identical key.
        #expect(nodes.map { "\(LawNode.sortKey($0))" } == keys.map { "\($0)" })
    }

    @Test("A constant extension has no normal form, and constantFold names which constant")
    func constantsAreDetected() {
        let s = Self.sub(0b0011)
        let atom = LawNode.atom(.init(attribute: .shape, subset: s))
        let never = LawNode.coupled(atom, .and, atom.complemented)
        let always = LawNode.coupled(atom, .or, atom.complemented)
        #expect(never.constantFold == .reject)
        #expect(always.constantFold == .admit)
        // An AND of two DISJOINT atoms on DIFFERENT attributes is satisfiable — the structural
        // route to a constant is narrower than the extension route.
        let disjointDifferent = LawNode.coupled(
            .atom(.init(attribute: .shape, subset: Self.sub(0b0001))),
            .and,
            .atom(.init(attribute: .pips, subset: Self.sub(0b1000))))
        #expect(disjointDifferent.constantFold == nil)
    }
}

extension LawNode {
    /// Comparison helper for the involution check: complementing twice must return the same
    /// LAW, and for a coupled node it may return a differently-ordered spelling.
    var normalisedForCompare: LawNode { constantFold == nil ? renderedNormalForm : self }
}
