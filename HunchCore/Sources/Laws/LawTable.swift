public import Glyphs

/// A law's **extension** — the design's word (§2's terminology table). `extension` is a Swift
/// keyword, so the type is `LawTable` and the file is never `Extension.swift` (`01 P28`).
///
/// §3.6 makes this the canonical form: *syntax is never compared*. Two laws are the same law
/// iff their tables are bit-identical in the common space.
public struct LawTable: Hashable, Sendable {
    public enum Arity: Hashable, Sendable { case stateless, contextual }

    @usableFromInline
    enum Storage: Hashable, Sendable {
        case stateless(Bitboard256)
        case contextual(Bitboard65536)
    }

    @usableFromInline let storage: Storage

    init(_ storage: Storage) { self.storage = storage }

    public init(stateless board: Bitboard256) { storage = .stateless(board) }
    public init(contextual board: Bitboard65536) { storage = .contextual(board) }

    // ── Resolution is MASK COMPOSITION, not evaluation ───────────────────────────────────
    // The AST is walked ONCE and every leaf reads a precomputed mask. Nothing here iterates
    // the deck: §3.6's "never walk the AST per glyph" is the whole reason MaskTable exists.

    public init(_ node: LawNode, masks: MaskTable = .resident) {
        switch node {
        case .atom(let a):
            storage = .stateless(masks.atom(a.attribute, subset: a.subset.rawValue))

        case .relational(let r):
            storage = .stateless(masks.relational(r.leading, r.comparator, r.trailing))

        // The one leaf that scatters. A row depends only on `prev`'s value of the TRAILING
        // attribute, so there are four distinct rows and the pair table is those four tiled
        // 64 times each (§3.6). Never built glyph by glyph.
        case .contextual(let c):
            storage = .contextual(
                Bitboard65536(rows: { previous in
                    let ordinal = Deck.glyph(id: previous).ordinal(of: c.previous)
                    return masks.contextualRow(
                        c.current, c.comparator, previous: c.previous, previousOrdinal: ordinal)
                }))

        case .guarded(let g):
            // (gate & then) | (~gate & otherwise) — three reads, four word-ops.
            let gate = masks.atom(g.gate, subset: UInt8(1) << g.gateValue)
            let then = masks.atom(g.branch, subset: g.then.rawValue)
            let otherwise = masks.atom(g.branch, subset: g.otherwise.rawValue)
            storage = .stateless((gate & then) | (~gate & otherwise))

        case .aggregate(let a):
            switch a {
            case .count(let c):
                storage = .stateless(
                    masks.count(
                        attributeSet: c.attributes.rawValue, subset: c.rankIn.rawValue,
                        countSet: c.countIn.rawValue))
            case .parity(let p):
                storage = .stateless(
                    masks.parity(attributeSet: p.attributes.rawValue, bit: p.isOdd ? 1 : 0))
            }

        case .coupled(let lhs, _, let rhs):
            let l = LawTable(lhs, masks: masks)
            let r = LawTable(rhs, masks: masks)
            guard case .coupled(_, let coupler, _) = node else { preconditionFailure() }
            storage = LawTable.combine(l, coupler, r).storage
        }
    }

    /// Combines two tables under a coupler, lifting the stateless one when the arities differ —
    /// §3.6's "comparison always happens at the larger of the two arities".
    static func combine(_ lhs: LawTable, _ coupler: Coupler, _ rhs: LawTable) -> LawTable {
        switch (lhs.storage, rhs.storage) {
        case (.stateless(let a), .stateless(let b)):
            switch coupler {
            case .and: return LawTable(.stateless(a & b))
            case .or: return LawTable(.stateless(a | b))
            case .xor: return LawTable(.stateless(a ^ b))
            }
        default:
            let a = lhs.liftedBoard
            let b = rhs.liftedBoard
            switch coupler {
            case .and: return LawTable(.contextual(a & b))
            case .or: return LawTable(.contextual(a | b))
            case .xor: return LawTable(.contextual(a ^ b))
            }
        }
    }

    @usableFromInline
    var liftedBoard: Bitboard65536 {
        switch storage {
        case .stateless(let b): Bitboard65536(lifting: b)
        case .contextual(let b): b
        }
    }

    // ── Shape ────────────────────────────────────────────────────────────────────────────

    public var arity: Arity {
        switch storage {
        case .stateless: .stateless
        case .contextual: .contextual
        }
    }

    public var universeSize: Int { arity == .stateless ? 256 : 65_536 }

    public var popCount: Int {
        switch storage {
        case .stateless(let b): b.count
        case .contextual(let b): b.count
        }
    }

    /// For a contextual law this is over 65,536 PAIRS (§5.3), never over 256.
    public var admitRate: Double { Double(popCount) / Double(universeSize) }

    public var isSatisfiable: Bool { popCount >= 1 }  // G1
    public var isFalsifiable: Bool { popCount <= universeSize - 1 }  // G2
    public var isConstant: Bool { !isSatisfiable || !isFalsifiable }

    /// This table tiled into pair space. Idempotent on a contextual table.
    public func lifted() -> LawTable { LawTable(.contextual(liftedBoard)) }

    /// How many entries of the common space the two tables disagree about — `|T₁ △ T₂|`.
    ///
    /// Lifted where the arities differ, which is §4.5's comparison rule: a stateless table and a
    /// contextual one are compared at the **larger** arity, so a stateless law that happens to
    /// agree on the 256 is still counted as disagreeing on the pairs where it cannot.
    public func disagreementCount(with other: LawTable) -> Int {
        switch (storage, other.storage) {
        case (.stateless(let a), .stateless(let b)): (a ^ b).count
        default: (liftedBoard ^ other.liftedBoard).count
        }
    }

    /// §3.6: `P == lift(P & FULL256)`. G7's test, negated.
    public var isSecretlyStateless: Bool {
        switch storage {
        case .stateless: true
        case .contextual(let b): b.isStateless
        }
    }

    /// The 256-bit slice for one pinned `prev` — what the live Assay draws (§4.3, §5.5).
    /// A stateless table returns its own bits for every `prev`.
    /// - Complexity: O(1).
    public func row(after previous: Glyph) -> Bitboard256 {
        switch storage {
        case .stateless(let b): b
        case .contextual(let b): b.row(after: previous.id)
        }
    }

    public func admits(_ current: Glyph, after previous: Glyph) -> Bool {
        switch storage {
        case .stateless(let b): b.contains(current.id)
        case .contextual(let b): b.contains(current: current.id, after: previous.id)
        }
    }

    /// The 16 `(attribute, value)` marginals, in canonical attribute order then rank order.
    ///
    /// Conditions are on the **current** glyph; for a contextual table the probability is taken
    /// over all 65,536 ordered pairs whose current glyph satisfies the condition (§5.1 m2).
    public var marginals: [Double] {
        var out: [Double] = []
        out.reserveCapacity(16)
        for attribute in Glyph.Attribute.allCases {
            for ordinal in 0..<4 {
                let condition = MaskTable.resident.atom(attribute, subset: UInt8(1) << ordinal)
                switch storage {
                case .stateless(let b):
                    out.append(Double((b & condition).count) / 64)
                case .contextual(let b):
                    // 64 current glyphs × 256 prev values = 16,384 pairs meet the condition.
                    var hits = 0
                    for previous in 0..<256 {
                        hits += (b.row(after: previous) & condition).count
                    }
                    out.append(Double(hits) / 16_384)
                }
            }
        }
        return out
    }
}
