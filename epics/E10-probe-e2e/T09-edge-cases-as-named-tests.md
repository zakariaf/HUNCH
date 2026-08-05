# T09 — §6.11's edge cases as named tests

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | Round state machine (PROBE) · Mid-round snapshot (PROBE) — both as *verified* rows rather than implemented ones |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | The whole task is test design: which of the 29 rows is a host test in `HunchCore`, which needs `LoomFeature`, which is a build setting, and which belongs to a later epic. It owns the naming convention that makes a row traceable (`§6.11 #7 — …`), the tag axes, and the `tests.json` obligation that keeps a delegated row from quietly vanishing. |

## Objective

At the end of this task every one of §6.11's twenty-nine rows is accounted for exactly once: each row is
either a named, passing test in this repository, or a named row in the delegation table below with the
epic and task that owns it. Nothing is "covered by the suite in general", and the row numbers survive
into the test names so a reader of §6.11 can grep for any of them.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.11 | all twenty-nine rows, verbatim — this table *is* the specification and every test name quotes its row number |
| `GAME_DESIGN.md` | §6.1 | the transition table each state-machine row is asserted against, and the two invariants (`the model never waits on an animation`, `no wall-clock quantity affects score`) |
| `GAME_DESIGN.md` | §6.9 | `probesUsed = max(1, probeCount)` — the guard row 1 turns on |
| `GAME_DESIGN.md` | §6.5 | the single-slot input queue rows 10 and 11 turn on |
| `GAME_DESIGN.md` | §4.3, §4.5 | rows 12–15: the barred Seal, the constant extension, extension identity with lifting |
| `ios-swift-guide/06-TESTING.md` | T21, T30, T53 | one behaviour per test; tag on both axes; promote every failure into a named case |

## The 29 rows, and who owns each

| # | Row | Owner | Named test |
|---|---|---|---|
| 1 | Declare at probe 0 | **this task** | `§6.11 #1 — declaring at probe 0 is legal and probesUsed floors at 1` |
| 2 | Twin pressed at probe 0 | **this task** | `§6.11 #2 — the twin at probe 0 probes the seed glyph, which never gains a ring` |
| 3 | Same glyph probed twice, non-adjacently | **this task** | `§6.11 #3 — a non-adjacent repeat is not a twin` |
| 4 | Cap reached on an admit | **this task** | `§6.11 #4 — the cap-th verdict is delivered in full before exhausted` |
| 5 | Backgrounded during the 420 ms verdict beat | **this task** | `§6.11 #5 — the verdict was committed at t = 0; resume skips the animation` |
| 6 | Backgrounded during the reveal | **this task** | `§6.11 #6 — the page was written at t = 0; resume lands on the round card` |
| 7 | Force-quit from the app switcher | **this task** | `§6.11 #7 — the .inactive snapshot exists, draft included` |
| 8 | Crash or battery death mid-round | **this task** | `§6.11 #8 — the last committed verdict survives; only the draft since .inactive is lost` |
| 9 | Phone call mid-round | **this task** (state half) | `§6.11 #9 — .inactive writes the snapshot and nothing is timed` · audio resume → **E20·T04** |
| 10 | Double-tap on PROBE inside the lock | **this task** | `§6.11 #10 — one queued tap honoured, further taps dropped` |
| 11 | Double-tap on the Seal | **this task** | `§6.11 #11 — the Seal is edge-triggered with no queue` |
| 12 | Barred Seal pressed | **E09·T07** | `§4.3 — pressing a barred Seal pulses the offending rail and does nothing else` |
| 13 | Draft's extension is constant | **this task** | `§6.11 #13 — a constant extension bars the Seal` |
| 14 | Correct declaration spelled differently | **E09·T08** | `§4.5 — extension identity in the common space` |
| 15 | Stateless declaration against a contextual law | **this task** | `§6.11 #15 — judged by lifting the stateless table to pair space` |
| 16 | Silent switch on | **E20·T04** | session policy: `.ambient` honours the silent switch |
| 17 | System haptics off | **E20·T06** | capability no-ops |
| 18 | Both off | **E04·T06 / E19·T09** | geometry alone — the triple-encoding proof is the assertion |
| 19 | Reduce Motion | **E09·T12** | the complete substitution table |
| 20 | Dynamic Type ≥ AX2 | **E19·T06** | Bench single-rail pager; the Assay becomes a chip |
| 21 | Low Power Mode | **E20·T07** | shader auto-disable; durations unchanged |
| 22 | Storage full — atomic write fails | **T02** (this epic) | `storageFullDoesNotEndTheRound` — re-listed here, not re-written |
| 23 | Stored law fails its `lawHash` | **T02** (this epic) | `corruptHashVoids` + `failureResolvesToVoided` |
| 24 | Device rotated | **E01·T02** | `Config/Base.xcconfig` portrait-only; asserted by `xcodebuild -showBuildSettings` |
| 25 | UTC date rolls over mid-round | **this task** | `§6.11 #25 — PROBE is unaffected; the Anomaly's seed is bound at round start` |
| 26 | VoiceOver on during a reveal | **E19·T05** | three announcements at 640 / 1,450 / 1,850 ms; tap-to-skip disabled |
| 27 | Exits to the run frame and returns without abandoning | **this task** | `§6.11 #27 — resuming costs nothing: draft, ribbon and count intact` |
| 28 | Backgrounded with the Bench up, then cold-launched | **T03** (this epic) | `resumeEntersProbing` — re-listed here, not re-written |
| 29 | Snapshot's probe count already equals `cap` | **T02** (this epic) | `snapshotAtCapIsCorruption` |

