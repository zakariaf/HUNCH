import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Ladder
import Laws

/// The Level-A harness answers the one question the unit tests cannot: does the **whole loop**
/// realise the 80 % the design is built on? Every piece can be individually correct and the
/// composition still land at 0.75 — that is exactly what `π₀` exists to prevent.
@Suite("The Level-A response harness", .tags(.integration, .presubmission))
struct ResponseHarnessTests {

    /// **H3.** The headline number, and the reason `π₀` is locked at 0.44.
    @Test(
        "H3 — the realised success rate is 0.80 ± 0.03 at equilibrium",
        arguments: [-2.0, 0.0, 2.0, 4.0])
    func h3SuccessRate(_ trueTheta: Double) {
        let result = ResponseHarness(trueTheta: trueTheta).run(rounds: 20_000, seed: 0xA11CE)
        #expect(abs(result.successRate - 0.80) < 0.03)
    }

    /// **H1.** The estimate finds the player. Started three logits away, it converges — which is
    /// the property that makes the first number mean anything.
    @Test("H1 — the estimate converges on the player's true ability")
    func h1Convergence() {
        let harness = ResponseHarness(trueTheta: 1.5)
        let result = harness.run(rounds: 4_000, seed: 0xBEEF, startingAt: -1.5)
        #expect(abs(result.finalTheta - 1.5) < 0.6)
    }

    /// **H8.** The ladder does not park. A converged player still sees a spread of bands, which
    /// is what the pressure term is for — jitter alone cannot cross a band from centre.
    @Test("H8 — the modal band stays under 60 % of rounds for a converged player")
    func h8FamilyRotation() {
        let result = ResponseHarness(trueTheta: 0.5).run(rounds: 20_000, seed: 0xF00D)
        #expect(result.modalBandShare < 0.60)
        #expect(result.bandHistogram.keys.count >= 3)
    }

    /// **H19.** At the ceiling the estimate is censored — a player above band 8's difficulty
    /// cannot be measured any further — so the success rate rises and that is correct, not a
    /// bug. What must not happen is the loop diverging.
    @Test("H19 — a player past the ceiling saturates rather than diverging")
    func h19CeilingIsCensored() {
        let result = ResponseHarness(trueTheta: 6.0).run(rounds: 5_000, seed: 0xC0DE)
        #expect(result.successRate > 0.80)
        #expect(Ability.range.contains(result.finalTheta))
        #expect(result.bandHistogram[8, default: 0] > result.rounds / 2)
    }

    /// The harness is a pure function of its seed. A harness that reached for a system RNG
    /// could not be re-run on a failure, which is the only time anybody wants it.
    @Test("The harness is reproducible from its seed")
    func harnessIsDeterministic() {
        let first = ResponseHarness(trueTheta: 0.3).run(rounds: 500, seed: 7)
        let second = ResponseHarness(trueTheta: 0.3).run(rounds: 500, seed: 7)
        #expect(first == second)
        #expect(ResponseHarness(trueTheta: 0.3).run(rounds: 500, seed: 8) != first)
    }
}

/// The ladder is **censored at both ends**, and the harness reproduces §10.7's own argument for
/// the floor rescue without being told it.
@Suite("The ladder's two censored ends", .tags(.integration, .presubmission))
struct LadderCensoringTests {

    /// A player below band 1's difficulty cannot be served anything easier — there is no band 0.
    /// The realised rate therefore falls below the target and **that is correct**: it is the
    /// mirror of H19's ceiling, and it is precisely why §10.7 answers three losses at the floor
    /// by opening the *tooling* rather than the difficulty. Measured at 0.66 for θ = −3.
    @Test("A player below the floor is served the floor, and the rate falls with them")
    func theFloorIsCensored() {
        let belowFloor = ResponseHarness(trueTheta: -3.0).run(rounds: 20_000, seed: 0xA11CE)
        #expect(belowFloor.successRate < 0.75)
        #expect(belowFloor.bandHistogram[1, default: 0] > belowFloor.rounds / 2)
        // …and the estimate does not chase them below what it can serve.
        #expect(Ability.range.contains(belowFloor.finalTheta))
    }

    /// §10.8's rotation claim is a claim about a *converged* player, and it cannot hold at
    /// either end: with the band pinned there is nothing to rotate. Stating that here is the
    /// difference between a measured bound and a bound that quietly excludes its worst case.
    @Test("Family rotation is a mid-ladder property, and the ends are named rather than hidden")
    func rotationIsMidLadderOnly() {
        let floor = ResponseHarness(trueTheta: -3.0).run(rounds: 20_000, seed: 0xA11CE)
        let middle = ResponseHarness(trueTheta: 0.0).run(rounds: 20_000, seed: 0xA11CE)
        let ceiling = ResponseHarness(trueTheta: 6.0).run(rounds: 20_000, seed: 0xA11CE)

        #expect(middle.modalBandShare < 0.60)
        #expect(floor.modalBandShare > 0.60)
        #expect(ceiling.modalBandShare > 0.60)
    }

    /// The whole ladder, swept: the rate is inside H3's window everywhere the ladder can
    /// actually reach the player, and outside it only where it is censored.
    @Test("The realised rate holds across the servable range")
    func theRateHoldsWhereItCan() {
        for theta in [-1.0, 0.0, 1.0, 2.0, 3.0, 4.0] {
            let result = ResponseHarness(trueTheta: theta).run(rounds: 20_000, seed: 0xA11CE)
            #expect(
                abs(result.successRate - 0.80) < 0.03,
                "θ = \(theta) realised \(result.successRate)")
        }
    }
}
