# T08 — `Probe`, `Ribbon` and `Score`

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | §14.1 PROBE → **The twin key**; §14.1 CORE SYSTEMS → **Par / cap / scoring** (the per-round application half; the arithmetic is E06·T07) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns `08 §3`'s naming row for this exact type — `struct Probe { let glyph; let verdict; let isTwin }`, `func probe(_:)` and `func probeTwin()` on `Round`, never `func twin()` — and owns the ruling that "the Loom" is no type at all, so the verdict stays a pure function of `(law, prev, cur)` |
| `hunch-swift-testing` | Owns `06 T42` — assert invariants over a seeded corpus, never a golden order — which is how the duplicate-pair and twin properties get tested without freezing a transcript |

## Objective

The transcript of a round exists as a value: `Probe`, and a `Ribbon` that derives twin-ness from
adjacency rather than from which key was pressed, so a resume that recomputes everything from glyph
IDs lands on the identical transcript. Alongside it, §6.9's scoring is applied *per round* — marks
read off the transcript, and every outcome that is not `.inscribed` scoring exactly zero.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.4 | `prev(1) = seedGlyph` primed and not a probe; `prev(n) = glyph(n − 1)`, the previously **probed** glyph regardless of verdict; a frozen verdict never changes |
| `GAME_DESIGN.md` | §6.3 | The twin key re-feeds the throat glyph unchanged and costs one probe; probe 1 defaults to a twin-of-seed; probes are never a spendable resource |
| `GAME_DESIGN.md` | §6.6 layer 4 | A twin pair draws as one unit under a doubled ring, **split** when the two verdicts differ |
| `GAME_DESIGN.md` | §6.11 cases 1, 2, 3 | Declaring at probe 0 (`probesUsed = max(1, 0)`); the twin key at probe 0 is legal and the seed glyph never gains a verdict ring; **a same glyph probed twice non-adjacently is drawn normally, with no doubled ring** |
| `GAME_DESIGN.md` | §6.9 | The scoring block verbatim, the mark thresholds, and *only `Outcome.inscribed` scores* |
| `GAME_DESIGN.md` | §5.7 | par and cap, locked per band — read from `Band`, never typed here |
| `GAME_DESIGN.md` | §11.9 (Retention row) | "a probe is a *duplicate pair* if its exact `(prev, cur)` ordered pair already appears in the ribbon" — the transcript quantity E16 consumes |
| `GAME_DESIGN.md` | §6.5 (*Recording*) | `ProbeRecord` in memory for rendering; the persisted snapshot stores glyph IDs only |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N6, N9, N47 | Imperative verb ⇒ side effect; `- Complexity:` on any computed property that is not O(1) |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/RibbonTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Rounds

@Suite("The ribbon", .tags(.unit, .presubmission))
struct RibbonTests {

    private let seed = Deck.glyph(id: 22)          // §12.5's seed glyph, a convenient constant
    private let other = Deck.glyph(id: 137)
    private let third = Deck.glyph(id: 200)

    // ---- context ----------------------------------------------------------------------------

    @Test("Before probe 1 the context is the seed glyph — primed, not probed")
    func contextStartsAtTheSeed() {
        let ribbon = Ribbon(seedGlyph: seed)
        #expect(ribbon.context == seed)
        #expect(ribbon.isEmpty)
    }

