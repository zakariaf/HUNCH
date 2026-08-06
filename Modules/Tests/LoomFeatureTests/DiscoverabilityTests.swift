import Testing

import Glyphs
import HunchUI
import Laws
import LoomFeature
import ModulesTestSupport
import Rounds

/// §6.6's five wordless layers, asserted band by band.
///
/// The claim under test is **not** "each layer exists" — the component suites already prove
/// that — but that no layer is band-conditional. A layer that appeared only where the law is
/// contextual would announce the family it exists to make findable, and the game would be
/// teaching by leaking instead of by structure.
@Suite("Discoverability layers 1–5 are present in every band", .tags(.unit, .presubmission))
@MainActor
struct DiscoverabilityTests {

    private static func probe(_ id: Int, _ verdict: Verdict, twin: Bool = false, at index: Int)
        -> ProbeRecord
    {
        ProbeRecord(index: UInt8(index), glyphID: UInt8(id), verdict: verdict, isTwin: twin)
    }

    @Test(
        "Layer 1 — the seed glyph is in the throat, ghost-framed, before probe 1",
        arguments: Band.allCases)
    func layer1SeedGlyph(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.draft == Fixtures.seedGlyph)
        #expect(round.probesUsed == 0)
        let tiles = RibbonTileModel.tiles(
            probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
        #expect(tiles[0].isSeed)
        #expect(tiles[0].wearsGhostMark)
    }

    @Test(
        "Layer 2 — the trailing-most tile wears the ghost mark at every probe count",
        arguments: Band.allCases)
    func layer2GhostMark(_ band: Band) {
        let round = Fixtures.round(band: band)
        for step in 0..<6 {
            let tiles = RibbonTileModel.tiles(
                probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
            #expect(tiles.filter(\.wearsGhostMark).count == 1, "probe \(step)")
            #expect(tiles[tiles.count - 1].wearsGhostMark, "probe \(step)")
            round.probe(Deck.glyph(id: step))
            round.landVerdict()
            round.endVerdictBeat()
        }
    }

    @Test("Layer 3 — the twin key is live from probe 0 in every band", arguments: Band.allCases)
    func layer3TwinKey(_ band: Band) {
        let round = Fixtures.round(band: band)
        #expect(round.isTwinAvailable)
        round.probeTwin()
        #expect(round.probesUsed == 1)
    }

    @Test(
        "Layer 4 — a twin whose verdicts differ draws SPLIT, in every band",
        arguments: Band.allCases)
    func layer4SplitRing(_ band: Band) {
        let agreeing = RibbonTileModel.tiles(
            probes: [
                Self.probe(7, .admit, at: 0), Self.probe(7, .admit, twin: true, at: 1),
            ], seedGlyph: Fixtures.seedGlyph)
        let differing = RibbonTileModel.tiles(
            probes: [
                Self.probe(7, .admit, at: 0), Self.probe(7, .reject, twin: true, at: 1),
            ], seedGlyph: Fixtures.seedGlyph)
        #expect(agreeing[agreeing.count - 1].ring == .doubled)
        #expect(differing[differing.count - 1].ring == .split)
        // The band is not an input to either answer, which is the layer's whole safety.
        #expect(band.rawValue > 0)
    }

    @Test(
        "Layer 5 — the verdict sort is reachable from probe 0 in every band",
        arguments: Band.allCases)
    func layer5VerdictSort(_ band: Band) {
        let round = Fixtures.round(band: band)
        round.toggleSpool()
        round.toggleSpool()
        #expect(round.sheet == .verdictSorted)
        #expect(round.probesUsed == 0)
    }

    /// The invariant behind all five, stated where it can actually be violated. `Round` is the
    /// one type in the chain that *knows* its band — it needs `par` and `cap` — so it is the one
    /// type that could branch on it. The same gesture sequence must leave every affordance in
    /// the same state at every band.
    @Test("The same gestures leave the same affordances in every band")
    func affordancesAreBandIndependent() {
        struct Affordances: Hashable {
            let twinAvailable: Bool
            let sheetReachable: Bool
            let sheetSorted: Bool
            let ghostMarkIndex: Int
            let ghostMarkCount: Int
            let breathing: Bool
        }

        let observed = Set(
            Band.allCases.map { band -> Affordances in
                let round = Fixtures.round(band: band)
                for id in 0..<3 {
                    round.probe(Deck.glyph(id: id))
                    round.landVerdict()
                    round.endVerdictBeat()
                }
                round.toggleSpool()
                round.toggleSpool()
                let tiles = RibbonTileModel.tiles(
                    probes: round.ribbon.probes, seedGlyph: round.seedGlyph)
                return Affordances(
                    twinAvailable: round.isTwinAvailable,
                    sheetReachable: round.sheet != .closed,
                    sheetSorted: round.sheet == .verdictSorted,
                    ghostMarkIndex: tiles.firstIndex(where: \.wearsGhostMark) ?? -1,
                    ghostMarkCount: tiles.filter(\.wearsGhostMark).count,
                    breathing: round.isBreathing)
            })

        #expect(observed.count == 1)  // one distinct answer across all eight bands
    }

    /// The breath is the one affordance whose *rule* mentions par, so it is the one that could
    /// be band-conditional without anybody noticing. It is not: the rule is the same fraction
    /// everywhere, and the three probes above are below 0.6·par in every band.
    @Test("The breath's rule is the same fraction in every band", arguments: Band.allCases)
    func theBreathRuleIsUniform(_ band: Band) {
        let threshold = Int((0.6 * Double(band.par)).rounded(.down))
        #expect(Round.breathes(probesUsed: threshold, par: band.par, twinEverUsed: false) == false)
        #expect(Round.breathes(probesUsed: threshold + 1, par: band.par, twinEverUsed: false))
        #expect(
            Round.breathes(probesUsed: band.cap, par: band.par, twinEverUsed: true) == false)
    }
}
