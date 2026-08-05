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
