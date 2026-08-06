import CoreGraphics
import Testing

import HunchUI
import Laws
import ModulesTestSupport

/// §6.9's par crossing, which is the round's one non-verdict event. Everything it decides is in
/// this value, so the frame on which the two rows change state is assertable without a frame.
@Suite("The par row and the par crossing", .tags(.unit, .presubmission))
struct ParRowTests {

    private func model(_ used: Int, _ band: Band = .contextual) -> ParRowModel {
        ParRowModel(probesUsed: used, par: band.par, cap: band.cap)
    }

    @Test("Below par the row counts up and the cap row is present but unlit")
    func belowPar() {
        let band = Band.contextual
        let model = model(5, band)
        #expect(model.parMode == .count(filled: 5, total: band.par))
        #expect(model.hasCrossed == false)
        #expect(model.capIsLit == false)
        // The cap row's total is cap − par: the budget that remains *after* par.
        #expect(model.capMode == .cap(remaining: band.cap - band.par, total: band.cap - band.par))
    }

    @Test(
        "At par the row inverts to one solid rule and the cap row lights, on the same frame",
        arguments: Band.allCases)
    func theCrossing(_ band: Band) {
        let model = model(band.par, band)
        #expect(model.hasCrossed)
        #expect(model.parMode == .crossed(total: band.par))
        #expect(model.capIsLit)
        #expect(model.capMode == .cap(remaining: band.cap - band.par, total: band.cap - band.par))
    }

    @Test("Past par the cap row empties, one stop per probe, and bottoms out at the cap")
    func capEmpties() {
        let band = Band.contextual
        for used in band.par...band.cap {
            let model = model(used, band)
            #expect(model.capMode == .cap(remaining: band.cap - used, total: band.cap - band.par))
            #expect(model.parMode == .crossed(total: band.par))
        }
        #expect(model(band.cap, band).capMode == .cap(remaining: 0, total: band.cap - band.par))
    }

    @Test("The crossing is one-way: it never un-crosses")
    func theCrossingIsPermanent() {
        let band = Band.literal
        #expect(model(band.par - 1, band).hasCrossed == false)
        for used in band.par...band.cap {
            #expect(model(used, band).hasCrossed)
        }
    }

    @Test("A spent cap stop is an absence, never a dimmed stop")
    func spentStopsAreAbsent() {
        let band = Band.contextual
        let model = model(band.par + 4, band)
        guard case .cap(let remaining, let total) = model.capMode else {
            #expect(Bool(false), "the cap row must be a .cap row past par")
            return
        }
        #expect(total - remaining == 4)
        #expect(model.dimmedStopCount == 0)  // there is no such thing
    }

    @Test(
        "The row's ticks never fall below the drawable gap on either device",
        arguments: Band.allCases)
    func theRowFits(_ band: Band) {
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            #expect(
                TickRow.pitch(
                    nominalPitch: layout.nominalTickPitch, rowWidth: layout.tickRowWidth,
                    total: band.par) == layout.nominalTickPitch)
        }
    }

    /// The clamp has one home. If `PlaySurfaceLayout` re-derived it, a change to the mark's
    /// arithmetic would leave the layout's answer behind and the row would stop being
    /// proportional at exactly the sizes nobody re-measures.
    @Test("The layout's pitch and the mark's pitch are the same function")
    func onePitchFormula() {
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            for total in [1, 7, 29, 40, 64] {
                #expect(
                    layout.tickPitch(total: total)
                        == TickRow.pitch(
                            nominalPitch: layout.nominalTickPitch,
                            rowWidth: layout.tickRowWidth, total: total))
            }
        }
    }
}
