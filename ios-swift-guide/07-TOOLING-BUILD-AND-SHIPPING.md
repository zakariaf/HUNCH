# Tooling, Build and Shipping

This file covers everything between "it compiles on my machine" and "the build is live in TestFlight": build settings and where they live, xcconfig files, run-script phases, formatters and linters, `Package.swift` mechanics, schemes and test plans as CI plumbing, versioning, GitHub Actions, archiving and upload, localization tooling, profiling, app size, and the metadata that gets builds rejected. Read it if you own a project's build configuration or its CI. It assumes you can already write Swift — `03-WRITING-THE-CODE.md` and `05-CONCURRENCY.md` own the code, `06-TESTING.md` owns what goes in a test; this file only owns how tests get *run*.

Rules are numbered `B1`–`B46` (B for build) and are stable — other files cite them by number, so new rules get letter suffixes (`B7a`, `B30a`) rather than renumbering. Cross-file citations are file-qualified: `05-CONCURRENCY.md R5`, never bare `R5`.

---

## 0. The baseline

| Thing | Version | How verified |
|---|---|---|
| Xcode | **26.6 (17F113)** | `xcodebuild -version`, 2026-07-27 |
| Swift compiler | **6.3.3** (`swiftlang-6.3.3.1.3`) | `swift --version` |
| iOS SDK in Xcode 26.6 | **26.5** — note it is *not* 26.6 | `xcodebuild -showsdks` |
| Bundled `swift-format` | **6.3.0** | `xcrun swift-format --version` |
| Host requirement | macOS Tahoe 26.2+ | Xcode 26.6 release notes |
| On-device debug floor | iOS 15+ | Xcode 26.6 release notes |
| Next major | Xcode 27 beta (Swift 6.4, iOS 27 SDK), **Apple silicon only**, debug floor iOS 17+ | Xcode 27 beta 4 release notes |

Apple moved to year-based OS numbering in 2025: **iOS 26 is the 2025 cycle, iOS 27 is the 2026 cycle, and there is no iOS 19–25.** A post about "iOS 20" is fabricated.

**Ship on Xcode 26.6 / Swift 6.3 / language mode 6.** Do not baseline on Xcode 27 while it is in beta — it is Apple-silicon-only and raises the on-device debugging floor to iOS 17, which locks out testers on older hardware. §15 covers what changes when you move. Everything version-sensitive below is marked inline; anything I could not confirm says so, and you should take that literally.

---

## 1. Language mode: the setting that decides everything else

A brand-new Xcode 26.6 app target is created with `SWIFT_VERSION = 5.0`. That is read out of `Project Templates/Base/Base_ProjectSettings.xctemplate/TemplateInfo.plist`, not folklore. The same template sets `SWIFT_APPROACHABLE_CONCURRENCY = YES` and, on the app target, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

That combination is a trap: it gives you the *ergonomics* of Swift 6 concurrency with none of the *enforcement*. `SWIFT_STRICT_CONCURRENCY` falls back to `minimal` at language mode 5, so data races stay warnings at best.

**B1. Set `SWIFT_VERSION` to Swift 6 language mode on every target.** Cost: a real migration on an existing codebase, days not hours. Deviate only if you have a large Objective-C boundary or a dependency that is not Swift 6 ready — then stay at `5.0` but set `SWIFT_STRICT_CONCURRENCY = complete` for the same diagnostics as warnings, and put a date on that state.

**B2. Write `SWIFT_VERSION = 6.0`. Not `6`, never `6.3`.** Three separate facts stack up here, and the middle one is the one nobody knows.

`SWIFT_VERSION` is the **language mode** — `4`, `4.2`, `5`, `6` — not the compiler version. Swift 6.3.3 compiler plus language mode 6 is the correct pairing; `6.3` is not a value.

`swiftc` accepts only the bare integer. Xcode strips the trailing `.0` before invoking it, which is why the stock template can write `5.0` at all:

```text
$ swiftc -swift-version 6   -typecheck x.swift   # OK
$ swiftc -swift-version 6.0 -typecheck x.swift   # error: invalid value '6.0' in '-swift-version 6.0'
```

But the **build-settings table does not normalise**, and one default is computed by string-pasting the version into a setting name (read out of `Swift.xcspec`, Xcode 26.6):

```text
SWIFT_STRICT_CONCURRENCY_DEFAULT =
    $(SWIFT_STRICT_CONCURRENCY_IN_SWIFT_VERSION$(_PREFIXED_SWIFT_VERSION:c99extidentifier):default=minimal)
_PREFIXED_SWIFT_VERSION = _$(SWIFT_VERSION)
SWIFT_STRICT_CONCURRENCY_IN_SWIFT_VERSION_6_0 = complete    # the only key of this shape that exists
```

`:c99extidentifier` rewrites `.` to `_`. So `6.0` → `..._6_0` → `complete`. A bare `6` → `..._6` → no such key → the `:default=minimal` fallback. Confirmed against a real app target on Xcode 26.6:

```text
$ xcodebuild -showBuildSettings -project App.xcodeproj -target App \
    SWIFT_VERSION=6   SWIFT_STRICT_CONCURRENCY='$(SWIFT_STRICT_CONCURRENCY_DEFAULT)' | grep STRICT
    SWIFT_STRICT_CONCURRENCY = minimal
$ xcodebuild … SWIFT_VERSION=6.0 … | grep STRICT
    SWIFT_STRICT_CONCURRENCY = complete
```

**Honest scope of the consequence:** enforcement is *not* affected. `swiftc -print-supported-features` reports `StrictConcurrency` as `enabled_in: 6`, so language mode 6 enables it either way — I checked, and `-swift-version 6` alone produces the same *error* on a global-mutable-state race that `-swift-version 5 -enable-upcoming-feature StrictConcurrency` produces. What breaks is everything that *reads* the table: the Xcode Build Settings UI, `-showBuildSettings`, and any CI audit you write will report `minimal` on a project that is actually strict. Someone will eventually act on that reading. `01-PROJECT-STRUCTURE.md P18` and `05-CONCURRENCY.md R2` both already write `6.0`; this rule is the reason they do, not a correction of them. The bare `6` you will meet in blog posts and answer sites is the string to distrust.

**B3. Migrate upcoming features with `MIGRATE`, not `YES`.** Several settings take `YES | MIGRATE | NO` and almost nobody uses the middle value:

```text
# Wrong: flip to YES on a 60k-line codebase, get 400 hard errors, revert in disgust.
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES

# Right: the compiler emits fix-its across the whole codebase instead of errors.
# Apply them, then flip to YES in the same PR.
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = MIGRATE
```

`MIGRATE` only works for features the compiler marks migratable. Check before you plan around it — `swiftc -print-supported-features` emits JSON with a `migratable` key per feature. On Swift 6.3.3, `ExistentialAny`, `MemberImportVisibility`, `NonisolatedNonsendingByDefault` and `InferIsolatedConformances` are migratable; `InternalImportsByDefault` is **not** (B7a).

Worth knowing why this is not optional work: those same four report `enabled_in: 7`. They become defaults in language mode 7. Adopting them now is paying down a migration you have already been scheduled for.

**B4. Know what the "Approachable Concurrency" checkbox does.** `SWIFT_APPROACHABLE_CONCURRENCY = YES` is shorthand for five upcoming-feature flags whose defaults are expressed in terms of it (read out of `Swift.xcspec`, Xcode 26.6):

| Compiler feature name | Proposal | Xcode build setting |
|---|---|---|
| `NonisolatedNonsendingByDefault` | SE-0461 | `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT` |
| `InferIsolatedConformances` | SE-0470 | `SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES` |
| `GlobalActorIsolatedTypesUsability` | SE-0434 | `SWIFT_UPCOMING_FEATURE_GLOBAL_ACTOR_ISOLATED_TYPES_USABILITY` |
| `InferSendableFromCaptures` | SE-0418 | `SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES` |
| `DisableOutwardActorInference` | SE-0401 | `SWIFT_UPCOMING_FEATURE_DISABLE_OUTWARD_ACTOR_ISOLATION` |

The last three additionally OR against `SWIFT_UPCOMING_FEATURE_6_0` — they are exactly the three the compiler reports as `enabled_in: 6`. What they *mean* for your code is `05-CONCURRENCY.md`'s subject; this file only tells you where the switch is.

