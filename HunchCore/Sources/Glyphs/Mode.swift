/// The four modes (§2). Uppercase in copy, and the names ship as untranslated **wordmarks** —
/// they never enter the String Catalog (§12.9), so they are rendered `Text(verbatim:)`.
public enum Mode: UInt8, CaseIterable, Sendable, Codable {
    case probe, drift, echo, sieve

    /// The untranslated wordmark. `08 §3`: `Text(verbatim: mode.wordmark)`, never
    /// `Text(mode.rawValue)` — a raw `String` value is not extracted by a String Catalog and
    /// would ship English forever, which is 07 B39's trap in its worst costume.
    public var wordmark: String {
        switch self {
        case .probe: "PROBE"
        case .drift: "DRIFT"
        case .echo: "ECHO"
        case .sieve: "SIEVE"
        }
    }

    /// Mixed into every generated seed — §5.3 step 1:
    /// `rng = SplitMix64(seed ^ (UInt64(band) << 32) ^ mode.salt)`.
    ///
    /// The design fixes the *formula* and is silent on the salt's value, so this task fixes it:
    /// the big-endian ASCII packing of the mode's own wordmark. Derived rather than invented,
    /// so it is reproducible by inspection and cannot be mistyped — the test recomputes it from
    /// `wordmark` rather than restating a literal. Frozen: changing a salt changes every puzzle
    /// that mode has ever generated.
    public var salt: UInt64 {
        wordmark.utf8.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}

extension Mode {
    /// The lowercase stable string used in a *filename* — `round-probe.json`. A human reads it
    /// in a bug report, which is why it is not the `UInt8` raw value.
    ///
    /// Never `String(describing:)`: that is a reflection spelling and it changes when the case
    /// is renamed, silently orphaning every suspended round on disk.
    public var slug: String {
        switch self {
        case .probe: "probe"
        case .drift: "drift"
        case .echo: "echo"
        case .sieve: "sieve"
        }
    }
}
