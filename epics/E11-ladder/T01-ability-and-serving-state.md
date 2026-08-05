# T01 — `Ability` and `ServingState`

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing (E10 must be merged) |
| **Delivers** | §14.1 Ability model |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns the ruling this whole task turns on: `08 §3` renames `core` to `baseline` and makes it `Double?` because *"§10.4 says core is **undefined**, not 0 — `var core: Double` cannot say that, so cold start becomes a sentinel someone will compare against `0.0`."* It also decides that `Ladder` is a `HunchCore` target (every field here is a value you can write down in a test), that `StickyTarget` nests inside its owner under `N22`, and that `lastFamily` becomes `lastBand` under the Band/Family collapse. |

## Objective

`ladder.json`'s entire payload exists as pure `Codable` value types: an `Ability` whose baseline is
optional so "undefined" is a type rather than a sentinel, and a `ServingState` carrying the pressure
accumulators, the calibration cursor, the palette ceiling and the sticky targets. At the end of this
task nothing in the package can express "a brand-new player whose ability is 0.0", and copying an
`Ability` allocates nothing — which is the precondition for T10's 10⁶ rounds in 0.4 s.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.1 | The two struct sketches verbatim: every field, its units and its stated range; `StickyTarget`; the bijection between band width and one logit |
| `GAME_DESIGN.md` | §10.2 | θ hard-clamped `[−6, +6]` at write; `n` capped at 4,096; `K_Δ = 0.6·K`; the 0.985 shrinkage and the `\|Δ\| ≤ 3.0` claim |
| `GAME_DESIGN.md` | §10.4 | `core` is undefined and not 0; what "Reset the ladder" sets, field by field; `maxBandEverServed` zeroing with the rest |
| `GAME_DESIGN.md` | §6.10, §9.8 | The sticky target: what freezes it and what clears it |
| `GAME_DESIGN.md` | §11.13 | `ladder.json` < 2 KB, and that it is one file with one owner |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §3, §4 | The `Ladder` target's place in the tree; the `baseline` / `offset` / `scoredRounds` naming; every public core value writes `: Sendable` explicitly |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W28, W29 | One type instead of two parallel fields; exhaustive `switch` with no `default:` |
| `ios-swift-guide/01-PROJECT-STRUCTURE.md` | P24, P25 | One top-level type per file, named for it; nested types are the sanctioned exception |

Do not restate a range, a cap or a shrinkage factor in prose. Cite §10.1 and §10.2.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LadderTests/AbilityTests.swift`:

```swift
import Foundation
import Testing
import Glyphs                    // Mode
import LawGeneration             // Band, Rasch
import Bench                     // PaletteCeiling, AssayEvidenceGrant
@testable import Ladder
import HunchTestSupport

@Suite("Ability — §10.1, §10.2", .tags(.unit, .presubmission))
struct AbilityTests {

    // MARK: undefined is a type, not a value

    /// `08 §3`'s ruling, made mechanical. If this ever compiles as `ability.baseline == 0`
    /// meaning "new player", cold start is broken and §10.4's first Decision is void.
    @Test("A brand-new player has no baseline at all")
    func freshPlayerHasNoBaseline() {
        let fresh = Ability.undefined
        #expect(fresh.baseline == nil)
        #expect(fresh.value(for: .probe) == nil)
        for mode in Mode.allCases {
            #expect(fresh.scoredRounds[mode] == 0)
            #expect(fresh.offset[mode] == 0)
            #expect(fresh.lastPlayed[mode] == nil)
        }
    }

