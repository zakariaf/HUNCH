public import Glyphs

extension LawNode {
    /// The law that admits exactly what this one rejects, spelled inside the grammar (§3.1).
    ///
    /// This is where a negation "introduced during editing" goes; the `NOT` node never exists.
    /// Each arm is one row of §3.1's complement-closure proof.
    public var complemented: LawNode {
        switch self {
        case .atom(let a):
            .atom(.init(attribute: a.attribute, subset: a.subset.complement))
        case .relational(let r):
            .relational(
                .init(
                    leading: r.leading, comparator: r.comparator.complemented,
                    trailing: r.trailing))
        case .contextual(let c):
            .contextual(
                .init(
                    current: c.current, comparator: c.comparator.complemented,
                    previous: c.previous))
        case .coupled(let l, let coupler, let r):
            switch coupler {
            // De Morgan, and both AND and OR live in the same family.
            case .and: .coupled(l.complemented, .or, r.complemented)
            case .or: .coupled(l.complemented, .and, r.complemented)
            // ¬(x XOR y) = x̄ XOR y — complement ONE side only.
            case .xor: .coupled(l.complemented, .xor, r)
            }
        case .guarded(let g):
            // The gate is untouched: ¬(IF g THEN A ELSE B) = IF g THEN Ā ELSE B̄.
            .guarded(
                .init(
                    gate: g.gate, gateValue: g.gateValue, branch: g.branch,
                    then: g.then.complement, otherwise: g.otherwise.complement))
        case .aggregate(let a):
            switch a {
            // Complement the COUNT SET, not the rank subset.
            case .count(let c):
                .aggregate(
                    .count(
                        .init(
                            attributes: c.attributes, rankIn: c.rankIn,
                            countIn: c.countIn.complement)))
            case .parity(let p):
                .aggregate(.parity(.init(attributes: p.attributes, isOdd: !p.isOdd)))
            }
        }
    }

    /// The constant this node's extension collapses to, or `nil` if it is a real law.
    ///
    /// Drives the Seal's bar, and is checked before `renderedNormalForm`. The merge in step 4
    /// can produce `0b0000`/`0b1111`, but that is only the *structural* route to a constant —
    /// the extension route is wider, since `x AND x̄` is unsatisfiable while an AND of two
    /// disjoint atoms on *different* attributes is not.
    ///
    /// - Complexity: builds a table, so ≈2 µs on a contextual draft. Runs once per Bench edit,
    ///   never per glyph.
    public var constantFold: Verdict? {
        let table = LawTable(self)
        if !table.isSatisfiable { return .reject }
        if !table.isFalsifiable { return .admit }
        return nil
    }

    /// This law in Rendered Normal Form (§3.4) — the one spelling the Bench lays out and the
    /// one spelling a suspended round stores.
    ///
    /// RNF is for **storage and display only**. It is explicitly not the equivalence test: two
    /// laws are the same law iff their extensions match (§3.6).
    ///
    /// - Precondition: `constantFold == nil`.
    /// - Complexity: O(leaves log leaves), at most 4 log 4.
    public var renderedNormalForm: LawNode {
        precondition(constantFold == nil, "a constant extension has no normal form (§4.3)")
        return normalised
    }

    /// The steps, without the precondition, so the recursion does not rebuild a table per node.
    var normalised: LawNode {
        switch self {
        // Step 1 is a no-op: the AST has no negation case at all.
        case .atom, .contextual, .guarded, .aggregate:
            return self

        // Step 3, relational half: operands into canonical attribute order, comparator flipped
        // to compensate. The only reordering RNF performs on operands.
        case .relational(let r):
            guard r.leading.rawValue > r.trailing.rawValue else { return self }
            return .relational(
                .init(
                    leading: r.trailing, comparator: r.comparator.flipped, trailing: r.leading))

        case .coupled(let lhs, let coupler, let rhs):
            let l = lhs.normalised
            let r = rhs.normalised

            // Step 4 — the same-attribute merge, which is what "unmasks a two-term law as a
            // one-term law before it can be emitted". Two ATOMS on one attribute only: a
            // Bridge on the same attribute pair does NOT merge, because that would be an
            // extension fact and RNF is not the equivalence test.
            if case .atom(let a) = l, case .atom(let b) = r, a.attribute == b.attribute {
                let merged: UInt8 =
                    switch coupler {
                    case .and: a.subset.intersection(b.subset)
                    case .or: a.subset.union(b.subset)
                    case .xor: a.subset.symmetricDifference(b.subset)
                    }
                // 0b0000 / 0b1111 are the constant cases; Subset4.init? rejects both and the
                // caller has already ruled them out via constantFold.
                if let subset = Subset4(rawValue: merged) {
                    return .atom(.init(attribute: a.attribute, subset: subset))
                }
            }

            // Step 2 — sort commutative operands. All three couplers are commutative.
            return LawNode.sortKey(l) <= LawNode.sortKey(r)
                ? .coupled(l, coupler, r)
                : .coupled(r, coupler, l)
        }
    }

    /// §3.4's `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)`.
    ///
    /// The fourth field is not total across productions, so it is pinned here: an atom's
    /// subset mask; for a relational or contextual the TRAILING attribute's canonical index;
    /// for a guard or aggregate a written-down ordinal over the payload. Never `hashValue` —
    /// Swift seeds that per process, and this ordering is stored on disk.
    public static func sortKey(_ node: LawNode) -> SIMD4<Int> {
        switch node {
        case .atom(let a):
            SIMD4(0, Int(a.attribute.rawValue), 0, Int(a.subset.rawValue))
        case .relational(let r):
            SIMD4(
                1, Int(r.leading.rawValue), Int(r.comparator.rawValue), Int(r.trailing.rawValue))
        case .contextual(let c):
            SIMD4(
                2, Int(c.current.rawValue), Int(c.comparator.rawValue), Int(c.previous.rawValue))
        case .guarded(let g):
            SIMD4(
                3, Int(g.gate.rawValue), Int(g.gateValue),
                Int(g.then.rawValue) << 4 | Int(g.otherwise.rawValue))
        case .aggregate(let a):
            switch a {
            case .count(let c):
                SIMD4(
                    4, Int(c.attributes.rawValue), Int(c.rankIn.rawValue), Int(c.countIn.rawValue))
            case .parity(let p):
                SIMD4(4, Int(p.attributes.rawValue), 0, p.isOdd ? 1 : 0)
            }
        // Guards and aggregates never appear under a coupler (§4.2), so this row exists only
        // so the key is total and the switch needs no `default:`.
        case .coupled:
            SIMD4(5, 0, 0, 0)
        }
    }
}

extension SIMD4 where Scalar == Int {
    static func <= (lhs: Self, rhs: Self) -> Bool {
        for i in 0..<4 {
            if lhs[i] != rhs[i] { return lhs[i] < rhs[i] }
        }
        return true
    }
}

extension CountSet {
    /// §3.1: `¬COUNT(A, S, C) = COUNT(A, S, C̄)` — the complement is over the count set's own
    /// universe `0…arity`, which is why the type carries its arity.
    public var complement: CountSet {
        let full = UInt8((1 << (arity + 1)) - 1)
        // The complement of a non-empty proper subset is a non-empty proper subset, so this
        // never fails.
        return CountSet(rawValue: full & ~rawValue, over: arity) ?? self
    }
}
