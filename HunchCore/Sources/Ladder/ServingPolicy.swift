public import Foundation

public import Glyphs
public import Laws

/// §10.1's serving-side state — the half of the ladder where all the asymmetry lives.
public struct ServingState: Codable, Equatable, Sendable {
    public var reach = 0.0
    public var relief = 0.0
    public var winStreak = 0
    public var consecutiveLosses = 0
    public var lastFamily: Band?
    /// `nil` once calibrated.
    public var calibrationRound: Int? = 1
    public var ceilingClampRun = 0
    /// Drives the palette ceiling (§10.4) and **never decreases**.
    public var maxBandEverServed = 1

    public init() {}

    /// §10.3's pressure pair.
    ///
    /// `reach` climbs with a win streak and collapses on a loss; `relief` accumulates on the
    /// *second* consecutive loss and decays on a win. This is the "up fast, down gently" the
    /// brief asks for, and it is here rather than in the estimator because multiplying the
    /// estimator's gain by a direction-dependent factor destroys its fixed point (§10.2).
    ///
    /// - Parameters:
    ///   - atMaxBand: while the band is clamped at the mode's ceiling, `reach` **freezes** —
    ///     the ladder must never build up unspendable pressure that has to be discharged before
    ///     the next real move can be felt.
    ///   - atMinBand: the same for `relief` at the floor.
    public mutating func record(win: Bool, atMaxBand: Bool = false, atMinBand: Bool = false) {
        if win {
            winStreak += 1
            if !atMaxBand { reach = min(1.00, 0.25 * Double(winStreak - 1)) }
            consecutiveLosses = 0
            if !atMinBand { relief = max(0.00, relief - 0.50) }
        } else {
            winStreak = 0
            reach = 0
            consecutiveLosses += 1
            if consecutiveLosses >= 2, !atMinBand { relief = min(2.00, relief + 1.00) }
        }
    }
}

/// §10.3's thirteen steps, executed in this exact order once per round, before generation.
public enum ServingPolicy {

    /// **`π₀ = 0.44`, locked.**
    ///
    /// `reach` is not an occasional excursion, it is a standing offset: at an 80 % win rate,
    /// streaks of ≥ 5 occupy about a third of rounds and `E[reach] ≈ 0.413`, while `relief`
    /// answers with `≈ 0.035` because two consecutive losses is a 4 % event. Left uncentred the
    /// policy serves about +0.37 logit hard and the fixed point lands at **0.75, not 0.80** —
    /// which is not a rounding error against H3's ±0.03, it is a different game. `π₀` makes the
    /// pressure term a *reallocation* of difficulty across rounds rather than a net shift.
    public static let pressureCentre = 0.44

    public static let jitterRange = 0.35
    public static let deltaRange = -4.00...3.99
    public static let sieveDeltaCeiling = 2.99

    public static func modeBias(_ mode: Mode) -> Double {
        switch mode {
        // §7.2: the mid-round swap is a schedule *outside* the AST and is therefore invisible
        // to `difficulty(of:)`. It costs about half a band empirically; the bias pays for that
        // rather than corrupting the difficulty function.
        case .drift: -0.50
        case .probe, .echo, .sieve: 0
        }
    }

    public static func minBand(_ mode: Mode) -> Int {
        // DRIFT's floor is not decorative: the hinge cannot fire inside 0.80·par at bands 1–2,
        // and §7.7's par/cap table has no rows below band 3.
        mode == .drift ? 3 : 1
    }

    public static func maxBand(_ mode: Mode) -> Int { mode == .sieve ? 7 : 8 }

    /// The outcome of the policy. **Bands and `targetδ` — never a logit.** §8.6 and §9.7 consume
    /// `targetDelta`; `floor(logit/0.125)+1` on a logit of −2 returns band −15, which is the
    /// shape of bug that sentence exists to prevent.
    public struct Serve: Equatable, Sendable {
        public let band: Band
        /// Difficulty units, `[0.000, 1.000)`.
        public let targetDelta: Double
        /// `8·targetδ − 4`. **This**, not step 6's δ, is what the estimator consumes.
        public var servedDelta: Double { 8 * targetDelta - 4 }
    }

    /// - Parameter jitter: `U[−0.35, +0.35]`, drawn from the round seed. Passed in rather than
    ///   drawn here, because a policy that reaches for an RNG is a policy that cannot be
    ///   replayed from a round record.
    public static func serve(
        ability: Ability, mode: Mode, state: ServingState, jitter: Double
    ) -> Serve {
        var delta = ability.theta(for: mode) - Ability.targetOffset  // steps 1–2
        delta += modeBias(mode)  // step 3
        delta += state.reach - state.relief - pressureCentre  // step 4
        delta += min(jitterRange, max(-jitterRange, jitter))  // step 5
        delta = min(deltaRange.upperBound, max(deltaRange.lowerBound, delta))  // step 6
        if mode == .sieve { delta = min(sieveDeltaCeiling, delta) }

        let quantised = min(8, max(1, Int((delta + 4).rounded(.down)) + 1))  // step 7
        var band = min(maxBand(mode), max(minBand(mode), quantised))  // step 8
        var moved = band != quantised

        // Step 9 — the family repeat guard.
        if let last = state.lastFamily, state.consecutiveLosses > 0, last.rawValue == band {
            band = band == minBand(mode) ? min(maxBand(mode), band + 1) : band - 1
            moved = true
        }

        // Step 10 — ceiling rotation.
        var rotated = false
        if band == maxBand(mode), state.ceilingClampRun >= 3 {
            band = max(minBand(mode), band - 1)
            rotated = true
            moved = true
        }

        // Step 11 — **re-derived after every step that can move the band.** Computing the
        // within-band position against the pre-guard band and then moving the band leaves
        // `targetδ` clamped into a range the new band does not contain: G8 wants
        // `difficulty ∈ [lo, hi)` *and* within 0.02 of `targetδ`, and for a 5 → 4 shift at
        // `targetδ = 0.56` those windows do not intersect. Every one of the 200 attempts then
        // fails and the generator falls back to the family anchor — silently degrading the
        // repeat guard into "serve the same anchor law every time you lose twice".
        let resolved = Band(rawValue: band) ?? .literal
        let target: Double =
            if rotated {
                0.125 * Double(band) - 0.020  // the new band's upper near edge
            } else if moved {
                0.125 * Double(band) - 0.0625  // the new band's centre
            } else {
                min(
                    0.125 * Double(band) - 0.001,
                    max(0.125 * Double(band - 1), (delta + 4) / 8))
            }
        return Serve(band: resolved, targetDelta: target)
    }
}
