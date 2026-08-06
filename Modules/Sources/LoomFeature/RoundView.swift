public import SwiftUI

public import HunchUI

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
                region(layout.throat) { ThroatRegion() }
                region(layout.ribbon) { RibbonRegion() }
                if let bezelGap = layout.bezelGap {
                    region(bezelGap) { BezelGapRegion() }
                }
                region(layout.dial) { DialRegion() }
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
private struct ThroatRegion: View { var body: some View { Color.clear } }
private struct RibbonRegion: View { var body: some View { Color.clear } }
private struct BezelGapRegion: View { var body: some View { Color.clear } }
private struct DialRegion: View { var body: some View { Color.clear } }
private struct BenchHandleRegion: View { var body: some View { Color.clear } }
private struct CommitKeyRegion: View { var body: some View { Color.clear } }