Fifteen rows are written here; seven are already written elsewhere in this epic and are only *listed*;
seven belong to other epics and each is named with its task. Twenty-nine rows, one owner each.

## TDD — the test comes first

**Step 1 — write the failing test.** Two files, split by what each row needs.

`HunchCore/Tests/RoundsTests/EdgeCaseTests.swift` — the rows that are pure:

```swift
import Testing
@testable import Rounds
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("§6.11 — the edge cases that are pure", .tags(.unit, .presubmission))
struct EdgeCaseTests {

    @Test("§6.11 #1 — declaring at probe 0 is legal and probesUsed floors at 1")
    func declareAtProbeZero() {
        #expect(Score.inscribed(par: 7, probesUsed: 0, strikes: 0) == 1000)
        #expect(Marks.earned(par: 7, probesUsed: 0, cap: 12) == 3)
        #expect(RoundPhase.probing.next(on: .benchOpened) == .declaring)
        #expect(RoundPhase.declaring.next(on: .sealPressed) == .sealing)
    }

    @Test("§6.11 #2 — the twin at probe 0 probes the seed glyph, which never gains a ring")
    func twinAtProbeZero() {
        var ribbon = Ribbon(seedGlyph: Deck.glyph(id: 22))
        ribbon.append(Probe(glyph: Deck.glyph(id: 22), verdict: .admit, isTwin: true))
        #expect(ribbon.probes.count == 1)
        #expect(ribbon.seedTile.verdictRing == nil)      // the seed itself never gains one
        #expect(ribbon.probes[0].isTwin)
    }

    @Test("§6.11 #3 — a non-adjacent repeat is not a twin")
    func nonAdjacentRepeatIsNotATwin() {
        var ribbon = Ribbon(seedGlyph: Deck.glyph(id: 22))
        ribbon.append(Probe(glyph: Deck.glyph(id: 38), verdict: .reject, isTwin: false))
        ribbon.append(Probe(glyph: Deck.glyph(id: 26), verdict: .admit, isTwin: false))
        ribbon.append(Probe(glyph: Deck.glyph(id: 38), verdict: .reject, isTwin: false))
        #expect(ribbon.probes.allSatisfy { !$0.isTwin })
        #expect(ribbon.doubledRingIndices.isEmpty)
    }

    @Test("§6.11 #4 — the cap-th verdict is delivered in full before exhausted")
    func capReachedOnAnAdmit() {
        let cap = Band.literal.cap
        #expect(RoundPhase.probing.next(on: .probeSubmitted(index: cap)) == .adjudicating(.admit))
        #expect(RoundPhase.adjudicating(.admit).next(on: .capReached) == .revealing(.exhausted))
        // a paid-for bit is never withheld: the verdict is in the ribbon before the reveal begins
        #expect(RoundPhase.adjudicating(.admit).commitsVerdict)
    }

    @Test("§6.11 #13 — a constant extension bars the Seal")
    func constantDraftBarsTheSeal() {
        let tautology = BenchLayout.tautology()
        #expect(SealBar.reason(for: tautology) == .constantExtension)
        let unsatisfiable = BenchLayout.contradiction()
        #expect(SealBar.reason(for: unsatisfiable) == .constantExtension)
    }

    @Test("§6.11 #15 — a stateless declaration against a contextual law is judged by lifting")
    func statelessAgainstContextual() {
        let contextual = Corpora.law(band: .contextual, index: 0)
        let stateless = Corpora.law(band: .literal, index: 0)
        let declared = LawTable(stateless).lifted
        let hidden = LawTable(contextual)

        #expect(declared.arity == hidden.arity)                // compare at the LARGER arity, always
        #expect(declared != hidden)                            // wrong, and wrong for the right reason
        #expect(!hidden.isSecretlyStateless)                   // …the hidden law really is contextual

        // A stateless declaration against a stateless law of the same extension is still correct,
        // which is what proves the previous line is measuring contextuality and not the lift itself.
        #expect(LawTable(stateless).lifted == LawTable(Corpora.equivalentSpelling(of: stateless)).lifted)
    }

    @Test("§6.11 #25 — a UTC rollover mid-round changes nothing in PROBE")
    func utcRolloverDoesNotTouchProbe() {
        let snapshot = ProbeSnapshot.fixture(probes: [22, 30])
        #expect(SnapshotIntegrity.validate(snapshot) == nil)
        // Nothing in the round's identity is date-derived: seed, band, targetDelta and law are all fixed.
        #expect(snapshot.seed == OpeningRound.seed)
        #expect(Score.inscribed(par: 7, probesUsed: 2, strikes: 0) == 1000)   // no wall-clock term (§6.1)
    }
}
```

