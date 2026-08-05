# E05 — Grammar, evaluator and equivalence

| | |
|---|---|
| **id** | E05 |
| **title** | Grammar, evaluator and equivalence |
| **branch** | `epic/E05-grammar` |
| **depends on** | E02 (Glyph vocabulary and the bitboard algebra) |
| **gate** | The evaluator agrees with a brute-force AST walk over all 65,536 ordered pairs on a seeded corpus · RNF is idempotent and gives one law exactly one layout · the six stateless per-band counts and the two contextual runs match §5.2 exactly (40 / 1,272 / 108 / 2,322 / 5,688 / 337 and 6,934 / 10,314, total 27,015) · `lowerBandIndex.bin` round-trips and its build is measured against open decision 4's 3 s A15 budget |
| **tasks** | 8 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH has a **law**: an `indirect enum LawNode` that spells the BNF of §3.2 and can hold nothing the grammar forbids; a `LawTable` that is the design's "extension" as a real Swift type; a `Law` that resolves node → table → cached metrics once so `admitRate`, `marginalDeficit`, `leafCount`, `freeAttributeCount` and `scatteredSubsetCount` are O(1) behind a dot; a mask-driven evaluator that never walks the AST per glyph; RNF, which gives one law exactly one tile layout; extension identity with lifting as the only comparison the codebase ever makes; the collapsed `Band` type; and the band-partitioned lower-band index with its 9,767 stateless tables and 17,248 contextual hashes behind an eight-run header. The eight `|H|` counts stop being numbers in a document and become eight assertions in `swift test`.

## Why now

E02 gave us the deck and the word-level algebra; nothing above it can be built without a law. **E06 (difficulty, the Bench model, the generator) is blocked on every single task here** — `difficulty(of:)` reads `Law`'s cached metrics, G4 reads the lower-band index, G5/G6 are T05's substitution and pivotality machinery, G7 is T02's lift identity, G10 compares against T04's RNF, and the generator samples T07's skeleton lists. E07's `ProbeSnapshot` stores the resolved `LawNode` from T01. E09's declaration verdict is T05's extension identity. E15's `CodexPage` is keyed on T05's `LawKey`. This epic is the widest fan-out in the plan and it must be exactly right, because eight epics downstream inherit whatever it decides.

It sits after E02 and beside E03/E04 because it touches no pixel: everything here is a pure function of values you can write down, so all of it runs in `swift test --package-path HunchCore` with no simulator.

## Scope

| In | Out — and who owns it |
|---|---|
| `LawNode`, the AST and its structural caps | `BenchLayout`, `RuleTile`, `SealBar` and the G10 round-trip — **E06 T03/T04** |
| `LawTable`, `Law`, the cached `Metrics` | `difficulty(of:)` itself and the Rasch coupling — **E06 T01/T02** |
| `Law.admits(_:after:)` and the §3.5 sequencing contract | `Probe`, `Ribbon`, twin semantics, the verdict beat — **E07 T08**, **E08 T06** |
| RNF: fold, sort, merge, constant detection | The Bench's *rendering* of RNF into tiles — **E06 T03**, **E09 T02** |
| Extension identity, `LawKey`, ⊤/⊥ dead terms, attribute pivotality | Guardrails G1–G10 as named, ordered predicates — **E06 T05** |
| `Band`: `par`, `cap`, `population`, `difficultyRange` | Serving policy, `targetDelta`, the ladder — **E11** |
| The lower-band index: enumeration, binary format, `LawIndexLoader` | Writing the file to `Application Support` and setting `isExcludedFromBackupKey` — **E07 T02** (this epic owns the *contract* and the `tests.json` entry, not the `FileManager` call) |
| Eight per-band `\|H\|` assertions | The 10,000-law generator suite — **E06 T09** |
| — | Counterexample selection — **E06 T08** |
| — | Anything drawn. This epic adds no view, no token, no `Canvas`. |

