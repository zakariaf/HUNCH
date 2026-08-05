/// **L1 duration.** `Duration`, never `Double` — a bare `260` is ambiguous between
/// milliseconds and seconds and both appear in the GDD. The adapter converts once.
public enum Dur {
    public static let tap = Duration.milliseconds(90)
    public static let micro = Duration.milliseconds(120)
    public static let ringAdmit = Duration.milliseconds(200)
    public static let ringReject = Duration.milliseconds(160)
    public static let admit = Duration.milliseconds(260)
    public static let reject = Duration.milliseconds(250)
    public static let crossfade = Duration.milliseconds(220)
    public static let push = Duration.milliseconds(280)
    public static let sheet = Duration.milliseconds(320)
    public static let zoom = Duration.milliseconds(300)
    public static let shared = Duration.milliseconds(340)
    public static let streak = Duration.milliseconds(600)
    public static let drift = Duration.milliseconds(520)
    public static let reveal = Duration.milliseconds(1840)
    public static let revealLost = Duration.milliseconds(1020)
    public static let grainReseed = Duration.milliseconds(125)
    public static let pulse = Duration.milliseconds(90)
    /// Reduce Motion substitutions (§13.7.4). Six, not two: the four below were raw
    /// numbers in canon and are L1 because each is shared by two or more components.
    /// `hunch-motion-and-feedback/references/reduce-motion.md` owns which row uses which.
    public static let reduceMotionReveal = Duration.milliseconds(260)
    public static let reduceMotionRing = Duration.milliseconds(160)
    public static let reduceMotionSwap = Duration.milliseconds(140)
    public static let reduceMotionStrike = Duration.milliseconds(180)
    public static let reduceMotionExpand = Duration.milliseconds(200)
    public static let reduceMotionMorph = Duration.milliseconds(240)
}

/// **L1 easing.** Platform-free; the adapter maps each case to a SwiftUI `Animation`.
public enum Easing: Hashable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, dampingFraction: Double)
}

extension Easing {
    public static let snap = Easing.spring(response: 0.18, dampingFraction: 0.90)
    /// The only overshoot in the app — 8 pt, reveal beat 2. Never on a verdict.
    public static let settle = Easing.spring(response: 0.26, dampingFraction: 0.78)
    public static let dock = Easing.spring(response: 0.30, dampingFraction: 0.85)
    public static let sheet = Easing.spring(response: 0.32, dampingFraction: 0.86)
    public static let zoom = Easing.spring(response: 0.30, dampingFraction: 0.88)
    public static let shared = Easing.spring(response: 0.34, dampingFraction: 0.86)
}
