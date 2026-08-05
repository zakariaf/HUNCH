# Project and File Structure

This file decides where things go: the repo tree, the Xcode project's relationship to disk, when a chunk of code becomes a module, how many packages you own, and which file a given declaration belongs in. Read it before you write the first line of a new app, and read it again when an existing app crosses about 15k lines and navigation starts to hurt. It does not cover naming conventions for types and APIs (`02-NAMING-AND-API-DESIGN.md`), in-file layout rules (`03-WRITING-THE-CODE.md`), what belongs in a view model (`04-ARCHITECTURE-AND-STATE.md`), or xcconfig and CI mechanics (`07-TOOLING-BUILD-AND-SHIPPING.md`).

---

## 0. Version ground truth

Everything below was verified on this machine on **2026-07-27** unless marked otherwise.

| Fact | Value | How verified |
|---|---|---|
| Shipping Xcode | **26.6 (17F113)** | `xcodebuild -version` |
| Shipping Swift | **6.3.3** (`swiftlang-6.3.3.1.3`) | `swift --version` |
| iOS SDK in Xcode 26.6 | **iOS 26.5** | `xcrun --sdk iphoneos --show-sdk-path` |
| Beta Xcode | **27 beta 4 (27A5228h)**, Swift 6.4, iOS 27 SDK, requires macOS 26.4+ | Apple releases page, 2026-07-20 |
| New Xcode 26.6 app target defaults | `SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | `plutil -p` on `Base_ProjectSettings.xctemplate` and `App Base.xctemplate` `TemplateInfo.plist` (templates, not a generated project) |
| New-project wizard defaults | Testing System: **None** (of None/XCTest/Swift Testing); Storage: **None** (of None/SwiftData/Core Data) | `plutil -p` on `Base_TestingSystem.xctemplate` / `Base_StorageType.xctemplate` |
| New `swift package init` default | tools-version 6.3, `swiftLanguageModes: [.v6]`, Swift Testing test stub | ran it |
| `PackageDescription.Platform.IOSVersion.v26` | exists | grep of `PackageDescription.swiftinterface` |
| `SwiftSetting.defaultIsolation(_:)` | `@available(_PackageDescription 6.2)` | same interface file |
| `#bundle` macro | `@available(macOS 12, iOS 15, tvOS 15, watchOS 8, visionOS 1, *)` | grep of `iPhoneOS26.5.sdk` `Foundation.swiftinterface`, line 21316 |

**The single structural trap of this toolchain generation:** a new Xcode app target compiles in **Swift 5 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`**, while a new SwiftPM package compiles in **Swift 6 language mode, nonisolated by default**. Moving a file from the app target into a package silently flips its default actor isolation and its language mode at the same time. This is the number-one cause of "it compiled in the app, it exploded in the package" during modularisation. Fix in P16 (isolation) and P18 (language mode).

---

## 1. The tree, stated once

App named `Recipes`; substitute your product name everywhere. There are two trees here, and copying the wrong one is the most common mistake this file can cause. **Day one is the first tree.** The second is where day one *ends up* after the P11 threshold has fired a few times — it is a destination, not a starting point.

**Tree 1 — day one.** Everything a new app needs, and nothing that anticipates a rule that has not fired yet. This is what P12 means by "start with `App/` and one `AppFeature` target."

```text
Recipes/                              # repo root == product name. No "iOS-" prefix, no "-app" suffix.
├── .gitignore
├── .swift-format                     # ONE at the root covers the whole tree (P39)
├── .github/workflows/ci.yml
├── README.md
│
├── Recipes.xcodeproj                 # at the ROOT, not under App/. Not an .xcworkspace (P41).
│
├── Config/                           # every build setting. Outside App/ so it can't become a target member.
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── Local.xcconfig                # gitignored, #include?'d from Base
│
├── App/                              # BUILDABLE FOLDER, sole member of the Recipes app target.
│   ├── RecipesApp.swift              # @main. Calls the composition root; nothing else (P8).
│   ├── Assets.xcassets               # app-level assets ONLY (P33)
│   ├── AppIcon.icon                  # Icon Composer document (Xcode 26+)
│   ├── Recipes.entitlements
│   └── PrivacyInfo.xcprivacy         # exact filename, app bundle root (P32)
│
├── Modules/                          # ONE local SwiftPM package, ONE target in it.
│   ├── Package.swift
│   ├── Sources/AppFeature/           # all your code lives here until P11 trips
│   └── Tests/AppFeatureTests/
│
├── RecipesTests/                     # created by the wizard; leave it nearly empty (P22) —
│                                     # real tests go in Modules/Tests/
└── RecipesUITests/                   # XCUITest. Must live in the app project.
```

No `Models/`, no `DesignSystem/`, no `TestSupport/`, no `Tools/`. Each of those arrives the day a named rule fires, and P12 is explicit that creating them early is a cost with no matching benefit.

`RecipesTests/` is the one directory here you did not choose: P40 tells you to set the wizard's Testing System to Swift Testing, and that switch creates the target and the folder. Keep it — deleting it means re-adding a test target by hand the first time you need one — and keep it *empty*, because P22 sends every test you actually write to `Modules/Tests/`.

**Tree 2 — what it grows into.** Every line below is here because a rule fired. Lines marked `(optional)` never become mandatory.

```text
Recipes/
├── .gitignore
├── .swift-format                     # ONE at the root covers the whole tree (P39)
├── .github/workflows/ci.yml
├── README.md
├── Makefile                          # (optional) make bootstrap / test / format
│
├── Recipes.xcodeproj                 # at the ROOT, not under App/. Not an .xcworkspace (P41).
│
├── Config/                           # every build setting. Outside App/ so it can't become a target member.
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── Local.xcconfig                # gitignored, #include?'d from Base
│
├── App/                              # BUILDABLE FOLDER, sole member of the Recipes app target. ~8 files. Ever.
│   ├── RecipesApp.swift              # @main. Calls the composition root; nothing else (P8).
│   ├── AppDelegate.swift             # only if UIApplicationDelegateAdaptor is genuinely needed
│   ├── Assets.xcassets               # app-level assets ONLY (P33)
│   ├── AppIcon.icon                  # Icon Composer document (Xcode 26+)
│   ├── Recipes.entitlements
│   ├── PrivacyInfo.xcprivacy         # exact filename, app bundle root (P32)
│   └── Info.plist                    # usually ABSENT — see P30
│
├── Modules/                          # ONE local SwiftPM package. N targets.
│   ├── Package.swift
│   ├── Sources/
│   │   ├── AppFeature/               # composes the features; the app target imports only this
│   │   ├── RecipeListFeature/
│   │   ├── RecipeDetailFeature/
│   │   ├── DesignSystem/
│   │   ├── RecipeClient/             # protocol + live impl
│   │   ├── Models/                   # pure domain types, no UI, zero dependencies (P5 carve-out)
│   │   └── TestSupport/              # a .target, NOT a .testTarget (P20)
│   └── Tests/
│       ├── RecipeListFeatureTests/
│       ├── RecipeClientTests/
│       └── ModelsTests/
│
├── RecipesTests/                     # app-target tests. Should be nearly empty (P22).
├── RecipesUITests/                   # XCUITest. Must live in the app project.
├── Recipes.xctestplan
│
└── Tools/
    └── Previews/                     # (optional, P10) mini-apps that launch one feature module
