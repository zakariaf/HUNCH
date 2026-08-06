public import Glyphs
public import Laws

/// Which of an attribute's four ranks a rule-tile admits — the Bench's editing buffer.
///
/// **Not `Subset4`.** `Subset4` is the *grammar's* subset and refuses its two degenerate values
/// by construction (§3.2), which is exactly right for a law and exactly wrong for a draft: a
/// player has to be able to pass through "nothing lit" on the way from one subset to another.
/// `RankSet` is all sixteen, and the two the grammar refuses are the two the Bench draws as
/// **inert** (§4.2: "14 usable states per ramp; 0 lit and 4 lit are inert").
public struct RankSet: Hashable, Sendable, Codable {
    public let bitmask: UInt8

    public init(bitmask: UInt8) { self.bitmask = bitmask & 0b1111 }

    public init(ranks: some Sequence<Int>) {
        var raw: UInt8 = 0
        for rank in ranks where (0..<4).contains(rank) { raw |= 1 << UInt8(rank) }
        self.init(bitmask: raw)
    }

    public static let empty = RankSet(bitmask: 0)
    public static let full = RankSet(bitmask: 0b1111)
    public static let all: [RankSet] = (0..<16).map { RankSet(bitmask: UInt8($0)) }

    public var count: Int { bitmask.nonzeroBitCount }

    public func contains(rank: Int) -> Bool {
        (0..<4).contains(rank) && bitmask & (1 << UInt8(rank)) != 0
    }

    public func toggling(rank: Int) -> RankSet {
        guard (0..<4).contains(rank) else { return self }
        return RankSet(bitmask: bitmask ^ (1 << UInt8(rank)))
    }

    /// **One inert state, not two.** Empty admits nothing and full admits everything; both are
    /// constant, both are outside the grammar, and they draw identically because nobody should
    /// have to learn the difference (§4.3). The two causes are distinguished in exactly one
    /// place — the VoiceOver announcement — because audio has no drawing to collapse them into.
    ///
    /// This predicate is **core**, and it is the same one `SealBar` reads. A view-side
    /// `admitted.isEmpty || admitted.count == 4` will disagree with the Seal on some subset and
    /// nobody will find out which.
    public var isVacuous: Bool { count == 0 || count == 4 }

    /// The grammar's subset, or `nil` when this draft is not yet a law.
    public var subset4: Subset4? { Subset4(rawValue: bitmask) }
}
