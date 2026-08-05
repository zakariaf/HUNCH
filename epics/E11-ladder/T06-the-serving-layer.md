# T06 — The serving layer

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | §14.1 Serving layer |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task is the boundary predicate's hardest case in the epic: `avoid` assembly is a pure function of values (core), seed choice is `SeedSource` (app layer), and the thing that holds both is an `@Observable` class (app layer, `@MainActor`). The skill's five-decisions ladder is what keeps the split at the right seam, and `08 §2`'s table already rules that `Codex`-shaped observables are `Modules/`. It also owns `N40`: the type is `Ladder`, never `LadderManager`, never `LadderStore`. |
| `hunch-swift-testing` | The two halves are tested in two places — `LadderTests` for the pure rings and the avoid assembly, `Modules/Tests/LoomFeatureTests` for the observable — and §5.3's *"explicitly not stable across sessions, which is the point of them"* has to become an assertion rather than a comment. The skill also owns the `@MainActor` annotation rule for suites that construct an observable. |

## Objective

The layer between the policy and the generator exists: it picks the seed, assembles `avoid` from the
50-entry novelty ring, the 8-entry lost-law cooldown ring, today's Anomaly and the per-band found set,
consumes a sticky target when one is frozen, and calls the estimator and the pressure term exactly
once per **scored** round and never otherwise. At the end of this task `generate` still knows nothing
about the player, and every fact it does not know has a named home here.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.3 | The purity Decision: *"Seed choice, `avoid` assembly (the player's last 50 solved extensions, their found set for that band, today's Anomaly) and retry-with-a-fresh-seed all live in the serving layer, are tested separately, and are explicitly not stable across sessions."* G9 reads the caller-supplied set and nothing else |
| `GAME_DESIGN.md` | §6.10 | The 8-entry lost-law cooldown ring and its reason; what is persisted at end of round and in what order |
| `GAME_DESIGN.md` | §10.8 | The shelf soft-avoid: *"the first 100 additionally reject any extension already in the Codex … Soft preference only — the locked constant is untouched"* |
| `GAME_DESIGN.md` | §14.6 risk 5 | *"Serving-layer soft-avoid uses the entire found set for `\|H\| ≤ 512` shelves"* — the sizing rule |
| `GAME_DESIGN.md` | §10.1, §10.7, §9.8 | Which outcomes are scored; the sticky target's freeze and its clearing |
| `GAME_DESIGN.md` | §10.6 | The Anomaly enters `avoid` and updates nothing |
| `GAME_DESIGN.md` | §11.13 | `ladder.json`'s write order and its 2 KB ceiling |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §4, §6 | The boundary rule; `Ladder` is one of the four `@MainActor @Observable` types; `AppDependencies` composes it; `SeedSource` lives in `HunchAppFeature` |
| `E10·T01`'s ruling | `DECISIONS.md` | `LoomFeature` cannot import `HunchAppFeature`, so a capability crosses as a `@Sendable` closure, not as a record |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files, because the split is the point.

