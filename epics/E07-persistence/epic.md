# E07 — Persistence and the round core

| | |
|---|---|
| **id** | E07 |
| **title** | Persistence and the round core |
| **branch** | `epic/E07-persistence` |
| **depends on** | E06 (which transitively carries E01, E02, E05) |
| **gate** | save → kill → relaunch identity for every `StoreFile` case · `Fixtures/v1/` loads green under the current schema · all five resets leave the exact specified file set with `anomaly.json` **and** `anomaly.hw` byte-identical · a truncated `codex-b4.json` quarantines and rebuilds rather than crashing · no single file in the store exceeds 512 KB · the `RoundPhase` transition table is an exhaustive `switch` with no `default:` |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH has a disk. `Application Support/Hunch/`'s ten kinds of file exist as
one exhaustive `enum StoreFile`, sitting behind an injected `protocol PersistenceStore` with two
shipping implementations — an `actor FilePersistenceStore` that writes atomically in §11.13's order
and an `InMemoryPersistenceStore` that previews and tests compose — plus a global schema, a
transactional migration that stages and swaps a whole directory, a checked-in `Fixtures/v1/` tree,
and the five-row reset map with the Anomaly ledger proved untouchable by all five. Alongside it, the
pure half of a round exists and is tested with no simulator anywhere in sight: `RoundPhase`,
`Outcome`, a total `(RoundPhase, RoundEvent) -> RoundPhase.Transition` function, `Probe`, `Ribbon`
with adjacency-derived twin semantics, `ProbeSnapshot` carrying the resolved `LawNode`, and
`CodexPage` / `RoundRecord` / `Profile` / `AnomalyLedger` as core `Codable Sendable` values.

## Why now

E06 finished the generator, so a law can be produced; nothing yet can keep one. Every epic after
this one writes to disk or reads a phase: E08's `Round` is explicitly "thin over `HunchCore`'s phase
machine, scoring and ribbon", E09 mints a `CodexPage` at t = 0 on the Seal press, E10's whole
phase-3 gate is *play, quit, relaunch, resume at the exact probe*, E11's `ladder.json` is a
`StoreFile` case, E15's `Codex` is lazy loading over `codexShelf(Band)`, E16's entire anti-cheat is
the reset map's immunity clause, and E17's DATA section is five buttons wired to `ResetAction`.
Landing persistence and the round core *before* the first pixel is what keeps the UI thin: the state
machine and the scoring are tested on the host in milliseconds, and `RoundView` gets to be a
rendering of values it does not own.

## Scope

| In | Out — and who owns it instead |
|---|---|
| `protocol PersistenceStore`, `enum StoreFile`, `StoreHealth`, `StoreError`, `RecoveryPolicy` | The `@Entry var storeHealth` hairline in the chrome — **E10·T01** wires it, **E20·T09** styles it |
| `actor FilePersistenceStore`: atomic writes, §11.13's write order, `isExcludedFromBackupKey`, quarantine | `actor LawIndexLoader` and the contents of `lowerBandIndex.bin` — **E05·T07** |
| `InMemoryPersistenceStore` (ships, imports no `Testing`) | `AppDependencies.preview(seed:date:)` that composes it — **E10·T01** |
| `Manifest`, the global `schema`, `SchemaEnvelope`, `migrate(directory:)` with staging + atomic replace | Any `migrate_v1_to_v2` step body — there is no v2; the step *chain* ships empty and tested |
| `Fixtures/v1/`, the `StoreSandbox` `TestScoping` trait, round-trip for every `StoreFile` case, the malformed sibling, the 512 KB assertion | The one-file-per-shelf-open assertion — **E15·T01**, because it is a `Codex` behaviour, not a store behaviour |
| `enum ResetAction` and the five file-level effects, asserted against a copy of the v1 fixture | The five alert variants, their copy and their cancel focus — **E17·T08**; the day-1 *contents* of a reset file — **E16** (Profile), **E11** (ladder), **E16·T11** (statistics) |
| `RoundPhase`, `Outcome`, `RoundEvent`, `RoundPhase.Transition`, the total transition function | Every duration in the table (420 / 640 / 960 / 1,840 ms …) — **E08·T06** and **E09·T10**; they are `HunchUI` |
| `Probe`, `Ribbon`, twin adjacency, `duplicatePairCount`, per-round score/marks application | `RibbonCanvas`, the doubled ring, the split ring drawing — **E04·T07** and **E08·T05**; the score *arithmetic* — **E06·T07** |
| `ProbeSnapshot` + its integrity check; `CodexPage`, `RoundRecord`, `Profile`, `AnomalyLedger` as values | Snapshot *cadence* (after every verdict, on `.inactive`) — **E10·T02**; the 900 ms re-entry beat — **E10·T03**; `utcDayIndex`/`anomalySeed` — **E16·T01**; the high-water *rule* — **E16·T02**; the Profile *update rule* — **E16·T06**; `Ability`/`ServingState`/`OnboardingLedger` — **E11·T01** / **E10·T07** |
| `DriftSchedule`, `SieveSchedule`, `EchoCast` — **not created here**. `01 P12` / `08 §7.3`: a target's per-mode files are created the day their owner section is implemented (**E12**–**E14**) | |

