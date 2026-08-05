# T09 — `EchoPhase`, the reveal and interruption

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T08 |
| **Delivers** | Interruption policy (ECHO) · Mode invariants (VERIFICATION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | Owns the beat sheet shape this reveal takes — one `phaseAnimator` over an enum, cue points published as data, and the rule that the model never waits on an animation, which is what lets a backgrounded reveal resume at `settled` having lost nothing. `references/reveal-beats.md` is the file E09·T10's reveal already lives in and this one is added beside it, not invented next to it. |
| `hunch-swift-testing` | The one-lit-member invariant is the epic's headline gate and it is an assertion *at a transition*, which is a different test from T03's assertion at the search's boundary. This skill also owns the seven-named-test discipline for §8.10 and the `tests.json` obligation for a `Mode invariants` row. |
| `hunch-shared-marks` | Three marks land in the reveal and every one has an owner: `VerdictRing.draw` for the cast's true verdicts, its two-concentric-rings form for an intrusion (§4.5), and `GhostFrame.draw` for the empty slot a miss opens in the rail. Drawing any of them by hand here is exactly the second-copy divergence the skill exists to stop. |
| `hunch-swift-code` | The transition table is a pure `(EchoPhase, Event) -> EchoPhase` function in core, tested exhaustively with no `default:`; the durations stay in `HunchUI`. It also owns the ruling that `EchoOutcome` is declared rather than §6.1's `Outcome` being extended. |

## Objective

At the end of this task ECHO's round has a spine: eight phases with a pure transition function, the
asserted invariant that exactly one pool member is lit when the primer hands over to the cast, a
reveal that replays the cast at 400 ms per glyph against the player's own rail, and an interruption
policy under which the first interruption costs nothing and the second ends the round with no ability
update in either direction. All seven of §8.10's edge cases exist as named, passing tests.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.5 (the enum and the whole transition table) | the eight phases verbatim; the seed held 1.2 s; 900 ms primer steps; the 600 ms gap; **"Invariant, asserted: exactly one strip member is lit at this transition"**; `recalling → casting` on the first twin press; `recalling → adjudicating` on the Seal, committing to disk **before** animating; the Codex burnish at 3 marks; and that there is no strike mechanic |
| `GAME_DESIGN.md` | §8.7 (Reveal paragraph) | the cast replays at 400 ms per glyph with each true verdict ring resolving as it lands; the player's rail beneath with its own rings; correct placements pulse once; intrusions take the two-ring conflict of §4.5; misses draw as an empty slot opening in the rail at the right index; the law then renders in rule-tiles, because it is the player's own law and there is nothing to protect |
| `GAME_DESIGN.md` | §8.9 (the whole section) | backgrounding during `casting` voids the cast and restarts it from position 1 on resume, at no cost, **once**; a second interruption in the same round abandons — no score, no Codex effect, **no ability update in either direction**; the nine persisted fields; the strip's lit state recomputed, never stored; `recalling` resumes exactly because recall is untimed |
| `GAME_DESIGN.md` | §8.10 (all seven rows) | BLIND-PRIMER, STALE-POOL, EMPTY-RAIL, RAIL-OVERFILL, DUPLICATE-SUPPRESSION, REPLAY-MID-PLACEMENT, POOL-CHURN-MID-ROUND |
| `GAME_DESIGN.md` | §10.1 (the "not scored at all" list) | an ECHO cast interrupted a second time is not scored |
| `GAME_DESIGN.md` | §4.5, §13.7.1 | the counterexample's two concentric rings — solid is the Loom's, dashed is yours; the reveal's interruption rule (early taps swallowed, a later tap snaps to `settled`, backgrounding resumes at `settled`) |
| `GAME_DESIGN.md` | §11.3 | a burnish sets `burnished = true` and ECHO's `modesSeen` bit and **nothing else** |
| `GAME_DESIGN.md` | §11.13, §12.7 | `round-echo.json` carries the mode's own extra state; the `scenePhase` table's PROBE/DRIFT/ECHO column; the leading chevron suspends silently |
| `GAME_DESIGN.md` | §6.1 | `.voided` is reachable only from `arming`, and only on a resume whose stored law fails its integrity hash |

## TDD — the test comes first

**Step 1 — write the failing test.** Three files.

`HunchCore/Tests/RoundsTests/EchoPhaseTests.swift`:

```swift
import Testing
@testable import Rounds
import HunchTestSupport

@Suite("EchoPhase — §8.5's transition table", .tags(.unit, .presubmission))
struct EchoPhaseTests {

    @Test("the eight phases are §8.5's, in §8.5's order")
    func theEightPhases() {
        #expect(EchoPhase.allCases == [.arming, .priming, .primer, .casting,
                                       .recalling, .adjudicating, .reveal, .settled])
    }

    @Test("the happy path walks arming → settled and touches every phase once")
    func happyPath() {
        var phase = EchoPhase.arming
        let events: [EchoEvent] = [.armed, .seedHeld, .primerComplete, .castComplete,
                                   .sealed, .adjudicated, .revealComplete]
        var visited: [EchoPhase] = [phase]
        for event in events { phase = phase.advance(on: event); visited.append(phase) }
        #expect(visited == EchoPhase.allCases)
    }

    @Test("the replay is the only edge back into casting, and only from recalling")
    func replayEdge() {
        #expect(EchoPhase.recalling.advance(on: .replayRequested) == .casting)
        for phase in EchoPhase.allCases where phase != .recalling {
            #expect(phase.advance(on: .replayRequested) == phase)
        }
    }

    @Test("no event moves a settled round")
    func settledIsTerminal() {
        for event in EchoEvent.allCases {
            #expect(EchoPhase.settled.advance(on: event) == .settled)
        }
    }

    @Test("there is no strike edge anywhere in the table")
    func noStrikeEdge() {
        #expect(!EchoEvent.allCases.contains { "\($0)".localizedCaseInsensitiveContains("strike") })
        #expect(EchoPhase.adjudicating.advance(on: .sealed) == .adjudicating)   // a commit is final
    }

    @Test("the table is total: every (phase, event) pair has an answer",
          arguments: EchoPhase.allCases, EchoEvent.allCases)
    func totality(_ phase: EchoPhase, _ event: EchoEvent) {
        _ = phase.advance(on: event)                 // no trap, no fatalError, no default:
    }
}

@Suite("The ECHO round invariants — §8.5, §14.1 Mode invariants", .tags(.unit, .presubmission))
struct EchoRoundInvariantTests {

    /// The epic's headline gate, asserted at the transition rather than at the search.
    @Test("exactly one strip member is lit at primer → casting, over a seeded corpus")
    func oneLitMemberAtCastingEntry() throws {
        for index in 0..<Corpora.echoPoolCount {
            guard let round = Corpora.armedEchoRound(index: index) else { continue }
            #expect(round.phase == .primer)
            #expect(round.litMembers.count == round.pool.members.count)   // all lit before the primer

            round.advanceToCasting()
            #expect(round.phase == .casting)
            guard round.litMembers.count == 1 else {
                Issue.record("round \(index) entered casting with \(round.litMembers.count) lit members")
                return
            }
            #expect(round.litMembers == [round.inForce.lawKey])
        }
    }

    @Test("the lit set is recomputed on restore and never read from disk")
    func litStateIsNeverStored() throws {
        let round = try #require(Corpora.armedEchoRound(index: 0))
        round.advanceToCasting()
        let snapshot = round.snapshot()

        let encoded = try JSONEncoder().encode(snapshot)
        let json = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(json["litMembers"] == nil)
        #expect(json["survivors"] == nil)

        let restored = EchoRoundState(restoring: snapshot)
        #expect(restored.litMembers == round.litMembers)
    }

    @Test("the snapshot carries exactly §8.9's nine fields plus the integrity hash")
    func snapshotShape() throws {
        let round = try #require(Corpora.armedEchoRound(index: 1))
        let encoded = try JSONEncoder().encode(round.snapshot())
        let keys = Set(try #require(try JSONSerialization.jsonObject(with: encoded)
                                    as? [String: Any]).keys)
        #expect(keys == ["pool", "lawKey", "primerChain", "cast", "load",
                         "phase", "rail", "replayed", "interruptions", "lawHash"])
    }
}
```

`HunchCore/Tests/RoundsTests/EchoInterruptionTests.swift`:

```swift
import Testing
@testable import Rounds
import HunchTestSupport

@Suite("ECHO interruption — §8.9", .tags(.unit, .presubmission))
struct EchoInterruptionTests {

    private func casting(_ index: Int = 0) throws -> EchoRoundState {
        let round = try #require(Corpora.armedEchoRound(index: index))
        round.advanceToCasting()
        for _ in 0..<4 { round.advanceCast() }
        return round
    }

    @Test("the first interruption restarts the cast from position 1, free")
    func firstInterruptionIsFree() throws {
        let round = try casting()
        let castBefore = round.cast
        round.interrupt()
        let restored = EchoRoundState(restoring: round.snapshot())

        #expect(restored.interruptions == 1)
        #expect(restored.phase == .casting)
        #expect(restored.castPosition == 0)          // from position 1 on the next advance
        #expect(restored.cast == castBefore)         // nothing re-sampled
        #expect(!restored.replayed)                  // free: the replay is still available
        #expect(restored.outcome == nil)
    }

    @Test("the second interruption abandons the round")
    func secondInterruptionAbandons() throws {
        let round = try casting()
        round.interrupt()
        var restored = EchoRoundState(restoring: round.snapshot())
        restored.advanceToCasting()
        restored.interrupt()

        #expect(restored.interruptions == 2)
        #expect(restored.phase == .settled)
        #expect(restored.outcome == .abandoned)
    }

    @Test("an abandoned round updates nothing in either direction")
    func abandonUpdatesNothing() throws {
        let round = try casting()
        round.interrupt(); round.interrupt()
        let settlement = try #require(round.settlement)

        #expect(settlement.outcome == .abandoned)
        #expect(settlement.score == nil)             // no score
        #expect(settlement.abilityUpdate == nil)     // no θ, in either direction
        #expect(settlement.burnish == nil)           // no Codex effect
        #expect(!settlement.isScored)                // §10.1's "not scored at all" list
    }

    @Test("an interruption during recalling changes nothing — recall is untimed")
    func recallingResumesExactly() throws {
        let round = try #require(Corpora.armedEchoRound(index: 2))
        round.advanceToCasting()
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        #expect(round.phase == .recalling)
        for index in [3, 1] { round.place(castIndex: index) }

        round.interrupt()
        let restored = EchoRoundState(restoring: round.snapshot())
        #expect(restored.interruptions == 0)
        #expect(restored.phase == .recalling)
        #expect(restored.rail.placed == [3, 1])
    }

    @Test("a replay is not an interruption, and an interruption is not a replay")
    func replayAndInterruptionAreSeparateCounters() throws {
        let round = try #require(Corpora.armedEchoRound(index: 3))
        round.advanceToCasting()
        for _ in 0..<round.cast.glyphs.count { round.advanceCast() }
        round.requestReplay()
        #expect(round.interruptions == 0)
        #expect(round.replayed)

        round.interrupt()
        #expect(round.interruptions == 1)
        #expect(round.replayed)                      // still spent; the restart does not refund it
    }

    @Test("a suspend from casting counts as an interruption, so the chevron is not a free re-view")
    func chevronFromCastingCounts() throws {
        let round = try casting(4)
        round.suspend()
        #expect(round.interruptions == 1)
    }

    @Test("a stored law that fails its integrity hash voids, and only from arming (§6.1)")
    func integrityFailureVoids() throws {
        let round = try #require(Corpora.armedEchoRound(index: 5))
        var snapshot = round.snapshot()
        snapshot.lawHash &+= 1
        let restored = EchoRoundState(restoring: snapshot)
        #expect(restored.phase == .settled)
        #expect(restored.outcome == .voided)
        #expect(restored.settlement?.abilityUpdate == nil)
    }
}
```

`HunchCore/Tests/RoundsTests/EchoEdgeCaseTests.swift` — seven names, exactly §8.10's seven rows:

```swift
import Testing
@testable import Rounds
import HunchTestSupport

@Suite("§8.10's seven edge cases, at the round", .tags(.unit, .presubmission))
struct EchoEdgeCaseTests {

    @Test("BLIND-PRIMER: an unseparable pool drops two and the round arms on the reduced pool")
    func blindPrimer() throws {
        let round = try #require(Corpora.echoRound(pool: Corpora.unseparablePool(dropCyclesNeeded: 1)))
        #expect(round.pool.members.count == 6)
        round.advanceToCasting()
        #expect(round.litMembers.count == 1)
        #expect(round.pool.members.contains { $0.lawKey == round.inForce.lawKey })
    }

    @Test("STALE-POOL: a pool far under target serves at ℓ = 8 or steps out of the rotation")
    func stalePool() {
        let low = Corpora.echoPool(difficulties: [0.02, 0.03, 0.04])
        #expect(EchoDifficulty.selectFromPool(low, targetDelta: 0.95) == .skip(.stalePool))
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(low, targetDelta: 0.20)
        else { return Issue.record("expected a serve at ℓ = 8") }
        #expect(serving.load == .eight)
    }

    @Test("EMPTY-RAIL: the Seal on an empty rail commits, scores 0 and asks nothing")
    func emptyRail() throws {
        let round = try #require(Corpora.recallingEchoRound(index: 0))
        round.seal()
        #expect(round.confirmationRequested == false)      // "an empty answer is a real answer"
        #expect(round.score?.points == 0)
        #expect(round.score?.marks == 0)
        #expect(round.score?.isSuccess == false)
    }

    @Test("RAIL-OVERFILL: placing all L tiles is legal and is dominated")
    func railOverfill() throws {
        let round = try #require(Corpora.recallingEchoRound(index: 1))
        for index in 0..<round.cast.glyphs.count { round.place(castIndex: index) }
        round.seal()
        #expect(round.score?.marks == 0)
        #expect(round.rail.placed.count == round.cast.glyphs.count)
    }

    @Test("DUPLICATE-SUPPRESSION: no cast ever contains a glyph twice", arguments: 0..<64)
    func duplicateSuppression(_ index: Int) throws {
        let round = try #require(Corpora.recallingEchoRound(index: index))
        #expect(Set(round.cast.glyphs).count == round.cast.glyphs.count)
    }

    @Test("REPLAY-MID-PLACEMENT: the replay runs, the rail survives, replayF drops to 0.6")
    func replayMidPlacement() throws {
        let round = try #require(Corpora.recallingEchoRound(index: 2))
        for index in [2, 5] { round.place(castIndex: index) }
        round.requestReplay()
        #expect(round.rail.placed == [2, 5])
        #expect(round.replayed)
        round.requestReplay()
        #expect(round.replayFactor == EchoScore.replayPenalty)
    }

    @Test("POOL-CHURN-MID-ROUND: a Codex write cannot reach a suspended round")
    func poolChurnMidRound() throws {
        let round = try #require(Corpora.recallingEchoRound(index: 3))
        let snapshot = round.snapshot()

        var codexPool = round.pool
        for member in Corpora.echoPoolMembers(count: 3, seed: 0xFACE) { codexPool.inscribe(member) }

        let restored = EchoRoundState(restoring: snapshot)
        #expect(restored.pool == round.pool)
        #expect(restored.pool != codexPool)
        #expect(restored.litMembers.count == 1)
    }
}
```

And `Modules/Tests/LoomFeatureTests/EchoRevealTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("The ECHO reveal — §8.7", .tags(.unit, .presubmission))
@MainActor
struct EchoRevealTests {

    @Test("the reveal replays the cast at 400 ms per glyph and has L + 1 beats",
          arguments: LoadIndex.allCases)
    func beatCount(_ load: LoadIndex) {
        let sheet = EchoRevealSheet(load: load, env: .reference)
        #expect(sheet.step == Dur.echoRevealStep)
        #expect(sheet.beats.count == load.length + 1)          // L glyphs + the law in rule-tiles
        #expect(sheet.total == Dur.echoRevealStep * load.length + sheet.beats.last!.duration)
    }

    @Test("each cast glyph's true verdict ring resolves as it lands")
    func trueRingsResolveInOrder() {
        let round = Fixtures.settledEchoRound()
        let sheet = EchoRevealSheet(round: round, env: .reference)
        #expect(sheet.beats.prefix(round.cast.glyphs.count).enumerated().allSatisfy { position, beat in
            beat.castVerdict == round.trueVerdict(at: position)
        })
    }

    @Test("a correct placement pulses once, an intrusion takes two rings, a miss opens a slot")
    func threeRailStates() {
        // truth [2,5,6,10], answer [2,6,5,9]: 2/5/6 correct, 9 an intrusion, 10 a miss.
        let round = Fixtures.settledEchoRound(truth: [2, 5, 6, 10], answer: [2, 6, 5, 9])
        let sheet = EchoRevealSheet(round: round, env: .reference)
        #expect(sheet.railMarks.filter { $0 == .pulse }.count == 3)
        #expect(sheet.railMarks.filter { $0 == .conflict }.count == 1)
        #expect(sheet.railMarks.filter { $0 == .openSlot }.count == 1)
    }

    @Test("the miss's slot opens at the index the missing glyph should have occupied")
    func missOpensAtTheRightIndex() {
        let round = Fixtures.settledEchoRound(truth: [2, 5, 6, 10], answer: [2, 6, 5, 9])
        let sheet = EchoRevealSheet(round: round, env: .reference)
        #expect(sheet.openSlotIndices == [3])                  // 10 is the fourth of the four lawful
    }

    @Test("the intrusion's two rings are the counterexample's, not a new mark")
    func intrusionReusesTheTwoRingConflict() {
        let probe = RenderProbe(EchoRevealView(round: Fixtures.settledEchoRound(), env: .reference))
        #expect(probe.concentricRingPairs == 1)
        #expect(probe.marksDrawnOutsideMarksDirectory.isEmpty)
    }

    @Test("the law renders in rule-tiles — it is the player's own law")
    func lawIsRevealed() {
        let probe = RenderProbe(EchoRevealView(round: Fixtures.settledEchoRound(), env: .reference))
        #expect(probe.ruleTileCount > 0)
    }

    @Test("Reduce Motion crossfades to the settled composition and keeps the marks")
    func reduceMotion() {
        let sheet = EchoRevealSheet(round: Fixtures.settledEchoRound(), env: .reduceMotion)
        #expect(sheet.beats.count == 1)
        #expect(sheet.total == Dur.revealCrossfade)
        #expect(sheet.railMarksAreAlreadyStruck)
    }

    @Test("a 3-mark round emits a burnish request and nothing else")
    func burnishAtThreeMarks() {
        let three = Fixtures.settledEchoRound(truth: [1, 4, 7], answer: [1, 4, 7], replayed: false)
        #expect(three.settlement?.burnish?.lawKey == three.inForce.lawKey)

        let two = Fixtures.settledEchoRound(truth: [1, 4, 7], answer: [7, 4, 1], replayed: false)
        #expect(two.settlement?.burnish == nil)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter EchoPhaseTests`, `--filter EchoRoundInvariantTests`,
`--filter EchoInterruptionTests`, `--filter EchoEdgeCaseTests`, then
`xcodebuild test … -only-testing:LoomFeatureTests/EchoRevealTests`.
Missing symbols only. `EchoRoundState` is the **core** value the phase machine operates on; `EchoRound`
(`LoomFeature`, T04) stays thin over it, exactly as `Round` is thin over `RoundPhase` (`08 §2`).

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/EchoPhase.swift` — `EchoEvent` and `advance(on:)` |
| create | `HunchCore/Sources/Rounds/EchoRoundState.swift` |
| create | `HunchCore/Sources/Rounds/EchoSnapshot.swift` |
| create | `HunchCore/Sources/Rounds/EchoOutcome.swift` |
| modify | `HunchCore/Sources/Persistence/StoreFile.swift` — confirm `round(.echo)` needs no new case |
| create | `Modules/Sources/LoomFeature/EchoRevealView.swift` |
| create | `Modules/Sources/LoomFeature/EchoRevealSheet.swift` |
| modify | `Modules/Sources/LoomFeature/EchoRound.swift` — delegate the phase to `EchoRoundState` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `Dur.echoRevealStep` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `armedEchoRound`, `recallingEchoRound`, `echoRound(pool:)` |
| create | `HunchCore/Tests/RoundsTests/EchoPhaseTests.swift` |
| create | `HunchCore/Tests/RoundsTests/EchoInterruptionTests.swift` |
| create | `HunchCore/Tests/RoundsTests/EchoEdgeCaseTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/EchoRevealTests.swift` |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/round-echo.json` — a suspended ECHO round |
| modify | `tests.json` — eleven entries |
| modify | `DECISIONS.md` — `EchoOutcome`, and what counts as an interruption |

## Implementation notes

### The transition table

`(EchoPhase, EchoEvent) -> EchoPhase`, pure, exhaustive, no `default:` — the same shape E07·T07 gave
`RoundPhase` and for the same reason (`08 §2`: durations are `HunchUI`, transitions are core). §8.5's
table has eight rows and every one becomes a `case` pair; every other pair returns its input unchanged,
written as an explicit `default`-free fallthrough at the end of the `switch` over events rather than as
a `default:` on the phase.

The one non-obvious edge is `recalling → casting` on the first twin press (T06), and the one edge that
must **not** exist is any path out of `adjudicating` back to `recalling`: §8.5's closing paragraph is
categorical, and `noStrikeEdge` asserts it by construction rather than by inspection.

### The invariant, asserted where §8.5 says to

§8.5 writes it into the table: *"`primer → casting` … **Invariant, asserted:** exactly one strip
member is lit at this transition."* So it is a `precondition` in the transition itself, not a comment:

```swift
mutating func advanceToCasting() {
    let lit = pool.survivors(of: primerChain, upTo: primerChain.glyphs.count, observed: primerVerdicts)
    precondition(lit == [inForce.lawKey],
                 "ECHO armed a primer that leaves \(lit.count) members lit; see §8.2 and §8.5")
    phase = .casting
}
```

A `precondition` rather than an `assert`, because it survives a Release build: a round that reaches
`casting` with two lit members is a round in which the player is being asked to apply a law the game
cannot name, and failing loudly is strictly better than playing it. It cannot fire in production —
T03's search only returns a chain that satisfies it — which is exactly the profile of an invariant
worth writing down. The corpus test above is the same claim exercised over hundreds of pools.

### `EchoOutcome`, and why §6.1's `Outcome` is not extended

```swift
public enum EchoOutcome: Hashable, Sendable {
    case committed(marks: Int)     // 0…3; the Seal was pressed and the answer scored
    case abandoned                 // a second interruption in one round (§8.9)
    case voided                    // the restored law failed its integrity hash (§6.1)
}
```

§6.1's `Outcome` has five cases and three of them — `broken`, `exhausted`, `inscribed` — are wrong here:
ECHO has no strike, no cap, and mints no page. Forcing an ECHO commit into `.inscribed(marks:fracture:)`
would put a lie in the round record that E15 and E16 would then read. Declare a mode-local outcome,
map it at the one boundary that needs the shared shape (`RoundRecord`), and record the reasoning in
`DECISIONS.md`. This mirrors whatever E12 did for DRIFT's own extra states; check that file first and
match its shape rather than inventing a second convention.

### Interruption, precisely

§8.9 says "backgrounding during `casting`". Three questions it leaves open, answered here and recorded
in `DECISIONS.md` because each one is exploitable if answered the other way:

1. **What counts.** `scenePhase → .background`, termination, **and a chevron suspend** — while `phase == .casting`. The chevron is included because the effect on the player's information is identical to a backgrounding, and excluding it would turn §12.7's silent suspend into an unlimited free re-viewing, which is precisely what §8.9's closing sentence rules out.
2. **What does not count.** `scenePhase → .inactive` — a banner, control centre, the app switcher. §12.7's PROBE/DRIFT/ECHO column says "nothing visible; the round is already on disk", and the cast continues at cadence. That is the spec as written; the priced replay is the remedy, and adding a pause here would give ECHO a clock it does not have (`references/transitions.md`: there is no pause control in PROBE, DRIFT or ECHO).
3. **When it does not count at all.** During `priming`, `primer`, `recalling`, `adjudicating` and `reveal`. The primer strip is on screen for the rest of the round and is recomputable; recall is untimed and "resumes exactly" (§8.9); the reveal resumes at `settled` (§13.7.1).

The counter itself:

```swift
mutating func interrupt() {
    guard phase == .casting else { return }
    interruptions += 1
    if interruptions >= 2 { settle(.abandoned) } else { castPosition = 0 }   // restart from position 1
}
```

`castPosition = 0` and **nothing else** — `replayed` is untouched (the free restart is not a refund),
`rail` is untouched, and the cast value is untouched. The `>= 2` rather than `== 2` is deliberate: a
third interruption of an already-abandoned round is a no-op because `phase` is `settled`, but the
comparison should not be the thing that depends on that.

`abandoned` settles with `score == nil`, `abilityUpdate == nil` and `burnish == nil`. §10.1's list is
explicit that the round is **not scored at all**, and §8.9 is explicit that there is no ability update
*in either direction* — so no `isSuccess: false` sneaks through to the estimator, which would be a
down-update wearing a different name. Whether the abandonment sets a sticky target follows E10·T04's
existing rule for an abandoned round and is not re-decided here.

### The snapshot

§8.9's nine fields plus `lawHash`: pool snapshot, law id, primer chain, cast, `ℓ`, phase, rail
contents, `replayed`, `interruptions`. The key-set assertion above is what stops a tenth appearing —
and the tenth that will try to appear is the strip's lit state, which §8.9 forbids: *"a pure function
of `(pool snapshot, primer chain, primer position)` and is recomputed on resume, never stored."*
Storing it would let a resumed round disagree with the law it restored, which is the same class of bug
`lawHash` exists to catch.

The pool inside the snapshot is **the armed pool** — post-BLIND-PRIMER-drop (T03) — which is what makes
POOL-CHURN-MID-ROUND impossible rather than merely unlikely: the round holds a value, and values do not
churn.

Write it into `round-echo.json` through `StoreFile.round(.echo)`, which E07·T01 already generates from
`Mode`; no new case is needed and adding one would break the reset map's exhaustive switch.

### The reveal

One `phaseAnimator` over `L + 1` beats: `L` cast steps at `Dur.echoRevealStep` (400 ms, §8.7) and one
closing beat that renders the law in rule-tiles. The beat count assertion is the same device E09·T10
uses so §8.7 and the shipped sheet cannot drift apart.

Per cast step, three things happen at once and all three are marks with owners:

| What | Mark | Source |
|---|---|---|
| the cast glyph's **true** verdict | `VerdictRing.draw` in its settled form | §8.7 |
| a correct placement in the rail beneath | one pulse — the admit micro-response at reduced amplitude | §8.7, §13.7.2 |
| an intrusion | the **two concentric rings** of §4.5 — solid is the Loom's reading, dashed is yours | §4.5, `references/verdict-ring.md` |
| a miss | an **empty slot opening** in the rail at the right index — `GhostFrame.draw`'s dashed hollow | §8.7 |

*"The right index"* is the position the missed cast index occupies in `truth`, ascending — the reveal
draws the correct rail beneath the cast, so a miss is a gap in that rail rather than a gap in the
player's. `openSlotIndices == [3]` in the test is that reading made concrete: `10` is the fourth of the
four lawful positions, so the slot opens fourth.

**The law is revealed in full and that is deliberate.** §8.7: *"it is the player's own law, so there is
nothing to protect."* The rule-tiles are E09·T02's canvases at the Codex scale, composed read-only —
this is the one reveal in the game with no secret in it.

**Reduce Motion** takes §13.7.4's law-reveal row unchanged: one crossfade to the settled composition
with the marks already struck. The rail's three mark states are *information*, so they survive the
substitution; only their staging is dropped.

**Skip and backgrounding** follow §13.7.1's interruption rule as E09·T10 implemented it — early taps
swallowed so the moment always starts, a later tap snaps straight to `settled`, and backgrounding
resumes at `settled`. Reuse E09·T10's threshold and its skip machinery; do not introduce a second
number.

### Burnish

§8.5's `reveal → settled` row: *"Codex burnish at 3 marks."* The settlement emits a request and applies
nothing:

```swift
public struct EchoBurnish: Hashable, Sendable { public let lawKey: UInt64 }
```

E15·T06 applies it, and §11.3 fixes exhaustively what it does: sets `burnished = true`, sets ECHO's bit
in `modesSeen`, and touches `timesFound`, `bestProbes`, `bestMarks`, `unfractured` and `lastFoundAt`
**not at all**. It is not a re-find and draws no re-strike ring. Emitting a request rather than mutating
a page keeps that boundary where §11.3 put it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoPhaseTests` green, all six, including the total-coverage parameterised sweep.
- [ ] `swift test --package-path HunchCore --filter EchoRoundInvariantTests` green — the one-lit-member corpus test is the epic's gate 2.
- [ ] `swift test --package-path HunchCore --filter EchoInterruptionTests` green, all eight — the epic's gate 5.
- [ ] `swift test --package-path HunchCore --filter EchoEdgeCaseTests` green, and the seven test names are exactly `blindPrimer`, `stalePool`, `emptyRail`, `railOverfill`, `duplicateSuppression`, `replayMidPlacement`, `poolChurnMidRound` — the epic's gate 6.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/EchoRevealTests` green, all eight.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/EchoPhase.swift` returns nothing.
- [ ] `grep -n "litMembers\|survivors" HunchCore/Sources/Rounds/EchoSnapshot.swift` returns nothing.
- [ ] The precondition has been exercised once by hand with a deliberately non-separating chain, observed to trap with its message, and the change reverted.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/round-echo.json` exists, loads green, and is under 512 KB.
- [ ] `tests.json` carries eleven entries: the phase table's totality, the one-lit-member invariant (a `Mode invariants` row), the lit state's absence from disk, the snapshot's field set, the free restart, the abandonment with no update, the reveal's beat count, the three rail mark states, the burnish trigger, the `.voided` path, and the seven edge cases as one grouped entry naming each.
- [ ] `DECISIONS.md` records `EchoOutcome` and the three interruption rulings.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T09: EchoPhase, the reveal, the interruption policy and §8.10's seven cases"`

## Out of scope

- Applying the burnish to a `CodexPage` — **E15·T06**; this task emits the request.
- The Rasch update the settlement feeds, and the sticky target an abandonment sets — **E11·T02/T03**, **E10·T04**.
- The `scenePhase` plumbing, the chevron's drawing and the 600 ms `.active` spin-up — **E17·T09**; this task defines what an interruption *means* and counts it.
- Audio and haptic cues on the reveal's beats — **E20**; publish the cue points as data.
- The Retention sample the transcript feeds — **E16·T05**.
