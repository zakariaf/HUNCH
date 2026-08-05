# T04 — `par_DRIFT`, `cap_DRIFT` and scoring

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Lifecycle + budgets (DRIFT) — the budget half · Par tick row + par crossing (PROBE), extended to 40 ticks |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `Band.par(for:)` is about to stop being total — DRIFT has no row below band 3 — and how that is expressed (`Int?`, a precondition, or a separate namespace) decides whether an unservable DRIFT round is a crash, a wrong number, or a compile error. The skill owns that `W28` question and the `RoundBudget` exhaustive-switch ruling E08·T09 already set up. |
| `hunch-shared-marks` | `references/tick-row.md` is normative for the row: the pitch formula, the four modes, and the fact that **the cap row's `total` is `cap − par`, not `cap`**. DRIFT is the one mode that makes the clamp engage, so this is the task that proves the skill's own worked number (7.2 pt at 40 ticks) rather than restating it. |

## Objective

At the end of this task a DRIFT round has a budget: the six-row table from 25/40 at band 3 to 40/64 at
band 8, with `rec(b)` alongside, and canon's scoring formula reproduces §7.7's worked round exactly —
600 points, two marks, fractured. The three-mark rule gains its second condition, `R ≤ rec(b)`, and the
par tick row compresses to 7.2 pt on the SE at 40 ticks without any change to `TickRow.draw` or to
`tickPitch`.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.7 | The six-row table verbatim — `par`, `rec`, `par_DRIFT`, `cap_DRIFT`, forced hinge; the scoring formula with `par_DRIFT` substituted; the three mark rules; the worked band-5 round and every number in it |
| `GAME_DESIGN.md` | §6.9 | Canon's formula, the **multiply-then-round-once** order, `probesUsed = max(1, probeCount)`, and that only `inscribed` scores |
| `GAME_DESIGN.md` | §6.2 | `tickPitch = min(nominalPitch, rowWidth / N)`; `nominalPitch` 9 / 10 pt, `rowWidth` 288 / 348 pt; the worked 288/40 = 7.2 pt and why compressing DRIFT's row costs no signal |
| `GAME_DESIGN.md` | §5.4, §5.7 | `par(b)` and `cap(b) = ceil(1.6·par)`, the three mark thresholds, and the locked-constant status of all of them |
| `GAME_DESIGN.md` | §11.9 | That `par` means the mode's own par — `par_DRIFT(b)` in DRIFT — for the Tempo sample, and that Flexibility's `L*` uses **canon's** `par(b)` instead |
| `hunch-shared-marks` | `references/tick-row.md` §1–§3 | The pitch formula, the four row modes, `cap − par` as the cap row's total, the crossing's crossfade and its silence |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | One home per quantity; the `RoundBudget` switch stays exhaustive |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/DriftBudgetTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration
import HunchTestSupport

@Suite("DRIFT's budget and scoring — §7.7", .tags(.unit, .presubmission))
struct DriftBudgetTests {

    // MARK: the six rows

    @Test("§7.7's table, row for row",
          arguments: zip(DriftBudget.servedBands,
                         [(rec: 9,  par: 25, cap: 40, forced: 13),
                          (rec: 9,  par: 29, cap: 47, forced: 16),
                          (rec: 9,  par: 32, cap: 52, forced: 19),
                          (rec: 9,  par: 32, cap: 52, forced: 19),
                          (rec: 11, par: 37, cap: 60, forced: 21),
                          (rec: 11, par: 40, cap: 64, forced: 24)]))
    func theTable(_ band: Band, _ row: (rec: Int, par: Int, cap: Int, forced: Int)) {
        #expect(DriftBudget.recovery(band) == row.rec)
        #expect(DriftBudget.par(band) == row.par)
        #expect(DriftBudget.cap(band) == row.cap)
        #expect(DriftSchedule.forcedHingeProbe(band: band) == row.forced)
    }

    @Test("par_DRIFT(b) == par(b) + rec(b) — the second induction is priced as an allowance",
          arguments: DriftBudget.servedBands)
    func parIsCanonPlusRecovery(_ band: Band) {
        #expect(DriftBudget.par(band) == band.par(for: .probe) + DriftBudget.recovery(band)!)
    }

    @Test("cap_DRIFT == ceil(1.6 · par_DRIFT), the same rule canon uses",
          arguments: DriftBudget.servedBands)
    func capIsDerived(_ band: Band) {
        let par = Double(DriftBudget.par(band)!)
        #expect(DriftBudget.cap(band) == Int((1.6 * par).rounded(.up)))
    }

