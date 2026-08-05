public import SwiftUI

internal import Glyphs
internal import Tokens

/// A temporary surface that renders the deck so it can be looked at on a device.
///
/// It is **not** a play surface — it carries text, and the play surface never may (§12.9). It
/// is deleted in E08·T01, when `RoundView` becomes the thing the app shows.
@MainActor
public struct TokenProofView: View {
    @State private var greyscale = false

    public init() {}

    public var body: some View {
        RenderEnvReader { env in
            let palette = env.palette
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    header(env)
                    channelLadders(env)
                    deck(env)
                }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(palette.ground.base).ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func header(_ env: RenderEnv) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("HUNCH")
                .typeRole(.display, in: env)
                .foregroundStyle(Color(env.palette.stroke.primary))
            Text(verbatim: "\(env.theme) · 256 glyphs")
                .typeRole(.numeral, in: env)
                .foregroundStyle(Color(env.palette.stroke.secondary))
            Toggle("Greyscale", isOn: $greyscale)
                .typeRole(.micro, in: env)
                .foregroundStyle(Color(env.palette.stroke.secondary))
                .tint(Color(env.palette.accent.brass))
        }
    }

    /// One row per channel, three attributes pinned and one moving — the only layout that
    /// isolates a channel (§13.5.1).
    @ViewBuilder
    private func channelLadders(_ env: RenderEnv) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            ladder(
                "FILL", env,
                Glyph.Fill.allCases.map {
                    Glyph(fill: $0, shape: .hexagon, pips: .three, hue: .amber)
                })
            ladder(
                "SHAPE", env,
                Glyph.Shape.allCases.map {
                    Glyph(fill: .hollow, shape: $0, pips: .three, hue: .teal)
                })
            ladder(
                "PIPS", env,
                Glyph.Pips.allCases.map {
                    Glyph(fill: .hollow, shape: .circle, pips: $0, hue: .frost)
                })
            ladder(
                "HUE — index stroke 0°/45°/90°/135°", env,
                Glyph.Hue.allCases.map {
                    Glyph(fill: .striped, shape: .triangle, pips: .two, hue: $0)
                })
        }
    }

    @ViewBuilder
    private func ladder(_ title: String, _ env: RenderEnv, _ glyphs: [Glyph]) -> some View {
        Text(title)
            .typeRole(.micro, in: env)
            .foregroundStyle(Color(env.palette.stroke.secondary))
        HStack(spacing: Space.s8) {
            ForEach(glyphs, id: \.id) { GlyphCanvasView(glyph: $0, side: 56, env: env) }
            Spacer()
        }
        .grayscale(greyscale ? 1 : 0)
    }

    @ViewBuilder
    private func deck(_ env: RenderEnv) -> some View {
        Text("THE DECK — all 256")
            .typeRole(.micro, in: env)
            .foregroundStyle(Color(env.palette.stroke.secondary))
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8),
            spacing: 2
        ) {
            ForEach(Deck.all, id: \.id) { GlyphCanvasView(glyph: $0, side: 40, env: env) }
        }
        .grayscale(greyscale ? 1 : 0)
    }
}
