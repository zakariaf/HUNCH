#!/bin/bash
# Scripts/check-tests-json.sh — tests.json is well-formed and nothing is silently failing.
# It validates SHAPE. Monotonicity (entries never removed or weakened) is a property of the
# DIFF and is E20/T12's check-tests-json-monotonic.sh.
set -uo pipefail
f=tests.json
status=0
jq -e . "$f" >/dev/null 2>&1 || { echo "tests.json is not valid JSON" >&2; exit 1; }

missing=$(jq -r '.invariants[] | select((.id|not) or (.statement|not) or (.command|not) or (.status|not) or (.task|not)) | .id // "<no id>"' "$f")
[ -n "$missing" ] && { echo "entries missing a required field:" >&2; echo "$missing" >&2; status=1; }

dupes=$(jq -r '[.invariants[].id] | group_by(.) | map(select(length>1)) | .[][0]' "$f")
[ -n "$dupes" ] && { echo "duplicate ids:" >&2; echo "$dupes" >&2; status=1; }

bad=$(jq -r '.invariants[] | select(.status | inside("pass fail known-issue") | not) | "\(.id): \(.status)"' "$f" 2>/dev/null)
[ -n "$bad" ] && { echo "status must be pass | fail | known-issue:" >&2; echo "$bad" >&2; status=1; }

failing=$(jq -r '.invariants[] | select(.status=="fail") | .id' "$f")
[ -n "$failing" ] && { echo "invariants currently failing:" >&2; echo "$failing" >&2; status=1; }

[ "$status" -eq 0 ] && echo "tests.json: $(jq '.invariants|length' "$f") invariants, all passing"
exit "$status"
