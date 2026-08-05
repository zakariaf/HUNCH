# T09 — The three library checkers

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | — (it is the gate that keeps every other epic's citations honest) |
| **Status** | not started |

> **Split note.** The plan's T06 carried the ten source-hygiene greps *and* these three checkers. They are different subjects — one lints Swift, one lints the skill library and the design documents — and one task file carrying both is a task file nobody executes top to bottom. Nothing left E01's scope.

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | `references/source-hygiene.md` §7.1–§7.3 are the three scripts in full, §7.4 proves each can fail, and §8 is the list of ways this exact task has already been got wrong — including "naming a script in the workflow before writing it", which is the defect these three were created to close. |

## Objective

`Scripts/check-inventory.sh`, `Scripts/check-symbols.sh` and `Scripts/check-skills.sh` exist, run, and are green — which means the seven defects they currently find in the skill library are fixed in the same commit. After this task, a component with two owning reference files, a cited token spelling nobody defines, and a `SKILL.md` whose frontmatter has silently stopped parsing are all build failures.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `hunch-build-and-ci` | `references/source-hygiene.md` §7.1 | `check-inventory.sh` in full, plus the declaration convention (`<!-- inventory: Row \| Symbol -->`) and why `--strict` is not the default yet. |
| `hunch-build-and-ci` | `references/source-hygiene.md` §7.2 | `check-symbols.sh` in full, plus the two scanning rules every checker shares. |
| `hunch-build-and-ci` | `references/source-hygiene.md` §7.3 | `check-skills.sh` in full, plus why malformed frontmatter is a *silent* auto-invocation outage. |
| `hunch-build-and-ci` | `references/source-hygiene.md` §7.4, §8 | The proving procedure and the six ways this goes wrong. |
| `design/DESIGN-SYSTEM-SCOPE.md` | §2(g), §3 | The defect `check-inventory.sh` exists to stop, and the 33-row component inventory it walks. |

## TDD — the test comes first

**Step 1 — write the failing test.** `source-hygiene.md` §7.4 is the test, and it is already written. Copy it into `/tmp/prove-checkers.sh` (scratch, not committed) — it breaks one category per checker and restores:

```bash
#!/bin/bash
# Scratch. §7.4 verbatim. Every line must exit 1 and name the right category. Run from the repo root.
set -uo pipefail

# check-skills.sh — five categories, each reachable
sed -i '' 's/^name: hunch-shared-marks/name: hunch-marks/' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "name: does not equal its directory", exit 1
git checkout -- .claude/skills/hunch-shared-marks/SKILL.md

sed -i '' 's/^metadata:/version: "1.0"\nmetadata:/' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "bare version: key", exit 1
git checkout -- .claude/skills/hunch-shared-marks/SKILL.md

sed -i '' 's|references/ownership.md|references/OWNERSHIP.md|' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "Cited path does not resolve" AND "never named in SKILL.md"
                           #   NOTE: `[ -e ]` would have PASSED this one on macOS. That is the test.
git checkout -- .claude/skills/hunch-shared-marks/SKILL.md

# check-inventory.sh — the fatal category and the orphan category
printf '\n<!-- inventory: Tick row | TickRow.draw -->\n' >> .claude/skills/hunch-shared-marks/references/ownership.md
Scripts/check-inventory.sh # → "claimed by more than one reference file", exit 1
git checkout -- .claude/skills/hunch-shared-marks/references/ownership.md

printf '\n<!-- inventory: Tick Row | TickRow.draw -->\n' >> .claude/skills/hunch-shared-marks/references/ownership.md
Scripts/check-inventory.sh # → "names a component that is not a §3 row" (capital R)
git checkout -- .claude/skills/hunch-shared-marks/references/ownership.md

Scripts/check-inventory.sh --strict   # → exit 1 on the rows still undeclared

# check-symbols.sh — assertion A, using the exact defect this library shipped
sed -i '' 's|`surface.cellLit`|`surface.cell.lit`|' .claude/skills/hunch-sigil-drawing/references/mode-sigils.md
Scripts/check-symbols.sh   # → "Token spelling that hunch-design-tokens does not define", exit 1
git checkout -- .claude/skills/hunch-sigil-drawing/references/mode-sigils.md

git status --porcelain .claude/skills   # must be empty — every plant above was reverted
```

**Step 2 — run it and watch it fail.** Before the scripts exist every line is `No such file or directory`. That is the failing state, and it is also §8's first bullet made concrete: *a gate step and its script land in the same commit.* Three steps in `ci-workflow.md` §1 invoked these three for a whole release while none existed, and four skills cited them as enforcement.

**Step 3 — implement**: extract the three scripts, then fix what they find.

**Step 4 — green, then refactor.** All three exit 0 on a clean tree, and §7.4's plants each produce the named category. **Break a second category and confirm the first failure did not stop the run** — all three use the `report`-and-continue convention for exactly that reason.

## Files

| Action | Path |
|---|---|
| create | `Scripts/check-inventory.sh` (executable) |
| create | `Scripts/check-symbols.sh` (executable) |
| create | `Scripts/check-skills.sh` (executable) |
| modify | `.claude/skills/hunch-bench-instruments/SKILL.md` — `allowed-tools` |
| modify | `.claude/skills/hunch-design-tokens/SKILL.md` — `allowed-tools` |
| modify | `.claude/skills/hunch-motion-and-feedback/SKILL.md` — `allowed-tools` |
| modify | `.claude/skills/hunch-release/SKILL.md` — `allowed-tools` |
| modify | `.claude/skills/hunch-swift-concurrency/SKILL.md` — `allowed-tools` |
| modify | `.claude/skills/hunch-chrome-and-meta/references/stock-controls.md` — one token spelling |
| modify | `.claude/skills/hunch-motion-and-feedback/references/transitions.md` — one token spelling |

## Implementation notes

### Extracting the three scripts

**A naive fence-to-fence `sed` does not work here**, and it is worth knowing why before you lose twenty minutes to it: each script's own source contains a triple-backtick, inside the `prose()` awk helper that skips fenced blocks. Anchor on the shebang and the final `exit` instead:

```bash
R=.claude/skills/hunch-build-and-ci/references/source-hygiene.md
for s in inventory symbols skills; do
  n=$(grep -n "^# Scripts/check-$s\.sh" "$R" | cut -d: -f1)          # the comment line
  sed -n "$((n-1)),/^exit \"\$status\"\$/p" "$R" > "Scripts/check-$s.sh"   # from the shebang above it
  chmod +x "Scripts/check-$s.sh"
done
wc -l Scripts/check-{inventory,symbols,skills}.sh    # 122, 83, 112 as of this writing
```

Verified on this repository: the three files come out at 122, 83 and 112 lines, each starting `#!/bin/bash` and ending `exit "$status"`.

### The four things all three share, none of which may be "simplified" away

- **`prose()` blanks fenced lines rather than deleting them**, so reported line numbers still point at the real line. Without it every checker fails on its own documentation — `source-hygiene.md` §7 necessarily prints each script's source and §7.2 names three spellings the scripts reject. That run is what produced the helper.
- **`<!-- CHECK-EXEMPT: reason -->` suppresses one line of prose**, for the rare sentence that must say a wrong spelling out loud. Same shape as check 7's `PLAY-TEXT-EXEMPT` and check 9's `TOKENS-EXEMPT`, including that the reason is written: a hatch with no reason is the thing being checked for.
- **`awk`, not `sed`, for the two-field inventory parse.** `sed` has no non-greedy match, so `(.*)\|(.*)` swallows the separator and every row parses as `"Row | Symbol -->"`. Nothing errors; the rows merely look unowned, which is indistinguishable from the state the check reports.
- **No `case` pattern inside `$( )`.** bash 3.2 — what macOS ships — mis-parses the pattern's `)` as closing the command substitution and reports a syntax error forty lines away. Both §7.1 and §7.3 avoid it, with a comment, because the next person will otherwise "simplify" it back.

### The seven defects they find today — fix all seven in this commit

Run each script once before changing anything and paste the output into `PROGRESS.md`. As of this writing, on this repository:

**`check-skills.sh` → five hits, all the same category.** Five `SKILL.md` files write `allowed-tools` as a space-separated list, which is one tool whose name contains spaces:

| Skill | Current | Fix |
|---|---|---|
| `hunch-bench-instruments` | `Read Grep Glob` | `Read, Grep, Glob` |
| `hunch-design-tokens` | `Read Grep Glob Bash(swift ${CLAUDE_SKILL_DIR}/scripts/*)` | comma-separate the four |
| `hunch-motion-and-feedback` | `Read Grep Glob` | `Read, Grep, Glob` |
| `hunch-release` | `Read Grep Glob Bash(…) × 6` | comma-separate all nine |
| `hunch-swift-concurrency` | `Read Grep Glob` | `Read, Grep, Glob` |

This is the failure the checker exists for and it is worse than it looks: the skill still answers `/<name>`, so a manual smoke test passes while its tool grants are wrong. Fix the frontmatter; change nothing else in those files.

**`check-symbols.sh` → two hits, both real.** Exactly the two `source-hygiene.md` §7.2 predicted (the third, `surface.cell.lit`, has since been fixed):

| File | Spelling used | Reality |
|---|---|---|
| `hunch-chrome-and-meta/references/stock-controls.md:138` | `space.s12` | `hunch-design-tokens` ships `space.s4` … `space.s64` |
| `hunch-motion-and-feedback/references/transitions.md:93` | `opacity.scrim` | it ships `opacity.scrimFlat` and `opacity.scrimBlurred` |

Read the sentence each sits in and pick the token the *sentence* means — a scrim over a blurred material is `opacity.scrimBlurred`, a flat one is `opacity.scrimFlat`. If neither fits, that is a design escalation to `hunch-design-tokens` and E03, recorded in `DECISIONS.md` — **never** a new token invented here and never a widened regex. None of these would have been caught by a hex-literal grep and none of them needs a compiler.

**`check-inventory.sh` → clean, with 26 warnings.** 33 rows in `DESIGN-SYSTEM-SCOPE.md` §3, 7 declared, 0 duplicated. Exit 0. Leave it on the warning branch: a gate that fails 26 times on day one gets waived, and this library's own rule is that a waivable gate is documentation. The **fatal** half — two owners for one row — is on unconditionally, because that is the failure §2(g) actually describes.

**When `--strict` turns on:** the commit that adds the *last* inventory declaration switches the CI step to `--strict` and deletes the warning branch. That is E15 on current planning (the family sigils and the Codex composites are the last rows). Put that switch in the same commit as the last declaration — the warning is a migration, not a setting.

### What would be wrong

- **Leaving any of the three red and adding `continue-on-error`.** A gate that can be waived is documentation.
- **Weakening a checker to reach green** — widening the token category list, dropping the `allowed-tools` check, loosening the exact-case path comparison. `[ -e path ]` in particular: APFS is case-insensitive by default, so `REFERENCE.md` resolves on the machine you wrote it on and 404s on the Linux lint runner. §7.3 compares against a `find` listing for exactly that reason and §7.4 proves the difference.
- **Fixing a `check-symbols.sh` hit by adding the missing token to `hunch-design-tokens`.** That skill is the vocabulary; every other skill spends it. Minting a token to satisfy a citation inverts the relationship and is how a design system acquires two names for one value.

## Acceptance criteria

- [ ] `Scripts/check-skills.sh` exits 0 and prints `Skill library: clean (13 skills)`.
- [ ] `Scripts/check-symbols.sh` exits 0 and prints its `Symbols: clean (N tokens defined, M citations checked)` line, with the "no Swift on disk yet" note gone (assertion B is live from T03 onward).
- [ ] `Scripts/check-inventory.sh` exits 0 and prints `Inventory: clean (33 rows in §3, 7 declared)` plus the 26-row warning.
- [ ] `Scripts/check-inventory.sh --strict` exits **1** — proof the strict branch works and is a real end state, not an unreachable flag.
- [ ] `bash /tmp/prove-checkers.sh` produces the named category for each of §7.4's six plants, and `git status --porcelain .claude/skills` is empty afterwards.
- [ ] Breaking two categories at once in one checker reports **both** (§7.4's closing note, §4 step 3).
- [ ] `bash -n Scripts/check-{inventory,symbols,skills}.sh` parses under macOS's `/bin/bash` 3.2.
- [ ] `git diff --stat .claude/skills` shows exactly seven files touched, and every change is a frontmatter list or a token spelling — no prose edited to satisfy a checker.

## Close the task

1. All three checkers exit 0; `swift test --package-path HunchCore` unaffected and still green.
2. **Run `/simplify`** — on scripts you did not author, its job is limited to the seven skill-file fixes. Reject anything that touches the four shared invariants above; each has a reproduced failure behind it.
3. **Run `/code-review`** — the diff to read is the seven skill files. A `description:` accidentally reflowed or an `allowed-tools` grant widened while comma-separating is the finding that matters.
4. Commit: `git commit -m "E01/T09: the three library checkers, and the seven defects they found"`

## Out of scope

- **`Scripts/check-source-hygiene.sh`, `Scripts/banned-lexemes.txt` and the build phase** — T06.
- **`Scripts/check-pbxproj-clean.sh`** — T02.
- **`check-boundary.sh`, `check-tokens.swift`, `check-coverage-separation.js`, `check-sigil-distinctness.js`** — they already exist inside their skills and are run, not rewritten. T07 adds their CI steps.
- **The sigil parity fixture** (`HunchCore/Tests/SigilsTests/Fixtures/sigils.json`, diffed against `check-sigil-distinctness.js --json`) — E15·T09 creates it. Its CI step lands with the fixture, not here; see T07's out-of-scope note.
- **Adding an inventory declaration to any reference file** — the epic that writes that file's drawing owns it (E04, E15, E16).
- **Flipping `--strict`** — E15.
