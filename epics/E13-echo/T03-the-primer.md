# T03 — The primer

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T02 |
| **Delivers** | The primer (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The search is the last place in the codebase where an RNG appears, and `08 §4`'s rule is absolute: `var rng = SplitMix64(seed:)` local to one synchronous call tree, threaded as `using rng: inout some RandomNumberGenerator`, never stored, never `async`. This skill owns that rule, the caseless-enum shape `EchoPrimer` takes, and the ruling that `EchoAvailability` is an enum with a reason rather than a `Bool` plus a parallel field. |
| `hunch-swift-testing` | The separation invariant is the epic's gate and it is a *seeded-corpus* claim, not a hand-picked example: the suite has to run the search over a corpus of pools and assert a property of every one, with a reproducing seed in every failure message. This skill owns the `T21` deviation that makes that legal and the `Attachment.record` obligation that pays for it. |
| `hunch-design-tokens` | The primer strip draws. The 44 pt ringed glyph and the 36 pt seed both resolve their weights through `env.weight(_:)`, and the seed's dashed frame is a token, not a `StrokeStyle` literal. Load first for the drawing half. |
| `hunch-shared-marks` | Two of the seven marks land here and both already have owners: `VerdictRing.draw` (the primer is one of its eight sites) and `GhostFrame.draw` (the ECHO seed glyph is one of its six). Drawing either by hand is the drift this skill exists to prevent, and it also owns the rule that a mark never claims an accessibility element of its own — the primer strip's host does. |
| `hunch-motion-and-feedback` | §8.5 requires each ring's resolution and its eliminations to land on the *same frame*. That is a beat, not a coincidence, and this skill owns the three clocks that keep it honest: commit at t = 0, then decoration. Getting it wrong shows up as a strip that dims a frame late, which reads as the machine hesitating. |

## Objective

At the end of this task ECHO can say *which law* without saying a word: a chain of `m ∈ {3,4,5}`
glyphs whose verdict vector is unique across the pool, found as the smallest `m` that works over 200
seeded attempts, delivered at 900 ms per glyph with each ring extinguishing every member it rules
out on the same frame it resolves. And when no such chain exists, ECHO says so by being **absent**
from the rack rather than lit and lying.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.2 ("The primer" paragraph, and the paragraph after it) | `m` is the smallest of {3,4,5} for which a separating chain exists, 200 seeded attempts per `m`; the verdict vector is unique across the pool; contextual members take `prev` from the chain's adjacency with the seed priming position 0; no chain at `m = 5` drops the two oldest and retries; pool below 3 → unavailable. The counting argument (3 bits separates 8, 4 separates 16, 5 separates 32) is why exactly seven thumbnails go dark |
| `GAME_DESIGN.md` | §8.4 (primer strip row, and the paragraph under the table) | y 116–164, `m` glyphs at 44 pt with verdict rings, read-only, leading-aligned, seed glyph at 36 pt in a dashed frame; during primer and cast the layout is PROBE's with a 96 pt throat at 64–176 |
| `GAME_DESIGN.md` | §8.5 (`arming → priming`, `priming → primer`, `primer → casting`) | the seed glyph held 1.2 s; `m` glyphs at 900 ms each; each ring extinguishes on the same frame it resolves; a 600 ms gap before `casting` |
| `GAME_DESIGN.md` | §8.10 BLIND-PRIMER | drop the two oldest and retry **from `m = 3`**; the five-page gate against the three-member floor guarantees at least one drop cycle; a three-member pool that still cannot be separated makes ECHO unavailable, its key *absent* from the rack exactly as when locked, with the rotation skipping it; availability is re-evaluated whenever the rack is drawn, and the Codex only changes between rounds |
| `GAME_DESIGN.md` | §3.5 | sequence semantics — the seed primes position 0 and is not itself a probe |
| `GAME_DESIGN.md` | §5.3, §5.7 | `SplitMix64` and its constants; the mode salt |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 (the RNG under strict concurrency) | randomness is a parameter, never an ambient; the generator is synchronous and `nonisolated`; no RNG escapes one synchronous call tree |
| `ios-swift-guide/06-TESTING.md` | T21, T53 | loop inside a band-parameterised test and pay it back with a reproducing seed; promote every failure into a named regression case |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/EchoPrimerTests.swift`:

```swift
import Foundation
import Testing
@testable import Rounds
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("EchoPrimer — §8.2's separating chain", .tags(.unit, .presubmission))
struct EchoPrimerTests {

    private func pool(_ index: Int) -> EchoPool { Corpora.echoPool(index: index) }
    private func newest(_ pool: EchoPool) -> EchoPool.Member { pool.members.last! }

    @Test("the search bounds are §8.2's, and nothing else is legal")
    func searchBounds() {
        #expect(EchoPrimer.attemptsPerLength == 200)
        #expect(Array(EchoPrimer.lengths) == [3, 4, 5])
    }

    /// The epic's gate. Over a seeded corpus of pools, every chain the search returns leaves
    /// exactly one member standing — never two, never zero.
    @Test("exactly one member survives the chain, over a seeded pool corpus")
    func exactlyOneMemberSurvivesTheChain() throws {
        for index in 0..<Corpora.echoPoolCount {
            let pool = pool(index)
            let inForce = newest(pool)
            guard case .available(let armed, let chain, let member) =
                    EchoPrimer.arm(pool: pool, seed: Corpora.seed(mode: .echo, index: index),
                                   selecting: { _ in inForce })
            else { continue }                       // BLIND-PRIMER cases are the next test's business

            let observed = chain.verdicts(under: Law(member.law))
            let survivors = armed.survivors(of: chain, upTo: chain.glyphs.count, observed: observed)
            guard survivors == [member.lawKey] else {
                Attachment.record(armed, named: "echo-pool-\(index).json")
                Issue.record("pool \(index) resolved to \(survivors.count) lit members, not 1")
                return
            }
            #expect(armed.members.count - survivors.count == armed.members.count - 1)
        }
    }

    @Test("m is minimal: no chain of length m − 1 was found in 200 attempts")
    func mIsMinimal() throws {
        for index in 0..<Corpora.echoPoolCount {
            let pool = pool(index)
            let inForce = newest(pool)
            let seed = Corpora.seed(mode: .echo, index: index)
            guard case .available(let armed, let chain, _) =
                    EchoPrimer.arm(pool: pool, seed: seed, selecting: { _ in inForce }) else { continue }
            let m = chain.glyphs.count
            #expect(EchoPrimer.lengths.contains(m))
            if m > EchoPrimer.lengths.lowerBound {
                #expect(EchoPrimer.chain(separating: inForce.lawKey, in: armed,
                                         length: m - 1, seed: seed) == nil)
            }
        }
    }

    @Test("the chain's glyphs are pairwise distinct and the seed is none of them")
    func chainGlyphsAreDistinct() throws {
        let pool = pool(3)
        let inForce = newest(pool)
        guard case .available(_, let chain, _) =
                EchoPrimer.arm(pool: pool, seed: 0xC0FFEE, selecting: { _ in inForce })
        else { return Issue.record("expected an armable pool") }

        #expect(Set(chain.glyphs).count == chain.glyphs.count)
        #expect(!chain.glyphs.contains(chain.seed))
    }

    @Test("the search is deterministic in (pool, member, seed)")
    func deterministic() throws {
        let pool = pool(5)
        let inForce = newest(pool)
        let first = EchoPrimer.arm(pool: pool, seed: 0xBEEF, selecting: { _ in inForce })
        let second = EchoPrimer.arm(pool: pool, seed: 0xBEEF, selecting: { _ in inForce })
        #expect(first == second)
    }

    @Test("a different seed is allowed to give a different chain, but never a wrong one")
    func differentSeedStillSeparates() throws {
        let pool = pool(5)
        let inForce = newest(pool)
        for seed in [UInt64(1), 2, 3, 4, 5] {
            guard case .available(let armed, let chain, let member) =
                    EchoPrimer.arm(pool: pool, seed: seed, selecting: { _ in inForce }) else { continue }
            let observed = chain.verdicts(under: Law(member.law))
            #expect(armed.survivors(of: chain, upTo: chain.glyphs.count,
                                    observed: observed) == [member.lawKey])
        }
    }
}