```

**Why the project is at the root and not under `App/`:** Point-Free's `isowords` puts `isowords.xcodeproj` under `App/`, which is correct for a repo that is *primarily* a package with an app attached. For an app repo, the root is what Xcode Cloud, Fastlane, `xcodebuild -project`, and every "just open it" instinct expect. Deviate only if the package is the product.

**Cost of the grown tree:** two build systems in one repo. `swift build` compiles `Modules/`, `xcodebuild` compiles the app, and you will occasionally get a green `swift test` and a red `xcodebuild` from the same commit — asset-symbol generation is the usual culprit (P34).

Every `(Pnn)` above is a live cross-reference, so treat it as testable. This fails the build on any citation that does not resolve to a rule heading:

```bash
#!/bin/bash
# tools/check-rule-refs.sh <file> — every Pnn mention must match a "**Pnn." rule heading.
set -euo pipefail
file="$1"
# `grep -oE` exits 1 on a file that cites no rules at all; under `pipefail` that status
# propagates to the assignment and `set -e` kills the script — a clean file reported as a
# red build. That is exactly the trap 07-TOOLING-BUILD-AND-SHIPPING.md B6 names, so absorb it.
# The braces are load-bearing: `|` binds tighter than `||`, so a bare
# `grep … || true | sort -u | while …` runs `true | sort -u | while …` as the alternative
# branch and prints every rule heading in the file as "dangling".
missing=$({ grep -oE '\bP[0-9]+\b' "$file" || true; } | sort -u | while read -r ref; do
  grep -q "^\*\*${ref}\." "$file" || echo "$ref"
done)
[ -z "$missing" ] || { echo "dangling rule references in $file: $missing"; exit 1; }
```

---

## 2. Buildable folders, not groups

Xcode 16 introduced folder references that build. Everything written before 2024 about groups being virtual and `Synx` being necessary is now obsolete for new projects.

From Apple's Xcode 16 release notes (Project Management, 123729918): *"Buildable folders only record the folder path into the project file without enumerating the contained files. This minimizes diffs to the project when files are added and removed, and avoids source control conflicts with your team."* And (127396845): *"The Project Navigator now defaults to creating groups with associated folders."*

| | Group | Folder (buildable) |
|---|---|---|
| Disk mapping | optional | is a directory; contents included automatically |
| pbxproj representation | "larger" (per-file `PBXFileReference` + `PBXBuildFile`) | "much smaller" — one `PBXFileSystemSynchronizedRootGroup` |
| Reacts to disk changes | no | yes, automatically |
| Merge conflicts | many | "fewer merge conflicts when adding/removing files" |
| Navigator ordering | arbitrary, decoupled from disk | disk order, alphabetical |

**P1. New project: every folder is a buildable folder. Never use "New Group without Folder."** To get a group without a folder in Xcode 16+ you must hold Option in the context menu — the friction is deliberate; take the hint.

**P2. Inherited project: convert top-down, one folder per PR.** Select the group → Control-click → **Convert to Folder**. Xcode refuses when the group doesn't match disk; "Show Details" lists what failed. Fix the disk layout first, in its own commit, so the conversion diff stays reviewable.

**P3. Do not share a source file between two targets. Put it in a module both targets depend on.** Buildable folders belong to a target as a unit; individual files inside them cannot be added to a second target. The classic "add `Constants.swift` to both the app and the widget" move no longer has a natural shape. This is a feature.

```swift
// ✗ AppGroupID.swift added to both the app target and the widget target's build phases.
//   Two copies compiled into two binaries. They drift the first time someone edits one.
enum AppGroupID { static let value = "group.com.example.recipes" }

// ✓ Modules/Sources/Models/AppGroupID.swift, and both targets link the Models library.
//   One definition, one symbol, one place to change it.
public enum AppGroupID {
    public static let value = "group.com.example.recipes"
}
```

**P4. The escape hatch is `PBXFileSystemSynchronizedBuildFileExceptionSet`, and you should never hand-write it.** It handles excluding files from a target, overriding file-type detection, and header visibility. If you need it, your disk layout is wrong — move the file instead.

**Moving a file is now `git mv`, not an Xcode operation.** The project file does not mention `Foo.swift` at all, so `git mv Sources/A/Foo.swift Sources/B/` is the complete change; Xcode picks it up on the next build. Two consequences worth internalising: refactoring scripts and coding agents can restructure the tree without touching `.pbxproj`, and deleting a file in Finder removes it from the build *immediately*, with no red reference to warn you. The safety net used to be Xcode complaining; now it is the compiler.

**Honest cost, from Apple DTS (forums thread 789705, Kevin Elliott):** the remaining advantage of groups is logical/physical decoupling — you can restructure the navigator hierarchy without touching files, so a reorganisation never collides with a file edit in version control. With folders you lose virtual ordering entirely. DTS identified no enterprise-blocking downside. **Ruling: take folders.** The ordering loss is cosmetic and you get it back by naming folders well.

**Version note:** buildable folders had a real incremental-build regression — non-deterministic file ordering causing unnecessary rebuilds — **fixed in Xcode 26** (release notes, Build System, 151472630). Anyone who tells you buildable folders slowed their builds was probably on Xcode 16–25. I grepped the Xcode 27 beta 4 release notes for `buildable`, `synchroniz`, `folder`, `group`, and `pbxproj` and found nothing; that is absence of evidence, not an Apple statement of "unchanged."

---

## 3. Feature-first folders, never layer-first

**P5. The top level of `Sources/` is named after features and capabilities, never after layers.** Banned as top-level directory names: `Views/`, `ViewModels/`, `Models/`, `Services/`, `Managers/`, `Utils/`, `Helpers/`, `Extensions/`, `Common/`, `Shared/`.

**One carve-out, written so it cannot be stretched: `Models` is legal as a *target* name.** The tree at §1 uses it and the manifest at §5b declares it. The difference is not cosmetic — a target is bounded by its `dependencies:` array, and that is what makes the rule checkable in review. A `Models` **target** is legal exactly while `.target(name: "Models")` has an **empty dependency list** and contains only domain types and the constants two targets share. The moment it needs to import anything, it has stopped being a leaf and started being the bin P5 exists to prevent; split it into named capabilities that day. A `Models/` **directory** at the top of `Sources/` inside a module has no such bound and stays banned. Nothing else on the list gets this treatment: there is no dependency-free reading of `Utils` or `Helpers`.

```text
✗ Sources/Views/RecipeListView.swift          ✓ Sources/RecipeListFeature/RecipeListView.swift
  Sources/ViewModels/RecipeListModel.swift      Sources/RecipeListFeature/RecipeListModel.swift
  Sources/Views/SettingsView.swift              Sources/RecipeListFeature/RecipeRow.swift
  Sources/ViewModels/SettingsModel.swift        Sources/SettingsFeature/SettingsView.swift