**Read the last row twice.** The build setting says `…DISABLE_OUTWARD_ACTOR_ISOLATION`; the flag it passes to `swiftc` says `DisableOutwardActorInference`. `Swift.xcspec` spells it out — `CommandLineArgs = { YES = ("-enable-upcoming-feature", "DisableOutwardActorInference"); }`. Copy the *build setting* spelling into `.enableUpcomingFeature(…)` and you get a flag that does nothing: `swiftc -enable-upcoming-feature DisableOutwardActorIsolation` exits **0 with no diagnostic** on 6.3.3, because unrecognised feature names are silently accepted and silently ignored. `swiftc -print-supported-features` is how you check a name before committing it.

---

## 2. xcconfig files: every setting, one place

**B5. Every build setting lives in an `.xcconfig`. `project.pbxproj` holds zero build settings.** The reason is precedence — Xcode resolves lowest to highest:

```text
platform defaults → project xcconfig → project build settings → target xcconfig → target build settings
```

A value someone typed into the target's Build Settings tab **silently beats your target xcconfig**. That is how a project ends up with a `-Onone` release build nobody can explain. "Use xcconfigs" without "and empty the pbxproj" is half the advice. Cost: you give up the Build Settings UI as an editing surface and must teach everyone to stop using it. Deviate for nothing; this one has no good exception.

**B6. Check the pbxproj is clean in CI, not by eye.** Every `buildSettings = { … }` block should be empty. `baseConfigurationReference` is a *sibling* key of `buildSettings` inside `XCBuildConfiguration`, not a member of it, so a clean block has nothing between its braces.

```bash
#!/bin/bash
# Scripts/check-pbxproj-clean.sh — fails if any target carries an inline build setting.
set -uo pipefail
project="${1:-MyApp.xcodeproj}/project.pbxproj"

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
```

Three details that version fixes, each reproduced before being written down:

- **`grep -A20` cannot work.** A fixed twenty-line window runs past the block's `};` into `name = Debug;` and `isa = XCBuildConfiguration;`, which survive the filter and report a clean project as dirty. An `awk` range ends at the block's own closing brace.
- **`… | grep -q . && { …; exit 1; }` fails when it succeeds.** Finding nothing means grep exits `1`; as the script's last command that becomes the script's status — clean project, red build. Capture the output, test it with `if`, end on a command that exits `0`.
- **Use POSIX classes, not `\s`.** macOS 26 ships BSD grep 2.6.0-FreeBSD, which does accept `\s` under `-E`, so the popular claim that this breaks on `macos-26` did not reproduce. `[[:space:]]` is portable to every grep you will meet and costs four characters.

Run it against a known-clean *and* a known-dirty project before trusting it. A check that cannot fail is worse than no check.

**B7. Use this layout** — four files, one optional and gitignored.

```text
Config/
  Base.xcconfig        # everything common
  Debug.xcconfig       # #include "Base.xcconfig"
  Release.xcconfig     # #include "Base.xcconfig"
  Local.xcconfig       # gitignored; #include? "Local.xcconfig" from Base
```

```text
// Config/Base.xcconfig
#include? "Local.xcconfig"          // optional include: no error when absent

SWIFT_VERSION = 6.0                 // B2 — the ".0" is load-bearing
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES          // 03-WRITING-THE-CODE.md W43 names the price
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES // B7b names the price
SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT = YES  // B7a names the price

// The floor is 01-PROJECT-STRUCTURE.md §5b's ruling, not this file's. Keep it equal to
// `platforms: [.iOS(.v18), …]` in Modules/Package.swift — those are the only two places.
IPHONEOS_DEPLOYMENT_TARGET = 18.0

INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO   // B37; see 01-PROJECT-STRUCTURE.md P30

MARKETING_VERSION = 1.4.2
CURRENT_PROJECT_VERSION = 1          // overridden from CI, see B27

ENABLE_USER_SCRIPT_SANDBOXING = YES

// Conditional syntax: [sdk=…], [arch=…], [config=…]
OTHER_SWIFT_FLAGS[config=Release] = $(inherited) -warnings-as-errors
```

Deliberately absent: `SWIFT_STRICT_CONCURRENCY`, because at `SWIFT_VERSION = 6.0` it already resolves to `complete` (B2), and `DEAD_CODE_STRIPPING`, because it is already `YES` for app targets (B13). Do not restate defaults in an xcconfig — every redundant line is a line someone will later "fix".

**B7a. `INTERNAL_IMPORTS_BY_DEFAULT` changes how you write `import`, and it is documented here because this file is what turns it on.** Under SE-0409 an undecorated `import` becomes `internal`. The moment a `public` declaration mentions a type from a dependency, the import supplying it must be raised to match — otherwise you get *"function cannot be declared public because its parameter uses an internal type"* (verbatim, Swift 6.3.3), pointing at the declaration, with nothing visibly wrong there:

```swift
// ❌ Error under InternalImportsByDefault, and it points at `fetch`, not at the import that caused it.
import Networking

public func fetch(with client: HTTPClient) async throws -> Order { … }
```

```swift
// ✅ The import's access level must be at least that of the API leaking the type.
public import Networking

public func fetch(with client: HTTPClient) async throws -> Order { … }
```

```swift
// ✅ Better in a one-package layout: keep the API `package`, keep the import `package`.
//    Nothing leaks out of the package, so nothing has to be public.
package import Networking

package func fetch(with client: HTTPClient) async throws -> Order { … }
```

One sentence: **an import's access level must be at least as visible as the most visible declaration that exposes a type from it.** Everything you do not export stays a plain `internal import`. That is a feature — it lets the compiler skip rebuilding your module when an internal-only dependency changes, and it forces you to notice when a supposedly-internal dependency has leaked into your public surface. `03-WRITING-THE-CODE.md §2` owns access control generally; this interaction lives here because the flag above produces it.

**Deviate** by dropping the flag if you are adopting all of this on an existing codebase in one sitting. `MIGRATE` will not help: `InternalImportsByDefault` has no `migratable` flag in `-print-supported-features`, so unlike `ExistentialAny` there are no fix-its — it is errors or nothing. Turn it on module by module, smallest first, and treat the errors as a free audit of your public surface.

**B7b. `MEMBER_IMPORT_VISIBILITY` makes *members* obey the same import rules as top-level names, and the bill arrives as one wave of errors.** SE-0444 (implemented in Swift 6.1), the third flag in the block above, and the one nobody can tell you the price of before they turn it on.

Today a member — a method on a struct, and above all a method added in an `extension` — is in scope if its module is reachable *transitively*: imported in some other file of yours, or a dependency of a dependency. Top-level functions have never worked that way. Under the flag, both work the same way, and every call that was quietly resolving through a transitive import stops compiling:

```swift
// ❌ RecipeKit is imported in another file of this module, not in this one.
//    error: instance method 'parse()' is inaccessible due to missing import
//           of defining module 'RecipeKit'
//    note: add import of module 'RecipeKit'
let recipe = "2 slices of bread, 1.5 tbs peanut butter".parse()
```

```swift
// ✅ The fix is the note, every time: import the module that declares the member.
import RecipeKit

let recipe = "2 slices of bread, 1.5 tbs peanut butter".parse()
```

**What you buy** is the ambiguity this prevents. SE-0444's own motivation: add a second dependency that also extends `String` with `parse()`, in a file you never touched, and the call above becomes `error: Ambiguous use of 'parse()'` — a break in file A caused by an import in file B. Under the flag each file's imports decide what that file can see, so the conflict cannot travel.

**What it costs** is one mechanical sweep proportional to how much extension API you reach through transitive dependencies, which in a Foundation-and-SwiftUI app is usually small and in a codebase leaning on a package's extension-heavy API is not. `MIGRATE` *does* work here — `MemberImportVisibility` is on B3's migratable list, so the compiler emits the "add import of module" fix-its across the whole codebase instead of errors. That is the difference from B7a and the reason this flag is cheap to adopt: run `MIGRATE`, apply the fix-its, flip to `YES`, one PR. It reports `enabled_in: 7`, so you are paying down scheduled work either way.

**B8. `//` is a comment delimiter everywhere, including inside what looks like a string.**

