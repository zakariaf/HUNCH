import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws
import Profile

/// §11.9. The property the whole table rests on is **monotonicity**: `§11.10` grows a vertex
/// radius with its axis value, so a strictly better transcript must never produce a smaller
/// sample — or the portrait would say the opposite of what the player did.
@Suite("The Profile's five axes", .tags(.unit, .presubmission))
struct ProfileSampleTests {

    @Test("Every sample lands in [0, 1]")
    func samplesAreBounded() {
        for band in Band.allCases {
            for solved in [true, false] {
                let sample = ProfileSample.induction(band: band, solved: solved)
                #expect((0...1).contains(sample))
            }
        }
        #expect((0...1).contains(ProfileSample.tempo(probes: 1, par: 29, solved: true)))
        #expect((0...1).contains(ProfileSample.tempo(probes: 400, par: 7, solved: false)))
        #expect(
            (0...1).contains(
                ProfileSample.retentionEcho(hit: 0, answerCount: 9, lawfulCount: 3)))
    }

    /// The monotonicity test §11.9 asks for, per axis.
    @Test("A strictly better transcript never produces a smaller sample")
    func monotoneInTheRightDirection() {
        // Induction: deeper band, larger sample; and a loss is worth less than a win.
        for band in Band.allCases where band != .systemic {
            let deeper = Band(rawValue: band.rawValue + 1) ?? .systemic
            #expect(
                ProfileSample.induction(band: deeper, solved: true)
                    > ProfileSample.induction(band: band, solved: true))
            #expect(
                ProfileSample.induction(band: band, solved: false)
                    <= ProfileSample.induction(band: band, solved: true))
        }

        // Tempo: fewer probes, larger sample — par OVER probes.
        #expect(
            ProfileSample.tempo(probes: 5, par: 20, solved: true)
                >= ProfileSample.tempo(probes: 15, par: 20, solved: true))
        #expect(
            ProfileSample.tempo(probes: 10, par: 20, solved: true)
                > ProfileSample.tempo(probes: 10, par: 20, solved: false))

        // Flexibility: recovering sooner, larger sample.
        #expect(
            ProfileSample.flexibility(latency: 4, par: 23, isDriftHinge: true)
                > ProfileSample.flexibility(latency: 16, par: 23, isDriftHinge: true))

        // Retention: more hits and fewer intrusions, larger sample.
        #expect(
            ProfileSample.retentionEcho(hit: 4, answerCount: 4, lawfulCount: 4)
                > ProfileSample.retentionEcho(hit: 4, answerCount: 6, lawfulCount: 4))
    }

    /// The orientation that would have been easy to get backwards. Canon names Tempo's quantity
    /// as `probes/par`; §11.10's geometry fixes the direction, and the other way round would
    /// draw the fastest player smallest.
    @Test("Tempo is par over probes, so the efficient player is pulled toward the vertex")
    func tempoIsOriented() {
        let efficient = ProfileSample.tempo(probes: 4, par: 20, solved: true)
        let wasteful = ProfileSample.tempo(probes: 40, par: 20, solved: true)
        #expect(efficient == 1)
        #expect(wasteful < 0.6)
    }

    /// §11.9's worked example, to the digit: band 5, `par = 23`, `R = 16`.
    @Test("The worked DRIFT flexibility sample reproduces exactly")
    func theWorkedExample() {
        let sample = ProfileSample.flexibility(latency: 16, par: 23, isDriftHinge: true)
        #expect(abs(sample - 0.303) < 0.001)
    }

    /// The ordering inside Restraint is the argument: a cap-loss with **zero strikes** scores
    /// above a win that took one, because restraint is declaring only once the evidence closes —
    /// and a player who never declared on a hunch showed more of it than one who declared twice.
    @Test("A clean cap-loss outranks a win that took a strike")
    func restraintOrdering() {
        #expect(
            ProfileSample.RestraintOutcome.capLossNoStrikes.rawValue
                > ProfileSample.RestraintOutcome.solvedAfterOneStrike.rawValue)
        #expect(
            ProfileSample.RestraintOutcome.solvedClean.rawValue
                > ProfileSample.RestraintOutcome.capLossNoStrikes.rawValue)
    }

    /// Bands 5 and 7 have no materialised stateless hypothesis set, so the margin is **skipped**
    /// rather than guessed — and Restraint falls back to `d` alone.
    @Test("Without a live hypothesis count Restraint uses the discrete term alone")
    func marginIsSkippedNotGuessed() {
        let skipped = ProfileSample.restraint(
            outcome: .solvedClean, liveHypotheses: nil, bandPopulation: 6_934)
        #expect(skipped == 1.0)

        let withMargin = ProfileSample.restraint(
            outcome: .solvedClean, liveHypotheses: 4, bandPopulation: 2_322)
        #expect(withMargin < 1.0)
        #expect(withMargin > 0.6)  // the discrete term still dominates at 0.6 weight
    }
}

/// §11.9's update rule — Robbins–Monro, and the **only** update rule for any axis.
@Suite("The Profile's update rule", .tags(.unit, .presubmission))
struct AxisStateTests {

