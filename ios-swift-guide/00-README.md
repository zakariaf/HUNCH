# iOS / Swift Engineering Guide

Seven files that give one defensible default per decision for building a **new SwiftUI iOS app in Swift** — project shape, naming, day-to-day code, state and dependencies, concurrency, tests, and everything between "it compiles" and "it is in TestFlight." It is written for an engineer who wants a ruling rather than a survey: every rule is numbered so the files can cite each other, every contested point is ruled with the losing argument stated, and every cost is named. It is current as of **2026-07-27** against **Xcode 26.6 (17F113)**, **Swift 6.3.3** (`swiftlang-6.3.3.1.3`), the **iOS 26.5 SDK**, and the **swift-format 6.3.0** bundled in that toolchain, shipping in **Swift 6 language mode**; `07-TOOLING-BUILD-AND-SHIPPING.md §0` is the single source for those numbers and every other file restates them. The shipping deployment floor is **iOS 18** (`01 §5b`), with iOS 17 as the architectural floor below which `04` stops applying. **Xcode 27 beta 4 (27A5228h) / Swift 6.4 / the iOS 27 SDK** are covered as a migration you will perform, not a baseline you adopt — every section about them says so inline.

---

## The short version

The twenty rules that would save the most pain if this were the only page you read.

1. Set `SWIFT_VERSION = 6.0` on every target in commit one, and write the `.0` — a bare `6` still enforces Swift 6 but makes the settings table report `SWIFT_STRICT_CONCURRENCY = minimal` on a project that is actually strict. → **07 B1, B2**
2. A new Xcode app target compiles Swift 5 / `MainActor`-default while a new SwiftPM package compiles Swift 6 / `nonisolated`, so set `.defaultIsolation` and the language mode **in the same commit** you move the first file into a package. → **01 P16–P18**
3. Do not pre-create a `Core`/`Networking`/`DesignSystem` scaffold; extract a module the first time two targets need it, or you want tests without a simulator, or it crosses ~1,500 lines with a nameable responsibility. → **01 P11, P12**
4. The top level of `Sources/` is named for features and capabilities, never for layers — `Views/`, `ViewModels/`, `Utils/`, `Helpers/`, `Common/` are banned as directory names. → **01 P5, P7**
5. Put the logic in package targets so `swift test` runs with no simulator boot and the app's test bundle stays nearly empty — this is the single largest lever on inner-loop latency and it is structural, not a testing technique. → **01 P22, P23; 06 T3**
6. Every build setting lives in an `.xcconfig` and `project.pbxproj` carries zero, checked by a CI script — a value typed into the Build Settings tab silently beats your xcconfig. → **07 B5, B6**
7. On CI: pin `macos-26`, select Xcode explicitly with `xcode-select`, resolve the simulator by UDID or `OS=latest`, and `set -o pipefail` before every pipe into a log formatter or green builds will hide failing tests. → **07 B28–B31**
8. Ship a truthful `PrivacyInfo.xcprivacy` in the right bundle (`UserDefaults` is a required-reason API) and set `ITSAppUsesNonExemptEncryption` once in the xcconfig, or TestFlight builds stall on Missing Compliance. → **07 B36, B37; 01 P32**
9. Compose the whole object graph in exactly one `live()` factory in the top feature module, named in one line by `@main` — the factory is the composition root, because `@main` is the one type a test and a preview can never construct. → **04 A2**
10. One `@Observable` store per bounded context, not per screen, and no per-screen view models by default — name a screen-scoped type for its job (`CheckoutFlow`), never `XViewModel`. → **04 A17–A19; 02 N40**
11. Read tracked state inside `body` and derive rather than store it — a value mirrored into `@State`, or read in `.onAppear`/`Task`/a button action, forms no dependency and never updates again. → **04 A6, A14, A15**
12. Domain logic lives in a module that *cannot* `import SwiftUI`; a review rule is not the same guarantee as a target boundary. → **04 A21**
13. Re-inject the environment into every sheet, cover, popover and new window — a presented subtree starts a new hierarchy, and a missing `@Environment` is a runtime trap rather than a compile error. → **04 A25, A26**
14. Choose state ownership in this order — `@MainActor`, then `Mutex` (or `OSAllocatedUnfairLock` below iOS 18), then `actor` — and never make an actor to protect a counter, a flag or a cache dictionary. → **05 R17, R18**
15. `nonisolated func … async` no longer means "off the main thread"; audit every one with the compiler's `:migrate` mode and say `@concurrent` where you meant to offload. → **05 R13, R14**
16. `@unchecked Sendable` without a comment naming the exact synchronisation mechanism is a defect, and "my target is iOS 17 so I need it for locks" is the most common false justification. → **05 R26, R27**
17. `await` is not a critical section: re-validate state read before a suspension, and cache the `Task` rather than the value so ten concurrent misses produce one fetch. → **05 R12, R30, R31**
18. Default to `struct`, make illegal states unrepresentable with an enum instead of a bag of `Bool`s and optionals, and let no bare `!` or `try!` outside tests survive review. → **03 W1, W25, W28, W37**
19. Reject `FooProtocol`, `FooManager`/`Provider`/`Helper`/`Service`, `getUserAsync(id:)` and `Utils.swift` on sight — a name that describes a bag of code is how a type reaches 2,000 lines without anyone noticing it changed subject. → **02 N25, N26, N37, N45**
20. Give every dependency an `unimplemented` double that fails loudly when touched, inject a clock instead of sleeping, and never add a blanket CI retry — retrying is precisely the mechanism by which a race condition ships. → **06 T38, T41, T63**