    @Test("Bands DRIFT does not serve have no budget at all", arguments: [Band.literal, .pair])
    func noBudgetBelowBandThree(_ band: Band) {
        #expect(DriftBudget.par(band) == nil)
        #expect(DriftBudget.cap(band) == nil)
        #expect(DriftBudget.recovery(band) == nil)
    }

    @Test("RoundBudget's .drift case is filled, and the worst-case transcript moves to 65")
    func roundBudgetIsFilled() {
        #expect(RoundBudget.cap(mode: .drift, band: .systemic) == 64)
        #expect(RoundBudget.cap(mode: .drift, band: .literal) == nil)
        #expect(RoundBudget.worstCaseTranscript == 65)
    }

    // MARK: scoring

    @Test("§7.7's worked band-5 round reproduces exactly")
    func workedRound() {
        let result = DriftScore.settle(band: .contextual, probesUsed: 27, strikes: 1,
                                       latency: 16, outcome: .win)
        #expect(result.score == 600)
        #expect(result.marks == 2)
        #expect(result.fracture == true)
    }

    @Test("Multiply then round once — a strike never produces a fractional intermediate")
    func multiplyThenRoundOnce() {
        // 1000 · min(1, 29/34) · 0.6 = 511.76…  → 512, not round(1000·0.8529)=853 then ×0.6=512 by luck
        #expect(DriftScore.settle(band: .relational, probesUsed: 34, strikes: 1,
                                  latency: 4, outcome: .win).score == 512)
    }

    @Test("Three marks need BOTH conditions: probes ≤ 0.6·par_DRIFT AND R ≤ rec(b)")
    func threeMarksNeedsBoth() {
        // band 5: 0.6 · 32 = 19.2, rec = 9
        #expect(DriftScore.settle(band: .contextual, probesUsed: 19, strikes: 0,
                                  latency: 9, outcome: .win).marks == 3)
        #expect(DriftScore.settle(band: .contextual, probesUsed: 19, strikes: 0,
                                  latency: 10, outcome: .win).marks == 2)   // fast, but clung
        #expect(DriftScore.settle(band: .contextual, probesUsed: 20, strikes: 0,
                                  latency: 4, outcome: .win).marks == 2)    // flexible, but slow
    }

    @Test("An undefined latency can never earn the third mark")
    func undefinedLatencyCapsAtTwo() {
        #expect(DriftScore.settle(band: .contextual, probesUsed: 12, strikes: 0,
                                  latency: nil, outcome: .win).marks == 2)
    }

    @Test("Two marks at par_DRIFT, one at cap_DRIFT, and the thresholds are inclusive")
    func markBoundaries() {
        #expect(DriftScore.settle(band: .exclusive, probesUsed: 25, strikes: 0,
                                  latency: 20, outcome: .win).marks == 2)   // == par_DRIFT
        #expect(DriftScore.settle(band: .exclusive, probesUsed: 26, strikes: 0,
                                  latency: 20, outcome: .win).marks == 1)
        #expect(DriftScore.settle(band: .exclusive, probesUsed: 40, strikes: 0,
                                  latency: 20, outcome: .win).marks == 1)   // == cap_DRIFT
    }

    @Test("Only a win scores; every loss is exactly zero",
          arguments: [DriftScore.Settlement.deadLawLoss, .brokenLoss, .exhausted, .abandoned])
    func lossesScoreZero(_ outcome: DriftScore.Settlement) {
        #expect(DriftScore.settle(band: .contextual, probesUsed: 12, strikes: 2,
                                  latency: 3, outcome: outcome).score == 0)
    }

    @Test("A strike fractures the page whether or not it was the dead-law strike")
    func anyStrikeFractures() {
        #expect(DriftScore.settle(band: .contextual, probesUsed: 12, strikes: 1,
                                  latency: 3, outcome: .win).fracture == true)
        #expect(DriftScore.settle(band: .contextual, probesUsed: 12, strikes: 0,
                                  latency: 3, outcome: .win).fracture == false)
    }

    @Test("DRIFT's par is DRIFT's, everywhere a par is asked for")
    func parIsTheModesOwn() {
        #expect(Band.contextual.par(for: .drift) == 32)
        #expect(Band.contextual.par(for: .probe) == 23)
        #expect(Band.contextual.cap(for: .drift) == 52)
    }
}
```

And `Modules/Tests/HunchUITests/DriftTickRowTests.swift`:

```swift
import Testing
@testable import HunchUI
import Rounds
import LawGeneration

