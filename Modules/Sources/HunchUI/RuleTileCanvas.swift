public import SwiftUI

public import Glyphs
public import Tokens

/// The atom of both interfaces (§4.1): **one drawing, seven interactive sites.**
///
/// The Dial ramp is instance 1. The other six — the Bench Ramp tile, the Fork's gate / then /
/// else docks, the Tally's rank ramp and its counter dial — arrive in E09 as *select modes on
/// this type*, never as a second cell drawing. Building a `DialRamp` here and a `RampView`
/// there is the drift this file exists to prevent, and the Fork's else dock is the instance
/// people most often lose: it is a full ramp on the same attribute as the then dock.
///
/// A cell is **a picture of one channel** — the silhouette for `shape`, the interior texture
/// for `fill`, the contour nodes for `pips`, the index stroke for `hue`. That is §4.1's whole
/// claim, and it is why there is no attribute emblem to learn.
@MainActor
public struct RampView: View {

    public enum SelectMode: Hashable, Sendable {
        /// The Dial: exactly one lit, tapping another moves the selection.
        case single
        /// A Bench rail: any subset, tapping toggles. **E09·T02.**
        case multi
        /// A Fork's gate dock. Behaves as `single`; kept distinct because the VoiceOver value
        /// and the narration differ, and because collapsing them would let a Dial ramp be
        /// dropped into a gate dock. **E09·T02.**
        case exactlyOne
        /// The Tally's counter dial — 5 stops, or 2 in parity mode. **E09·T02.**
        case stops(Int)
    }

    public var env: RenderEnv
    /// `nil` for the Tally's rank ramp and counter dial, which range over ranks and counts
    /// rather than over an attribute's values.
    public var attribute: Glyph.Attribute?
    /// The lit ranks, 0-based. `Set<Int>` and not a `RankSet` **only because the Bench's
    /// `RankSet` and its `isVacuous` predicate are E09·T02's**: the inert state needs it and
    /// `.single` cannot reach the inert state, so inventing the type here would be inventing it
    /// twice.
    public var admitted: Set<Int>
    public var mode: SelectMode
    public var metrics: Metrics
    public var isReadOnly: Bool
    public var onToggle: (Int) -> Void

    public init(
        env: RenderEnv,
        attribute: Glyph.Attribute?,
        admitted: Set<Int>,
        mode: SelectMode,
        metrics: Metrics,
        isReadOnly: Bool = false,
        onToggle: @escaping (Int) -> Void = { _ in }
    ) {
        self.env = env
        self.attribute = attribute
        self.admitted = admitted
        self.mode = mode
        self.metrics = metrics
        self.isReadOnly = isReadOnly
        self.onToggle = onToggle
    }

    private var stopCount: Int {
        if case .stops(let count) = mode { count } else { 4 }
    }

    /// On a **draft composer** an unlit cell means "not chosen"; on a **rule tile** it means
    /// "rejected", and only the second is a claim about the law. The cancel hatch is that claim
    /// drawn, so it belongs to the multi-select modes alone — hatching the Dial's three
    /// unselected cells would tell the player their draft excludes those values. See
    /// `DECISIONS.md` 45.
    private var marksRejection: Bool {
        switch mode {
        case .multi, .stops: true
        case .single, .exactlyOne: false
        }
    }

