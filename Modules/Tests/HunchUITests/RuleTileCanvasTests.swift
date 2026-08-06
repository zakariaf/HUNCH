import CoreGraphics
import SwiftUI
import Testing

import Bench
import Glyphs
import ModulesTestSupport
import Tokens

@testable import HunchUI

/// The four tile classes have to be distinguishable at **silhouette level** (§4.2), and every
/// mark on them is a construction rather than an icon — so each of these tests is about a
/// geometric relationship that survives a change of size, not about a picture.
@Suite("The rule-tile canvases", .tags(.unit, .presubmission))
struct RuleTileCanvasTests {

    private static let box = CGRect(x: 0, y: 0, width: 44, height: 44)

    private func wedge(_ comparator: Glyphs.Comparator) -> Path {
        WedgeShape(comparator: comparator).path(in: Self.box)
    }

    @Test("All six comparators draw a distinct, non-empty path")
    func sixWedgesAreDistinct() {
        let paths = Glyphs.Comparator.allCases.map(wedge)
        #expect(paths.count == 6)
        #expect(paths.allSatisfy { !$0.isEmpty })
        for (index, first) in paths.enumerated() {
            for second in paths[(index + 1)...] {
                #expect(first.description != second.description)
            }
        }
    }

    /// The direction is **positional**: the wide end physically opens toward the larger side, so
    /// mirroring the rail under RTL mirrors the meaning correctly rather than inverting it.
    @Test("lt and gt are reflections of each other about the mark box's vertical axis")
    func wedgeDirectionIsPositional() {
        #expect(WedgeShape.apexX(for: .lt, in: Self.box) < Self.box.midX)
        #expect(WedgeShape.apexX(for: .gt, in: Self.box) > Self.box.midX)
        let lt = wedge(.lt).boundingRect
        let gt = wedge(.gt).boundingRect
        #expect(abs(lt.width - gt.width) < 0.001)
        #expect(abs(lt.midX - gt.midX) < 0.001)
    }

