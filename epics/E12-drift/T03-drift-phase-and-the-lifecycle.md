# T03 — `DriftPhase` and the lifecycle

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Lifecycle + budgets (DRIFT) — the lifecycle half |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This is E07·T07's problem a second time: a `(phase, event) -> phase` function over two enums with associated values cannot be proved exhaustive by one `switch`, and the shape that *is* exhaustive in both directions — an outer switch over the phase, one private helper per case, each an exhaustive switch over the event — is the skill's `W29` ruling. Copy the shape, not just the idea; the two machines must read alike or a reviewer cannot diff them. |

## Objective

At the end of this task DRIFT's round is a nine-phase machine with a total, exhaustively tested
transition function, including the two paths §7.4 adds to PROBE that have no counterpart there: a
pre-hinge correct declaration that is *accepted and continues the round*, and a post-hinge `L₁`
declaration that produces the **dead-law strike**. Both loss paths — the second strike and
`cap_DRIFT` — land in the same `hinge` phase, so a lost round still plays the reveal.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.4 | The nine phases verbatim and the ten-row transition table, including the side-effect column |
| `GAME_DESIGN.md` | §7.5 | Win = an `L₂` declaration at any point after the hinge; loss = second strike or `cap_DRIFT`; two strikes as canon §4.5 |
| `GAME_DESIGN.md` | §7.6 | The post-hinge `L₁` path is a strike whose counterexample is special; and that a loss before the hinge still plays the full reveal with the un-fired `L₂` at 40 % |
| `GAME_DESIGN.md` | §7.11 | DOUBLE-STRIKE-PRE-HINGE — two wrong declarations before the hinge is a loss and the reveal still plays |
| `GAME_DESIGN.md` | §6.1 | PROBE's machine, which this one must not contradict: the model never waits on an animation; every verdict is committed at t = 0 and merely displayed later |
| `GAME_DESIGN.md` | §6.8 | The 640 ms verdict-blind seal hold, which DRIFT reuses; the Bench auto-collapse after a strike and the absence of a forced probe |
| `GAME_DESIGN.md` | §7.10 | Resume "enters the same phase at the same probe index", and a termination during `hinge` resumes into `settled` |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | Exhaustive `switch`, no `default:`, in **both** directions |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20 | The transitions are a pure core function; the durations are `LoomFeature`'s |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/DriftPhaseTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration
import Glyphs

@Suite("DriftPhase and the transition table — §7.4", .tags(.unit, .presubmission))
struct DriftPhaseTests {

