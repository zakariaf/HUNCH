# T05 — The five Profile axes

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | nothing (may run in parallel with T01–T04) |
| **Delivers** | Five axes (PROFILE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The five identifiers `induction`, `retention`, `flexibility`, `restraint`, `tempo` are code-only and must never become anything a translator can reach — this skill's naming pass carries that rule (`08 §3`'s Profile row). It also rules that the whole of this task is core: five formulas over a transcript value are a pure function, so they run in the fast suite and never see a view. |
| `hunch-swift-testing` | Monotonicity is a *property*, not an example, and there are five of them. This skill owns the parameterised-property shape, the `isApproximatelyEqual(_:_:absoluteTolerance:)` rule (swift-numerics is banned so `#expect(a == b)` on a `Double` is not available), and the ban on `for` loops in tests that this task's five sweeps have to work around by parameterising over the axis. |

## Objective

At the end of this task each of the five axes has exactly one sample formula, in one file, oriented so
that more is always more of the thing the vertex is named for — Tempo samples `par/probes`, not
`probes/par`, so the efficient player is pulled *toward* the Tempo vertex. Five shipped monotonicity
tests assert that a strictly better transcript never produces a smaller sample.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.9 | **the single normative table.** The five sample formulas, the `Feeds` and `w` columns, the direction rule, the `par` clause, SIEVE's two suppressions, the bands-5-and-7 margin skip, and the Induction-is-a-mean decision |
| `GAME_DESIGN.md` | §7.8 | `R` — *"probes from the first contradicting verdict to the sealing declaration"* — and the sentence that §7.8 defines the quantity and **not** the axis |
| `GAME_DESIGN.md` | §8.7 | `hit`, `answer`, `A`, `order`, and the worked round whose Retention sample is `(3 − 1)/4 = 0.50` |
| `GAME_DESIGN.md` | §9.6 | the SIEVE emission `(median gate-entry-to-tap latency over hits, mean window over the same glyphs, ratio, completion)`, and its warning that SIEVE has no 0–12 quantity and no "tier" |
| `GAME_DESIGN.md` | §9.5 | *"a miss is caution and a foul is a false claim"*, and that fouls do not accrue during the tell — the basis for SIEVE's Restraint `d` |
| `GAME_DESIGN.md` | §5.7, §7.7 | `par(b)` and `par_DRIFT(b)`; **Flexibility's `L*` uses canon's `par(b)` in every mode, never `par_DRIFT`** |
| `GAME_DESIGN.md` | §5.2 | `\|H_band\|` — the eight band populations the Restraint margin's denominator reads |
| `GAME_DESIGN.md` | §10.5 | the serving-parameter ↔ axis table, and its rule that the two lists must never be confused |
| `GAME_DESIGN.md` | §11.10, §11.11 | why direction is fixed by geometry: the vertex radius grows with the value, so the sample must be oriented *more is more* |
| `ios-swift-guide/06-TESTING.md` | T21, T30, T42 | parameterise over the five axes rather than looping; tag on both axes; never assert a golden order out of an RNG |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/ProfileAxisTests.swift`:

```swift
import Foundation
import Testing
import Archive
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("The five Profile axes — §11.9's single normative table", .tags(.unit, .presubmission))
struct ProfileAxisTests {

    // MARK: - fixtures

    private func probe(band: Band = .relational, outcome: Outcome = .solved, strikes: Int = 0,
                       probes: Int = 10, duplicatePairs: Int = 0,
                       liveHypotheses: Int? = 8) -> RoundTranscript {
        RoundTranscript(mode: .probe, band: band, outcome: outcome, strikes: strikes,
                        probesUsed: probes, par: band.par, duplicatePairProbes: duplicatePairs,
                        liveHypotheses: liveHypotheses, isAnomaly: false,
                        drift: nil, echo: nil, sieve: nil, strikeRecovery: nil)
    }

    private func sample(_ axis: ProfileAxis, _ t: RoundTranscript) -> Double? {
        AxisSampling.samples(for: t).first { $0.axis == axis }?.value
    }

    private func weight(_ axis: ProfileAxis, _ t: RoundTranscript) -> Double? {
        AxisSampling.samples(for: t).first { $0.axis == axis }?.weight
    }

    // MARK: - Induction