```

The layer-first tree makes every change touch four distant directories and makes it impossible to see, at a glance, what a feature consists of or whether it can be deleted. John Sundell's diagnosis is the right one: folders named `Utilities`, `Helpers`, `Managers` become dumping grounds precisely because their scope is too broad to reject anything.

**P6. Layer sub-folders *inside* one feature are fine, and only once that feature exceeds ~10 files.** `RecipeListFeature/Views/`, `RecipeListFeature/Models/`. The rule is about the top level, not every level.

**P7. Technical modules sit *beside* features, not above them.** `Sources/Networking/`, `Sources/DesignSystem/`, `Sources/Persistence/` are peers of `Sources/RecipeListFeature/`. There is no `Sources/Core/` wrapper directory.

**Cost, stated honestly:**
1. **Cross-cutting types become homeless.** `Recipe` is used by four features. You will end up with the `Models` target P5 carves out, and a recurring judgement call about what belongs in it. The dependency-free test is the crisp rule — but it only tells you when the module has gone wrong, not what to do next, and the split it demands is real work. Layer-based trees never have this problem because everything has an obvious bin.
2. **It only pays off past about three features.** A five-screen app with layer folders is perfectly navigable.
3. **It reads as unconventional** to anyone arriving from MVVM tutorials, which are near-uniformly layer-first. Expect to defend it in review.

**When to deviate:** a genuinely tiny app — one screen, a weekend project — put everything flat in `App/` and stop thinking about it. Structure is a cost you pay to buy navigability; buy nothing until you need something.

**Contested:** Nimble and most "SwiftUI best practices" posts show `Presentation/Domain/Data` at the top level. That is Clean Architecture layering applied to directories. **Ruling: layers may name your *modules*; features must name your *folders*.** `PaymentsCore` and `PaymentsUI` as module names is fine. `Sources/Presentation/` is not.

---

## 4. The app target is a shell

**P8. The app target contains the `@main` entry point, the *call* to the composition root, and bundle-level resources. Nothing else.** If `App/` has more than about a dozen files, code that belongs in a module is sitting in the shell. The root itself is a factory inside `AppFeature`, not the `App` struct — `04-ARCHITECTURE-AND-STATE.md` A2 owns that, and the reason is that `@main` is the one type a test and a preview can never construct.

**P9. The app target imports exactly one feature module (`AppFeature`), plus `DesignSystem` if the shell styles anything.** More imports in `RecipesApp.swift` means the shell is doing composition that `AppFeature` should own.

```swift
// App/RecipesApp.swift — the whole app target's Swift code, essentially.
import AppFeature
import SwiftUI

@main
struct RecipesApp: App {
    // Names the composition root; does not *be* it. AppDependencies.live() lives in
    // AppFeature, where a test and a preview can also call it (04 A2).
    @State private var dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            AppView()
                .recipesEnvironment(dependencies)   // one exported modifier — 04 A28
        }
    }
}
```

```swift
// ✗ App/RecipesApp.swift doing the work itself
import RecipeListFeature
import RecipeDetailFeature
import SettingsFeature
import Networking
import Persistence

@main
struct RecipesApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {                       // this is app composition — it belongs in AppFeature,
                RecipeListView(...)         // where it is testable without booting a simulator
                SettingsView(...)
            }
        }
    }
}
```

**Why this is worth doing:** the app target is the one place you cannot test cheaply, cannot preview in isolation, and cannot compile without the full dependency graph. Every line you keep out of it is a line that stays fast to build and test. That is also why the graph is composed one module *down*: `04-ARCHITECTURE-AND-STATE.md` A2 owns where the object graph is built and what it contains; this file only insists that the app target names it in one line and imports nothing else.

**P10. Optional but high value: a preview app per feature.** `Tools/Previews/RecipeListPreview/` is an app target that links exactly one feature module and launches it. This is the `isowords` `App/Previews/` pattern: targets that "contain no real code — just code for configuring and launching the application." Useful when a feature is buried five taps deep. Cost: one more target to keep compiling. Skip it until a feature is genuinely hard to reach.

---

## 5. Modularisation: when, and in what unit

### 5a. The threshold

**P11. Extract a module the first time a chunk of code satisfies any one of:**
- **two targets need it** (app + widget, app + extension), or
- **you want tests for it that don't need a simulator**, or
- **it has crossed ~1,500 lines and has a nameable responsibility.**

**P12. Do not pre-create an empty `Core` / `Networking` / `DesignSystem` scaffold on day one.** An empty module is a dependency edge you have to maintain and a boundary you have not yet learned the right shape of. Start with `App/` and one `AppFeature` target; split when the threshold trips.

**What you actually buy, ranked by how reliably you get it:**

| Benefit | Reliability |
|---|---|
| **Enforced boundaries.** `HomeFeature` cannot reach into `SettingsFeature` unless someone adds an edge in `Package.swift` — a visible, reviewable act. | Guaranteed. This is the reason to modularise. |
| **Test speed.** `swift test` runs with no simulator boot. My two-target probe: build 0.67s, test run 0.001s. | Guaranteed, and large. |
| **Preview and editor responsiveness in smaller modules.** | Practitioner consensus (Point-Free are explicit about it). I found no Apple source and no benchmark. Treat as likely, not measured. |
| **Incremental build time.** | Conditional — see the cost below. |

**Honest cost:** a badly shaped graph is *slower* than a monolith. A wide, shallow graph parallelises; a deep chain serialises and pays module-emission overhead at every hop. Small projects often find the compile-time benefit negligible. Every new module is a manifest edit plus an access-level decision plus a default-isolation decision.

**P13. Keep the graph wide and shallow. Depth is the thing that hurts.** Feature modules depend on leaf modules (`Models`, `DesignSystem`, client interfaces) and on nothing else. Feature modules must never depend on each other — that is what `AppFeature` is for.

**Where does this new file go?** Answer it from the table, not from taste. The last row is the one that keeps the graph honest.

| What you are adding | Target |
|---|---|
| A view, model, or helper used by exactly one feature | that feature's target |
| A domain type two or more features read | `Models` — and only while its `dependencies:` array is still empty (P5 carve-out) |
| Anything that performs I/O: network, disk, keychain, location | its own `…Client` target — interface plus a live implementation |
| A colour, font, spacing token, or a control with no feature knowledge | `DesignSystem` |
| A fixture or builder used by two or more test targets | `TestSupport`, a `.target` (P20) |
| Code the app and a widget/extension both need | a target both link (P3). Never a shared file |
| **Anything else** | **the feature you are already in.** Move it when a second consumer appears, not before |

**Extracting the first module from a monolith, in this order.** Six commits, each of which builds:

1. Convert groups to buildable folders, top-down (P2). First, because every later step moves files and moving files in a group-based project produces a `.pbxproj` diff nobody can review.
2. Rearrange on disk into feature folders (P5), still entirely inside the app target. No module yet.
3. Create `Modules/` with one target and one trivial file. Wire the link (§9) and prove `import` works before moving anything real.
4. Move the leaves first — domain types, formatters, anything with no dependencies. It compiles or it doesn't; there is no ambiguity to debug.
5. Set `.defaultIsolation` and the language mode **in the same commit as the first move** (P16, P18). This is exactly where the app-versus-package trap fires.
6. Move features last, one at a time, and only once their leaves are already in the package.

### 5b. One package, many targets

**P14. Own exactly one local package, containing N targets. Split into a second package only when a chunk will be open-sourced or shared across separate app repos.**

Three concrete reasons, in order of weight:

1. **The `package` access level only works within a package.** SE-0386 defines `package` as "accessed from outside of their defining module, but only from other modules in the same package"; SwiftPM passes `-package-name` automatically from the package identity. One package per module forces you to make everything `public`, which means every internal helper becomes API you have to keep working.
2. **No versioning obligation.** No external consumers means you can rename and reshape APIs freely.
3. **N manifests and N `Package.resolved` files to keep in step.** Every shared dependency is declared, pinned and bumped in each package that uses it, and a resolution mismatch between two of them is a diagnostic nobody enjoys reading. One package has one of each.

**What is *not* a reason, because the guide got this wrong and people repeat it:** a local path-based package depending on another local package works fine. Apple's `.package(path:)` documentation recommends it in as many words — *"The Swift Package Manager uses the package dependency as-is and does not perform any source control access. Local package dependencies are especially useful during development of a new package or when working on multiple tightly coupled packages."* Reproduced on Swift 6.3.3: `Packages/Core` plus `Packages/Feature` whose manifest declares `dependencies: [.package(path: "../Core")]` resolves and builds clean in 1.4s. If you have inherited a `Packages/MyAppCore` + `Packages/MyAppUI` layout, it builds; restructure it for reasons 1–3 or leave it alone, but do not restructure it because someone told you it cannot compile.

Verified firsthand on Swift 6.3.3 — this compiles and tests clean:

```swift
// Modules/Sources/DesignSystem/Tokens.swift
public enum Tokens {
    public static let spacing = 8
    package static let internalSpacing = 4   // visible to other targets in Modules, invisible to the app
}
```

```swift
// Modules/Sources/RecipeListFeature/RecipeListModel.swift
import DesignSystem

