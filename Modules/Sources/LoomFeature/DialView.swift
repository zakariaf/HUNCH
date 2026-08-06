public import SwiftUI

public import HunchUI

public import Glyphs
public import Tokens

/// The Dial: four single-select ramps in canonical `fill → shape → pips → hue` order (§4.1).
///
/// Free construction, not a dealt hand and not a 256-glyph grid. The Dial *factors* the eight
/// bits of a glyph into four independent two-bit choices that map exactly onto the hypothesis
/// structure — which is what makes controlled variation reachable at all, and why Hick's law
/// applies to the flat set rather than to this one.
@MainActor
public struct DialView: View {

    /// §2's canonical order, which is the order of everything: VoiceOver labels, the deck sort,
    /// ramp rows here and on the Bench, Codex page layout and serialisation.
    public nonisolated static let attributeOrder = Glyph.Attribute.allCases

    public var draft: Glyph
    public var layout: PlaySurfaceLayout
    public var env: RenderEnv
    public var isEnabled: Bool
    public var onSelect: (Glyph.Attribute, Int) -> Void

    public init(
        draft: Glyph,
        layout: PlaySurfaceLayout,
        env: RenderEnv,
        isEnabled: Bool = true,
        onSelect: @escaping (Glyph.Attribute, Int) -> Void = { _, _ in }
    ) {
        self.draft = draft
        self.layout = layout
        self.env = env
        self.isEnabled = isEnabled
        self.onSelect = onSelect
    }

    public var body: some View {
        let metrics = RampView.Metrics.dial(
            deviceClass: layout.deviceClass, artScale: env.artScale)
        // Above AX2 nothing shrinks: the ramps scroll inside the region rather than growing it
        // (§13.11), which is why `PlaySurfaceLayout.dial` is a fixed height. The full AX matrix
        // is verified in E19·T06; the container is wired here so there is something to verify.
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(Array(Self.attributeOrder.enumerated()), id: \.element) { index, attr in
                    RampView(
                        env: env,
                        attribute: attr,
                        admitted: [draft.ordinal(of: attr)],
                        mode: .single,
                        metrics: metrics,
                        isReadOnly: !isEnabled,
                        onToggle: { rank in onSelect(attr, rank + 1) }
                    )
                    .frame(height: layout.dialRow(index).height, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(env.artScale < Prim.artScaleCeiling)
        .accessibilityElement(children: .contain)
    }
}
