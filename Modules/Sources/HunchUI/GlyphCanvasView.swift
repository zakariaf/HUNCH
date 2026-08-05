public import SwiftUI

public import Glyphs
public import Tokens

/// The SwiftUI wrapper around `GlyphRenderer`. One `Canvas` per glyph; the blurred bed
/// (pass A) is one offscreen layer per glyph-BEARING REGION and belongs to the region's view,
/// never here — §13.5 budgets three layers per frame, not sixteen.
@MainActor
public struct GlyphCanvasView: View {
    public let glyph: Glyph
    public let side: Double
    public let env: RenderEnv

    public init(glyph: Glyph, side: Double, env: RenderEnv) {
        self.glyph = glyph
        self.side = side
        self.env = env
    }

    public var body: some View {
        let bleed = C.Glyph.bleed(side: side, in: env)
        Canvas { context, size in
            var context = context
            GlyphRenderer(glyph: glyph, side: side, env: env)
                .draw(into: &context, canvas: size)
        }
        .frame(width: side + 2 * bleed.x, height: side + 2 * bleed.y)
        // The full four-part VoiceOver label is E19·T02's, and it is a localized format
        // string with four interpolations — never concatenated fragments (§2). This is the
        // minimum that keeps the element from being unlabelled in the meantime.
        .accessibilityLabel(Text(verbatim: "glyph \(glyph.id)"))
    }
}
