import Foundation
import Testing

import HunchTestSupport
import Laws

/// §5.2's `|H|` is stated as *"enumerated exhaustively over the real 256-glyph deck, not
/// estimated"*. This is that enumeration, so the band table is a MEASUREMENT rather than a
/// quoted number — and if this disagrees with `Band.population`, one of them is wrong.
///
/// The six stateless bands run in the fast suite. Bands 5 and 7 are minutes (17,328 contextual
/// tables × up to 24 permutes of 65,536 bits each) and are gated `.nightly`.
@Suite("Band enumeration", .tags(.integration))
struct BandEnumerationTests {
    /// The six stateless bands, in ascending order so each band's G4 exclusion set is complete
    /// and frozen before it is counted — §5.2 is explicit that this ordering is what makes the
    /// definition well-founded rather than circular.
    /// Gated behind `HUNCH_CALIBRATION=1`. A Swift Testing tag does not exclude a test from
    /// `swift test` — only a test PLAN filters by tag, and the fast loop is a plain
    /// `swift test` with no plan. At 8 s this is most of the ten-second budget on its own, so
    /// the gate has to be a trait that actually skips.
    @Test(
        "The six stateless bands enumerate to §5.2's counts exactly",
        .tags(.nightly),
        .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"))
    func statelessBandsReproduce() {
        let statelessBands: [Band] = [
            .literal, .pair, .exclusive, .relational, .guarded, .systemic,
        ]
        var lower = LawSet()
        var counts: [Band: Int] = [:]

        for band in statelessBands {
            let survivors = BandEnumeration.survivors(for: band, excluding: lower)
            counts[band] = survivors.count
            for table in survivors.tables { lower.insert(table) }
        }

        for band in statelessBands {
            #expect(
                counts[band] == band.population,
                "\(band): enumerated \(counts[band] ?? -1), §5.2 says \(band.population)")
        }
        #expect(lower.count == 9_767, "the lower-band index is 9,767 tables (§3.6)")
    }

    /// Band 3 is a THEOREM, not a guardrail (§5.2): an XOR's marginals are `{p_T, 1 − p_T}`, so
    /// all sixteen equal `p` iff both subsets have size 2. That is why band 2's form space
    /// subtracts band 3's shape by CONSTRUCTION — G4 only looks downward, and band 3 sits
    /// above band 2. Leaving them in gives 1,290 and 90 instead of 1,272 and 108.
    @Test("Band 3's shape is exactly XOR of two 2-subsets, and band 2 excludes it")
    func exclusiveShapeIsExclusive() {
        let band3 = BandEnumeration.forms(for: .exclusive)
        let band2 = BandEnumeration.forms(for: .pair)
        #expect(band3.count == 216)
        #expect(band3.allSatisfy { BandEnumeration.isExclusiveShape($0) })
        #expect(band2.allSatisfy { !BandEnumeration.isExclusiveShape($0) })
    }

    @Test("The form spaces are §3.3's counts")
    func formSpaceSizes() {
        #expect(BandEnumeration.forms(for: .literal).count == 56)
        #expect(BandEnumeration.forms(for: .guarded).count == 8_736)
        #expect(BandEnumeration.forms(for: .systemic).count == 1_214)
    }
}
