public import Glyphs

/// A resolved law: the AST, its extension, and the metrics §5.1's modifiers read.
///
/// Deliberately **not** `Codable` (`08 §3`). Persist `node`; a contextual table costs ≈2 µs to
/// rebuild and 8 KiB to store, and storing a derived value invites the two to disagree.
public struct Law: Hashable, Sendable {
    public let node: LawNode
    public let table: LawTable
    public let metrics: Metrics

    /// The five quantities §5.1's modifiers read.
    ///
    /// Resolved in `init`, never as computed properties: `difficulty(of:)` is called inside a
    /// 200-attempt rejection loop, 10,000 laws × 8 bands per test run, and `marginals` is
    /// O(universe).
    public struct Metrics: Hashable, Sendable {
        public let admitRate: Double
        public let marginalDeficit: Double
        public let leafCount: Int
        public let freeAttributeCount: Int
        public let scatteredSubsetCount: Int
    }

    /// - Precondition: `node.structuralFault == nil`.
    public init(_ node: LawNode, masks: MaskTable = .resident) {
        precondition(
            node.structuralFault == nil,
            "law is not grammar-valid: \(String(describing: node.structuralFault))")
        self.node = node
        let table = LawTable(node, masks: masks)
        self.table = table
        metrics = Metrics(
            admitRate: table.admitRate,
            marginalDeficit: Self.marginalDeficit(of: table),
            leafCount: node.leafCount,
            freeAttributeCount: 4 - node.namedAttributes.count,
            scatteredSubsetCount: Self.scatteredSubsetCount(of: node))
    }

    // §5.1's published spellings, forwarded so the code reads as the design writes it.
    public var admitRate: Double { metrics.admitRate }
    public var marginalDeficit: Double { metrics.marginalDeficit }
    public var leafCount: Int { metrics.leafCount }
    public var freeAttributeCount: Int { metrics.freeAttributeCount }
    public var scatteredSubsetCount: Int { metrics.scatteredSubsetCount }

    /// §5.1's `m2`, the key modifier: *does any single value predict the verdict?*
    ///
    /// `1 − min(1, maxφ |P(admit | φ) − p| / 0.35)` over the 16 `(attribute, value)`
    /// conditions. An atom scores 0 — vary that attribute and the lamp answers. A flat XOR, a
    /// relational law and a parity law all score 1, because no single value predicts anything.
    static func marginalDeficit(of table: LawTable) -> Double {
        let p = table.admitRate
        let worst = table.marginals.map { abs($0 - p) }.max() ?? 0
        return 1 - min(1, worst / 0.35)
    }

    /// Leaves whose subset is not a contiguous run of ranks. Only atoms, guard branches and an
    /// aggregate's `rankIn` carry a subset — a `CountSet` is **not** a rank subset and does not
    /// count.
    static func scatteredSubsetCount(of node: LawNode) -> Int {
        switch node {
        case .atom(let a):
            a.subset.isContiguousRun ? 0 : 1
        case .relational, .contextual:
            0
        case .coupled(let l, _, let r):
            scatteredSubsetCount(of: l) + scatteredSubsetCount(of: r)
        case .guarded(let g):
            (g.then.isContiguousRun ? 0 : 1) + (g.otherwise.isContiguousRun ? 0 : 1)
        case .aggregate(let a):
            switch a {
            case .count(let c): c.rankIn.isContiguousRun ? 0 : 1
            case .parity: 0
            }
        }
    }
}
