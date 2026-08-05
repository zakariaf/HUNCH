# E10 — PROBE end to end: shell, resume and onboarding

| | |
|---|---|
| **id** | E10 |
| **title** | PROBE end to end: shell, resume and onboarding |
| **branch** | `epic/E10-probe-e2e` |
| **depends on** | E09 (which itself carries E01–E08) |
| **gate** | A real round is played in the simulator, the app quit, relaunched, and resumed at the exact probe with the draft intact · the opening round runs its 13 beats and `OnboardingLedger` records success · the elastic cap defers the loss while `sawReject == false` and hard-stops at probe 24 · a fresh-context subagent diff review against `SPEC.md` reports no correctness or stated-requirement gaps |
| **tasks** | 10 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH is an **app** rather than a play surface. `@main` names one composition
root; `SeedSource` and `Now` are the only two points at which the program stops being a pure function
of its inputs, and both are one line wide. A round survives being killed: the snapshot is written
after every committed verdict, after every strike, and on `scenePhase → .inactive` with the Bench
draft, and a cold launch opens **directly into the round** through a 900 ms re-entry beat with no
dialog and no "Resume?" button. Leaving is defined — zero probes discards, one or more abandons at
score 0 with a sticky target, the chevron suspends silently into one of three `round-{mode}.json`
slots. And a player who has read nothing is taught the whole mechanic by a fixed opening round whose
thirteen beats reveal one affordance at a time, measured by an eight-field `OnboardingLedger` and
protected by an elastic cap that refuses to end the round before the player has ever seen a reject.

That closes §14.3's phase 3.

## Why now

E08 and E09 built the surface a round is played on; nothing yet launches it, saves it, or explains
it. Phase 3's gate is not "the Bench works", it is *"a real round is playable in the simulator, quit,
relaunched and resumed at the exact probe"* — and that sentence names the shell, the snapshot and
the re-entry beat, which is exactly this epic. It sits here because:

- **E11 cannot start without it.** The adaptive engine needs a round that reliably *ends* with an
  outcome, and it needs the two outcomes that must **not** move θ (`abandoned`, `voided`) already
  defined as values. T04 delivers them.
- **The onboarding round is the only round every player is guaranteed to play**, and §14.6's risk 2
  ("the declaration interface is unusable without text") is retired here or not at all — its stated
  early signal is `OnboardingLedger.clearedTheSealBar`, which does not exist until T07.
- **The subagent diff review is a phase boundary, not a task.** Everything E02–E09 built is reviewed
  against `SPEC.md` once, in T10, before three more modes are layered on top of it.

## Scope

