# T04 — Zero play-surface strings

| | |
|---|---|
| **Epic** | E18 — Localization |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | LOCALIZATION → Zero play-surface strings |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns the gate roster and the reason this is a lint at all: neither a String Catalog nor a repo-relative source file exists inside a test bundle, so §12.9's `PlaySurfaceTextTests` cannot be a runtime test (`08 §5`). `references/source-hygiene.md` §2 holds check 7 as it stands, §3 the conventions any appended check must follow, §4 the prove-it-can-fail drill, and it states check 7's two known properties — it is line-based and cannot see nesting, and `PLAY-TEXT-EXEMPT` is the rare-wrap escape. |

`hunch-accessibility` **owns** check 7 by the roster, but is not loaded here: this task changes no
label, no trait and no element. It extends the lint. If a check-7 hit turns out to be a genuine
labelling problem rather than a stray `Text`, that is an escalation to `hunch-accessibility` and not
a fix in this file — the constraint is zero characters in any locale, so the exemption comment is
the last resort, not the first.

## Objective

At the end of this task the claim *"the play surface has zero strings — not few, zero"* is a build
failure rather than a review habit, proved by planting a violation in a real play-surface file for
the first time since E01 deferred that proof here. Both of §12.9 trap 1's spellings become
impossible **app-wide**: a `Text(` whose argument's static type is `String` (never extracted,
English forever) and a bare `Text("literal")` (extracted, but resolved against `Bundle.main` and
therefore English until the next cold launch).

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.9 (opening paragraph) | the six files by name, and that the ban covers `Text`, `Label` and `AttributedString` outside an `.accessibility*` modifier |
| `GAME_DESIGN.md` | §12.9 (The traps, named — trap 1) | both spellings, and why a bare literal that *is* extracted is still a bug |
| `GAME_DESIGN.md` | §12.8 (VoiceOver) | a wordless surface is not an unlabelled one — accessibility labels are exempt and required |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B39` | `Text(someString)` is never extracted; the grep exists because the compiler will not say so |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5, check 7 | why this is a `Scripts/` lint and not a package test |
| `.claude/skills/hunch-accessibility/SKILL.md` | "The rule" | a `Loc` accessor returns an already-resolved `String`, so **every** legal call site in the app is `Text(verbatim:)` — which is what makes the app-wide rule a one-line grep |

The six play-surface files are §12.9's and are already in check 7's `play` variable; do not retype
the list.

## TDD — the test comes first

A lint's only honest test is a planted violation. `references/source-hygiene.md` §4 is the drill and
this task runs it five times.

**Step 1 — write the failing test.** Before touching the script, prove each violation is currently
**undetected**. Run the script, plant, run again, and record that the second run is still green:

```bash
bash Scripts/check-source-hygiene.sh; echo "exit=$?"           # baseline: clean, exit=0

# (1) check 7, for real, in a real play-surface file — the proof E01·T06 deferred to E08·T01
#     and which is re-run here now that all six files exist.
printf '\n// planted\nprivate let planted = Text("PROBE")\n' \
  >> Modules/Sources/LoomFeature/RoundView.swift

# (2) trap A — a String-typed argument. Never extracted; English forever (07 B39).
printf '\n// planted\nprivate func planted(_ m: Mode) -> Text { Text(m.wordmark) }\n' \
  >> Modules/Sources/MetaFeature/StatisticsView.swift

# (3) trap B — a bare literal outside the accessor. Extracted, but bypasses `loc`.
printf '\n// planted\nprivate let planted = Text("Clear Codex")\n' \
  >> Modules/Sources/MetaFeature/SettingsView.swift

# (4) a stock-control literal — the same trap wearing a different initializer.
printf '\n// planted\nprivate let planted = Toggle("Haptics", isOn: .constant(true))\n' \
  >> Modules/Sources/MetaFeature/SettingsView.swift

# (5) an accessibility literal — extracted, bypasses `loc`, and lives on the play surface.
printf '\n// planted\nprivate let planted = Color.clear.accessibilityLabel("Loom throat")\n' \
  >> Modules/Sources/LoomFeature/BenchView.swift

bash Scripts/check-source-hygiene.sh; echo "exit=$?"
```

Violation 1 must already fail (check 7 exists). **Violations 2–5 must pass**, and that is the
failing test: the script is green over five real bugs. Revert all five before writing a line:

```bash
git checkout -- Modules/Sources/LoomFeature/RoundView.swift \
                Modules/Sources/LoomFeature/BenchView.swift \
                Modules/Sources/MetaFeature/StatisticsView.swift \
                Modules/Sources/MetaFeature/SettingsView.swift