```text
# Wrong — the value becomes "https:"
API_BASE_URL = https://api.example.com

# Right — store the host, prepend the scheme in Swift
API_HOST = api.example.com
```

Getting that value into the running app collides with `01-PROJECT-STRUCTURE.md P30` (**a new project should have no `Info.plist`**), and the collision has a precise resolution.

**`INFOPLIST_KEY_*` only covers keys Apple already knows about.** swift-build's `InfoPlistProcessorTaskAction.swift` walks a fixed `generatedInfoPlistKeys` array — `CFBundleDisplayName`, `ITSAppUsesNonExemptEncryption`, `LSApplicationCategoryType`, the `NS*UsageDescription` family and so on — and copies the matching `INFOPLIST_KEY_<key>` setting into the generated plist. There is no wildcard. `INFOPLIST_KEY_APIHost` is silently ignored, which is the worst possible failure mode for a value you resolve at runtime.

A **custom** key is therefore exactly P30's carve-out, and you materialise the smallest possible plist for it:

```text
// Config/Base.xcconfig
API_HOST = api.example.com

GENERATE_INFOPLIST_FILE = YES        // keep generating Apple's keys…
INFOPLIST_FILE = App/Info.plist      // …and merge them into this file
```

```xml
<!-- App/Info.plist — custom keys only. Anything Apple knows about stays a build setting. -->
<key>APIHost</key>
<string>$(API_HOST)</string>
```

Two behaviours make that work, both confirmed on Xcode 26.6: `GENERATE_INFOPLIST_FILE = YES` alongside `INFOPLIST_FILE` **merges** rather than replaces (generated keys are added to your file; yours win on conflict), and `INFOPLIST_EXPAND_BUILD_SETTINGS` defaults to `YES`, which is what expands `$(API_HOST)`. Then:

```swift
var components = URLComponents()
components.scheme = "https"
components.host = Bundle.main.object(forInfoDictionaryKey: "APIHost") as? String
```

The alternative — a generated Swift constant — costs you a run-script phase, which B15 makes you pay for on every build. For one or two static strings the four-line plist is the cheaper trade.

**B9. Always write `$(inherited)` when appending.** `OTHER_SWIFT_FLAGS = -foo` silently drops platform defaults and everything from the included file. `OTHER_SWIFT_FLAGS = $(inherited) -foo` does not.

**B10. `.xcconfig` files must not be members of any target.** If they are, they are copied into the `.ipa` and you ship your build configuration to users. Check Target Membership in the File Inspector after adding one.

**B11. Prefix your own helper variables.** Unprefixed names are Apple's namespace. `MY_API_HOST` will not collide with a setting Apple adds in Xcode 28; `API_HOST` might.

---

## 3. Build settings worth setting deliberately

Defaults read from `Swift.xcspec` / `CoreBuildSystem.xcspec` in Xcode 26.6 on 2026-07-27, and effective values confirmed with `xcodebuild -showBuildSettings` against a real `com.apple.product-type.application` target.

| Setting | Toolchain default | Effective for an app target | Set it to | Why |
|---|---|---|---|---|
| `SWIFT_VERSION` | `''` | template writes `5.0` | `6.0` | B1, B2 |
| `SWIFT_COMPILATION_MODE` | `singlefile` | `singlefile` | `wholemodule` **Release only** | Cross-file optimization; destroys incremental builds in Debug |
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` | `-O` | `-Onone` Debug, `-O` Release | B12 |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS` | `NO` | `NO` | `YES` in CI/Release only | B18 |
| `DEBUG_INFORMATION_FORMAT` | `dwarf` | `dwarf` | `dwarf-with-dsym` Release | dSYMs for symbolication |
| `ENABLE_TESTABILITY` | `NO` | `NO` | `YES` Debug only | `@testable import` |
| `ONLY_ACTIVE_ARCH` | `NO` | `NO` | `YES` Debug only | Roughly halves Debug build time |
| `ENABLE_NS_ASSERTIONS` | `YES` | `YES` | `NO` Release | Template already does this |
| `DEAD_CODE_STRIPPING` | `NO` | **`YES`** | leave alone | B13 |
| `ENABLE_USER_SCRIPT_SANDBOXING` | `NO` | **`NO`** (template writes `YES`) | `YES` | B14 |

**B12. `-Osize` is the Swift size lever and it is not the default.** Apple's app-size documentation says "the default optimization level for the Release configuration is Fastest, Smallest [-Os]" — that sentence is about `GCC_OPTIMIZATION_LEVEL` (C/ObjC) and does not apply to Swift. The verified `SWIFT_OPTIMIZATION_LEVEL` default is `-O`, and the accepted values are exactly `-Onone`, `-O`, `-Osize`. If your binary is over budget, moving Release to `-Osize` is a real lever; measure your hottest path before keeping it.

**B13. `DEAD_CODE_STRIPPING` resolves to `YES` for an app target — do not set it.** The spec default is `NO` and no project template overrides it, which is why this is widely repeated as a thing you must turn on. It is not: I resolved it against a real application target on Xcode 26.6 and got `YES`. The only product type that pins it to `NO` in `ProductTypes.xcspec` is `com.apple.product-type.objfile`. Run `xcodebuild -showBuildSettings -scheme MyApp | grep DEAD_CODE` on your own project rather than trusting either the spec or me.

**B14. Leave `ENABLE_USER_SCRIPT_SANDBOXING = YES` on.** The widely repeated "it defaults to YES since Xcode 15" is **false as stated** — the build-system default is `NO` (confirmed: a hand-built project with no template settings resolves to `NO`); the *new-project template* writes `YES`. That distinction is exactly why pre-Xcode-15 projects never hit sandbox errors and new ones hit them constantly. With it on, a run-script phase may only read and write files it declares as inputs and outputs; violations appear as `Sandbox: <tool>(pid) deny(1) file-read-data …` and fail the build. Fix by declaring inputs and outputs, or by moving the tool out of the build (§5). Turning the setting off to make CocoaPods or a codegen script work trades a real security control for five minutes.

---

## 4. Run-script build phases

Apple is unusually blunt in *Improving the speed of incremental builds*: Xcode runs custom scripts during **every** build cycle, **serially** with respect to other tasks. A phase re-runs when any of these hold:

1. it has no input files; 2. it has no output files; 3. an input changed; 4. an output is missing.

**B15. Every run-script phase declares at least one input and one output — even when it needs neither.** Apple says so explicitly: "For a script that requires no input, provide a file that never changes as the input file. For a script with no outputs, create a static output file from your script."

```bash
# Wrong: no inputs, no outputs. Runs on every build, serially, forever.
"$SRCROOT/Scripts/generate-api-client.sh"
```

```bash
# Right: declared in the phase's Input Files / Output Files boxes.
#   Input Files:  $(SRCROOT)/api/openapi.yaml
#   Output Files: $(DERIVED_FILE_DIR)/APIClient.generated.swift
"$SRCROOT/Scripts/generate-api-client.sh" \
  "$SRCROOT/api/openapi.yaml" \
  "$DERIVED_FILE_DIR/APIClient.generated.swift"
```

Use `.xcfilelist` files once the list outgrows the UI.

**B16. Measure before arguing about build times.** `Product > Perform Action > Build With Timing Summary`, or `xcodebuild -showBuildTimingSummary` on CI. Apple names "extraneous tasks, such as custom scripts" as the first thing to look for. Two more cheap wins from the same document: set the scheme's **Build Order** to **Dependency Order** so targets build in parallel, and set `DEFINES_MODULE = YES` on your own frameworks so the compiler caches module symbol information instead of re-preprocessing headers per source file.

---

## 5. Formatting, linting and warnings

**Use Apple's bundled `swift-format`.** It ships inside Xcode (16 and later; 26.6 bundles **6.3.0**) — no install, no SPM dependency, no version to keep in sync with the toolchain. IDE entry point: `Editor > Structure > Format File with 'swift-format'`. Config is `.swift-format` at the repo root (`01-PROJECT-STRUCTURE.md P39` — one file, root, it walks up from each source file).

```bash
# Non-mutating, for CI. Both roots: App/ is the shell, Modules/Sources is the code (01 §1).
xcrun swift-format lint --strict --recursive App Modules/Sources

# Mutating, for the pre-commit hook and the editor.
xcrun swift-format format --in-place --recursive App Modules/Sources

# Audit after a toolchain bump: defaults move between releases, and your committed
# file is only the delta, so read this diff rather than overwriting the file with it.
xcrun swift-format dump-configuration | diff - .swift-format
```

