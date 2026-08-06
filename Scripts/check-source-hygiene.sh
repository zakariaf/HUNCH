#!/bin/bash
# Scripts/check-source-hygiene.sh — every rule this repo states that the compiler cannot check.
# Run from the repo root. Prints every category that has offenders, then exits 1.
#   --fast   skip the checks that need a Swift toolchain or jq (4 and 8): the build-phase subset.
#
# THIS FILE IS THE SINGLE COPY OF THESE CHECKS. The documents that describe it are recipes for
# building it and are not normative for its text. Checks are APPENDED, never renumbered — every
# skill in .claude/skills/ cites them by number.
set -uo pipefail

roots=(App HunchCore/Sources HunchCore/Tests Modules/Sources Modules/Tests)
core=HunchCore/Sources
catalog=Modules/Sources/HunchUI/Resources/Localizable.xcstrings
fast=0; [ "${1:-}" = "--fast" ] && fast=1
status=0

report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# Day-one guard: the tree is built target by target (01 P12), so drop roots that do not exist
# yet rather than filling the log with "No such file or directory" and training people to skim it.
#
# The length is tested BEFORE the expansion. On macOS's /bin/bash (3.2.57), expanding an empty
# array under `set -u` is itself an error, so the obvious spelling aborts before it can print:
#   $ /bin/bash -c 'set -uo pipefail; present=(); roots=("${present[@]}"); echo ok'
#   present[@]: unbound variable
present=(); for d in "${roots[@]}"; do [ -d "$d" ] && present+=("$d"); done
if [ "${#present[@]}" -eq 0 ]; then echo 'No Swift source roots yet — nothing to check.'; exit 0; fi
roots=("${present[@]}")

# The token checks (9, 10) scan the whole Modules package, not Modules/Sources, and exclude
# HunchCore/Tests. Built by the same presence filter: `grep -r` on a missing path prints an
# error and, with `|| true`, silently yields nothing — so a hardcoded list would appear to pass
# while checking a subset.
tokenWanted=(App Modules HunchCore/Sources)
tokenRoots=(); for d in "${tokenWanted[@]}"; do [ -d "$d" ] && tokenRoots+=("$d"); done

# 1. Banned file names — 01 P28.
banned='Utils|Utilities|Helpers|Constants|Extensions|Managers|Common|Shared'
hits=$(find "${roots[@]}" -name '*.swift' \
  | grep -E "/($banned)\.swift$|\+Utilities\.swift$" || true)
[ -n "$hits" ] && report 'Banned file names (01 P28) — name the capability:' "$hits"

# 2. Snapshot record mode — 06 T51.
hits=$(grep -rn --include='*.swift' -E 'record:[[:space:]]*\.all' "${roots[@]}" || true)
[ -n "$hits" ] && report 'record: .all reached main (06 T51) — re-record locally, commit .failed:' "$hits"

# 3. Concurrency escape hatches need a justifying comment — 05 R29.
#    Two-line window: R29 asks for a justifying comment and people write it above the
#    declaration as often as beside it. The `line > 1` guard is not decoration — `sed -n '0,1p'`
#    is an error, and a hatch on line 1 is exactly the case you want reported.
hatches='@unchecked Sendable|nonisolated\(unsafe\)|@preconcurrency import|Task\.detached|assumeIsolated'
hits=$(
  grep -rn --include='*.swift' -E "$hatches" "${roots[@]}" \
    | cut -d: -f1,2 \
    | while IFS=: read -r file line; do
        start=$(( line > 1 ? line - 1 : 1 ))
        sed -n "${start},${line}p" "$file" | grep -q '//' || printf '%s:%s\n' "$file" "$line"
      done
)
[ -n "$hits" ] && report 'Escape hatch with no justifying comment (05 R29):' "$hits"

