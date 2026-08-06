import Testing

import Drift
import Glyphs
import HunchTestSupport
import Laws

/// §7.8. The quantity worth the most here is `cling`: probes spent inside the agreement set
/// after the first contradiction, whose verdicts are equally consistent with the dead law and
/// the live one. Pure confirmation, zero bits — and no analogue in PROBE, where such probes do
/// not exist.
@Suite("DRIFT's transcript metrics", .tags(.unit, .presubmission))
struct DriftTranscriptTests {

    private static let wide = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0110))))
    private static let narrow = Law(
        .atom(.init(attribute: .shape, subset: Fixture.subset(0b0010))))

    /// The gap between the hinge and the evidence is the mode: the law changed at `t_hinge` and
    /// the player could not have known until `t_evidence`, because everything between agreed.
    @Test("Evidence lands after the hinge, not at it")
    func evidenceTrailsTheHinge() {
        let triangle = Deck.glyph(id: 16)
        let square = Deck.glyph(id: 32)
        let probes = [triangle, triangle, triangle, square]

        let transcript = DriftTranscript.derive(
            probes: probes, seedGlyph: triangle, hinge: 0, first: Self.wide,
            second: Self.narrow, sealedAt: nil, deadDeclaration: false)

        #expect(transcript.hinge == 0)
        #expect(transcript.evidence == 3)  // the first square: admitted by L₁, rejected by L₂
        #expect(transcript.evidence ?? 0 > transcript.hinge)
    }

    /// Cling is the design's own name for the behaviour: three more agreeing probes after the
    /// contradiction, each of which the dead theory explains perfectly.
    @Test("Cling counts the probes spent inside the agreement set after the contradiction")
    func clingIsMeasured() {
        let triangle = Deck.glyph(id: 16)
        let square = Deck.glyph(id: 32)
        let probes = [square, triangle, triangle, square]

        let transcript = DriftTranscript.derive(
            probes: probes, seedGlyph: triangle, hinge: -1, first: Self.wide,
            second: Self.narrow, sealedAt: 5, deadDeclaration: false)

        #expect(transcript.evidence == 0)
        #expect(transcript.recover == 3)
        #expect(transcript.cling == 3)
        #expect(transcript.redeclarationLatency == 5)
    }

    /// "Did not recover" and "recovered instantly" are opposite facts, so cling is `nil` rather
    /// than zero when the player never probed the disagreement set again.
    @Test("A player who never recovers has no cling, not a cling of zero")
    func neverRecoveredIsNotZero() {
        let triangle = Deck.glyph(id: 16)
        let square = Deck.glyph(id: 32)
        let transcript = DriftTranscript.derive(
            probes: [square, triangle, triangle], seedGlyph: triangle, hinge: -1,
            first: Self.wide, second: Self.narrow, sealedAt: nil, deadDeclaration: true)

        #expect(transcript.evidence == 0)
        #expect(transcript.recover == nil)
        #expect(transcript.cling == nil)
    }

    /// §7.8 is explicit that it defines the quantities and **not** the axis. The emission is
    /// three fields, and `cling` is not one of them — it is retained for the harness and feeds
    /// nothing the player ever sees.
    @Test("The emission carries three fields, and cling is not one of them")
    func theEmissionIsNarrow() {
        let transcript = DriftTranscript(
            hinge: 4, evidence: 6, recover: 9, seal: 12, deadDeclaration: true)
        let emission = transcript.emission(recoveryAllowance: 9)

        #expect(emission.redeclarationLatency == 6)
        #expect(emission.recoveryAllowance == 9)
        #expect(emission.deadDeclaration)
        #expect(transcript.cling == 3)  // measured, and not emitted
    }
}
