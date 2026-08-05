// Four game-wide value enums live in `Glyphs` because it is the one target every other target
// depends on (08 §1 marks it "leaf; empty dependencies:"). Mode is named by LawGeneration,
// Persistence, Ladder and Rounds; Comparator by Laws. Putting either anywhere else inverts an
// arrow, and a ninth target contradicts E01·T03's manifest.

/// The two verdicts (§2). Never "pass/fail", never "yes/no".
///
/// `N29` would normally reject imperative-verb cases; `N36` applies — the domain locks these
/// two words and `verdict == .admit` reads correctly (`08 §3`). The `UInt8` raw value is
/// additive to `08 §3`'s spelling: the ribbon and the snapshot persist a verdict per probe
/// (§6.10), so it needs one byte and free `Codable`.
public enum Verdict: UInt8, CaseIterable, Sendable, Codable {
    case admit, reject

    /// The verdict a `Bool` from the evaluator means.
    public init(admits: Bool) { self = admits ? .admit : .reject }
}

/// The AND/OR/XOR node between two rule-tiles (§2, §3.2's `<coupler>`).
///
/// Deliberately no `apply(_:_:)`: combining two tables under a coupler is *evaluation*, and the
/// evaluator has one owner (E05·T03). The mapping to `&`, `|`, `^` is one-to-one by construction.
public enum Coupler: UInt8, CaseIterable, Sendable, Codable {
    case and, or, xor
}