    @Test("The context is the previously probed glyph regardless of its verdict")
    func contextIgnoresVerdicts() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .reject)
        #expect(ribbon.context == other)
        ribbon.append(third, verdict: .admit)
        #expect(ribbon.context == third)
    }

    // ---- the twin key ------------------------------------------------------------------------

    @Test("An adjacent re-probe is a twin")
    func adjacentReprobeIsATwin() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)
        ribbon.append(other, verdict: .admit)
        #expect(ribbon.probes[0].isTwin == false)
        #expect(ribbon.probes[1].isTwin == true)
    }

    /// §6.11 case 3, and the reason `isTwin` is derived rather than recorded.
    @Test("A non-adjacent repeat is not a twin and draws normally")
    func nonAdjacentRepeatIsNotATwin() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)
        ribbon.append(third, verdict: .reject)
        ribbon.append(other, verdict: .admit)
        #expect(ribbon.probes.map(\.isTwin) == [false, false, false])
        #expect(ribbon.twinRing(endingAt: 2) == nil)
    }

    /// §6.11 case 2: the twin key at probe 0 probes the seed glyph, and the seed glyph itself
    /// never gains a verdict ring — so there is no *pair* of tiles and no doubled ring.
    @Test("The twin key at probe 0 produces an ordinary first tile, not a twin")
    func twinOfSeedIsNotATwin() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(seed, verdict: .admit)
        #expect(ribbon.probes[0].isTwin == false)
        #expect(ribbon.twinRing(endingAt: 0) == nil)
    }

    @Test("A twin pair whose verdicts agree takes the doubled ring")
    func agreeingTwinRing() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)
        ribbon.append(other, verdict: .admit)
        #expect(ribbon.twinRing(endingAt: 1) == .agreeing)
    }

    /// §6.6 layer 4 — the rendered contradiction that teaches contextuality with no words.
    @Test("A twin pair whose verdicts differ takes the split ring")
    func disagreeingTwinRingSplits() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)
        ribbon.append(other, verdict: .reject)
        #expect(ribbon.twinRing(endingAt: 1) == .split)
    }

    @Test("Three identical probes in a row are two overlapping twin pairs, not one triple")
    func threeInARowIsTwoPairs() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)
        ribbon.append(other, verdict: .admit)
        ribbon.append(other, verdict: .reject)
        #expect(ribbon.probes.map(\.isTwin) == [false, true, true])
        #expect(ribbon.twinRing(endingAt: 1) == .agreeing)
        #expect(ribbon.twinRing(endingAt: 2) == .split)
    }

    // ---- duplicate pairs (§11.9's Retention input) --------------------------------------------

    @Test("A duplicate pair is the same ordered (prev, cur), not merely the same glyph")
    func duplicatePairsAreOrderedPairs() {
        var ribbon = Ribbon(seedGlyph: seed)
        ribbon.append(other, verdict: .admit)   // (seed, other)
        ribbon.append(third, verdict: .admit)   // (other, third)
        ribbon.append(other, verdict: .admit)   // (third, other) — same glyph, different context
        #expect(ribbon.duplicatePairCount == 0)
        ribbon.append(third, verdict: .admit)   // (other, third) — seen at index 1
        #expect(ribbon.duplicatePairCount == 1)
    }

    // ---- rehydration -------------------------------------------------------------------------

    /// §6.10: "the stored law re-derives every ribbon verdict from glyph IDs alone". If `isTwin`
    /// were recorded rather than derived, a resume could produce a different ribbon than the one
    /// the player left — which is the bug this property exists to make impossible.
    @Test("Rebuilding a ribbon from its glyph sequence reproduces it exactly")
    func rehydrationIsIdentity() {
        var original = Ribbon(seedGlyph: seed)
        for (glyph, verdict) in [(other, Verdict.admit), (other, .reject), (third, .admit),
                                 (other, .admit), (other, .admit)] {
            original.append(glyph, verdict: verdict)
        }
        var rebuilt = Ribbon(seedGlyph: seed)
        for probe in original.probes { rebuilt.append(probe.glyph, verdict: probe.verdict) }
        #expect(rebuilt == original)
    }
}
```

And `HunchCore/Tests/RoundsTests/RoundScoreTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Rounds

@Suite("Scoring, applied per round", .tags(.unit, .presubmission))
struct RoundScoreTests {

    /// §6.9: "Only `Outcome.inscribed` scores; `broken`, `exhausted`, `abandoned` and `voided` all
    /// score exactly 0." Asserted at a probe count that would score 1000 if the gate were missing.
    @Test("Every losing outcome scores zero at any probe count",
          arguments: [Outcome.broken, .exhausted, .abandoned, .voided])
    func losingOutcomesScoreZero(_ outcome: Outcome) {
        #expect(outcome.score(probesUsed: 1, par: 29, strikes: 0) == 0)
        #expect(outcome.score(probesUsed: 47, par: 29, strikes: 1) == 0)
    }

