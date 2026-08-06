import CoreGraphics
import Testing

import HunchUI
import ModulesTestSupport

/// §6.2, region for region, on both devices it tabulates — and then the four properties that
/// have to survive a device the table does not mention.
@Suite("PlaySurfaceLayout — §6.2 region for region", .tags(.unit, .presubmission))
struct PlaySurfaceLayoutTests {

    // `nonisolated`: this target's default isolation is MainActor, and an `arguments:` list is
    // built outside the test's isolation — a main-actor static would be an `await` the macro
    // cannot write for you (06 T9).
    private nonisolated static let se = PlaySurfaceLayout(
        size: CGSize(width: 375, height: 667), safeAreaTop: 20, safeAreaBottom: 0)
    private nonisolated static let proMax = PlaySurfaceLayout(
        size: CGSize(width: 440, height: 956), safeAreaTop: 62, safeAreaBottom: 34)

    @Test("iPhone SE 2/3 — 375 × 667, safe 375 × 647")
    func seRegions() {
        let layout = Self.se
        #expect(layout.deviceClass == .compact)
        #expect(layout.instrumentBar == CGRect(x: 0, y: 20, width: 375, height: 44))
        #expect(layout.throat == CGRect(x: 0, y: 64, width: 375, height: 112))
        #expect(layout.ribbon == CGRect(x: 0, y: 176, width: 375, height: 52))
        #expect(layout.bezelGap == nil)
        #expect(layout.dial == CGRect(x: 0, y: 236, width: 375, height: 272))
        #expect(layout.benchHandle == CGRect(x: 0, y: 516, width: 375, height: 44))
        #expect(layout.commitBar == CGRect(x: 0, y: 604, width: 375, height: 63))
        #expect(layout.ribbonLanes == 1)
    }

    @Test("iPhone 16 Pro Max — 440 × 956, safe y 62…922")
    func proMaxRegions() {
        let layout = Self.proMax
        #expect(layout.deviceClass == .large)
        #expect(layout.instrumentBar == CGRect(x: 0, y: 62, width: 440, height: 44))
        #expect(layout.throat == CGRect(x: 0, y: 106, width: 440, height: 200))
        #expect(layout.ribbon == CGRect(x: 0, y: 306, width: 440, height: 114))
        #expect(layout.bezelGap == CGRect(x: 0, y: 420, width: 440, height: 50))
        #expect(layout.dial == CGRect(x: 0, y: 470, width: 440, height: 342))
        #expect(layout.benchHandle == CGRect(x: 0, y: 820, width: 440, height: 44))
        #expect(layout.commitBar == CGRect(x: 0, y: 868, width: 440, height: 54))
        #expect(layout.ribbonLanes == 2)
    }

    @Test("`reference(_:)` is the table, so previews and tests cannot drift apart")
    func referenceMatchesTheTable() {
        #expect(PlaySurfaceLayout.reference(.compact) == Self.se)
        #expect(PlaySurfaceLayout.reference(.large) == Self.proMax)
    }

    @Test(
        "The regions tile the safe area exactly, in order, with no overlap",
        arguments: [Self.se, Self.proMax])
    func regionsTileTheSafeArea(_ layout: PlaySurfaceLayout) {
        let boxes = layout.orderedRegions
        #expect(boxes[0].minY == layout.safeTop)
        #expect(boxes[boxes.count - 1].maxY == layout.safeBottom)
        for (upper, lower) in zip(boxes, boxes.dropFirst()) {
            #expect(upper.maxY <= lower.minY)
        }
        // Every point of the safe area is either a region or a declared gap.
        let regionHeight = boxes.reduce(0) { $0 + $1.height }
        let gapHeight = zip(boxes, boxes.dropFirst()).reduce(0) { $0 + ($1.1.minY - $1.0.maxY) }
        #expect(regionHeight + gapHeight == layout.safeBottom - layout.safeTop)
    }

