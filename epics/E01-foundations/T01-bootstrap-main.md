# T01 — Bootstrap `main` with a direct commit

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | nothing |
| **Delivers** | — (no §14.1 row; this is the precondition for every row) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns where `swift-format` runs and what the committed `.swift-format` contains (`references/swift-format.md` §2), and it is the skill that will read `.gitignore` back when a `Local.xcconfig` or a `Package.resolved` goes missing. |

## Objective

`main` gains its first commit, on the remote, so that a branch and a pull request become possible at all. Four files land: `README.md`, `.gitignore`, `LICENSE` and the single root `.swift-format`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P39` | One `.swift-format` at the repo root covers the whole tree, including both packages — swift-format walks up from each source file. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P43`, `P44`, `P45` | Exactly what is committed and what is ignored, and the one path that must be whitelisted back in. |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | `W54`, `W55` | The committed formatter config is a **delta** — four rules on, two values set. That rule holds the single copy; print it, do not retype it. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §7.6 | The tree these files sit at the top of, and `04 A45`'s requirement that the README records which side of the SwiftData question this project is on. |
| `GAME_DESIGN.md` | §1.13 | The copy and claims policy binds the README too. No cognitive-benefit claim, in any register, including in jest. |
| `GAME_DESIGN.md` | §14.4 | What the README may truthfully say the app does not do — no network, no accounts, no sync, no ads. |

Print `W54`'s config rather than transcribing it from memory:

```bash
sed -n '/^\*\*W54\./,/^\*\*W55\./p' ios-swift-guide/03-WRITING-THE-CODE.md
```

## TDD — the test comes first

There is no Swift in this task, so the failing test is a shell check. It is still a real check: it fails now for the right reason (no commits, no files, `git check-ignore` answering wrongly) and passes only when the task is done.

**Step 1 — write the failing check.** Create `/tmp/check-bootstrap.sh` (a scratch file — it is *not* committed; the durable checks are T06's and T09's):

```bash
#!/bin/bash
# Scratch verification for E01/T01. Run from the repo root.
set -uo pipefail
status=0
fail() { status=1; printf 'FAIL  %s\n' "$1" >&2; }
pass() { printf 'ok    %s\n' "$1"; }

# 1. main exists, has at least one commit, and that commit is on the remote.
git rev-parse --verify main >/dev/null 2>&1 && pass 'main has a commit' || fail 'main has no commits'
[ "$(git rev-parse main 2>/dev/null)" = "$(git rev-parse origin/main 2>/dev/null)" ] \
  && pass 'origin/main matches main' || fail 'main is not pushed'

# 2. The four files exist AND are tracked. Untracked files are not a bootstrap.
for f in README.md .gitignore LICENSE .swift-format; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 && pass "tracked: $f" || fail "not tracked: $f"
done

# 3. .swift-format is valid JSON, sets indentation to 4 (W55) and turns on W54's four rules.
if jq -e . .swift-format >/dev/null 2>&1; then
  pass '.swift-format parses'
  [ "$(jq -r '.indentation.spaces' .swift-format)" = "4" ] \
    && pass 'indentation is 4 (W55)' || fail 'indentation is not 4 — Xcode default is 4, swift-format default is 2'
  for rule in NeverForceUnwrap NeverUseForceTry UseEarlyExits AlwaysUseLiteralForEmptyCollectionInit; do
    [ "$(jq -r --arg r "$rule" '.rules[$r]' .swift-format)" = "true" ] \
      && pass "rule on: $rule" || fail "rule not on: $rule (W54)"
  done
  # It must be a DELTA, not a dump-configuration dump.
  [ "$(jq '.rules | length' .swift-format)" -le 6 ] \
    && pass '.swift-format is a delta, not a dump' \
    || fail '.swift-format has too many rules — never `dump-configuration > .swift-format` (07 §5)'
else
  fail '.swift-format is not valid JSON'
fi

# 4. The formatter accepts the config on this toolchain.
xcrun swift-format lint --strict .swift-format >/dev/null 2>&1
[ $? -le 1 ] && pass 'swift-format reads the config' || fail 'swift-format rejected the config'

# 5. .gitignore ignores the right things and NOT the wrong ones (P44, P45).
for p in xcuserdata/x DerivedData/x .build/x .DS_Store Config/Local.xcconfig a.ipa a.hmap; do
  git check-ignore -q "$p" && pass "ignored: $p" || fail "not ignored: $p (P44)"
done
for p in Hunch.xcodeproj/project.pbxproj Config/Base.xcconfig Presubmission.xctestplan \
         Hunch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved; do
  git check-ignore -q "$p" && fail "wrongly ignored: $p (P43, P45)" || pass "committable: $p"
done

exit "$status"
```

