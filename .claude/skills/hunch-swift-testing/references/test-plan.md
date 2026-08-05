# The test plan — targets, tags, plans, and the seven invariants in full

1. [The target map](#1-the-target-map)
2. [Tags — the eight, and where each package declares them](#2-tags--the-eight-and-where-each-package-declares-them)
3. [Test plans](#3-test-plans)
4. [Invariant 1 — generator guardrails at scale](#4-invariant-1--generator-guardrails-at-scale)
5. [Invariants 2 and 3 — the simulated player and calibration](#5-invariants-2-and-3--the-simulated-player-and-calibration)
6. [Invariant 4 — determinism](#6-invariant-4--determinism)
7. [Invariant 5 — localisation completeness](#7-invariant-5--localisation-completeness)
8. [Invariant 6 — persistence round-trip and migration](#8-invariant-6--persistence-round-trip-and-migration)
9. [Invariant 7 — no network](#9-invariant-7--no-network)
10. [What is deliberately not tested](#10-what-is-deliberately-not-tested)

---

## 1. The target map

`08-APPLIED-TO-HUNCH.md §1` owns the tree; this is the testing projection of it. One test target per source target, path-mirrored (`06 T5b`).

| Source target | Test target | Runs where | Why |
|---|---|---|---|
| `HunchCore/Sources/Glyphs` | `HunchCore/Tests/GlyphsTests` | host, `swift test` | pure values |
| `…/Laws` | `LawsTests` | host | pure |
| `…/LawGeneration` | `LawGenerationTests` | host | pure; owns invariants 1 and 4 |
| `…/Bench` | `BenchTests` | host | `BenchLayout` is core because G10 is a generation-time guardrail (`08 §2`) |
| `…/Rounds` | `RoundsTests` | host | `RoundPhase` transitions are a pure function `(RoundPhase, Event) -> RoundPhase` |
| `…/Ladder` | `LadderTests` | host | owns invariants 2 and 3 |
| `…/Archive` | `ArchiveTests` | host | `Anomaly` is pure over `TimeInterval`/`Int64` |
| `…/Persistence` | `PersistenceTests` | host | owns invariant 6; needs a temp dir, not a simulator |
| `Modules/Sources/HunchNavigation` | `Modules/Tests/HunchNavigationTests` | host | the target imports no SwiftUI precisely so this runs on the host |
| `…/HunchUI` | `HunchUITests` *(package)* | simulator | SwiftUI |
| `…/LoomFeature` | `LoomFeatureTests` | simulator | `@MainActor` models |
| `…/CodexFeature` | `CodexFeatureTests` | simulator | `@MainActor` models |
| — | `E03/HunchUITests/` *(Xcode)* | simulator | XCUITest, `XCTestCase` only |

**The two `HunchUITests` are different things.** `Modules/Tests/HunchUITests` is the package test target for the `HunchUI` design-system module. `E03/HunchUITests/` is the Xcode-wizard XCUITest bundle — screenshots in en/de/ar and `performAccessibilityAudit`. Rename the wizard one to `HunchScreenTests` if the collision ever costs you a minute; nothing in the brief requires the wizard's name.

**Which files decide the layer.** `08 §2` states the boundary rule as a two-part predicate, and it is what settles arguments about where a test goes: a file lives in `HunchCore` **iff** it imports nothing but `Swift`/`Foundation` **and** its behaviour is a pure function of values you can write down. Both halves are mechanical. The four things that look core and are not — the par tick row, the Assay's pinned slice, the counterexample's presentation, `Codex` — and the two that look app-layer and are core — `BenchLayout`, `RoundPhase` — are enumerated there with the failure mode each split prevents. Do not re-derive them.

## 2. Tags — the eight, and where each package declares them

The vocabulary is fixed at eight on two axes (`06 T29`, `T30`, `07 B24`). Adding a ninth is a decision, not a convenience.

```swift
// HunchCore/Sources/HunchTestSupport/Tags.swift
import Testing

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

**Declare the same eight again in `Modules/Sources/ModulesTestSupport/Tags.swift`.** `HunchTestSupport` is absent from `HunchCore`'s `products:` (`06 T5a` condition 1), so a target in the `Modules` package cannot import it — that is the deliberate cost of the two-package deviation (`08 §7.2`). `06 T29` states that tags with the same name in different modules are treated as equivalent, which is what makes the mirror correct rather than a second vocabulary: `-only-testing-tags presubmission` still selects both packages' tests. `ModulesTestSupport` is subject to the same three `T5a` conditions as `HunchTestSupport` — no product entry, named only by test targets, asserted in CI.

Do **not** reach for `static var slow: Self { integration }`. Aliasing compiles and silently does nothing at runtime (`06 T29`).

`06 T31`: a plain comment immediately above `@Test`/`@Suite` is captured and printed with recorded issues. Free context in a CI log where the source is not visible. If the comment is about a defect, use `.bug(id:)` instead.

## 3. Test plans

Three plans at the repo root, each named after the cadence tag it filters on, so keeping them in sync is mechanical rather than a promise (`06 T30`, `07 B24`).

| Plan | Include tag | Contents | Where it runs |
|---|---|---|---|
| `Presubmission.xctestplan` | `.presubmission` | invariants 1, 2A, 4, 6; every unit suite | ⌘U and every PR |
| `Nightly.xctestplan` | `.nightly` | invariants 2B and 3, the Bench fuzzer, the accessibility audit | scheduled |
| `Prerelease.xctestplan` | `.prerelease` | XCUITest screenshots en/de/ar, the full Level-B matrix | before any archive |

Set Execution Order to **Random** in at least one configuration (`06 T61`, `07 B25`). Alphabetical order hides inter-test dependence until the day it does not.

The fast local loop is not a plan at all — it is `swift test --package-path HunchCore`, which boots nothing. Reach for the `Presubmission` plan when you need the `Modules` package or the app target in the run.

## 4. Invariant 1 — generator guardrails at scale

`LawGenerationTests/GeneratorTests.swift`. The shape and the `06 T21` deviation are in SKILL.md; this is what the loop asserts, taken from the brief's own wording:

- every law is **satisfiable** and **falsifiable** by at least one glyph in the deck — `table.isSatisfiable`, `table.isFalsifiable`;
- no law is trivially always-true or always-false — the same two, plus `band.admitWindow.contains(table.admitRate)`;
- no two structurally identical laws are emitted as different — compare `law.renderedNormalForm`, which is what RNF exists for; collect the RNFs of a band into a `Set` and assert the count matches after accounting for deliberate reprises;
- the declaration UI can express every generated law — **G10**, `LawNode(BenchLayout(law)) == law.renderedNormalForm`, one line in both directions because `08 §3` gave the conversion `init`s value-preserving labels (`N14`).

`Corpora.lawsPerBand` and `Corpora.seed(band:index:)` live in `HunchTestSupport`; they are the authoritative home of the count and the seed derivation. Do not write `10_000` into a test.

The 200,000-configuration Bench fuzzer (the backward direction: `BenchLayout` → `LawNode` → `BenchLayout`) is the same pattern with the same seed-reporting discipline, and it moves to `.nightly` the moment it measures over ~1 s.

## 5. Invariants 2 and 3 — the simulated player and calibration

Two levels, and the split is what keeps the budget.

**Level A — `ResponseHarness`.** A synthetic player whose response to a served law is a function of `(ability, difficulty)` only: no reasoning, one arithmetic step per round. `08 §5` cites the design's budget of 10⁶ rounds in under 0.4 s. It carries invariant 2's three assertions:

- the estimator **converges** to the tunable ability within N rounds — assert `|estimate − truth|` falls below a stated tolerance, using `isApproximatelyEqual` from `HunchTestSupport`, never `==` on a `Double`;
- the served difficulty **holds the ~80 % success target** in steady state;
- the player is **never trapped in a loss loop** — over a long run, no window of K consecutive rounds is all losses. This is the assertion people forget, and it is the one that catches a serving policy that has stopped adapting.

Tags `.unit .presubmission`. It is a unit test despite the round count, because it touches nothing outside `Ladder` and runs in milliseconds.

**Level B — `ReasonerHarness`.** A player that actually induces, so a round costs real work. This carries invariant 3: `difficulty(of:)` must correlate with the observed failure rate, Spearman ρ ≥ 0.75. Gated declaratively (`06 §18` play 7):

```swift
@Suite("Difficulty calibration",
       .tags(.integration, .nightly),
       .enabled(if: ProcessInfo.processInfo.environment["HUNCH_CALIBRATION"] == "1"),
       .timeLimit(.minutes(15)))
struct DifficultyCalibrationTests { … }
```

`.timeLimit` is a hang guard, not a performance assertion (`06 T26`) — `.minutes` is the only factory. The full matrix (640 k rounds, ~9 min) runs nightly and as a hard gate before any archive. A smoke subset of roughly 0.8 s stays in the fast suite so the harness itself cannot rot. **It is not deleted** (`06 T58`): a slow test that runs nightly still catches the regression.

If ρ comes in under threshold, fix `difficulty(of:)`. The brief is explicit — do not fix the test.

## 6. Invariant 4 — determinism

Owned by `references/determinism.md` in full. The summary: same-process comparison in `LawGenerationTests`, a committed golden fixture at `LawGenerationTests/Fixtures/determinism-seeds-v1.json` for the cross-process claim, and a macOS-only exit test as the cheap second opinion.

## 7. Invariant 5 — localisation completeness

**This is not a package test and cannot be made one.** A String Catalog is compiled into `.lproj` directories at build time; `Localizable.xcstrings` is a repo-relative source file that no test bundle contains. It is check 8 of `Scripts/check-source-hygiene.sh` (`07 B34a` extended per `08 §5`): ≤ 250 keys, zero entries in state `new` or `needsReview` across all 12 locales, zero duplicate keys, zero per-locale banned lexemes.

Check 7 is its sibling and has the same nature: no `Text`, `Label` or `AttributedString` outside `.accessibility*` modifiers in the six play-surface files — the zero-text-on-the-play-surface rule, enforced as a source lint because the rule is about source, not runtime.

The build skill owns the script's placement in CI. This skill owns the fact that you must not try to write these as `@Test` functions, and the reason.

## 8. Invariant 6 — persistence round-trip and migration

`PersistenceTests`, backed by `Fixtures/v1/` — a whole `Application Support/Hunch/` tree declared `resources: [.copy("Fixtures")]`, so every lookup passes `subdirectory: "Fixtures"` (`06 T54`; see `references/doubles-and-fixtures.md` for the accessor). A `TestScoping` trait copies the tree into a fresh temp directory per test and removes it after — no `deinit`, no shared path (`06 T20`).

Three assertions:

1. **v1 loads green under the current schema, forever.** The fixture must have been produced by a shipped binary, not by current code (`06 T56`). One fixture directory per shipped schema version, kept forever.
2. **Each of the five reset actions leaves exactly the specified file set**, with `anomaly.json` and `anomaly.hw` byte-identical across a reset that is not supposed to touch them. `StoreFile` is an exhaustive `enum` with no `default:` (`08 §3`), so adding a file to the tree is a compile error in the reset map — the test then only has to check the behaviour, not the enumeration.
3. **A round-trip of every `StoreFile` case, each with a malformed sibling** (`06 T55`). A truncated `codex-b4.json` must quarantine and rebuild, not crash — assert the specific typed error and the resulting `StoreHealth`, not merely that something threw.

Save → kill → relaunch → identical state is invariant 6's headline in the brief; in the package it is a round-trip through `FilePersistenceStore` against a real temp directory, because that actor is what a relaunch exercises.

## 9. Invariant 7 — no network

An Xcode run-script build phase **and** CI grep, never a test: `URLSession`, `Network`, `CFNetwork`, `NWConnection` appear nowhere in the repo. `08 §5` check 5. A runtime assertion would only prove the code path you exercised did not call out; the grep proves the symbols are absent from the source.

Its companion is check 6, which is the determinism guard rather than the network one: no `SystemRandomNumberGenerator`, `.random(`, `Date()` or `UUID()` under `HunchCore/Sources/`. See `references/determinism.md` §5.

## 10. What is deliberately not tested

`06 §21` is the general list. The HUNCH-specific applications, each of which someone will otherwise write:

- **`View` bodies.** No ViewInspector — it is banned as a dependency anyway, and `06 §21.3` refuses it on merits. Test the `@Observable` model; the visual regression corpus is the DEBUG snapshot gallery, not a test target.
- **Token values.** `check-tokens.swift` in the design-tokens skill owns the palette/Swift/canon three-way divergence check. Do not write a Swift Testing suite that re-asserts hexes; you would be creating the second copy the whole anti-drift scheme exists to prevent.
- **Localised copy.** Assert the key, never the translation (`06 §21.9`). In HUNCH the play surface has no strings at all, so the only assertions available are structural — which is what check 8 does.
- **Mode wordmarks.** `Text(verbatim: mode.wordmark)` is deliberately not extracted (`08 §3`). A test asserting the wordmark string is a change-detector on a constant.
- **Trivial delegation and synthesised conformances.** `Glyph`'s memberwise init, `Codable` synthesis with no custom keys, `Deck.glyph(id:)` as a subscript alias.