## The task list

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [LawNode — the AST](T01-law-node-ast.md) | P0 | M | — | `indirect enum` over the BNF's five productions plus the coupler; `Codable`; `MAX_DEPTH 2` / `MAX_LEAVES 4`; no `NOT`; the four structural caps as a `StructuralFault?` |
| T02 | [LawTable and Law](T02-law-table-and-law.md) | P0 | M | T01 | `LawTable` as the design's "extension"; `Law` = node + table + `Metrics` resolved once in `init`, deliberately not `Codable` |
| T03 | [The evaluator](T03-the-evaluator.md) | P0 | M | T02 | `Law.admits(_:after:)` as a table lookup; §3.5's `prev` and seed-glyph contract; agreement with a brute-force walk over all 65,536 ordered pairs |
| T04 | [RNF canonicaliser](T04-rnf-canonicaliser.md) | P0 | L | T02 | Complement-fold, commutative sort, `cur`-leading contextual, same-attribute set-algebra merge, constant detection; idempotence and one-law-one-layout |
| T05 | [Equivalence, dead terms and liveness](T05-equivalence-dead-terms-liveness.md) | P0 | M | T04 | Extension identity in the common space; `LawKey` with full compare on collision; ⊤ **and** ⊥ per leaf; pivotality by value permutation |
| T06 | [Band — the collapsed Band/Family type](T06-band-table.md) | P0 | S | T01 | One `enum Band` for band and family; `par`, `cap`, `population`, `difficultyRange`, `minLeaves`; the collapse recorded in `DECISIONS.md` |
| T07 | [The lower-band index](T07-lower-band-index.md) | P0 | L | T05, T06 | Six stateless runs (9,767 tables, 305 KB) + two contextual hash runs (17,248, 138 KB) behind an offset header; `actor LawIndexLoader` caching the `Task`; the 3 s A15 measurement |
| T08 | [Per-band \|H\| enumeration test](T08-per-band-h-enumeration.md) | P0 | M | T07 | Eight separate assertions in ascending band order, summing to 27,015 |

Execute strictly in that order. T02 cannot compile before T01, T07 needs both T05 and T06, and T08's ascending-band requirement is not an ordering preference — it is what makes G4's exclusion set well-founded (§5.2).

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E05-grammar

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E05-grammar
gh pr create --title "E05 — Grammar, evaluator and equivalence" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E06 until this PR is merged.** If a check fails, fix it on the same branch and push again. Never merge red, and never disable, weaken or delete a check to reach green — `tests.json` entries are append-only (brief; `hunch-swift-testing` "Never").

## The gate

Every one of these must be true before the PR may merge. Each row names the command that proves it.

| # | What must be true | Proof |
|---|---|---|
| 1 | The evaluator agrees with a brute-force AST walk over **all 65,536 ordered pairs** for every law in the seeded corpus, and reproduces §5.5's 15 machine-verified verdicts and §5.6's six | `swift test --package-path HunchCore --filter EvaluatorTests` |
| 2 | RNF is idempotent (`rnf(rnf(x)) == rnf(x)`) and one law gets exactly one layout (extension-equal laws in the corpus are node-equal after RNF) | `swift test --package-path HunchCore --filter RenderedNormalFormTests` |
| 3 | The six stateless per-band counts are **40 / 1,272 / 108 / 2,322 / 5,688 / 337** as six separate assertions, and the two contextual runs are **6,934 / 10,314** as two more — eight assertions, never one on a blob | `swift test --package-path HunchCore --filter BandPopulationTests` |
| 4 | The eight sum to **27,015** and the stateless six sum to **9,767** | same suite, its final assertion |
| 5 | `lowerBandIndex.bin` round-trips: `decode(encode(index)) == index`, and the payload is exactly `9_767 * 32 + 17_248 * 8` bytes behind its offset header | `swift test --package-path HunchCore --filter LawIndexTests` |
| 6 | The index build is **measured** and the number is written into `DECISIONS.md` against §14.5 open decision 4's 3 s A15 budget, with the chosen strategy (background build vs bundled resource) stated | `grep -n 'lowerBandIndex' DECISIONS.md` |
| 7 | Exactly two actors exist in the repo and `LawIndexLoader` is the second | `grep -rn --include='*.swift' -E '^[[:space:]]*(public \|package )?actor ' HunchCore Modules` returns exactly `FilePersistenceStore`-shaped rows plus `LawIndexLoader`; at E05 the first does not exist yet, so exactly one row |
| 8 | The fast suite is still green **and under 10 s** | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 9 | Source hygiene passes — nothing in this epic writes `Date()`, `UUID()`, `.random(`, `SystemRandomNumberGenerator`, `import SwiftUI`, or a `final class` under `HunchCore/Sources/` | `Scripts/check-source-hygiene.sh` |
| 10 | `tests.json` carries an entry for each of rows 1–6 | `git diff main -- tests.json` |

## Definition of done

- All eight task files are `Status: done`, each committed separately with the message form `E05/T0n: …`.
- `swift test --package-path HunchCore` is green in under 10 s and the ten gate rows above all pass.
- `SPEC.md` carries the locked constants this epic pins: the eight `|H|` values, the total 27,015, the six/two run partition, and the leaf-counting rule (atom / relational / contextual = 1 leaf, guard = 3, aggregate = `|attrSet|`), each cited to its GDD section.
- `DECISIONS.md` carries: the `Band`/`Family` collapse (T06); the RNF sort-key spelling for the fourth field (T04); the `LawIndex` run-index-not-`Band` addressing that keeps the `Laws → LawGeneration` arrow pointing one way (T07); `LawIndexLoader`'s target placement (T07); the measured index build time and the open-decision-4 ruling (T07); the resolving clause for the contextual form space (T08).
- `PROGRESS.md` records the measured index build time and the measured fast-suite duration.
- The PR is merged and `epic/E05-grammar` is deleted.