| In | Out — and who owns it |
|---|---|
| `AppDependencies.live()/.preview(seed:date:)`, `hunchEnvironment(_:)`, the three `@Entry` values, `SeedSource`, `Now`, re-injection into presented subtrees | The `Router` and the route graph — **E17·T01**. `AppDependencies` holds no router (`04 A33`) |
| Snapshot **cadence and integrity** (when it is written, what rides which write, `lawHash` → `.voided`) | The `ProbeSnapshot` value type, `StoreFile`, `PersistenceStore`, `FilePersistenceStore`, atomic writes and the write order — **E07·T01/T02/T09** |
| The 900 ms cold-launch re-entry beat | The 600 ms `.active` spin-up inside a live process — **E17·T09**; the verdict and reveal beats — **E08·T06 / E09·T10** |
| Abandon / discard / suspend semantics as values; three suspendable slots | Consuming the sticky target and the "no θ update" rule in the estimator — **E11·T01/T03/T06**; SIEVE's void-not-suspend policy — **E14·T08** |
| The fixed opening round, the 13-beat script, `OnboardingLedger`, the elastic cap, the five nudges | Cold-start calibration and the galloping ladder — **E11·T05**; the palette ceiling rule the script's beat 8 relies on — **E09·T04** |
| The Frame **withheld** on first launch and its key lighting at beat 13 | `FrameView` itself, the mode rack, sigils, key states and gates — **E17·T03/T04** |
| §6.11's 29 edge cases as named tests, at the layer each is testable | The rows §6.11 delegates: audio/haptics (#16–18) **E20**, Reduce Motion substitutions (#19) **E09·T12**, Dynamic Type (#20) **E19·T06**, Low Power (#21) **E20·T07**, rotation lock (#24) **E01·T02**, VoiceOver reveal (#26) **E19·T05** |
| `PROGRESS.md` / `tests.json` for the phase-3 gate, and the fresh-context diff review | The CI workflow and the hygiene script itself — **E01·T06/T07** (T01 and T08 here *append* checks 11 and 12 to the existing script) |
| Nudge **scheduling** and its hard floor | Nudge suppression wording under VoiceOver as an element-map concern — **E19·T10**; the audio click's synthesis — **E20·T03** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The composition root](T01-composition-root.md) | P0 | M | — | `AppDependencies.live()/.preview()`, `hunchEnvironment(_:)`, three `@Entry` values, `SeedSource` and `Now` as the app's only nondeterminism, re-injection into every presented subtree, and `AppLaunchRoute` deciding the first frame |
| T02 | [Mid-round snapshot wiring](T02-mid-round-snapshot-wiring.md) | P0 | M | T01 | Writes after every committed verdict, after every strike resolution and on `.inactive` (draft on that write only); `SnapshotIntegrity` turning a bad `lawHash` into `Outcome.voided` and never a silent alteration |
| T03 | [The 900 ms re-entry beat](T03-re-entry-beat.md) | P0 | M | T02 | Cold launch opens into `probing`, Bench collapsed, draft preserved; par ticks → ribbon → docked counterexample → throat, crossing **restored not replayed**, input locked throughout, no dialog |
| T04 | [Abandon and suspend semantics](T04-abandon-and-suspend-semantics.md) | P0 | M | T02 | Zero probes discards; ≥ 1 abandons at score 0 with no θ update and a sticky target; the chevron suspends silently; three `round-{mode}.json` slots, SIEVE excluded |
| T05 | [The fixed opening round](T05-fixed-opening-round.md) | P0 | M | T01 | Mode `probe`, band 1, seed `0x48554E4348`, `shape ∈ {triangle}`, seed glyph 22, generator bypassed, par 7 / cap 12, Dial preset to the seed glyph |
| T06 | [The 13-beat reveal script](T06-thirteen-beat-reveal-script.md) | P0 | L | T05 | One affordance at a time, beats 0–13; beats 0–5 never repeat and the script re-arms from beat 6; the Frame withheld until round 1 ends |
| T07 | [`OnboardingLedger` and the elastic cap](T07-onboarding-ledger-and-elastic-cap.md) | P0 | M | T06 | Eight fields in `ladder.json`; success iff the five-way conjunction; the cap defers while `sawReject == false`, re-arms at `max(12, probesUsed + 3)`, hard-stops at 24, stops re-arming after three failed openings |
| T08 | [The five nudges](T08-five-nudges.md) | P1 | M | T07 | Idle, no-Bench, barred-Seal, global idle, unvaried — one vocabulary, one hard floor, suppressed under VoiceOver, opacity-only under Reduce Motion |
| T09 | [§6.11's edge cases as named tests](T09-edge-cases-as-named-tests.md) | P0 | M | T04 | All 29 rows accounted for: each testable one a separate named test, each delegated one named with its owning epic |
| T10 | [Phase-3 gate and subagent diff review](T10-phase-3-gate-and-subagent-review.md) | P0 | M | T09 | The played-quit-relaunched-resumed run recorded in `PROGRESS.md`, `tests.json` updated, and the fresh-context review against `SPEC.md` |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E10-probe-e2e

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E10-probe-e2e
gh pr create --title "E10 — PROBE end to end: shell, resume and onboarding" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E11 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green | `swift test --package-path Modules` (host-runnable targets) **and** `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |
| 3 | Hygiene is green, including the two checks this epic adds | `Scripts/check-source-hygiene.sh` — check 11 (every presented subtree re-injects `hunchEnvironment`), check 12 (`Date()` only in `Now.swift`, `SystemRandomNumberGenerator` only in `SeedSource.swift`) |
| 4 | **A real round was played, the app quit, relaunched, and resumed at the exact probe with the draft intact** | The transcript in `PROGRESS.md` §Phase 3, produced by T10's `xcrun simctl` sequence, including the `round-probe.json` dump taken between quit and relaunch |
| 5 | The opening round runs its 13 beats and the ledger records success | `swift test --package-path Modules --filter OnboardingScriptTests` + the simulator transcript showing `declaredCorrectly && selfConstructedProbes >= 1 && sawAdmit && sawReject && boundAnAttribute` in `ladder.json` |
| 6 | The elastic cap defers the loss while `sawReject == false` and hard-stops at probe 24 | `swift test --package-path HunchCore --filter ElasticCapTests` |
| 7 | Every one of §6.11's 29 rows is either a named passing test or a named row with its owning epic | `swift test --package-path HunchCore --filter EdgeCase` and `--package-path Modules --filter RoundEdgeCase`; the delegation table in T09 |
| 8 | A fresh-context subagent diff review against `SPEC.md` reports **no** correctness or stated-requirement gap | The review transcript pasted into `PROGRESS.md`, with every finding either fixed on this branch or recorded in `DECISIONS.md` with a reason |

## Definition of done

- [ ] All ten task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with checks 11 and 12 present and each demonstrated to fail on a deliberately planted violation before being reverted.
- [ ] The play → quit → relaunch → resume transcript is in `PROGRESS.md`, with the on-disk `round-probe.json` quoted.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: snapshot cadence, `lawHash` void, re-entry beat order and lock, leave-round actions, opening-round configuration, script beats and re-arm, ledger success, elastic cap and hard stop, nudge floor and suppression, and each named §6.11 case.
- [ ] `DECISIONS.md` carries this epic's five entries: `Now`/`SeedSource` placement and the closure-shaped seam into `LoomFeature`; Modules-side tests selected by target rather than tag; the three-slot reading of open decision 3; the re-entry beat's Reduce Motion form; and any subagent-review finding deliberately not fixed.
- [ ] The PR is merged with every check green, and `main` is pulled before E11 begins.
