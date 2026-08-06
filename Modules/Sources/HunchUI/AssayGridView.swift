public import SwiftUI

public import Bench
public import Glyphs
public import Tokens

/// §4.3's constellation: the whole deck as a 16 × 16 micro-grid, lit where the draft admits.
///
/// It is **one `Canvas`** and one accessibility element. 256 cells as 256 views would be 256
/// stops on the rotor for a picture whose whole content is its density — and the density is the
/// point: admit rate reads as brightness, all-dark and all-lit read instantly, and scrubbing the
/// pin morphs the picture, which is the clearest wordless statement of what contextual means.
///
/// The **inspector** (T06's full-screen expansion) is the same drawing at a larger cell, not a
/// second view: one picture, two sizes.
@MainActor
public struct AssayGridView: View {
    public var assay: Assay
    public var evidence: AssayEvidence
    public var site: C.Assay.Site
    public var env: RenderEnv
    public var onTap: () -> Void

    public init(
        assay: Assay,
        evidence: AssayEvidence = .none,
        site: C.Assay.Site = .benchWell,
        env: RenderEnv,
        onTap: @escaping () -> Void = {}
    ) {
        self.assay = assay
        self.evidence = evidence
        self.site = site
        self.env = env
        self.onTap = onTap
    }

    public var body: some View {
        let side = C.Assay.gridSide(site)
        Button(action: onTap) {
            Canvas { context, size in
                let cell = min(size.width, size.height) / Double(Assay.side)
                for id in 0..<Assay.cellCount {
                    let position = Assay.position(of: id)
                    let rect = CGRect(
                        x: Double(position.column) * cell, y: Double(position.row) * cell,
                        width: cell, height: cell)
                    if assay.isLit(id) {
                        context.fill(
                            Path(rect.insetBy(dx: cell * 0.1, dy: cell * 0.1)),
                            with: .color(env.palette.accent.brass.rgb.color))
                    }
                    // The overlay's two marks are geometric, not tinted: a ring for "you have
                    // probed this", a stroke for "your draft disagrees with the transcript
                    // here". A colour-only overlay would be invisible in greyscale on a grid
                    // whose whole content is already brightness.
                    if evidence.probed.contains(id) {
                        context.stroke(
                            Path(ellipseIn: rect.insetBy(dx: cell * 0.15, dy: cell * 0.15)),
                            with: .color(env.palette.stroke.secondary.color),
                            lineWidth: env.weight(.hairline))
                    }
                    if evidence.contradicted.contains(id) {
                        CancelHatch.draw(
                            into: context, region: rect, variant: .slash, paint: .verdict,
                            env: env)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
    }
}