public struct RecipeListModel: Sendable {
    public init() {}
    public var pad: Int { Tokens.spacing + Tokens.internalSpacing }   // compiles; the app target cannot do this
}
```

**Cost:** one `Package.swift` with 30 targets is a wall of repeated string literals with no autocomplete. The standard fix (Dan Thorpe's "hyper-modularization") is to build a `Module` struct and result builders and construct the manifest programmatically; he reports it scaling to 50+ modules. Cost of *that*: your manifest becomes code a newcomer must read before they can add a module. **Under ~15 targets, don't. Plain declarations with a small `Target.Dependency` extension are enough.**

**Deployment target: decide the floor before you copy the manifest.** A `platforms:` line is a product decision, not a code sample, and it is silently expensive — ship `.iOS(.v26)` and the app will not install on anything older, which no build error will ever tell you.

| Floor | What it buys | What it costs |
|---|---|---|
| **iOS 17** | Observation / `@Observable`, which `04-ARCHITECTURE-AND-STATE.md` A1 treats as the baseline for the whole architecture | No `Mutex` below iOS 18, so `05-CONCURRENCY.md` R17's last row applies and you hand-roll `final class` + `OSAllocatedUnfairLock` + `@unchecked Sendable` + a comment naming the lock |
| **iOS 18 — the recommendation** | Everything at iOS 17, plus `Mutex` (`import Synchronization`), which R17 makes the answer for small state with synchronous access, and which removes roughly half your `@unchecked Sendable` | Two OS generations of install base. As of 2026 that is the oldest floor most consumer apps still justify |
| **iOS 26** | `Observations` (SE-0475) and the iOS 26 SwiftUI surface, with no back-deployment branches anywhere | Three generations. Take it only for an internal, enterprise-MDM, or brand-new-hardware audience where you can name the install base |

**Ruling: iOS 18.** It is the lowest floor at which every rule in `04-ARCHITECTURE-AND-STATE.md` and `05-CONCURRENCY.md` applies without a fallback path, which is worth more than the delta in reach. Set it in exactly two places and keep them equal: `platforms:` in the manifest below, and `IPHONEOS_DEPLOYMENT_TARGET = 18.0` in `Config/Base.xcconfig`. If you deviate, deviate in both, in one commit, with the install-base number in the message.

**The manifest must also declare a macOS platform, and this is not optional.** P23 makes `swift test` the inner loop, and `swift test` builds for the **host**. With an iOS-only `platforms:` array, SwiftPM compiles against its own default macOS floor and every target that touches SwiftUI fails before a test runs — reproduced on Swift 6.3.3: `error: 'View' is only available in macOS 10.15 or newer`. Declare the aligned macOS release (`.macOS(.v15)` pairs with `.iOS(.v18)`) and the same targets build and test on the host in seconds.

That leaves a per-target decision, and the seven targets below split cleanly:

| Target | Host-testable (`swift test`) | Why |
|---|---|---|
| `Models`, `RecipeClient`, `TestSupport` | **Yes, unconditionally** | Foundation only. No UI framework, nothing iOS-only. These are the targets P11 says to extract *because* of this. |
| `DesignSystem` | **Yes, if you keep it cross-platform** | SwiftUI's core surface is on both. Anything reaching for `UIKit`, `UIDevice`, `UIScreen`, `UIApplication` or `UIFont` goes behind `#if canImport(UIKit)` — but check first whether SwiftUI already vends it on every platform, because most of what people guard does not need it. |
| `RecipeListFeature`, `RecipeDetailFeature`, `AppFeature` | **Only with guards** | iOS-only view modifiers — `.navigationBarTitleDisplayMode`, `.fullScreenCover`, `.listStyle(.insetGrouped)` — do not exist on macOS and are not caught by `canImport`. |

For the third row, pick one policy per target and write it in the manifest, not in your head: either guard every iOS-only API and keep the target on the fast path, or accept that the target is simulator-tested and run it with `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`. Guarding is cheap when the iOS-only surface is modifiers; excluding is honest when the target *is* the iOS UI.

```swift
// Modules/Sources/DesignSystem/Chrome.swift — the shape of a guard that keeps a target host-testable.
// The target sets .defaultIsolation(MainActor.self) in §5b's manifest, so these are main-actor already.
public enum Chrome {}

#if canImport(UIKit)
import UIKit

extension Chrome {
    /// Whether the process is running in the iPad idiom.
    ///
    /// Declared only where UIKit exists, so the host build of this target does not see it.
    /// Call it from behind the same `#if`, or give the cross-platform path its own default.
    public static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}
#endif
```

Note what is *not* behind the guard. Display scale looks like the obvious `#if canImport(UIKit)` candidate and it is not: SwiftUI vends it as an environment value on every platform, so reaching for `UIScreen` here would cost you the host build for nothing.

```swift
// Modules/Sources/DesignSystem/HairlineDivider.swift — cross-platform, so no guard and no UIKit.
public struct HairlineDivider: View {
    @Environment(\.displayScale) private var displayScale

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1 / displayScale)
    }
}
```

**`UIScreen.main` is not available to you as a fallback, and this is a build failure rather than a style note.** It is deprecated in iOS 26 — verified against `UIScreen.h` in the iOS 26.5 SDK, whose deprecation text reads *"Use a UIScreen instance found through context instead (i.e, view.window.windowScene.screen), or for properties like UIScreen.scale with trait equivalents, use a traitCollection found through context."* Because `07-TOOLING-BUILD-AND-SHIPPING.md` B18 sets `OTHER_SWIFT_FLAGS[config=Release] = $(inherited) -warnings-as-errors`, that warning is an error in Release and on CI. Reproduced on Swift 6.3.3 targeting `arm64-apple-ios26.0`:

```text
error: 'main' was deprecated in iOS 26.0: Use a UIScreen instance found through context instead
       (i.e, view.window.windowScene.screen), or for properties like UIScreen.scale with trait
       equivalents, use a traitCollection found through context. [#DeprecatedDeclaration]
```

```swift
// Modules/Package.swift — readable at this size without any DSL.
// swift-tools-version: 6.3
import PackageDescription

// Typo-proofs dependency strings and gives you autocomplete. This is as fancy as it should get.
extension Target.Dependency {
    static let models: Self = "Models"
    static let designSystem: Self = "DesignSystem"
    static let recipeClient: Self = "RecipeClient"
}

let featureSettings: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Modules",
    defaultLocalization: "en",           // REQUIRED as soon as any target ships a String Catalog
    // iOS: must match IPHONEOS_DEPLOYMENT_TARGET in Config/Base.xcconfig.
    // macOS: what `swift test` builds against (P23). Without it, SwiftUI targets do not compile on the host.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    targets: [
        .target(name: "Models"),
        .target(name: "RecipeClient", dependencies: [.models]),
        .target(name: "DesignSystem",
                dependencies: [.models],
                resources: [.process("Resources")],
                swiftSettings: featureSettings),
        .target(name: "RecipeListFeature",
                dependencies: [.designSystem, .recipeClient],
                resources: [.process("Resources")],
                swiftSettings: featureSettings),
        .target(name: "RecipeDetailFeature",
                dependencies: [.designSystem, .recipeClient],
                resources: [.process("Resources")],
                swiftSettings: featureSettings),
        .target(name: "AppFeature",
                dependencies: ["RecipeListFeature", "RecipeDetailFeature"],
                swiftSettings: featureSettings),
        .target(name: "TestSupport", dependencies: [.models]),   // NOT a testTarget — see P20
        .testTarget(name: "RecipeListFeatureTests",
                    dependencies: ["RecipeListFeature", "TestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
```