`HunchCore/Tests/LadderTests/AvoidSetTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import LawGeneration
@testable import Ladder
import HunchTestSupport

@Suite("The avoid set and its rings — §5.3, §6.10, §10.8", .tags(.unit, .presubmission))
struct AvoidSetTests {

    // MARK: the novelty ring

    @Test("The novelty ring holds the last 50 solved extensions, oldest evicted first")
    func noveltyRingIsFiftyDeep() {
        var ring = NoveltyRing.empty
        for i in 0..<120 { ring = ring.inserting(UInt64(i)) }
        #expect(ring.hashes.count == NoveltyRing.capacity)
        #expect(ring.set.contains(119))
        #expect(ring.set.contains(70))
        #expect(!ring.set.contains(69))
    }

    @Test("Re-solving a law already in the ring refreshes it rather than duplicating it")
    func noveltyRingDeduplicates() {
        var ring = NoveltyRing.empty
        for i in 0..<50 { ring = ring.inserting(UInt64(i)) }
        ring = ring.inserting(0)
        #expect(ring.hashes.count == NoveltyRing.capacity)
        #expect(ring.set.contains(0))
        #expect(!ring.set.contains(1))          // 1 is now the oldest and was evicted
    }

    // MARK: the cooldown ring

    /// §6.10: "a lost law additionally enters an 8-entry cooldown ring and is not re-served for
    /// 8 rounds … because re-serving a law the player just failed reads as the machine taunting them."
    @Test("A lost law is barred for exactly eight rounds and then released")
    func cooldownExpiresAfterEightRounds() {
        var ring = CooldownRing.empty
        ring = ring.inserting(0xABCD, atRound: 100)
        #expect(ring.active(atRound: 100).contains(0xABCD))
        #expect(ring.active(atRound: 107).contains(0xABCD))
        #expect(!ring.active(atRound: 108).contains(0xABCD))
    }

    @Test("The cooldown ring holds at most eight entries")
    func cooldownRingIsEightDeep() {
        var ring = CooldownRing.empty
        for i in 0..<30 { ring = ring.inserting(UInt64(i), atRound: i) }
        #expect(ring.entries.count <= CooldownRing.capacity)
        #expect(ring.active(atRound: 29).contains(29))
    }

    // MARK: the two tiers

    /// The ruling this task records. Hard: the two rings and today's Anomaly — G9 must never
    /// emit these. Soft: the per-band found set — a preference that may never force the anchor.
    @Test("The avoid set separates what G9 must refuse from what it should merely prefer")
    func avoidSetIsTwoTiered() {
        var novelty = NoveltyRing.empty
        novelty = novelty.inserting(0x11)
        var cooldown = CooldownRing.empty
        cooldown = cooldown.inserting(0x22, atRound: 5)

        let avoid = AvoidSet.assemble(band: .relational, novelty: novelty, cooldown: cooldown,
                                      currentRound: 6, found: [0x33, 0x44], anomaly: 0x55)

        #expect(avoid.hard == [0x11, 0x22, 0x55])
        #expect(avoid.soft == [0x33, 0x44])
        #expect(avoid.preferred == [0x11, 0x22, 0x33, 0x44, 0x55])
    }

    /// §14.6 risk 5 and §5.2's populations: exactly three shelves are at or under 512 laws.
    @Test("The whole found set is soft-avoided on a thin shelf and only the 512 most recent elsewhere")
    func softAvoidSizing() {
        #expect(Band.allCases.filter { $0.population <= AvoidSet.wholeFoundSetThreshold }
                == [.literal, .exclusive, .systemic])

        let many = (0..<2_000).map(UInt64.init)
        #expect(AvoidSet.softAvoid(band: .literal, found: many).count == many.count)
        let capped = AvoidSet.softAvoid(band: .contextual, found: many)
        #expect(capped.count == AvoidSet.recentFoundSetLimit)
        #expect(capped.contains(1_999))                 // most recent survive
        #expect(!capped.contains(0))
    }

    /// The reason the tiers exist, as arithmetic. Band 1 has forty laws; a player who has found
    /// thirty-five of them and whose found set is HARD-avoided burns all 200 attempts on almost
    /// every round, and H19 reads ≈1.0 at band 1 while every other statistic looks healthy.
    @Test("A hard-avoided found set would break H19 at band 1")
    func hardAvoidingTheFoundSetWouldBreakTheBudget() {
        let index = Corpora.index
        let found = Set(index.dedupHashes(for: .literal).prefix(35))
        var fallbacks = 0
        for i in 0..<200 {
            let report = generateReporting(seed: Corpora.seed(band: .literal, index: i),
                                           band: .literal, targetDelta: Band.literal.centre,
                                           mode: .probe, avoid: found, in: index)
            if report.usedAnchor { fallbacks += 1 }
        }
        #expect(Double(fallbacks) / 200.0 > 0.50,
                "if this is low, the two-tier ruling needs revisiting, not the test")
    }

    // MARK: sticky targets

    @Test("A sticky target reuses the band and targetδ and re-rolls only the seed")
    func stickyTargetRerollsOnlyTheSeed() {
        var state = ServingState.dayOneCalibrated
        state.stickyTarget[.probe] = .init(band: .guarded, targetDelta: 0.6875, tempoStep: 0)

        let a = ServingLayer.serving(mode: .probe, ability: Ability.seeded(baseline: 0.0),
                                     state: state, roundSeed: 1)
        let b = ServingLayer.serving(mode: .probe, ability: Ability.seeded(baseline: 0.0),
                                     state: state, roundSeed: 2)
        #expect(a.band == .guarded && b.band == .guarded)
        #expect(a.targetDelta == b.targetDelta)
        #expect(a.seed != b.seed)
        #expect(a.isSticky && b.isSticky)
    }

    @Test("Any scored round clears the sticky target for that mode")
    func scoredRoundClearsSticky() {
        var state = ServingState.dayOneCalibrated
        state.stickyTarget[.probe] = .init(band: .guarded, targetDelta: 0.6875, tempoStep: 0)
        state.stickyTarget[.sieve] = .init(band: .pair, targetDelta: 0.20, tempoStep: 2)

        let after = ServingLayer.settling(.win, mode: .probe, servedBand: .guarded, state: state)
        #expect(after.stickyTarget[.probe] == nil)
        #expect(after.stickyTarget[.sieve] != nil)      // per mode, never global
    }
}
```

