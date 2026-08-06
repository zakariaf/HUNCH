public import Foundation

public import Glyphs
public import Laws

/// §7.7's budget. **The second induction costs less than the first**: the family is known and the
/// search collapses to the one-leaf edit-neighbourhood of `L₁`, so `par_DRIFT = par + rec(b)`
/// rather than `2 · par`.
public enum DriftBudget {

    /// §7.2: DRIFT is restricted to bands 3–8. Not decorative — the hinge cannot fire inside
    /// `0.80 · par` at bands 1–2, and this table has no rows below band 3.
    public static let bands: [Band] = [
        .exclusive, .relational, .contextual, .guarded, .composite, .systemic,
    ]

    /// The recovery allowance, `ceil(k(b) · log₂|Nbhd|)`, locked over real neighbourhood sizes.
    public static func recovery(_ band: Band) -> Int? {
        switch band {
        case .exclusive, .relational, .contextual, .guarded: 9
        case .composite, .systemic: 11
        case .literal, .pair: nil
        }
    }

    public static func par(_ band: Band) -> Int? {
        guard let recovery = recovery(band) else { return nil }
        return band.par + recovery
    }

    /// The same `ceil(1.6 · par)` canon uses everywhere; only `par` is substituted.
    public static func cap(_ band: Band) -> Int? {
        guard let par = par(band) else { return nil }
        return Int((1.6 * Double(par)).rounded(.up))
    }

    /// §7.3 trigger (c): probe index `ceil(0.80 · par(b))` — an unlucky run still gets the mode.
    /// **`par(b)`, not `par_DRIFT(b)`**: the forced hinge is measured against the *first*
    /// induction's budget, because it exists to guarantee the drift happens while the player is
    /// still forming their first theory.
    public static func forcedHinge(_ band: Band) -> Int? {
        guard recovery(band) != nil else { return nil }
        return Int((0.80 * Double(band.par)).rounded(.up))
    }
}
