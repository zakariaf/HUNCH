# Determinism — asserting it, and the traps that make it look asserted

1. [The rule: determinism is a scoping problem](#1-the-rule-determinism-is-a-scoping-problem)
2. [Seed derivation](#2-seed-derivation)
3. [Same-process determinism](#3-same-process-determinism)
4. [Cross-process determinism — the golden fixture](#4-cross-process-determinism--the-golden-fixture)
5. [The exit test, as a second opinion](#5-the-exit-test-as-a-second-opinion)
6. [The banned-symbol greps](#6-the-banned-symbol-greps)
7. [Time — there is no `Clock` in this project](#7-time--there-is-no-clock-in-this-project)
8. [The Anomaly](#8-the-anomaly)
9. [Invariants, not golden orders](#9-invariants-not-golden-orders)

---

## 1. The rule: determinism is a scoping problem

`08 §4` settles what looks like a concurrency problem: **the generator never lets an RNG escape one synchronous call tree.** `SplitMix64` is a struct of one `UInt64`, trivially `Sendable`; `generate` constructs one as a local `var` and threads `&rng` down; `generate` is synchronous and `nonisolated`, so `05 R13`'s "bare `nonisolated async` runs on the caller's actor" trap cannot fire.

Five consequences you test against rather than re-derive:

1. Randomness is a **parameter**, never an ambient — `using rng: inout some RandomNumberGenerator` (`N15`'s preposition row, matching `shuffled(using:)`).
2. No RNG is ever stored in an `@Observable` class; state would then depend on how many times SwiftUI evaluated a body.
3. `SystemRandomNumberGenerator`, `.random(`, `Date()` and `UUID()` are banned from `HunchCore/Sources/` by CI grep (§6).
4. The only legal source of nondeterminism in the whole app is `SeedSource`, which lives in `Modules/Sources/HunchAppFeature` and is one line wide (`08 §6`).
5. Therefore a test never needs to "control randomness". It passes a seed.

```swift
// ❌ untestable, and check 6 fails the build
let law = generate(band: .relational, targetDelta: 0.5, mode: .probe)   // seeds itself internally

// ✅ the seed is an argument, so the failure is reproducible from the message alone
let law = generate(seed: seed, band: .relational, targetDelta: 0.5, mode: .probe)
```

## 2. Seed derivation

`Corpora` in `HunchTestSupport` owns the derivation, so a corpus is reproducible from `(band, index)` and nothing else:

```swift
// HunchCore/Sources/HunchTestSupport/Corpora.swift
import Glyphs
import LawGeneration
import Laws

public enum Corpora {
    /// The brief's invariant-1 count. The single authoritative home; tests cite this, never a literal.
    public static let lawsPerBand = 10_000

    /// Reproducible from `(band, index)` alone, so a failure message is a complete repro.
    public static func seed(band: Band, index: Int) -> UInt64 {
        var rng = SplitMix64(seed: 0xC0FF_EE00_0000_0000 ^ UInt64(band.rawValue))
        for _ in 0..<index { _ = rng.next() }
        return rng.next()
    }

    /// Built once for the whole suite. A `let` of an immutable Sendable value is the one
    /// sanctioned piece of shared state under parallel-in-one-process execution (06 T10).
    public static let index: LawIndex = LawIndex.rebuild()
}
```

`static let`, never `static var`. A `static var` in `HunchTestSupport` is a data race across every parallel test in the process, not merely an ordering hazard.

The stepped-`next()` derivation above is O(index) per call and that is fine at these counts; if it ever measures, replace it with a mix of `(band, index)` inside `Corpora` — the tests do not change, because they only ever say `Corpora.seed(band:index:)`.

## 3. Same-process determinism

The cheap half of invariant 4. Generate twice from the same tuple, compare the resolved table bit-for-bit.

```swift
@Test("The same tuple produces the same law within a process",
      arguments: Band.allCases)
func generationIsReproducible(_ band: Band) throws {
    for index in 0..<64 {
        let seed = Corpora.seed(band: band, index: index)
        let first = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
        let second = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
        guard LawTable(first) != LawTable(second) else { continue }
        Issue.record("nondeterministic at band \(band) index \(index)")
        return
    }
}
```

Compare `LawTable`, not `LawNode`, and not a description string: the table is the *meaning*, and two structurally different nodes that resolve to the same table are the same law by construction (that is what RNF is for). Comparing rendered text would pass on a formatter change and fail on a whitespace change — both wrong.

## 4. Cross-process determinism — the golden fixture

The brief asks for byte-identical output "across runs **and across processes**". Re-running in a child process proves less than it sounds: the child is the same binary, built by the same compiler, on the same machine, the same minute. **The claim worth asserting is against bytes written by a different process on a different day**, and the mechanism is a committed golden fixture.

`HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json` maps 512 `(seed, band, targetDelta, mode)` tuples to the resulting law key. It is produced by a separate executable and **committed**, so every subsequent run compares against a foreign artefact.

```swift
// HunchCore/Tests/LawGenerationTests/DeterminismFixtureTests.swift
import Foundation
import Testing
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Cross-process determinism", .tags(.unit, .presubmission))
struct DeterminismFixtureTests {
    struct Case: Codable, Sendable {
        let seed: UInt64
        let band: Band
        let targetDeltaBits: UInt64        // bit pattern, not the Double — see the gotcha below
        let mode: Mode
        let lawKey: UInt64
    }

    static let cases: [Case] = {
        // Force-try in a static is acceptable here: a missing fixture is a broken checkout,
        // and failing at load is clearer than 512 identical #require failures.
        let data = try! Fixture.data("determinism-seeds-v1", in: #bundle)
        return try! JSONDecoder().decode([Case].self, from: data)
    }()

    @Test("Every committed tuple still produces its recorded law", arguments: Self.cases)
    func matchesTheGoldenFixture(_ testCase: Case) throws {
        let law = generate(
            seed: testCase.seed,
            band: testCase.band,
            targetDelta: Double(bitPattern: testCase.targetDeltaBits),
            mode: testCase.mode
        )
        #expect(LawTable(law).key == testCase.lawKey)
    }
}
```

Four things this file gets right, each of which is a way the fixture silently stops asserting anything:

- **`targetDeltaBits`, not `targetDelta`.** A `Double` written as JSON text and re-parsed is not guaranteed to be the same bits. Store `value.bitPattern` and rebuild with `Double(bitPattern:)`. The same rule applies to any `Double` in any committed fixture in this repo.
- **`LawTable.key` is a hand-rolled FNV-1a over the table's words, and lives in `Laws`.** It is the same digest `LawIndex` uses for its 17,248 contextual hashes, so there is exactly one implementation. **Never `hashValue`, never `Hasher`** — Swift's standard hashing is seeded per process, so a fixture built on `hashValue` compares a fresh random number against a stale one and fails on the second run. That failure looks like a determinism bug and is not one; recognising it is the whole reason this bullet exists.
- **The `Case` type is `Codable`,** so `06 T23`'s selective re-run works and one failing tuple re-runs alone.
- **The fixture is versioned in the filename.** `-v1` bumps when the generator's *intended* output changes; the old file is deleted in the same commit that bumps, and `DECISIONS.md` records why. A change to `determinism-seeds-v1.json` that is not accompanied by a deliberate generator change is the regression.

**Producing it.** An `.executableTarget` in `HunchCore/Package.swift`, depending on `Laws` and `LawGeneration` and on nothing in `Tests/`. No test target depends on it, so it costs the fast loop nothing.

```bash
swift run --package-path HunchCore hunch-fixtures determinism \
  > HunchCore/Tests/LawGenerationTests/Fixtures/determinism-seeds-v1.json
```

Encode with `JSONEncoder` configured `outputFormatting: [.sortedKeys, .prettyPrinted]` — sorted keys so the file diffs, pretty-printed so a reviewer can read the diff. `08 §7.9` names this as the role `swift-snapshot-testing`'s `.json` strategy would have filled; hand-rolling it is five lines and takes no dependency.

**Re-recording is a deliberate act.** There is no `--record` flag and there should not be one. `06 T51`'s lesson from snapshot suites is that a re-record affordance trains people to re-record without looking; here the affordance is a shell redirect that shows up in the diff.

## 5. The exit test, as a second opinion

`#expect(processExitsWith:)` genuinely spawns a child process, so it is a cheap corroboration of the golden fixture — and it is available only because `HunchCore` is host-testable (`06 T49`). Wrap it in `#if os(macOS)`; see `references/swift-testing-mechanics.md` §11 for why that is not optional. It is a second opinion, not the primary evidence: same binary, same machine, same minute.

## 6. The banned-symbol greps

`Scripts/check-source-hygiene.sh`, checks 5 and 6 (`07 B34a` extended per `08 §5`). They catch what no test can see, because a test only proves the path it exercised did not misbehave.

| # | Grep over | Fails on |
|---|---|---|
| 5 | the whole repo | `URLSession`, `Network`, `CFNetwork`, `NWConnection` |
| 6 | `HunchCore/Sources/` | `SystemRandomNumberGenerator`, `.random(`, `Date()`, `UUID()` |

Check 6's scope is `HunchCore/Sources/` and not `HunchTestSupport/` — the sandbox trait legitimately calls `UUID()` and `FileManager` to make a temp directory. If you find yourself wanting to widen the grep, you have found a file in the wrong target instead.

The build skill owns where these run. This skill owns the fact that **they are the assertion** for invariants 5 and 7, and that trying to convert them into `@Test` functions cannot work.

## 7. Time — there is no `Clock` in this project

`08 §5` designed the dependency out rather than injecting it: §6.1 fixes that no wall-clock quantity affects score, marks or the Rasch update, and §9's speed curve is a function of glyph index, not elapsed seconds. So there is **no `Clock` abstraction anywhere**, SIEVE's timing is a pure `SieveSchedule` value plus one `ContinuousClock.sleep` at the view edge, and the only injected time source is the minimal shape:

```swift
public struct Now: Sendable {                       // dates only: firstFoundAt, lastPlayed, the UTC day index
    public var date: @Sendable () -> Date
    public static let live = Self { Date() }
    public static func fixed(_ date: Date) -> Self { Self { date } }
}
```

This matters twice: `swift-clocks` is a third-party dependency and therefore banned, so re-implementing `TestClock` would have been real work — and a `Clock` in the graph is an invitation for `Task.sleep` to reach a package whose entire value is that it has no clock.

If a future feature genuinely needs elapsed time in the core, that is a design change with a `DECISIONS.md` entry, not a test-support convenience.

## 8. The Anomaly

One law per day, identical for every player on Earth, from `seed = hash(UTC date)` — the feature that makes determinism a product requirement rather than a testing preference. `Anomaly` is a caseless enum with `dayIndex(_:)` and `seed(day:)`, both pure over `TimeInterval`/`Int64` (`08 §3`).

**No `Calendar`, no `Locale`, no `TimeZone`.** Those are three ambient globals that vary per device, per user setting and per OS release; routing the day index through any of them makes two players in different regions see different laws, and no unit test will notice because the test machine has one locale. The day index is integer arithmetic on seconds since the epoch.

Assert two things: `dayIndex` is monotone and increments exactly once per 86,400 seconds across a range that spans DST transitions and a leap second; and `seed(day:)` for a fixed day is stable — which the golden fixture already covers if you include a handful of anomaly tuples in it.

## 9. Invariants, not golden orders

`06 T42`: assert the invariant, not a fixed sequence out of the RNG. A golden order is a change-detector on the generator's internals; an invariant survives a refactor and still catches the bug. Byte-for-byte comparison is reserved for §4, where identity *is* the property under test.

The five shapes worth writing (`06 T53`), and where each lands in HUNCH:

| Shape | HUNCH instance |
|---|---|
| Round-trip | `LawNode(BenchLayout(law)) == law.renderedNormalForm` (G10); every `StoreFile` case through `PersistenceStore`; `Mode`/`Band` raw values |
| Idempotence | `law.renderedNormalForm.renderedNormalForm == law.renderedNormalForm`; a second migration of an already-migrated store is a no-op |
| Commutativity / associativity | `Coupler.and`/`.or`/`.xor` over their operands; `LawTable` intersection |
| Ordering | `Deck.all` is a permutation of the 256 glyphs *and* is in canonical fill→shape→pips→hue order; a shuffled serving is a permutation of what was served |
| Conservation | the Assay's admit count equals the table's popcount; ribbon marks before and after a phase transition |

You lose shrinking by refusing a property-based library (`06 T52` — SwiftCheck is unmaintained and the brief bans dependencies anyway). Compensate by promoting **every** failure into a named regression case with the literal input. `Corpora.knownBadSeeds` is that list, and it only works if you actually append to it.
