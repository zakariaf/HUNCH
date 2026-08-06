import Testing

import Drift
import Glyphs
import HunchTestSupport
import Laws

/// §7.4's lifecycle. The row that carries the whole mode is `runningPre → runningPost`: the law
/// changes and **nothing visible does**.
@Suite("DRIFT's lifecycle", .tags(.unit, .presubmission))
struct DriftPhaseTests {

    @Test("Every row of §7.4's table")
    func theTable() {
        let rows: [(DriftPhase, DriftPhase.Event, DriftPhase)] = [
            (.arming, .generated, .priming),
            (.priming, .firstDialCommit, .runningPre),
            (.runningPre, .hingeFired, .runningPost),
            (.runningPre, .capturedFirstLaw, .runningPost),
            (.runningPre, .declaredWrong, .struck),
            (.runningPost, .declaredSecondLaw, .hinge),
            (.runningPost, .declaredFirstLawAfterHinge, .struck),
            (.runningPost, .declaredWrong, .struck),
            (.struck, .secondStrike, .hinge),
            (.runningPre, .capReached, .hinge),
            (.runningPost, .capReached, .hinge),
            (.hinge, .revealComplete, .settled),
        ]
        for (from, event, to) in rows {
            #expect(DriftPhase.advance(from, on: event) == to)
        }
    }

    /// Trigger (b) is a *transition*, not an ending: the player is told they were right, the
    /// Bench slides away, and the round continues. Without it a fast player solves `L₁` before
    /// the hinge and never experiences DRIFT, so the mode's presence would be a function of how
    /// good they are at PROBE.
    @Test("Capturing the first law moves the floor and does not end the round")
    func captureContinues() {
        #expect(DriftPhase.advance(.runningPre, on: .capturedFirstLaw) == .runningPost)
        #expect(DriftPhase.advance(.runningPre, on: .declaredSecondLaw) == nil)
    }

    /// If any interface element changed at the hinge, the interface would be announcing the
    /// change and the mode would measure reading rather than noticing.
    @Test("DRIFT adds no controls, no chrome and no timer")
    func noChrome() {
        #expect(DriftPhase.addsNoChrome)
    }

    @Test("Settled is terminal and arming accepts only its own event")
    func endsAreClosed() {
        for event in [
            DriftPhase.Event.generated, .hingeFired, .declaredSecondLaw, .capReached,
            .revealComplete,
        ] {
            #expect(DriftPhase.advance(.settled, on: event) == nil)
        }
        #expect(DriftPhase.advance(.arming, on: .firstDialCommit) == nil)
    }
}

/// §7.6's step 0. The counterexample the player most needs is one they have **already seen give
/// the other answer**.
@Suite("The dead-law counterexample", .tags(.unit, .presubmission))
struct DeadLawCounterexampleTests {

    private static let triangles = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
    private static let trianglesAndSquares = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0110))))

    @Test("It prefers a ribbon glyph the two laws disagree about")
    func prefersARibbonMember() {
        let square = Deck.glyph(id: 32)  // shape ordinal 2
        let triangle = Deck.glyph(id: 16)
        let ribbon = [triangle, square]
        let choice = DeadLawCounterexample.select(
            first: Self.trianglesAndSquares, second: Self.triangles, ribbon: ribbon,
            seedGlyph: triangle)
        #expect(choice == square)
    }

    /// Tie-break by **most recent** ribbon index: the glyph the player looked at last is the one
    /// they still remember the answer to.
    @Test("It tie-breaks toward the most recent probe")
    func mostRecentWins() {
        let first = Deck.glyph(id: 32)
        let second = Deck.glyph(id: 34)
        let choice = DeadLawCounterexample.select(
            first: Self.trianglesAndSquares, second: Self.triangles,
            ribbon: [first, second], seedGlyph: Deck.glyph(id: 16))
        #expect(choice == second)
    }

    /// Falls through to canon's ordinary rule when the ribbon holds nothing that disagrees —
    /// which is a real case, not a defensive one: a player can drift without ever probing a
    /// glyph the edit touches.
    @Test("With no disagreeing ribbon member it declines rather than inventing one")
    func fallsThrough() {
        let choice = DeadLawCounterexample.select(
            first: Self.trianglesAndSquares, second: Self.triangles,
            ribbon: [Deck.glyph(id: 16)], seedGlyph: Deck.glyph(id: 16))
        #expect(choice == nil)
    }

    /// A fast loss still teaches the mode's shape rather than looking like a PROBE round the
    /// player got wrong.
    @Test("A loss before the hinge still reveals the un-fired second law")
    func aFastLossStillTeaches() {
        #expect(DeadLawCounterexample.unfiredSecondLawOpacity == 0.40)
    }
}