    /// §6.11 case 1 — a declaration at probe 0 must not divide by zero.
    @Test("A declaration at probe 0 uses probesUsed = 1 and scores full marks")
    func declaringAtProbeZero() {
        let ribbon = Ribbon(seedGlyph: Deck.glyph(id: 22))
        #expect(ribbon.probesUsed == 1)
        let outcome = Outcome.inscribed(probesUsed: ribbon.probesUsed, par: 7, strikes: 0)
        #expect(outcome == .inscribed(marks: 3, fracture: false))
        #expect(outcome.score(probesUsed: ribbon.probesUsed, par: 7, strikes: 0) == 1000)
    }

    @Test("A strike sets the fracture, and marks and fracture are independent records")
    func fractureIsIndependentOfMarks() {
        // §6.9: "A 3-mark fractured page exists and is drawn with three marks and a crack."
        #expect(Outcome.inscribed(probesUsed: 4, par: 23, strikes: 1)
                == .inscribed(marks: 3, fracture: true))
        #expect(Outcome.inscribed(probesUsed: 4, par: 23, strikes: 0)
                == .inscribed(marks: 3, fracture: false))
    }

    @Test("Marks come from the transcript against that band's own par", arguments: Band.allCases)
    func marksAgreeWithTheBandTable(_ band: Band) {
        let par = band.par
        #expect(Outcome.inscribed(probesUsed: 1, par: par, strikes: 0).marks == 3)
        #expect(Outcome.inscribed(probesUsed: par, par: par, strikes: 0).marks == 2)
        #expect(Outcome.inscribed(probesUsed: par + 1, par: par, strikes: 0).marks == 1)
    }

    @Test("The per-round application never recomputes the arithmetic E06 owns")
    func scoreDelegatesToScoring() {
        // Same inputs, same answer: the round-level entry point is a gate plus a call, nothing more.
        #expect(Outcome.inscribed(marks: 2, fracture: true).score(probesUsed: 24, par: 20, strikes: 1)
                == Scoring.points(par: 20, probesUsed: 24, strikes: 1))
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter RibbonTests`
and `--filter RoundScoreTests`. Failures must be missing symbols. If `nonAdjacentRepeatIsNotATwin`
passes while `adjacentReprobeIsATwin` fails, `isTwin` is hard-coded `false` — keep going.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/Probe.swift` |
| create | `HunchCore/Sources/Rounds/Ribbon.swift` — `Ribbon` and its nested `TwinRing` |
| create | `HunchCore/Sources/Rounds/RoundScore.swift` — the `Outcome` extensions |
| create | `HunchCore/Tests/RoundsTests/RibbonTests.swift` |
| create | `HunchCore/Tests/RoundsTests/RoundScoreTests.swift` |

## Implementation notes

### `Probe`

```swift
/// One entry in the transcript. `08 §3` fixes the shape; `isTwin` is *derived at append*, never
/// passed in — see `Ribbon.append(_:verdict:)`.
public struct Probe: Sendable, Equatable, Hashable {
    public let glyph: Glyph
    public let verdict: Verdict
    public let isTwin: Bool
}
```

Not `Codable`. §6.10 is explicit: the snapshot stores **glyph IDs only** and verdicts are recomputed
from the stored law on every resume. A `Codable Probe` is an invitation to persist a verdict, and a
persisted verdict is a verdict that can disagree with the law.

### `Ribbon`, and the one decision that matters

