import Foundation
import Testing

import Glyphs
import LoomFeature
import ModulesTestSupport
import LawGeneration
import Laws
import Rounds

/// §6.10's snapshot, at the round level. The property that matters is *when* it is written:
/// after every committed verdict, at t = 0 of the beat, so that killing the app mid-animation
/// loses nothing — the animation is the only thing between the commit and the write.
@Suite("Snapshot wiring", .tags(.unit, .presubmission))
@MainActor
struct SnapshotWiringTests {

    private final class Recorder {
        var writes: [ProbeSnapshot] = []
    }

    private func round(_ recorder: Recorder, band: Band = .literal) -> Round {
        Round(
            law: Fixtures.openingLaw, band: band, mode: .probe, seedGlyph: Fixtures.seedGlyph,
            seed: 0x4855_4E43_48, targetDelta: band.difficultyRange.lowerBound,
            now: { Date(timeIntervalSince1970: 100) },
            persist: { recorder.writes.append($0) })
    }

    @Test("Every committed verdict writes, and it writes before the beat ends")
    func everyVerdictWrites() {
        let recorder = Recorder()
        let round = round(recorder)

        round.probe(Fixtures.seedGlyph)
        #expect(recorder.writes.count == 1)  // t = 0, not t = 420
        #expect(recorder.writes[0].probes.count == 1)

        round.endVerdictBeat()
        #expect(recorder.writes.count == 1)  // the unlock is not an event worth a write

        round.probe(Deck.glyph(id: 9))
        #expect(recorder.writes.count == 2)
        #expect(recorder.writes[1].probes.count == 2)
    }

    /// The Bench draft rides the `.inactive` write and no other: it is the only state a player
    /// would notice missing and the only one that changes without a verdict, so writing after
    /// every cell tap would be a file write per tap.
    @Test("Going inactive writes; editing does not")
    func inactiveWrites() {
        let recorder = Recorder()
        let round = round(recorder)

        round.select(.pips, rank: 3)
        round.select(.hue, rank: 2)
        #expect(recorder.writes.isEmpty)

        round.sceneBecameInactive()
        #expect(recorder.writes.count == 1)
    }

    /// §6.10: the snapshot stores **glyph IDs only** and recomputes verdicts from the stored
    /// law, which is what makes a tampered file produce `.voided` rather than a quietly altered
    /// round — there is no verdict on disk to alter.
    @Test("The snapshot stores IDs and the law, never verdicts")
    func verdictsAreNotOnDisk() {
        let recorder = Recorder()
        let round = round(recorder)
        round.probe(Deck.glyph(id: 3))

        let snapshot = round.snapshot()
        #expect(snapshot.probes == [3])
        #expect(snapshot.passesIntegrityCheck)
        #expect(snapshot.law == round.law.node)
        #expect(snapshot.seedGlyph == UInt8(Fixtures.seedGlyph.id))
        #expect(snapshot.strikes == 0)
    }

    /// A strike changes state the ribbon does not show, so it writes too. Resuming a round that
    /// had taken a strike and finding two strikes still available would hand back a life.
    @Test("A resolved strike writes")
    func strikeWrites() {
        let recorder = Recorder()
        let round = round(recorder)
        round.setBenchDraft(Fixtures.contextualLaw)
        round.seal()
        let before = recorder.writes.count

        round.resolveSeal()
        #expect(recorder.writes.count == before + 1)
        #expect(recorder.writes[recorder.writes.count - 1].strikes == 1)
    }

    /// §6.1: **no wall-clock quantity affects score, marks or the Rasch update.** The clock is
    /// read for two snapshot fields and nothing else, so a round paused for a week is worth
    /// exactly what it was worth.
    @Test("The clock reaches the snapshot and nothing else")
    func theClockIsInert() {
        let recorder = Recorder()
        let round = round(recorder)
        round.probe(Fixtures.seedGlyph)
        round.endVerdictBeat()

        #expect(round.startedAt == Date(timeIntervalSince1970: 100))
        #expect(round.elapsedActive == 0)  // a frozen clock: the round still scores normally
        #expect(round.score == Scoring.score(probesUsed: 1, par: round.par, strikes: 0))
    }

    /// A settled round is not a live one: writing after the outcome would leave a snapshot on
    /// disk that the next launch would resume into a round that is already over.
    @Test("A settled round stops writing")
    func settledRoundsStopWriting() {
        let recorder = Recorder()
        let round = round(recorder)
        while round.probesUsed < round.cap {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        let atEnd = recorder.writes.count
        round.sceneBecameInactive()
        #expect(recorder.writes.count == atEnd)
    }
}
