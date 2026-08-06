public import SwiftUI

public import Glyphs
public import HunchNavigation
public import HunchUI
public import Persistence
public import Tokens

/// §12.4's Frame — **a mode is chosen with zero text.**
///
/// Every interactive target sits at y ≥ 300, inside the right-thumb comfort arc. The Settings
/// and Anomaly keys at the top are the two exceptions and are both non-urgent; the idle Loom
/// between them is scenery, not a control, and sits above the arc deliberately.
///
/// First launch never shows this screen (§12.5): a menu is a text-shaped object, and the first
/// thing a new player must meet is the machine.
@MainActor
public struct FrameView: View {

    public struct Availability: Equatable, Sendable {
        public var pages: Int
        public var highestPageBand: Int
        public var suspended: Set<Mode>

        public init(pages: Int = 0, highestPageBand: Int = 0, suspended: Set<Mode> = []) {
            self.pages = pages
            self.highestPageBand = highestPageBand
            self.suspended = suspended
        }
    }

    public var availability: Availability
    public var env: RenderEnv
    public var onPlay: (Mode) -> Void
    public var onSettings: () -> Void
    public var onAnomaly: () -> Void
    public var onCodex: () -> Void
    public var onProfile: () -> Void

    public init(
        availability: Availability,
        env: RenderEnv,
        onPlay: @escaping (Mode) -> Void = { _ in },
        onSettings: @escaping () -> Void = {},
        onAnomaly: @escaping () -> Void = {},
        onCodex: @escaping () -> Void = {},
        onProfile: @escaping () -> Void = {}
    ) {
        self.availability = availability
        self.env = env
        self.onPlay = onPlay
        self.onSettings = onSettings
        self.onAnomaly = onAnomaly
        self.onCodex = onCodex
        self.onProfile = onProfile
    }

    /// §12.4's order: PROBE · DRIFT / ECHO · SIEVE. Not by unlock order and not by difficulty —
    /// by the order the modes were introduced, which is the order the player met them.
    public nonisolated static let rackOrder: [Mode] = [.probe, .drift, .echo, .sieve]

    public var body: some View {
        VStack(spacing: 0) {
            InstrumentBar {
                Button(action: onSettings) { KeyGlyph(env: env) }
                    .buttonStyle(.plain)
                    .frame(width: Space.s44, height: Space.s44)
                    .contentShape(.rect)
            } centre: {
                Color.clear
            } trailing: {
                Button(action: onAnomaly) { KeyGlyph(env: env) }
                    .buttonStyle(.plain)
                    .frame(width: Space.s44, height: Space.s44)
                    .contentShape(.rect)
            }

            IdleLoom(env: env)
                .frame(height: 216)
                .padding(.top, Space.s8)

            Spacer(minLength: Space.s12)

            // The rack. 2 × 2, because four modes in a column is a list and a list is a menu.
            Grid(horizontalSpacing: Space.s12, verticalSpacing: Space.s12) {
                GridRow {
                    rackKey(.probe)
                    rackKey(.drift)
                }
                GridRow {
                    rackKey(.echo)
                    rackKey(.sieve)
                }
            }
            .padding(.horizontal, 13.5)

            Spacer(minLength: Space.s12)

            HStack(spacing: Space.s12) {
                shelfKey(action: onCodex)
                shelfKey(action: onProfile)
            }
            .padding(.horizontal, 13.5)
            .padding(.bottom, Space.s44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(env.palette.ground.base).ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func rackKey(_ mode: Mode) -> some View {
        let unlocked = ModeGate.isUnlocked(
            mode, pages: availability.pages, highestPageBand: availability.highestPageBand)
        Button {
            if unlocked { onPlay(mode) }
        } label: {
            ModeKeyFace(
                mode: mode, env: env, isUnlocked: unlocked,
                isSuspended: availability.suspended.contains(mode))
        }
        .buttonStyle(.plain)
        .frame(width: 168, height: 108)
        .contentShape(.rect)
        .disabled(!unlocked)
        .accessibilityAddTraits(unlocked ? [] : .isSelected)
    }

    @ViewBuilder
    private func shelfKey(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Radius.chrome)
                .strokeBorder(
                    Color(env.palette.stroke.secondary), lineWidth: env.weight(.thin))
        }
        .buttonStyle(.plain)
        .frame(width: 168, height: 52)
        .contentShape(.rect)
    }
}

/// §12.4's mode sigil plus its key state. **All readable without colour**: a barred key wears the
/// identical machined bar as the barred Seal, and a suspended one wears an arc filled to its own
/// progress — reuse over invention, both times.
@MainActor
struct ModeKeyFace: View {
    let mode: Mode
    let env: RenderEnv
    let isUnlocked: Bool
    let isSuspended: Bool

