# The ten-second budget, what is gated, and how to kill a flake

1. [The budget, and the timer that enforces it](#1-the-budget-and-the-timer-that-enforces-it)
2. [Where the time actually goes here](#2-where-the-time-actually-goes-here)
3. [What is gated to nightly, and what is never gated](#3-what-is-gated-to-nightly-and-what-is-never-gated)
4. [Diagnosing a slow suite](#4-diagnosing-a-slow-suite)
5. [Flakes](#5-flakes)
6. [Coverage](#6-coverage)

---

## 1. The budget, and the timer that enforces it

**`swift test --package-path HunchCore` must finish under 10 seconds.** The brief states it, and it is the stated rationale for the two-target split: the fast suite boots no simulator and launches no host app, which is the single largest lever on inner-loop latency (`06 T3`, `01 P22`).

A budget nobody measures has already been spent, so CI times it (`08 §5`):

```bash
# The measurement. The build skill owns which job this lives in.
start=$SECONDS
swift test --package-path HunchCore
elapsed=$(( SECONDS - start ))
if [ "$elapsed" -ge 10 ]; then
  echo "fast suite took ${elapsed}s, budget is 10s — tag the offender .nightly or make it faster" >&2
  exit 1
fi
```

Run `swift build --package-path HunchCore` first in CI so the timer measures the suite and not a cold compile. Locally the same distinction applies: the first `swift test` after a checkout is not the number the budget is about.

The published sub-budgets, from the design's own measurements cited in `08 §5`: the 10,000-law generator suite ≈ 1.2 s; Level A at 10⁶ rounds < 0.4 s; the Level-B smoke subset ≈ 0.8 s. That is under 2.5 s of the 10, which is the headroom the rest of the suite spends.

When the timer fails, the fix is one of exactly three: tag the offender `.nightly` and gate it (§3), find the real I/O or the real sleep, or fix shared state that forced a `.serialized`. It is never "raise the budget", and it is never "delete the test" (`06 T58`).

## 2. Where the time actually goes here

`06 §18` lists the general causes in payoff order. Three of them are already structurally solved in HUNCH and one is not:

| Cause | Status |
|---|---|
| Simulator boot and host-app launch for a unit bundle | **solved** — the fast suite is a package, `swift test`, no host |
| Real clocks | **solved** — there is no `Clock` in the project at all (`references/determinism.md` §7) |
| Serial execution | **solved by default** — nothing in this repo may carry `.serialized` |
| Real I/O | **live** — `PersistenceTests` genuinely writes files. Per-test temp dirs via the `TestScoping` trait, and no fixture larger than it needs to be |
| Compilation | **live** — `HunchCore` is eight source targets, so a one-line change rebuilds one of them; keep it that way, and do not collapse targets for tidiness |

The other live cost is unique to this project: **corpus construction**. `Corpora.index` — the 9,767-table `LawIndex` — is built once as a `static let` for the whole suite. If two suites each build their own, the budget goes immediately, and the mistake looks like good hygiene ("each suite owns its fixtures") rather than like a bug.

## 3. What is gated to nightly, and what is never gated

Gate **declaratively**, with a trait, so the gate is visible at the definition rather than in a shell script (`06 §18` play 7):

```swift
@Suite("Difficulty calibration, full matrix",
       .tags(.integration, .nightly),
       .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
       .timeLimit(.minutes(15)))
struct DifficultyCalibrationTests { … }
```

| Gated to `.nightly` | Why |
|---|---|
| Level-B `ReasonerHarness`, full matrix — 640 k rounds, ~9 min | genuinely expensive; a smoke subset stays fast so the harness cannot rot |
| Invariant 3, the ρ ≥ 0.75 calibration statistic | needs Level B |
| The 200,000-configuration Bench fuzzer | only once it measures over ~1 s; below that it stays presubmission |
| The accessibility audit | `XCUIApplication`, therefore a simulator |

| Never gated | Why |
|---|---|
| Invariant 1, generator guardrails | 1.2 s, and it is the assertion that the game is playable at all |
| Invariant 4, determinism | cheap, and it is the property the daily Anomaly depends on |
| Invariant 6, persistence round-trip and v1 migration | the one class of bug that is unrecoverable in production |
| Level A convergence, 80 % target, no loss loop | under 0.4 s and worth more than any manual playtesting |

**The nightly matrix is also a hard gate before any archive.** Nightly means "not on every PR", not "advisory". The release skill owns the archive gate; this skill owns the fact that the gate exists and that a red nightly blocks it.

**`.enabled(if:)` conditions may be evaluated more than once** (`06 §9`), so keep them to an environment-variable read. Anything that touches the filesystem in a condition is paid per test.

## 4. Diagnosing a slow suite

In order, because each step is cheaper than the next:

1. **Get per-test timings.** `swift test --package-path HunchCore 2>&1 | sort` on the duration column, or read the `.xcresult`. Guessing which test is slow is nearly always wrong.
2. **Look for a Cartesian product.** `arguments: A, B` where you meant `zip(A, B)` (`06 T22`) is the most common way a suite silently gains thirty seconds, and the diff that introduced it looks harmless.
3. **Look for a second corpus build.** `grep -rn 'LawIndex' HunchCore/Tests` — anything but a reference to `Corpora.index` is a rebuild.
4. **Look for real I/O outside `PersistenceTests`.** A fixture read in a `@Test` that did not need one; a temp directory created per *case* of a parameterised test rather than per test.
5. **Look for a sleep.** There should be none. `grep -rn 'Task.sleep\|ContinuousClock' HunchCore/Tests Modules/Tests` — the only legitimate `ContinuousClock` in the repo is the one at the SIEVE view edge, and it is not in a test.
6. **Only then** consider tagging it `.nightly`.

## 5. Flakes

`06 §20` maps cause to mechanism to cure. The three that can actually happen in this repo, given that there is no network, no clock and no ambient RNG:

**Shared mutable state.** Tests run parallel in one process, so a `static var` is a data race, not an ordering hazard (`06 T10`). The sanctioned exception is exactly one shape: a `static let` of an immutable `Sendable` value, which is what `Corpora.index` and `Corpora.knownBadSeeds` are. `MaskTable.resident` and `Deck.all` are the same shape in the core and are explicitly *not* the singletons the brief bans, because there is no mutable state and nothing to substitute (`08 §4`).

**Main-actor assumptions.** A `Modules/` suite that constructs `Round` or `Codex` without `@MainActor` compiles under some isolation configurations and races at runtime (`06 T9`). `.defaultIsolation(MainActor.self)` on the source target does not reach the test target.

**Ordering assumptions.** `Dictionary` and `Set` iteration order is not stable across runs. `Ability.offset` is `[Mode: Double]` and `Ability.scoredRounds` is `[Mode: Int]`; asserting on their iteration order will pass locally and fail in CI. Assert on sets, or sort by `Mode.allCases`.

The protocol when one appears:

1. **Reproduce with repetition, not retries** (`06 T62`): `xcodebuild test -only-testing <id> -run-tests-until-failure -test-iterations 100`, or on Swift 6.4 `swift test --maximum-repetitions 100 --repeat-until fail`, which repeats per *case* so only the failing argument repeats.
2. **Do not add `.serialized`.** If it makes the flake go away you have located shared mutable state; go delete the state (`06 T27`). Serial tests are slower and they mask the concurrency bug in the product, which is the bug that ships.
3. **Do not add a CI retry, ever** (`06 T63`). Retrying is precisely the mechanism by which a genuine race ships.
4. **Quarantine visibly** if it cannot be fixed today: `withKnownIssue(isIntermittent: true)` plus `.bug(id:)`. That keeps it in the report and attributable, which commenting it out does not.
5. **Turn on random execution order** in at least one plan configuration permanently (`06 T61`, `07 B25`). If that breaks the suite, you have inter-test dependencies and you want to know today.

## 6. Coverage

Gather it; do not set a global percentage gate (`06 T59`). The specific ways the number lies in this project:

- **The app shell inflates it.** `App/` is five files and `HunchTests/` stays nearly empty by design (`01 P22`, `P40`); any host-app-inflated number is measuring the wizard's template.
- **Generated code dominates.** `@Observable` on `Round`, `Codex` and `Ladder`, `Codable` synthesis on every core value type, and `#Preview` are all counted and none of them are yours.
- **`withKnownIssue` blocks still count.** You can hold coverage flat while the feature is broken.

Use it diff-wise and per-module (`06 T60`). "Which lines in this PR are uncovered?" is actionable. A per-module gate is defensible on `Laws`, `LawGeneration` and `Ladder` — pure logic with no I/O, where an uncovered branch is a real gap. It is not defensible on `HunchUI` or any `*Feature` target, and it is meaningless on the app shell.

Turn coverage **off** for the fast local plan and for anything measuring time. Instrumentation is not free, and the ten-second budget is measured without it.
