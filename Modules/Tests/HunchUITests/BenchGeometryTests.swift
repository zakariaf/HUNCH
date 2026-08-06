import CoreGraphics
import Testing

import HunchUI
import ModulesTestSupport
import Tokens

/// §6.7's single most important layout constraint, and §12.8's tier 1, made structural rather
/// than checked: the evidence and the commit bar are computed **before** the mode is consulted,
/// so the two modes cannot disagree about them however either is edited later.
@Suite("Bench geometry", .tags(.unit, .presubmission))
struct BenchGeometryTests {

    @Test(
        "The throat and the ribbon hold their rects across both modes",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func evidenceNeverLeavesTheScreen(_ device: PlaySurfaceLayout.DeviceClass) {
        let dial = PlaySurfaceLayout.reference(device, mode: .dial)
        let bench = PlaySurfaceLayout.reference(device, mode: .bench)

        #expect(dial.throat == bench.throat)
        #expect(dial.ribbon == bench.ribbon)
        #expect(dial.instrumentBar == bench.instrumentBar)
    }

    @Test(
        "The commit bar is in the same place in both modes, and only its contents change",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func commitBarIsInvariant(_ device: PlaySurfaceLayout.DeviceClass) {
        let dial = PlaySurfaceLayout.reference(device, mode: .dial)
        let bench = PlaySurfaceLayout.reference(device, mode: .bench)

        #expect(dial.commitBar == bench.commitBar)
        #expect(dial.commitBarKeys == 3)  // PROBE · twin · Bench
        #expect(bench.commitBarKeys == 2)  // Dial · Seal
    }

    /// §4.2's SE reference: rails 291 pt, the Assay in a 64 pt trailing column.
    @Test("The Bench region splits into rails plus the Assay column with no overlap")
    func benchRegionSplit() {
        let bench = PlaySurfaceLayout.reference(.compact, mode: .bench)

        // `CGFloat(...)`, always, when a token meets a rect: a mixed comparison inside
        // `#expect` reports failure for both `==` and `!=` (DECISIONS 39).
        #expect(bench.rails.width == CGFloat(C.RuleTile.railContent))
        #expect(bench.assayColumn.width == CGFloat(C.Assay.gridSide(.benchWell)))
        #expect(bench.rails.maxX <= bench.assayColumn.minX)
        #expect(bench.assayColumn.maxX <= bench.width)
        #expect(bench.rails.minY == bench.assayColumn.minY)
        #expect(bench.rails.height == bench.assayColumn.height)
    }

    @Test(
        "Bench regions are contiguous and ordered",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func regionsAreContiguous(_ device: PlaySurfaceLayout.DeviceClass) {
        let bench = PlaySurfaceLayout.reference(device, mode: .bench)
        let stack = [
            bench.instrumentBar, bench.throat, bench.ribbon, bench.benchRegion, bench.palette,
            bench.commitBar,
        ]
        for (above, below) in zip(stack, stack.dropFirst()) {
            #expect(above.maxY <= below.minY, "\(above) overlaps \(below)")
        }
        #expect(bench.commitBar.maxY <= bench.safeArea.maxY)
        #expect(bench.benchRegion.height > 0)
    }

    /// The palette comes out of the Bench's own height and never out of the handle-to-commit
    /// gap, which is 44 pt on the compact device and **4 pt** on the large one — a palette laid
    /// out into that gap would be legal on one device and unusable on the other.
    @Test(
        "The palette is a full-height target on both devices",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func paletteClearsTheTargetFloor(_ device: PlaySurfaceLayout.DeviceClass) {
        let bench = PlaySurfaceLayout.reference(device, mode: .bench)
        #expect(bench.palette.height >= CGFloat(Space.targetMin))
        #expect(bench.palette.maxY == bench.commitBar.minY)
        #expect(CGFloat(C.Key.paletteStamp.height) <= bench.palette.height)
        #expect(CGFloat(4 * C.Key.paletteStamp.width) <= bench.width)
    }

    /// §6.2's decision again, this time through the Bench: the controls keep their heights and
    /// only the evidence absorbs surplus device height.
    @Test("Surplus device height goes to the throat and the ribbon, never to the controls")
    func surplusGoesToEvidence() {
        let compact = PlaySurfaceLayout.reference(.compact, mode: .bench)
        let large = PlaySurfaceLayout.reference(.large, mode: .bench)

        #expect(large.throat.height > compact.throat.height)
        #expect(large.ribbon.height > compact.ribbon.height)
        #expect(large.palette.height == compact.palette.height)
        #expect(large.commitBar.height <= compact.commitBar.height)
    }

    /// §12.8 tier 1–2 across the mode switch: opening the Bench must not put a control out of
    /// reach, which is the failure a taller drawer would introduce silently.
    @Test(
        "Every Bench control is inside the reach budget",
        arguments: PlaySurfaceLayout.DeviceClass.allCases)
    func benchControlsAreInReach(_ device: PlaySurfaceLayout.DeviceClass) {
        let bench = PlaySurfaceLayout.reference(device, mode: .bench)
        for region in [bench.palette, bench.commitBar, bench.assayColumn] {
            #expect(bench.safeBottom - region.minY <= CGFloat(C.Bench.reachBudget))
        }
        // The rails' *nearest* row is what reach is measured at (§12.8 tier 2): a multi-cell
        // grid is entered from below, so its far edge is not the number that matters.
        #expect(bench.safeBottom - bench.rails.maxY <= CGFloat(C.Bench.reachBudget))
    }
}
