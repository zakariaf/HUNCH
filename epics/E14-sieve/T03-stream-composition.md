# T03 — Stream composition

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | Stream composition (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The stream is generated, so this task lands squarely on the rule that **randomness is a parameter, never an ambient**: `SieveStream.build` takes `using rng: inout some RandomNumberGenerator`, is synchronous and `nonisolated`, and no RNG escapes the call tree. The skill also carries the ban list (`SystemRandomNumberGenerator`, `.random(`, `Date()`, `UUID()`) that CI greps `HunchCore/Sources/` for, and the boundary predicate that keeps a stream builder core. |
| `hunch-swift-testing` | S1–S5 over a seeded corpus is the **T21 deviation** applied a second time: parameterise over `Band.sieveServable`, loop the streams inside, and pay `T21`'s protection back with a reproducing seed in every message plus an `Attachment.record` of the offending stream. The skill also owns `Corpora`, the `static let` shared-state rule and the ten-second budget this suite has to fit inside. |

`hunch-glyph-renderer` is **not** loaded: a stream is a list of `Glyph` values, and nothing here draws
one.

## Objective

At the end of this task `SieveStream.build` produces, from a seed and a law, the exact ordered list of
glyphs a run will show — partitioned into three reaches by **subtraction** so they cover the stream
exactly, each built to its own rule, and satisfying S1–S5. Contextual streams carry a seed glyph held
inert in the gate for 1.5 s that primes position 0 and is never scored, so `prev` is defined for the
first glyph without the player having to have probed anything.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.4 | `tell = 12`, `runOut = round(0.25·N)`, `body = N − 12 − runOut` **as the remainder and never a percentage**; the three reaches' extents, lawful fractions, construction rules and weights; the decision paragraph explaining that a fixed fraction over-subscribes every band but 6; the seed glyph held inert for 1.5 s in contextual bands; guardrails **S1–S5** |
| `GAME_DESIGN.md` | §9.3 | the `N` and the tell / body / run-out integer triple per band — the table the subtraction must reproduce |
| `GAME_DESIGN.md` | §9.9 | BLIND-STREAM, prevented by S3 |
| `GAME_DESIGN.md` | §3.5 | sequence semantics: `prev` for position 0 comes from the seed glyph, and the seed glyph is not itself an event |
| `GAME_DESIGN.md` | §5.7 | the admit-rate window `p ∈ [0.15, 0.60]`, which is what makes "the law's own `p`" a bounded quantity and what the tap-everything domination argument in T04 rests on |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 | the RNG rule: `var rng = SplitMix64(seed: …)` local, `&rng` threaded down, never stored, never escaping |
| `ios-swift-guide/06-TESTING.md` | T21, T22, T53, T18a | the deviation, the Cartesian trap, promoting every failure into a named case, `Attachment.record` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

`HunchCore/Tests/RoundsTests/SieveReachTests.swift` — the arithmetic, which is exact and cheap:

```swift
import Testing
import Glyphs
import Rounds

@Suite("SIEVE reaches partition the stream exactly — §9.4", .tags(.unit, .presubmission))
struct SieveReachTests {

    @Test("S5 — tell + body + runOut == N, for every band and every tempo step",
          arguments: Band.sieveServable, 0...3)
    func reachesPartitionExactly(_ band: Band, _ step: Int) {
        let reaches = SieveReaches(glyphCount: SieveSchedule(band: band, tempoStep: step,
                                                             pacing: .ramped).glyphCount)
        #expect(reaches.tell + reaches.body + reaches.runOut == reaches.glyphCount)
    }

    @Test("S5 — body ≥ 20 for every band and every tempo step",
          arguments: Band.sieveServable, 0...3)
    func bodyIsNeverStarved(_ band: Band, _ step: Int) {
        let reaches = SieveReaches(glyphCount: SieveSchedule(band: band, tempoStep: step,
                                                             pacing: .ramped).glyphCount)
        #expect(reaches.body >= 20)
    }

    @Test("the tell is a fixed 12 at every band — it is a count, not a fraction",
          arguments: Band.sieveServable)
    func tellIsFixed(_ band: Band) {
        let n = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped).glyphCount
        #expect(SieveReaches(glyphCount: n).tell == 12)
    }

    @Test("the run-out is round(0.25·N)", arguments: Band.sieveServable)
    func runOutIsAQuarterRounded(_ band: Band) {
        let n = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped).glyphCount
        #expect(SieveReaches(glyphCount: n).runOut == Int((0.25 * Double(n)).rounded()))
    }

    @Test("the body is the REMAINDER — a 60 % body would over-subscribe every band but 6",
          arguments: Band.sieveServable)
    func bodyIsTheRemainderNotAPercentage(_ band: Band) {
        let n = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped).glyphCount
        let reaches = SieveReaches(glyphCount: n)
        #expect(reaches.body == n - 12 - reaches.runOut)
        // The fraction that was rejected: 12 + 0.60·N + 0.25·N equals N only at N = 80.
        let fractional = 12 + Int((0.60 * Double(n)).rounded()) + Int((0.25 * Double(n)).rounded())
        if n != 80 { #expect(fractional != n) }
    }

    @Test("the reach of any index is total and contiguous", arguments: Band.sieveServable)
    func reachOfIndexIsTotal(_ band: Band) {
        let n = SieveSchedule(band: band, tempoStep: 0, pacing: .ramped).glyphCount
        let reaches = SieveReaches(glyphCount: n)
        let sequence = (0..<n).map(reaches.reach(of:))
        #expect(sequence.prefix(reaches.tell).allSatisfy { $0 == .tell })
        #expect(sequence.suffix(reaches.runOut).allSatisfy { $0 == .runOut })
        #expect(sequence.filter { $0 == .body }.count == reaches.body)
    }

    @Test("the tell weighs 0.5 and the other two weigh 1.0 (§9.6)")
    func weights() {
        #expect(SieveReach.tell.weight == 0.5)
        #expect(SieveReach.body.weight == 1.0)
        #expect(SieveReach.runOut.weight == 1.0)
    }
}
```

`HunchCore/Tests/RoundsTests/SieveStreamGuardrailTests.swift` — S1–S5 over a seeded corpus:

```swift
import Foundation                  // Attachment.record on a Codable value
import Testing
import Glyphs
import Laws
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("SIEVE stream guardrails S1–S5 — §9.4", .tags(.unit, .presubmission))
struct SieveStreamGuardrailTests {

    /// The T21 deviation, second application: parameterise over the band, loop the streams inside,
    /// and name the reproducing seed in every failure.
    @Test("every guardrail holds across the band", arguments: Band.sieveServable)
    func guardrailsHold(_ band: Band) throws {
        for index in 0..<Corpora.sieveStreamsPerBand {
            let seed = Corpora.seed(band: band, index: index)
            let law = Law(generate(seed: seed, band: band, targetDelta: band.centre, mode: .sieve))
            var rng = SplitMix64(seed: seed)
            let stream = SieveStream.build(law: law, band: band, tempoStep: index % 4, using: &rng)

            let failure: String? =
                if !SieveGuardrail.s1(stream, law: law) { "S1: a named attribute misses a value in the tell" }
                else if !SieveGuardrail.s2(stream, law: law) { "S2: five consecutive glyphs share a verdict" }
                else if !SieveGuardrail.s3(stream, law: law, band: band) { "S3: too few boundary-straddling pairs in the tell" }
                else if !SieveGuardrail.s4(band: band, tempoStep: index % 4) { "S4: pitch invariant broken" }
                else if !SieveGuardrail.s5(stream) { "S5: reaches do not partition, or body < 20" }
                else { nil }

            guard let failure else { continue }
            Attachment.record(stream, named: "sieve-band\(band.rawValue)-index\(index).json")
            Issue.record("\(failure) — reproduce with Corpora.seed(band: .\(band), index: \(index))")
            return
        }
    }

    @Test("known bad seeds stay fixed", arguments: Corpora.knownBadSieveSeeds)
    func regressions(_ known: Corpora.SieveSeed) throws {
        let law = Law(generate(seed: known.seed, band: known.band,
                               targetDelta: known.targetDelta, mode: .sieve))
        var rng = SplitMix64(seed: known.seed)
        let stream = SieveStream.build(law: law, band: known.band, tempoStep: known.tempoStep, using: &rng)
        #expect(SieveGuardrail.all(stream, law: law, band: known.band, tempoStep: known.tempoStep))
    }

    // MARK: the construction rules, stated as assertions rather than as prose

    @Test("the tell is exactly half lawful, at every band", arguments: Band.sieveServable)
    func tellIsExactlyHalfLawful(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        let tell = stream.glyphs.prefix(stream.reaches.tell)
        let lawful = tell.indices.filter { stream.isLawful(at: $0) }.count
        #expect(lawful == stream.reaches.tell / 2)
    }

    @Test("consecutive tell glyphs differ in at least two attributes", arguments: Band.sieveServable)
    func tellVariesMaximally(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        for i in 1..<stream.reaches.tell {
            #expect(stream.glyphs[i].attributeDistance(to: stream.glyphs[i - 1]) >= 2)
        }
    }

    @Test("run-out glyphs differ from their predecessor in EXACTLY one attribute",
          arguments: Band.sieveServable)
    func runOutIsSingleAttributeSteps(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        for i in stream.reaches.runOutRange {
            #expect(stream.glyphs[i].attributeDistance(to: stream.glyphs[i - 1]) == 1)
        }
    }

    @Test("at least 40 % of adjacent run-out pairs straddle the law's boundary",
          arguments: Band.sieveServable)
    func runOutStraddlesTheBoundary(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        let pairs = stream.reaches.runOutRange
        let straddling = pairs.filter { stream.isLawful(at: $0) != stream.isLawful(at: $0 - 1) }.count
        #expect(Double(straddling) / Double(pairs.count) >= 0.40)
    }

    @Test("the body's lawful fraction sits inside the admit-rate window (§5.7)",
          arguments: Band.sieveServable)
    func bodyTracksTheLawsOwnP(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        let body = stream.reaches.bodyRange
        let fraction = Double(body.filter(stream.isLawful(at:)).count) / Double(body.count)
        #expect(fraction >= 0.05 && fraction <= 0.75)      // p ∈ [0.15, 0.60], ± sampling noise
    }

    // MARK: contextual priming

    @Test("a contextual stream carries an inert seed glyph that primes position 0 and is never scored")
    func contextualStreamsAreSeeded() {
        let stream = Corpora.sieveStream(band: .contextual, index: 0)
        let seed = try? #require(stream.seedGlyph)
        #expect(seed != nil)
        #expect(stream.seedHold == C.GateBand.seedHold)
        #expect(stream.isScored(seedGlyph: true) == false)
        // The verdict of glyph 0 is computed against the seed glyph, not against nothing.
        #expect(stream.previousGlyph(for: 0) == stream.seedGlyph)
    }

    @Test("a stateless band carries no seed glyph — there is no prev to prime",
          arguments: [Band.literal, .pair, .exclusive, .relational, .guarded])
    func statelessStreamsAreNotSeeded(_ band: Band) {
        #expect(Corpora.sieveStream(band: band, index: 0).seedGlyph == nil)
    }

    // MARK: determinism

    @Test("the stream is a pure function of (seed, law, band, tempoStep)",
          arguments: Band.sieveServable)
    func streamIsDeterministic(_ band: Band) {
        let seed = Corpora.seed(band: band, index: 7)
        let law = Law(generate(seed: seed, band: band, targetDelta: band.centre, mode: .sieve))
        var a = SplitMix64(seed: seed), b = SplitMix64(seed: seed)
        #expect(SieveStream.build(law: law, band: band, tempoStep: 1, using: &a)
                == SieveStream.build(law: law, band: band, tempoStep: 1, using: &b))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter Sieve`

Expect missing `SieveStream`, `SieveReaches`, `SieveReach`, `SieveGuardrail`,
`Corpora.sieveStreamsPerBand`, `Corpora.sieveStream(band:index:)`, `Corpora.knownBadSieveSeeds` and
`Glyph.attributeDistance(to:)`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveStream.swift` — `SieveStream`, `SieveReaches`, `SieveReach` |
| create | `HunchCore/Sources/Rounds/SieveGuardrail.swift` — S1–S5 as five separately testable predicates |
| modify | `HunchCore/Sources/Glyphs/Glyph.swift` — `attributeDistance(to:)`, if E02 has not already added it |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `sieveStreamsPerBand`, `sieveStream(band:index:)`, `knownBadSieveSeeds`, `SieveSeed` |
| create | `HunchCore/Tests/RoundsTests/SieveReachTests.swift` |
| create | `HunchCore/Tests/RoundsTests/SieveStreamGuardrailTests.swift` |
| modify | `tests.json` — six entries: S1, S2, S3, S4, S5, and the reaches-partition-by-subtraction rule |
| modify | `DECISIONS.md` — the 200-attempt-then-repair bound |

## Implementation notes

### The reaches are computed once, by subtraction, and never re-derived

```swift
public struct SieveReaches: Hashable, Sendable {
    public let glyphCount: Int
    public let tell: Int            // 12, always
    public let runOut: Int          // round(0.25 · N)
    public let body: Int            // N − 12 − runOut  ← the remainder

    public init(glyphCount: Int) {
        self.glyphCount = glyphCount
        tell = 12
        runOut = Int((0.25 * Double(glyphCount)).rounded())
        body = glyphCount - tell - runOut
        precondition(body >= 20, "§9.4 S5")
    }

    public var tellRange: Range<Int>    { 0..<tell }
    public var bodyRange: Range<Int>    { tell..<(tell + body) }
    public var runOutRange: Range<Int>  { (tell + body)..<glyphCount }
    public func reach(of index: Int) -> SieveReach
}
```

§9.4's decision paragraph is the reason the type exists rather than three `let`s at the call site:
*"12 + 0.85·N equals N only at N = 80 — every band but 6 was over-subscribed, band 1 by three
glyphs."* The subtraction is load-bearing for the score (`idealResolved` sums weights over reaches)
and for S1–S3, so it is fixed by construction. Assert the reproduced triple against §9.3's table
rather than restating it: the table's `12 / 33 / 15` at band 1 is what `SieveReaches(glyphCount: 60)`
must produce, and the test above derives it instead of copying it.

### Construction, reach by reach

```swift
public enum SieveStream {
    /// Pure over (law, band, tempoStep, rng). Nothing here reads a clock, a file or the environment.
    public static func build(law: Law, band: Band, tempoStep: Int,
                             using rng: inout some RandomNumberGenerator) -> Stream
}
```

**The tell** — 12 glyphs, exactly 6 lawful and 6 unlawful, the law's *pivotal* attributes varying
maximally, consecutive glyphs differing in ≥ 2 attributes. Build it as a constrained shuffle: draw
candidate lawful and unlawful glyphs from `law.table`'s two halves, then greedily order them so the
≥ 2-attribute step and the alternating-verdict constraint both hold. Pivotality is E05·T05's
`law.pivotalAttributes` — do not recompute it by permutation here.

**The body** — uniform over the deck subject to the law's own `p`. Literally: sample uniformly from
`Deck.all` using `rng`; the lawful fraction then *is* `p` by construction, which is why the test
asserts a window around `p` rather than an exact count. Do not stratify it to hit `p` exactly — that
would make the body a second tell.

**The run-out** — each glyph differs from its predecessor in exactly one attribute (a walk on the
4-dimensional 4-ary Hamming graph), and ≥ 40 % of adjacent pairs straddle the law's boundary. Build
it as a walk that prefers, at each step, a neighbour whose verdict differs from the current one,
falling back to any neighbour when the straddle quota is already met. The first run-out glyph's
predecessor is the last body glyph, so the walk is continuous across the reach boundary — §9.5 is
explicit that *no visible cue* marks a reach boundary, and a discontinuity in the walk would be one.

**Contextual bands** — `prev` comes from the stream's own adjacency. Position 0's `prev` is the
**seed glyph**, held inert in the gate for `C.GateBand.seedHold` before the stream starts. It is not
actionable, not scored, and not counted in `N` or in any reach. Model it as
`Stream.seedGlyph: Glyph?` — `nil` for the five stateless bands, because there is no `prev` to prime
and a seed glyph there would be a free glyph with no job.

### The attempt bound §9.4 does not state

§9.4 lists five guardrails and no attempt budget. Canon's generator uses **200 attempts then a
deterministic anchor** (§5.3, §5.7), and this task takes the same shape so the two are not two
policies:

1. Build the stream.
2. Check S1–S5. If all pass, done.
3. Otherwise **repair** rather than re-roll: S1 by forcing the missing attribute values into the tell
   at the positions with the most slack; S2 by swapping the offending fifth glyph with the nearest
   glyph of the other verdict; S3 by replacing a non-straddling tell pair. Repair is deterministic
   given the same RNG state.
4. Up to 200 repair passes, then fall back to a **deterministic anchor stream** for `(band, p)` —
   the same escape hatch the generator has, and equally exempt from the "prefer variety" pressure.

Record the bound in `DECISIONS.md` with the note that §9.4 does not state one, so a future reader
knows this is an engineering choice made against canon's precedent and not a transcription.

### S1–S5 as five predicates, ordered cheap → expensive

```swift
public enum SieveGuardrail {
    public static func s1(_ stream: Stream, law: Law) -> Bool          // ≥ 3 of 4 values, per named attribute, in the tell
    public static func s2(_ stream: Stream, law: Law) -> Bool          // no run of 5 sharing a verdict, anywhere
    public static func s3(_ stream: Stream, law: Law, band: Band) -> Bool  // contextual: ≥ 4 straddling pairs in the tell
    public static func s4(band: Band, tempoStep: Int) -> Bool          // the pitch invariant, at every r
    public static func s5(_ stream: Stream) -> Bool                    // partition, and body ≥ 20
    public static func all(_:law:band:tempoStep:) -> Bool
}
```

Two notes. **S2 is "anywhere", not "in the body"** — a run of five in the run-out is exactly as bad,
because it is a stretch the player can coast through. **S3 is vacuous outside band 5**, so it returns
`true` there rather than being skipped at the call site; a guardrail that is sometimes not called is a
guardrail that will eventually not be called at all. **S4 is a re-assertion of T02's invariant** and
delegates to the same predicate — it does not recompute `132 > 88`.

### `Corpora` additions

`Corpora.sieveStream(band:index:)` is a `static let`-backed cache of an immutable `Sendable` value
(the one sanctioned piece of shared state under `06 T10`), built once for the whole suite. A `static
var` is a data race. `Corpora.sieveStreamsPerBand` is a constant the tests cite rather than typing —
start at 200 and lower it only if the suite measures over ~0.4 s; if it needs more than that to be
convincing, the extra runs go to `.nightly`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveReachTests` green — all seven tests.
- [ ] `swift test --package-path HunchCore --filter SieveStreamGuardrailTests` green, and the whole SIEVE stream suite measures under 0.4 s.
- [ ] `SieveReaches(glyphCount:)` reproduces §9.3's tell/body/run-out triple for all six bands, asserted by derivation and not by a copied table.
- [ ] `grep -rn "SystemRandomNumberGenerator\|\.random(\|Date()\|UUID()" HunchCore/Sources/Rounds/` returns nothing.
- [ ] `grep -n "var rng\|inout some RandomNumberGenerator" HunchCore/Sources/Rounds/SieveStream.swift` shows the RNG only as a parameter; no stored property holds one.
- [ ] Each of S1–S5 has its own predicate, its own test and its own `tests.json` entry, and each is demonstrated to **fail** on a deliberately broken stream before the fix is reverted.
- [ ] `DECISIONS.md` records the 200-attempt-then-anchor bound and notes that §9.4 states no budget.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes merging S3 into S1 (both look at the tell), decline: they answer different questions and §9.9's BLIND-STREAM row names S3 alone as the prevention.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E14/T03: stream composition, the three reaches and guardrails S1–S5"`

## Out of scope

- Generating the law itself, and G1–G10 — **E06·T05/T06**. This task takes a `Law` and never makes one.
- `Law.admits(_:after:)` and the seed-glyph priming *semantics* — **E05·T03**. This task supplies the seed glyph; the evaluator decides what it means.
- Scoring the stream, and the weights' arithmetic role in `idealResolved` — **T05**.
- The inert seed's 1.5 s *presentation* in the gate — **T02** owns `C.GateBand.seedHold`; **T04** owns the `priming → streaming(.tell)` transition.
- Choosing the band and the tempo step — **T06** and **E11·T03**.
