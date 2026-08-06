public import Glyphs
public import Laws

/// The hard probe ceiling a mode serves at a band, and the worst-case transcript length every
/// **shared** surface must hold (§6.2).
///
/// Exhaustive over `Mode`, with no `default:` — adding a mode is a compile error here, and that
/// is the point: the spool sheet's capacity invariant is a cross-epic claim, and a cross-epic
/// claim needs a table a future epic cannot walk past. DRIFT reaches a cap of 64 at band 8
/// (§7.7) while PROBE tops out at 47, so a sheet sized against PROBE would be too small for a
/// surface §7.5 hands to DRIFT region for region.
public enum RoundBudget {

    /// `nil` where the mode does not serve that band, or has not defined its budget yet.
    public static func cap(mode: Mode, band: Band) -> Int? {
        switch mode {
        case .probe: band.cap
        // E12·T04 fills §7.7's six-row table — 40 at bands 5–6 through 64 at band 8. When it
        // does, `worstCaseTranscript` moves and the spool sheet's capacity test covers
        // `cap_DRIFT = 64` with no edit in `Modules/`.
        case .drift: nil
        // ECHO has no probe cap; it has a cast length (E13).
        case .echo: nil
        // SIEVE has no probe cap; it has a stream length (E14).
        case .sieve: nil
        }
    }

    /// `1 +` the largest cap over every mode and band: the longest possible probe run, plus the
    /// seed glyph, which occupies a cell on a transcript surface and is not a probe.
    public static var worstCaseTranscript: Int {
        let caps = Mode.allCases.flatMap { mode in
            Band.allCases.compactMap { band in cap(mode: mode, band: band) }
        }
        return 1 + (caps.max() ?? 0)
    }
}
