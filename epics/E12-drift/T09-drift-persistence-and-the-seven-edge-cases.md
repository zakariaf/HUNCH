# T09 — DRIFT persistence and the seven edge cases

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | Lifecycle + budgets (DRIFT) — the persistence half · Mid-round snapshot (PROBE), extended to DRIFT |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | The seven edge cases are §7.11's table and each one has to become a **named** test, not a row in a parameterised blob — the skill's `T53` rule is that a named case is what a future regression reports against. It also owns the `TestScoping` trait and the `subdirectory:` trap that kills fixture suites, which this task needs for the `round-drift.json` fixture. |
| `hunch-swift-code` | "Nothing is re-randomised on resume" is a *type* claim: every value the round was built with has to be a stored field rather than something recomputed from the seed. The skill owns the `decodeIfPresent`-plus-default additive-field rule and the `StoreFile` exhaustive switch that decides where the DRIFT fields live. |

## Objective

At the end of this task a DRIFT round survives being killed: `round-drift.json` carries `L₁`, `L₂`,
`N_admits`, `hingeFired`, the three `t`-values, `seamMarkerIndex` and `strikes`, nothing is
re-randomised on resume, and the hinge **neither re-fires nor un-fires**. §7.11's seven edge cases are
seven named passing tests, and starting a second DRIFT round over a suspended one asks first, behind a
confirmation that lives outside the play surface.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.10 | The whole task: the nine extra record fields; "nothing is re-randomised on resume; the hinge neither re-fires nor un-fires"; backgrounding; termination during `hinge` resuming into `settled` with the page present; the mode switch, one suspended round per mode, and the discard confirmation as the only modal, living outside the play surface; DRIFT reads no clock |
| `GAME_DESIGN.md` | §7.11 | The seven edge cases, each with its defined behaviour |
| `GAME_DESIGN.md` | §6.10 | `ProbeSnapshot`'s fields and the two invariants DRIFT inherits: the law is **stored**, not regenerated; verdicts are recomputed from the stored law on every resume |
| `GAME_DESIGN.md` | §11.13 | `round.json`'s row — written after every probe, smallest file, written first — and the schema/migration rules including `decodeIfPresent` with defaults |
| `GAME_DESIGN.md` | §12.7 | The chevron suspends silently in PROBE / DRIFT / ECHO with no confirmation, because nothing is lost |
| `GAME_DESIGN.md` | §14.5 open decision 3 | Four slots, `round-{mode}.json`, SIEVE excluded — already taken at its default by E10·T04 |
| `GAME_DESIGN.md` | §12.2 | The 18-screen inventory, which the discard confirmation must not become a nineteenth member of |
| `ios-swift-guide/06-TESTING.md` | T20, T53, T54, T55 | `TestScoping` for the fixture tree, a named test per case, `subdirectory:` on every resource lookup, the malformed-sibling case |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/PersistenceTests/DriftSnapshotTests.swift`:

```swift
import Testing
@testable import Persistence
@testable import Rounds
import LawGeneration
import HunchTestSupport

@Suite("DRIFT's snapshot — §7.10", .tags(.unit, .presubmission), .fixtureTree)
struct DriftSnapshotTests {

    @Test("Every one of §7.10's nine extra fields round-trips")
    func nineFieldsRoundTrip() throws {
        let before = DriftSnapshotState.fixture(.midRoundPostHinge)
        let data = try JSONEncoder.hunch.encode(before)
        let after = try JSONDecoder.hunch.decode(DriftSnapshotState.self, from: data)
        #expect(after.lawOne == before.lawOne)
        #expect(after.lawTwo == before.lawTwo)
        #expect(after.admitsBeforeHinge == before.admitsBeforeHinge)
        #expect(after.hingeFired == before.hingeFired)
        #expect(after.hingeProbe == before.hingeProbe)
        #expect(after.evidenceProbe == before.evidenceProbe)
        #expect(after.recoveryProbe == before.recoveryProbe)
        #expect(after.seamMarkerIndex == before.seamMarkerIndex)
        #expect(after.strikes == before.strikes)
        #expect(after == before)
    }

    @Test("Both laws are integrity-checked, not only the first")
    func bothLawsAreHashed() throws {
        var snapshot = ProbeSnapshot.fixture(.driftPostHinge)
        snapshot.drift?.lawTwoHash &+= 1
        #expect(SnapshotIntegrity.validate(snapshot) == .failed)
        #expect(SnapshotIntegrity.outcome(for: snapshot) == .voided)
    }

