import Testing

import HunchTestSupport
import Tokens

/// The accessibility gates, as arithmetic rather than as a claim.
///
/// §13.12 lists thirteen acceptance gates and two of them are contrast; `design/`'s audit
/// praised §13 for "measured contrast rather than claimed contrast", and T01 showed that was
/// only mostly true. Everything here is recomputed from the shipped hexes, so the document
/// cannot drift away from the binary without this suite failing.
@Suite("Contrast gates", .tags(.unit, .presubmission))
struct ContrastTests {
    /// WCAG 2.1: 4.5 : 1 for anything state-bearing at text size.
    static let stateBearingFloor = 4.5
    /// 3 : 1 for a large graphical object — §13.5's silhouette floor.
    static let graphicalFloor = 3.0

    @Test(
        "Every state-bearing token clears 4.5 : 1 on its own ground",
        arguments: RenderEnv.Theme.allCases)
    func stateBearingTokensClearTheFloor(_ theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        let ground = p.ground.base
        let stateBearing: [(String, RGB8)] = [
            ("stroke.primary", p.stroke.primary),
            ("accent.brass", p.accent.brass.rgb),
            ("accent.cold", p.accent.cold.rgb),
        ]
        for (name, colour) in stateBearing {
            let ratio = colour.contrastRatio(against: ground)
            #expect(ratio >= Self.stateBearingFloor, "\(theme).\(name) is \(ratio) : 1")
        }
    }

    /// `stroke.hairline` is declared NEVER state-bearing (§13.2), which is what licenses it to
    /// sit below the floor. This asserts the licence is actually needed — if hairline ever
    /// cleared 4.5 : 1 the declaration would be dead text, and if something state-bearing were
    /// spelled with it the reject ring would vanish. E20/T09's PLATE fix was exactly this bug.
    @Test("stroke.hairline sits below the floor deliberately, and is never state-bearing")
    func hairlineIsBelowTheFloorOnPurpose() {
        for theme in RenderEnv.Theme.allCases {
            let p = Palette(theme: theme)
            let ratio = p.stroke.hairline.contrastRatio(against: p.ground.base)
            #expect(ratio < Self.stateBearingFloor, "\(theme) hairline is \(ratio) : 1")
        }
    }

    @Test(
        "Every glyph hue clears the 3 : 1 graphical floor in dark",
        arguments: [RenderEnv.Theme.dark])
    func huesClearTheGraphicalFloorInDark(_ theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        for hue in p.hue.ranked {
            let ratio = hue.rgb.contrastRatio(against: p.ground.base)
            #expect(ratio >= Self.graphicalFloor, "\(theme) hue is \(ratio) : 1")
        }
    }

    /// On a light ground the raw Okabe–Ito hues fall to 1.8–2.7 : 1 and cannot carry the
    /// silhouette. §13.2's answer is a stroke.primary keyline BENEATH the hue, and this is the
    /// assertion that the keyline is genuinely required rather than decorative.
    @Test("Light theme needs the keyline: the raw hues do NOT clear 3 : 1 there")
    func lightThemeHuesRequireTheKeyline() {
        let p = Palette(theme: .light)
        for hue in p.hue.ranked {
            let ratio = hue.rgb.contrastRatio(against: p.ground.base)
            #expect(
                ratio < Self.graphicalFloor, "light hue at \(ratio) : 1 would not need a keyline")
        }
        #expect(p.glyphKeyline != nil, "light theme must define a keyline")
        // And the keyline itself carries the silhouette.
        if let keyline = p.glyphKeyline {
            #expect(keyline.contrastRatio(against: p.ground.base) >= 15)
        }
    }

    /// §13.11 states the High Contrast floor as "9.7 : 1". Measured, the binding member of
    /// the state-bearing set — `stroke.secondary` on `#B0B0B0` — is **9.683**, and
    /// `hunch-design-tokens` already documents it as 9.68. So 9.7 is a ROUNDED RESTATEMENT of
    /// the measurement, not an independent threshold the palette must clear, and asserting
    /// `>= 9.7` would fail a palette that is exactly as specified.
    ///
    /// The floor is therefore asserted at the documented 9.68, and the four measured values
    /// are pinned individually so a palette edit that moved any of them would be caught rather
    /// than absorbed by a loose inequality.
    @Test("High Contrast's state-bearing set clears its measured 9.68 floor (§13.11)")
    func highContrastFloor() {
        let p = Palette(theme: .highContrast)
        let measured: [(String, RGB8, Double)] = [
            ("stroke.primary", p.stroke.primary, 21.00),
            ("stroke.secondary", p.stroke.secondary, 9.68),
            ("accent.brass", p.accent.brass.rgb, 13.08),
            ("accent.cold", p.accent.cold.rgb, 15.00),
        ]
        for (name, colour, expected) in measured {
            let ratio = colour.contrastRatio(against: p.ground.base)
            #expect(ratio >= 9.68, "HC \(name) is \(ratio) : 1")
            #expect(abs(ratio - expected) < 0.02, "HC \(name) moved: \(ratio) vs \(expected)")
        }
    }
}
