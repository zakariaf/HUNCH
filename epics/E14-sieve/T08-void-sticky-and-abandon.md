# T08 — Void, sticky and abandon

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Void / sticky / abandon (SIEVE) · Leaving a round (SCREENS / NAVIGATION — the SIEVE row) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The whole task is `W28`'s question — one type or a scatter of parallel booleans — applied to an anti-cheat. "Quitting buys a re-roll of the law and never an easier one" only holds if `δ_served`, `lawBand` and `s` are frozen in a value the serving layer **cannot** ignore, and "a terminated run is never banked at its frozen score" only holds if the void record is a distinguishable case rather than a flag on a normal record. The skill also carries the `StoreFile` exhaustive-switch ruling that keeps `round(.sieve)` nameable but never written. |
| `hunch-swift-testing` | The SERIAL-VOID sequence is a small state machine over three runs, and it is exactly the kind of thing that gets tested with one happy path and then breaks on the fourth run. Parameterise the sequence, assert the counter's reset condition on every non-void ending, and put a golden `RoundRecord` fixture behind it so the "the attempt log stays truthful" claim is checkable on disk rather than in memory. |

`hunch-chrome-and-meta` is **not** loaded: the chevron's drawing and the overlay are T07's, and the
run frame does not exist in SIEVE.

## Objective

At the end of this task the three ways a SIEVE run can stop being played are three distinct values
with three distinct effect records. A **terminated** run (swipe-kill, OOM, crash) is void — no score,
no Codex effect, no ability update, no foul carried forward — but its record is still written, marked
`void`, carrying `resolvedGlyphs`, `raw` and `idealResolved` at the last resolved glyph boundary; the
target is frozen so the next run is the same difficulty from a different seed; and the **third**
consecutive termination is not voidable, it is scored at its frozen `ratio` and `completion`. An
**abandoned** run — the two-tap chevron, reachable only from `paused` — is scored exactly as a
foul-out at the last resolved glyph and updates the ability normally.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.8 | the void decision in full — what termination is and is not, why a timed run cannot be honestly resumed across a cold launch, that the record is **still written marked `void`** carrying `resolvedGlyphs` / `raw` / `idealResolved` at the last resolved glyph boundary, and that *"a terminated run is never banked at its frozen score"*; **voiding is sticky and bounded** — `δ_served`, `lawBand` and `s` unchanged for the next run, and the third consecutive termination scored normally; **abandoning is not voiding** — `completion = resolvedGlyphs/N`, `ratio` as it stands, `yield = ratio·completion`, marks by `yield`, a page only at `yield ≥ 0.92`, and the ability update runs normally |
| `GAME_DESIGN.md` | §9.9 | SERIAL-VOID: two force-quits leave the target unchanged so runs 2 and 3 are served at the identical target from fresh seeds; the **third** is scored and updates the ability |
| `GAME_DESIGN.md` | §9.5 | `paused --chevron, then confirm tap--> reveal`, **abandoned**, scored as a foul-out at the last resolved glyph |
| `GAME_DESIGN.md` | §12.7 | the SIEVE column of the `scenePhase` table: termination relaunches into the Frame, the run is voided, *"banking a force-quit is the one exploit a timed mode has, and this closes it"*; SIEVE has no chevron while streaming and its exit exists only from `paused` |
| `GAME_DESIGN.md` | §9.10 | SIEVE's interruption-policy cell, which is the one-line summary all three behaviours must agree with |
| `GAME_DESIGN.md` | §11.13 | `stats.json`'s 200-entry `recentRounds` ring of `RoundRecord`s, which is where the void record lands; `round.json`'s row, which SIEVE never writes |
| `GAME_DESIGN.md` | §14.5 open decision 3 | four `round-{mode}.json` slots, **SIEVE excluded (it voids rather than suspends)** — already taken at its default in **E10·T04** |
| `GAME_DESIGN.md` | §6.10 | PROBE's sticky target, the precedent §9.8 says SIEVE takes *"the same rule"* from |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | one type instead of parallel fields; exhaustive `switch` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveTerminationTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import Archive                     // RoundRecord
import HunchTestSupport

@Suite("SIEVE void, sticky and abandon — §9.8, §9.9", .tags(.unit, .presubmission))
struct SieveTerminationTests {

