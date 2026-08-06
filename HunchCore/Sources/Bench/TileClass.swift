public import Glyphs
public import Laws

/// §4.2's four tile classes plus the coupler — what a player can put on a rail.
public enum TileClass: String, CaseIterable, Hashable, Sendable, Codable {
    case ramp, bridge, fork, tally
}

/// §4.4's palette ceiling.
///
/// Tile classes unlock at the player's **lifetime maximum band + 1**, never at the current
/// round's band: a veteran always sees the full palette whatever they are being served and
/// cannot read the family off their own toolbox, and a beginner literally cannot express a
/// band-5 law — which is fine, because they will never be served one.
public enum PaletteCeiling {

    /// Which tile classes a family needs to be stated at all.
    ///
    /// Exhaustive over `Band`, no `default:` — a ninth band would have to answer this question
    /// rather than inherit an answer.
    public static func required(for band: Band) -> Set<TileClass> {
        switch band {
        case .literal: [.ramp]
        case .pair: [.ramp]
        case .exclusive: [.ramp]
        case .relational: [.ramp, .bridge]
        case .contextual: [.ramp, .bridge]
        case .guarded: [.ramp, .bridge, .fork]
        case .composite: [.ramp, .bridge, .fork]
        case .systemic: [.ramp, .bridge, .fork, .tally]
        }
    }

    /// The palette a player holds, given the highest band they have ever been **served**.
    ///
    /// Served, not cleared: `reach` can add a full band and jitter another third, so a player
    /// whose lifetime maximum *cleared* band is 6 can be served band 8 and still have no Tally.
    ///
    /// - Parameter isCalibrating: rounds 1–5 unlock the full palette, exactly as the Anomaly
    ///   round does, and revert when calibration ends. The gallop is what makes §4.4's "they
    ///   will never be served one" false: a player who wins bands 1 and 2 has a lifetime maximum
    ///   of 2, hence a ceiling of band 3 and **no Bridge**, and round 3 is band 4 RELATIONAL —
    ///   unwinnable by construction, and that loss is what would seed `core`.
    public static func available(
        maxBandEverServed: Band, isCalibrating: Bool = false
    ) -> Set<TileClass> {
        guard !isCalibrating else { return Set(TileClass.allCases) }
        let ceiling = Band(rawValue: min(Band.systemic.rawValue, maxBandEverServed.rawValue + 1))
        return required(for: ceiling ?? .systemic)
    }

    /// §10.4's serve-time assertion. G10 proves every emitted law is buildable **on the full
    /// palette** and says nothing about the palette this player is holding, so the guarantee has
    /// to be checked here, before the round arms — not at generation time.
    public static func canExpress(band: Band, with palette: Set<TileClass>) -> Bool {
        required(for: band).isSubset(of: palette)
    }
}
