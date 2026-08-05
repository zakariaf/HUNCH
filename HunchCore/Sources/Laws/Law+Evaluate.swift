public import Glyphs

extension Law {
    /// Whether this law admits `glyph` when the previously probed glyph was `previous`.
    ///
    /// One table lookup. The AST is never walked here — it was walked exactly once, in
    /// `Law.init`, to compose the extension from precomputed masks (§3.6).
    ///
    /// A stateless law ignores `previous` entirely; passing any glyph is correct and cheap.
    /// - Complexity: O(1).
    public func admits(_ glyph: Glyph, after previous: Glyph) -> Bool {
        table.admits(glyph, after: previous)
    }

    /// The verdict, as the domain's two-valued type (`N29`).
    /// - Complexity: O(1).
    public func verdict(for glyph: Glyph, after previous: Glyph) -> Verdict {
        Verdict(admits: admits(glyph, after: previous))
    }

    /// Every verdict in a probe sequence, under §3.5's semantics.
    ///
    /// `seed` primes position 0: it is `prev` for probe 1, it is **not** a probe, it carries no
    /// verdict and it is not scored (§3.5). `prev` for probe *n* is probe *n−1* **regardless of
    /// its verdict** — the design overrules the brief here, and reproducibility of the ribbon
    /// is the reason: under *previously admitted* the same probe yields different verdicts at
    /// different moments for reasons not visible in the record.
    ///
    /// - Returns: exactly `probes.count` verdicts.
    /// - Complexity: O(probes.count).
    public func verdicts(seededBy seed: Glyph, probes: [Glyph]) -> [Verdict] {
        var previous = seed
        var out: [Verdict] = []
        out.reserveCapacity(probes.count)
        for probe in probes {
            out.append(verdict(for: probe, after: previous))
            previous = probe  // regardless of the verdict — §3.5
        }
        return out
    }
}
