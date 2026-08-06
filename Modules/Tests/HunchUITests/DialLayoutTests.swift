import CoreGraphics
import Testing

import Glyphs
@testable import HunchUI
import LoomFeature
import ModulesTestSupport
import Tokens

/// The row arithmetic §4.1 and §6.2 each give once, asserted on both devices and at every art
/// scale the app ships — because the failure mode is a cell that drops under 44 pt at a text
/// size nobody tested, which is invisible until someone with large type cannot hit it.
@Suite("The Dial's four ramps, both devices", .tags(.unit, .presubmission))
struct DialLayoutTests {

    @Test("Four ramps in canonical fill → shape → pips → hue order")
    func canonicalOrder() {
        #expect(DialView.attributeOrder == Glyph.Attribute.allCases)
        #expect(DialView.attributeOrder == [.fill, .shape, .pips, .hue])
        #expect(DialView.attributeOrder.count == 4)
    }

    @Test("Cell and header geometry, per device")
    func cellGeometry() {
        let se = RampView.Metrics.dial(deviceClass: .compact, artScale: 1)
        #expect(se.cell == C.Ramp.dialCell)
        #expect(se.headerWidth == C.Ramp.headerWidth)
        #expect(se.gutter == C.Ramp.dialGutter)

        let big = RampView.Metrics.dial(deviceClass: .large, artScale: 1)
        #expect(big.cell == C.Ramp.dialCellLarge)
        #expect(big.headerWidth == C.Ramp.headerWidthLarge)
        #expect(big.gutter == C.Ramp.dialGutterLarge)
    }

    /// §4.1: "Header 44 pt + 4 cells of 70 × 48 pt + 6 pt gutters = 342 pt in 375."
    @Test("The row fills its column: header + four cells + three gutters")
    func rowArithmetic() {
        let metrics = RampView.Metrics.dial(deviceClass: .compact, artScale: 1)
        let width = metrics.headerWidth + 4 * metrics.cell.width + 3 * metrics.gutter
        #expect(width == 342)
        #expect(width <= Space.columnContent)
    }

    @Test(
        "Every cell clears the 44 pt floor at every shipped art scale",
        arguments: [PlaySurfaceLayout.DeviceClass.compact, .large],
        [1.0, 1.2, Prim.artScaleCeiling]
    )
    func targetFloor(_ device: PlaySurfaceLayout.DeviceClass, _ artScale: Double) {
        let metrics = RampView.Metrics.dial(deviceClass: device, artScale: artScale)
        #expect(metrics.cell.width >= Space.targetMin)
        #expect(metrics.cell.height >= Space.targetMin)
    }

    /// §12.8's Dynamic Type row asks for a cell that does not fit — `44 + 4 × 84 + 3 × 6 = 398`
    /// on a 375 pt screen. The growth lands in the **height**, the width takes what the row has
    /// left, and the row never exceeds its budget at any shipped scale. DECISIONS 46.
    @Test(
        "Dynamic Type grows the cell's height; the row never outgrows its budget",
        arguments: [PlaySurfaceLayout.DeviceClass.compact, .large])
    func theRowStillFitsAtLargeType(_ device: PlaySurfaceLayout.DeviceClass) {
        let budget = device == .large ? C.Ramp.dialRowWidthLarge : C.Ramp.dialRowWidth
        var lastHeight = 0.0
        for artScale in [1.0, 1.2, Prim.artScaleCeiling] {
            let metrics = RampView.Metrics.dial(deviceClass: device, artScale: artScale)
            let width = metrics.headerWidth + 4 * metrics.cell.width + 3 * metrics.gutter
            #expect(width <= budget)
            #expect(metrics.cell.height > lastHeight)
            #expect(
                metrics.headerWidth
                    == (device == .large ? C.Ramp.headerWidthLarge : C.Ramp.headerWidth))
            lastHeight = metrics.cell.height
        }
        let accessible = RampView.Metrics.dial(deviceClass: device, artScale: Prim.artScaleCeiling)
        #expect(accessible.gutter == C.Ramp.dialGutterAccessible)
    }

    @Test(
        "Four rows fit the Dial region on both devices",
        arguments: [PlaySurfaceLayout.reference(.compact), .reference(.large)])
    func rowsFitTheRegion(_ layout: PlaySurfaceLayout) {
        #expect(layout.dialRow(0).minY == layout.dial.minY)
        #expect(layout.dialRow(3).maxY <= layout.dial.maxY)
        #expect(layout.dialCellSize.height <= layout.dialRow(0).height)
    }

    /// A cell is a picture of ONE channel. The specimen holds the other three fixed across all
    /// four cells of a ramp, so the only thing varying down a row is the thing the row is about.
    @Test("A cell's specimen varies its own attribute and holds the other three")
    func specimenVariesOneAttribute() {
        for attribute in Glyph.Attribute.allCases {
            let cells = (0..<4).map { RampCell.specimen(attribute, rank: $0) }
            for (rank, glyph) in cells.enumerated() {
                #expect(glyph.ordinal(of: attribute) == rank)
            }
            for other in Glyph.Attribute.allCases where other != attribute {
                #expect(Set(cells.map { $0.ordinal(of: other) }).count == 1)
            }
        }
    }
}