**Do not write `dump-configuration > .swift-format`.** That freezes all 43 rules and every formatting setting at today's toolchain values, so the next Xcode silently leaves you on stale defaults and the diff above stops meaning anything. `03-WRITING-THE-CODE.md W54` owns the committed file and it is seven lines of delta — this file owns only *where* the formatter runs.

Honest disagreement: plenty of practitioners prefer Nick Lockwood's SwiftFormat for its far larger rule set, and they are not wrong. **Rule: default to `swift-format`** — zero-dependency and swiftlang-maintained beats configurable. Switch to SwiftFormat if your team already encodes style opinions Apple's tool cannot express. SwiftLint (0.65.0, 2026-06-27) is a *linter*, not a formatter; add it when you want rules formatting cannot express. Naming conventions are not those rules — `02-NAMING-AND-API-DESIGN.md` owns them, and encoding them as lint regexes produces false positives faster than value.

**B17. Never put a formatter in a run-script build phase.** Three independent reasons, each checkable:

1. A formatter has no meaningful inputs or outputs to declare, so per B15 it runs on every incremental build, serially, taxing every build anyone ever does.
2. It writes across your whole source root, which `ENABLE_USER_SCRIPT_SANDBOXING = YES` denies. The workaround everyone reaches for is disabling sandboxing project-wide: a real security regression bought for a cosmetic feature.
3. It mutates files underneath the compiler mid-build, which is how you get stale-state weirdness.

A large chunk of the community does exactly this, so expect pushback. The pipeline instead:

| Task | Where | Command |
|---|---|---|
| Format | On save in the editor, and/or a pre-commit hook | `swift-format format --in-place` |
| Lint | Its own CI job | `swift-format lint --strict` — and `swiftlint lint --strict` **as well**, only if you are a team (`03-WRITING-THE-CODE.md W56`) |
| Warnings-as-errors | The build, in CI/Release | `-warnings-as-errors` |

A **lint-only** (non-mutating) phase with declared inputs is defensible if you want in-Xcode signal. A **format** phase is not. SwiftLint's own tracker notes that scheme-based scripts give no inline editor feedback anyway, which removes most of the benefit.

**B18. Warnings become errors in CI and Release, not in Debug.** Blocking local iteration on an unused variable mid-refactor is how you train people to disable the linter wholesale. Gate it: `OTHER_SWIFT_FLAGS[config=Release] = $(inherited) -warnings-as-errors`.

**B19. Prefer targeted warning control, and put the blanket flag first.** SE-0443 (Swift 6.1+) adds `-Werror <group>` / `-Wwarning <group>` over diagnostic groups. **Flags apply left to right**, so a trailing `-warnings-as-errors` silently overrides an earlier exemption. Verified on 6.3.3 against a deprecated-call test file:

```text
# Wrong: the trailing blanket flag wins — the exemption does nothing.
-Wwarning DeprecatedDeclaration -warnings-as-errors
  → dep.swift:3:17: error: 'old()' is deprecated

# Right: blanket first, exemptions last.
-warnings-as-errors -Wwarning DeprecatedDeclaration
  → dep.swift:3:17: warning: 'old()' is deprecated [#DeprecatedDeclaration]
```

You do not have to guess group names: the compiler prints them in brackets at the end of each diagnostic, exactly as shown. And unlike upcoming-feature names (B4), a typo here is *not* silent — `swiftc -Werror NotARealGroup` emits `warning: unknown warning group: 'NotARealGroup' [#UnknownWarningGroup]`. Promote that group to an error in CI and typos in your own warning config stop shipping.

SE-0522 adds in-source warning control; Swift 6.4 adds a `@diagnose` attribute in the same space (Xcode 27 beta, not shipping).

---

## 6. `Package.swift`

Module boundaries and when to split a package are `01-PROJECT-STRUCTURE.md`'s subject. This is manifest mechanics only — in particular the deployment floor and the macOS pairing below are `01-PROJECT-STRUCTURE.md §5b`'s call, reproduced here so the manifest is copyable, not re-decided here.

```swift
// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),                    // redundant at tools 6.2+, but states intent
    .defaultIsolation(MainActor.self),          // PackageDescription 6.2+
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "Feature",
    defaultLocalization: "en",
    // iOS: 01 §5b's ruling; must equal IPHONEOS_DEPLOYMENT_TARGET in Config/Base.xcconfig (B7).
    // macOS: not optional — it is what `swift test` builds against on the host (01 P23).
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "Feature", targets: ["Feature"])],
    targets: [
        .target(
            name: "Feature",
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FeatureTests",
            dependencies: ["Feature"],
            swiftSettings: swiftSettings
        ),
    ]
)
```

**B20. Never use `unsafeFlags` in a package you intend to publish.** A package using `unsafeFlags` cannot be consumed as a versioned dependency — SwiftPM refuses to resolve it. Use `enableUpcomingFeature` and `swiftLanguageMode`. (Long-standing SwiftPM behaviour; re-check against current SwiftPM docs if you are betting a decision on it.)