    @Test("A defined baseline resolves per mode as baseline + that mode's offset")
    func modeAbilityIsBaselinePlusOffset() throws {
        var ability = Ability.seeded(baseline: 1.20)
        ability.setOffset(-0.80, for: .sieve)
        #expect(isApproximatelyEqual(try #require(ability.value(for: .probe)), 1.20,
                                     absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(try #require(ability.value(for: .sieve)), 0.40,
                                     absoluteTolerance: 1e-12))
    }

    /// PROBE's offset is not "usually zero"; it is unrepresentable as anything else.
    @Test("PROBE has no offset and cannot acquire one")
    func probeOffsetIsIdenticallyZero() {
        var ability = Ability.seeded(baseline: 0.0)
        ability.setOffset(2.0, for: .probe)
        #expect(ability.offset[.probe] == 0)
    }

    // MARK: the clamps, at write

    @Test("The baseline is hard-clamped at write, in both directions",
          arguments: [(99.0, 6.0), (-99.0, -6.0), (5.9, 5.9), (-5.9, -5.9)])
    func baselineClampsAtWrite(_ written: Double, _ expected: Double) throws {
        var ability = Ability.seeded(baseline: 0)
        ability.setBaseline(written)
        #expect(isApproximatelyEqual(try #require(ability.baseline), expected,
                                     absoluteTolerance: 1e-12))
    }

    /// The clamp is on θ_mode — the quantity the estimator updates — not on the offset in
    /// isolation. A baseline of +5.5 with an offset of +2.0 is θ = 7.5 and must not exist.
    @Test("A mode offset cannot push θ_mode outside the clamp")
    func modeAbilityClampsAtWrite() throws {
        var ability = Ability.seeded(baseline: 5.5)
        ability.setOffset(2.0, for: .drift)
        #expect(isApproximatelyEqual(try #require(ability.value(for: .drift)), 6.0,
                                     absoluteTolerance: 1e-12))
        ability.setOffset(-20.0, for: .echo)
        #expect(isApproximatelyEqual(try #require(ability.value(for: .echo)), -6.0,
                                     absoluteTolerance: 1e-12))
    }

    @Test("Scored rounds cap and never go negative")
    func scoredRoundsCap() {
        var ability = Ability.seeded(baseline: 0)
        ability.setScoredRounds(10_000, for: .probe)
        #expect(ability.scoredRounds[.probe] == Ability.scoredRoundsCap)
        ability.setScoredRounds(-3, for: .probe)
        #expect(ability.scoredRounds[.probe] == 0)
    }

    @Test("Every stored double is finite after any write", arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteWritesAreRefused(_ bad: Double) throws {
        var ability = Ability.seeded(baseline: 1.0)
        ability.setBaseline(bad)
        #expect(try #require(ability.baseline).isFinite)
        ability.setOffset(bad, for: .drift)
        #expect(ability.offset[.drift].isFinite)
    }

    // MARK: shrinkage

    @Test("Shrinkage pulls a played mode's offset toward zero and never past it")
    func shrinkageIsContractive() {
        var ability = Ability.seeded(baseline: 0)
        ability.setOffset(1.0, for: .echo)
        for _ in 0..<400 { ability.shrinkOffset(for: .echo) }
        #expect(ability.offset[.echo] > 0)
        #expect(ability.offset[.echo] < 0.01)
    }

    /// §10.2: "means an unplayed mode never drifts". Shrinking ECHO must not touch DRIFT.
    @Test("Shrinkage touches exactly one mode")
    func shrinkageIsScoped() {
        var ability = Ability.seeded(baseline: 0)
        ability.setOffset(1.0, for: .echo)
        ability.setOffset(1.0, for: .drift)
        ability.shrinkOffset(for: .echo)
        #expect(ability.offset[.drift] == 1.0)
        #expect(ability.offset[.echo] < 1.0)
    }

    // MARK: the value is trivially copyable — T10's budget depends on it

    @Test("Copying an Ability allocates nothing", .tags(.performance))
    func copyingIsAllocationFree() {
        // 10^6 copies in the harness's inner loop; a Dictionary-backed Ability makes this
        // a retain/release per round and blows §10.10's 0.4 s budget on its own.
        var sink = 0.0
        var ability = Ability.seeded(baseline: 0.5)
        let start = ContinuousClock.now
        for i in 0..<1_000_000 {
            var copy = ability
            copy.setBaseline(Double(i % 7) - 3)
            sink += copy.baseline ?? 0
            ability = copy
        }
        #expect(sink.isFinite)
        #expect(ContinuousClock.now - start < .milliseconds(120))
    }

    // MARK: round-trip

    @Test("Ability round-trips through JSON with the baseline still optional")
    func abilityRoundTrips() throws {
        var ability = Ability.seeded(baseline: -2.114)
        ability.setOffset(-0.75, for: .sieve)
        ability.setScoredRounds(37, for: .probe)
        ability.setLastPlayed(Date(timeIntervalSince1970: 1_700_000_000), for: .probe)

        let data = try JSONEncoder().encode(ability)
        #expect(try JSONDecoder().decode(Ability.self, from: data) == ability)

        let undefinedData = try JSONEncoder().encode(Ability.undefined)
        #expect(try JSONDecoder().decode(Ability.self, from: undefinedData).baseline == nil)
    }
}
```

And `HunchCore/Tests/LadderTests/ServingStateTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Bench
@testable import Ladder
import HunchTestSupport

