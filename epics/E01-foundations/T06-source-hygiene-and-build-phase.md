# T06 — Source-hygiene script and the no-network build phase

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02, T05 |
| **Delivers** | No-network build phase (§14.1 VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns the gate roster and the script. `references/source-hygiene.md` §1 says where each check's text comes from, §2 is the skeleton and checks 5–8 in full, §3 is the conventions every check must follow, §4 is how to prove a check can fail, §5 is the run-script phase and the sandbox, §6 is the pre-commit hook. |

The four checks this script inherits belong to other skills — `hunch-swift-code` (check 1), `hunch-swift-testing` (checks 2, 4), `hunch-swift-concurrency` (checks 3, 6), `hunch-accessibility` (check 7), `hunch-design-tokens` (checks 9, 10). You do not need to load them to *assemble* the script, and you do need to name them in each check's comment, because six months from now that citation is the only way to know whether the check or the rule is the thing that moved.

## Objective

`Scripts/check-source-hygiene.sh` exists with all ten checks, each proved able to fail, and runs as the repository's **one** Xcode run-script build phase (in its `--fast` subset) and in the pre-commit hook. From this commit onward, every rule this project states that the compiler cannot check is a numbered gate rather than a thing someone remembers.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | §9.1 (`B34a`) | Checks 1–4, printed there in full, with four footnotes explaining the `awk` range, the `\|\| true`, the two-line comment window and the `describe --type json` choice. |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B14`, `B15`, `B16`, `B17` | Sandboxing stays on; a phase with no outputs runs every build; never a formatter in a build phase; measure the phase once. |
| `hunch-build-and-ci` | `references/source-hygiene.md` §1–§6 | The assembly order, the skeleton, checks 5–8, the conventions, the proving procedure, the phase and the hook. |
| `hunch-design-tokens` | `references/tokens-swift-layout.md` §6.1 | Checks 9 and 10, and the `TOKENS-EXEMPT` convention. |
| `GAME_DESIGN.md` | §14.4 | *"Any network code at all — no `URLSession`, no `Network`, no analytics, no crash SDK; enforced by a build phase."* This is the check the brief mandates at build time. |
| `GAME_DESIGN.md` | §1.13 | The per-locale banned-lexeme list check 8 reads out of `Scripts/banned-lexemes.txt`. §1.13 is the list's single home; the file is its transcription. |
| `GAME_DESIGN.md` | §12.9 | Check 7's six play-surface files and check 8's ≤ 250-key budget. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | Why checks 7 and 8 are source lints and cannot be package tests: neither artefact exists inside a test bundle. |

## TDD — the test comes first

For a script, the failing test **is** the deliberate violation. `07 B6`: *a check that cannot fail is worse than no check*, because it converts an absence of evidence into a green tick.

**Step 1 — write the ten deliberate violations, before the script.** Create `/tmp/prove-hygiene.sh` (scratch; not committed):

```bash
#!/bin/bash
# Scratch. Plants one violation per check, runs the script, restores. Run from the repo root.
# Every line must print "check N: CAUGHT". A line printing "MISSED" is a check that does nothing.
set -uo pipefail

probe() {                                   # probe <n> <plant-command> <restore-command>
  eval "$2"
  if Scripts/check-source-hygiene.sh >/tmp/hyg.out 2>&1; then echo "check $1: MISSED"; else echo "check $1: CAUGHT"; fi
  eval "$3"
}

probe 1 'touch HunchCore/Sources/LawGeneration/Helpers.swift' \
        'rm -f HunchCore/Sources/LawGeneration/Helpers.swift'
probe 2 'printf "\n// record: .all\nlet r = 1  // record: .all\n" >> App/HunchApp.swift' \
        'git checkout -- App/HunchApp.swift'
probe 3 'printf "\nfinal class Leak: @unchecked Sendable {}\n" >> App/HunchApp.swift' \
        'git checkout -- App/HunchApp.swift'
probe 5 'printf "\nlet leak = URLSession.shared\n" >> App/HunchApp.swift' \
        'git checkout -- App/HunchApp.swift'
probe 6 'printf "\nlet d = Date()\n" >> HunchCore/Sources/LawGeneration/SplitMix64.swift' \
        'git checkout -- HunchCore/Sources/LawGeneration/SplitMix64.swift'
probe 6 'printf "\nlet n = Int.random(in: 0..<4)\n" >> HunchCore/Sources/LawGeneration/SplitMix64.swift' \
        'git checkout -- HunchCore/Sources/LawGeneration/SplitMix64.swift'
probe 9 'printf "\nlet w = 3.0  // lineWidth: 3.0\nlet x = \"#AABBCC\"\n" >> App/HunchApp.swift' \
        'git checkout -- App/HunchApp.swift'
probe 10 'printf "\nlet c = HueColor(rgb: 0)\n" >> App/HunchApp.swift' \
        'git checkout -- App/HunchApp.swift'

# The legal spelling must NOT be caught — a check that flags correct code gets suppressed.
printf '\nlet n = Int.random(in: 0..<4, using: &rng)\n' >> HunchCore/Sources/LawGeneration/SplitMix64.swift
Scripts/check-source-hygiene.sh >/dev/null 2>&1 && echo "using:-filter: OK" || echo "using:-filter: FALSE POSITIVE"
git checkout -- HunchCore/Sources/LawGeneration/SplitMix64.swift

# Two categories at once: the script must report BOTH, not stop at the first.
printf '\nlet leak = URLSession.shared\n' >> App/HunchApp.swift
touch HunchCore/Sources/LawGeneration/Constants.swift
Scripts/check-source-hygiene.sh 2>&1 | grep -c '^Network API\|^Banned file names'
git checkout -- App/HunchApp.swift; rm -f HunchCore/Sources/LawGeneration/Constants.swift
```

Checks 4, 7 and 8 need a live violation the repo cannot host in E01 — check 4 needs a manifest edit, check 7 needs a play-surface file (E08/E09) and check 8 needs the String Catalog (E18). Prove those three differently, and record which method you used in `PROGRESS.md`:

- **check 4** — temporarily add `dependencies: ["HunchTestSupport"]` to the `LawGeneration` target, run, revert. This is verified to report `target LawGeneration` and exit 1.
- **check 7** — `mkdir -p /tmp/psx && printf 'Text("PROBE")\n' > /tmp/psx/RoundView.swift`, point the check's `find` root at `/tmp/psx` for one run, revert. Record that the real proof lands in E08·T01.
- **check 8** — write a two-key `Localizable.xcstrings` into a temp path with one `"state": "new"` entry and one banned lexeme, point `catalog=` at it for one run, revert. Record that the real proof lands in E18·T01.

**Step 2 — run it and watch it fail.** `bash /tmp/prove-hygiene.sh` before the script exists prints `MISSED` on every line (there is nothing to run). That is the failing state.

**Step 3 — implement** the script, below.

**Step 4 — green, then refactor.** Every line reads `CAUGHT`, the `using:`-filter line reads `OK`, and the two-category line prints `2`. **Step 3 of `source-hygiene.md` §4 is the one people skip**: a script that stops at the first failing category hides the rest, and the `|| true` convention exists for exactly that.

## Files

| Action | Path |
|---|---|
| create | `Scripts/check-source-hygiene.sh` (executable) |
| create | `Scripts/banned-lexemes.txt` |
| create | `.git/hooks/pre-commit` (executable; **not versioned** — document it in `CLAUDE.md`, T08) |
| modify | `Hunch.xcodeproj` — one new run-script build phase, ordered first |

## Implementation notes

### Assemble, do not compose

**Once `Scripts/check-source-hygiene.sh` exists, it is the single copy of these checks.** Every document — including this one — is a recipe for building it and stops being normative for its text. So print the three blocks rather than retyping any of them:

```bash
# checks 1–4
sed -n '/^#!\/bin\/bash/,/^exit "\$status"/p' ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md
# the skeleton and checks 5–8
sed -n '/^```bash$/,/^```$/p' .claude/skills/hunch-build-and-ci/references/source-hygiene.md | sed -n '1,120p'
# checks 9–10
sed -n '/^# 9\./,/^\[ -n "\$hits" \] && report .Minting/p' \
  .claude/skills/hunch-design-tokens/references/tokens-swift-layout.md
```

**Numbering is fixed. Checks are appended, never renumbered**, because every other skill in this library cites them by number.

### The skeleton, with one fix

Take `source-hygiene.md` §2's skeleton as written, with **one correction that was reproduced on this machine**. The day-one guard drops roots that do not exist yet — but on macOS's `/bin/bash` (3.2.57) expanding an *empty* array under `set -u` is an error, so the guard aborts before it can print its message:

```text
$ /bin/bash -c 'set -uo pipefail; present=(); roots=("${present[@]}"); echo ok'
present[@]: unbound variable          # exit 1
```

Test the length **before** the expansion:

```bash
present=(); for d in "${roots[@]}"; do [ -d "$d" ] && present+=("$d"); done
if [ "${#present[@]}" -eq 0 ]; then echo 'No Swift source roots yet — nothing to check.'; exit 0; fi
roots=("${present[@]}")
```

This matters in E01 and only in E01: after T02 the `App` root exists, so the branch is unreachable — which is precisely how a broken guard survives to be discovered by someone else in a year.

### The seven adaptations, check by check

Everything else is pasted verbatim. These are the only edits, and each is required:

| Check | Adaptation | Why |
|---|---|---|
| skeleton | `roots=(App HunchCore/Sources HunchCore/Tests Modules/Sources Modules/Tests)`, `core=HunchCore/Sources`, `catalog=Modules/Sources/HunchUI/Resources/Localizable.xcstrings` | `source-hygiene.md` §2's values; `08 §1`'s tree. In E01 only `App`, `HunchCore/Sources` and `HunchCore/Tests` are present and the guard drops the rest. |
| 1 | none | `01 P28`'s list is the same everywhere. |
| 2 | none | Inert until a snapshot suite exists, which in this project it never quite does (`08 §7.9` fills that role with golden fixtures); the check stays, because a future contributor's first instinct will be `swift-snapshot-testing`. |
| 3 | none | The two-line comment window is load-bearing: `05 R29` asks for a *justifying comment* and people write it above the declaration as often as beside it. |
| 4 | `"TestSupport"` → `"HunchTestSupport"` (three places), and `--package-path HunchCore` on `swift package describe`, and the whole block guarded by `if [ "$fast" -eq 0 ]; then … fi` | The target's real name, the package it lives in, and the fact that `--fast` (the build phase) has neither a guaranteed `swift` nor `jq` on its PATH. Verified: the `jq` filter prints nothing on a clean manifest and `target LawGeneration` when `LawGeneration` is given a `HunchTestSupport` dependency. |
| 5 | none — **and do not "tidy" the alternation** | `(public \|package \|internal \|)?` is `grep: empty (sub)expression` on the grep macOS ships, and the failure is a *stderr line*, not a non-zero exit, so the check would silently check nothing. Reproduced. Write `(public \|package \|internal )?` and let the `?` carry the empty case. |
| 6 | none — **and keep the `\| grep -v 'using:'`** | `Int.random(in: 0..<5, using: &rng)` is deterministic and legal (T05); a bare `.random(in:)` is not. A check that flags the legal spelling gets suppressed within a week, and a suppressed check protects nothing. |
| 7 | none | Line-based and cannot see nesting; that is the correct bias, and `PLAY-TEXT-EXEMPT` is the rare-wrap escape. Keep `grep -H`: grep omits the filename when given a single path, and the play-surface set is often one file. |
| 8 | none | Needs `jq`; already inside the `--fast` guard. |
| 9, 10 | replace the hardcoded roots `App Modules HunchCore/Sources` with a `tokenRoots` array built by the same presence filter, keeping `Modules` (the whole package, not `Modules/Sources`) and **excluding `HunchCore/Tests`** | `grep -r` on a path that does not exist prints an error and, with `\|\| true`, silently yields nothing — so on a tree without `Modules/` the token check would appear to pass while checking a subset. Tests are excluded because §6.1's own scope is the source roots. |

### `Scripts/banned-lexemes.txt`

Format is `locale<TAB>lexeme`, one per line, `#` for a comment. **The list is `GAME_DESIGN.md` §1.13's and has exactly one home**; transcribe it from that paragraph — all twelve locales — rather than from memory or from this file:

```bash
sed -n '/^`en` brain/,/^Exclamation marks/p' GAME_DESIGN.md
```

Two things the transcription must get right:

- **Exclamation marks are on the same list**, and the script matches per-locale, so `!` needs one line for each of the twelve locales. There is no wildcard locale in the jq filter.
- **§1.13 requires case- *and* diacritic-insensitive matching, and `test($w; "i")` gives you only the first.** The compensating measure is already in §1.13, which lists both spellings where they differ (`memoria`/`memória`, `concentración`/`concentração`) — so transcribe them **all**, including the accented forms, and record the gap in `DECISIONS.md` (T08) rather than leaving it unstated. If a later epic wants real diacritic folding, that is a change to check 8 with a written decision, not a quiet regex tweak.

### The run-script build phase

`source-hygiene.md` §5 is the box, and all three of its decisions are deliberate:

```text
Hunch target ▸ Build Phases ▸ + ▸ New Run Script Phase
  Name:  Source hygiene
  Order: FIRST, above Compile Sources — it should fail before a two-minute compile, not after
  Shell: /bin/bash

  "$SRCROOT/Scripts/check-source-hygiene.sh" --fast

  Input Files:
    $(SRCROOT)/Scripts/check-source-hygiene.sh
    $(SRCROOT)/App
    $(SRCROOT)/HunchCore/Sources
    $(SRCROOT)/Modules/Sources        ← add this line in E03·T06, when the directory exists

  Output Files:  (none — deliberately)
```

- **`--fast`** skips checks 4 and 8, which need `swift package describe` and `jq`; neither is guaranteed on a sandboxed build-phase PATH and both are slow. They run in CI (T07).
- **The inputs are declared to buy sandbox read access**, not to drive re-runs.
- **No outputs, on purpose.** `07 B15` rule 2 means the phase then runs on **every** build, serially. That is the price of the brief's build-phase gate, taken knowingly.

Measure it once with Product ▸ Perform Action ▸ Build With Timing Summary (`07 B16`). If the phase costs more than ~0.5 s, cut it to check 5 alone — that is the only check the brief requires at build time — and record the cut in `DECISIONS.md`.

If the sandbox denies a read (`Sandbox: bash(…) deny(1) file-read-data …` in the build log) the fallback order is: declare the specific denied subdirectories → drop the phase to check 5 with a narrower input set → delete the phase, keep the hook and CI, and record it. **Never set `ENABLE_USER_SCRIPT_SANDBOXING = NO`** — that trades a real security control for a convenience and is the exact move `07 B14` and `B17` both name as wrong.

Verify after the first clean build:

```bash
xcodebuild build -scheme Hunch -destination 'generic/platform=iOS' 2>&1 | grep -c 'deny(1)'   # expect 0
```

### The pre-commit hook

`source-hygiene.md` §6, verbatim. It formats the staged Swift files, **re-stages them**, then runs the fast subset. Formatting *before* re-staging is what stops the hook from producing a commit whose content differs from what you reviewed. It is not versioned (nothing under `.git/` is), so `CLAUDE.md` (T08) carries the four lines and the `chmod +x`.

### What this task must not do

- Never weaken or delete a check to reach green, and never add `continue-on-error` to its CI step. Inside the script, `|| true` on a `grep` is **required** and means the opposite — finding nothing exits 1, and under `pipefail` that would abort the script at the first *clean* category so every later check silently never runs.
- Never end a check on `grep -q … && exit 1`. Clean means grep exits 1, which becomes the script's status: clean repo, red build.
- Never put the formatter in this phase (`07 B17`). It has no meaningful inputs or outputs, it writes across the whole source root — which sandboxing denies — and it mutates files underneath the compiler mid-build.

## Acceptance criteria

- [ ] `bash /tmp/prove-hygiene.sh` prints `CAUGHT` for checks 1, 2, 3, 5, 6 (both plants), 9 and 10; `OK` for the `using:` filter; and `2` for the two-category line.
- [ ] Checks 4, 7 and 8 each proved by their named alternative method, with the method and its output written into `PROGRESS.md`.
- [ ] `Scripts/check-source-hygiene.sh` on a clean tree prints `Source hygiene: clean` and exits 0; with `--fast` prints `Source hygiene: clean (fast subset)` and exits 0.
- [ ] `grep -c '^# *[0-9]*\.' Scripts/check-source-hygiene.sh` shows all ten numbered checks present, in order, each naming its owning rule (`01 P28`, `06 T51`, `05 R29`, `06 T5a`, the brief, `08 §4`, §12.9, §1.13, `hunch-design-tokens` ×2).
- [ ] `bash -n Scripts/check-source-hygiene.sh` parses under macOS's `/bin/bash` 3.2, and `/bin/bash -c 'cd /tmp/empty && …'` on a tree with no source roots prints the "nothing to check" line and exits 0 rather than `unbound variable`.
- [ ] The build phase exists, is **first**, and a full `xcodebuild build` log contains zero `deny(1)` lines.
- [ ] Planting `URLSession.shared` in `App/HunchApp.swift` makes `xcodebuild build -scheme Hunch` **fail at the Source hygiene phase**, before Compile Sources — this is the epic gate and the brief's mandated build-phase grep.
- [ ] `.git/hooks/pre-commit` is executable, formats staged Swift and runs `--fast`.
- [ ] `Scripts/banned-lexemes.txt` has one line per `(locale, token)` pair from §1.13 plus twelve `!` lines, and `awk -F'\t' 'NF!=2 && $0 !~ /^#/ && NF' Scripts/banned-lexemes.txt` returns nothing.

## Close the task

1. `swift test --package-path HunchCore` still green (nothing here touches Swift), and `Scripts/check-source-hygiene.sh` clean.
2. **Run `/simplify`** — reject any suggestion that collapses `|| true`, replaces the `awk` range with `grep -A20`, removes the `using:` filter, or "tidies" check 5's alternation. All four are reproduced failures, named above. Re-run `/tmp/prove-hygiene.sh` after it.
3. **Run `/code-review`** — the findings that matter are a check whose `report` is unreachable, a hardcoded root that skips a directory, and a check that exits early.
4. Commit: `git commit -m "E01/T06: check-source-hygiene.sh, banned-lexemes.txt, the run-script phase and the pre-commit hook"`

## Out of scope

- **`Scripts/check-pbxproj-clean.sh`** — T02 created it, because T02 is what makes it able to fail.
- **`Scripts/check-inventory.sh`, `check-symbols.sh`, `check-skills.sh`** — T09. They are not greps; they parse markdown and need a shared `prose()` helper.
- **`check-boundary.sh`, `check-tokens.swift`, `check-coverage-separation.js`, `check-sigil-distinctness.js`** — they already exist inside their skills. T07 wires them into CI; nobody re-implements them.
- **Every CI step** — T07. *A gate step and its script land in the same commit*, so T07 adds this script's step, not this task.
- **Making checks 9 and 10 able to fail on real code** — E03 creates `HunchCore/Sources/Tokens/` and the `HueColor`/`AccentColor` types. Until then those two checks pass over a tree with no colours in it, which is a true statement about the tree and not a disabled check.
- **Check 7's real proof** — E08·T01 creates the first play-surface file.
- **Check 8's real proof** — E18·T01 creates `Localizable.xcstrings`.
- **Flipping `check-inventory.sh` to `--strict`** — the epic that writes the last inventory declaration (E15).
