# E13 — ECHO

| | |
|---|---|
| **id** | E13 |
| **title** | ECHO |
| **branch** | `epic/E13-echo` |
| **depends on** | E12 (which itself carries E01–E11) |
| **gate** | The primer separation invariant asserts **exactly one lit pool member** at the `primer → casting` transition over a seeded pool corpus · §8.7's worked round reproduces numerically (setF1 0.75, order 0.667, score 506, 1 mark, Retention sample 0.50) · one interruption restarts the cast free and a second abandons with **no ability update in either direction** |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH contains the one mode that does not ask the player to *find* a law.
ECHO selects — never generates — from the **echo pool**, the last eight laws the player actually
inscribed, identifies which one is in force with a primer whose verdict vector is unique across that
pool, and then switches the Loom's lamp off: `L` distinct glyphs stream through the throat at a fixed
cadence with no verdict rings and a dark ribbon, and the player must reproduce, from a tray and a
rail, which of them the law admitted and in what order. Difficulty moves through a single load index
`ℓ ∈ 1…8` — `L`, the lawful count `A`, and the cadence — and never through the law, because the law
is the player's own.

The epic also ships the *proof* that this is not a memory task, as running code rather than as a
paragraph: every cast glyph is re-presented in the tray, the pool strip renders all eight candidates
and extinguishes seven of them on screen as the primer resolves, and the round's dominant scoring
term is `setF1²`, which for a stateless pool law is fully recomputable from what is on the display.
Without the strip, §8.8's claim is false and the mode measures unaided recall of eight laws spanning
eight rounds. The strip is therefore not decoration; it is the invariant.

## Why now

§14.3's phase 5 is three epics in a fixed order — DRIFT, then ECHO, then SIEVE — and ECHO sits in the
middle for two reasons that are not merely sequencing.

- **ECHO consumes what DRIFT produces.** §8.2's contribution table says a won DRIFT round contributes
  `L₂` **only** to the pool, and `L₂` does not exist as a distinct value until E12·T01 ships
  `DriftSchedule`. Building ECHO first would mean writing the contribution rule against a law pair
  that has no type.
- **ECHO's pool is what SIEVE's inscription rule is aimed at.** §9.6 gives a run sieved at
  `ratio ≥ 0.92` a Codex page "which then enters ECHO's pool", so E14·T05 is written against
  `EchoPool` as an existing type. The pool must exist before the mode that feeds it does.

It also unblocks E15 and E16 in one narrow way each: E15·T06's **burnish** is triggered by exactly one
event in the whole game — an ECHO round settled at 3 marks — and E16·T05's **Retention** axis has
exactly one primary source, which is the transcript T08 emits. Neither has an input until this
epic lands.

## Scope

