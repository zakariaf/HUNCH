public import Foundation

public import Glyphs

/// §10.1's ability estimate — a **pure value type, no clock, no store.**
public struct Ability: Codable, Equatable, Sendable {
    /// PROBE-anchored, and the only absolute. Everything else is an offset from it, which is
    /// what stops four modes from each having their own idea of who the player is.
    public var core: Double
    public var drift = 0.0
    public var echo = 0.0
    public var sieve = 0.0
    /// Scored rounds per mode, after calibration.
    public var n: [Mode: Int] = [:]
    public var lastPlayed: [Mode: Date] = [:]

    public init(core: Double) { self.core = core }

    /// §10.2: hard-clamped at write. A θ outside this range is not a player, it is a bug that
    /// has been accumulating.
    public static let range = -6.0...6.0
    public static let maxScoredRounds = 4_096

    /// The 80 % target, exactly: `σ(ln 4) = 4/5`, so serving `δ = θ − ln 4` hits 0.800 by
    /// construction. That identity is the whole target mechanism; everything in §10.3 is
    /// correction and safety on top of it.
    public static let targetOffset = 1.386_294_361_119_890_6

    public func theta(for mode: Mode) -> Double {
        switch mode {
        case .probe: core
        case .drift: core + drift
        case .echo: core + echo
        case .sieve: core + sieve
        }
    }

    public func scoredRounds(in mode: Mode) -> Int { n[mode] ?? 0 }

    /// `P(win) = σ(θ − δ)`. Nothing else: no guessing parameter, because a wrong declaration is
    /// not a lucky guess over 27,015 laws, and no discrimination parameter, because the family
    /// structure already carries it.
    public static func successProbability(theta: Double, delta: Double) -> Double {
        1 / (1 + exp(delta - theta))
    }
}

/// §10.2's update rule — **symmetric, pure, unbiased.**
public enum AbilityEstimator {

    /// `K(n) = max(0.18, 0.90 / (1 + n/8))`.
    ///
    /// At the floor a win at `P = 0.8` moves `+0.036` and a loss `−0.144`: four wins to undo one
    /// loss, which is the correct ratio at an 80 % target and needs no asymmetry to produce it.
    public static func gain(scoredRounds n: Int) -> Double {
        max(0.18, 0.90 / (1 + Double(n) / 8))
    }

    /// Mode offsets move on the same rule at 0.6 × the gain, with shrinkage after each update —
    /// which is what makes an unplayed mode never drift.
    public static let offsetGainFactor = 0.6
    public static let offsetShrinkage = 0.985

    /// **Strictly symmetric.** `θ += K(x − P)` has a fixed point at `E[x] = P` for any `K`;
    /// multiplying `K` by a direction-dependent factor destroys that fixed point and biases the
    /// estimate upward by ~0.4 logit at equilibrium, silently moving the true success rate to
    /// ~0.74. All the "up fast, down gently" asymmetry the brief asks for lives in the serving
    /// policy's `reach` and `relief`, where it costs the estimate nothing.
    public static func updated(
        _ ability: Ability, mode: Mode, servedDelta: Double, inscribed: Bool
    ) -> Ability {
        var ability = ability
        let n = ability.scoredRounds(in: mode)
        let theta = ability.theta(for: mode)
        let probability = Ability.successProbability(theta: theta, delta: servedDelta)
        let outcome = inscribed ? 1.0 : 0.0
        let step = gain(scoredRounds: n) * (outcome - probability)

        ability.core = clamp(ability.core + step)
        if mode != .probe {
            let offsetStep = step * offsetGainFactor
            switch mode {
            case .drift: ability.drift = (ability.drift + offsetStep) * offsetShrinkage
            case .echo: ability.echo = (ability.echo + offsetStep) * offsetShrinkage
            case .sieve: ability.sieve = (ability.sieve + offsetStep) * offsetShrinkage
            case .probe: break
            }
        }
        ability.n[mode] = min(Ability.maxScoredRounds, n + 1)
        return ability
    }

    private static func clamp(_ theta: Double) -> Double {
        min(Ability.range.upperBound, max(Ability.range.lowerBound, theta))
    }
}
