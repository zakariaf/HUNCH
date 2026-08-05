# T07 — `OnboardingLedger` and the elastic cap

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T06 |
| **Delivers** | `OnboardingLedger` (ONBOARDING) · Elastic cap (ONBOARDING) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that both halves are core: the ledger is a `Codable` value inside `ladder.json` (`HunchCore/Sources/Ladder/`) and the cap is round machinery (`HunchCore/Sources/Rounds/`). It also owns the ruling that keeps `isComplete` a computed property on the value rather than a free function somewhere in the view layer. |
| `hunch-swift-testing` | The elastic cap is the one rule in the epic that can be wrong in a way no play session reveals — a cap that ends the round one probe early on the passive path looks identical to a cap that works. This skill owns the seeded-corpus and boundary-case style that catches it, and the `tests.json` obligation. |

## Objective

At the end of this task the opening round is *measured*: eight fields in `ladder.json` record what the
player actually did, and success is a single five-way conjunction rather than a judgement. And the
passive path is closed: while the player has never seen a reject the cap cannot end the round, the moment
one lands the cap re-arms at `max(12, probesUsed + 3)`, and the whole suspension hard-stops at probe 24.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.5 (Onboarding success criterion) | the eight-field struct verbatim and the success conjunction |
| `GAME_DESIGN.md` | §12.5 (The passive path) | why the cap bends, the re-arm formula, the probe-24 hard stop, and that the extra probes are scored normally — nothing refunded, nothing gifted, only the loss deferred |
| `GAME_DESIGN.md` | §12.5 (Failure of the opening round) | after three failed opening rounds the ledger stops re-arming |
| `GAME_DESIGN.md` | §6.9 | economy `min(1, par/probesUsed)` and `marks ≤ cap → 1`, which is what "scored normally" means once the cap has moved |
| `GAME_DESIGN.md` | §5.7 | par and cap as locked constants — the elastic cap adjusts the *round's* limit, never `Band.cap` |
| `GAME_DESIGN.md` | §11.13 | `ladder.json`'s row: ability, serving state, both rings **and** `OnboardingLedger`, under 2 KB |
| `GAME_DESIGN.md` | §14.6 risk 2 | `clearedTheSealBar` false for > 20 % of first rounds is the stated early signal — the field exists to be read, not to be pretty |
| `ios-swift-guide/06-TESTING.md` | T30, T53 | tag on both axes; promote every failure into a named regression case |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/LadderTests/OnboardingLedgerTests.swift`:

```swift
import Foundation
import Testing
@testable import Ladder
import HunchTestSupport

@Suite("OnboardingLedger — §12.5's success criterion", .tags(.unit, .presubmission))
struct OnboardingLedgerTests {

    private var complete: OnboardingLedger {
        OnboardingLedger(selfConstructedProbes: 1, unvariedRun: 0,
                         sawAdmit: true, sawReject: true, openedBench: true,
                         boundAnAttribute: true, clearedTheSealBar: true,
                         declaredCorrectly: true, nudgesFired: 0)
    }

