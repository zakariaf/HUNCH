# E06 — Difficulty, the Bench model and the generator

| | |
|---|---|
| **id** | E06 |
| **title** | Difficulty, the Bench model and the generator |
| **branch** | `epic/E06-generator` |
| **depends on** | E05 (grammar, evaluator, RNF, equivalence, `Band`, the lower-band index) |
| **gate** | The 10,000-law × 8-band suite passes every guardrail in ≈1.2 s · determinism is byte-identical against the committed `determinism-seeds-v1.json` golden written by a different process · G10 is node-identical for all 80,000 generated laws and the 200,000-configuration Bench fuzzer parses-or-bars every one · the whole fast suite is still under 10 s |
| **tasks** | 10 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH can **make a law on demand**. `difficulty(of:)` scores any law on the
0…1 scale §5.1 defines; the eight-row band table carries every column §5.2 publishes plus the Rasch
coupling that E11 will serve against; `BenchLayout` exists as a core `Codable` value with both
directions of its conversion to `LawNode`, which is what makes G10 a *generation-time* guardrail
rather than a simulator test; the ten guardrails are ten separately testable predicates; and
`generate(seed:band:targetDelta:mode:avoid:)` is a pure, synchronous, `nonisolated` function that
returns a law satisfying all ten or the family's deterministic anchor. Par, cap, scoring, marks and
counterexample selection land alongside, because they are the other pure halves of a round. Two
suites make the whole thing verifiable: 80,000 generated laws checked against every guardrail, and a
committed cross-process determinism golden.

## Why now

E05 gave the AST, the evaluator, RNF, extension identity and the band-partitioned index. Nothing yet
*produces* a law, so nothing downstream can start: E07's mid-round snapshot stores a resolved
`LawNode` and needs one to store; E08 and E09 cannot play a round without a hidden law; E11's Rasch
estimator has nothing to serve; E12's DRIFT pair generation is this generator run twice under extra
pair guardrails; E16's Anomaly is `generate(… avoid: [])` with a derived seed. This epic is the
last purely-core epic before the play surface, and the Bench model is deliberately inside it —
`08 §2` rules `BenchLayout` core precisely so that the dependency arrow does not invert when G10 is
enforced at generation time.

## Scope

| In | Out — and who owns it |
|---|---|
| `difficulty(of:)` and its five modifiers, with a per-modifier breakdown | The Rasch **estimator** (`θ += K(n)·(x − P)`) and the 13-step serving policy — **E11** |
| The band table's remaining columns: exemplar, `k`, `d`, achievable difficulty range, centre; the Rasch coupling functions | `enum Band` itself, `par(for:)`, `cap(for:)`, `population`, `difficultyRange` — **E05·T06** |
| `BenchLayout`, `RuleTile`, `SealBar` and both conversions, as core `Codable` values | `RampView` / `BridgeView` / `ForkView` / `TallyView` / `CouplerView` / `SealView` and every pixel of the Bench — **E09·T01–T07** |
| G10 node-identity and the 200,000-configuration Bench fuzzer | The palette ceiling and palette sufficiency — **E09·T04**, **E11·T05** |
| G1–G10 as ten predicates plus a cheap→expensive evaluation order | The `avoid` set's *assembly* (novelty ring, per-band soft-avoid, today's Anomaly) — **E11·T06** |
| `generate(…)`, skeleton sampling, the 200-attempt bound and the family anchor | Seed **choice** and retry-with-a-fresh-seed — **E11·T06**; DRIFT's two-law generation — **E12·T01** |
| Par/cap constants re-derived from §5.4, `Score` (points + marks) | `Outcome` gating ("only `inscribed` scores"), `Probe`, `Ribbon` — **E07·T07–T08**; the par tick row and the par crossing — **E08·T08** |
| Counterexample **selection** — the deterministic four steps | The two-ring presentation, the 640 ms hold and the 960 ms beat — **E09·T09**; DRIFT's dead-law step 0 — **E12·T06** |
| The 10,000-law × 8-band suite and the fallback-rate statistic | H1–H21 and the simulated-player harnesses — **E11·T10–T12** |
| In-process and cross-process determinism, plus the golden-producing tool | `SeedSource`, the single point of nondeterminism, which lives in `Modules/` — **E10·T01** |

## The task list

Execution order is top to bottom. Every task ends with `/simplify`, `/code-review` and one commit.