---

## The seven files

| File | Covers | Open it when |
|---|---|---|
| `01-PROJECT-STRUCTURE.md` (P1–P46) | Repo tree, buildable folders, feature-first layout, the app-target shell, when and how to modularise, one package with N targets, deployment floor, where tests live, which file a declaration goes in, resources and manifests, the new-project wizard, what to commit | Before the first line of a new app; again when an existing one passes ~15k lines and navigation hurts |
| `02-NAMING-AND-API-DESIGN.md` (N1–N47) | Types, methods, argument labels, booleans, initialisers, protocols, enums and errors, generics, acronyms, async and actors, SwiftUI views/modifiers/environment, test names, file and module names, doc comments, the ban list | You are about to type a declaration and want a defensible default instead of a debate |
| `03-WRITING-THE-CODE.md` (W1–W57) | Choosing the kind of type, access control, files and extensions, immutability, optionals, illegal states, errors and typed throws, generics vs existentials, protocol vs struct-of-closures, the metaprogramming budget, doc comments, `swift-format` config, the fails-review-on-sight table | Writing or reviewing day-to-day application code |
| `04-ARCHITECTURE-AND-STATE.md` (A1–A50) | Observation and `@Observable`, the Xcode 27 `@State` macro migration, the property-wrapper table, the view-model ruling, the UI-free core, dependency injection, navigation as data, the persistence boundary and `@Query`-vs-repository, the networking client, whether to buy TCA | Deciding where state lives, who owns it, and how the pieces reach each other |
| `05-CONCURRENCY.md` (R1–R56) | Which settings to turn on and in what order, default isolation per module, reading the two classes of diagnostic, `nonisolated` after SE-0461, `Sendable` vs `sending`, actor reentrancy, SwiftUI isolation, structured concurrency and cancellation, bridging callbacks, migrating an existing app | §2–§7 before the first line of a new app; §12–§13 when staring at a wall of warnings in an old one |
| `06-TESTING.md` (T1–T63) | What to test and what to refuse, Swift Testing mechanics, `#expect` vs `#require`, traits and tags, parameterized tests, test doubles by hand, determinism, what stays in XCTest, snapshots, fixtures and migration tests, keeping the fast suite under ten seconds, coverage, flakes | Writing tests, reviewing them, or deciding what a test target should contain |
| `07-TOOLING-BUILD-AND-SHIPPING.md` (B1–B46) | Language mode, xcconfig, build settings worth setting, run-script phases, formatting and linting, `Package.swift` mechanics, schemes and test plans, versioning, GitHub Actions and source-hygiene checks, archive/sign/upload, rejection triggers, localization, profiling and app size, accessibility audits in CI | You own a project's build configuration or its CI |

---

## Start here

### Starting a brand-new app

1. `01 §1` — copy tree 1, not tree 2. Tree 2 is where tree 1 ends up, not a scaffold to create.
2. `01 §9` — the wizard's two wrong defaults, and the three steps of wiring a local package (skipping the third is the classic day-one wall).
3. `07 §1–§2` — language mode and xcconfig, in the first commit, while there is no code to break.
4. `05 §2–§7` — the isolation design. This is the decision that is expensive to change later; everything else can be refactored.
5. `04 §2`, `§5–§7` — the composition root, the property-wrapper table, and the view-model ruling.
6. `02` and `03` — opened per declaration as you write, not read front to back.
7. `06 §1–§3` once there is something worth testing; `07 §9` for CI; `07 §10–§11` before the first upload.

### Joining an existing codebase

1. `07 §16` and `01 §11` — the contested-points tables. Read them to find out which side of each ruling the project is already on before you propose changing anything.
2. `01 §2`, `§5a` — is the module graph shaped, or accidental? The placement table answers "where does this go" for every future file.
3. `05 §13` — if the codebase is not yet in Swift 6 mode, this migration table is the plan, one shippable commit per row.
4. `04 §14` and `03 §13` — the review-trigger and fails-on-sight tables. These are what turn a diff into a list of concrete objections.
5. `06 §20` if the suite flakes; `06 §18` if it is merely slow.

Do not open with a naming pass. `02` is the cheapest file to apply per declaration and the most expensive place to spend your first month.

### Fixing a specific problem

| Symptom | Go to |
|---|---|
| A concurrency error you do not understand | `05 §4` — classify it as `Sendable` or isolation *before* fixing, then `§12` |
| A view that silently stopped updating | `04 §3` (A6) — the three ways a tracked read escapes `body` |
| CI green on failing tests, or a build that differs on the runner | `07 §9` |
| A suite that takes minutes | `06 §18` |
| A build rejected by App Store Connect | `07 §11` |
| A naming argument that will not resolve | `02 N2` — it converts the debate into a design task |
| "Where does this new file go?" | The placement table in `01 §5a` |
| "Do I need a protocol here?" | `03 W44`, which owns the guide's one copy of the threshold |