`Modules/Tests/LoomFeatureTests/LadderObservableTests.swift`:

```swift
import Testing
import Foundation
import Glyphs
import LawGeneration
import Persistence
import Ladder
@testable import LoomFeature
import HunchTestSupport

@MainActor
@Suite("Ladder — the serving layer's one impure part", .tags(.unit, .presubmission))
struct LadderObservableTests {

    private func makeLadder(seed: UInt64 = 0xC0FFEE) -> Ladder {
        var counter = seed
        return Ladder(store: InMemoryPersistenceStore(),
                      nextSeed: { counter &+= 0x9E37_79B9_7F4A_7C15; return counter },
                      now: { Date(timeIntervalSince1970: 1_700_000_000) },
                      index: Corpora.index)
    }

    /// §5.3: the serving layer is "explicitly not stable across sessions — which is the point of
    /// them". Two ladders in the same state, different seed sources, must diverge.
    @Test("Two sessions with the same state and different seeds serve different laws")
    func notStableAcrossSessions() async throws {
        let a = makeLadder(seed: 1)
        let b = makeLadder(seed: 2)
        let lawA = try await a.serve(mode: .probe).law
        let lawB = try await b.serve(mode: .probe).law
        #expect(lawA != lawB)
    }

    /// The other half: within one serving, the generator is still a pure function of its
    /// arguments. Same seed, same band, same targetδ, same avoid → byte-identical law.
    @Test("The generator is still deterministic given what the layer chose")
    func generatorRemainsPure() async throws {
        let ladder = makeLadder()
        let served = try await ladder.serve(mode: .probe)
        let again = generate(seed: served.serving.seed, band: served.serving.band,
                             targetDelta: served.serving.targetDelta, mode: .probe,
                             avoid: served.avoid.preferred, in: Corpora.index)
        #expect(again == served.law)
    }

    @Test("A win writes the law into the novelty ring; a loss writes it into the cooldown ring")
    func ringsAreFedByOutcome() async throws {
        let ladder = makeLadder()
        let served = try await ladder.serve(mode: .probe)
        let key = served.law.dedupHash

        try await ladder.settle(served, outcome: .win, marks: 2, probesUsed: 6)
        #expect(ladder.state.novelty.set.contains(key))
        #expect(!ladder.state.cooldown.active(atRound: ladder.state.roundIndex).contains(key))

        let second = try await ladder.serve(mode: .probe)
        try await ladder.settle(second, outcome: .loss, marks: 0, probesUsed: 32)
        #expect(ladder.state.cooldown.active(atRound: ladder.state.roundIndex)
                    .contains(second.law.dedupHash))
    }

    /// E10·T04's `RoundEffects.updatesAbility` is the predicate; this is the assertion that the
    /// layer honours it. Abandon, void, suspend and the Anomaly all leave θ̂ bit-identical.
    @Test("An unscored outcome moves neither the estimate nor the pressure term",
          arguments: [LadderOutcome.abandoned, .voided, .suspended, .anomaly])
    func unscoredOutcomesChangeNothing(_ outcome: LadderOutcome) async throws {
        let ladder = makeLadder()
        let served = try await ladder.serve(mode: .probe)
        let before = ladder.state

        try await ladder.settle(served, outcome: outcome, marks: 0, probesUsed: 4)

        #expect(ladder.state.ability == before.ability)
        #expect(ladder.state.serving.reach == before.serving.reach)
        #expect(ladder.state.serving.relief == before.serving.relief)
        #expect(ladder.state.serving.winStreak == before.serving.winStreak)
        #expect(ladder.state.serving.consecutiveLosses == before.serving.consecutiveLosses)
    }

    @Test("An abandon leaves the target sticky; a suspend does not")
    func abandonIsStickyAndSuspendIsNot() async throws {
        let ladder = makeLadder()
        let served = try await ladder.serve(mode: .probe)
        try await ladder.settle(served, outcome: .abandoned, marks: 0, probesUsed: 3)
        #expect(ladder.state.serving.stickyTarget[.probe]?.band == served.serving.band)

        let other = makeLadder()
        let s2 = try await other.serve(mode: .probe)
        try await other.settle(s2, outcome: .suspended, marks: 0, probesUsed: 3)
        #expect(other.state.serving.stickyTarget[.probe] == nil)
    }

    @Test("A scored round increments n for that mode only")
    func scoredRoundIncrementsN() async throws {
        let ladder = makeLadder()
        let served = try await ladder.serve(mode: .probe)
        try await ladder.settle(served, outcome: .win, marks: 3, probesUsed: 4)
        #expect(ladder.state.ability.scoredRounds[.probe] == 1)
        for mode in Mode.allCases where mode != .probe {
            #expect(ladder.state.ability.scoredRounds[mode] == 0)
        }
    }

    @Test("The ladder round-trips through the store and reloads identical")
    func persistsAndReloads() async throws {
        let store = InMemoryPersistenceStore()
        var counter: UInt64 = 5
        let first = Ladder(store: store, nextSeed: { counter &+= 1; return counter },
                           now: { Date(timeIntervalSince1970: 0) }, index: Corpora.index)
        let served = try await first.serve(mode: .probe)
        try await first.settle(served, outcome: .win, marks: 2, probesUsed: 5)

        let second = Ladder(store: store, nextSeed: { 0 },
                            now: { Date(timeIntervalSince1970: 0) }, index: Corpora.index)
        try await second.load()
        #expect(second.state == first.state)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter AvoidSetTests` and