**Step 2 — run it and watch it fail.** `bash /tmp/check-bootstrap.sh; echo "exit=$?"`
On a repo with zero commits every single line fails, and the first two fail because `git rev-parse main` finds nothing — that is the right reason. If it passes before you have written anything, the script is wrong, not the repo.

**Step 3 — implement.** The four files below.

**Step 4 — green, then refactor.** Re-run until every line reads `ok`, then push and re-run: rows 1 and 2 only turn green after `git push`.

## Files

| Action | Path |
|---|---|
| create | `README.md` |
| create | `.gitignore` |
| create | `LICENSE` |
| create | `.swift-format` |

## Implementation notes

### `.swift-format`

Copy `W54`'s JSON block **verbatim** from the `sed` command above. It is seven lines: `version`, `lineLength`, `indentation`, and four rules turned on. Do not add rules, do not run `dump-configuration > .swift-format` — that freezes all 43 rules at today's toolchain values, so the next Xcode silently leaves you on stale defaults and the post-bump audit diff (`xcrun swift-format dump-configuration | diff - .swift-format`) stops meaning anything (`07 §5`, `hunch-build-and-ci/references/swift-format.md` §5).

`NeverForceUnwrap` is on and flags every `!`, including sanctioned ones. The per-site suppression is `// swift-format-ignore: NeverForceUnwrap` with the proof written above it. A file-wide `// swift-format-ignore-file` is never the answer.

### `.gitignore`

`P44`'s list, plus the two HUNCH-specific entries, plus `P45`'s whitelist:

```gitignore
# Xcode
xcuserdata/
DerivedData/
*.hmap
*.ipa
*.dSYM
*.xcresult

# SwiftPM
.build/

# macOS
.DS_Store

# Machine-local build settings — the ONE xcconfig that is not committed (01 P43)
Config/Local.xcconfig

# P45: an app project's Package.resolved lives inside the implicit workspace.
# It must be committed, so whitelist it back after the xcuserdata rule above.
!Hunch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Two things this deliberately does **not** ignore: `Hunch.xcodeproj/` (it is committed in full, `P43`) and `*.xctestplan` (also committed). If you find yourself adding `*.xcodeproj/` you have copied a Tuist-shaped `.gitignore` — this repo generates nothing (`P42`).

The repo currently holds a `.DS_Store` at the root that was never committed; the rule above is what keeps it out. There is also an untracked `50-apps-challenge-slides.html` and `hunch-claude-code-prompt.md` at the root. `hunch-claude-code-prompt.md` **is the brief** — commit it in this task, because `SPEC.md` (T08) cites it and a cited artefact that is not in the repository is the failure `hunch-build-and-ci/references/source-hygiene.md` §8 names. `50-apps-challenge-slides.html` is unrelated to HUNCH; leave it untracked or delete it, and say which in the commit message.

### `README.md`

Short. It is read by a human deciding whether they can build the repo, and by `04 A45`, which asks you to record which side of the SwiftData question you are on. Sections, in this order:

1. **What HUNCH is** — one paragraph, in §1.13's approved register. "A rule-induction puzzle." Never "brain game", never "train your brain", never an exclamation mark. §1.13 is a compliance boundary and it binds this file.
2. **Requirements** — Xcode 26.6, iOS 18.0 floor, no third-party dependencies of any kind.
3. **Build** — `Config/Local.xcconfig` is gitignored and a fresh clone will not sign without it; give the three lines it needs (`DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, `HUNCH_BUNDLE_ID_PREFIX`) and point at `Config/Base.xcconfig` for everything else. This is the single most common "it does not build on my machine".
4. **The two loops** — `swift test --package-path HunchCore` (under 10 s, no simulator) and `xcodebuild test -scheme Hunch -testPlan Presubmission`. Note that `swift test --package-path Modules` is **not** a command in this repo (`hunch-build-and-ci/references/package-manifests.md` §5).
5. **Layout** — three lines pointing at `ios-swift-guide/08-APPLIED-TO-HUNCH.md` §1 for the tree, not a copy of it.
6. **Persistence** — the `A45` entry: *no SwiftData, no Core Data.* `Codable` JSON sharded per `GAME_DESIGN.md` §11.13, because the Codex is above `A40`'s JSON threshold in total and below it per file, and `Codex` therefore re-implements change notification by hand (`08 §7.5`, `§7.6`). One paragraph, and it is the only place in the README that argues.
7. **The documents** — one line each for `CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`, `tests.json`, marked "arriving in T08" until they do.