    @Test("Nine phases, exactly as §7.4 declares them")
    func nineCases() {
        #expect(DriftPhase.allCases.count == 9)
        #expect(DriftPhase.allCases == [.arming, .priming, .runningPre, .runningPost,
                                        .declaring, .adjudicating, .struck, .hinge, .settled])
    }

    // MARK: the opening

    @Test("arming → priming on generation; the seed glyph is in the throat")
    func arming() {
        #expect(DriftPhase.arming.transition(on: .roundGenerated) == .to(.priming))
    }

    @Test("A resume never lands in `declaring`, and lands on the side the hinge left it")
    func resume() {
        #expect(DriftPhase.arming.transition(on: .snapshotRestored(integrityHolds: true,
                                                                   hingeFired: false, probesUsed: 0))
                == .to(.priming))
        #expect(DriftPhase.arming.transition(on: .snapshotRestored(integrityHolds: true,
                                                                   hingeFired: false, probesUsed: 6))
                == .to(.runningPre))
        #expect(DriftPhase.arming.transition(on: .snapshotRestored(integrityHolds: true,
                                                                   hingeFired: true, probesUsed: 12))
                == .to(.runningPost))
        #expect(DriftPhase.arming.transition(on: .snapshotRestored(integrityHolds: false,
                                                                   hingeFired: true, probesUsed: 12))
                == .to(.settled(.voided)))
    }

    @Test("priming → runningPre on the first Dial commit, through the verdict beat")
    func firstDialCommit() {
        #expect(DriftPhase.priming.transition(on: .probeSubmitted(.reject)) == .to(.adjudicating))
        #expect(DriftPhase.adjudicating.transition(
                    on: .verdictBeatCompleted(hingeFiredOnThisProbe: false, capReached: false))
                == .to(.runningPre))
    }

    // MARK: the hinge, which is invisible

    @Test("runningPre → runningPost when the verdict beat reports the hinge fired — no other effect")
    func hingeCrossing() {
        #expect(DriftPhase.adjudicating.transition(
                    on: .verdictBeatCompleted(hingeFiredOnThisProbe: true, capReached: false))
                == .to(.runningPost))
    }

    @Test("Once post-hinge, a verdict beat never returns to runningPre")
    func postHingeIsAbsorbing() {
        #expect(DriftPhase.runningPost.transition(on: .probeSubmitted(.admit)) == .to(.adjudicating))
        #expect(DriftPhase.adjudicating.transition(
                    on: .verdictBeatCompleted(hingeFiredOnThisProbe: false, capReached: false,
                                              hingeAlreadyFired: true))
                == .to(.runningPost))
    }

    // MARK: declaring

    @Test("The Bench opens from either running phase and returns to the one it came from")
    func benchRoundTrip() {
        #expect(DriftPhase.runningPre.transition(on: .benchOpened) == .to(.declaring))
        #expect(DriftPhase.runningPost.transition(on: .benchOpened) == .to(.declaring))
        #expect(DriftPhase.declaring.transition(on: .benchDismissed(hingeFired: false))
                == .to(.runningPre))
        #expect(DriftPhase.declaring.transition(on: .benchDismissed(hingeFired: true))
                == .to(.runningPost))
    }

    @Test("The Seal enters the verdict-blind hold, identically for every outcome")
    func sealEntersTheHold() {
        #expect(DriftPhase.declaring.transition(on: .sealPressed) == .to(.adjudicating))
    }

    // MARK: the four declaration outcomes

    @Test("CAPTURE: pre-hinge L₁ is accepted and the round continues under L₂")
    func capture() {
        #expect(DriftPhase.adjudicating.transition(on: .declarationResolved(.captured))
                == .to(.runningPost))
    }

    @Test("WIN: post-hinge L₂ goes to the hinge reveal")
    func win() {
        #expect(DriftPhase.adjudicating.transition(on: .declarationResolved(.correct))
                == .to(.hinge))
    }

    @Test("DEAD LAW: post-hinge L₁ is a strike, not a win and not a capture")
    func deadLaw() {
        #expect(DriftPhase.adjudicating.transition(on: .declarationResolved(.deadLaw))
                == .to(.struck))
    }

    @Test("Anything else is the ordinary strike, on either side of the hinge")
    func ordinaryStrike() {
        #expect(DriftPhase.adjudicating.transition(on: .declarationResolved(.wrong))
                == .to(.struck))
    }

    // MARK: strikes and the two losses

    @Test("The first strike returns to the running phase; the second ends the round")
    func strikes() {
        #expect(DriftPhase.struck.transition(on: .counterexampleBeatCompleted(strikes: 1,
                                                                             hingeFired: false))
                == .to(.runningPre))
        #expect(DriftPhase.struck.transition(on: .counterexampleBeatCompleted(strikes: 1,
                                                                             hingeFired: true))
                == .to(.runningPost))
        #expect(DriftPhase.struck.transition(on: .counterexampleBeatCompleted(strikes: 2,
                                                                             hingeFired: true))
                == .to(.hinge))
    }

    @Test("DOUBLE-STRIKE-PRE-HINGE is a loss and still enters the reveal")
    func doubleStrikePreHinge() {
        #expect(DriftPhase.struck.transition(on: .counterexampleBeatCompleted(strikes: 2,
                                                                             hingeFired: false))
                == .to(.hinge))
    }

    @Test("cap_DRIFT ends the round from either running phase, after the verdict resolves in full",
          arguments: [true, false])
    func capLoss(_ hingeFired: Bool) {
        #expect(DriftPhase.adjudicating.transition(
                    on: .verdictBeatCompleted(hingeFiredOnThisProbe: false, capReached: true,
                                              hingeAlreadyFired: hingeFired))
                == .to(.hinge))
    }

    @Test("hinge → settled on completion or skip, and settled is terminal but for leaving")
    func settling() {
        #expect(DriftPhase.hinge.transition(on: .revealCompleted) == .to(.settled(.broken)))
        #expect(DriftPhase.settled(.broken).transition(on: .left) == .exit)
    }

    // MARK: totality

    @Test("Every phase answers every event — the function is total and never traps",
          arguments: DriftPhase.allCases, DriftEvent.exhaustiveSamples)
    func totality(_ phase: DriftPhase, _ event: DriftEvent) {
        _ = phase.transition(on: event)      // must not trap; `.ignored` is a legal answer
    }

    @Test("Input-locked phases ignore every player input")
    func lockedPhasesIgnoreInput() {
        for phase in [DriftPhase.adjudicating, .struck, .hinge] {
            #expect(phase.transition(on: .probeSubmitted(.admit)) == .ignored)
            #expect(phase.transition(on: .benchOpened) == .ignored)
            #expect(phase.transition(on: .sealPressed) == .ignored)
        }
    }

    @Test("Every phase maps onto a PROBE phase, so the two machines cannot drift apart")
    func mapsOntoProbe() {
        #expect(DriftPhase.runningPre.probeEquivalent == RoundPhase.probing)
        #expect(DriftPhase.runningPost.probeEquivalent == RoundPhase.probing)
        #expect(DriftPhase.priming.probeEquivalent == RoundPhase.probing)
        #expect(DriftPhase.struck.probeEquivalent == RoundPhase.counterexample)
        #expect(DriftPhase.allCases.allSatisfy { $0.probeEquivalent != nil })
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DriftPhaseTests`

Expect missing `DriftPhase`, `DriftEvent`, `DriftTransition`, `DriftEvent.exhaustiveSamples`,
`probeEquivalent`. The `.to(.settled(.voided))` case needs E07·T07's `Outcome`, which already exists.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Add a `DriftEvent` case and all nine helpers must fail to compile.
Verify that by adding a throwaway case, watching nine errors, and removing it.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/DriftPhase.swift` — `DriftPhase`, `DriftEvent`, `DriftTransition`, `transition(on:)`, the nine helpers |
| modify | `HunchCore/Sources/Rounds/DriftSchedule.swift` — expose `strikes` and `hingeFired` as the facts the events carry |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `DriftEvent.exhaustiveSamples` |
| create | `HunchCore/Tests/RoundsTests/DriftPhaseTests.swift` |
| modify | `tests.json` — the nine-phase count, the transition table's totality, the dead-law path, both loss paths |
| modify | `DECISIONS.md` — the `adjudicating` reading and the missing probe-beat phase |

## Implementation notes

### The nine phases, verbatim

```swift
public enum DriftPhase: Sendable, Equatable, CaseIterable {
    case arming, priming, runningPre, runningPost,
         declaring, adjudicating, struck, hinge, settled(Outcome)
}
```

Copy §7.4's declaration and add `CaseIterable` and `Equatable` and nothing else — the same discipline
E07·T07 applied to `RoundPhase`. `settled` takes E07·T07's `Outcome` because the round card and the
record are shared with PROBE; a second outcome enum would be `W28` in a different costume.
(`CaseIterable` over an enum with an associated value needs a hand-written `allCases`; write it, with
`.settled(.broken)` as the representative, and let the count assertion above police it.)

### `adjudicating` is the declaration hold, and the probe beat is not a phase

§7.4 lists nine phases and its table has **no row for the 420 ms probe verdict beat**, while three of
its rows are Seal rows and one of them is annotated *"adjudication commits before any animation"*. PROBE's
eight phases have both a probe `adjudicating(Verdict)` and a declaration `sealing`; DRIFT's nine have
one word for the two jobs. The reading this task ships:

> **`adjudicating` is the declaration's 640 ms verdict-blind hold** (PROBE's `sealing`). The probe's
> 420 ms beat is **not** a DriftPhase; it is the input-lock window inside `priming` / `runningPre` /
> `runningPost`, enforced by E08·T06's `InputLock` exactly as in PROBE.

