import Testing

import Bench
import Glyphs
import HunchTestSupport
import Laws

/// §4.3's bar. The interesting property is not *that* it bars but that it knows **which rail**:
/// a pulse on the wrong rail is worse than no pulse, because it sends the player to edit
/// something that was already fine.
@Suite("The machined bar", .tags(.unit, .presubmission))
struct SealBarTests {

    private static let ready = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
    private static let tautology = Law(
        .coupled(
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b0111))), .or,
            .atom(.init(attribute: .shape, subset: Fixture.subset(0b1100)))))

    @Test("An empty Bench is barred")
    func emptyIsBarred() {
        #expect(SealBar.reason(rails: [], extension: nil) == .empty)
        #expect(SealBar.reason(rails: [.empty, .empty], extension: nil) == .empty)
    }

    @Test("A ready draft is not barred")
    func readyIsUnbarred() {
        #expect(SealBar.reason(rails: [.ready], extension: Self.ready.table) == nil)
        #expect(SealBar.reason(rails: [.ready, .empty], extension: Self.ready.table) == nil)
    }

    /// The reading order is the rail order, so the rail that pulses is the one nearest the edit
    /// the player just made rather than the lowest-numbered fault in the whole Bench.
    @Test("The offending rail is the first one that is not ready")
    func theFirstFaultWins() {
        #expect(
            SealBar.reason(rails: [.ready, .inert], extension: Self.ready.table)
                == .inertRail(index: 1))
        #expect(
            SealBar.reason(rails: [.unboundSocket, .inert], extension: Self.ready.table)
                == .unboundSocket(index: 0))
        #expect(
            SealBar.offendingRail(SealBar.reason(rails: [.ready, .inert], extension: nil)) == 1)
    }

    /// §4.4's one genuine over-reach: the Bench can build a draft whose extension is constant,
    /// and the Seal is barred for exactly those. The Assay is already showing it as all-lit or
    /// all-dark, so the bar and the picture agree without either quoting the other.
    @Test("A constant extension is barred even though every rail is ready")
    func constantExtensionIsBarred() {
        #expect(Self.tautology.table.isConstant)
        #expect(
            SealBar.reason(rails: [.ready], extension: Self.tautology.table)
                == .constantExtension)
        // …and no rail pulses, because a constant extension is not any one rail's doing and
        // pulsing an arbitrary one teaches the player to look in the wrong place.
        #expect(SealBar.offendingRail(.constantExtension) == nil)
    }

    /// The bar and the generator's guardrails must agree about "constant", or a law G1 and G2
    /// accepted could be one the Seal refuses to let the player state.
    @Test("The bar's constancy is the table's own G1/G2 predicate")
    func constancyIsTheTables() {
        #expect(SealBar.isConstant(Self.tautology.table))
        #expect(SealBar.isConstant(Self.ready.table) == false)
        #expect(Self.ready.table.isSatisfiable && Self.ready.table.isFalsifiable)
    }
}
