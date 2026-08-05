# Where a Swift file goes

1. [The tree — print it, never copy it](#1-the-tree--print-it-never-copy-it)
2. [The routing table](#2-the-routing-table)
3. [The boundary predicate, in full](#3-the-boundary-predicate-in-full)
4. [Which file inside the target](#4-which-file-inside-the-target)
5. [Creating a target](#5-creating-a-target)
6. [Where tests go](#6-where-tests-go)
7. [The twelve places HUNCH deviates from the guide](#7-the-twelve-places-hunch-deviates-from-the-guide)
8. [Not owned here](#8-not-owned-here)

---

## 1. The tree — print it, never copy it

`ios-swift-guide/08-APPLIED-TO-HUNCH.md` §1 is the normative tree, annotated per line with the rule that put it there. Read it rather than trusting a paraphrase:

```bash
sed -n '/^## 1\. The tree/,/^## 2\./p' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

Two facts from it govern everything below. **`E03/` is the repo root** and `Hunch.xcodeproj` sits at that root, not under `App/` (`01 P41`). **There are two packages**, `HunchCore/` and `Modules/`, and that is a named deviation from `01 P14` with a ruling in `08 §7.2` — do not "fix" it into one package.

Do not create a target before its owner section is being implemented (`01 P12`, `08 §7.3`). `Feedback`, `EchoRoundView`, `SieveSchedule` and `MetaFeature` arrive at phase 5/6, not on day one. The dynamic listing at the top of `SKILL.md` tells you which targets are real right now.

## 2. The routing table

Run it top to bottom and take the first match. The last row is the one that keeps the graph honest — `01 §5a`'s "anything else" default, which is how you avoid inventing a target for one file.

| What you are adding | Target |
|---|---|
| The glyph value, its four attributes, the deck, a bitboard | `HunchCore/Sources/Glyphs` |
| The AST, a truth table, RNF folding, mask tables, the law index | `HunchCore/Sources/Laws` |
| The generator, a guardrail, `SplitMix64`, `Band`, `Difficulty`, counterexample selection | `HunchCore/Sources/LawGeneration` |
| Bench layout, rule-tile payloads, coupler, seal bar | `HunchCore/Sources/Bench` — core, because G10 is a *generation-time* guardrail and `HunchCore` cannot depend on the UI package (`08 §2`) |
| Phases and their transition function, outcome, ribbon, score, snapshots, per-mode schedules | `HunchCore/Sources/Rounds` |
| Ability, the estimator, the serving policy, calibration | `HunchCore/Sources/Ladder` |
| Codex pages, round records, profile, the anomaly ledger | `HunchCore/Sources/Archive` |
| The store protocol, the file enum, the file-backed actor, schema migration, the in-memory store | `HunchCore/Sources/Persistence` |
| A seeded corpus, an `unimplemented` double, approximate equality | `HunchCore/Sources/HunchTestSupport` — a `.target`, never a `.testTarget` (`01 P20`) |
| A route, a screen identity, the navigation graph | `Modules/Sources/HunchNavigation` — deliberately no SwiftUI, so its tests run on the host |
| A token, a `Shape`, a `Canvas`, a shared component, the localization accessor, the String Catalog | `Modules/Sources/HunchUI` — this is the design-system target, and it sits *beside* the features, not above them (`01 P7`) |
| A cue, a player, the synthesiser, haptics | `Modules/Sources/Feedback` |
| A play-surface screen, the round observable, the inspector, the inscription | `Modules/Sources/LoomFeature` |
| A Codex screen; a frame, anomaly, profile, statistics, settings or about screen | `Modules/Sources/CodexFeature`, `Modules/Sources/MetaFeature` |
| The dependency graph, the environment installer, a router, the root view | `Modules/Sources/HunchAppFeature` — the only target `App/` imports (`01 P9`) |
| `@main`, the asset catalog, the icon, entitlements, the privacy manifest | `App/` — five files, forever (`01 P8`) |
| A build setting, an xcconfig, a test plan | `Config/`, repo root — never inside `App/` (`01 P38`) |
| **Anything else** | **the target you are already in.** Move it when a second consumer appears, not before |

**Feature targets never depend on each other** (`01 P13`). `LoomFeature` reaching into `CodexFeature` is a manifest edit you should reject; the composition that needs both is `HunchAppFeature`.

## 3. The boundary predicate, in full

> A file may live in `HunchCore/` **iff** (a) it imports nothing but `Swift`/`Foundation`, and (b) its behaviour is a pure function of values you can write down in a test — no `Date()`, no `UUID()`, no `.random`, no file path, no bundle, no screen geometry. If either half fails, it belongs in `Modules/`. — `08 §2`

```bash
${CLAUDE_SKILL_DIR}/scripts/check-boundary.sh Path/To/Candidate.swift    # verdict + the failing lines
${CLAUDE_SKILL_DIR}/scripts/check-boundary.sh --all                      # audit every core file; non-zero on violation
```

**The clarification the predicate needs, and the one people get wrong: half (b) bans *ambient* sources, not parameters.**

```swift
// ✗ HunchCore. Ambient: the value cannot be written down in a test.
public func todayIndex() -> Int64 { Int64(Date().timeIntervalSince1970 / 86_400) }

// ✓ HunchCore. The same arithmetic over a value the caller supplies.
public enum Anomaly {
    /// - Complexity: O(1).
    public static func dayIndex(at instant: TimeInterval) -> Int64 { Int64(instant / 86_400) }
}
```

`FilePersistenceStore` is core for exactly this reason — its directory arrives in `init`, so a test points it at a temp directory. `Codex` is not core, because `@Observable` is a macro over a `@MainActor` class and drags Observation and main-actor isolation into a target that must stay nonisolated.

The four things that look like core logic and are app-layer, and the two that look app-layer and are core, are `08 §2`'s two tables with the failure mode each split prevents. Read them before overriding the script:

```bash
sed -n '/^## 2\. The module boundary/,/^---/p' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

**The boundary needs no lint rule.** `Modules/Package.swift` declares `.package(path: "../HunchCore")`; `HunchCore/Package.swift` declares no dependency on anything of ours. Leave the arrow out and the `import` stops compiling (`04 A3`). The script exists for half (b), which the compiler cannot see.

## 4. Which file inside the target

- **One top-level type per file; the file is named for the type** (`01 P24`, `W11`, `N45`).
- **Three exceptions, and only these** (`01 P25`): a type plus private nested helpers meaningless alone; a type plus its delegate protocol; a SwiftUI parent plus the section views it extracted purely for invalidation, when those are `private` and under ~20 lines each.
- Exception (a) is what puts `Glyph` and its four nested attribute enums in `Glyph.swift`, and `RuleTile` with its nested `Ramp`/`Bridge`/`Fork`/`Tally` payload structs in `RuleTile.swift`. It is *not* a licence to put `LawNode` and `Law` in one file — those are two top-level types with different conformances (`08 §3`), so they are two files.
- **A conformance extension on your own type stays in that type's file** unless it is large or drags in an import the type otherwise does not need; split as `Type+Protocol.swift` (`01 P26`). One conformance per extension (`W12`).
- **An extension on a foreign type always gets its own file**, `Foreign+Capability.swift`, one capability each (`01 P27`).
- **Banned filenames** (`01 P28`, checked by a CI grep): `Utils.swift`, `Utilities.swift`, `Helpers.swift`, `Constants.swift`, `Extensions.swift`, `Managers.swift`, `Common.swift`, `Shared.swift`, `*+Utilities.swift`. Add `Extension.swift` for this project — it is the name the design's terminology invites and it is both a keyword collision and a banned-grep hit (`08 §3`).
- **Never put an access level on an `extension` declaration** (`W7`, enforced by swift-format's `NoAccessLevelOnExtensionDeclaration`, on by default). It silently applies to whatever you add six months later.

## 5. Creating a target

A new target is five obligations, and the third is the one that fires the trap:

1. It is a directory under `Sources/`, and **the directory name is the module name is the `import`** — UpperCamelCase, no hyphens, no nesting (`01 P19`, `P21`).
2. It is declared in the package's `targets:` list, and every name in its `dependencies:` is itself a declared target — `swift build --package-path HunchCore` fails to *resolve* otherwise, in under a second (`01 §5b`).
3. **Its default isolation is decided in the manifest, in the same commit.** `HunchCore` targets get none; `HunchUI`, the three feature targets and `HunchAppFeature` get `.defaultIsolation(MainActor.self)`; `HunchNavigation` and `Feedback` get none (`01 P16`, `P17`, `08 §4`). `hunch-swift-concurrency` owns the reasoning; this rule owns only "it is written in the manifest, not left to default".
4. Its test target is `<Target>Tests` under `Tests/`, path-mirrored (`01 P19`, `06 T5b`).
5. If it ships a String Catalog it needs `resources:` on the target and `defaultLocalization:` on the package (`01 P35`) — only `HunchUI` does, and it holds the one catalog for the whole app.

Manifest mechanics beyond placement — upcoming-feature flags, resource declaration rules, `swiftLanguageModes` — belong to `hunch-build-and-ci`.

## 6. Where tests go

Placement only; `hunch-swift-testing` owns everything else.

| Code under test | Directory | Runner |
|---|---|---|
| Anything in a `HunchCore` target | `HunchCore/Tests/<Target>Tests/` | `swift test --package-path HunchCore` — the fast suite, no simulator |
| Anything in a `Modules` target | `Modules/Tests/<Target>Tests/` | `swift test --package-path Modules` |
| Composition, anything needing the app bundle | `HunchTests/` — stays nearly empty (`01 P22`) | `xcodebuild test` |
| UI flows, screenshots, the accessibility audit | `HunchUITests/` — must be `XCTestCase` (`06 T43`, `08 §7.10`) | `xcodebuild test` |

The whole point of the split is that the logic sits in packages, so the app's test bundle stays nearly empty and the inner loop needs no simulator boot (`01 P22`, `P23`, `08 §5`). A test you write in `HunchTests/` that could have lived in a package has cost the project its ten-second budget.

## 7. The twelve places HUNCH deviates from the guide

`08 §7` names each conflict and rules on it. One line each, so you recognise the argument when it comes up; the ruling's reasoning is in the cited section and is not repeated here.

| # | The conflict | Ruling |
|---|---|---|
| 1 | Brief's "two targets" vs an eight-file app shell and 18 screens | Read "two targets" as two build *products*; the UI lives in a package (`08 §7.1`) |
| 2 | `01 P14` "one local package" vs zero SwiftUI in the core plus a 10-second suite | Two packages, named deviation; only `P14`'s cost (a) survives (`08 §7.2`) |
| 3 | `01 P12` "don't pre-create modules" vs a design that already names every system | Boundaries are given, but create each target the day its owner section is implemented (`08 §7.3`) |
| 4 | `06 T21` "no loops in tests" vs 10,000-law suites | Parameterise over bands, loop inside, pay it back with a reproducing seed (`08 §7.4`) |
| 5 | `04 A40` JSON "under ~1000 records" vs a 27,015-page Codex | Shard into eight lazily-loaded shelves; assert the shard boundary (`08 §7.5`) |
| 6 | `04 A45` "`@Query` is the default" | Inapplicable — no SwiftData; `Codex` re-implements change notification by hand (`08 §7.6`) |
| 7 | `05 R17`'s ladder has no row for a real-time audio callback | One lock-free `VoiceBank`, one documented `@unchecked Sendable` (`08 §7.7`) |
| 8 | `04 §7` "no per-screen view models" vs the round | `A18` triggers 1 and 2 fire; ship `Round`, never `RoundViewModel` (`08 §7.8`) |
| 9 | `06`'s toolbox assumes three packages the brief bans | Clock designed out, golden fixtures by hand, five-line approximate equality (`08 §7.9`) |
| 10 | "Swift Testing, not XCTest" vs `06 T43` | UI tests stay `XCTestCase`; the brief governs new *unit* tests (`08 §7.10`) |
| 11 | `01 P34` generated symbols break `swift build` inside a package | Leave String Catalog symbol generation off; `Loc` is hand-written (`08 §7.11`) |
| 12 | `07 B18`/`B19` vs "archive builds with zero warnings" | `-warnings-as-errors` in Release; any exemption is written *before* it (`08 §7.12`) |

## 8. Not owned here

`.xcconfig`, `Package.swift` mechanics, run-script phases, the source-hygiene greps and CI → `hunch-build-and-ci`. Isolation values and `Sendable` → `hunch-swift-concurrency`. Test content → `hunch-swift-testing`. Any colour, dimension, duration or type value → `hunch-design-tokens`.