Two reasons, and record both in `DECISIONS.md`:

1. The mode's entire drama is on the declaration path — capture, dead law, ordinary strike, win are four
   different destinations from one Seal press — so that is the path that must be phased. The probe beat
   has one destination.
2. DRIFT is specified as adding nothing to PROBE's surface. Reusing E08·T06's lock unchanged is what
   makes that true in code rather than in prose; a DRIFT-only probe phase would be a second
   implementation of the 420/320 ms window and the single-slot queue.

`.verdictBeatCompleted` therefore carries the probe beat's *results* into the machine, which is E07·T07's
own convention (`snapshotRestored(integrityHolds:)`, `verdictBeatCompleted(capReached:)`): the beat is
displayed by `LoomFeature`, and the phase machine learns only what it decides on.

### `DriftEvent`

```swift
public enum DriftEvent: Sendable, Equatable {
    case roundGenerated
    /// §7.10: resume enters the same phase at the same probe index — never `declaring` (§6.11 case 28).
    case snapshotRestored(integrityHolds: Bool, hingeFired: Bool, probesUsed: Int)
    /// The verdict is already computed and committed at t = 0 of the beat (§6.1), so it arrives here.
    case probeSubmitted(Verdict)
    /// The three facts the beat resolves. `hingeFiredOnThisProbe` is T02's decision, made at the
    /// boundary; `hingeAlreadyFired` distinguishes "still pre" from "already post" and defaults false.
    case verdictBeatCompleted(hingeFiredOnThisProbe: Bool, capReached: Bool,
                              hingeAlreadyFired: Bool = false)
    case benchOpened
    case benchDismissed(hingeFired: Bool)
    /// Unbarred only. A barred Seal emits no event — it pulses the offending rail (§4.3, E09·T07).
    case sealPressed
    case declarationResolved(DriftDeclarationOutcome)
    /// §6.8: the Bench auto-collapses and there is **no forced probe** before re-declaring.
    case counterexampleBeatCompleted(strikes: Int, hingeFired: Bool)
    case revealCompleted
    case abandoned(probesUsed: Int)
    case left
}
```

