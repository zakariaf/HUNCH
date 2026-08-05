# T12 — The archive gates

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T11 |
| **Delivers** | §14.3 phase 8's gate, closed · hand-off to `/hunch-release` |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-release` | `SKILL.md`'s section A is nine read-only gates that are *safe to run at any time*, and the sentence that governs this whole task: **stop before section B.** `references/release-checklist.md` §2 carries each gate's exact command, its pass condition and — the column that matters — what a failure actually means, plus §7's table of the tempting wrong fix for every one. It also owns "the gate that passes when it did not run": `.enabled(if:)` skips report as successes, so a plain `swift test` is green over a matrix that never executed. `references/rejection-triggers.md` §10 owns the build number this task must not burn. |
| `hunch-build-and-ci` | A6's zero-warning gate is its ruling: `-warnings-as-errors` is on Release and the blanket flag is written **first**, any `-Wwarning` exemption **after** it — `08 §7.12` says the opposite and is wrong, and the build skill carries the reproduced ordering. It also owns the gate roster A5 must be ticked against (*"a run that reports fewer checks than that table lists is itself the failure"*), the ban on `continue-on-error`, and the rule that no check is ever weakened to reach green. |
| `hunch-swift-testing` | `references/budget.md` owns the ten-second timer and the rule that an over-budget suite is gated to nightly and never deleted (`06 T58`); `references/test-plan.md` §5 owns the Level-B split and the `HUNCH_CALIBRATION=1` gate; and the skill owns step 5 of writing a test — *update `tests.json`; never delete or weaken an entry to reach green* — which is the sentence this task turns into a script. |

## Objective

At the end of this task every gate in §14.3's phase 8 and every row of this epic's gate table is green
and has a record: the Release build produces zero warnings under `-warnings-as-errors`, the size is
measured twice (a CI proxy now, the real thinning report later, and the difference between them is
stated rather than blurred), a real device has played a round in airplane mode, three testers who were
not told which is which have separated `admit`, `reject` and `bar` face-down, the full Level-B matrix
has run and reported cases rather than skips, `tests.json` is green with a script that proves nothing
was removed or weakened since `main`, and a fresh-context subagent has reviewed the whole branch
against `SPEC.md`. Then this task stops — and tells the user, in these words, to run `/hunch-release`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §14.3 phase 8 | the gate, verbatim: *"archive builds with zero warnings; binary under 15 MB; airplane-mode playthrough; face-down haptic discrimination by three testers; every string re-read against §1.13"* |
| `GAME_DESIGN.md` | §13.12 gate 12 | *"admit / reject / `bar` are distinguishable face-down by three testers who were not told which is which"* |
| `GAME_DESIGN.md` | §13.12 gate 13 | the claims re-read — **T11 ran it; this task records it in the release ledger and re-checks nothing** |
| `GAME_DESIGN.md` | §14.5 decision 5 | the full Level-B matrix is a **hard gate before any archive**, not a nightly nicety |
| `GAME_DESIGN.md` | §14.1 (VERIFICATION) | *"`tests.json` — structured pass/fail list of every invariant; entries are never removed or weakened"* |
| `GAME_DESIGN.md` | §14.4 | *"any network code at all"* is out of scope — the claim the airplane-mode playthrough is the end-to-end proof of |
| `GAME_DESIGN.md` | §14.6 risk 7 | *"subagent diff reviews at phases 3, 5 and 8"* — this is phase 8's |
| `.claude/skills/hunch-release/references/release-checklist.md` | §1, §2, §4, §7 | the inputs, gates A1–A9 with commands, why the size gate sits after the archive, and the tempting wrong fix per gate |
| `.claude/skills/hunch-release/SKILL.md` | A, "the gate that passes when it did not run", "Never" | the read-only nine, the calibration trap, and the four things that are never done to make a gate green |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B18`, `B19`, `B31`, `B33`, `B44` | warnings-as-errors and flag order; `set -o pipefail`; `xcresulttool get test-results`; **you cannot measure app size from the `.app`, the `.xcarchive` or the `.ipa`** |

**This task runs `hunch-release`'s section A and stops.** Section B archives, signs and exports;
section C uploads. Both are `/hunch-release`'s, both are irreversible in different ways, and the skill
carries `disable-model-invocation: true` precisely so it cannot be reached any other way. An uploaded
`CURRENT_PROJECT_VERSION` can never be reused and a metadata string that clears review is a public
claim.

## TDD — the test comes first

Most of this task is *running* gates that already exist, and running an existing gate is not a test.
The one thing this task **builds** is the gate that has no owner today: `tests.json` says entries are
never removed or weakened, and nothing checks that. `Scripts/check-tests-json.sh` (E01·T08) validates
the file's *shape*; monotonicity is a property of the **diff** against `main`, and it needs its own
program.

So the failing test is a script with plants, and it has the shape every check in this repository has:
prove it catches the violation, **and prove it does not catch the legal spelling** — because the legal
spelling here is *adding an entry*, which this epic does thirteen times, and a check that flagged that
would be disabled on its first run.

**Step 1 — write the plants first.** `/tmp/prove-tests-json.sh`, scratch, not committed:

```bash
#!/bin/bash
# Scripts/check-tests-json-monotonic.sh compares tests.json against its state at a base ref.
# Every plant must print CAUGHT; every legal edit must print OK.
set -uo pipefail
base=$(git merge-base HEAD main)
probe() { eval "$2"
  if Scripts/check-tests-json-monotonic.sh "$base" >/tmp/t.out 2>&1; then
    echo "$1: MISSED"; else echo "$1: CAUGHT"; fi
  eval "$3"; }