    @Test("THE GATE: a resume re-fires nothing and un-fires nothing")
    func hingeSurvivesTheRoundTrip() throws {
        var round = Round.fixture(.driftMidRound(band: .contextual, probes: 14))
        while round.driftSchedule?.hingeFired == false { round.probeAnything() }
        let fired = try #require(round.driftSchedule?.hinge)

        let data = try JSONEncoder.hunch.encode(round.snapshot)
        let resumed = try Round.resumed(from: JSONDecoder.hunch.decode(ProbeSnapshot.self, from: data))

        #expect(resumed.driftSchedule?.hinge == fired)
        #expect(resumed.driftSchedule?.hingeFired == true)
        #expect(resumed.phase == .runningPost)
        #expect(resumed.probesUsed == round.probesUsed)
    }

    @Test("Nothing is re-randomised: N_admits and the seed glyph are read, never redrawn")
    func nothingIsReRandomised() throws {
        let round = Round.fixture(.driftMidRound(band: .guarded, probes: 6))
        let resumed = try Round.resumed(from: round.snapshot)
        #expect(resumed.driftSchedule?.pair.admitsBeforeHinge
             == round.driftSchedule?.pair.admitsBeforeHinge)
        #expect(resumed.seedGlyph == round.seedGlyph)
        #expect(resumed.driftSchedule?.pair.lawTwo == round.driftSchedule?.pair.lawTwo)
    }

    @Test("Verdicts are recomputed from the two stored laws, so the transcript re-derives exactly")
    func verdictsAreRecomputed() throws {
        let round = Round.fixture(.driftMidRound(band: .contextual, probes: 18))
        let resumed = try Round.resumed(from: round.snapshot)
        #expect(resumed.ribbon.verdicts == round.ribbon.verdicts)
        #expect(round.snapshot.probes.allSatisfy { $0 <= 255 })      // glyph IDs only
    }

    @Test("A pre-hinge resume lands in runningPre and a post-hinge one in runningPost",
          arguments: [(false, DriftPhase.runningPre), (true, DriftPhase.runningPost)])
    func resumeSide(_ fired: Bool, _ phase: DriftPhase) throws {
        let round = try Round.resumed(from: .fixture(fired ? .driftPostHinge : .driftPreHinge))
        #expect(round.phase == phase)
    }

    @Test("Termination during the reveal resumes into settled with the page already present")
    func terminationDuringTheReveal() throws {
        let round = try Round.resumed(from: .fixture(.driftAtHinge))
        #expect(round.phase == .settled(.inscribed(marks: 2, fracture: true)))
        #expect(round.mintedPageExists == true)
    }

    @Test("A v1 snapshot with no DRIFT block decodes as a PROBE round, not as a failure")
    func additiveDecoding() throws {
        let legacy = try Data(contentsOf: Bundle.module.url(forResource: "round-probe",
                                                            withExtension: "json",
                                                            subdirectory: "Fixtures/v1")!)
        let snapshot = try JSONDecoder.hunch.decode(ProbeSnapshot.self, from: legacy)
        #expect(snapshot.drift == nil)
        #expect(snapshot.mode == .probe)
    }

    @Test("round-drift.json stays the smallest file and is written first")
    func writeOrder() async throws {
        let store = InMemoryPersistenceStore()
        try await store.saveRoundEnd(.driftFixture)
        #expect(store.writeOrder.first == .round(.drift))
        #expect(store.byteCount(of: .round(.drift)) < 4_096)
    }

    @Test("DRIFT reads no clock, so a date change cannot alter a suspended round")
    func noClock() throws {
        let round = Round.fixture(.driftMidRound(band: .composite, probes: 9))
        let resumedEarly = try Round.resumed(from: round.snapshot, now: .fixed(.distantPast))
        let resumedLate  = try Round.resumed(from: round.snapshot, now: .fixed(.distantFuture))
        #expect(resumedEarly.driftSchedule == resumedLate.driftSchedule)
    }
}
```

And `HunchCore/Tests/RoundsTests/DriftEdgeCaseTests.swift` — **one named test per §7.11 row**:

```swift
@Suite("§7.11's seven edge cases", .tags(.unit, .presubmission))
struct DriftEdgeCaseTests {

