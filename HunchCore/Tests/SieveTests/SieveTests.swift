import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws
import Sieve

/// §9.2–§9.4. The invariant that makes the mode playable at all is that **at most one glyph is
/// ever actionable** — and it holds by arithmetic, at every speed, rather than by a guard.
@Suite("SIEVE's stream", .tags(.unit, .presubmission))
struct SieveStreamTests {

    @Test("§9.3's band table reproduces row for row")
    func theTable() {
        #expect(SieveStream.curves.count == 6)
        let rows: [(Band, Double, Double, Int, Int, Int, Int)] = [
            (.literal, 1.00, 1.60, 60, 12, 33, 15),
            (.pair, 1.10, 1.75, 64, 12, 36, 16),
            (.exclusive, 1.20, 1.90, 68, 12, 39, 17),
            (.relational, 1.30, 2.05, 72, 12, 42, 18),
            (.contextual, 1.40, 2.20, 76, 12, 45, 19),
            (.guarded, 1.45, 2.35, 80, 12, 48, 20),
        ]
        for (band, start, end, length, tell, body, runOut) in rows {
            let curve = SieveStream.curve(for: band)
            #expect(curve?.startRate == start)
            #expect(curve?.endRate == end)
            #expect(curve?.length == length)
            #expect(curve?.tell == tell)
            #expect(curve?.body == body)
            #expect(curve?.runOut == runOut)
        }
    }

    /// §9.4's decision: the body is **the remainder**, so the three reaches partition the stream
    /// exactly. `12 + 0.60·N + 0.25·N` equals `N` only at `N = 80`; every other band was
    /// over-subscribed, band 1 by three glyphs.
    @Test("The three reaches partition the stream exactly", arguments: SieveStream.curves)
    func reachesPartition(_ curve: SieveStream.BandCurve) {
        #expect(curve.tell + curve.body + curve.runOut == curve.length)
        #expect(curve.runOut == Int((0.25 * Double(curve.length)).rounded()))

        let stream = SieveStream(curve: curve)
        let counts = (0..<curve.length).reduce(into: [SieveStream.Reach: Int]()) {
            $0[stream.reach(at: $1), default: 0] += 1
        }
        #expect(counts[.tell] == curve.tell)
        #expect(counts[.body] == curve.body)
        #expect(counts[.runOut] == curve.runOut)
    }

    /// The hard invariant. Pitch is 132 pt and the gate is 88 pt, so the next glyph cannot enter
    /// the band before the current one leaves it — at **any** rate, because both are distances
    /// and the rate cancels.
    @Test("At most one glyph is ever actionable, at every speed")
    func oneActionableGlyph() {
        #expect(SieveStream.pitch > SieveStream.gateHeight)
        for curve in SieveStream.curves {
            for step in SieveStream.tempoSteps {
                let stream = SieveStream(curve: curve, tempoStep: step)
                for index in 0..<curve.length {
                    let travelBetweenGlyphs =
                        SieveStream.pitch
                        / (stream.rate(at: index) * SieveStream.pitch)
                    #expect(travelBetweenGlyphs > stream.actionableWindow(at: index))
                }
            }
        }
    }

    /// §9.3's worked worst case: band 6 at `s = 3` gives `r₁ = 2.95 g/s`, a 226 ms window and
    /// 1.10 s of total decision time from first sight to last chance.
    @Test("The fastest shipped configuration is band 6 at tempo step 3")
    func theFastestConfiguration() {
        let stream = SieveStream(curve: SieveStream.curves[5], tempoStep: 3)
        #expect(abs(stream.endRate - 2.95) < 1e-9)
        let window = stream.actionableWindow(at: stream.curve.length)
        #expect(abs(window - 0.226) < 0.002)
        let decision = window + stream.preview(at: stream.curve.length)
        #expect(abs(decision - 1.10) < 0.02)
    }