```

**Step 2 — run it and watch it fail.** The recorded output of the second run *is* the failure, and
it must be pasted into `.github/pr-body.md` beside the passing output from step 4. A lint task with
no before-and-after is a lint task that proves nothing.

**Step 3 — implement** the two appended checks, below.

**Step 4 — green, then refactor.** Re-run all five plants. Every one must now exit 1 and name its
check, its file and its line; then revert and confirm a clean tree exits 0.

## Files

| Action | Path |
|---|---|
| modify | `Scripts/check-source-hygiene.sh` — append two checks; leave check 7 exactly as it is |
| modify | `.github/pr-body.md` — the before-and-after output of all five plants |
| modify | `tests.json` — three entries: `PlaySurfaceTextTests` (check 7, now proved), trap A, trap B |
| modify | `PROGRESS.md` — record that check 7's real proof, deferred in E01·T06, has now been taken |

No Swift changes. If a plant reveals a real violation already in the tree, fix that file too and
list it here.

## Implementation notes

### Why this is not a test, restated in the script

Write the reason into the comment, because it is the first thing a reviewer will challenge:

> A String Catalog is compiled to `.lproj` at build time and the source is repo-relative, so neither
> artifact exists inside a test bundle. §12.9 calls this `PlaySurfaceTextTests`; it is a source
> lint. — `08 §5`

### The rule the two checks encode

`hunch-accessibility` fixes one spelling for the whole app: **a `Loc` accessor returns an
already-resolved `String`, so every legal call site is `Text(verbatim:)`.** That collapses trap A
and trap B into a single, checkable statement:

> The only legal `Text(` and `Label(` in `Modules/Sources` is `Text(verbatim:` / `Label(verbatim:`.

- `Text(loc[.foo])` is trap A — a `String`-typed argument. Not extracted, never translated, and it
  compiles.
- `Text("Clear Codex")` is trap B — extracted, so a translator sees it, but resolved against
  `Bundle.main`'s launch-time localization, so it stays English until the next cold launch. That is
  §12.9's *"most of the app's strings"* failure.
- `Text(verbatim: loc[.foo])` is correct in both directions: the string is already resolved through
  the override-carrying accessor, and `verbatim:` states that at the call site.

### Check N — `Text(` and `Label(`, app-wide

Determine the next free number first; the roster has grown since E01 and checks are appended, never
renumbered:

```bash
grep -oE '^# +[0-9]+\.' Scripts/check-source-hygiene.sh | tail -1
```

```bash
# N. §12.9 trap 1, both spellings. The only legal Text/Label in the app is `verbatim:`, because a
#    Loc accessor returns an already-resolved String (hunch-accessibility). A String-typed argument
#    is never extracted (07 B39); a bare literal IS extracted but bypasses the override accessor
#    and stays English until the next cold launch (§12.9, trap 2).
uiRoots=(); for d in Modules/Sources; do [ -d "$d" ] && uiRoots+=("$d"); done
if [ "${#uiRoots[@]}" -gt 0 ]; then
  hits=$(
    grep -rHnE '\b(Text|Label)\(' --include='*.swift' "${uiRoots[@]}" \
      | grep -vE '\b(Text|Label)\(verbatim:' \
      | grep -vE '\b(Text|Label)\(\s*$' \
      | grep -vE 'LOC-EXEMPT' || true
  )
  [ -n "$hits" ] && report 'Text/Label without verbatim: (§12.9 trap 1) — go through `loc`:' "$hits"
fi
```

Three details, each of which decides whether the check survives its first week:

- **`grep -H`**, because a single-file match omits the filename and a report nobody can act on is a
  report somebody disables. This is the same lesson check 7 already carries.
- **`Text(` at end of line is skipped.** `Label(title:icon:)`'s trailing-closure form and any
  multi-line call open with `Text(` and continue below; flagging those makes the check noisy and
  it will be commented out. The cost is that a multi-line `Text(` *is* invisible to this check —
  which is acceptable, because the idiom everywhere in this codebase is one line, and because
  check 7 still covers the six files where it matters most.
- **`LOC-EXEMPT`, not `PLAY-TEXT-EXEMPT`.** Check 7's escape means *"this line wraps a
  `.accessibility*` modifier oddly"*; this one would mean *"this string is deliberately not
  localized"*, which is a different claim with different reviewers. Keep them distinguishable in a
  diff. The only legitimate uses today are the DEBUG snapshot gallery's specimen labels (E04·T09,
  which already uses `verbatim:` and needs no exemption) and nothing else.

### Check N+1 — stock-control and modifier literals

`Text(` is not the only initializer that takes a `LocalizedStringKey`. `Toggle("Haptics", …)`,
`Section("Display")`, `Button("Cancel")` and `.accessibilityLabel("Loom throat")` are all trap B
with a different spelling, and `hunch-chrome-and-meta` `references/stock-controls.md` names the four
screens where stock controls are permitted at all — so the list is closed and short.

```bash
# N+1. The same trap in the stock controls and the accessibility modifiers. The list is closed:
#      references/stock-controls.md names the only four screens allowed a stock component, so a
#      spelling that is not here is a spelling that should not exist. Add to the list, never widen
#      it to a bare-literal grep — that would flag every identifier and every format specifier.
if [ "${#uiRoots[@]}" -gt 0 ]; then
  stock='(Toggle|Button|Section|Picker|NavigationLink|Stepper|TextField|Link)\("'
  modifier='\.(navigationTitle|accessibilityLabel|accessibilityValue|accessibilityHint|accessibilityInputLabels)\("'
  hits=$(grep -rHnE "$stock|$modifier" --include='*.swift' "${uiRoots[@]}" | grep -vE 'LOC-EXEMPT' || true)
  [ -n "$hits" ] && report 'A localizable literal outside `loc` (§12.9 trap 1):' "$hits"
fi
```

**Do not widen this to "any string literal in a view file".** Accessibility *identifiers* are string
literals and are deliberately never localized (`hunch-accessibility` §6: "identifiers are not labels
and are never localized"); so are `#bundle` resource names, `UserDefaults` keys under
`hunch.settings.`, and every `LocKey` raw value. A check that flags all of those gets a blanket
exemption comment within a week and then protects nothing.

### What check 7 is, and why it is not touched

Check 7 is stricter than these two inside the six play-surface files: it bans `Text`, `Label`,
`AttributedString`, `LocalizedStringKey` and `LocalizedStringResource` **entirely**, outside an
`.accessibility*` modifier. That is the right asymmetry — the play surface renders zero characters,
so even `Text(verbatim:)` is wrong there unless it is inside a label. Leave it exactly as E01·T06
wrote it and add nothing to its file list; E12, E13 and E14 have already added
`EchoRoundView`, `SieveRoundView` and `SievePauseOverlay` to the surfaces, and §12.9's six names are
the normative set.

### If a plant does not fail

The most likely cause is `pipefail` plus a clean `grep`: a `grep` with no `|| true` exits 1, and
under `set -uo pipefail` that aborts the script at the first *clean* category, so every check after
it silently never runs (`07 §9.1`). Check the `|| true` on every new pipeline, and confirm by
planting a violation in a **later** check and watching both reports appear in one run —
`references/source-hygiene.md` §4 step 3 exists for exactly this.

## Acceptance criteria

- [ ] `bash Scripts/check-source-hygiene.sh` exits 0 on a clean tree and prints `Source hygiene: clean`.
- [ ] Each of the five plants, run one at a time, makes the script exit 1 and name its check, its file and its line. All five outputs, before and after, are in `.github/pr-body.md`.
- [ ] Two plants in one run produce **two** reports, not one — proving no `|| true` is missing.
- [ ] `grep -rnE '\b(Text|Label)\(' Modules/Sources --include='*.swift' | grep -vE 'verbatim:|\($' ` returns nothing on the clean tree.
- [ ] `grep -c 'LOC-EXEMPT' Modules/Sources -r` is 0; if it is not, every hit carries a reason on the same line or the line above, matching check 3's two-line window convention.
- [ ] `tests.json` carries three entries — `PlaySurfaceTextTests`, trap A and trap B — each with the runnable plant-and-check command.
- [ ] `PROGRESS.md` records that check 7's real proof, deferred in E01·T06, has been taken against `RoundView.swift`.
- [ ] The fast suite is still under 10 s (this task adds no Swift).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E18/T04: PlaySurfaceTextTests proved, and both Text( traps linted app-wide"`

## Out of scope

- **Check 7 itself** — **E01·T06** wrote it; this task proves it and leaves it alone.
- **The `loc[.key]` accessor and the migration to it** — **T01**. This check assumes it exists.
- **Which accessibility labels the play surface carries** — **E19·T01**. This task asserts only
  that whatever they are, they go through `loc`.
- **The RTL `left`/`right` lint** — **T06**, which appends its own check for a different rule.
- **The `count == 1` and concatenation lints** — **T07**.
- **The banned-lexeme checker** — **T08**. That one reads values; this one reads call sites.