`swift test --package-path Modules --filter LadderObservableTests`

Both must fail on missing symbols — `NoveltyRing`, `CooldownRing`, `AvoidSet`, `ServingLayer`,
`Ladder`, `LadderOutcome` — not on a malformed expectation.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** Check the boundary with
`.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all`; anything in `Ladder/` that fails it
belongs in `LoomFeature/`.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/NoveltyRing.swift` |
| create | `HunchCore/Sources/Ladder/CooldownRing.swift` |
| create | `HunchCore/Sources/Ladder/AvoidSet.swift` |
| create | `HunchCore/Sources/Ladder/ServingLayer.swift` |
| modify | `HunchCore/Sources/Ladder/LadderState.swift` — adds `novelty`, `cooldown`, `roundIndex` |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/ladder.json` — the three new fields, so E07·T05's fixture still loads |
| create | `Modules/Sources/LoomFeature/Ladder.swift` |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — the `ladder` field, `live()` and `preview(seed:date:)` |
| create | `Modules/Tests/LoomFeatureTests/LadderObservableTests.swift` |
| create | `HunchCore/Tests/LadderTests/AvoidSetTests.swift` |
| modify | `DECISIONS.md` — the two-tier `avoid` ruling |
| modify | `tests.json` — `ladder.novelty-ring`, `ladder.cooldown-ring`, `ladder.avoid-two-tier`, `ladder.sticky-target`, `ladder.unscored-outcomes` |

E10·T01's out-of-scope note pointed at **E11·T01** for `AppDependencies.ladder`. It lands here instead,
because T01 shipped a value with nothing to hold and this is the task where the observable exists.
Note the redirection in the commit message.

## Implementation notes

### The two-tier ruling