    /// Punishing an unlearnable prefix would be dishonest: the tell resolves visibly — that is
    /// how the player learns — and costs no foul.
    @Test("Fouls do not accrue during the tell", arguments: SieveStream.curves)
    func tellIsFoulFree(_ curve: SieveStream.BandCurve) {
        let stream = SieveStream(curve: curve)
        #expect((0..<curve.tell).allSatisfy { !stream.accruesFouls(at: $0) })
        #expect((curve.tell..<curve.length).allSatisfy { stream.accruesFouls(at: $0) })
        #expect(SieveStream.Reach.tell.weight == 0.5)
    }

    /// Bands 7 and 8 are absent by construction: neither is learnable from a passive stream in
    /// 45 seconds, and serving them would teach the player only that SIEVE is arbitrary.
    @Test("SIEVE serves bands 1–6 and ability above that goes into the tempo step")
    func bandCeiling() {
        #expect(SieveStream.curve(for: .composite) == nil)
        #expect(SieveStream.curve(for: .systemic) == nil)
        #expect(SieveStream.tempoSteps == 0...3)
    }
}

/// §9.6's scoring, and the correction it carries: `ratio` over **resolved** glyphs.
@Suite("SIEVE's scoring", .tags(.unit, .presubmission))
struct SieveScoringTests {

    private func resolved(
        _ outcomes: [SieveScoring.Outcome], lawful: [Bool], tellCount: Int = 0
    ) -> [SieveScoring.Resolved] {
        outcomes.enumerated().map { index, outcome in
            SieveScoring.Resolved(
                outcome: outcome, lawful: lawful[index],
                weight: index < tellCount ? 0.5 : 1.0, inTell: index < tellCount)
        }
    }

    @Test("A flawless sieved run is 1000 and three marks")
    func flawless() {
        let outcomes = Array(repeating: SieveScoring.Outcome.hit, count: 10)
        let result = SieveScoring.score(
            resolved: resolved(outcomes, lawful: Array(repeating: true, count: 10)),
            length: 10)
        #expect(result.ratio == 1)
        #expect(result.completion == 1)
        #expect(result.score == 1_000)
        #expect(result.marks == 3)
        #expect(result.isSuccess)
        #expect(result.inscribes)
    }

    /// The correction, measured. A flawless player fouling out at glyph 20 of 76 keeps their
    /// accuracy and is charged once for reach — the old normalisation squared the penalty and
    /// scored them at about 69.
    @Test("Accuracy and reach are charged exactly once each")
    func ratioIsOverResolved() {
        let outcomes = Array(repeating: SieveScoring.Outcome.hit, count: 20)
        let result = SieveScoring.score(
            resolved: resolved(outcomes, lawful: Array(repeating: true, count: 20)),
            length: 76)
        #expect(result.ratio == 1)  // accuracy over what was actually seen
        #expect(abs(result.completion - 20.0 / 76.0) < 1e-9)
        #expect(result.score == 263)

        // What the old normalisation would have given: completion appears twice, once inside
        // `ratio` and once beside it.
        let squared = Int((1_000 * result.completion * result.completion).rounded())
        #expect(squared == 69)
        #expect(Double(result.score) / Double(squared) > 3.5)
    }

    /// §9.5's argument that both degenerate strategies are strictly dominated: tap-nothing
    /// survives the whole run and lands below the one-mark threshold.
    @Test("Tap-nothing completes the run and still fails")
    func tapNothingIsDominated() {
        // A law admitting 40 % of the stream: 24 misses, 36 correct passes over 60 glyphs.
        var outcomes: [SieveScoring.Outcome] = []
        var lawful: [Bool] = []
        for index in 0..<60 {
            let isLawful = index % 5 < 2
            outcomes.append(isLawful ? .miss : .correctPass)
            lawful.append(isLawful)
        }
        let result = SieveScoring.score(
            resolved: resolved(outcomes, lawful: lawful, tellCount: 12), length: 60)
        #expect(result.sieved)
        #expect(result.marks == 0)
        #expect(result.ratio < 0.60)
        #expect(result.isSuccess == false)
    }

