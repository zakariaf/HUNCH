public import Glyphs

/// A 64-bit bucket for a law's extension. **Not an identity.**
///
/// §3.6 requires a full compare on collision, and `LawSet` is where that happens. At 300
/// stored Codex pages the birthday probability is ≈2⁻⁴⁵, which is why 64 bits is enough — and
/// why the full compare is still written.
///
/// The hash is stable **across processes and releases**, because `codex-index.json` persists
/// it. Never `Hasher`/`hashValue`: Swift seeds those per process, so a Codex written today
/// would not find its own pages tomorrow.
public struct LawKey: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) { self.rawValue = rawValue }

    /// Folds the table's words through `SplitMix64.mix`, which §11.6 already fixes and E01·T05
    /// already shipped. The finaliser is CALLED, never re-typed — a second transcription of
    /// those constants is what makes a globally shared derivation a coin flip.
    public init(_ table: LawTable) {
        var acc: UInt64 = 0x9E37_79B9_7F4A_7C15
        table.forEachWord { word in
            acc = SplitMix64.mix(acc ^ word)
        }
        // Fold the arity in, so a stateless table and its own lift are different buckets even
        // though they are the same law — LawSet's full compare is what reunites them.
        acc = SplitMix64.mix(acc ^ (table.arity == .contextual ? 1 : 0))
        rawValue = acc
    }
}

/// A set of law extensions with §3.6's two-stage lookup: bucket by `LawKey`, then full compare.
public struct LawSet: Sendable {
    private var buckets: [LawKey: [LawTable]] = [:]
    public private(set) var count = 0

    public init() {}

    @discardableResult
    public mutating func insert(_ table: LawTable) -> Bool {
        insert(table, forcedKey: nil)
    }

    /// `forcedKey` exists only so a test can exercise the collision path — a bucket collision
    /// is otherwise unreachable in a test, and an unreachable branch is an untested branch.
    @discardableResult
    package mutating func insert(_ table: LawTable, forcedKey: LawKey?) -> Bool {
        let key = forcedKey ?? LawKey(table)
        var bucket = buckets[key, default: []]
        if bucket.contains(where: { LawTable.equalInCommonSpace($0, table) }) { return false }
        bucket.append(table)
        buckets[key] = bucket
        count += 1
        return true
    }

    public func contains(_ table: LawTable) -> Bool {
        contains(table, forcedKey: nil)
    }

    package func contains(_ table: LawTable, forcedKey: LawKey?) -> Bool {
        let key = forcedKey ?? LawKey(table)
        return buckets[key, default: []].contains { LawTable.equalInCommonSpace($0, table) }
    }
}
