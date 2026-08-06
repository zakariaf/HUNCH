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
        // A **plain** reader, and the regions drawn in safe-area-local coordinates.
        //
        // `.ignoresSafeArea()` was tried on both sides of the reader and neither is reliable:
        // inside it the proxy is already inset and reports zero insets, and outside it the
        // proxy reports the full height with a zero *top* inset and a real *bottom* one — so
        // every region below the instrument bar drifts up the screen by the top inset, which is
        // invisible on the compact device and 62 pt wrong on the large one. That is exactly the
        // defect the second reference column exists to catch.
        //
        // A plain reader gives the safe rect, which is a fact and not an interpretation. §6.2's
        // coordinates are absolute, so `PlaySurfaceLayout` still speaks them and the placement
        // subtracts `safeTop` once, here — the one conversion in the file.
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let screen = CGSize(
                width: proxy.size.width,
                height: proxy.size.height + insets.top + insets.bottom)
            let layout = PlaySurfaceLayout(
                size: screen, safeAreaTop: insets.top, safeAreaBottom: insets.bottom)

            ZStack(alignment: .topLeading) {
                region(layout, layout.instrumentBar) {
                    RenderEnvReader { env in
                        // The chevron's ACTION is E10·T04's and the mode sigil's DRAWING is
                        // E17·T04's; both arrive as slot contents, so neither epic reopens
                        // this file.
                        InstrumentBar {
                            ChevronSlot()
                        } centre: {
                            ParTickRowView(
                                model: ParRowModel(
                                    probesUsed: round.probesUsed, par: round.par,
                                    cap: round.cap),
                                layout: layout, env: env)
                        } trailing: {
                            Color.clear
                        }
                    }
                }
                region(layout, layout.throat) {
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
                region(layout, layout.ribbon) {
                    RenderEnvReader { env in
                        RibbonView(
                            tiles: RibbonTileModel.tiles(
                                probes: round.ribbon.probes, seedGlyph: round.seedGlyph),
                            layout: layout, env: env, loadedIndex: round.loadedIndex,
                            onLoad: load)
                    }
                }
                if let bezelGap = layout.bezelGap {
                    region(layout, bezelGap) { BezelGapRegion() }
                }
                region(layout, layout.dial) {
                    RenderEnvReader { env in
                        DialView(
                            draft: round.draft, layout: layout, env: env,
                            isEnabled: round.acceptsInput, onSelect: select)
                    }
                }
                region(layout, layout.benchHandle) { BenchHandleRegion() }
                region(layout, layout.commitBar) {
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
            .frame(
                width: proxy.size.width, height: proxy.size.height, alignment: .topLeading
            )
            .overlay {
                if round.sheet != .closed {
                    RenderEnvReader { env in
                        SpoolSheetView(
                            tiles: sheetTiles,
                            sheet: SpoolSheetLayout(
                                deviceClass: layout.deviceClass),
                            env: env, onLoad: loadFromSheet, onToggleSort: round.toggleSpool)
                    }
                }
            }
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

    /// The sheet's cells, in the order the current spool state asks for. One tile model, two
    /// surfaces — the sheet does not get its own ring logic or its own ghost-mark rule.
    private var sheetTiles: [RibbonTileModel] {
        let chain = RibbonTileModel.tiles(
            probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
        return round.sheet == .verdictSorted
            ? RibbonTileModel.verdictSorted(chain) : chain
    }

    /// A sheet cell tap. The cell's chain index comes from the *current* ordering, which under
    /// verdict sort is not the identity.
    private func loadFromSheet(_ chainIndex: Int) {
        outgoingDraft = nil
        round.load(ribbonIndex: chainIndex)
        round.closeSpool()
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

    /// One region, placed by its rectangle.
    ///
    /// Two conversions and no others: §6.2's absolute y minus the safe-area origin, and
    /// `.position`'s centre.
    private func region(
        _ layout: PlaySurfaceLayout, _ frame: CGRect, @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY - layout.safeTop)
    }
}

// The seven placeholders. Each is replaced in full by the task that owns its region, and each
// is a distinct type rather than a shared `EmptyView` so that replacing one is a one-line
// change here and the compiler names the site.

private struct ChevronSlot: View { var body: some View { Color.clear } }
private struct BezelGapRegion: View { var body: some View { Color.clear } }
private struct BenchHandleRegion: View { var body: some View { Color.clear } }
/// The key's own drawing — the sigil each of the three carries. **E17·T03** draws them; until
/// then a key is its border and its press state, which is enough to place and to press.
private struct KeyFace: View { var body: some View { Color.clear } }
