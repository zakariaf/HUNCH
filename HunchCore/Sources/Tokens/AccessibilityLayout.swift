public import Foundation

/// §13.11's Dynamic Type behaviour, per screen — as a table, because "above AX2 nothing shrinks"
/// is a rule that has to hold on **every** screen and is otherwise checked one screen at a time.
public enum AccessibilityLayout {

    /// What a screen does above AX2, where the art scale has already saturated at 1.35×.
    public enum AboveAX2: String, Equatable, Sendable {
        /// The Dial's four ramps scroll vertically inside a region that does not grow.
        case scrollsInsideItsRegion
        /// The Bench becomes a single-rail pager and the Assay moves to a full-width strip.
        case pages
        /// Rows reflow to two lines and the row height grows.
        case reflowsRows
        /// A drawing, not text: it holds its geometry and does not scale at all.
        case holdsItsGeometry
        /// No text by construction — nothing to do.
        case unaffected
    }

    public enum Screen: String, CaseIterable, Hashable, Sendable {
        case probeSurface
        case bench
        case codex
        case profile
        case anomaly
        case statistics
        case settings
        case onboarding

        public var aboveAX2: AboveAX2 {
            switch self {
            case .probeSurface: .scrollsInsideItsRegion
            case .bench: .pages
            case .codex, .statistics, .settings, .anomaly: .reflowsRows
            case .profile: .holdsItsGeometry
            case .onboarding: .unaffected
            }
        }

        /// **Nothing shrinks, anywhere, ever.** Chrome text never truncates and never scales
        /// down: `lineLimit(nil)`, `fixedSize`, no `minimumScaleFactor`. If a row cannot fit,
        /// the row grows.
        public var shrinksAnything: Bool { false }
    }

    /// The commit bar is pinned on every surface and never scrolls — §12.8 tier 1's "the thing
    /// that ends a decision is always in the same place under the same thumb", which a scrolling
    /// commit bar would break at exactly the text size where reach matters most.
    public static let commitBarScrolls = false

    /// A thumbnail is a **picture, not text**, so it holds 44 pt at every size. Scaling it would
    /// make a 16 × 16 constellation illegible in the name of legibility.
    public static let thumbnailSide = 44.0

    /// §13.11: Reduce Transparency turns the shader off and makes every material opaque, and the
    /// Bench scrim goes from a 0.6 α blur to a flat 0.85 α ground.
    public static func scrimOpacity(reduceTransparency: Bool) -> Double {
        reduceTransparency ? Opacity.scrimFlat : Opacity.scrimBlurred
    }

    /// §13.11: Bold Text steps every type role one weight **and** steps glyph and rule-tile
    /// stroke weights ×1.25.
    ///
    /// The play surface has no text, so Bold Text is the only signal the system gives us that
    /// this player wants heavier marks — honouring it there is more useful than ignoring it,
    /// which is the whole argument for a text setting reaching a wordless surface.
    public static let boldTextStrokeScale = Prim.boldTextStrokeScale

    /// §13.11: Differentiate Without Colour is **true by construction** — every verdict is a
    /// shape before it is a colour. When on, two marks additionally widen: the reject ring's gap
    /// doubles, and the counterexample's two rings take distinct dash patterns so the
    /// contradiction is separable without either colour **or memory**.
    public static let differentiateWithoutColourIsDefault = true
}
