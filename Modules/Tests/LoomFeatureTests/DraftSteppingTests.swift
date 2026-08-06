import Testing

import Glyphs
import LoomFeature
import ModulesTestSupport

/// §6.3's cheapest inductive move: one attribute steps, three hold. The stepping rule is model
/// behaviour, so it is tested here with no view — and `changedRegister` is tested alongside it,
/// because "only the changed register animates" is a claim about *what moved*, which only the
/// model knows.
@Suite("The draft steps by one rank and wraps off", .tags(.unit, .presubmission))
@MainActor
struct DraftSteppingTests {

    @Test("A swipe steps the last-touched attribute by ±1 and changes nothing else")
    func stepsOneAttribute() {
        let round = Fixtures.round()
        round.select(.pips, rank: 2)  // a Dial tap sets the last-touched attribute
        let before = round.draft

        round.stepDraft(by: 1)

        #expect(round.draft.pips.rank == before.pips.rank + 1)
        #expect(round.draft.fill == before.fill)
        #expect(round.draft.shape == before.shape)
        #expect(round.draft.hue == before.hue)
        #expect(round.changedRegister == .pips)
    }

    @Test(
        "Wrapping is off: the ends are sticky, not circular",
        arguments: Glyph.Attribute.allCases)
    func wrappingIsOff(_ attribute: Glyph.Attribute) {
        let round = Fixtures.round()

        round.select(attribute, rank: 1)
        round.stepDraft(by: -1)
        #expect(round.draft.rank(of: attribute) == 1)  // clamped, never wrapped to 4

        round.select(attribute, rank: 4)
        round.stepDraft(by: +1)
        #expect(round.draft.rank(of: attribute) == 4)  // clamped, never wrapped to 1
    }

    @Test("The last-touched attribute is the most recent edit, not the first")
    func lastTouchedIsTheNewest() {
        let round = Fixtures.round()
        round.select(.fill, rank: 3)
        round.select(.hue, rank: 2)
        round.stepDraft(by: 1)
        #expect(round.changedRegister == .hue)
    }

    @Test("Before any edit the gesture is live, not dead")
    func lastTouchedHasADefault() {
        let round = Fixtures.round()
        let before = round.draft
        round.stepDraft(by: 1)
        #expect(round.draft != before)  // §6.3's gesture works from the first frame
        #expect(round.changedRegister == .fill)  // canonical order's first — DECISIONS 41
    }

    @Test("A step that changes nothing reports no changed register")
    func aClampedStepAnimatesNothing() {
        let round = Fixtures.round()
        round.select(.shape, rank: 4)
        round.stepDraft(by: 1)
        #expect(round.changedRegister == nil)  // nothing moved, so nothing crossfades
    }

    /// A ribbon-load is a wholesale adoption, not a controlled variation. Reporting one changed
    /// register for a two-register jump would animate a lie: the player would see one attribute
    /// move and read the other as having always been there.
    @Test("A ribbon-load reports one changed register only when exactly one differs")
    func ribbonLoadIsNotAControlledVariation() {
        let round = Fixtures.round()
        let seed = Fixtures.seedGlyph

        round.setDraft(Deck.glyph(id: seed.id ^ 0b01))  // hue only — the low two bits
        #expect(round.changedRegister == .hue)

        round.setDraft(Deck.glyph(id: seed.id ^ 0b0101_0101))
        #expect(round.changedRegister == nil)
    }

    /// The throat is the input, and input is locked outside `probing` and `declaring` (§6.1).
    /// A swipe landing inside the 420 ms beat must not move the draft under the animation.
    @Test("Editing is refused while input is locked")
    func editingIsRefusedInsideTheBeat() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        let locked = round.draft

        round.select(.pips, rank: 4)
        round.stepDraft(by: -1)

        #expect(round.draft == locked)
    }
}
