import Testing

import Bench
import HunchTestSupport
import Laws

/// §4.4's ceiling and §10.4's serve-time assertion. The interesting cases are all about the
/// gallop, which is the one thing that makes "they will never be served one" false.
@Suite("The palette ceiling", .tags(.unit, .presubmission))
struct PaletteCeilingTests {

    @Test("A veteran holds the full palette and cannot read the family off it")
    func veteranSeesEverything() {
        #expect(
            PaletteCeiling.available(maxBandEverServed: .systemic)
                == Set(TileClass.allCases))
        #expect(PaletteCeiling.available(maxBandEverServed: .composite).contains(.tally))
    }

    /// The opening state: a player who has been served band 1 holds a band-2 palette — two
    /// Ramps and a coupler, no Bridge.
    @Test("A beginner's palette is short")
    func beginnerPaletteIsShort() {
        let opening = PaletteCeiling.available(maxBandEverServed: .literal)
        #expect(opening == [.ramp])
        #expect(opening.contains(.bridge) == false)
    }

    @Test("Every band's palette can express that band", arguments: Band.allCases)
    func servedBandIsAlwaysExpressible(_ band: Band) {
        // The ceiling is maximum-served + 1, so a player who has been served this band holds at
        // least what this band needs.
        let palette = PaletteCeiling.available(maxBandEverServed: band)
        #expect(PaletteCeiling.canExpress(band: band, with: palette))
    }

    /// The gallop: bands 1, 2, 4, 6, 8. A player who wins the first two has a lifetime maximum
    /// of 2 and a ceiling of band 3 — **no Bridge** — and round 3 is band 4 RELATIONAL, which
    /// cannot be stated without one. Every new player who won their first two rounds would be
    /// handed a round unwinnable by construction.
    @Test("Without the calibration unlock the gallop hands out unwinnable rounds")
    func theGallopWouldBreakWithoutTheUnlock() {
        let afterTwoWins = PaletteCeiling.available(maxBandEverServed: .pair)
        #expect(PaletteCeiling.canExpress(band: .relational, with: afterTwoWins) == false)

        let calibrating = PaletteCeiling.available(maxBandEverServed: .pair, isCalibrating: true)
        for band in [Band.relational, .guarded, .systemic] {
            #expect(PaletteCeiling.canExpress(band: band, with: calibrating))
        }
    }

    @Test("The unlock reverts when calibration ends")
    func theUnlockIsTemporary() {
        #expect(
            PaletteCeiling.available(maxBandEverServed: .pair, isCalibrating: true)
                != PaletteCeiling.available(maxBandEverServed: .pair))
    }

    /// The requirement table is monotone: a harder band never needs *fewer* tile classes, so a
    /// palette that can state band n can state every band below it.
    @Test("The requirement table is monotone in the band")
    func requirementsAreMonotone() {
        for band in Band.allCases {
            for lower in Band.allCases where lower < band {
                #expect(
                    PaletteCeiling.required(for: lower)
                        .isSubset(of: PaletteCeiling.required(for: band)))
            }
        }
    }

    @Test("Band 8 is its own ceiling and does not overflow")
    func topBandIsStable() {
        #expect(
            PaletteCeiling.available(maxBandEverServed: .systemic)
                == PaletteCeiling.required(for: .systemic))
    }
}
