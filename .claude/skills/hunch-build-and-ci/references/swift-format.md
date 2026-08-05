# `swift-format` — where it lives, where it runs, and where it must not

1. [The three places it runs, and the one it never does](#1-the-three-places-it-runs-and-the-one-it-never-does)
2. [The committed configuration](#2-the-committed-configuration)
3. [The roots to lint in this repo](#3-the-roots-to-lint-in-this-repo)
4. [Three spellings of the same binary](#4-three-spellings-of-the-same-binary)
5. [The audit after a toolchain bump](#5-the-audit-after-a-toolchain-bump)
6. [Suppressions](#6-suppressions)
7. [What the formatter must not be asked to enforce](#7-what-the-formatter-must-not-be-asked-to-enforce)

---

## 1. The three places it runs, and the one it never does

| Task | Where | Command |
|---|---|---|
| Format | on save in the editor, and in the pre-commit hook | `xcrun swift-format format --in-place` |
| Lint | its own CI job, on Linux | `swift format lint --strict --recursive <roots>` |
| Warnings-as-errors | the Release build, not Debug | `OTHER_SWIFT_FLAGS` in `Config/Release.xcconfig` (`07 B18`) |

**Never a build phase.** `07 B17` gives three independent reasons and each is checkable here: a formatter has no meaningful inputs or outputs to declare, so it re-runs on every incremental build serially (`07 B15`); it writes across the whole source root, which `ENABLE_USER_SCRIPT_SANDBOXING = YES` denies, and the workaround everyone reaches for is disabling sandboxing project-wide; and it mutates files underneath the compiler mid-build. A large part of the community does exactly this — expect to be told it is normal.

A **lint-only** phase with declared inputs is defensible if you want in-Xcode signal. HUNCH does not have one: the repo already spends its one run-script phase on the hygiene script (`source-hygiene.md` §5), and a second always-running phase doubles that tax for a rule the pre-commit hook already catches.

The hook is in `source-hygiene.md` §6. It formats the staged files, re-stages them, then runs the fast hygiene subset — formatting *before* re-staging is what stops a commit whose content differs from what you reviewed.

---

## 2. The committed configuration

`.swift-format` at the **repo root**, and one file covers both packages and the app: swift-format looks in the file's own directory then walks up parents (`01 P39`). It is committed (`01 P43`).

**Its contents are `03 W54`'s single copy — do not retype them here or anywhere else.** Print them:

```bash
sed -n '/^\*\*W54\./,/^\*\*W55\./p' ios-swift-guide/03-WRITING-THE-CODE.md
```

What that rule ships is a **delta**, not a dump: 43 rules with 31 already on, so the committed file turns on four and sets two values. `07 §5` is explicit about the alternative — **never `dump-configuration > .swift-format`**, because it freezes every rule at today's toolchain values, so the next Xcode silently leaves you on stale defaults and §5's audit diff stops meaning anything.

---

## 3. The roots to lint in this repo

```bash
xcrun swift-format format --in-place --recursive \
  App HunchCore/Sources HunchCore/Tests Modules/Sources Modules/Tests HunchAutomationTests
```

**List source roots, not package roots.** `--recursive HunchCore` would walk into `HunchCore/.build`, lint thousands of generated files and report violations you cannot fix. Naming `Sources` and `Tests` sidesteps it without needing an ignore file.

`HunchAutomationTests` is the XCUITest bundle (`package-manifests.md` §3). `HunchTests/` — the wizard-made target that stays nearly empty (`01 P22`, `P40`) — has nothing to lint until it does.

---

## 4. Three spellings of the same binary

| Context | Spelling | Why |
|---|---|---|
| macOS, terminal | `xcrun swift-format` | hyphen; resolves through the selected Xcode |
| Linux container, CI | `swift format` | **space, not dash.** Swift 6 toolchains include it, which is why the lint container needs no install step |
| Xcode | Editor ▸ Structure ▸ Format File with 'swift-format' (⌃⇧I) | the only in-IDE entry point |

There is no format-on-save in Xcode 26.6 (`03 W54`'s stated deviation); the community workaround is a System Settings keyboard shortcut bound to that menu item. The pre-commit hook is what makes the absence not matter.

---

## 5. The audit after a toolchain bump

Defaults move between releases, and the whole point of committing only the delta is that this diff stays readable:

```bash
xcrun swift-format dump-configuration | diff - .swift-format
```

**Read the diff; do not apply it.** A line appearing there means one of two things — a default moved (leave your file alone, the delta shrank or grew by one rule) or your file drifted from what `W54` asks for (fix your file). Overwriting `.swift-format` with the dump destroys the distinction permanently.

Run it whenever `xcodebuild -version` changes, and record the outcome in `DECISIONS.md` if a default moved under you.

---

## 6. Suppressions

`NeverForceUnwrap` is on (`03 W54`), and it flags every `!` including the sanctioned one. HUNCH's own rule is stricter — `03 W25`, no bare `!` — so a suppression here should be rare enough to be a reviewable event:

```swift
// swift-format-ignore: NeverForceUnwrap
let deck = Deck.glyph(id: 0)!   // Deck.all is 256 entries; id 0 is a compile-time constant.
```

The comment above it is the proof, not decoration. A file-wide `// swift-format-ignore-file` is never the answer: it silences 31 rules to buy one, and nothing in the repo tells you later which one you wanted.

---

## 7. What the formatter must not be asked to enforce

- **Naming.** `02-NAMING-AND-API-DESIGN.md` owns it, and `07 §5` is direct: encoding naming conventions as lint regexes produces false positives faster than value. The banned-filename check (`01 P28`) is check 1 of the hygiene script precisely because it is a *filename* rule, which a regex can actually decide.
- **Token literals, network symbols, play-surface text, catalog completeness.** All of them are hygiene checks. A formatter reformats; it does not refuse.
- **A second formatter.** `03 W56` — `swift-format` and nicklockwood/SwiftFormat will fight. One formatter.
- **SwiftLint.** `03 W56` and `07 §16` add it only when you have a *team* and want rules a formatter cannot express — cyclomatic complexity, file length, forbidden APIs. It is a second tool, a second config file and a second CI job; HUNCH has one author and a hygiene script that already covers the forbidden-API case.
