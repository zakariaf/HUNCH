# The two package manifests

1. [Why two, and what the second one costs](#1-why-two-and-what-the-second-one-costs)
2. [`HunchCore/Package.swift`](#2-hunchcorepackageswift)
3. [`Modules/Package.swift`](#3-modulespackageswift)
4. [Adding a target](#4-adding-a-target)
5. [The platform floors, ruled](#5-the-platform-floors-ruled)
6. [Resources](#6-resources)
7. [`InternalImportsByDefault` across the boundary](#7-internalimportsbydefault-across-the-boundary)
8. [Failures and what they actually mean](#8-failures-and-what-they-actually-mean)

---

## 1. Why two, and what the second one costs

`01 P14` says own exactly one local package. HUNCH owns two, and `08 §7.2` is the ruling: one package means `swift test` compiles the SwiftUI targets on the host, where iOS-only modifiers do not exist, and the 10-second fast suite dies. Of `P14`'s three costs, two are void here — nothing consumes these packages, and the brief bans third-party dependencies so there is no shared dependency to keep in step. **The one surviving cost is that `package` access does not cross the boundary**, so everything `Modules/` exposes to `App/` is `public` (`03 W6`, `08 §7.2`).

The dependency arrow is the module boundary, and it is enforced by the manifests rather than by a lint rule: `Modules` declares `.package(path: "../HunchCore")`, `HunchCore` declares nothing. Leave the edge out and the `import` stops compiling (`04 A3`, `08 §2`). That is why `hunch-swift-code`'s `check-boundary.sh` audits *imports inside* `HunchCore`, not the package graph — the graph cannot be wrong.

---

## 2. `HunchCore/Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

// Applied to every target and test target. No .defaultIsolation anywhere in this package:
// 01 P17 and 05 R7 put pure-domain modules on the nonisolated default, and 08 §4 makes it
// explicit — nothing here touches the main actor.
let coreSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "HunchCore",
    // macOS is not decoration: it is what `swift test` builds against on the host, and what
    // #bundle's availability is checked against in PersistenceTests (07 B22, 01 §5b).
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "HunchCore", targets: [
            "Tokens", "Glyphs", "Laws", "LawGeneration", "Bench",
            "Rounds", "Ladder", "Archive", "Persistence",
        ]),
        // HunchTestSupport is deliberately NOT here — that absence is half of what keeps
        // `import Testing` out of the release binary (01 P20, 06 T5a). Check 4 asserts it.
    ],
    targets: [
        .target(name: "Tokens", swiftSettings: coreSettings),           // leaf, no dependencies
        .target(name: "Glyphs", swiftSettings: coreSettings),           // leaf
        .target(name: "Laws", dependencies: ["Glyphs"], swiftSettings: coreSettings),
        .target(name: "Bench", dependencies: ["Laws", "Glyphs"], swiftSettings: coreSettings),
        // The generator depends on Bench because G10 is a generation-time guardrail: the
        // generator refuses to emit a law the Bench cannot express (08 §2).
        .target(name: "LawGeneration", dependencies: ["Laws", "Bench"], swiftSettings: coreSettings),
        .target(name: "Rounds", dependencies: ["Laws", "Bench"], swiftSettings: coreSettings),
        .target(name: "Ladder", dependencies: ["Rounds"], swiftSettings: coreSettings),
        .target(name: "Archive", dependencies: ["Laws", "Rounds"], swiftSettings: coreSettings),
        .target(
            name: "Persistence",
            dependencies: ["Archive", "Ladder", "Rounds", "Laws"],
            swiftSettings: coreSettings
        ),

        // A .target, never a .testTarget — test targets cannot be depended on (01 P20).
        .target(
            name: "HunchTestSupport",
            dependencies: ["Laws", "LawGeneration", "Glyphs", "Persistence"],
            swiftSettings: coreSettings
        ),

        .testTarget(name: "TokensTests", dependencies: ["Tokens"], swiftSettings: coreSettings),
        .testTarget(name: "GlyphsTests", dependencies: ["Glyphs", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(name: "LawsTests", dependencies: ["Laws", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(
            name: "LawGenerationTests",
            dependencies: ["LawGeneration", "HunchTestSupport"],
            resources: [.copy("Fixtures")],          // .copy, so every lookup passes subdirectory: — 06 T54
            swiftSettings: coreSettings
        ),
        .testTarget(name: "BenchTests", dependencies: ["Bench", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(name: "RoundsTests", dependencies: ["Rounds", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(name: "LadderTests", dependencies: ["Ladder", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(name: "ArchiveTests", dependencies: ["Archive", "HunchTestSupport"], swiftSettings: coreSettings),
        .testTarget(
            name: "PersistenceTests",
            dependencies: ["Persistence", "HunchTestSupport"],
            resources: [.copy("Fixtures")],
            swiftSettings: coreSettings
        ),
    ]
)
```

**`swiftLanguageModes` is absent on purpose.** At `swift-tools-version: 6.2` the package is already in language mode 6; `01 P18` asks that the app and the package agree, and they do. Add `swiftLanguageModes: [.v6]` if you prefer the intent stated — it is redundant, not wrong. What is *not* optional is that the tools version stays at 6.2 or later, because `Modules` needs `.defaultIsolation` and `07 B21` puts that at PackageDescription 6.2.

**The target list is a ceiling, not a schedule.** `01 P12` and `08 §7.3` both say create a target the day its owner section is implemented. Delete the rows you have not built rather than shipping empty directories — an empty target is a build-graph node with no code and no tests.

---

## 3. `Modules/Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

let base: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

// 01 P17 / 05 R7 / 08 §4: UI and feature targets are main-actor by default; a route graph and
// a cue vocabulary are values and stay nonisolated. Every declaration visible outside its own
// file still writes @MainActor explicitly (05 R8) — the setting is a default, not a substitute.
let ui: [SwiftSetting] = base + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Modules",
    // iOS only — see §5. This package is never built for the host.
    platforms: [.iOS(.v18)],
    defaultLocalization: "en",                       // required by the String Catalog — 01 P35
    products: [
        .library(name: "HunchAppFeature", targets: ["HunchAppFeature"]),   // App/ imports this and
    ],                                                                     // nothing else — 01 P9
    dependencies: [.package(path: "../HunchCore")],
    targets: [
        .target(name: "HunchNavigation", swiftSettings: base),
        .target(
            name: "HunchUI",
            dependencies: [.product(name: "HunchCore", package: "HunchCore")],
            resources: [.process("Resources")],      // Localizable.xcstrings — 01 P35
            swiftSettings: ui
        ),
        .target(
            name: "Feedback",
            dependencies: [.product(name: "HunchCore", package: "HunchCore")],
            swiftSettings: base                      // nonisolated: the two players annotate themselves
        ),
        .target(
            name: "LoomFeature",
            dependencies: ["HunchUI", "HunchNavigation", "Feedback",
                           .product(name: "HunchCore", package: "HunchCore")],
            swiftSettings: ui
        ),
        .target(name: "CodexFeature", dependencies: ["HunchUI", "HunchNavigation"], swiftSettings: ui),
        .target(name: "MetaFeature", dependencies: ["HunchUI", "HunchNavigation"], swiftSettings: ui),
        .target(
            name: "HunchAppFeature",
            dependencies: ["LoomFeature", "CodexFeature", "MetaFeature", "Feedback"],
            swiftSettings: ui
        ),

        .testTarget(name: "HunchNavigationTests", dependencies: ["HunchNavigation"], swiftSettings: base),
        .testTarget(name: "HunchUITests", dependencies: ["HunchUI"], swiftSettings: ui),
        .testTarget(name: "LoomFeatureTests", dependencies: ["LoomFeature"], swiftSettings: ui),
        .testTarget(name: "CodexFeatureTests", dependencies: ["CodexFeature"], swiftSettings: ui),
    ]
)
```

**Name collision to resolve before the second of these two targets exists.** `06 T5b` mirrors the source path, so `HunchUI`'s unit tests are `Modules/Tests/HunchUITests` — and the Xcode wizard's XCUITest bundle is also called `HunchUITests` (`08 §1`). Two test targets with one name makes `-only-testing:HunchUITests` ambiguous and puts two identically-named rows in every scheme and test plan. **Rename the Xcode UI test target to `HunchAutomationTests`**; the package's mirroring rule is mechanical and load-bearing, the wizard's name is not. Record it in `DECISIONS.md`, and update `08 §1`'s tree.

---

## 4. Adding a target

1. **Decide the package first** — `hunch-swift-code`'s boundary predicate, run as `check-boundary.sh`, not by eye.
2. **Add the `.target`, its dependency edges, and its `.testTarget` in one commit.** One test target per source target, path-mirrored (`06 T5b`).
3. **Add an edge only when a file actually imports it.** A speculative `dependencies:` entry compiles fine and silently widens the boundary you are paying to keep narrow.
4. **If it goes in `HunchCore`, do not give it a `.defaultIsolation`.** If it goes in `Modules` and draws or observes, give it `ui`; if it is values, give it `base`.
5. **Do not add it to `products:` unless something outside the package imports it.** `HunchCore`'s single library product and `Modules`' single `HunchAppFeature` product are what keep `01 P9` true — `App/` imports exactly one module.
6. **Re-run `swift build --package-path HunchCore`** and the hygiene script. A new target that lands in `products:` by reflex is how `HunchTestSupport` would leak.

---

## 5. The platform floors, ruled

| Package | `platforms:` | Why |
|---|---|---|
| `HunchCore` | `[.iOS(.v18), .macOS(.v15)]` | `swift test` builds it for the host. Without the macOS entry, `#bundle` in `PersistenceTests` fails with `'bundle()' is only available in macOS 12 or newer` — an error that names macOS on a project you think is iOS-only (`07 B22`). Exit tests (`06 T49`) also need a host platform. |
| `Modules` | `[.iOS(.v18)]` | **This package is never built for the host.** `HunchUI`, `LoomFeature`, `CodexFeature` and `MetaFeature` use iOS-only SwiftUI, `CHHapticEngine` and `AVAudioSession`; adding `.macOS` would promise a host build they cannot honour, and the failure would arrive as a wall of availability errors on an unrelated day. |

**The consequence, stated plainly:** `swift test --package-path Modules` is not a command in this repo. Everything in `Modules` is tested through `xcodebuild test` in the simulator. `08 §1`'s note that `HunchNavigation` avoids SwiftUI "so `NavigationDepthTests` runs on the host" cannot be true while its package is iOS-only — if a `Modules` test genuinely needs the host, its subject passes the boundary predicate and belongs in `HunchCore`. That is a placement call and it is `hunch-swift-code`'s, not this file's; flag it rather than papering over it with a macOS floor.

`IPHONEOS_DEPLOYMENT_TARGET = 18.0` in `Config/Base.xcconfig` is the third copy of the iOS floor and must equal both (`xcconfig.md` §6).

---

## 6. Resources

- **`Localizable.xcstrings`** at `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` with `resources: [.process("Resources")]` and `defaultLocalization: "en"` — all three are required and the third is the one people miss (`01 P35`). One catalog for the whole app.
- **Fixture trees** use `.copy`, not `.process`, because the directory layout *is* the fixture — `Fixtures/v1/` is a whole `Application Support/Hunch/` tree (`08 §5`). `.copy` preserves it and `.process` flattens it, so every lookup must pass `subdirectory: "Fixtures"` (`06 T54`).
- **Load through `#bundle`, never `Bundle.main`** (`01 P36`, `07 B22`). `Bundle.main` works in the app target and returns the wrong bundle in every test.
- **There are no image assets.** `App/Assets.xcassets` holds the app icon and the launch colour and nothing else (`01 P33`, `P37`); every mark is drawn. A `.png` appearing in either package is a design-system violation before it is a build one.

---

## 7. `InternalImportsByDefault` across the boundary

`07 B7a`: an undecorated `import` is `internal`, so an import must be at least as visible as the most visible declaration exposing a type from it. Two shapes in this repo:

```swift
// Inside HunchCore — `package` is enough, because both files are in the same package.
package import Laws

package func difficulty(of law: Law) -> Double { … }
```

```swift
// Modules/Sources/HunchUI/GlyphCanvas.swift — `public`, because `package` does not cross the
// two-package boundary (03 W6, 08 §7.2) and this signature leaves the package.
public import HunchCore

public struct GlyphCanvas: View {
    public init(glyph: Glyph, env: RenderEnv) { … }
}
```

```swift
// ❌ Compiles until the day a public signature mentions a HunchCore type, then errors at the
//    DECLARATION, not at the import — with nothing visibly wrong at the error site.
import HunchCore

public struct GlyphCanvas: View {
    public init(glyph: Glyph, env: RenderEnv) { … }   // error: cannot be declared public…
}
```

Everything you do not re-export stays a plain `internal import`, which is the point: the compiler then skips rebuilding your module when an internal-only dependency changes.

---

## 8. Failures and what they actually mean

| Message | Cause | Fix |
|---|---|---|
| `'bundle()' is only available in macOS 12 or newer` | you host-built a package with no macOS floor | If it is `HunchCore`, add `.macOS(.v15)`. If it is `Modules`, stop host-building it (§5). |
| `cannot be declared public because its parameter uses an internal type` | `07 B7a` — the import is narrower than the API | raise the import to `package` or `public` (§7) |
| `instance method '…' is inaccessible due to missing import of defining module '…'` | `07 B7b` — a member reached through a transitive import | add the import the note names; `MIGRATE` emits these as fix-its |
| `product 'HunchCore' required by package 'Modules' target … not found` | the `.product(name:package:)` spelling, or a missing `dependencies:` entry | the package name is `HunchCore`, the product is `HunchCore` — both are required in `.product` |
| a test target cannot see `HunchTestSupport` | it is a `.target` and must be listed in that test target's `dependencies:` | `01 P20` |
| `HunchTestSupport` appears in check 4's output | something non-test named it, or it reached `products:` | remove the edge; `import Testing` was one link from the release binary (`06 T5a`) |
