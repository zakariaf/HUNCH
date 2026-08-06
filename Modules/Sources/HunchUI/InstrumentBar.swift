public import SwiftUI

public import Tokens

/// The three-slot instrument bar, built once and reused by every screen.
///
/// **`minHeight`, never `height`.** On a play surface the bar resolves to exactly 44 pt because
/// a play surface carries zero text and therefore nothing that can wrap — but the height must
/// still be *resolved and read*, and every region below it positioned from its `maxY`, because
/// the same component sits on titled screens that do grow. Writing `.padding(.top, 64)` at a
/// call site is the single most likely defect in this component and the reason this comment is
/// here rather than in a document.
///
/// The 44 pt slots supply the horizontal margin; there is no extra outer padding, and the
/// trailing slot takes no alignment — the centre's `maxWidth: .infinity` is what pins it.
@MainActor
public struct InstrumentBar<Leading: View, Centre: View, Trailing: View>: View {
    private let leading: Leading
    private let centre: Centre
    private let trailing: Trailing

    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder centre: () -> Centre,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.centre = centre()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: Space.s44, height: Space.s44)
            centre.frame(maxWidth: .infinity)
            trailing.frame(width: Space.s44, height: Space.s44)
        }
        .frame(minHeight: Space.s44)
    }
}

/// PROBE's centre slot: the par row above, the cap row below, both drawn by the one mark.
@MainActor
public struct ParTickRowView: View {
    public var model: ParRowModel
    public var layout: PlaySurfaceLayout
    public var env: RenderEnv

    public init(model: ParRowModel, layout: PlaySurfaceLayout, env: RenderEnv) {
        self.model = model
        self.layout = layout
        self.env = env
    }

    public var body: some View {
        Canvas { context, size in
            let width = min(size.width, layout.tickRowWidth)
            let x = (size.width - width) / 2
            let rowHeight = size.height / 2
            TickRow.draw(
                into: context,
                frame: CGRect(x: x, y: 0, width: width, height: rowHeight * 0.8),
                mode: model.parMode, nominalPitch: layout.nominalTickPitch, env: env)
            if model.capIsLit {
                TickRow.draw(
                    into: context,
                    frame: CGRect(
                        x: x, y: rowHeight, width: width, height: rowHeight * 0.6),
                    mode: model.capMode, nominalPitch: layout.nominalTickPitch, env: env)
            }
        }
        // The crossing crossfades in BOTH motion modes: nothing translates, scales or rotates,
        // so §13.7.4 has no row for it and the substitution is the identity. A reader will look
        // for that row and not find it, which is why this says so.
        .animation(.easeInOut(duration: Dur.micro.seconds), value: model)
        // The probe tally speaks par and cap as numbers. That is legal: accessibility labels
        // are audio and §12.9's no-text rule constrains rendered pixels only. E19·T02 writes
        // the wording.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
