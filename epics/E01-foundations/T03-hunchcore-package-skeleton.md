# T03 — `HunchCore` package skeleton

| | |
|---|---|
| **Epic** | E01 — Foundations, bootstrap and CI |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Fast loop (§14.1 VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | It owns the boundary predicate that decides what may live in `HunchCore` at all, the target routing table, and the banned filenames. Run `scripts/check-boundary.sh --all` from it rather than eyeballing imports. |
| `hunch-build-and-ci` | `references/package-manifests.md` §2 is the authoritative `HunchCore/Package.swift`; §4 is the checklist for adding a target; §5 rules the platform floors and says why `.macOS(.v15)` is not decoration. |
| `hunch-swift-concurrency` | The one thing that must be *absent* here: no `.defaultIsolation` on any `HunchCore` target. This skill owns default isolation per target and reads it back in its own step-0 listing. |
| `hunch-swift-testing` | `references/test-plan.md` §2 owns the eight-tag vocabulary this task declares, and §1 owns the one-test-target-per-source-target mirroring. |

## Objective

`HunchCore/` becomes a Swift 6 package that builds and tests on the **host** with no simulator, carrying `HunchTestSupport` as a `.target` that is absent from `products:` and the eight-tag vocabulary every later suite is filtered by. From this commit onward `swift test --package-path HunchCore` is the inner loop and the thing CI times.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §7.2 | The `HunchCore/` tree; the boundary rule as a two-part predicate; why two packages exist and what the deviation costs (`package` access does not cross the boundary). |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | `P12`, `P14`, `P17`, `P18`, `P19`, `P20`, `P21`, `P22`, `P23`, `P28` | Create a target the day its owner section is implemented; one package unless ruled otherwise; isolation per target; `swiftLanguageModes` agreeing with `SWIFT_VERSION`; directory name = module name; `TestSupport` is a `.target`; flat `Sources/`; banned filenames. |
| `ios-swift-guide/06-TESTING.md` | `T5`, `T5a`, `T5b`, `T10`, `T29`, `T30` | `import Testing` must never reach a shipping target; the three mechanical conditions that make a `.target` importing `Testing` safe; path-mirrored test targets; parallel-in-one-process execution; tag declaration rules. |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B20`, `B21`, `B22` | No `unsafeFlags`; `.defaultIsolation` needs tools 6.2+; `#bundle` needs a `platforms:` floor. |
| `hunch-build-and-ci` | `references/package-manifests.md` §2 | The manifest to paste from. Read §2's note that *the target list is a ceiling, not a schedule*. |
| `GAME_DESIGN.md` | §5.7 | The 10-second `swift test` budget this package structure exists to buy. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/HunchTestSupportTests/TagVocabularyTests.swift`:

```swift
import Testing
import HunchTestSupport

/// The eight tags are the whole vocabulary (06 T30) and adding a ninth is a decision, not a
/// convenience. This suite exists because a tag that is never declared is a COMPILE error in a
/// test but a silent nothing in a test plan: a plan whose include-tag names something nobody
/// declared selects zero tests and reports a green run over them (07 B24).
@Suite("Tag vocabulary", .tags(.unit, .presubmission))
struct TagVocabularyTests {
    @Test("The five kind tags are declared and pairwise distinct")
    func kindTagsAreDistinct() {
        let kinds: Set<Tag> = [.unit, .integration, .snapshot, .ui, .performance]
        #expect(kinds.count == 5)
    }

    @Test("The three cadence tags are declared and pairwise distinct")
    func cadenceTagsAreDistinct() {
        let cadences: Set<Tag> = [.presubmission, .nightly, .prerelease]
        #expect(cadences.count == 3)
    }

    @Test("Kind and cadence are two axes, not one list")
    func theTwoAxesDoNotOverlap() {
        let kinds: Set<Tag> = [.unit, .integration, .snapshot, .ui, .performance]
        let cadences: Set<Tag> = [.presubmission, .nightly, .prerelease]
        #expect(kinds.isDisjoint(with: cadences))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter TagVocabularyTests`

It fails to compile — `error: no such module 'HunchTestSupport'`, then once the target exists, `error: type 'Tag' has no member 'presubmission'`. Both are the right reason: the symbol is missing. Note that `06 T29`'s point is exactly this — a tag declared anywhere other than an extension of `Tag` is a compile error, and an *alias* (`static var slow: Self { integration }`) compiles and silently does nothing at runtime, so never write one.

**Step 3 — implement** the manifest, the directories and `Tags.swift`.

**Step 4 — green, then refactor.** Then run the three structural queries in the acceptance criteria; they are what stop `HunchTestSupport` from leaking into the app.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Package.swift` |
| create | `HunchCore/Sources/HunchTestSupport/Tags.swift` |
| create | `HunchCore/Tests/HunchTestSupportTests/TagVocabularyTests.swift` |
| modify | `Hunch.xcodeproj` — register `HunchCore/` as a local package (navigator only; **not** linked) |

## Implementation notes

### The manifest

Paste from `hunch-build-and-ci/references/package-manifests.md` §2 and then **delete the target rows this epic does not fill**. That reference says so in as many words: *"The target list is a ceiling, not a schedule. `01 P12` and `08 §7.3` both say create a target the day its owner section is implemented. Delete the rows you have not built rather than shipping empty directories."*

This is not a theoretical preference. Verified on Swift 6.3.3, a target whose `Sources/<Target>/` directory is empty produces:

```text
warning: 'hunchcore': Source files for target Glyphs should be located under 'Sources/Glyphs' …
error:   'hunchcore': target 'Glyphs' referenced in product 'HunchCore' is empty
```

— a warning if it is only declared, a hard **error** the moment it appears in `products:`. Eight declared targets on day one is eight warnings and a broken build; the plan's phrase "the eight source targets" describes the shape, and the shape is recorded as a comment.

```swift
// swift-tools-version: 6.2
import PackageDescription

// Applied to every target and test target. There is NO .defaultIsolation anywhere in this
// package: 01 P17 and 05 R7 put pure-domain modules on the nonisolated default, and 08 §4 makes
// it explicit — nothing here touches the main actor and nothing here is a class.
let coreSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),           // 03 W43 names the price
    .enableUpcomingFeature("MemberImportVisibility"),   // 07 B7b names the price
    .enableUpcomingFeature("InternalImportsByDefault"), // 07 B7a names the price
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
//   LawGeneration  E01→E06  ["Laws", "Bench"]      SplitMix64 (T05), Band, Difficulty, Generator, Guardrail
//   Rounds         E07  ["Laws", "Bench"]          RoundPhase, Outcome, Ribbon, Score, RoundSnapshot
//   Ladder         E11  ["Rounds"]                 Ability, AbilityEstimator, ServingPolicy, Calibration
//   Archive        E16  ["Laws", "Rounds"]         CodexPage, RoundRecord, Profile, AnomalyLedger, Anomaly
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
    swiftLanguageModes: [.v6]   // 01 P18 — redundant at tools 6.2, but it states the intent and
)                               // it is the half of the pair Config/Base.xcconfig's 6.0 agrees with
```

Three notes on that manifest:

- **`products: []` is legal and correct here.** A library product listing zero targets is not. The `HunchCore` library is created in T05, when `LawGeneration` gets its first file.
- **`HunchTestSupportTests` is not in `package-manifests.md` §2's list, and it belongs.** `06 T5b` asks for one test target per source target, path-mirrored, and `isApproximatelyEqual` (T04) is the helper every floating-point assertion in the project routes through — an untested comparison helper is a silent falsifier of every test that uses it. Add the row; note it in the commit message.
- **No `unsafeFlags`, ever** (`07 B20`), and no dependencies of any kind. Zero third-party packages is a brief constraint, and it is why there is no `Package.resolved` to cache and no cache step in the workflow (T07).

### The directories

```bash
mkdir -p HunchCore/Sources/HunchTestSupport HunchCore/Tests/HunchTestSupportTests
```

`P19`: the directory name under `Sources/` **is** the module name **is** the `import` statement — UpperCamelCase, no hyphens. `P21`: keep `Sources/` flat, one directory per module, no nesting. `P28`: no file in this package may ever be named `Utils.swift`, `Helpers.swift`, `Constants.swift`, `Extensions.swift`, `Managers.swift`, `Common.swift`, `Shared.swift` or `*+Utilities.swift`; check 1 of the hygiene script (T06) enforces it.

### `Tags.swift`

```swift
// HunchCore/Sources/HunchTestSupport/Tags.swift
public import Testing

// The vocabulary is fixed at eight on two axes (06 T29, T30, 07 B24). It is declared once per
// PACKAGE, not once per repo: HunchTestSupport is absent from products: by design, so the
// Modules package gets its own copy (E03·T06) and the Xcode HunchTests target a third
// (E01·T02). 06 T29 treats same-named tags in different modules as equivalent, which is what
// keeps one include-tag filter selecting all three.
extension Tag {
    // Kind — what the test is.
    @Tag public static var unit: Self
    @Tag public static var integration: Self
    @Tag public static var snapshot: Self
    @Tag public static var ui: Self
    @Tag public static var performance: Self

    // Cadence — when you can afford to run it.
    @Tag public static var presubmission: Self
    @Tag public static var nightly: Self
    @Tag public static var prerelease: Self
}
```

**`public import Testing`, not a bare `import`.** Under `InternalImportsByDefault` an undecorated import is `internal`, and an import must be at least as visible as the most visible declaration exposing a type from it (`07 B7a`). These `static var`s are `public` and their type is `Tag`, so the import is `public`. A bare `import` here produces *"cannot be declared public because its type uses an internal type"* pointing at the declaration, with nothing visibly wrong there. Verified on Swift 6.3.3.

### Registering the package with Xcode

Drag `HunchCore/` into the project navigator. That *registers* the package so Xcode resolves and indexes it. **Do not** add it under the app target's Frameworks, Libraries and Embedded Content: nothing imports it yet, and the app will only ever link `HunchAppFeature` (`01 P9`, `08 §6`). If `Hunch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` appears, commit it — `.gitignore` already whitelists that path (`01 P45`, T01).

Then re-run `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj`. Adding a package reference must not have introduced a build setting; if it did, Xcode wrote it and you remove it.

## Acceptance criteria

- [ ] `swift build --package-path HunchCore` succeeds with **zero warnings** — in particular no `Source files for target … should be located under` line.
- [ ] `swift test --package-path HunchCore --filter TagVocabularyTests` is green with 3 tests.
- [ ] `swift package describe --package-path HunchCore --type json | jq -r '[ .products[] | select(.targets | index("HunchTestSupport")) | "product \(.name)" ] + [ .targets[] | select(.type != "test") | select((.target_dependencies // []) | index("HunchTestSupport")) | "target \(.name)" ] | .[]'` prints **nothing** (this is check 4 of T06's script, run early).
- [ ] `grep -c 'defaultIsolation' HunchCore/Package.swift` is `0`, and `grep -c 'unsafeFlags\|dependencies: \[.package' HunchCore/Package.swift` is `0`.
- [ ] `swift package describe --package-path HunchCore --type json | jq -r '.targets[] | select(.type=="library") | .name'` and `… select(.type=="test") | .name'` show a **one-to-one, name-mirrored** pairing (`06 T5b`).
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` exits 0.
- [ ] `grep -rn 'import ' HunchCore/Sources` shows only `Swift`, `Foundation` and `Testing` (the last only inside `HunchTestSupport`) — the boundary rule's half (a), `08 §2`.
- [ ] `Scripts/check-pbxproj-clean.sh Hunch.xcodeproj` still prints `pbxproj clean`.

## Close the task

1. `swift test --package-path HunchCore` green. Time it once for the record — at three tests it should be well under a second; the 10-second budget starts being interesting around E05.
2. **Run `/simplify`** — the manifest is the diff. Do not let it delete the target-ceiling comment: that comment is the schedule, and deleting it is how the tree gets re-derived wrongly two epics from now.
3. **Run `/code-review`** — the findings that matter are an accidental `.defaultIsolation`, a `HunchTestSupport` entry in `products:`, and a missing `public` on the `import Testing`.
4. Commit: `git commit -m "E01/T03: HunchCore package, HunchTestSupport and the eight-tag vocabulary"`

## Out of scope

- **`SplitMix64` and the `LawGeneration` target** — T05, which also adds the `HunchCore` library product.
- **`isApproximatelyEqual`, the `unimplemented` doubles and `Corpora`** — T04.
- **`Corpora.index` (the `LawIndex` static let)** — E05·T07. It is the corpus build that the ten-second budget is actually spent on, and it cannot exist before `LawIndex` does.
- **`Fixture` and any `resources: [.copy("Fixtures")]` row** — E06·T10 (`determinism-seeds-v1.json`) and E07·T05 (`Fixtures/v1/`) add theirs with the fixtures themselves.
- **The `Modules` package, `ModulesTestSupport` and its mirrored tags** — E03·T06.
- **The `Tokens` target** — E03·T01, and it is what finally lets checks 9 and 10 fail.
- **Any `.executableTarget`** — E06·T10's fixture-producing tool. No test target may depend on it, so it costs the fast loop nothing.