    @Test("EARLY-SEAL — a pre-hinge L₁ declaration is accepted and costs nothing")
    func earlySeal() {
        var s = DriftSchedule.fixture(band: .relational, admits: 5)
        let before = (s.strikes, s.probeCount)
        #expect(s.recordDeclaration(s.pair.lawOne, atProbeCount: 4) == .captured)
        #expect(s.strikes == before.0)
        #expect(s.probeCount == before.1)
        #expect(s.seamMarkerIndex == 4)
        #expect(DriftScore.settle(band: .relational, probesUsed: 4, strikes: 0,
                                  latency: nil, outcome: .win).score
             == DriftScore.settle(band: .relational, probesUsed: 4, strikes: 0,
                                  latency: nil, outcome: .win).score)   // no score change
        #expect(s.hingeFired == true)
    }

    @Test("STARVED-HINGE — fewer than N_admits admits by ceil(0.80·par) fires it anyway")
    func starvedHinge() {
        var s = DriftSchedule.fixture(band: .composite, admits: 6)      // forced at 21
        for i in 1...21 { s.recordProbe(index: i, verdictUnderLawOne: .reject) }
        #expect(s.hinge == DriftHinge(firedAtProbe: 21, trigger: .forced))
    }

    @Test("DEAD-HINGE — never probing inside D and declaring L₁ still delivers the lesson")
    func deadHinge() throws {
        let s = DriftScenario.fixture(.neverProbedInsideD)
        let chosen = try #require(DriftCounterexample.select(declared: s.pair.lawOne,
                                                             pair: s.pair, ribbon: s.ribbon))
        #expect(s.pair.disagrees(on: chosen))
    }

    @Test("CONTEXT-CARRY — the hinge does not touch prev, and the chain stays continuous")
    func contextCarry() {
        let s = DriftSchedule.fixture(.contextualAcrossTheHinge)
        let t = s.hinge!.firedAtProbe
        #expect(s.previousGlyph(forProbe: t + 1) == s.probeGlyph(at: t))
        #expect(s.ribbonChainIsContinuous == true)
    }

    @Test("BLIND-EDIT — D7 makes the edited leaf reachable from the seed glyph by one flick",
          arguments: DriftBudget.servedBands)
    func blindEdit(_ band: Band) throws {
        let report = try #require(DriftPair.makeReporting(seed: Corpora.driftSeed(band: band, index: 2),
                                                          band: band, targetDelta: band.centre,
                                                          avoid: [], in: Corpora.index))
        #expect(report.pair.seedGlyphExposers(from: report.seedGlyph).isEmpty == false)
    }

    @Test("DOUBLE-STRIKE-PRE-HINGE — a loss, and the reveal still plays with L₂ at 40 %")
    func doubleStrikePreHinge() {
        #expect(DriftPhase.struck.transition(on: .counterexampleBeatCompleted(strikes: 2,
                                                                             hingeFired: false))
                == .to(.hinge))
        let g = HingeRevealGeometry(transcript: .fixture(.doubleStrikePreHinge), ribbonLength: 14)
        #expect(g.seamIsDashed == true)
        #expect(g.lawTwoOpacity == C.HingeReveal.unfiredLawOpacity)
    }

    @Test("TWIN-OF-THE-HINGE — twinning the probe that fired (a) is evaluated under L₂")
    func twinOfTheHinge() {
        var s = DriftSchedule.fixture(band: .contextual, admits: 3)
        for i in 1...3 { s.recordProbe(index: i, verdictUnderLawOne: .admit) }
        #expect(s.hinge?.firedAtProbe == 3)
        #expect(s.lawInForce(atProbe: 4) == s.pair.lawTwo)
        // and it is legal: the twin key is never blocked and never refunded (§6.3)
        #expect(s.twinIsPermitted(atProbe: 4) == true)
    }
}
```

And `Modules/Tests/MetaFeatureTests/SuspendedDriftDiscardTests.swift`:

```swift
@Suite("Starting a second DRIFT round over a suspended one — §7.10", .tags(.unit, .presubmission))
struct SuspendedDriftDiscardTests {

    @Test("With no suspended round the conflict is nil and nothing is presented")
    func noConflict() {
        #expect(SuspendedRoundConflict.check(mode: .drift, suspended: nil) == nil)
    }