---

## What this guide deliberately does not cover

- **UIKit as an architecture.** SwiftUI-first throughout; UIKit appears only as interop — `UIApplicationDelegateAdaptor`, `@IBOutlet` in `03 W24`, `#if canImport(UIKit)` guards, and XCUITest. No view controllers, storyboards, Auto Layout, or coordinator patterns (`04 A38` rules the coordinator layer out rather than documenting it).
- **Server-side Swift.** Vapor, Hummingbird and the whole server ecosystem are absent; `04 §11a` is an HTTP *client*, not a service.
- **Non-iOS platforms.** macOS appears only as the host `swift test` builds against (`01 §5b`); watchOS, tvOS, visionOS and widgets appear only as availability rows and as the trigger that forces a module split (`01 P11`). No Catalyst, no spatial design.
- **App Store marketing and monetisation.** `07 §11` covers only the metadata that gets builds *rejected*; screenshots, localized metadata push, ASO, pricing, subscriptions and StoreKit are out — `07 B35` names screenshot and metadata automation as the explicit cost of skipping fastlane.
- **Design and the HIG.** `DesignSystem` is named as a module and `07 §14` wires `performAccessibilityAudit` into CI, but there is no guidance on tokens, typography, colour, motion, or Icon Composer artwork beyond the mechanics in `01 P37`.
- **Specific third-party frameworks**, mostly because the guide rules against them: TCA (`04 A43`), mocking frameworks (`06 T36`), property-based-testing libraries (`06 T52`), ViewInspector (`06 §21`), Tuist/XcodeGen (`01 P42`), fastlane on a new single-app project (`07 B35`). The short conditional endorsement list is `swift-dependencies`, `swift-sharing`, `swift-clocks`, `swift-snapshot-testing`, `swift-numerics`, GRDB and SwiftLint — each with its trigger stated. Combine gets no treatment beyond "what you migrate off"; RxSwift none at all.
- **Whole subsystems with their own literature:** CloudKit sync, push notifications, App Intents and Live Activities, keychain and cryptography, analytics vendors, crash reporting beyond stable `errorCode`s, ML, and Objective-C interop past annotating headers. Core Data is covered only as "do not start a new one in 2026" (`04 §11`).

---

## Version sensitivity

**Ages fastest, roughly in order:**

1. The version table each file opens with. Six carry one (`01 §0`, `03 §0`, `04 §1`, `05 §1`, `06 §0`, `07 §0`) and `02 §0` carries the prose equivalent; `07 §0` is the declared single source, so update it first and let the copies follow.
2. Everything marked Xcode 27 / Swift 6.4 — `04 §4` (`@State` becomes a macro; TN3211), `05 §14`, `06 T46` (XCTest interop), `03 W5`/`W27`, `07 §15`. These are dated for a September 2026 GA.
3. New-project template defaults, read out of `TemplateInfo.plist` and changed per release: `01 P40`, `05 §2`, `07 §1`.
4. `swift-format`'s 43-rule default set — which is exactly why `03 W54` commits only the delta and not a dumped config.
5. CI runner image contents. The `macos-26` image README changes monthly; installed Xcodes and simulator runtimes move under you (`07 B28`–`B30`).
6. Third-party version pins scattered through `04 §11–§12` and `06 §15–§16`.
7. Accepted-but-unshipped proposals whose spelling may still move: SE-0506, ST-0025, ST-0026, SE-0516, SE-0526.
8. The iOS 18 floor (`01 §5b`), which moves as the install base does.

**Ages slowest:** Apple's API Design Guidelines, unamended since SE-0023 in 2016. `02`'s spine is the safest thing here — learn it once, re-learn the surface each September.

**When a new Swift or Xcode ships, re-check in this order:**

1. Re-run the verification commands — `xcodebuild -version`, `swift --version`, `xcrun --sdk iphoneos --show-sdk-path`, `xcrun swift-format --version` — and update `07 §0` first, because the other six restate or cite it.
2. `xcrun swift-format dump-configuration | diff - .swift-format`. Read the diff; do not overwrite the file with it.
3. `swiftc -print-supported-features` for feature names, `migratable`, and `enabled_in` — an unrecognised `-enable-upcoming-feature` name is accepted silently and does nothing, so a flag that changes nothing tells you nothing.
4. The new template plists, for the wizard and target defaults `01 P40` tells you to change.
5. The runner image README, before re-pinning `07 B28`/`B29`.
6. A Release build with `-warnings-as-errors`, where a newly-deprecated API becomes a hard failure — `UIScreen.main` in iOS 26 was the last one.
7. The actual SDK headers for any API the guide flags as unconfirmed — chiefly SE-0506's continuous-observation spelling (`04 §1`, `§13`), where Apple's sample and the proposal disagree, and the required-reason codes in `07 B36`.
