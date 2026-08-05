# T07 — The lower-band index

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T05, T06 |
| **Delivers** | Lower-band index · Backup policy (the contract half — see Out of scope) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-concurrency` | `LawIndexLoader` is **the second and last actor in the entire codebase**, and the skill's budget is exact — a third is a design change, not a fix. It carries the compiling `05 R30` shape (cache the `Task`, not the value), the three properties that shape must keep, and the three wrong fixes that will be proposed. It also rules that `08 §1`'s tree does not place the loader, so the target choice is yours and must be recorded in `DECISIONS.md`. |
| `hunch-swift-code` | The enumeration crosses a target boundary: `LawIndex` lives in `Laws` and `Band` lives in `LawGeneration`, which **depends on** `Laws` — so the index cannot name `Band` without inverting the arrow. The skill's boundary predicate and routing table are what settle the run-index addressing below. It also owns "never a `static var`", which the loader's cache would otherwise be. |

## Objective

The stateless law space of bands 1, 2, 3, 4, 6 and 8 is enumerated once into **9,767 sorted tables** in six runs behind an offset header, so any prefix union is a contiguous range of runs and G4's "strictly lower bands" test is a binary search. Bands 5 and 7 contribute **17,248 64-bit hashes** in two runs. The whole thing encodes to `lowerBandIndex.bin`, decodes back bit-identically, and is built exactly once per process by `actor LawIndexLoader`, which caches the `Task` and not the value.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §3.6 | "The lower-band index" paragraph and the two that follow: 9,767 tables / 305 KB, band-partitioned into six sorted runs of **40 / 1,272 / 108 / 2,322 / 5,688 / 337** behind a six-entry offset header; the strictly-lower-bands rule and why comparing a band against itself would drive the fallback rate to 1.00; bands 5 and 7 stored separately as 17,248 hashes / 138 KB in two runs of **6,934 / 10,314**, collisions resolved by rebuild-and-compare; why G4 is vacuous at band 5 and reduces to the band-5 hash run at band 7. |
| `GAME_DESIGN.md` | §5.2 | The definition of `\|H\|(b)`: which guardrails it closes over and which three it deliberately does not, and the ascending-band-order requirement. |
| `GAME_DESIGN.md` | §5.3 | G4's statement, step 3's "the family's skeleton list", and the 200-attempt bound the index is consulted inside. |
| `GAME_DESIGN.md` | §5.7 | The two locked rows: `9,767 tables, 305 KB — band-partitioned 40 / 1,272 / 108 / 2,322 / 5,688 / 337` and `17,248 × 8 B = 138 KB — band-partitioned 6,934 / 10,314`. |
| `GAME_DESIGN.md` | §11.13 | `lowerBandIndex.bin`: derived, `isExcludedFromBackupKey = true` set **here and nowhere else**, regenerated if absent or corrupt. |
| `GAME_DESIGN.md` | §14.5 decision 4 | The three options for when the index is built, the recommended default (background build, gated so no band ≥ 2 round arms until it completes), and the instruction: **measure in phase 2 and switch to a bundled resource only if the build exceeds 3 s on an A15.** This epic is phase 2. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 | The `LawIndexLoader` shape, verbatim. Read it with `grep -n -A14 'actor LawIndexLoader' ios-swift-guide/08-APPLIED-TO-HUNCH.md` rather than retyping it. |
| `ios-swift-guide/05-CONCURRENCY.md` | R17, R30, R32 | The state ladder's third row, cache-the-Task, and the three wrong fixes. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

```swift
// HunchCore/Tests/LawsTests/LawIndexTests.swift  — the value and its codec
import Foundation
import Testing
import Glyphs
import Laws
import HunchTestSupport

@Suite("Law index format", .tags(.unit, .presubmission))
struct LawIndexTests {

    @Test("The index round-trips through its binary encoding")
    func roundTrip() throws {
        let index = Corpora.index
        let data = index.encoded()
        let decoded = try LawIndex(decoding: data)
        #expect(decoded == index)
    }

