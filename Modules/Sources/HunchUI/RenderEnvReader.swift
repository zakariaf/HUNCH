public import SwiftUI

public import Tokens

/// Builds a `RenderEnv` from SwiftUI's environment.
///
/// `RenderEnv` is injected, never global (04 A29) — but its seven axes come from seven
/// different `@Environment` keys, and reading them in each view would be seven chances to
/// forget one. This reads them in one place and hands the value down.
@MainActor
public struct RenderEnvReader<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let themeOverride: RenderEnv.Theme?
    private let content: (RenderEnv) -> Content

    public init(
        themeOverride: RenderEnv.Theme? = nil,
        @ViewBuilder content: @escaping (RenderEnv) -> Content
    ) {
        self.themeOverride = themeOverride
        self.content = content
    }

    public var body: some View {
        content(
            RenderEnv(
                theme: themeOverride ?? (colorScheme == .dark ? .dark : .light),
                isReduceMotionEnabled: reduceMotion,
                isReduceTransparencyEnabled: reduceTransparency,
                isBoldTextEnabled: legibilityWeight == .bold,
                isDifferentiateWithoutColorEnabled: differentiateWithoutColor,
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                typeMultiplier: Self.multiplier(for: dynamicTypeSize)
            )
        )
    }

    /// `DynamicTypeSize` is an ordinal enum with no published scale factor, so the mapping is
    /// stated here rather than guessed at a call site. It saturates at AX2, which is where
    /// §13.11 freezes art scaling anyway.
    static func multiplier(for size: DynamicTypeSize) -> Double {
        switch size {
        case .xSmall: 0.85
        case .small: 0.90
        case .medium: 0.95
        case .large: 1.00
        case .xLarge: 1.06
        case .xxLarge: 1.12
        case .xxxLarge: 1.20
        case .accessibility1: 1.30
        default: 1.35  // AX2…AX5 — §13.11's ceiling
        }
    }
}
