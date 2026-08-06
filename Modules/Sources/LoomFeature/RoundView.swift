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
                            ring: throatRing,
                            ringProgress: round.hasLandedVerdict ? 1 : 0,
                            aperture: apertureTurn,
                            layout: layout,
                            env: env,
                            onStep: step)
                    }
                }
                region(layout.ribbon) {
                    RenderEnvReader { env in
                        RibbonView(
                            tiles: RibbonTileModel.tiles(
                                probes: round.ribbon.probes, seedGlyph: round.seedGlyph),
                            layout: layout, env: env, loadedIndex: round.loadedIndex,
                            onLoad: load)
                    }
                }
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
                    RenderEnvReader { env in
                        // §12.6's Left-hand keys setting mirrors exactly this bar's order and
                        // the Bench handle's side; it lands in E19 and flips one flag here.
                        CommitBar {
                            CommitKey(env: env, isEnabled: round.acceptsInput) {
                                round.probeDraft()
                            } face: {
                                KeyFace()
                            }
                        } centre: {
                            CommitKey(
                                env: env,
                                breath: CommitKey<KeyFace>.BreathPresentation(
                                    isBreathing: round.isBreathing,
                                    reduceMotion: env.isReduceMotionEnabled),
                                isEnabled: round.acceptsInput && round.isTwinAvailable
                            ) {
                                round.probeTwin()
                            } face: {
                                KeyFace()
                            }
                        } trailing: {
                            CommitKey(env: env, isEnabled: round.acceptsInput) {
                                round.openBench()
                            } face: {
                                KeyFace()
                            }
                        }
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

    /// A ribbon tile tap: the Dial and the throat adopt that glyph wholesale (§4.1's second
    /// mitigation). No outgoing draft is captured — a load crossfades the whole glyph, because
    /// it is not a controlled variation and must not be dressed as one.
    private func load(_ index: Int) {
        outgoingDraft = nil
        round.load(ribbonIndex: index)
    }

    /// §6.5, 90–260 ms: the aperture turns through the hold and stops the moment the verdict
    /// lands. Nothing else on the throat moves, and the turn is never conditioned on the
    /// verdict — the Loom must not look like it is thinking harder about a harder glyph.
    private var apertureTurn: Double? {
        guard case .adjudicating = round.phase, !round.hasLandedVerdict else { return nil }
        return 0
    }

    /// The ring appears only once the verdict has landed. Before that the throat is holding,
    /// which is the whole content of the 260 ms.
    private var throatRing: VerdictRing.State? {
        guard case .adjudicating(let verdict) = round.phase, round.hasLandedVerdict else {
            return nil
        }
        return verdict == .admit ? .admit : .reject
    }

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
private struct BezelGapRegion: View { var body: some View { Color.clear } }
private struct BenchHandleRegion: View { var body: some View { Color.clear } }
/// The key's own drawing — the sigil each of the three carries. **E17·T03** draws them; until
/// then a key is its border and its press state, which is enough to place and to press.
private struct KeyFace: View { var body: some View { Color.clear } }
