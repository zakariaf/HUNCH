import Foundation
import Testing

import Bench
import Glyphs
import LawGeneration
import Laws
import LoomFeature
import ModulesTestSupport
import Persistence
import Rounds

/// §6.11's twenty-nine rows, accounted for **exactly once each**.
///
/// Every row is either a named test here — the row number is in the test name so a reader of
/// §6.11 can grep for any of them — or a named row in `delegated`, with the epic that owns it.
/// Nothing is "covered by the suite in general": that phrase is how a row goes missing.
@Suite("§6.11's edge cases", .tags(.unit, .presubmission))
@MainActor
struct EdgeCaseLedgerTests {

    /// Rows this epic does not own, each with its owner. The ledger is the point: a row with no
    /// entry in either list is a row nobody has looked at.
    static let delegated: [Int: String] = [
        9: "E20 — audio session interruption and .shouldResume",
        16: "E20 — the silent switch",
        17: "E20 — system haptics off",
        18: "E20 — both off; geometry alone",
        19: "E09·T12, E19 — the Reduce Motion table across every surface",
        20: "E19·T06 — the AX2+ pager matrix",
        21: "E20 — Low Power Mode and the shader's 2 s disable",
        22: "E17·T03 — the chrome's storage hairline",
        24: "E01 — portrait lock in the target's Info settings",
        25: "E16 — the Anomaly's date derivation",
        26: "E19·T02 — VoiceOver during the reveal",
    ]

