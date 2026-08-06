public import Foundation

public import Glyphs
public import Laws

/// §7.2's pair guardrails, D1–D7.
///
/// `L₂` is a **one-leaf edit of `L₁`** — same family, same skeleton, differing in exactly one
/// leaf parameter. A randomly re-rolled second law is indistinguishable from "the round silently
/// restarted", and clinging only exists as a failure when the dead theory still explains most of
/// what the player sees.
public enum DriftPair {

    public enum Fault: Equatable, Sendable {
        /// D1 — the two laws are the same law.
        case identical
        /// D2 — the disagreement rate is outside `[0.10, 0.30]`: too small to notice, or so
        /// large that the round reads as a restart.
        case disagreementRate(Double)
        /// D4 — the edit must be able to break a **positive**, not only a negative.
        case breaksNoPositives(Int)
    }

    public static let disagreementRange = 0.10...0.30
    /// D4's floor: at least this many glyphs go from admit to reject.
    public static let brokenPositiveFloor = 8

    /// D1, D2 and D4 — the three that are pure functions of the two extensions. D3 (both legal),
    /// D5 (novel) and D6/D7 (hinge placement and exposability) need the generator, the Codex and
    /// the seed glyph respectively and are checked where those live.
    public static func fault(first: Law, second: Law) -> Fault? {
        let disagreements = first.table.disagreementCount(with: second.table)
        guard disagreements > 0 else { return .identical }

        let mixed = first.table.arity != second.table.arity
        let universe = Double(
            mixed || first.table.arity == .contextual ? 65_536 : first.table.universeSize)
        let rate = Double(disagreements) / universe
        guard disagreementRange.contains(rate) else { return .disagreementRate(rate) }

        let broken = brokenPositives(first: first, second: second)
        guard broken >= brokenPositiveFloor else { return .breaksNoPositives(broken) }
        return nil
    }

    /// `|{g : L₁(g) = admit, L₂(g) = reject}|` over the 256 glyphs at the seed context.
    public static func brokenPositives(first: Law, second: Law, after previous: Glyph? = nil)
        -> Int
    {
        let context = previous ?? Deck.glyph(id: 0)
        return Deck.all.count {
            first.admits($0, after: context) && !second.admits($0, after: context)
        }
    }
}
