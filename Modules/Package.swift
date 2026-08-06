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

// The target ceiling is package-manifests.md §3's. A row is uncommented by the epic that writes
// its first file: an empty target is a warning, and a hard error once it reaches products:.
//   HunchNavigation  E10   route graph, nonisolated values
//   Feedback         E20   the two cue players
//   LoomFeature      E08   the play surface
//   CodexFeature     E15   the archive
//   MetaFeature      E16   Anomaly and Profile
//   HunchAppFeature  E10   the composition root App/ imports
let package = Package(
    name: "Modules",
    // defaultLocalization MUST precede platforms — SwiftPM rejects the other order outright
    // ("argument 'defaultLocalization' must precede argument 'platforms'"). The manifest in
    // package-manifests.md §3 has them the other way round and does not compile.
    defaultLocalization: "en",  // required by the String Catalog — 01 P35
    // package-manifests.md §3 says "iOS only — this package is never built for the host".
    // That does not survive contact with SwiftPM: an unstated platform defaults to its oldest
    // supported version, so macOS resolves to 10.13 and cannot depend on HunchCore, which
    // declares macOS 15. The floor must be stated even though nothing here is ever built for
    // it. It must also EQUAL HunchCore's, or resolution fails the other way.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "HunchUI", targets: ["HunchUI"]),
        .library(name: "LoomFeature", targets: ["LoomFeature"]),
        .library(name: "Feedback", targets: ["Feedback"]),
        .library(name: "HunchAppFeature", targets: ["HunchAppFeature"]),
        .library(name: "HunchNavigation", targets: ["HunchNavigation"]),
    ],
    dependencies: [.package(path: "../HunchCore")],
    targets: [
        .target(
            name: "HunchUI",
            dependencies: [.product(name: "HunchCore", package: "HunchCore")],
            // The catalog is empty until E18 fills it, but it must EXIST: an empty Resources
            // directory builds a resource bundle with no payload, and codesign rejects that
            // ("bundle format unrecognized, invalid, or unsuitable"). One real file fixes it.
            resources: [.process("Resources")],  // Localizable.xcstrings — 01 P35
            swiftSettings: ui
        ),
        .testTarget(
            name: "HunchUITests", dependencies: ["HunchUI", "ModulesTestSupport", "LoomFeature"],
            swiftSettings: ui),

        // A .target, never a .testTarget — test targets cannot be depended on (01 P20). It may
        // import Testing under 06 T5a's three conditions: absent from products:, named only by
        // test targets, and both asserted in CI rather than remembered. It is this package's
        // HunchTestSupport, and exists because that one is absent from HunchCore's products:.
        .target(
            name: "ModulesTestSupport",
            dependencies: ["LoomFeature", .product(name: "HunchCore", package: "HunchCore")],
            swiftSettings: ui
        ),

        // A cue VOCABULARY is data, so this target takes no default isolation and imports
        // neither AVFoundation nor CoreHaptics. Only the value half ships here; the four
        // players are E20's. See DECISIONS.md 49 for why the target exists a phase early.
        .target(
            name: "Feedback",
            dependencies: [.product(name: "HunchCore", package: "HunchCore")],
            swiftSettings: base
        ),

        .target(
            name: "LoomFeature",
            dependencies: [
                "HunchUI", "Feedback",
                .product(name: "HunchCore", package: "HunchCore"),
            ],
            swiftSettings: ui
        ),

        // A route graph is values, so this target takes NO default isolation (08 §4).
        .target(
            name: "HunchNavigation",
            dependencies: [.product(name: "HunchCore", package: "HunchCore")],
            swiftSettings: base
        ),

        .testTarget(
            name: "HunchNavigationTests",
            dependencies: ["HunchNavigation", "ModulesTestSupport"],
            swiftSettings: ui
        ),

        .target(
            name: "HunchAppFeature",
            dependencies: [
                "HunchUI", "LoomFeature", "Feedback", "HunchNavigation",
                .product(name: "HunchCore", package: "HunchCore"),
            ],
            swiftSettings: ui
        ),

        .testTarget(
            name: "HunchAppFeatureTests",
            dependencies: ["HunchAppFeature", "ModulesTestSupport"],
            swiftSettings: ui
        ),

        .testTarget(
            name: "LoomFeatureTests",
            dependencies: [
                "LoomFeature", "ModulesTestSupport",
                .product(name: "HunchCore", package: "HunchCore"),
            ],
            swiftSettings: ui),
    ]
)
