# T07 — `RoundPhase` and `Outcome`

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | §14.1 PROBE → **Round state machine** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns `08 §2`'s ruling that `RoundPhase` *looks* app-layer and is core — "the *durations* are `HunchUI`; the *transitions* are a pure function and belong in core, tested exhaustively" — and owns `W29`, which is what makes the transition table a compile-time obligation rather than a review note |
| `hunch-swift-testing` | Owns `06 T21`'s no-loops rule and the sanctioned way round it: collect offenders into an array and assert it is empty, so one failure names every offending pair rather than the first one |

## Objective

`HunchCore/Sources/Rounds/` exists and holds §6.1's eight phases and five outcomes verbatim, plus the
event vocabulary and a total, pure `(RoundPhase, RoundEvent) -> RoundPhase.Transition` function
written as nested exhaustive switches with no `default:` anywhere. Every one of the 17 × 18
representative pairs has a defined answer, `settled(.voided)` is reachable only from `arming` and
only on a resume, and no duration appears anywhere in the file.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.1 | The two enums **verbatim**, the full transition table row by row, the `settled(.voided)` clause, and the two invariants (the model never waits on an animation; no wall-clock quantity affects score, marks or the Rasch update) |
| `GAME_DESIGN.md` | §6.5 | That the verdict is computed and committed at t = 0 of the beat and merely displayed later — which is why the phase machine takes a `Verdict` *into* `adjudicating` rather than out of it |
| `GAME_DESIGN.md` | §6.8 | The seal hold is verdict-blind; the three resolution paths; **two declarations per round, hard** |
| `GAME_DESIGN.md` | §6.10, §6.11 cases 23, 27, 28, 29 | Abandon before/after probe 1; the voided round; returning to the run frame costs nothing; a snapshot already at cap is corruption |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 (second table), §7.8 | Why this is core, and why `Round` in `LoomFeature` stays thin over it |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20 | Extract the logic into a plain type and test that, not the view |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | Make the illegal state unrepresentable rather than guarded; no `default:` |

