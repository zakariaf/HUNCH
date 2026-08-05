/// The extension of a contextual law: which of the 65,536 ordered `(prev, cur)` pairs it admits.
///
/// 1024 `UInt64`s, bit `(prev*256 + cur)`, exactly as §3.6 fixes the index. `prev` is the
/// previously *probed* glyph regardless of verdict (§3.5); at position 0 it is the seed glyph.
/// There is no third axis and there will not be one — §3.5 rules out depth-2 statefulness, and
/// the table would grow from 8 KiB to 2 MiB.
///
/// Never persisted. A Codex page stores the AST and rebuilds this in ≈2 µs (§3.6).
/// `Hashable` because §3.6 makes the extension the dedup key: the Codex's identity is a
/// 64-bit hash of the word array, with a full compare only on collision.
public struct Bitboard65536: Hashable, Sendable {

    /// 65,536 bits ÷ 64.
    public static let wordCount = 1_024

    @usableFromInline internal private(set) var words: ContiguousArray<UInt64>

    /// The empty table.
    public init() {
        words = ContiguousArray(repeating: 0, count: Self.wordCount)
    }

    /// Tiles `table` across every value of `prev` — §3.6's `lift(T) = TILE * T`.
    ///
    /// §3.6 states this as a bignum multiply. Do not write one: 256 bits is exactly four 64-bit
    /// words, so every block boundary `prev*256` is a multiple of 64 and the multiply
    /// degenerates to a word-aligned copy with no shifting and, by construction, no carries.
    public init(lifting table: Bitboard256) {
        var words = ContiguousArray<UInt64>(repeating: 0, count: Self.wordCount)
        for previous in 0..<256 {
            let base = previous << 2  // prev*256 bits = prev*4 words
            words[base] = table.word(at: 0)
            words[base + 1] = table.word(at: 1)
            words[base + 2] = table.word(at: 2)
            words[base + 3] = table.word(at: 3)
        }
        self.words = words
    }

    /// Materialises a contextual table from one row per `prev` — the four-row tiling of §3.6.
    /// - Complexity: O(256) calls to `row`, 1024 word writes, ≈2 µs.
    public init(rows row: (Int) -> Bitboard256) {
        var words = ContiguousArray<UInt64>(repeating: 0, count: Self.wordCount)
        for previous in 0..<256 {
            let r = row(previous)
            let base = previous << 2
            words[base] = r.word(at: 0)
            words[base + 1] = r.word(at: 1)
            words[base + 2] = r.word(at: 2)
            words[base + 3] = r.word(at: 3)
        }
        self.words = words
    }

    public static let full = Bitboard65536(lifting: .full)

    public var count: Int {
        words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    public var isEmpty: Bool {
        words.allSatisfy { $0 == 0 }
    }

    @inlinable
    public func contains(current: Int, after previous: Int) -> Bool {
        precondition((0..<256).contains(current), "current \(current) is outside 0…255")
        precondition((0..<256).contains(previous), "previous \(previous) is outside 0…255")
        let bit = previous << 8 | current
        return words[bit >> 6] & (1 << UInt64(bit & 63)) != 0
    }

    @inlinable
    public mutating func insert(current: Int, after previous: Int) {
        precondition((0..<256).contains(current), "current \(current) is outside 0…255")
        precondition((0..<256).contains(previous), "previous \(previous) is outside 0…255")
        let bit = previous << 8 | current
        words[bit >> 6] |= 1 << UInt64(bit & 63)
    }

    /// The 256-glyph row this table admits when the previous glyph was `previous`.
    public func row(after previous: Int) -> Bitboard256 {
        precondition((0..<256).contains(previous), "previous \(previous) is outside 0…255")
        let base = previous << 2
        return Bitboard256(
            word0: words[base], word1: words[base + 1],
            word2: words[base + 2], word3: words[base + 3])
    }

    /// §3.6's `P & FULL256`: the low 256 bits, which is the row for `prev == 0`.
    public var statelessProjection: Bitboard256 { row(after: 0) }

    /// §3.6's *"is this contextual law secretly stateless?"* — `P == lift(P & FULL256)`.
    /// G7 (§5.3) requires this to be `false` at bands 5 and 7.
    public var isStateless: Bool { self == Bitboard65536(lifting: statelessProjection) }

    /// Comparison at the larger of the two arities (§3.6) — how a stateless declaration is
    /// judged against a contextual hidden law (§4.5).
    public func matches(_ table: Bitboard256) -> Bool { self == Bitboard65536(lifting: table) }

    public static prefix func ~ (board: Self) -> Self {
        var out = board
        for i in 0..<wordCount { out.words[i] = ~board.words[i] }
        return out
    }

    public static func & (lhs: Self, rhs: Self) -> Self {
        var out = lhs
        for i in 0..<wordCount { out.words[i] = lhs.words[i] & rhs.words[i] }
        return out
    }

    public static func | (lhs: Self, rhs: Self) -> Self {
        var out = lhs
        for i in 0..<wordCount { out.words[i] = lhs.words[i] | rhs.words[i] }
        return out
    }

    public static func ^ (lhs: Self, rhs: Self) -> Self {
        var out = lhs
        for i in 0..<wordCount { out.words[i] = lhs.words[i] ^ rhs.words[i] }
        return out
    }
}