    @Test("The ledger accounts for all twenty-nine rows exactly once")
    func everyRowIsAccountedFor() {
        let tested: Set<Int> = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 23, 27, 28, 29]
        let owned = Set(Self.delegated.keys)
        #expect(tested.isDisjoint(with: owned))
        #expect(tested.union(owned) == Set(1...29))
    }

    /// Row 1 — declare at probe 0. `probesUsed = max(1, 0)` keeps the score finite.
    @Test("6.11 #1 — declaring at probe 0 is legal and does not divide by zero")
    func row01DeclareAtProbeZero() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.subsetLaw)
        #expect(round.seal() == nil)
        round.resolveSeal()
        #expect(round.probesUsed == 0)
        #expect(round.score == Scoring.score(probesUsed: 0, par: round.par, strikes: 0))
        #expect(round.score == 1_000)
        #expect(round.marks == 3)
    }

    /// Row 2 — twin at probe 0 probes the seed and the seed never gains a verdict ring.
    @Test("6.11 #2 — the twin key at probe 0 probes the seed glyph")
    func row02TwinAtProbeZero() {
        let round = Fixtures.round()
        round.probeTwin()
        #expect(round.ribbon.probes[0].glyph == Fixtures.seedGlyph)
        #expect(round.ribbon.probes[0].isTwin == false)
    }

    /// Row 3 — a twin is an **adjacent** re-probe only.
    @Test("6.11 #3 — a non-adjacent repeat gets no doubled ring")
    func row03NonAdjacentRepeat() {
        let round = Fixtures.round()
        let glyph = Deck.glyph(id: 7)
        round.probe(glyph)
        round.endVerdictBeat()
        round.probe(Deck.glyph(id: 8))
        round.endVerdictBeat()
        round.probe(glyph)
        #expect(round.ribbon.probes.allSatisfy { $0.isTwin == false })
    }

    /// Row 4 — a paid-for bit is never withheld.
    @Test("6.11 #4 — the cap-th verdict is delivered in full, then exhausted")
    func row04CapOnAnAdmit() {
        let round = Fixtures.round()
        while round.probesUsed < round.cap - 1 {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        round.probe(Fixtures.seedGlyph)
        #expect(round.ribbon.probes.count == round.cap)
        #expect(round.phase == .adjudicating(.admit))
        round.endVerdictBeat()
        #expect(round.phase == .revealing(.exhausted))
    }

    /// Rows 5, 7, 8, 28 — backgrounded, force-quit, crashed, or backgrounded with the Bench up.
    /// All four are the same fact: the verdict was committed at t = 0 and is already on disk.
    @Test("6.11 #5, #7, #8, #28 — nothing in flight is lost, because nothing was in flight")
    func rows05and07and08and28() {
        final class Recorder { var last: ProbeSnapshot? }
        let recorder = Recorder()
        let round = Round(
            law: Fixtures.openingLaw, band: .literal, mode: .probe,
            seedGlyph: Fixtures.seedGlyph, seed: 1, targetDelta: 0,
            persist: { recorder.last = $0 })

        round.probe(Deck.glyph(id: 5))  // mid-beat: the animation has not finished
        #expect(recorder.last?.probes == [5])  // …and the probe is already on disk

        round.select(.pips, rank: 4)  // a Bench-side edit
        round.sceneBecameInactive()
        #expect(recorder.last?.probes == [5])
    }

    /// Row 6 — the page is written on the Seal press, not at the end of the reveal.
    @Test("6.11 #6 — the reveal is decoration over a committed result")
    func row06BackgroundedDuringTheReveal() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.subsetLaw)
        round.seal()
        // The comparison is done and held; the 2,480 ms that follow cannot change it.
        round.resolveSeal()
        #expect(round.phase == .revealing(.inscribed(marks: 3, fracture: false)))
    }

    /// Rows 10 and 11 — one queued tap on PROBE, and no queue at all on the Seal.
    @Test("6.11 #10, #11 — one queued probe; the Seal is edge-triggered")
    func rows10and11() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        round.probe(Deck.glyph(id: 2))  // queued
        round.probe(Deck.glyph(id: 3))  // dropped
        round.endVerdictBeat()
        #expect(round.probesUsed == 2)
        #expect(round.ribbon.probes[1].glyph == Deck.glyph(id: 2))

        round.setBenchDraft(Fixtures.subsetLaw)
        #expect(round.seal() == .empty)  // refused while the lock is held, never queued
    }

    /// Rows 12 and 13 — a barred Seal says nothing, and a constant draft is one of the reasons.
    @Test("6.11 #12, #13 — the bar is silent and covers the constant draft")
    func rows12and13() {
        let round = Fixtures.round()
        #expect(round.seal() == .empty)
        round.setBenchDraft(
            Law(
                .coupled(
                    .atom(.init(attribute: .shape, subset: Fixtures.subset(0b0111))), .or,
                    .atom(.init(attribute: .shape, subset: Fixtures.subset(0b1100))))))
        #expect(round.sealBarReason == .constantExtension)
        #expect(round.phase != .sealing)
    }

    /// Row 14 — extension identity, not spelling.
    @Test("6.11 #14 — a differently spelled correct declaration is correct")
    func row14Spelling() {
        let round = Fixtures.round()
        round.setBenchDraft(Fixtures.subsetLaw)
        round.seal()
        round.resolveSeal()
        #expect(round.strikes == 0)
    }

    /// Row 15 — a stateless declaration is judged by **lifting** it to pair space, so it is
    /// wrong unless it is genuinely equivalent there.
    @Test("6.11 #15 — a stateless declaration against a contextual law is lifted, then compared")
    func row15Lifting() {
        let round = Fixtures.round(law: Fixtures.contextualLaw, band: .contextual)
        round.setBenchDraft(Fixtures.subsetLaw)
        round.seal()
        round.resolveSeal()
        #expect(round.strikes == 1)
        #expect(Fixtures.contextualLaw.table.arity == .contextual)
        #expect(Fixtures.subsetLaw.table.arity == .stateless)
    }

    /// Row 23 — a tampered snapshot is `voided`, reached from `arming` and nowhere else.
    @Test("6.11 #23 — a failed integrity check voids rather than alters")
    func row23Integrity() {
        let round = Fixtures.round()
        round.probe(Fixtures.seedGlyph)
        var snapshot = round.snapshot()
        #expect(snapshot.passesIntegrityCheck)

        snapshot.lawHash ^= 1
        #expect(snapshot.passesIntegrityCheck == false)
        #expect(
            RoundPhase.advance(.arming, on: .integrityCheckFailed) == .settled(.voided))
        for phase in [RoundPhase.probing, .declaring, .sealing] {
            #expect(RoundPhase.advance(phase, on: .integrityCheckFailed) == nil)
        }
    }

    /// Row 27 — leaving to the run frame and coming back is not abandoning.
    @Test("6.11 #27 — returning without abandoning resumes in probing with everything intact")
    func row27ReturnWithoutAbandoning() {
        let round = Fixtures.round()
        round.probe(Deck.glyph(id: 4))
        round.endVerdictBeat()
        round.select(.hue, rank: 3)
        let draft = round.draft

        round.sceneBecameInactive()
        #expect(round.phase == .probing)
        #expect(round.draft == draft)
        #expect(round.probesUsed == 1)
        #expect(round.outcome == nil)
    }

    /// Row 29 — unreachable by construction, and the phase table is what makes it so: the
    /// cap-th verdict goes straight to `revealing(.exhausted)`, so a snapshot at the cap cannot
    /// be written by a live round.
    @Test("6.11 #29 — a snapshot at the cap is unreachable by construction")
    func row29SnapshotAtCap() {
        let round = Fixtures.round()
        while round.probesUsed < round.cap {
            round.probe(Fixtures.seedGlyph)
            round.endVerdictBeat()
        }
        #expect(round.outcome == .exhausted)
        #expect(round.snapshot().isStructurallyValid == false)
        #expect(
            RoundPhase.advance(.adjudicating(.admit), on: .capReached)
                == .revealing(.exhausted))
    }
}
