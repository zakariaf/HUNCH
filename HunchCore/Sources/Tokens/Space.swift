/// **L1 length, in points.** Never scaled by Dynamic Type: text grows and containers
/// reflow (§13.4, `minimumScaleFactor` 1.0), while the 4 pt grid holds. Art that does
/// scale multiplies by `env.artScale` at the drawing site.
///
/// Steps are named for their value because the scale is a grid, not a semantic ramp;
/// inventing `space.cozy` would assign meaning the GDD never assigned. Semantic
/// spacing lives at L2 (`c.settingsRow.labelInset = Space.s16`).
public enum Space {
    public static let s4 = 4.0
    public static let s8 = 8.0
    public static let s12 = 12.0
    public static let s16 = 16.0
    public static let s20 = 20.0
    public static let s24 = 24.0
    public static let s32 = 32.0
    public static let s44 = 44.0
    public static let s64 = 64.0

    public static let marginOuter = 16.0
    public static let columnContent = 343.0
    public static let targetMin = 44.0
    public static let ruleInset = 16.0
    public static let boundaryAbove = 24.0
    public static let boundaryBelow = 16.0
}

/// **L1 corner radius, in points.**
public enum Radius {
    /// Zero, always. Corner count is the `shape` channel; rounding erodes it (§13.1).
    public static let glyph = 0.0
    public static let chrome = 2.0
    /// The Bench sheet's top corners, and nothing else.
    public static let sheet = 12.0
}

/// **L1 opacity.** No multiplicative axis exists: High Contrast *substitutes* an
/// opacity, it never scales one. Component-scoped opacities live at L2.
public enum Opacity {
    public static let halo = 0.12
    public static let bloomBed = 0.35
    public static let disabled = 0.35
    public static let pressed = 0.70
    public static let scrimFlat = 0.85
    public static let scrimBlurred = 0.60

    /// The light theme's impression ladder — four concentric hairlines that press a
    /// panel into the sheet. Read only when `env.isImpressionDepthEnabled`; the
    /// geometry (weights and insets) belongs to `hunch-chrome-and-meta`.
    public static let impressionOuter = 1.00
    public static let impressionMid = 0.55
    public static let impressionInner = 0.30
    public static let impressionFaint = 0.14

    /// The Bench scrim: 0.6 α over a blur when transparency is allowed, otherwise a
    /// flat 0.85 α `ground` (§13.11).
    public static func scrim(in env: RenderEnv) -> Double {
        env.isReduceTransparencyEnabled ? scrimFlat : scrimBlurred
    }
}
