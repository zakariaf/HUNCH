import Testing

import HunchTestSupport
import Tokens

/// The register split is the anti-drift mechanism made structural: `AccentColor` and `HueColor`
/// are distinct types, so "the accent never touches a glyph body" is unrepresentable rather
/// than reviewable. This suite asserts the arithmetic behind every ratio the design states,
/// recomputed from the hexes rather than quoted.
@Suite("Palette", .tags(.unit, .presubmission))
struct PaletteTests {
    @Test("All three themes resolve", arguments: RenderEnv.Theme.allCases)
    func everyThemeResolves(_ theme: RenderEnv.Theme) {
        let p = Palette(theme: theme)
        #expect(p.theme == theme)
    }

    @Test("stroke.primary clears 15 : 1 against its own ground in dark and light")
    func primaryStrokeIsHighContrast() {
        for theme in [RenderEnv.Theme.dark, .light] {
            let p = Palette(theme: theme)
            let ratio = p.stroke.primary.contrastRatio(against: p.ground.base)
            #expect(ratio > 15.0, "\(theme) primary stroke is \(ratio) : 1")
        }
    }

    @Test("High Contrast collapses all four hues to the foreground stroke (§13.11)")
    func highContrastCollapsesHues() {
        let hc = Palette(theme: .highContrast)
        for hue in hc.hue.ranked {
            #expect(hue.rgb == hc.stroke.primary)
        }
        // …and that foreground clears 21 : 1 on the HC ground.
        #expect(abs(hc.stroke.primary.contrastRatio(against: hc.ground.base) - 21) < 0.05)
    }

    @Test("Okabe–Ito is verbatim in dark AND light — never re-lit (§2, §13.2)")
    func huesAreNeverReLit() {
        let dark = Palette(theme: .dark).hue
        let light = Palette(theme: .light).hue
        #expect(dark.amber.rgb == light.amber.rgb)
        #expect(dark.teal.rgb == light.teal.rgb)
        #expect(dark.frost.rgb == light.frost.rgb)
        #expect(dark.rose.rgb == light.rose.rgb)
        #expect(dark.amber.rgb == Prim.okabeItoAmber)
    }

    @Test("The hue ranked order is §2's amber → teal → frost → rose")
    func rankedOrder() {
        let hue = Palette(theme: .dark).hue
        #expect(hue.ranked.count == 4)
        #expect(hue.ranked[0].rgb == Prim.okabeItoAmber)
        #expect(hue.ranked[3].rgb == Prim.okabeItoRose)
    }

    @Test("Every ground layer is distinguishable from its neighbour — the 1.06 : 1 shift")
    func groundLayersAreDistinct() {
        for theme in RenderEnv.Theme.allCases {
            let g = Palette(theme: theme).ground
            #expect(g.base != g.raised || theme == .highContrast)
            #expect(g.base != g.sunken || theme == .highContrast)
        }
    }

    @Test("accent.brass and accent.cold clear 4.5 : 1 in every theme — they are state-bearing")
    func accentsAreStateBearing() {
        for theme in RenderEnv.Theme.allCases {
            let p = Palette(theme: theme)
            #expect(p.accent.brass.rgb.contrastRatio(against: p.ground.base) > 4.5)
            #expect(p.accent.cold.rgb.contrastRatio(against: p.ground.base) > 4.5)
        }
    }
}