Every target named in a `dependencies:` array must also be declared in `targets:` (or vended by a package dependency). Omit `RecipeDetailFeature` from the list above and the manifest does not merely build wrong, it fails to *resolve* — `error: 'Modules': product 'RecipeDetailFeature' required by package 'Modules' target 'AppFeature' not found.` `swift build --package-path Modules` catches it in under a second, which is a good thing to run once after every manifest edit.

`07-TOOLING-BUILD-AND-SHIPPING.md` owns manifest mechanics (upcoming-feature flags, `unsafeFlags`, resource declaration rules). This file owns the *shape* of the target list.

**Contested:** Nimble and manu.show both use one package per module wired with `.package(name:path:)`. It works — genuinely, not grudgingly — and you pay for it with `public` on everything and N manifests to keep in step. **Ruled against, on cost, not on capability.**

### 5c. SwiftPM package vs Xcode library target

**P15. For a new iOS app with a single app target, use a local SwiftPM package.** `Package.swift` is a text file that diffs and reviews; `.pbxproj` is not. You get `package` access for free, `swift build`/`swift test` from a terminal with no simulator, and it is Apple's documented recommendation ("Organizing your code with local packages").

**Where the strongest dissent is right:** Matt Massicotte (Chime) argues for **static library targets inside the Xcode project** instead, for projects with app extensions or XPC services — packages give up control of linking, and Xcode may automatically produce dynamic frameworks when multiple targets link the same package, which can hurt launch time. Library targets support the full build-settings surface (so `.xcconfig` can drive them) and let you state the artifact type explicitly.

**Ruling: package now; revisit the moment you ship a widget, extension, or watchOS app that links the same modules as the app.** At that point either move to library targets or set product types explicitly (`.library(name:type:.static)`) and audit what actually ends up dynamic in the bundle. Massicotte's specific dynamic-framework claim is plausible and consistent with older SwiftPM reports, but I did not reproduce it on Xcode 26.6 — verify before relying on it. He is unambiguously right about the bigger point: "project modularization is really worth the effort," including for small projects.

### 5d. The isolation and language-mode trap

**P16. When you move code from the app target into a package, set the package's isolation explicitly in the same commit.** The app target ships `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; a package defaults to `nonisolated`.

```swift
// ✗ Move RecipeListModel.swift from App/ into Sources/RecipeListFeature/ and the target
//   defaults to nonisolated. Every @MainActor assumption the code silently relied on is
//   now a Swift 6 concurrency error — usually dozens at once, in unrelated-looking places.
.target(name: "RecipeListFeature", dependencies: [.designSystem])

// ✓ Restores the isolation the code was written under. Requires swift-tools-version 6.2+;
//   verified @available(_PackageDescription 6.2) in the Xcode 26.6 toolchain.
.target(
    name: "RecipeListFeature",
    dependencies: [.designSystem],
    swiftSettings: [.defaultIsolation(MainActor.self)]
)
```

**P17. Split isolation by module kind: UI and feature modules get `.defaultIsolation(MainActor.self)`; pure-domain and client modules get the `nonisolated` default.** `Models`, `RecipeClient` and anything doing I/O should be explicitly non-main. `05-CONCURRENCY.md` owns the reasoning and the migration path; the structural rule is that the decision is made per target, in the manifest, and written down.

**P18. Set `swiftLanguageModes: [.v6]` on the package and `SWIFT_VERSION = 6.0` in `Config/Base.xcconfig` so the two halves of the repo agree.** A repo where the app is Swift 5 mode and the package is Swift 6 mode will pass CI and fail on the next file you move.

### 5e. `Sources/` and `Tests/` layout

SwiftPM's documented convention: *"Swift sources are collected by target name under the `Sources` directory, and tests collected, also by target name, under the `Tests` directory."*

**P19. The directory name under `Sources/` *is* the module name *is* the `import` statement.** Therefore: UpperCamelCase, no hyphens, no spaces. `DesignSystem`, never `design-system`. Test directory is module name + `Tests`. (`02-NAMING-AND-API-DESIGN.md` owns which suffixes are good; this is the mechanical constraint.)

**P20. Shared test fixtures live in a `.target` named `TestSupport`, never a `.testTarget`.** Test targets cannot be depended on. Getting this wrong means copy-pasting builders into every test target.

**P21. Keep `Sources/` flat — one directory per module, no nesting.** Nesting works (`path: "Sources/Features/Home"` is verified to compile) but costs an explicit `path:` on every single target and decouples directory name from module name, which is a footgun that buys only navigator cosmetics. Deviate past ~30 modules, where a flat list genuinely stops being scannable.

---

## 6. Where tests live

`06-TESTING.md` owns what to test and how to write it. This is placement and the runner decision.

| Code under test | Directory | Runner | Wall clock |
|---|---|---|---|
| Anything in a package target | `Modules/Tests/<Target>Tests/` | `swift test` | seconds, no simulator |
| Composition, anything needing the app bundle | `RecipesTests/` | `xcodebuild test` | simulator boot |
| UI flows | `RecipesUITests/` | `xcodebuild test` | simulator boot |

**P22. Default every test to a package test target. The app's test bundle should be nearly empty, because the app target is nearly empty.** App-hosted bundles need a simulator boot; package tests do not. This is the single largest lever on your inner-loop latency, and it is a *structural* lever — you get it by putting code in modules, not by writing tests differently.

**P23. Run `swift test` locally and both runners on CI.** `swift test` in `Modules/` for the inner loop, then `xcodebuild test -testPlan Recipes` for app plus UI tests. Do not force simulator-free tests through `xcodebuild` for tidiness; you will pay for it every commit.

**Known friction, unresolved:** adding a local package's test target to the app's `.xctestplan` and running "build for testing" can fail with **"Module '…' was not compiled for testing."** Apple Developer Forums thread 764589 was still open with no Apple response as of March 2025; I did not determine whether Xcode 26.6 or 27 fixes it and did not reproduce it. If you hit it, fall back to running package tests via `swift test` as a separate CI step. The aggregating single-test-plan approach (one simulator boot instead of N) is worth setting up **only if your package tests genuinely need a simulator** — UIKit, SwiftUI snapshots, CoreData on device. Reported CI savings from that pattern are large but single-source and workload-specific; don't budget against them.

---

## 7. Which file does this declaration go in

`03-WRITING-THE-CODE.md` owns what goes *inside* a file (extension layout, `// MARK:`, access control). These are the rules for choosing the file.

**P24. One top-level type per file; the file is named for the type.** `RecipeListModel.swift` contains `RecipeListModel` and nothing else at top level.

**P25. Break P24 for exactly three cases:** (a) a type and its private nested helpers that are meaningless alone; (b) a type and its delegate protocol; (c) **a SwiftUI parent view plus the section views it extracted purely for invalidation**, when those sections are private to the parent and under ~20 lines each.

