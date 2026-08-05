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
