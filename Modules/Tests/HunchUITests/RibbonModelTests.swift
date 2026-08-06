import Testing

import Glyphs
import HunchUI
import ModulesTestSupport
import Rounds

/// Everything the ribbon *decides* is in this model; the view only draws it. Which is why the
/// whole component's spec — §6.6 layers 2 and 4, §6.11 cases 2 and 3, §6.2's two spool orders —
/// can be asserted here on the host, with no simulator and no snapshot.
@Suite("The ribbon's tile model", .tags(.unit, .presubmission))
struct RibbonModelTests {

    private static func probe(_ id: Int, _ verdict: Verdict, twin: Bool = false, at index: Int)
        -> ProbeRecord
    {
        ProbeRecord(
            index: UInt8(index), glyphID: UInt8(id), verdict: verdict, isTwin: twin)
    }

    private func tiles(_ probes: [ProbeRecord], seed: Glyph = Fixtures.seedGlyph)
        -> [RibbonTileModel]
    {
        RibbonTileModel.tiles(probes: probes, seedGlyph: seed)
    }

    @Test("At probe 0 the ribbon is the seed glyph alone, ghost-marked and unringed")
    func probeZero() {
        let tiles = tiles([])
        #expect(tiles.count == 1)
        #expect(tiles[0].glyph == Fixtures.seedGlyph)
        #expect(tiles[0].isSeed)
        #expect(tiles[0].wearsGhostMark)  // §6.6 layer 2
        #expect(tiles[0].ring == nil)  // §6.11 case 2 — the seed never gains a verdict ring
    }

    @Test("The ghost mark is always on the trailing-most tile, and only there")
    func ghostMarkFollowsPrev() {
        let tiles = tiles([
            Self.probe(1, .admit, at: 0), Self.probe(2, .reject, at: 1),
        ])
        #expect(tiles.count == 3)  // seed + two probes
        #expect(tiles.filter(\.wearsGhostMark).count == 1)
        #expect(tiles[tiles.count - 1].wearsGhostMark)
        #expect(tiles[0].wearsGhostMark == false)
    }

    @Test("An admit closes its ring and a reject breaks it")
    func verdictRings() {
        let tiles = tiles([
            Self.probe(1, .admit, at: 0), Self.probe(2, .reject, at: 1),
        ])
        #expect(tiles[1].ring == .closed)
        #expect(tiles[2].ring == .broken)
    }

    @Test("A twin pair draws as one unit under a doubled ring")
    func twinDoubledRing() {
        let tiles = tiles([
            Self.probe(7, .admit, at: 0), Self.probe(7, .admit, twin: true, at: 1),
        ])
        #expect(tiles[1].twinGroup == tiles[2].twinGroup)
        #expect(tiles[1].twinGroup != nil)
        #expect(tiles[2].ring == .doubled)
    }

    @Test("When a twin's two verdicts differ the ring draws SPLIT — §6.6 layer 4")
    func twinSplitRing() {
        let tiles = tiles([
            Self.probe(7, .admit, at: 0), Self.probe(7, .reject, twin: true, at: 1),
        ])
        #expect(tiles[2].ring == .split)
        #expect(tiles[2].twinGroup != nil)
    }

    @Test("A non-adjacent repeat is drawn normally, with no doubled ring — §6.11 case 3")
    func nonAdjacentRepeatIsNotATwin() {
        let tiles = tiles([
            Self.probe(7, .admit, at: 0), Self.probe(8, .reject, at: 1),
            Self.probe(7, .admit, at: 2),
        ])
        #expect(tiles.allSatisfy { $0.twinGroup == nil })
        #expect(tiles[3].ring == .closed)
    }

    @Test("The ribbon is pinned to its trailing edge and re-pins on every append")
    func pinnedToTrailing() {
        var probes: [ProbeRecord] = []
        for id in 0..<5 {
            probes.append(Self.probe(id, .admit, at: id))
            let tiles = tiles(probes)
            #expect(tiles.pinnedIndex == tiles.count - 1)
        }
    }

    @Test("Two lanes wrap with a return elbow on the large device, one lane never wraps")
    func lanesAndElbows() {
        let probes = (0..<20).map { Self.probe($0, .admit, at: $0) }
        let single = RibbonLayoutModel(tiles: tiles(probes), lanes: 1, perLane: 7)
        let double = RibbonLayoutModel(tiles: tiles(probes), lanes: 2, perLane: 8)

        #expect(single.lane(of: 12) == 0)
        #expect(single.wrapsAfter(index: 6) == false)  // it scrolls; it does not wrap
        #expect(double.lane(of: 0) == 0)
        #expect(double.lane(of: 9) == 1)
        #expect(double.wrapsAfter(index: 7))  // return elbow at the lane boundary
        #expect(double.wrapsAfter(index: 6) == false)
    }

    @Test("Verdict sort blocks admits then rejects, keeps chain order, drops the link arcs")
    func verdictSort() {
        let probes = [
            Self.probe(1, .reject, at: 0), Self.probe(2, .admit, at: 1),
            Self.probe(3, .reject, at: 2), Self.probe(4, .admit, at: 3),
        ]
        let sorted = RibbonTileModel.verdictSorted(tiles(probes))
        #expect(sorted.compactMap(\.verdict) == [.admit, .admit, .reject, .reject])
        // Chain order preserved inside each block: ids 2, 4 then 1, 3.
        #expect(sorted.filter { $0.verdict != nil }.map(\.id) == [2, 4, 1, 3])
        #expect(sorted.allSatisfy { $0.drawsLinkArc == false })
        #expect(sorted.contains { $0.ring == .doubled } == false)  // no twins in this corpus
        // The seed keeps its place at the head: it has no verdict to sort by, and moving it
        // would make the sorted ribbon claim the round began with an admit.
        #expect(sorted[0].isSeed)
    }

    /// A twin's rings survive the sort — the pair is one experiment however the tiles are laid
    /// out, and the doubled ring is what says so.
    @Test("Verdict sort keeps twin rings and twin groups")
    func verdictSortKeepsTwins() {
        let sorted = RibbonTileModel.verdictSorted(
            tiles([
                Self.probe(7, .admit, at: 0), Self.probe(7, .reject, twin: true, at: 1),
            ]))
        #expect(sorted.contains { $0.ring == .split })
        #expect(sorted.filter { $0.twinGroup != nil }.count == 2)
    }
}
