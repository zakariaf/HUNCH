public import Foundation

public import Glyphs
public import LawGeneration
public import Laws

/// §10.8's triggers. At the top of the ladder the game **silently changes question**: bands 1–6
/// ask *what is the law*, and band 8 with the tightened par asks *in how few probes*, which has
/// no ceiling. That is what keeps hour 20 interesting — not a difficulty number that climbs,
/// because it cannot; there are eight bands.
public enum AntiBoredom {

    /// The tightened three-mark standard. **The law does not change; the *scoring* does.**
    public static let tightenedThreeMarkFraction = 0.45

    /// Reverts after this many losses of the tightened standard.
    public static let tightenedRevertLosses = 3

    /// ≥ 8 wins in the last 10 rounds at band 8 with δ pinned at the ceiling.
    public static func ceilingVariationApplies(
        recentWinsAtCeiling: Int, recentRounds: Int, band: Band, deltaClamped: Bool
    ) -> Bool {
        band == .systemic && deltaClamped && recentRounds >= 10 && recentWinsAtCeiling >= 8
    }

    /// Band 8 holds 337 laws, which canon flags honestly: past 150 lifetime solves a player has
    /// seen nearly half of them. The novelty preference is **soft** — the first 100 of the
    /// generator's 200 attempts additionally reject anything already in the Codex, and attempts
    /// 101–200 fall back to the locked last-50 guard, so the locked constant is untouched.
    public static let softNoveltyThreshold = 150
    public static let softNoveltyAttempts = 100

    /// §10.8's textless nudge: the weakest mode's sigil renders at full luminance while the
    /// others sit at 60 %. A pointer toward the mode that still has slope in it.
    public static func weakestMode(_ ability: Ability) -> Mode? {
        let offsets: [(Mode, Double)] = [
            (.drift, ability.drift), (.echo, ability.echo), (.sieve, ability.sieve),
        ]
        guard let weakest = offsets.min(by: { $0.1 < $1.1 }), weakest.1 < -1.0 else {
            return nil
        }
        return weakest.0
    }

    public static let dimmedModeLuminance = 0.60
}