    @Test("The payload is exactly the counted bytes behind an offset header")
    func layout() throws {
        let index = Corpora.index
        let data = index.encoded()
        #expect(index.statelessCount == 9_767)
        #expect(index.contextualCount == 17_248)
        #expect(data.count == LawIndex.headerByteCount + 9_767 * 32 + 17_248 * 8)
        #expect(index.statelessRunLengths == [40, 1_272, 108, 2_322, 5_688, 337])
        #expect(index.contextualRunLengths == [6_934, 10_314])
    }

    @Test("Each run is sorted, so a prefix union is a contiguous range and lookup is a search")
    func runsAreSorted() {
        for run in 0..<LawIndex.statelessRunCount {
            let tables = Corpora.index.statelessRun(run)
            #expect(tables == tables.sorted())
        }
        for run in 0..<LawIndex.contextualRunCount {
            let hashes = Corpora.index.contextualRun(run)
            #expect(hashes == hashes.sorted())
        }
    }

    @Test("Membership over a prefix of runs is exact")
    func prefixMembership() {
        let index = Corpora.index
        let firstBandOneTable = index.statelessRun(0)[0]
        #expect(index.containsStateless(firstBandOneTable, inRunsBelow: 1) == false)  // empty prefix
        #expect(index.containsStateless(firstBandOneTable, inRunsBelow: 2))           // run 0 included
    }

    @Test("A truncated or magic-less file throws rather than decoding garbage")
    func malformedSibling() {
        let good = Corpora.index.encoded()
        #expect(throws: LawIndexError.self) { try LawIndex(decoding: good.prefix(64)) }
        var wrongMagic = Data(good)
        wrongMagic[0] = 0x00
        #expect(throws: LawIndexError.self) { try LawIndex(decoding: wrongMagic) }
    }

    @Test("Decoding is byte-order stable")
    func endianness() throws {
        // The file is written little-endian explicitly, never by memcpy of a struct, so a
        // future big-endian host or a bundled resource decodes identically.
        let data = Corpora.index.encoded()
        #expect(try LawIndex(decoding: Data(data)).encoded() == data)
    }
}
```

```swift
// HunchCore/Tests/LawGenerationTests/LawIndexLoaderTests.swift  — the build and the actor
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Law index build and loader", .tags(.unit, .presubmission))
struct LawIndexLoaderTests {

    @Test("Enumerating a band twice gives the identical run")
    func enumerationIsDeterministic() {
        for band in Band.allCases {
            #expect(band.enumeratedTables() == band.enumeratedTables())
        }
    }

    @Test("A concurrent race builds the index exactly once")
    func loaderCachesTheTaskNotTheValue() async throws {
        let cache = CountingLawIndexCache()
        let loader = LawIndexLoader(cache: cache.seam)
        async let a = loader.index()
        async let b = loader.index()
        async let c = loader.index()
        let (x, y, z) = try await (a, b, c)
        #expect(x == y)
        #expect(y == z)
        #expect(await cache.buildCount == 1)
    }

    @Test("A failed build clears the slot instead of caching the failure")
    func failureIsNotCached() async {
        let cache = FailingOnceLawIndexCache()
        let loader = LawIndexLoader(cache: cache.seam)
        await #expect(throws: (any Error).self) { _ = try await loader.index() }
        await #expect(throws: Never.self) { _ = try await loader.index() }
    }

    @Test("A present, valid cache is read rather than rebuilt")
    func warmStartSkipsTheBuild() async throws {
        let cache = CountingLawIndexCache(seeded: Corpora.index.encoded())
        let loader = LawIndexLoader(cache: cache.seam)
        _ = try await loader.index()
        #expect(await cache.buildCount == 0)
    }