**B21. `defaultIsolation(MainActor.self)` needs `swift-tools-version: 6.2` or later.** Apple documents it as "First available in PackageDescription 6.2"; the only valid arguments are `MainActor.self` and `nil`, and the unspecified default is `nonisolated`. The Swift 6.3 toolchain in Xcode 26.6 satisfies this. (The mapping from "PackageDescription 6.2" to `// swift-tools-version: 6.2` is conventional, not stated verbatim on Apple's page.) Which modules should get `MainActor` and which should stay `nonisolated` is `05-CONCURRENCY.md R5`.

**B22. Load package resources through the module's own bundle. Never `Bundle.main`.**

```swift
// ✗ Works in an app target; breaks in tests and in every consumer of the package.
let url = Bundle.main.url(forResource: "settings", withExtension: "plist")

// △ Correct, and what SwiftPM's own documentation still says.
let url = Bundle.module.url(forResource: "settings", withExtension: "plist")

// ✓ Current Apple guidance, and what to write in new code.
let url = #bundle.url(forResource: "settings", withExtension: "plist")
```

`01-PROJECT-STRUCTURE.md P36` rules for `#bundle` and documents the source conflict (SwiftPM docs still say "always `Bundle.module`"); this file defers to it. One mechanical caveat worth knowing before you sweep a codebase: **`#bundle` carries `@available(iOS 15, macOS 12, …)`**, so a package with no `platforms:` floor fails to build with `'bundle()' is only available in macOS 12 or newer`. Read that error message literally — it names **macOS**, because `swift test` builds for the host, and it is the `.macOS(.v15)` entry in the manifest above that fixes it. Adding only an iOS floor leaves the message exactly where it was. Declare both platforms, or stay on `Bundle.module` for that target.

Resource declaration (tools 5.3+): XIBs/storyboards, `.xcdatamodeld`, asset catalogs and `.lproj` folders are picked up automatically. Everything else needs `.process(_:)` — the default choice, applies platform-appropriate processing recursively and **flattens** into the bundle root — or `.copy(_:)`, verbatim and **preserving directory structure**. Use `.copy` only when you genuinely need the layout, and `exclude:` for non-resource files (docs, fixtures) that happen to live in the target folder.

---

## 7. Schemes and test plans

`06-TESTING.md` owns what to test and how to write it. This is the wiring.

**B23. One scheme per module plus one umbrella scheme.** Apple, verbatim: "If your product has multiple targets — like an iOS app that contains a static library and a widget extension — create a scheme for each of the individual targets in addition to an 'umbrella' scheme that builds the whole product suitable for release." Per-module schemes give fast local feedback; the umbrella scheme is what CI archives. Cost: more schemes to keep shared in `xcshareddata/xcschemes/` (`01-PROJECT-STRUCTURE.md P43`).

**B24. Drive test-plan membership with Swift Testing tags, not checkbox lists.** From Xcode 16 the plan editor has *Include Tags* / *Exclude Tags* with Any/All semantics, so a plan becomes a filter that never goes stale rather than a list someone forgets to update.

`06-TESTING.md` T29/T30 own the tag vocabulary, and it is exactly eight tags on two axes:

| Axis | Tags |
|---|---|
| Kind — what the test *is* | `.unit`, `.integration`, `.snapshot`, `.ui`, `.performance` |
| Cadence — when you can afford to run it | `.presubmission`, `.nightly`, `.prerelease` |

**Build one plan per cadence tag and name the plan after the tag, capitalised:** plan `Presubmission` includes `.presubmission`, `Nightly` includes `.nightly`, `Prerelease` includes `.prerelease`. That is what makes keeping this file and 06 in sync mechanical instead of a promise — the plan name *is* the tag name.

Do not invent a tag at this end. There is no `.smoke`: 06 T29 notes that a tag which is never declared is a **compile error**, so `.tags(.smoke)` in a test does not build, and a "Smoke" plan whose include-tag filter names something 06 never declares selects nothing and reports a green run over zero tests.

**B25. Set Execution Order to Random in at least one plan configuration.** Alphabetical order hides inter-test dependence until the day it does not.

**B26. Use plan *configurations* for anything you would otherwise run by hand.** A plan has one or more configurations and Xcode runs the whole plan **once per configuration**. The knobs: Application Language / Region, Simulated Location, Execution Order, Test Timeouts, Test Repetition Mode, Code Coverage, and the sanitizers (ASan, TSan, UBSan, Main Thread Checker, Zombie Objects, Malloc Guard Edges/Scribble). This is how RTL and double-length localization coverage becomes free (B40). Cost is linear: two configurations is two full runs, so keep the expensive ones out of the PR plan.

```bash
xcodebuild -scheme MyApp -showTestPlans
xcodebuild -scheme MyApp test -testPlan "Presubmission"
xcodebuild -scheme MyApp test -testPlan "Nightly" --only-test-configuration "RTL"
xcodebuild -scheme MyApp test -testPlan "Nightly" --skip-test-configuration "Sanitizers"
```

The inconsistent dashes are Apple's, not a typo: `-testPlan` takes one, `--only-test-configuration` takes two.

---

## 8. Versioning

- `MARKETING_VERSION` → `CFBundleShortVersionString` — the "1.4.2" users see.
- `CURRENT_PROJECT_VERSION` → `CFBundleVersion` — the build number, which must strictly increase per upload within a marketing version.

Both have empty defaults in the toolchain spec; the template populates them.

**B27. `MARKETING_VERSION` lives in the xcconfig and a human changes it at release time. `CURRENT_PROJECT_VERSION` is injected by CI as a command-line build setting.**

```bash
# Right: overrides the xcconfig for this invocation, dirties nothing.
xcodebuild archive … CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER
```

```bash
# Wrong: rewrites files on disk and forces a commit from CI.
agvtool new-version -all "$GITHUB_RUN_NUMBER"
```

`agvtool` additionally requires `VERSIONING_SYSTEM = apple-generic` and is largely legacy. A `PlistBuddy` run-script phase is worse — it re-runs on every build (B15). Deviate only if your release process genuinely requires the build number to be committed and tagged; then bump it in a release commit, not in CI.

---

## 9. CI on GitHub Actions

**B28. Pin `macos-26`. Never use `macos-latest`.** `macos-latest` began pointing at `macos-26` on 2026-06-15; the next time it moves, it moves mid-sprint. The `macos-26` arm64 image carries macOS 26.4, Xcode 26.0.1 through 26.6, and iOS runtimes 26.2, 26.4 and 26.5 (image README, 2026-07-27 — these change monthly, re-read before pinning a runtime).

**B29. Select Xcode explicitly with `xcode-select`.** The image's *default* Xcode is 26.5 even though 26.6 is installed, so relying on the default silently downgrades you. Plain `xcode-select` is also one fewer third-party action in your supply chain:

```yaml
- run: sudo xcode-select -s /Applications/Xcode_26.6.app
```

**B30. Do not hardcode a simulator name + OS pair.** `-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` works until the image bumps runtimes, then fails with "Unable to find a destination" — the single most common iOS CI breakage. Use `OS=latest` with a fixed device name, or resolve a UDID at run time:

```bash
UDID=$(xcrun simctl list devices available --json \
  | jq -r '.devices | to_entries[] | select(.key|test("iOS-26")) | .value[]
           | select(.name=="iPhone 17 Pro") | .udid' | head -1)
xcodebuild test -scheme MyApp -destination "id=$UDID"
```

**B30a. Pass `-skipMacroValidation` on CI if you depend on any macro.** Macro packages are trusted per-machine through an interactive Xcode prompt that a headless runner cannot answer; without the flag the build fails on a fresh runner every time. The flag is real (`xcodebuild -help`, Xcode 26.6) and its own help text says what you are accepting: "this can be a security risk if they are not from trusted sources." That is a fair trade for macros you have pinned in `Package.resolved` and a bad one for anything resolved from a moving branch. `-skipPackagePluginValidation` is the same bargain for build-tool plugins.

**B31. `set -o pipefail` before piping `xcodebuild` into a formatter.** Without it the pipeline's exit status is the formatter's, `xcodebuild`'s non-zero status is swallowed, and CI goes green on failing tests. This is the number one silent-failure bug in iOS CI and it sits undetected for months.

```yaml
name: CI
on:
  pull_request:
  push: { branches: [main] }

concurrency:                       # cancels superseded runs; directly saves macOS minutes
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest         # Linux costs roughly a tenth of macOS
    container: swift:6.3.3         # the toolchain ships swift-format; on Linux it is `swift format`
    steps:
      - uses: actions/checkout@v4
      - run: swift format lint --strict --recursive App Modules/Sources

  test:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -s /Applications/Xcode_26.6.app

      - uses: actions/cache@v4
        with:
          path: .build
          key: spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-

      # Seconds, and it fails before anything boots a simulator. §9.1.
      - name: Source hygiene
        run: Scripts/check-source-hygiene.sh

      # 01 P23: swift test is the inner loop, so CI runs it too. No simulator, no host app.
      - name: Package tests
        run: swift test --package-path Modules

      - name: App and UI tests
        run: |
          set -o pipefail
          xcodebuild test \
            -scheme MyApp \
            -testPlan Presubmission \
            -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
            -resultBundlePath TestResults.xcresult \
            -derivedDataPath DerivedData \
            -skipMacroValidation \
            CURRENT_PROJECT_VERSION=${{ github.run_number }} \
            | xcbeautify --renderer github-actions

      - if: always()
        run: xcrun xcresulttool get test-results summary --path TestResults.xcresult --compact
```

`xcbeautify --renderer github-actions` emits workflow commands, so warnings and errors annotate the PR diff instead of hiding in a log; it is preinstalled on the image.

Three things about that file are deliberate and get argued about:

- **`swift-format`, not SwiftLint.** §16 rules for the bundled formatter and `03-WRITING-THE-CODE.md W56` adds SwiftLint "only when you have a *team*" and want rules a formatter cannot express — cyclomatic complexity, file length, forbidden APIs. A solo project that copies a SwiftLint job has installed the tool this guide told it to skip and is running no `swift-format lint` at all. If you are a team and you do want it, add a **second** job (`ghcr.io/realm/swiftlint:0.65.0 swiftlint lint --strict` in a container, plus the `.swiftlint.yml` you will have to write) — alongside the lint job above, never instead of it.
- **Both runners.** `01-PROJECT-STRUCTURE.md P23` requires `swift test` locally *and* both runners on CI, and `06-TESTING.md §18` calls the package run "by far the biggest win". The `xcodebuild` step alone never runs a package test.
- **`swift format`, not `xcrun swift-format`.** Same binary, different invocation: swift-format's README states Swift 6 and later toolchains include it and that you run it as `swift format` (space, not dash) anywhere on the system, which is why the Linux container needs no install step. On the macOS runner it is `xcrun swift-format` (§5).

**B32. Lint on `ubuntu-latest`; keep macOS for simulator work and archives.** macOS runners bill at roughly ten times Linux against included minutes and at a much higher per-minute rate. (The figures circulating in 2026 come from cost aggregators, not GitHub's docs — the direction is certain, the numbers are not; check your own billing page.) Tactics that hold regardless of pricing: `concurrency.cancel-in-progress`; run pure-SwiftPM unit tests on Linux; split `build-for-testing` and `test-without-building` across jobs; tag UI tests and gate them to a nightly plan.

**B33. Parse results with `xcresulttool get test-results`, not `get object`.** `get object --format json` is **deprecated as of Xcode 16** and will be removed. Current subcommands, verified on Xcode 26.6: `summary`, `tests`, `test-details`, `activities`, `insights`, `metrics`. Discover the shape with `xcrun xcresulttool help get test-results summary`.

**B34. Cache SPM. Think twice about caching DerivedData.** Caching `.build` / SourcePackages keyed on `Package.resolved` is straightforward and worth it. DerivedData caching is fragile because Xcode's build system keys off file modification timestamps and `actions/cache` does not preserve them — `irgaly/xcode-cache` exists purely to restore mtimes with nanosecond precision. Reach for it only when build time is genuinely your bottleneck, and expect to babysit it.

### 9.1 Source-hygiene checks

**B34a. Four rules elsewhere in this guide say "enforce it with a CI grep". This is that job, and it is one script.** They are cheap, they are the kind of thing nobody catches by eye, and each of them fails silently in production if you skip it — so they belong together, in the `test` job, before anything boots a simulator.

| # | Rule | What it catches | Owner |
|---|---|---|---|
| 1 | Banned file names | `Helpers.swift`, `Date+Utilities.swift` — the bin you swore you would not start | `01-PROJECT-STRUCTURE.md P28` |
| 2 | `record: .all` on `main` | A snapshot suite that re-records instead of asserting, forever, silently | `06-TESTING.md T51` |
| 3 | Escape hatch with no justifying comment | `@unchecked Sendable` etc. as an undocumented promise to a compiler that cannot check it | `05-CONCURRENCY.md R29` |
| 4 | `TestSupport` reachable from the app | `import Testing` in the shipping binary: your fixtures, builders and `Issue.record` strings ship | `06-TESTING.md T5a` |

```bash
#!/bin/bash
# Scripts/check-source-hygiene.sh — the four greps this guide promises, as one job.
# Run from the repo root. Prints every category that has offenders, then exits 1.
set -uo pipefail

roots=(App Modules)          # every directory holding Swift you wrote
package=Modules              # the local SwiftPM package
status=0

report() { status=1; printf '\n%s\n%s\n' "$1" "$2" >&2; }

# 1. Banned file names — 01-PROJECT-STRUCTURE.md P28.
banned='Utils|Utilities|Helpers|Constants|Extensions|Managers|Common|Shared'
hits=$(find "${roots[@]}" -name '*.swift' \
  | grep -E "/($banned)\.swift$|\+Utilities\.swift$" || true)
[ -n "$hits" ] && report 'Banned file names (01 P28) — name the capability:' "$hits"

# 2. Snapshot record mode — 06-TESTING.md T51.
hits=$(grep -rn --include='*.swift' -E 'record:[[:space:]]*\.all' "${roots[@]}" || true)
[ -n "$hits" ] && report 'record: .all reached main (06 T51) — re-record locally, commit .failed:' "$hits"

# 3. Concurrency escape hatches need a justifying comment — 05-CONCURRENCY.md R29.
hatches='@unchecked Sendable|nonisolated\(unsafe\)|@preconcurrency import|Task\.detached|assumeIsolated'
hits=$(
  grep -rn --include='*.swift' -E "$hatches" "${roots[@]}" \
    | cut -d: -f1,2 \
    | while IFS=: read -r file line; do
        start=$(( line > 1 ? line - 1 : 1 ))
        sed -n "${start},${line}p" "$file" | grep -q '//' || printf '%s:%s\n' "$file" "$line"
      done
)
[ -n "$hits" ] && report 'Escape hatch with no justifying comment (05 R29):' "$hits"

# 4. TestSupport must not be reachable from anything the app links — 06-TESTING.md T5a.
hits=$(
  swift package describe --package-path "$package" --type json \
    | jq -r '
        [ .products[] | select(.targets | index("TestSupport")) | "product \(.name)" ]
      + [ .targets[] | select(.type != "test")
          | select((.target_dependencies // []) | index("TestSupport"))
          | "target \(.name)" ]
        | .[]'
)
[ -n "$hits" ] && report 'TestSupport is reachable from the app (06 T5a) — Testing will ship:' "$hits"

[ "$status" -eq 0 ] && echo 'Source hygiene: clean'
exit "$status"
```

Four things about it that took a run against a deliberately dirty repo to get right, in B6's spirit — a check that cannot fail is worse than no check:

- **Check 3 tests a two-line window, not the matched line.** `05 R29` asks for a *justifying comment*, and people write it above the declaration as often as beside it. `sed -n "${start},${line}p" | grep -q '//'` accepts both and only flags the bare hatch. The `line > 1` guard is not decoration: `sed -n '0,1p'` is an error, and a hatch on line 1 is exactly the case you want reported.
- **Check 4 does not need a transitive walk.** Any path from the app to `TestSupport` ends in an edge `X → TestSupport` where `X` is something the app links — and the app links no test target. So "no non-test target names `TestSupport`" is *equivalent* to the closure query and is one `jq` filter instead of a fixed-point loop. It checks `products` separately because a `TestSupport` product is nameable by anyone, which is T5a's condition 1.
- **`swift package describe --type json` is the interface, not `show-dependencies`.** `show-dependencies` resolves *package* dependencies; the leak T5a warns about is a *target* edge inside your own manifest, and only `describe` prints those. Its shape — `targets[].name`, `.type` (`"library"` / `"test"` / `"executable"`), `.target_dependencies` — verified on Swift 6.3.3.
- **`|| true` on every `grep` and `find`.** Finding nothing is exit `1`, and under `pipefail` that would abort the script at the first clean category and never run the rest. This is B6's second footgun in a different costume.

The job step is in B31's workflow. It runs on the macOS runner because check 4 needs a Swift toolchain and `jq`, both already there; checks 1–3 are pure text and will run anywhere if you would rather split them onto Linux.

---

## 10. Archiving, signing and upload

**B35. Use `xcodebuild` with an App Store Connect API key.** No Apple ID password, no app-specific password, no keychain dance.

```bash
xcodebuild archive \
  -scheme MyApp \
  -destination 'generic/platform=iOS' \
  -archivePath build/MyApp.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

Xcode 15 added API-key support to `-exportArchive` for uploading to both App Store Connect and the notary service. `altool` was deprecated for notarization (hard cutoff 2023-11-01; `notarytool` replaced it) and its `--upload-app` is deprecated in favour of `--upload-package`; for iOS, `xcodebuild -exportArchive` supersedes both.

**Start a new single-app project without fastlane.** fastlane is emphatically not dead — 2.237.0 shipped 2026-07-05 and the repo was pushed the day I checked, so ignore the 2026 commentary claiming otherwise — but `xcodebuild` plus API keys now covers archive, export, signing and upload natively, while fastlane adds a Ruby toolchain, a Gemfile to pin and maintain, and a large action surface. Cost of skipping it: you hand-roll changelog and metadata push, and you have no screenshot automation. **Deviate and adopt fastlane the moment you need `match`** (multi-developer certificate sharing — still the best answer available), `deliver`/`snapshot` (metadata and localized screenshots at scale), or you run several apps through one pipeline.

Xcode Cloud suits solo and small teams: no runner maintenance, and a free tier that compares well against GitHub's macOS allowance. It is weaker when your CI also does non-Apple work. Published free-hour and overage figures circulate from third parties — check the current terms in App Store Connect before budgeting on them.

---

## 11. Things that get builds rejected

Metadata problems, not code problems, which is why they surprise people at 6pm on a Friday.

**B36. Ship a `PrivacyInfo.xcprivacy`, and remember `UserDefaults` is a required-reason API.** Since **2024-05-01 App Store Connect rejects uploads** that use a required-reason API without declaring it; before that it was a warning email. A plain app that stores one setting needs a manifest. Every executable or dynamic library that uses such an API needs a manifest **in its own bundle** — Apple states directly that a third-party SDK "can't rely on the privacy manifest files for apps that link" it. Declared reasons must be truthful; you may use the API and derived data only for those reasons, and never for tracking.

```xml
<!-- PrivacyInfo.xcprivacy -->
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
```

The five categories are `NSPrivacyAccessedAPICategoryFileTimestamp`, `…SystemBootTime`, `…DiskSpace`, `…ActiveKeyboards`, `…UserDefaults`. Commonly cited reason codes: `C617.1` (file timestamps inside your own container), `35F9.1` (system boot time), `E174.1` (disk space), `CA92.1` (your app's own `UserDefaults`), `1C8F.1` (`UserDefaults` shared via App Group). **As of 2026-07-27 I could not verify these code strings against Apple's page** — the DocC JSON endpoints for `NSPrivacyAccessedAPIType` return only key descriptions, not the tables. Read the rendered HTML at `developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api` before shipping, and use Apple's request form if your reason is not listed.

Where the file goes depends on linkage, not on your repo layout: `01-PROJECT-STRUCTURE.md P32` owns placement, and the short version is one manifest at the app bundle root unless a local package ends up as a dynamic framework. Separately, SDKs on Apple's commonly-used-third-party-SDK list must ship a manifest **and a valid signature** as binary dependencies (since 2024-05-01), and from 2025-02-12 any newly added privacy-impacting SDK needs one.

**B37. Set `ITSAppUsesNonExemptEncryption` once and never click the compliance prompt again.** Omitting it puts every build in "Missing Compliance", which **blocks TestFlight builds from reaching testers** until someone clicks through, per build. Set `NO` if you only use OS-provided crypto (HTTPS via `URLSession`); `YES` if you ship your own cryptography, and then you owe export documentation. It is one of the keys `INFOPLIST_KEY_*` covers, so it belongs in the xcconfig (B7) — no plist file required.

**B38. If anything in the binary touches the IDFA you need both `NSUserTrackingUsageDescription` and a real `ATTrackingManager.requestTrackingAuthorization` call.** One without the other is a **Guideline 5.1.2(i)** rejection, among the most common privacy rejections there is. The trap: an ads or sign-in SDK added months ago can pull this in without you noticing. Audit your dependencies' privacy manifests, not just your own code.

---

## 12. Localization tooling

New Xcode projects set `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` (verified in the 26.6 template). String Catalogs are `.xcstrings`, edited in Xcode, compiled to `.strings`/`.stringsdict` at build time. Extraction covers string literals in SwiftUI (most SwiftUI API takes `LocalizedStringKey`), `String(localized:)` and variants, `NSLocalizedString`, and Interface Builder files.

**B39. Literals in SwiftUI are localized; variables are not.** `Text(someString)` binds to the non-localizing overload, so nothing is extracted and nothing is translated. It compiles, ships, and stays English forever. Route dynamic content through `String(localized:)`.

```swift
// ✗ Silently unlocalized.
let title = isPremium ? "Premium" : "Free"
Text(title)

// ✓ Extracted, with comments the translator can use.
let title = isPremium
    ? String(localized: "Premium", comment: "Subscription tier badge")
    : String(localized: "Free", comment: "Subscription tier badge")
Text(title)
```

Inside a package this interacts with bundle lookup — see `01-PROJECT-STRUCTURE.md P35`/`P36`, which own string catalogs in packages and the `#bundle` requirement.

**B40. Test pseudolocalization from a test-plan configuration, not by hand.** The scheme editor's `Run > Options > Application Language` offers **Double Length Pseudolanguage** (catches truncation and layout breakage) and **Right to Left Pseudolanguage** (mirrors layout with no translation), plus `Localization Debugging > Show non-localized strings`, which renders unlocalized strings in UPPERCASE. Setting these by hand means doing it once and forgetting. Set Application Language in a **second test-plan configuration** (B26) and Xcode runs your whole UI suite in both directions on every CI run. Equivalent launch arguments if you need them: `NSDoubleLocalizedStrings`, `NSShowNonLocalizedStrings`, `AppleTextDirection` with `NSForceRightToLeftWritingDirection`.

Xcode 26 added on-device-model comment generation and a workflow that generates symbols for strings, separating keys from values. Note `01-PROJECT-STRUCTURE.md P34`: generated symbols used *inside a package* break plain `swift build`.

---

## 13. Profiling, previews and app size

**B41. Use the SwiftUI instrument's Cause & Effect graph, not `Self._printChanges()`.** The SwiftUI instrument (Instruments 26) has a **Long View Body Updates** lane flagging slow `body` evaluations, coloured by how likely each is to cause a hitch or hang, and a **Cause & Effect graph** tracing which dependency — Observable, `@Environment`, `@State` — triggered an update. That is the structured, supported version of what people reach for `_printChanges()` to do. `Self._printChanges()` is underscored SPI: undocumented, no availability guarantee, and it costs runtime performance. I could not verify it or `Self._logChanges()` against current Apple documentation as of 2026-07-27; treat both as unsupported conveniences that must not ship. The instruments that earn their keep in a SwiftUI app: SwiftUI, Time Profiler, Hangs, Animation Hitches, Allocations/Leaks, Swift Concurrency.

**B42. When a preview fails, `Cmd+B` before you read the error.** Previews build the whole module, so a compile error in a file unrelated to the view kills the preview and the canvas error is downstream noise. Then click **Diagnostics** and read the *bottom* of the output — the real error is buried under a compilation command dump. Preview cache corruption is a recurring cause; quitting Xcode and clearing the cache is the reliable reset. `Editor > Canvas > Use Legacy Previews Execution` dodges a class of bugs in the newer execution engine.

**B43. Design for previews: a view that reaches a live network or database at init cannot preview.** Previews need every dependency constructible in-process. Chronically broken previews are an architecture problem, not an Xcode problem — `04-ARCHITECTURE-AND-STATE.md §9` owns how to inject the stub.

**B44. You cannot measure app size from the `.app`, the `.xcarchive` or the `.ipa`.** Apple is explicit: all three contain things users never download, dSYMs among them. Locally: Archive → Export as Ad Hoc/Development/Enterprise → choose **"All compatible device variants"** for thinning; the output folder contains **`App Thinning Size Report.txt`** with compressed (≈ download) and uncompressed (≈ installed) sizes per variant. Automate it by adding `thinning` = `<thin-for-all-variants>` to your export options plist and running the `-exportArchive` from B35. Authoritatively: App Store Connect, which gives per-variant sizes and warns past the cellular download limit. TestFlight builds are *larger* than App Store builds; the final App Store build can be *slightly larger* than what you uploaded, because Apple adds DRM and re-compresses.

**B45. Keep data and images out of source code.** Apple names data baked into source as string literals as a common culprit, alongside READMEs accidentally added to a target, unused image assets and stray headers. Moving data and images into asset catalogs "significantly reduces the size of your app's binary and allows App Store Connect to more efficiently compress your app", and unlocks per-device slicing. To find what is large, rename the `.ipa` to `.zip` and run `unzip -lv app.zip` for per-file sizes without extracting.

---

## 14. Accessibility auditing in CI

`06-TESTING.md` owns test authoring; this is the one accessibility API worth wiring into the pipeline.

```swift
@MainActor @nonobjc @preconcurrency
func performAccessibilityAudit(
    for auditTypes: XCUIAccessibilityAuditType = .all,
    _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil
) throws
```

Available iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+ / visionOS 1.0+. Note the framework: since the Xcode 16 module split this lives in **`XCUIAutomation`**, not `XCTest`. Audit types: `.action`, `.contrast`, `.dynamicType`, `.elementDetection`, `.hitRegion`, `.parentChild`, `.sufficientElementDescription`, `.textClipped`, `.trait`, `.all`.

**B46. `issueHandler` returning `true` means "suppress this issue", not "keep going".** Get it backwards and you write a test that passes unconditionally forever. Apple's own page is terse enough that an automated summary of it told me the opposite; practitioner sources agree on the suppress reading, and the failure mode of guessing wrong is silent.

```swift
// ✗ Suppresses every issue. The test can never fail.
try app.performAccessibilityAudit { _ in true }
```

```swift
// ✓ Suppress one known, accepted exception; everything else fails the test.
//   XCTest, in the UI test target — see below. Not Swift Testing.
final class AccessibilityUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false          // 06-TESTING.md T47
        app.launchArguments += ["-UITest", "-AppleAnimationsEnabled", "NO"]
        app.launch()
    }

    @MainActor
    func testHomeScreenIsAccessible() throws {
        try app.performAccessibilityAudit(for: [.dynamicType, .contrast]) { issue in
            guard let element = issue.element else { return false }
            return element.label == "Decorative Badge" && issue.auditType == .contrast
        }
    }
}
```

**This one is `XCTestCase`, and it has to be.** `performAccessibilityAudit` is a method on `XCUIApplication`, so it needs the out-of-process XCUITest runner and a UI test bundle — and Swift Testing cannot be used there. `06-TESTING.md T43` rules UI automation out of `@Test` from the authoring side; from the tooling side the block is harder than a rule, because Xcode's build system rejects `import Testing` in a UI test target outright. Swift Testing's maintainers confirm it and say why: XCTest's UI automation APIs "do not behave correctly when used in Swift Testing tests", and unblocking them needs work inside Apple's closed-source XCTest (swift-testing#516, open since 2024 and still open on 2026-07-27). Write the audit as an `XCTestCase` method in `RecipesUITests/`, tag the plan that runs it `.ui`, and gate it to a `Nightly` plan (B24).

Accessibility Inspector (`Xcode > Open Developer Tool > Accessibility Inspector`, pick the running simulator, `Run Audit`) is the exploratory manual pass and has a Font slider for previewing Dynamic Type live. `performAccessibilityAudit` is the regression net, and it belongs in CI.

---

## 15. What changes with Xcode 27 / Swift 6.4

Beta as of 2026-07-27 — all of it may change before GA, none of it should be your baseline yet.

- **Adoption cost:** Apple silicon only; macOS Tahoe 26.4+; on-device debugging floor rises to **iOS 17 / tvOS 17 / watchOS 10**, and `xctrace` gains the same floor. That floor is the reason to wait, not the toolchain.
- **Language:** `anyAppleOS` availability syntax; the `@diagnose` attribute; `async` code permitted in `defer`; a new iteration protocol extending `for-in` to noncopyable types. Foundation gains a unified Swift `URL` implementation with parsing reported up to 4x faster.
- **Testing:** XCTest ↔ Swift Testing interop in both directions, explicitly for incremental migration; issues recorded in detached Tasks and background threads now attach to the originating test; Test Repetition Mode repeats individual Swift Testing cases instead of the whole plan; `swift test --maximum-repetitions` and `--repeat-until [pass|fail]` for flake hunting.
- **Migration hazard:** the dependency scanner now requires every Clang module reachable from one scan to have a **unique module name**. Vendored SDKs that redeclare a module name will start failing to build — test this before upgrading if you ship or consume binary frameworks.

---

## 16. Contested points, ruled

| Question | The disagreement | Ruling |
|---|---|---|
| `ENABLE_USER_SCRIPT_SANDBOXING` default | Blogs universally say "YES since Xcode 15" | **False as stated.** Build-system default is `NO`; the *template* writes `YES`. Keep it `YES` anyway (B14). |
| Formatter in a build phase | Common practice; Apple's incremental-build doc argues against | **Don't.** Editor and pre-commit only; lint in CI (B17). |
| `swift-format` vs SwiftFormat vs SwiftLint | Practitioners favour SwiftFormat's rule coverage | **`swift-format`.** Bundled, zero-install, swiftlang-maintained. SwiftLint additionally, for rules formatting cannot express. |
| Release Swift optimization | Apple's size doc says the Release default is `-Os` | **That sentence is about `GCC_OPTIMIZATION_LEVEL`.** Swift's verified default is `-O`; `-Osize` is opt-in (B12). |
| Is fastlane dead in 2026 | Widely assumed dying; 2.237.0 shipped 2026-07-05 | **Alive, and still skip it** on a new single-app project. Adopt for `match`/`deliver` (B35). |
| `SWIFT_VERSION = 6` vs `6.0` | Most of the internet writes `6`; every file in this guide writes `6.0` | **`6.0`.** Same enforcement either way, but only `6.0` resolves `SWIFT_STRICT_CONCURRENCY` to `complete` in the settings table, so only `6.0` reports honestly (B2). `01-PROJECT-STRUCTURE.md P18` and `05-CONCURRENCY.md R2` already agree. |
| Xcode 27 as baseline | Beta 4 is available now | **No.** Apple-silicon-only and an iOS 17 debug floor. Revisit at GA (§15). |

---

## Checklist

**Configuration**
- [ ] `SWIFT_VERSION = 6.0` on every target — the `.0` matters
- [ ] `IPHONEOS_DEPLOYMENT_TARGET` in `Base.xcconfig` equals `platforms: [.iOS(…)]` in the manifest (01 §5b)
- [ ] Adopting an upcoming feature? `MIGRATE`, apply fix-its, then `YES` — after checking it is migratable
- [ ] Every upcoming-feature flag you turned on has its price named somewhere (B7a, B7b, 03 W43)
- [ ] All build settings in `Config/*.xcconfig`; `project.pbxproj` has zero inline settings, checked in CI
- [ ] `$(inherited)` on every appended setting; no `//` inside values; xcconfigs in no target
- [ ] Release: `wholemodule`, `dwarf-with-dsym`, `ENABLE_NS_ASSERTIONS = NO`. Debug: `-Onone`, `ONLY_ACTIVE_ARCH = YES`, `ENABLE_TESTABILITY = YES`
- [ ] `ENABLE_USER_SCRIPT_SANDBOXING = YES`, still on
- [ ] No redundant lines restating a default you have not verified is wrong

**Build hygiene**
- [ ] Every run-script phase declares inputs and outputs, or has been deleted
- [ ] No formatter in any build phase — editor and pre-commit only
- [ ] Warnings-as-errors in CI/Release only; blanket flag *before* targeted `-Wwarning` exemptions
- [ ] `#UnknownWarningGroup` promoted to an error so typos in warning config cannot ship
- [ ] `Build With Timing Summary` run at least once; scheme Build Order is Dependency Order

**Packages**
- [ ] No `unsafeFlags` in anything published; `swiftLanguageMode(.v6)` in `swiftSettings`
- [ ] `platforms:` declares **both** iOS and macOS — macOS is what `swift test` and `#bundle` build against (01 §5b, B22)
- [ ] Resources via `.process` unless layout matters; loaded via `#bundle`, never `Bundle.main`

**CI**
- [ ] `runs-on: macos-26`, never `macos-latest`; Xcode selected explicitly with `xcode-select`
- [ ] Destination resolved by UDID or `OS=latest`, never a hardcoded name+OS pair
- [ ] `set -o pipefail` before every `xcodebuild | formatter`
- [ ] `-skipMacroValidation` if you depend on macros, with dependencies pinned
- [ ] Lint on `ubuntu-latest` with `swift format lint --strict`; SwiftLint only if you are a team (03 W56)
- [ ] Both runners: `swift test --package-path Modules` **and** `xcodebuild test` (01 P23)
- [ ] `Scripts/check-source-hygiene.sh` runs before the simulator work (§9.1, B34a)
- [ ] `concurrency.cancel-in-progress` set; UI tests gated to the `Nightly` plan
- [ ] Results parsed with `xcresulttool get test-results`, not the deprecated `get object`
- [ ] `CURRENT_PROJECT_VERSION` injected on the command line, strictly greater than the last upload

**Tests and coverage**
- [ ] Per-module schemes plus one umbrella scheme, all shared
- [ ] Test plans built from the eight tags in `06-TESTING.md` T30, one plan per cadence tag, named after it (B24)
- [ ] At least one plan configuration on Random order
- [ ] A plan configuration each for RTL and Double Length pseudolanguage
- [ ] `performAccessibilityAudit` covers the main flows, lives in an `XCTestCase`, and does not blanket-return `true` (B46, §14)

**Ship**
- [ ] `PrivacyInfo.xcprivacy` present, truthful, and in the right bundle — including `UserDefaults`
- [ ] Every third-party binary SDK ships its own manifest and signature
- [ ] `ITSAppUsesNonExemptEncryption` set via `INFOPLIST_KEY_*`
- [ ] `NSUserTrackingUsageDescription` plus a real ATT call if anything touches the IDFA
- [ ] All `NS*UsageDescription` strings present and written for humans
- [ ] App Thinning Size Report generated and diffed against the previous release
- [ ] Instruments SwiftUI pass on the main flow: no red Long View Body Updates
- [ ] dSYMs archived for symbolication
