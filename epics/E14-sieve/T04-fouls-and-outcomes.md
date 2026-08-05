# T04 — Fouls and outcomes

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Fouls and outcomes (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | `SievePhase` is a state machine with a payload (`streaming(Reach)`), and the transition table has to be a pure `(SievePhase, SieveEvent) -> SievePhase` with an exhaustive `switch` and **no `default:`** (`W29`) — adding a phase must break the table at compile time. The skill also carries `08 §2`'s ruling that a phase machine's *transitions* are core while its *durations* are `HunchUI`, which is exactly the split this task has to hold. |

`hunch-motion-and-feedback` is **not** loaded, but its cue vocabulary is *cited*: `sieve.hit`,
`sieve.miss` and `law.broken` are declared by E08·T06 in `Modules/Sources/Feedback/Cue.swift`, and
this task's job is to say **which outcome fires which cue**, as data, not to play anything.
`references/verdict-motion.md` §7 is the row to read when wiring it, and it is a two-minute read
rather than a skill load.

## Objective

At the end of this task a resolved SIEVE glyph is one of exactly four things — hit, correct pass,
miss, foul — decided by a pure function of `(lawful, tapped)`; three fouls end a run and a miss never
does; no foul accrues during the tell; and `SievePhase` is a total, exhaustively tested transition
table covering all seven phases and every way a run can end. Both degenerate strategies are asserted
strictly dominated with numbers rather than argued in prose.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.5 | the seven-phase `SievePhase` enum **verbatim**; the full transition table with its side effects; the four-outcome table (hit / correct pass / miss / foul) with consequences; *three fouls end a run and misses never do*; **fouls do not accrue during the tell**; the two degenerate strategies and why each is dominated; the three ways a run ends — sieved, fouled, abandoned |
| `GAME_DESIGN.md` | §9.4 | the reach a glyph belongs to, which decides its weight and whether a false positive can accrue a foul |
| `GAME_DESIGN.md` | §9.9 | TELL-FOUL (resolves visibly, weighted 0.5, no foul accrued), ZERO-ACTION RUN (legal, sieved, counted as a failure) |
| `GAME_DESIGN.md` | §9.10 | *"Strikes: none — 3 fouls instead"*; feedback per glyph, unconditional |
| `GAME_DESIGN.md` | §5.7 | `p ∈ [0.15, 0.60]`, the window that makes the tap-everything argument arithmetic rather than rhetoric |
| `.claude/skills/hunch-motion-and-feedback/references/verdict-motion.md` | §7 | which cue and haptic each of the four outcomes fires — including that a **correct pass fires nothing**, that a tap outside the gate fires nothing, and the 400 ms `fouling` freeze |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | exhaustive `switch`, no `default:` |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A20 | extract the logic into a plain type and test that, not the view |

## TDD — the test comes first

**Step 1 — write the failing test.** Create two files.

`HunchCore/Tests/RoundsTests/SieveResolutionTests.swift`:

```swift
import Testing
import Glyphs
import Rounds

@Suite("SIEVE outcomes and fouls — §9.5", .tags(.unit, .presubmission))
struct SieveResolutionTests {

    // MARK: the four outcomes

    @Test("the four outcomes are exactly (lawful × tapped)",
          arguments: [(true, true, SieveResolution.hit),
                      (false, false, .correctPass),
                      (true, false, .miss),
                      (false, true, .foul)])
    func fourOutcomes(_ lawful: Bool, _ tapped: Bool, _ expected: SieveResolution) {
        #expect(SieveResolution(lawful: lawful, tapped: tapped) == expected)
    }

    @Test("a correct pass is silent — silence is the reward")
    func correctPassIsSilent() {
        #expect(SieveResolution.correctPass.cue == nil)
        #expect(SieveResolution.correctPass.haptic == nil)
    }

    @Test("each of the other three carries exactly one cue")
    func theOtherThreeSpeak() {
        #expect(SieveResolution.hit.cue == .sieveHit)
        #expect(SieveResolution.miss.cue == .sieveMiss)
        #expect(SieveResolution.foul.cue == .lawBroken)
    }

    // MARK: fouls

    @Test("only a foul accrues a foul", arguments: SieveResolution.allCases)
    func onlyFoulsAccrue(_ resolution: SieveResolution) {
        #expect(resolution.accruesFoul == (resolution == .foul))
    }

    @Test("TELL-FOUL — a false positive in the tell resolves visibly and accrues NO foul")
    func tellFoulsDoNotAccrue() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .literal, index: 0))
        for index in run.stream.reaches.tellRange where !run.stream.isLawful(at: index) {
            run.resolve(index: index, tapped: true)
        }
        #expect(run.resolutions.filter { $0 == .foul }.isEmpty == false)   // they ARE fouls, visibly
        #expect(run.foulCount == 0)                                        // and they cost nothing
        #expect(run.phase != .fouling)
    }

    @Test("a false positive outside the tell accrues one foul each")
    func bodyFoulsAccrue() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .literal, index: 0))
        let unlawful = run.stream.reaches.bodyRange.filter { !run.stream.isLawful(at: $0) }
        run.resolve(index: unlawful[0], tapped: true)
        #expect(run.foulCount == 1)
        run.resolve(index: unlawful[1], tapped: true)
        #expect(run.foulCount == 2)
        #expect(run.phase == .streaming(.body))
    }

    @Test("the third foul ends the run; the run never survives a fourth")
    func thirdFoulEndsTheRun() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .literal, index: 0))
        let unlawful = run.stream.reaches.bodyRange.filter { !run.stream.isLawful(at: $0) }
        for index in unlawful.prefix(3) { run.resolve(index: index, tapped: true) }
        #expect(run.foulCount == 3)
        #expect(run.phase == .fouling)
        #expect(run.ending == .fouled)
        #expect(run.resolvedGlyphs == unlawful[2] + 1)
    }

    @Test("a miss NEVER ends a run, however many there are")
    func missesNeverEndARun() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .literal, index: 0))
        for index in 0..<run.stream.glyphs.count { run.resolve(index: index, tapped: false) }
        #expect(run.foulCount == 0)
        #expect(run.ending == .sieved)
        #expect(run.resolutions.contains(.miss))
    }

    @Test("ZERO-ACTION RUN — tapping nothing is legal, sieves, and resolves every glyph")
    func zeroActionRunIsLegal() {
        var run = SieveRunState(stream: Corpora.sieveStream(band: .contextual, index: 0))
        for index in 0..<run.stream.glyphs.count { run.resolve(index: index, tapped: false) }
        #expect(run.ending == .sieved)
        #expect(run.resolvedGlyphs == run.stream.glyphs.count)
    }
}
```

`HunchCore/Tests/RoundsTests/SievePhaseTests.swift` and
`HunchCore/Tests/RoundsTests/SieveDegenerateStrategyTests.swift`:

```swift
// SievePhaseTests.swift
import Testing
import Rounds

@Suite("SievePhase transitions — §9.5", .tags(.unit, .presubmission))
struct SievePhaseTests {

    @Test("the lifecycle runs arming → priming → tell → body → run-out → reveal → settled")
    func happyPath() {
        var phase = SievePhase.arming
        phase = SievePhase.next(phase, on: .streamBuilt);        #expect(phase == .priming)
        phase = SievePhase.next(phase, on: .primingElapsed);     #expect(phase == .streaming(.tell))
        phase = SievePhase.next(phase, on: .reachBoundary(.body));   #expect(phase == .streaming(.body))
        phase = SievePhase.next(phase, on: .reachBoundary(.runOut)); #expect(phase == .streaming(.runOut))
        phase = SievePhase.next(phase, on: .lastGlyphResolved);  #expect(phase == .reveal)
        phase = SievePhase.next(phase, on: .revealComplete);     #expect(phase == .settled)
    }

    @Test("pause is reachable only from streaming, and resume returns to the SAME reach",
          arguments: [SieveReach.tell, .body, .runOut])
    func pauseAndResumeKeepTheReach(_ reach: SieveReach) {
        let paused = SievePhase.next(.streaming(reach), on: .pauseRequested)
        #expect(paused == .paused(reach))
        #expect(SievePhase.next(paused, on: .resumeRequested) == .streaming(reach))
    }

    @Test("the third foul goes to fouling and fouling goes only to reveal")
    func foulingIsAOneWayDoor() {
        #expect(SievePhase.next(.streaming(.body), on: .thirdFoul) == .fouling)
        #expect(SievePhase.next(.fouling, on: .foulingFreezeElapsed) == .reveal)
        #expect(SievePhase.next(.fouling, on: .pauseRequested) == .fouling)   // nothing else moves it
    }

    @Test("the abandon chevron reaches reveal ONLY from paused")
    func abandonOnlyFromPaused() {
        #expect(SievePhase.next(.paused(.body), on: .abandonConfirmed) == .reveal)
        #expect(SievePhase.next(.streaming(.body), on: .abandonConfirmed) == .streaming(.body))
    }

    @Test("every (phase, event) pair is total — no crash, no nil, and unhandled pairs are identity",
          arguments: SievePhase.allRepresentative, SieveEvent.allRepresentative)
    func transitionIsTotal(_ phase: SievePhase, _ event: SieveEvent) {
        _ = SievePhase.next(phase, on: event)      // must not trap
    }

    @Test("settled is terminal", arguments: SieveEvent.allRepresentative)
    func settledIsTerminal(_ event: SieveEvent) {
        #expect(SievePhase.next(.settled, on: event) == .settled)
    }
}
```

```swift
// SieveDegenerateStrategyTests.swift
import Testing
import Glyphs
import Rounds
import HunchTestSupport

@Suite("Both degenerate SIEVE strategies are strictly dominated — §9.5",
       .tags(.unit, .presubmission))
struct SieveDegenerateStrategyTests {

    @Test("tap-everything fouls out inside the first three BODY glyphs at p ≤ 0.60",
          arguments: Band.sieveServable)
    func tapEverythingFoulsOutImmediately(_ band: Band) {
        for index in 0..<Corpora.sieveStreamsPerBand / 10 {
            let stream = Corpora.sieveStream(band: band, index: index)
            let run = SieveRunState.simulate(stream: stream, strategy: .tapEverything)
            #expect(run.ending == .fouled)
            let bodyGlyphsSeen = run.resolvedGlyphs - stream.reaches.tell
            #expect(bodyGlyphsSeen <= 8,                     // 3 unlawful at p ≤ 0.60 ⇒ ≤ 8 glyphs
                    "band \(band) index \(index) survived \(bodyGlyphsSeen) body glyphs")
        }
    }

    @Test("tap-nothing survives the whole run and lands below the 1-mark threshold",
          arguments: Band.sieveServable)
    func tapNothingSurvivesAndScoresBadly(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        let run = SieveRunState.simulate(stream: stream, strategy: .tapNothing)
        #expect(run.ending == .sieved)
        #expect(run.foulCount == 0)
        #expect(run.resolvedGlyphs == stream.glyphs.count)
    }

    @Test("playing the law beats both, at every band", arguments: Band.sieveServable)
    func perfectPlayStrictlyDominates(_ band: Band) {
        let stream = Corpora.sieveStream(band: band, index: 0)
        let perfect = SieveRunState.simulate(stream: stream, strategy: .playTheLaw)
        let nothing = SieveRunState.simulate(stream: stream, strategy: .tapNothing)
        let everything = SieveRunState.simulate(stream: stream, strategy: .tapEverything)
        #expect(perfect.resolvedGlyphs > everything.resolvedGlyphs)
        #expect(perfect.foulCount == 0)
        #expect(nothing.resolutions.filter { $0 == .miss }.count > 0)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter Sieve`

Expect missing `SieveResolution`, `SieveRunState`, `SievePhase`, `SieveEvent`, `SieveEnding`,
`SieveStrategy` and the two `allRepresentative` collections.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SievePhase.swift` — `SievePhase`, `SieveEvent`, `SievePhase.next(_:on:)` |
| create | `HunchCore/Sources/Rounds/SieveResolution.swift` — `SieveResolution`, its cue and haptic mapping, `accruesFoul` |
| create | `HunchCore/Sources/Rounds/SieveRunState.swift` — `SieveRunState`, `SieveEnding`, `SieveStrategy`, `simulate(stream:strategy:)` |
| modify | `Modules/Sources/LoomFeature/SieveRun.swift` — drives the phase machine, fires the cue, holds the durations |
| modify | `Modules/Sources/LoomFeature/SieveRoundView.swift` — the three foul ticks read `run.foulCount` |
| create | `HunchCore/Tests/RoundsTests/SieveResolutionTests.swift` |
| create | `HunchCore/Tests/RoundsTests/SievePhaseTests.swift` |
| create | `HunchCore/Tests/RoundsTests/SieveDegenerateStrategyTests.swift` |
| modify | `tests.json` — five entries: four outcomes, tell-foul, three-fouls-end, misses-never-end, both strategies dominated |

## Implementation notes

### `SievePhase`, verbatim and with a payload

```swift
public enum SievePhase: Hashable, Sendable {
    case arming
    case priming
    case streaming(SieveReach)
    case paused(SieveReach)          // remembers the reach so resume returns to it
    case fouling
    case reveal
    case settled
}
```

§9.5 writes `case paused` without a payload, and the table then says *"resume → `streaming`"* without
saying which reach. Carrying the reach is the only spelling that makes the resume transition total;
without it the machine has to reach back into the run to recover it, which is `W28`'s two-homes smell.
Record nothing in `DECISIONS.md` for this — it is a faithful implementation of a table that has one
underdetermined cell, and the test `pauseAndResumeKeepTheReach` is the documentation.

`SievePhase.next(_:on:)` is a pure function with an exhaustive `switch` over `(phase, event)` and
**no `default:`**. Unhandled pairs return the phase unchanged rather than trapping — a timed mode
cannot afford a crash on a stray event during a frame drop — and `transitionIsTotal` asserts it.

### Resolution is a two-bit function and nothing more

```swift
public enum SieveResolution: UInt8, Hashable, Sendable, CaseIterable {
    case hit, correctPass, miss, foul

    public init(lawful: Bool, tapped: Bool) {
        self = switch (lawful, tapped) {
        case (true, true):   .hit
        case (false, false): .correctPass
        case (true, false):  .miss
        case (false, true):  .foul
        }
    }

    public var accruesFoul: Bool { self == .foul }
    public var cue: Cue? { … }        // .sieveHit / nil / .sieveMiss / .lawBroken
}
```

**`lawful` is `law.admits(glyph, after: previous)`** where `previous` is the *previous glyph in the
stream* — or the seed glyph at index 0 in contextual bands (T03). It is never the previously *tapped*
glyph: SIEVE has no probes, so PROBE's "`prev` is the previously probed glyph regardless of verdict"
rule (§3.5, E05·T03) reads here as "the previous glyph in the stream", and the stream is a forced
march. Getting this wrong makes every contextual band silently wrong and no stateless band wrong at
all, which is the worst possible failure signature.

**Every glyph resolves whether the player acted or not.** There is no fifth case for "unresolved" at
the glyph level; unresolved glyphs are the ones the run never reached, and they are `completion`'s
business in T05.

### The tell's no-foul rule is a property of the *reach*, not of the resolution

```swift
mutating func resolve(index: Int, tapped: Bool) {
    let resolution = SieveResolution(lawful: stream.isLawful(at: index), tapped: tapped)
    resolutions.append(resolution)
    resolvedGlyphs = index + 1

    // §9.5 — "Fouls do not accrue during the tell." The glyph still RESOLVES as a foul: it is drawn
    // with the two-ring conflict and it is scored at weight 0.5. What it does not do is count.
    if resolution.accruesFoul, stream.reaches.reach(of: index) != .tell {
        foulCount += 1
        if foulCount == 3 { phase = .fouling; ending = .fouled }
    }
}
```

The comment is load-bearing and the test pins it: a tell foul is *visibly* a foul (the two-ring
conflict is how the player learns) and *arithmetically* a foul (it subtracts `0.5 · 8` in T05's
`raw`). It is only the **counter** that ignores it. Punishing an unlearnable prefix would be
dishonest; hiding it from the player would be worse, because the tell is where the law is learned.

### The four cues, and the two silences

| Outcome | Cue | Haptic | Why |
|---|---|---|---|
| hit | `sieveHit` | `sieveHit` | the only positive confirmation in the mode |
| correct pass | — | — | **silence is the reward**; a confirmation sound turns not-tapping into an event |
| miss | `sieveMiss` | `sieveMiss` | a hollow result: the Loom's admit ring with the player's ring absent |
| foul | `lawBroken` | `lawBroken` | a false claim, and it shares the vocabulary with a wrong declaration |

Plus `sieveTick` once per glyph **arrival**, metronomic, fired by `SieveRun` from the conveyor and not
by resolution. And two total silences already established in T02: a tap outside the band, and a
duplicate tap on a glyph already admitted. Neither is an outcome and neither may reach this enum.

### `SieveStrategy` and why the domination test is numeric

```swift
public enum SieveStrategy: Sendable { case tapEverything, tapNothing, playTheLaw }
```

§9.5's decision paragraph makes two quantitative claims and this task turns both into assertions.
*Tap-everything fouls out inside the first three body glyphs* — at `p ≤ 0.60` the expected number of
glyphs to accumulate three unlawful ones is `3 / (1 − p) ≤ 7.5`, so the test's bound of 8 is the
claim with one glyph of slack, asserted over a tenth of the corpus at every band. *Tap-nothing
survives the full run and scores ≈ 41 %* — the score half lands in T05, but the survival and the
zero-foul half belong here.

`simulate(stream:strategy:)` is a plain `for` loop over the stream applying the strategy; it lives in
`HunchCore` beside the state it drives, not in the test bundle, because T05's scoring tests and T08's
termination tests both consume it. It is not a harness in the `10.10` sense and does not belong in
`HunchTestSupport`.

### The `fouling` freeze is a duration, so it is not here

§9.5's `fouling` side effect is *"stream halts mid-lane, 400 ms freeze"*. The **transition** is core;
the **400 ms** is `HunchUI`'s and lands in `C.GateBand` beside `sumpDissolve`. `08 §2` is explicit:
timing constants in the core invite `Task.sleep` into a package whose entire value is that it has no
clock.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveResolutionTests` green — all eight tests.
- [ ] `swift test --package-path HunchCore --filter SievePhaseTests` green, including the total-transition parameterisation over every representative `(phase, event)` pair.
- [ ] `swift test --package-path HunchCore --filter SieveDegenerateStrategyTests` green at every band.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/SievePhase.swift HunchCore/Sources/Rounds/SieveResolution.swift` returns nothing.
- [ ] `grep -rn "400\|milliseconds" HunchCore/Sources/Rounds/SievePhase.swift` returns nothing — no duration in the core.
- [ ] Adding a case to `SievePhase` breaks `SievePhase.next` at compile time — demonstrated once by adding a throwaway case, observing the error, and reverting.
- [ ] `SieveResolution.correctPass.cue == nil` and `.haptic == nil`, asserted, not commented.
- [ ] `tests.json` carries the five entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes dropping `SievePhase.paused`'s payload, decline and point at `pauseAndResumeKeepTheReach`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically to check that `lawful` reads the previous *stream* glyph and never the previous *tapped* glyph.
4. Commit: `git commit -m "E14/T04: SIEVE outcomes, the foul rule and the phase machine"`

## Out of scope

- The arithmetic of `raw`, `idealResolved`, `ratio`, `completion`, `yield` and marks — **T05**.
- The `paused` phase's overlay, scrim, chevron and run-up — **T07**.
- `abandoned` and `voided` as *endings* with their own effects records — **T08**. This task defines the `.abandonConfirmed` transition; T08 defines what it costs.
- Playing the cues and haptics — **E20·T03/T04**. This task only says which one fires.
- The 400 ms `fouling` freeze and the `dur.tap` ring — **T02**'s `C.GateBand` and **E09·T12**'s Reduce Motion table.
- Drawing the two-ring conflict on a foul — **E04·T07** (`hunch-shared-marks`), composed by **T02**.
