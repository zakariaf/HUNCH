public import CoreGraphics

/// §6.2's spool sheet: a full-screen, read-only **7 × 10 grid of 70 cells**.
///
/// Seven columns rather than eight because eight forces a 38 pt cell on the compact device,
/// below the 44 pt hit floor — and every cell is tappable, so the floor binds. 70 cells against
/// a worst case of `RoundBudget.worstCaseTranscript` leaves cells to spare, which is what the
/// sheet is *for*: the longest possible round in any mode on one screen with no scrolling.
public nonisolated struct SpoolSheetLayout: Equatable, Sendable {

    public struct Position: Equatable, Sendable {
        public let row: Int
        public let column: Int

        public init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }
    }

    public let columns = 7
    public let rows = 10
    public let cellSide: Double
    public let glyphSide: Double
    public let gutter: Double
    public let margin: Double

    public init(deviceClass: PlaySurfaceLayout.DeviceClass) {
        switch deviceClass {
        // 7 × 45 + 6 × 6 + 2 × 12 = 375 across, 10 × 45 + 9 × 6 = 504 down.
        case .compact:
            cellSide = 45
            glyphSide = 40
            gutter = 6
            margin = 12
        // 7 × 51 + 6 × 8 + 2 × 16 = 437 across, 10 × 51 + 9 × 8 = 582 down.
        case .large:
            cellSide = 51
            glyphSide = 46
            gutter = 8
            margin = 16
        }
    }

    public var cellCount: Int { columns * rows }

    public var contentWidth: Double {
        Double(columns) * cellSide + Double(columns - 1) * gutter + 2 * margin
    }

    public var contentHeight: Double {
        Double(rows) * cellSide + Double(rows - 1) * gutter
    }

    /// Chain order: leading→trailing, top→bottom. Mirrored under RTL by the layout direction,
    /// never by this arithmetic — the source order is canonical and the visual direction
    /// follows the locale.
    public func position(of index: Int) -> Position {
        Position(row: index / columns, column: index % columns)
    }

    /// A return elbow at each row end, so adjacency survives the wrap. Without it the grid
    /// reads as ten unrelated rows, and adjacency is the transcript's only structure.
    public func drawsReturnElbow(after index: Int) -> Bool {
        guard index >= 0, index + 1 < cellCount else { return false }
        return position(of: index).row != position(of: index + 1).row
    }
}