# 1. An entry deleted outright — the offence §14.1 names.
probe 'entry removed' \
  'jq "del(.entries[] | select(.id == \"audio.session-triple\"))" tests.json > /tmp/tj && mv /tmp/tj tests.json' \
  'git checkout -- tests.json'

# 2. An entry re-worded so it no longer means what it meant.
probe 'statement re-worded' \
  'jq "(.entries[] | select(.id == \"haptics.discriminability-triple\") | .statement) = \"haptics feel fine\"" tests.json > /tmp/tj && mv /tmp/tj tests.json' \
  'git checkout -- tests.json'

# 3. A pass condition weakened — the subtlest one, and the one a reviewer skims past.
probe 'command narrowed to a subset' \
  'jq "(.entries[] | select(.id == \"tokens.no-literals\") | .command) = \"true\"" tests.json > /tmp/tj && mv /tmp/tj tests.json' \
  'git checkout -- tests.json'

# 4. A green entry demoted to pending to get a branch merged.
probe 'green demoted to pending' \
  'jq "(.entries[] | select(.id == \"audio.mix-ceiling\") | .status) = \"pending\"" tests.json > /tmp/tj && mv /tmp/tj tests.json' \
  'git checkout -- tests.json'

# 5. An owner blanked, so a manual gate loses the person who runs it.
probe 'owner removed from a manual entry' \
  'jq "(.entries[] | select(.kind == \"manual\") | .owner) = \"\"" tests.json > /tmp/tj && mv /tmp/tj tests.json' \
  'git checkout -- tests.json'

# THE LEGAL SPELLINGS. This epic adds thirteen entries; a check that flagged that is a check
# nobody would keep. And a pending entry becoming green is the direction the file is allowed
# to move.
jq '.entries += [{"id":"release.new-thing","statement":"a new invariant","source":"§14.3",
                  "home":"HunchTests","command":"true","owner":"E20","status":"green",
                  "kind":"automated"}]' tests.json > /tmp/tj && mv /tmp/tj tests.json
Scripts/check-tests-json-monotonic.sh "$base" >/dev/null 2>&1 \
  && echo 'entry added: OK' || echo 'entry added: FALSE POSITIVE'
git checkout -- tests.json

jq '(.entries[] | select(.status == "pending") | .status) = "green"' tests.json > /tmp/tj && mv /tmp/tj tests.json
Scripts/check-tests-json-monotonic.sh "$base" >/dev/null 2>&1 \
  && echo 'pending → green: OK' || echo 'pending → green: FALSE POSITIVE'
