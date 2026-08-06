import Testing

import Feedback
import Glyphs
import LawGeneration
import Laws
import LoomFeature
import ModulesTestSupport

/// §6.9's decision, asserted rather than trusted: **the par crossing has no audio and no
/// haptic.** It lands on the same frame as a verdict, which owns those two channels absolutely
/// (§6.4). A second cue there would either mask the verdict or be misread as part of it, and
/// the player would learn "sometimes the admit tone is different" — a lie about the law.
@Suite("The par crossing is silent", .tags(.unit, .presubmission))
@MainActor
struct ParCrossingSilenceTests {

    @Test("Crossing par fires no cue of its own", arguments: [Band.literal, Band.exclusive])
    func theCrossingIsSilent(_ band: Band) {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(band: band, cues: recorder)

        while round.probesUsed < band.par {
            round.probe(Deck.glyph(id: round.probesUsed % 256))
            round.landVerdict()
            round.endVerdictBeat()
        }
        #expect(round.hasCrossedPar)

        // Two cues per probe and not one more: submit, then the verdict. Nothing for the
        // crossing, on the crossing probe or on any other.
        #expect(recorder.cues.count == 2 * band.par)
        #expect(recorder.cues.allSatisfy { $0 != .driftMoment })
    }

    /// The crossing probe is the one that fills the last par tick, and it is an ordinary probe
    /// in every other respect: same beat, same lock, same two cues.
    @Test("The crossing probe's beat is the same length and shape as any other")
    func theCrossingProbeIsOrdinary() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(band: .literal, cues: recorder)
        while round.probesUsed < round.par - 1 {
            round.probe(Fixtures.seedGlyph)
            round.landVerdict()
            round.endVerdictBeat()
        }
        recorder.reset()

        round.probe(Fixtures.seedGlyph)
        #expect(round.hasCrossedPar)
        #expect(recorder.cues == [.probeSubmit])
        round.landVerdict()
        #expect(recorder.cues.count == 2)
        #expect(round.beat.adjudicationHold == .milliseconds(260))
    }
}