@Suite("EchoPrimer — BLIND-PRIMER and availability", .tags(.unit, .presubmission))
struct EchoPrimerAvailabilityTests {

    @Test("a pool under three members is unavailable, not merely difficult", arguments: 0...2)
    func poolTooSmall(_ count: Int) {
        let pool = Corpora.echoPool(members: count, index: 0)
        let result = EchoPrimer.arm(pool: pool, seed: 0x1, selecting: { $0.members.last! })
        #expect(result == .unavailable(.poolTooSmall))
    }

    @Test("an unseparable pool drops its two oldest and retries from m = 3")
    func blindPrimerDropsTwoOldest() throws {
        // The two oldest members are extension-twins of two newer ones under every chain of
        // length ≤ 5 the sampler can draw; the remaining six separate at m = 3.
        let pool = Corpora.unseparablePool(dropCyclesNeeded: 1)
        guard case .available(let armed, let chain, let member) =
                EchoPrimer.arm(pool: pool, seed: 0x2, selecting: { $0.members.last! })
        else { return Issue.record("expected one drop cycle to succeed") }

        #expect(armed.members.count == pool.members.count - 2)
        #expect(armed.members == Array(pool.members.dropFirst(2)))
        #expect(chain.glyphs.count == 3)                      // retried FROM m = 3, not from m = 5
        let observed = chain.verdicts(under: Law(member.law))
        #expect(armed.survivors(of: chain, upTo: 3, observed: observed) == [member.lawKey])
    }

