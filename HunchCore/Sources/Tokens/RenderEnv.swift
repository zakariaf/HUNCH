/// The seven axes every token resolves against. Hunch's tokens are not constants:
/// High Contrast rewrites hues, Bold Text scales strokes, Reduce Transparency kills
/// bloom, Dynamic Type scales art. A scheme that models variation as "modes" loses
/// four of these seven.
///
/// Injected, never global (`04 A29`): the composition root builds one and passes it down.
public struct RenderEnv: Hashable, Sendable {
    public enum Theme: String, CaseIterable, Hashable, Sendable, Codable {
        case dark, light, highContrast
    }

    public var theme: Theme
    public var isReduceMotionEnabled: Bool
    public var isReduceTransparencyEnabled: Bool
    public var isBoldTextEnabled: Bool
    public var isDifferentiateWithoutColorEnabled: Bool
    public var isLowPowerModeEnabled: Bool
    /// The system's Dynamic Type multiplier, unclamped. Read `artScale` to draw with it.
    public var typeMultiplier: Double

    public init(
        theme: Theme = .dark,
        isReduceMotionEnabled: Bool = false,
        isReduceTransparencyEnabled: Bool = false,
        isBoldTextEnabled: Bool = false,
        isDifferentiateWithoutColorEnabled: Bool = false,
        isLowPowerModeEnabled: Bool = false,
        typeMultiplier: Double = 1.0
    ) {
        self.theme = theme
        self.isReduceMotionEnabled = isReduceMotionEnabled
        self.isReduceTransparencyEnabled = isReduceTransparencyEnabled
        self.isBoldTextEnabled = isBoldTextEnabled
        self.isDifferentiateWithoutColorEnabled = isDifferentiateWithoutColorEnabled
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.typeMultiplier = typeMultiplier
    }
}

extension RenderEnv {
    /// Dynamic Type scales **art**, never stroke weight, and freezes at AX2 (§13.11).
    /// Weight has its own axis (Bold Text); multiplying it here would compound them.
    public var artScale: Double { min(max(typeMultiplier, 1.0), Prim.artScaleCeiling) }

    public var palette: Palette { Palette(theme: theme) }

    /// The resolved stroke weight, in points. The only resolution order in the app.
    public func weight(_ token: StrokeWeight) -> Double { token.resolved(in: self) }

    /// The resolved type role: Bold Text steps the font weight one notch.
    public func type(_ role: TypeRole) -> TypeRole { role.resolved(in: self) }

    /// Pass B, the widened low-opacity stroke. The `S >= 32` gate is geometry and
    /// belongs to the glyph renderer; this is the environment half only.
    public var isBloomEnabled: Bool {
        !isReduceTransparencyEnabled && theme != .highContrast && !isLowPowerModeEnabled
    }

    /// Pass A, the blurred bed. **Dark only** — a blurred bright mark on a light ground
    /// reads as a printing fault, not as light. The light theme gets depth from the
    /// impression, not from a bloom.
    public var isBloomBedEnabled: Bool { isBloomEnabled && theme == .dark }

    /// §13.6's `amt`.
    public var isShaderEnabled: Bool {
        !isReduceTransparencyEnabled && theme != .highContrast && !isLowPowerModeEnabled
    }

    /// The scanline term. **Dark only** — paper has no scanline.
    public var isScanlineEnabled: Bool { isShaderEnabled && theme == .dark }

    /// §13.6's `t`, frozen at 0 under Reduce Motion: static grain, no shimmer.
    public var isShaderTimeFrozen: Bool { isReduceMotionEnabled }

    /// The depth model. Dark separates panels by a ground step **and** a hairline;
    /// light separates them by an **impression**, because a 1.03–1.10 : 1 ground step is
    /// at or below the visible threshold under glare and is erased by auto-dimming.
    /// Shadows, elevation and `.ultraThinMaterial` remain forbidden in both.
    public var isImpressionDepthEnabled: Bool { theme == .light }
}