Every event that could send the machine to either side of the hinge carries `hingeFired` as a
parameter rather than reading it from a captured `DriftSchedule`. That is what keeps `transition(on:)`
a pure function of `(phase, event)` and therefore exhaustively testable in one table — the same
property E07·T07 bought and for the same reason.

### The transition table, complete

`—` means `.ignored`. Every cell not listed is `.ignored`.

| From | Event | To | Side effect (owned by `Round`, not by this function) |
|---|---|---|---|
| `arming` | `roundGenerated` | `priming` | seed glyph drawn into the throat |
| `arming` | `snapshotRestored(true, false, 0)` | `priming` | 900 ms re-entry beat (E10·T03) |
| `arming` | `snapshotRestored(true, false, n>0)` | `runningPre` | as above |
| `arming` | `snapshotRestored(true, true, _)` | `runningPost` | as above; the hinge is **restored, not replayed** |
| `arming` | `snapshotRestored(false, _, _)` | `settled(.voided)` | no beat sheet; broken-seal round card (§6.11 case 23) |
| `priming` · `runningPre` · `runningPost` | `probeSubmitted(_)` | `adjudicating` | *no* — see the ruling above: the probe beat is the input lock, and `Round` does not enter `adjudicating` for a probe. This row exists only for the **first** transition out of `priming`; see the note below |
| `priming` · `runningPre` · `runningPost` | `benchOpened` | `declaring` | 380 ms Dial→Bench |
| `priming` · `runningPre` · `runningPost` | `abandoned(0)` | `exit` | discarded outright, no record (§6.10) |
| `priming` · `runningPre` · `runningPost` | `abandoned(n>0)` | `settled(.abandoned)` | score 0, no θ update, sticky target (E10·T04) |
| `adjudicating` | `verdictBeatCompleted(hinge: false, cap: false, already: false)` | `runningPre` | one par tick fills |
| `adjudicating` | `verdictBeatCompleted(hinge: true, cap: false, _)` | `runningPost` | `t_hinge` recorded; **no visible change** |
| `adjudicating` | `verdictBeatCompleted(hinge: false, cap: false, already: true)` | `runningPost` | — |
| `adjudicating` | `verdictBeatCompleted(_, cap: true, _)` | `hinge` | **loss**; the cap-th verdict was delivered in full first (§6.11 case 4) |
| `declaring` | `sealPressed` | `adjudicating` | 640 ms verdict-blind hold; the comparison is committed at t = 0 |
| `declaring` | `benchDismissed(hingeFired:)` | `runningPre` / `runningPost` | draft preserved verbatim (§6.7) |
| `adjudicating` | `declarationResolved(.captured)` | `runningPost` | accept ring, inscribe haptic, seam marker; **no strike, no score change, no page** |
| `adjudicating` | `declarationResolved(.correct)` | `hinge` | **win**; adjudication commits before any animation |
| `adjudicating` | `declarationResolved(.deadLaw)` | `struck` | the §7.6 counterexample |
| `adjudicating` | `declarationResolved(.wrong)` | `struck` | the ordinary counterexample (§4.5) |
| `struck` | `counterexampleBeatCompleted(1, hingeFired:)` | `runningPre` / `runningPost` | Bench auto-collapses, draft preserved, **no forced probe** |
| `struck` | `counterexampleBeatCompleted(2, _)` | `hinge` | **loss**; both laws revealed, un-fired `L₂` at 40 % if the hinge never fired |
| `hinge` | `revealCompleted` | `settled(_)` | Codex page on a win only |
| `settled(_)` | `left` | `exit` | — |

