/// **L1 weight.** `base` is the value at Large with no accessibility setting on;
/// `respondsToBoldText` travels with the token because §13.11 scopes Bold Text by
/// *token*, not by call site, and the same token must not behave two ways at two sites.
public struct StrokeWeight: Hashable, Sendable {
    public let base: Double
    public let respondsToBoldText: Bool

    public init(base: Double, respondsToBoldText: Bool = true) {
        self.base = base
        self.respondsToBoldText = respondsToBoldText
    }

    /// **The resolution order. Multiply, then offset — never the reverse.**
    ///
    /// `body` with Bold Text and High Contrast both on is `3.0 × 1.25 + 0.5 = 4.25`,
    /// not `(3.0 + 0.5) × 1.25 = 4.375`. §13.11 gives Bold Text a multiplicative
    /// spelling with worked values that must hold (`hairline` 0.5 → 0.625) and High
    /// Contrast a flat `+0.5 pt`; a flat offset that also got multiplied would
    /// silently become `+0.625` and the two settings would stop being independent.
    public func resolved(in env: RenderEnv) -> Double {
        let scaled =
            base * (env.isBoldTextEnabled && respondsToBoldText ? Prim.boldTextStrokeScale : 1)
        return scaled + (env.theme == .highContrast ? Prim.highContrastStrokeOffset : 0)
    }
}

extension StrokeWeight {
    public static let hairline = StrokeWeight(base: 0.5)
    public static let thin = StrokeWeight(base: 1.0)
    public static let bodySm = StrokeWeight(base: 1.5)
    public static let body = StrokeWeight(base: 3.0)
    public static let heavy = StrokeWeight(base: 4.0)
}
