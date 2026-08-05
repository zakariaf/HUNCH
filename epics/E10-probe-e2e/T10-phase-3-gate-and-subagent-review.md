# T10 — Phase-3 gate and subagent diff review

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T09 |
| **Delivers** | `tests.json` (VERIFICATION) — as a phase-gated, complete document rather than a growing list |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns `tests.json`'s obligation — a structured pass/fail list of every invariant, never weakened, never trimmed — and the ten-second budget measurement this gate re-checks. It also owns the ruling on which suites are host-runnable and which need the simulator, which is what makes the gate's command list correct. |
| `hunch-build-and-ci` | Owns the workflow, the three test plans and the hygiene script. The gate runs exactly the commands CI runs, because a gate that only exists in a task file is not a gate. |

## Objective

At the end of this task §14.3's phase 3 is closed with evidence rather than assertion: a transcript of a
real round played, quit, relaunched and resumed at the exact probe with the draft intact, sitting in
`PROGRESS.md`; a complete `tests.json`; and a fresh-context subagent diff review against `SPEC.md` whose
findings are each fixed on this branch or recorded in `DECISIONS.md` with a reason.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §14.3 phase 3 | the gate verbatim: *a real round is playable in the simulator, quit, relaunched and resumed at the exact probe; G10 round-trip + 200 k Bench fuzzer green; subagent diff review against `SPEC.md`* |
| `GAME_DESIGN.md` | §14.6 risk 7 | the stated early signal — *phase 3 not gated by the end of the third context window*, and `PROGRESS.md` describing intentions rather than passing output |
| `GAME_DESIGN.md` | §14.6 risk 2 | the phase-3 human gate: five testers who have never seen the game must each state `shape ∈ {triangle}` unaided in the opening round, **recorded**, before phase 3 is called done |
| `GAME_DESIGN.md` | §14.1 (VERIFICATION) | `tests.json` — a structured pass/fail list of every invariant; entries are never removed or weakened |
| `GAME_DESIGN.md` | §11.13 | the on-disk tree the transcript inspects |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B24, B34a | the three test plans and the hygiene script the gate invokes |
| `ios-swift-guide/06-TESTING.md` | T3, T58 | the fast suite runs with no simulator; a gated test is never deleted |

## TDD — the test comes first

This task ships no new production code, so its "test" is the **gate script**: written first, run, and
watched to fail on the parts of the gate that are not yet true.

**Step 1 — write the failing gate.** Create `Scripts/phase-gate.sh`:

```bash
#!/usr/bin/env bash
# Phase gate. Runs exactly what CI runs, in the order a reviewer would.
# Usage: Scripts/phase-gate.sh 3
set -euo pipefail
PHASE="${1:?usage: phase-gate.sh <phase>}"
cd "$(dirname "$0")/.."

echo "== 1. fast suite, with its budget"
START=$SECONDS
swift test --package-path HunchCore
ELAPSED=$((SECONDS - START))
echo "   fast suite: ${ELAPSED}s"
[ "$ELAPSED" -lt 10 ] || { echo "FAIL: fast suite over its 10 s budget"; exit 1; }

echo "== 2. app-side suites"
swift test --package-path Modules

echo "== 3. simulator test plan"
xcodebuild test -project Hunch.xcodeproj -scheme Hunch \
  -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  | tee /tmp/hunch-presubmission.log

echo "== 4. source hygiene, all twelve checks"
Scripts/check-source-hygiene.sh

echo "== 5. tests.json is complete and nothing is weakened"
Scripts/check-tests-json.sh "$PHASE"

echo "== phase $PHASE gate: mechanical checks green"
echo "   remaining, and NOT automatable: the resume transcript (§14.3) and the"
echo "   five-tester opening-round record (§14.6 risk 2). Both live in PROGRESS.md."
```

and `Scripts/check-tests-json.sh`, which is the part with teeth:

```bash
#!/usr/bin/env bash
# Fails if tests.json has an entry with no status, an entry that regressed to "skipped",
# or fewer entries than the previous commit — §14.1: entries are never removed or weakened.
set -euo pipefail
PHASE="${1:-0}"
CURRENT=$(jq '[.invariants[]] | length' tests.json)
PREVIOUS=$(git show HEAD:tests.json 2>/dev/null | jq '[.invariants[]] | length' || echo 0)
[ "$CURRENT" -ge "$PREVIOUS" ] || { echo "FAIL: tests.json lost $((PREVIOUS-CURRENT)) entries"; exit 1; }
jq -e '[.invariants[] | select(.status == null)] | length == 0' tests.json > /dev/null \
  || { echo "FAIL: an invariant has no status"; exit 1; }
jq -e --arg p "$PHASE" \
  '[.invariants[] | select(.phase <= ($p|tonumber)) | select(.status != "pass" and .status != "owned")] | length == 0' \
  tests.json > /dev/null || { echo "FAIL: a phase-$PHASE invariant is not passing"; exit 1; }
echo "tests.json: $CURRENT invariants, none unstatused, none regressed"
```

**Step 2 — run it and watch it fail.** `Scripts/phase-gate.sh 3`

It must fail at step 5 first (no `tests.json` completeness), which is the correct failure: the gate is
measuring a document that has not been finished yet. If it fails at step 1 or 3, that is an E10 defect
and it is fixed before this task continues.

**Step 3 — do the work**: run the simulator transcript, complete `tests.json`, run the review.

**Step 4 — re-run the gate** until every mechanical step is green, then record the two human items.

## Files

| Action | Path |
|---|---|
| create | `Scripts/phase-gate.sh` |
| create | `Scripts/check-tests-json.sh` |
| modify | `tests.json` — completed for phases 1–3 |
| modify | `PROGRESS.md` — the transcript, the delegation table from T09, the review findings, the tester record |
| modify | `DECISIONS.md` — any review finding deliberately not fixed, with its reason |
| modify | `.github/workflows/*.yml` — call `Scripts/phase-gate.sh` steps 1, 2, 4, 5 (step 3 already runs) |

## Implementation notes

### The resume transcript — the exact sequence

This is the gate sentence, so it is executed and pasted, not summarised.

```bash
# 0. identity
BUNDLE=$(xcodebuild -project Hunch.xcodeproj -scheme Hunch -showBuildSettings \
         | awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')
DEVICE="iPhone SE (3rd generation)"

# 1. a genuinely fresh install — the opening round only exists once
xcrun simctl boot "$DEVICE" || true
xcrun simctl uninstall booted "$BUNDLE" || true
xcodebuild -project Hunch.xcodeproj -scheme Hunch \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath .build/dd build
xcrun simctl install booted .build/dd/Build/Products/Debug-iphonesimulator/Hunch.app
xcrun simctl launch booted "$BUNDLE"

# 2. play by hand: the 13 beats, then STOP mid-round at a known probe count with a
#    half-built draft on the Bench. Record the probe count and the draft you left.

# 3. quit the way a player does
xcrun simctl terminate booted "$BUNDLE"

# 4. read the disk BEFORE relaunching — this is the evidence
CONTAINER=$(xcrun simctl get_app_container booted "$BUNDLE" data)
jq '{probes, strikes, benchDraft, lawHash, seedGlyph}' \
  "$CONTAINER/Library/Application Support/Hunch/round-probe.json"

# 5. relaunch and observe: the app opens INTO the round, no dialog, 900 ms beat,
#    the same probe count, the same draft when the Bench is pulled up.
xcrun simctl launch booted "$BUNDLE"

# 6. and the ledger, after finishing the opening round
jq '.onboarding' "$CONTAINER/Library/Application Support/Hunch/ladder.json"
```

`PROGRESS.md` gets the real output of steps 4 and 6, the probe count played, the draft left, and one
sentence per observation at step 5. Paste output; do not describe it (§14.6 risk 7's stated failure mode
is a `PROGRESS.md` that describes intentions).

Four observations that must each be explicitly recorded as seen:

1. The app opened **into the round**, not the Frame, with **no dialog and no Resume button**.
2. The ribbon held exactly the probes played, in order, with the same verdicts.
3. The Bench draft was intact when pulled up, and the Bench was **collapsed** on entry (§6.11 #28).
4. If the round was past par, the par row was **already inverted on the first frame** and the cap row
   already partly emptied (§6.10, T03).

### `tests.json`

One entry per invariant, with the fields the later phases will keep using:

```json
{
  "schema": 1,
  "invariants": [
    {
      "id": "probe.snapshot.cadence",
      "phase": 3,
      "spec": "GAME_DESIGN.md §6.10",
      "test": "SnapshotCadenceTests.writesAfterEveryCommittedVerdict",
      "suite": "Modules/LoomFeatureTests",
      "status": "pass"
    },
    {
      "id": "probe.edge.19.reduceMotion",
      "phase": 7,
      "spec": "GAME_DESIGN.md §6.11 #19",
      "owner": "E09·T12",
      "status": "owned"
    }
  ]
}
```

Statuses: `pass`, `fail`, `blocked` (with `owner`), `owned` (a later phase's row, listed so it cannot be
forgotten). **Never** `skipped`, and never a removal — `check-tests-json.sh` fails the build on a
shrinking file, which is the mechanical form of §14.1's rule.

Phase-3 completeness means every invariant this epic and E07–E09 shipped has a row, plus all 29 of
§6.11's rows from T09, plus the phase-1 and phase-2 rows E01–E06 already wrote.

### The subagent diff review

Run it in a **fresh context** — the point is a reader who has not been persuaded by the last ten commits.

Prompt, verbatim:

> You are reviewing a diff against a specification. Read `SPEC.md` and `GAME_DESIGN.md` §§4, 6, 11.13,
> 12.4, 12.5, 12.7 first. Then read the diff of `main...epic/E10-probe-e2e`.
>
> Report **only** gaps that affect correctness or a stated requirement: behaviour that contradicts the
> spec, a stated number that is wrong or duplicated into a second source of truth, a rule the spec states
> that the code does not implement, or a test that asserts something weaker than the rule it names.
>
> Do **not** report style, naming taste, formatting, or suggestions for future work. For each finding
> give: the spec section, the file and line, what the spec requires, what the code does, and the smallest
> change that would close the gap.
>
> If you find nothing, say so plainly and name the three sections you checked hardest.

Every finding is then either fixed on this branch, or written into `DECISIONS.md` with a reason and a
`tests.json` row. A finding that is neither is an unresolved review comment, and the epic's git workflow
forbids merging over one.

### The human gate §14.6 risk 2 asks for

*Five testers who have never seen the game must each state `shape ∈ {triangle}` unaided in the opening
round, recorded.* Record in `PROGRESS.md`, per tester: whether they cleared the Seal bar unaided, the
probe count they declared at, which nudges fired, and the `OnboardingLedger` dump. If five testers are
not available, that is a **deviation** and it goes in `DECISIONS.md` naming what was done instead
(for example: three testers, or a recorded screen capture reviewed asynchronously) — never silently
dropped, because §14.6 names this as the mitigation for the design's second-largest risk and the
elastic cap and the five nudges are both calibrated against it.

### What phase 3's gate does **not** include

`G10 round-trip + 200 k Bench fuzzer green` is in §14.3's phase-3 row but was delivered and gated in
**E06·T04**. Re-run it here as part of the fast suite (it is already in `Presubmission`) and cite E06's
`tests.json` rows rather than re-asserting them.

## Acceptance criteria

- [ ] `Scripts/phase-gate.sh 3` exits 0.
- [ ] `PROGRESS.md` contains the played → quit → relaunched → resumed transcript with the real `round-probe.json` and `ladder.json` output pasted, and the four observations explicitly recorded.
- [ ] `PROGRESS.md` contains T09's 29-row delegation table and the tester record (or the recorded deviation).
- [ ] `tests.json` validates: every entry has a status, no phase ≤ 3 entry is `fail` or `blocked`, and the entry count is ≥ the previous commit's.
- [ ] The subagent review transcript is in `PROGRESS.md`, and every finding is either fixed in this branch's diff or has a `DECISIONS.md` entry.
- [ ] The workflow calls `Scripts/phase-gate.sh` steps so the gate runs on every later PR, not only this one.
- [ ] `swift test --package-path HunchCore` still under 10 s with the phase-3 suite complete.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T10: phase-3 gate, resume transcript, complete tests.json and the SPEC review"`

Then push, open the PR, `gh pr checks --watch`, and merge only on green. **E11 does not start until this
PR is merged.**

## Out of scope

- Phase 5's and phase 8's subagent reviews — **E14·T10** and **E20·T12**.
- The nightly Level-B matrix — **E11·T11/T12**; phase 3 does not gate on it.
- The accessibility audit and §13.12's thirteen gates — **E19·T11**.
- Archive-time gates (zero warnings, 15 MB, airplane mode, face-down haptics) — **E20·T12**.
- Rewriting `SPEC.md` — it is E01·T08's; this task reads it and reports against it.