@Suite("ServingState and LadderState — §10.1, §10.4", .tags(.unit, .presubmission))
struct ServingStateTests {

    @Test("Day one: no pressure, calibration armed at round 1, palette at its opening state")
    func dayOneIsSpelledOut() {
        let state = ServingState.dayOne
        #expect(state.reach == 0)
        #expect(state.relief == 0)
        #expect(state.winStreak == 0)
        #expect(state.consecutiveLosses == 0)
        #expect(state.lastBand == nil)
        #expect(state.calibrationRound == 1)
        #expect(state.ceilingClampRun == 0)
        #expect(state.sieveVoidRun == 0)
        #expect(state.stickyTarget.allSatisfy { $0 == nil })
        #expect(state.palette == PaletteCeiling.opening)
        #expect(state.assayGrant == AssayEvidenceGrant.none)
    }

    /// §10.4's reset paragraph, field by field. The Codex, the Profile and the Anomaly ledger
    /// are files this type does not name, so "untouched" is structural here and asserted in
    /// E07·T06 for the file map.
    @Test("Reset the ladder returns exactly day-one state, baseline included")
    func resetIsDayOne() {
        var lived = LadderState.dayOne
        lived.ability.setBaseline(3.2)
        lived.ability.setScoredRounds(200, for: .probe)
        lived.serving.reach = 1.0
        lived.serving.relief = 2.0
        lived.serving.winStreak = 9
        lived.serving.consecutiveLosses = 3
        lived.serving.calibrationRound = nil
        lived.serving.palette = PaletteCeiling.opening.raised(toServe: .systemic)

        #expect(lived.resettingTheLadder() == LadderState.dayOne)
        #expect(lived.resettingTheLadder().ability.baseline == nil)
        #expect(lived.resettingTheLadder().serving.palette == PaletteCeiling.opening)
    }

    // MARK: the sticky target

    @Test("A sticky target freezes a band, a targetδ and a tempo step — and nothing else")
    func stickyTargetCarriesThreeThings() throws {
        var state = ServingState.dayOne
        let sticky = ServingState.StickyTarget(band: .contextual, targetDelta: 0.5625, tempoStep: 2)
        state.stickyTarget[.probe] = sticky

        let restored = try #require(state.stickyTarget[.probe])
        #expect(restored.band == .contextual)
        #expect(isApproximatelyEqual(restored.targetDelta, 0.5625, absoluteTolerance: 1e-12))
        #expect(restored.tempoStep == 2)
        #expect(state.stickyTarget[.drift] == nil)          // per mode, never global
    }

    @Test("The sticky target survives a JSON round-trip inside ladder.json's payload")
    func ladderStateRoundTrips() throws {
        var state = LadderState.dayOne
        state.serving.stickyTarget[.sieve] =
            ServingState.StickyTarget(band: .guarded, targetDelta: 0.6875, tempoStep: 3)
        state.serving.lastBand = .guarded

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        #expect(try JSONDecoder().decode(LadderState.self, from: data) == state)
        #expect(data.count < 2_048)                          // §11.13's stated ceiling for ladder.json
    }

    /// E09·T04 shipped `PaletteCeiling` with `maxBandEverServed` inside it. There must not be a
    /// second copy of that integer on `ServingState` — that is `W28` in its most expensive form,
    /// because the two would disagree about what the player is allowed to build.
    @Test("maxBandEverServed has exactly one home")
    func paletteCeilingIsTheOnlyHome() {
        var state = ServingState.dayOne
        state.palette = state.palette.raised(toServe: .composite)
        #expect(state.palette.maxBandEverServed == .composite)
        #expect(state.palette.isSufficient(for: .composite))
    }