    @Test("With one suspended DRIFT round, starting another needs a confirmation")
    func conflictRequiresConfirmation() {
        let c = SuspendedRoundConflict.check(mode: .drift, suspended: .driftAtProbe(11))
        #expect(c?.requiresConfirmation == true)
        #expect(c?.discardsSlot == .round(.drift))
    }

    @Test("Confirming discards exactly one slot and starts the new round")
    func confirming() async throws {
        let store = InMemoryPersistenceStore.withSuspendedDrift()
        try await SuspendedRoundConflict.confirmDiscard(.round(.drift), in: store)
        #expect(await store.exists(.round(.drift)) == false)
        #expect(await store.exists(.round(.probe)) == true)
    }

    @Test("Cancelling changes nothing on disk")
    func cancelling() async throws {
        let store = InMemoryPersistenceStore.withSuspendedDrift()
        let before = await store.snapshotOfDisk()
        // the alert's cancel path performs no store call at all
        #expect(await store.snapshotOfDisk() == before)
    }

    @Test("Cancel is the focused action, and the alert lives outside the play surface")
    func alertShape() {
        #expect(SuspendedRoundDiscardAlert.defaultFocus == .cancel)
        #expect(SuspendedRoundDiscardAlert.presentedFrom == .frame)
        #expect(Screen.allCases.contains(.suspendedRoundDiscardAlert) == false)   // not a 19th screen
    }