`Modules/Tests/LoomFeatureTests/RoundEdgeCaseTests.swift` — the rows that need the round object:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("§6.11 — the edge cases that need a live round")
@MainActor
struct RoundEdgeCaseTests {

    private func makeRound(_ store: RecordingPersistenceStore) -> Round {
        Round(serving: .openingRound, store: store,
              now: { Date(timeIntervalSince1970: 1_700_000_000) }, cues: SilentCuePlayer())
    }

    @Test("§6.11 #5 — the verdict was committed at t = 0; resume skips the animation")
    func backgroundedDuringTheVerdictBeat() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))                       // t = 0 of the 420 ms beat
        round.scenePhaseChanged(to: .inactive)
        await round.flush()

        let snapshot = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(snapshot.probes == [22])
        let resumed = RoundEntryPlan(snapshot: snapshot, par: 7, in: .standard)
        #expect(resumed.phase == .probing)                    // not .adjudicating — the beat is not replayed
        #expect(resumed.ribbon.probes.count == 1)
    }

    @Test("§6.11 #6 — the page was written at t = 0 of the seal beat; resume lands on the round card")
    func backgroundedDuringTheReveal() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        round.declare(.correctDraft)                          // page, θ, Profile, novelty all at t = 0
        round.scenePhaseChanged(to: .inactive)
        await round.flush()

        #expect(await store.writes(to: .codexShelf(.literal)).count == 1)
        #expect(await store.operations.contains(.delete(.round(.probe))))   // the slot is cleared
        #expect(AppLaunchRoute.initial(suspended: nil, hasFinishedARound: true) == .frame)
    }

    @Test("§6.11 #7 — a force-quit finds the .inactive snapshot, draft included")
    func forceQuit() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        round.openBench()
        round.editDraft(.rampBound(to: .shape))
        round.scenePhaseChanged(to: .inactive)                 // the app switcher backgrounds first
        await round.flush()

        let snapshot = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(snapshot.benchDraft != nil)
        #expect(snapshot.probes == [22])
    }

    @Test("§6.11 #8 — a crash keeps every committed verdict and loses only the draft since .inactive")
    func crashMidRound() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        await round.flush()
        round.openBench()
        round.editDraft(.rampBound(to: .shape))                // no .inactive follows — this is the crash
        let snapshot = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(snapshot.probes == [22])                       // zero probes lost
        #expect(snapshot.benchDraft == nil)                    // the draft since .inactive is gone
    }

    @Test("§6.11 #9 — a phone call is an .inactive; nothing is timed, so nothing needs pausing")
    func phoneCall() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        let before = round.elapsedActive
        round.scenePhaseChanged(to: .inactive)
        round.scenePhaseChanged(to: .active)
        await round.flush()
        #expect(round.phase == .probing)
        #expect(round.elapsedActive >= before)
        #expect(round.probes.count == 1)                       // no probe lost, none gained
    }

    @Test("§6.11 #10 — one queued tap is honoured, further taps are dropped")
    func doubleTapOnProbe() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))                        // input locks
        round.probe(Deck.glyph(id: 30))                        // queued
        round.probe(Deck.glyph(id: 44))                        // dropped
        round.probe(Deck.glyph(id: 60))                        // dropped
        #expect(round.queuedProbe == Deck.glyph(id: 30))
        round.advanceBeat()                                    // t = 420 ms
        await round.flush()
        #expect(round.probes.map(\.glyph) == [Deck.glyph(id: 22), Deck.glyph(id: 30)])
    }

    @Test("§6.11 #11 — the Seal is edge-triggered with no queue; the second tap is discarded")
    func doubleTapOnTheSeal() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        await round.flush()
        round.openBench()
        round.seal()
        round.seal()                                           // inside the 640 ms hold
        #expect(round.declarationCount == 1)
        #expect(round.strikes <= 1)
    }

    @Test("§6.11 #27 — leaving to the run frame and returning costs nothing")
    func returnFromTheRunFrameCostsNothing() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        round.openBench()
        round.editDraft(.rampBound(to: .shape))
        let draft = round.draft
        round.leave(.chevron)
        await round.flush()

        let snapshot = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        let resumed = RoundEntryPlan(snapshot: snapshot, par: 7, in: .standard)
        #expect(resumed.phase == .probing)
        #expect(resumed.draft == draft)
        #expect(resumed.ribbon.probes.count == 1)
        #expect(await store.writes(to: .statistics).isEmpty)    // no record: a suspend is not an end
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter EdgeCaseTests` and
`swift test --package-path Modules --filter RoundEdgeCaseTests`.

Rows 5, 7 and 8 are the three most likely to pass accidentally, because a snapshot that is never written
also never contains a draft. Before implementing, confirm each fails with a `#require` on a **missing
snapshot**, not with a nil draft.