@Suite("The par row at DRIFT's lengths — §6.2", .tags(.unit, .presubmission))
struct DriftTickRowTests {

    @Test("Band 8's 40 ticks compress the SE row to exactly 7.2 pt")
    func fortyTicksOnSE() {
        let se = PlaySurfaceLayout.reference(.compact)
        #expect(se.tickPitch(total: DriftBudget.par(.systemic)!) == se.tickRowWidth / 40)
        #expect(isApproximatelyEqual(se.tickPitch(total: 40), 7.2, absoluteTolerance: 0.001))
    }

    @Test("Pro Max compresses to 8.7 pt at the same count")
    func fortyTicksOnProMax() {
        let big = PlaySurfaceLayout.reference(.large)
        #expect(isApproximatelyEqual(big.tickPitch(total: 40), 8.7, absoluteTolerance: 0.001))
    }

    @Test("The tick stays 2 pt wide, so the gap never falls below 5 pt",
          arguments: DriftBudget.servedBands)
    func gapStaysLegible(_ band: Band) {
        let se = PlaySurfaceLayout.reference(.compact)
        #expect(se.tickPitch(total: DriftBudget.par(band)!) - C.TickRow.tickWidth >= 5)
    }

    @Test("The clamp engages only past band 6 — below that DRIFT's row is still nominal",
          arguments: zip(DriftBudget.servedBands, [true, true, true, true, false, false]))
    func clampEngagement(_ band: Band, _ unclamped: Bool) {
        let se = PlaySurfaceLayout.reference(.compact)
        #expect((se.tickPitch(total: DriftBudget.par(band)!) == se.nominalTickPitch) == unclamped)
    }

    @Test("The cap row never compresses, because its total is cap − par",
          arguments: DriftBudget.servedBands)
    func capRowIsShort(_ band: Band) {
        let se = PlaySurfaceLayout.reference(.compact)
        let stops = DriftBudget.cap(band)! - DriftBudget.par(band)!
        #expect(stops <= 24)
        #expect(se.tickPitch(total: stops) == se.nominalTickPitch)
    }

