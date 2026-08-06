import Testing

import Bench
import Glyphs
import HunchTestSupport
import Laws

/// §4.3's two claims that a drawing could quietly break: the live grid is a **slice** of the
/// pair table rather than a projection of it, and the evidence overlay is gated at band 4.
@Suite("The Assay", .tags(.unit, .presubmission))
struct AssayTests {

    private static let contextual = Law(
        .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
    private static let stateless = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))

    @Test("The grid is the whole deck in canonical order")
    func geometryIsMemorable() {
        #expect(Assay.side * Assay.side == Assay.cellCount)
        #expect(Assay.cellCount == Deck.all.count)
        #expect(Assay.position(of: 0) == (row: 0, column: 0))
        #expect(Assay.position(of: 17) == (row: 1, column: 1))
        #expect(Assay.position(of: 255) == (row: 15, column: 15))
    }

    /// The load-bearing one. For a contextual draft the lit count is the **row** count for the
    /// pinned `prev`; quoting the unconditional marginal instead makes a contextual draft look
    /// stateless, which is the single fact the tool exists to make visible.
    @Test("A contextual draft's constellation morphs when the pin scrubs")
    func theGridIsASliceNotAProjection() {
        // Four pins that differ in PIPS — the attribute this law reads. Ids 0/64/128/192 all
        // share pips rank 1 and would agree, which would make this test pass while asserting
        // nothing about conditioning.
        let pins = [0, 4, 8, 12].map { Deck.glyph(id: $0) }
        let counts = pins.map { Assay.live(for: Self.contextual, pinned: $0).litCount }
        #expect(Set(counts).count > 1)

        // …and the average of the slices is the projection, which is a different picture.
        let pairs = Deck.all.reduce(0) {
            $0 + Assay.live(for: Self.contextual, pinned: $1).litCount
        }
        #expect(counts.contains { $0 * 256 != pairs })
    }

    @Test("A stateless draft's constellation is the same at every pin")
    func statelessDraftsDoNotMorph() {
        let counts = [0, 99, 255].map {
            Assay.live(for: Self.stateless, pinned: Deck.glyph(id: $0)).lit
        }
        #expect(Set(counts).count == 1)
        #expect(counts[0].count == 64)  // one shape of four, across 64 glyphs each
    }

    /// §4.3: unsatisfiability and tautology are visible *instantly and unmistakably*, with no
    /// message — all dark and all lit. The Seal is barred for exactly these two.
    @Test("All dark and all lit are the two constant drafts")
    func constantDraftsAreVisible() {
        let dark = Assay(lit: .empty, pinned: Deck.glyph(id: 0))
        let full = Assay(lit: .full, pinned: Deck.glyph(id: 0))
        #expect(dark.isUnsatisfiable)
        #expect(dark.admitRate == 0)
        #expect(full.isTautology)
        #expect(full.admitRate == 1)
        #expect(Assay.live(for: Self.stateless, pinned: Deck.glyph(id: 0)).isUnsatisfiable == false)
    }

    @Test("The evidence overlay unlocks at band 4, not band 1", arguments: Band.allCases)
    func evidenceGate(_ band: Band) {
        #expect(AssayEvidence.isUnlocked(band: band) == (band >= .relational))
        // Two deliberate early opens: the Anomaly is meant to be a different experience, and
        // §10.7's floor rescue opens the tool permanently for a player the ladder has failed.
        #expect(AssayEvidence.isUnlocked(band: band, isAnomaly: true))
        #expect(AssayEvidence.isUnlocked(band: band, floorRescueGranted: true))
    }

    /// A probe judged after a *different* `prev` is evidence about a different row. Folding it
    /// into this row would flash a contradiction the player has not created.
    @Test("The overlay only counts probes taken at the pinned context")
    func evidenceIsPerRow() {
        let pin = Deck.glyph(id: 0)
        let other = Deck.glyph(id: 200)
        let probe = Deck.glyph(id: 7)
        let transcript = [
            (glyph: probe, previous: pin, verdict: Verdict.admit),
            (glyph: probe, previous: other, verdict: Verdict.reject),
        ]
        let overlay = AssayEvidence.overlay(
            draft: Self.contextual, pinned: pin, transcript: transcript)
        #expect(overlay.probed.count == 1)
        #expect(overlay.probed.contains(probe.id))
    }

    @Test("A draft that disagrees with the transcript is contradicted")
    func contradictionIsDetected() {
        let pin = Deck.glyph(id: 0)
        let triangle = Deck.glyph(id: 22)
        let agreeing = AssayEvidence.overlay(
            draft: Self.stateless, pinned: pin,
            transcript: [(glyph: triangle, previous: pin, verdict: .admit)])
        #expect(agreeing.isConsistent)

        let disagreeing = AssayEvidence.overlay(
            draft: Self.stateless, pinned: pin,
            transcript: [(glyph: triangle, previous: pin, verdict: .reject)])
        #expect(disagreeing.isConsistent == false)
        #expect(disagreeing.contradicted.contains(triangle.id))
    }
}
