public import Glyphs
public import Laws

/// §4.3's machined bar: the Seal is **physically barred** until the draft is a law.
///
/// Pressing a barred Seal pulses the offending rail and nothing else. **No error text, no error
/// state, no modal** — the machine simply is not ready, and a bar across the key says that in a
/// language a player already has. Which is why this type answers *which* rail, not merely
/// whether: a pulse on the wrong rail is worse than no pulse at all.
public enum SealBar {

    /// Why the Seal is barred. Ordered by how the Bench is built, so the reason a player is
    /// shown is the one nearest the edit they just made.
    public enum Reason: Equatable, Sendable {
        /// A ramp with 0 or 4 cells lit — §4.2's inert pair, and the same `RankSet.isVacuous`
        /// the rail draws itself with.
        case inertRail(index: Int)
        /// A Bridge socket with no attribute bound.
        case unboundSocket(index: Int)
        /// The draft admits everything or nothing. The one genuine over-reach the Bench allows
        /// over the grammar (§4.4), and the Assay is already showing it as all-lit or all-dark.
        case constantExtension
        /// Nothing on the rails at all.
        case empty
    }

    /// A rail's state, as far as the bar is concerned.
    public enum RailState: Equatable, Sendable {
        case empty
        case inert
        case unboundSocket
        case ready
    }

    /// - Returns: the reason the Seal is barred, or `nil` when the draft may be declared.
    ///
    /// The rail order is the reading order, so "the offending rail" is the first one that is not
    /// ready — a player who has just broken rail 2 sees rail 2 pulse, not rail 1.
    public static func reason(rails: [RailState], extension table: LawTable?) -> Reason? {
        guard !rails.isEmpty, rails.contains(where: { $0 != .empty }) else { return .empty }
        for (index, rail) in rails.enumerated() {
            switch rail {
            case .inert: return .inertRail(index: index)
            case .unboundSocket: return .unboundSocket(index: index)
            case .empty, .ready: continue
            }
        }
        guard let table else { return .empty }
        return isConstant(table) ? .constantExtension : nil
    }

    /// Constant in the space the law is **judged** in: a stateless draft over 256, a contextual
    /// one over 65,536. `LawTable.isConstant` already reads it that way — G1 and G2's own
    /// predicates — so the bar and the generator's guardrails agree by construction rather than
    /// by coincidence.
    public static func isConstant(_ table: LawTable) -> Bool { table.isConstant }

    /// Which rail to pulse, if any. `nil` where the fault is the whole draft rather than one
    /// rail — a constant extension is not any single rail's doing, and pulsing an arbitrary one
    /// would teach the player to look in the wrong place.
    public static func offendingRail(_ reason: Reason?) -> Int? {
        switch reason {
        case .inertRail(let index), .unboundSocket(let index): index
        case .constantExtension, .empty, nil: nil
        }
    }
}