**The `priming` row that needs a word.** `priming` ends at "the first Dial commit" (§7.4), and a Dial
commit is a probe submission. Because the probe beat is not a phase, the machine's honest shape is that
`probeSubmitted` from `priming` goes to `adjudicating` **only** as the bookkeeping edge that lets the
following `verdictBeatCompleted` decide `runningPre`. If that reads as a wart during implementation, the
alternative — `priming --probeSubmitted--> runningPre` directly, with the hinge decision folded into
`recordProbe` — is equally faithful to §7.4 and strictly simpler. **Pick one, make the tests match, and
record which in `DECISIONS.md`.** What is not acceptable is two spellings that disagree about whether
probe 1 can fire the hinge; it can (at `N_admits = 3` with three admits it cannot, but trigger (c) at
band 3 fires at probe 13, and a satiation at probe 3 is reachable) so the edge must be live either way.

### `probeEquivalent`, the anti-drift device

```swift
extension DriftPhase {
    /// The PROBE phase this one stands in for. Total by construction, so the day someone adds a
    /// tenth DRIFT phase they are forced to say what it is in PROBE's vocabulary — or to argue that
    /// DRIFT has grown a state PROBE does not have, which is a design change, not a refactor.
    public var probeEquivalent: RoundPhase? { … }
}
```

`priming`, `runningPre` and `runningPost` all map to `.probing`; `adjudicating` maps to `.sealing`;
`struck` to `.counterexample`; `hinge` to `.revealing(_)`. Ship it non-optional if every case really
does map, and let the test assert totality either way.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftPhaseTests` green, including the parameterised totality test over `DriftPhase.allCases × DriftEvent.exhaustiveSamples`.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/DriftPhase.swift` returns nothing.
- [ ] Adding a throwaway `DriftEvent` case produces **nine** compile errors; adding a throwaway `DriftPhase` case produces at least one in `transition(on:)` and one in `probeEquivalent`. Demonstrate both, then revert.
- [ ] `grep -n "Duration\|sleep\|Animation" HunchCore/Sources/Rounds/DriftPhase.swift` returns nothing.
- [ ] Both loss paths — `strikes == 2` and `capReached` — reach `.hinge`, asserted with `hingeFired` both true and false.
- [ ] `DECISIONS.md` records the `adjudicating` reading, the absent probe-beat phase, and which `priming` edge was chosen.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T03: DriftPhase, the nine-phase transition table and the dead-law strike path"`

## Out of scope

- `cap_DRIFT`'s value — **T04**. This task consumes `capReached` as a fact the caller supplies.
- Every duration in the table's side-effect column — **E08·T06**, **E09·T09/T10**, **T08**. This file holds none.
- The dead-law counterexample's *selection* — **T06**. This task only routes `.deadLaw` to `struck`.
- The reveal that `hinge` plays — **T08**.
- Wiring the machine into `@MainActor @Observable Round` — **T05**, which parameterises E08·T01's class by mode.
- `Outcome` and PROBE's eight-phase machine — **E07·T07**; neither is modified here.
