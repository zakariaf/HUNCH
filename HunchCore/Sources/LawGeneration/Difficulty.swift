public import Glyphs
public import Laws

/// §5.1's difficulty function: the family determines the band, the modifiers determine the
/// position within it.
///
/// **Difficulty is structural.** It is the law's *family*, not its term count — a flat
/// grammar's hour 20 is hour 1 with more clauses. The five modifiers sum to at most 0.124, one
/// tick short of the 0.125 band width, so a law can never escape its band.
public enum Difficulty {
    /// The five modifier ceilings from §5.1, summing to exactly 0.124.
    public static let leafWeight = 0.030
    public static let deficitWeight = 0.040
    public static let freeAttributeWeight = 0.020
    public static let rateSkewWeight = 0.020
    public static let scatterWeight = 0.014

    /// The admit-rate mode the skew term measures distance from (§5.1 `m4`, §5.3).
    public static let targetAdmitRate = 0.30

    /// - Returns: a value in `[0.000, 1.000)`.
    public static func of(_ law: Law, in band: Band) -> Double {
        let base = Double(band.rawValue - 1) * 0.125

        // m1 — more terms inside the same idea.
        let extraLeaves = min(2, max(0, law.leafCount - band.minLeaves))
        let m1 = leafWeight * Double(extraLeaves) / 2

        // m2 — THE KEY MODIFIER. Does any single value predict the verdict? That is exactly
        // the power of the strategy every real player uses: vary one attribute, watch the lamp.
        let m2 = deficitWeight * law.marginalDeficit

        // m3 — unreferenced attributes must be ruled out.
        let m3 = freeAttributeWeight * Double(law.freeAttributeCount) / 3

        // m4 — evidence starvation in either direction.
        let m4 = rateSkewWeight * abs(law.admitRate - targetAdmitRate) / targetAdmitRate

        // m5 — a scattered subset is far harder to conjecture than a contiguous run.
        let m5 = scatterWeight * Double(min(2, law.scatteredSubsetCount)) / 2

        return base + m1 + m2 + m3 + m4 + m5
    }

    /// The five maxima sum to exactly 0.124 — one tick short of the band width, which is what
    /// makes "a law can never escape its band" true rather than hoped for.
    public static let modifierCeiling =
        leafWeight + deficitWeight + freeAttributeWeight + rateSkewWeight + scatterWeight

    /// §5.1's Rasch coupling: `δ_logit = 8 · difficulty − 4`, working range ≈ [−4.0, +3.99].
    public static func logit(forDifficulty difficulty: Double) -> Double { 8 * difficulty - 4 }

    /// The inverse, for the serving policy's step 11.
    public static func difficulty(forLogit logit: Double) -> Double { (logit + 4) / 8 }

    /// To hold 80 % success, serve `δ_logit = θ − ln 4`. `σ(ln 4) = 4/5` exactly, which is the
    /// whole target mechanism (§10.1).
    public static let eightyPercentOffset = 1.386_294_361_119_890_6  // ln 4
}
