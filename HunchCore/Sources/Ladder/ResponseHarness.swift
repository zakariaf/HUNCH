public import Foundation

public import Glyphs
public import Laws

/// §10's **Level-A harness**: a simulated player whose only property is a true ability, played
/// against the real serving policy and the real estimator.
///
/// Its job is to answer one question the unit tests cannot: does the *whole loop* — target,
/// pressure, jitter, quantisation, band clamps, guards and the estimator — realise the 80 %
/// success rate the design is built on? Every piece can be individually correct and the
/// composition still land at 0.75, which is what `π₀` exists to prevent and what this measures.
public struct ResponseHarness: Sendable {

    public struct Result: Equatable, Sendable {
        public var rounds: Int
        public var wins: Int
        public var finalTheta: Double
        public var bandHistogram: [Int: Int]
        public var longestSameFamilyRun: Int

        public var successRate: Double {
            rounds == 0 ? 0 : Double(wins) / Double(rounds)
        }

        /// §10.8's measured claim: the modal family stays under 60 % of rounds.
        public var modalBandShare: Double {
            guard rounds > 0, let modal = bandHistogram.values.max() else { return 0 }
            return Double(modal) / Double(rounds)
        }
    }

    public let trueTheta: Double
    public let mode: Mode

    public init(trueTheta: Double, mode: Mode = .probe) {
        self.trueTheta = trueTheta
        self.mode = mode
    }

    /// - Parameter seed: the whole run is a pure function of it. A harness that reached for a
    ///   system RNG could not be re-run on a failure, which is the only time anybody wants it.
    public func run(rounds: Int, seed: UInt64, startingAt core: Double? = nil) -> Result {
        var rng = SplitMix64(seed: seed)
        var ability = Ability(core: core ?? trueTheta)
        var state = ServingState()
        state.calibrationRound = nil

        var wins = 0
        var histogram: [Int: Int] = [:]
        var longestRun = 0
        var currentRun = 0
        var previousBand: Int?

        for _ in 0..<rounds {
            let jitter =
                (Double(rng.next() >> 11) / Double(1 << 53)) * 2 * ServingPolicy.jitterRange
                - ServingPolicy.jitterRange
            let serve = ServingPolicy.serve(
                ability: ability, mode: mode, state: state, jitter: jitter)

            // The simulated player: a Rasch response at their TRUE ability against the δ the
            // policy actually served — not the δ the policy intended before quantisation.
            let probability = Ability.successProbability(
                theta: trueTheta, delta: serve.servedDelta)
            let roll = Double(rng.next() >> 11) / Double(1 << 53)
            let won = roll < probability
            if won { wins += 1 }

            histogram[serve.band.rawValue, default: 0] += 1
            if serve.band.rawValue == previousBand {
                currentRun += 1
            } else {
                currentRun = 1
            }
            longestRun = max(longestRun, currentRun)
            previousBand = serve.band.rawValue

            ability = AbilityEstimator.updated(
                ability, mode: mode, servedDelta: serve.servedDelta, inscribed: won)
            let atMax = serve.band.rawValue == ServingPolicy.maxBand(mode)
            let atMin = serve.band.rawValue == ServingPolicy.minBand(mode)
            state.record(win: won, atMaxBand: atMax, atMinBand: atMin)
            state.lastFamily = serve.band
            state.maxBandEverServed = max(state.maxBandEverServed, serve.band.rawValue)
        }

        return Result(
            rounds: rounds, wins: wins, finalTheta: ability.core,
            bandHistogram: histogram, longestSameFamilyRun: longestRun)
    }
}
