#!/bin/bash
#
# check-boundary.sh — the HunchCore boundary predicate (ios-swift-guide/08-APPLIED-TO-HUNCH.md §2),
# run as the two greps that predicate says it is.
#
#   A file may live in HunchCore/ iff
#     (a) it imports nothing but Swift/Foundation, and
#     (b) its behaviour is a pure function of values you can write down in a test.
#   Fail either half and it belongs in Modules/.
#
# Half (b) bans AMBIENT sources, not parameters. `Date()` called inside the core is a violation;
# a `Date` handed in is data. That is why FilePersistenceStore is core — its directory arrives
# in init — while Codex is not.
#
# Usage:
#   check-boundary.sh                       audit every file under HunchCore/Sources (default)
#   check-boundary.sh --all                 same
#   check-boundary.sh <file.swift> [...]    verdict for candidate files, wherever they live
#   check-boundary.sh --list                print the two symbol lists and exit
#
# Exit: 0 clean or advisory-only, 1 at least one FAIL, 2 bad usage.
#
# Not owned here: the repo-wide network grep, the play-surface text lint and the localization
# checks are Scripts/check-source-hygiene.sh (07 B34a, 08 §5) — hunch-build-and-ci.

# No `set -e`: grep exits 1 when it finds nothing, which is the good case throughout.
set -uo pipefail

# Half (a): the only import a HunchCore file may carry. `Testing` is additionally legal under
# HunchTestSupport, which is a .target and is absent from products: (01 P20, 06 T5a).
ALLOWED_IMPORTS='Foundation'

# Half (b): ambient sources of state. Every one of these makes behaviour depend on something
# a test cannot write down. Injected equivalents — `Now`, `SeedSource`, an `inout` RNG, a URL
# passed to init — are the sanctioned spellings and are not matched here.
AMBIENT='Date\(\)|UUID\(\)|\.random\(|randomElement\(\)|shuffled\(\)|SystemRandomNumberGenerator'
AMBIENT="$AMBIENT"'|Locale\.current|TimeZone\.current|Calendar\.current|ProcessInfo|UserDefaults'
AMBIENT="$AMBIENT"'|Bundle\.|#bundle|applicationSupportDirectory|documentsDirectory|cachesDirectory'
AMBIENT="$AMBIENT"'|Task\.sleep|ContinuousClock|SuspendingClock|DispatchTime|CFAbsoluteTime|Date\.now'
AMBIENT="$AMBIENT"'|@Observable|@MainActor|@Environment|@State|@AppStorage'
AMBIENT="$AMBIENT"'|CGRect|CGSize|CGPoint|UIScreen|displayScale'

# Advisory: legal, but each one has been wrong more often than right in this package.
ADVISORY='CGFloat|final class|lazy var|static var'

usage() { sed -n '3,24p' "$0" | sed 's|^# \{0,1\}||'; }

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi
if [ "${1:-}" = "--list" ]; then
    printf 'allowed imports:\n  %s\n\nambient (FAIL):\n  %s\n\nadvisory (REVIEW):\n  %s\n' \
        "$ALLOWED_IMPORTS" "$AMBIENT" "$ADVISORY"
    exit 0
fi

# Repo root: the directory that contains HunchCore/ or ios-swift-guide/.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
while [ "$root" != "/" ] && [ ! -d "$root/HunchCore" ] && [ ! -d "$root/ios-swift-guide" ]; do
    root="$(dirname "$root")"
done
[ "$root" = "/" ] && root="${CLAUDE_PROJECT_DIR:-$PWD}"

fails=0
reviews=0

# strip line comments so a `Date()` inside a doc comment is not a violation.
# Block comments and string literals are not handled; read the reported line before acting.
body() { sed 's|//.*||' "$1"; }

check_file() {
    local file="$1" rel="$2" hits extra='' ambient="$AMBIENT" bad=0

    case "$rel" in */HunchTestSupport/*) extra='|Testing' ;; esac
    # FileManager is legal in Persistence/, whose whole job is the file tree (08 §1). Nowhere else.
    case "$rel" in */Persistence/*) : ;; *) ambient="$ambient"'|FileManager' ;; esac

    hits="$(body "$file" | grep -nE '^[[:space:]]*import[[:space:]]' |
            grep -vE "^[0-9]+:[[:space:]]*import[[:space:]]+(${ALLOWED_IMPORTS}${extra})[[:space:]]*$")"
    if [ -n "$hits" ]; then
        printf 'FAIL  %s  half (a): imports something other than Swift/Foundation\n' "$rel"
        printf '%s\n' "$hits" | sed 's|^|        |'
        bad=1
    fi

    hits="$(body "$file" | grep -nE "$ambient")"
    if [ -n "$hits" ]; then
        printf 'FAIL  %s  half (b): ambient state — behaviour is not a function of its arguments\n' "$rel"
        printf '%s\n' "$hits" | sed 's|^|        |'
        bad=1
    fi

    hits="$(body "$file" | grep -nE "$ADVISORY")"
    if [ -n "$hits" ]; then
        printf 'REVIEW %s  legal, but rarely right in HunchCore (08 §4: no classes, no mutable statics)\n' "$rel"
        printf '%s\n' "$hits" | sed 's|^|        |'
        reviews=$((reviews + 1))
    fi

    return $bad
}

if [ $# -eq 0 ] || [ "${1:-}" = "--all" ]; then
    core="$root/HunchCore/Sources"
    if [ ! -d "$core" ]; then
        echo "no HunchCore/Sources under $root — nothing to audit yet."
        echo "The tree to build toward is ios-swift-guide/08-APPLIED-TO-HUNCH.md §1."
        exit 0
    fi
    count=0
    while IFS= read -r file; do
        count=$((count + 1))
        check_file "$file" "${file#"$root"/}" || fails=$((fails + 1))
    done < <(find "$core" -name '*.swift' -type f | sort)

    printf '\n%s file(s) audited under HunchCore/Sources — %s FAIL, %s REVIEW\n' "$count" "$fails" "$reviews"
    [ "$fails" -eq 0 ] || {
        echo "A file that fails either half belongs in Modules/. Pick its target from"
        echo "hunch-swift-code/references/file-placement.md §2 before moving it."
        exit 1
    }
    exit 0
fi

# Candidate mode: advisory by design. Both verdicts are legal answers, so exit 0 either way.
status=0
for file in "$@"; do
    if [ ! -f "$file" ]; then printf 'not a file: %s\n' "$file"; status=2; continue; fi
    rel="${file#"$root"/}"
    if check_file "$file" "$rel"; then
        printf 'VERDICT %s -> HunchCore is legal. Pick the target from file-placement.md §2.\n' "$rel"
    else
        printf 'VERDICT %s -> Modules/. It fails the predicate above.\n' "$rel"
    fi
done
exit $status
