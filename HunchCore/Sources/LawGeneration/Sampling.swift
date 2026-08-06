public import Glyphs

/// Integer-only sampling.
///
/// `Int.random`, `Double.random` and `RandomNumberGenerator.next(upperBound:)` are all off the
/// table: the first two are banned inside `HunchCore` by hygiene check 6, and the third's
/// algorithm is a stdlib implementation detail that may change between toolchains — which would
/// silently invalidate the cross-process golden fixture. Hand-rolled so the golden survives a
/// toolchain upgrade.
public enum Sampling {
    /// Unbiased rejection sampling over `0..<bound`.
    ///
    /// The naive `next() % bound` is biased whenever `bound` does not divide 2⁶⁴. The rejection
    /// zone is the top `2⁶⁴ mod bound` values, and discarding them makes every outcome equally
    /// likely — at an expected cost below two draws for any bound this project uses.
    public static func uniform(
        below bound: UInt64, using rng: inout some RandomNumberGenerator
    ) -> UInt64 {
        precondition(bound > 0, "uniform(below:) needs a positive bound")
        let limit = UInt64.max - (UInt64.max % bound)
        while true {
            let draw = rng.next()
            if draw < limit { return draw % bound }
        }
    }

    public static func uniform(
        below bound: Int, using rng: inout some RandomNumberGenerator
    ) -> Int {
        Int(uniform(below: UInt64(bound), using: &rng))
    }

    /// Cumulative integer weights; ties resolve toward the lower index. No floating point, so
    /// the choice is reproducible bit for bit on every platform.
    public static func weightedIndex(
        _ weights: [Int], using rng: inout some RandomNumberGenerator
    ) -> Int {
        precondition(!weights.isEmpty)
        let total = weights.reduce(0, +)
        precondition(total > 0, "weightedIndex needs at least one positive weight")
        var draw = Int(uniform(below: UInt64(total), using: &rng))
        for (index, weight) in weights.enumerated() {
            draw -= weight
            if draw < 0 { return index }
        }
        return weights.count - 1
    }
}