```swift
public struct Ribbon: Sendable, Equatable {
    /// Primed at position 0 and never a probe (§6.4). It has no verdict and never gains a ring.
    public let seedGlyph: Glyph
    public private(set) var probes: [Probe] = []

    public init(seedGlyph: Glyph) { self.seedGlyph = seedGlyph }

    /// The `prev` the law reads for the next probe: the previously *probed* glyph regardless of
    /// verdict, or the seed glyph before probe 1 (§6.4).
    public var context: Glyph { probes.last?.glyph ?? seedGlyph }

    /// §6.9's `probesUsed`, floored at 1 so a probe-0 declaration cannot divide by zero
    /// (§6.11 case 1).
    public var probesUsed: Int { max(1, probes.count) }

    /// Appends a probe and freezes its verdict (§6.4: "a verdict once frozen never changes").
    ///
    /// **`isTwin` is adjacency, not intent.** §6.11 case 3: a twin is an *adjacent* re-probe only,
    /// because only adjacency holds the context fixed, which is the twin's entire purpose. Whether
    /// the player pressed the twin key or rebuilt the same glyph on the Dial produces the identical
    /// transcript, and must — otherwise a resume, which knows only glyph IDs, would draw a
    /// different ribbon than the player left.
    public mutating func append(_ glyph: Glyph, verdict: Verdict) {
        probes.append(Probe(glyph: glyph, verdict: verdict,
                            isTwin: probes.last?.glyph == glyph))
    }
}
```

Derived-not-recorded is the load-bearing decision of this task, and there are three independent
reasons, all of which belong in that doc comment: §6.11 case 3 defines twin-ness by adjacency; §6.10
rebuilds the ribbon from glyph IDs alone; and E08·T07's twin key is "never blocked and never
refunded", so it is an affordance rather than a distinct verb in the model.

### `TwinRing`

```swift
extension Ribbon {
    /// The doubled ring a twin pair draws under (§6.6 layer 4), or `nil` if the tile at `index`
    /// does not end a twin pair. **Split** when the two verdicts differ — a rendered contradiction,
    /// no colour required, no text possible.
    public enum TwinRing: Sendable, Equatable { case agreeing, split }

    /// - Complexity: O(1).
    public func twinRing(endingAt index: Int) -> TwinRing? {
        guard probes.indices.contains(index), probes[index].isTwin else { return nil }
        return probes[index].verdict == probes[index - 1].verdict ? .agreeing : .split
    }
}
```

Indexed by the **trailing** tile of the pair, because that is the tile whose `isTwin` is true and the
one the renderer reaches when it walks the ribbon forward. Three in a row is two overlapping pairs
(the test pins it): §6.6 speaks of pairs, and a "triple ring" is not in the vocabulary.

### `duplicatePairCount`

```swift
extension Ribbon {
    /// §11.9's Retention input for PROBE: a probe is a *duplicate pair* when its exact ordered
    /// `(prev, cur)` pair already appears earlier in the transcript. Emitted here because the
    /// ribbon is the only thing that knows the ordered pairs; the axis sample is E16·T05's.
    ///
    /// - Complexity: O(n) in the probe count. Read once per declaration, never per frame.
    public var duplicatePairCount: Int { … }
}
```

Walk the transcript once, building `Set<UInt16>` of `prev.glyphID << 8 | cur.glyphID`, counting the
inserts that fail. The pair for probe *i* is `(context before i, probes[i].glyph)`, where the context
before probe 0 is the seed glyph — so a repeated `(seed, x)` is impossible and the first probe never
counts. Do **not** cache it in a stored property: `04 A14`, derive, never mirror, and the `-
Complexity:` note (`N47`) is what makes a linear property honest.

### Scoring, per round

E06·T07 owns the arithmetic (`Scoring.points(par:probesUsed:strikes:)` and
`Scoring.marks(par:probesUsed:)` — use whatever spellings it shipped; if they differ, adapt the call
and change nothing else). This task adds two things and no new arithmetic:

```swift
extension Outcome {
    /// §6.9 — the outcome a correct declaration produces, with marks read off the transcript and
    /// the fracture set by the strike. Marks and the fracture are **independent** records: a
    /// 3-mark fractured page exists.
    public static func inscribed(probesUsed: Int, par: Int, strikes: Int) -> Outcome {
        .inscribed(marks: Scoring.marks(par: par, probesUsed: probesUsed), fracture: strikes == 1)
    }

    /// §6.9 — what this outcome is worth. Only `.inscribed` scores; `broken`, `exhausted`,
    /// `abandoned` and `voided` all score exactly 0, with no consolation points, because score is
    /// the Codex's currency and a loss inscribes no page.
    public func score(probesUsed: Int, par: Int, strikes: Int) -> Int {
        switch self {
        case .inscribed:                             Scoring.points(par: par,
                                                                    probesUsed: probesUsed,
                                                                    strikes: strikes)
        case .broken, .exhausted, .abandoned, .voided: 0
        }
    }

    /// Marks earned, 0 for every outcome that inscribes nothing.
    public var marks: Int {
        switch self {
        case .inscribed(let marks, _):                 marks
        case .broken, .exhausted, .abandoned, .voided: 0
        }
    }
}
```

The static factory shares the case's base name with different argument labels; that is legal, reads
correctly at both call sites (`Outcome.inscribed(probesUsed:par:strikes:)` builds one,
`.inscribed(marks:fracture:)` matches one), and `N14` is satisfied because neither is a conversion.
If `/code-review` finds it confusing, rename the factory `Outcome.inscribing(probesUsed:par:strikes:)`
rather than reaching for a free function.

**Do not reimplement the formula.** §6.9's `multiply then round once` and the three mark thresholds
are locked constants (§5.7) with worked examples already asserted in E06·T07. A second copy here is
the exact second-source-of-truth failure the skill library exists to prevent; `scoreDelegatesToScoring`
is the test that pins it.

### Where the cap lives

`cap = ceil(1.6 · par)` is `Band.cap` (E05·T06). This task never computes it and never stores it —
`verdictBeatCompleted(capReached:)` in T07 takes the answer as a parameter, and `Round` (E08·T01)
compares `ribbon.probes.count` to `band.cap`. Ribbon does not know about the cap at all; it is a
transcript, not a budget.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter RibbonTests` green, all ten cases.
- [ ] `swift test --package-path HunchCore --filter RoundScoreTests` green, including the eight
      parameterised band cases.
- [ ] `grep -n 'Codable' HunchCore/Sources/Rounds/Probe.swift HunchCore/Sources/Rounds/Ribbon.swift`
      is empty.
- [ ] `grep -nE '1000|0\.6|1\.6' HunchCore/Sources/Rounds/RoundScore.swift` is empty — every number
      comes from `Scoring` or `Band`.
- [ ] `grep -c 'default:' HunchCore/Sources/Rounds/RoundScore.swift` returns `0`.
- [ ] Changing `isTwin` to a parameter of `append` makes `rehydrationIsIdentity` still pass but
      `nonAdjacentRepeatIsNotATwin` become unenforceable. Try it, understand why the derived form is
      the only one that survives a resume, revert.
- [ ] `Ribbon` is a `struct` with no reference type inside it: `swift build` under strict concurrency
      accepts `: Sendable` with no `@unchecked`.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — re-run the tests after it. Likely finding: caching `duplicatePairCount`.
   Refuse; keep the `- Complexity:` note instead.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T08: Probe, Ribbon with adjacency twins, and per-round scoring"`

## Out of scope

- Drawing anything. The doubled ring, the split ring, the link arc and the ghost mark are
  **E04·T07/T08** (the owning functions) and **E08·T05** (the ribbon surface).
- The twin **key** — its 44 pt target, the never-blocked/never-refunded rule and the breath —
  **E08·T07**.
- The single-slot input queue and the 420 ms lock — **E08·T06**.
- The scoring arithmetic and §6.9's three worked rounds — **E06·T07**, already asserted there.
- `par` and `cap` themselves — **E05·T06** (`Band`) and **E06·T07**.
- DRIFT's `par_DRIFT` substitution — **E12·T04**, which reuses `Outcome.score` with a different par
  and must not need a second scoring path.
- The Retention axis sample that consumes `duplicatePairCount` — **E16·T05**.