    /// The bezel gap is a *surface*, not spacing, so it has to coincide exactly with the
    /// interval the tiling test counts as a gap — otherwise it would be drawn over a region.
    @Test("The bezel gap occupies exactly the ribbon-to-Dial interval")
    func bezelGapFillsItsInterval() {
        let layout = Self.proMax
        #expect(
            layout.bezelGap
                == CGRect(
                    x: 0, y: layout.ribbon.maxY, width: layout.width,
                    height: layout.dial.minY - layout.ribbon.maxY))
        #expect(Self.se.ribbon.maxY < Self.se.dial.minY)  // compact: a gutter, undrawn
    }

    @Test("Surplus height goes to the throat and the ribbon, never to the commit bar")
    func surplusGoesToTheEvidence() {
        let se = Self.se
        let big = Self.proMax
        let surplus = (big.safeBottom - big.safeTop) - (se.safeBottom - se.safeTop)
        let evidenceGain =
            (big.throat.height + big.ribbon.height) - (se.throat.height + se.ribbon.height)
        #expect(surplus > 0)
        #expect(evidenceGain > surplus / 2)  // the majority of it
        #expect(big.commitBar.height <= se.commitBar.height)  // the controls do not inflate
        #expect(big.benchHandle.height == se.benchHandle.height)
        #expect(big.instrumentBar.height == se.instrumentBar.height)
    }

    @Test(
        "Every interactive target is within 460 pt of the bottom safe edge",
        arguments: [Self.se, Self.proMax])
    func reach(_ layout: PlaySurfaceLayout) {
        for region in layout.interactiveRegions {
            #expect(layout.safeBottom - region.minY <= 460)
        }
        // §12.8 tier 3: the throat and the ribbon are read, not touched, and sit above the band.
        #expect(layout.readOnlyRegions.contains(layout.throat))
        #expect(layout.readOnlyRegions.contains(layout.ribbon))
        #expect(layout.interactiveRegions.contains(layout.throat) == false)
        #expect(layout.interactiveRegions.contains(layout.ribbon) == false)
        #expect(layout.safeBottom - layout.throat.minY > 460)
        #expect(layout.safeBottom - layout.ribbon.minY > 460)
    }

    @Test("The Dial's top edge barely moves across a 289 pt difference in screen height")
    func theDialStaysInTheThumbArc() {
        let seReach = Self.se.safeBottom - Self.se.dial.minY
        let bigReach = Self.proMax.safeBottom - Self.proMax.dial.minY
        #expect(seReach == 431)  // §6.2 says 411 — see DECISIONS 38
        #expect(bigReach == 452)
        #expect(bigReach - seReach < 60)
        #expect(bigReach <= 460)
    }

    /// A device the table does not mention. It must be `compact` — the large class needs a
    /// throat as tall as its glyph and this screen cannot give it one — and every invariant
    /// above must still hold, which is the whole reason the class is a predicate.
    @Test("An iPhone 16 lays out as compact, with the surplus in the throat")
    func anUntabulatedDeviceIsStillLegal() {
        let layout = PlaySurfaceLayout(
            size: CGSize(width: 393, height: 852), safeAreaTop: 59, safeAreaBottom: 34)
        #expect(layout.deviceClass == .compact)
        #expect(layout.ribbonLanes == 1)
        #expect(layout.instrumentBar.minY == 59)
        #expect(layout.commitBar.maxY == 818)
        #expect(layout.throat.height == Self.se.throat.height + (759 - 647))
        #expect(layout.ribbon.height == Self.se.ribbon.height)
        for region in layout.interactiveRegions {
            #expect(layout.safeBottom - region.minY <= 460)
        }
    }

    /// §6.7: the throat and the ribbon **do not move** between Dial mode and Bench mode. The
    /// layout makes that structurally possible by deriving both from the top edge, so nothing
    /// E09 does to the bottom half can shift them.
    @Test("The throat and the ribbon are anchored to the top, not to the Dial")
    func evidenceIsAnchoredToTheTopEdge() {
        let layout = Self.se
        #expect(layout.throat.minY == layout.instrumentBar.maxY)
        #expect(layout.ribbon.minY == layout.throat.maxY)
    }

    @Test(
        "The Dial's four ramps start at its top edge and fit inside it",
        arguments: [
            PlaySurfaceLayout.reference(.compact), .reference(.large),
        ])
    func dialRowsFitTheRegion(_ layout: PlaySurfaceLayout) {
        #expect(layout.dialRow(0).minY == layout.dial.minY)
        #expect(layout.dialRow(layout.dialRowCount - 1).maxY <= layout.dial.maxY)
        for index in 1..<layout.dialRowCount {
            #expect(layout.dialRow(index).minY > layout.dialRow(index - 1).maxY)
        }
        // §4.1's row budget is horizontal: header + four cells inside the screen width.
        #expect(
            layout.dialHeaderWidth + 4 * layout.dialCellSize.width <= layout.width)
        #expect(layout.dialCellSize.height <= layout.dialRow(0).height)
    }
}