    @Test("a pool that cannot be separated at any size makes ECHO unavailable")
    func noSeparatingChainAtAll() {
        let pool = Corpora.unseparablePool(dropCyclesNeeded: .max)
        let result = EchoPrimer.arm(pool: pool, seed: 0x3, selecting: { $0.members.last! })
        #expect(result == .unavailable(.noSeparatingChain))
    }

    @Test("the armed pool is what gets persisted, so the strip and the primer describe the same pool")
    func armedPoolIsTheRoundsPool() throws {
        let pool = Corpora.unseparablePool(dropCyclesNeeded: 1)
        guard case .available(let armed, _, let member) =
                EchoPrimer.arm(pool: pool, seed: 0x4, selecting: { $0.members.last! })
        else { return Issue.record("expected one drop cycle to succeed") }
        #expect(armed.members.contains(member))
        #expect(armed.members.count >= EchoPool.minimumSize)
    }

    @Test("availability is a pure function and can be asked as often as the rack is drawn")
    func availabilityIsCheap() {
        let pool = Corpora.echoPool(index: 1)
        let first = EchoPrimer.arm(pool: pool, seed: 0x5, selecting: { $0.members.last! })
        let second = EchoPrimer.arm(pool: pool, seed: 0x5, selecting: { $0.members.last! })
        #expect(first == second)
    }
}
```

And `Modules/Tests/LoomFeatureTests/PrimerStripTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("The primer strip — §8.4, §8.5", .tags(.unit, .presubmission))
@MainActor
struct PrimerStripTests {

    @Test("the seed is 36 pt in a ghost frame and carries no verdict ring")
    func seedRendering() {
        let strip = PrimerStripLayout(chain: Fixtures.primerChain, env: .reference)
        #expect(strip.seedSide == C.Ribbon.echoSeedGlyph)
        #expect(strip.seedWearsGhostFrame)
        #expect(!strip.seedWearsVerdictRing)
    }

    @Test("each primer glyph is 44 pt with a settled verdict ring, leading-aligned", arguments: 3...5)
    func glyphRendering(_ m: Int) {
        let strip = PrimerStripLayout(chain: Fixtures.primerChain(length: m), env: .reference)
        #expect(strip.glyphSlots.count == m)
        #expect(strip.glyphSlots.allSatisfy { $0.side == C.Ribbon.echoRailGlyph })
        #expect(strip.frame.minY == C.Echo.primerStripTop)
        #expect(strip.glyphSlots.map(\.origin.x).sorted() == strip.glyphSlots.map(\.origin.x))
    }

    @Test("the strip is read-only and is not a hit target")
    func readOnly() {
        let probe = InteractionProbe(PrimerStripView(chain: Fixtures.primerChain,
                                                     verdicts: Fixtures.primerVerdicts, env: .reference))
        #expect(probe.hitTargets.isEmpty)
    }

