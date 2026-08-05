public import Glyphs

extension Law {
    /// Whether this is the same law as `other` — §3.6's only test.
    ///
    /// Spelling, operand order, coupler choice and complement direction are all irrelevant,
    /// which is exactly what §4.5 promises the player. **Nothing in HUNCH compares two laws by
    /// AST except G10**, which does so on purpose.
    public func isSameLaw(as other: Law) -> Bool {
        LawTable.equalInCommonSpace(table, other.table)
    }

    public var key: LawKey { LawKey(table) }

    /// Leaves whose presence does not change the extension (§3.6, G5).
    ///
    /// For each leaf: rebuild with ⊤ substituted, rebuild with ⊥ substituted. If **either**
    /// rebuild equals the original, the leaf is dead. Both substitutions are required —
    /// a subsumed `AND` is caught by removal, and `XOR(a, b)` has no meaningful removal at
    /// all, so it is only caught by the ⊥ rebuild.
    ///
    /// - Complexity: 2 × leafCount rebuilds, ≈16 µs for a four-leaf contextual law.
    ///   Generation-time only; never in a hot loop.
    public var deadLeaves: [Leaf] {
        let all = node.leaves
        return all.indices.compactMap { index in
            let top = LawTable(node, forcingLeaf: index, to: true)
            let bottom = LawTable(node, forcingLeaf: index, to: false)
            let dead =
                LawTable.equalInCommonSpace(top, table)
                || LawTable.equalInCommonSpace(bottom, table)
            return dead ? all[index] : nil
        }
    }

    /// §3.6: attribute `a` is live iff some non-identity relabelling of its four values changes
    /// the table.
    ///
    /// **The permutation is applied to `cur` and `prev` INDEPENDENTLY**, and that is the whole
    /// content of this property. The naive contextual implementation permutes both halves of
    /// the pair index at once — under which `RANK pips(cur) == PREV RANK pips` is invariant,
    /// because equality survives any relabelling applied to both sides. `pips` would read as
    /// dead, G6 would reject it, and §3.3's entry-level contextual law — the one that *"must
    /// exist"* — would be silently deleted from bands 5 and 7.
    ///
    /// - Complexity: O(3 × 2 × 4) table permutes — microseconds.
    public var pivotalAttributes: Set<Glyph.Attribute> {
        // The three non-identity permutations of four values that suffice: a transposition, a
        // 3-cycle and a full reversal. Any relabelling the table depends on moves one of them.
        let permutations: [[UInt8]] = [[1, 0, 2, 3], [1, 2, 0, 3], [3, 2, 1, 0]]
        var live: Set<Glyph.Attribute> = []
        let positions: [LawTable.Position] =
            table.arity == .contextual ? [.current, .previous] : [.current]
        for attribute in Glyph.Attribute.allCases {
            outer: for permutation in permutations {
                for position in positions {
                    let permuted = table.permuting(attribute, by: permutation, in: position)
                    if !LawTable.equalInCommonSpace(permuted, table) {
                        live.insert(attribute)
                        break outer
                    }
                }
            }
        }
        return live
    }

    /// G6: every attribute the law names is pivotal.
    public var hasLiveNamedAttributes: Bool {
        node.namedAttributes.isSubset(of: pivotalAttributes)
    }
}
