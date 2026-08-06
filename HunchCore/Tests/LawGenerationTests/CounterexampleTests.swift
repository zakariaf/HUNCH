import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws

/// §4.5's selection is "fully deterministic" and each of its four steps does a job. The
/// false-negative preference is the one that carries design intent: it targets the over-narrow
/// hypothesis, which is exactly what confirmation-only probing produces.
@Suite("Counterexample", .tags(.unit, .presubmission))
struct CounterexampleTests {
    static func g(_ f: Glyph.Fill, _ s: Glyph.Shape, _ p: Glyph.Pips, _ h: Glyph.Hue) -> Glyph {
        Glyph(fill: f, shape: s, pips: p, hue: h)
    }

    @Test("Hamming distance is over ATTRIBUTES, not glyph ids")
    func hammingIsAttributeSpace() {
        let a = Self.g(.hollow, .circle, .one, .amber)  // id 0
        let b = Self.g(.hollow, .circle, .one, .rose)  // id 3 — one attribute apart
        let c = Self.g(.solid, .circle, .one, .amber)  // id 192 — also one apart
        #expect(Counterexample.hammingDistance(a, b) == 1)
        #expect(Counterexample.hammingDistance(a, c) == 1)
        #expect(Counterexample.hammingDistance(a, a) == 0)
        #expect(
            Counterexample.hammingDistance(a, Self.g(.solid, .hexagon, .four, .rose)) == 4)
    }

    /// The player declared something too NARROW — the classic error. §4.5 prefers the case the
    /// hidden law admits and the declaration rejects.
    @Test("A false negative is preferred over a false positive")
    func prefersFalseNegatives() {
        // Hidden: shape ∈ {triangle, square}. Declared: shape ∈ {triangle} — strictly narrower,
        // so every disagreement is a false negative.
        let hidden = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0110))))
        let declared = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))
        let seed = Self.g(.hollow, .circle, .one, .amber)
        let choice = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [], seedGlyph: seed)
        #expect(choice?.isFalseNegative == true)
        #expect(choice?.current.shape == .square)
    }

    /// When both kinds exist, the false negative still wins — that is the whole preference.
    @Test("A false negative wins even when a closer false positive exists")
    func falseNegativeBeatsCloserFalsePositive() {
        // Hidden: pips ∈ {3,4}.  Declared: pips ∈ {1,3}.
        // False positive: pips 1 (declared admits, hidden rejects).
        // False negative: pips 4 (hidden admits, declared rejects).
        let hidden = Law(.atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        let declared = Law(.atom(.init(attribute: .pips, subset: Fixture.subset(0b0101))))
        let ribbon = [Self.g(.hollow, .circle, .one, .amber)]  // adjacent to the FALSE POSITIVE
        let choice = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: ribbon,
            seedGlyph: Self.g(.hollow, .circle, .one, .amber))
        #expect(choice?.isFalseNegative == true)
        #expect(choice?.current.pips == .four)
    }

    /// Step 3: the chosen glyph is near something the player has already seen, so it lands as
    /// "oh, THAT one" rather than as a random glyph.
    @Test("Among equals, the glyph nearest the ribbon wins")
    func minimisesHammingToRibbon() {
        let hidden = Law(.atom(.init(attribute: .hue, subset: Fixture.subset(0b0011))))
        let declared = Law(.atom(.init(attribute: .hue, subset: Fixture.subset(0b0001))))
        let anchor = Self.g(.solid, .hexagon, .four, .amber)
        let choice = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [anchor], seedGlyph: anchor)
        // Every disagreement is hue == teal; the nearest one differs from the anchor in hue only.
        #expect(choice?.current.hue == .teal)
        #expect(choice.map { Counterexample.hammingDistance(anchor, $0.current) } == 1)
    }

    @Test("Selection is deterministic — the same inputs give the same glyph")
    func isDeterministic() {
        let hidden = Law(.relational(.init(leading: .shape, comparator: .eq, trailing: .pips)))
        let declared = Law(.atom(.init(attribute: .shape, subset: Fixture.subset(0b0011))))
        let seed = Self.g(.hollow, .circle, .one, .amber)
        let a = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [], seedGlyph: seed)
        let b = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [], seedGlyph: seed)
        #expect(a == b)
    }

    /// A contextual band returns an ordered PAIR, because a single glyph proves nothing when a
    /// glyph has no verdict by itself.
    @Test("A contextual disagreement returns a pair, not a glyph")
    func contextualReturnsAPair() {
        let hidden = Law(.contextual(.init(current: .pips, comparator: .gt, previous: .pips)))
        let declared = Law(.atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        let seed = Self.g(.hollow, .circle, .one, .amber)
        let choice = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [], seedGlyph: seed)
        #expect(choice?.previous != nil)
    }

    /// §6.9's anti-farming argument: a garbage declaration disagrees nearly everywhere, so the
    /// minimum-Hamming rule hands back a glyph the player has effectively already probed.
    @Test("A garbage declaration yields a glyph adjacent to the ribbon — near-zero information")
    func garbageDeclarationYieldsNothingNew() {
        let hidden = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b0100))))
        // The complement — so the declaration disagrees with the hidden law nearly everywhere.
        let declared = Law(.atom(.init(attribute: .fill, subset: Fixture.subset(0b1011))))
        let probed = Self.g(.striped, .triangle, .two, .frost)
        let choice = Counterexample.select(
            declared: declared, hidden: hidden, ribbon: [probed], seedGlyph: probed)
        #expect(choice.map { Counterexample.hammingDistance(probed, $0.current) } ?? 9 <= 1)
    }
}