git checkout -- tests.json
```

**Step 2 — run it and watch it fail.** `bash /tmp/prove-tests-json.sh` prints `MISSED` on all five
plants, because the script does not exist. That is the failing state, and it is also an honest
statement about the repository today: **`tests.json`'s central rule has been unenforced for nineteen
epics.**

**Step 3 — implement** the script, then run the nine gates and the four manual ones.

**Step 4 — green, then hand over.** Every gate green, every record written, the subagent review pasted
in, the PR merged — and then one sentence to the user naming `/hunch-release`.

## Files

| Action | Path |
|---|---|
| create | `Scripts/check-tests-json-monotonic.sh` |
| modify | `.github/workflows/ci.yml` — the monotonicity check as a named PR step against `origin/main` |
| modify | `PROGRESS.md` — §Release: the zero-warning run, the size proxy, the airplane-mode playthrough, the Level-B run summary. §Feedback: the three-tester panel. §Review: the subagent transcript |
| modify | `tests.json` — this epic's entries completed; gate 12 flipped from `pending` to `green`; `release.size-report` entered as `pending` with `/hunch-release` §4 as its owner |
| modify | `DECISIONS.md` — anything the subagent review raised that is answered rather than fixed |
| modify | `.github/pr-body.md` — the gate table with every row's evidence |

Nothing under `App/`, `Modules/` or `HunchCore/` changes in this task unless a gate goes red. If a gate
does go red, the fix lands in the owning file **on this branch** and the commit body says which gate
found it.

## Implementation notes

### A6 — zero warnings, and the two forbidden fixes

```bash
xcodebuild -project Hunch.xcodeproj -scheme Hunch -configuration Release \
  -destination 'generic/platform=iOS' build 2>&1 | grep -c ' warning: '     # → 0