## The task list

| # | Task | P | Size | Deps | One line |
|---|---|---|---|---|---|
| T01 | [`PersistenceStore` and `StoreFile`](T01-persistence-store-and-store-file.md) | P0 | M | — | The seam and the ten-file tree as one exhaustive enum, so adding a file is a compile error everywhere it matters |
| T02 | [`FilePersistenceStore`](T02-file-persistence-store.md) | P0 | M | T01 | The actor: atomic writes, §11.13's order, the one backup exclusion, nothing in `Documents/` |
| T03 | [`InMemoryPersistenceStore`](T03-in-memory-persistence-store.md) | P0 | S | T01 | The shipping in-memory store, plus one parity suite both stores must pass |
| T04 | [Schema and migration](T04-schema-and-migration.md) | P0 | M | T02 | One global schema echoed by every file; staging directory, fsync, atomic replace, and it rolls back |
| T05 | [`Fixtures/v1/` and the persistence suite](T05-fixtures-v1-and-the-persistence-suite.md) | P0 | M | T04 | The checked-in tree, the sandbox trait, save→kill→relaunch for every case, quarantine, 512 KB |
| T06 | [The reset map](T06-the-reset-map.md) | P0 | M | T05 | Five actions, five exact surviving file sets, and the assertion that *is* the Anomaly anti-cheat |
| T07 | [`RoundPhase` and `Outcome`](T07-round-phase-and-outcome.md) | P0 | M | — | Eight phases, five outcomes, a total transition function, `settled(.voided)` reachable only from `arming` |
| T08 | [`Probe`, `Ribbon` and `Score`](T08-probe-ribbon-and-score.md) | P0 | M | T07 | The transcript as a value; a twin is an *adjacent* re-probe only; scoring applied per round |
| T09 | [`ProbeSnapshot` and the archive value types](T09-probe-snapshot-and-archive-value-types.md) | P0 | M | T07 | The snapshot stores the law itself; `CodexPage` / `RoundRecord` / `Profile` / `AnomalyLedger` |

**Execution order:** T01 → T02 → T03 → T04 → T05 → T06, and T07 → T08 → T09 alongside. T07 has no
dependency on the persistence chain, so if two sittings are available, start T07 first and let T09
land after T05 (its `ProbeSnapshot` fixture file wants the tree). One commit per task, in order.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E07-persistence

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E07-persistence
gh pr create --title "E07 — Persistence and the round core" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E08 until this PR is merged.** E08·T01's `Round` imports `RoundPhase`, `Ribbon` and
`PersistenceStore` in its first line; starting it against an unmerged branch means resolving those
types twice. If a check fails, fix it on the same branch and push again. **Never merge red, and
never disable, skip or weaken a check to get green** — `tests.json` entries are added here, never
removed.

## The gate

Every line below must be true, and each names the command that proves it. Run them from the repo
root on the branch, immediately before `gh pr create`.