    @Test("A corrupt cache is discarded and rebuilt, never surfaced")
    func corruptCacheRebuilds() async throws {
        let cache = CountingLawIndexCache(seeded: Data(repeating: 0xAB, count: 4_096))
        let loader = LawIndexLoader(cache: cache.seam)
        let index = try await loader.index()
        #expect(index.statelessCount == 9_767)
        #expect(await cache.buildCount == 1)
    }

    /// §14.5 open decision 4: measure in phase 2 and switch to a bundled resource only if the
    /// build exceeds 3 s on an A15. The host is not an A15, so this is a **regression fence**,
    /// not the device gate. The device number goes in DECISIONS.md.
    @Test("The cold build stays inside the recorded host budget", .tags(.performance))
    func coldBuildBudget() {
        let start = ContinuousClock.now
        _ = LawIndex.build()
        let elapsed = ContinuousClock.now - start
        #expect(elapsed < .seconds(LawIndex.hostBuildBudgetSeconds))
    }
}
```

`CountingLawIndexCache` and `FailingOnceLawIndexCache` are hand-written fakes in `HunchTestSupport` (`06 T36`: no mocking framework; a fake, so assertions land on state).

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter 'LawIndexTests|LawIndexLoaderTests'`
Expect missing symbols, then — the interesting one — a **wrong run length**. `statelessRunLengths` failing at `[40, 1_272, 108, …]` is the enumeration telling you the skeleton set is wrong. Fix the skeletons; never the number.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Laws/LawIndex.swift` |
| create | `HunchCore/Sources/Laws/LawIndexError.swift` |
| create | `HunchCore/Sources/LawGeneration/Skeleton.swift` — `enum Skeleton` plus `extension Band { var skeletons: [Skeleton] }` |
| create | `HunchCore/Sources/LawGeneration/LawIndexCache.swift` |
| create | `HunchCore/Sources/LawGeneration/LawIndexLoader.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `static let index: LawIndex`, the two cache fakes |
| create | `HunchCore/Tests/LawsTests/LawIndexTests.swift` |
| create | `HunchCore/Tests/LawGenerationTests/LawIndexLoaderTests.swift` |
| modify | `DECISIONS.md` — run-index addressing, loader placement, the measured build time and the open-decision-4 ruling |
| modify | `SPEC.md` — the binary layout and the backup-exclusion rule |
| modify | `PROGRESS.md` — the measured build time on host and on device |
| modify | `tests.json` — "Lower-band index", "Backup policy" |

## Implementation notes

### The dependency arrow — read this before writing a line

`08 §1` puts `LawIndex.swift` in `Laws/` and `Band` in `LawGeneration/`, and `LawGeneration` **depends on** `Laws`. So `LawIndex` cannot mention `Band` — that would invert the arrow and `swift build` would fail to resolve in under a second (`01 §5b`).

**Ruling: `LawIndex` is addressed by run index, not by `Band`.** It holds six stateless runs numbered 0…5 and two contextual runs numbered 0…1, and `LawGeneration` owns the mapping:

```swift
// HunchCore/Sources/LawGeneration/Band.swift (extended here)
extension Band {
    /// This band's run in the stateless section of the index, or `nil` if it is contextual.
    public var statelessRun: Int? { … }   // literal 0, pair 1, exclusive 2, relational 3,
                                          // guarded 4, systemic 5 — ascending band order
    /// This band's run in the contextual section, or `nil` if it is stateless.
    public var contextualRun: Int? { … }  // contextual 0, composite 1
}
```

The alternative — moving `Band` into `Laws` — is defensible and would be simpler. Pick one, record it in `DECISIONS.md` with the arrow argument, and do not leave both half-done.

### The binary layout

Write it explicitly, little-endian, field by field. Never `withUnsafeBytes` over a struct: the file outlives the build that wrote it, `§14.5`'s bundled-resource option would ship it in the app, and a padding change would silently corrupt every install.