    /// §12.5 declares the ledger on eight lines; `sawAdmit` and `sawReject` share one, so there are
    /// nine stored properties. The key set below is the authority — do not add a tenth.
    @Test("the fields are exactly §12.5's, and they round-trip through ladder.json")
    func roundTrips() throws {
        let data = try JSONEncoder().encode(complete)
        let decoded = try JSONDecoder().decode(OnboardingLedger.self, from: data)
        #expect(decoded == complete)
        let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        #expect(Set(keys) == ["selfConstructedProbes", "unvariedRun", "sawAdmit", "sawReject",
                              "openedBench", "boundAnAttribute", "clearedTheSealBar",
                              "declaredCorrectly", "nudgesFired"])
    }

    @Test("success is the five-way conjunction and nothing else")
    func successIsTheConjunction() {
        #expect(complete.isComplete)
    }

    @Test("each of the five conjuncts is load-bearing")
    func eachConjunctIsLoadBearing() {
        var a = complete; a.declaredCorrectly = false;        #expect(!a.isComplete)
        var b = complete; b.selfConstructedProbes = 0;        #expect(!b.isComplete)
        var c = complete; c.sawAdmit = false;                 #expect(!c.isComplete)
        var d = complete; d.sawReject = false;                #expect(!d.isComplete)
        var e = complete; e.boundAnAttribute = false;         #expect(!e.isComplete)
    }

    @Test("openedBench, clearedTheSealBar and nudgesFired are recorded but are NOT success conditions")
    func recordedButNotRequired() {
        var ledger = complete
        ledger.openedBench = false
        ledger.clearedTheSealBar = false
        ledger.nudgesFired = 5
        #expect(ledger.isComplete)          // §12.5 names five conjuncts; these three are diagnostics
    }

    @Test("a self-constructed probe is one whose Dial differs from the previous probe")
    func selfConstructedCounting() {
        var ledger = OnboardingLedger()
        ledger.record(probe: 22, previous: nil)        // the seed, un-edited
        #expect(ledger.selfConstructedProbes == 0)
        ledger.record(probe: 22, previous: 22)         // a twin
        #expect(ledger.selfConstructedProbes == 0)
        ledger.record(probe: 30, previous: 22)         // a chosen edit
        #expect(ledger.selfConstructedProbes == 1)
    }

    @Test("unvariedRun counts consecutive unchanged probes and resets on any variation")
    func unvariedRunCounting() {
        var ledger = OnboardingLedger()
        ledger.record(probe: 22, previous: 22)
        ledger.record(probe: 22, previous: 22)
        #expect(ledger.unvariedRun == 2)
        ledger.record(probe: 30, previous: 22)
        #expect(ledger.unvariedRun == 0)
    }

    @Test("after three failed opening rounds the ledger stops re-arming (§12.5)")
    func stopsReArmingAfterThree() {
        var ledger = OnboardingLedger()
        #expect(ledger.isArmed)
        for _ in 0..<3 { ledger.recordFailedOpeningRound() }
        #expect(ledger.failedOpeningRounds == 3)
        #expect(!ledger.isArmed)
        #expect(ledger.nextAttempt == nil)
    }

    @Test("a completed opening round disarms the ledger permanently, without counting as a failure")
    func successDisarms() {
        var ledger = complete
        ledger.recordCompletedOpeningRound()
        #expect(!ledger.isArmed)
        #expect(ledger.failedOpeningRounds == 0)
    }
}
```

`HunchCore/Tests/RoundsTests/ElasticCapTests.swift`:

```swift
import Testing
@testable import Rounds
import LawGeneration
import HunchTestSupport

@Suite("The elastic cap — §12.5's passive path", .tags(.unit, .presubmission))
struct ElasticCapTests {

    private func openingCap() -> ElasticCap { ElasticCap(base: Band.literal.cap, isOpeningRound: true) }

    @Test("the base cap is the band's own, never a copy")
    func baseIsTheBandsCap() {
        #expect(openingCap().limit == 12)
        #expect(Band.literal.cap == 12)
    }

    @Test("twelve consecutive admits do NOT end the round")
    func passivePathDoesNotEnd() {
        var cap = openingCap()
        for probe in 1...12 { cap.record(verdict: .admit, probesUsed: probe) }
        #expect(cap.isSuspended)
        #expect(!cap.endsRound(atProbe: 12))
        #expect(!cap.endsRound(atProbe: 20))
    }

    @Test("the first reject re-arms the cap at max(12, probesUsed + 3)")
    func firstRejectReArms() {
        var cap = openingCap()
        for probe in 1...15 { cap.record(verdict: .admit, probesUsed: probe) }
        cap.record(verdict: .reject, probesUsed: 16)
        #expect(!cap.isSuspended)
        #expect(cap.limit == 19)                    // max(12, 16 + 3)
        #expect(!cap.endsRound(atProbe: 18))
        #expect(cap.endsRound(atProbe: 19))
    }

    @Test("an early reject leaves the cap at its base — the floor is 12, not probesUsed + 3")
    func earlyRejectKeepsTheBase() {
        var cap = openingCap()
        cap.record(verdict: .admit, probesUsed: 1)
        cap.record(verdict: .reject, probesUsed: 2)
        #expect(cap.limit == 12)                    // max(12, 5)
        #expect(cap.endsRound(atProbe: 12))
    }

    @Test("the player always has at least three probes to declare with after their first reject",
          arguments: 1...24)
    func alwaysThreeProbesAfterAReject(_ rejectAt: Int) {
        var cap = openingCap()
        for probe in 1..<rejectAt { cap.record(verdict: .admit, probesUsed: probe) }
        cap.record(verdict: .reject, probesUsed: rejectAt)
        #expect(cap.limit >= min(rejectAt + 3, ElasticCap.hardStop))
    }