**Step 3 — implement.** Most of these rows are already implemented by T02–T07 and by E08/E09; the work
here is (a) the missing wiring each failing test exposes and (b) nothing else. Any row that needs new
behaviour outside this epic's scope is a **finding**, not a fix: record it in `PROGRESS.md`, open it
against the owning epic, and leave the test failing on this branch only if the owning epic is already
merged — otherwise mark the test `.disabled("E12·T09")`-style with the owner named, never deleted
(`06 T58`).

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/RoundsTests/EdgeCaseTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/RoundEdgeCaseTests.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` — whatever the failing rows expose (queue, `declarationCount`, `elapsedActive`) |
| modify | `tests.json` — **29 entries**, one per row, each naming either its test or its owning task |
| modify | `PROGRESS.md` — the delegation table above, so a reader of §6.11 can find every row |

## Implementation notes

- **The row number is in the test name.** `§6.11 #7 — …`. That is not decoration: it is what makes
  `grep '#6.11 #' -r .` a coverage report, and it is what T10's subagent review will use to check the
  table against the spec.
- **One behaviour per test** (`06 T21`). Row 10 tests the queue, not the queue *and* the compressed
  travel; the 180 ms travel is E08·T06's.
- **`.disabled` is a delegation, never a deletion.** If a row cannot pass because the owning epic has
  not shipped, the test stays in the file with the owner in the reason string. `tests.json` records it
  as `blocked` with the same owner. Rows are never removed and never weakened.
- **Rows 22, 23, 28 and 29 are already written** in T02 and T03. Do not re-write them here; list them in
  `tests.json` pointing at the existing test names. A second assertion of the same behaviour is a second
  source of truth about what the behaviour *is*.
- **Row 4's subtlety.** "The verdict is delivered in full, then `exhausted`" means the transition is
  `probing → adjudicating → revealing(.exhausted)` and never `probing → revealing(.exhausted)`. Assert
  the intermediate phase explicitly; a shortcut here would silently withhold a paid-for bit.
- **Row 15's subtlety.** The comparison is at the *larger* arity always (§3.6): lift the stateless table
  into pair space and compare there. A test that compares a 256-entry table with a 65,536-entry one and
  gets `false` proves nothing — assert the arities match first.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EdgeCaseTests` green (7 tests).
- [ ] `swift test --package-path Modules --filter RoundEdgeCaseTests` green (8 tests).
- [ ] `grep -rn "§6.11 #" HunchCore/Tests Modules/Tests | wc -l` ≥ 15, and every number 1–29 appears exactly once across the tests and the delegation table together.
- [ ] `tests.json` has 29 rows tagged `6.11`, each `pass`, `blocked(<owner>)` or `owned(<epic·task>)` — none absent.
- [ ] No test in either file is deleted or weakened to reach green; any `.disabled` carries an owner in its reason string.
- [ ] `PROGRESS.md` carries the delegation table.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T09: §6.11's 29 rows, fifteen as named tests and fourteen as named owners"`

## Out of scope

- Implementing anything a delegated row needs — the seven other-epic rows are listed, not built.
- DRIFT's seven edge cases (§7.11), ECHO's (§8.10) and SIEVE's (§9.9) — **E12·T09**, **E13·T09**, **E14·T08**.
- The verdict beat's queue *timing* and the 180 ms compressed travel — **E08·T06**.
- The reveal's skip threshold and its announcements — **E09·T10**, **E19·T05**.
