// swift-tools-version: 6.2
import PackageDescription

// Applied to every target and test target. There is NO .defaultIsolation anywhere in this
// package: 01 P17 and 05 R7 put pure-domain modules on the nonisolated default, and 08 §4 makes
// it explicit — nothing here touches the main actor and nothing here is a class.
let coreSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),  // 03 W43 names the price
    .enableUpcomingFeature("MemberImportVisibility"),  // 07 B7b names the price
    .enableUpcomingFeature("InternalImportsByDefault"),  // 07 B7a names the price
]

// ─────────────────────────────────────────────────────────────────────────────────────────────
// THE TARGET CEILING — 08 §1's tree. A row is uncommented by the epic that writes its first
// file, together with its .testTarget row and its entry in the HunchCore product (01 P12,
// 08 §7.3, hunch-build-and-ci/references/package-manifests.md §2 and §4). An empty target is a
// build-graph node with no code, no tests and one warning per build.
//
//   Tokens         E03  leaf                       Prim, semantic layer, RenderEnv, C.*
//   Glyphs         E02  leaf                       Glyph, Deck, Bitboard256/65536
//   Laws           E02→E05  ["Glyphs"]             LawNode, Law, LawTable, MaskTable, RNF, LawIndex
//   Bench          E06  ["Laws", "Glyphs"]         BenchLayout, RuleTile, SealBar
//   LawGeneration  E01→E06  ["Laws", "Bench"]      SplitMix64 (T05), Band, Difficulty, Generator
//   Rounds         E07  ["Laws", "Bench"]          RoundPhase, Outcome, Ribbon, Score, RoundSnapshot
//   Ladder         E11  ["Rounds"]                 Ability, AbilityEstimator, ServingPolicy
//   Archive        E16  ["Laws", "Rounds"]         CodexPage, RoundRecord, Profile, AnomalyLedger
//   Persistence    E07  ["Archive","Ladder","Rounds","Laws"]   PersistenceStore, StoreFile, …
//
// LawGeneration's dependency list is empty in E01 because SplitMix64 imports nothing; the edges
// arrive with the files that need them (package-manifests.md §4 rule 3 — a speculative
// dependencies: entry compiles fine and silently widens the boundary you are paying to keep
// narrow).
// ─────────────────────────────────────────────────────────────────────────────────────────────

let package = Package(
    name: "HunchCore",
    // macOS is not decoration: it is what `swift test` builds against on the host, what
    // #bundle's availability is checked against, and what makes exit tests available at all
    // (07 B22, 06 T49, 01 §5b). iOS must equal IPHONEOS_DEPLOYMENT_TARGET in Config/Base.xcconfig.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // The single library product arrives in T05 with the first shipping target.
        // HunchTestSupport is deliberately NEVER here — that absence is half of what keeps
        // `import Testing` out of the release binary (01 P20, 06 T5a). Check 4 asserts it.
    ],
    targets: [
        // A .target, never a .testTarget — test targets cannot be depended on (01 P20).
        // It may import Testing under 06 T5a's three conditions: absent from products:, named
        // only by test targets, and both asserted in CI rather than remembered.
        .target(name: "HunchTestSupport", swiftSettings: coreSettings),

        .testTarget(
            name: "HunchTestSupportTests",
            dependencies: ["HunchTestSupport"],
            swiftSettings: coreSettings
        ),
    ],
    swiftLanguageModes: [.v6]  // 01 P18 — redundant at tools 6.2, but it states the intent and
)  // it is the half of the pair Config/Base.xcconfig's 6.0 agrees with