    /// Three fouls end a run; misses never do. A miss is caution and a foul is a false claim.
    @Test("The foul limit is three, and it is the only thing that ends a run early")
    func theFoulLimit() {
        #expect(SieveScoring.foulLimit == 3)
        let outcomes: [SieveScoring.Outcome] = [.foul, .foul, .foul]
        let result = SieveScoring.score(
            resolved: resolved(outcomes, lawful: [false, false, false], tellCount: 0),
            length: 60)
        #expect(result.foulsOutsideTell == 3)
        #expect(result.sieved == false)
        #expect(result.ratio == 0)  // raw is negative and clamps at zero
    }

    /// Marks read off `yield` rather than `ratio`, so reach is charged to the mark too — and on
    /// a sieved run the two are equal, which is what makes the thresholds the ones they were
    /// calibrated as.
    @Test("On a sieved run yield equals ratio, so the thresholds are the calibrated ones")
    func marksReadYield() {
        var outcomes = Array(repeating: SieveScoring.Outcome.hit, count: 9)
        outcomes.append(.miss)
        let lawful = Array(repeating: true, count: 10)
        let sieved = SieveScoring.score(resolved: resolved(outcomes, lawful: lawful), length: 10)
        #expect(sieved.completion == 1)
        #expect(sieved.yield == sieved.ratio)
        #expect(sieved.marks == 2)  // 0.9 ratio: past 0.80, short of 0.92

        let partial = SieveScoring.score(
            resolved: resolved(outcomes, lawful: lawful), length: 20)
        #expect(partial.ratio == sieved.ratio)
        #expect(partial.marks < sieved.marks)  // same accuracy, half the reach
    }
}

/// §9.5's lifecycle and §9.8's void allowance.
@Suite("SIEVE's lifecycle", .tags(.unit, .presubmission))
struct SievePhaseTests {

    @Test("A run reaches the reveal three ways and only three")
    func threeEndings() {
        #expect(SievePhase.advance(.streaming(.runOut), on: .streamResolved) == .reveal)
        #expect(SievePhase.advance(.fouling, on: .freezeComplete) == .reveal)
        #expect(SievePhase.advance(.paused, on: .abandonConfirmed) == .reveal)
    }

    /// Abandoning is the only two-tap action in the game and is reachable **only from a stopped
    /// stream**: a confirmation on a moving conveyor is a confirmation nobody reads.
    @Test("Abandon is reachable only from paused")
    func abandonNeedsAStoppedStream() {
        #expect(SievePhase.advance(.streaming(.body), on: .abandonConfirmed) == nil)
        #expect(SievePhase.advance(.paused, on: .abandonConfirmed) == .reveal)
    }

    /// A stream that resumed at full speed would charge the player for the pause.
    @Test("Resuming runs up over three glyphs")
    func theRunUp() {
        #expect(SievePhase.runUpGlyphs == 3)
        #expect(SievePhase.advance(.paused, on: .resumed) != nil)
    }

    /// Being told would turn the run-out's fine discrimination into an announced exam.
    @Test("The reach boundary crosses with no cue")
    func reachChangeIsSilent() {
        #expect(SievePhase.reachChangeIsInvisible)
        #expect(
            SievePhase.advance(.streaming(.tell), on: .reachChanged(.body))
                == .streaming(.body))
    }

    /// A terminated run is not automatically a loss, and it is not free either.
    @Test("Two consecutive voids are forgiven; the third is scored")
    func voidAllowance() {
        #expect(SieveVoid.isScored(consecutiveVoids: 1) == false)
        #expect(SieveVoid.isScored(consecutiveVoids: 2) == false)
        #expect(SieveVoid.isScored(consecutiveVoids: 3))
        // An abandon is always scored: there the exit is a confirmed choice, not an
        // interruption, and the confirmation exists precisely to make that distinction.
        #expect(SieveVoid.abandonIsScored)
    }
}