Case (c) needs justification, because it is where two good rules collide. Apple's SwiftUI structure guidance is emphatic that a view is SwiftUI's unit of invalidation, that each region of a multi-region screen should be its own `struct: View`, and that *"a computed property is inlined into the enclosing view's body; it does not introduce its own invalidation boundary, so it does not reduce update cost."* Follow that plus a literal one-type-per-file rule and a single product screen becomes five files. That harms navigation more than the split helps.

```swift
// ✓ ProductDetailView.swift — one file, four types, one screen.
//   Each section IS a separate View type (real invalidation boundaries, per Apple's guidance),
//   but they are fileprivate and meaningless outside this file, so they stay here.
struct ProductDetailView: View {
    let product: Product

    var body: some View {
        ScrollView {
            ProductHeader(title: product.title, subtitle: product.vendor)
            ProductGallery(images: product.images)
            ProductPriceRow(price: product.price, currency: product.currency)
        }
    }
}

private struct ProductHeader: View {
    let title: String            // narrow inputs: this view re-renders only when title/subtitle change
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.title2)
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}

private struct ProductGallery: View {
    let images: [ImageResource]
    var body: some View { /* … */ EmptyView() }
}

private struct ProductPriceRow: View {
    let price: Decimal
    let currency: Locale.Currency
    var body: some View { /* … */ EmptyView() }
}
```

```swift
// ✗ The same screen written with computed properties. Fewer types, same file count,
//   and NO invalidation boundaries — every `product` change re-evaluates all three regions.
struct ProductDetailView: View {
    let product: Product
    var body: some View { ScrollView { header; gallery; priceRow } }

    private var header: some View { /* … */ EmptyView() }
    private var gallery: some View { /* … */ EmptyView() }
    private var priceRow: some View { /* … */ EmptyView() }
}
```

**P26. An extension on a type you own, adding a conformance, stays in the type's own file** — unless the conformance is large or drags in an import the type otherwise doesn't need. If you split it: `RecipeListModel+Codable.swift`.

**P27. An extension on a foreign type always gets its own file, named `Foreign+Capability.swift`, one capability per file.** `Date+RelativeFormatting.swift`, never `Date+Extensions.swift`. Sundell's reasoning is the right one: the narrow name forces an intentional decision about where each helper belongs, and the broad name makes the file a bin.

```swift
// ✗ Extensions.swift — 400 lines, six foreign types, imports UIKit for one function.
//   Every feature that needs one helper now transitively depends on all of them.
import UIKit
extension String { var trimmed: String { … } }
extension Date   { var relative: String { … } }
extension Color  { static let brand = Color(…) }
extension Array  { var second: Element? { … } }
```

```swift
// ✓ String+Trimming.swift
extension String {
    /// Whitespace- and newline-trimmed copy.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// ✓ Date+RelativeFormatting.swift
extension Date {
    /// Localized relative description, e.g. "2 hours ago".
    func relativeDescription(to reference: Date = .now) -> String {
        formatted(.relative(presentation: .named))
    }
}

// ✓ DesignSystem/Theme.swift — a brand colour is a design-system concern, not a Color extension.
public enum Theme {
    public static let brand = Color(.brand)
}

// Array+SecondElement.swift — deleted. `dropFirst().first` already exists.
```

**P28. Banned file names, no exceptions:** `Utils.swift`, `Utilities.swift`, `Helpers.swift`, `Constants.swift`, `Extensions.swift`, `Managers.swift`, `Common.swift`, `Shared.swift`, and anything matching `*+Utilities.swift`. If you cannot name the capability, you have not decided what you are writing. Enforce it with a CI grep; it takes one line.

**P29. Generated code lives in a `Generated/` subfolder inside its target, is never hand-edited, and is excluded from the formatter and linter.** If it is cheap to regenerate from a build plugin, gitignore it. If the plugin is slow or CI-hostile, commit it and add a CI step that regenerates and fails on any diff.

---

## 8. Resources, plists, entitlements, manifests

**P30. `Info.plist` should not exist in a new project.** Modern templates set `GENERATE_INFOPLIST_FILE = YES` and ship no plist file; keys are stored as `INFOPLIST_KEY_*` build settings and synthesised at build time. Put them in your xcconfig, where they get version control and code review for free:

```text
// Config/Base.xcconfig
INFOPLIST_KEY_UILaunchScreen_Generation = YES
INFOPLIST_KEY_NSCameraUsageDescription = Recipes uses the camera to scan recipe cards.
```

Materialise a real `App/Info.plist` (pointed at by `INFOPLIST_FILE`) only for keys the build settings cannot express — nested dictionaries such as `NSAppTransportSecurity` exceptions or URL schemes with sub-arrays. Note that Xcode will re-create a physical plist on its own when you add a key it classes as "additional"; common keys like `NSCameraUsageDescription` do not trigger this.

**P31. Entitlements: one `.entitlements` plist per target that needs one, beside that target's entry point, referenced by `CODE_SIGN_ENTITLEMENTS` in the xcconfig — not set through the UI.** `App/Recipes.entitlements`, `Widget/RecipesWidget.entitlements`.

**P32. `PrivacyInfo.xcprivacy` — exact filename, and the owner of the rule is the *bundle*, not the repo.** The manifest belongs to whatever ships as its own bundle, so the count depends on how your package ends up linked:

- **Local packages statically linked into the app (the default, and what §5b's manifest produces): exactly one manifest, at `App/PrivacyInfo.xcprivacy`, and it must cover the union of required-reason APIs used by the app *and* every target linked into it.** Do not add per-target manifests; there is no second bundle for them to live in.
- **A local package that ends up as a dynamic framework needs its own.** P15 flags exactly when this happens: Xcode may produce dynamic frameworks when multiple targets link the same package — the app + widget case P11 recommends. Declare it on the target: `resources: [.process("PrivacyInfo.xcprivacy")]`. `07-TOOLING-BUILD-AND-SHIPPING.md` B36 states the general form ("every executable or dynamic library that uses such an API needs a manifest in its own bundle"); P32 is the app-side placement rule and this bullet is where the two meet.
- **Anything you distribute** — an XCFramework, an open-sourced package, a third-party SDK — always carries its own, regardless of linkage.

Check which case you are in rather than assuming: build, then `find "$BUILT_PRODUCTS_DIR/Recipes.app" -name '*.framework'`. Empty output means one manifest at the app root is right. Anything listed is a bundle that needs its own.

Apple's placement rules per bundle kind: iOS-family app → bundle root; macOS/Catalyst app → `Contents/Resources/`; iOS-family framework → framework bundle root; Swift package → the target's default resource location, declared explicitly as above. Static `.a` libraries don't support resources at all — convert to a static framework if you need one there. App Store Connect rejects manifests containing unexpected keys or values, and a *missing* one on a dynamic bundle that uses a required-reason API is a rejection, not a warning.

**P33. Feature and design-system assets live in the module that uses them; `App/Assets.xcassets` holds only genuinely app-level assets** (launch imagery, marketing assets). Module assets go at `Sources/<Module>/Resources/Colors.xcassets` with `resources: [.process("Resources")]`.

**P34. If you enable generated asset or string-catalog symbols *and use them inside a package*, that package stops building with plain `swift build`.** Symbol generation is done by Xcode's build system, not by SwiftPM. This directly breaks the `swift test` fast path from P22 — which is the whole reason you modularised. Either don't use generated symbols inside packages, or accept `xcodebuild` for those modules and know you chose that. (Reported as swift-package-manager issue 9655 and on the developer forums; I did not reproduce it on Xcode 26.6, so confirm before designing around it.)

**P35. String Catalogs in a package need three things, and the third is the one people miss:** the file at `Sources/<Module>/Resources/Localizable.xcstrings`, `resources: [.process("Resources")]` on the target, `defaultLocalization: "en"` on the `Package`. Xcode does not create the catalog for you.

**P36. Inside a package or framework, every localized string needs an explicit bundle. Use `#bundle`.** Without one, SwiftUI looks up strings from `Bundle.main`, the lookup **fails silently**, and the string ships untranslated. Apps, app extensions, and XPC services are their own main bundle and may omit it.

```swift
// ✗ Inside a package: compiles, runs, and ships English to every locale.
Text("Save to Favorites")

// △ Works. Older pattern.
Text("Save to Favorites", bundle: .module)

// ✓ Current Apple guidance. Verified @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
//   in the iOS 26.5 SDK, so there is no deployment-target reason to prefer .module.
Text("Save to Favorites", bundle: #bundle)
```

**Sources conflict here and it matters:** the SwiftPM documentation still says *"Always use `Bundle.module` to access resources,"* while Apple's Xcode 27 SwiftUI guidance says *"`#bundle` is the preferred form; `Bundle.module` and `Bundle(for: MyClass.self)` work but are older patterns."* **Ruling: `#bundle`.** It is newer Apple guidance and it costs nothing at any supported deployment target. `07-TOOLING-BUILD-AND-SHIPPING.md` B22 follows this ruling for non-string resources and adds the one mechanical caveat — `#bundle` needs a `platforms:` floor. (The Xcode 27 skill text quoted here came from a third-party mirror of Apple's bundled agent skills, corroborated by SwiftLee — high confidence, not certified; Xcode 26.6 ships no skills to export.)

