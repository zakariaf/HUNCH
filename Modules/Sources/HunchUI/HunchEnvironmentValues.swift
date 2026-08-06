public import SwiftUI

// `StoreHealth` is E07's and lives in `Persistence`. Declaring a second one here — even an
// identical one — would give the store's own opinion of its health and the chrome's a way to
// disagree, which is the one thing §11.13's hairline exists to report.
public import Persistence
public import Tokens

extension EnvironmentValues {
    /// Dynamic Type's art scale, capped at 1.35.
    @Entry public var glyphScale: CGFloat = 1.0
    /// The **resolved** theme — the Settings choice already resolved against
    /// `isDarkerSystemColorsEnabled` (§12.6) — not the Settings row itself.
    @Entry public var theme: RenderEnv.Theme = .dark
    /// §11.13's disk state, driving a hairline strip in the **chrome** — never on the play
    /// surface, which has no way to say "your last write failed" without text.
    @Entry public var storeHealth: StoreHealth = .healthy
}