    @Test("Induction solved is (band − 1)/7 and lost is clamp((band − 2)/7, 0, 1)",
          arguments: Band.allCases)
    func inductionFormula(_ band: Band) {
        let b = Double(band.rawValue)
        #expect(isApproximatelyEqual(sample(.induction, probe(band: band, outcome: .solved))!,
                                     (b - 1) / 7, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(sample(.induction, probe(band: band, outcome: .lostAtCap))!,
                                     max(0, min(1, (b - 2) / 7)), absoluteTolerance: 1e-12))
    }

    @Test("ECHO emits no Induction sample — its law is selected from the pool, not served at a band")
    func echoEmitsNoInduction() {
        #expect(sample(.induction, echoTranscript(hit: 4, answerCount: 4, a: 4, order: 1)) == nil)
    }

    @Test("SIEVE emits Induction — §11.9's own SIEVE paragraph says so")
    func sieveEmitsInduction() {
        #expect(sample(.induction, sieveTranscript(fouls: 0, medianLatency: 0.3, meanWindow: 0.6)) != nil)
    }

    // MARK: - Retention

    @Test("Retention from ECHO reproduces §8.7's worked round exactly")
    func retentionMatchesTheWorkedEchoRound() {
        // §8.7: hit = 3, |answer| = 4, A = 4 → (3 − 1)/4 = 0.50
        let s = sample(.retention, echoTranscript(hit: 3, answerCount: 4, a: 4, order: 0.667))!
        #expect(isApproximatelyEqual(s, 0.50, absoluteTolerance: 1e-9))
    }

    @Test("Retention from ECHO floors at zero when intrusions outnumber lawful placements")
    func retentionFloorsAtZero() {
        #expect(isApproximatelyEqual(sample(.retention, echoTranscript(hit: 1, answerCount: 6, a: 4))!,
                                     0, absoluteTolerance: 1e-12))
    }

    @Test("Retention from PROBE is 1 − duplicatePairProbes / probes at weight 0.35")
    func retentionFromProbe() {
        let t = probe(probes: 20, duplicatePairs: 3)
        #expect(isApproximatelyEqual(sample(.retention, t)!, 1 - 3.0 / 20, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(weight(.retention, t)!, 0.35, absoluteTolerance: 1e-12))
    }

    // MARK: - Flexibility

    @Test("Flexibility reproduces §11.9's worked DRIFT transcript")
    func flexibilityMatchesTheWorkedDriftRound() {
        // §7.7 / §11.9: band 5, par(b) = 23, R = 16, L* = 0.45·23 = 10.35 → 0.303
        let t = driftTranscript(band: .contextual, reDeclarationLatency: 16)
        #expect(isApproximatelyEqual(sample(.flexibility, t)!, 0.303, absoluteTolerance: 5e-4))
        #expect(isApproximatelyEqual(weight(.flexibility, t)!, 1.0, absoluteTolerance: 1e-12))
    }

    /// The trap §11.9 names: `L*` reads canon's `par(b)`, NEVER `par_DRIFT(b)`.
    @Test("Flexibility's L* uses canon's par, not par_DRIFT")
    func flexibilityUsesCanonPar() {
        let t = driftTranscript(band: .contextual, reDeclarationLatency: 16)
        let wrong = clamp01((2 * 0.45 * Double(Band.contextual.parDrift) - 16)
                            / (1.5 * 0.45 * Double(Band.contextual.parDrift)))
        #expect(!isApproximatelyEqual(sample(.flexibility, t)!, wrong, absoluteTolerance: 1e-3))
    }

    @Test("a first strike in any mode emits a strike-recovery Flexibility sample at weight 0.5",
          arguments: [Mode.probe, .drift])
    func strikeRecoveryEmitsFlexibility(_ mode: Mode) {
        let t = strikeRecoveryTranscript(mode: mode, band: .relational, reDeclarationLatency: 4)
        // L* = 0.30 · par(4) = 0.30 · 20 = 6.0 → clamp((12 − 4) / 9) = 0.889
        #expect(isApproximatelyEqual(sample(.flexibility, t)!, 8.0 / 9.0, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(weight(.flexibility, t)!, 0.5, absoluteTolerance: 1e-12))
    }

    @Test("a round with neither a hinge nor a strike emits no Flexibility sample")
    func noHingeNoStrikeNoSample() {
        #expect(sample(.flexibility, probe()) == nil)
    }

    // MARK: - Restraint

    @Test("the discrete d ladder is §11.9's four values, in §11.9's order")
    func discreteDLadder() {
        #expect(isApproximatelyEqual(Restraint.d(outcome: .solved, strikes: 0), 1.00, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Restraint.d(outcome: .lostAtCap, strikes: 0), 0.60, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Restraint.d(outcome: .solved, strikes: 1), 0.35, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Restraint.d(outcome: .lostOnStrike, strikes: 2), 0.00, absoluteTolerance: 1e-12))
    }

    /// This ordering is deliberate and is NOT outcome quality: a cap loss with zero strikes restrained
    /// better than a solve after a wrong declaration. Anyone "fixing" it breaks the axis.
    @Test("a cap-loss with zero strikes outranks a solve after one strike")
    func capLossOutranksASolveAfterAStrike() {
        #expect(Restraint.d(outcome: .lostAtCap, strikes: 0) > Restraint.d(outcome: .solved, strikes: 1))
    }

    @Test("the margin is 1 − log2(H_live)/log2(|H_band|), clamped")
    func marginFormula() {
        // Band 4: |H| = 2,322. H_live = 2,322 → m = 0. H_live = 1 → m = 1.
        #expect(isApproximatelyEqual(Restraint.margin(liveHypotheses: Band.relational.population,
                                                      band: .relational), 0, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(Restraint.margin(liveHypotheses: 1, band: .relational),
                                     1, absoluteTolerance: 1e-9))
    }

    @Test("Restraint is 0.6·d + 0.4·m where a margin exists, and d alone where it does not",
          arguments: [Band.contextual, .composite])                    // bands 5 and 7
    func restraintSkipsTheMarginAtFiveAndSeven(_ band: Band) {
        let withMargin = probe(band: .relational, outcome: .solved, liveHypotheses: 1)
        #expect(isApproximatelyEqual(sample(.restraint, withMargin)!,
                                     0.6 * 1.0 + 0.4 * 1.0, absoluteTolerance: 1e-9))

        let skipped = probe(band: band, outcome: .solved, liveHypotheses: nil)
        #expect(isApproximatelyEqual(sample(.restraint, skipped)!, 1.00, absoluteTolerance: 1e-9))
    }

    @Test("SIEVE's d is read from fouls against the three that end a run, and its margin is skipped")
    func sieveRestraint() {
        #expect(isApproximatelyEqual(sample(.restraint, sieveTranscript(fouls: 0))!, 1.0,
                                     absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(sample(.restraint, sieveTranscript(fouls: 3))!, 0.0,
                                     absoluteTolerance: 1e-9))
    }

    @Test("ECHO emits no Restraint sample — there is no declaration and no d")
    func echoEmitsNoRestraint() {
        #expect(sample(.restraint, echoTranscript(hit: 4, answerCount: 4, a: 4)) == nil)
    }

    // MARK: - Tempo, and the direction rule

    /// §11.9: "Tempo therefore samples `par/probes`, not canon's `probes/par`". If this inverts, the
    /// efficient player is pulled AWAY from the Tempo vertex and §11.10's silhouette is drawn wrong.
    @Test("Tempo samples par/probes — the efficient player scores HIGHER")
    func tempoIsParOverProbes() {
        let efficient = sample(.tempo, probe(band: .relational, probes: 10))!   // par 20
        let wasteful = sample(.tempo, probe(band: .relational, probes: 40))!
        #expect(efficient > wasteful)
        #expect(isApproximatelyEqual(efficient, 1.0, absoluteTolerance: 1e-12))   // min(1, 20/10)
        #expect(isApproximatelyEqual(wasteful, 0.5, absoluteTolerance: 1e-12))    // min(1, 20/40)
    }

    @Test("a lost round's Tempo is half the solved value at the same probe count")
    func lostTempoIsHalved() {
        let solved = sample(.tempo, probe(band: .relational, probes: 40, outcome: .solved))!
        let lost = sample(.tempo, probe(band: .relational, probes: 40, outcome: .lostAtCap))!
        #expect(isApproximatelyEqual(lost, 0.5 * solved, absoluteTolerance: 1e-12))
    }

    @Test("SIEVE's Tempo is 1 − median latency / mean window, at weight 0.7")
    func sieveTempo() {
        let t = sieveTranscript(fouls: 0, medianLatency: 0.15, meanWindow: 0.60)
        #expect(isApproximatelyEqual(sample(.tempo, t)!, 0.75, absoluteTolerance: 1e-9))
        #expect(isApproximatelyEqual(weight(.tempo, t)!, 0.7, absoluteTolerance: 1e-12))
    }

    @Test("SIEVE emits NO Tempo sample under step mode or steady stream, but still emits the rest",
          arguments: [SieveRate.voiceOverStep, .steadyStream])
    func sieveFixedRateEmitsNoTempo(_ rate: SieveRate) {
        let t = sieveTranscript(fouls: 0, medianLatency: 0.15, meanWindow: 0.60, rate: rate)
        #expect(sample(.tempo, t) == nil)
        #expect(sample(.induction, t) != nil)
        #expect(sample(.restraint, t) != nil)
    }

    // MARK: - the shipped monotonicity property, one per axis

    /// §11.9: "A test asserts monotonicity per axis: for each axis, a strictly better transcript
    /// never produces a smaller sample."
    @Test("a strictly better transcript never produces a smaller sample", arguments: ProfileAxis.allCases)
    func monotone(_ axis: ProfileAxis) {
        let ladder = MonotonicityCorpus.ascending(for: axis)     // 64 transcripts, weakly improving
        #expect(ladder.count >= 64)
        let samples = ladder.compactMap { sample(axis, $0) }
        #expect(samples.count == ladder.count)                   // every rung emits
        #expect(zip(samples, samples.dropFirst())
            .allSatisfy { $0.1 >= $0.0 - 1e-12 })                // never smaller
        #expect(samples.last! > samples.first! + 1e-6)           // and the ladder actually moves
    }

    @Test("every sample lands in [0, 1] over the whole corpus", arguments: ProfileAxis.allCases)
    func samplesAreBounded(_ axis: ProfileAxis) {
        let all = MonotonicityCorpus.ascending(for: axis) + MonotonicityCorpus.adversarial(for: axis)
        #expect(all.compactMap { sample(axis, $0) }.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}
```

`MonotonicityCorpus` lives in `HunchTestSupport` and is a `static let` of immutable `Sendable`
values (`06 T10`). For each axis it returns a ladder of 64 transcripts in which exactly one input is
improved at each rung — probes falling for Tempo, `R` falling for Flexibility, `hit` rising and
`|answer|` falling for Retention, band rising for Induction, `d` and `m` rising for Restraint — with
everything else held fixed.

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ProfileAxisTests`
Confirm the failures are missing symbols (`ProfileAxis`, `AxisSampling`, `RoundTranscript`,
`Restraint`, `MonotonicityCorpus`), not a malformed test. Once the shapes compile, watch
`tempoIsParOverProbes` fail if the formula is inverted, and `flexibilityUsesCanonPar` fail if
`par_DRIFT` was used. Both are the bugs this suite exists to catch.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/ProfileAxis.swift` — the five identifiers and their locked order |
| create | `HunchCore/Sources/Archive/RoundTranscript.swift` — the input value, one per settled round |
| create | `HunchCore/Sources/Archive/AxisSampling.swift` — the five formulas, and nothing else |
| create | `HunchCore/Sources/Archive/Restraint.swift` — `d(outcome:strikes:)` and `margin(liveHypotheses:band:)` |
| create | `HunchCore/Sources/HunchTestSupport/MonotonicityCorpus.swift` |
| create | `HunchCore/Tests/ArchiveTests/ProfileAxisTests.swift` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `population` if E05·T06 has not already added it |
| modify | `tests.json` — twelve entries |
| modify | `DECISIONS.md` — the four `Feeds` rulings below |

## Implementation notes

### The five identifiers, and where they may appear

```swift
/// §11.11 P3: these five identifiers are internal, used in code and in GAME_DESIGN.md ONLY. They
/// never enter Localizable.xcstrings in any form, visible or spoken, and never appear in the app.
public enum ProfileAxis: Int, CaseIterable, Sendable {
    case induction = 0, retention, flexibility, restraint, tempo    // §11.10's locked vertex order
}
```

The raw values are the vertex indices §11.10 locks (`θᵢ = −90° + i·72°`), so `allCases` order *is*
drawing order and no second table exists. Hygiene check 13 greps the catalog for these five words;
this is the only file that may spell them alongside a doc comment.

### The transcript

One value per settled round, assembled at `settled` by whichever mode owns the round, carrying only
quantities the mode sections already define. It carries **no derived axis quantity** — every formula
lives in `AxisSampling` and reads raw fields, which is what stops a second spelling appearing inside
`DriftSchedule` or `EchoCast`.

```swift
public struct RoundTranscript: Equatable, Sendable {
    public let mode: Mode
    public let band: Band                    // the band SERVED. For ECHO this is the pool law's band.
    public let outcome: Outcome
    public let strikes: Int
    public let probesUsed: Int
    public let par: Int                      // the MODE's own par — §5.7's in PROBE, §7.7's in DRIFT
    public let duplicatePairProbes: Int      // §11.9's PROBE Retention quantity
    public let liveHypotheses: Int?          // H_live; nil at bands 5 and 7 and in SIEVE — T07 fills it
    public let isAnomaly: Bool
    public let drift: DriftTranscript?       // §7.8: reDeclarationLatency (R), hinge fired
    public let echo: EchoTranscript?         // §8.7: hit, answerCount, a, order, replayed
    public let sieve: SieveTranscript?       // §9.6: medianLatency, meanWindow, foulsOutsideTell, rate
    public let strikeRecovery: StrikeRecovery?   // R measured from the FIRST strike, any mode
}
```

### The five formulas

Each is three to six lines, and each names its §11.9 row in a doc comment. Cite; do not restate the
numbers in a second comment.

- **Induction** — `solved: (band − 1)/7`, `lost: clamp((band − 2)/7, 0, 1)`. §11.9's decision that
  Induction is a **mean of settled rounds, not a running maximum** is delivered by T06's update rule,
  not here; here the only thing that matters is that the sample is a level, not a record.
- **Retention** — two forms. ECHO: `max(0, (hit − (answerCount − hit)) / a)`. PROBE:
  `1 − Double(duplicatePairProbes)/Double(probesUsed)`. Guard `probesUsed == 0` by emitting nothing;
  a round with zero probes is a discard (E10·T04) and has no transcript at all.
- **Flexibility** — `clamp((2·L* − L)/(1.5·L*), 0, 1)`, `L*` = `0.45·par(band)` at a DRIFT hinge and
  `0.30·par(band)` at a first strike in any mode. **`par(band)` is canon's `Band.par`, in every mode,
  including DRIFT.** §11.9 is explicit and `flexibilityUsesCanonPar` is the guard. A round with
  neither a hinge nor a strike emits nothing — silence is not a zero.
- **Restraint** — `0.6·d + 0.4·m`, or `d` alone where no margin exists. `Restraint.d` is a four-case
  switch with no `default:`; `Restraint.margin` is
  `clamp(1 − log2(Double(max(1, hLive)))/log2(Double(band.population)), 0, 1)`. Computing `H_live`
  is **T07**; this task consumes an `Int?` and the `nil` path is the bands-5-and-7 skip.
- **Tempo** — `solved: min(1, par/probes)`, `lost: 0.5·min(1, par/probes)`, SIEVE:
  `clamp01(1 − medianLatency/meanWindow)` over hits only, and **nothing at all** under
  `SieveRate.voiceOverStep` or `.steadyStream`, because both fix `r` and the sample would measure the
  setting rather than the player.

### Four `Feeds` rulings, each recorded in `DECISIONS.md`

§11.9's `Feeds` column and §11.9's own SIEVE paragraph do not agree about which modes emit which
axes, and §10.5's table is a third list. Resolve them once, here, conservatively — every ruling below
is the reading that satisfies every explicit sentence:

1. **Induction feeds PROBE, DRIFT, SIEVE and the Anomaly. Not ECHO.** The `Feeds` column names the
   first three; §11.9's SIEVE paragraph adds SIEVE with *"It still emits Induction and Restraint."*
   ECHO is named by neither, and the reason is structural: §8.1 makes ECHO's law **selected from the
   pool, never generated**, so its `band` is a property of the round that first found it — sampling
   Induction there would count one discovery twice.
2. **Restraint feeds PROBE, DRIFT, SIEVE and the Anomaly. Not ECHO.** `d`'s four values enumerate the
   outcomes of a *declaration*, and §8.8 is explicit that ECHO has no strike mechanic and that a
   commit is final; there is no `d` to read and inventing one is the failure §11.9 exists to prevent.
3. **SIEVE's `d` is `1 − Double(foulsOutsideTell)/3`.** §9.5: *"a miss is caution and a foul is a
   false claim"*, and Restraint measures declaring only once the evidence closes. Three fouls end a
   run (§9.5), so the denominator is fixed and the endpoints match the declaration ladder exactly:
   zero fouls is 1.00 and a foul-out is 0.00. Fouls during the tell do not accrue, which is why the
   field is `foulsOutsideTell` and not `fouls`.
4. **SIEVE's Restraint skips the margin**, like bands 5 and 7. There is no declaration moment at
   which "the whole ribbon" exists, so `m` has no referent. Restraint from SIEVE is `d` alone.

The Anomaly is a PROBE round (§11.6), so it emits exactly PROBE's set. T03's `profileWeight` scales
all of them by 0.5 and suppresses the Induction *loss* sample; neither happens here.

### The monotonicity property, and the one place it must not be over-applied

The property is *"a strictly better transcript never produces a smaller sample"*, and "better" is
per-axis:

| Axis | The improving input | Held fixed |
|---|---|---|
| Induction | `band` rises; and at one band, solved ≥ lost | outcome, then band |
| Retention | `hit` rises, or `answerCount` falls at fixed `hit`; `duplicatePairProbes` falls | `a`, `probesUsed` |
| Flexibility | `R` falls | band, trigger |
| Restraint | `d` rises, or `H_live` falls | the other one |
| Tempo | `probesUsed` falls, or `medianLatency` falls; and at one probe count, solved ≥ lost | par, outcome |

**Restraint's ladder is over `d` and `m`, never over outcome quality.** `d` ranks a cap loss with
zero strikes (0.60) *above* a solve after one strike (0.35), because the axis measures declaring only
once the evidence closes and a wrong declaration is exactly the thing it counts. A monotonicity test
written as "solved ≥ lost" would fail correctly and would then be "fixed" by breaking the axis;
`capLossOutranksASolveAfterAStrike` is the pin that stops that.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ProfileAxisTests` green, all twenty-one tests, including the five parameterised monotonicity cases and the five boundedness cases.
- [ ] §8.7's worked ECHO round reproduces at `0.50` and §11.9's worked DRIFT transcript at `0.303`, both as shipped assertions.
- [ ] `grep -rn "probes/par\|probesUsed) / Double(par" HunchCore/Sources/Archive/AxisSampling.swift` returns nothing — the Tempo ratio is `par/probes`.
- [ ] `grep -rn "parDrift" HunchCore/Sources/Archive/AxisSampling.swift` returns nothing — `L*` reads `Band.par`.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/Restraint.swift HunchCore/Sources/Archive/AxisSampling.swift` returns nothing.
- [ ] `grep -rniE "induction|retention|flexibility|restraint|tempo" Modules/Sources/HunchUI/Resources/Localizable.xcstrings` returns nothing.
- [ ] Every sample formula appears exactly once in the codebase: `grep -rn "0.45\|0.30" HunchCore/Sources` shows `L*`'s two constants only in `AxisSampling.swift`.
- [ ] `DECISIONS.md` carries the four `Feeds` rulings with their citations.
- [ ] `tests.json` carries twelve entries: the five formulas, the two worked reproductions, the direction rule, the `par` trap, the SIEVE suppression, the bands-5-and-7 skip, and the five-axis monotonicity property.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes making `Restraint.d` monotone in outcome quality, reject it and point at `capLossOutranksASolveAfterAStrike`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T05: the five Profile axis sample formulas and their monotonicity property"`

## Out of scope

- The update rule, `α`, the `n` cap and the idle decay — **T06**.
- Computing `H_live` — **T07**; this task consumes the `Int?` and tests both branches.
- The 0.5 Anomaly weight and the suppressed Induction loss-sample — **T03** decides them, **T06** applies them.
- Anything drawn — **T08**–**T10**.
- The transcript *quantities* themselves: `R` — **E12·T07**; `hit`/`A`/`order` — **E13·T08**; latency and window — **E14·T05**. This task consumes them and defines none of them.
