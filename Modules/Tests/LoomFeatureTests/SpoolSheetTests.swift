import Testing

import Glyphs
import HunchUI
import LoomFeature
import ModulesTestSupport
import Rounds

/// §6.2's sheet is a **shared** surface — §7.5 hands DRIFT PROBE's layout region for region —
/// so its capacity is a cross-epic claim and is asserted against a table a future epic cannot
/// walk past.
@Suite("The spool sheet", .tags(.unit, .presubmission))
struct SpoolSheetTests {

    @Test(
        "The grid is 7 × 10 and every cell clears the 44 pt hit floor on both devices",
        arguments: [PlaySurfaceLayout.DeviceClass.compact, .large])
    func gridShape(_ device: PlaySurfaceLayout.DeviceClass) {
        let sheet = SpoolSheetLayout(deviceClass: device)
        #expect(sheet.columns == 7)
        #expect(sheet.rows == 10)
        #expect(sheet.cellCount == 70)
        #expect(sheet.cellSide >= 44)
    }

    /// Eight columns would force a 38 pt cell on the compact device, and every cell is
    /// tappable — so the hit floor is what fixes the column count, not the aspect ratio.
    @Test("Eight columns would not clear the hit floor")
    func sevenColumnsIsForced() {
        let sheet = SpoolSheetLayout(deviceClass: .compact)
        let eightAcross = (sheet.contentWidth - 2 * sheet.margin - 7 * sheet.gutter) / 8
        #expect(eightAcross < 44)
    }

    @Test(
        "The grid spans the screen exactly, on both devices",
        arguments: [
            (PlaySurfaceLayout.DeviceClass.compact, 375.0),
            (PlaySurfaceLayout.DeviceClass.large, 437.0),
        ])
    func gridArithmetic(_ device: PlaySurfaceLayout.DeviceClass, _ across: Double) {
        let sheet = SpoolSheetLayout(deviceClass: device)
        #expect(sheet.contentWidth == across)
        #expect(
            sheet.contentHeight == 10 * sheet.cellSide + 9 * sheet.gutter)
    }

    /// §6.2's invariant, and the reason the sheet is sized against every mode rather than
    /// PROBE's cap.
    @Test("sheetCells ≥ 1 + the largest cap over every mode and band")
    func capacity() {
        let worst = RoundBudget.worstCaseTranscript
        #expect(SpoolSheetLayout(deviceClass: .compact).cellCount >= worst)
        #expect(SpoolSheetLayout(deviceClass: .large).cellCount >= worst)
    }

    @Test("Chain order reads leading→trailing, top→bottom, with a return elbow at each row end")
    func chainOrder() {
        let sheet = SpoolSheetLayout(deviceClass: .compact)
        #expect(sheet.position(of: 0) == SpoolSheetLayout.Position(row: 0, column: 0))
        #expect(sheet.position(of: 6) == SpoolSheetLayout.Position(row: 0, column: 6))
        #expect(sheet.position(of: 7) == SpoolSheetLayout.Position(row: 1, column: 0))
        #expect(sheet.drawsReturnElbow(after: 6))
        #expect(sheet.drawsReturnElbow(after: 5) == false)
        #expect(sheet.drawsReturnElbow(after: 69) == false)  // nothing follows the last cell
    }

    /// One drawing, two surfaces: the sheet reuses the ribbon's tile model rather than growing
    /// its own ring logic and its own ghost-mark rule.
    @Test("Verdict sort blocks admits then rejects and drops the link arcs")
    func verdictSort() {
        let probes = [
            ProbeRecord(index: 0, glyphID: 1, verdict: .reject, isTwin: false),
            ProbeRecord(index: 1, glyphID: 2, verdict: .admit, isTwin: false),
            ProbeRecord(index: 2, glyphID: 3, verdict: .reject, isTwin: false),
        ]
        let tiles = RibbonTileModel.tiles(probes: probes, seedGlyph: Fixtures.seedGlyph)
        let sorted = RibbonTileModel.verdictSorted(tiles)
        #expect(sorted.compactMap(\.verdict) == [.admit, .reject, .reject])
        #expect(sorted.allSatisfy { $0.drawsLinkArc == false })
    }

    @Test("Three spool taps cycle open → sort → closed")
    @MainActor
    func threeTapCycle() {
        let round = Fixtures.round()
        #expect(round.sheet == .closed)
        round.toggleSpool()
        #expect(round.sheet == .chainOrder)
        round.toggleSpool()
        #expect(round.sheet == .verdictSorted)
        round.toggleSpool()
        #expect(round.sheet == .closed)
    }

    /// Under verdict sort the cell index is not the chain index. A sheet that loaded by cell
    /// index would silently load a different probe than the one the player touched, which is
    /// why this loads cell 0 of a *sorted* sheet rather than of an empty round.
    @Test("A cell tap loads through the current ordering and dismisses")
    @MainActor
    func tapLoadsAndDismisses() {
        let round = Fixtures.round()
        let rejected = Deck.glyph(id: 0)  // a circle: the opening law admits triangles only
        round.probe(rejected)
        round.endVerdictBeat()
        round.probe(Fixtures.seedGlyph)  // a triangle — admitted
        round.endVerdictBeat()

        round.toggleSpool()
        round.toggleSpool()
        #expect(round.sheet == .verdictSorted)

        let sorted = RibbonTileModel.verdictSorted(
            RibbonTileModel.tiles(probes: round.ribbon.probes, seedGlyph: round.seedGlyph))
        // Cell 1 of the sorted sheet is the ADMIT — chain index 2 — not chain index 1.
        #expect(sorted[1].id == 2)
        round.loadFromSheet(cellIndex: 1) { sorted.indices.contains($0) ? sorted[$0].id : nil }

        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.loadedIndex == 2)
        #expect(round.sheet == .closed)
    }

    @Test("An out-of-range cell tap does nothing and leaves the sheet open")
    @MainActor
    func outOfRangeTapIsInert() {
        let round = Fixtures.round()
        round.toggleSpool()
        round.loadFromSheet(cellIndex: 69) { _ in nil }
        #expect(round.sheet == .chainOrder)
    }
}
