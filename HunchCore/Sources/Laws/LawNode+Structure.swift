public import Glyphs

extension LawNode {
    public static let maxDepth = 2  // §3.4
    public static let maxLeaves = 4

    /// Every leaf, in traversal order.
    ///
    /// **A leaf is one `(attribute, comparator, operand)` triple.** That is the spelling
    /// §3.4's duplicate cap uses, and the only reading that reproduces §5.2's eight exemplar
    /// δ values through §5.1's `m1`: an atom, a relational and a contextual are one leaf each;
    /// a guard is three (gate + then + else, which §5.7 states outright); an aggregate is one
    /// per counted attribute, which is where `MAX_LEAVES = 4` comes from.
    ///
    /// - Complexity: O(leaves), at most 4.
    public var leaves: [Leaf] {
        switch self {
        case .atom(let a):
            [Leaf(attribute: a.attribute, comparator: nil, operand: .subset(a.subset))]
        case .relational(let r):
            [Leaf(attribute: r.leading, comparator: r.comparator, operand: .rank(r.trailing))]
        case .contextual(let c):
            [
                Leaf(
                    attribute: c.current, comparator: c.comparator,
                    operand: .previousRank(c.previous))
            ]
        case .coupled(let lhs, _, let rhs):
            lhs.leaves + rhs.leaves
        case .guarded(let g):
            [
                Leaf(attribute: g.gate, comparator: .eq, operand: .value(g.gateValue)),
                Leaf(attribute: g.branch, comparator: nil, operand: .subset(g.then)),
                Leaf(attribute: g.branch, comparator: nil, operand: .subset(g.otherwise)),
            ]
        case .aggregate(let a):
            switch a {
            case .count(let c):
                c.attributes.members.map {
                    Leaf(attribute: $0, comparator: nil, operand: .subset(c.rankIn))
                }
            case .parity(let p):
                p.attributes.members.map {
                    Leaf(attribute: $0, comparator: nil, operand: .value(p.isOdd ? 1 : 0))
                }
            }
        }
    }

    public var leafCount: Int { leaves.count }

    /// The attributes this law *names*. A relational and a contextual name two; an aggregate
    /// names its set. §5.1's `m3` reads `4 - namedAttributes.count`, and so does G6.
    public var namedAttributes: Set<Glyph.Attribute> {
        switch self {
        case .atom(let a): [a.attribute]
        case .relational(let r): [r.leading, r.trailing]
        case .contextual(let c): [c.current, c.previous]
        case .coupled(let lhs, _, let rhs): lhs.namedAttributes.union(rhs.namedAttributes)
        case .guarded(let g): [g.gate, g.branch]
        case .aggregate(let a):
            switch a {
            case .count(let c): Set(c.attributes.members)
            case .parity(let p): Set(p.attributes.members)
            }
        }
    }

    /// Tree depth. A bare term is 1; one coupler over two terms is 2.
    public var depth: Int {
        switch self {
        case .coupled(let lhs, _, let rhs): 1 + max(lhs.depth, rhs.depth)
        case .atom, .relational, .contextual, .guarded, .aggregate: 1
        }
    }

    /// Whether this node is a `<term>` — the only thing a coupler may join (§3.2).
    var isTerm: Bool {
        switch self {
        case .atom, .relational, .contextual: true
        case .coupled, .guarded, .aggregate: false
        }
    }

    private var relationalCount: Int {
        switch self {
        case .relational: 1
        case .coupled(let l, _, let r): l.relationalCount + r.relationalCount
        case .atom, .contextual, .guarded, .aggregate: 0
        }
    }

    private var contextualCount: Int {
        switch self {
        case .contextual: 1
        case .coupled(let l, _, let r): l.contextualCount + r.contextualCount
        case .atom, .relational, .guarded, .aggregate: 0
        }
    }

    /// The first structural rule this node breaks, or `nil` if it is grammar-valid.
    ///
    /// Checked in a fixed order so the fault is deterministic: depth, coupler-over-non-term,
    /// leaf count, term caps, per-attribute cap, duplicate leaves, then the per-production
    /// operand rules. Tests assert that order, so do not reshuffle it casually.
    ///
    /// - Complexity: O(leaves), at most 4.
    public var structuralFault: StructuralFault? {
        if depth > Self.maxDepth { return .depthExceeded(depth) }

        if case .coupled(let lhs, _, let rhs) = self, !lhs.isTerm || !rhs.isTerm {
            return .couplerOverNonTerm
        }

        let all = leaves
        if all.count > Self.maxLeaves { return .tooManyLeaves(all.count) }
        if relationalCount > 1 { return .tooManyRelationalTerms(relationalCount) }
        if contextualCount > 2 { return .tooManyContextualTerms(contextualCount) }

        // Counts leaves that NAME the attribute, so a relational on (shape, pips) contributes
        // one to each. A guard is 1 on the gate and 2 on the branch — exactly at the cap, and
        // the reason a Fork occupies the whole Bench and takes no coupler (§4.2).
        for attribute in Glyph.Attribute.allCases {
            let n = all.count { $0.attribute == attribute }
            if n > 2 { return .tooManyLeavesOnAttribute(attribute, n) }
        }

        // Literally §3.4's wording. A hand-rolled pairwise comparison drifts from the spec.
        if Set(all).count != all.count { return .duplicateLeaf }

        return operandFault
    }

    private var operandFault: StructuralFault? {
        switch self {
        case .atom:
            return nil
        case .relational(let r):
            return r.leading == r.trailing ? .relationalOperandsEqual(r.leading) : nil
        case .contextual:
            // `a` and `b` MAY be equal here — `RANK pips(cur) > PREV RANK pips` is §5.2's
            // entry-level contextual law and must exist.
            return nil
        case .coupled(let lhs, _, let rhs):
            return lhs.operandFault ?? rhs.operandFault
        case .guarded(let g):
            if g.gate == g.branch { return .guardGateEqualsBranch(g.gate) }
            if g.then == g.otherwise { return .guardBranchesEqual(g.branch) }
            return nil
        case .aggregate:
            return nil
        }
    }
}