    @Test("the suspension hard-stops at probe 24 even with no reject ever")
    func hardStopAtTwentyFour() {
        var cap = openingCap()
        for probe in 1...23 { cap.record(verdict: .admit, probesUsed: probe) }
        #expect(!cap.endsRound(atProbe: 23))
        #expect(cap.endsRound(atProbe: ElasticCap.hardStop))
        #expect(ElasticCap.hardStop == 24)
    }

    @Test("outside the opening round the cap is rigid at every band", arguments: Band.allCases)
    func rigidOutsideTheOpeningRound(_ band: Band) {
        var cap = ElasticCap(base: band.cap, isOpeningRound: false)
        cap.record(verdict: .admit, probesUsed: band.cap - 1)
        #expect(!cap.isSuspended)
        #expect(cap.limit == band.cap)
        #expect(cap.endsRound(atProbe: band.cap))
    }

    @Test("the extra probes are scored normally — nothing refunded, nothing gifted (§6.9)")
    func extraProbesAreScoredNormally() {
        // A long tutorial round: 20 probes against par 7, no strike.
        #expect(Score.inscribed(par: 7, probesUsed: 20, strikes: 0) == 350)
        #expect(Marks.earned(par: 7, probesUsed: 20, cap: 19) == 1)
        // …and the same round declared inside par is still worth full value.
        #expect(Score.inscribed(par: 7, probesUsed: 4, strikes: 0) == 1000)
        #expect(Marks.earned(par: 7, probesUsed: 4, cap: 12) == 3)
    }

