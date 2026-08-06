public import SwiftUI

public import Tokens

/// The pull-up handle (§6.7).
///
/// Handle tap, handle drag and the Bench key are **equivalent**, and the handle is exposed to
/// VoiceOver as a button so the drag is never required. `acceptsTap` is therefore unconditional
/// and not a Reduce Motion concession: a control whose only route is a drag is a control
/// VoiceOver cannot operate, and §4.2 rules drag out of the declaration UI entirely.
@MainActor
public struct BenchHandleView: View {
    public var env: RenderEnv
    public var isOpen: Bool
    public var onToggle: () -> Void
    public var onDrag: (Double) -> Void
    public var onDragEnded: (Double, Double) -> Void

    public init(
        env: RenderEnv,
        isOpen: Bool,
        onToggle: @escaping () -> Void = {},
        onDrag: @escaping (Double) -> Void = { _ in },
        onDragEnded: @escaping (Double, Double) -> Void = { _, _ in }
    ) {
        self.env = env
        self.isOpen = isOpen
        self.onToggle = onToggle
        self.onDrag = onDrag
        self.onDragEnded = onDragEnded
    }

    public var body: some View {
        Button(action: onToggle) {
            Canvas { context, size in
                let width = size.width * 0.24
                let box = CGRect(
                    x: (size.width - width) / 2, y: size.height / 2 - 2, width: width, height: 4)
                MachinedBar.draw(into: context, key: box, env: env)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Space.targetMin)
        .contentShape(.rect)
        .gesture(
            BenchDrawer.affordance(reduceMotion: env.isReduceMotionEnabled) == .drag
                ? DragGesture()
                    .onChanged { onDrag($0.translation.height) }
                    .onEnded {
                        onDragEnded($0.translation.height, $0.predictedEndTranslation.height)
                    }
                : nil
        )
        .accessibilityAddTraits(.isButton)
    }
}

/// §4.2's palette: four tile stamps, 68 × 44, one per tile class.
@MainActor
public struct PaletteView: View {
    public var env: RenderEnv
    public var isEnabled: Bool
    public var onStamp: (Int) -> Void

    public init(
        env: RenderEnv, isEnabled: Bool = true, onStamp: @escaping (Int) -> Void = { _ in }
    ) {
        self.env = env
        self.isEnabled = isEnabled
        self.onStamp = onStamp
    }

    public var body: some View {
        HStack(spacing: Space.s8) {
            ForEach(0..<4, id: \.self) { index in
                Button {
                    onStamp(index)
                } label: {
                    Canvas { context, size in
                        let box = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                        context.stroke(
                            Path(roundedRect: box, cornerRadius: Radius.chrome),
                            with: .color(env.palette.stroke.secondary.color),
                            lineWidth: env.weight(.thin))
                    }
                }
                .buttonStyle(.plain)
                .frame(
                    width: C.Key.paletteStamp.width, height: C.Key.paletteStamp.height
                )
                .contentShape(.rect)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : Opacity.disabled)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}
