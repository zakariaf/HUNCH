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