    @Test("The row is still length-proportional to par within DRIFT, until the clamp")
    func proportionalUntilTheClamp() {
        let se = PlaySurfaceLayout.reference(.compact)
        let b3 = se.tickRowLength(total: DriftBudget.par(.exclusive)!)
        let b4 = se.tickRowLength(total: DriftBudget.par(.relational)!)
        #expect(b4 / b3 == 29.0 / 25.0)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DriftBudgetTests`
then `swift test --package-path Modules --filter DriftTickRowTests`

Expect missing `DriftBudget.par/cap/recovery`, `DriftScore`, `Band.par(for: .drift)`, and a
`RoundBudget.worstCaseTranscript` still reporting 48. The `multiplyThenRoundOnce` expectation of 512
must be recomputed by hand before you trust it — do the arithmetic in the test's comment.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** E08·T09's `RoundBudgetTests` asserts `worstCaseTranscript == 1 + max
PROBE cap`; that test must now be **updated, not deleted** — the whole point of pinning it there was
that E12's edit moves it visibly.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/DriftBudget.swift` — the six rows, `par`, `cap`, `recovery` |
| create | `HunchCore/Sources/Rounds/DriftScore.swift` — `settle(band:probesUsed:strikes:latency:outcome:)` |
| modify | `HunchCore/Sources/Rounds/RoundBudget.swift` — fill the `.drift` case |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `par(for:)` / `cap(for:)` gain their `.drift` arm |
| modify | `HunchCore/Tests/RoundsTests/RoundBudgetTests.swift` — `worstCaseTranscript` 48 → 65 |
| create | `HunchCore/Tests/RoundsTests/DriftBudgetTests.swift` |
| create | `Modules/Tests/HunchUITests/DriftTickRowTests.swift` |
| modify | `tests.json` — the six rows, the worked round, the two mark conditions, the tick clamp |
| modify | `DECISIONS.md` — the `Band.par(for: .drift)` totality ruling and the `rec(b)` derivation note |

## Implementation notes

### The table is data, and the formula behind it is a comment

§7.7 defines `rec(b) = ceil(k(b) · log₂|Nbhd|)` "over real neighbourhood sizes, locked" and then gives
the six results — it never states `k(b)` or the neighbourhood sizes. **Do not reconstruct them.** Ship
the six `rec` values as the locked table with the formula in a doc comment marked as the derivation the
spec does not restate, exactly as canon's `par` ships `k` and `d` as prose beside a locked column.

```swift
public enum DriftBudget {
    public static let servedBands: [Band] = [.exclusive, .relational, .contextual,
                                             .guarded, .composite, .systemic]
    /// §7.7's recovery allowance. `rec(b) = ceil(k(b)·log₂|Nbhd|)` over the real one-leaf
    /// neighbourhood sizes; §7.7 locks the six results and does not publish `k` or `|Nbhd|`, so this
    /// is the table and not the formula.
    public static func recovery(_ band: Band) -> Int?
    /// `par_DRIFT(b) = par(b) + rec(b)`. Derived, not tabulated — the identity is asserted, so the
    /// two columns of §7.7 cannot disagree in this file.
    public static func par(_ band: Band) -> Int?
    /// `ceil(1.6 · par_DRIFT)`, canon §5.4's own rule applied to the substituted par.
    public static func cap(_ band: Band) -> Int?
}
```

Deriving `par` and `cap` rather than tabulating them is deliberate: §7.7 prints all four columns, and
four hand-typed columns are four chances to transpose a digit. Derive two, tabulate two (`par(b)` is
canon's, already shipped; `rec(b)` is new), and let the row-for-row test above compare the derivation
against §7.7's printed numbers.

### Which par, where — the distinction that is easiest to get wrong

Three different quantities in this epic divide by a par, and only one of them is DRIFT's:

| Quantity | Uses | Why |
|---|---|---|
| `score`, the three mark thresholds, the par tick row, the par crossing, the Tempo sample | **`par_DRIFT(b)`** | §7.7 substitutes it; §11.9 says "the mode's own par" |
| D6's mid-theory ratio, the forced hinge index `ceil(0.80·par(b))` | **canon `par(b)`** | Both ask "how far into a *normal* round", and `par_DRIFT` already contains the post-hinge allowance |
| Flexibility's `L* = 0.45·par(b)` | **canon `par(b)`** | §11.9 says so explicitly: *"on canon's `par(b)`, never `par_DRIFT`"* |

`Band.par(for: .drift)` is the accessor for the first row only. A test in T07 asserts the third row's
independence; T01's tests assert the second's.

### `Band.par(for:)` stops being total, and that has to be visible

DRIFT has no row below band 3, so `Band.par(for: .drift)` has no answer at bands 1 and 2. Three
spellings, and the ruling:

- **`Int?` everywhere** — correct, and it makes every existing PROBE call site optional for no reason.
- **A precondition inside the `.drift` arm** — chosen. `Band.par(for:)` stays `Int`; the `.drift` arm
  is `DriftBudget.par(self)!` behind a precondition whose message names §7.2's served-band rule. The
  guarantee that it is never called there comes from three places at once: E11·T03's per-mode clamp
  3…8, `DriftPair.make` returning `nil`, and an arm-time assertion in `Round`.
- **A separate `DriftBudget` namespace only** — rejected: §11.9 asks for "the mode's own par" through
  one accessor, and two accessors for one concept is `W28`.

`RoundBudget.cap(mode:band:)` remains the **total** function and is what any cross-mode surface (the
spool sheet, the sheet-capacity invariant) must use. Record the split in `DECISIONS.md`.

### Scoring

```swift
public enum DriftScore {
    public enum Settlement: Sendable, Equatable {
        case win, deadLawLoss, brokenLoss, exhausted, abandoned
    }
    public struct Result: Sendable, Equatable {
        public let score: Int
        public let marks: Int
        public let fracture: Bool
    }
    /// `latency` is §7.8's `R`. `nil` means it is undefined for this round (the player was never
    /// contradicted, or never sealed after being contradicted) — which can never earn three marks.
    public static func settle(band: Band, probesUsed: Int, strikes: Int,
                              latency: Int?, outcome: Settlement) -> Result
}
```

```swift
let probes  = max(1, probesUsed)                                   // §6.9's zero-probe guard
let economy = min(1.0, Double(DriftBudget.par(band)!) / Double(probes))
let penalty = strikes >= 1 ? 0.6 : 1.0
let score   = Int((1000.0 * economy * penalty).rounded(.toNearestOrAwayFromZero))
```

Canon's formula, one substitution, and the **multiply-then-round-once** order preserved — reuse
E06·T07's implementation with an injected par rather than writing a second copy of the arithmetic. If
E06·T07 hard-coded `band.par(for: .probe)` inside it, that is the line to parameterise; adding
`DriftScore.score` as a second expression is the drift this task is meant to prevent.

Marks:

```swift
let marks = (probes <= Int(0.6 * Double(par)) && (latency ?? .max) <= rec) ? 3
          : probes <= par                                                  ? 2 : 1
```

Two notes. The 3-mark test is **`0.6 · par_DRIFT` and `R ≤ rec(b)` together** — §7.7 is explicit, and
the reason it is a conjunction rather than a second score term is that the flexibility signal belongs
on the Seal marks, where it is categorical, and not in the score, where it would be continuous and
therefore readable as a number. And a round that meets the probe condition but not the latency
condition falls to **2**, not to 1, because it still satisfies `probes ≤ par_DRIFT`.

`fracture = strikes >= 1`, independent of marks (§6.9's decision), and independent of *which* strike it
was: a dead-law strike fractures exactly like an ordinary one. §7.7's last sentence — "a strike still
fractures the Codex page and forfeits the Anomaly streak" — is the same rule as PROBE's, not a new one.

### The tick row: nothing to build, one number to prove

`TickRow.draw` and `PlaySurfaceLayout.tickPitch` already exist (E04·T08, E08·T08) and this task changes
**neither**. What changes is that `total` can now be 40, and `min(nominalPitch, rowWidth/total)` does
the rest. Two facts to keep straight while writing the test:

- **Only the par row compresses.** The cap row's `total` is `cap − par`, not `cap`
  (`tick-row.md` §2), so its worst case is `64 − 40 = 24` stops, which at 9 pt is 216 pt inside a 288 pt
  budget. A test that asserts a 64-tick cap row is testing the wrong drawing.
- **The compression costs no signal.** §6.2's argument, and it is worth understanding before touching
  the row: the row's *length* is the only difficulty signal the player gets (§5.4, §10.5), and DRIFT's
  tick count already identifies the mode by design (§7.5). So compressing DRIFT's row gives away
  nothing that was not already given away. The tick stays 2 pt wide and ≥ 5.2 pt of gap remains.

The par crossing itself is unchanged: same geometry, same crossfade, **no audio and no haptic**
(`tick-row.md` §3, §6.9's decision). Do not wire a cue to a DRIFT crossing on the grounds that it is a
different mode; the reason for the silence — the crossing lands on the same frame as a verdict, which
owns those channels absolutely — is identical here.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftBudgetTests` green, and `swift test --package-path Modules --filter DriftTickRowTests` green.
- [ ] §7.7's worked round reproduces: `score == 600`, `marks == 2`, `fracture == true` at `probesUsed = 27`, `strikes = 1`, `R = 16`, band 5.
- [ ] `RoundBudget.worstCaseTranscript == 65`, and E08·T09's `RoundBudgetTests` was **updated** rather than deleted; `SpoolSheetLayout`'s capacity assertion still passes with 70 ≥ 65.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/RoundBudget.swift` returns nothing.
- [ ] `grep -rn "1000\.0 \*\|1000 \*" HunchCore/Sources/Rounds/` shows the multiply-then-round expression in exactly **one** file.
- [ ] `grep -rn "25\|29\|32\|37\|40" HunchCore/Sources/Rounds/DriftBudget.swift` shows `par_DRIFT`'s values appearing **zero** times as literals — they are derived from `par(b) + rec(b)`.
- [ ] `isApproximatelyEqual(tickPitch(total: 40), 7.2, absoluteTolerance: 0.001)` on the SE reference layout.
- [ ] `DECISIONS.md` records the `Band.par(for:)` precondition ruling and that `rec(b)` ships as a table.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T04: par_DRIFT, cap_DRIFT, rec(b) and DRIFT scoring with the two-condition third mark"`

## Out of scope

- `R` itself — how it is derived from the transcript is **T07**. This task consumes it as an `Int?`.
- The Flexibility sample and `L* = 0.45·par(b)` — **§11.9 / E16·T05**. This task only keeps DRIFT's par out of it.
- `TickRow.draw`, `tickPitch` and the instrument bar — **E04·T08**, **E08·T08**; neither is modified.
- The Codex page's `bestProbes` strip against `par_DRIFT` — **E15·T05**.
- The Tempo sample's use of `par_DRIFT` — **E16·T05**.
- The θ update and `servedDelta` — **E11·T02**; DRIFT's score has no path into the estimator.