    /// A clipped `gte` loses its underbar and becomes `gt` — a different law. The underbar is
    /// therefore additive and the mark box clamps to the container rather than overflowing it.
    @Test("lte and gte add an underbar and nothing else")
    func underbarIsAdditive() {
        #expect(wedge(.lte).boundingRect.maxY > wedge(.lt).boundingRect.maxY)
        #expect(wedge(.gte).boundingRect.maxY > wedge(.gt).boundingRect.maxY)
        #expect(
            abs(wedge(.lte).boundingRect.minY - wedge(.lt).boundingRect.minY) < 0.001)
    }

    @Test("The mark shrinks with its container rather than clipping")
    func theMarkClampsToTheContainer() {
        let tiny = CGRect(x: 0, y: 0, width: 12, height: 12)
        let mark = WedgeShape.markBox(in: tiny)
        #expect(mark.width <= tiny.width)
        // The whole mark fits, underbar included — that is what "shrinks rather than clips"
        // has to mean, or a `gte` in a small container quietly renders as a `gt`.
        for comparator in Glyphs.Comparator.allCases {
            let drawn = WedgeShape(comparator: comparator).path(in: tiny).boundingRect
            #expect(drawn.maxY <= tiny.maxY + 0.001)
            #expect(drawn.minY >= tiny.minY - 0.001)
        }
    }

    @Test("The wedge cycles in Comparator's declaration order and wraps")
    func wedgeCycleOrder() {
        var seen: [Glyphs.Comparator] = [.eq]
        for _ in 0..<6 { seen.append(seen[seen.count - 1].next) }
        #expect(Array(seen.prefix(6)) == Glyphs.Comparator.allCases)
        #expect(seen[seen.count - 1] == .eq)
    }

    /// All three couplers are symmetric about the axis because the combinators are commutative
    /// and RNF sorts their operands — an asymmetric OR asserts an order the AST does not have.
    @Test(
        "AND is one strand; OR and XOR are two, and all three are symmetric about the axis",
        arguments: Coupler.allCases)
    func couplerTopology(_ coupler: Coupler) {
        #expect(CouplerShape.strandCount(coupler) == (coupler == .and ? 1 : 2))
        let bounds = CouplerShape(coupler: coupler).path(in: Self.box).boundingRect
        #expect(abs(bounds.midX - Self.box.midX) < 0.0001)
        #expect(abs(bounds.midY - Self.box.midY) < 0.0001)
    }

    @Test("The AND weld is heavier than the OR and XOR strands")
    func weldIsHeavier() {
        #expect(C.Coupler.weldWeight > C.Coupler.strandWeight)
        #expect(CouplerShape.weight(.and) > CouplerShape.weight(.or))
        #expect(CouplerShape.weight(.or) == CouplerShape.weight(.xor))
    }

    /// The tile that teaches itself: the incoming line originates at the lit gate cell and
    /// **moves when the selection moves**. A fixed origin looks right and teaches nothing.
    @Test("The turnout's origin follows the lit gate cell")
    func turnoutOriginFollowsTheGate() {
        let previous = (0..<4).map {
            TurnoutShape.originX(litCellIndex: $0, cellCount: 4, in: Self.box)
        }
        #expect(previous == previous.sorted())
        #expect(Set(previous).count == 4)
        #expect(previous[0] > Self.box.minX)
        #expect(previous[3] < Self.box.maxX)
        // Out of range clamps rather than escaping the tile.
        #expect(TurnoutShape.originX(litCellIndex: 9, cellCount: 4, in: Self.box) == previous[3])
        #expect(TurnoutShape.originX(litCellIndex: -1, cellCount: 4, in: Self.box) == previous[0])
    }

    /// §4.2's inert pair, drawn once. The predicate is core (`RankSet.isVacuous`) and is the
    /// same one the Seal reads, so the ramp and the Seal cannot disagree about which drafts are
    /// declarable.
    @Test("Both inert states are the same drawing and the same predicate")
    func oneInertDrawing() {
        #expect(RankSet.empty.isVacuous)
        #expect(RankSet.full.isVacuous)
        #expect(RampView.isInert(admitted: .empty) == RampView.isInert(admitted: .full))
        #expect(RampView.isInert(admitted: RankSet(ranks: [0, 2])) == false)
    }

    /// `ramp.md` §1's census. The instance that gets lost is the Fork's **else** dock — a full
    /// independent ramp on the same attribute as the then dock. Collapsing it makes 8,736 guard
    /// forms unreachable.
    @Test("The ramp has seven interactive instances and no eighth")
    func rampInstanceCensus() {
        #expect(RampView.Instance.allCases.count == 7)
        #expect(RampView.Instance.allCases.contains(.forkThenDock))
        #expect(RampView.Instance.allCases.contains(.forkElseDock))
        #expect(RampView.Instance.allCases.contains(.forkGateDock))
    }
}

/// The tile classes as *behaviour*: what cycles, what toggles, and the one asymmetry that is
/// the entire contextual grammar.
@Suite("The tiles' verbs", .tags(.unit, .presubmission))
struct TileVerbTests {

    @Test("The coupler cycles AND → OR → XOR and wraps")
    func couplerCycles() {
        #expect(Coupler.and.next == .or)
        #expect(Coupler.or.next == .xor)
        #expect(Coupler.xor.next == .and)
    }

    /// §3.4's RNF rule 3 made physical: the ghost toggle is on the **trailing** socket only.
    /// Every one of the 96 contextual forms is `RANK a(cur) ⋈ PREV RANK b`, so `cur`-leading is
    /// the grammar's orientation rather than a restriction — and all 96 are reachable as
    /// leading × trailing × wedge = 4 × 4 × 6.
    @Test("Leading × trailing × comparator reaches all 96 contextual forms")
    func theGrammarIsReachable() {
        var forms: Set<String> = []
        for leading in Glyph.Attribute.allCases {
            for trailing in Glyph.Attribute.allCases {
                for comparator in Glyphs.Comparator.allCases {
                    forms.insert("\(leading)\(trailing)\(comparator)")
                }
            }
        }
        #expect(forms.count == 96)
    }

    @Test("A ramp's lit ranks round-trip through the set the view speaks in")
    func litRanksRoundTrip() {
        for set in RankSet.all {
            #expect(RankSet(ranks: set.litRanks) == set)
        }
    }
}