    public var body: some View {
        // The header abuts cell 1 with no gutter (§12.8's intra-group exemption), so the header
        // is outside the spaced stack rather than its first element.
        HStack(spacing: 0) {
            if let attribute {
                AttributeHeaderView(env: env, attribute: attribute)
                    .frame(width: metrics.headerWidth, height: metrics.cell.height)
            }
            HStack(spacing: metrics.gutter) {
                ForEach(0..<stopCount, id: \.self) { rank in
                    Button {
                        onToggle(rank)
                    } label: {
                        RampCell(
                            env: env, attribute: attribute, rank: rank,
                            isLit: admitted.contains(rank), marksRejection: marksRejection,
                            side: metrics.cell.height)
                    }
                    .buttonStyle(.plain)
                    .frame(width: metrics.cell.width, height: metrics.cell.height)
                    .contentShape(.rect)
                    .disabled(isReadOnly)
                    .accessibilityAddTraits(admitted.contains(rank) ? .isSelected : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension RampView {
    /// Built, never assembled at a call site: a site that writes `70 * scale` inline is the bug
    /// this factory exists to prevent. E09 adds `.benchTile(env:railContent:)` and E15
    /// `.codex(env:)` here, beside it.
    public nonisolated struct Metrics: Equatable, Sendable {
        public var headerWidth: Double
        public var cell: C.Size
        public var gutter: Double

        /// The cell's **height** multiplies by `artScale` (≤ 1.35); its width is capped by the
        /// row's budget, and the header does not scale at all.
        ///
        /// §12.8 asks for 70 × 48 → 84 × 58 and that does not fit: `44 + 4 × 84 + 3 × 6 = 398`
        /// on a 375 pt screen, and no ramp anywhere in the design scrolls horizontally. So the
        /// growth lands in the height, where §13.11 already sanctions the Dial's region
        /// scrolling vertically, and the width takes whatever the row has left. The header
        /// stays at 44 because it *is* the target floor — scaling it would eat the cells' width
        /// to grow a mark that is already big enough. Stroke weights never take `artScale`;
        /// they have their own axis.
        public static func dial(
            deviceClass: PlaySurfaceLayout.DeviceClass, artScale: Double
        ) -> Metrics {
            let isLarge = deviceClass == .large
            let cell = isLarge ? C.Ramp.dialCellLarge : C.Ramp.dialCell
            let headerWidth = isLarge ? C.Ramp.headerWidthLarge : C.Ramp.headerWidth
            let gutter =
                artScale >= Prim.artScaleCeiling
                ? C.Ramp.dialGutterAccessible
                : (isLarge ? C.Ramp.dialGutterLarge : C.Ramp.dialGutter)
            let budget = isLarge ? C.Ramp.dialRowWidthLarge : C.Ramp.dialRowWidth
            let widest = (budget - headerWidth - 3 * gutter) / 4
            return Metrics(
                headerWidth: headerWidth,
                cell: C.Size(
                    width: min(cell.width * artScale, widest),
                    height: cell.height * artScale),
                gutter: gutter)
        }
    }
}

/// One cell: the attribute's own register at one rank, and nothing in the other three.
@MainActor
struct RampCell: View {
    let env: RenderEnv
    let attribute: Glyph.Attribute?
    let rank: Int
    let isLit: Bool
    let marksRejection: Bool
    let side: Double

    var body: some View {
        Canvas { context, size in
            var context = context
            if let attribute {
                let box = CGRect(
                    x: (size.width - side) / 2, y: (size.height - side) / 2,
                    width: side, height: side)
                // `fill` and `pips` mark the *interior* and the *contour nodes*, and neither
                // reads without an edge to be inside or on: a hollow cell would be a blank
                // rectangle and three pips would be three floating dots. The hairline guide is
                // `attribute-header.md` §3's own idiom for exactly this, at the same ink — a
                // guide, not a silhouette, so the cell stays a picture of one channel.
                if attribute == .fill || attribute == .pips {
                    var guideContext = context
                    guideContext.opacity =
                        C.AttributeHeader.contourGuideInk
                        * (isLit ? 1 : C.Ramp.cellUnlitInk(in: env))
                    let radius = C.Glyph.radius(side: side)
                    let centre = CGPoint(
                        x: box.midX, y: box.midY + C.Glyph.centreOffset(side: side))
                    guideContext.stroke(
                        Path(
                            ellipseIn: CGRect(
                                x: centre.x - radius, y: centre.y - radius,
                                width: 2 * radius, height: 2 * radius)),
                        with: .color(env.palette.stroke.secondary.color),
                        style: StrokeStyle(lineWidth: env.weight(.hairline)))
                }
                context.opacity = isLit ? 1 : C.Ramp.cellUnlitInk(in: env)
                GlyphRenderer(
                    glyph: RampCell.specimen(attribute, rank: rank), side: side, env: env
                )
                // Strictly this attribute's register — NOT `affectedRegisters(by:)`, which is
                // about what an *animation* must crossfade. A hue cell draws the index stroke
                // alone; under High Contrast all four hues render as `stroke.primary` and the
                // cells are told apart by rotation only, which is why a hue cell must never
                // shrink below the size that keeps four rotations distinct.
                .draw(into: &context, canvas: size, registers: [attribute])
                if !isLit, marksRejection {
                    context.opacity = 1
                    CancelHatch.draw(
                        into: context, region: box, variant: .hatch, paint: .chrome, env: env)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The glyph a cell draws one register of.
    ///
    /// The other three attributes are held at rank 1 so the cell is a *picture of its own
    /// attribute* and nothing else — and held at the **same** values across all four cells of a
    /// ramp, so the only thing that varies down a row is the thing the row is about.
    static func specimen(_ attribute: Glyph.Attribute, rank: Int) -> Glyph {
        let base = Glyph(fill: .hollow, shape: .circle, pips: .one, hue: .amber)
        let raw = UInt8(min(3, max(0, rank)))
        return Glyph(
            fill: attribute == .fill ? Glyph.Fill(rawValue: raw) ?? base.fill : base.fill,
            shape: attribute == .shape ? Glyph.Shape(rawValue: raw) ?? base.shape : base.shape,
            pips: attribute == .pips ? Glyph.Pips(rawValue: raw) ?? base.pips : base.pips,
            hue: attribute == .hue ? Glyph.Hue(rawValue: raw) ?? base.hue : base.hue)
    }
}
