## What this epic delivers

<one paragraph: what exists now that did not before>

## Gate

<the epic's gate, the command that proves it, and the output pasted>

```
$ <command>
<output>
```

## DECISIONS.md entries added

<one line each, or "none">

## Checklist

- [ ] `swift test --package-path HunchCore` green, fast suite under 10 s
- [ ] `xcodebuild test -scheme Hunch -testPlan Presubmission` green
- [ ] `Scripts/check-source-hygiene.sh` clean
- [ ] `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj` clean
- [ ] `Scripts/check-tests-json.sh` green, with entries added for new invariants
- [ ] `/simplify` and `/code-review` run on every task in the epic