| # | Must be true | Proof |
|---|---|---|
| 1 | Save → kill → relaunch is identity for **every** `StoreFile` case | `swift test --package-path HunchCore --filter StoreRoundTripTests` — the test iterates `StoreFile.allCases`, drops the actor, builds a second one on the same directory and compares bytes |
| 2 | `Fixtures/v1/` loads green under the current schema | `swift test --package-path HunchCore --filter FixtureV1Tests` |
| 3 | All five resets leave the exact specified file set | `swift test --package-path HunchCore --filter ResetMapTests` |
| 4 | `anomaly.json` **and** `anomaly.hw` are byte-identical after all five | `ResetMapTests.anomalyLedgerSurvivesEveryReset` — a direct `Data` comparison of both files before and after each of `ResetAction.allCases`, and again after all five have run in sequence |
| 5 | A truncated `codex-b4.json` quarantines and rebuilds, and never throws to the round | `swift test --package-path HunchCore --filter truncatedShelfQuarantines` (`StoreRoundTripTests`) |
| 6 | No single file in the store exceeds 512 KB | `FixtureV1Tests.noFileExceedsTheShardBudget`, run over the sandboxed v1 tree |
| 7 | The `RoundPhase` transition table has no `default:` | `! grep -n 'default:' HunchCore/Sources/Rounds/RoundPhase.swift HunchCore/Sources/Rounds/RoundEvent.swift HunchCore/Sources/Persistence/StoreFile.swift HunchCore/Sources/Persistence/ResetAction.swift` |
| 8 | The transition function is total and pure over all 17 × 18 (phase, event) pairs | `swift test --package-path HunchCore --filter RoundPhaseTransitionTests` |
| 9 | The fast suite is still under 10 s | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 10 | Source hygiene is clean — no `Date()`, `UUID()`, `.random(`, `SystemRandomNumberGenerator` under `HunchCore/Sources/`, and no `documentsDirectory` anywhere | `bash Scripts/check-source-hygiene.sh` |
| 11 | Exactly one actor was added to the two-actor budget, and no escape hatch | `grep -rn --include='*.swift' -E '^[[:space:]]*(public \|package )?actor ' HunchCore Modules` shows `FilePersistenceStore`, `InMemoryPersistenceStore` and (from E05) `LawIndexLoader`; `grep -rn '@unchecked Sendable\|nonisolated(unsafe)\|Task.detached\|assumeIsolated' HunchCore Modules App` is empty |

> Gate 11 note: `InMemoryPersistenceStore` is the epic's one deliberate widening of
> `hunch-swift-concurrency`'s "exactly two actors" budget, because it is the same seam as
> `FilePersistenceStore` and conforming a `struct` to an `async` protocol would need either a
> `Mutex` (a row `05 R17` explicitly leaves empty here) or shared mutable state. **Record it in
> `DECISIONS.md` in T03**, with this reasoning, or gate 11 is a failure rather than a note.

## Definition of done

- [ ] All nine task files are `status: done`, each with its own commit named `E07/T0n: …`.
- [ ] Gates 1–11 above all pass, run in one sitting on the branch head.
- [ ] `tests.json` carries a new entry for each of: persistence round-trip, v1 fixture load, the five
      reset actions, the Anomaly byte-identity, the shelf quarantine, the 512 KB budget, the
      `RoundPhase` transition totality, and the twin adjacency rule. No existing entry weakened.
- [ ] `DECISIONS.md` carries entries for: the `StoreFile.anomalyHighWater` tenth case, the
      `ProbeSnapshot` spelling (over `08 §1`'s `RoundSnapshot`), `InMemoryPersistenceStore` as a
      third actor, the `anomaly.hw`-before-`anomaly.json` write order, and the 512 KB-versus-band-7
      arithmetic tension.
- [ ] `PROGRESS.md` records the epic with the gate output pasted, not summarised.
- [ ] `/simplify` and `/code-review` have been run on every task and every finding resolved.
- [ ] The PR is squash-merged with every check green, and the branch deleted.
