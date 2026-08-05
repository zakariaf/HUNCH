# T06 — The generator

| | |
|---|---|
| **Epic** | E06 — Difficulty, the Bench model and the generator |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T05 (and therefore T01–T04) |
| **Delivers** | §14.1 Generator |
| **Status** | not started |

## Skills to load

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides the shape: a free function in `LawGeneration`, no `Generator` class, no stored state, `Band.skeletons` as a `static let` of immutable `Sendable` values rather than a lazily-built cache. It also owns the ban on `static var` that a memoised skeleton table would otherwise walk into. |
| `hunch-swift-concurrency` | This is *the* file its RNG rule was written for: `generate` is synchronous and `nonisolated`, `rng` is a local `var` threaded by `inout`, and the four wrong answers (an `@Observable` property, an actor, `nonisolated(unsafe)`, a `static var`) are each spelled out with what they break. Determinism is a scoping problem, and the scope is this one function call. |

## Objective

`generate(seed:band:targetDelta:mode:avoid:in:)` returns a law that satisfies all ten guardrails, or
— after exactly 200 attempts — the family's deterministic anchor. It is pure over its arguments,
synchronous, `nonisolated`, and never blocks, fails or throws.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.3 | The six numbered steps, the purity decision and its reasoning, the 200-attempt bound, the anchor and its two exemptions, the 2 % fallback budget |
| `GAME_DESIGN.md` | §5.2 | One family per band, no reprises, and why a band-2 law served at band 5 poisons the estimate |
| `GAME_DESIGN.md` | §5.1 | Rejection sampling within the family until `\|difficulty − target\| ≤ 0.02` |
| `GAME_DESIGN.md` | §3.2, §3.4 | The productions a skeleton may be, and the structural caps generated laws must satisfy |
| `GAME_DESIGN.md` | §5.7 | Generator purity, the attempt bound, the seeded-RNG row |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 | The RNG-under-strict-concurrency resolution and its five consequences, verbatim in shape |
| `ios-swift-guide/05-CONCURRENCY.md` | R7, R8, R13 | Default isolation, explicit annotation, and why a bare `nonisolated async` is forbidden |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/LawGenerationTests/GeneratorSamplingTests.swift`. (`GeneratorTests.swift` is
reserved for T09's corpus suite, which is where `hunch-swift-testing` puts brief invariant #1.)

```swift
import Foundation
import Testing
import Glyphs
import Laws
import Bench
import LawGeneration
import HunchTestSupport

@Suite("The generator", .tags(.unit, .presubmission))
struct GeneratorSamplingTests {

    private func makeLaw(_ band: Band, seed: UInt64 = 0x48554E4348,
                         targetDelta: Double? = nil, avoid: Set<UInt64> = []) -> LawNode {
        generate(seed: seed, band: band, targetDelta: targetDelta ?? band.centre,
                 mode: .probe, avoid: avoid, in: Corpora.index)
    }

    // MARK: purity

    @Test("Same arguments, same law — twice in one process", arguments: Band.allCases)
    func sameArgumentsSameLaw(_ band: Band) {
        #expect(makeLaw(band) == makeLaw(band))
    }

    @Test("The mode salt separates the four modes", arguments: Band.allCases)
    func modeSaltSeparatesModes(_ band: Band) {
        let laws = Mode.allCases.map {
            generate(seed: 0x48554E4348, band: band, targetDelta: band.centre,
                     mode: $0, avoid: [], in: Corpora.index)
        }
        #expect(Set(laws).count > 1)                 // not a hash-quality claim: just "salt is used"
    }

    @Test("A different seed gives a different law far more often than not", arguments: Band.allCases)
    func seedsSeparate(_ band: Band) {
        let laws = (0..<64).map { makeLaw(band, seed: Corpora.seed(band: band, index: $0)) }
        #expect(Set(laws).count >= 32)               // bands 1 and 3 are thin; 32 of 64 is safe
    }

    // MARK: the six steps

    @Test("Every generated law is in the requested band, with no reprises", arguments: Band.allCases)
    func oneFamilyPerBand(_ band: Band) {
        for index in 0..<256 {
            let law = makeLaw(band, seed: Corpora.seed(band: band, index: index))
            #expect(Band(classifying: law) == band)
        }
    }