    private func partialRun(resolved: Int = 20) -> SieveRunState {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .contextual, index: 0),
                                serving: SieveDifficulty.serving(targetDelta: 0.525,
                                                                 lawDifficulty: 0.525))
        for index in 0..<resolved { run.resolve(index: index, tapped: run.stream.isLawful(at: index)) }
        return run
    }

    // MARK: void — what it costs and what it does not

    @Test("a terminated run is void: no score, no Codex effect, no ability update, no foul carried")
    func terminationVoids() {
        let ending = SieveTermination.resolve(run: partialRun(), cause: .terminated,
                                              consecutiveTerminations: 0)
        #expect(ending.ending == .voided)
        #expect(ending.effects == SieveEffects(points: 0, marks: 0,
                                               updatesAbility: false, mintsCodexPage: false,
                                               carriesFoulsForward: false, writesRecord: true,
                                               recordIsVoid: true, freezesTarget: true))
    }

    @Test("a terminated run is NEVER banked at its frozen score — that is the exploit voiding closes")
    func terminationIsNeverBanked() {
        let ending = SieveTermination.resolve(run: partialRun(resolved: 74), cause: .terminated,
                                              consecutiveTerminations: 0)
        #expect(ending.effects.points == 0)
        #expect(ending.frozen.ratio > 0.0)                 // the frozen figures are still recorded…
        #expect(ending.effects.points == 0)                // …and still worth nothing
    }

    @Test("the record IS written, marked void, at the last resolved glyph boundary")
    func voidRecordIsStillWritten() {
        let run = partialRun(resolved: 20)
        let ending = SieveTermination.resolve(run: run, cause: .terminated, consecutiveTerminations: 0)
        let record = ending.roundRecord
        #expect(record.isVoid)
        #expect(record.resolvedGlyphs == 20)
        #expect(record.raw == run.score.raw)
        #expect(record.idealResolved == run.score.idealResolved)
        #expect(record.score == 0)
        #expect(record.mode == .sieve)
    }

    @Test("the frozen ratio and completion remain recoverable from the void record")
    func frozenFiguresAreRecoverable() {
        let ending = SieveTermination.resolve(run: partialRun(resolved: 20), cause: .terminated,
                                              consecutiveTerminations: 0)
        let rebuilt = SieveScore(raw: ending.roundRecord.raw,
                                 idealResolved: ending.roundRecord.idealResolved,
                                 glyphCount: ending.roundRecord.glyphCount,
                                 resolvedGlyphs: ending.roundRecord.resolvedGlyphs)
        #expect(isApproximatelyEqual(rebuilt.ratio, ending.frozen.ratio, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(rebuilt.completion, ending.frozen.completion, absoluteTolerance: 1e-12))
    }

    // MARK: sticky

    @Test("a void leaves δ_served, lawBand and s unchanged for the next run")
    func voidFreezesTheTarget() {
        let run = partialRun()
        let ending = SieveTermination.resolve(run: run, cause: .terminated, consecutiveTerminations: 0)
        let next = ending.nextServing
        #expect(next?.lawBand == run.serving.lawBand)
        #expect(next?.tempoStep == run.serving.tempoStep)
        #expect(next?.servedDelta == run.serving.servedDelta)
    }

    @Test("the next run is a different SEED at the same target — a re-roll of the law, never an easier one")
    func stickyIsASeedReroll() {
        let run = partialRun()
        let ending = SieveTermination.resolve(run: run, cause: .terminated, consecutiveTerminations: 0)
        #expect(ending.nextServing?.reusesTarget == true)
        #expect(ending.nextServing?.reusesSeed == false)
    }

    @Test("a non-void ending clears the frozen target",
          arguments: [SieveEndCause.sieved, .fouled, .abandoned])
    func nonVoidEndingsUnfreeze(_ cause: SieveEndCause) {
        let ending = SieveTermination.resolve(run: partialRun(), cause: cause,
                                              consecutiveTerminations: 2)
        #expect(ending.effects.freezesTarget == false)
        #expect(ending.nextServing == nil)
    }

    // MARK: bounded — the third consecutive termination

    @Test("SERIAL-VOID — voids 1 and 2 are free; the third termination is SCORED",
          arguments: [(0, true), (1, true), (2, false), (3, false)])
    func thirdTerminationIsScored(_ priorTerminations: Int, _ expectVoid: Bool) {
        let ending = SieveTermination.resolve(run: partialRun(resolved: 30), cause: .terminated,
                                              consecutiveTerminations: priorTerminations)
        #expect((ending.ending == .voided) == expectVoid)
        if !expectVoid {
            #expect(ending.effects.updatesAbility)
            #expect(ending.effects.points > 0)
            #expect(ending.effects.recordIsVoid == false)
        }
    }

    @Test("the third termination is scored at its FROZEN ratio and completion, not at zero and not at full")
    func thirdTerminationUsesFrozenFigures() {
        let run = partialRun(resolved: 30)
        let ending = SieveTermination.resolve(run: run, cause: .terminated, consecutiveTerminations: 2)
        #expect(isApproximatelyEqual(ending.frozen.completion,
                                     30.0 / Double(run.stream.glyphs.count),
                                     absoluteTolerance: 1e-12))
        #expect(ending.effects.points == SieveScore.points(yield: ending.frozen.yield))
        #expect(ending.effects.marks == SieveScore.marks(yield: ending.frozen.yield,
                                                         foulsOutsideTheTell: run.foulsOutsideTheTell))
    }

    @Test("the consecutive counter resets on any ending that is not a termination",
          arguments: [SieveEndCause.sieved, .fouled, .abandoned])
    func counterResets(_ cause: SieveEndCause) {
        #expect(SieveTermination.nextConsecutiveCount(after: cause, from: 2) == 0)
        #expect(SieveTermination.nextConsecutiveCount(after: .terminated, from: 2) == 3)
    }

    // MARK: abandon — a foul-out, not a void

    @Test("an abandoned run is scored exactly as a foul-out at the last resolved glyph")
    func abandonIsAFoulOut() {
        let run = partialRun(resolved: 40)
        let abandoned = SieveTermination.resolve(run: run, cause: .abandoned, consecutiveTerminations: 0)
        let fouled = SieveTermination.resolve(run: run, cause: .fouled, consecutiveTerminations: 0)
        #expect(abandoned.frozen == fouled.frozen)
        #expect(abandoned.effects.points == fouled.effects.points)
        #expect(abandoned.effects.marks == fouled.effects.marks)
        #expect(abandoned.effects.updatesAbility)
        #expect(abandoned.effects.recordIsVoid == false)
        #expect(abandoned.effects.freezesTarget == false)
    }

    @Test("an abandoned run mints a page only at yield ≥ 0.92 — which needs a nearly complete run")
    func abandonMintsAPageOnlyWhenAlmostDone() {
        let nearlyDone = partialRun(resolved: 75)
        let barelyStarted = partialRun(resolved: 5)
        #expect(SieveTermination.resolve(run: barelyStarted, cause: .abandoned,
                                         consecutiveTerminations: 0).effects.mintsCodexPage == false)
        _ = nearlyDone      // a flawless 75-of-76 run can clear 0.92; a 5-of-76 run mathematically cannot
        #expect(SieveTermination.pageGate(for: .abandoned) == .yieldAtLeast(0.92))
        #expect(SieveTermination.pageGate(for: .sieved) == .ratioAtLeast(0.92))
    }

    @Test("abandoning is reachable only from paused — the chevron does not exist while streaming")
    func abandonOnlyFromPaused() {
        #expect(SieveTermination.canAbandon(from: .paused(.body)))
        #expect(SieveTermination.canAbandon(from: .streaming(.body)) == false)
        #expect(SieveTermination.canAbandon(from: .fouling) == false)
        #expect(SieveTermination.canAbandon(from: .reveal) == false)
    }

    // MARK: SIEVE never suspends

    @Test("SIEVE has no suspended-round slot — it voids rather than suspends (open decision 3)")
    func sieveNeverSuspends() {
        #expect(Mode.sieve.suspends == false)
        #expect(SieveTermination.writesSuspendedRound == false)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveTerminationTests`

Expect missing `SieveTermination`, `SieveEndCause`, `SieveEffects`, `SieveEnding.voided`,
`RoundRecord.isVoid` and `SieveScore.init(raw:idealResolved:glyphCount:resolvedGlyphs:)`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveTermination.swift` — `SieveTermination`, `SieveEndCause`, `SieveEffects`, `SievePageGate` |
| modify | `HunchCore/Sources/Rounds/SieveScore.swift` — the second initialiser that rebuilds a score from a frozen `(raw, idealResolved, glyphCount, resolvedGlyphs)` |
| modify | `HunchCore/Sources/Archive/RoundRecord.swift` — `isVoid`, `resolvedGlyphs`, `raw`, `idealResolved`, `glyphCount`, all `decodeIfPresent` with defaults (§11.13's additive-field rule) |
| modify | `HunchCore/Sources/Ladder/ServingPolicy.swift` — read the frozen `SieveServing` before running the 13 steps for SIEVE |
| modify | `Modules/Sources/LoomFeature/SieveRun.swift` — the `scenePhase → .background` write of the frozen figures; the chevron's `.abandonConfirmed` path |
| create | `HunchCore/Tests/RoundsTests/SieveTerminationTests.swift` |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/stats.json` — one void `RoundRecord` in the ring, so the fixture proves the shape decodes |
| modify | `tests.json` — six entries: void costs nothing, void record written, sticky target, third-termination-scored, counter reset, abandon-as-foul-out |
| modify | `DECISIONS.md` — the void record's field set, and the two different page gates |

## Implementation notes

### Four causes, one resolver, one effects record

```swift
public enum SieveEndCause: UInt8, Hashable, Sendable, CaseIterable {
    case sieved         // all N resolved
    case fouled         // third foul
    case abandoned      // the two-tap chevron, from `paused` only
    case terminated     // swipe-kill, OOM, crash — NOT backgrounding
}

public struct SieveEffects: Hashable, Sendable {
    public let points: Int
    public let marks: Int
    public let updatesAbility: Bool
    public let mintsCodexPage: Bool
    public let carriesFoulsForward: Bool
    public let writesRecord: Bool          // always true — the attempt log stays truthful
    public let recordIsVoid: Bool
    public let freezesTarget: Bool
}
```

`writesRecord` is `true` in all four cases and is still a field rather than an omission, because
§9.8's sentence *"the run record is still written, marked `void`, so the attempt log stays truthful"*
is the thing a future reviewer is most likely to "optimise away" on the grounds that a void run has
no score. It has no score and it still happened.

`carriesFoulsForward` exists only to be `false` everywhere. §9.8 lists it among the things a void
does not do, which means somebody once thought it might; naming it and asserting it costs one line
and closes the question permanently.

### Why the abandon path reuses the fouled path

```swift
case .abandoned, .fouled:
    // §9.8 — "An abandoned run is scored exactly as a foul-out at the last resolved glyph."
    // Not "similarly to". The two branches share one expression on purpose.
```

`abandonIsAFoulOut` asserts the two are byte-equal rather than merely close, which is the only test
that survives a future edit to either. The *reason* they are the same is worth carrying in the doc
comment: the exit is deliberate and confirmed, so it is a choice about this run rather than an
accident of the operating system, and treating a chosen exit as a non-event is the same censoring
problem in a nicer costume.

The one place they differ is the page gate, and it differs for both of them from the sieved case:

```swift
public enum SievePageGate: Hashable, Sendable {
    case ratioAtLeast(Double)     // sieved
    case yieldAtLeast(Double)     // abandoned / fouled
    case never                    // voided
}
```

§9.6 gates a sieved page on `ratio ≥ 0.92`; §9.8 gates an abandoned page on `yield ≥ 0.92`. On a
sieved run `completion = 1` so the two coincide, which is why it is easy to write one and think you
have written both. The enum makes the difference impossible to lose.

### Sticky, and the shape that makes it enforceable

```swift
public struct FrozenServing: Hashable, Sendable {
    public let lawBand: Band
    public let tempoStep: Int
    public let servedDelta: Double
    public var reusesTarget: Bool { true }
    public var reusesSeed: Bool { false }
}
```

The serving layer reads this **before** running §10.3's thirteen steps for SIEVE and short-circuits
steps 1–12 when it is present. That is the only implementation in which the guarantee holds: if the
policy ran normally and then had its output overwritten, a future edit to step 11 could silently
reintroduce the drift. `reusesSeed == false` is what makes it *"a re-roll of the law, never an easier
one"* — same target, fresh seed, different law.

`FrozenServing` lives in `ladder.json`'s `ServingState` (§11.13), not in `round.json` — SIEVE never
writes `round.json` (open decision 3, E10·T04). It is cleared by the first non-terminated ending.

### The bound: two escapes is generous, three is a strategy

```swift
public static func resolve(run: SieveRunState, cause: SieveEndCause,
                           consecutiveTerminations: Int) -> SieveTermination.Outcome {
    let isVoidable = cause == .terminated && consecutiveTerminations < 2
    …
}
```

Read the boundary carefully against §9.8: *"After **two consecutive voids**, the third run is not
voidable."* So `consecutiveTerminations` counts *prior* voids, and `< 2` means the first two
terminations void and the third does not. The parameterised test pins all four cases including the
fourth, because an off-by-one here is the difference between a closed exploit and a three-run cycle.

`nextConsecutiveCount(after:from:)` resets to 0 on `sieved`, `fouled` **and** `abandoned`. An
abandoned run is a scored outcome, so it breaks the streak — which is also why abandoning is the
honest exit and terminating is not.

### The void record's field set

§9.8 names three fields — `resolvedGlyphs`, `raw`, `idealResolved` — *"at the last resolved glyph
boundary"*, and says the frozen `ratio`/`completion` *"remain recoverable"*. That phrasing is a
design instruction: store the two **inputs** and derive the two **ratios**, never store all four.
`glyphCount` has to ride along as well or `completion` is not recoverable, which is a fourth field
§9.8 does not name; record that in `DECISIONS.md` as a necessary addition rather than quietly adding
it. All four decode with `decodeIfPresent` and defaults, per §11.13's additive-field rule, and one
void record goes into `Fixtures/v1/stats.json` so the shape is proved against the migration test
rather than against a unit test alone.

### What this task must not do

It must not resume a SIEVE run. §9.8's first sentence is the reason: *"a timed run cannot be honestly
resumed across a cold launch."* Relaunch after termination opens the **Frame** (§12.7), not the round.
There is no `round-sieve.json`, no snapshot slot, and no code path that reads one — E10·T04 already
made `LeaveRound.action(mode: .sieve, …)` return `nil` and put a `precondition` on the write path;
this task asserts that from the SIEVE side so the two epics agree.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveTerminationTests` green — all fourteen tests.
- [ ] `swift test --package-path HunchCore --filter PersistenceTests` green with the void `RoundRecord` in `Fixtures/v1/stats.json`.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/SieveTermination.swift` returns nothing.
- [ ] `grep -rn "round-sieve\|StoreFile.round(.sieve)" HunchCore/Sources Modules/Sources` shows no write call site.
- [ ] The `.abandoned` and `.fouled` branches share one scoring expression — verified by reading the file, and asserted byte-equal by `abandonIsAFoulOut`.
- [ ] `SievePageGate` has three cases and `pageGate(for:)` returns `.ratioAtLeast` for `.sieved` and `.yieldAtLeast` for the other two scored causes.
- [ ] `ServingPolicy` short-circuits steps 1–12 when a `FrozenServing` is present for SIEVE — verified by a test that a frozen target survives a `reach`/`relief` change.
- [ ] `DECISIONS.md` records the void record's four fields (with `glyphCount` named as the necessary addition) and the two different page gates.
- [ ] `tests.json` carries the six entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes storing `ratio` and `completion` on the record instead of `raw`/`idealResolved`/`resolvedGlyphs`/`glyphCount`, decline: two homes for one fact, and §9.8 names the inputs.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically to check the `< 2` boundary against §9.8's "after two consecutive voids, the third run is not voidable".
4. Commit: `git commit -m "E14/T08: SIEVE void, the sticky target, the third-termination rule and abandon"`

## Out of scope

- The chevron's drawing, its two-tap latch and the pause overlay it lives on — **T07**. This task consumes the confirmed intent.
- The 0.85 steady-stream multiplier, which multiplies `points` in every scored cause — **T09**.
- Consuming `FrozenServing` inside §10.3's thirteen steps, and the `reach`/`relief` interaction — **E11·T03/T04/T06**. This task writes it and asserts the short-circuit.
- `RoundRecord`'s other fields and the 200-entry ring's eviction — **E07·T09 / E16·T11**.
- Minting the Codex page the gate permits — **E15·T01/T06**.
- The `scenePhase` plumbing itself — **T07**; this task only distinguishes backgrounding from termination.