# 4. HunchTestSupport must not be reachable from anything the app links — 06 T5a.
#    Needs a Swift toolchain and jq; neither is guaranteed on the build phase's PATH.
if [ "$fast" -eq 0 ]; then
  # `describe` must be captured and validated separately. If it fails — a cyclic dependency, a
  # manifest that will not compile — it prints to stderr and yields NO JSON, and a jq filter over
  # nothing finds nothing, so the check would report clean on a broken manifest. Reproduced with
  # `HunchTestSupport -> LawGeneration -> HunchTestSupport`: describe exits non-zero, and the
  # original spelling of this block printed "Source hygiene: clean".
  described=$(swift package describe --package-path HunchCore --type json 2>/dev/null)
  if [ -z "$described" ] || ! printf '%s' "$described" | jq -e . >/dev/null 2>&1; then
    report 'swift package describe failed — the manifest is broken, so check 4 could not run:' \
      "$(swift package describe --package-path HunchCore --type json 2>&1 | head -5)"
  else
    hits=$(
      printf '%s' "$described" | jq -r '
          [ .products[]? | select(.targets | index("HunchTestSupport")) | "product \(.name)" ]
        + [ .targets[] | select(.type != "test")
            | select((.target_dependencies // []) | index("HunchTestSupport"))
            | "target \(.name)" ]
          | .[]'
    )
    [ -n "$hits" ] && report 'HunchTestSupport is reachable from the app (06 T5a) — Testing will ship:' "$hits"
  fi
fi

# 5. No network, anywhere. The brief's hard constraint and its mandated build-phase grep.
#    Imports and symbols both, because `import Network` alone is already a violation.
#    Do NOT "tidy" the alternation to (public |package |internal |)? — an empty branch is
#    `grep: empty (sub)expression` on the grep macOS ships, and that failure is a STDERR line,
#    not a non-zero exit, so the check would silently check nothing.
net='URLSession|URLRequest|NSURLSession|NSURLConnection|CFNetwork|CFURL(Request|Connection)'
net="$net"'|NWConnection|NWListener|NWBrowser|NWPathMonitor|CKContainer|CKDatabase|CKRecord'
# `Socket\(` needs a left boundary: §4.2 calls the Bridge's two attribute slots SOCKETS, so
# `onTapSocket(` is domain vocabulary and matched the bare pattern. A check that fires on canon
# gets an exemption comment today and gets deleted next year.
net="$net"'|WKWebView|SFSafariViewController|getaddrinfo|(^|[^A-Za-z_])Socket\('
net="$net"'|^[[:space:]]*(public |package |internal )?import[[:space:]]+(Network|CloudKit|WebKit|SafariServices|SystemConfiguration)\b'
hits=$(grep -rnE "$net" --include='*.swift' "${roots[@]}" || true)
[ -n "$hits" ] && report 'Network API in an app that has no network (the brief):' "$hits"

# 6. No ambient nondeterminism inside HunchCore — 08 §4, the boundary predicate's half (b).
#    Two passes: the RNG family is legal WITH `using:` (a threaded SplitMix64) and illegal
#    without it. Filtering that one line-substring is the difference between a check people
#    trust and a check people comment out.
rng='SystemRandomNumberGenerator|\.random\(|randomElement\(|shuffled\(|randomizedElement'
hits=$(grep -rnE "$rng" --include='*.swift' "$core" | grep -v 'using:' || true)
[ -n "$hits" ] && report 'Unseeded randomness in HunchCore (08 §4) — thread `using: &rng`:' "$hits"

ambient='Date\(\)|Date\.now|UUID\(\)|ProcessInfo|Locale\.current|TimeZone\.current|Calendar\.current'
ambient="$ambient"'|CFAbsoluteTimeGetCurrent|DispatchTime\.now|ContinuousClock|SuspendingClock|Task\.sleep'
hits=$(grep -rnE "$ambient" --include='*.swift' "$core" || true)
[ -n "$hits" ] && report 'Ambient clock/locale/identity in HunchCore (08 §2, §5) — take it as a parameter:' "$hits"

# 7. Zero characters on the play surface, in any locale — §12.9, owner hunch-accessibility.
#    Strings exist there only inside .accessibility* modifiers. Line-based and cannot see
#    nesting; that is the correct bias, and PLAY-TEXT-EXEMPT is the rare-wrap escape.
#    Keep `grep -H`: grep omits the filename when given a single path, and this set is often one.
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
if [ "$fast" -eq 0 ] && [ -f "$catalog" ]; then
  want='ar de en es fr it ja ko pt-BR ru tr zh-Hans'          # the brief's twelve, sorted
  keys=$(jq '.strings | length' "$catalog")
  [ "$keys" -le 250 ] || report "String Catalog over budget — $keys keys, the ceiling is 250 (§12.9):" "$catalog"

  # A catalog with zero strings has zero locales, and that is not a violation — it is an empty
  # catalog. The locale-set and per-key completeness checks below only mean something once
  # there are keys, so they are skipped while it is empty (E18 fills it). The budget check
  # above still runs, because "0 <= 250" is a real answer.
  if [ "$keys" -gt 0 ]; then
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
elif [ "$fast" -eq 0 ] && [ -d Modules/Sources ]; then
  report 'String Catalog missing (01 P35):' "$catalog"
fi

if [ "${#tokenRoots[@]}" -gt 0 ]; then
  # 9. No literal colour, dimension, opacity or duration outside the token module.
  #    Owner: hunch-design-tokens. Escape hatch: a `// TOKENS-EXEMPT: <reason>` comment
  #    on the line above or beside, matching check 3's convention.
  literals='#[0-9A-Fa-f]{6}|Color\(red:|UIColor\(|NSColor\(|\.opacity\([0-9.]|lineWidth:[[:space:]]*[0-9.]'
  literals="$literals"'|cornerRadius:[[:space:]]*[0-9.]|\.font\(\.system\(size:|duration:[[:space:]]*[0-9.]'
  literals="$literals"'|Duration\.(milli|micro|nano)seconds\(|\.tracking\([0-9.]|\.blur\(radius:[[:space:]]*[0-9.]'
  hits=$(
    grep -rnE "$literals" --include='*.swift' "${tokenRoots[@]}" \
      | grep -v '^HunchCore/Sources/Tokens/' \
      | cut -d: -f1,2 \
      | while IFS=: read -r file line; do
          start=$(( line > 1 ? line - 1 : 1 ))
          sed -n "${start},${line}p" "$file" | grep -q 'TOKENS-EXEMPT' || printf '%s:%s\n' "$file" "$line"
        done
  )
  [ -n "$hits" ] && report 'Literal value outside Tokens/ — name a token (hunch-design-tokens):' "$hits"

  # 10. Register laundering — AccentColor and HueColor exist to make this a compile error,
  #     and `.rgb` is the one way around them.
  appRoots=(); for d in App Modules; do [ -d "$d" ] && appRoots+=("$d"); done
  if [ "${#appRoots[@]}" -gt 0 ]; then
    hits=$(grep -rnE 'HueColor\(|AccentColor\(' --include='*.swift' "${appRoots[@]}" || true)
    [ -n "$hits" ] && report 'Minting a register colour outside Tokens/ (§13.2 segregation):' "$hits"
  fi
fi

# 11. §6.6's five discoverability layers must not be band-conditional. A layer that appeared
#     only where the law is contextual would announce the family it exists to make findable.
#     The list is short and specific on purpose: grepping all of Modules/ would fire on every
#     legitimate `band.par` and the check would be disabled within a week.
layerFiles=(
  Modules/Sources/HunchUI/RibbonTileModel.swift
  Modules/Sources/HunchUI/SpoolSheetLayout.swift
  Modules/Sources/HunchUI/ThroatView.swift
  Modules/Sources/HunchUI/CommitKey.swift
)
present=(); for f in "${layerFiles[@]}"; do [ -f "$f" ] && present+=("$f"); done
if [ "${#present[@]}" -gt 0 ]; then
  # Comments are exempt, and deliberately: "the same in every band" is precisely what these
  # files SHOULD say. It is the code that must not read it.
  hits=$(grep -rnE '\bband\b|Band\.' "${present[@]}" | grep -vE ':[[:space:]]*(//|\*)' || true)
  [ -n "$hits" ] && report \
    'A discoverability layer reads the band (§6.6 requires all five to be band-independent):' \
    "$hits"
fi

label=""; [ "$fast" -eq 1 ] && label=" (fast subset)"
[ "$status" -eq 0 ] && echo "Source hygiene: clean$label"
exit "$status"
