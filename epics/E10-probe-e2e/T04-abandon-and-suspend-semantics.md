# T04 — Abandon and suspend semantics

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Abandon semantics (PROBE) · Leaving a round (SCREENS / NAVIGATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The whole task is a type-design problem: "quitting buys a re-roll and never an easier law" has to be a value the estimator *cannot* misread, and "SIEVE has no chevron" has to be unrepresentable rather than remembered. This skill owns the `W28`-shaped question (one type or two parallel fields) and the `StoreFile` exhaustive-switch ruling. |

`hunch-chrome-and-meta` is **not** loaded: the chevron, the run frame and the mode-key arc are drawings
and belong to E17·T03/T04/T09. This task produces the values those drawings act on.

## Objective

At the end of this task leaving a round is a total function over `(mode, probesUsed, intent)` returning
one of four actions, each with an explicit effects record, so that no caller can invent a fifth reading.
Zero probes discards outright with no record and the seed back in the pool; one or more probes yields
`abandoned` at score 0 with **no θ update** and a sticky target; the leading chevron suspends silently
into one of three `round-{mode}.json` slots, and SIEVE is not one of them.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.10 (Abandonment) | before probe 1 → discarded outright, no record, no θ update, the seed returns to the pool; after probe 1 → `Outcome.abandoned`, score 0, no θ update, and the target δ is **sticky** across the abandon |
| `GAME_DESIGN.md` | §6.9 | only `inscribed` scores; `broken`, `exhausted`, `abandoned` and `voided` all score exactly 0 |
| `GAME_DESIGN.md` | §12.7 (Leaving a round) | the leading chevron suspends in PROBE / DRIFT / ECHO with **no confirmation**, because nothing is lost; SIEVE's exit is §9.2's and needs a confirming second tap |
| `GAME_DESIGN.md` | §12.4 (Suspended round) | the mode key draws an arc filled to `probesUsed / par` and one tap resumes — which is why the slot is per mode |
| `GAME_DESIGN.md` | §14.5 open decision 3 | **default: four slots, `round-{mode}.json`, SIEVE excluded** (it voids rather than suspends), so three files in practice |
| `GAME_DESIGN.md` | §11.13 | `round.json`'s row and the reset map; the file is written first and is the smallest |
| `GAME_DESIGN.md` | §10.7 | the sticky target as an anti-frustration measure, whose *consumption* is the serving policy's |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | one type instead of two parallel fields; exhaustive `switch` with no `default:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/LeaveRoundTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration            // Band, Mode
import Persistence              // StoreFile

@Suite("Leaving a round — §6.10, §12.7, open decision 3", .tags(.unit, .presubmission))
struct LeaveRoundTests {

    // MARK: abandon, from the run frame

    @Test("zero probes discards outright: no record, no outcome, the seed returns to the pool")
    func zeroProbesDiscards() {
        #expect(LeaveRound.action(mode: .probe, probesUsed: 0, intent: .abandonFromRunFrame) == .discard)
        #expect(LeaveRound.effects(of: .discard) ==
                RoundEffects(writesRecord: false, outcome: nil, score: 0,
                             updatesAbility: false, stickyTarget: false, returnsSeedToPool: true))
    }

    @Test("one probe or more abandons: recorded, score 0, no ability update, target sticky")
    func oneProbeAbandons() {
        #expect(LeaveRound.action(mode: .probe, probesUsed: 1, intent: .abandonFromRunFrame) == .abandon)
        #expect(LeaveRound.effects(of: .abandon) ==
                RoundEffects(writesRecord: true, outcome: .abandoned, score: 0,
                             updatesAbility: false, stickyTarget: true, returnsSeedToPool: false))
    }

    @Test("the boundary is at exactly one probe, not at 'some probes'", arguments: [0, 1, 2, 11])
    func boundaryIsExactlyOne(_ probes: Int) {
        let expected: LeaveAction = probes == 0 ? .discard : .abandon
        #expect(LeaveRound.action(mode: .probe, probesUsed: probes, intent: .abandonFromRunFrame) == expected)
    }

    @Test("an abandon never scores and never touches ability — the anti-farm is the sticky target")
    func abandonCannotFarmTheEngine() {
        let effects = LeaveRound.effects(of: .abandon)
        #expect(effects.score == 0)
        #expect(effects.updatesAbility == false)
        #expect(effects.stickyTarget == true)
    }

    @Test("every non-inscribed outcome scores exactly zero (§6.9)",
          arguments: [Outcome.broken, .exhausted, .abandoned, .voided])
    func lossesScoreZero(_ outcome: Outcome) {
        #expect(Score.forOutcome(outcome, par: 7, probesUsed: 5, strikes: 0) == 0)
    }

    // MARK: suspend, from the chevron

    @Test("the leading chevron suspends silently, at any probe count",
          arguments: [Mode.probe, .drift, .echo])
    func chevronSuspends(_ mode: Mode) {
        #expect(LeaveRound.action(mode: mode, probesUsed: 0, intent: .chevron) == .suspend)
        #expect(LeaveRound.action(mode: mode, probesUsed: 9, intent: .chevron) == .suspend)
        #expect(LeaveRound.effects(of: .suspend) ==
                RoundEffects(writesRecord: false, outcome: nil, score: 0,
                             updatesAbility: false, stickyTarget: false, returnsSeedToPool: false))
    }

    @Test("SIEVE has no chevron and no run-frame abandon — its exit is §9.2's, not this policy's",
          arguments: [LeaveIntent.chevron, .abandonFromRunFrame])
    func sieveIsNotThisPolicysBusiness(_ intent: LeaveIntent) {
        #expect(LeaveRound.action(mode: .sieve, probesUsed: 3, intent: intent) == nil)
    }

    // MARK: the slots

    @Test("exactly three modes suspend, and SIEVE is not one of them (open decision 3)")
    func threeSlots() {
        #expect(Mode.allCases.filter(\.suspends) == [.probe, .drift, .echo])
        #expect(Mode.sieve.suspends == false)
    }

    @Test("each suspendable mode owns its own file, so starting DRIFT never destroys a PROBE round")
    func perModeFiles() {
        let names = Mode.allCases.filter(\.suspends).map { StoreFile.round($0).filename }
        #expect(names == ["round-probe.json", "round-drift.json", "round-echo.json"])
        #expect(Set(names).count == names.count)
    }

    @Test("the suspended-key arc reads probesUsed / par and nothing else (§12.4)")
    func suspendedArcFraction() {
        #expect(SuspendedRound(probesUsed: 5, par: 7).arcFraction == 5.0 / 7.0)
        #expect(SuspendedRound(probesUsed: 9, par: 7).arcFraction == 1.0)   // never over-fills
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter LeaveRoundTests`

Expect missing `LeaveRound`, `LeaveAction`, `LeaveIntent`, `RoundEffects`, `Mode.suspends`,
`SuspendedRound`. If `StoreFile.round(_:).filename` does not exist under that name, use E07·T01's actual
accessor and keep the assertion.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/LeaveRound.swift` — `LeaveRound`, `LeaveIntent`, `LeaveAction`, `RoundEffects` |
| create | `HunchCore/Sources/Rounds/SuspendedRound.swift` |
| modify | `HunchCore/Sources/Glyphs/Mode.swift` (or wherever E02·T06 put `Mode`) — add `suspends` |
| modify | `HunchCore/Sources/Persistence/StoreFile.swift` — assert the `round-{mode}.json` spelling; add the guard that `round(.sieve)` is never *written* |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `func leave(_ intent: LeaveIntent)` applying the effects |
| create | `HunchCore/Tests/RoundsTests/LeaveRoundTests.swift` |
| modify | `tests.json` — four entries (discard, abandon effects, chevron suspends, three slots) |
| modify | `DECISIONS.md` — open decision 3 recorded as taken at its default |

## Implementation notes

### The shape

```swift
public enum LeaveIntent: Equatable, Sendable {
    case chevron                 // §12.7 — the leading chevron in the instrument bar
    case abandonFromRunFrame     // §6.10 — the run frame, opened by tapping the mode sigil
}

public enum LeaveAction: Equatable, Sendable {
    case discard      // 0 probes: nothing happened, so nothing is written
    case abandon      // ≥ 1 probe: an interruption signal, not a failure signal
    case suspend      // the round waits in its slot
}

public struct RoundEffects: Equatable, Sendable {
    public let writesRecord: Bool
    public let outcome: Outcome?
    public let score: Int
    public let updatesAbility: Bool
    public let stickyTarget: Bool
    public let returnsSeedToPool: Bool
}

public enum LeaveRound {
    /// `nil` means *this affordance does not exist in this mode* — SIEVE, whose exit is §9.2's.
    public static func action(mode: Mode, probesUsed: Int, intent: LeaveIntent) -> LeaveAction?
    public static func effects(of action: LeaveAction) -> RoundEffects
}
```

Three design points, each of which is the reason the type exists rather than a pair of `if`s at the call
site:

1. **`updatesAbility: false` is data, not documentation.** §6.10's anti-farm argument only holds if the
   estimator can never be handed an abandon. E11·T02's `AbilityEstimator` takes `(Ability, Mode,
   servedDelta, Bool)` and has no opinion about outcomes; the filter has to be here, and it has to be a
   field somebody can assert on.
2. **`stickyTarget: true` is the *other* half of the same argument** — quitting buys a re-roll of the
   seed and never an easier law. E11·T06's serving layer reads it; this task only sets it.
3. **`nil` for SIEVE is deliberate and is asserted.** Returning `.abandon` for SIEVE would be wrong twice:
   SIEVE's abandon is scored as a foul-out at the last resolved glyph and its *termination* voids
   (§9.8) — two different things, neither of them this function's.

### `Mode.suspends`, and the three files

```swift
extension Mode {
    /// §14.5 open decision 3, taken at its default: four slots by design, SIEVE excluded because it
    /// voids rather than suspends (§9.8), so three files in practice.
    public var suspends: Bool { self != .sieve }
}
```

`StoreFile.round(Mode)` keeps E07's shape — the case is still parameterised on `Mode`, because
`round(.sieve)` must remain *nameable* so that a stale file can be deleted and so the reset map's
exhaustive switch keeps covering it. What changes is that **nothing writes it**: `Round.leave(.chevron)`
is unreachable for SIEVE (the function returns `nil`), and `FilePersistenceStore` gains one
`precondition` on the write path with the §9.8 citation in its message.

Record open decision 3 in `DECISIONS.md` with the two costs the spec names: four slots cost ~8 KB and one
extra resume path; one slot costs the Frame's arc semantics and silently destroys a suspended PROBE round.

### The chevron is silent

No alert, no confirmation, no "are you sure" — §12.7 is explicit, and the reason is that nothing is lost.
The confirm-by-repeat pattern exists in exactly two places in the app (SIEVE's paused chevron and the
optional Seal confirm), and adding a third here would break a stated global claim. The chevron's drawing
and its 44 × 44 hit rect are E17·T09's; this task must not add a `ResetConfirmAlert`-shaped anything.

### Zero probes really means nothing at all

`.discard` writes **no** `RoundRecord`, mints no page, updates no θ, and emits no Profile sample. The seed
returns to the pool — concretely, the serving layer's `avoid` set never learns about it, which is a
non-action here and an assertion in E11·T06. The one thing that *does* happen is that the snapshot slot is
deleted, because a discarded round must not resume on the next launch.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter LeaveRoundTests` green, all ten tests.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/LeaveRound.swift` returns nothing.
- [ ] `grep -rn "\.abandoned" HunchCore/Sources Modules/Sources | grep -i "ability\|estimator\|theta"` returns nothing — no path feeds an abandon to the estimator.
- [ ] `grep -rn "round(\.sieve)" Modules/Sources HunchCore/Sources` shows no *write* call site.
- [ ] `DECISIONS.md` records open decision 3 at its default, with both costs named.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T04: leave-round actions, abandon effects and the three suspendable slots"`

## Out of scope

- The chevron drawing, the run frame and the mode key's suspended arc — **E17·T03/T04/T09**.
- Consuming `stickyTarget` and honouring `updatesAbility == false` — **E11·T01/T03/T06**.
- SIEVE's void / sticky / abandon policy and its two-tap confirm — **E14·T08**.
- DRIFT's "a second DRIFT round discards the older one" modal — **E12·T09**.
- `RoundRecord`'s fields and the 200-entry ring it lands in — **E07·T09**, **E16·T11**.
- Deleting a suspended round by swiping its mode key — **E17·T04**.
