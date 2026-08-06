public import SwiftUI

public import Tokens

/// One key face in the commit bar: **PROBE** · **twin** · **Bench** (§4.1).
///
/// A key is a shape and a press state and nothing else — no text in any locale (§12.9), and no
/// badge, arrow or count. The breath is the one exception the design allows and it is *only* an
/// opacity event: a hinting control never gains a second affordance.
@MainActor
public struct CommitKey<Face: View>: View {

    /// §6.6 layer 3's two presentations. A value rather than an `if` scattered through a body,
    /// so the Reduce Motion substitution cannot be forgotten at one of the sites.
    public enum BreathPresentation: Hashable, Sendable {
        /// A 1.2 s hairline pulse every 8 s.
        case pulse
        /// A static 30 % opacity lift — Reduce Motion (§13.7.4).
        case staticLift
        case none

        public init(isBreathing: Bool, reduceMotion: Bool) {
            self = isBreathing ? (reduceMotion ? .staticLift : .pulse) : .none
        }
    }

    public var env: RenderEnv
    public var breath: BreathPresentation
    public var isEnabled: Bool
    public var action: () -> Void
    private let face: Face

    public init(
        env: RenderEnv,
        breath: BreathPresentation = .none,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder face: () -> Face
    ) {
        self.env = env
        self.breath = breath
        self.isEnabled = isEnabled
        self.action = action
        self.face = face()
    }

    @State private var isPulsing = false

    public var body: some View {
        Button(action: action) {
            face
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.chrome)
                        .strokeBorder(
                            Color(env.palette.stroke.secondary),
                            lineWidth: env.weight(.thin)
                        )
                        .opacity(breathOpacity)
                }
        }
        .buttonStyle(.plain)
        // A floor **and** a ceiling: `minHeight` alone lets a key grow past the commit bar's
        // own region, which puts a 44 pt target inside a 54 pt row and draws a 69 pt border
        // over the Bench handle above it.
        .frame(
            minWidth: Space.targetMin, maxWidth: .infinity,
            minHeight: Space.targetMin, maxHeight: .infinity
        )
        .contentShape(.rect)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Opacity.disabled)
        .task(id: breath) {
            isPulsing = breath == .pulse
        }
        .animation(
            breath == .pulse
                ? .easeInOut(duration: C.TwinKey.breathPulse.seconds)
                    .repeatForever(autoreverses: true)
                : nil,
            value: isPulsing)
    }

    private var breathOpacity: Double {
        switch breath {
        case .none: 1
        case .staticLift: 1 + C.TwinKey.breathStaticLift
        case .pulse: isPulsing ? 1 : 1 - C.TwinKey.breathStaticLift
        }
    }
}
