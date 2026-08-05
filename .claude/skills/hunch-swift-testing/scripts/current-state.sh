#!/usr/bin/env bash
# current-state.sh — which test targets and tags exist right now.
#
# SKILL.md is static markdown and cannot substitute a command, so this is run
# explicitly as step 0 of the skill. Its output outranks the tables below it.
set -u
root="${CLAUDE_PROJECT_DIR:-$PWD}"

echo "— test targets —"
targets=$(find "$root/HunchCore/Tests" "$root/Modules/Tests" "$root/HunchUITests" \
          -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s|^$root/||" | sort)
if [ -n "$targets" ]; then
  echo "$targets"
else
  echo "  NO TEST TARGETS YET — references/test-plan.md §1 is the target map to build to."
fi

echo "— declared tags —"
tags=$(grep -rh '@Tag public static var\|@Tag static var' \
       "$root/HunchCore/Sources" "$root/Modules/Sources" 2>/dev/null | tr -d ' ' | sort -u)
if [ -n "$tags" ]; then
  echo "$tags"
else
  echo "  NO TAGS DECLARED YET — references/test-plan.md §2 has the eight,"
  echo "  and which package declares each."
fi