    @Test("The chevron still suspends silently — this confirmation is only for the second start")
    func chevronIsUnaffected() {
        #expect(LeaveRound.action(mode: .drift, probesUsed: 9, intent: .chevron) == .suspend)
        #expect(SuspendedRoundConflict.check(mode: .drift, suspended: nil) == nil)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter DriftSnapshotTests` then `--filter DriftEdgeCaseTests`
then `swift test --package-path Modules --filter SuspendedDriftDiscardTests`

Expect missing `DriftSnapshotState`, `ProbeSnapshot.drift`, `SnapshotIntegrity` extended to two laws,
`Round.resumed(from:now:)`, `SuspendedRoundConflict`, `SuspendedRoundDiscardAlert`. The
`additiveDecoding` test needs `Fixtures/v1/round-probe.json` from E07·T05 — if it does not exist there,
add it to the fixture tree in **that** file's shape, never a new one.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Then run the simulator sequence in the gate: play past the hinge,
quit, dump `round-drift.json`, relaunch, dump again, and diff. Paste both into `PROGRESS.md`.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/DriftSnapshotState.swift` — the nine fields plus `lawTwoHash` |
| modify | `HunchCore/Sources/Rounds/ProbeSnapshot.swift` — `let drift: DriftSnapshotState?`, additive, `decodeIfPresent` with `nil` |
| modify | `HunchCore/Sources/Rounds/SnapshotIntegrity.swift` — validate both laws; either failure voids |
| modify | `Modules/Sources/LoomFeature/Round.swift` — build a `DriftSchedule` from the stored state on resume; never re-derive it from the seed |
| create | `HunchCore/Sources/Rounds/SuspendedRoundConflict.swift` — the pure policy |
| create | `Modules/Sources/MetaFeature/SuspendedRoundDiscardAlert.swift` — the alert, cancel focused |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/` — add `round-drift.json` beside E07·T05's tree |
| create | `HunchCore/Tests/PersistenceTests/DriftSnapshotTests.swift` |
| create | `HunchCore/Tests/RoundsTests/DriftEdgeCaseTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/SuspendedDriftDiscardTests.swift` |
| modify | `tests.json` — the nine fields, the hinge-survives gate, the seven named cases, the discard policy |
| modify | `DECISIONS.md` — the alert-not-a-screen ruling and the two-hash integrity rule |
| modify | `PROGRESS.md` — the play → quit → relaunch → resume transcript with both `round-drift.json` dumps |

## Implementation notes

### The record's extra fields

```swift
/// §7.10's DRIFT block. Additive on `ProbeSnapshot`: a v1 file without it decodes as a PROBE round.
/// Every field is *stored*, because §7.10's rule is that nothing is re-randomised on resume — which
/// is only true if nothing is re-derived from the seed.
public struct DriftSnapshotState: Codable, Sendable, Equatable {
    public let lawOne: LawNode           // == ProbeSnapshot.law; see the note below
    public let lawTwo: LawNode
    public let lawTwoHash: UInt64        // the same corruption check `lawHash` is, for the second law
    public let admitsBeforeHinge: Int    // N_admits — read on resume, NEVER redrawn
    public let hingeFired: Bool
    public let hingeProbe: Int?
    public let hingeTrigger: DriftHinge.Trigger?
    public let evidenceProbe: Int?
    public let recoveryProbe: Int?
    public let seamMarkerIndex: Int?
    public let strikes: Int
    public let editedLeafIndex: Int      // the reveal's one moving part; deriving it again would be
                                         // a second source of truth for "which part changed"
}
```

Two rulings:

- **`ProbeSnapshot.law` is `L₁`**, and `lawHash` checks it, exactly as in PROBE. `L₂` rides in the DRIFT
  block with its own hash. The alternative — storing the *in-force* law in `law` — would make the field's
  meaning depend on `hingeFired` and would break the PROBE-shaped resume path for no benefit. Record it.
- **Either hash failing voids the round** (§6.11 case 23, §6.10). A DRIFT round whose `L₂` is corrupt is
  not recoverable by falling back to `L₁`: the round would silently become a PROBE round, which is the
  "silently altered" outcome §6.10 forbids by name.

`hingeTrigger` is stored beyond §7.10's list because the reveal needs it (the seam docks to a marker only
for trigger (b)) and because re-deriving it from `seamMarkerIndex != nil` couples two facts that should
be independently readable. It is an additive field with a `decodeIfPresent` default of `nil`.

### "Nothing is re-randomised on resume" — how it is enforced rather than promised

`Round.resumed(from:)` for a DRIFT round constructs the `DriftSchedule` **entirely from stored fields**:

```swift
let pair = DriftPair(lawOne: Law(state.lawOne), lawTwo: Law(state.lawTwo),
                     editedLeafIndex: state.editedLeafIndex, editKind: …,
                     admitsBeforeHinge: state.admitsBeforeHinge)
```

There is **no call to `DriftPair.make` on the resume path** — and that is exactly the assertion to grep
for. The reason is §5.4's, extended: `avoid` moves while a round is suspended, so re-generating from
`(seed, band, targetδ)` can legitimately resolve to a different pair; and `N_admits` re-drawn from the
seed would be stable, but re-*deriving* it invites someone to change the derivation later and silently
move every suspended round's hinge.

The hinge itself neither re-fires nor un-fires because it is not recomputed at all: `hinge` is
`hingeFired ? DriftHinge(firedAtProbe: hingeProbe!, trigger: hingeTrigger!) : nil`, and
`lawInForce(atProbe:)` is a pure function of it (T02). Re-playing the transcript through `recordProbe`
on resume would be the bug — it would count admits again and could fire a *second* hinge at a different
index. Restore the state; do not replay it.

### The seven edge cases, each named

§7.11's table is seven rows and each becomes one `@Test` with the row's name in its title, so a future
failure reports *"TWIN-OF-THE-HINGE failed"* rather than *"case 7 of 7 failed"*. Where a case is already
covered by an earlier task's test (STARVED-HINGE by T02, DOUBLE-STRIKE-PRE-HINGE by T03 and T08,
BLIND-EDIT by T01's D7), the test here is **still written** — it asserts the row's *stated behaviour*
end to end rather than the mechanism, and it is what `tests.json` points at.

Two rows deserve a note:

- **EARLY-SEAL's "no score change"** is not an assertion about a delta; a capture never enters the
  scoring path at all, because `DriftScore.settle` is called once at `settled`. The test states it as an
  invariance of `strikes` and `probeCount` plus the fact that the round continues.
- **TWIN-OF-THE-HINGE** is the one row that is a *reward* rather than a hazard: the twin immediately
  after trigger (a) holds the context fixed and changes only the law, which in a contextual band is the
  cheapest possible hinge detector. It must remain legal, unblocked and unrefunded — §6.3's twin rules
  are untouched by DRIFT, and the test says so.

### The discard confirmation

§7.10: starting a second DRIFT round discards the older one **after a confirmation** — *"the only modal
in the game, and it lives outside the play surface"*. Three decisions:

1. **The policy is a core value**, so it is testable without a Frame:

