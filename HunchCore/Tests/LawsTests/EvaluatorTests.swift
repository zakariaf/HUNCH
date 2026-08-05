import Testing

import Glyphs
import HunchTestSupport
import Laws

/// §3.5's sequence semantics are the design's most consequential overrule of the brief, and
/// this suite is where "previously PROBED, regardless of verdict" is pinned. Under the brief's
/// "previously admitted" reading, the worked round in §5.5 does not reproduce.
@Suite("Evaluator", .tags(.unit, .presubmission))
struct EvaluatorTests {

    // A func, not a `static let` closure: a function type is not Sendable, and strict
    // concurrency rejects it as shared mutable state. Correctly.
    static func g(
        _ f: Glyph.Fill, _ s: Glyph.Shape, _ p: Glyph.Pips, _ h: Glyph.Hue
    ) -> Glyph {
        Glyph(fill: f, shape: s, pips: p, hue: h)
    }

    @Test("A stateless law ignores `previous` entirely")
    func statelessIgnoresPrevious() {
        let law = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
        let probe = Self.g(.striped, .circle, .one, .amber)
        for previous in stride(from: 0, to: 256, by: 17) {
            #expect(law.admits(probe, after: Deck.glyph(id: previous)))
        }
    }

    /// The whole point of §3.5: `prev` advances on EVERY probe, not only on admitted ones. A
    /// rejected probe still becomes the next probe's context.
    @Test("`prev` advances on every probe, admitted or not (§3.5)")
    func previousAdvancesRegardlessOfVerdict() {
        let law = Law(.contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
        let seed = Self.g(.hollow, .circle, .two, .amber)
        let probes = [
            Self.g(.hollow, .circle, .one, .amber),  // 1 > 2 false -> reject; prev becomes 1 pip
            Self.g(.hollow, .circle, .two, .amber),  // 2 > 1 true  -> admit
        ]
        let verdicts = law.verdicts(seededBy: seed, probes: probes)
        #expect(verdicts == [.reject, .admit])

        // Under the brief's "previously ADMITTED" reading, probe 2's context would still be the
        // seed (2 pips) and 2 > 2 is false — so it would read .reject. That is the difference.
        #expect(verdicts[1] != .reject)
    }

    /// §5.5's worked band-5 round, verdict by verdict. The design calls it machine-verified;
    /// this is the machine.
    @Test("§5.5's worked round reproduces exactly, all 15 probes")
    func workedRoundReproduces() {
        // RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}
        let law = Law(
            .coupled(
                .contextual(.init(current: .pips, comparator: .gt, previous: .pips)),
                .and,
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b1010)))))

        expectApproximatelyEqual(law.admitRate, 0.188, absoluteTolerance: 0.001)

        let seed = Self.g(.hollow, .triangle, .two, .teal)
        let probes: [Glyph] = [
            Self.g(.hollow, .triangle, .three, .amber),  // 1  admit
            Self.g(.hollow, .triangle, .three, .amber),  // 2  twin -> reject
            Self.g(.hollow, .triangle, .four, .amber),  // 3  admit
            Self.g(.hollow, .triangle, .four, .amber),  // 4  twin -> reject
            Self.g(.hollow, .triangle, .one, .amber),  // 5  reject
            Self.g(.hollow, .triangle, .two, .amber),  // 6  admit
            Self.g(.hollow, .square, .three, .amber),  // 7  reject — shape participates
            Self.g(.hollow, .triangle, .four, .amber),  // 8  admit
            Self.g(.hollow, .triangle, .one, .amber),  // 9  reject
            Self.g(.hollow, .circle, .two, .amber),  // 10 reject
            Self.g(.hollow, .hexagon, .three, .amber),  // 11 admit
            Self.g(.hollow, .triangle, .one, .amber),  // 12 reject
            Self.g(.hollow, .square, .two, .amber),  // 13 reject
            Self.g(.solid, .hexagon, .three, .rose),  // 14 admit
            Self.g(.striped, .triangle, .four, .frost),  // 15 admit
        ]
        let expected: [Verdict] = [
            .admit, .reject, .admit, .reject, .reject, .admit, .reject, .admit,
            .reject, .reject, .admit, .reject, .reject, .admit, .admit,
        ]
        #expect(law.verdicts(seededBy: seed, probes: probes) == expected)
    }

    /// §5.6's band-3 round: the player who varies one attribute at a time sees 50 % admits on
    /// every attribute and concludes the machine is random.
    @Test("§5.6's worked band-3 round reproduces")
    func exclusiveRoundReproduces() {
        let law = Law(
            .coupled(
                // circle, triangle
                .atom(.init(attribute: .shape, subset: Fixture.subset(0b0011))),
                .xor,
                .atom(.init(attribute: .fill, subset: Fixture.subset(0b0011)))))  // hollow, dotted
        let seed = Self.g(.hollow, .circle, .one, .amber)
        let probes: [Glyph] = [
            Self.g(.hollow, .circle, .one, .amber),  // T⊕T -> reject
            Self.g(.hollow, .triangle, .one, .amber),  // T⊕T -> reject
            Self.g(.hollow, .square, .one, .amber),  // F⊕T -> admit
            Self.g(.solid, .circle, .one, .amber),  // T⊕F -> admit
            Self.g(.solid, .square, .one, .amber),  // F⊕F -> reject
            Self.g(.dotted, .hexagon, .one, .amber),  // F⊕T -> admit
        ]
        #expect(
            law.verdicts(seededBy: seed, probes: probes)
                == [.reject, .reject, .admit, .admit, .reject, .admit])
    }

    @Test("verdicts returns exactly probes.count entries, and the seed is never scored")
    func seedIsNotAProbe() {
        let law = Law(.atom(.init(attribute: .hue, subset: Fixture.subset(0b0001))))
        let seed = Self.g(.hollow, .circle, .one, .amber)
        #expect(law.verdicts(seededBy: seed, probes: []).isEmpty)
        #expect(law.verdicts(seededBy: seed, probes: [seed]).count == 1)
    }
}