**P37. App icon (Xcode 26+): one `AppIcon.icon` Icon Composer document, referenced by `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` — the filename minus its extension.** Xcode generates every variant from it. Keep a legacy `AppIcon` appiconset alongside only if you need different rendering below iOS 26.

**P38. `Config/` lives outside `App/`** so the `.xcconfig` files can never be swept into the app's buildable folder and shipped as resources. Apple's own instructions say to deselect all targets when creating one. `07-TOOLING-BUILD-AND-SHIPPING.md` owns everything else about xcconfig.

**P39. One `.swift-format` at the repo root covers the whole tree, including the package.** swift-format looks for `.swift-format` in the file's own directory, then walks up parents. One file, root, done.

---

## 9. Creating the project: wizard, workspace, generators

**P40. Two of the new-project wizard's defaults are wrong for you. Change them before you press Create.** Read out of the Xcode 26.6 template plists on 2026-07-27:

| Wizard option | Ships as | Set it to | Why |
|---|---|---|---|
| **Testing System** | `None` | **Swift Testing** | The default gives you a project with *no test target at all*. That is the single most common reason an app has no tests on day 30. (`Swift Testing` is only offered when Language is Swift; `06-TESTING.md` owns everything after this choice.) |
| **Storage** | `None` | **None** — keep it | The `SwiftData` and `Core Data` options scatter a `ModelContainer` into your `@main` file, violating P8 on line one. Persistence is a module decision; `04-ARCHITECTURE-AND-STATE.md` owns it. |
| Interface / Language | SwiftUI / Swift | leave | — |

The generated app target arrives at `SWIFT_VERSION = 5.0` with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Fix the language mode per P18 in the first commit, while there is no code to break — not after you have written 5,000 lines against Swift 5 semantics.

**P41. One app repo, one `.xcodeproj`, no `.xcworkspace`.** Xcode creates `Recipes.xcodeproj/project.xcworkspace` implicitly, so a local package needs no workspace of your own. Create a real workspace only when you have **two or more `.xcodeproj` files** — an app plus a separately-versioned SDK project, or a CocoaPods-era codebase.

**Creating and wiring a local package is three steps, and skipping the last is the classic day-one wall.**

0. **Create the package.** From the repo root, next to `Recipes.xcodeproj`:

```bash
mkdir Modules && cd Modules
swift package init --type library --name AppFeature
```

Then open the generated `Package.swift` and replace it wholesale with §5b's — the generated one has no `platforms:`, no `defaultLocalization`, and no `swiftSettings`, all three of which you need before you write a line of UI.

**Pass `--name AppFeature`, not `--name Modules`.** `--name` sets the *target* name as well as the package name, and the target name is the directory under `Sources/`. Verified on Swift 6.3.3: `--name AppFeature` produces exactly the tree-1 shape, `Sources/AppFeature/AppFeature.swift` and `Tests/AppFeatureTests/AppFeatureTests.swift`, with nothing to rename. Running it as `--name Modules` because the folder is called `Modules` gets you `Sources/Modules/` and `Tests/ModulesTests/` — a module you would `import Modules`, which violates P19 and which you would then have to `git mv` into place. The directory is `Modules/` and the first target inside it is `AppFeature`; those are two different names and the flag wants the second one. Only the package's own `name:` comes out wrong, and replacing the manifest fixes that — §5b's already says `name: "Modules"`.

1. Drag `Modules/` into the project navigator. This *registers* the package: Xcode resolves it, indexes it, and shows its targets.
2. Select the **app target → General → Frameworks, Libraries, and Embedded Content → `+`** and add the `AppFeature` library. (Equivalently: Build Phases → Link Binary With Libraries.) This is what makes the app target *link* the product.

Step 1 alone links nothing. `import AppFeature` in `RecipesApp.swift` — the thing P9 tells you to write next — then fails with **"no such module 'AppFeature'"**, and the error names the import rather than the missing link, which is why it costs people an afternoon. Only declared `products:` appear in that `+` list; that is precisely why the manifest in §5b exports `AppFeature` as a `.library`. A target you did not put in `products:` is invisible here no matter how correct the rest of the manifest is.

Apple's own caveat is worth knowing before you reach for a workspace: *"It's good practice to use a workspace to manage multiple projects. However, you can't create explicit dependencies between two projects in the same workspace."* Workspaces give you implicit dependency detection and cross-project indexing; explicit dependencies require cross-project references instead.

**Cost of the no-workspace choice:** adding a second project later means creating the workspace then and re-pointing CI from `-project` to `-workspace`. That is a ten-minute change. Do not pre-build for it.

**P42. Do not adopt Tuist or XcodeGen for a solo project or a small team on a new app.** Four reasons:

1. `pbxproj` merge conflicts are a **multi-author** problem. A solo developer has no concurrent branch adding files to the same project. The strongest argument for these tools does not apply.
2. Buildable folders already remove most of the churn: adding a file changes nothing in `project.pbxproj`.
3. Moving code into a SwiftPM package moves the module graph into `Package.swift` — a text file that diffs and reviews perfectly. That is the same benefit a generation tool sells, with zero extra tooling.
4. Every generator is a dependency that must track Xcode betas. In a year when you want Xcode 27 on day one, that is a real tax.

Tuist's own blog says the same thing about their own product: their remedy ladder puts synchronized groups first as "low effort" and calls project generation "potentially **overkill** if conflicts are your only concern," recommending you "start small with synchronized groups." Their best-practices page now explicitly recommends buildable folders. That is a vendor arguing against its own upsell — believe it.

| Adopt | When |
|---|---|
| **Tuist** | 3+ engineers **and** 20+ targets **and** you want binary caching. Binary caching is the one thing SwiftPM plus vanilla Xcode genuinely cannot do. |
| **XcodeGen** | You need reproducible project files generated from CI — white-label apps built per client — and you don't need caching. |
| **Neither** | Everything else. |

