# CLAUDE.md

Build/test commands, rules, and the gotchas that cost real time. Under 60 lines by design —
prune it rather than let it grow. Everything here would cause a mistake if removed.

## Commands

```bash
swift test --package-path HunchCore                    # fast loop, must stay under 10 s
xcodebuild test -scheme Hunch -testPlan Presubmission -destination "id=$UDID"
Scripts/check-source-hygiene.sh                        # 10 checks; --fast skips 4 and 8
Scripts/check-pbxproj-clean.sh Hunch.xcodeproj
UDID=$(xcrun simctl list devices available --json \
  | jq -r '.devices|to_entries[]|.value[]|select(.name=="iPhone 16")|.udid' | head -1)
```

## Rules

- **Every build setting lives in `Config/*.xcconfig`.** `project.pbxproj` carries zero. A value
  typed into Xcode's Build Settings tab silently beats the target xcconfig.
- **No literal colour, dimension, opacity or duration outside `HunchCore/Sources/Tokens/`.**
  Check 9 fails the build. Escape hatch is `// TOKENS-EXEMPT: <reason>` on the line above.
- **Randomness is a parameter**, threaded as `using rng: inout some RandomNumberGenerator`.
  Never stored, never ambient. Check 6 enforces it, and filters `using:` so the legal spelling
  is not flagged.
- **`HunchCore` imports neither UIKit nor SwiftUI**, and nothing in it reads `Date()`,
  `Locale.current` or an unseeded RNG. Check 6 enforces the second half.
- **`HunchTestSupport` is never a product and never a dependency of a non-test target.** That
  absence is what keeps `import Testing` out of the release binary. Check 4 asserts it.
- **Swift Testing, not XCTest** — except XCUITest, which cannot use it. Tags are the fixed
  eight; a ninth is a decision.
- **TDD.** Write the failing test, run it, confirm it fails *for the right reason*, then
  implement. A check that cannot fail is worse than no check.
- Close every task with `/simplify`, then `/code-review`, then one commit.

## Gotchas

- **`swift package describe` yields no JSON when the manifest is broken**, and a `jq` filter
  over nothing finds nothing. Any check built on it must validate the JSON separately or it
  reports clean on a cyclic dependency. (Cost: one silently-passing check in T06.)
- **macOS `/bin/bash` is 3.2.57.** Expanding an empty array under `set -u` is an error, so test
  `${#arr[@]}` *before* the expansion.
- **`grep -E` rejects an empty alternation branch** — `(a |b |)?` is `empty (sub)expression`,
  and it fails on *stderr* with a zero exit, so the check silently checks nothing.
- **A unit-test bundle needs `TEST_HOST`; a UI-test bundle sets `USES_XCTRUNNER`.** Xcode
  rejects a target carrying both, and xcconfig has no per-target conditional — hence
  `Config/UnitTests*.xcconfig` and `Config/UITests*.xcconfig`.
- **XCTestCase's designated inits are nonisolated**, so a UI-test target must set
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. Base's `MainActor` default is for `App/` only.
- **`PRODUCT_NAME` must be `$(TARGET_NAME)`.** A literal makes three targets emit one
  `.swiftmodule` name — "Multiple commands produce".
- **XCTest cases carry no Swift Testing tags**, so a plan with `includeTags` selects zero of
  them and reports green over nothing. Nightly and Prerelease therefore filter by target.
- **`#_sourceLocation`, with the underscore.** The unprefixed spelling is the compiler's
  line-control directive and does not parse in a parameter default.
- The pre-commit hook lives in `.git/hooks/pre-commit` and is **not versioned**. On a fresh
  clone, copy it from this repo's history or run the two check scripts by hand.
