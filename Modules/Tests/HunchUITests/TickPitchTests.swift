import CoreGraphics
import Testing

import HunchUI
import Laws
import ModulesTestSupport
import Tokens

/// §10.5 gives the player exactly three signals of difficulty, and the par row's **length** is
/// one of them. That only holds while the pitch is constant, so these are the tests that keep
/// it constant — including against the two things most likely to break it later, a longer mode
/// and a larger text size.
@Suite("The par row is length-proportional at constant pitch", .tags(.unit, .presubmission))
struct TickPitchTests {

    @Test(
        "tickPitch = min(nominalPitch, rowWidth / N), and inside PROBE it never clamps",
        arguments: Band.allCases)
    func pitchIsNeverClampedInProbe(_ band: Band) {
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            let total = band.par
            let pitch = layout.tickPitch(total: total)
            #expect(pitch == layout.nominalTickPitch)  // unclamped
            #expect(pitch * CGFloat(total) <= layout.tickRowWidth)  // and it fits
        }
    }

    @Test("The row's length is proportional to par, which is the only difficulty signal")
    func lengthIsProportionalToPar() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let short = layout.tickRowLength(total: Band.literal.par)
        let long = layout.tickRowLength(total: Band.systemic.par)
        let parRatio = CGFloat(Band.systemic.par) / CGFloat(Band.literal.par)
        #expect(long / short == parRatio)
    }

    /// §6.2: `par_DRIFT` reaches 40 at band 8, which is the one place in the game the clamp
    /// engages. DRIFT's tick count already identifies the mode, so compressing its row costs no
    /// signal that was not already given away.
    @Test("The clamp engages only past the row's budget — DRIFT band 8's 40 ticks")
    func theClampEngagesAtFortyTicks() {
        let se = PlaySurfaceLayout.reference(.compact)
        let big = PlaySurfaceLayout.reference(.large)
        #expect(se.tickPitch(total: 40) == se.tickRowWidth / 40)
        #expect(big.tickPitch(total: 40) == big.tickRowWidth / 40)
        #expect(se.tickPitch(total: 40) < se.nominalTickPitch)
        // The tick stays 2 pt wide, so the gap must stay positive and legible.
        #expect(se.tickPitch(total: 40) - C.TickRow.tickWidth >= 5)
        #expect(big.tickPitch(total: 40) - C.TickRow.tickWidth >= 5)
    }

    @Test("Dynamic Type scales tick heights and never the pitch")
    func artScaleNeverReachesThePitch() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let plain = layout.tickPitch(total: Band.systemic.par)
        let large = layout.tickPitch(total: Band.systemic.par, artScale: 1.35)
        #expect(plain == large)
    }

    /// The row's budget and the bar's centre slot are within a few points of each other and
    /// have different owners (`instrument-bar` §1 versus §6.2). This is the test that notices
    /// if someone merges them: the row must centre *inside* the slot at every par.
    @Test(
        "The row fits inside the instrument bar's centre slot at every band",
        arguments: [
            PlaySurfaceLayout.reference(.compact), .reference(.large),
        ])
    func theRowFitsTheSlot(_ layout: PlaySurfaceLayout) {
        #expect(layout.tickRowWidth != layout.instrumentCentreSlotWidth)
        for band in Band.allCases {
            #expect(layout.tickRowLength(total: band.par) <= layout.instrumentCentreSlotWidth)
        }
    }
}
