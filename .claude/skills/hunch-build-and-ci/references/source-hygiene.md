# `Scripts/check-source-hygiene.sh` — the ten checks, assembled

1. [Where each check's text comes from](#1-where-each-checks-text-comes-from)
2. [The skeleton, and checks 5–8 in full](#2-the-skeleton-and-checks-58-in-full)
3. [Conventions every check must follow](#3-conventions-every-check-must-follow)
4. [Proving a check can fail](#4-proving-a-check-can-fail)
5. [The Xcode run-script phase, and the sandbox](#5-the-xcode-run-script-phase-and-the-sandbox)
6. [The pre-commit hook](#6-the-pre-commit-hook)
7. [The checkers that are not greps](#7-the-checkers-that-are-not-greps) —
   [7.1 `check-inventory.sh`](#71-scriptscheck-inventorysh) ·
   [7.2 `check-symbols.sh`](#72-scriptscheck-symbolssh) ·
   [7.3 `check-skills.sh`](#73-scriptscheck-skillssh) ·
   [7.4 proving they fail](#74-proving-these-three-can-fail)
8. [What would be wrong](#8-what-would-be-wrong)

---

## 1. Where each check's text comes from

**Once `Scripts/check-source-hygiene.sh` exists, it is the single copy.** Every document below, this one included, becomes a recipe for building it and stops being normative for its text. That is why `SKILL.md` opens by reading the live check roster out of the script rather than listing it.

| # | Source of the code | Do this |
|---|---|---|
| 1–4 | `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` §9.1 (`B34a`) — the script is printed there in full | paste verbatim; the four footnotes under it explain the `awk` range, the `\|\| true`, the two-line window and the `describe --type json` choice |
| 5–8 | **this file, §2** — written nowhere else | paste from below |
| 9–10 | `.claude/skills/hunch-design-tokens/references/tokens-swift-layout.md` §6.1 | paste verbatim; `hunch-design-tokens` owns the literal ban and the `TOKENS-EXEMPT` convention |

```bash
# Print the two blocks you do not own, side by side, instead of retyping either.
sed -n '/^#!\/bin\/bash/,/^exit "\$status"/p' ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md
sed -n '/^# 9\./,/^\[ -n "\$hits" \] && report .Minting/p' \
  .claude/skills/hunch-design-tokens/references/tokens-swift-layout.md
```

Numbering is fixed. Checks are appended, never renumbered, because every other skill in this library cites them by number.

---

## 2. The skeleton, and checks 5–8 in full

```bash
#!/bin/bash
# Scripts/check-source-hygiene.sh — every rule this repo states that the compiler cannot check.
# Run from the repo root. Prints every category that has offenders, then exits 1.
#   --fast   skip the checks that need a Swift toolchain or jq (4 and 8): the build-phase subset.
set -uo pipefail

roots=(App HunchCore/Sources HunchCore/Tests Modules/Sources Modules/Tests)
core=HunchCore/Sources
catalog=Modules/Sources/HunchUI/Resources/Localizable.xcstrings
fast=0; [ "${1:-}" = "--fast" ] && fast=1
status=0

report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Day-one guard: the tree is built target by target (01 P12), so drop roots that do not exist
# yet rather than filling the log with "No such file or directory" and training people to skim it.
present=(); for d in "${roots[@]}"; do [ -d "$d" ] && present+=("$d"); done
roots=("${present[@]}")
if [ "${#roots[@]}" -eq 0 ]; then echo 'No Swift source roots yet — nothing to check.'; exit 0; fi

# 1. Banned file names — 01 P28.            [paste from 07 §9.1]
# 2. Snapshot record mode — 06 T51.         [paste from 07 §9.1]
# 3. Undocumented escape hatch — 05 R29.    [paste from 07 §9.1]
# 4. TestSupport reachable from the app — 06 T5a.  [paste from 07 §9.1; needs swift + jq]
#    Guard it:  if [ "$fast" -eq 0 ]; then … fi   — and pass --package-path HunchCore.

# 5. No network, anywhere. The brief's hard constraint and its mandated build-phase grep.
#    Imports and symbols both, because `import Network` alone is already a violation.
net='URLSession|URLRequest|NSURLSession|NSURLConnection|CFNetwork|CFURL(Request|Connection)'
net="$net"'|NWConnection|NWListener|NWBrowser|NWPathMonitor|CKContainer|CKDatabase|CKRecord'
net="$net"'|WKWebView|SFSafariViewController|getaddrinfo|Socket\('
net="$net"'|^[[:space:]]*(public |package |internal )?import[[:space:]]+(Network|CloudKit|WebKit|SafariServices|SystemConfiguration)\b'
hits=$(grep -rnE "$net" --include='*.swift' "${roots[@]}" || true)
[ -n "$hits" ] && report 'Network API in an app that has no network (the brief):' "$hits"

# 6. No ambient nondeterminism inside HunchCore — 08 §4, the boundary predicate's half (b).
#    Two passes: the RNG family is legal WITH `using:` (a threaded SplitMix64) and illegal
#    without it, so filtering that one line-substring is the difference between a check people
#    trust and a check people comment out.
rng='SystemRandomNumberGenerator|\.random\(|randomElement\(|shuffled\(|randomizedElement'
hits=$(grep -rnE "$rng" --include='*.swift' "$core" | grep -v 'using:' || true)
[ -n "$hits" ] && report 'Unseeded randomness in HunchCore (08 §4) — thread `using: &rng`:' "$hits"

ambient='Date\(\)|Date\.now|UUID\(\)|ProcessInfo|Locale\.current|TimeZone\.current|Calendar\.current'
ambient="$ambient"'|CFAbsoluteTimeGetCurrent|DispatchTime\.now|ContinuousClock|SuspendingClock|Task\.sleep'
hits=$(grep -rnE "$ambient" --include='*.swift' "$core" || true)
[ -n "$hits" ] && report 'Ambient clock/locale/identity in HunchCore (08 §2, §5) — take it as a parameter:' "$hits"

# 7. Zero characters on the play surface, in any locale — §12.9, owner hunch-accessibility.
#    Strings exist there only inside .accessibility* modifiers.
play='RoundView|EchoRoundView|SieveRoundView|BenchView|AssayInspectorView|InscriptionView'
surface=$(find Modules/Sources -name '*.swift' 2>/dev/null | grep -E "/($play)\.swift$" || true)
if [ -n "$surface" ]; then
  hits=$(
    grep -HnE '\b(Text|Label|AttributedString|LocalizedStringKey|LocalizedStringResource)\b' $surface \
      | grep -vE 'accessibility|PLAY-TEXT-EXEMPT' || true
  )
  [ -n "$hits" ] && report 'Text on the play surface (§12.9) — the surface renders no characters:' "$hits"
fi

# 8. The String Catalog — the brief's invariant 5. Needs jq; skipped under --fast.
if [ "$fast" -eq 0 ]; then
  want='ar de en es fr it ja ko pt-BR ru tr zh-Hans'          # the brief's twelve, sorted
  if [ ! -f "$catalog" ]; then
    report 'String Catalog missing (01 P35):' "$catalog"
  else
    keys=$(jq '.strings | length' "$catalog")
    [ "$keys" -le 250 ] || report "String Catalog over budget — $keys keys, the ceiling is 250 (§12.9):" "$catalog"

    have=$(jq -r '[.strings[].localizations? // {} | keys[]] | unique | join(" ")' "$catalog")
    [ "$have" = "$want" ] || report 'Locale set is not the brief’s twelve:' "want: $want
have: $have"

    hits=$(jq -r '
      .strings | to_entries[] as $e
      | ($e.value.localizations? // {}) | to_entries[] as $l
      | [$l.value | .. | objects | select(has("state")) | .state]
      | select(any(. == "new" or . == "needsReview"))
      | "\($e.key)  [\($l.key)]"' "$catalog")
    [ -n "$hits" ] && report 'Untranslated or needs-review entries (brief invariant 5):' "$hits"

    hits=$(jq -r --arg want "$want" '
      ($want | split(" ")) as $w
      | .strings | to_entries[]
      | select(.value.shouldTranslate != false)
      | ($w - ((.value.localizations? // {}) | keys)) as $gap
      | select($gap | length > 0) | "\(.key)  missing \($gap | join(","))"' "$catalog")
    [ -n "$hits" ] && report 'Keys missing a locale (brief invariant 5):' "$hits"

    hits=$(jq -r '
      [ .strings | to_entries[] | select(.value.shouldTranslate != false)
        | { k: .key, v: (.value.localizations.en.stringUnit.value // .key) } ]
      | group_by(.v) | map(select(length > 1))[] | map(.k) | join("  /  ")' "$catalog")
    [ -n "$hits" ] && report 'Two keys with identical English — the translations will diverge:' "$hits"

    # §1.13's per-locale banned lexemes live in one file, not in this script.
    if [ -f Scripts/banned-lexemes.txt ]; then
      while IFS=$'\t' read -r loc word; do
        [ -z "${loc:-}" ] && continue
        case "$loc" in '#'*) continue ;; esac
        hit=$(jq -r --arg l "$loc" --arg w "$word" '
          .strings | to_entries[]
          | select( ((.value.localizations[$l]? // {}) | [.. | strings] | any(test($w; "i"))) )
          | .key' "$catalog")
        [ -n "$hit" ] && report "Banned lexeme \"$word\" in $loc (§1.13):" "$hit"
      done < Scripts/banned-lexemes.txt
    fi
  fi
fi

# 9. Literal colour/dimension/opacity/duration outside Tokens/.  [paste from tokens-swift-layout.md §6.1]
# 10. Minting a register colour outside Tokens.                  [paste from tokens-swift-layout.md §6.1]

label=""; [ "$fast" -eq 1 ] && label=" (fast subset)"
[ "$status" -eq 0 ] && echo "Source hygiene: clean$label"
exit "$status"
```

Checks 5–7 were run against a deliberately dirty tree and a clean one before being written down (§4). Two BSD-grep details came out of that and are load-bearing:

- **`(public |package |internal |)?` is `grep: empty (sub)expression` on BSD grep**, which is what macOS ships. An empty alternation branch is a GNU extension; write `(public |package |internal )?` and let the `?` carry the empty case. The failure is a *stderr line*, not a non-zero exit, so without it check 5 silently checks nothing.
- **`grep -H`, because the play-surface set is often one file.** grep omits the filename when given a single path, and a report that says `5: Text("PROBE")` with no file is a report nobody can act on.

**Check 6's `using:` filter is the design decision in that block.** `Int.random(in: 0..<5, using: &rng)` is deterministic and legal (`08 §4`: randomness is a parameter, never an ambient); a bare `.random(in:)` is not. A check that flags the legal spelling gets suppressed within a week, and a suppressed check protects nothing.

**Check 7 is line-based and cannot see nesting.** `.accessibilityLabel(Text(Loc.seal))` on one line passes; the same modifier split across three lines would be flagged. That is the correct bias — the idiom the accessibility skill prescribes is one line, and the `PLAY-TEXT-EXEMPT` escape exists for the rare wrap. **An exemption on check 7 is a design escalation, not a build fix**: the constraint is zero characters in any locale, so reach for `hunch-accessibility` before reaching for the comment.

**`Scripts/banned-lexemes.txt`** is `locale<TAB>lexeme`, one per line, `#` for comments. The list is `GAME_DESIGN.md` §1.13's and has exactly one home; do not inline it into the script.

---

## 3. Conventions every check must follow

- **`|| true` on every `grep` and `find`.** Finding nothing exits 1, and under `pipefail` that aborts the script at the first *clean* category — so the checks after it silently never run (`07 §9.1`).
- **Never end on `grep -q … && exit 1`.** Clean means grep exits 1, which becomes the script's status. Capture, test with `if`/`[ -n … ]`, end on a command that exits 0 (`07 B6`).
- **POSIX classes, not `\s`.** `[[:space:]]` works in every grep you will meet.
- **`awk` ranges, not `grep -A20`,** for anything block-shaped: a fixed window runs past the block's close and reports clean files as dirty.
- **The escape hatch is a comment on the line or the line above,** matching check 3's two-line window: `// TOKENS-EXEMPT: <reason>`, `// PLAY-TEXT-EXEMPT: <reason>`, and in markdown `<!-- CHECK-EXEMPT: <reason> -->` for §7's three library checkers. A hatch with no reason is the thing being checked for.
- **A checker that reads markdown skips fenced blocks.** A ``` fence is an example, and a checker that cannot tell an example from a citation fails on its own documentation — which is how a gate gets waived in its first week. §7's three all share one `prose()` helper for this, and it blanks fenced lines rather than deleting them so reported line numbers still point at the real line.
- **One `report` call per category, listing every offender.** Fixing them one build at a time is how a ten-minute cleanup becomes a ten-build cleanup.
- **Every check names its owning rule in its comment** (`01 P28`, `06 T51`, …). Six months from now that citation is the only way to know whether the check or the rule is the thing that moved.

---

## 4. Proving a check can fail

A check that cannot fail is worse than no check, because it converts an absence of evidence into a green tick (`07 B6`). Before a new check is committed:

```bash
# 1. Green on a clean tree.
Scripts/check-source-hygiene.sh; echo "exit=$?"          # expect: clean, exit=0

# 2. Red on a deliberate violation — one per new check, reverted immediately.
printf '\nlet x = Color(red: 1, green: 0, blue: 0)\n' >> Modules/Sources/HunchUI/Palette.swift
Scripts/check-source-hygiene.sh; echo "exit=$?"          # expect: check 9 names that file, exit=1
git checkout -- Modules/Sources/HunchUI/Palette.swift

# 3. Red on the SECOND category too — a script that stops at the first failure hides the rest.
```

Step 3 is the one people skip, and it is the one the `|| true` convention exists for.

---

## 5. The Xcode run-script phase, and the sandbox

The brief mandates a build-phase grep for network APIs. `07 B14` keeps `ENABLE_USER_SCRIPT_SANDBOXING = YES`, under which a script may only read files declared as inputs. Those two pull against each other and the resolution is deliberate.

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
    $(SRCROOT)/Modules/Sources

  Output Files:  (none — deliberately)
```

Three decisions in that box:

- **`--fast`.** Checks 4 and 8 need `swift package describe` and `jq`; neither is guaranteed on a sandboxed build-phase PATH, and both are slow. They run in CI, where the toolchain and `jq` are already present (`07 §9.1`).
- **Inputs are declared to buy sandbox read access**, not to drive re-runs.
- **No outputs, on purpose.** `07 B15` rule 2 means the phase then runs on **every** build, serially. That is the price of the brief's build-phase gate, taken knowingly. Measure it once with `Product ▸ Perform Action ▸ Build With Timing Summary` (`07 B16`); if the phase costs more than ~0.5 s, cut it to check 5 alone — that is the only check the brief requires at build time.

**If the sandbox denies the read** — `Sandbox: bash(…) deny(1) file-read-data …` in the build log — the fallback order is: (1) declare the specific subdirectories that were denied; (2) drop the phase to check 5 with a narrower input set; (3) delete the phase, keep the pre-commit hook and CI, and record it in `DECISIONS.md`. **Never set `ENABLE_USER_SCRIPT_SANDBOXING = NO`** — that trades a real security control for a convenience, and it is the exact move `07 B14` and `B17` both name as the wrong one.

Verify after the first clean build:

```bash
xcodebuild build -scheme Hunch -destination 'generic/platform=iOS' 2>&1 | grep -c 'deny(1)'   # expect 0
```

---

## 6. The pre-commit hook

The formatter and the fast checks belong here, where they are free and reversible — not in a build phase (`07 B17`).

```bash
# .git/hooks/pre-commit  (chmod +x; not versioned, so document it in CLAUDE.md)
#!/bin/bash
set -uo pipefail
changed=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
[ -n "$changed" ] && xcrun swift-format format --in-place $changed && git add $changed
Scripts/check-source-hygiene.sh --fast || exit 1
```

Formatting *then* re-staging is what stops the hook from producing a commit whose content differs from what you reviewed. Everything slower than this — the full hygiene run, the tests, the token check — is CI's job.

---

## 7. The checkers that are not greps

Eight checks need a parse, a toolchain or a runtime, so they are separate programs. CI runs them in this order, cheapest first, so the common failure is reported in seconds (`ci-workflow.md` §3 is the wiring).

| Command | Asserts | Owner |
|---|---|---|
| `Scripts/check-source-hygiene.sh` | the ten checks above | this skill |
| `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj` | every `buildSettings = { … }` block is empty (`07 B6`) | this skill; the script is printed in `07 §2` |
| `.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` | no `HunchCore` file imports outside `Swift`/`Foundation` (`08 §2`) | `hunch-swift-code` |
| `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` | `palette.md` ↔ `Prim.swift` ↔ canon, every ratio recomputed | `hunch-design-tokens` |
| `Scripts/check-inventory.sh` | every `DESIGN-SYSTEM-SCOPE.md` §3 row has exactly one reference file and one owning symbol | `hunch-shared-marks` |
| `Scripts/check-symbols.sh` | every backticked token spelling is one `hunch-design-tokens` defines; every cited `C.*` member resolves in Swift | the library itself |
| `Scripts/check-skills.sh` | every `SKILL.md` parses, `name` equals its directory, `allowed-tools` is comma-separated, no unreferenced reference file, no cited path that resolves only on a case-insensitive filesystem | the library itself |
| `node .claude/skills/hunch-glyph-renderer/scripts/check-coverage-separation.js` | the 256 glyphs stay visually separated | `hunch-glyph-renderer` |
| `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` | the 22 sigils clear `T`, the ink and stage budgets, and the one-owning-section rule | `hunch-sigil-drawing` |

`check-skills.sh` matters more than it looks: malformed frontmatter is a **silent** auto-invocation outage — the skill still answers `/hunch-build-and-ci`, so a manual smoke test passes while the description is gone from every session's context.

The last three were named here and in `ci-workflow.md` §1 for a release without ever being written, which made three CI steps assertions about scripts that did not exist. Their bodies are §7.1–§7.3 below and each is proved failing in §7.4. **`check-inventory.sh` and `check-symbols.sh` need a convention, and §7.1 states it** — that is why they could not simply be pasted from somewhere else.

---

### 7.1 `Scripts/check-inventory.sh`

The declaration is a single HTML comment in the reference file that owns the row:

```markdown
<!-- inventory: Verdict ring | VerdictRing.draw -->
```

A comment rather than prose, for three reasons: it renders as nothing, it cannot be written by accident in the middle of a sentence, and it is exactly greppable. The row name must match §3's bolded first cell character for character.

```bash
#!/bin/bash
# Scripts/check-inventory.sh — every component in the inventory has exactly one owner.
#
# design/DESIGN-SYSTEM-SCOPE.md §3 is the component inventory. §2(g) of the same document
# states the defect this exists to stop: "Shared idioms have no declared owner — the machined
# bar is specified twice … with no statement of which file owns the drawing." A component
# with two reference files diverges; a component with none gets reinvented.
#
# The declaration is a single HTML comment in the reference file that owns the row:
#
#     <!-- inventory: Verdict ring | VerdictRing.draw -->
#
# A comment, not prose: it renders as nothing, it cannot be written by accident, and it is
# exactly greppable. The row name must match §3's bolded first cell character for character.
#
# Run from the repo root.
#   --strict   a §3 row with no declaration is a failure (the end state)
#   default    a §3 row with no declaration is a warning; TWO declarations always fail
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
scope="$root/design/DESIGN-SYSTEM-SCOPE.md"
skills="$root/.claude/skills"
strict=0; [ "${1:-}" = "--strict" ] && strict=1
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Markdown scanning helper, shared by all three library checkers.
#
# A fenced code block is an EXAMPLE, not a citation. Without this, every checker fails on the
# documentation that explains it — source-hygiene.md §7 necessarily prints each script's source
# and names the exact spellings the scripts reject. Blank the fenced lines rather than deleting
# them, so reported line numbers still point at the real line.
#
# `<!-- CHECK-EXEMPT -->` on a line suppresses it in prose, for the rare sentence that has to
# name a wrong spelling out loud. Same shape as check-source-hygiene.sh's TOKENS-EXEMPT (§3).
prose() {
    awk '/^[[:space:]]*```/ { fence = !fence; print ""; next }
         /CHECK-EXEMPT/     { print ""; next }
         { print (fence ? "" : $0) }' "$1"
}

[ -f "$scope" ] || { echo "No $scope — nothing to check."; exit 0; }

# §3's rows: table lines whose first cell is bold. `| ***A. Marks*** |` is a section header
# and extracts to a name starting with `*`, which is how it is dropped.
rows=$(awk '/^## 3\./{ inside = 1; next } /^## 4\./{ inside = 0 }
            inside && /^\| \*\*/ {
              line = $0
              sub(/^\| \*\*/, "", line)
              sub(/\*\*.*$/, "", line)
              if (line !~ /^\*/ && line != "") print line
            }' "$scope")

# Every declaration in the library, as "row<TAB>symbol<TAB>file".
# awk, not sed: `sed` has no non-greedy match, so `(.*)\|(.*)` swallows the separator and every
# row comes out as "Row | Symbol -->". That failure is silent — the rows just look unowned.
decls=$(find "$skills" -name '*.md' | sort |
  while IFS= read -r f; do prose "$f" | sed "s|^|${f#"$skills"/}\\$(printf '\t')|"; done |
  awk '
    /<!--[[:space:]]*inventory:/ {
      tab = index($0, "\t")
      file = substr($0, 1, tab - 1)
      body = substr($0, tab + 1)
      sub(/^.*<!--[[:space:]]*inventory:[[:space:]]*/, "", body)
      sub(/[[:space:]]*-->.*$/, "", body)
      bar = index(body, "|")
      if (bar == 0) next
      row = substr(body, 1, bar - 1); sym = substr(body, bar + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", row)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", sym)
      print row "\t" sym "\t" file
    }')

unowned=''
while IFS= read -r row; do
  [ -z "$row" ] && continue
  hits=$(printf '%s\n' "$decls" | awk -F'\t' -v r="$row" '$1 == r { print $3 }')
  n=$(printf '%s' "$hits" | grep -c . )
  if [ "$n" -eq 0 ]; then
    unowned="$unowned
  $row"
  elif [ "$n" -gt 1 ]; then
    report "Inventory row claimed by more than one reference file — this IS the §2(g) bug:" \
      "  $row
$(printf '%s\n' "$hits" | sed 's|^|    |')"
  fi
done <<EOF
$rows
EOF

if [ -n "$unowned" ]; then
  if [ "$strict" -eq 1 ]; then
    report 'Inventory row with no owning reference file:' "$unowned"
  else
    printf '\nwarning: %s inventory row(s) not yet declared (add the comment when the file is written):%s\n' \
      "$(printf '%s' "$unowned" | grep -c .)" "$unowned" >&2
  fi
fi

# A declaration naming a row §3 does not have is a typo or a stale rename; either way the row
# it meant to claim is now unowned and nothing else would say so.
orphans=$(printf '%s\n' "$decls" | awk -F'\t' 'NF==3 { print $1 "\t" $3 }' |
  while IFS=$'\t' read -r row file; do
    printf '%s\n' "$rows" | grep -qxF "$row" || printf '  %s  (declared in %s)\n' "$row" "$file"
  done)
[ -n "$orphans" ] && report 'Declaration names a component that is not a §3 row:' "$orphans"

# Once the Swift exists, every declared owning symbol must resolve in it.
if [ -d "$root/Modules/Sources" ] || [ -d "$root/HunchCore/Sources" ]; then
  missing=$(printf '%s\n' "$decls" | awk -F'\t' 'NF==3 { print $2 "\t" $3 }' |
    while IFS=$'\t' read -r sym file; do
      base="${sym%%.*}"
      grep -rqE "(struct|enum|final class|actor)[[:space:]]+$base\b" \
        "$root/Modules/Sources" "$root/HunchCore/Sources" --include='*.swift' 2>/dev/null \
        || printf '  %s  (declared in %s)\n' "$sym" "$file"
    done)
  [ -n "$missing" ] && report 'Owning symbol does not resolve in Swift:' "$missing"
fi

[ "$status" -eq 0 ] && echo "Inventory: clean ($(printf '%s\n' "$rows" | grep -c .) rows in §3, $(printf '%s\n' "$decls" | grep -c .) declared)"
exit "$status"
```

**Why `--strict` is not the default yet, and when it becomes it.** Only `hunch-shared-marks`' seven files carry the comment today; the other 26 rows are warnings. A gate that fails 26 times on day one gets waived, and this skill's own rule is that a waivable gate is documentation. The *fatal* half — two owners — is on unconditionally, because that is the failure §2(g) actually describes. **When the last reference file adopts the comment, CI switches to `--strict` and the warning branch is deleted.** Put that switch in the same commit as the last declaration.

---

### 7.2 `Scripts/check-symbols.sh`

```bash
#!/bin/bash
# Scripts/check-symbols.sh — no skill may cite a symbol that does not exist.
#
# Two assertions, one of which runs today and one of which starts working the day the Swift lands.
#
#   A. Token vocabulary. Every backticked `<category>.<name>` used anywhere in the library must
#      appear in hunch-design-tokens' own reference files. That skill is the vocabulary; every
#      other skill spends it. This is the check that catches `surface.cell.lit` for `surface.cellLit`
#      — a spelling that reads fine, is cited in four places, and resolves to nothing.
#
#   B. Swift resolution. Once HunchCore/Sources or Modules/Sources exists, every backticked
#      `C.Namespace.member` must resolve to a declaration in it.
#
# Run from the repo root.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
skills="$root/.claude/skills"
tokens="$skills/hunch-design-tokens/references"
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Markdown scanning helper, shared by all three library checkers.
#
# A fenced code block is an EXAMPLE, not a citation. Without this, every checker fails on the
# documentation that explains it — source-hygiene.md §7 necessarily prints each script's source
# and names the exact spellings the scripts reject. Blank the fenced lines rather than deleting
# them, so reported line numbers still point at the real line.
#
# `<!-- CHECK-EXEMPT -->` on a line suppresses it in prose, for the rare sentence that has to
# name a wrong spelling out loud. Same shape as check-source-hygiene.sh's TOKENS-EXEMPT (§3).
prose() {
    awk '/^[[:space:]]*```/ { fence = !fence; print ""; next }
         /CHECK-EXEMPT/     { print ""; next }
         { print (fence ? "" : $0) }' "$1"
}

[ -d "$tokens" ] || { echo "No hunch-design-tokens/references — nothing to check against."; exit 0; }

# The categories the token skill owns. A dotted identifier under any other prefix is a Swift
# expression or prose and is not this check's business.
cats='ground|surface|stroke|accent|hue|opacity|weight|dur|ease|radius|space|type|glyph|assay|bleed|pitch'
pattern="\`($cats)\.[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*\`"

# A. The vocabulary is whatever hunch-design-tokens writes down.
vocab=$(find "$tokens" "$skills/hunch-design-tokens/SKILL.md" -name '*.md' -o -name 'SKILL.md' |
  sort -u | while IFS= read -r f; do prose "$f"; done | grep -ohE "$pattern" | tr -d '`' | sort -u)

used=$(find "$skills" -name '*.md' | grep -v '/hunch-design-tokens/' | sort |
  while IFS= read -r f; do
    prose "$f" | grep -noE "$pattern" | sed "s|^|${f#"$skills"/}:|"
  done)

unknown=$(printf '%s\n' "$used" |
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    sym=$(printf '%s\n' "$hit" | sed -E 's|^.*:([0-9]+):||' | tr -d '`')
    printf '%s\n' "$vocab" | grep -qxF "$sym" || printf '  %s\n' "$hit"
  done)
[ -n "$unknown" ] && report \
  'Token spelling that hunch-design-tokens does not define (a category is not also a token):' \
  "$unknown"

# B. Backticked C.* members, once there is Swift to resolve them against.
if [ -d "$root/HunchCore/Sources" ] || [ -d "$root/Modules/Sources" ]; then
  src=""
  [ -d "$root/HunchCore/Sources" ] && src="$src $root/HunchCore/Sources"
  [ -d "$root/Modules/Sources" ] && src="$src $root/Modules/Sources"
  # Backticked, so this only ever sees prose citations; a `C.` inside a Swift fence is bare.
  missing=$(grep -rhoE '`C\.[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*' "$skills" --include='*.md' 2>/dev/null |
    tr -d '`' | sort -u |
    while IFS= read -r sym; do
      member="${sym##*.}"
      grep -rqE "(let|var|func)[[:space:]]+$member\b" $src --include='*.swift' 2>/dev/null \
        || printf '  %s\n' "$sym"
    done)
  [ -n "$missing" ] && report 'Cited C.* member does not resolve in Swift:' "$missing"
else
  echo "note: no Swift on disk yet — assertion B (C.* resolution) is inert until HunchCore/Sources exists." >&2
fi

[ "$status" -eq 0 ] && echo "Symbols: clean ($(printf '%s\n' "$vocab" | grep -c .) tokens defined, $(printf '%s\n' "$used" | grep -c .) citations checked)"
exit "$status"
```

**Assertion A is the one that pays now.** Run against the library as written it reports three real defects with no Swift on disk at all: `surface.cell.lit` (four sites in `hunch-sigil-drawing`, since fixed), `space.s12` in `hunch-chrome-and-meta/references/stock-controls.md`, and `opacity.scrim` in `hunch-motion-and-feedback/references/transitions.md` — the last two because the token skill ships `space.s4`/`space.s64` and `opacity.scrimFlat`/`opacity.scrimBlurred`. None of the three would have been caught by a grep for hex literals, and none of them needs a compiler. <!-- CHECK-EXEMPT: this sentence names the wrong spellings on purpose -->

**Two scanning rules all three checkers share, and both were learned by running them.** A **fenced code block is an example, not a citation** — without skipping fences, every checker fails on §7 itself, which necessarily prints each script's source and names the spellings the scripts reject. And `<!-- CHECK-EXEMPT: reason -->` suppresses one line of prose, for the rare sentence (like the one above) that has to say a wrong spelling out loud. That is deliberately the same shape as check 7's `PLAY-TEXT-EXEMPT` and check 9's `TOKENS-EXEMPT` (§3), including the requirement that the reason is written: a hatch with no reason is the thing being checked for.

---

### 7.3 `Scripts/check-skills.sh`

```bash
#!/bin/bash
# Scripts/check-skills.sh — the skill library lints itself.
#
# Malformed frontmatter is a SILENT auto-invocation outage: the skill still answers
# /<name>, so a manual smoke test passes while its description is gone from every
# session's context. Nothing else in this repo catches that.
#
# Run from the repo root. Exits 1 on the first category with offenders (all are printed).
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"
skills="$root/.claude/skills"
status=0
report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Markdown scanning helper, shared by all three library checkers.
#
# A fenced code block is an EXAMPLE, not a citation. Without this, every checker fails on the
# documentation that explains it — source-hygiene.md §7 necessarily prints each script's source
# and names the exact spellings the scripts reject. Blank the fenced lines rather than deleting
# them, so reported line numbers still point at the real line.
#
# `<!-- CHECK-EXEMPT -->` on a line suppresses it in prose, for the rare sentence that has to
# name a wrong spelling out loud. Same shape as check-source-hygiene.sh's TOKENS-EXEMPT (§3).
prose() {
    awk '/^[[:space:]]*```/ { fence = !fence; print ""; next }
         /CHECK-EXEMPT/     { print ""; next }
         { print (fence ? "" : $0) }' "$1"
}

[ -d "$skills" ] || { echo "No .claude/skills — nothing to lint."; exit 0; }

for dir in "$skills"/*/; do
  name=$(basename "$dir")
  file="$dir/SKILL.md"
  [ -f "$file" ] || { report "No SKILL.md:" "$name"; continue; }

  # Frontmatter is lines 2..N where N is the second '---'. Missing either fence is fatal.
  if [ "$(head -1 "$file")" != "---" ]; then
    report 'SKILL.md does not open with a --- fence (frontmatter will not parse):' "$name"; continue
  fi
  end=$(awk 'NR>1 && $0=="---" { print NR; exit }' "$file")
  if [ -z "$end" ]; then
    report 'SKILL.md frontmatter is never closed:' "$name"; continue
  fi
  fm=$(sed -n "2,$((end - 1))p" "$file")

  # name: must equal the directory. The spec requires it and a mismatch disables the skill.
  declared=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | tr -d '"'"'"' ')
  [ "$declared" = "$name" ] || report 'name: does not equal its directory:' "$name  declares  ${declared:-<missing>}"

  # description: required, under 1024 chars, no angle brackets (they break the listing).
  desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p')
  if [ -z "$desc" ]; then
    report 'No description: — the skill can never be auto-invoked:' "$name"
  else
    n=${#desc}
    [ "$n" -le 1024 ] || report 'description over 1024 chars:' "$name  ($n)"
    case "$desc" in *'<'*|*'>'*) report 'description contains an angle bracket:' "$name" ;; esac
  fi

  # A bare `version:` key fails validation; the version belongs under metadata:.
  printf '%s\n' "$fm" | grep -qE '^version:' && report 'bare version: key (must be metadata.version):' "$name"

  # allowed-tools must be comma-separated. `Read Grep Glob` is one tool named "Read Grep Glob".
  at=$(printf '%s\n' "$fm" | sed -n 's/^allowed-tools:[[:space:]]*//p')
  if [ -n "$at" ]; then
    case "$at" in
      *,*) : ;;
      *' '*)
        # No comma but a space outside parentheses => space-separated list.
        stripped=$(printf '%s\n' "$at" | sed 's/([^)]*)//g')
        case "$stripped" in *' '*) report 'allowed-tools is space-separated; it must be comma-separated:' "$name: $at" ;; esac ;;
    esac
  fi

  # Every reference file must be reachable from SKILL.md, and every path SKILL.md
  # names must exist. An unreferenced reference file is invisible to the skill.
  if [ -d "$dir/references" ]; then
    for ref in "$dir/references"/*.md; do
      [ -f "$ref" ] || continue
      base=$(basename "$ref")
      grep -qF "$base" "$file" || report 'reference file is never named in SKILL.md (invisible):' "$name/references/$base"
    done
  fi
done

# Every skills-relative path cited anywhere in the library must resolve, WITH EXACT CASE.
# `-e` is not enough: APFS is case-insensitive by default, so `REFERENCE.md` resolves on the
# machine you wrote it on and 404s on the Linux lint runner. That is the defect Anthropic's
# own `pdf` skill shipped. Compare against a real listing instead of asking the filesystem.
have=$(cd "$skills" && find . -type f \( -name '*.md' -o -name '*.js' -o -name '*.sh' -o -name '*.swift' \) |
       sed 's|^\./||' | sort -u)
missing=$(
  find "$skills" -name '*.md' | while IFS= read -r f; do prose "$f"; done |
    grep -ohE '(hunch-[a-z-]+/)?(references|scripts)/[A-Za-z0-9._-]+\.(md|js|sh|swift)' | sort -u |
  while IFS= read -r p; do
    # No `case` here: bash 3.2 (what macOS ships) mis-parses a case pattern's `)` inside a
    # command substitution, and the error surfaces as a syntax error 40 lines away.
    if [ "${p#hunch-}" != "$p" ]; then
      printf '%s\n' "$have" | grep -qxF "$p" || echo "$p"
    else
      # Skill-relative: it must exist under at least one skill, spelled exactly this way.
      printf '%s\n' "$have" | grep -qE "^hunch-[a-z-]+/$(printf '%s' "$p" | sed 's/\./\\./g')$" \
        || echo "$p (relative, matches no skill)"
    fi
  done
)
[ -n "$missing" ] && report 'Cited path does not resolve (exact case matters on Linux):' "$missing"

[ "$status" -eq 0 ] && echo "Skill library: clean ($(ls -d "$skills"/*/ | wc -l | tr -d ' ') skills)"
exit "$status"
```

---

### 7.4 Proving these three can fail

Same discipline as §4, and the same reason: a checker that cannot fail converts an absence of evidence into a green tick. Each of these was run against a deliberately broken tree and restored.

```bash
# check-skills.sh — five categories, each reachable
sed -i '' 's/^name: hunch-shared-marks/name: hunch-marks/' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "name: does not equal its directory", exit 1
sed -i '' 's/^metadata:/version: "1.0"\nmetadata:/' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "bare version: key", exit 1
sed -i '' 's|references/ownership.md|references/OWNERSHIP.md|' .claude/skills/hunch-shared-marks/SKILL.md
Scripts/check-skills.sh    # → "Cited path does not resolve" AND "never named in SKILL.md"
                           #   NOTE: `[ -e ]` would have PASSED this one on macOS. That is the test.

# check-inventory.sh — the fatal category and the orphan category
printf '\n<!-- inventory: Tick row | TickRow.draw -->\n' >> .claude/skills/hunch-shared-marks/references/ownership.md
Scripts/check-inventory.sh # → "claimed by more than one reference file", exit 1
printf '\n<!-- inventory: Tick Row | TickRow.draw -->\n' >> .claude/skills/hunch-shared-marks/references/ownership.md
Scripts/check-inventory.sh # → "names a component that is not a §3 row" (capital R)
Scripts/check-inventory.sh --strict   # → exit 1 on the 26 rows still undeclared

# check-symbols.sh — assertion A, using the exact defect this library shipped
sed -i '' 's|`surface.cellLit`|`surface.cell.lit`|' .claude/skills/hunch-sigil-drawing/references/mode-sigils.md
Scripts/check-symbols.sh   # → "Token spelling that hunch-design-tokens does not define", exit 1

git checkout -- .claude/skills          # every one of the above, reverted
```

**All three were also run against this file**, which is the hardest input they will ever get: §7 prints their own source and §7.2 names three spellings they reject. That run is what produced the `prose()` helper and the `CHECK-EXEMPT` marker (§3) — without them, each checker failed on its own documentation and would have been switched off within a week. Re-run them after editing §7.

**Step 3 of §4 applies here too**: break a second category and confirm the first failure did not stop the run. All three use §3's `report`-and-continue convention for exactly that reason.

---

## 8. What would be wrong

- **Naming a script in the workflow before writing it.** Three steps in `ci-workflow.md` §1 invoked `check-inventory.sh`, `check-symbols.sh` and `check-skills.sh` for a whole release while none of the three existed. On a runner that is a hard failure the first time CI runs; in a repo with no CI yet it is worse — four skills cited them as enforcement and every ownership defect they were meant to catch shipped. **A gate step and its script land in the same commit.**
- **Citing a document that is not in the repository.** Those same three checkers cited `skill-plan.md` as their specification, in five places across four skills, and `find` over the project returns nothing. An agent told to print the spec has nothing to print. Cite the artefact — `DESIGN-SYSTEM-SCOPE.md` §3, the reference file, the rule ID — or commit the document.
- **Using `[ -e path ]` to check that a cited path exists.** APFS is case-insensitive by default, so `REFERENCE.md` resolves on the machine you wrote it on and 404s on the Linux lint runner. §7.3 compares against a `find` listing for exactly this reason, and §7.4 proves the difference.
- **`sed` for a two-field parse.** `sed` has no non-greedy match, so `(.*)\|(.*)` swallows the separator and every inventory row parses as `"Row | Symbol -->"`. Nothing errors; the rows merely look unowned, which is indistinguishable from the state the check exists to report. §7.1 uses `awk` and says so.
- **A `case` pattern inside `$( )` on macOS.** bash 3.2 mis-parses the pattern's `)` as closing the command substitution and reports a syntax error forty lines away. Both §7.1 and §7.3 avoid it, with a comment, because the next person will otherwise "simplify" it back.
- **Leaving `check-inventory.sh` on its warning branch forever.** The warning exists so that 26 undeclared rows do not train people to skim a red log; it is a migration, not a setting. The commit that adds the last inventory comment switches CI to `--strict` and deletes the branch.
- **Weakening a checker to reach green.** Same rule as the greps: `|| true` inside a check is required and means the opposite (§3); `continue-on-error` on the step is a waiver. A gate that can be waived is documentation.