> **Ruling, to be recorded in `DECISIONS.md`.** `avoid` has two tiers.
> **Hard** — the 50-entry novelty ring, the 8-entry lost-law cooldown ring and today's Anomaly hash.
> These are passed to `generate` on every attempt; G9 must never emit them.
> **Soft** — the player's found set for that band (the whole set where `band.population ≤ 512`, the
> 512 most recent otherwise). This is applied on a **first** `generateReporting` call; if that call
> reports `usedAnchor`, a second call is made with the hard set only and the same seed.
>
> §5.3 lists the found set inside `avoid` and §10.8 calls it *"soft preference only — the locked
> constant is untouched"*. The two readings differ and only one survives arithmetic:
> `hardAvoidingTheFoundSetWouldBreakTheBudget` shows band 1 falling back on more than half of all
> rounds once a player has found 35 of its 40 laws, against §5.3's own 2 % budget and H19's assertion.
> The two-tier reading satisfies both sentences — the found set genuinely biases generation, and it
> can never be the reason a player is handed the anchor.
>
> §10.8's "first 100 attempts / attempts 101–200" split is implemented as two full 200-attempt calls
> rather than one call with an internal phase change, because §5.7 locks the 200-attempt bound and
> `generate`'s signature is closed. The observable difference is nil: in both readings the soft set
> can delay but not force the anchor.

### The rings

Both are small immutable value types with a bounded capacity and a `func inserting(…) -> Self`. No
`mutating` API: they live inside `LadderState`, which is replaced wholesale on every write, and a
mutating ring inside an immutable state is a shape that invites a partial update.

```swift
/// §5.3, §5.7: "the player's last 50 solved extensions". Extension dedup hashes, newest last.
public struct NoveltyRing: Codable, Equatable, Sendable {
    public static let capacity = 50
    public private(set) var hashes: [UInt64]
    public var set: Set<UInt64> { Set(hashes) }
    public func inserting(_ hash: UInt64) -> Self       // dedup, then evict from the front
}

/// §6.10's addition to canon: a *lost* law is not re-served for eight rounds.
public struct CooldownRing: Codable, Equatable, Sendable {
    public static let capacity = 8
    public static let rounds = 8
    public struct Entry: Codable, Equatable, Sendable { public let hash: UInt64; public let round: Int }
    public private(set) var entries: [Entry]
    public func inserting(_ hash: UInt64, atRound round: Int) -> Self
    public func active(atRound round: Int) -> Set<UInt64>       // round - entry.round < rounds
}
```

`set` is computed rather than stored so there is one source of truth; at fifty entries the `Set`
construction is free relative to a generator call, and `AvoidSet.assemble` builds it once per round.

`CooldownRing` needs a round counter, which is why `LadderState` gains `roundIndex: Int` — monotone,
incremented on every **settled** round including unscored ones (a suspended round still passes time
from the taunting-the-player point of view). State that choice in the doc comment.

### `AvoidSet`

```swift
public struct AvoidSet: Equatable, Sendable {
    /// G9 must never emit these (§5.3, §6.10, §10.6).
    public let hard: Set<UInt64>
    /// A preference that may never force the anchor (§10.8, §14.6 risk 5).
    public let soft: Set<UInt64>
    public var preferred: Set<UInt64> { hard.union(soft) }

    /// §5.2's populations: band 1 (40), 3 (108) and 8 (337) are at or under this.
    public static let wholeFoundSetThreshold = 512
    public static let recentFoundSetLimit = 512

    public static func softAvoid(band: Band, found: [UInt64]) -> Set<UInt64>
    public static func assemble(band: Band, novelty: NoveltyRing, cooldown: CooldownRing,
                                currentRound: Int, found: [UInt64], anomaly: UInt64?) -> AvoidSet
}
```

`found` arrives as an **ordered array, newest last** — that is what makes "the 512 most recent"
expressible, and it is `Codex`'s per-shelf order (E15·T01). The `Ladder` observable reads it from
`codex-index.json` rather than parsing a shelf, which is the whole reason E15·T01 makes the index the
dedup authority; until E15 lands, `Ladder` takes it as a closure parameter defaulting to `[]` and
`LadderObservableTests` covers the empty case. Leave a `// E15·T01` marker at the one call site.