| # | Task | P | Size | Deps | One line |
|---|---|---|---|---|---|
| T01 | [difficulty(of:)](T01-difficulty-of.md) | P0 | M | — | Family base × 0.125 plus five bounded modifiers summing to exactly 0.124, asserted against §5.2's eight exemplar δ values |
| T02 | [The band table and the Rasch coupling](T02-band-table-and-rasch-coupling.md) | P0 | M | T01 | The remaining band-table columns, the achievable difficulty range, and `δ_logit = 8·difficulty − 4` |
| T03 | [`BenchLayout`, `RuleTile` and `SealBar`](T03-bench-layout-rule-tile-and-seal-bar.md) | P0 | L | T01 | The Bench as core `Codable` data, both conversion directions, and the bar that knows which rail pulses |
| T04 | [G10 round-trip and the Bench fuzzer](T04-g10-round-trip-and-bench-fuzzer.md) | P0 | M | T03 | Node-identity for §4.4's whole parity table, and 200,000 random configurations that parse or bar |
| T05 | [Guardrails G1–G10](T05-guardrails-g1-g10.md) | P0 | L | T04, T02 | Ten predicates, one evaluation order, G4 scoped to strictly lower bands |
| T06 | [The generator](T06-the-generator.md) | P0 | L | T05 | Pure, synchronous, `nonisolated`; inverse-cardinality skeletons; 200 attempts then the anchor |
| T07 | [Par, cap, scoring and marks](T07-par-cap-scoring-and-marks.md) | P0 | M | T02 | Par re-derived from `k·log₂|H| + d`, cap from `ceil(1.6·par)`, multiply-then-round-once |
| T08 | [Counterexample selection](T08-counterexample-selection.md) | P0 | M | T05 | The deterministic four steps, returning an ordered pair in contextual bands |
| T09 | [The 10,000-law suite](T09-ten-thousand-law-suite.md) | P0 | M | T06 | Parameterised over eight bands, ten thousand looped inside, every failure naming its seed |
| T10 | [Determinism, in-process and cross-process](T10-determinism-in-and-cross-process.md) | P0 | M | T06 | A 512-tuple golden written by a separate `swift run` tool, plus the macOS exit test |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E06-generator

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E06-generator
gh pr create --title "E06 — Difficulty, the Bench model and the generator" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E07 until this PR is merged.** If a check fails, fix it on the same branch and push
again. Never merge red, and never disable, weaken or delete a check to get green — `tests.json`
entries are added here, never removed.

## The gate

Every one of these must be true before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The 10,000-law × 8-band suite passes every guardrail, in ≈1.2 s | `swift test --package-path HunchCore --filter GeneratorTests` and the printed duration |
| 2 | G10 is node-identical for all 80,000 generated laws | the same run — G10 is one of the guardrails the suite checks per law |
| 3 | §4.4's parity table round-trips production by production | `swift test --package-path HunchCore --filter BenchRoundTripTests` |
| 4 | The 200,000-configuration Bench fuzzer parses-or-bars every one | `swift test --package-path HunchCore --filter BenchFuzzerTests` |
| 5 | Determinism is byte-identical against a golden written by a different process | `swift test --package-path HunchCore --filter DeterminismTests`, with `git log -1 --format=%cd -- HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json` showing an earlier commit than the test file |
| 6 | The generator fallback rate is under 2 % in every band | the fallback statistic asserted inside the 10,000-law suite |
| 7 | The whole fast suite is still under 10 s | the timed command below |

```bash
cd /Users/zakariafatahi/50-apps-challenge/E03/HunchCore
START=$SECONDS
swift test
STATUS=$?
ELAPSED=$((SECONDS - START))
echo "fast suite: ${ELAPSED}s"
[ $STATUS -eq 0 ] && [ $ELAPSED -lt 10 ]
```

If the Bench fuzzer alone measures over ~1 s, move it to `.tags(.integration, .nightly)` and keep a
20,000-configuration `.presubmission` smoke — that is the sanctioned trade in `hunch-swift-testing`,
and the full 200,000 then runs in `Nightly.xctestplan`, which the gate must still show green.

## Definition of done

- [ ] All ten task files are checked off and each has its own commit.
- [ ] `swift test --package-path HunchCore` is green and under 10 s.
- [ ] `Scripts/check-source-hygiene.sh` passes — in particular no `.random(`,
      `SystemRandomNumberGenerator`, `Date()` or `UUID()` reached `HunchCore/Sources/`.
- [ ] `tests.json` has an entry for the 10,000-law suite, the G10 round-trip, the Bench fuzzer, the
      determinism golden and the fallback-rate statistic, each with its current status.
- [ ] `DECISIONS.md` records the six rulings this epic makes: the `LawIndex`-as-explicit-argument
      resolution, the Bench's second admitted over-reach (two relational terms), the evaluation
      order of the ten guardrails, `Band.achievableDifficultyRange` and its consequence for E11's
      clamp, the hand-rolled unbiased `Sampling.uniform(below:using:)`, and the choice of §5.2's
      exemplar as each family's deterministic anchor.
- [ ] `SPEC.md`'s locked-constant table still agrees with the code: par, cap, `|H|`, the admit-rate
      window, the 200-attempt bound and the 0.02 proximity tolerance are each read from one place.
- [ ] `PROGRESS.md` records the measured fast-suite duration and the measured per-band fallback rate.
