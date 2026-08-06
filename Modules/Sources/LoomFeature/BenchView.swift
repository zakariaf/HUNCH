public import SwiftUI

public import HunchUI

public import Tokens

/// §4.2's declaration surface: rails, the Assay's trailing column, the palette, and a commit
/// bar that swaps three keys for two without moving.
///
/// The Bench is a **drawer over the Dial**, not a screen: the throat and the ribbon stay exactly
/// where they were, because a player declares *from* the evidence and a surface that hid it
/// would be asking them to remember instead of to read (§6.7).
@MainActor
public struct BenchView: View {
    public var layout: PlaySurfaceLayout
    public var env: RenderEnv
    public var onStamp: (Int) -> Void

    public init(
        layout: PlaySurfaceLayout, env: RenderEnv, onStamp: @escaping (Int) -> Void = { _ in }
    ) {
        self.layout = layout
        self.env = env
        self.onStamp = onStamp
    }

    public var body: some View {
        HStack(spacing: Space.s4) {
            RailsRegion()
                .frame(width: layout.rails.width)
            AssayRegion()
                .frame(width: layout.assayColumn.width)
        }
        .frame(width: layout.benchRegion.width, height: layout.benchRegion.height)
        .accessibilityElement(children: .contain)
    }
}

// The two halves of the drawer. **E09·T02** fills the rails with the four tile canvases and
// **E09·T05** the column with the Assay grid; each is replaced whole, so the split above is the
// only thing this file has to get right.
private struct RailsRegion: View { var body: some View { Color.clear } }
private struct AssayRegion: View { var body: some View { Color.clear } }