   ```swift
   public struct SuspendedRoundConflict: Sendable, Equatable {
       public let mode: Mode
       public let discardsSlot: StoreFile
       public var requiresConfirmation: Bool { true }
       public static func check(mode: Mode, suspended: SuspendedRound?) -> SuspendedRoundConflict?
       public static func confirmDiscard(_ slot: StoreFile, in store: any PersistenceStore) async throws
   }
   ```

2. **The alert is not a nineteenth screen.** §12.2's inventory is eighteen and an alert is not a route —
   `NavigationDepthTests` is unaffected. It is presented from the Frame's mode key. Record the ruling,
   and record the tension it resolves: §7.10 calls it *the only modal in the game* while §12.2 already
   lists `ResetConfirmAlert`; the consistent reading is that it is the only modal **in the play flow**,
   and the reset alerts live in Settings, which is chrome. It is a distinct alert from `ResetConfirmAlert`
   because it guards a different object and its body says a different thing.

3. **It is only for starting a second round.** The chevron still suspends silently with no confirmation
   (§12.7), and E17·T04's trailing-swipe-to-discard on the mode key is a different gesture with its own
   treatment. Adding a confirmation to either would break §12.7's stated global claim that confirm-by-repeat
   exists in exactly two places.

**Wiring note.** The Frame does not exist until E17, so this task ships the policy, the alert view and
their tests, and E17·T04 presents it from the DRIFT key. Until then the round-start path is a function
callable from the preview harness. Write that obligation into E17's path as a comment on
`SuspendedRoundConflict.check` and into this task's Out of scope.

### DRIFT reads no clock

§7.10's last sentence, and it is worth an assertion rather than a comment: the `noClock` test resumes the
same snapshot under two absurd `Now` values and expects an identical schedule. Date manipulation affects
the Anomaly and nothing here — which is also why `elapsedActive` and `startedAt` stay exactly what
§6.10 already made them: round-card decoration, never inputs to score, marks or the hinge.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftSnapshotTests` green; `--filter DriftEdgeCaseTests` green with **seven** named tests; `swift test --package-path Modules --filter SuspendedDriftDiscardTests` green.
- [ ] **The gate:** `hingeSurvivesTheRoundTrip` passes, and the simulator transcript in `PROGRESS.md` shows `round-drift.json` byte-identical in `hingeFired`, `hingeProbe`, `hingeTrigger`, `admitsBeforeHinge` and the probe list either side of a quit and relaunch.
- [ ] `grep -rn "DriftPair.make" Modules/Sources/LoomFeature/Round.swift` shows it **only** on the fresh-round path, never on the resume path.
- [ ] `grep -rn "SplitMix64\|admitsBeforeHinge(roundSeed" Modules/Sources/LoomFeature/Round.swift` returns nothing on the resume path.
- [ ] A v1 fixture without a `drift` block decodes green, and `Fixtures/v1/round-drift.json` loads green; every lookup passes `subdirectory:`.
- [ ] Corrupting `lawTwoHash` yields `Outcome.voided`, not a fallback to `L₁`.
- [ ] `grep -n "suspendedRoundDiscardAlert" Modules/Sources/HunchNavigation/Screen.swift` returns nothing — it is not a screen.
- [ ] `DECISIONS.md` records the `law == L₁` ruling, the two-hash integrity rule and the alert-not-a-screen reading.
- [ ] `tests.json` carries an entry per §7.11 row, plus the nine fields and the resume gate.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T09: DRIFT persistence, the seven named edge cases and the suspended-round discard policy"`

## Out of scope

- `ProbeSnapshot`'s existing fields, `StoreFile`, `FilePersistenceStore`, atomic writes and §11.13's write order — **E07·T01/T02/T09**.
- Snapshot **cadence** — after every verdict, after every strike, on `.inactive` — and the `lawHash` → `.voided` path in general — **E10·T02**; this task extends the payload, not the schedule.
- The 900 ms re-entry beat a DRIFT resume plays — **E10·T03**, reused unchanged.
- Abandon / discard / suspend semantics and the three `round-{mode}.json` slots — **E10·T04**.
- Presenting the discard alert from the DRIFT mode key, and the trailing-swipe discard — **E17·T04**.
- The mode key's suspended arc — **E17·T04**; its fraction is `probesUsed / par_DRIFT`, which T04 supplies.
- The Codex page written on a win, including `driftPartner` and `driftHinge` — **E09·T11**.
