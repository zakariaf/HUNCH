public import SwiftUI

public import Tokens

/// The Dial ↔ Bench transition (§6.7, §13.7.3).
///
/// **Two clocks, and they are not the same one.** §6.7's 380 ms is the *tap* path — handle tap,
/// Bench key, Dial key — where there is no finger to follow and the whole choreography runs on a
/// fixed clock. §13.7.3's `Dur.sheet` bound is the *settle after release* of an interactive
/// drag. Naming one and reusing it for the other makes the drag either snap or lag.
public nonisolated struct BenchDrawer: Equatable, Sendable {

    /// §13.7.4 replaces the gesture wholesale under Reduce Motion; it does not shorten it.
    /// Shortening a drag to 40 ms is the named failure — the motion is still there, it is just
    /// too fast to read, which is worse than not moving at all.
    public enum Affordance: Equatable, Sendable {
        case drag
        case button
    }

    public var isOpen: Bool
    /// The live drag offset, in points, negative upward. Tracks the finger directly — not a
    /// `withAnimation` on a `Bool`, which cannot be interrupted mid-flight.
    public var dragOffset: Double

    public init(isOpen: Bool = false, dragOffset: Double = 0) {
        self.isOpen = isOpen
        self.dragOffset = dragOffset
    }

    public static func affordance(reduceMotion: Bool) -> Affordance {
        reduceMotion ? .button : .drag
    }

    /// How far the drawer has travelled, 0…1.
    public var progress: Double {
        let base = isOpen ? C.Bench.travel : 0
        return min(1, max(0, (base - dragOffset) / C.Bench.travel))
    }

    /// §13.7.3: a **flick** commits on predicted velocity at a third of the travel; a slow drag
    /// needs half of it. Two thresholds, because a fast short swipe and a slow long one are both
    /// "open" and neither is the other.
    public static func resolves(
        translation: Double, predictedEnd: Double, isOpen: Bool
    ) -> Bool {
        let travel = C.Bench.travel
        let direction: Double = isOpen ? 1 : -1
        let flick = predictedEnd * direction > travel * C.Bench.flickFraction
        let dragged = translation * direction > travel * C.Bench.dragCommitFraction
        return flick || dragged
    }
}
