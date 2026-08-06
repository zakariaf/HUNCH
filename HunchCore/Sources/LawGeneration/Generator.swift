public import Glyphs
public import Laws

public enum Generation {
    /// §5.7's locked attempt bound. Generation must never block or fail, so exhausting this
    /// falls back to the family anchor.
    public static let attemptBound = 200
    /// §5.3's monitored statistic: the anchor fallback must stay under 2 % per band.
    public static let fallbackBudget = 0.02
}

public struct GenerationReport: Sendable {
    public let law: LawNode
    public let attempts: Int
    public let usedAnchor: Bool
}

/// §5.3's generator. Pure over the caller's five arguments plus the law index, which is derived
/// data identical in every process.
///
/// - Complexity: bounded by `Generation.attemptBound` guardrail evaluations.
public func generate(
    seed: UInt64, band: Band, targetDelta: Double, mode: Mode,
    avoid: Set<UInt64> = [], in index: LawIndex
) -> LawNode {
    generateReporting(
        seed: seed, band: band, targetDelta: targetDelta, mode: mode, avoid: avoid, in: index
    ).law
}

public func generateReporting(
    seed: UInt64, band: Band, targetDelta: Double, mode: Mode,
    avoid: Set<UInt64>, in index: LawIndex
) -> GenerationReport {
    // 08 §4's shape, and it is not negotiable: a local `var` that never escapes, threaded by
    // `inout` down a synchronous call tree. Never async, never stored.
    var rng = SplitMix64(seed: seed ^ (UInt64(band.rawValue) << 32) ^ mode.salt)

    let candidates = index.forms(for: band)
    guard !candidates.isEmpty else {
        return GenerationReport(law: band.anchor, attempts: 0, usedAnchor: true)
    }

    for attempt in 1...Generation.attemptBound {
        let node = candidates[Sampling.uniform(below: candidates.count, using: &rng)]
        let law = Law(node)
        if Guardrail.clearsRequest(law, in: band, targetDelta: targetDelta, avoid: avoid) {
            return GenerationReport(law: node, attempts: attempt, usedAnchor: false)
        }
    }

    // The anchor is exempt from G8's proximity clause and from G9 — a last resort that can
    // itself be vetoed is not a last resort (§5.3).
    return GenerationReport(law: band.anchor, attempts: Generation.attemptBound, usedAnchor: true)
}
