#!/bin/bash
# Scripts/check-tests-json-monotonic.sh — nothing was removed or weakened since main.
#
# tests.json's whole value is that an entry is never deleted or softened to reach green. That is
# a property of the DIFF, not of the file, so it cannot live in check-tests-json.sh: a weakened
# entry is perfectly well-formed. Run in CI against the merge base.
set -uo pipefail
base="${1:-origin/main}"
f=tests.json
status=0

git show "$base:$f" > /tmp/hunch-tests-base.json 2>/dev/null || {
  echo "no baseline at $base — nothing to compare"; exit 0; }

removed=$(jq -r --slurpfile now "$f" '
  [.invariants[].id] - [$now[0].invariants[].id] | .[]' /tmp/hunch-tests-base.json)
if [ -n "$removed" ]; then
  echo "invariants REMOVED since $base — an entry is never deleted:" >&2
  echo "$removed" >&2
  status=1
fi

# A statement that got shorter is the shape a weakening takes: the qualifiers go first.
weakened=$(jq -r --slurpfile now "$f" '
  .invariants[] as $old
  | ($now[0].invariants[] | select(.id == $old.id)) as $new
  | select(($new.statement | length) < ($old.statement | length) - 8)
  | $old.id' /tmp/hunch-tests-base.json)
if [ -n "$weakened" ]; then
  echo "invariant statements got materially shorter — weakened?" >&2
  echo "$weakened" >&2
  status=1
fi

# pass -> fail is a regression and must be deliberate; pass -> known-issue is the same move
# wearing a different hat, so both are reported.
downgraded=$(jq -r --slurpfile now "$f" '
  .invariants[] | select(.status == "pass") as $old
  | ($now[0].invariants[] | select(.id == $old.id)) as $new
  | select($new.status != "pass")
  | "\($old.id): pass -> \($new.status)"' /tmp/hunch-tests-base.json)
if [ -n "$downgraded" ]; then
  echo "invariants downgraded from pass:" >&2
  echo "$downgraded" >&2
  status=1
fi

[ "$status" -eq 0 ] && echo "tests.json: monotonic against $base"
exit "$status"
