# E11 — The adaptive engine and the harnesses

| | |
|---|---|
| **id** | E11 |
| **title** | The adaptive engine and the harnesses |
| **branch** | `epic/E11-ladder` |
| **depends on** | E10 (which itself carries E01–E09) |
| **gate** | H1–H21 pass at the fast-suite subset · H3 holds `0.80 ± 0.03` · H10 gives ρ ≥ 0.75 overall and ≥ 0.45 within every band · H18 asserts `π₀ = 0.44` and fails the build if it is stale · H19 keeps generator fallback under 2 % per band · the full Level-B matrix is green behind `HUNCH_CALIBRATION=1` · Level A's 10⁶ rounds run in under 0.4 s inside the ten-second budget |
| **tasks** | 12 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH **chooses what to serve you**, and the choice is measured rather than
asserted. A Rasch estimator holds one latent ability per mode on the same logit scale the difficulty
function already publishes; a thirteen-step serving policy turns that ability into a band and a
`targetδ` in difficulty units; a centred pressure term makes the ladder escalate on a streak and
relent after two losses without moving the average anywhere; a galloping cold start seeds a brand-new
player in at most five rounds with the full palette in their hands; and a serving layer assembles
`avoid` from three rings so the generator never repeats a law you just solved or just lost.

And — the half that makes the other half true — **two simulated players ship in the package**. Level A
draws Bernoulli responses and runs a million rounds in under four tenths of a second inside the fast
suite. Level B actually induces: a greedy maximum-expected-entropy-reduction reasoner over a
deliberately mis-specified human family prior, with ability entering as search breadth and Wason's
positive-test bias entering as a substitution probability. Twenty-one invariants, H1 to H21, become
shipped assertions with a `tests.json` entry each. The design's headline number — **80 % round
success across 600 rounds** — stops being a target in a document and becomes a measurement that fails
the build when it drifts.

## Why now

The engine cannot be written before there is a round that reliably ends with an outcome, and it
cannot be *believed* before there is a generator whose difficulty function it can trust. E10 closed
phase 3: a round plays, quits, relaunches and resumes, and the two outcomes that must **not** move θ
(`abandoned`, `voided`) already exist as values with `updatesAbility: false` as a field somebody can
assert on. E06 closed the generator, `difficulty(of:)` and `Band.achievableDifficultyRange` — the last
of which is a hard input to step 11 and the reason H19 can pass at band 1 at all.

It sits before the three remaining modes because:

- **DRIFT, ECHO and SIEVE each consume a `targetδ` and hand back an outcome.** §10.3 step 13 dispatches
  to all four; §8.6's load index and §9.7's tempo step are *solved from* `targetδ`. Building those
  three modes against a serving policy that does not exist yet means building them against a stub, and
  the stub would be the thing that ships.
- **H10 is allowed to fail honestly, and if it does, §5.1's modifier weights are regenerated.** That
  regeneration touches `difficulty(of:)`, which every band's `|H|`, par, cap and index depend on. It has
  to happen before three more modes are calibrated against those numbers, not after.
- **`ladder.json` is the file three later epics write into.** `maxBandEverServed` (E09·T04's palette
  ceiling), the floor-rescue Assay grant (E09·T06), and the `OnboardingLedger` (E10·T07) are all
  already shipped *values* with no owning payload. This epic gives them one.

## Scope

