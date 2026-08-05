# T02 — Xcode project, `Config/*.xcconfig` and the app shell

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | — (no §14.1 row; it is the build product every row ships in) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | It owns `Config/*.xcconfig` outright — `references/xcconfig.md` §2–§3 are the four files complete, §4 says why each absent setting is absent, and §5 names the two settings whose spelling must be confirmed before writing because a wrong `INFOPLIST_KEY_*` is **silently ignored**. |

## Objective

`Hunch.xcodeproj` exists at the repo root, builds and runs an iPhone-only, portrait-only, Swift 6 app whose `App/` buildable folder holds four files, and **every** build setting lives in `Config/*.xcconfig` with `project.pbxproj` carrying none. `Scripts/check-pbxproj-clean.sh` makes that mechanical rather than a promise.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 | The tree: `Hunch.xcodeproj` at the root, `Config/` outside `App/`, `App/` as a buildable folder with `HunchApp.swift`, `Assets.xcassets`, `Hunch.entitlements`. |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P8`, `P9`, `P30`, `P31`, `P33`, `P37`, `P38`, `P40`, `P41`, `P43` | Shell-only app target; no `Info.plist`; entitlements beside the entry point and referenced from the xcconfig; module assets never in `App/Assets.xcassets`; the two wizard defaults to change; one `.xcodeproj`, no workspace. |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B2`, `B5`, `B6`, `B7`, `B9`, `B10`, `B11`, `B12`, `B13`, `B14`, `B18`, `B19`, `B27`, `B37` | `SWIFT_VERSION = 6.0` and why the `.0` is load-bearing; xcconfigs are the only home; the pbxproj-clean script printed in full in `07 §2`; `$(inherited)`; `-Osize`; blanket warning flag first. |
| `hunch-build-and-ci` | `references/xcconfig.md` §1–§8 | The authoritative text of all four files. Read it and paste; do not compose from memory. |
| `hunch-build-and-ci` | `references/package-manifests.md` §3 | Why the wizard's `HunchUITests` target must be renamed `HunchAutomationTests`. |
| `GAME_DESIGN.md` | §12.9 | `Info.plist` carries zero localizable strings and **no `NS*UsageDescription` of any kind** — the app requests nothing. `CFBundleDisplayName` is "HUNCH" in all twelve locales because it is a wordmark. |
| `GAME_DESIGN.md` | §14.4 | Portrait-only, iPhone-only, one device class — the reason `TARGETED_DEVICE_FAMILY = 1`. |

## TDD — the test comes first

Two failing artefacts, because this task has two claims: *the settings are where they should be* and *the settings reached the built product*.

**Step 1a — write the pbxproj check.** Create `Scripts/check-pbxproj-clean.sh`, verbatim from `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` `B6` (print it with `sed -n '/^#!\/bin\/bash/,/^echo "pbxproj clean/p' ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md`), with the default project name changed to `Hunch.xcodeproj`. `chmod +x` it.

The three details `B6` reproduced before writing down, and which you must not "simplify" away: an `awk` range and not `grep -A20`; capture-then-test rather than `grep -q … && exit 1`; POSIX classes and not `\s`.

**Step 1b — write the built-product test.** Create `HunchTests/BuildSettingsTests.swift`:

```swift
import Foundation
import Testing

/// The app test bundle is hosted by the app, so `Bundle.main` is the app bundle and its
/// Info.plist is the one the build system generated from Config/Base.xcconfig (01 P30).
/// This suite asserts the settings LANDED — reading the xcconfig back proves nothing
/// (hunch-build-and-ci/references/xcconfig.md §5, §7).
@Suite("Generated Info.plist", .tags(.unit, .presubmission))
struct BuildSettingsTests {
    private func value(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    @Test("iPhone only — one device class, GAME_DESIGN.md §14.4")
    func deviceFamilyIsIPhoneOnly() throws {
        let families = try #require(value("UIDeviceFamily") as? [Int])
        #expect(families == [1])
    }

    @Test("Portrait only — the layout is tuned to a 375 pt thumb arc, §14.4")
    func portraitOnly() throws {
        let orientations = try #require(value("UISupportedInterfaceOrientations") as? [String])
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }

    @Test("Export compliance is declared, so TestFlight never stalls on it (07 B37)")
    func encryptionComplianceIsDeclared() throws {
        let declared = try #require(value("ITSAppUsesNonExemptEncryption") as? Bool)
        #expect(declared == false)
    }

    @Test("The bundle identifier resolved — a missing Local.xcconfig leaves a leading dot")
    func bundleIdentifierResolved() throws {
        let identifier = try #require(Bundle.main.bundleIdentifier)
        #expect(!identifier.isEmpty)
        #expect(!identifier.hasPrefix("."))
        #expect(identifier.hasSuffix(".hunch"))
    }

    @Test("The display name is the wordmark, untranslated (§12.9)")
    func displayNameIsTheWordmark() throws {
        let name = (value("CFBundleDisplayName") as? String) ?? (value("CFBundleName") as? String)
        #expect(name == "Hunch" || name == "HUNCH")
    }
}
```

and `HunchTests/Tags.swift`, which is the **third and last** copy of the eight-tag vocabulary in this repo:

```swift
import Testing

// The tag vocabulary is declared once per MODULE, not once per repo (06 T29 — tags with the
// same name in different modules are treated as equivalent, which is exactly what keeps a
// plan's include-tag filter selecting all of them). HunchTestSupport (E01·T03) is absent from
// HunchCore's products: by design, so this Xcode target cannot import it. Copies: here,
// HunchTestSupport, and ModulesTestSupport (E03·T06). There is no fourth.
extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var snapshot: Self
    @Tag static var ui: Self
    @Tag static var performance: Self
    @Tag static var presubmission: Self
    @Tag static var nightly: Self
    @Tag static var prerelease: Self
}
```

**Step 2 — run them and watch them fail.**

```bash
Scripts/check-pbxproj-clean.sh Hunch.xcodeproj    # before you empty it: prints every wizard setting, exit 1
UDID=$(xcrun simctl list devices available --json | jq -r '.devices | to_entries[]
        | select(.key | test("iOS-26")) | .value[] | select(.name=="iPhone 16") | .udid' | head -1)
set -o pipefail
xcodebuild test -scheme Hunch -destination "id=$UDID" -only-testing:HunchTests | xcbeautify
```

The first fails because the wizard writes `SWIFT_VERSION = 5.0`, `GENERATE_INFOPLIST_FILE`, `SWIFT_DEFAULT_ACTOR_ISOLATION` and a dozen more into the target's `buildSettings` blocks. The second fails on `UIDeviceFamily` (the template ships `1,2`) and on `ITSAppUsesNonExemptEncryption` (absent). Both fail for the right reason: the values are wrong, not the checks.

**Step 3 — implement** the wizard run, the rename, the four xcconfigs and the pbxproj emptying, below.

**Step 4 — green, then refactor.** Both commands pass; then re-run `xcodebuild -showBuildSettings` and read the resolved values with your own eyes once — the test asserts the plist, the `-showBuildSettings` output asserts the compiler flags.

## Files