Both are healthy projects as of 2026-07-27 (XcodeGen 2.46.0 released 2026-07-16; Tuist CLI in the 4.203/4.204 range), so this is a judgement about fit, not about risk.

---

## 10. What to commit

**P43. Commit these:** `.xcodeproj` including `project.pbxproj`; **shared** schemes under `xcshareddata/xcschemes/`; `Package.resolved`; `.xctestplan` files; every `.xcconfig` except `*Local.xcconfig`; `.swift-format`.

**P44. Ignore these:** `xcuserdata/`, `DerivedData/`, `.build/`, `.DS_Store`, `*Local.xcconfig`, `*.hmap`, `*.ipa`, `*.dSYM`.

**P45. `Package.resolved` must be committed, and for an app project it is not where you expect.**

```text
Recipes.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved   # app project
Modules/Package.resolved                                                      # the package itself
```

If your `.gitignore` excludes generated workspace files, whitelist it back explicitly:

```gitignore
*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/*
!*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

**P46. Start from `github/gitignore`'s `Swift.gitignore` and add what it is missing.** As fetched on 2026-07-27 it does **not** include `DerivedData/` or `.DS_Store`. Follow `swift package init`'s lead on `.swiftpm`: ignore the volatile parts, not the whole directory.

```gitignore
# Additions to the upstream Swift.gitignore
.DS_Store
DerivedData/
xcuserdata/
.swiftpm/xcode/xcuserdata/
.swiftpm/configuration/registries.json
Config/Local.xcconfig
```

---

## 11. Contested points, ruled

| Question | The disagreement | Ruling |
|---|---|---|
| Feature vs layer folders | Sundell and most modern practice say feature; most MVVM tutorials and Nimble say layer | **Feature at the top level.** Layers may name modules, never folders. |
| One package or many | Swift Forums consensus and SE-0386 semantics say one; Nimble and manu.show say one per module | **One package, many targets.** `package` access, no versioning obligation, one manifest to keep in step. Many packages *build* — that is a cost argument, not a capability one. |
| SwiftPM package vs Xcode library target | Massicotte (Chime) says library targets, for linkage control; Apple docs and mainstream say packages | **Package for a single-app-target project.** Switch when widgets or extensions link the same modules. |
| Buildable folders vs groups | Apple release notes, Tuist, and community say folders; Apple DTS notes groups still win on logical/physical decoupling | **Folders, everywhere, for a new project.** Groups only if you inherit a disk layout you cannot yet fix. |
| Tuist/XcodeGen in 2026 | Comparison posts imply you must pick one; Tuist itself says it is often overkill | **Neither**, until 3+ engineers and 20+ targets and you want binary caching. |
| `Bundle.module` vs `#bundle` | SwiftPM docs still say "always `Bundle.module`"; Apple's Xcode 27 SwiftUI guidance says `#bundle` is preferred | **`#bundle`.** Available back to iOS 15 in the shipping SDK, so it costs nothing. |
| Strict one type per file | Google's style guide says "most source files contain only one top-level type"; Apple's SwiftUI guidance multiplies your type count | **One type per file, with a named exception for private SwiftUI section views.** |
| Does `Info.plist` still exist | Old advice assumes it always does | **It shouldn't.** `GENERATE_INFOPLIST_FILE = YES` plus `INFOPLIST_KEY_*` in xcconfig. |

---

## Checklist

**Project shape**
- [ ] Wizard: Testing System set to Swift Testing, Storage left at None (P40)
- [ ] Every folder is a buildable folder; no group-without-folder anywhere (P1, P2)
- [ ] No source file is a member of two targets (P3)
- [ ] `Recipes.xcodeproj` at the repo root; no `.xcworkspace` (P41)
- [ ] `Modules/` was created with `swift package init --type library --name AppFeature`, so `Sources/AppFeature/` is right without a rename (§9, P19)
- [ ] The app target *links* the `AppFeature` library under General → Frameworks, Libraries, and Embedded Content — dragging the package in is only step 1 (§9, P41)
- [ ] No Tuist, no XcodeGen (P42)

**Folders**
- [ ] Top level of `Sources/` is features and capabilities; zero `Views/`, `ViewModels/`, `Utils/` directories (P5, P7)
- [ ] If a `Models` target exists, its `dependencies:` array is still empty (P5 carve-out)
- [ ] Layer sub-folders only inside a feature, only past ~10 files (P6)
- [ ] `Sources/` is flat, one directory per module, directory name == module name (P19, P21)
- [ ] Files are moved with `git mv`, not through the navigator (§2)

**App target**
- [ ] `App/` is under a dozen files: `@main`, the call to the composition root, bundle resources (P8)
- [ ] `RecipesApp.swift` imports one feature module (P9)

**Modules**
- [ ] You copied tree 1, not tree 2 — nothing exists that a rule has not yet demanded (§1, P12)
- [ ] `RecipesTests/` exists because the wizard made it, and is still nearly empty (§1, P22, P40)
- [ ] No module was created before it tripped the threshold: two consumers, or simulator-free tests, or ~1,500 lines (P11, P12)
- [ ] Every new file's target was chosen from the placement table, defaulting to "the feature I am in" (§5a)
- [ ] Exactly one local package (P14)
- [ ] Deployment floor decided once (default iOS 18) and identical in `platforms:` and `IPHONEOS_DEPLOYMENT_TARGET` (§5b)
- [ ] `platforms:` also declares macOS, and every target is labelled host-testable or simulator-only (§5b, P23)
- [ ] `swift build --package-path Modules` succeeds — every name in a `dependencies:` array is a declared target (§5b)
- [ ] Graph is wide and shallow; no feature depends on another feature (P13)
- [ ] Every feature/UI target sets `.defaultIsolation(MainActor.self)`; domain and client targets do not (P16, P17)
- [ ] `swiftLanguageModes: [.v6]` and `SWIFT_VERSION = 6.0` agree (P18)
- [ ] Shared fixtures are in a `.target` called `TestSupport`, not a `.testTarget` (P20)

**Tests**
- [ ] Default location is a package test target; the app's bundle is nearly empty (P22)
- [ ] `swift test` locally; both runners on CI (P23)

**Files**
- [ ] One top-level type per file, named for the type (P24)
- [ ] Only exception in use: private SwiftUI section views in the parent's file (P25)
- [ ] Foreign-type extensions are `Foreign+Capability.swift`, one capability each (P27)
- [ ] Zero files named `Utils`, `Helpers`, `Constants`, `Extensions`, `Managers`, `Common`, `Shared` — CI greps for this (P28)
- [ ] Generated code is in `Generated/`, excluded from formatter and linter (P29)

**Resources**
- [ ] No `Info.plist` file; keys are `INFOPLIST_KEY_*` in `Config/Base.xcconfig` (P30)
- [ ] Entitlements path set in xcconfig, not the UI (P31)
- [ ] One `PrivacyInfo.xcprivacy` per shipped bundle: `App/` always, plus any local package that built as a dynamic framework (P32)
- [ ] Module assets live in the module; `App/Assets.xcassets` holds only app-level assets (P33)
- [ ] Every localized string in a package passes `bundle: #bundle` (P36)
- [ ] `defaultLocalization` set on the package if any catalog exists (P35)
- [ ] You have decided, deliberately, whether generated asset/string symbols are worth losing `swift build` (P34)
- [ ] `Config/` sits outside `App/`; one `.swift-format` at the root (P38, P39)

**Version control**
- [ ] `Package.resolved` committed, from both locations (P45)
- [ ] Shared schemes and test plans committed; `xcuserdata/` and `DerivedData/` ignored (P43, P44, P46)