    @Test("Every generated law is already in rendered normal form", arguments: Band.allCases)
    func outputIsCanonical(_ band: Band) {
        for index in 0..<256 {
            let law = makeLaw(band, seed: Corpora.seed(band: band, index: index))
            #expect(law.renderedNormalForm == law)
        }
    }

    @Test("Every generated law satisfies §3.4's structural caps", arguments: Band.allCases)
    func structuralCapsHold(_ band: Band) {
        for index in 0..<256 {
            let law = makeLaw(band, seed: Corpora.seed(band: band, index: index))
            #expect(law.depth <= LawNode.maxDepth)
            #expect(law.leafCount <= LawNode.maxLeaves)
            #expect(law.relationalTermCount <= 1)
            #expect(law.contextualTermCount <= 2)
            #expect(law.maxLeavesPerAttribute <= 2)
            #expect(law.hasNoDuplicateLeafTriple)
        }
    }

    @Test("Every generated law clears every guardrail", arguments: Band.allCases)
    func guardrailsHold(_ band: Band) {
        for index in 0..<256 {
            let seed = Corpora.seed(band: band, index: index)
            let target = Corpora.targetDelta(band: band, index: index)
            let law = generate(seed: seed, band: band, targetDelta: target,
                               mode: .probe, avoid: [], in: Corpora.index)
            let ctx = GuardrailContext(band: band, targetDelta: target, avoid: [],
                                       index: Corpora.index,
                                       exemptions: law == band.exemplar ? [.proximity, .novelty] : [])
            #expect(firstFailure(for: Law(law), in: ctx) == nil,
                    "seed 0x\(String(seed, radix: 16))")
        }
    }

    // MARK: skeletons

    @Test("Every band's skeleton list agrees with its minimum leaf count", arguments: Band.allCases)
    func skeletonsAgreeWithMinLeaves(_ band: Band) {
        #expect(band.skeletons.isEmpty == false)
        #expect(band.skeletons.map(\.leafCount).min() == band.minLeaves)
    }

    @Test("Skeleton cardinalities sum to the band population", arguments: Band.enumerableCases)
    func skeletonCardinalitiesSumToPopulation(_ band: Band) {
        #expect(band.skeletons.map(\.cardinality).reduce(0, +) >= band.population)
    }

    /// Inverse-cardinality weighting exists so rare skeletons surface. Without it a band whose
    /// skeleton list is {2,322 relational composites, 36 bare relationals} shows a bare relational
    /// once in 65 rounds, and the family's entry-level law becomes the rarest thing in it.
    @Test("Rare skeletons surface at roughly their inverse-cardinality share",
          arguments: Band.enumerableCases)
    func rareSkeletonsSurface(_ band: Band) throws {
        try #require(band.skeletons.count > 1)
        var histogram: [Skeleton.ID: Int] = [:]
        for index in 0..<4_000 {
            let law = makeLaw(band, seed: Corpora.seed(band: band, index: index),
                              targetDelta: Corpora.targetDelta(band: band, index: index))
            histogram[Skeleton.identifying(law), default: 0] += 1
        }
        #expect(histogram.count == band.skeletons.count)     // every skeleton appears at all
        let rarest = band.skeletons.max(by: { $0.cardinality < $1.cardinality })!
        #expect(histogram[rarest.id, default: 0] > 0)
    }

    // MARK: hue

    @Test("hue is down-weighted in relational and contextual slots")
    func hueIsDownWeighted() {
        var hueSlots = 0, totalSlots = 0
        for index in 0..<4_000 {
            let law = makeLaw(.relational, seed: Corpora.seed(band: .relational, index: index))
            for attribute in law.ordinalOperandAttributes {
                totalSlots += 1
                if attribute == .hue { hueSlots += 1 }
            }
        }
        let share = Double(hueSlots) / Double(totalSlots)
        #expect(share < 0.25)              // uniform would be 0.25; the 0.5 weight puts it near 0.14
        #expect(share > 0.05)              // and it is down-weighted, not excluded
    }

    /// §5.3: hue's rank is the weakest of the four, so below band 5 no law may rest its entire
    /// ordinal content on it. Under §3.2 `<rel>` takes distinct attributes, so the predicate is
    /// false by construction at bands 1–4 — the check guards the day a skeleton list changes.
    @Test("hue is never the sole ordinal operand below band 5")
    func hueIsNeverTheSoleOrdinalOperandBelowBandFive() {
        for band in Band.allCases where band < .contextual {
            for index in 0..<1_000 {
                let law = makeLaw(band, seed: Corpora.seed(band: band, index: index))
                #expect(!Sampler.hueIsSoleOrdinalOperand(law))
            }
        }
        // and the predicate is not vacuously false everywhere: band 5's entry-level law trips it,
        // and is permitted there.
        let entryLevel = LawNode.contextual(leading: .hue, comparator: .gt, trailing: .hue)
        #expect(Sampler.hueIsSoleOrdinalOperand(entryLevel))
    }

    // MARK: the bound and the anchor

    @Test("An unsatisfiable request falls back to the anchor after the attempt bound",
          arguments: Band.allCases)
    func impossibleTargetFallsBackToTheAnchor(_ band: Band) {
        // a target outside the band entirely can satisfy no candidate.
        let report = generateReporting(seed: 0x48554E4348, band: band, targetDelta: -1.0,
                                       mode: .probe, avoid: [], in: Corpora.index)
        #expect(report.usedAnchor)
        #expect(report.attempts == Generation.attemptBound)
        #expect(report.law == band.exemplar)
    }

    @Test("The anchor is exempt from proximity and novelty, never from the other eight",
          arguments: Band.allCases)
    func anchorIsExemptFromExactlyTwoClauses(_ band: Band) {
        let law = Law(band.exemplar)
        var ctx = GuardrailContext(band: band, targetDelta: -1.0,
                                   avoid: [law.table.dedupHash],
                                   index: Corpora.index,
                                   exemptions: [.proximity, .novelty])
        #expect(firstFailure(for: law, in: ctx) == nil)
        ctx.exemptions = []
        #expect(firstFailure(for: law, in: ctx) != nil)
    }

    @Test("Avoiding everything the generator can produce still returns a law", arguments: Band.allCases)
    func generationNeverFails(_ band: Band) {
        let everything = Set((0..<512).map {
            Law(makeLaw(band, seed: Corpora.seed(band: band, index: $0))).table.dedupHash
        })
        let law = makeLaw(band, avoid: everything)
        #expect(Band(classifying: law) == band)         // it returned *something*, in band
    }

    // MARK: sampling primitives

    @Test("Uniform sampling below a bound is unbiased and reproducible")
    func uniformSamplingIsUnbiased() {
        var rng = SplitMix64(seed: 0xA5A5A5A5)
        var histogram = [Int](repeating: 0, count: 7)
        for _ in 0..<70_000 { histogram[Int(Sampling.uniform(below: 7, using: &rng))] += 1 }
        for bucket in histogram { #expect(abs(bucket - 10_000) < 500) }

        var a = SplitMix64(seed: 1), b = SplitMix64(seed: 1)
        #expect((0..<100).map { _ in Sampling.uniform(below: 13, using: &a) }
             == (0..<100).map { _ in Sampling.uniform(below: 13, using: &b) })
    }

    @Test("Weighted sampling honours integer weights exactly")
    func weightedSamplingHonoursWeights() {
        var rng = SplitMix64(seed: 0xC0FFEE)
        var histogram = [0, 0, 0]
        for _ in 0..<60_000 { histogram[Sampling.weightedIndex([1, 2, 3], using: &rng)] += 1 }
        #expect(abs(histogram[0] - 10_000) < 500)
        #expect(abs(histogram[1] - 20_000) < 700)
        #expect(abs(histogram[2] - 30_000) < 900)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter GeneratorSamplingTests`

**Step 3 — implement.** Files below.

**Step 4 — green, then refactor.** Then run T09's corpus suite even though it is not written yet in
its final form — a 256-law-per-band smoke inside this task is what tells you the fallback rate is
sane before you build the 10,000-law measurement on top of it.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/Generator.swift` — `generate(…)`, `generateReporting(…)`, `enum Generation` holding the attempt bound |
| create | `HunchCore/Sources/LawGeneration/Skeleton.swift` — the skeleton value, its cardinality, and `Skeleton.identifying(_:)` |
| create | `HunchCore/Sources/LawGeneration/Sampler.swift` — leaf filling, attribute weighting, the hue rules |
| create | `HunchCore/Sources/LawGeneration/Sampling.swift` — `uniform(below:using:)`, `weightedIndex(_:using:)` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `skeletons` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `targetDelta(band:index:)` |
| create | `HunchCore/Tests/LawGenerationTests/GeneratorSamplingTests.swift` |
| modify | `DECISIONS.md` — the `LawIndex`-as-argument ruling, the anchor choice, the hand-rolled uniform sampler |
| modify | `tests.json` — one entry for Generator |

## Implementation notes

### The signature, and the sixth argument

```swift
/// §5.3's generator. Pure over the request — the caller's five arguments — plus the program-wide
/// law index, which is derived data identical in every process.
///
/// - Complexity: bounded by `Generation.attemptBound` guardrail evaluations.
public func generate(seed: UInt64, band: Band, targetDelta: Double, mode: Mode,
                     avoid: Set<UInt64> = [], in index: LawIndex) -> LawNode {
    generateReporting(seed: seed, band: band, targetDelta: targetDelta,
                      mode: mode, avoid: avoid, in: index).law
}

public struct GenerationReport: Sendable {
    public let law: LawNode
    public let attempts: Int
    public let usedAnchor: Bool
}

public func generateReporting(seed: UInt64, band: Band, targetDelta: Double, mode: Mode,
                              avoid: Set<UInt64>, in index: LawIndex) -> GenerationReport
```

> **Ruling, to be recorded in `DECISIONS.md`.** §5.3's signature has five arguments and the design's
> point is that **player history never reaches inside**. `LawIndex` is not player history: it is a
> deterministic enumeration of the law space, byte-identical in every process, built once and
> immutable. The alternatives are both worse — reaching for it through a `static let` makes it the
> ambient state §5.3 exists to forbid *and* puts a 3-second enumeration on the generator's critical
> path (§14.5 open decision 4 explicitly moves that build to the background). So the index is
> threaded explicitly as a sixth argument and the function is *more* pure than the design's phrasing,
> not less. The determinism golden of T10 records the index's checksum in its header so that a
> changed index invalidates the fixture loudly.

### The RNG

`08 §4` is the shape and it is not negotiable:

```swift
var rng = SplitMix64(seed: seed ^ (UInt64(band.rawValue) << 32) ^ mode.salt)
```

A local `var` that never escapes; every helper takes `using rng: inout some RandomNumberGenerator`.
`generate` is **synchronous and `nonisolated`**, never `async`. `hunch-swift-concurrency` lists the
four wrong answers and what each one breaks; if band-8 generation ever measures slow on an A15 the
offload passes the *seed* across the isolation boundary, never the generator.

### Sampling must be integer-only

`Int.random`, `Double.random` and `RandomNumberGenerator.next(upperBound:)` are all off the table:
the first two are banned in `HunchCore` by the hygiene grep, and the third's algorithm is a stdlib
implementation detail that may change between toolchains — which would silently invalidate the
cross-process golden T10 commits. Hand-roll it:

```swift
public enum Sampling {
    /// Unbiased rejection sampling. Documented and hand-rolled because the golden fixture of T10
    /// must survive a toolchain upgrade; see `DECISIONS.md`.
    public static func uniform(below bound: UInt64, using rng: inout some RandomNumberGenerator) -> UInt64
    /// Cumulative integer weights; ties resolved toward the lower index. No floating point.
    public static func weightedIndex(_ weights: [Int], using rng: inout some RandomNumberGenerator) -> Int
}
```

The whole generator uses these two and nothing else. Inverse-cardinality skeleton weights are
integers: take `weight_i = totalCardinality / cardinality_i` (integer division against a common
scale), not `1.0 / Double(cardinality_i)`.

### The six steps

1. **Seed the RNG** as above.
2. **`family = Band`** — `08 §3`'s collapse means step 2 is the identity and there is nothing to
   write. The test that matters is `Band(classifying: law) == band` on the output.
3. **Sample a skeleton**, weighted by inverse cardinality. `Band.skeletons` is a `static let` of
   immutable `Sendable` values; each `Skeleton` carries its production shape, its `leafCount` and
   its `cardinality`.
4. **Fill leaves.** Attributes drawn without replacement *within a leaf*; subsets and comparators
   uniform subject to family constraints; `hue` at half weight in relational and contextual slots.
5. **Canonicalise to RNF.** Everything after this point sees the canonical node, which is what makes
   G8's "difficulty of the canonical form" and G10's node identity both well-defined.
6. **Run the guardrails in `Guardrail.evaluationOrder`**, resample on failure, bounded at
   `Generation.attemptBound`, then return the anchor.

### `Band.skeletons` has one owner

E05·T07's enumerator already walks each band's law space, which means it already encodes family
membership. **`Band.skeletons` must be the same set.** If E05 inlined the shapes into its
enumerator, the first step of this task is to lift them into `Band.skeletons` and re-run
`LawsTests`: the per-band `|H|` assertions passing unchanged is the proof the lift changed nothing.
Two encodings of family membership will drift, and the day they do, `Band(classifying:)` and the
enumeration will disagree about what band a law is in — which is the one disagreement the Rasch
model cannot survive.

### The anchor

> **Ruling, to be recorded in `DECISIONS.md`.** The family's deterministic anchor is **§5.2's
> "Example law" column** — already shipped as `Band.exemplar` in T01, already asserted in T02 to be
> in RNF, in its own band, and clear of every guardrail except the two it is exempt from. Inventing
> a ninth set of laws for the fallback path would be a second source of truth for "what a band-*b*
> law looks like", and the exemplar is the law the design itself reaches for when it needs one.

Its exemptions are set by the generator, not by the anchor: `exemptions = [.proximity, .novelty]`.
It is **not** exempt from G1–G7, G8's membership clause or G10 — §5.3 says it satisfies those by
construction, and T02's `exemplarsClearEverything` test is what makes "by construction" true.

### The 2 % budget

§5.3 makes the fallback rate a monitored test statistic. `generateReporting` exists so it can be
measured; T09 measures it over 10,000 laws per band and asserts it. If it is over budget at any
band, the cause is almost always the requested `targetδ` sitting outside
`band.achievableDifficultyRange` (T02's ruling) — check that before touching the attempt bound,
which §5.7 locks.

### Never in this file

No `Date()`, no `UUID()`, no `.random(`, no `SystemRandomNumberGenerator`, no store, no `Ladder`, no
`Codex`, no clock, no `Task`, no `async`. `Scripts/check-source-hygiene.sh` check 6 catches the
first four; the package graph catches the middle three; `05 R13` catches the last two in review.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter GeneratorSamplingTests` is green.
- [ ] `generate` is declared synchronous and `nonisolated`, its RNG is a local `var`, and
      `grep -rn 'async\|await\|Task' HunchCore/Sources/LawGeneration/Generator.swift` returns nothing.
- [ ] 256 laws per band are all in the requested band, all in RNF, all satisfying §3.4's structural
      caps, and all clearing `firstFailure(for:in:) == nil`.
- [ ] `band.skeletons.map(\.leafCount).min() == band.minLeaves` for all eight bands, and
      `Band.skeletons` is the only encoding of family membership in the repository
      (`grep -rn 'case .contextual' HunchCore/Sources` shows no second classifier).
- [ ] Every skeleton in every enumerable band appears at least once in 4,000 draws.
- [ ] hue's share of ordinal operand slots at band 4 is measurably below the uniform 0.25 and above
      0.05.
- [ ] An unsatisfiable `targetδ` returns the band's exemplar with `attempts == Generation.attemptBound`
      and `usedAnchor == true`, for all eight bands.
- [ ] `Sampling.uniform(below:using:)` is unbiased over 70,000 draws and reproducible from a seed;
      `Sampling.weightedIndex` honours integer weights.
- [ ] `DECISIONS.md` records the index-as-argument ruling, the anchor choice and the hand-rolled
      sampler.
- [ ] `tests.json` has a Generator entry.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E06/T06: the pure generator — skeleton sampling, 200 attempts, family anchor"`

## Out of scope

- The 10,000-law corpus and the fallback-rate assertion — **T09**.
- Determinism across processes — **T10**.
- Seed choice, `avoid` assembly, retry-with-a-fresh-seed and the lost-law cooldown — **E11·T06**.
- The serving policy that decides which band and `targetδ` to ask for — **E11·T03**.
- DRIFT's two-law generation and its one-leaf edit — **E12·T01**.
- The Anomaly's derived seed and its `avoid: []` call — **E16·T01**.