Do not put the game's rules in the README. `GAME_DESIGN.md` is canon and the README cites it.

### `LICENSE`

HUNCH is a paid, closed-source App Store app (`GAME_DESIGN.md` §14.5 decision 1, §14.4). An OSI licence would be actively wrong. Write a copyright notice:

```text
Copyright (c) 2026 Zakaria Fatahi. All rights reserved.

This software and its design documents are not licensed for redistribution,
modification or derivative works. No permission is granted by the presence of
this repository.
```

If the intent is in fact to open-source it, stop and ask — this is a one-line change now and an irreversible one after publication. Record whichever way it goes in `DECISIONS.md` (T08).

## Acceptance criteria

- [ ] `bash /tmp/check-bootstrap.sh` exits 0 with every line reading `ok`.
- [ ] `git log --oneline main` shows the bootstrap commit and `git rev-parse main` equals `git rev-parse origin/main`.
- [ ] `git ls-files` lists exactly `.gitignore`, `.swift-format`, `LICENSE`, `README.md`, `GAME_DESIGN.md`, `hunch-claude-code-prompt.md`, the `ios-swift-guide/` files, the `design/` files, the `.claude/skills/` files and the `epics/` files — and nothing under `DerivedData/`, `.build/` or `xcuserdata/`.
- [ ] `jq '.rules | length' .swift-format` is `4` and `jq '.indentation.spaces' .swift-format` is `4`.
- [ ] `xcrun swift-format dump-configuration | diff - .swift-format` prints a diff consisting only of defaults you did not override (this is the audit baseline; record the date you ran it in `DECISIONS.md` at T08).
- [ ] `grep -riE 'brain|cognitive|memory|focus|IQ|sharper|smarter|train your|workout|!' README.md` returns nothing (§1.13).
- [ ] `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` is `main`.

## Close the task

1. There is no `swift test` yet — the fast suite arrives in T03. Run `bash /tmp/check-bootstrap.sh` instead and require exit 0.
2. **Run `/simplify`** — there is little code, so expect it to touch the README's structure and the `.gitignore` ordering. Re-run the check after it.
3. **Run `/code-review`** — the working diff is four files; the review that matters is §1.13 compliance in the README and `P44`/`P45` correctness in `.gitignore`. Fix what it finds.
4. Commit **directly to `main`** and push:
   `git commit -m "E01/T01: bootstrap main with README, .gitignore, LICENSE and .swift-format"` then `git push -u origin main`.
5. Confirm on the remote before starting T02: `git ls-remote --heads origin main`.

## Out of scope

- **`Hunch.xcodeproj`, `Config/`, `App/`** — T02. This task creates no build system.
- **`Scripts/`** — T06 and T09. `/tmp/check-bootstrap.sh` is scratch and is never committed.
- **`CLAUDE.md`, `SPEC.md`, `DECISIONS.md`, `PROGRESS.md`, `tests.json`** — T08. The README references them as forthcoming.
- **The pre-commit hook** — T06 (`hunch-build-and-ci/references/source-hygiene.md` §6). It cannot run the hygiene script before the hygiene script exists.
- **Branch protection on `main`** — deliberately not enabled in this task, because T01 must push to it directly. Enable it after E01 merges, if at all; the epic loop's `gh pr checks --watch` is the real gate.
