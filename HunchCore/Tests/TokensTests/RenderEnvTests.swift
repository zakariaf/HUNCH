import Foundation
import Testing

import HunchTestSupport
import Tokens

/// The GDD never states the environment resolution order, and Bold Text (×1.25) and High
/// Contrast (+0.5 pt) can both be on. hunch-design-tokens rules it Select → Scale → Offset →
/// Derive, giving 3.0 × 1.25 + 0.5 = 4.25 and NOT (3.0 + 0.5) × 1.25 = 4.375. This suite is
/// what makes that ruling enforceable.
@Suite("RenderEnv resolution order", .tags(.unit, .presubmission))
struct RenderEnvTests {
    @Test("Bold Text scales, High Contrast offsets, and the offset is never scaled")
    func resolutionOrderIsScaleThenOffset() {
        let plain = RenderEnv(theme: .dark)
        let bold = RenderEnv(theme: .dark, isBoldTextEnabled: true)
        let hc = RenderEnv(theme: .highContrast)
        let both = RenderEnv(theme: .highContrast, isBoldTextEnabled: true)

        #expect(plain.weight(.body) == 3.0)
        #expect(bold.weight(.body) == 3.0 * 1.25)
        #expect(hc.weight(.body) == 3.0 + 0.5)
        // The ruling, in one assertion.
        #expect(both.weight(.body) == 4.25)
        #expect(both.weight(.body) != 4.375)
    }

    @Test("The weight ladder stays strictly increasing under both settings")
    func ladderStaysMonotone() {
        for env in [
            RenderEnv(theme: .dark),
            RenderEnv(theme: .dark, isBoldTextEnabled: true),
            RenderEnv(theme: .highContrast),
            RenderEnv(theme: .highContrast, isBoldTextEnabled: true),
        ] {
            let ladder = [
                env.weight(.hairline), env.weight(.thin), env.weight(.bodySm),
                env.weight(.body), env.weight(.heavy),
            ]
            #expect(ladder == ladder.sorted())
            #expect(Set(ladder).count == ladder.count, "weights must stay distinguishable")
        }
    }

    @Test("artScale clamps to §13.11's 1.35 ceiling and never below 1.0")
    func artScaleIsClamped() {
        #expect(RenderEnv(theme: .dark, typeMultiplier: 0.8).artScale == 1.0)
        #expect(RenderEnv(theme: .dark, typeMultiplier: 1.2).artScale == 1.2)
        #expect(RenderEnv(theme: .dark, typeMultiplier: 3.0).artScale == 1.35)
    }

    @Test("Bloom is off under Reduce Transparency and under High Contrast (§13.5)")
    func bloomRespectsAccessibility() {
        #expect(RenderEnv(theme: .dark).isBloomEnabled)
        #expect(!RenderEnv(theme: .dark, isReduceTransparencyEnabled: true).isBloomEnabled)
        #expect(!RenderEnv(theme: .highContrast).isBloomEnabled)
    }

    @Test("The scanline is dark-only; grain and vignette are not (§13.6)")
    func scanlineIsDarkOnly() {
        #expect(RenderEnv(theme: .dark).isScanlineEnabled)
        #expect(!RenderEnv(theme: .light).isScanlineEnabled)
        #expect(!RenderEnv(theme: .highContrast).isShaderEnabled)
    }

    @Test("Reduce Motion freezes shader time rather than disabling the shader")
    func reduceMotionFreezesTime() {
        let env = RenderEnv(theme: .dark, isReduceMotionEnabled: true)
        #expect(env.isShaderTimeFrozen)
        #expect(env.isShaderEnabled)
    }

    @Test("Theme is Codable — it is persisted; colours never are")
    func themeIsCodable() throws {
        for theme in RenderEnv.Theme.allCases {
            let data = try JSONEncoder().encode(theme)
            #expect(try JSONDecoder().decode(RenderEnv.Theme.self, from: data) == theme)
        }
    }
}
