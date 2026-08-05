# T06 — Difficulty mapping

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Difficulty mapping (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task's whole risk is a units confusion: §10.3 hands SIEVE a `targetδ` in **difficulty units** `[0.000, 1.000)` and feeding it a logit returns a negative band. The skill's naming pass fixes `targetδ → targetDelta` and `δ_served → servedDelta`, and its type-choice rules are what turn "difficulty units, never a logit" from a comment into a type. It also carries the ruling that the generator is pure over its five arguments, which is what this task calls. |

`hunch-bench-instruments` is **not** loaded. Nothing here is drawn, and the palette ceiling — which
*is* band-derived — is E09·T04's and reads `maxBandEverServed`, never this.

## Objective

At the end of this task `SieveDifficulty` turns a `targetδ` in difficulty units into the pair SIEVE
actually needs — a law band capped at 6 and a tempo step 0–3 solved as the remainder — and reports
back the two distinct quantities the rest of the system consumes: `δ_SIEVE`, capped at 0.874, and the
effective `band_SIEVE`, capped at 7. Two consecutive losses drop `s` to 0 before ever reducing
`lawBand`, because speed is reduced before the idea is.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.7 | `δ_SIEVE = clamp(difficulty(law) + 0.125·s/3, 0.0, 0.999)`; `band_SIEVE = floor(δ_SIEVE/0.125) + 1`; the three-line derivation from `targetδ` — `lawBand = min(6, floor(targetδ/0.125)+1)`, `generate(seed, lawBand, min(targetδ, 0.749), .sieve, avoid)`, `s = clamp(round(3·(targetδ − difficulty(law))/0.125), 0, 3)`; the ceiling `δ_SIEVE = 0.874` at `lawBand 6, s 3` and the effective `band_SIEVE = 7`; **the two quantities are distinct and both are needed**; canon's two-consecutive-failures rule applies unchanged, which in SIEVE means dropping `s` to 0 first and only then reducing `lawBand` |
| `GAME_DESIGN.md` | §9.3 | SIEVE serves law bands 1–6 only, and why: bands 7 and 8 are not learnable from a passive stream in 45 s. **Ability above band 6 is absorbed by the tempo step, not by the law** |
| `GAME_DESIGN.md` | §10.3 | steps 6, 8, 11, 12 and 13 — the `δ ≤ 2.99` logit clamp, the `1…7` per-mode band clamp, `targetδ` in difficulty units, `δ_served = 8·targetδ − 4` as what the estimator consumes, and the dispatch row that names §9.7 |
| `GAME_DESIGN.md` | §9.10 | SIEVE's row: δ ceiling **0.874**, difficulty knobs *law band 1–6 + tempo step `s` 0–3*, law source *generated, bands 1–6* |
| `GAME_DESIGN.md` | §5.3, §5.7 | `generate(seed:band:targetδ:mode:avoid:)`, pure over five arguments; the ±0.02 G8 proximity tolerance and the 200-attempt bound this task inherits rather than re-implements |
| `GAME_DESIGN.md` | §10.7 | the relief ladder that produces "two consecutive losses"; the *consumption* is E11's, the SIEVE-specific ordering is this task's |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N1, N33 | `targetDelta`, `servedDelta`, `ability` — Greek identifiers and underscores are out |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveDifficultyTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("SIEVE difficulty mapping — §9.7", .tags(.unit, .presubmission))
struct SieveDifficultyTests {

    // MARK: lawBand, capped at 6

    @Test("lawBand = min(6, floor(targetδ/0.125)+1), across the whole difficulty range")
    func lawBandIsQuantisedAndCapped() {
        for step in 0..<1000 {
            let targetDelta = Double(step) / 1000.0
            let expected = min(6, Int((targetDelta / 0.125).rounded(.down)) + 1)
            #expect(SieveDifficulty.lawBand(for: targetDelta).rawValue == expected)
        }
    }

    @Test("SIEVE never serves a band-7 or band-8 law, at any targetδ")
    func neverServesTheTopTwoBands() {
        for step in 0..<1000 {
            let band = SieveDifficulty.lawBand(for: Double(step) / 1000.0)
            #expect(Band.sieveServable.contains(band))
            #expect(band <= .guarded)
        }
    }

    @Test("the generator is called with min(targetδ, 0.749), so band 6 is never asked for band-7 difficulty")
    func generatorTargetIsClamped() {
        #expect(SieveDifficulty.generatorTarget(for: 0.500) == 0.500)
        #expect(SieveDifficulty.generatorTarget(for: 0.749) == 0.749)
        #expect(SieveDifficulty.generatorTarget(for: 0.900) == 0.749)
        #expect(SieveDifficulty.generatorTarget(for: 0.999) == 0.749)
    }

    // MARK: the tempo step, solved as the remainder

    @Test("s = clamp(round(3·(targetδ − difficulty(law))/0.125), 0, 3)")
    func tempoStepIsTheRemainder() {
        // A law exactly at target leaves no remainder.
        #expect(SieveDifficulty.tempoStep(targetDelta: 0.500, lawDifficulty: 0.500) == 0)
        // One third of a band's width above the law is one step.
        #expect(SieveDifficulty.tempoStep(targetDelta: 0.5417, lawDifficulty: 0.500) == 1)
        // A full band above is three steps, capped.
        #expect(SieveDifficulty.tempoStep(targetDelta: 0.625, lawDifficulty: 0.500) == 3)
        #expect(SieveDifficulty.tempoStep(targetDelta: 0.999, lawDifficulty: 0.500) == 3)
        // A law harder than the target does not produce a negative step.
        #expect(SieveDifficulty.tempoStep(targetDelta: 0.400, lawDifficulty: 0.500) == 0)
    }

    // MARK: the two distinct quantities

    @Test("δ_SIEVE = clamp(difficulty(law) + 0.125·s/3, 0, 0.999)",
          arguments: [(0.500, 0, 0.500), (0.500, 1, 0.5417), (0.500, 3, 0.625),
                      (0.749, 3, 0.874), (0.990, 3, 0.999)])
    func deltaSieveFromLawAndStep(_ lawDifficulty: Double, _ step: Int, _ expected: Double) {
        #expect(isApproximatelyEqual(SieveDifficulty.deltaSieve(lawDifficulty: lawDifficulty,
                                                                tempoStep: step),
                                     expected, absoluteTolerance: 0.0005))
    }

    @Test("δ_SIEVE reaches exactly 0.874 at lawBand 6 / s 3, and never exceeds it in practice")
    func deltaSieveCeiling() {
        let atCeiling = SieveDifficulty.deltaSieve(lawDifficulty: 0.749, tempoStep: 3)
        #expect(isApproximatelyEqual(atCeiling, 0.874, absoluteTolerance: 0.0005))
        for step in 0..<1000 {
            let targetDelta = Double(step) / 1000.0
            let serving = SieveDifficulty.serving(targetDelta: targetDelta,
                                                  lawDifficulty: SieveDifficulty
                                                      .generatorTarget(for: targetDelta))
            #expect(serving.deltaSieve <= 0.874 + 1e-9)
        }
    }

    @Test("band_SIEVE = floor(δ_SIEVE/0.125)+1 and reaches 7 — but the LAW band is still ≤ 6")
    func bandSieveReachesSevenWhileTheLawDoesNot() {
        let serving = SieveDifficulty.serving(targetDelta: 0.874, lawDifficulty: 0.749)
        #expect(serving.lawBand == .guarded)          // 6
        #expect(serving.bandSieve == 7)
        #expect(serving.tempoStep == 3)
    }

    @Test("band_SIEVE never exceeds 7, at any targetδ")
    func bandSieveCeiling() {
        for step in 0..<1000 {
            let targetDelta = Double(step) / 1000.0
            let serving = SieveDifficulty.serving(targetDelta: targetDelta,
                                                  lawDifficulty: SieveDifficulty
                                                      .generatorTarget(for: targetDelta))
            #expect(serving.bandSieve <= 7)
            #expect(serving.bandSieve >= 1)
        }
    }

    @Test("lawBand and bandSieve are two quantities and diverge above 0.749")
    func theTwoQuantitiesAreDistinct() {
        let low = SieveDifficulty.serving(targetDelta: 0.300, lawDifficulty: 0.300)
        #expect(low.lawBand.rawValue == low.bandSieve)
        let high = SieveDifficulty.serving(targetDelta: 0.874, lawDifficulty: 0.749)
        #expect(high.lawBand.rawValue != high.bandSieve)
    }

    // MARK: units — a logit must not silently produce a band

    @Test("a logit is not a difficulty and the mapping refuses it")
    func aLogitTraps() {
        #expect(SieveDifficulty.lawBandIfValid(for: -2.0) == nil)
        #expect(SieveDifficulty.lawBandIfValid(for: 1.0) == nil)     // [0.000, 1.000) is half-open
        #expect(SieveDifficulty.lawBandIfValid(for: 3.99) == nil)
        #expect(SieveDifficulty.lawBandIfValid(for: 0.0) != nil)
        #expect(SieveDifficulty.lawBandIfValid(for: 0.999) != nil)
    }

    // MARK: the two-consecutive-losses rule

    @Test("two consecutive losses drop s to 0 BEFORE reducing lawBand — speed before the idea",
          arguments: [(Band.guarded, 3, Band.guarded, 0),
                      (.guarded, 1, .guarded, 0),
                      (.guarded, 0, .contextual, 0),
                      (.literal, 0, .literal, 0)])          // band 1 has nowhere lower
    func speedIsReducedBeforeTheIdea(_ band: Band, _ step: Int,
                                     _ expectedBand: Band, _ expectedStep: Int) {
        let relieved = SieveDifficulty.relieved(lawBand: band, tempoStep: step)
        #expect(relieved.lawBand == expectedBand)
        #expect(relieved.tempoStep == expectedStep)
    }

    @Test("repeated relief walks s down to 0, then lawBand down to 1, and stops")
    func reliefTerminates() {
        var current = (lawBand: Band.guarded, tempoStep: 3)
        for _ in 0..<20 { current = SieveDifficulty.relieved(lawBand: current.lawBand,
                                                             tempoStep: current.tempoStep) }
        #expect(current.lawBand == .literal)
        #expect(current.tempoStep == 0)
    }

    // MARK: what the estimator sees

    @Test("servedDelta is derived from band_SIEVE's difficulty, not from the law's band")
    func servedDeltaUsesTheEffectiveBand() {
        let serving = SieveDifficulty.serving(targetDelta: 0.874, lawDifficulty: 0.749)
        #expect(isApproximatelyEqual(serving.servedDelta, 8 * serving.deltaSieve - 4,
                                     absoluteTolerance: 1e-9))
    }

    // MARK: end to end, against the generator

    @Test("a served SIEVE round is always a band 1–6 law whose δ_SIEVE tracks the target",
          arguments: Band.sieveServable)
    func endToEnd(_ band: Band) {
        for index in 0..<Corpora.lawsPerBand / 50 {
            let seed = Corpora.seed(band: band, index: index)
            let targetDelta = band.centre
            let serving = SieveDifficulty.serve(seed: seed, targetDelta: targetDelta, avoid: [])
            #expect(Band.sieveServable.contains(serving.lawBand))
            #expect((0...3).contains(serving.tempoStep))
            #expect(serving.deltaSieve <= 0.874 + 1e-9)
            #expect(abs(serving.deltaSieve - targetDelta) <= 0.125 / 3 + 0.021)
        }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveDifficultyTests`

Expect missing `SieveDifficulty`, `SieveServing` and `Band.centre`. Confirm `aLogitTraps` fails
because `lawBandIfValid` does not exist, not because a logit happens to produce a band that is also
`nil`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SieveDifficulty.swift` — `SieveDifficulty`, `SieveServing` |
| modify | `HunchCore/Sources/Ladder/ServingPolicy.swift` — step 13's SIEVE dispatch calls `SieveDifficulty.serve`; the file exists from **E11·T03** and this is the one line it gains |
| modify | `HunchCore/Sources/Rounds/SieveRunState.swift` — carry `SieveServing` so T08 can freeze it |
| create | `HunchCore/Tests/RoundsTests/SieveDifficultyTests.swift` |
| modify | `tests.json` — five entries: lawBand ≤ 6, band_SIEVE ≤ 7, δ_SIEVE ≤ 0.874, logit refusal, speed-before-idea |

## Implementation notes

### The two quantities, in one value

```swift
public struct SieveServing: Hashable, Sendable {
    public let lawBand: Band            // 1…6 — gates the GENERATOR
    public let tempoStep: Int           // 0…3 — the remainder, expressed as speed
    public let deltaSieve: Double       // ≤ 0.874
    public let bandSieve: Int           // 1…7 — what the RASCH UPDATE and §10.3's clamp see
    public let servedDelta: Double      // 8·deltaSieve − 4, in logits, for §10.2's estimator
}
```

§9.7's own sentence is the API contract and belongs in the doc comment verbatim in spirit: *"the two
quantities are distinct and both are needed: `lawBand ≤ 6` gates the generator, `band_SIEVE ≤ 7` is
what the Rasch update and §10.3's per-mode clamp see."* Two `Int`s in one struct with different
names and different ceilings is the only shape in which a caller cannot accidentally use one for the
other. A single `band` field would be the exact bug §9.7 spends a paragraph preventing.

Note the direction of travel: `servedDelta` is computed from `deltaSieve`, which includes the tempo
step. That matters — the player really did face a harder round because the stream was faster, and
the estimator has to be told so, or every tempo step is free difficulty the ladder never learns from.

### The three-line derivation, and where the generator sits

```swift
public static func serve(seed: UInt64, targetDelta: Double, avoid: Set<UInt64>) -> SieveServing {
    precondition((0.0..<1.0).contains(targetDelta), "§10.3 hands SIEVE difficulty units, never a logit")

    let band = lawBand(for: targetDelta)                                    // min(6, floor(δ/0.125)+1)
    let node = generate(seed: seed, band: band,
                        targetDelta: generatorTarget(for: targetDelta),     // min(targetδ, 0.749)
                        mode: .sieve, avoid: avoid)
    let lawDifficulty = difficulty(of: Law(node))
    let step = tempoStep(targetDelta: targetDelta, lawDifficulty: lawDifficulty)
    return serving(targetDelta: targetDelta, lawDifficulty: lawDifficulty, tempoStep: step, band: band)
}
```

Three things this ordering fixes. **`s` is solved from the law that was actually generated**, not
from the target — G8 only guarantees `difficulty ∈ [lo, hi)` and within ±0.02 of `targetδ`, so the
realised law can sit up to 0.02 off and the remainder has to absorb it. **`generatorTarget` clamps at
0.749**, the top of band 6's range, so a `targetδ` of 0.90 does not ask a band-6 generator for
band-8 difficulty and burn all 200 attempts into the family anchor. **`avoid` is passed straight
through** — the novelty ring, the per-band soft-avoid and today's Anomaly are E11·T06's assembly and
this function must not add to or filter them.

### `lawBandIfValid` and the units guard

```swift
/// `nil` when the argument is not a difficulty in `[0.000, 1.000)`. §10.3's own warning:
/// `floor(logit/0.125)+1` on a logit of −2 returns band −15.
public static func lawBandIfValid(for targetDelta: Double) -> Band?
```

Ship both spellings: `lawBand(for:)` with a `precondition` for the production path, and
`lawBandIfValid(for:)` returning `Double?` for the test. A `precondition` alone cannot be asserted in
Swift Testing without an exit test, and an exit test for a units error is disproportionate; a
`nil`-returning sibling is five lines and is directly testable. Both share one implementation.

### The relief rule, which is SIEVE's alone

```swift
/// Canon's two-consecutive-losses rule drops a full band. In SIEVE a "band" is two knobs, so the
/// order is fixed: `s` to 0 first, and only then `lawBand` down one. §9.7 — *speed is reduced
/// before the idea is.*
public static func relieved(lawBand: Band, tempoStep: Int) -> (lawBand: Band, tempoStep: Int) {
    if tempoStep > 0 { (lawBand, 0) }
    else if lawBand > .literal { (Band(rawValue: lawBand.rawValue - 1)!, 0) }
    else { (.literal, 0) }
}
```

Two notes. It drops `s` **to 0**, not by one — canon's rule is "a full band", and the tempo step
spans exactly one band's worth of difficulty (`0.125·3/3`), so the whole step is the full band.
And it is idempotent at the floor: band 1 with `s = 0` has nowhere lower, and §10.7's floor rescue
takes over there — do not invent a seventh, easier thing for SIEVE to do.

This function is **called by** E11·T04's relief ladder and does not implement it. `consecutiveLosses`,
`relief` and the pressure term are `ServingState`'s; this is the SIEVE-shaped translation of one of
their outcomes.

### The `avoid` set and the 200 attempts are not re-implemented

`generate` already owns the attempt bound, the family anchor fallback and G8's ±0.02 tolerance
(§5.3, E06·T06). This task calls it once and reads what came back. If the fallback fires, `s` absorbs
the difference and the round is still served — which is why the end-to-end test asserts
`|deltaSieve − targetDelta| ≤ 0.125/3 + 0.021` (one tempo step of granularity plus G8's tolerance)
rather than an exact match.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveDifficultyTests` green — all 13 tests, including the 1,000-point sweeps for `lawBand ≤ 6`, `bandSieve ≤ 7` and `deltaSieve ≤ 0.874`.
- [ ] `grep -n "targetδ\|δ_served\|θ" HunchCore/Sources/Rounds/SieveDifficulty.swift` returns nothing — Greek identifiers are out (`N1`).
- [ ] `SieveServing` has both `lawBand: Band` and `bandSieve: Int` as separate stored properties, and no accessor collapses them.
- [ ] `grep -n "0.749\|0.874" HunchCore/Sources/Rounds/SieveDifficulty.swift` shows each exactly once, each with its §9.7 citation.
- [ ] `SieveDifficulty.serve` calls `generate` exactly once, with `avoid` passed straight through and never mutated.
- [ ] `tests.json` carries the five entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes collapsing `lawBand` and `bandSieve`, decline and point at §9.7's paragraph.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically whether any path can reach `generate` with a band above 6 or a `targetDelta` above 0.749.
4. Commit: `git commit -m "E14/T06: SIEVE difficulty mapping — lawBand, tempo step and the two ceilings"`

## Out of scope

- §10.3's thirteen serving steps, its `δ ≤ 2.99` logit clamp and its `1…7` per-mode band clamp — **E11·T03**. This task is step 13's SIEVE branch and nothing above it.
- `reach`, `relief`, `consecutiveLosses` and the pressure term — **E11·T04**. This task translates one of their outcomes into two knobs.
- Assembling `avoid` — **E11·T06**.
- The generator, G1–G10 and the family anchor — **E06**.
- Freezing `lawBand`, `s` and `servedDelta` across a void — **T08**.
- The palette ceiling, which reads `maxBandEverServed` and never `lawBand` — **E09·T04**.
- Surfacing any of this as a number to the player — forbidden outright (§10.5, **E11·T09**).
