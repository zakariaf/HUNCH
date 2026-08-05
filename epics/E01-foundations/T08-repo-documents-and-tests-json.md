# T08 — Repo documents and `tests.json`

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01, T07 |
| **Delivers** | `tests.json` (§14.1 VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | `tests.json` is a gate: it owns the rule that **no entry is ever removed** and the workflow step this task appends to the ladder. It also owns the pre-commit hook that `CLAUDE.md` has to document, because `.git/hooks/` is not versioned. |
| `hunch-swift-testing` | It owns the seven brief invariants and where each one lives (`SKILL.md`, "The seven brief invariants"), which is the seed content of `tests.json`, and step 5 of "To write a test": *update `tests.json`; never delete or weaken an entry to reach green.* |

## Objective

The five documents the brief mandates exist and each has one job that no other document does: `CLAUDE.md` tells an agent how to work this repo, `SPEC.md` routes every quantity to its owner, `DECISIONS.md` records what was decided and why, `PROGRESS.md` records what actually passed, and `tests.json` is the structured invariant ledger — with `Scripts/check-tests-json.sh` in CI so "entries are never removed or weakened" is mechanical rather than remembered.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §0.4 | The ownership table — *every quantity has exactly one normative home, and when two sections disagree the owner wins.* `SPEC.md` carries it as a **routing** table. |
| `GAME_DESIGN.md` | §5.7 | The locked constants. `SPEC.md` carries their **names and owners**, not their values — see the ruling below. |
| `GAME_DESIGN.md` | §14.1 | The 162-row feature inventory whose VERIFICATION group seeds `tests.json`. |
| `GAME_DESIGN.md` | §14.5 | The eight open decisions, each with a recommended default. `DECISIONS.md` adopts all eight explicitly. |
| `GAME_DESIGN.md` | §14.6 risk 7 | *"`PROGRESS.md` describing intentions rather than passing output"* is a named early signal of the project not finishing. `PROGRESS.md` records output. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3, §7 | The five documents live at the repo root and are in no target; §3's naming pass and §7's twelve rulings are the first `DECISIONS.md` content. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P14` | The two-package deviation and its three costs, two of which are void here. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Scripts/check-tests-json.sh`:

```bash
#!/bin/bash
# Scripts/check-tests-json.sh — tests.json is well-formed, and it never shrinks.
#
# The brief: "a structured pass/fail list of every invariant; entries are never removed or
# weakened." The second half is the one that needs a machine, because removing a red entry is
# indistinguishable from fixing it in a diff nobody reads closely.
#
# Run from the repo root.
set -uo pipefail

file=tests.json
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

[ -f "$file" ] || { echo "No $file" >&2; exit 1; }
jq -e . "$file" >/dev/null 2>&1 || { echo "$file is not valid JSON" >&2; exit 1; }

# 1. Every entry carries every required field, with a status from the allowed set.
hits=$(jq -r '
  .invariants[]
  | select((.id? and .statement? and .source? and .home? and .command? and .owner? and .status?) | not)
  | .id // "<entry with no id>"' "$file")
[ -n "$hits" ] && report 'Entry missing a required field (id, statement, source, home, command, owner, status):' "$hits"

hits=$(jq -r '.invariants[] | select(.status | IN("pass","fail","pending") | not) | "\(.id): \(.status)"' "$file")
[ -n "$hits" ] && report 'status must be pass, fail or pending:' "$hits"

# 2. Ids are unique — two entries with one id means one of them is invisible.
hits=$(jq -r '[.invariants[].id] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$file")
[ -n "$hits" ] && report 'Duplicate invariant id:' "$hits"

# 3. THE RULE: no id that existed on main may be missing now, and a changed statement is
#    reported so a reviewer sees it. Skipped on a branch with no merge base (the bootstrap).
base=$(git merge-base HEAD origin/main 2>/dev/null)
if [ -n "$base" ] && git cat-file -e "$base:$file" 2>/dev/null; then
  git show "$base:$file" > /tmp/tests-base.json
  hits=$(jq -r -n --slurpfile old /tmp/tests-base.json --slurpfile new "$file" '
    ($old[0].invariants | map(.id)) - ($new[0].invariants | map(.id)) | .[]')
  [ -n "$hits" ] && report 'Invariant REMOVED from tests.json — entries are never removed (the brief):' "$hits"

  changed=$(jq -r -n --slurpfile old /tmp/tests-base.json --slurpfile new "$file" '
    ($old[0].invariants | map({key: .id, value: .statement}) | from_entries) as $o
    | ($new[0].invariants | map({key: .id, value: .statement}) | from_entries) as $n
    | [ $o | keys[] | select($n[.] != null and $n[.] != $o[.]) ] | .[]')
  [ -n "$changed" ] && printf '\nwarning: statement changed for: %s\n(read the diff — weakening an invariant is a decision with a DECISIONS.md entry)\n' \
    "$changed" >&2
fi

[ "$status" -eq 0 ] && echo "tests.json: $(jq '.invariants | length' "$file") invariants, clean"
exit "$status"
```

**Step 2 — run it and watch it fail.** `Scripts/check-tests-json.sh; echo "exit=$?"` → `No tests.json`, exit 1. Then create a `tests.json` with a deliberately broken entry (a missing `command`, a `status` of `"green"`, two entries sharing an id) and confirm each category is named. Then delete an entry that exists on `main` and confirm the removal category fires — this is the only assertion in the repository that protects the brief's "never removed" rule, so prove it once, on purpose.

**Step 3 — implement** the five documents.

**Step 4 — green, then refactor.** The check exits 0, and its step is appended to `ci.yml`'s ladder — after `check-skills.sh`, before the Node checkers.

## Files

| Action | Path |
|---|---|
| create | `CLAUDE.md` |
| create | `SPEC.md` |
| create | `DECISIONS.md` |
| create | `PROGRESS.md` |
| create | `tests.json` |
| create | `Scripts/check-tests-json.sh` (executable) |
| create | `.github/pr-body.md` |
| modify | `.github/workflows/ci.yml` — one step |
| modify | `README.md` — the "documents" section stops saying "arriving in T08" |

## Implementation notes

### `CLAUDE.md` — how to work this repo

Written for the agent that opens this repository in a fresh context and has read nothing. Short, imperative, and it links rather than restates. Seven sections:

1. **What this is, and the order of authority.** `GAME_DESIGN.md` is canon for every game fact and every quantity; `ios-swift-guide/` (365 numbered rules) is the engineering law; `.claude/skills/` is the applied layer and the place where a rule meets this project. When the guide and the design disagree, `08-APPLIED-TO-HUNCH.md` §7 has already ruled — read the ruling, do not re-derive it.
2. **The loop.** One epic = one branch = one PR = one merge. Tasks in order; each task ends `/simplify`, then `/code-review`, then a commit. Wait for `gh pr checks --watch`. Never merge red, never disable a check, never remove a `tests.json` entry. The epic files are `epics/<EID>-*/epic.md`.
3. **The commands**, copy-pasteable: the fast loop, the gate ladder in order, the simulator run, the three plans.
4. **The skills table** — thirteen rows, one line each on when to load it. Reproduce the trigger, not the content. Note the two that are user-invoked or drawing-first: `/hunch-release` carries `disable-model-invocation: true` and can only be reached by the user typing it, and `hunch-design-tokens` loads first whenever a task touches a drawing because the component skills assume its vocabulary.
5. **The never-list**, five lines: no third-party dependency, no network symbol, no build setting outside `Config/`, no literal colour/dimension/duration outside `Tokens/`, no `Date()`/`UUID()`/`.random(`/`SystemRandomNumberGenerator` under `HunchCore/Sources`. Each points at the check number that enforces it.
6. **The pre-commit hook**, in full — `.git/hooks/` is not versioned, so this is the only place its four lines survive a fresh clone, together with the `chmod +x`.
7. **The five documents**, one line each on what goes in and what does not.

### `SPEC.md` — the routing table, and a ruling you must not get wrong

The plan says `SPEC.md` carries §0.4's ownership table and §5.7's locked constants. **Carry the ownership, not the values.** Copying §5.7's numbers into `SPEC.md` would mint a second source of truth for every constant in the game — which is the exact failure §0.4 exists to prevent and the one this whole skill library is built around. So:

- **§0.4's table becomes a three-column routing table**: *quantity → normative section → the Swift symbol that owns it in code → the epic that writes it.* `Par / cap` → §5.4, §5.7 → `Band.par(for:)` / `Band.cap(for:)` → E05·T06. `The reset map` → §11.13 → `StoreFile` + the reset switch → E07·T06. That column is new information and it is the reason to write the file at all.
- **§5.7's locked constants become a name → owner list with no numbers.** `Deck size` → `Deck.all.count` → §5.7. `Admit-rate window` → `Band.admitWindow` → §5.3. A reader who wants the value opens §5.7 or reads the Swift; there is never a third place to check.
- **The one thing `SPEC.md` states in its own right** is the engineering contract the design does not: the two-package boundary predicate (`08 §2`), the naming pass's three collisions (`08 §3`), the concurrency budget (exactly two actors, exactly one `@unchecked Sendable`), and the ten gate checks by number.

Record this interpretation as a `DECISIONS.md` entry, because someone will later "notice" that the constants are missing.

### `DECISIONS.md` — seeded with nine entries

One entry per decision: **what was decided, why, what it costs, and what would reverse it.** Date each one.

| # | Decision | Source |
|---|---|---|
| 1 | **`Band` and `Family` collapse into one type.** §5.3 fixes one family per band with no reprises, so they are in bijection; `Family(band)` would be an identity function that eventually drifts. Both words survive in prose; one type ships. | `08 §3` |
| 2 | **Two packages, not one.** `01 P14` says own exactly one; `HunchCore` + `Modules` is the named deviation, because one package means `swift test` compiles the SwiftUI targets on the host and the ten-second suite dies. Two of `P14`'s three costs are void here; the surviving one is that `package` access does not cross the boundary, so everything `Modules/` exposes to `App/` is `public`. | `08 §7.2` |
| 3 | **§14.5's eight open decisions, all adopted at their recommended defaults**, listed individually: $5.99 with no launch discount; keep the name HUNCH; four `round-{mode}.json` slots with SIEVE excluded; background build of the band index gated so no band ≥ 2 round arms until it completes; fast subset per commit and the full matrix nightly and pre-archive; English written as a copywriter then machine draft plus native review; the throat ring app icon; no ECHO cadence accommodation. Each is reversible and each names what would reverse it. | §14.5 |
| 4 | **The wizard's `HunchUITests` target is renamed `HunchAutomationTests`.** `06 T5b`'s path mirroring makes `Modules/Tests/HunchUITests` the package test target for `HunchUI`, and two test targets with one name make `-only-testing` ambiguous. The wizard's name is not load-bearing; the mirroring rule is. `08 §1`'s tree is updated to match. | `package-manifests.md` §3 |
| 5 | **SplitMix64's gamma is `0x9E37_79B9_7F4A_7C15`.** Canon fixes the finaliser (§11.6) and is silent on the increment; two spellings of `next()` are two different games. The cross-process golden fixture (E06·T10) freezes this one. | E01·T05 |
| 6 | **A package target is declared the day its first file is written**, not on day one. `01 P12` and `08 §7.3`, plus the reproduced fact that an empty target directory is a build warning and a hard error the moment the target appears in `products:`. The eight-target shape is recorded as a comment block in `HunchCore/Package.swift`, with the owning epic per row. | E01·T03 |
| 7 | **Check 8 matches case-insensitively but not diacritic-insensitively.** §1.13 asks for both; `jq`'s `test(…; "i")` gives one. The compensating measure is that `Scripts/banned-lexemes.txt` transcribes §1.13's accented *and* unaccented spellings. Real folding is a change to check 8 with its own entry, never a quiet regex tweak. | E01·T06 |
| 8 | **`SPEC.md` carries ownership, not values** — see above. | E01·T08 |
| 9 | **The licence.** Whatever T01 landed, with the reasoning and what would reverse it. | E01·T01 |

Add the `swift-format dump-configuration` audit date from T01's acceptance criteria as a dated line under entry 2 or its own short note — `swift-format.md` §5 asks for the outcome to be recorded whenever `xcodebuild -version` changes.

### `PROGRESS.md` — output, not intention

§14.6's risk 7 names "`PROGRESS.md` describing intentions rather than passing output" as an early signal that the project does not finish. So the format is fixed and every entry pastes real output:

```markdown
## E01 — Foundations, bootstrap and CI · merged <date> · PR #<n>

**Gate**
```
$ start=$SECONDS; swift test --package-path HunchCore; echo "$(( SECONDS - start ))s"
✔ Test run with 23 tests in 5 suites passed after 0.09 seconds.
1s
$ Scripts/check-source-hygiene.sh
Source hygiene: clean
```

**Proved able to fail** — checks 1, 2, 3, 5, 6, 9, 10 by planted violation; 4 by manifest edit; 7 and 8 by temp-path substitution (real proofs land in E08·T01 and E18·T01).

**Decisions added** — 1–9 in `DECISIONS.md`.

**Known gaps carried forward** — checks 9 and 10 cannot fail until E03 creates `Tokens/`.
```

One section per epic, appended, never rewritten.

### `tests.json` — the ledger

```json
{
  "schema": 1,
  "updated": "2026-07-30",
  "invariants": [
    {
      "id": "E01.fast-loop-budget",
      "statement": "swift test --package-path HunchCore completes in under 10 seconds",
      "source": "GAME_DESIGN.md §5.7; brief",
      "home": ".github/workflows/ci.yml — step 'Fast suite, timed'",
      "command": "swift build --package-path HunchCore --build-tests && start=$SECONDS && swift test --package-path HunchCore && [ $((SECONDS-start)) -lt 10 ]",
      "owner": "E01/T07",
      "status": "pass",
      "lastVerified": "2026-07-30"
    }
  ]
}
```

Seed it with **every** invariant that is already known, whether or not it can pass yet — `status: "pending"` with the owning epic is how a future gate becomes visible today. At minimum:

*E01, `status: "pass"`* — the budget above; the no-network build phase and grep (check 5); the core determinism greps (check 6); `pbxproj` clean; `SWIFT_VERSION = 6.0` resolved; `HunchTestSupport` unreachable from the app (check 4); banned file names (check 1); documented escape hatches (check 3); SplitMix64's reference vectors; the tag vocabulary; `isApproximatelyEqual`'s NaN and infinity behaviour; `Corpora`'s frozen derivation; the three library checkers.

*`status: "pending"`, with `owner` naming the epic* — the seven brief invariants (generator guardrails E06, simulated player E11, difficulty calibration E11, cross-process determinism E06, localisation completeness E18, persistence round-trip E07, no network — already E01); plus the headline gates of each remaining epic: the 256-glyph round-trip and mask brute-force (E02), every §13.2 ratio recomputed (E03), triple-encoding distinctness at `T` (E04), the eight per-band `|H|` counts (E05), G10 node-identity and the 200 k Bench fuzzer (E06), the five-reset map with `anomaly.json` byte-identical (E07), `tickPitch` and `sheetCells` (E08), the §6.8 reveal absolutes (E09), resume-at-the-exact-probe (E10), H1–H21 (E11), D1–D7 (E12), the ECHO primer separation invariant (E13), the SIEVE pitch invariant and Reduce-Motion parity (E14), one-file-per-shelf-open and 512 KB (E15), the same-UTC-date Anomaly (E16), `NavigationDepthTests ≤ 2` (E17), twelve-language completeness and the banned lexemes (E18), §13.12's thirteen gates (E19), the archive gates (E20).

Three rules, and they are the whole point of the file:

- **An entry is never removed.** If an invariant becomes untestable, its status becomes `fail` with a `note`, and the reason is a `DECISIONS.md` entry.
- **An entry is never weakened.** `check-tests-json.sh` warns on a changed `statement` so a reviewer has to look; H10 in particular *is allowed to fail honestly*, in which case §5.1's modifier weights are regenerated from the harness and the test is not touched (E11·T12).
- **`command` must be runnable as written**, from the repo root. An invariant nobody can re-run from the file is a claim, not a ledger.

### `.github/pr-body.md`

Write it now so E01's own PR has one: the gate table with each command's pasted output, the `DECISIONS.md` entries added, and the known gaps carried forward. Each epic overwrites it in its last commit.

### The CI step

Append to `ci.yml`'s ladder, after `check-skills.sh` (it is a `jq` parse — cheap, and it needs `git` history, so it belongs on the macOS job where the checkout is unshallowed):

```yaml
      - run: git fetch --no-tags --depth=50 origin main    # merge-base for the no-shrink check
      - run: Scripts/check-tests-json.sh
```

`actions/checkout@v4` fetches depth 1 by default, and a merge base needs history — without the fetch the removal check silently skips, which is precisely the shape of failure this whole file is against.

## Acceptance criteria

- [ ] `Scripts/check-tests-json.sh` exits 0 and prints the invariant count; deleting any entry and re-running names it under `Invariant REMOVED`.
- [ ] `jq -e '.invariants | length >= 30' tests.json` is true, and every entry has all seven required fields.
- [ ] Every `command` in `tests.json` whose `status` is `"pass"` has been **run** from the repo root during this task, and its output pasted into `PROGRESS.md`.
- [ ] `jq -r '.invariants[] | select(.status=="pending") | .owner' tests.json | sort -u` lists an epic id for every pending entry — no orphans.
- [ ] `grep -c '§' SPEC.md` is high and `grep -nE '\b(256|27,015|0\.15|0\.60|1000|1\.6)\b' SPEC.md` returns **nothing** — the file routes to values, it does not hold them.
- [ ] `DECISIONS.md` has nine dated entries, each stating the decision, the reason, the cost and what would reverse it.
- [ ] `PROGRESS.md`'s E01 section contains pasted command output, not prose describing it.
- [ ] `CLAUDE.md` contains the pre-commit hook verbatim and the thirteen-row skill table.
- [ ] `grep -riE 'brain|cognitive|train your|workout|!' CLAUDE.md SPEC.md README.md` returns nothing (§1.13 binds every document).
- [ ] The new CI step runs and passes on E01's PR.

## Close the task

1. `swift test --package-path HunchCore` green; the whole gate ladder green including the new step.
2. **Run `/simplify`** — its useful scope here is the shell script and any duplication between `README.md` and `CLAUDE.md` (they overlap on the build commands; the README is for a human deciding whether they can build, `CLAUDE.md` is for an agent about to work — keep both, and keep them short).
3. **Run `/code-review`** — the finding that matters is a `tests.json` `command` that does not actually run, and a `SPEC.md` line that restates a value.
4. Commit: `git commit -m "E01/T08: CLAUDE.md, SPEC.md, DECISIONS.md, PROGRESS.md, tests.json and its no-shrink check"`
5. This is the epic's last task: write `.github/pr-body.md`, push, open the PR, `gh pr checks --watch`, and merge only when green.

## Out of scope

- **Every later `tests.json` entry's transition from `pending` to `pass`** — the epic that earns it, in the same PR.
- **Every later `DECISIONS.md` entry** — including the earned `@Observable` exception for `Round` (E08·T01), the `T` constant for triple-encoding (E04·T06), and the third actor or second escape hatch if either is ever admitted (they are not, today).
- **`PROGRESS.md`'s phase-3, phase-5 and phase-8 subagent diff reviews** — E10·T10, E14, E20·T12.
- **The design documents** — `GAME_DESIGN.md` and `design/` already exist and are canon; this task cites them and changes neither.
- **`.github/pr-body.md` for any epic but this one** — each epic writes its own.
