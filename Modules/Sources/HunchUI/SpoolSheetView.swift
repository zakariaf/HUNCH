public import SwiftUI

public import Tokens

/// §6.2's spool sheet: the whole transcript on one screen, read-only apart from the cell tap.
///
/// **Full-screen and opaque, with no scrim.** `scrim.md` fixes the count at two — the Bench and
/// SIEVE's pause — and neither is this: a scrim exists so the surface *behind* stays readable,
/// and the sheet's entire purpose is to replace that surface with a longer view of the same
/// evidence. Ten rows of 70 cells over a half-visible Dial would be less legible, not more.
///
/// It costs nothing, consumes no probe and is available from probe 0. No title, no count, no
/// label, no confirmation, no empty state — the header carries the spool cap and the sort
/// toggle and nothing else.
@MainActor
public struct SpoolSheetView: View {
    public var tiles: [RibbonTileModel]
    public var sheet: SpoolSheetLayout
    public var env: RenderEnv
    public var onLoad: (Int) -> Void
    public var onToggleSort: () -> Void

    public init(
        tiles: [RibbonTileModel],
        sheet: SpoolSheetLayout,
        env: RenderEnv,
        onLoad: @escaping (Int) -> Void = { _ in },
        onToggleSort: @escaping () -> Void = {}
    ) {
        self.tiles = tiles
        self.sheet = sheet
        self.env = env
        self.onLoad = onLoad
        self.onToggleSort = onToggleSort
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(sheet.cellSide), spacing: sheet.gutter),
            count: sheet.columns)
    }

    public var body: some View {
        VStack(spacing: 0) {
            InstrumentBar {
                Button(action: onToggleSort) { SpoolCap(env: env) }
                    .buttonStyle(.plain)
                    .frame(width: Space.s44, height: Space.s44)
                    .contentShape(.rect)
            } centre: {
                Color.clear
            } trailing: {
                Color.clear
            }

            LazyVGrid(columns: columns, spacing: sheet.gutter) {
                ForEach(tiles) { tile in
                    Button {
                        onLoad(tile.id)
                    } label: {
                        RibbonTile(
                            tile: tile, side: sheet.glyphSide, isLoaded: false, env: env)
                    }
                    .buttonStyle(.plain)
                    .frame(width: sheet.cellSide, height: sheet.cellSide)
                    .contentShape(.rect)
                }
            }
            .padding(.horizontal, sheet.margin)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(env.palette.ground.base).ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

/// The 24 pt rail-cap at the ribbon's leading edge — the sheet's one control, and the same mark
/// on the ribbon and on the sheet's header.
@MainActor
public struct SpoolCap: View {
    public var env: RenderEnv

    public init(env: RenderEnv) { self.env = env }

    public var body: some View {
        Canvas { context, size in
            let width = C.Ribbon.spoolCapWidth
            let box = CGRect(
                x: (size.width - width) / 2, y: (size.height - width) / 2,
                width: width, height: width)
            MachinedBar.draw(into: context, key: box, env: env)
        }
        .frame(width: Space.s44, height: Space.s44)
    }
}