| Offset | Field | Bytes |
|---|---|---|
| 0 | magic `"HLB1"` | 4 |
| 4 | schema, `UInt32` — echoes §11.13's single global `schema` | 4 |
| 8 | six stateless run **offsets**, `UInt32` each, in ascending band order | 24 |
| 32 | stateless total count, `UInt32` | 4 |
| 36 | two contextual run offsets, `UInt32` each | 8 |
| 44 | contextual total count, `UInt32` | 4 |
| 48 | stateless payload — `statelessCount × 4 × UInt64` | 312,544 |
| … | contextual payload — `contextualCount × UInt64` | 137,984 |

`LawIndex.headerByteCount = 48`. Total file ≈ 450,576 B, which is the ≈443 KB §14.5 decision 4 quotes for the bundled-resource option — use that as a sanity check on your arithmetic.

Six *offsets* rather than six counts is §3.6's own wording, and it is the shape that makes "any prefix union is a contiguous range" literally true: `⋃{index[b'] : b' < b}` is `payload[0 ..< offsets[b]]`. Because each run is independently sorted, membership over a prefix is one binary search **per run in the prefix** — at most five, each over ≤ 5,688 entries. Do not merge the runs into one globally sorted array; the partition is the feature.

### The skeleton lists — the form space of each family

`enum Skeleton` is the value §5.3 step 3 calls "the family's skeleton list". Each case knows how to enumerate every syntactic form it can take, and `Band.skeletons` names which cases belong to which family. **This is the part of the task that decides the eight counts**, so it is written here and asserted in T08.

The six stateless families, and these definitions were run against a reference enumerator during planning and reproduce **40 / 1,272 / 108 / 2,322 / 5,688 / 337 exactly**:

| Band | Skeletons |
|---|---|
| 1 LITERAL | `<atom>` alone |
| 2 PAIR | `<atom> <coupler> <atom>` on **distinct** attributes, coupler over all three, **minus** the EXCLUSIVE shape (see band 3). Same-attribute pairs are not in the space: RNF rule 4 merges them into a band-1 atom before they can be emitted (§3.4). |
| 3 EXCLUSIVE | `<atom> XOR <atom>` on distinct attributes with **both subsets of size 2** — §5.2 states this is a theorem, not a guardrail |
| 4 RELATIONAL | `<rel>` alone, **and** `<rel> <coupler> <atom>` over all three couplers and all 56 atoms (§3.3: "the relational 18 … [is] not [the band count], since bands 4, 5 and 7 admit composites over those terms") |
| 6 GUARDED | `<guard>` alone — a Fork is a whole-Bench tile and takes no coupler (§4.2) |
| 8 SYSTEMIC | `COUNT` and `PARITY` — the full 1,214 forms |

The two contextual families:

| Band | Skeletons |
|---|---|
| 5 CONTEXTUAL | `<ctx>` alone, and `<ctx> <coupler> <atom>` |
| 7 COMPOSITE | `<ctx> <coupler> <ctx>` over unordered pairs of **distinct** forms, and `<ctx> <coupler> <rel>` — §5.2's "hold two of the above at once", and §5.4's `k = 1.55` "two conceptual layers interfere" |

**A gap you must close, stated up front so you do not rediscover it.** The six stateless counts fall out of the definitions above exactly. The two contextual runs do **not**: under the most literal reading of §3.2 + §3.3 + §5.3 they enumerate to **6,960** and **10,368** — 26 and 54 more than §5.2's 6,934 and 10,314, an excess of 80 tables in total. Neither an alternative liveness definition, an alternative band-5/band-7 split, nor any structural restriction on the ctx leaf closes it. §5.7 locks 6,934 / 10,314 and 27,015, so **the counts are the oracle and the form space is what moves.** T08 carries the dedicated step for finding the missing clause and recording it in `DECISIONS.md`.

### The predicate the enumeration applies, in this order

§5.2 defines `|H|(b)` as the distinct extensions in band `b`'s family surviving G1–G3, G5–G7, G10 and G8's band-membership clause, plus G4 against strictly lower bands. Apply them cheapest first:

1. **G1 / G2** — `popCount ≥ 1` and `≤ N − 1`.
2. **G3** — `admitRate ∈ band.admitWindow`, computed over 256 or 65,536 (§5.3).
3. **G7**, bands 5 and 7 only — `table.isSecretlyStateless == false` (T02).
4. **G5** — `law.deadLeaves.isEmpty` (T05).
5. **G6** — `law.hasLiveNamedAttributes` (T05).
6. **G4** — not present in the union of strictly lower runs. For a stateless band that is a prefix of the stateless section; band 5's is empty (vacuous, §3.6) and band 7's is the band-5 hash run alone.
7. **Dedup by extension**, which is `LawSet` from T05.

**G8's band-membership clause and G10 are vacuous over an exhaustive family enumeration**, and that is why this task can run before E06 exists:

- G8 membership: §5.1's five modifiers sum to **exactly 0.124**, one tick short of the 0.125 band width, so "a law can never escape its band" — a law of family *b* is in band *b* by construction.
- G10: §4.4's parity table marks every production "exhaustive", so the Bench can express every grammar-valid law and G10 excludes none of them.

Write both arguments as a comment above the predicate, cite §5.1 and §4.4, and add a line to E06 T05's acceptance list: **if G8's membership clause or G10 ever rejects a member of the enumerated set, this epic's count assertion is the thing that fails first.**

### `LawIndexCache` — the seam, because `PersistenceStore` does not exist yet

