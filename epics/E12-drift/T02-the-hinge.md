# T02 — The hinge

| | |
|---|---|
| **Epic** | E12 — DRIFT |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | The hinge (DRIFT) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The whole task is one type-design question: *which law is in force at probe n* must be a total function of stored state, never a `var currentLaw` that something mutates at the hinge. A mutable in-force pointer is unrecoverable from a snapshot and is precisely how a resume would silently un-fire the hinge (T09's gate). The skill owns the `W28` "one type, not two parallel fields" ruling and the `HunchCore` boundary that keeps this file clock-free. |

`hunch-motion-and-feedback` is **not** loaded here even though trigger (b) fires an accept ring and an
inscribe haptic: those are cue *points*, and the beat sheet that plays them is **T08** and **E09·T09**.
This task decides only that the trigger occurred.

## Objective

At the end of this task a DRIFT round knows exactly when its law changed and can be asked, for any
probe index, which of the two laws evaluated it — including after being reconstructed from disk.
`N_admits` is drawn once from the round seed, the hinge fires at the earliest of satiation, capture and
the forced index, and **the pre-hinge `prev` survives the transition untouched**, so a contextual
chain is never broken by the mode's central event.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §7.3 | The whole task: `N_admits ~ U[3,6]` drawn deterministically from the round seed; the three triggers and their exact conditions; trigger (b)'s acceptance decision and the seam marker; "the hinge never resets context" |
| `GAME_DESIGN.md` | §7.7 | The *forced hinge at* column — 13/16/19/19/21/24 — which is `ceil(0.80 · par(b))` on **canon's** par |
| `GAME_DESIGN.md` | §7.8 | `t_hinge` is "the probe index at which `L₂` took force", and the worked transcript fixes its off-by-one: the hinge fires *on* probe 10 and probe 11 is the first evaluated by `L₂` |
| `GAME_DESIGN.md` | §7.11 | EARLY-SEAL (capture accepted, no strike, no score change), STARVED-HINGE (fires on that probe's boundary regardless), CONTEXT-CARRY (`prev` untouched), TWIN-OF-THE-HINGE (the twin after trigger (a) is evaluated under `L₂`) |
| `GAME_DESIGN.md` | §3.5 | `prev` is the previously **probed** glyph regardless of verdict; the seed glyph primes position 0 and is not a probe |
| `GAME_DESIGN.md` | §4.5 | Extension identity in the common space with lifting — how "the declaration's extension equals `L₁`'s" is decided |
| `GAME_DESIGN.md` | §5.7 | `par(b)` = 7/13/16/20/23/23/26/29 |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | State the hinge as one value, not a `Bool` plus an index; exhaustive `switch` over the trigger |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20 | The decision is a pure function tested directly; the phase it drives is T03's |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/DriftHingeTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration
import Laws
import Glyphs
import HunchTestSupport

@Suite("The hinge — §7.3", .tags(.unit, .presubmission))
struct DriftHingeTests {

    // MARK: N_admits

    @Test("N_admits is uniform on [3,6] and is a function of the round seed alone")
    func admitsRange() {
        let counts = (0..<4_000).map { DriftSchedule.admitsBeforeHinge(roundSeed: UInt64($0)) }
        #expect(counts.allSatisfy { (3...6).contains($0) })
        #expect(Set(counts) == [3, 4, 5, 6])
        #expect(DriftSchedule.admitsBeforeHinge(roundSeed: 0xD21F7)
             == DriftSchedule.admitsBeforeHinge(roundSeed: 0xD21F7))
    }

    // MARK: trigger (a) — satiation

    @Test("(a) fires on the probe delivering the N_admits-th admit under L₁")
    func satiation() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 3)
        // verdicts under L₁: reject, admit, reject, admit, admit  → the 5th probe is the 3rd admit
        for (index, verdict) in [Verdict.reject, .admit, .reject, .admit, .admit].enumerated() {
            s.recordProbe(index: index + 1, verdictUnderLawOne: verdict)
        }
        #expect(s.hinge == DriftHinge(firedAtProbe: 5, trigger: .satiation))
    }

    @Test("The firing probe is still L₁'s; the next probe is L₂'s (§7.8's worked transcript)")
    func theFiringProbeBelongsToLawOne() {
        var s = DriftSchedule.fixture(band: .contextual, admits: 4)
        for index in 1...10 {
            s.recordProbe(index: index, verdictUnderLawOne: index % 3 == 1 ? .admit : .reject)
        }
        #expect(s.hinge?.firedAtProbe == 10)
        #expect(s.lawInForce(atProbe: 10) == s.pair.lawOne)
        #expect(s.lawInForce(atProbe: 11) == s.pair.lawTwo)
        #expect(s.lawInForce(atProbe: 1) == s.pair.lawOne)
    }

    @Test("An admit after the hinge never re-fires it")
    func hingeFiresOnce() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 3)
        for index in 1...3 { s.recordProbe(index: index, verdictUnderLawOne: .admit) }
        let fired = s.hinge
        for index in 4...9 { s.recordProbe(index: index, verdictUnderLawOne: .admit) }
        #expect(s.hinge == fired)
    }

    // MARK: trigger (c) — forced

    @Test("(c) fires at ceil(0.80·par(b)) on CANON's par, matching §7.7's column",
          arguments: zip(DriftBudget.servedBands, [13, 16, 19, 19, 21, 24]))
    func forcedIndex(_ band: Band, _ expected: Int) {
        #expect(DriftSchedule.forcedHingeProbe(band: band) == expected)
        #expect(DriftSchedule.forcedHingeProbe(band: band)
             == Int((0.80 * Double(band.par(for: .probe))).rounded(.up)))
    }

    @Test("STARVED-HINGE: fewer than N_admits admits by the forced index fires it anyway")
    func starvedHinge() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 6)   // forced at 13
        for index in 1...13 { s.recordProbe(index: index, verdictUnderLawOne: .reject) }
        #expect(s.hinge == DriftHinge(firedAtProbe: 13, trigger: .forced))
        #expect(s.lawInForce(atProbe: 14) == s.pair.lawTwo)
    }

    @Test("Satiation beats the forced index when it lands first — earliest wins")
    func earliestWins() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 3)   // forced at 13
        for index in 1...3 { s.recordProbe(index: index, verdictUnderLawOne: .admit) }
        #expect(s.hinge?.trigger == .satiation)
        #expect(s.hinge?.firedAtProbe == 3)
    }

    // MARK: trigger (b) — capture

    @Test("(b) a pre-hinge declaration equal to L₁ is ACCEPTED and fires the hinge")
    func capture() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 5)
        for index in 1...4 { s.recordProbe(index: index, verdictUnderLawOne: .reject) }
        let outcome = s.recordDeclaration(s.pair.lawOne, atProbeCount: 4)
        #expect(outcome == .captured)
        #expect(s.hinge == DriftHinge(firedAtProbe: 4, trigger: .capture))
        #expect(s.seamMarkerIndex == 4)
    }

    @Test("A capture is not a strike and does not end the round")
    func captureCostsNothing() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 5)
        _ = s.recordDeclaration(s.pair.lawOne, atProbeCount: 2)
        #expect(s.strikes == 0)
        #expect(s.deadDeclaration == false)     // a CAPTURE is not a dead declaration (§7.8)
    }

    @Test("A pre-hinge declaration that is not L₁ is an ordinary wrong declaration, even if it is L₂")
    func preHingeLawTwoIsStillWrong() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 5)
        #expect(s.recordDeclaration(s.pair.lawTwo, atProbeCount: 3) == .wrong)
        #expect(s.hinge == nil)
    }

    @Test("Capture fires at most once — a second L₁ declaration post-hinge is the dead-law strike")
    func captureThenDeadLaw() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 5)
        _ = s.recordDeclaration(s.pair.lawOne, atProbeCount: 2)
        #expect(s.recordDeclaration(s.pair.lawOne, atProbeCount: 6) == .deadLaw)
        #expect(s.hinge?.trigger == .capture)
        #expect(s.hinge?.firedAtProbe == 2)
        #expect(s.deadDeclaration == true)
    }

    @Test("Post-hinge, a declaration equal to L₂ wins")
    func postHingeWin() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 3)
        for index in 1...3 { s.recordProbe(index: index, verdictUnderLawOne: .admit) }
        #expect(s.recordDeclaration(s.pair.lawTwo, atProbeCount: 9) == .correct)
    }

    @Test("Declaration comparison is extension identity in the common space, not spelling")
    func spellingIsIrrelevant() {
        var s = DriftSchedule.fixture(band: .exclusive, admits: 5)
        #expect(s.recordDeclaration(s.pair.lawOne.complementSpelling, atProbeCount: 3) == .captured)
    }

    // MARK: CONTEXT-CARRY

    @Test("CONTEXT-CARRY: the hinge does not reset prev — probe t+1 is judged against the pre-hinge prev")
    func contextCarry() {
        var s = DriftSchedule.fixture(band: .contextual, admits: 3)
        let chain = Corpora.probeChain(band: .contextual, length: 6)
        for (i, glyph) in chain.enumerated() {
            s.recordProbe(index: i + 1, verdictUnderLawOne: s.pair.lawOne.admits(glyph, after: s.previous))
        }
        let t = try! #require(s.hinge).firedAtProbe
        #expect(s.previousGlyph(forProbe: t + 1) == chain[t - 1])   // unbroken: the pre-hinge probe
    }

    @Test("The seed glyph primes probe 1 in both halves and is never itself a probe")
    func seedGlyphPrimesPositionZero() {
        let s = DriftSchedule.fixture(band: .contextual, admits: 3)
        #expect(s.previousGlyph(forProbe: 1) == s.seedGlyph)
        #expect(s.probeCount == 0)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter DriftHingeTests`

Expect missing `DriftSchedule`, `DriftHinge`, `DriftDeclarationOutcome`, `DriftSchedule.fixture`,
`Corpora.probeChain`. If `Law.complementSpelling` does not exist, build the equivalent law by hand from
E05's RNF fixtures and keep the assertion — the property under test is that comparison is semantic.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** The `fixture` helper belongs in `HunchTestSupport`, not in the test
file, because T03, T07 and T09 all build schedules.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/DriftSchedule.swift` — `DriftSchedule`, `DriftHinge`, `DriftDeclarationOutcome` |
| modify | `HunchCore/Sources/Rounds/DriftBudget.swift` — add `forcedHingeProbe(band:)` beside `servedBands` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `DriftSchedule.fixture(band:admits:)`, `probeChain(band:length:)` |
| create | `HunchCore/Tests/RoundsTests/DriftHingeTests.swift` |
| modify | `tests.json` — the three triggers, `t_hinge`'s off-by-one, the capture-costs-nothing rule, CONTEXT-CARRY |
| modify | `DECISIONS.md` — the two-strikes-not-two-declarations ruling and the trigger-(c) boundary reading |

## Implementation notes

### The shape

```swift
public struct DriftHinge: Sendable, Equatable, Codable {
    public enum Trigger: UInt8, Sendable, Codable { case satiation, capture, forced }
    /// The index of the probe that fired it — still evaluated by `L₁`. For `.capture` this is the
    /// probe count at the moment the declaration was accepted, and no probe fired it.
    public let firedAtProbe: Int
    public let trigger: Trigger
}

public enum DriftDeclarationOutcome: Sendable, Equatable {
    case captured     // pre-hinge, extension == L₁: accepted, fires the hinge, costs nothing
    case correct      // post-hinge, extension == L₂: the win
    case deadLaw      // post-hinge, extension == L₁: the strike §7.6 gives its own counterexample
    case wrong        // anything else, either side of the hinge: the ordinary strike
}

/// A DRIFT round's schedule. Pure: no clock, no store, no RNG after construction. Everything a
/// resume needs is a stored field, and everything else is derived from them (§7.10).
public struct DriftSchedule: Sendable, Equatable {
    public let pair: DriftPair
    public let band: Band
    public let seedGlyph: Glyph
    public private(set) var hinge: DriftHinge?
    public private(set) var seamMarkerIndex: Int?     // set only by `.capture` (§7.3)
    public private(set) var strikes: Int
    public private(set) var deadDeclaration: Bool
    public private(set) var admitsUnderLawOne: Int
    public private(set) var probeCount: Int

    public var hingeFired: Bool { hinge != nil }
    public func lawInForce(atProbe index: Int) -> Law
    public mutating func recordProbe(index: Int, verdictUnderLawOne: Verdict)
    public mutating func recordDeclaration(_ declared: Law, atProbeCount: Int) -> DriftDeclarationOutcome
}
```

### `lawInForce` is a function, not a pointer

```swift
public func lawInForce(atProbe index: Int) -> Law {
    guard let hinge, index > hinge.firedAtProbe else { return pair.lawOne }
    return pair.lawTwo
}
```

Three properties fall out of it and none of them survives a `var currentLaw`:

1. **The whole transcript is re-derivable.** §6.10 stores glyph IDs and recomputes verdicts; DRIFT
   needs the same property across two laws, and it has it because `(hinge, index)` decides.
2. **A resume cannot un-fire the hinge**, which is T09's gate. There is no in-force pointer to fail to
   restore — only `hinge`, which is one `Codable` field.
3. **The reveal's split can re-read the past.** §7.9 part 2 re-evaluates *every* ribbon tile under
   *both* laws, which is a different question from "which law judged it"; keeping both laws live and
   the index a parameter is what lets T08 ask both questions of the same value.

### The off-by-one, which the worked transcript settles

§7.8 says `t_hinge` is "the probe index at which `L₂` took force", which reads as the first `L₂` probe.
§7.7's transcript disagrees and wins: probe 10 is the fourth admit and is annotated *"in force: L₁ →
hinge fires (a)"*, probe 11 is the first `L₂` verdict, and `t_evidence = 11`. So:

> `t_hinge` = the index of the **last probe evaluated by `L₁`**. The first probe evaluated by `L₂` is
> `t_hinge + 1`.

Trigger (c) uses the same convention — §7.11's STARVED-HINGE says it "fires on that probe's boundary",
and a boundary is where a probe ends, so the probe at `ceil(0.80·par(b))` is `L₁`'s and the next is
`L₂`'s. Trigger (b) is the only one where no probe fired the hinge: `firedAtProbe` is the probe count at
the moment of acceptance, so the next probe issued is `t_hinge + 1` and the rule is unchanged. Record
the reading in `DECISIONS.md`; a one-off here shifts `t_evidence`, `R` and the whole Flexibility sample.

### Trigger (b), and the rule it quietly changes

A capture is accepted: the player gets the correct-declaration ring and the inscribe haptic, the Bench
slides away, and the round **continues** — no strike, no score change, no Codex page (§9.10 mints a page
on a correct `L₂` declaration and on nothing else). Two consequences:

- **In DRIFT the hard limit is two *strikes*, not two declarations.** §6.8's "two declarations per
  round, hard" is PROBE's, and §7.4's transition table has no declaration counter at all — it ends the
  round on `strikes == 2`. A capture followed by two wrong declarations is therefore three Seal presses
  and a legal round. Record it in `DECISIONS.md`, because it is a deviation from a sentence in §6.8 that
  a reviewer will find.
- **A capture cannot happen twice.** It is only reachable while `hinge == nil`, and it sets `hinge`.
  After that an `L₁` declaration is `.deadLaw`.

`deadDeclaration` (§7.8) latches on `.deadLaw` and **not** on `.captured`: a capture is a correct
declaration about the law that was in force, which is the opposite of clinging.

### The comparison

`recordDeclaration` compares extensions in the common space with lifting (§4.5, §3.6) — never AST
equality, never `RNF(declared) == RNF(lawOne)`. The lifting decision is `Counterexample.arity`'s
(E06·T08), reused rather than re-derived: a stateless declaration against a contextual `L₁` is judged in
pair space and is wrong unless genuinely equivalent (§6.11 case 15).

### What this file must not contain

No duration, no `Task.sleep`, no ring, no haptic, no `seamMarker` *drawing*. `seamMarkerIndex` is an
`Int?`; the vertical hairline and its 20 pt silhouette are T05's. The accept ring and the inscribe
haptic that §7.3 promises for a capture are cue points published by T08 and played by E20. `08 §2` names
the failure this avoids: timing constants in the core invite a clock into a package whose entire value
is that it has none.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter DriftHingeTests` green, all sixteen tests.
- [ ] `DriftSchedule.forcedHingeProbe` reproduces §7.7's column exactly for all six served bands, and the test derives it from `band.par(for: .probe)` rather than from a literal array.
- [ ] `grep -n "var currentLaw\|var lawInForce\|activeLaw" HunchCore/Sources/Rounds/DriftSchedule.swift` returns nothing.
- [ ] `grep -n "Duration\|sleep\|Animation\|Cue\|haptic" HunchCore/Sources/Rounds/DriftSchedule.swift` returns nothing.
- [ ] `DECISIONS.md` records the `t_hinge` off-by-one and the two-strikes ruling.
- [ ] `tests.json` carries the five entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E12/T02: DriftSchedule, the three hinge triggers and lawInForce(atProbe:)"`

## Out of scope

- The nine phases and the transition table the outcomes drive — **T03**.
- `par_DRIFT` / `cap_DRIFT` / `rec(b)` — **T04**; this task adds only `forcedHingeProbe`, which is on canon's par.
- The seam marker's drawing and the mode sigil — **T05**.
- The dead-law counterexample's *selection* — **T06**; this task only classifies the declaration as `.deadLaw`.
- `t_evidence`, `t_recover`, cling `C` and latency `R` — **T07**.
- The accept ring, the inscribe haptic and the hinge reveal — **T08**, **E09·T09**, **E20**.
- Persisting `hinge`, `seamMarkerIndex` and `admitsBeforeHinge` — **T09**.