    /// Fast while the portrait is unformed and slow once it is.
    @Test("Early samples move the value far; late ones move it little")
    func confidenceSlowsIt() {
        var young = AxisState()
        young.update(sample: 1.0, weight: 1.0)
        #expect(young.value == 1.0)  // α = 1 at n = 0: the first sample IS the value

        var old = AxisState(value: 0.5, n: 60)
        old.update(sample: 1.0, weight: 1.0)
        #expect(abs(old.value - (0.5 + 0.06 * 0.5)) < 1e-12)
    }

    /// The 0.06 floor is why the portrait never freezes: at maximum confidence a sample still
    /// moves it six per cent of the way.
    @Test("The alpha floor keeps a settled portrait responsive")
    func itNeverFreezes() {
        var state = AxisState(value: 0.2, n: AxisState.confidenceCeiling)
        let before = state.value
        for _ in 0..<40 { state.update(sample: 1.0, weight: 1.0) }
        #expect(state.value > before + 0.5)
        #expect(state.n == AxisState.confidenceCeiling)
    }

    /// **No decay of `value` toward anything.** Coming back after a long gap makes the portrait
    /// more responsive, not lower — a decay toward the mean would read as punishment for not
    /// playing, which is the same lever as a streak reminder.
    @Test("Idling decays confidence and never the value")
    func idlingDoesNotPunish() {
        var state = AxisState(value: 0.82, n: 60)
        state.decayConfidence(daysIdle: 120)
        #expect(state.value == 0.82)
        #expect(state.n == 15)

        state.decayConfidence(daysIdle: 10_000)
        #expect(state.n == 4)  // floored: it becomes responsive, never blank
        #expect(state.value == 0.82)
    }

    @Test("Weight scales both the step and the confidence gained")
    func weightIsHonoured() {
        var full = AxisState(value: 0, n: 10)
        var half = AxisState(value: 0, n: 10)
        full.update(sample: 1, weight: 1.0)
        half.update(sample: 1, weight: 0.5)
        #expect(full.value > half.value)
        #expect(full.n == 11)
        #expect(half.n == 10.5)
    }

    @Test("The value stays inside [0, 1] under any sample")
    func valueIsBounded() {
        var state = AxisState(value: 0.5, n: 3)
        state.update(sample: 9, weight: 1)
        #expect(state.value <= 1)
        state.update(sample: -4, weight: 1)
        #expect(state.value >= 0)
    }
}

/// §11.10. One rule carries the whole screen: radii are normalised against the player's own
/// five-axis mean, so the portrait **cannot grow**.
@Suite("The Profile's geometry", .tags(.unit, .presubmission))
struct ProfileGeometryTests {

    @Test("Five vertices, locked order, 72° apart from the top")
    func vertexOrder() {
        #expect(ProfileGeometry.vertexOrder.count == 5)
        #expect(ProfileGeometry.vertexOrder[0] == .induction)
        #expect(ProfileGeometry.angle(of: .induction) == -90)
        #expect(ProfileGeometry.angle(of: .tempo) == 198)
        #expect(Set(ProfileAxis.allCases) == Set(ProfileGeometry.vertexOrder))
    }

    /// The point of the whole design: a player who improves **everywhere** draws the identical
    /// silhouette, because they have not changed what kind of player they are.
    @Test("Improving on every axis does not change the shape")
    func thePortraitCannotGrow() {
        let modest = Dictionary(
            uniqueKeysWithValues: ProfileAxis.allCases.map { ($0, 0.30) })
        let excellent = Dictionary(
            uniqueKeysWithValues: ProfileAxis.allCases.map { ($0, 0.95) })

        let first = ProfileGeometry.radii(modest)
        let second = ProfileGeometry.radii(excellent)
        for axis in ProfileAxis.allCases {
            #expect(abs((first[axis] ?? 0) - (second[axis] ?? 0)) < 1e-9)
            #expect(abs((first[axis] ?? 0) - ProfileGeometry.baseRadius) < 1e-9)
        }
    }

    /// …and a player who is better at one thing draws a longer spoke there. That is the only
    /// comparison the Profile makes, and it is with themselves.
    @Test("An imbalance draws as an imbalance")
    func imbalanceShows() {
        var values = Dictionary(uniqueKeysWithValues: ProfileAxis.allCases.map { ($0, 0.4) })
        values[.tempo] = 0.9
        let radii = ProfileGeometry.radii(values)
        #expect((radii[.tempo] ?? 0) > ProfileGeometry.baseRadius)
        #expect((radii[.induction] ?? 0) < ProfileGeometry.baseRadius)
    }

    /// An unformed axis is **unknown**, not bad. Drawing it short would say the second, so it
    /// trembles instead.
    @Test("Low confidence trembles rather than shortens")
    func lowConfidenceTrembles() {
        #expect(ProfileGeometry.tremble(confidence: 0) == 1)
        #expect(ProfileGeometry.tremble(confidence: AxisState.confidenceCeiling) == 0)
        // The value, and therefore the radius, is untouched by confidence.
        let values = Dictionary(uniqueKeysWithValues: ProfileAxis.allCases.map { ($0, 0.5) })
        #expect(ProfileGeometry.radii(values)[.tempo] == ProfileGeometry.baseRadius)
    }

    @Test("A blank profile draws a regular pentagon rather than a point")
    func blankIsRegular() {
        let radii = ProfileGeometry.radii([:])
        #expect(radii.count == 5)
        #expect(radii.values.allSatisfy { $0 == ProfileGeometry.baseRadius })
    }
}
