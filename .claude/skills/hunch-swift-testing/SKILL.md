---
name: hunch-swift-testing
description: "Writes HUNCH's tests in Swift Testing — the seven brief invariants and where each lives, seeded corpora and golden fixtures for cross-process determinism, tags and test plans, hand-written doubles, and the ten-second fast-suite budget with what is gated to nightly. Use when writing or repairing a test or an XCTest/XCUITest bundle, when a suite is slow or flaky, or when deciding whether something is testable without a simulator. Not for the CI workflow that runs the suite — see the build skill."
allowed-tools: Read, Grep, Glob, Bash(swift:*), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "the seven brief invariants and their homes, the T21 deviation, cross-process determinism, the eight tags, the ten-second budget"
---

## Step 0 — read the test targets and tags as they exist right now

**Before anything else, run `bash ${CLAUDE_SKILL_DIR}/scripts/current-state.sh`.** It lists the test
targets that exist and the `@Tag` vocabulary each package actually declares.

**Trust that listing over anything written below it.** A tag that is not in it cannot be used, and a
target that is not in it has to be added to the manifest before a file can go in it.

## To write a test

1. **Decide the layer before the assertion.** If the behaviour is a pure function of values you can write down, it belongs in `HunchCore` and runs on the host with no simulator (`06 T3`, `08 §2`'s boundary rule). If it needs screen geometry, a bundle, a date or SwiftUI, it belongs in `Modules/` — and if it needs `XCUIApplication`, it is `XCTestCase` in `HunchUITests/`, not `@Test` (`06 T43`, `08 §7.10`).
2. **Place the file by mirroring the source path** (`06 T5b`). `HunchCore/Sources/LawGeneration/Generator.swift` → `HunchCore/Tests/LawGenerationTests/GeneratorTests.swift`. One suite per file, file named for the suite.
3. **Tag on both axes** (`06 T30`): kind `.unit .integration .snapshot .ui .performance`, cadence `.presubmission .nightly .prerelease`. Put them on the `@Suite`; contained tests inherit. There is no `.smoke`.
4. **Inject, never reach.** The RNG is a `SplitMix64` parameter threaded down one synchronous call tree (`08 §4`); the store is a `PersistenceStore`; time is `Now`. Nothing else is substitutable, because nothing else is nondeterministic.
5. **Update `tests.json`** at the repo root — the brief mandates a structured list of every invariant with its status. Never delete or weaken an entry to reach green.

## The seven brief invariants — where each one lives

| # | Invariant | Kind | Home | Tags |
|---|---|---|---|---|
| 1 | Generator guardrails, `Corpora.lawsPerBand` laws × every `Band` | seeded-corpus invariant suite | `LawGenerationTests/GeneratorTests.swift` | `.unit .presubmission` |
| 2 | Simulated player: convergence, ~80 % target, no loss loop | `ResponseHarness` (Level A) fast; `ReasonerHarness` (Level B) gated | `LadderTests/` | A `.unit .presubmission` · B `.integration .nightly` |
| 3 | `difficulty(of:)` correlates with observed failure rate | Level-B statistic | `LadderTests/` | `.integration .nightly` |
| 4 | Determinism across runs **and processes** | same-process comparison + committed golden fixture + macOS exit test | `LawGenerationTests/` | `.unit .presubmission` |
| 5 | Localization completeness, ≤ 250 keys, banned lexemes | **`Scripts/` source lint, not a package test** | `Scripts/check-source-hygiene.sh` check 8 | — |
| 6 | Persistence round-trip and v1 migration | fixture tree + `TestScoping` trait | `PersistenceTests/` | `.unit .presubmission` |
| 7 | No network anywhere | **build phase + CI grep, not a test** | `Scripts/` + Xcode | — |

Full detail, including the Level A/B split and what each assertion actually is, in `references/test-plan.md`.

## The deliberate T21 deviation — read before parameterising anything large

`06 T21` says a `for` loop inside a test is a bug. HUNCH breaks it once, on purpose (`08 §7.4`): parameterising the generator suite would mean `arguments: Band.allCases, 0..<Corpora.lawsPerBand`, and `06 T22`'s Cartesian product is then tens of thousands of runner nodes that cost more than the assertions. **Parameterise over the bands, loop the laws inside, and pay `T21`'s protection back in full — a reproducing seed in the message and an `Attachment` of the offending AST in every failure.**

```swift
// HunchCore/Tests/LawGenerationTests/GeneratorTests.swift
import Foundation                              // Attachment needs it — see Gotchas
import Testing
import Bench
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Generator guardrails", .tags(.unit, .presubmission))
struct GeneratorTests {
    @Test("Every guardrail holds across the band", arguments: Band.allCases)
    func guardrailsHold(_ band: Band) throws {
        for index in 0..<Corpora.lawsPerBand {
            let seed = Corpora.seed(band: band, index: index)
            let law = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
            let table = LawTable(law)

            let failure: String? =
                if !table.isSatisfiable { "unsatisfiable" }
                else if !table.isFalsifiable { "unfalsifiable" }
                else if !band.admitWindow.contains(table.admitRate) { "admit rate \(table.admitRate)" }
                else if LawNode(BenchLayout(law)) != law.renderedNormalForm { "G10: Bench cannot express it" }
                else { nil }

            guard let failure else { continue }
            Attachment.record(law, named: "band\(band.rawValue)-index\(index).json")   // 06 T18a
            Issue.record("\(failure) — reproduce with Corpora.seed(band: .\(band), index: \(index))")
            return                              // one named seed is enough; promote it, then re-run
        }
    }
}
```

Then **promote every failure into a permanent case** — `@Test(arguments: Corpora.knownBadSeeds)` with a `Codable` argument type so one case re-runs alone (`06 T23`, `06 T53`). That promotion is the whole compensation for having no shrinker, and skipping it turns a found bug into a bug you will find again. The 200,000-configuration Bench fuzzer gets the same treatment and moves to `.nightly` the moment it measures over ~1 s.

## The ten-second budget

`swift test --package-path HunchCore` is the fast suite and it must finish **under 10 seconds** — the brief's number, and the stated reason the two-target split exists. Four rules hold it (`08 §5`): the fast suite never boots a simulator; Level B's full matrix is `.enabled(if:)`-gated to nightly rather than deleted (`06 T58`); `Corpora.index` is built once as a `static let`; and **CI times the run and fails over budget**, because a budget nobody measures has already been spent. The timer and the nightly gate are in `references/budget.md`; the workflow that hosts them belongs to the build skill.

## Where the detail lives

| Read this | When |
|---|---|
| `references/test-plan.md` | choosing a home or a tag for a new test, wiring a test plan, or working on any of the seven invariants |
| `references/swift-testing-mechanics.md` | writing the test body — `#expect`/`#require`, traits, parameterisation, helpers, known issues, exit tests, the XCTest boundary |
| `references/determinism.md` | anything involving a seed, an RNG, a golden fixture, `Now`, or a comparison that must hold across processes |
| `references/budget.md` | the suite is slow, a test is flaky, or you are deciding what to gate to nightly |
| `references/doubles-and-fixtures.md` | building a fake, a corpus, or a fixture tree — and before adding a target to either `Package.swift` |

## Gotchas

- **`resources: [.copy("Fixtures")]` means every lookup passes `subdirectory: "Fixtures"`.** `.copy` preserves the directory; a bare `#bundle.url(forResource:withExtension:)` returns `nil` and every `#require` in the suite fails at once. This is where fixture suites die (`06 T54`, `07 B22`). `.process` flattens and is the reverse — HUNCH uses `.copy`.
- **The tag vocabulary is declared once per *package*, not once per repo.** `HunchTestSupport` is deliberately absent from `products:` (`06 T5a`), so `Modules/` cannot import it. Mirror the eight `@Tag static var` declarations into a `ModulesTestSupport` target. This is correct, not duplication: `06 T29` treats same-named tags in different modules as equivalent, which is exactly what keeps `-only-testing-tags presubmission` selecting both packages.
- **`Attachment.record` on a `Codable` value needs `import Foundation` in that file.** The `Attachable` conformance for `Encodable` comes from Foundation; without it the call does not compile and the tempting fix is to `print` instead, which loses the artefact on CI.
- **`.defaultIsolation(MainActor.self)` on a `Modules/` UI target does not reach its test target.** A `LoomFeatureTests` suite constructing `Round`, `Codex`, `Ladder` or `Router` writes `@Test @MainActor` explicitly, or it races (`06 T9`). `HunchCore` targets have no default isolation at all, so core tests are correctly nonisolated and need nothing.
- **`Corpora.index` is a `static let` of an immutable `Sendable` value — the one sanctioned piece of shared state.** Tests run parallel in one process (`06 T10`), so a `static var` anywhere in `HunchTestSupport` is a data race, not an ordering hazard.
- **There is no `Clock` abstraction in this project and you should not add one.** `08 §5` designed the timing out: no wall-clock quantity affects score, marks or the Rasch update. `Now` is the only injected time source, and SIEVE's timing is a pure `SieveSchedule` plus one `ContinuousClock.sleep` at the view edge.
- **Invariants 5 and 7 are source lints, not tests, and no amount of trying will make them tests.** A String Catalog is compiled to `.lproj` at build time and the play-surface `Text` ban is repo-relative — neither artefact exists inside a test bundle (`08 §5`).
- **`#_sourceLocation`, with the underscore.** The unprefixed `#sourceLocation` is the compiler's line-control directive; the underscored macro is the public one (`06 T17`). Every helper that records an issue forwards it or the failure points at the helper.

## Never

- Never take a testing dependency. `swift-clocks`, `swift-snapshot-testing`, `swift-numerics`, `swift-dependencies`, SwiftCheck and every mocking framework are banned by the brief (`08 §7.9`, `06 T36`, `06 T52`). `isApproximatelyEqual(_:_:absoluteTolerance:)` is five hand-written lines in `HunchTestSupport`, written **before** the first `#expect` compares two `Double`s.
- Never `import Testing` from a shipping target, and never let a non-test target name `HunchTestSupport` (`06 T5`, `T5a`). `InMemoryPersistenceStore` ships and imports no `Testing`; the `Issue.record`ing `unimplemented` doubles do not ship. CI asserts it against the manifest, not against your memory.
- Never assert a golden *order* out of the RNG. Assert the invariant — permutation, round-trip, admit-rate window — and reserve byte-for-byte comparison for the determinism fixture, where identity is the property under test (`06 T42`).
- Never `Task.sleep` in a test, never poll then assert, never add `.serialized` to fix a flake (`06 T27`, `T57`). `.serialized` fixing something means you found shared mutable state; go delete the state.
- Never add a blanket CI retry, and never quarantine a flake by commenting it out. `withKnownIssue(isIntermittent: true)` plus `.bug(id:)` keeps it visible and attributable (`06 T35`, `T63`).
- Never use `@testable import`. Plain `import` (`06 T4`) — every `HunchCore` type the tests need is already `public` because `Modules/` consumes it across a package boundary.
- Never write a fixture by hand where a recorded one is possible, and never ship a decoding fixture without a malformed sibling asserting a specific typed error (`06 T55`).
- Never restate a value that lives in Swift. Cite `Corpora.lawsPerBand`, `band.admitWindow`, `Band.allCases.count` — not the numbers. If it can be read in one tool call, write the tool call.