    @Test("a reject after the hard stop cannot resurrect the round")
    func rejectAfterHardStopChangesNothing() {
        var cap = openingCap()
        for probe in 1...23 { cap.record(verdict: .admit, probesUsed: probe) }
        cap.record(verdict: .reject, probesUsed: 24)
        #expect(cap.endsRound(atProbe: 24))
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter OnboardingLedgerTests` and `--filter ElasticCapTests`.
Missing symbols only. `Score.inscribed` and `Marks.earned` are E06·T07's; if their spellings differ, use
theirs — but the four numbers (350, 1, 1000, 3) do not move.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/OnboardingLedger.swift` |
| create | `HunchCore/Sources/Rounds/ElasticCap.swift` |
| modify | `HunchCore/Sources/Ladder/ServingState.swift` (or E11's placeholder) — carry the ledger inside `ladder.json`'s payload |
| modify | `Modules/Sources/LoomFeature/Round.swift` — feed the ledger and consult the cap instead of `Band.cap` |
| modify | `Modules/Sources/LoomFeature/OnboardingScript.swift` — take `OnboardingLedger` for beat 6 and `attempt` from `ledger.nextAttempt` |
| create | `HunchCore/Tests/LadderTests/OnboardingLedgerTests.swift` |
| create | `HunchCore/Tests/RoundsTests/ElasticCapTests.swift` |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/ladder.json` — add the ledger so the v1 fixture stays loadable |
| modify | `tests.json` — five entries |

## Implementation notes

### The ledger

§12.5's eight declaration lines — nine stored properties, because `sawAdmit` and `sawReject` share a
line — with the names verbatim, `Codable`, `Equatable`, `Sendable`, all `var`:

```swift
public struct OnboardingLedger: Codable, Equatable, Sendable {   // in ladder.json (§11.13)
    public var selfConstructedProbes: Int = 0
    public var unvariedRun: Int = 0
    public var sawAdmit = false, sawReject = false
    public var openedBench = false
    public var boundAnAttribute = false
    public var clearedTheSealBar = false
    public var declaredCorrectly = false
    public var nudgesFired = 0

    /// §12.5, verbatim. Five conjuncts; `openedBench`, `clearedTheSealBar` and `nudgesFired` are
    /// diagnostics for §14.6 risk 2 and are deliberately *not* success conditions.
    public var isComplete: Bool {
        declaredCorrectly && selfConstructedProbes >= 1 && sawAdmit && sawReject && boundAnAttribute
    }
}
```

Two things the tests pin that a reader might otherwise "tidy":

- `openedBench` is recorded and not required. A player who declares correctly must have opened the
  Bench, so requiring it adds nothing — but nudge 2 keys off it, so it must exist.
- `unvariedRun` is a *run*, not a total. It resets on any variation, because nudge 5 fires every two
  unvaried probes.

Persistence: the ledger lives inside `ladder.json` alongside `Ability` and `ServingState`. Adding it is an
**additive** schema change — `decodeIfPresent` with a default-constructed value (§11.13) — so the checked-in
`Fixtures/v1/` tree keeps loading. Add the field to the fixture too, because the fixture is what proves
the round-trip, and never regenerate the fixture to make a build pass.

### The elastic cap

```swift
public struct ElasticCap: Equatable, Sendable {
    /// §12.5: the suspension itself ends at probe 24.
    public static let hardStop = 24

    public private(set) var limit: Int
    public private(set) var isSuspended: Bool

    public init(base: Int, isOpeningRound: Bool)
    public mutating func record(verdict: Verdict, probesUsed: Int)
    public func endsRound(atProbe probe: Int) -> Bool
}
```

The whole rule in four lines of behaviour:

1. `isSuspended` starts `true` **only** in the opening round, and only while `sawReject == false`.
2. On the first `.reject`: `limit = max(base, probesUsed + 3)`, `isSuspended = false`. §12.5 writes it as
   `max(12, probesUsed + 3)`; 12 *is* `Band.literal.cap`, so read the base and never the literal — that
   is the difference between a rule and a coincidence.
3. `endsRound(atProbe:)` is `probe >= limit` normally, and `probe >= Self.hardStop` while suspended.
4. Outside the opening round the constructor sets `isSuspended = false` and nothing ever moves `limit`.

The `alwaysThreeProbesAfterAReject` test is parameterised over every reject index 1…24 because the
interesting failure is off-by-one at the boundary between the floor and the re-arm, and a single hand-picked
case would miss it.

### What the cap does **not** touch

- **Not `Band.cap`.** The band table is locked (§5.7). `ElasticCap` is the round's live limit; the band's
  cap is its base. If a future reader can find `Band.cap` being mutated, this task is wrong.
- **Not par.** §10.7 is explicit: no cap relief and no par relief, ever, in the adaptive engine. The
  opening round's elasticity is a *tutorial* rule scoped by `isOpeningRound` and nothing else may set it.
- **Not scoring.** `economy = min(1, par/probesUsed)` and `marks ≤ cap_effective → 1` are E06·T07's and
  are read as they are. The `extraProbesAreScoredNormally` test is here rather than there because it is
  the claim §12.5 makes, and it is the claim a well-meaning "fix" would break.

### Three failed openings

`recordFailedOpeningRound()` increments a counter; `isArmed` is `failedOpeningRounds < 3 && !completed`.
`nextAttempt` returns `failedOpeningRounds + 1` while armed and `nil` after, which is exactly what
`OnboardingScript.armed(attempt:)` consumes — and why that function's `precondition` can never fire in
production. §12.5's closing note is worth keeping as the doc comment: *the adaptive engine's
two-consecutive-failure band drop has nowhere lower to go, which is correct.*

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter OnboardingLedgerTests` green, all eight tests.
- [ ] `swift test --package-path HunchCore --filter ElasticCapTests` green, all nine tests, including the 24-case parameterised one.
- [ ] `grep -rn "== 12\|= 12\b" HunchCore/Sources/Rounds/ElasticCap.swift` returns nothing.
- [ ] `grep -rn "isOpeningRound" HunchCore/Sources Modules/Sources` shows the flag set in exactly one place — where the opening round arms.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/ladder.json` contains the ledger and `PersistenceTests` is still green.
- [ ] `tests.json` carries five entries: the conjunction, the passive path, the re-arm formula, the hard stop, and the stop-re-arming rule.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T07: OnboardingLedger, the elastic cap and the probe-24 hard stop"`

## Out of scope

- Nudge 5 *Unvaried*, which reads `unvariedRun` — **T08**.
- `Ability`, `ServingState` and the two rings that share `ladder.json` — **E11·T01**.
- The cap reveal that a hard-stopped opening round runs into — **E09·T10** (`revealing(.exhausted)`).
- The two-consecutive-failure band drop — **E11·T03**.
- Reading `clearedTheSealBar` as a playtest signal — **T10** records it; §14.6 risk 2 acts on it.
