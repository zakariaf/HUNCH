import Testing

import Glyphs
import HunchTestSupport
import Laws
import Rounds

/// The number every shared transcript surface is sized against. Pinned here so that E12's
/// DRIFT table visibly moves it rather than silently invalidating a grid three epics away.
@Suite("The worst-case transcript", .tags(.unit, .presubmission))
struct RoundBudgetTests {

    /// DRIFT's row landed in E12 and moved this number from 48 to 65 — PROBE's band-8 cap is
    /// 47, DRIFT's is 64. The spool sheet's capacity test covered the change with no edit in
    /// `Modules/`, which is the whole reason the switch is exhaustive.
    @Test("The worst case is DRIFT's band-8 cap plus the seed")
    func theWorstCaseIsDrift() {
        #expect(RoundBudget.worstCaseTranscript == 65)
        #expect(RoundBudget.cap(mode: .drift, band: .systemic) == 64)
        #expect((Band.allCases.map(\.cap).max() ?? 0) == 47)
    }

    @Test("The table is total over Mode × Band", arguments: Mode.allCases)
    func totalOverModes(_ mode: Mode) {
        for band in Band.allCases {
            // `nil` is a legal answer; a trap or a missing row is not.
            _ = RoundBudget.cap(mode: mode, band: band)
        }
    }

    @Test("PROBE's row is the band's own cap, never a second table")
    func probeReadsTheBand() {
        for band in Band.allCases {
            #expect(RoundBudget.cap(mode: .probe, band: band) == band.cap)
        }
    }

    /// §6.2's grid is 70 cells and the invariant is `cells ≥ worstCaseTranscript`. Asserted on
    /// the core side too, because the number that has to fit is core's and the grid that has to
    /// hold it is not.
    @Test("Seventy cells hold the worst case with room to spare")
    func seventyCellsIsEnough() {
        #expect(RoundBudget.worstCaseTranscript <= 70)
    }
}