    var body: some View {
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            context.stroke(
                Path(roundedRect: box, cornerRadius: Radius.chrome),
                with: .color(env.palette.stroke.secondary.color),
                lineWidth: env.weight(.thin))

            var sigilContext = context
            sigilContext.opacity = isUnlocked ? 1 : Opacity.disabled
            ModeSigil.draw(mode: mode, into: sigilContext, box: box, env: env)

            if !isUnlocked {
                // The same drawing as the barred Seal. The bar idiom carries the whole message
                // and there is no text explaining it.
                MachinedBar.draw(
                    into: context,
                    key: CGRect(
                        x: box.minX, y: box.midY - 2, width: box.width, height: 4), env: env)
            }
        }
    }
}

/// §12.4's four sigils, each **built only from idioms the player has already met**.
enum ModeSigil {
    @MainActor
    static func draw(mode: Mode, into context: GraphicsContext, box: CGRect, env: RenderEnv) {
        let ink = GraphicsContext.Shading.color(env.palette.stroke.primary.color)
        let style = StrokeStyle(lineWidth: env.weight(.body), lineCap: .round)
        let radius = min(box.width, box.height) * 0.22
        let centre = CGPoint(x: box.midX, y: box.midY)

        switch mode {
        case .probe:
            // One stroke entering a ring — the throat.
            context.stroke(ring(at: centre, radius: radius), with: ink, style: style)
            var stroke = Path()
            stroke.move(to: CGPoint(x: centre.x - radius * 2.2, y: centre.y))
            stroke.addLine(to: CGPoint(x: centre.x - radius * 0.4, y: centre.y))
            context.stroke(stroke, with: ink, style: style)

        case .drift:
            // Two offset law-plates, the trailing one ghost-framed — the `prev` marker.
            let plate = CGRect(
                x: centre.x - radius * 1.6, y: centre.y - radius, width: radius * 1.8,
                height: radius * 2)
            context.stroke(Path(plate), with: ink, style: style)
            GhostFrame.draw(
                into: context, box: plate.offsetBy(dx: radius * 1.2, dy: radius * 0.5),
                role: .marker, env: env)

        case .echo:
            // A ring trailing three decaying concentric arcs — the ribbon's link arc.
            context.stroke(ring(at: centre, radius: radius), with: ink, style: style)
            for step in 1...3 {
                var trailing = context
                trailing.opacity = 1 - Double(step) * 0.25
                trailing.stroke(
                    ring(at: centre, radius: radius * (1 + 0.35 * Double(step))), with: ink,
                    style: StrokeStyle(lineWidth: env.weight(.hairline)))
            }

        case .sieve:
            // Three strokes falling through a slotted grate, one caught.
            var grate = Path()
            for column in 0..<4 {
                let x = box.minX + box.width * (0.34 + 0.11 * Double(column))
                grate.move(to: CGPoint(x: x, y: centre.y))
                grate.addLine(to: CGPoint(x: x + radius * 0.5, y: centre.y))
            }
            context.stroke(grate, with: ink, style: style)
            for column in 0..<3 {
                let x = box.minX + box.width * (0.38 + 0.11 * Double(column))
                var fall = Path()
                let caught = column == 1
                fall.move(to: CGPoint(x: x, y: centre.y - radius * 1.4))
                fall.addLine(to: CGPoint(x: x, y: caught ? centre.y - 2 : centre.y + radius))
                context.stroke(fall, with: ink, style: style)
            }
        }
    }

    private static func ring(at centre: CGPoint, radius: Double) -> Path {
        Path(
            ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius, width: radius * 2,
                height: radius * 2))
    }
}

/// §12.4's idle Loom: one glyph drifting through a 128 pt throat ring. **Non-interactive by
/// design** — it sits above the thumb arc and is scenery, not a control.
@MainActor
struct IdleLoom: View {
    let env: RenderEnv

    var body: some View {
        Canvas { context, size in
            var context = context
            let side = 128.0
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: centre.x - side / 2, y: centre.y - side / 2, width: side,
                        height: side)),
                with: .color(env.palette.stroke.secondary.color),
                lineWidth: env.weight(.hairline))
            // The glyph itself is `HunchUI`'s to draw; the Frame only says where.
            GlyphCanvasView.draw(
                glyph: Deck.glyph(id: 22), side: 72, into: &context, canvas: size, env: env)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
struct KeyGlyph: View {
    let env: RenderEnv

    var body: some View {
        Canvas { context, size in
            let box = CGRect(origin: .zero, size: size).insetBy(dx: 12, dy: 12)
            context.stroke(
                Path(ellipseIn: box), with: .color(env.palette.stroke.secondary.color),
                lineWidth: env.weight(.thin))
        }
    }
}
