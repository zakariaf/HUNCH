public import SwiftUI

public import Bench
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
    public var assay: Assay
    public var evidence: AssayEvidence
    public var onStamp: (Int) -> Void
    public var onExpandAssay: () -> Void

    public init(
        layout: PlaySurfaceLayout,
        env: RenderEnv,
        assay: Assay,
        evidence: AssayEvidence = .none,
        onStamp: @escaping (Int) -> Void = { _ in },
        onExpandAssay: @escaping () -> Void = {}
    ) {
        self.layout = layout
        self.env = env
        self.assay = assay
        self.evidence = evidence
        self.onStamp = onStamp
        self.onExpandAssay = onExpandAssay
    }

    public var body: some View {
        HStack(spacing: Space.s4) {
            RailsRegion()
                .frame(width: layout.rails.width)
            AssayGridView(
                assay: assay, evidence: evidence, site: .benchWell, env: env,
                onTap: onExpandAssay
            )
            .frame(width: layout.assayColumn.width, alignment: .top)
        }
        .frame(width: layout.benchRegion.width, height: layout.benchRegion.height)
        .accessibilityElement(children: .contain)
    }
}

// The rails' contents are the player's draft, which E09·T07 gives `Round` a home for. The tile
// canvases themselves are already built; what is missing is the draft that decides which of them
// are on which rail.
private struct RailsRegion: View { var body: some View { Color.clear } }
