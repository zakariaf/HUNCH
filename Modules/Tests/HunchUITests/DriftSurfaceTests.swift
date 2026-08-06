import CoreGraphics
import Testing

import Drift
import Glyphs
import HunchUI
import Laws
import Tokens
import ModulesTestSupport
import Rounds

/// §7.5: the DRIFT surface is PROBE's, **region for region**. The only differences are the mode
/// sigil — which identifies DRIFT, never the hinge — and the seam marker.
///
/// That is §7.1's decision made checkable: if any interface element changed at the hinge, the
/// interface would be announcing the change and the mode would measure reading rather than
/// noticing.
@Suite("The DRIFT surface", .tags(.unit, .presubmission))
struct DriftSurfaceTests {

    @Test(
        "DRIFT gets PROBE's layout region for region",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func theSurfaceIsShared(_ device: PlaySurfaceLayout.DeviceClass) {
        // There is one layout type and one set of regions; a DRIFT-specific layout would be the
        // first place the mode could start announcing itself.
        let layout = PlaySurfaceLayout.reference(device)
        #expect(layout.orderedRegions.count == 6)
        #expect(layout.instrumentBar.height == 44)
    }

    /// The par tick row counts against `par_DRIFT`, so a veteran can read the mode off the tick
    /// count. §7.5 says that is fine and intended — the mode is not a secret; the **hinge** is.
    ///
    /// The clamp engages at **bands 7 and 8**, not band 8 alone as §6.2's worked example
    /// implies: `par_DRIFT` is 37 at band 7 and `37 × 9 = 333 > 288`. Bands 5–6 land exactly on
    /// the boundary at `32 × 9 = 288`, with zero slack, which is worth knowing before anyone
    /// retunes a row width. Canon corrected; see `DECISIONS.md` 103.
    @Test("The tick row counts against par_DRIFT", arguments: DriftBudget.bands)
    func theTickRowCountsDriftPar(_ band: Band) {
        let par = DriftBudget.par(band) ?? 0
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            let pitch = layout.tickPitch(total: par)
            #expect(pitch <= layout.nominalTickPitch)
            #expect(pitch * Double(par) <= layout.tickRowWidth + 0.001)
            // Whatever the pitch, the tick stays 2 pt and the gap stays legible.
            #expect(pitch - C.TickRow.tickWidth >= 5)
        }
    }

    @Test("The clamp engages at DRIFT bands 7 and 8, and nowhere else in the game")
    func whereTheClampEngages() {
        let se = PlaySurfaceLayout.reference(.compact)
        let clamped = DriftBudget.bands.filter {
            se.tickPitch(total: DriftBudget.par($0) ?? 0) < se.nominalTickPitch
        }
        #expect(clamped == [.composite, .systemic])
        #expect(DriftBudget.par(.composite) == 37)
        #expect(DriftBudget.par(.systemic) == 40)

        // Bands 5–6 sit exactly on the boundary: 32 × 9 = 288, the whole row budget.
        #expect(se.tickPitch(total: 32) == se.nominalTickPitch)
        #expect(se.tickRowLength(total: 32) == se.tickRowWidth)

        // PROBE never clamps at any band, which is what keeps §10.5's length signal exact.
        for band in Band.allCases {
            #expect(se.tickPitch(total: band.par) == se.nominalTickPitch)
        }
    }

    /// The seam marker appears **only** at trigger (b)'s index, and PROBE never passes one.
    @Test("The seam marker is written at one index and nowhere else")
    func theSeamIsSingular() {
        let probes = (0..<6).map {
            ProbeRecord(index: UInt8($0), glyphID: UInt8($0), verdict: .admit, isTwin: false)
        }
        let drifted = RibbonTileModel.tiles(
            probes: probes, seedGlyph: Fixtures.seedGlyph, seamMarkerIndex: 3)
        #expect(drifted.filter(\.carriesSeamMarker).count == 1)
        #expect(drifted[3].carriesSeamMarker)

        let probe = RibbonTileModel.tiles(probes: probes, seedGlyph: Fixtures.seedGlyph)
        #expect(probe.contains { $0.carriesSeamMarker } == false)
    }

    /// The other two triggers leave no trace at all. An interface that marked every hinge would
    /// be announcing the change — and trigger (b) is exempt only because the player already
    /// knows something happened: they were just told they were right.
    @Test("Only trigger (b) leaves a trace")
    func onlyCaptureIsVisible() {
        #expect(DriftHinge.writesSeamMarker(.capture))
        #expect(DriftHinge.writesSeamMarker(.satiation) == false)
        #expect(DriftHinge.writesSeamMarker(.forced) == false)
    }
}
