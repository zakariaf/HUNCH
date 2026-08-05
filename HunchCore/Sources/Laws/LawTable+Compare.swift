public import Glyphs

extension LawTable {
    /// Iterates the raw words, whatever the arity — 4 or 1024.
    func forEachWord(_ body: (UInt64) -> Void) {
        switch storage {
        case .stateless(let b):
            for i in 0..<4 { body(b.word(at: i)) }
        case .contextual(let b):
            for previous in 0..<256 {
                let row = b.row(after: previous)
                for i in 0..<4 { body(row.word(at: i)) }
            }
        }
    }

    /// §3.6's only comparison: bit-for-bit in the **common space**. If the arities differ, the
    /// stateless one is lifted.
    /// - Complexity: O(1) stateless, O(1024 words) mixed or contextual.
    public static func equalInCommonSpace(_ lhs: LawTable, _ rhs: LawTable) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.stateless(let a), .stateless(let b)): a == b
        default: lhs.liftedBoard == rhs.liftedBoard
        }
    }

    /// Which half of the pair index a permutation applies to.
    public enum Position: Hashable, Sendable { case current, previous }

    /// This table with `attribute`'s four values relabelled by `permutation`, applied to
    /// `position` **only**.
    ///
    /// Independence is the whole point — see `Law.pivotalAttributes`.
    package func permuting(
        _ attribute: Glyph.Attribute, by permutation: [UInt8], in position: Position
    ) -> LawTable {
        // relabel[id] = the glyph id with `attribute`'s ordinal mapped through `permutation`.
        var relabel = [Int](repeating: 0, count: 256)
        for id in 0..<256 {
            let g = Deck.glyph(id: id)
            let mapped = Int(permutation[g.ordinal(of: attribute)])
            let shift = (3 - Int(attribute.rawValue)) * 2
            relabel[id] = (id & ~(0b11 << shift)) | (mapped << shift)
        }

        switch storage {
        case .stateless(let b):
            guard position == .current else { return self }
            var out = Bitboard256.empty
            for id in 0..<256 where b.contains(id) { out.insert(relabel[id]) }
            return LawTable(.stateless(out))
        case .contextual(let b):
            var out = Bitboard65536()
            for previous in 0..<256 {
                let row = b.row(after: previous)
                let targetPrev = position == .previous ? relabel[previous] : previous
                for current in 0..<256 where row.contains(current) {
                    let targetCur = position == .current ? relabel[current] : current
                    out.insert(current: targetCur, after: targetPrev)
                }
            }
            return LawTable(.contextual(out))
        }
    }

    /// Resolve `node`, forcing the leaf at `index` to a constant.
    ///
    /// Substitution is a **resolver** parameter, not an AST edit: the grammar has no ⊤ or ⊥
    /// node and must not gain one, or it would leak into `Codable`.
    package init(_ node: LawNode, forcingLeaf index: Int, to constant: Bool) {
        var counter = 0
        self = LawTable.resolve(node, forcing: index, to: constant, counter: &counter)
    }

    private static func resolve(
        _ node: LawNode, forcing index: Int, to constant: Bool, counter: inout Int
    ) -> LawTable {
        let start = counter
        let leafCount = node.leafCount
        // Only a coupled node can have the forced leaf in one sub-tree; every other production
        // is atomic with respect to substitution.
        if case .coupled(let lhs, let coupler, let rhs) = node {
            let l = resolve(lhs, forcing: index, to: constant, counter: &counter)
            let r = resolve(rhs, forcing: index, to: constant, counter: &counter)
            return LawTable.combine(l, coupler, r)
        }
        counter += leafCount
        if index >= start, index < start + leafCount {
            return LawTable(.stateless(constant ? .full : .empty))
        }
        return LawTable(node)
    }
}
