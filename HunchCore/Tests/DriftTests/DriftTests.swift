import Foundation
import Testing

import Drift
import Glyphs
import HunchTestSupport
import Laws

/// §7.7's budget. The claim it encodes is that **the second induction costs less than the
/// first**: the family is known and the search collapses to the one-leaf neighbourhood, so
/// `par_DRIFT` is `par + rec`, not `2 · par`.
@Suite("DRIFT's budget", .tags(.unit, .presubmission))
struct DriftBudgetTests {

    /// §7.7's locked table, row for row.
    @Test("The published par/cap table reproduces exactly")
    func theTable() {
        let rows: [(Band, Int, Int, Int, Int)] = [
            (.exclusive, 9, 25, 40, 13),
            (.relational, 9, 29, 47, 16),
            (.contextual, 9, 32, 52, 19),
            (.guarded, 9, 32, 52, 19),
            (.composite, 11, 37, 60, 21),
            (.systemic, 11, 40, 64, 24),
        ]
        for (band, recovery, par, cap, forced) in rows {
            #expect(DriftBudget.recovery(band) == recovery)
            #expect(DriftBudget.par(band) == par)
            #expect(DriftBudget.cap(band) == cap)
            #expect(DriftBudget.forcedHinge(band) == forced)
        }
    }

    /// §7.2: bands 1–2 have no rows, and that is structural — the hinge cannot fire inside
    /// `0.80 · par` at those bands.
    @Test("Bands 1 and 2 have no DRIFT budget at all")
    func lowBandsAreAbsent() {
        #expect(DriftBudget.par(.literal) == nil)
        #expect(DriftBudget.cap(.pair) == nil)
        #expect(DriftBudget.forcedHinge(.literal) == nil)
        #expect(DriftBudget.bands.count == 6)
        #expect(DriftBudget.bands.contains(.literal) == false)
    }

    /// The second induction is cheaper than a second round would be.
    @Test("par_DRIFT is par + rec, and always well under twice par", arguments: DriftBudget.bands)
    func theSecondInductionIsCheaper(_ band: Band) {
        let par = DriftBudget.par(band) ?? 0
        #expect(par == band.par + (DriftBudget.recovery(band) ?? 0))
        #expect(par < 2 * band.par)
    }

    /// The forced hinge is measured against the **first** induction's par, not the drift par:
    /// it exists to guarantee the drift happens while the player is still forming their first
    /// theory, and `0.80 · par_DRIFT` would land after they had already finished it.
    @Test("The forced hinge is measured against par, not par_DRIFT", arguments: DriftBudget.bands)
    func forcedHingeUsesTheFirstPar(_ band: Band) {
        let forced = DriftBudget.forcedHinge(band) ?? 0
        #expect(forced == Int((0.80 * Double(band.par)).rounded(.up)))
        #expect(forced < band.par)
        // Against par_DRIFT it would land after the player had already finished their first
        // induction, which is the opposite of what the trigger is for.
        #expect(forced < Int((0.80 * Double(DriftBudget.par(band) ?? 0)).rounded(.up)))
    }

    /// §6.2's sheet is sized against `max(cap, cap_DRIFT) + 1 = 65`. The number that has to fit
    /// is here; the grid that holds it is in `Modules`.
    @Test("The longest possible DRIFT transcript is 64 probes plus the seed")
    func theWorstCaseTranscript() {
        let worst = DriftBudget.bands.compactMap(DriftBudget.cap).max() ?? 0
        #expect(worst == 64)
        #expect(worst + 1 == 65)
    }
}

/// §7.3's hinge. Trigger (b) is the design decision worth testing: without it, a fast player
/// solves `L₁` before the hinge and never experiences DRIFT at all.
@Suite("DRIFT's hinge", .tags(.unit, .presubmission))
struct DriftHingeTests {