```

`-warnings-as-errors` is already on Release (`07 B18`), so a warning is a build failure and the grep is
belt-and-braces for anything a `-Wwarning <group>` exemption downgraded. Two things that are forbidden
and one that is required:

- **Forbidden: adding `-Wwarning <group>` to clear the gate.** The epic's git-workflow section names
  this as one of two famously tempting wrong fixes. Fix the warning.
- **Forbidden: appending an exemption after the blanket flag is *right*; appending the blanket flag
  after an exemption is what kills it.** `OTHER_SWIFT_FLAGS[config=Release] = $(inherited)
  -warnings-as-errors -Wwarning SomeGroup`. Flags apply left to right; written the other way round the
  exemption is dead and the group errors the archive. `07 B19` is the reproduced ordering and
  `08 §7.12` states the opposite and is wrong.
- **Required: promote `#UnknownWarningGroup` to an error**, so a typo in the warning config cannot
  ship silently (`07 B19`'s second half). A misspelled group name is accepted with a warning that
  nobody reads.

Two warning sources this epic is likely to have introduced, both worth looking for by name: an unused
symbol inside a `#if DEBUG` gallery block that Release does not compile out cleanly (E04·T09 flagged
it), and a deprecation on an `AVAudioSession` or `CHHapticEngine` API used from T04/T06.

### The size number, measured twice, and why the two are different measurements

The epic gate says *the Release `.app` size proxy in CI **and** the real figure from `App Thinning
Size Report.txt`* — and the "and" is the whole point.

| Measurement | When | What it is | What it is not |
|---|---|---|---|
| the CI proxy | now, this task | `du -sk` on the Release `.app`, tracked as a **trend** with stated headroom | a size measurement |
| the thinning report | after `/hunch-release` §3's Ad Hoc export | compressed (≈ download) and uncompressed (≈ installed) per variant | available before an archive |

`07 B44` is unambiguous: **you cannot measure app size from the `.app`, the `.xcarchive` or the
`.ipa`** — all three contain things users never download, dSYMs among them. So the proxy is honest only
if it is labelled a proxy. Record it as one, with the headroom stated, and enter the real figure in
`tests.json` as a `pending` entry owned by the release run rather than pretending this task can close
it. `hunch-release` gate B3 is where it closes, and its own gotcha says the size gate sits *after* the
archive and *before* the upload for exactly this reason.

What the proxy is actually good for is the **delta**. This epic added a `.metal` file, an audio engine,
a haptic engine, sixty text files and one PNG. If the proxy jumped, the two candidates are `07 B45`'s:
a bundled resource that should be derived, or a data table baked into source as string literals. HUNCH
has no glyph images and no audio assets by construction (`08 §1`), so a jump is a finding, not a shrug.
`lowerBandIndex.bin` is a *derived* file built on device (§14.5 decision 4) — if it has become a
bundled resource, it is on this line item and must then be version-locked to the generator.

### The airplane-mode playthrough — the only end-to-end proof the grep cannot give

Check 5 proves the *symbols* are absent from the source. That is a strong claim and it is not the same
claim as "the app works with no network", which is what the privacy manifest, the About screen and the
App Privacy questionnaire all assert. Run it on a real device, on the build number you will record:

1. Aeroplane mode **on**, Wi-Fi off, cellular off. Confirm in Control Centre, not from memory.
2. Play **one full round to inscription** — probe, twin, declare, and a correct declaration so a Codex
   page mints.
3. Open **one Codex page**.
4. Tap **one Anomaly cell**.
5. Background the app, return, confirm the round resumed.

Record in `PROGRESS.md` §Release: the date, the build number, the device, and one sentence per step
saying what happened. Anything that spins, stalls or shows a system network prompt is a finding, and
the finding is bigger than this task.

### Gate 12 — the three-tester face-down panel, and the protocol that makes it mean something

§13.12 gate 12 is three testers distinguishing `admit`, `reject` and `bar` **face-down, without being
told which is which**. The epic gate demands 9 of 9. The protocol matters more than the number:

- **Three testers × three events = nine presentations.** Each tester feels all three.
- **Randomise the presentation order per tester** and record the order. A fixed order lets a tester
  learn the sequence rather than the sensation.
- **No brief beyond the task.** Say: *"you will feel three different things; tell me each time whether
  it is the same as one you have felt before, and at the end sort them into three groups."* Do not say
  "one soft, two sharp, one blunt" — that is the answer, and §13.9 is explicit that they are not told
  which is which.
- **Screen face-down, sound off.** Both channels are redundant copies (§6.4) and both would leak it.
- **Record per tester**: date, build number, presentation order, and the three-way assignment.
- **9 of 9, or the panel is re-run after a pattern change — never after a re-brief.** This is the line
  that keeps the gate honest. A re-brief teaches the tester the answer and the second run measures
  memory. If the panel fails, the fix is in T05's pattern table: `admit` is one soft event, `reject` is
  two sharp, `bar` is the only high-intensity low-sharpness event in the game, and
  `barIsTheOnlyBluntHeavyEvent` is the test that pins the corner.

Flip `haptics.face-down-panel` in `tests.json` from `pending` to `green` only when nine of nine is
recorded. E19·T11 entered it as the one entry legitimately non-green at that epic's merge and named
this task as its owner; this is where that debt is paid.

### The Level-B matrix — the gate that passes when it did not run

```bash
HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter CalibrationTests
```

`.enabled(if:)` skips are reported as **successes**. A plain `swift test` is green over a matrix that
never executed, and §14.5 decision 5 makes the full matrix a hard gate before *any* archive. So the
pass condition is not "green" — it is **"the run summary reports cases executed, not zero"**. Read the
summary. Paste the case count into `PROGRESS.md`.

If ρ comes in under H10's threshold, the fix is §14.6 risk 3's: regenerate §5.1's modifier weights from
the harness. **Never lower the threshold to clear a release.** That is `release-checklist.md` §7's row
and it is the difference between a calibrated difficulty engine and a number in a document.

### `Scripts/check-tests-json-monotonic.sh`

```bash
#!/bin/bash
# Scripts/check-tests-json-monotonic.sh — §14.1: "entries are never removed or weakened."
#
# check-tests-json.sh (E01·T08) validates the file's SHAPE. This validates its HISTORY, which is
# a property of the diff and not of the file: an entry may be added, and a `pending` entry may
# become `green`. Nothing else may change.
#
#   usage: check-tests-json-monotonic.sh [base-ref]        default: origin/main
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$PWD}"
base="${1:-origin/main}"
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

git -C "$root" show "$base:tests.json" > /tmp/tests-base.json 2>/dev/null \
  || { echo "No tests.json at $base — nothing to compare."; exit 0; }

# 1. No id disappears. This is the offence §14.1 names first.
gone=$(jq -r --slurpfile now "$root/tests.json" '
  [ $now[0].entries[].id ] as $ids
  | .entries[] | select(.id as $i | ($ids | index($i)) | not) | "  \(.id)"' /tmp/tests-base.json)
[ -n "$gone" ] && report 'tests.json entry removed (§14.1: entries are never removed):' "$gone"

# 2. No statement, source, command or home changes. A re-worded statement is a different claim
#    wearing the same id, which is indistinguishable from a deletion by anyone reading the file.
changed=$(jq -r --slurpfile now "$root/tests.json" '
  ($now[0].entries | map({ (.id): . }) | add) as $n
  | .entries[] | select($n[.id] != null)
  | . as $old | $n[.id] as $new
  | [ ["statement", $old.statement, $new.statement],
      ["source",    $old.source,    $new.source],
      ["command",   $old.command,   $new.command],
      ["home",      $old.home,      $new.home] ]
  | map(select(.[1] != .[2]) | "  \($old.id).\(.[0]): \"\(.[1])\" → \"\(.[2])\"")[]' \
  /tmp/tests-base.json)
[ -n "$changed" ] && report 'tests.json entry re-worded (§14.1: entries are never weakened):' "$changed"

# 3. Status may only move forward. pending → green is progress; green → pending is a waiver.
demoted=$(jq -r --slurpfile now "$root/tests.json" '
  ($now[0].entries | map({ (.id): . }) | add) as $n
  | { "pending": 0, "manual": 0, "green": 1 } as $rank
  | .entries[] | select($n[.id] != null)
  | select(($rank[$n[.id].status] // 0) < ($rank[.status] // 0))
  | "  \(.id): \(.status) → \($n[.id].status)"' /tmp/tests-base.json)
[ -n "$demoted" ] && report 'tests.json status demoted (a waiver wearing a status field):' "$demoted"

# 4. A manual entry keeps a named owner. An owner-less manual gate is a gate nobody runs.
orphaned=$(jq -r '.entries[] | select(.kind == "manual")
                  | select((.owner // "") == "") | "  \(.id)"' "$root/tests.json")
[ -n "$orphaned" ] && report 'A manual entry with no owner (§13.12: each gate names who runs it):' "$orphaned"

[ "$status" -eq 0 ] && echo "tests.json: monotonic against $base ($(jq '.entries | length' "$root/tests.json") entries)"
exit "$status"
```

Four notes on it, each of which came out of running it:

- **It compares against a ref, not against a stored copy.** A committed snapshot of `tests.json` would
  itself be a second home for the same data and would need its own monotonicity check.
- **`manual` ranks with `pending`, not with `green`.** A manual gate is not automatically satisfied and
  promoting one to `green` requires a `PROGRESS.md` record — which the human ticks, not the script.
- **Adding an entry is legal and is the common case.** This epic adds thirteen. The plant script proves
  the check stays quiet for them; without that proof the check would be disabled on its first run.
- **It runs on the PR, against `origin/main`.** Running it locally against `HEAD~1` is a different and
  much weaker claim, because a branch can weaken an entry in one commit and add an unrelated one in the
  next.

### The fresh-context subagent diff review

§14.6 risk 7 mandates one at phases 3, 5 and 8. This is phase 8's, and "fresh context" is the load-bearing
word: the reviewer must not have written the code, and must read `SPEC.md` rather than being told what
the code was supposed to do.

The prompt, verbatim enough to reproduce:

> Read `SPEC.md` and `GAME_DESIGN.md` §13 and §14.1. Then read the full diff of
> `epic/E20-polish-ship` against `main`. Report, as a numbered list: every place the diff
> contradicts a stated requirement; every stated requirement in §14.1's AUDIO, HAPTICS and
> ART/MOTION rows that the diff does not deliver; every number in the diff that appears in more
> than one file; and every test whose assertion is weaker than the sentence it cites. Do not
> propose refactors. Do not comment on style.

Paste the transcript into `PROGRESS.md` §Review. **Every finding is either fixed on this branch or
answered in `DECISIONS.md` with a reason.** A finding that is neither is an open finding, and the epic
gate does not pass with one.

The categories that review has actually caught in this project's earlier phases, and which are worth
looking for by hand if the subagent misses them: a number transcribed into two files (the whole reason
`check-symbols.sh` and `check-tokens.swift` exist); a test that asserts a *shape* where the spec states
a *value*; and a spec sentence delivered in code but never wired into `tests.json`.

### Running the nine gates

`hunch-release`'s section A, in order, all read-only, all safe. `release-checklist.md` §2 has the exact
commands and this task does not restate them — it runs them and records the outcome. Three that need a
sentence here:

- **A5 is ticked against the roster table, not against a remembered count.** The roster lives in
  `hunch-build-and-ci/SKILL.md` and this epic added checks 12 and 13 plus three standalone checkers.
  *A run that reports fewer checks than that table lists is itself the failure.*
- **A4 runs the `Prerelease` plan**, which is ten configurations — five locales × two text directions,
  AX5 per configuration (E19·T11). `set -o pipefail` before the formatter or a failing suite reports
  success (`07 B31`), and results come from `xcresulttool get test-results`, not the deprecated
  `get object` (`07 B33`).
- **A8 and A9 were run by E18·T09 and E19·T11** and are re-run here rather than re-implemented. If
  either has drifted — a German Settings row that now wraps to three lines at AX3 because T09 changed a
  type role — this is where it shows, and the fix is upstream.

### The hand-over, and the four things this task never does

When every gate is green, every record is written and the PR has merged with every check green:

> **Tell the user, in these words, to run `/hunch-release`.**

It carries `disable-model-invocation: true`, so it is absent from the model's skill listing entirely
and cannot be reached any other way. "Run `/hunch-release`" is the whole correct answer to "ship this";
improvising the archive steps is the wrong one.

Never, in this task or any other:

- **Never archive from an unmerged branch.** An archive from a branch is a build that cannot be rebuilt
  from a tag, and `hunch-release` gate A1 refuses a dirty tree for exactly that reason.
- **Never run section B or C.** A build number cannot be recovered and a metadata string that clears
  review is a public claim.
- **Never make a gate green by weakening it** — not a `-Wwarning` group, not a lowered ρ, not a
  `tests.json` edit, not a lexeme added to `DECISIONS.md` without the user's written exception, not a
  raised key-count budget, not `continue-on-error` on a step.
- **Never add a third-party dependency, a network call or an analytics SDK to make a release step
  easier.** Each is a brief violation and the first two re-open a privacy-manifest obligation this app
  currently satisfies by being empty.

## Acceptance criteria

- [ ] `bash /tmp/prove-tests-json.sh` prints `CAUGHT` on all five plants and `OK` on both legal edits — an added entry and a `pending → green` promotion.
- [ ] `Scripts/check-tests-json-monotonic.sh origin/main` exits 0 and is a named CI step on pull requests with no `continue-on-error`.
- [ ] `Scripts/check-tests-json.sh` green, and **every** entry's `command` has been run in this task, with the outcomes in `PROGRESS.md`.
- [ ] **A6:** the Release build succeeds and `… | grep -c ' warning: '` → `0`; `grep -n 'OTHER_SWIFT_FLAGS' Config/Release.xcconfig` shows `-warnings-as-errors` **before** any `-Wwarning`, and `#UnknownWarningGroup` promoted to an error.
- [ ] **A2:** `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` passes, with the elapsed figure recorded.
- [ ] **A3:** `HUNCH_CALIBRATION=1 swift test --package-path HunchCore --filter CalibrationTests` green **and the run summary reports a non-zero case count**, pasted into `PROGRESS.md`.
- [ ] **A4:** the `Prerelease` plan green across all ten configurations, with a non-zero test count from `xcresulttool get test-results summary`.
- [ ] **A5:** `Scripts/check-source-hygiene.sh` green and reporting **every** check in `hunch-build-and-ci/SKILL.md`'s roster table, plus the five standalone checkers (`check-pbxproj-clean`, `check-boundary`, `check-tokens`, `check-inventory`, `check-symbols`, `check-skills`, `check-motion-rows`, `check-register-segregation`, `check-metadata`, `check-banned-lexemes` × 2 corpora).
- [ ] **A7 / gate 13:** the catalog and metadata lexeme passes both green; T11's human re-read recorded.
- [ ] **A8 / A9:** screenshots reviewed in en / de / ar plus both pseudolocales, and `performAccessibilityAudit` green with exactly one `issueHandler` in the bundle.
- [ ] **Size proxy:** the Release `.app` figure recorded in `PROGRESS.md` **labelled as a proxy**, with the delta against the previous run and the stated headroom; `release.size-report` entered in `tests.json` as `pending`, owned by `/hunch-release` §4.
- [ ] **Airplane mode:** `PROGRESS.md` §Release carries the playthrough — date, build number, device, one sentence per step — and nothing spun, stalled or prompted.
- [ ] **Gate 12:** `PROGRESS.md` §Feedback carries a dated entry per tester with the build number, the presentation order and each tester's three-way assignment; **9 of 9**; `haptics.face-down-panel` flipped from `pending` to `green`.
- [ ] **Gate 5 / shader:** the Instruments figure from T07 is in `PROGRESS.md` §Shader and `HunchUITests/GrainGovernorTests` is green.
- [ ] **Gate 9:** `MotionRowTests` green and T08's row-by-row hand audit is in `PROGRESS.md`.
- [ ] **Review:** the fresh-context subagent transcript is pasted into `PROGRESS.md` §Review, and every finding is either fixed on this branch (named in a commit) or answered in `DECISIONS.md`. **No open findings.**
- [ ] `.github/pr-body.md` carries the epic's fifteen-row gate table with each row's evidence — a command output, a `PROGRESS.md` anchor, or both.
- [ ] All twelve task files are `Status: done`, each with its own commit.
- [ ] The PR is merged with every check green, `main` is pulled, and **the user has been told, in these words, to run `/hunch-release`.**

## Close the task

1. `swift test` green and under 10 s; `Presubmission`, `Nightly` and `Prerelease` green; `HUNCH_CALIBRATION=1` reports a non-zero case count.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. There is almost nothing to simplify here; reject any suggestion that collapses `check-tests-json.sh` and `check-tests-json-monotonic.sh` into one program, because one validates a file and the other validates a diff and only the second needs a git ref. Re-run the checks after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. This is in addition to the fresh-context subagent review, not instead of it: `/code-review` reads the diff, the subagent reads the diff **against `SPEC.md`**.
4. Commit: `git commit -m "E20/T12: the archive gates run and recorded — zero warnings, airplane mode, the face-down panel, the Level-B matrix and tests.json monotonicity"`
5. Push, open the PR, `gh pr checks --watch`, merge only on green, `git checkout main && git pull`.
6. **Then tell the user to run `/hunch-release`.** Nothing else in this repository may archive, sign, export or upload.

## Out of scope

- **Archiving, signing, exporting, uploading, tagging, the two export plists, the real thinning-report figure, the App Privacy questionnaire, the age rating and Submit for Review** — **`/hunch-release`, user-invoked only.** This task runs section A and stops.
- `Scripts/check-tests-json.sh` itself — **E01·T08**. This task adds its historical sibling.
- The CI workflow's structure, the three test plans and the ten-second timer — **E01·T07**; this task adds one step.
- The eleven pattern definitions gate 12 tests — **T05**. A failed panel is fixed there, never by re-briefing a tester.
- The Instruments shader measurement — **T07**; recorded there and re-read here.
- The Reduce Motion hand audit — **T08**; recorded there and re-read here.
- The claims re-read over sixty metadata units — **T11**; recorded there and re-read here.
- Any code change that is not the fix for a gate this task found red. If the diff grows a feature, the diff is wrong.
