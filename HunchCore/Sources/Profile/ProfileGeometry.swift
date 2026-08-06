public import Foundation

/// §11.10's geometry. **The load-bearing rule: radii are normalised against the player's own
/// five-axis mean, so the portrait cannot grow.**
///
/// That single choice is what makes this a self-portrait rather than a score: two players with
/// identical shapes are identical *in balance*, and a player who improves everywhere sees the
/// same silhouette — which is exactly right, because they have not changed what kind of player
/// they are.
public enum ProfileGeometry {

    /// Five vertices at `θ_i = −90° + i·72°`, locked order clockwise from the top.
    public static let vertexOrder: [ProfileAxis] = [
        .induction, .retention, .flexibility, .restraint, .tempo,
    ]

    public static func angle(of axis: ProfileAxis) -> Double {
        guard let index = vertexOrder.firstIndex(of: axis) else { return -90 }
        return -90 + 72 * Double(index)
    }

    public static let cardSize = (width: 375.0, height: 280.0)
    public static let centre = (x: 187.5, y: 140.0)
    public static let baseRadius = 96.0

    /// Radius as a fraction of `R₀`, normalised against the mean of all five.
    ///
    /// A player who is better at everything draws the same shape, and a player who is better at
    /// *one* thing draws a longer spoke there — which is the only comparison the Profile makes,
    /// and it is with themselves.
    public static func radii(_ values: [ProfileAxis: Double]) -> [ProfileAxis: Double] {
        let all = vertexOrder.map { values[$0] ?? 0 }
        let mean = all.reduce(0, +) / Double(all.count)
        guard mean > 0 else {
            return Dictionary(uniqueKeysWithValues: vertexOrder.map { ($0, baseRadius) })
        }
        return Dictionary(
            uniqueKeysWithValues: vertexOrder.map {
                ($0, baseRadius * ((values[$0] ?? 0) / mean))
            })
    }

    /// §11.10's tremble: low confidence draws the vertex unsteady rather than short. An unformed
    /// axis is *unknown*, not *bad*, and drawing it short would say the second.
    public static func tremble(confidence n: Double) -> Double {
        max(0, 1 - n / AxisState.confidenceCeiling)
    }
}