| In | Out — and who owns it |
|---|---|
| `Ability`, `ServingState`, `StickyTarget`, `LadderState` — the whole `ladder.json` payload | `PersistenceStore`, `StoreFile.ladder`, atomic writes, the schema and the reset map — **E07·T01/T02/T04/T06**. The Settings alert that fires the reset — **E17·T08** |
| `AbilityEstimator` — `θ += K(n)(x − P)`, strictly symmetric, pure | The Profile's `value += α(sample − value)` update, which is a different rule for a different quantity — **E16·T06** |
| The 13-step serving policy, steps 1–12, and `Serving` as its output value | Step 13's four dispatch implementations: PROBE/DRIFT → **E06·T06** / **E12·T01**; ECHO's `selectFromPool` and `ℓ` — **E13·T07**; SIEVE's `lawBand` and tempo step `s` — **E14·T06** |
| The pressure term, the `reach`/`relief` ladders, the clamp-binding freeze, and `π₀ = 0.44` | The *rendering* of anything the pressure term moves — there is none, and T09 is the test that says so |
| Cold start: the 1·2·4·6·8 gallop, `b_est`, `core = b_est − 3.114`, the calibration palette grant | `PaletteCeiling` itself and `required(for:)` — **E09·T04**; `AssayEvidenceGrant` — **E09·T06**; the fixed opening round and its 13 beats — **E10·T05/T06** |
| The serving layer: seed choice, the two-tier `avoid`, the 50-entry novelty ring, the per-band soft-avoid, today's Anomaly, the 8-entry lost-law cooldown, sticky-target consumption | `generate` and G9 itself — **E06·T05/T06**; the Anomaly's derivation and its θ-isolation — **E16·T01/T03**; the Codex found set's storage — **E15·T01** |
| Anti-frustration and anti-boredom **triggers and state**: floor rescue, ceiling variation's tightened mark, ceiling rotation, weak-mode detection | Every one of their *drawings*: the mode sigil's luminance lift — **E17·T04**; the third tick row — **E08·T08**; the cap reveal — **E09·T10** |
| Absence and return: `n` decay, the re-entry relief grant | The `Now` source itself, which stays in `HunchAppFeature` — **E10·T01** |
| "Difficulty is never a number" as hygiene check 13 plus the drone step as a value | The drone's synthesis and its `Cue` — **E20·T03**; the three permitted signals' drawings — **E08·T08**, **E09·T01**, **E15·T02** |
| `ResponseHarness`, `ReasonerHarness`, the family prior, Spearman ρ, and H1–H21 | The 10,000-law generator suite and the determinism golden — **E06·T09/T10**; the accessibility gates — **E19·T11** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [`Ability` and `ServingState`](T01-ability-and-serving-state.md) | P0 | M | — | `baseline: Double?` so "undefined, not 0" is a type; three mode offsets at `K_Δ = 0.6·K` with 0.985 shrinkage; `n` capped at 4,096; θ clamped `[−6,+6]` at write; `StickyTarget`; `ModeVector` instead of `[Mode: T]` so a round costs no allocation |
| T02 | [`AbilityEstimator`](T02-ability-estimator.md) | P0 | M | T01 | `θ += K(n)(x − P)`, `K = max(0.18, 0.90/(1 + n/8))`, **strictly symmetric** and branch-free on the outcome; a pure function of `(Ability, Mode, servedDelta, Bool)` with no clock, RNG or store |
| T03 | [The 13-step serving policy](T03-the-thirteen-step-serving-policy.md) | P0 | L | T02 | Steps 1–12 in exact order with step 11 re-deriving `targetδ` after every step that can move the band; `modeBias` drift −0.50; deterministic jitter from `roundSeed`; the per-mode clamps and SIEVE's `δ ≤ 2.99`; difficulty units out, never a logit |
| T04 | [The pressure term and `π₀`](T04-the-pressure-term-and-pi-zero.md) | P0 | M | T03 | `reach` on a win streak, `relief` after two losses, both frozen in whichever direction a step-8 clamp binds; `π₀ = 0.44` locked and decomposed into `0.375 + 0.065` so H18 can catch staleness at the right granularity; `reach` never touches θ |
| T05 | [Cold start and calibration](T05-cold-start-and-calibration.md) | P0 | M | T04 | The galloping ladder over bands 1·2·4·6·8, `b_est` broken by the previous round's marks, `core = (b_est − 4.5) + ln 4`, the full palette for rounds 1–5, and exemption from `reach`, `relief` and `consecutiveLosses` |
| T06 | [The serving layer](T06-the-serving-layer.md) | P0 | M | T03 | Seed choice, the two-tier `avoid` (hard: novelty ring + cooldown ring + today's Anomaly; soft: the per-band found set), sticky-target consumption, and the `@Observable Ladder` that is the only thing here that is not a pure function |
| T07 | [Anti-frustration and anti-boredom](T07-anti-frustration-and-anti-boredom.md) | P2 | M | T06 | Floor rescue at band 1 with a permanent Assay overlay; the ceiling variation's tightened `0.45·par` mark; the ceiling-rotation counter; the weakest-mode predicate; **no cap relief and no par relief, ever**, asserted structurally |
| T08 | [Absence and return](T08-absence-and-return.md) | P1 | S | T04 | θ never decays and confidence does: `n` decays past seven days by `exp(−(gap−7)/90)` with a floor of 6; the re-entry relief grant, armed once per session, disarmed on the first win or after two rounds; §10.9's four-row table reproduced exactly |
| T09 | [Difficulty is never a number](T09-difficulty-is-never-a-number.md) | P0 | S | T03 | Exactly three signals plus the sub-numeric drone step; hygiene check 13 asserting no band number, percentage, difficulty colour, level string or post-round "difficulty adjusted" acknowledgement exists anywhere the player can see |
| T10 | [Level A — `ResponseHarness`](T10-level-a-response-harness.md) | P0 | M | T04 | `x ~ Bernoulli(σ(θ_true + ε − δ))` with `ε ~ N(0, 0.35²)`, a full closed loop over policy + estimator + pressure, 10⁶ rounds in under 0.4 s, and the offline solver `π₀` is measured against |
| T11 | [Level B — `ReasonerHarness`](T11-level-b-reasoner-harness.md) | P0 | L | T10 | A greedy maximum-expected-entropy-reduction reasoner over a mis-specified family prior; ability as search breadth; the Wason substitution; the declare threshold; counterexample ingestion as a hard constraint; the 8 × 20 × 20 smoke subset fast and the 640 k matrix behind `HUNCH_CALIBRATION=1` |
| T12 | [H1–H21 as shipped assertions](T12-h1-h21-as-shipped-assertions.md) | P0 | L | T11 | Every invariant with its stated measurement and pass condition and a `tests.json` entry, including H9's unforced-band-change form, H14's Anomaly isolation and H20's serve-time palette sufficiency; H10 may fail honestly and the answer is regenerated weights, never a weakened test |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E11-ladder

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E11-ladder
gh pr create --title "E11 — The adaptive engine and the harnesses" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E12 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed, retagged or given a wider tolerance to make a build pass (§14.1,
VERIFICATION) — and H10 is the specific row this rule exists for: if ρ comes in under 0.75 the answer
is to regenerate §5.1's modifier weights from the harness and re-run, not to lower the threshold.

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | **All twenty-one invariants pass at their fast form** | `swift test --package-path HunchCore --filter HarnessInvariant` — twenty-one named tests, zero skips, zero `withKnownIssue` |
| 3 | **H3 holds `0.80 ± 0.03`** over rounds 26–400 at `θ_true ∈ {−1, 0, +1, +2, +3}` | `swift test --package-path HunchCore --filter 'HarnessInvariantTests/targetHold'`, whose failure message prints the realised rate per `θ_true` |
| 4 | **H10 gives ρ ≥ 0.75 overall and ≥ 0.45 within every band** | `HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter DifficultyCalibrationTests` — and if it fails, the weights are regenerated, `DECISIONS.md` records the regeneration, and the run is repeated |
| 5 | **H18 asserts `π₀ = 0.44` and fails on staleness** | `swift test --package-path HunchCore --filter 'HarnessInvariantTests/pressureIsCentred'`; then deliberately widen the jitter to `±0.50`, watch H18 go red, and revert — the transcript goes in `PROGRESS.md` |
| 6 | **H19 keeps generator fallback under 2 % per band** | `swift test --package-path HunchCore --filter 'HarnessInvariantTests/generatorFallbackRate'`, which prints the per-band rate whether it passes or fails |
| 7 | **Level A runs 10⁶ rounds in under 0.4 s** | `swift test --package-path HunchCore --filter ResponseHarnessTests` — the budget is an assertion inside the test, not a stopwatch in a comment |
| 8 | **The full Level-B matrix is green behind the env var**, inside the fifteen-minute hang guard | `HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter ReasonerHarness` and the same on the nightly workflow run |
| 9 | Hygiene is green, including check 13 | `Scripts/check-source-hygiene.sh`, with check 13 demonstrated to fail on a planted `Text(verbatim: "Band \(band.rawValue)")` before being reverted |
| 10 | Nothing in `Ladder` reads a clock, an RNG or a store | `grep -rn 'Date()\|UUID()\|\.random(\|SystemRandomNumberGenerator\|PersistenceStore\|import Testing' HunchCore/Sources/Ladder` returns nothing |
| 11 | The Modules-side suites are green | `swift test --package-path Modules --filter LadderObservableTests` and `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |

## Definition of done

- [ ] All twelve task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator; `Nightly.xctestplan` green with `HUNCH_CALIBRATION=1`.
- [ ] `tests.json` carries **twenty-one** harness rows (`harness.H1` … `harness.H21`), each with the measurement, the pass condition and the command that produced its status, plus the per-task rows for the estimator, the policy's thirteen steps, the pressure ladder, calibration, the avoid set, the pacing triggers, absence, and the drone step.
- [ ] `Scripts/check-source-hygiene.sh` carries check 13 and was demonstrated red on a planted violation.
- [ ] `PROGRESS.md` records: the measured Level-A table (θ_true × θ̂@400 × rounds-to-±0.5 × success × max loss run × modal band) against §10.10's published table; the measured per-band fallback rate; the measured ρ overall and within band; and the H18 staleness demonstration.
- [ ] `DECISIONS.md` carries this epic's rulings: the `ModeVector` deviation from `08 §3`'s `[Mode: T]` shape and its 400 ns/round reason; PROBE-anchored updating (only `baseline` moves on a PROBE round, only the offset on the other three); the two-tier `avoid` reading of §5.3 against §10.8; the re-entry-grant reading of §10.9 that reproduces its worked table; the ceiling-variation revert condition; and the statistics-screen exemption to §10.5's "no percentage" clause.
- [ ] `SPEC.md`'s locked-constant table shows `π₀ = 0.44` with H18 named as its guard.
- [ ] The PR is merged with every check green, and `main` is pulled before E12 begins.
