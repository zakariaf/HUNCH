/// The six ordinal comparators of §3.2's `<cmp>` production.
///
/// They appear only on relational and contextual terms: §3.1 collapses every comparator
/// against a constant into a subset, so there is no operator dimension at the atom level at
/// all. The raw values are RNF's `cmpOrdinal` (§3.4 step 2) and are therefore a stored sort
/// key — reordering the cases relays out every saved Bench draft.
public enum Comparator: UInt8, CaseIterable, Sendable, Codable {
    case eq, neq, lt, lte, gt, gte

    /// Whether this comparator holds between two ranks.
    ///
    /// Ranks are 1…4 (§2), but the answer is unchanged on 0-based ordinals, because
    /// `rank == ordinal + 1` is strictly increasing.
    public func matches(_ lhs: Int, _ rhs: Int) -> Bool {
        switch self {
        case .eq: lhs == rhs
        case .neq: lhs != rhs
        case .lt: lhs < rhs
        case .lte: lhs <= rhs
        case .gt: lhs > rhs
        case .gte: lhs >= rhs
        }
    }

    /// The comparator that means the same thing with the operands swapped.
    ///
    /// §3.4 step 3: relational operands are ordered by canonical attribute order and the
    /// comparator is *"flipped to compensate"*; contextual terms always render `cur`-leading
    /// and reach the converse reading by flipping this, never by moving `prev`.
    public var flipped: Comparator {
        switch self {
        case .eq: .eq
        case .neq: .neq
        case .lt: .gt
        case .lte: .gte
        case .gt: .lt
        case .gte: .lte
        }
    }

    /// The negation. §3.1: the six comparators are closed under complement, which is one of
    /// the five cases that make `NOT` unnecessary in the grammar.
    public var complemented: Comparator {
        switch self {
        case .eq: .neq
        case .neq: .eq
        case .lt: .gte
        case .lte: .gt
        case .gt: .lte
        case .gte: .lt
        }
    }
}