| Action | Path |
|---|---|
| create | `Hunch.xcodeproj/` (including `project.pbxproj` and `xcshareddata/xcschemes/Hunch.xcscheme`) |
| create | `App/HunchApp.swift` |
| create | `App/Assets.xcassets/` (`AppIcon` placeholder only) |
| create | `App/Hunch.entitlements` |
| create | `Config/Base.xcconfig` |
| create | `Config/Debug.xcconfig` |
| create | `Config/Release.xcconfig` |
| create | `Scripts/check-pbxproj-clean.sh` |
| create | `HunchTests/BuildSettingsTests.swift` |
| create | `HunchTests/Tags.swift` |
| create | `HunchAutomationTests/` (renamed from the wizard's `HunchUITests`) |
| modify | `.gitignore` — nothing to add; confirm `Config/Local.xcconfig` is already ignored |

`Config/Local.xcconfig` is created on your machine and is **never committed** (`01 P43`). CI synthesises its own in T07.

## Implementation notes

### 1. Run the wizard, and change two defaults before pressing Create (`01 P40`)

File ▸ New ▸ Project ▸ iOS ▸ App. Product Name **Hunch**. Interface **SwiftUI**, Language **Swift**. Then:

- **Testing System: `Swift Testing`** — the default is `None`, which gives a project with no test target at all. That default is the single most common reason an app has no tests on day 30.
- **Storage: `None`** — keep it. `SwiftData` and `Core Data` scatter a `ModelContainer` into `@main`, violating `P8` on line one. This project uses neither (`08 §7.5`).

Save it at the repo root so `Hunch.xcodeproj` is a sibling of `GAME_DESIGN.md`. Do **not** create a workspace (`P41`) — Xcode's implicit `project.xcworkspace` is all a local package needs.

### 2. Reshape what the wizard produced

| Wizard artefact | Do this | Why |
|---|---|---|
| `Hunch/` folder (a buildable folder / synchronized root group) | rename to `App/` in the Xcode navigator | `08 §1`'s tree. Renaming in the navigator makes Xcode rewrite the group's `path`; renaming only on disk leaves `path = Hunch;` in the pbxproj and the target loses its sources. |
| `Hunch/ContentView.swift` | delete | `P8` — the shell holds `@main` and nothing else. |
| `Hunch/Preview Content/` (if the template made one) | delete the folder | It exists only to hold preview-only assets, and this app has none — every mark is drawn (`01 P33`). Its `DEVELOPMENT_ASSET_PATHS` setting disappears when you empty the pbxproj anyway, so leaving the folder gives you a directory referenced by nothing. |
| `Hunch/HunchApp.swift` | rewrite (below) | |
| `Assets.xcassets` → `AccentColor` colour set | delete | §13.2 owns every colour and it lives in `HunchCore/Sources/Tokens` (E03). A system accent colour is a second home for a colour. |
| `Assets.xcassets` → `AppIcon` | keep, empty | E20·T10 fills it, tested at 29, 60 and 1024 pt before anything else is drawn. |
| `HunchUITests` target and folder | **rename both to `HunchAutomationTests`** | `06 T5b` mirrors source paths, so `HunchUI`'s package tests are `Modules/Tests/HunchUITests` (E03·T06). Two test targets with one name makes `-only-testing:HunchUITests` ambiguous and puts two identically-named rows in every scheme and plan. The wizard's name is not load-bearing; the mirroring rule is (`hunch-build-and-ci/references/package-manifests.md` §3). Record it in `DECISIONS.md` (T08). |
| `HunchTests` target | keep, and keep it nearly empty | `P22`, `P40` — the app target is nearly empty, so its test bundle is too. In E01 it holds exactly the two files above. |
| the `Hunch` scheme | mark **Shared** and confirm it lands in `Hunch.xcodeproj/xcshareddata/xcschemes/` | `P43`. An unshared scheme is invisible to CI and to a fresh clone. |

`App/HunchApp.swift`, the whole of the app target's Swift in E01:

```swift
import SwiftUI

/// The app target holds `@main`, the call to the composition root, and nothing else (01 P8).
/// E10·T01 replaces this body with `AppView().hunchEnvironment(AppDependencies.live())`;
/// until `Modules/` exists (E03·T06) there is nothing to compose and nothing to import (01 P9).
@main
struct HunchApp: App {
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}
```

`App/Hunch.entitlements` is an empty plist — no capability is requested, ever:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

It is referenced by `CODE_SIGN_ENTITLEMENTS` in the xcconfig and **not** set through the UI (`P31`).

### 3. The four xcconfig files

Paste them from `hunch-build-and-ci/references/xcconfig.md` §2 (`Base`) and §3 (`Debug`, `Release`, `Local`). They are complete there; this file adds only what that reference tells you to look up rather than assert:

- **`CODE_SIGN_ENTITLEMENTS = App/Hunch.entitlements`** goes in `Base` (`P31`). It is not in the reference because the reference documents settings, not paths.
- **The launch screen key.** `08 §1` ships a launch colour only. `xcconfig.md` §5 refuses to assert the `INFOPLIST_KEY_UILaunchScreen_*` spelling from memory, and it is right to: a wrong `INFOPLIST_KEY_*` name is silently ignored, which is the worst failure mode available (`07 B8`). Read the real names first, then write one:

  ```bash
  xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch | grep -i 'LAUNCH\|STRING_CATALOG'
  ```

  Then confirm the value landed by reading the **generated plist out of the build products**, not by reading the xcconfig back:

  ```bash
  plutil -p "$(xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}')/Hunch.app/Info.plist"
  ```

- **String Catalog symbol generation stays OFF** (`01 P34`, `08 §7.11`). Generated symbols are produced by Xcode's build system, not SwiftPM, and using them inside a package breaks plain `swift build` — which is the ten-second fast path this whole structure exists to buy. `Loc` is the hand-written accessor §12.9 requires anyway (E18·T01).
- **`TARGETED_DEVICE_FAMILY = 1` is the setting; `UIDeviceFamily` is the plist key it generates.** Writing `UIDeviceFamily` in an xcconfig does nothing at all. The test in Step 1b asserts the *generated key*, which is why it catches the mistake.
- **`OTHER_SWIFT_FLAGS` in `Release.xcconfig` puts the blanket flag first**: `$(inherited) -warnings-as-errors -Werror UnknownWarningGroup`. Flags apply left to right, so a *trailing* blanket flag silently overrides an earlier `-Wwarning` exemption (`07 B19`). `08 §7.12` states the opposite ordering while giving this exact reasoning; `B19` is the reproduced one and it wins.
- **Do not restate a default you have not verified is wrong** (`07 B7`, `B13`). `SWIFT_STRICT_CONCURRENCY` is deliberately absent because `SWIFT_VERSION = 6.0` already resolves it to `complete`; `DEAD_CODE_STRIPPING` is absent because it resolves to `YES` for an app target. `xcconfig.md` §4 is the full list of absences and each is a decision.

Wire them up:

- **`Base.xcconfig` is set at the PROJECT level** (Project ▸ Info ▸ Configurations ▸ Debug/Release ▸ the *project* row).
- **`Debug.xcconfig` and `Release.xcconfig` are set at the TARGET level** for their configuration, on all three targets (`Hunch`, `HunchTests`, `HunchAutomationTests`).
- **None of the four is a member of any target.** Check Target Membership in the File Inspector after adding them; an `.xcconfig` in a target is copied into the `.ipa` and you ship your build configuration to users (`07 B10`). Verify: `grep -n 'xcconfig' Hunch.xcodeproj/project.pbxproj | grep -v baseConfigurationReference` must return nothing.

Your own `Config/Local.xcconfig` (gitignored):

```text
DEVELOPMENT_TEAM = <your team id>
CODE_SIGN_STYLE = Automatic
HUNCH_BUNDLE_ID_PREFIX = com.<you>
```

A team ID in a committed file is the usual reason a fresh clone cannot build on someone else's machine.

### 4. Empty `project.pbxproj`

`B5` is the rule and it has no good exception: precedence runs platform defaults → project xcconfig → project build settings → target xcconfig → **target build settings**, so a value someone typed into the Build Settings tab silently beats your target xcconfig. "Use xcconfigs" without "and empty the pbxproj" is half the advice.

Open `Hunch.xcodeproj/project.pbxproj` in a text editor and empty every `buildSettings = { … };` block so it reads `buildSettings = {\n};`. There are six (three targets × two configurations) plus two project-level ones. **`baseConfigurationReference` is a sibling key of `buildSettings` inside `XCBuildConfiguration`, not a member of it** — it sits outside the braces and must survive. A clean block has nothing between its braces.

Then run the check until it says `pbxproj clean: Hunch.xcodeproj`, close and reopen Xcode, and run it again — Xcode rewrites the file on save and will helpfully re-add a setting the moment anyone touches the Build Settings tab. That is exactly why the check is in CI (T07) and not in your head.

### 5. What you must not do

- Never type a setting into Xcode's Build Settings tab. If you already did, the check will tell you, and the fix is to delete it there and add it to an xcconfig.
- Never set `ENABLE_USER_SCRIPT_SANDBOXING = NO` (`07 B14`). It stays `YES`; T06's run-script phase is written to live inside it.
- Never add an `Info.plist` file (`P30`). Every key HUNCH needs is one Apple already knows about, so `INFOPLIST_KEY_*` covers all of them. `07 B8`'s custom-key carve-out does not apply: the app has no runtime configuration because it has no network and no remote anything.
- Never add a `NS*UsageDescription` key. The app requests no permission of any kind (§12.9, `xcconfig.md` §4), and an unused usage description is a reviewer question you cannot answer.

## Acceptance criteria

- [ ] `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj` prints `pbxproj clean: Hunch.xcodeproj` and exits 0 — and printed offenders and exited 1 before you emptied it (record both in `PROGRESS.md`).
- [ ] `xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch | grep -E 'SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY'` reports `6.0`, `complete`, `18.0`, `1`.
- [ ] `xcodebuild -showBuildSettings -project Hunch.xcodeproj -target Hunch -configuration Release | grep -E 'SWIFT_OPTIMIZATION_LEVEL|OTHER_SWIFT_FLAGS'` reports `-Osize` and a flag list whose **first** element after `$(inherited)` is `-warnings-as-errors`.
- [ ] `xcodebuild test -scheme Hunch -destination "id=$UDID" -only-testing:HunchTests` is green with **5 tests**, not 0.
- [ ] `grep -n 'xcconfig' Hunch.xcodeproj/project.pbxproj | grep -v baseConfigurationReference` returns nothing (`07 B10`).
- [ ] `ls App/` is exactly `Assets.xcassets  Hunch.entitlements  HunchApp.swift` — three entries (`PrivacyInfo.xcprivacy` arrives in E20·T11).
- [ ] `ls Hunch.xcodeproj/xcshareddata/xcschemes/` contains `Hunch.xcscheme`.
- [ ] `xcodebuild -list -project Hunch.xcodeproj` shows targets `Hunch`, `HunchTests`, `HunchAutomationTests` — and no `HunchUITests`.
- [ ] `git status --porcelain Config/Local.xcconfig` returns nothing (it is ignored, not committed).

## Close the task

1. There is still no `swift test` — T03 brings it. Run the two Step-2 commands instead; both green.
2. **Run `/simplify`** — it will mostly look at `HunchApp.swift` and the check script. Do not let it collapse the `awk` range in `check-pbxproj-clean.sh` into `grep -A20`; `B6` reproduced why that reports clean projects as dirty.
3. **Run `/code-review`** — the diff to read is `project.pbxproj` and the three xcconfigs. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E01/T02: Hunch.xcodeproj, Config/*.xcconfig, the App shell and the pbxproj-clean check"`

## Out of scope

- **`PrivacyInfo.xcprivacy`** — E20·T11 owns its contents (the no-collection, no-tracking claims and the `UserDefaults` required-reason code) and `/hunch-release` owns the pre-archive checklist.
- **`AppIcon.icon` artwork and the launch surface's drawing** — E20·T10.
- **The `HunchCore` package** — T03. It is added to the project in T03, not here.
- **The `Modules` package and anything the shell would import** — E03·T06 creates it; E10·T01 makes `HunchApp.swift` name the composition root.
- **The run-script build phase** — T06. This task leaves Build Phases as the wizard made them.
- **The `.xctestplan` files and the scheme's test-plan conversion** — T07.
- **`Info.plist` *absence* assertions** — the "no `NS*UsageDescription`, no `UIFileSharingEnabled`, no `LSSupportsOpeningDocumentsInPlace`, zero localizable strings" suite is **E18·T08**. This task asserts only what its own xcconfig *sets*.
- **`MARKETING_VERSION` bumps and `CURRENT_PROJECT_VERSION` injection at archive time** — `/hunch-release`, user-invoked. CI passes `CURRENT_PROJECT_VERSION` on the command line (T07), which is `07 B27`'s right half.
