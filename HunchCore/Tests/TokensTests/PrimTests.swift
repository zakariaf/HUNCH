import Testing

import HunchTestSupport
import Tokens

/// L0 holds literals with no meaning. What is asserted here is the arithmetic every other
/// token file depends on — a wrong `relativeLuminance` curve moves every ratio in
/// `palette.md` by a few hundredths, which is exactly the size of the divergence §2 of that
/// file exists to record.
@Suite("Prim and RGB8", .tags(.unit, .presubmission))
struct PrimTests {
    @Test("init(hex:) reads a §13.2 row across without transposition")
    func hexRoundTrip() {
        let ground = RGB8(hex: 0x0B_0A_08)
        #expect(ground.red == 0x0B)
        #expect(ground.green == 0x0A)
        #expect(ground.blue == 0x08)
        #expect(ground.hex == 0x0B_0A_08)
    }

    @Test("relativeLuminance is WCAG 2.1 sRGB — the 0.04045 knee and the 2.4 exponent")
    func luminanceIsWCAG() {
        // Black and white are the two fixed points of the formula.
        #expect(RGB8(hex: 0x00_00_00).relativeLuminance == 0)
        #expect(abs(RGB8(hex: 0xFF_FF_FF).relativeLuminance - 1) < 1e-12)
        // Below the knee the curve is linear, not a power.
        let dark = RGB8(hex: 0x0A_0A_0A)
        #expect(abs(dark.relativeLuminance - 0.003_035_269_835_488_375) < 1e-9)
    }

    @Test("contrastRatio is symmetric and closed on 1.0 … 21.0")
    func contrastIsSymmetricAndBounded() {
        let black = RGB8(hex: 0x00_00_00)
        let white = RGB8(hex: 0xFF_FF_FF)
        #expect(abs(black.contrastRatio(against: white) - 21) < 1e-9)
        #expect(black.contrastRatio(against: white) == white.contrastRatio(against: black))
        #expect(black.contrastRatio(against: black) == 1)
    }

    /// The four hues are Okabe–Ito verbatim, in every theme. §2 and §13.2 forbid re-lighting
    /// them, and this is the assertion that makes "verbatim" enforceable rather than intended.
    @Test("Okabe–Ito is verbatim — no lightness steps exist because none may")
    func okabeItoIsVerbatim() {
        #expect(Prim.okabeItoAmber.hex == 0xE6_9F_00)
        #expect(Prim.okabeItoTeal.hex == 0x00_9E_73)
        #expect(Prim.okabeItoFrost.hex == 0x56_B4_E9)
        #expect(Prim.okabeItoRose.hex == 0xCC_79_A7)
    }

    /// Canon §2 claims teal and rose are "the same pixel value in greyscale". They are not —
    /// they are 8 of 255 levels apart — and GAME_DESIGN.md was corrected to say so. This
    /// freezes the real number, because the whole triple-encoding argument rests on hue NOT
    /// being recoverable from luminance.
    @Test("teal and rose are luminance-adjacent, not identical — 1.12 : 1")
    func tealAndRoseAreAdjacentNotIdentical() {
        let ratio = Prim.okabeItoTeal.contrastRatio(against: Prim.okabeItoRose)
        #expect(ratio > 1.10 && ratio < 1.14)
        #expect(Prim.okabeItoTeal.relativeLuminance < Prim.okabeItoRose.relativeLuminance)
    }

    /// The measured correction to §13.2's stated ratios, frozen so it cannot drift back.
    @Test("The four corrected §13.2 ratios against the dark ground")
    func correctedCanonRatios() {
        let ground = Prim.soot900
        #expect(abs(Prim.okabeItoAmber.contrastRatio(against: ground) - 8.79) < 0.02)
        #expect(abs(Prim.okabeItoTeal.contrastRatio(against: ground) - 5.78) < 0.02)
        #expect(abs(Prim.okabeItoFrost.contrastRatio(against: ground) - 8.58) < 0.02)
        #expect(abs(Prim.okabeItoRose.contrastRatio(against: ground) - 6.47) < 0.02)
    }

    /// §13.2 claims amber and brass sit 1.36 : 1 apart. Measured, it is 1.22 : 1 — close
    /// enough that luminance carries none of the distinction, which is why the registers are
    /// separate Swift types rather than a convention.
    @Test("hue.amber and accent.brass are 1.22 : 1 apart — register segregation carries it")
    func amberAndBrassAreCloserThanCanonClaimed() {
        let ratio = Prim.okabeItoAmber.contrastRatio(against: Prim.brass400)
        #expect(ratio > 1.20 && ratio < 1.25)
    }

    @Test("The three environment constants are §13.11's")
    func environmentConstants() {
        #expect(Prim.artScaleCeiling == 1.35)
        #expect(Prim.boldTextStrokeScale == 1.25)
        #expect(Prim.highContrastStrokeOffset == 0.5)
    }
}