| In | Out — and who owns it |
|---|---|
| `EchoPool`, §8.2's contribution table (DRIFT's `L₂` only, SIEVE at `ratio ≥ 0.92`, a loss contributes nothing), the arming snapshot | `CodexPage`, `RoundRecord` and the archive value types — **E07·T09**; `codex-index.json`'s loading and the `Codex` observable — **E15·T01**; applying the burnish to a page — **E15·T06** |
| The pool strip's drawing, its elimination predicate, and the exemption argument that keeps it off the 44 pt hit floor | The extension thumbnail's own geometry and the Codex sites that use it — **E15·T03**; the shelf plate's recents strip — **E15·T02** |
| `PrimerChain`, the separating-chain search over `m ∈ {3,4,5}`, verdict-vector uniqueness, BLIND-PRIMER, ECHO's availability predicate | Drawing an absent-versus-barred mode key on the rack, and §9.10's five-page unlock gate — **E17·T04** |
| `EchoCast` construction (distinctness, contextual realisation by evaluation, no four consecutive same-verdict positions) and the cast's cadence beat sheet | The glyph renderer — **E04**; the ribbon/rail/tail drawing that ECHO reuses — **E08·T05**; the verdict ring, link arc, cancel hatch and tick row — **E04·T07/T08** |
| Tray and rail, tap-to-lift / tap-to-return, the tray tile's `placed` toggle, and the reach argument that keeps ECHO playable below `y = 220` | The 44 pt floor and the inter-target rule as global lints — **E19**; the four rotors and every announcement's wording — **E19·T01/T04** |
| The twin key's ECHO meaning (one replay, ×0.6, never clears the rail) | The twin key's PROBE meaning and the breath — **E08·T07**; the Seal's drawing and its five states — **E09·T07** |
| The `ℓ` table, `δ_ECHO`, `band_ECHO`, `selectFromPool(targetδ)` and STALE-POOL | The 13-step serving policy that hands ECHO a `targetδ`, the per-mode band clamp and the mode rotation — **E11·T03/T06**; `difficulty(of:)` — **E06·T01** |
| `EchoScore`, the LIS-based `order`, marks, EMPTY-RAIL / RAIL-OVERFILL, and the `(hit, falseIncludes, A, order, replayed)` transcript | Turning that transcript into a Retention increment and applying `α` — **E16·T05/T06**; the Rasch update itself — **E11·T02** |
| `EchoPhase`, the one-lit-member invariant, the 400 ms-per-glyph reveal, the interruption policy, `EchoSnapshot` and the seven edge cases | `PersistenceStore`, atomic writes and the §11.13 write order — **E07·T01/T02**; the chevron, the `scenePhase` table and the 600 ms spin-up — **E17·T09** |
| — | DRIFT in its entirety — **E12**; SIEVE in its entirety — **E14** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The echo pool](T01-the-echo-pool.md) | P0 | M | — | The last 8 inscribed laws as a deduplicated value, selected and never generated so G9 is bypassed by construction; §8.2's contribution table as an exhaustive switch; the snapshot taken at `arming` and persisted with the round |
| T02 | [The pool strip](T02-the-pool-strip.md) | P0 | M | T01 | `PrimerChain` plus the elimination predicate, and eight 40 pt extension thumbnails in Codex order, oldest leading, each inconsistent member extinguishing to 25 % with the diagonal cancel hatch; read-only and not a hit target |
| T03 | [The primer](T03-the-primer.md) | P0 | L | T02 | The smallest `m ∈ {3,4,5}` for which a separating chain exists over 200 seeded attempts; contextual members take `prev` from the chain's own adjacency with the seed glyph priming position 0; BLIND-PRIMER drops the two oldest and retries from `m = 3`; below three members ECHO is absent, never lit and lying |
| T04 | [The cast](T04-the-cast.md) | P0 | M | T03 | `L` pairwise-distinct glyphs at fixed cadence, no verdicts, dark ribbon; 120 ms draw-in / `cadence − 240 ms` hold / 120 ms withdraw with link arcs; Reduce Motion is hard crossfades at the identical cadence; `A` never reaches the view layer |
| T05 | [Tray and rail](T05-tray-and-rail.md) | P0 | M | T04 | The tray as 84 × 72 cells in canonical `glyphID` order, the rail as the fifth surface of the one ribbon drawing, tap to lift and tap to return, and the `placed` toggle that keeps every action below `y = 220` |
| T06 | [One replay](T06-one-replay.md) | P1 | S | T05 | The twin key replays the cast exactly once per round at ×0.6, stays live during recall, never clears the rail, and is structurally impossible to press twice |
| T07 | [Load index ℓ and δ_ECHO](T07-load-index-and-delta-echo.md) | P0 | M | T01, T03 | The eight-column table with its cast duration derived rather than stored, `δ_ECHO` and `band_ECHO`, `selectFromPool(targetδ)` and its tie-break, and STALE-POOL raising `ℓ` to 8 and skipping ECHO rather than generating |
| T08 | [ECHO scoring](T08-echo-scoring.md) | P0 | M | T07 | `setF1²·(0.70 + 0.30·order)·replayF` with `order` by longest increasing subsequence, success iff `setF1 == 1`, marks 3/2/1, EMPTY-RAIL and RAIL-OVERFILL both legal and both strictly dominated, and no strike mechanic at all |
| T09 | [`EchoPhase`, the reveal and interruption](T09-echophase-reveal-and-interruption.md) | P1 | M | T08 | The eight phases with the asserted one-lit-member invariant, the 400 ms-per-glyph reveal with intrusions and misses, one free cast restart then abandonment with no ability update, and the seven edge cases each as a named test |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E13-echo

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E13-echo
gh pr create --title "E13 — ECHO" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E14 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | **Exactly one strip member is lit at `primer → casting`**, over a seeded pool corpus and for every pool the corpus produces | `swift test --package-path HunchCore --filter EchoPrimerTests/exactlyOneMemberSurvivesTheChain` (the search's own boundary) and `--filter EchoRoundInvariantTests/oneLitMemberAtCastingEntry` (the phase transition, where §8.5 says to assert it) |
| 3 | The primer is minimal in `m` and honest when it fails: no chain at `m = 5` drops the two oldest and retries from `m = 3`; a three-member pool that still cannot be separated makes ECHO **unavailable**, not lit | `swift test --package-path HunchCore --filter EchoPrimerTests` |
| 4 | **§8.7's worked round reproduces numerically** — setF1 0.75, order 0.667, score 506, 1 mark, and the emitted transcript `(hit 3, falseIncludes 1, A 4, order 0.667)` yielding §11.9's Retention sample 0.50 | `swift test --package-path HunchCore --filter EchoScoreTests/workedRoundFromSectionEightSeven` |
| 5 | **One interruption restarts the cast free; a second abandons with no ability update in either direction** | `swift test --package-path HunchCore --filter EchoInterruptionTests` |
| 6 | The seven §8.10 edge cases are each a named, passing test | `swift test --package-path HunchCore --filter EchoEdgeCaseTests` — seven test names: `blindPrimer`, `stalePool`, `emptyRail`, `railOverfill`, `duplicateSuppression`, `replayMidPlacement`, `poolChurnMidRound` |
| 7 | The app-side suites are green on both reference devices | `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` and the same with `name=iPhone 16 Pro Max` |
| 8 | ECHO is playable without reaching above `y = 220`, and the rail's one action has a same-effect route inside the thumb arc | `xcodebuild test … -only-testing:LoomFeatureTests/EchoReachTests` |
| 9 | Hygiene is green, including this epic's two additions | `Scripts/check-source-hygiene.sh` — `EchoRoundView` contains no `Text`/`Label`/`AttributedString` outside `.accessibility*` (existing check 7, now covering a real file), and the new check: no symbol naming the lawful count (`lawfulCount`, `truth`, `A`) is reachable from `Modules/Sources/LoomFeature/EchoRoundView.swift` or its subviews |
| 10 | `ECHO` never calls the generator | `grep -rn "generate(" Modules/Sources/LoomFeature/Echo*.swift HunchCore/Sources/Rounds/Echo*.swift` returns nothing |

## Definition of done

- [ ] All nine task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green on both reference devices.
- [ ] `Scripts/check-source-hygiene.sh` green, with the lawful-count check present and demonstrated to fail on a deliberately planted reference before being reverted.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: pool capacity and dedup, the contribution table, chain uniqueness and minimality, one lit member at `casting`, cast distinctness and the three-in-a-row bound, the `ℓ` table and its derived cast duration, `δ_ECHO`/`band_ECHO`, `selectFromPool`'s tie-break, STALE-POOL, the score formula and the four mark thresholds, success iff `setF1 == 1`, the reveal's phase count, the interruption policy, the reach rule, and each of the seven edge cases.
- [ ] `DECISIONS.md` carries this epic's five entries: pool dedup by `lawKey` (forced by the primer's uniqueness requirement, not chosen for tidiness); `EchoOutcome` declared rather than extending §6.1's `Outcome`; the 40 pt pool member drawn by `ExtensionThumbnail` and not by the Assay grid, resolving the 2.25 / 2.5 pt cell conflict between two skill reference files; what counts as an *interruption* (a departure from `casting` only); and BLIND-PRIMER's drop happening **before** selection, so the strip and the primer always describe the same pool.
- [ ] `SPEC.md` records ECHO's ownership rows: §8.2 the pool, §8.6 `ℓ` and `δ_ECHO`, §8.7 the score and the transcript, §11.9 the Retention sample (owned there, **not** here).
- [ ] The PR is merged with every check green, and `main` is pulled before E14 begins.
