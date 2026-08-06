public import CoreGraphics

/// §6.9's par crossing — the round's one non-verdict event — as a pure value.
///
/// Two rows, one state: below par the par row counts up and the cap row waits unlit; at par the
/// par row inverts to a single solid rule and the cap row lights on the *same frame*; past par
/// the cap row empties, one stop per probe, and when it empties the round is over.
///
/// No numerals and no countdown anywhere: §10.5 permits exactly three signals of difficulty and
/// a number is not one of them.
public nonisolated struct ParRowModel: Equatable, Sendable {
    public let probesUsed: Int
    public let par: Int
    public let cap: Int

    public init(probesUsed: Int, par: Int, cap: Int) {
        self.probesUsed = probesUsed
        self.par = par
        self.cap = cap
    }

    /// One-way. A row that could un-cross would be telling the player their budget had been
    /// given back, which nothing in the round can do.
    public var hasCrossed: Bool { probesUsed >= par }

    public var parMode: TickRow.Mode {
        hasCrossed ? .crossed(total: par) : .count(filled: probesUsed, total: par)
    }

    /// **`total` is `cap − par`, not `cap`**: the cap row is the budget that remains *after*
    /// par, which is what "begins emptying" means. At band 5 that is 14 stops.
    public var capMode: TickRow.Mode {
        let total = max(0, cap - par)
        return .cap(remaining: max(0, min(total, cap - probesUsed)), total: total)
    }

    public var capIsLit: Bool { hasCrossed }

    /// The two rows' tick counts, so a caller can size each row to its own drawn length rather
    /// than to the slot it sits in.
    public var parTotal: Int { par }
    public var capTotal: Int { max(0, cap - par) }

    /// **A spent cap stop is an absence, never a dimmed stop.** Dimming would put a second,
    /// weaker copy of the same fact on the row and reintroduce exactly the tint channel that
    /// the height-based state channel removed. The concept must not exist, which is why this is
    /// a constant zero rather than a computation.
    public var dimmedStopCount: Int { 0 }
}
