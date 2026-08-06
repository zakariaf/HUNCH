import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Ladder
import Laws

/// §10.3's thirteen steps. The three properties worth the most here are the ones whose failure
/// is silent: `targetδ` re-derived after every band move, the pressure term centred, and the
/// pressure frozen at a clamp.
@Suite("The serving policy", .tags(.unit, .presubmission))
struct ServingPolicyTests {

    private func ability(_ core: Double) -> Ability { Ability(core: core) }

    @Test("The served band is always inside the mode's range", arguments: Mode.allCases)
    func bandsRespectTheMode(_ mode: Mode) {
        for core in stride(from: -6.0, through: 6.0, by: 0.5) {
            for jitter in [-0.35, 0.0, 0.35] {
                let serve = ServingPolicy.serve(
                    ability: ability(core), mode: mode, state: ServingState(), jitter: jitter)
                #expect(serve.band.rawValue >= ServingPolicy.minBand(mode))
                #expect(serve.band.rawValue <= ServingPolicy.maxBand(mode))
            }
        }
    }

    /// The single most important invariant in the policy: `targetδ` must lie inside the band it
    /// was served for. When it does not, G8's two windows fail to intersect, all 200 generator
    /// attempts fail, and the generator falls back to the family anchor — which silently turns
    /// the family-repeat guard into "serve the same anchor law every time you lose twice".
    @Test("targetδ always lies inside its own band", arguments: Mode.allCases)
    func targetIsAlwaysInsideItsBand(_ mode: Mode) {
        var state = ServingState()
        for core in stride(from: -6.0, through: 6.0, by: 0.25) {
            for losses in [0, 1, 2] {
                state.consecutiveLosses = losses
                state.lastFamily = .contextual
                for run in [0, 3] {
                    state.ceilingClampRun = run
                    let serve = ServingPolicy.serve(
                        ability: ability(core), mode: mode, state: state, jitter: 0.2)
                    let lower = 0.125 * Double(serve.band.rawValue - 1)
                    let upper = 0.125 * Double(serve.band.rawValue)
                    #expect(serve.targetDelta >= lower)
                    #expect(serve.targetDelta < upper)
                }
            }
        }
    }

    /// §10.3 step 12: the estimator consumes `8·targetδ − 4`, not step 6's δ. Feeding it the
    /// pre-quantisation logit would make the estimate answer a question the player was never
    /// asked.
    @Test("The recorded δ is derived from targetδ, not from the pre-quantisation logit")
    func theRecordedDeltaIsTheServedOne() {
        let serve = ServingPolicy.serve(
            ability: ability(0.4), mode: .probe, state: ServingState(), jitter: 0)
        #expect(abs(serve.servedDelta - (8 * serve.targetDelta - 4)) < 1e-12)
        let band = serve.band.rawValue
        #expect(serve.servedDelta >= Double(band - 1) - 4)
        #expect(serve.servedDelta < Double(band) - 4)
    }

    /// π₀ centres the pressure term. Without it the policy serves about +0.37 logit hard and
    /// the fixed point lands at 0.75 rather than 0.80 — a different game, not a rounding error.
    @Test("The pressure term is a reallocation, not a net shift")
    func pressureIsCentred() {
        #expect(ServingPolicy.pressureCentre == 0.44)

        // Averaged over the streak distribution at an 80 % win rate, `reach − relief` is close
        // to π₀, so the mean served δ is close to the uncentred target.
        var state = ServingState()
        var pressures: [Double] = []
        var wins = 0
        for round in 0..<2_000 {
            let win = round % 5 != 0
            state.record(win: win)
            if win { wins += 1 }
            pressures.append(state.reach - state.relief)
        }
        let mean = pressures.reduce(0, +) / Double(pressures.count)
        #expect(abs(mean - ServingPolicy.pressureCentre) < 0.15)
        #expect(wins == 1_600)
    }

    /// "Up fast, down gently", and it lives here rather than in the estimator.
    @Test("reach climbs with a streak and collapses on a loss; relief needs two losses")
    func theAsymmetryIsInThePolicy() {
        var state = ServingState()
        for _ in 0..<5 { state.record(win: true) }
        #expect(state.reach == 1.00)  // capped
        #expect(state.winStreak == 5)

        state.record(win: false)
        #expect(state.reach == 0)  // collapses
        #expect(state.relief == 0)  // one loss is not two

        state.record(win: false)
        #expect(state.relief == 1.00)
        state.record(win: false)
        #expect(state.relief == 2.00)  // capped
        state.record(win: true)
        #expect(state.relief == 1.50)  // decays gently
    }

    /// The ladder must never build up unspendable pressure that has to be discharged before the
    /// next real move can be felt.
    @Test("Pressure freezes at a clamp")
    func pressureFreezesAtTheClamp() {
        var top = ServingState()
        for _ in 0..<5 { top.record(win: true, atMaxBand: true) }
        #expect(top.reach == 0)
        #expect(top.winStreak == 5)  // the streak still counts; only the pressure is frozen

        var bottom = ServingState()
        bottom.record(win: false, atMinBand: true)
        bottom.record(win: false, atMinBand: true)
        #expect(bottom.relief == 0)
        #expect(bottom.consecutiveLosses == 2)
    }

    /// Step 9: after a loss, the same family is not served again.
    @Test("The family repeat guard moves the band after a loss")
    func theRepeatGuardMoves() {
        var state = ServingState()
        state.consecutiveLosses = 1
        let unguarded = ServingPolicy.serve(
            ability: ability(0), mode: .probe, state: ServingState(), jitter: 0)
        state.lastFamily = unguarded.band
        let guarded = ServingPolicy.serve(
            ability: ability(0), mode: .probe, state: state, jitter: 0)
        #expect(guarded.band != unguarded.band)
        // …and the moved band's target is its centre, re-derived rather than carried over.
        #expect(
            abs(guarded.targetDelta - (0.125 * Double(guarded.band.rawValue) - 0.0625)) < 1e-12)
    }

    /// Step 10: three consecutive rounds clamped at the ceiling rotate down, and the new band's
    /// target is its **upper near edge** — a player at the ceiling gets the hardest law that is
    /// not the ceiling, not a mid-band one.
    @Test("The ceiling rotation drops a band and serves its upper near edge")
    func ceilingRotation() {
        var state = ServingState()
        state.ceilingClampRun = 3
        let serve = ServingPolicy.serve(
            ability: ability(6), mode: .probe, state: state, jitter: 0)
        #expect(serve.band.rawValue == ServingPolicy.maxBand(.probe) - 1)
        #expect(abs(serve.targetDelta - (0.125 * Double(serve.band.rawValue) - 0.020)) < 1e-12)
    }

    /// DRIFT's floor is structural: §7.7's par/cap table has no rows below band 3, so a
    /// calibrated beginner at core −2.114 with 2.00 of relief must still not be served band 1.
    @Test("A beginner under full relief is still served band 3 in DRIFT")
    func driftNeverGoesBelowItsFloor() {
        var state = ServingState()
        state.relief = 2.00
        let serve = ServingPolicy.serve(
            ability: ability(-2.114), mode: .drift, state: state, jitter: -0.35)
        #expect(serve.band == .exclusive)
        #expect(serve.band.rawValue == ServingPolicy.minBand(.drift))
    }
}
