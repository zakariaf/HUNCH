public import SwiftUI

internal import Tokens

/// A temporary surface that renders the token layer so it can be looked at on a device.
///
/// It is **not** a play surface — it carries text, and the play surface never may (§12.9). It
/// is deleted in E08·T01, when `RoundView` becomes the thing the app shows. Until then, the
/// alternative is an app that builds and displays nothing, which is not a check on anything.
@MainActor
public struct TokenProofView: View {
    public init() {}

    public var body: some View {
        RenderEnvReader { env in
            let palette = env.palette
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    Text("HUNCH")
                        .typeRole(.display, in: env)
                        .foregroundStyle(Color(palette.stroke.primary))

                    Text(verbatim: "\(env.theme) · art ×\(String(format: "%.2f", env.artScale))")
                        .typeRole(.numeral, in: env)
                        .foregroundStyle(Color(palette.stroke.secondary))

                    swatches(palette, env)
                    weights(env)
                }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(palette.ground.base).ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func swatches(_ palette: Palette, _ env: RenderEnv) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("HUE — Okabe–Ito, verbatim in every theme")
                .typeRole(.micro, in: env)
                .foregroundStyle(Color(palette.stroke.secondary))
            HStack(spacing: Space.s8) {
                ForEach(Array(palette.hue.ranked.enumerated()), id: \.offset) { _, hue in
                    RoundedRectangle(cornerRadius: Radius.chrome)
                        .fill(Color(hue))
                        .frame(height: 44)
                }
            }
            Text("ACCENT — never on a glyph body")
                .typeRole(.micro, in: env)
                .foregroundStyle(Color(palette.stroke.secondary))
            HStack(spacing: Space.s8) {
                RoundedRectangle(cornerRadius: Radius.chrome)
                    .fill(Color(palette.accent.brass)).frame(height: 44)
                RoundedRectangle(cornerRadius: Radius.chrome)
                    .fill(Color(palette.accent.cold)).frame(height: 44)
            }
        }
    }

    @ViewBuilder
    private func weights(_ env: RenderEnv) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("STROKE — resolved for this environment")
                .typeRole(.micro, in: env)
                .foregroundStyle(Color(env.palette.stroke.secondary))
            let ladder: [(String, StrokeWeight)] = [
                ("hairline", .hairline), ("thin", .thin), ("bodySm", .bodySm),
                ("body", .body), ("heavy", .heavy),
            ]
            ForEach(ladder, id: \.0) { name, token in
                HStack(spacing: Space.s12) {
                    Rectangle()
                        .fill(Color(env.palette.stroke.primary))
                        .frame(width: 120, height: env.weight(token))
                    Text(verbatim: "\(name)  \(String(format: "%.3f", env.weight(token)))")
                        .typeRole(.numeral, in: env)
                        .foregroundStyle(Color(env.palette.stroke.secondary))
                }
            }
        }
    }
}
