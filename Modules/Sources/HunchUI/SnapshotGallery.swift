#if DEBUG
    public import SwiftUI

    internal import Glyphs
    internal import Tokens

    /// The visual-regression corpus: every component × its states × three themes, plus
    /// greyscale. DEBUG-only, so it costs the shipped binary nothing.
    ///
    /// Its job is comparability over time — a Bridge drawn differently six months from now
    /// changes a snapshot here. It is the answer to the design audit's finding that §13 had
    /// never been *rendered*, only specified.
    @MainActor
    public struct SnapshotGallery: View {
        @State private var theme: RenderEnv.Theme = .dark
        @State private var greyscale = false
        @State private var boldText = false

        public init() {}

        public var body: some View {
            RenderEnvReader(themeOverride: theme) { base in
                let env = RenderEnv(
                    theme: base.theme,
                    isReduceMotionEnabled: base.isReduceMotionEnabled,
                    isReduceTransparencyEnabled: base.isReduceTransparencyEnabled,
                    isBoldTextEnabled: boldText,
                    isDifferentiateWithoutColorEnabled: base.isDifferentiateWithoutColorEnabled,
                    isLowPowerModeEnabled: base.isLowPowerModeEnabled,
                    typeMultiplier: base.typeMultiplier
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s16) {
                        controls(env)
                        section("VERDICT RING", env) { verdictRings(env) }
                        section("MARKS", env) { marks(env) }
                        section("GLYPH — the four channels", env) { channels(env) }
                    }
                    .padding(Space.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .grayscale(greyscale ? 1 : 0)
                }
                .background(Color(env.palette.ground.base).ignoresSafeArea())
            }
        }

        @ViewBuilder
        private func controls(_ env: RenderEnv) -> some View {
            VStack(alignment: .leading, spacing: Space.s4) {
                Picker("Theme", selection: $theme) {
                    ForEach(RenderEnv.Theme.allCases, id: \.self) {
                        Text(verbatim: "\($0)").tag($0)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Greyscale", isOn: $greyscale).typeRole(.micro, in: env)
                Toggle("Bold Text", isOn: $boldText).typeRole(.micro, in: env)
            }
            .foregroundStyle(Color(env.palette.stroke.secondary))
            .tint(Color(env.palette.accent.brass))
        }

        @ViewBuilder
        private func section(
            _ title: String, _ env: RenderEnv, @ViewBuilder _ content: () -> some View
        ) -> some View {
            Text(title)
                .typeRole(.micro, in: env)
                .foregroundStyle(Color(env.palette.stroke.secondary))
            content()
        }

        @ViewBuilder
        private func verdictRings(_ env: RenderEnv) -> some View {
            let states: [(String, VerdictRing.State)] = [
                ("admit", .admit), ("reject", .reject),
                ("twin ✓", .twin(admitted: true)), ("twin ✗", .twin(admitted: false)),
                ("counterex.", .counterexample(loomAdmits: true)),
                ("restrike 3", .restrike(count: 3)),
            ]
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s12) {
                    ForEach(states, id: \.0) { name, state in
                        VStack(spacing: Space.s4) {
                            Canvas { context, size in
                                // Concentric with the glyph BODY, not the canvas: the body sits
                                // at centreOffset above the box centre (§13.5, screen frame).
                                let centre = CGPoint(
                                    x: size.width / 2,
                                    y: size.height / 2 + C.Glyph.centreOffset(side: 44))
                                GlyphRenderer(
                                    glyph: Glyph(
                                        fill: .hollow, shape: .circle, pips: .two, hue: .amber),
                                    side: 44, env: env
                                ).draw(into: &context, canvas: size)
                                VerdictRing.draw(
                                    into: context, centre: centre, bodyRadius: 44 * 0.37,
                                    state: state, env: env)
                            }
                            .frame(width: 64, height: 64)
                            Text(verbatim: name).typeRole(.micro, in: env)
                                .foregroundStyle(Color(env.palette.stroke.secondary))
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func marks(_ env: RenderEnv) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s12) {
                    labelled("ghost", env) { context, size in
                        GhostFrame.draw(
                            into: context,
                            box: CGRect(
                                x: 8, y: 8, width: size.width - 16, height: size.height - 16),
                            env: env)
                    }
                    labelled("barred", env) { context, size in
                        MachinedBar.draw(
                            into: context,
                            key: CGRect(
                                x: 6, y: size.height / 2 - 12, width: size.width - 12, height: 24),
                            env: env)
                    }
                    labelled("hatch", env) { context, size in
                        CancelHatch.draw(
                            into: context,
                            region: CGRect(
                                x: 8, y: 8, width: size.width - 16, height: size.height - 16),
                            variant: .hatch, bounds: .rect, paint: .chrome, env: env)
                    }
                    labelled("ticks", env) { context, size in
                        TickRow.draw(
                            into: context,
                            frame: CGRect(
                                x: 4, y: size.height - 20, width: size.width - 8, height: 14),
                            mode: .count(filled: 5, total: 13), nominalPitch: 9, env: env)
                    }
                    labelled("arc", env) { context, size in
                        ArcMeter.draw(
                            into: context,
                            track: .ring(
                                in: CGRect(
                                    x: 10, y: 10, width: size.width - 20,
                                    height: size.height - 20)),
                            value: 7, total: 13, style: .shelfFill, env: env)
                    }
                }
            }
        }

        @ViewBuilder
        private func labelled(
            _ name: String, _ env: RenderEnv,
            _ draw: @escaping (GraphicsContext, CGSize) -> Void
        ) -> some View {
            VStack(spacing: Space.s4) {
                Canvas { context, size in draw(context, size) }
                    .frame(width: 64, height: 64)
                Text(verbatim: name).typeRole(.micro, in: env)
                    .foregroundStyle(Color(env.palette.stroke.secondary))
            }
        }

        @ViewBuilder
        private func channels(_ env: RenderEnv) -> some View {
            VStack(alignment: .leading, spacing: Space.s8) {
                row(
                    Glyph.Fill.allCases.map {
                        Glyph(fill: $0, shape: .hexagon, pips: .three, hue: .amber)
                    }, env)
                row(
                    Glyph.Shape.allCases.map {
                        Glyph(fill: .hollow, shape: $0, pips: .three, hue: .teal)
                    }, env)
                row(
                    Glyph.Pips.allCases.map {
                        Glyph(fill: .hollow, shape: .circle, pips: $0, hue: .frost)
                    }, env)
                row(
                    Glyph.Hue.allCases.map {
                        Glyph(fill: .striped, shape: .triangle, pips: .two, hue: $0)
                    }, env)
            }
        }

        @ViewBuilder
        private func row(_ glyphs: [Glyph], _ env: RenderEnv) -> some View {
            HStack(spacing: Space.s8) {
                ForEach(glyphs, id: \.id) { GlyphCanvasView(glyph: $0, side: 48, env: env) }
                Spacer()
            }
        }
    }
#endif
