import Foundation
import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws

/// §5.2 publishes a δ for each of its eight exemplars, and §5.1's five modifiers are what turn
/// a law into one. This suite is the only proof that the modifiers were read correctly — every
/// one of the eight must land within 0.001 of its published value.
@Suite("difficulty(of:)", .tags(.unit, .presubmission))
struct DifficultyTests {
    /// §5.1: the five maxima sum to EXACTLY 0.124, one tick short of the 0.125 band width.
    /// That is what makes "a law can never escape its band" a fact rather than an intention.
    @Test("The modifier ceiling is exactly 0.124, one tick under the band width")
    func modifierCeiling() {
        expectApproximatelyEqual(Difficulty.modifierCeiling, 0.124, absoluteTolerance: 1e-12)
        #expect(Difficulty.modifierCeiling < 0.125)
    }

    @Test("Every exemplar reproduces its published δ (§5.2)", arguments: Exemplar.all)
    func exemplarDifficultyMatches(_ exemplar: Exemplar) {
        let law = Law(exemplar.node)
        let delta = Difficulty.of(law, in: exemplar.band)
        expectApproximatelyEqual(
            delta, exemplar.publishedDelta, absoluteTolerance: 0.001,
            "\(exemplar.band): computed \(delta), §5.2 publishes \(exemplar.publishedDelta)")
    }

    @Test("Every exemplar's δ lands inside its own band's range", arguments: Exemplar.all)
    func exemplarStaysInBand(_ exemplar: Exemplar) {
        let delta = Difficulty.of(Law(exemplar.node), in: exemplar.band)
        #expect(exemplar.band.difficultyRange.contains(delta))
    }

    /// The Rasch coupling, and the one identity the 80 % target rests on.
    @Test("δ_logit = 8·difficulty − 4, and serving θ − ln4 hits 0.800 exactly")
    func raschCoupling() {
        expectApproximatelyEqual(Difficulty.logit(forDifficulty: 0.5), 0, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(
            Difficulty.logit(forDifficulty: 0.0), -4.0, absoluteTolerance: 1e-12)
        expectApproximatelyEqual(
            Difficulty.logit(forDifficulty: 0.999), 3.992, absoluteTolerance: 1e-9)
        // Round-trip.
        for d in stride(from: 0.0, to: 1.0, by: 0.077) {
            expectApproximatelyEqual(
                Difficulty.difficulty(forLogit: Difficulty.logit(forDifficulty: d)), d,
                absoluteTolerance: 1e-12)
        }
        // σ(ln 4) = 4/5 exactly — the whole target mechanism.
        let sigma = 1 / (1 + exp(-Difficulty.eightyPercentOffset))
        expectApproximatelyEqual(sigma, 0.8, absoluteTolerance: 1e-9)
    }
}

/// §5.2's eight exemplars, with the δ each publishes.
struct Exemplar: Sendable, CustomStringConvertible {
    let band: Band
    let node: LawNode
    let publishedDelta: Double

    var description: String { "band \(band.rawValue)" }

    static let all: [Exemplar] = [
        .init(
            band: .literal,
            node: .atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))),
            publishedDelta: 0.023),
        .init(
            band: .pair,
            node: .coupled(
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b1010))), .and,
                .atom(.init(attribute: .pips, subset: Fixture.subset(0b1100)))),
            publishedDelta: 0.160),
        .init(
            band: .exclusive,
            node: .coupled(
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b0011))), .xor,
                .atom(.init(attribute: .fill, subset: Fixture.subset(0b0011)))),
            publishedDelta: 0.317),
        .init(
            band: .relational,
            node: .relational(.init(leading: .shape, comparator: .eq, trailing: .pips)),
            publishedDelta: 0.432),
        .init(
            band: .contextual,
            node: .contextual(.init(current: .pips, comparator: .gt, previous: .pips)),
            publishedDelta: 0.525),
        .init(
            band: .guarded,
            node: .guarded(
                .init(
                    gate: .hue, gateValue: 0, branch: .pips,
                    then: Fixture.subset(0b1100), otherwise: Fixture.subset(0b0001))),
            publishedDelta: 0.639),
        .init(
            band: .composite,
            node: .coupled(
                .contextual(.init(current: .hue, comparator: .eq, previous: .hue)), .xor,
                .relational(.init(leading: .shape, comparator: .lt, trailing: .pips))),
            publishedDelta: 0.785),
        .init(
            band: .systemic,
            node: .aggregate(
                .parity(.init(attributes: Fixture.attributeSet(0b1111), isOdd: false))),
            publishedDelta: 0.928),
    ]
}
