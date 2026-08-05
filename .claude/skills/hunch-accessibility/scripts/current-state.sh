#!/usr/bin/env bash
# current-state.sh — which accessibility modifiers are actually shipped.
#
# SKILL.md is static markdown and cannot substitute a command, so this is run
# explicitly as step 0 of the skill. A modifier that is not in this listing is
# not shipped, whatever a reference file claims.
set -u
root="${CLAUDE_PROJECT_DIR:-$PWD}"

if [ -d "$root/Modules/Sources" ]; then
  echo "— modifiers in use —"
  grep -rho 'accessibility[A-Za-z]*(' "$root/Modules/Sources" | sort | uniq -c | sort -rn | head -14

  echo "— the five counts check 11 asserts (audit-in-ci.md §5) —"
  for pattern in 'accessibilityAction(\.magicTap)' 'accessibilityAction(\.escape)' \
                 'accessibilityRotor(' 'accessibilitySortPriority' 'children: .combine'; do
    printf '  %-38s %s\n' "$pattern" \
      "$(grep -Rho "$pattern" "$root/Modules/Sources" --include='*.swift' 2>/dev/null | wc -l | tr -d ' ')"
  done

  grep -rl 'performAccessibilityAudit' "$root/HunchUITests" 2>/dev/null \
    || echo "AUDIT NOT WIRED — references/audit-in-ci.md §2 is the file to create."
else
  echo "NO SWIFT YET — references/voiceover-elements.md is the normative element index"
  echo "until Modules/Sources exists."
fi
