public import SwiftUI

public import HunchUI

internal import Glyphs
internal import Rounds
internal import Tokens

/// The PROBE play surface — §6.2's seven regions and nothing else.
///
/// It positions; it does not draw. Each region is filled by its own view as the epic proceeds
/// (T03 the throat, T04 the Dial, T05 the ribbon, T08 the instrument bar), and this file stays
/// the one place that knows where they go. It reads the geometry from a `PlaySurfaceLayout`
/// built out of `GeometryReader`, so there is no `UIScreen`, no device check and no literal
/// origin anywhere below.
///
/// **Zero text, in every locale** (§12.9). `Scripts/check-source-hygiene.sh` check 7 polices
/// this file from this commit onward.
public struct RoundView: View {

    @State private var round: Round

    /// The draft as it was before the last edit, so the throat can crossfade one register
    /// between two glyphs. Held by the view rather than by `Round`: it is a fact about the
    /// last *animation*, not about the round, and a resumed round has no outgoing draft.
    @State private var outgoingDraft: Glyph?

    public init(round: Round) {
        _round = State(initialValue: round)
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = PlaySurfaceLayout(
                size: proxy.size,
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom)

            ZStack(alignment: .topLeading) {
                region(layout.instrumentBar) { InstrumentBarRegion() }
                region(layout.throat) {
                    RenderEnvReader { env in
                        ThroatView(
                            draft: round.draft,
                            outgoing: outgoingDraft,
                            changedRegister: round.changedRegister,
                            isSeed: round.probesUsed == 0 && round.draft == round.seedGlyph,
                            presentation: round.acceptsInput ? .live : .animating,
                            aperture: apertureTurn,
                            layout: layout,
                            env: env,
                            onStep: step)
                    }
                }
                region(layout.ribbon) { RibbonRegion() }
                if let bezelGap = layout.bezelGap {
                    region(bezelGap) { BezelGapRegion() }
                }
                region(layout.dial) {
                    RenderEnvReader { env in
                        DialView(
                            draft: round.draft, layout: layout, env: env,
                            isEnabled: round.acceptsInput, onSelect: select)
                    }
                }
                region(layout.benchHandle) { BenchHandleRegion() }
                region(layout.commitBar) {
                    CommitBar {
                        CommitKeyRegion()
                    } centre: {
                        CommitKeyRegion()
                    } trailing: {
                        CommitKeyRegion()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .ignoresSafeArea()
        }
    }

    /// One throat swipe or one VoiceOver adjustment. The outgoing draft is captured *before*
    /// the edit, because after it there is nothing left to crossfade from.
    private func step(_ delta: Int) {
        outgoingDraft = round.draft
        round.stepDraft(by: delta)
    }

    /// One Dial cell tap. Captures the outgoing draft for the throat's register crossfade, the
    /// same way a swipe does — one behaviour, two entry points.
    private func select(_ attribute: Glyph.Attribute, _ rank: Int) {
        outgoingDraft = round.draft
        round.select(attribute, rank: rank)
    }

    /// §6.5's 90–260 ms hold. T06 drives it; until then the aperture is absent, which is the
    /// same thing the view shows outside the beat.
    private var apertureTurn: Double? { nil }

    /// One region, placed by its rectangle. `.position` takes a centre, which is the one
    /// conversion this file does — every rectangle it is given is a `CGRect` in screen space.
    private func region(
        _ frame: CGRect, @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}

// The seven placeholders. Each is replaced in full by the task that owns its region, and each
// is a distinct type rather than a shared `EmptyView` so that replacing one is a one-line
// change here and the compiler names the site.

private struct InstrumentBarRegion: View { var body: some View { Color.clear } }
private struct RibbonRegion: View { var body: some View { Color.clear } }
private struct BezelGapRegion: View { var body: some View { Color.clear } }
private struct BenchHandleRegion: View { var body: some View { Color.clear } }
private struct CommitKeyRegion: View { var body: some View { Color.clear } }
