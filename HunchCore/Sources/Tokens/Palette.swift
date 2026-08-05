/// A colour from the **accent** register. Constructible only inside `Tokens`, so
/// `accent.*` reaching a glyph body, a ramp cell or an index stroke is a compile
/// error rather than a review note (§13.2's hard rule, made structural).
public struct AccentColor: Hashable, Sendable {
    public let rgb: RGB8
    init(_ rgb: RGB8) { self.rgb = rgb }
}

/// A colour from the **hue** register. Constructible only inside `Tokens`, so
/// `hue.*` cannot reach chrome, a rule-tile frame, a tick mark or the Seal.
/// Under High Contrast every member is `stroke.primary` — the one sanctioned
/// crossing, and it lives here rather than at a call site for exactly that reason.
public struct HueColor: Hashable, Sendable {
    public let rgb: RGB8
    init(_ rgb: RGB8) { self.rgb = rgb }
}

/// **L1 colour.** Every value is `theme`-selected; nothing here is multiplied or offset.
public struct Palette: Hashable, Sendable {
    public struct Ground: Hashable, Sendable {
        public let base: RGB8
        public let raised: RGB8
        public let sunken: RGB8
    }

    public struct Surface: Hashable, Sendable {
        public let cell: RGB8
        public let cellLit: RGB8
    }

    public struct Stroke: Hashable, Sendable {
        public let primary: RGB8
        public let secondary: RGB8
        public let hairline: RGB8
    }

    public struct Accent: Hashable, Sendable {
        public let brass: AccentColor
        public let brassPress: AccentColor
        public let cold: AccentColor
        public let coldPress: AccentColor
    }

    public struct Hue: Hashable, Sendable {
        public let amber: HueColor
        public let teal: HueColor
        public let frost: HueColor
        public let rose: HueColor
        /// Rank order 1…4 — the order §13.5 pins to index rotations 0/45/90/135°.
        public var ranked: [HueColor] { [amber, teal, frost, rose] }
    }

    public let theme: RenderEnv.Theme
    public let ground: Ground
    public let surface: Surface
    public let stroke: Stroke
    public let accent: Accent
    public let hue: Hue
    /// **Light theme only.** The `stroke.primary` keyline drawn beneath the hue at
    /// `resolvedBodyWeight + 1.0`, so the silhouette edge is 15.58 : 1 while
    /// Okabe–Ito stays verbatim (§13.2 †). `nil` in dark (worst hue 5.78 : 1, no
    /// keyline needed) and in High Contrast (hue is already `stroke.primary`).
    public let glyphKeyline: RGB8?

    public init(theme: RenderEnv.Theme) {
        self.theme = theme
        switch theme {
        case .dark:
            ground = Ground(base: Prim.soot900, raised: Prim.soot800, sunken: Prim.soot950)
            surface = Surface(cell: Prim.soot850, cellLit: Prim.soot750)
            stroke = Stroke(primary: Prim.bone100, secondary: Prim.bone500, hairline: Prim.bone700)
            accent = Accent(
                brass: AccentColor(Prim.brass400),
                brassPress: AccentColor(Prim.brass500),
                cold: AccentColor(Prim.cold300),
                coldPress: AccentColor(Prim.cold500)
            )
            hue = Hue(
                amber: HueColor(Prim.okabeItoAmber),
                teal: HueColor(Prim.okabeItoTeal),
                frost: HueColor(Prim.okabeItoFrost),
                rose: HueColor(Prim.okabeItoRose)
            )
            glyphKeyline = nil

        case .light:
            ground = Ground(base: Prim.paper200, raised: Prim.paper100, sunken: Prim.paper300)
            surface = Surface(cell: Prim.paper150, cellLit: Prim.paper50)
            stroke = Stroke(primary: Prim.bone900, secondary: Prim.bone450, hairline: Prim.bone200)
            accent = Accent(
                brass: AccentColor(Prim.brass600),
                brassPress: AccentColor(Prim.brass800),
                cold: AccentColor(Prim.cold700),
                coldPress: AccentColor(Prim.cold800)
            )
            hue = Hue(
                amber: HueColor(Prim.okabeItoAmber),
                teal: HueColor(Prim.okabeItoTeal),
                frost: HueColor(Prim.okabeItoFrost),
                rose: HueColor(Prim.okabeItoRose)
            )
            glyphKeyline = Prim.bone900

        case .highContrast:
            ground = Ground(
                base: Prim.neutral1000, raised: Prim.neutral900, sunken: Prim.neutral1000)
            surface = Surface(cell: Prim.neutral1000, cellLit: Prim.neutral850)
            stroke = Stroke(
                primary: Prim.neutral0, secondary: Prim.neutral400, hairline: Prim.neutral600)
            accent = Accent(
                brass: AccentColor(Prim.brass200),
                brassPress: AccentColor(Prim.brass300),
                cold: AccentColor(Prim.cold200),
                coldPress: AccentColor(Prim.cold400)
            )
            hue = Hue(
                amber: HueColor(Prim.neutral0),
                teal: HueColor(Prim.neutral0),
                frost: HueColor(Prim.neutral0),
                rose: HueColor(Prim.neutral0)
            )
            glyphKeyline = nil
        }
    }
}
