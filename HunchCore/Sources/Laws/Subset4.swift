public import Glyphs

/// A `<subset4>` from §3.2: a bitmask over the four values of one attribute, bit *v* meaning
/// the value with ordinal *v*.
///
/// The empty and full masks are **unrepresentable**, not merely rejected: §3.2 forbids both,
/// and a value that cannot exist needs no guardrail. That is why `init?(rawValue:)` is the only
/// way in.
public struct Subset4: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UInt8

    public init?(rawValue: UInt8) {
        guard (1...14).contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// The 14 legal subsets, ascending.
    public static let all: [Subset4] = (1...14).compactMap { Subset4(rawValue: $0) }

    public var count: Int { rawValue.nonzeroBitCount }

    public func contains(ordinal: Int) -> Bool { rawValue & (1 << UInt8(ordinal)) != 0 }

    /// `pips ∈ {1,3}` is far harder to conjecture than `pips ∈ {1,2}` — §5.1's `m5` reads this,
    /// and §5.1 states that 5 of the 14 are scattered.
    public var isContiguousRun: Bool {
        let v = rawValue
        // A contiguous run of set bits: shifting off the low zeros leaves a mask of the form
        // 2^k − 1.
        let shifted = v >> UInt8(v.trailingZeroBitCount)
        return (shifted & (shifted &+ 1)) == 0
    }

    // Set algebra returns a bare UInt8 because the result may be 0 or 15 — which is exactly
    // RNF's constant case (§3.4 step 4), and the caller decides what to do about it.
    public func intersection(_ other: Subset4) -> UInt8 { rawValue & other.rawValue }
    public func union(_ other: Subset4) -> UInt8 { rawValue | other.rawValue }
    public func symmetricDifference(_ other: Subset4) -> UInt8 { rawValue ^ other.rawValue }

    /// §3.1: the 14 subsets are closed under complement, which is one of the five cases that
    /// make `NOT` unnecessary in the grammar.
    public var complement: Subset4 {
        // 15 − rawValue is in 1...14 whenever rawValue is, so this never fails.
        Subset4(rawValue: 0b1111 & ~rawValue) ?? self
    }
}

/// A `<attrSet>`: a subset of the four attributes with `|set| ≥ 3`, so exactly five values.
public struct AttributeSet: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UInt8

    public init?(rawValue: UInt8) {
        guard rawValue.nonzeroBitCount >= 3, rawValue <= 0b1111 else { return nil }
        self.rawValue = rawValue
    }

    public init?(_ attributes: Glyph.Attribute...) {
        let mask = attributes.reduce(UInt8(0)) { $0 | (1 << $1.rawValue) }
        self.init(rawValue: mask)
    }

    public static let all: [AttributeSet] = [0b0111, 0b1011, 0b1101, 0b1110, 0b1111]
        .compactMap { AttributeSet(rawValue: $0) }

    public var count: Int { rawValue.nonzeroBitCount }

    public var members: [Glyph.Attribute] {
        Glyph.Attribute.allCases.filter { rawValue & (1 << $0.rawValue) != 0 }
    }
}

/// A `<countSet>`: a non-empty **proper** subset of `0…k` where `k = |attrSet|`. Arity-dependent,
/// so it carries its arity — 14 values at `k = 3`, 30 at `k = 4`.
public struct CountSet: Hashable, Sendable {
    public let rawValue: UInt8
    public let arity: Int

    public init?(rawValue: UInt8, over arity: Int) {
        guard (3...4).contains(arity) else { return nil }
        let ceiling = UInt8((1 << (arity + 1)) - 2)
        guard (1...ceiling).contains(rawValue) else { return nil }
        self.rawValue = rawValue
        self.arity = arity
    }

    public static func all(over arity: Int) -> [CountSet] {
        guard (3...4).contains(arity) else { return [] }
        let ceiling = UInt8((1 << (arity + 1)) - 2)
        return (1...ceiling).compactMap { CountSet(rawValue: $0, over: arity) }
    }

    public func contains(count: Int) -> Bool { rawValue & (1 << UInt8(count)) != 0 }
}
