/// The extension of a stateless law: which of the 256 glyphs it admits.
///
/// Four `UInt64`s, bit `id & 63` of word `id >> 6`, indexed by `Glyph.id`. §3.6 makes this the
/// canonical form of a law — *syntax is never compared* — so equality of two `Bitboard256`s is
/// equality of two laws, and it costs four word compares.
///
/// Four stored properties rather than `[UInt64]` or a tuple: an array is a heap allocation and
/// a retain/release per copy, which destroys §3.6's ≈20 ns build budget; a tuple synthesises no
/// `Equatable`/`Hashable`. This is a 32-byte trivially-copyable value with both synthesized.
public struct Bitboard256: Hashable, Sendable {
    public var word0: UInt64
    public var word1: UInt64
    public var word2: UInt64
    public var word3: UInt64

    @inlinable
    public init(word0: UInt64 = 0, word1: UInt64 = 0, word2: UInt64 = 0, word3: UInt64 = 0) {
        self.word0 = word0
        self.word1 = word1
        self.word2 = word2
        self.word3 = word3
    }

    @inlinable
    public init(ids: some Sequence<Int>) {
        self.init()
        for id in ids { insert(id) }
    }

    /// Nothing admitted. The all-0 table §3.4 step 5 constant-folds and the Seal bars on.
    public static let empty = Bitboard256()

    /// Everything admitted — §3.6's `FULL256`, spelled for `N33`.
    public static let full = Bitboard256(word0: .max, word1: .max, word2: .max, word3: .max)

    @inlinable
    public var count: Int {
        word0.nonzeroBitCount + word1.nonzeroBitCount + word2.nonzeroBitCount
            + word3.nonzeroBitCount
    }

    /// Cheaper than `count == 0`: four compares against zero, no popcounts.
    @inlinable
    public var isEmpty: Bool {
        word0 == 0 && word1 == 0 && word2 == 0 && word3 == 0
    }

    /// `Int` is not our own enum, so `W29`'s ban on `default:` does not apply and the arm is
    /// required. `W19`'s expression form.
    @inlinable
    public func word(at index: Int) -> UInt64 {
        switch index {
        case 0: word0
        case 1: word1
        case 2: word2
        case 3: word3
        default: preconditionFailure("word index \(index) is outside 0…3")
        }
    }

    /// - Precondition: `id` is in `0..<256`. A silent wrap here would corrupt a mask table
    ///   that four later epics trust.
    @inlinable
    public func contains(_ id: Int) -> Bool {
        precondition((0..<256).contains(id), "glyphID \(id) is outside 0…255")
        return word(at: id >> 6) & (1 << UInt64(id & 63)) != 0
    }

    /// - Precondition: `id` is in `0..<256`.
    @inlinable
    public mutating func insert(_ id: Int) {
        precondition((0..<256).contains(id), "glyphID \(id) is outside 0…255")
        let bit: UInt64 = 1 << UInt64(id & 63)
        switch id >> 6 {
        case 0: word0 |= bit
        case 1: word1 |= bit
        case 2: word2 |= bit
        case 3: word3 |= bit
        default: preconditionFailure("unreachable — id was range-checked")
        }
    }

    // The three combinators are exactly `Coupler.and/or/xor` (§3.2), and RNF's same-attribute
    // merge is stated in §3.4 as AND→∩, OR→∪, XOR→△. The operator spelling makes the evaluator
    // read like the BNF. Deliberately NOT `SetAlgebra`: that drags in subtracting, isSubset,
    // remove and an insert returning a tuple — a wider surface the design never uses, and it
    // invites callers to treat a law's extension as a collection to iterate.

    @inlinable
    public static prefix func ~ (board: Self) -> Self {
        Self(word0: ~board.word0, word1: ~board.word1, word2: ~board.word2, word3: ~board.word3)
    }

    @inlinable
    public static func & (lhs: Self, rhs: Self) -> Self {
        Self(
            word0: lhs.word0 & rhs.word0, word1: lhs.word1 & rhs.word1,
            word2: lhs.word2 & rhs.word2, word3: lhs.word3 & rhs.word3)
    }

    @inlinable
    public static func | (lhs: Self, rhs: Self) -> Self {
        Self(
            word0: lhs.word0 | rhs.word0, word1: lhs.word1 | rhs.word1,
            word2: lhs.word2 | rhs.word2, word3: lhs.word3 | rhs.word3)
    }

    @inlinable
    public static func ^ (lhs: Self, rhs: Self) -> Self {
        Self(
            word0: lhs.word0 ^ rhs.word0, word1: lhs.word1 ^ rhs.word1,
            word2: lhs.word2 ^ rhs.word2, word3: lhs.word3 ^ rhs.word3)
    }
}
