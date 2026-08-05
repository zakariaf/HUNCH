/// **L0.** Literals with no meaning. Never referenced from a view, a component or `C`;
/// only `Palette` and the L1 scales may name a `Prim`.
///
/// Naming: `<family><lightness>`, lightness ascending as the colour darkens. The step
/// numbers are ordinal, not perceptual. Trailing comments carry the measured luminance;
/// regenerate them with `scripts/contrast.swift`.
public enum Prim {
    // soot — the dark theme's grounds. Warm near-black, never pure.
    public static let soot950 = RGB8(hex: 0x05_05_04)  // L 0.0015
    public static let soot900 = RGB8(hex: 0x0B_0A_08)  // L 0.0031
    public static let soot850 = RGB8(hex: 0x10_0E_0A)  // L 0.0045
    public static let soot800 = RGB8(hex: 0x15_12_0D)  // L 0.0062
    public static let soot750 = RGB8(hex: 0x1C_18_11)  // L 0.0094

    // paper — the light theme's grounds. Warm laid paper, never white.
    public static let paper50 = RGB8(hex: 0xFD_FB_F6)  // L 0.9653
    public static let paper100 = RGB8(hex: 0xFB_F7_EE)  // L 0.9320
    public static let paper150 = RGB8(hex: 0xF7_F3_EA)  // L 0.8982
    public static let paper200 = RGB8(hex: 0xF4_EF_E4)  // L 0.8657
    public static let paper300 = RGB8(hex: 0xEB_E4_D5)  // L 0.7795

    // bone — the warm ink family, serving foreground in both themes.
    public static let bone100 = RGB8(hex: 0xEF_E3_D0)  // L 0.7784
    public static let bone200 = RGB8(hex: 0xD6_CD_BC)  // L 0.6159
    public static let bone450 = RGB8(hex: 0x6E_66_59)  // L 0.1354
    public static let bone500 = RGB8(hex: 0x6B_61_53)  // L 0.1230
    public static let bone700 = RGB8(hex: 0x3A_34_2B)  // L 0.0353
    public static let bone900 = RGB8(hex: 0x1A_17_12)  // L 0.0088

    // neutral — High Contrast only. Achromatic by construction.
    public static let neutral0 = RGB8(hex: 0xFF_FF_FF)  // L 1.0000
    public static let neutral400 = RGB8(hex: 0xB0_B0_B0)  // L 0.4342
    public static let neutral600 = RGB8(hex: 0x5A_5A_5A)  // L 0.1022
    public static let neutral850 = RGB8(hex: 0x14_14_14)  // L 0.0070
    public static let neutral900 = RGB8(hex: 0x0A_0A_0A)  // L 0.0030
    public static let neutral1000 = RGB8(hex: 0x00_00_00)  // L 0.0000

    // brass — the warm accent. Admit, the Seal, marks, streak.
    public static let brass200 = RGB8(hex: 0xFF_C2_4D)  // L 0.6038
    public static let brass300 = RGB8(hex: 0xC9_94_33)  // L 0.3384
    public static let brass400 = RGB8(hex: 0xC9_92_2F)  // L 0.3318
    public static let brass500 = RGB8(hex: 0x8A_64_20)  // L 0.1462
    public static let brass600 = RGB8(hex: 0x8A_5E_14)  // L 0.1346
    public static let brass800 = RGB8(hex: 0x5E_3F_0C)  // L 0.0596

    // cold — the sharp accent. Reject, strike, counterexample, barred.
    public static let cold200 = RGB8(hex: 0x7F_E9_FF)  // L 0.7001
    public static let cold300 = RGB8(hex: 0x7F_D8_E0)  // L 0.5901
    public static let cold400 = RGB8(hex: 0x4F_B8_CC)  // L 0.4030
    public static let cold500 = RGB8(hex: 0x4E_9A_A2)  // L 0.2734
    public static let cold700 = RGB8(hex: 0x0E_5F_72)  // L 0.0949
    public static let cold800 = RGB8(hex: 0x09_3F_4C)  // L 0.0413

    // Okabe–Ito, verbatim, in every theme. No lightness steps exist because these are
    // never re-lit (§13.2, §2). Source names are the published ones.
    public static let okabeItoAmber = RGB8(hex: 0xE6_9F_00)  // "orange"
    public static let okabeItoTeal = RGB8(hex: 0x00_9E_73)  // "bluish green"
    public static let okabeItoFrost = RGB8(hex: 0x56_B4_E9)  // "sky blue"
    public static let okabeItoRose = RGB8(hex: 0xCC_79_A7)  // "reddish purple"

    /// Canon's Dynamic Type art ceiling: art scales to AX2 and then freezes (§13.11).
    public static let artScaleCeiling = 1.35
    /// Bold Text's stroke multiplier (§13.11).
    public static let boldTextStrokeScale = 1.25
    /// High Contrast's flat stroke offset, in points (§13.11). Added, never multiplied.
    public static let highContrastStrokeOffset = 0.5
}
