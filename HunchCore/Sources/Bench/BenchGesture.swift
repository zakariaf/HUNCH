/// §4.2's gesture inventory — **exhaustive**, and a value rather than prose so that the claim
/// "there is no drag, no pinch, no long-press and no double-tap anywhere in the declaration UI"
/// can be asserted rather than remembered.
///
/// The reason is accessibility, not taste: drag and pinch are precisely the gestures VoiceOver
/// cannot perform and that no textless affordance can teach. Every row here is a tap or a
/// trailing swipe, and every non-tap row carries a custom action so the whole Bench is operable
/// with rotor plus single-finger double-tap.
public enum BenchGesture: String, CaseIterable, Hashable, Sendable {
    case tapPaletteStamp
    case tapCell
    case tapCoupler
    case tapWedge
    case tapGhostToggle
    case tapSocketThenHeader
    case swipeRailTrailing
    case tapSeal

    public enum Kind: String, Hashable, Sendable {
        case tap
        /// The one non-tap in the whole declaration UI.
        case trailingSwipe
    }

    public var kind: Kind {
        switch self {
        case .swipeRailTrailing: .trailingSwipe
        case .tapPaletteStamp, .tapCell, .tapCoupler, .tapWedge, .tapGhostToggle,
            .tapSocketThenHeader, .tapSeal:
            .tap
        }
    }

    /// Whether the row needs a VoiceOver custom action to be reachable without the gesture.
    /// Taps do not: a tap *is* single-finger double-tap under VoiceOver.
    public var needsCustomAction: Bool { kind != .tap }
}
