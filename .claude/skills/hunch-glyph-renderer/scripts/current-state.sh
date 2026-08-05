#!/usr/bin/env bash
# current-state.sh — what the glyph renderer looks like in the repo RIGHT NOW.
#
# SKILL.md is static markdown and cannot substitute a command, so this is run
# explicitly as step 0 of the skill. Its output outranks every table below it:
# the reference files are the spec until the Swift exists, and the Swift is the
# spec once it does.
set -u
root="${CLAUDE_PROJECT_DIR:-$PWD}"
dir=""
for candidate in "$root/Modules/Sources/HunchUI" "./Modules/Sources/HunchUI" "../Modules/Sources/HunchUI"; do
  [ -d "$candidate" ] && { dir="$candidate"; break; }
done

if [ -n "$dir" ] && ls "$dir"/Glyph*.swift >/dev/null 2>&1; then
  grep -Hn 'struct \|static let \|static func \|func draw' "$dir"/Glyph*.swift | sed 's|.*/HunchUI/||'
  echo
fi

tokens="$root/HunchCore/Sources/Tokens/C.swift"
if [ -f "$tokens" ]; then
  echo "— C.Glyph members that ship —"
  sed -n '/enum Glyph {/,/^    }/p' "$tokens" | grep -n 'static ' | sed 's/^/  /'
fi

if [ -z "$dir" ] || ! ls "$dir"/Glyph*.swift >/dev/null 2>&1; then
  echo "GLYPH RENDERER NOT BUILT YET — references/geometry.md §4 is the file to write,"
  echo "and references/reference-renderer.js is the executable spec it ports."
fi
