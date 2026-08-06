import Testing

import Feedback
import Glyphs
import LoomFeature
import ModulesTestSupport
import Rounds

/// The order matters more than the contents: **the verdict is true before anything announces
/// it**. Every cue in this file is played from state that was already committed, which is what
/// makes killing the app mid-beat lossless and what makes silence a complete experience.
@Suite("What the beat fires, and when", .tags(.unit, .presubmission))
@MainActor
struct VerdictCueTests {

    @Test("A probe fires probeSubmit at t = 0 and the verdict cue at the end of the hold")
    func cueOrder() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)

        round.probe(Fixtures.seedGlyph)
        #expect(recorder.cues == [.probeSubmit])  // committed and announced at t = 0

        round.landVerdict()  // the end of the 260 ms hold
        #expect(recorder.cues.count == 2)
        #expect(
            recorder.cues.last == .verdict(round.ribbon.probes[0].verdict, isTwin: false))

        round.endVerdictBeat()
        #expect(recorder.cues.count == 2)  // the unlock is silent
    }

    @Test("The verdict is in the ribbon before any cue for it is played")
    func commitPrecedesFeedback() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)
        round.probe(Fixtures.seedGlyph)
        #expect(round.ribbon.probes.count == 1)
        #expect(recorder.cues.contains { if case .verdict = $0 { true } else { false } } == false)
    }

    /// Landing is idempotent because §6.11 case 5 can background the app mid-beat and leave the
    /// task unfinished — the resume must not fire a second verdict cue for a verdict the player
    /// has already heard.
    @Test("Landing twice fires one cue")
    func landingIsIdempotent() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)
        round.probe(Fixtures.seedGlyph)
        round.landVerdict()
        round.landVerdict()
        #expect(recorder.cues.count == 2)
    }

    /// The hold's end does not reopen input. If it did, a player could outrun the 260 ms and
    /// the beat would stop being a beat.
    @Test("Landing the verdict does not unlock input")
    func landingDoesNotUnlock() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        round.landVerdict()
        #expect(round.hasLandedVerdict)
        #expect(round.acceptsInput == false)
        round.endVerdictBeat()
        #expect(round.acceptsInput)
        #expect(round.hasLandedVerdict == false)
    }

    @Test("A twin's verdict cue says so, because audio resolves it differently")
    func twinCueCarriesTheFlag() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(cues: recorder)
        round.probe(Fixtures.seedGlyph)
        round.endVerdictBeat()
        recorder.reset()

        round.probeTwin()
        round.landVerdict()
        // The seed is a triangle and the opening law is `shape ∈ {triangle}`, so both verdicts
        // are admits — the twin flag is what tells the two apart, not the verdict.
        #expect(recorder.cues == [.probeSubmit, .verdict(.admit, isTwin: true)])
    }

    @Test("SilentCuePlayer is a legitimate implementation, not a stub")
    func silenceIsAnImplementation() {
        let round = Fixtures.round(cues: SilentCuePlayer())
        round.probe(Fixtures.seedGlyph)
        round.landVerdict()
        #expect(round.ribbon.probes.count == 1)  // geometry alone carries the verdict
    }
}
