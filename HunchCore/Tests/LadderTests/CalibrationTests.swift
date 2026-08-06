import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Ladder
import Laws

/// §10.5's cold start. The gallop exists so a returning expert is placed as fast as a
/// first-time player; a five-round walk up 1…5 would only ever discover a beginner.
@Suite("Cold start and calibration", .tags(.unit, .presubmission))
struct CalibrationTests {

    @Test("Five rounds, and the rungs are 1, 2, 4, 6, 8")
    func theGallop() {
        #expect(Calibration.rounds == 5)
        #expect(Calibration.gallop.map(\.rawValue) == [1, 2, 4, 6, 8])
        #expect(Calibration.band(forRound: 1) == .literal)
        #expect(Calibration.band(forRound: 5) == .systemic)
    }

    /// §10.5's published seeding table, row for row.
    @Test("The seeding table reproduces exactly")
    func seedingTable() {
        let rows: [(Band, Int, Double)] = [
            (.literal, 3, -2.114), (.pair, 3, -2.114),
            (.relational, 3, -0.114), (.relational, 1, -1.114),
            (.guarded, 3, 1.886), (.guarded, 1, 0.886),
            (.systemic, 3, 3.886), (.systemic, 1, 2.886),
        ]
        for (band, marks, expected) in rows {
            let estimated = Calibration.estimatedBand(lostAt: band, previousMarks: marks)
            #expect(abs(Calibration.seededCore(estimatedBand: estimated) - expected) < 5e-4)
        }
        #expect(abs(Calibration.allWinsCore - 4.886) < 5e-4)
    }

    /// Probe economy breaks the tie: a player who won the previous rung on three marks was not
    /// scraping it, so their true level is nearer that rung than one who spent their whole cap.
    @Test("Marks decide whether the estimate drops one rung or two")
    func marksBreakTheTie() {
        #expect(Calibration.estimatedBand(lostAt: .guarded, previousMarks: 2) == 5)
        #expect(Calibration.estimatedBand(lostAt: .guarded, previousMarks: 1) == 4)
        #expect(Calibration.estimatedBand(lostAt: .literal, previousMarks: 1) == 1)  // floored
    }

    /// A seeded core places the player at the centre of the band they proved, so the first
    /// served round after calibration is the middle of it rather than its edge.
    @Test("The seeded core serves the band it estimated")
    func theSeedServesItsOwnBand() {
        for band in 1...8 {
            let core = Calibration.seededCore(estimatedBand: band)
            let serve = ServingPolicy.serve(
                ability: Ability(core: core), mode: .probe, state: ServingState(), jitter: 0)
            #expect(abs(serve.band.rawValue - band) <= 1)
        }
    }

    /// Zeroing `core` instead of resetting the whole state would serve band 3 immediately and
    /// skip calibration entirely — the precise cold-start failure §10.5 exists to prevent.
    @Test("Resetting the ladder returns to round 1 of the gallop, not to band 3")
    func resetReturnsToCalibration() {
        var state = ServingState()
        state.calibrationRound = nil
        state.maxBandEverServed = 8
        state.reach = 1.0
        Calibration.reset(&state)
        #expect(state.calibrationRound == 1)
        #expect(state.maxBandEverServed == 1)
        #expect(state.reach == 0)
    }
}

/// §10.7's triggers as a table. Scattered `if`s are how two of these end up firing at once.
@Suite("Anti-frustration", .tags(.unit, .presubmission))
struct AntiFrustrationTests {

    @Test("Two losses give one band of relief; three give two")
    func reliefLadder() {
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 2, band: .guarded, mode: .probe, repeatsFamily: false)
                == .relief(1.00))
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 3, band: .guarded, mode: .probe, repeatsFamily: false)
                == .relief(2.00))
    }

    @Test("A repeated family after a loss shifts the band")
    func noThreeXorsInARow() {
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 1, band: .exclusive, mode: .probe, repeatsFamily: true)
                == .shiftFamily)
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 1, band: .exclusive, mode: .probe, repeatsFamily: false)
                == .none)
    }

    /// At the floor the **tooling** opens, because the difficulty cannot close further. It is
    /// the one place the game answers a stuck player with a tool rather than an easier law.
    @Test("Three losses at the floor open the tooling instead of the difficulty")
    func floorRescue() {
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 3, band: .literal, mode: .probe, repeatsFamily: false)
                == .floorRescue)
        // DRIFT's floor is band 3, so the rescue fires there rather than at band 1.
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 3, band: .exclusive, mode: .drift, repeatsFamily: false)
                == .floorRescue)
        #expect(
            AntiFrustration.response(
                consecutiveLosses: 3, band: .literal, mode: .drift, repeatsFamily: false)
                == .relief(2.00))
    }

    /// Softening either silently would make the model unidentifiable and the Profile a lie:
    /// par feeds Tempo and cap feeds the failure signal the estimator needs.
    @Test("There is no cap relief and no par relief, ever")
    func noCapOrParRelief() {
        #expect(AntiFrustration.relievesCap == false)
        #expect(AntiFrustration.relievesPar == false)
    }
}
