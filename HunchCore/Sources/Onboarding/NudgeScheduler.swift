public import Foundation

public import Tokens

/// §12.5's five nudges, as a value with one owner.
///
/// **The hard floor is structural**: a nudge names a *control*, never a value, so the type
/// cannot express "try triangle". The five differ only in trigger, form and budget — the
/// vocabulary is one opacity breath, everywhere.
public struct NudgeScheduler: Equatable, Sendable {

    /// What a nudge may point at. There is no case carrying a glyph, an attribute or a rank,
    /// and that is the point: a nudge may only ever say *this control exists and is pressable*.
    public enum Target: String, Hashable, Sendable, CaseIterable {
        case probeKey
        case benchKey
        case offendingRail
        case surface
        case dialRamps
    }

    public enum Kind: String, Hashable, Sendable, CaseIterable {
        /// 12 s idle with no probe: the PROBE key breathes.
        case idle
        /// Past the point where a declaration is due and the Bench has never been opened.
        case noBench
        /// The third barred Seal press: the offending rail's cells sweep.
        case barredSeal
        /// 90 s idle: the whole surface dims.
        case globalIdle
        /// Two unvaried probes in a row: the Dial's ramps breathe.
        case unvaried

        public var target: Target {
            switch self {
            case .idle: .probeKey
            case .noBench: .benchKey
            case .barredSeal: .offendingRail
            case .globalIdle: .surface
            case .unvaried: .dialRamps
            }
        }

        public var budget: Int {
            switch self {
            case .idle: C.Nudge.idleBudget
            case .barredSeal: C.Nudge.barredSealBudget
            case .noBench, .globalIdle, .unvaried: C.Nudge.idleBudget
            }
        }
    }

    /// Everything the scheduler is allowed to know. It never reads a clock: the view drives
    /// elapsed time in, which is what keeps timers out of the model and the tests out of sleeps.
    public struct Observation: Equatable, Sendable {
        public var idleSeconds: Double
        public var probesUsed: Int
        public var par: Int
        public var openedBench: Bool
        public var barredSealPresses: Int
        public var unvariedRun: Int
        public var isVoiceOverRunning: Bool

        public init(
            idleSeconds: Double, probesUsed: Int, par: Int, openedBench: Bool,
            barredSealPresses: Int, unvariedRun: Int, isVoiceOverRunning: Bool
        ) {
            self.idleSeconds = idleSeconds
            self.probesUsed = probesUsed
            self.par = par
            self.openedBench = openedBench
            self.barredSealPresses = barredSealPresses
            self.unvariedRun = unvariedRun
            self.isVoiceOverRunning = isVoiceOverRunning
        }
    }

    public private(set) var pending: Kind?
    public private(set) var fired: [Kind: Int] = [:]

    public init() {}

    public var totalFired: Int { fired.values.reduce(0, +) }

    /// Suppression is **at the scheduler**, not inside the animation and not by setting the
    /// amplitude to zero: a suppressed animation still consumes its budget and still increments
    /// the count, so the player who turns VoiceOver off later finds their nudges already spent.
    /// Under VoiceOver nothing fires at all — the rotor already enumerates every control.
    public mutating func update(_ observation: Observation) {
        guard !observation.isVoiceOverRunning else {
            pending = nil
            return
        }
        pending = nil
        for kind in candidates(for: observation) where (fired[kind] ?? 0) < kind.budget {
            pending = kind
            fired[kind, default: 0] += 1
            return
        }
    }

    /// Order is priority: the most specific situation wins, and the global dim is last because
    /// it says the least.
    private func candidates(for observation: Observation) -> [Kind] {
        var kinds: [Kind] = []
        if observation.barredSealPresses >= C.Nudge.barredSealBudget { kinds.append(.barredSeal) }
        if observation.unvariedRun >= 2 { kinds.append(.unvaried) }
        if observation.probesUsed >= observation.par, !observation.openedBench {
            kinds.append(.noBench)
        }
        if observation.idleSeconds >= Double(C.Nudge.globalIdleThresholdSeconds) {
            kinds.append(.globalIdle)
        } else if observation.idleSeconds >= Double(C.Nudge.idleThresholdSeconds) {
            kinds.append(.idle)
        }
        return kinds
    }
}