    @Test("the k-th ring resolving and the k-th elimination are one event, not two")
    func ringAndEliminationShareAFrame() {
        let driver = PrimerDriver(chain: Fixtures.primerChain, pool: Fixtures.echoPool,
                                  observed: Fixtures.primerVerdicts)
        for position in 0..<Fixtures.primerChain.glyphs.count {
            driver.resolve(position)
            #expect(driver.ringsResolved == position + 1)
            #expect(driver.survivors == Fixtures.echoPool.survivors(of: Fixtures.primerChain,
                                                                    upTo: position + 1,
                                                                    observed: Fixtures.primerVerdicts))
        }
    }

    @Test("the primer's own durations are §8.5's and are read from tokens, not typed")
    func durations() {
        #expect(C.Echo.seedHold == Dur.echoSeedHold)
        #expect(C.Echo.primerStep == Dur.echoPrimerStep)
        #expect(C.Echo.primerToCastGap == Dur.echoPrimerGap)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter EchoPrimer`, then
`xcodebuild test … -only-testing:LoomFeatureTests/PrimerStripTests`.
Missing symbols only. If `Corpora.unseparablePool` cannot be constructed on the first attempt, build it
as described in the notes below **before** weakening the test — a BLIND-PRIMER path with no test is a
path that has never run.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/EchoPrimer.swift` |
| create | `HunchCore/Sources/Rounds/EchoAvailability.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Echo` primer geometry and the three durations |
| create | `Modules/Sources/LoomFeature/PrimerStripView.swift` |
| create | `Modules/Sources/LoomFeature/PrimerDriver.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `echoPool(index:)`, `echoPoolCount`, `unseparablePool(dropCyclesNeeded:)`, `seed(mode:index:)` |
| create | `HunchCore/Tests/RoundsTests/EchoPrimerTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/PrimerStripTests.swift` |
| modify | `tests.json` — five entries |
| modify | `DECISIONS.md` — the drop-before-selection ruling, and the distinctness ruling |

## Implementation notes

### The search

```swift
// HunchCore/Sources/Rounds/EchoPrimer.swift
/// §8.2's separating chain. Pure over `(pool, lawKey, seed)`; no clock, no store, no ambient RNG.
public enum EchoPrimer {
    /// §8.2: "200 seeded attempts per `m`".
    public static let attemptsPerLength = 200
    /// §8.2: `m ∈ {3, 4, 5}`.
    public static let lengths = 3...5

    /// The shortest chain that separates `lawKey` from every other member, or nil.
    public static func chain(separating lawKey: UInt64, in pool: EchoPool,
                             seed: UInt64) -> PrimerChain?

    /// One length only — the minimality test calls this directly.
    public static func chain(separating lawKey: UInt64, in pool: EchoPool,
                             length m: Int, seed: UInt64) -> PrimerChain?

    /// §8.2 + §8.10: select, search, and on failure drop the two oldest and retry from `m = 3`.
    public static func arm(pool: EchoPool, seed: UInt64,
                           selecting select: (EchoPool) -> EchoPool.Member) -> EchoAvailability
}
```

The single-length search, in full:

```swift
public static func chain(separating lawKey: UInt64, in pool: EchoPool,
                         length m: Int, seed: UInt64) -> PrimerChain? {
    guard let target = pool.members.first(where: { $0.lawKey == lawKey }) else { return nil }
    let targetLaw = Law(target.law)
    let others = pool.members.filter { $0.lawKey != lawKey }.map { Law($0.law) }

    var rng = SplitMix64(seed: seed ^ Mode.echo.salt ^ UInt64(m))     // local; never escapes
    for _ in 0..<attemptsPerLength {
        let drawn = Deck.distinctGlyphs(count: m + 1, using: &rng)     // seed + m, pairwise distinct
        let candidate = PrimerChain(seed: drawn[0], glyphs: Array(drawn[1...]))
        let vector = candidate.verdicts(under: targetLaw)
        if others.allSatisfy({ candidate.verdicts(under: $0) != vector }) { return candidate }
    }
    return nil
}
```

Four points, each of which is a bug if inverted:

1. **The RNG is a local `var` and is never returned, stored or captured.** `08 §4` consequence 1: the function is synchronous and `nonisolated`, and there is no `async` anywhere near it. The salt is folded in with `m` so the three lengths do not re-draw the same sequence — otherwise `m = 4`'s first 200 attempts would begin with `m = 3`'s failures re-labelled.
2. **The predicate is "unique against every other member", not "all vectors pairwise distinct".** §8.2's sentence is *"no other member could have produced it"*. Requiring full pairwise distinctness is strictly stronger, would fail chains that are perfectly serviceable, and would make BLIND-PRIMER fire far more often than the design expects. The counting argument (`m = 3` separates at most 8) is about the *feasible* set, not about the acceptance test.
3. **`Law(...)` is built once per member, outside the attempt loop.** A contextual `LawTable` costs ≈2 µs to build (§5.7); building it inside 200 iterations would turn a microsecond search into a millisecond one and put the corpus test over budget.
4. **Glyphs are pairwise distinct including the seed**, and that is a ruling to write down. A repeated glyph contributes no additional bit under a stateless law, so the sampler would burn attempts on chains that cannot separate anything new; under a contextual law a repeat is meaningful but rarely necessary, and BLIND-PRIMER is the designed fallback for the case where it would have been. Record it in `DECISIONS.md` with that trade-off stated, because a future reader will otherwise "fix" the sampler to allow repeats and quietly change how often the pool drops.

`Deck.distinctGlyphs(count:using:)` is a partial Fisher–Yates over `0..<256` — add it to `Glyphs/Deck.swift`
if E02·T02 did not ship it, taking `using rng: inout some RandomNumberGenerator` (`08 §4` consequence 2,
`N15`'s preposition row). Do **not** write a rejection-sampling loop at the call site.

### Availability and BLIND-PRIMER

```swift
// HunchCore/Sources/Rounds/EchoAvailability.swift
public enum EchoAvailability: Hashable, Sendable {
    case available(pool: EchoPool, chain: PrimerChain, inForce: EchoPool.Member)
    case unavailable(Reason)

    public enum Reason: Hashable, Sendable {
        case poolTooSmall          // fewer than EchoPool.minimumSize members (§8.2)
        case noSeparatingChain     // BLIND-PRIMER exhausted its drop cycles (§8.10)
    }
}
```

`arm` is the drop cycle and nothing else:

```swift
public static func arm(pool: EchoPool, seed: UInt64,
                       selecting select: (EchoPool) -> EchoPool.Member) -> EchoAvailability {
    guard pool.isServable else { return .unavailable(.poolTooSmall) }
    var working = pool
    while working.isServable {
        let member = select(working)
        if let chain = chain(separating: member.lawKey, in: working, seed: seed) {
            return .available(pool: working, chain: chain, inForce: member)
        }
        working.dropTwoOldest()                    // §8.10, then the loop retries FROM m = 3
    }
    return .unavailable(.noSeparatingChain)
}
```

**The drop happens before selection, and that is the ruling to record.** §8.10 says "drop the two
oldest members, retry" without saying whether the law already selected survives the drop. It cannot:
if the dropped pair contains the selected member, the strip would show six thumbnails while the
primer identified a seventh that is not on it, and §8.8's clause (2) — the candidate set is *drawn*,
not held — would be false. So selection is re-run against the reduced pool each cycle, and the pool
that comes back in `.available` is **the round's pool**: it is what T09 persists, what T02 draws, and
what T07's `selectFromPool` was asked about. Record it in `DECISIONS.md`.

**Why a selector closure rather than a `targetδ`.** Selection is T07's — it needs `difficulty(of:)` and
the serving policy's target. Taking `(EchoPool) -> Member` keeps this file free of the difficulty
model, lets the tests drive it with `{ $0.members.last! }`, and means the drop cycle and the selection
rule can be wrong independently and be tested independently. The closure is not stored and does not
escape, so no `@Sendable` annotation is needed.

**The rack calls this.** §8.10: *"availability is re-evaluated whenever the rack is drawn, and the
Codex only changes between rounds"*. That second clause is the licence to memoize: `FrameView`
(E17·T04) caches the result against the pool value it was computed from and recomputes only when the
pool changes. The cost is 200 × 3 attempts × 8 mask lookups — microseconds — so the cache is a nicety,
not a requirement, and if it is ever removed nothing breaks.

**The unseparable fixture.** `Corpora.unseparablePool(dropCyclesNeeded:)` needs two members with the
same `LawTable` under every drawable chain. The reliable construction is **two laws with identical
extensions and different node spellings** — `RenderedNormalForm` equality without node equality, which
E05·T04/T05 already give you: take a law, produce a spelling variant (commutative reordering, or a
complement fold), and inscribe both. Their verdict vectors agree under every chain by definition, so
no chain can separate one from the other. Put the pair at the two oldest positions for
`dropCyclesNeeded: 1`, and at both ends for `.max`. This fixture is *also* the argument for T01's
dedup rule — with dedup on, the pair cannot arise from real play, which is exactly why it has to be
constructed by hand to be tested.

### The strip, and a layout conflict §8.4 does not flag

§8.4's recall-phase table puts the primer strip at **y 116–164**; the same section says that during
primer and cast the layout is PROBE's, with the 96 pt throat at **y 64–176**. Those overlap by 48 pt,
so they are not two things drawn at once — they are two phases:

- **`priming` and `primer`**: PROBE's layout. The seed glyph sits in the throat for 1.2 s, then each primer glyph appears in the throat and resolves its ring at 900 ms. The pool strip is pinned at 68–108 throughout, because it is the surface that must be readable at the moment a ring resolves.
- **`recalling` onward**: the recall layout. The primer strip appears at 116–164 holding all `m` glyphs with their settled rings, and stays for the rest of the round. That is what §8.2's *"the primer and the pool strip both stay on screen for the whole round"* means and the only thing it can mean.

Write that in the doc comment of `PrimerStripView`. An engineer reading only the §8.4 table will
otherwise draw both simultaneously and discover the overlap in the simulator.

The strip itself is composition, not drawing: each slot is `GlyphCanvas` at `C.Ribbon.echoRailGlyph`
under `VerdictRing.draw(… state: .settled …)`, and the seed is `GlyphCanvas` at
`C.Ribbon.echoSeedGlyph` under `GhostFrame.draw`. `references/verdict-ring.md` lists the ECHO primer as
a `.settled` site, which means `progress` is ignored and the ring is the one the surface holds — there
is no per-frame animation in the strip after the primer ends.

### The beat

`PrimerDriver` is a small `@MainActor @Observable` type owning one integer, `position`, and publishing
`survivors` as a computed call into `EchoPool.survivors(of:upTo:observed:)`. Two rules from
`hunch-motion-and-feedback`'s three clocks:

- **Commit at t = 0 of each step.** `position += 1` happens at the beginning of the 900 ms step, not at its end; the ring's `progress` animation and the strip's opacity change are both decoration over a value that is already true. That is what makes "on the same frame as the ring resolves" a structural property rather than a timing coincidence, and it is why the test asserts `ringsResolved` and `survivors` together after one call.
- **The strip never animates itself.** The opacity change rides the same `withAnimation` the ring does. Under Reduce Motion both become a crossfade at the identical step duration — the *cadence* of the primer is information (it is the pace at which evidence arrives), and §13.7.4's rule is that a substitution replaces the animation, never the information.

Durations live in tokens: `Dur.echoSeedHold` (1.2 s), `Dur.echoPrimerStep` (900 ms),
`Dur.echoPrimerGap` (600 ms), each with its §8.5 citation, and `C.Echo` aliases them so a view names
one thing.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoPrimerTests` green — the corpus test, minimality, distinctness, determinism and the five-seed sweep.
- [ ] `swift test --package-path HunchCore --filter EchoPrimerAvailabilityTests` green — all five, including both BLIND-PRIMER paths.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/PrimerStripTests` green, all five.
- [ ] `grep -rn "SystemRandomNumberGenerator\|\.random(" HunchCore/Sources/Rounds/EchoPrimer.swift` returns nothing, and `Scripts/check-source-hygiene.sh` check 6 is green.
- [ ] `grep -n "async\|await" HunchCore/Sources/Rounds/EchoPrimer.swift` returns nothing.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh HunchCore/Sources/Rounds/EchoPrimer.swift` exits 0.
- [ ] The corpus test's failure path has been exercised once by hand (temporarily invert the acceptance predicate) and the message names a reproducing pool index with an `Attachment`; the inversion is reverted before commit.
- [ ] `DECISIONS.md` records both rulings: drop-before-selection, and pairwise-distinct primer glyphs with the BLIND-PRIMER trade-off stated.
- [ ] `tests.json` carries five entries: one-lit-member over the corpus, minimality of `m`, determinism, BLIND-PRIMER's drop-and-retry-from-3, and unavailability.
- [ ] The fast suite is still under 10 s — measure the corpus test in isolation and record the figure in the PR body.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T03: the separating-chain search, BLIND-PRIMER and the primer strip"`

## Out of scope

- Choosing which member the selector returns — **T07**. This task takes the selector as an argument.
- The cast that follows the 600 ms gap — **T04**.
- Asserting the one-lit-member invariant *at the phase transition* — **T09**; here it is asserted at the search's own boundary.
- Drawing an absent key on the mode rack, and the five-page unlock gate — **E17·T04**.
- `VerdictRing`, `GhostFrame`, `GlyphCanvas` — **E04**; this task calls them.
