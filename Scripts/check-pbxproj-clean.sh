#!/bin/bash
# Scripts/check-pbxproj-clean.sh — fails if any target carries an inline build setting.
set -uo pipefail
project="${1:-Hunch.xcodeproj}/project.pbxproj"

offenders=$(
  awk '/buildSettings = \{/,/^[\t ]*\};/' "$project" \
    | grep -vE 'buildSettings = \{|^[[:space:]]*\};$' \
    || true
)

if [ -n "${offenders//[[:space:]]/}" ]; then
  printf 'Inline build settings in %s — move them to Config/*.xcconfig:\n%s\n' \
    "$project" "$offenders"
  exit 1
fi

echo "pbxproj clean: $project"