`wholeFoundSetThreshold` and `recentFoundSetLimit` happen to be the same number and are two constants
anyway: they answer different questions (*is this shelf small enough to avoid entirely?* and *how much
history do we keep on a big one?*) and a future change to one must not silently move the other.

### `ServingLayer` — the pure part of the layer

```swift
/// The pure half of §5.3's serving layer. Everything here is a function of values; the seed
/// source, the store and the clock are the other half and live in `LoomFeature.Ladder`.
public enum ServingLayer {
    /// §10.7 / §6.10: a frozen target is reused verbatim and only the seed is re-rolled.
    public static func serving(mode: Mode, ability: Ability,
                               state: ServingState, roundSeed: UInt64) -> Serving

    /// The outcome-time transition: pressure, sticky target, rings and `n`, in one place.
    public static func settling(_ outcome: Pressure.Outcome, mode: Mode,
                                servedBand: Band, state: ServingState) -> ServingState
}
```

`serving` wraps `ServingPolicy.next` (T05's dispatcher) with the sticky-target check in front:

```swift
if let sticky = state.stickyTarget[mode] {
    return Serving(mode: mode, band: sticky.band, targetDelta: sticky.targetDelta,
                   servedDelta: Rasch.logit(ofDifficulty: sticky.targetDelta),
                   seed: roundSeed, isSticky: true, trace: .sticky(sticky))
}
```

The sticky path **bypasses the thirteen steps entirely** — that is what "quitting buys a re-roll and
never an easier law" means, and running the policy would let `relief` (which the abandon did not earn,
because an abandon is not a loss) lower the band. `Trace.sticky` is a fourth trace constructor whose
`targetOrigin` is `.sticky`; add the case and fix the switches.

### The `Ladder` observable

```swift
/// §5.3's serving layer, app side. `08 §4` lists it among the four `@MainActor @Observable`
/// types; `N40` gives it the bare domain noun.
@MainActor
@Observable
public final class Ladder {
    public private(set) var state: LadderState

    private let store: any PersistenceStore
    private let nextSeed: @Sendable () -> UInt64        // E10·T01's closure-shaped capability
    private let now: @Sendable () -> Date
    private let index: LawIndex

    public func load() async throws
    public func serve(mode: Mode) async throws -> ServedRound
    public func settle(_ served: ServedRound, outcome: LadderOutcome,
                       marks: Int, probesUsed: Int) async throws
}

public struct ServedRound: Sendable {
    public let serving: Serving
    public let law: LawNode
    public let avoid: AvoidSet
    public let usedAnchor: Bool
}

/// What the round layer reports back. Wider than `Pressure.Outcome` on purpose: four of these
/// six are the outcomes that must move nothing (§10.1, §10.6, §6.10, §9.8).
public enum LadderOutcome: Sendable {
    case win, loss, abandoned, voided, suspended, anomaly
}
```

`Ladder.swift` goes in **`LoomFeature`**, not `HunchAppFeature`: the composition root composes
features and does not own domain state, and `LoomFeature` is the target that serves rounds. `E10·T01`
already ruled that a capability crosses into `LoomFeature` as a `@Sendable` closure rather than as a
`SeedSource`/`Now` record, so `Ladder`'s `init` takes `nextSeed:` and `now:` and `LoomFeature` gains no
dependency on the composition root. `AppDependencies.live()` passes `seeds.next` and `now.date`;
`AppDependencies.preview(seed:date:)` passes the fixed pair. Record the placement in the commit
message; if E17's Settings later needs the ladder for its reset, it acts on the **file** through the
reset map (E07·T06) and asks the ladder to `load()` again — `MetaFeature` must not import
`LoomFeature`.

`serve(mode:)` does, in order:

1. `serving = ServingLayer.serving(mode:ability:state:roundSeed: nextSeed())`
2. `state.serving = state.serving.recordingServe(serving)` — the palette raise, H20's serve-time half
3. `avoid = AvoidSet.assemble(band:novelty:cooldown:currentRound:found:anomaly:)`
4. `report = generateReporting(seed:band:targetDelta:mode:avoid: avoid.preferred, in: index)`
5. if `report.usedAnchor`, retry once with `avoid.hard` and the same seed
6. persist `ladder.json`, then return the `ServedRound`

