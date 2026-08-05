public import SwiftUI

public import Tokens

extension View {
    /// Applies a resolved `TypeRole`. The one place a role becomes a `Font`, so that no view
    /// writes a literal size, weight or tracking — check 9 of the hygiene script is what makes
    /// "no view" true.
    public func typeRole(_ role: TypeRole, in env: RenderEnv) -> some View {
        let resolved = role.resolved(in: env)
        let scaled = resolved.size * env.artScale
        return
            self
            .font(
                .system(
                    size: scaled,
                    weight: resolved.weight.swiftUI,
                    design: resolved.face == .mono ? .monospaced : .default
                )
            )
            .tracking(resolved.tracking(atScaledSize: scaled))
    }
}

extension TypeRole.Weight {
    public var swiftUI: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