    @Test("N_admits is U[3, 6] and is a function of the seed alone")
    func admitsBeforeHinge() {
        var seen: Set<Int> = []
        for seed in UInt64(0)..<200 {
            let value = DriftHinge.admitsBeforeHinge(seed: seed)
            #expect((3...6).contains(value))
            seen.insert(value)
        }
        #expect(seen == [3, 4, 5, 6])
        #expect(
            DriftHinge.admitsBeforeHinge(seed: 42) == DriftHinge.admitsBeforeHinge(seed: 42))
    }

    @Test("Satiation fires on the N-th admit under the first law")
    func satiation() {
        #expect(
            DriftHinge.trigger(
                probeIndex: 5, admitsUnderFirstLaw: 3, admitsBeforeHinge: 4,
                capturedFirstLaw: false, forcedAt: 13) == nil)
        #expect(
            DriftHinge.trigger(
                probeIndex: 6, admitsUnderFirstLaw: 4, admitsBeforeHinge: 4,
                capturedFirstLaw: false, forcedAt: 13) == .satiation)
    }

    /// Without trigger (b) the mode's presence would be a function of how good you are at PROBE.
    /// The declaration is **accepted** and the round continues: being told *yes, that was the
    /// law* and then finding that it is not is the mode stated in one gesture.
    @Test("Capture beats every other trigger and is the only one that leaves a seam")
    func capture() {
        #expect(
            DriftHinge.trigger(
                probeIndex: 1, admitsUnderFirstLaw: 0, admitsBeforeHinge: 6,
                capturedFirstLaw: true, forcedAt: 13) == .capture)
        #expect(DriftHinge.writesSeamMarker(.capture))
        #expect(DriftHinge.writesSeamMarker(.satiation) == false)
        #expect(DriftHinge.writesSeamMarker(.forced) == false)
    }

    /// An unlucky run still gets the mode.
    @Test("The forced hinge fires when the admits never arrive")
    func forced() {
        #expect(
            DriftHinge.trigger(
                probeIndex: 13, admitsUnderFirstLaw: 1, admitsBeforeHinge: 6,
                capturedFirstLaw: false, forcedAt: 13) == .forced)
    }

    /// The chain is unbroken; only the predicate changed. Resetting the context would add a
    /// second simultaneous change and make the mode measure two things at once.
    @Test("The hinge never resets the context")
    func contextSurvives() {
        #expect(DriftHinge.preservesContext)
    }
}

/// §7.2's pair guardrails. `L₂` is a one-leaf edit because a randomly re-rolled second law is
/// indistinguishable from "the round silently restarted".
@Suite("DRIFT's pair guardrails", .tags(.unit, .presubmission))
struct DriftPairTests {

    private static let triangles = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
    private static let trianglesAndSquares = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0110))))
    private static let hexagons = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b1000))))

    /// D1 — a pair that is the same law is not a drift.
    @Test("D1 — identical laws are rejected")
    func d1() {
        #expect(DriftPair.fault(first: Self.triangles, second: Self.triangles) == .identical)
    }

    /// D2 — too small to notice, or so large the round reads as a restart. A one-shape edit
    /// moves 64 of 256 glyphs, which is 0.25 and inside the window.
    @Test("D2 — the disagreement rate must sit inside [0.10, 0.30]")
    func d2() {
        // A one-shape narrowing moves 64 of 256 — 0.25, inside the window — and breaks 64
        // positives, so it clears D2 and D4 together.
        #expect(
            DriftPair.fault(first: Self.trianglesAndSquares, second: Self.triangles) == nil)

        // Two disjoint single-shape laws disagree about 128 of 256 — half the deck, which reads
        // as a different round rather than as a drift.
        let fault = DriftPair.fault(first: Self.triangles, second: Self.hexagons)
        if case .disagreementRate(let rate) = fault {
            #expect(rate == 0.5)
        } else {
            #expect(
                Bool(false), "expected a disagreement-rate fault, got \(String(describing: fault))")
        }
    }

    /// D4 — **the edit must be able to break a positive**, and the guardrail is *directional*.
    /// A drift that only widens is one the player's dead theory never contradicts: every glyph
    /// it admitted, the new law still admits, so nothing they believe is ever proved wrong and
    /// the mode measures nothing. The disagreement rate cannot see that — both directions have
    /// the identical rate — which is exactly why D4 exists beside D2 rather than inside it.
    @Test("D4 — a widening-only edit is rejected, though its disagreement rate is identical")
    func d4() {
        // triangles ⊂ triangles+squares: every glyph the first admits, the second admits too.
        #expect(
            DriftPair.brokenPositives(first: Self.triangles, second: Self.trianglesAndSquares)
                == 0)
        #expect(
            DriftPair.brokenPositives(first: Self.trianglesAndSquares, second: Self.triangles)
                == 64)

        #expect(
            DriftPair.fault(first: Self.triangles, second: Self.trianglesAndSquares)
                == .breaksNoPositives(0))
        #expect(DriftPair.fault(first: Self.trianglesAndSquares, second: Self.triangles) == nil)
        #expect(DriftPair.brokenPositiveFloor == 8)
    }
}
