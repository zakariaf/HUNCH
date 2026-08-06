public import Foundation

public import Glyphs
public import Laws

/// §11.9's five axes. **This is the single normative definition** — the per-mode sections own
/// the transcript *quantities* and nothing else, because five axes with three spellings is the
/// same defect as one law with two extensions.
public enum ProfileAxis: String, CaseIterable, Hashable, Sendable, Codable {
    case induction
    case retention
    case flexibility
    case restraint
    case tempo
}

/// One axis's state: a value and a confidence count.
public struct AxisState: Codable, Equatable, Sendable {
    public var value: Double
    /// Confidence, `0…60`. Not a count of rounds — a count of *weighted* rounds.
    public var n: Double

    public init(value: Double = 0, n: Double = 0) {
        self.value = value
        self.n = n
    }

    public static let confidenceCeiling = 60.0
    /// The floor is why the portrait never freezes: at `n = 60` a sample still moves it 6 %.
    public static let alphaFloor = 0.06

    /// **Robbins–Monro, and the only update rule for any axis.** It subsumes a fixed-α EWMA —
    /// which is its `n → ∞` tail — is fast while the portrait is unformed and slow once it is,
    /// and the 0.06 floor means it never stops responding.
    public mutating func update(sample: Double, weight: Double) {
        let alpha = weight * max(AxisState.alphaFloor, 1 / (n + 1))
        value += alpha * (min(1, max(0, sample)) - value)
        n = min(AxisState.confidenceCeiling, n + weight)
    }

    /// §11.9's idle handling: **no decay of `value` toward anything.** Confidence decays
    /// instead, so coming back after a long gap makes the portrait *more responsive*, not
    /// *lower*. A decay toward the mean would read as punishment for not playing — the same
    /// lever as a streak reminder, which the brief rules out.
    public mutating func decayConfidence(daysIdle: Double) {
        n = max(4, n * pow(0.5, daysIdle / 60))
    }
}

/// §11.9's per-round samples. Every one is oriented **more is more of the thing the vertex is
/// named for**, because §11.10 grows a radius with its value — so Tempo samples `par/probes`,
/// not canon's `probes/par`.
public enum ProfileSample {

    /// Induction is a **mean of settled rounds, not a running maximum**, overruling the plainest
    /// reading of §5.4's "highest band cleared". §11.10 normalises radii against the player's own
    /// five-axis mean, so an axis that can only ratchet upward eventually dominates the
    /// silhouette for reasons unrelated to how the player plays — and one lucky band-8 clear
    /// would permanently redraw the portrait, which is the definition of a trophy. The mean says
    /// *where you live*, which is what a self-portrait is for.
    public static func induction(band: Band, solved: Bool) -> Double {
        solved
            ? Double(band.rawValue - 1) / 7
            : min(1, max(0, Double(band.rawValue - 2) / 7))
    }

    /// Credit for each lawful index placed, debited one-for-one by each intrusion, over the `A`
    /// that were there.
    public static func retentionEcho(hit: Int, answerCount: Int, lawfulCount: Int) -> Double {
        guard lawfulCount > 0 else { return 0 }
        return max(0, Double(hit - (answerCount - hit)) / Double(lawfulCount))
    }

    /// A probe is a *duplicate pair* if its exact ordered `(prev, cur)` already appears in the
    /// ribbon — which is the PROBE-side analogue of an intrusion.
    public static func retentionProbe(duplicatePairProbes: Int, probes: Int) -> Double {
        guard probes > 0 else { return 1 }
        return max(0, 1 - Double(duplicatePairProbes) / Double(probes))
    }

    /// `clamp((2L* − L) / (1.5L*))`, on canon's `par(b)` and **never** `par_DRIFT` — the target
    /// is how fast a *hypothesis* is abandoned, and measuring it against the recovery budget
    /// would make a mode with a longer budget look more flexible.
    public static func flexibility(latency: Int, par: Int, isDriftHinge: Bool) -> Double {
        let target = (isDriftHinge ? 0.45 : 0.30) * Double(par)
        guard target > 0 else { return 0 }
        return min(1, max(0, (2 * target - Double(latency)) / (1.5 * target)))
    }

    /// §11.9's discrete component. The ordering is the argument: a cap-loss with **zero
    /// strikes** scores above a win that took one, because restraint is about declaring only
    /// once the evidence closes — and a player who never declared on a hunch showed more of it
    /// than one who declared twice and got there.
    public enum RestraintOutcome: Double, Sendable {
        case solvedClean = 1.00
        case capLossNoStrikes = 0.60
        case solvedAfterOneStrike = 0.35
        case lostOnSecondStrike = 0.00
    }

    /// `0.6·d + 0.4·m`. The margin is skipped — and Restraint uses `d` alone — at bands 5 and 7,
    /// where no materialised stateless hypothesis set exists to count `H_live` against.
    public static func restraint(
        outcome: RestraintOutcome, liveHypotheses: Int?, bandPopulation: Int
    ) -> Double {
        guard let live = liveHypotheses, live > 0, bandPopulation > 1 else {
            return outcome.rawValue
        }
        let margin = min(1, max(0, 1 - log2(Double(live)) / log2(Double(bandPopulation))))
        return 0.6 * outcome.rawValue + 0.4 * margin
    }

    /// `min(1, par/probes)` — **par over probes**, so the efficient player is pulled *toward* the
    /// Tempo vertex. Canon names the quantity as `probes/par`; §11.10's geometry fixes the
    /// direction, and a sample oriented the other way would draw the fastest player smallest.
    public static func tempo(probes: Int, par: Int, solved: Bool) -> Double {
        let ratio = min(1, Double(par) / Double(max(1, probes)))
        return solved ? ratio : 0.5 * ratio
    }

    public static func tempoSieve(medianLatency: Double, meanWindow: Double) -> Double {
        guard meanWindow > 0 else { return 0 }
        return min(1, max(0, 1 - medianLatency / meanWindow))
    }
}
