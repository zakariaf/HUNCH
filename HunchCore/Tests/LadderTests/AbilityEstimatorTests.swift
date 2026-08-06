import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Ladder

/// §10.2's estimator. The load-bearing property is that it is **symmetric**: the temptation to
/// make it move up fast and down gently is exactly what would destroy its fixed point.
@Suite("The ability estimator", .tags(.unit, .presubmission))
struct AbilityEstimatorTests {

    /// `σ(ln 4) = 4/5` exactly, so serving `δ = θ − ln 4` hits 0.800 by construction. That
    /// identity *is* the target mechanism, so it is worth pinning to the digit.
    @Test("The 80 % target is one constant, and it is exact")
    func theTargetIsExact() {
        let probability = Ability.successProbability(theta: 0, delta: -Ability.targetOffset)
        #expect(abs(probability - 0.8) < 1e-12)
        #expect(abs(exp(Ability.targetOffset) - 4) < 1e-9)
    }

    /// §10.2's published row: `K` at n = 0, 4, 8, 16, 24, ≥32.
    @Test("K(n) reproduces the published gain row")
    func gainRow() {
        let expected: [(Int, Double)] = [
            (0, 0.900), (4, 0.600), (8, 0.450), (16, 0.300), (24, 0.225), (32, 0.180),
            (4_000, 0.180),
        ]
        for (n, gain) in expected {
            #expect(abs(AbilityEstimator.gain(scoredRounds: n) - gain) < 5e-4)
        }
    }

    /// "Four wins to undo one loss, which is the correct ratio at an 80 % target and needs no
    /// asymmetry to produce it." The ratio falls out of the symmetric rule.
    @Test("At the target, four wins undo one loss — with no asymmetry anywhere")
    func fourWinsUndoOneLoss() {
        var ability = Ability(core: 0)
        ability.n[.probe] = 32
        let delta = -Ability.targetOffset

        let afterWin = AbilityEstimator.updated(
            ability, mode: .probe, servedDelta: delta, inscribed: true)
        let afterLoss = AbilityEstimator.updated(
            ability, mode: .probe, servedDelta: delta, inscribed: false)

        #expect(abs(afterWin.core - 0.036) < 5e-4)
        #expect(abs(afterLoss.core + 0.144) < 5e-4)
        #expect(abs(afterLoss.core / afterWin.core + 4) < 0.01)
    }

    /// The fixed point: at `E[x] = P` the estimate does not move on average. Multiplying `K` by
    /// a direction-dependent factor destroys this, biasing θ̂ upward by ~0.4 logit at
    /// equilibrium and silently moving the true success rate to ~0.74.
    @Test("The estimator is unbiased at its own fixed point")
    func theFixedPointHolds() {
        var ability = Ability(core: 0.0)
        ability.n[.probe] = 32
        let delta = -Ability.targetOffset

        // Outcomes **sampled** at the target rate rather than cycled through it. The claim is
        // that `E[x] = P` is a fixed point, which is a statement about a sample; a deterministic
        // four-then-one pattern settles into a limit cycle whose mean is a small positive
        // artefact of the ordering, not of the estimator, and asserting against that number
        // would be pinning the artefact.
        var rng = SplitMix64(seed: 0x5EED)
        var theta = ability
        var samples: [Double] = []
        for index in 0..<4_000 {
            let roll = Double(rng.next() >> 11) / Double(1 << 53)
            theta = AbilityEstimator.updated(
                theta, mode: .probe, servedDelta: delta, inscribed: roll < 0.8)
            if index >= 2_000 { samples.append(theta.core) }
        }
        let mean = samples.reduce(0, +) / Double(samples.count)
        #expect(abs(mean) < 0.05)

        // And the same run at a rate BELOW the target moves the estimate down, which is the
        // other half of "unbiased": it tracks, it does not merely stay still.
        var falling = ability
        var slowRng = SplitMix64(seed: 0x5EED)
        for _ in 0..<400 {
            let roll = Double(slowRng.next() >> 11) / Double(1 << 53)
            falling = AbilityEstimator.updated(
                falling, mode: .probe, servedDelta: delta, inscribed: roll < 0.5)
        }
        #expect(falling.core < -0.5)
    }

    @Test("θ is clamped and n saturates")
    func boundsHold() {
        var ability = Ability(core: 5.9)
        ability.n[.probe] = Ability.maxScoredRounds
        for _ in 0..<50 {
            ability = AbilityEstimator.updated(
                ability, mode: .probe, servedDelta: -6, inscribed: true)
        }
        #expect(Ability.range.contains(ability.core))
        #expect(ability.scoredRounds(in: .probe) == Ability.maxScoredRounds)
    }

    /// An unplayed mode never drifts: the offset only moves when that mode is played, and the
    /// shrinkage pulls it back toward `core` when it is.
    @Test("Mode offsets move only for the mode played, and shrink toward core")
    func offsetsAreLocal() {
        var ability = Ability(core: 0)
        ability.n[.drift] = 0

        let after = AbilityEstimator.updated(
            ability, mode: .drift, servedDelta: -Ability.targetOffset, inscribed: false)
        #expect(after.drift < 0)
        #expect(after.echo == 0)
        #expect(after.sieve == 0)

        // Playing DRIFT still moves `core` — it is the only absolute — and the offset moves at
        // 0.6 × the gain on top of it.
        #expect(after.core < 0)
        #expect(abs(after.drift) < abs(after.core))
    }

    @Test("Theta reads as core plus the mode's own offset", arguments: Mode.allCases)
    func thetaComposition(_ mode: Mode) {
        var ability = Ability(core: 1.5)
        ability.drift = 0.4
        ability.echo = -0.2
        ability.sieve = 0.9
        let expected: Double =
            switch mode {
            case .probe: 1.5
            case .drift: 1.9
            case .echo: 1.3
            case .sieve: 2.4
            }
        #expect(abs(ability.theta(for: mode) - expected) < 1e-9)
    }
}
