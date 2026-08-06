public import SwiftUI

public import Glyphs
public import Tokens

/// The ribbon: the round's transcript, pinned to its trailing edge (§6.2).
///
/// **Two accessibility shapes in one component, and getting them the right way round is the
/// whole trick.** The tiles are `Button`s — §13.10 gives each a label, a value and a "load into
/// the Dial" action, and they are the stops of the *Probes* rotor. The arcs, the elbows and the
/// lane background are **one** `Canvas`, hidden: they are not targets, they carry no separate
/// information, and adjacency is already carried by the traversal order. A single canvas drawn
/// over the tiles would take all three away and kill the rotor.
@MainActor
public struct RibbonView: View {
    public var tiles: [RibbonTileModel]
    public var layout: PlaySurfaceLayout
    public var env: RenderEnv
    public var loadedIndex: Int?
    public var onLoad: (Int) -> Void

    public init(
        tiles: [RibbonTileModel],
        layout: PlaySurfaceLayout,
        env: RenderEnv,
        loadedIndex: Int? = nil,
        onLoad: @escaping (Int) -> Void = { _ in }
    ) {
        self.tiles = tiles
        self.layout = layout
        self.env = env
        self.loadedIndex = loadedIndex
        self.onLoad = onLoad
    }

    private var model: RibbonLayoutModel {
        RibbonLayoutModel(
            tiles: tiles, lanes: layout.ribbonLanes,
            perLane: Int(layout.ribbon.width / C.Ribbon.tilePitch))
    }

    public var body: some View {
        // `.defaultScrollAnchor(.trailing)` is what re-pins after a verdict: it holds the
        // trailing anchor as the content grows, so the append does the work and no imperative
        // `scrollTo` is needed — and no scroll position to get wrong on a resume.
        ScrollView(.horizontal) {
            LazyHStack(spacing: C.Ribbon.tilePitch - C.Ribbon.tileSide) {
                ForEach(tiles) { tile in
                    Button {
                        onLoad(tile.id)
                    } label: {
                        RibbonTile(
                            tile: tile, glyphSide: C.Ribbon.tileGlyphSide,
                            isLoaded: tile.id == loadedIndex, env: env)
                    }
                    .buttonStyle(.plain)
                    .frame(width: C.Ribbon.tileSide, height: C.Ribbon.tileSide)
                    .contentShape(.rect)
                }
            }
            .padding(.horizontal, Space.marginOuter)
            // Under Reduce Motion the append must not slide: `LazyHStack`'s default insertion
            // transition would translate the new tile in and quietly violate §13.12 gate 9.
            .animation(env.isReduceMotionEnabled ? nil : .default, value: tiles.count)
            .background {
                Canvas { context, size in
                    drawChain(into: context, size: size)
                }
                .accessibilityHidden(true)
            }
        }
        .defaultScrollAnchor(.trailing)
        .scrollIndicators(.hidden)
        .frame(width: layout.ribbon.width, height: layout.ribbon.height)
        .accessibilityElement(children: .contain)
    }

    /// The link arcs and the return elbows — the ribbon's only structural information.
    private func drawChain(into context: GraphicsContext, size: CGSize) {
        let pitch = C.Ribbon.tilePitch
        let side = C.Ribbon.tileSide
        let laneHeight = size.height / Double(max(1, layout.ribbonLanes))
        for index in tiles.indices.dropLast() where tiles[index + 1].drawsLinkArc {
            let lane = model.lane(of: index)
            let nextLane = model.lane(of: index + 1)
            let y = laneHeight * (Double(lane) + 0.5)
            let column = index - lane * model.perLane
            let from = CGPoint(
                x: Space.marginOuter + Double(column) * pitch + side, y: y)
            if model.wrapsAfter(index: index) {
                // The elbow is what keeps adjacency readable across a wrap. Without it a
                // two-lane ribbon reads as two unrelated rows.
                LinkArc.draw(
                    into: context, from: from,
                    to: CGPoint(
                        x: Space.marginOuter, y: laneHeight * (Double(nextLane) + 0.5)),
                    kind: .elbow(drop: C.Ribbon.returnElbowDrop), env: env)
            } else {
                LinkArc.draw(
                    into: context, from: from,
                    to: CGPoint(x: from.x + (pitch - side), y: y), env: env)
            }
        }
    }
}

/// One tile: the glyph, its verdict ring, and the two marks the transcript carries.
@MainActor
struct RibbonTile: View {
    let tile: RibbonTileModel
    /// The glyph's own side — **smaller than the tile**, so the settled verdict ring has room.
    let glyphSide: Double
    let isLoaded: Bool
    let env: RenderEnv

    var body: some View {
        Canvas { context, size in
            var context = context
            let side = glyphSide
            let box = CGRect(
                x: (size.width - side) / 2, y: (size.height - side) / 2,
                width: side, height: side)
            let bodyCentre = CGPoint(
                x: box.midX, y: box.midY + C.Glyph.centreOffset(side: side))

            // §6.6 layer 2: the ghost mark is the Loom's memory made permanently visible. It
            // and a verdict ring share one tile after probe 1, which is correct rather than a
            // collision — the tile is both the last probe and the next probe's context.
            if tile.isSeed || tile.wearsGhostMark {
                GhostFrame.draw(
                    into: context, box: box, role: tile.isSeed ? .seed : .marker, env: env)
            }
            GlyphRenderer(glyph: tile.glyph, side: side, env: env)
                .draw(into: &context, canvas: size)
            if let state = ringState {
                VerdictRing.draw(
                    into: context, centre: bodyCentre,
                    bodyRadius: C.Glyph.radius(side: side), state: state, role: .settled,
                    env: env)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(isLoaded ? .isSelected : [])
    }

    /// The ribbon's vocabulary translated into the mark's. The split ring is **not** an
    /// animation: it draws in its final state, because the contradiction is a fact about the
    /// transcript and not an event.
    private var ringState: VerdictRing.State? {
        switch tile.ring {
        case .closed: .admit
        case .broken: .reject
        case .doubled:
            .twin(
                first: tile.verdict ?? .admit, second: tile.verdict ?? .admit)
        case .split:
            .twin(
                first: tile.verdict == .admit ? .reject : .admit,
                second: tile.verdict ?? .admit)
        case nil: nil
        }
    }
}