> **A discrepancy to know about before you start.** `08 §2` and `08 §7.8` describe the round as a
> "nine-phase machine". §6.1's `enum RoundPhase` declares **eight** cases and §14.1's row says
> "`RoundPhase` 8 states, `Outcome` 5 cases". §6.1 is the declaration and wins; the guide's prose is
> counting loosely (DRIFT's `DriftPhase` in §7.4 is the nine-phase one). Ship eight, and note it in
> `DECISIONS.md` so the next reader does not "fix" it.

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/RoundsTests/RoundPhaseTransitionTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Rounds

@Suite("The round transition table", .tags(.unit, .presubmission))
struct RoundPhaseTransitionTests {

    // MARK: exhaustive enumeration, tied to the enums by the compiler

    /// One kind per `RoundPhase` case. `kind(of:)` below is an exhaustive switch, so adding a phase
    /// breaks compilation here and forces the new phase into every assertion in this file.
    private enum PhaseKind: CaseIterable {
        case arming, probing, adjudicating, declaring, sealing, counterexample, revealing, settled
    }

    private static func kind(of phase: RoundPhase) -> PhaseKind {
        switch phase {
        case .arming:         .arming
        case .probing:        .probing
        case .adjudicating:   .adjudicating
        case .declaring:      .declaring
        case .sealing:        .sealing
        case .counterexample: .counterexample
        case .revealing:      .revealing
        case .settled:        .settled
        }
    }

    private static let outcomes: [Outcome] =
        [.inscribed(marks: 3, fracture: false), .broken, .exhausted, .abandoned, .voided]

    private static func samples(of kind: PhaseKind) -> [RoundPhase] {
        switch kind {
        case .arming:         [.arming]
        case .probing:        [.probing]
        case .adjudicating:   [.adjudicating(.admit), .adjudicating(.reject)]
        case .declaring:      [.declaring]
        case .sealing:        [.sealing]
        case .counterexample: [.counterexample]
        case .revealing:      outcomes.map(RoundPhase.revealing)
        case .settled:        outcomes.map(RoundPhase.settled)
        }
    }

    private static let allPhases = PhaseKind.allCases.flatMap(samples)

    private enum EventKind: CaseIterable {
        case firstFrameCommitted, snapshotRestored, probeSubmitted, verdictBeatCompleted,
             benchOpened, benchDismissed, sealPressed, declarationResolved,
             counterexampleBeatCompleted, revealCompleted, abandoned, left
    }

    private static func kind(of event: RoundEvent) -> EventKind {
        switch event {
        case .firstFrameCommitted:          .firstFrameCommitted
        case .snapshotRestored:             .snapshotRestored
        case .probeSubmitted:               .probeSubmitted
        case .verdictBeatCompleted:         .verdictBeatCompleted
        case .benchOpened:                  .benchOpened
        case .benchDismissed:               .benchDismissed
        case .sealPressed:                  .sealPressed
        case .declarationResolved:          .declarationResolved
        case .counterexampleBeatCompleted:  .counterexampleBeatCompleted
        case .revealCompleted:              .revealCompleted
        case .abandoned:                    .abandoned
        case .left:                         .left
        }
    }

    private static func samples(of kind: EventKind) -> [RoundEvent] {
        switch kind {
        case .firstFrameCommitted:         [.firstFrameCommitted]
        case .snapshotRestored:            [.snapshotRestored(integrityHolds: true),
                                            .snapshotRestored(integrityHolds: false)]
        case .probeSubmitted:              [.probeSubmitted(.admit), .probeSubmitted(.reject)]
        case .verdictBeatCompleted:        [.verdictBeatCompleted(capReached: false),
                                            .verdictBeatCompleted(capReached: true)]
        case .benchOpened:                 [.benchOpened]
        case .benchDismissed:              [.benchDismissed]
        case .sealPressed:                 [.sealPressed]
        case .declarationResolved:         [.declarationResolved(.correct(marks: 2, fracture: true)),
                                            .declarationResolved(.firstWrong),
                                            .declarationResolved(.secondWrong)]
        case .counterexampleBeatCompleted: [.counterexampleBeatCompleted]
        case .revealCompleted:             [.revealCompleted]
        case .abandoned:                   [.abandoned(probesUsed: 0), .abandoned(probesUsed: 4)]
        case .left:                        [.left]
        }
    }

    private static let allEvents = EventKind.allCases.flatMap(samples)

    @Test("The enumeration covers every case of both enums")
    func enumerationIsComplete() {
        #expect(Set(Self.allPhases.map(Self.kind(of:))).count == PhaseKind.allCases.count)
        #expect(Set(Self.allEvents.map(Self.kind(of:))).count == EventKind.allCases.count)
        #expect(Self.allPhases.count == 17)
        #expect(Self.allEvents.count == 18)
    }

    // MARK: one test per phase — §6.1's table, row by row

    @Test("arming: a fresh round and an intact resume both open into probing; a failed hash voids")
    func armingRow() {
        #expect(RoundPhase.arming.transition(on: .firstFrameCommitted) == .to(.probing))
        #expect(RoundPhase.arming.transition(on: .snapshotRestored(integrityHolds: true))
                == .to(.probing))
        #expect(RoundPhase.arming.transition(on: .snapshotRestored(integrityHolds: false))
                == .to(.settled(.voided)))
        expectIgnoredForEveryOtherEvent(
            from: .arming,
            except: [.firstFrameCommitted,
                     .snapshotRestored(integrityHolds: true),
                     .snapshotRestored(integrityHolds: false)])
    }

    @Test("probing: a probe adjudicates its own verdict, the Bench declares, 0 probes discards")
    func probingRow() {
        #expect(RoundPhase.probing.transition(on: .probeSubmitted(.admit))
                == .to(.adjudicating(.admit)))
        #expect(RoundPhase.probing.transition(on: .probeSubmitted(.reject))
                == .to(.adjudicating(.reject)))
        #expect(RoundPhase.probing.transition(on: .benchOpened) == .to(.declaring))
        #expect(RoundPhase.probing.transition(on: .abandoned(probesUsed: 0)) == .exit)
        #expect(RoundPhase.probing.transition(on: .abandoned(probesUsed: 1))
                == .to(.settled(.abandoned)))
        expectIgnoredForEveryOtherEvent(
            from: .probing,
            except: [.probeSubmitted(.admit), .probeSubmitted(.reject), .benchOpened,
                     .abandoned(probesUsed: 0), .abandoned(probesUsed: 4)])
    }

    @Test("adjudicating: input is locked; the beat returns to probing, or reveals at the cap",
          arguments: [Verdict.admit, .reject])
    func adjudicatingRow(_ verdict: Verdict) {
        let phase = RoundPhase.adjudicating(verdict)
        #expect(phase.transition(on: .verdictBeatCompleted(capReached: false)) == .to(.probing))
        #expect(phase.transition(on: .verdictBeatCompleted(capReached: true))
                == .to(.revealing(.exhausted)))
        // §6.11 case 4: the cap-th verdict is still delivered in full — so the cap does not
        // interrupt the beat, it changes where the beat lands.
        expectIgnoredForEveryOtherEvent(
            from: phase,
            except: [.verdictBeatCompleted(capReached: false),
                     .verdictBeatCompleted(capReached: true)])
    }

    @Test("declaring: the Dial key preserves the draft, the Seal seals, an abandon still abandons")
    func declaringRow() {
        #expect(RoundPhase.declaring.transition(on: .benchDismissed) == .to(.probing))
        #expect(RoundPhase.declaring.transition(on: .sealPressed) == .to(.sealing))
        #expect(RoundPhase.declaring.transition(on: .abandoned(probesUsed: 3))
                == .to(.settled(.abandoned)))
        #expect(RoundPhase.declaring.transition(on: .abandoned(probesUsed: 0)) == .exit)
        expectIgnoredForEveryOtherEvent(
            from: .declaring,
            except: [.benchDismissed, .sealPressed,
                     .abandoned(probesUsed: 0), .abandoned(probesUsed: 4)])
    }

    @Test("sealing: correct reveals, the first wrong shows a counterexample, the second ends it")
    func sealingRow() {
        #expect(RoundPhase.sealing.transition(on: .declarationResolved(.correct(marks: 2,
                                                                               fracture: true)))
                == .to(.revealing(.inscribed(marks: 2, fracture: true))))
        #expect(RoundPhase.sealing.transition(on: .declarationResolved(.firstWrong))
                == .to(.counterexample))
        #expect(RoundPhase.sealing.transition(on: .declarationResolved(.secondWrong))
                == .to(.revealing(.broken)))
        expectIgnoredForEveryOtherEvent(
            from: .sealing,
            except: [.declarationResolved(.correct(marks: 2, fracture: true)),
                     .declarationResolved(.firstWrong),
                     .declarationResolved(.secondWrong)])
    }

    @Test("counterexample: the beat completes back into probing and nothing else moves it")
    func counterexampleRow() {
        #expect(RoundPhase.counterexample.transition(on: .counterexampleBeatCompleted)
                == .to(.probing))
        expectIgnoredForEveryOtherEvent(from: .counterexample,
                                        except: [.counterexampleBeatCompleted])
    }

    @Test("revealing carries its outcome into settled unchanged", arguments: Self.outcomes)
    func revealingCarriesTheOutcome(_ outcome: Outcome) {
        #expect(RoundPhase.revealing(outcome).transition(on: .revealCompleted)
                == .to(.settled(outcome)))
        expectIgnoredForEveryOtherEvent(from: .revealing(outcome), except: [.revealCompleted])
    }

    @Test("settled: leaving exits; a new round is a new machine, not a self-loop",
          arguments: Self.outcomes)
    func settledRow(_ outcome: Outcome) {
        #expect(RoundPhase.settled(outcome).transition(on: .left) == .exit)
        expectIgnoredForEveryOtherEvent(from: .settled(outcome), except: [.left])
    }

    // MARK: the four invariants, over the whole 17 × 18 product

    @Test("The function is total: every pair has an answer and none of them traps")
    func theTableIsTotal() {
        let answers = Self.allPhases.flatMap { phase in
            Self.allEvents.map { phase.transition(on: $0) }
        }
        #expect(answers.count == Self.allPhases.count * Self.allEvents.count)
    }

    @Test("The function is pure: the same pair gives the same answer every time")
    func theTableIsPure() {
        let offenders = Self.allPhases.flatMap { phase in
            Self.allEvents.compactMap { event -> String? in
                phase.transition(on: event) == phase.transition(on: event)
                    ? nil : "\(phase) --\(event)-->"
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// §6.1: "`settled(.voided)` is reachable **only** from `arming`, and only on a resume."
    @Test("settled(.voided) is reachable only from arming, and only from a failed integrity hash")
    func voidedIsReachableOnlyFromArming() {
        let offenders = Self.allPhases.flatMap { phase in
            Self.allEvents.compactMap { event -> String? in
                guard phase.transition(on: event) == .to(.settled(.voided)) else { return nil }
                let legal = Self.kind(of: phase) == .arming
                    && event == .snapshotRestored(integrityHolds: false)
                return legal ? nil : "\(phase) --\(event)--> settled(.voided)"
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("Nothing transitions back into arming — it is an entry phase and only an entry phase")
    func armingIsEntryOnly() {
        let offenders = Self.allPhases.flatMap { phase in
            Self.allEvents.compactMap { event -> String? in
                phase.transition(on: event) == .to(.arming) ? "\(phase) --\(event)-->" : nil
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("A round can only be discarded outright before probe 1")
    func exitAtZeroProbesOnly() {
        let offenders = Self.allPhases.flatMap { phase in
            Self.allEvents.compactMap { event -> String? in
                guard phase.transition(on: event) == .exit else { return nil }
                let legal = event == .left
                    || (event == .abandoned(probesUsed: 0)
                        && [.probing, .declaring].contains(Self.kind(of: phase)))
                return legal ? nil : "\(phase) --\(event)--> exit"
            }
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    // MARK: helper

    private func expectIgnoredForEveryOtherEvent(
        from phase: RoundPhase,
        except legal: [RoundEvent],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let offenders = Self.allEvents
            .filter { !legal.contains($0) }
            .compactMap { event -> String? in
                phase.transition(on: event) == .ignored ? nil : "\(event) moved \(phase)"
            }
        #expect(offenders.isEmpty, "\(offenders)", sourceLocation: sourceLocation)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter RoundPhaseTransitionTests`
Confirm the failures are `cannot find 'RoundPhase' in scope`. `enumerationIsComplete`'s two count
assertions (17 and 18) are the ones that will fail if you add a case and forget the sample list —
that is their entire purpose, so do not soften them into `>= `.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** The only refactor to consider is collapsing the eight per-phase
helper functions into one big `switch (phase, event)`. **Do not** — see the implementation note.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/RoundPhase.swift` — `RoundPhase`, its nested `Transition`, and the transition function |
| create | `HunchCore/Sources/Rounds/Outcome.swift` |
| create | `HunchCore/Sources/Rounds/RoundEvent.swift` — `RoundEvent` and `DeclarationResult` |
| create | `HunchCore/Tests/RoundsTests/RoundPhaseTransitionTests.swift` |
| modify | `HunchCore/Package.swift` — the `Rounds` target (dependencies `["Glyphs", "Laws", "LawGeneration", "Bench"]`) and `RoundsTests` |
| modify | `DECISIONS.md` — eight phases, not nine |

## Implementation notes

### The two enums, verbatim

Copy §6.1's declarations exactly, cases and comments alike, then add two conformances and nothing
else:

```swift
public enum RoundPhase: Sendable, Equatable {
    case arming
    case probing
    case adjudicating(Verdict)
    case declaring
    case sealing
    case counterexample
    case revealing(Outcome)
    case settled(Outcome)
}

public enum Outcome: Sendable, Equatable, Codable, Hashable {
    case inscribed(marks: Int, fracture: Bool)
    case broken
    case exhausted
    case abandoned
    case voided
}
```

`Outcome` gains `Codable` and `Hashable` beyond §6.1's declaration: it is persisted, in
`RoundRecord` (§6.10, T09), and `Hashable` makes it usable as a test argument and a dictionary key.
`RoundPhase` gains nothing — it is never persisted, because §6.10 resumes into `probing` regardless
of the phase the app died in (§6.11 case 28: restoring *into* `declaring` "would put a player back on
a commit surface they did not just choose to be on").

`marks: Int` rather than a `Marks` type: E06·T07 owns the 1…3 range and the thresholds, and a second
type for the same quantity is `W28` in a different costume.

### `RoundEvent` and the unrepresentable third declaration

```swift
/// What can happen to a round. Every case is something the player or a completed beat did; none of
/// them is a duration, and none of them is a `Bool` about the model's own state — that belongs to
/// `Round` in `LoomFeature` (E08·T01).
public enum RoundEvent: Sendable, Equatable {
    /// A fresh round's first frame is on screen (§6.1: "one frame; never visible as a wait").
    case firstFrameCommitted
    /// A cold launch rehydrated `round-{mode}.json`. `integrityHolds` is `lawHash` against the
    /// stored law's own extension (§6.10) — never a re-generation.
    case snapshotRestored(integrityHolds: Bool)
    /// PROBE key, twin key, or throat-swipe-then-PROBE. The verdict is already computed and
    /// committed at t = 0 of the beat (§6.5), which is why it arrives with the event.
    case probeSubmitted(Verdict)
    /// The 420 ms beat finished. `capReached` is "that probe filled the cap" (§6.11 case 4).
    case verdictBeatCompleted(capReached: Bool)
    case benchOpened
    case benchDismissed
    /// The Seal was pressed **unbarred**. A barred Seal emits no event at all — it pulses the
    /// offending rail and does nothing else (§4.3, §6.11 case 12), which is E09·T07's concern.
    case sealPressed
    case declarationResolved(DeclarationResult)
    case counterexampleBeatCompleted
    /// The reveal beat finished, or the player skipped it from its one skip threshold.
    case revealCompleted
    /// Abandon from the run frame. `probesUsed` decides between a record and a discard (§6.10).
    case abandoned(probesUsed: Int)
    /// NEXT, or the run frame, from the round card.
    case left
}

/// The result of the one comparison a round can make twice.
///
/// There is no `case thirdWrong`, and no `strikes: Int`: §6.8 locks **two declarations per round,
/// hard**, so a third is not a value to validate — it is a state the type refuses to hold (`W28`).
public enum DeclarationResult: Sendable, Equatable, Hashable {
    case correct(marks: Int, fracture: Bool)
    case firstWrong
    case secondWrong
}
```

### `Transition`, and why `.exit` and `.ignored` exist

```swift
extension RoundPhase {
    /// What an event does to a phase. Three answers, because §6.1's table has three shapes of row.
    public enum Transition: Sendable, Equatable {
        /// The machine moves.
        case to(RoundPhase)
        /// The round ceases to exist: discarded before probe 1, or left from the round card.
        /// §6.1 writes this as *(exit)*; it is not a phase, and modelling it as one would invent a
        /// ninth state the design does not have.
        case exit
        /// The event is not legal here and the machine does not move. Every input-locked phase
        /// (`adjudicating`, `sealing`, `counterexample`, `revealing`) is mostly this, and saying so
        /// as a value is what makes "input locked" testable instead of a comment.
        case ignored
    }

    public func transition(on event: RoundEvent) -> Transition {
        switch self {
        case .arming:                     Self.fromArming(event)
        case .probing:                    Self.fromProbing(event)
        case .adjudicating:               Self.fromAdjudicating(event)
        case .declaring:                  Self.fromDeclaring(event)
        case .sealing:                    Self.fromSealing(event)
        case .counterexample:             Self.fromCounterexample(event)
        case .revealing(let outcome):     Self.fromRevealing(event, outcome: outcome)
        case .settled:                    Self.fromSettled(event)
        }
    }
}
```

**Eight private helpers, each an exhaustive `switch event`.** This is the shape, and it is not
stylistic:

- A single `switch (phase, event)` over two enums with associated values cannot be proved exhaustive
  by the compiler; you would end up writing `case (_, _):`, which is `default:` wearing a disguise
  and silences the compiler on exactly the day you add a case (`W29`).
- Nested switches give the real property in **both** directions: add a `RoundPhase` case and the
  outer switch fails; add a `RoundEvent` case and **all eight** helpers fail. That second half is the
  one that matters, because an event is what gets added when a mode grows.
- Collapse the ignored events by listing them (`case .a, .b, .c: .ignored`), which is `W29`'s own
  prescribed spelling.

Example helper, fully written:

```swift
private static func fromProbing(_ event: RoundEvent) -> Transition {
    switch event {
    case .probeSubmitted(let verdict):
        .to(.adjudicating(verdict))
    case .benchOpened:
        .to(.declaring)
    case .abandoned(let probesUsed):
        // §6.10: before probe 1 the round is discarded outright — no record, no θ update, the seed
        // returns to the pool. After probe 1 it is `abandoned`, score 0, and the target is sticky.
        probesUsed == 0 ? .exit : .to(.settled(.abandoned))
    case .firstFrameCommitted, .snapshotRestored, .verdictBeatCompleted, .benchDismissed,
         .sealPressed, .declarationResolved, .counterexampleBeatCompleted, .revealCompleted, .left:
        .ignored
    }
}
```

### Three things this function must not know

1. **Durations.** Not 420, not 640, not 960, not 1,840. §6.1's table gives them and `08 §2` assigns
   them to `HunchUI`; a `Task.sleep` or a millisecond literal in this file is the exact regression the
   module boundary exists to prevent. The events are named for the beat *completing*, which is how a
   pure machine talks about time without owning a clock.
2. **Strike bookkeeping.** `counterexample --beat--> probing` sets `strikes := 1` per §6.1, and that
   assignment lives in `Round` (E08·T01) — the phase machine says *where* the round goes, the round
   says *what it now knows*. Encoding `strikes` in the phase would make `probing` two different
   phases, which §6.1 explicitly does not do.
3. **Whether the Seal is barred.** `sealPressed` is only emitted unbarred (E09·T07). Adding a
   `barred: Bool` to the event would put `SealBar` — a Bench concept — into the round machine.

### The 900 ms re-entry beat

§6.1's `arming` row for a resumed round says *"the 900 ms re-entry beat; input locked throughout,
**phase is `probing` from its first frame**"*. So the resume transition lands on `.probing`
immediately, exactly like a fresh round; the beat is a `HunchUI` animation over a phase that has
already moved (E10·T03). Do not add an `enteringBeat` phase. This is the single most likely wrong
turn in the task and the test `armingRow` pins it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RoundPhaseTransitionTests` green — 8 row cases
      (two of them parameterised), 4 invariant cases, and `enumerationIsComplete`.
- [ ] `grep -c 'default:' HunchCore/Sources/Rounds/*.swift` returns `0`.
- [ ] `grep -nE '[0-9]{3,}|Task\.sleep|Duration|TimeInterval' HunchCore/Sources/Rounds/RoundPhase.swift`
      returns nothing.
- [ ] Adding a throwaway `case paused` to `RoundEvent` produces **eight** compile errors, one per
      helper. Do it, count them, revert.
- [ ] Adding a throwaway ninth `RoundPhase` case produces an error in `transition(on:)` **and** in
      the test's `kind(of:)`. Do it, revert.
- [ ] `RoundPhase` does not conform to `Codable`; `grep -n 'Codable' HunchCore/Sources/Rounds/RoundPhase.swift`
      is empty.
- [ ] `DECISIONS.md` records eight phases against `08 §2`'s "nine".

## Close the task

1. `swift test` green, and the fast suite still under 10 s. This suite should run in single-digit
   milliseconds; if it does not, something in it is allocating per pair.
2. **Run `/simplify`** — re-run the tests after it. It will almost certainly propose merging the
   eight helpers into one tuple switch. Refuse, and leave the three-bullet reason above as a comment
   above `transition(on:)` so the proposal is answered once and for all.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T07: RoundPhase, Outcome and the exhaustive transition table"`

## Out of scope

- Every duration and every beat sheet — **E08·T06** (the 420 ms verdict beat) and **E09·T10** (the
  reveal sheets). Nothing in `Rounds/` may name a millisecond.
- `Round`, the `@MainActor @Observable` class that drives this machine — **E08·T01**.
- Input locking as a *behaviour* (the single-slot queue, the dropped second tap) — **E08·T06**. This
  task expresses the lock as `.ignored` and nothing more.
- `DriftPhase`'s nine phases and the post-hinge dead-law path — **E12·T03**; `EchoPhase` —
  **E13·T09**; SIEVE's run lifecycle — **E14·T08**.
- The scoring that turns a transcript into `Outcome.inscribed(marks:fracture:)` — **T08**.
- The integrity check behind `snapshotRestored(integrityHolds:)` — **T09** computes it, **E10·T02**
  calls it.
