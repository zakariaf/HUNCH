public import Glyphs
public import Feedback
public import Laws

extension Round {
    /// §12.5's fixed opening round: `shape ∈ {triangle}` at band 1, seeded on `glyphID` 22.
    ///
    /// The only law written down in the design, so it needs no generator and no seed — which is
    /// exactly why it is what the app opens on until E10 wires the run frame and the ladder.
    /// Everything about it is checkable by eye: a triangle is admitted, anything else is not.
    @MainActor
    public static func openingRound(
        reduceMotion: Bool = false, cues: any CuePlayer = SilentCuePlayer()
    ) -> Round {
        Round(
            law: Law(.atom(.init(attribute: .shape, subset: Round.triangleOnly))),
            band: .literal, mode: .probe, seedGlyph: Deck.glyph(id: 22),
            seed: 0x4855_4E43_48, targetDelta: Band.literal.difficultyRange.lowerBound,
            beat: VerdictBeat(reduceMotion: reduceMotion), cues: cues)
    }

    static let triangleOnly: Subset4 = {
        guard let subset = Subset4(rawValue: 1 << UInt8(Glyph.Shape.triangle.rawValue)) else {
            preconditionFailure("{triangle} is a legal <subset4> — §3.2")
        }
        return subset
    }()
}
