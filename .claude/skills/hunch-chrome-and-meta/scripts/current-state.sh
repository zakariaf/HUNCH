#!/usr/bin/env bash
# current-state.sh — which chrome and archive files already exist.
#
# SKILL.md is static markdown and cannot substitute a command, so this is run
# explicitly as step 0 of the skill. A file that appears here already has an
# owning symbol; read it before drawing a second copy. A file that does not
# appear is yours to create from its reference file.
set -u
root="${CLAUDE_PROJECT_DIR:-$PWD}"
found=$(find "$root/Modules/Sources/HunchUI" \
             "$root/Modules/Sources/MetaFeature" \
             "$root/Modules/Sources/CodexFeature" \
        -name '*.swift' 2>/dev/null | sed "s|.*/Sources/||" | sort)

if [ -n "$found" ]; then
  echo "$found"
else
  echo "CHROME NOT BUILT YET — the reference files are normative until"
  echo "Modules/Sources/{HunchUI,MetaFeature,CodexFeature} exist. Create the file,"
  echo "then update the reference file's owning-symbol line."
fi