    /// E10·T07 shipped `OnboardingLedger` and said it rides inside `ladder.json`. This is the
    /// payload that carries it; the assertion is that it is still the same value.
    @Test("The onboarding ledger rides inside ladder.json and round-trips unchanged")
    func onboardingLedgerRidesAlong() throws {
        var state = LadderState.dayOne
        state.onboarding.sawAdmit = true
        state.onboarding.sawReject = true
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(LadderState.self, from: data).onboarding == state.onboarding)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter 'AbilityTests|ServingStateTests'`

It must fail on **missing symbols** — `Ability`, `ServingState`, `LadderState`, `ModeVector` — not on a
malformed expectation. If `freshPlayerHasNoBaseline` passes before `Ability.swift` exists, the test is
asserting nothing.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** In particular: if `copyingIsAllocationFree` is red, the offsets are
still in a `Dictionary` — fix the storage, not the budget.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/Ability.swift` |
| create | `HunchCore/Sources/Ladder/ServingState.swift` (with `ServingState.StickyTarget` nested) |
| create | `HunchCore/Sources/Ladder/LadderState.swift` |
| create | `HunchCore/Sources/Ladder/ModeVector.swift` |
| modify | `HunchCore/Package.swift` — the `Ladder` target's row: dependencies `["Rounds", "LawGeneration", "Bench"]`, plus its `.testTarget`, plus its addition to the `HunchCore` product |
| modify | `HunchCore/Sources/Persistence/StoreFile.swift` — nothing structural; confirm `.ladder` still maps to `ladder.json` |
| create | `HunchCore/Tests/LadderTests/AbilityTests.swift` |
| create | `HunchCore/Tests/LadderTests/ServingStateTests.swift` |
| modify | `DECISIONS.md` — the `ModeVector` deviation |
| modify | `tests.json` — `ladder.ability-model`, `ladder.state-round-trip`, `ladder.reset-is-day-one` |

E10·T07 may already have created `HunchCore/Sources/Ladder/OnboardingLedger.swift` and uncommented the
`Ladder` row in the manifest. If so, **do not create a second row** — amend the existing one's
dependency list and note the amendment in the commit message. E01·T03's comment block records
`Ladder E11 ["Rounds"]`; `LawGeneration` and `Bench` are added here because `Band`, `Rasch` and
`PaletteCeiling` are all named by these types, and a speculative-looking edge that is actually used is
not speculative.

## Implementation notes

### `ModeVector` — and why `[Mode: Double]` cannot ship

`08 §3` sketches `var offset: [Mode: Double]` and `var scoredRounds: [Mode: Int]`. Both are
`Dictionary`, which means heap storage, which means that copying an `Ability` — something T10's inner
loop does **10⁶ times in under 0.4 s**, i.e. once every 400 ns including the policy, the response draw
and the estimator — costs a retain, and mutating it costs a copy-on-write allocation. That is the
whole budget, spent on bookkeeping.

There are exactly four modes and there will never be a fifth (§6.10 fixes the `UInt8` raw values;
§9.10 fixes the unlock order). So:

```swift
/// A total function from `Mode` to `Element`, stored inline. There are exactly four modes and
/// the raw values are locked (§6.10), so this is a fixed-size record, not a collection.
///
/// Deviates from `08 §3`'s `[Mode: Double]` sketch for one measured reason, recorded in
/// `DECISIONS.md`: `Ability` is copied once per simulated round and §10.10 budgets 10⁶ rounds
/// at under 0.4 s. A `Dictionary` makes that a heap allocation per round.
public struct ModeVector<Element>: Sendable where Element: Sendable {
    public var probe: Element
    public var drift: Element
    public var echo: Element
    public var sieve: Element

    public init(repeating value: Element) { … }

    public subscript(mode: Mode) -> Element {
        get { switch mode { case .probe: probe; case .drift: drift; case .echo: echo; case .sieve: sieve } }
        set { switch mode { case .probe: probe = newValue; … } }          // no `default:` — W29
    }

    public func allSatisfy(_ predicate: (Element) -> Bool) -> Bool { … }
    public func map<T>(_ transform: (Element) -> T) -> ModeVector<T> { … }
}

extension ModeVector: Equatable where Element: Equatable {}
extension ModeVector: Hashable where Element: Hashable {}
extension ModeVector: Codable where Element: Codable {}                   // keyed by mode name, not index
```

The `Codable` conformance is **keyed by the mode's name**, not by an array index, so `ladder.json`
stays readable and a future field reorder cannot silently transpose two modes' abilities. Write the
`CodingKeys` explicitly; do not let synthesis choose.

The call site is unchanged from the design's sketch — `ability.offset[.drift]` reads the same — which
is what makes this a storage deviation rather than an API one. That sentence goes in `DECISIONS.md`.

### `Ability`

```swift
public struct Ability: Codable, Equatable, Sendable {
    /// §10.4's "core is **undefined**, not 0", as a type (`08 §3`). PROBE-anchored; the only absolute.
    public private(set) var baseline: Double?
    /// Logit offsets from `baseline`, per mode. `offset[.probe]` is identically zero (§10.1).
    public private(set) var offset: ModeVector<Double>
    /// §10.2's `n` — scored rounds in that mode after calibration.
    public private(set) var scoredRounds: ModeVector<Int>
    /// Set by the app layer from `Now`; read by T08. A `Date` handed in is data (`08 §2`).
    public private(set) var lastPlayed: ModeVector<Date?>

    public static let undefined = Ability(...)
    public static func seeded(baseline: Double) -> Ability

    public var isCalibrated: Bool { baseline != nil }
    public func value(for mode: Mode) -> Double?      // baseline.map { $0 + offset[mode] }
}
```

Every stored property is `private(set)` and every write goes through a mutating method that applies
the invariants. That is the only way "hard-clamped **at write**" (§10.2) can be true — a `var` with a
clamp applied by convention is a clamp that will be forgotten:

```swift
extension Ability {
    /// §10.2's bounds. Non-finite input is refused outright: a NaN written here would poison
    /// every future round and H16 would only notice at the end of a run.
    public static let range: ClosedRange<Double> = -6 ... 6
    public static let scoredRoundsCap = 4_096
    /// §10.2's `K_Δ(n) = 0.6 · K(n)`.
    public static let offsetLearningRateFactor = 0.6
    /// §10.2's per-update shrinkage of a mode offset.
    public static let offsetShrinkage = 0.985

    public mutating func setBaseline(_ value: Double)
    public mutating func setOffset(_ value: Double, for mode: Mode)
    public mutating func setScoredRounds(_ n: Int, for mode: Mode)
    public mutating func setLastPlayed(_ date: Date, for mode: Mode)
    public mutating func shrinkOffset(for mode: Mode)
}
```

Three details that are easy to get wrong:

1. **`setOffset` clamps θ_mode, not the offset.** §10.2 says θ is clamped at write, and θ for a
   non-PROBE mode is `baseline + offset`. So the implementation is
   `offset[mode] = clamp(baseline + value, to: Self.range) - baseline` when the baseline is defined,
   and a plain clamp of the offset into `range` when it is not (during calibration, where only PROBE
   is served anyway). `modeAbilityClampsAtWrite` is the test.
2. **`setOffset(_:for: .probe)` is a no-op.** §10.1 gives PROBE no offset; making it writable creates
   two ways to spell the same number and a guaranteed drift. Do not `precondition` — a silent no-op
   plus the test is the shape that survives a release build.
3. **`shrinkOffset` is separate from `setOffset`.** §10.2 applies the shrinkage *after* each update in
   that mode, which is one step of a two-step operation; folding it into the setter would shrink on
   every write including the ones T05 makes when seeding.

`|Δ| ≤ 3.0` is stated by §10.2 as an empirical consequence of the shrinkage ("in practice"), not as a
clamp. Do **not** hard-clamp it here. T10 asserts it over 10⁶ rounds, which is the honest form.

### `ServingState`

```swift
public struct ServingState: Codable, Equatable, Sendable {
    public var reach: Double            // 0 … 1.00 — §10.3
    public var relief: Double           // 0 … 2.00 — §10.3
    public var winStreak: Int
    public var consecutiveLosses: Int
    /// §10.1's `lastFamily`, under `08 §3`'s Band/Family collapse. SIEVE records `Band(lawBand)`,
    /// the family actually served, never the effective band (§10.5).
    public var lastBand: Band?
    /// `nil` once calibrated. §10.4 — PROBE only; modes 2–4 never re-calibrate.
    public var calibrationRound: Int?
    /// Consecutive rounds clamped at `maxBand(mode)` — §10.3 step 10's input.
    public var ceilingClampRun: Int
    /// Consecutive terminated SIEVE runs — §9.8. Read by E14·T08, stored here.
    public var sieveVoidRun: Int
    /// E09·T04's value. Carries `maxBandEverServed`; there is no second copy of that integer.
    public var palette: PaletteCeiling
    /// E09·T06's value. §10.7's floor rescue latches it; T07 is what calls the latch.
    public var assayGrant: AssayEvidenceGrant
    /// Frozen by a void or an abandon; cleared by any scored round (§6.10, §9.8).
    public var stickyTarget: ModeVector<StickyTarget?>

    public struct StickyTarget: Codable, Equatable, Sendable {
        public var band: Band
        public var targetDelta: Double       // difficulty units — never a logit (§10.3)
        public var tempoStep: Int            // SIEVE's `s`; 0 in every other mode
    }

    public static let dayOne: ServingState
}
```

`StickyTarget` is nested (`N22`, `P25`'s sanctioned exception) rather than top-level: it has no meaning
outside a `ServingState` and a bare `StickyTarget` in a signature reads as a global concept. §10.1
spells it top-level; the nesting is a naming pass, not a semantic change, and the fields are verbatim.

**`ceilingVariation` is not here yet.** T07 adds it. Leave the field out rather than adding a
placeholder — an unused `Codable` field is a schema commitment made before the design is settled.

### `LadderState` — the file's payload

```swift
/// The whole of `ladder.json` (§11.13), as one value. `PersistenceStore` (E07·T01) saves and
/// loads it; nothing in this target knows a file exists.
public struct LadderState: Codable, Equatable, Sendable {
    public var schema: Int                 // E07·T04's single global schema echo
    public var ability: Ability
    public var serving: ServingState
    public var onboarding: OnboardingLedger      // E10·T07

    public static let dayOne: LadderState

    /// §10.4's "Resetting the ladder", defined there and only there.
    public func resettingTheLadder() -> LadderState { .dayOne }
}
```

`resettingTheLadder()` returning `.dayOne` looks like a function that earns nothing. It earns two
things: it is the one place §10.4's paragraph is *named* in code, and it is the assertion site — if a
future field must survive a ladder reset (none does today), the compiler forces a decision here rather
than in a `switch` in `MetaFeature`. Keep it, with the citation.

T06 adds `novelty: NoveltyRing` and `cooldown: CooldownRing` to this type. Adding a field is additive
under E07·T04's migration rule (`decodeIfPresent` with a default), so the v1 fixture keeps loading —
verify that when T06 lands, and add the two fields to `Fixtures/v1/ladder.json` in the same commit.

### What must not appear in this target

No `Date()`, no `UUID()`, no `.random(`, no `SystemRandomNumberGenerator`, no `import Testing`, no
`PersistenceStore`, no `async`, no `Task`, no class. `Scripts/check-source-hygiene.sh` check 6 catches
the first four; the manifest catches the store; review catches the rest. `lastPlayed` holds `Date`
*values* handed in from `Now` — `08 §2`'s "half (b) bans ambient sources, not parameters".

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'AbilityTests|ServingStateTests'` is green.
- [ ] `grep -rn 'Date()\|UUID()\|\.random(\|SystemRandomNumberGenerator\|import Testing' HunchCore/Sources/Ladder` returns nothing.
- [ ] `grep -rn '\[Mode *:' HunchCore/Sources/Ladder` returns nothing — every per-mode field is a `ModeVector`.
- [ ] `grep -n 'default:' HunchCore/Sources/Ladder/ModeVector.swift` returns nothing.
- [ ] `grep -rn 'maxBandEverServed' HunchCore/Sources/Ladder` shows it read only through `serving.palette`, never stored.
- [ ] `Ability.undefined.baseline == nil` and `Ability.undefined.value(for:)` is `nil` for all four modes.
- [ ] The encoded `LadderState.dayOne` is under 2,048 bytes and decodes back to `==`.
- [ ] `copyingIsAllocationFree` passes — 10⁶ copy-and-mutate cycles under 120 ms.
- [ ] `DECISIONS.md` records the `ModeVector` deviation with the 400 ns/round figure that forced it.
- [ ] `tests.json` carries `ladder.ability-model`, `ladder.state-round-trip` and `ladder.reset-is-day-one`.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T01: Ability, ServingState and the ladder.json payload as allocation-free values"`

## Out of scope

- The update rule itself — **T02**. Nothing here computes `K`, `P` or a new θ.
- Every rule that *changes* `reach`, `relief`, `winStreak`, `consecutiveLosses` or `ceilingClampRun` — **T03** (serve-time) and **T04** (outcome-time). This task ships the fields and their day-one values only.
- `calibrationRound`'s advance and `baseline`'s seeding — **T05**.
- The novelty and cooldown rings — **T06**.
- `ceilingVariation` — **T07**.
- `n`'s decay and the re-entry grant — **T08**.
- `PaletteCeiling`, `AssayEvidenceGrant` and `OnboardingLedger`, all of which are consumed here and owned by **E09·T04**, **E09·T06** and **E10·T07**.
- Saving or loading the file — **E07·T02**; the reset *alert* — **E17·T08**.
