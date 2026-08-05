import Testing

import HunchTestSupport
import Tokens

/// L2 is where the resolution order's fourth stage — Derive — actually lands. The keyline and
/// the halo are geometric relationships computed from the ALREADY-RESOLVED weight, so they
/// must never themselves be scaled or offset a second time. That is the whole content of this
/// suite, and it is the mistake that would otherwise be invisible.
@Suite("C — L2 component tokens", .tags(.unit, .presubmission))
struct ComponentTokenTests {
    @Test("The size regime is a rule, not a token: 48 pt is the boundary (§13.5)")
    func sizeRegimeBoundary() {
        let env = RenderEnv(theme: .dark)
        #expect(C.Glyph.bodyStroke(side: 44, in: env) == env.weight(.bodySm))
        #expect(C.Glyph.bodyStroke(side: 48, in: env) == env.weight(.body))
        #expect(C.Glyph.bodyStroke(side: 96, in: env) == env.weight(.body))
    }

    @Test("The keyline is derived from the resolved weight, never re-scaled")
    func keylineIsDerivedLast() {
        let light = RenderEnv(theme: .light)
        let boldLight = RenderEnv(theme: .light, isBoldTextEnabled: true)

        // +1.0 so the keyline shows 0.5 pt on each side of the hue.
        #expect(C.Glyph.keylineStroke(side: 96, in: light) == light.weight(.body) + 1.0)
        // Under Bold Text the BODY scales; the +1.0 does not become +1.25.
        #expect(C.Glyph.keylineStroke(side: 96, in: boldLight) == boldLight.weight(.body) + 1.0)
        #expect(C.Glyph.keylineStroke(side: 96, in: boldLight) == 3.0 * 1.25 + 1.0)
    }

    @Test("Dark needs no keyline — its worst hue already clears 5.78 : 1")
    func darkHasNoKeyline() {
        #expect(C.Glyph.keylineStroke(side: 96, in: RenderEnv(theme: .dark)) == nil)
    }

    @Test("The halo is ×3 of the resolved stroke (§13.5), derived last")
    func haloIsDerivedLast() {
        let env = RenderEnv(theme: .dark)
        #expect(C.Glyph.haloStroke(side: 96, in: env) == env.weight(.body) * 3)
        let bold = RenderEnv(theme: .dark, isBoldTextEnabled: true)
        #expect(C.Glyph.haloStroke(side: 96, in: bold) == 3.0 * 1.25 * 3)
    }
}