E07 owns `PersistenceStore` and it is two epics away, so the loader takes a struct of closures (`W44`'s leftover row, the `Now`/`SeedSource` shape):

```swift
/// Where the built index is parked between launches. E07 T02 constructs the live one from
/// `FilePersistenceStore` and `StoreFile.lawIndex`.
public struct LawIndexCache: Sendable {
    public var read: @Sendable () async throws -> Data?
    public var write: @Sendable (Data) async throws -> Void

    /// **Contract:** `write` must mark the written file `isExcludedFromBackupKey = true`.
    /// §11.13 sets that flag on `lowerBandIndex.bin` and on **no other file in the tree**; the
    /// index is derived and regenerable, and 443 KB of derived data has no business in a
    /// device backup. E07 T02 is where the `URL.setResourceValues` call lands, and E07 T06's
    /// reset-map suite is where "and nowhere else" is asserted against the v1 fixture.
    public static let inMemory: LawIndexCache
    public static let none: LawIndexCache          // always rebuilds; what previews use
}
```

### `LawIndexLoader` — the second and last actor

Read the shape out of the guide rather than retyping it:

```bash
grep -n -A14 'actor LawIndexLoader' ios-swift-guide/08-APPLIED-TO-HUNCH.md
```

Three properties it must keep, and each has a test above:

1. **The `Task` is stored before the first `await`.** Storing is synchronous, so it lands before any suspension and the second caller finds it. `loaderCachesTheTaskNotTheValue` fails if you store after.
2. **Failure clears the slot.** A cached failed `Task` is a permanent outage. `failureIsNotCached` is that test.
3. **`LawIndex` is an immutable `Sendable` struct**, so once built it leaves the actor and is never touched again — the actor serialises *building*, not reading.

`05 R32` names the three wrong fixes that will be proposed and all three are wrong here: making `index()` `nonisolated` moves the problem, an `isLoading` flag with an early `nil` return silently drops results, and a lock around the body is impossible across `await`.

**Placement.** The loader needs `LawIndex` (in `Laws`) and the build (in `LawGeneration`), so it goes in `LawGeneration`. Do not add a dependency edge to `Laws` for it. Record the choice in `DECISIONS.md` — `08 §1`'s tree does not place it and `hunch-swift-concurrency` explicitly asks for the note.

### The 3 s A15 measurement

§14.5 decision 4 says measure in phase 2. Do all three of these:

1. **Host fence.** `LawIndex.hostBuildBudgetSeconds` is a `static let` set just above your measured host time; the `.performance` test above fails when the build regresses. This is a fence, not the gate.
2. **Device number.** Run the build once on an A15-class device (iPhone 13 / SE 3) or the slowest simulator available and write the figure into `PROGRESS.md`.
3. **The ruling.** Write into `DECISIONS.md` which of §14.5's three options is adopted, with the measured number as the reason. If it is under 3 s the default stands — background build, gated so no band ≥ 2 round arms until it completes, which is E11 T06's serving-layer concern and gets a line in `SPEC.md` here. If it is over, the ruling is the bundled resource and the index must then be version-locked to the generator, which is a second `DECISIONS.md` sentence.

`Corpora.index` is a `static let` built once for the whole test suite (`06 T10`, `08 §5`). If two suites each build their own, the ten-second budget is gone and the mistake will look like good hygiene.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'LawIndexTests|LawIndexLoaderTests'` is green.
- [ ] `index.statelessRunLengths == [40, 1_272, 108, 2_322, 5_688, 337]` and `index.contextualRunLengths == [6_934, 10_314]`.
- [ ] `index.encoded().count == 48 + 9_767 * 32 + 17_248 * 8`.
- [ ] `LawIndex(decoding: index.encoded()) == index` and both malformed-sibling cases throw a `LawIndexError`.
- [ ] Every run is sorted ascending, and `containsStateless(_:inRunsBelow:)` is a binary search per run — no linear scan: `grep -n 'firstIndex(of:\|contains(' HunchCore/Sources/Laws/LawIndex.swift` shows no linear membership call on a run.
- [ ] Three concurrent `loader.index()` calls produce one build; a failed build does not poison the next call; a valid cache skips the build; a corrupt cache rebuilds.
- [ ] `grep -rn --include='*.swift' -E '^[[:space:]]*(public |package )?actor ' HunchCore Modules` returns exactly one row, `LawIndexLoader`.
- [ ] `grep -rn 'static var' HunchCore/Sources` returns nothing.
- [ ] The encoder writes little-endian field by field: `grep -n 'withUnsafeBytes\|unsafeBitCast' HunchCore/Sources/Laws/LawIndex.swift` returns nothing.
- [ ] `DECISIONS.md` carries four entries: run-index addressing, loader placement, the measured build time, and the §14.5 decision-4 ruling.
- [ ] `PROGRESS.md` carries the host and device build measurements.
- [ ] `SPEC.md` states the binary layout and that `isExcludedFromBackupKey` is set on `lowerBandIndex.bin` and nowhere else.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. **Reject any suggestion to flatten the six runs into one sorted array** — the partition is what makes G4's prefix union a contiguous range.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T07: the band-partitioned lower-band index and LawIndexLoader"`

## Out of scope

- **Asserting the eight counts.** T08. This task builds the runs; T08 is the eight separate assertions and the ascending-order argument, and it is where the 80-table contextual gap is closed.
- **Writing the file to disk.** `FilePersistenceStore`, `StoreFile.lawIndex`, the atomic write and the `URL.setResourceValues(isExcludedFromBackupKey:)` call are **E07 T02**. This task ships the cache seam, the contract on it, the `SPEC.md` rule and the `tests.json` entry; E07 T06's reset-map suite asserts "and nowhere else".
- **Gating round arming on the build.** "No band ≥ 2 round arms until it completes" is the serving layer, E11 T06. This task states the rule in `SPEC.md` and exposes `LawIndexLoader.index()`; it does not arm anything.
- **G4 as a named guardrail.** E06 T05 assembles the ten predicates in order; this task ships the membership query it calls.
- **The generator's skeleton sampling.** Inverse-cardinality weighting, the `hue` down-weight and the 200-attempt bound are E06 T06. This task ships `Band.skeletons` as an exhaustive enumerator; the generator samples from it.