Step 5's retry is where the two-tier ruling becomes code, and step 4's argument is `preferred`, never
`hard` — reversing those two is the bug the ruling exists to prevent, so put the citation on the line.

`settle(_:outcome:…)` switches on `LadderOutcome` with **no `default:`**:

| Outcome | estimator | pressure | `n` | novelty | cooldown | sticky | `roundIndex` |
|---|---|---|---|---|---|---|---|
| `.win` | yes | `.win` | +1 | insert | — | cleared | +1 |
| `.loss` | yes | `.loss` | +1 | — | insert | cleared | +1 |
| `.abandoned` | no | no | — | — | — | **set** | +1 |
| `.voided` | no | no | — | — | — | **set** | +1 |
| `.suspended` | no | no | — | — | — | — | — |
| `.anomaly` | no | no | — | insert | — | — | +1 |

Four rows worth reading twice. **`.suspended` does not even advance `roundIndex`** — §10.7 says a
suspended round "persists indefinitely" and is not an event. **`.anomaly` feeds the novelty ring** —
§10.6 says the Anomaly feeds the Codex fully, so its extension is a solved law for novelty purposes,
while updating nothing else; that is H14's exact shape. **`.voided` sets the sticky target** — §9.8's
voiding is sticky for the same anti-farm reason as an abandon. And **`.abandoned` sets sticky but does
not clear it if one is already there**, so a player cannot abandon their way out of a frozen target;
write `if state.stickyTarget[mode] == nil` and cite §6.10.

The table above is the test matrix as well: `unscoredOutcomesChangeNothing` covers four rows, and each
remaining column gets its own assertion.

### Write order

§11.13 fixes it and E07·T02 implements it: `round.json` first, the snapshot slot cleared last. `Ladder`
writes `ladder.json` in the middle, and it writes it **before** returning from `serve` — a crash
between serving and the first probe must not re-serve with a stale novelty ring. Use the store's
existing atomic write; do not add a second persistence path.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AvoidSetTests` green, all eight tests.
- [ ] `swift test --package-path Modules --filter LadderObservableTests` green, all seven tests.
- [ ] `Band.allCases.filter { $0.population <= AvoidSet.wholeFoundSetThreshold } == [.literal, .exclusive, .systemic]`.
- [ ] Two `Ladder`s in identical state with different seed sources serve different laws; the generator called with what the layer chose reproduces the law byte-identically.
- [ ] The six-row `LadderOutcome` table is implemented as a `switch` with no `default:` and every row has a passing assertion.
- [ ] `.suspended` leaves `roundIndex` unchanged; `.anomaly` inserts into the novelty ring and changes nothing else.
- [ ] `bash .claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` passes.
- [ ] `grep -rn 'SeedSource\|Now(' Modules/Sources/LoomFeature/Ladder.swift` returns nothing — both cross as closures.
- [ ] `grep -rn 'avoid.hard' Modules/Sources/LoomFeature/Ladder.swift` shows exactly one call site, the retry.
- [ ] `Fixtures/v1/ladder.json` carries the three new fields and `PersistenceTests` is still green.
- [ ] `DECISIONS.md` carries the two-tier ruling with the band-1 arithmetic.
- [ ] `tests.json` carries the five serving-layer entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green in both packages, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T06: the serving layer — two-tier avoid, three rings, sticky targets and the Ladder observable"`

## Out of scope

- `generate`, `generateReporting` and G9 itself — **E06·T05/T06**.
- The Codex's found set and `codex-index.json` as the dedup authority — **E15·T01**. Consumed here through one closure.
- Today's Anomaly hash and its derivation — **E16·T01**; its θ-isolation assertion — **E16·T03** and **T12**.
- Setting the sticky target at the round layer (`RoundEffects.stickyTarget`) — **E10·T04**; SIEVE's void policy — **E14·T08**.
- The anti-boredom trigger that strengthens the soft-avoid at band 8 — **T07**.
- H19's per-band fallback measurement — **T12**. This task ships the mechanism it measures.
- The reset alert and `MetaFeature`'s wiring — **E17·T08**.
