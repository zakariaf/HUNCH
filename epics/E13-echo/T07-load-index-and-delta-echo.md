# T07 — Load index ℓ and δ_ECHO

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01, T03 |
| **Delivers** | Load index ℓ (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that all of this is core and none of it is UI: `LoadIndex` is a table, `δ_ECHO` is arithmetic, and `selectFromPool` is a pure function of `(pool, targetδ)`. It also owns the naming pass that turns `targetδ` into `targetDelta` and `δ_served` into `servedDelta` — Greek identifiers compile but cannot be typed, greped or read aloud — and the ruling that the serving result is an enum with a skip reason rather than an optional. |
| `hunch-swift-testing` | Every claim in this task is an arithmetic identity over a small domain, which is exactly what parameterised tests are for: eight load indices, eight bands, and a round-trip that must hold for every `(law, ℓ)` pair. The skill also owns the `isApproximatelyEqual(_:_:absoluteTolerance:)` rule — swift-numerics is banned and this file compares `Double`s on every line. |

## Objective

At the end of this task ECHO has exactly one difficulty knob and it is not the law: the eight-row load
table, `δ_ECHO` and `band_ECHO` derived from it, and `selectFromPool(targetδ)` choosing the pool member
nearest the engine's target and then solving for `ℓ`. When the pool cannot reach the target, ECHO
raises `ℓ` to its ceiling and then steps out of the rotation — it never generates a law the player has
not already found.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.6 (the whole section) | the eight-column table (`L` 6…14, `A` 2…6, cadence 1400…850 ms, cast duration 8.4…11.9 s); `δ_ECHO = clamp01(0.60·difficulty(law) + 0.40·(ℓ−1)/7)`; `band_ECHO = floor(δ_ECHO/0.125) + 1`; `selectFromPool(targetδ)`'s two lines and its tie-break; `ℓ` is the only thing ECHO adapts; G9 and the 200-attempt bound do not apply because nothing is generated; `δ_ECHO` spans `[0.014, 0.999]` over a full pool, so ECHO's served band range is 1…8 |
| `GAME_DESIGN.md` | §8.10 STALE-POOL | serve the highest-δ member and raise `ℓ` to 8; if `δ_ECHO` is still more than 0.125 under target, skip ECHO in the rotation; **never generate an unseen law** |
| `GAME_DESIGN.md` | §10.3 (steps 8 and 13) | ECHO's per-mode band clamp is 1…8 — the identity — and step 13 dispatches ECHO to `selectFromPool(targetδ)` rather than to `generate` |
| `GAME_DESIGN.md` | §10.5 (the `core + echo` row) | `ℓ` is solved from `targetδ` by §8.6's table and is **not defined** in §10; this task is where it is defined |
| `GAME_DESIGN.md` | §9.10 (δ ceiling row) | ECHO's δ ceiling is 0.999, unlike SIEVE's 0.874 |
| `GAME_DESIGN.md` | §5.1, §5.2 | `difficulty(of:)` and the band table's 0.125 width — read, never restated |
| `GAME_DESIGN.md` | §8.7 (worked round) | `ℓ = 5`, law difficulty 0.432 → `δ_ECHO = 0.488` → band 4 |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 (`targetδ`, `δ_served`, `θ`), §7.9 | the naming pass; hand-rolled approximate equality |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/RoundsTests/EchoLoadIndexTests.swift`:

```swift
import Testing
@testable import Rounds
import Laws
import LawGeneration
import HunchTestSupport

@Suite("LoadIndex — §8.6's table", .tags(.unit, .presubmission))
struct LoadIndexTests {

    @Test("the eight rows are §8.6's, verbatim",
          arguments: zip(LoadIndex.allCases,
                         [(6, 2, 1400), (8, 3, 1300), (9, 3, 1200), (10, 4, 1100),
                          (11, 4, 1000), (12, 5, 950), (13, 5, 900), (14, 6, 850)]))
    func table(_ load: LoadIndex, _ row: (length: Int, lawful: Int, cadenceMilliseconds: Int)) {
        #expect(load.length == row.length)
        #expect(load.lawfulCount == row.lawful)
        #expect(load.cadence == .milliseconds(row.cadenceMilliseconds))
    }

    @Test("cast duration is derived, not stored, and matches §8.6's last row to 0.1 s",
          arguments: zip(LoadIndex.allCases, [8.4, 10.4, 10.8, 11.0, 11.0, 11.4, 11.7, 11.9]))
    func castDurationIsDerived(_ load: LoadIndex, _ seconds: Double) {
        #expect(load.castDuration == load.cadence * load.length)
        #expect(isApproximatelyEqual(load.castDuration.seconds, seconds, absoluteTolerance: 0.05))
    }

    @Test("L and A are both monotone in ℓ, and A never exceeds §8.8's cap of 6")
    func monotone() {
        let rows = LoadIndex.allCases
        for (lower, higher) in zip(rows, rows.dropFirst()) {
            #expect(lower.length <= higher.length)
            #expect(lower.lawfulCount <= higher.lawfulCount)
            #expect(lower.cadence > higher.cadence)          // faster as ℓ rises
        }
        #expect(rows.map(\.lawfulCount).max() == 6)
        #expect(rows.map(\.length).max() == 14)              // §8.8 clause (6)
    }

    @Test("A is always a strict minority of L, so flooding the rail is dominated",
          arguments: LoadIndex.allCases)
    func lawfulIsAMinority(_ load: LoadIndex) {
        #expect(load.lawfulCount * 2 < load.length)
    }
}

@Suite("δ_ECHO and band_ECHO — §8.6", .tags(.unit, .presubmission))
struct EchoDifficultyTests {

    @Test("§8.7's worked round: difficulty 0.432 at ℓ = 5 gives δ 0.488 in band 4")
    func workedExample() {
        let delta = EchoDifficulty.delta(lawDifficulty: 0.432, load: .five)
        #expect(isApproximatelyEqual(delta, 0.488, absoluteTolerance: 0.0005))
        #expect(EchoDifficulty.band(for: delta) == .relational)      // band 4
    }

    @Test("δ_ECHO is monotone in ℓ for a fixed law", arguments: [0.05, 0.2, 0.432, 0.75, 0.98])
    func monotoneInLoad(_ difficulty: Double) {
        let deltas = LoadIndex.allCases.map { EchoDifficulty.delta(lawDifficulty: difficulty, load: $0) }
        #expect(deltas == deltas.sorted())
    }

    @Test("δ_ECHO is monotone in law difficulty for a fixed ℓ", arguments: LoadIndex.allCases)
    func monotoneInDifficulty(_ load: LoadIndex) {
        let deltas = stride(from: 0.0, through: 0.99, by: 0.11)
            .map { EchoDifficulty.delta(lawDifficulty: $0, load: load) }
        #expect(deltas == deltas.sorted())
    }

    @Test("the served band range is 1…8 over a full pool (§8.6, §10.3 step 8)")
    func bandRangeIsOneToEight() {
        #expect(EchoDifficulty.band(for: EchoDifficulty.delta(lawDifficulty: 0.0234, load: .one)) == .literal)
        #expect(EchoDifficulty.band(for: EchoDifficulty.delta(lawDifficulty: 0.999, load: .eight)) == .systemic)
        #expect(Mode.echo.bandClamp == Band.literal...Band.systemic)
    }

    @Test("δ = 1.0 does not produce a ninth band")
    func bandIsClampedAtEight() {
        #expect(EchoDifficulty.band(for: 1.0) == .systemic)
        #expect(EchoDifficulty.delta(lawDifficulty: 1.0, load: .eight) <= 1.0)
    }
}

@Suite("selectFromPool — §8.6's serving, §8.10 STALE-POOL", .tags(.unit, .presubmission))
struct EchoServingTests {

    private func pool(_ difficulties: [Double]) -> EchoPool { Corpora.echoPool(difficulties: difficulties) }

    @Test("the nearest member by |difficulty − targetδ| is chosen")
    func nearestMember() throws {
        let pool = pool([0.10, 0.30, 0.55, 0.80])
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(pool, targetDelta: 0.52)
        else { return Issue.record("expected a serve") }
        #expect(isApproximatelyEqual(serving.member.difficulty, 0.55, absoluteTolerance: 1e-9))
    }

    @Test("ties break toward the most recently inscribed member")
    func tieBreak() throws {
        let pool = pool([0.40, 0.60, 0.40])                    // index 2 is the newest 0.40
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(pool, targetDelta: 0.40)
        else { return Issue.record("expected a serve") }
        #expect(serving.member.lawKey == pool.members[2].lawKey)
    }

    @Test("solving ℓ from δ_ECHO returns the ℓ it came from, for every row and every law",
          arguments: LoadIndex.allCases)
    func loadIndexRoundTrips(_ load: LoadIndex) {
        for difficulty in stride(from: 0.02, through: 0.98, by: 0.08) {
            let delta = EchoDifficulty.delta(lawDifficulty: difficulty, load: load)
            #expect(EchoDifficulty.load(forTargetDelta: delta, lawDifficulty: difficulty) == load)
        }
    }

    @Test("ℓ clamps at both ends rather than leaving the table")
    func loadClamps() {
        #expect(EchoDifficulty.load(forTargetDelta: 0.0, lawDifficulty: 0.9) == .one)
        #expect(EchoDifficulty.load(forTargetDelta: 1.0, lawDifficulty: 0.1) == .eight)
    }

    @Test("STALE-POOL: a pool far below target serves the highest-δ member at ℓ = 8")
    func stalePoolRaisesTheLoad() throws {
        let pool = pool([0.05, 0.08, 0.12])                    // every law well under target
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(pool, targetDelta: 0.60)
        else { return Issue.record("expected a serve at the ceiling, not a skip") }
        #expect(serving.load == .eight)
        #expect(isApproximatelyEqual(serving.member.difficulty, 0.12, absoluteTolerance: 1e-9))
        #expect(serving.servedDelta >= 0.60 - EchoDifficulty.staleThreshold)
    }

    @Test("STALE-POOL: still more than 0.125 under target at ℓ = 8 skips ECHO")
    func stalePoolSkips() {
        let pool = pool([0.01, 0.02, 0.03])
        #expect(EchoDifficulty.selectFromPool(pool, targetDelta: 0.95) == .skip(.stalePool))
        #expect(EchoDifficulty.staleThreshold == 0.125)
    }

    @Test("selection never calls the generator and never invents a law")
    func selectionNeverGenerates() throws {
        let pool = pool([0.2, 0.4, 0.6])
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(pool, targetDelta: 0.99)
        else { return Issue.record("expected a serve") }
        #expect(pool.members.contains { $0.lawKey == serving.member.lawKey })
    }

    @Test("the served delta and the served band agree with the table")
    func servingIsSelfConsistent() throws {
        let pool = pool([0.2, 0.45, 0.7])
        guard case .serve(let serving) = EchoDifficulty.selectFromPool(pool, targetDelta: 0.5)
        else { return Issue.record("expected a serve") }
        #expect(serving.servedDelta == EchoDifficulty.delta(lawDifficulty: serving.member.difficulty,
                                                            load: serving.load))
        #expect(serving.band == EchoDifficulty.band(for: serving.servedDelta))
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter Echo`
Missing symbols only. `EchoPool.Member.difficulty` is a computed property added by this task
(`difficulty(of: Law(law))`), so `Corpora.echoPool(difficulties:)` needs laws whose difficulty is
known — build it by generating at a target δ and asserting the achieved difficulty, not by fabricating
a member with a stored difficulty, which would let the test pass over a broken `difficulty(of:)`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/LoadIndex.swift` — T04's eight rows gain `castDuration` |
| create | `HunchCore/Sources/Rounds/EchoDifficulty.swift` |
| create | `HunchCore/Sources/Rounds/EchoServing.swift` |
| modify | `HunchCore/Sources/Rounds/EchoPool.swift` — `Member.difficulty` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `echoPool(difficulties:)` |
| create | `HunchCore/Tests/RoundsTests/EchoLoadIndexTests.swift` |
| modify | `tests.json` — five entries |

## Implementation notes

### The table

```swift
public enum LoadIndex: Int, CaseIterable, Comparable, Sendable {
    case one = 1, two, three, four, five, six, seven, eight

    public var length: Int          // L — §8.6
    public var lawfulCount: Int     // A — §8.6; never rendered (§8.3)
    public var cadence: Duration    // §8.6

    /// §8.6's last row is *derived*: `L × cadence`. Stating it as a fifth stored column would be
    /// a second source of truth that a future edit could contradict without failing anything.
    public var castDuration: Duration { cadence * length }
}
```

Check the derivation once by hand before trusting it: `6 × 1400 ms = 8.4 s`, `8 × 1300 = 10.4`,
`9 × 1200 = 10.8`, `10 × 1100 = 11.0`, `11 × 1000 = 11.0`, `12 × 950 = 11.4`, `13 × 900 = 11.7`,
`14 × 850 = 11.9`. Every one of §8.6's stated durations falls out, including the two equal rows at
`ℓ = 4` and `ℓ = 5` — which is a real feature of the ladder, not a typo: between those two rows the
cast gets *longer in glyphs* and *faster per glyph* by exactly compensating amounts, so what rises is
load and not patience.

`A` being a strict minority of `L` at every row is what makes RAIL-OVERFILL dominated (§8.10), and it
is asserted here rather than argued in T08.

### `δ_ECHO`, and the one guard §8.6 does not write

```swift
public enum EchoDifficulty {
    /// §8.6. `clamp01` is canon's; `lawDifficulty` is `difficulty(of:)`, never a logit.
    public static func delta(lawDifficulty: Double, load: LoadIndex) -> Double {
        clamp01(0.60 * lawDifficulty + 0.40 * Double(load.rawValue - 1) / 7.0)
    }

    /// §8.6. The `min` is the guard §8.6 omits: `clamp01` admits exactly 1.0, and
    /// `floor(1.0 / 0.125) + 1 = 9`, which is not a band.
    public static func band(for delta: Double) -> Band {
        Band(rawValue: min(Band.systemic.rawValue, Int(delta / 0.125) + 1))!
    }
}
```

`0.60`, `0.40` and `7` are §8.6's own coefficients and stay as written — reordering them into
`0.6·d + 0.4·(ℓ−1)/7` in a different associativity changes the last bit of the result and the worked
example is asserted to 0.0005. Write the expression the way §8.6 writes it.

Whether the top of the range is reachable: with `difficulty ∈ [0.000, 1.000)` (§5.7) the largest
`δ_ECHO` is just under `0.6 + 0.4 = 1.0`, so band 9 cannot occur from real inputs. The guard is for the
clamped boundary and for a future caller that hands in a rounded 1.0 — the kind of defensive `min`
that is right precisely because it is unreachable today.

### Serving

```swift
public enum EchoServing: Hashable, Sendable {
    case serve(Serving)
    case skip(SkipReason)

    public struct Serving: Hashable, Sendable {
        public let member: EchoPool.Member
        public let load: LoadIndex
        public let servedDelta: Double
        public let band: Band
    }
    public enum SkipReason: Hashable, Sendable { case stalePool }
}
```

An enum rather than `Serving?` because §8.10 gives the failure a *reason* and E11's rotation logs it;
`W28`'s rule is that a `Bool` plus a parallel field is the smell, and an optional here is the same
shape with the reason thrown away. T03's `EchoAvailability` carries the other two reasons —
`poolTooSmall` and `noSeparatingChain` — and the rotation consumes both types; they are deliberately
not merged, because availability is a property of the *pool* and staleness is a property of the pool
*against a target*.

`selectFromPool` in the order the rules must run:

1. **Nearest by `|difficulty − targetδ|`**, tie-broken toward the **most recently inscribed** — and since `members` is oldest-leading, that is the *highest* index, so use `max(by:)` on a reversed comparison or `enumerated().min(by:)` with the index as a descending secondary key. Getting the tie-break backwards is the one silent bug in this function: it fails no arithmetic test and quietly always serves the stalest of two equally-good laws.
2. **Solve `ℓ`**: `clamp(1 + round(7 · (targetδ − 0.60·difficulty) / 0.40), 1, 8)`. Swift's `.rounded()` is half-away-from-zero, which is what §8.6's `round` means; do not reach for `.rounded(.toNearestOrEven)`.
3. **STALE-POOL.** If `delta(member, ℓ) < targetδ − staleThreshold`, re-select as the member of **maximum difficulty** and set `ℓ = .eight`. Note that step 2's clamp has usually already pinned `ℓ = 8`; the distinct action here is *changing the objective* from "nearest" to "highest", which is the only lever left. If the result is still more than `staleThreshold` under target, return `.skip(.stalePool)`.
4. **Never generate.** There is no fourth step. §8.10: *"Never generate an unseen law for ECHO — the mode's premise is that you already own the law."* The epic's gate greps for `generate(` in these files for exactly this reason.

`staleThreshold = 0.125` is §8.10's number and it is one band width, which is why it is that number:
being a full band under target is the point at which the round stops measuring what the engine asked
for.

### What ECHO does **not** adapt

`ℓ` is the only knob. Three consequences to keep in front of you while writing this file:

- **No G9.** §8.2: ECHO selects, so the novelty guard is bypassed *by construction* — there is nothing to avoid, and passing an `avoid:` set into this function would be meaningless.
- **No 200-attempt bound and no anchor law.** Those belong to `generate` (§5.3). Selection either finds a member or reports staleness; there is no retry loop.
- **No band argument.** §10.3 step 13 hands ECHO a `targetδ` in difficulty units, never a logit and never a band. `band_ECHO` is an *output*, computed from `servedDelta` for the Rasch update and for the Codex's shelf, and it is never an input to selection.

### `Member.difficulty`

```swift
extension EchoPool.Member {
    /// - Complexity: O(1) after the table resolves; `Law.init` caches the metrics (§08 §3).
    public var difficulty: Double { HunchCore.difficulty(of: Law(law)) }
}
```

Resolving a `Law` costs a table build — ≈2 µs for a contextual law (§5.7). `selectFromPool` touches at
most eight members, so the whole selection is ≈16 µs and needs no cache. Do **not** store `difficulty`
on `Member`: it would be a second source of truth that a change to `difficulty(of:)` could not reach,
and the pool is persisted, so a stored value would survive a version bump that changed the model.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter LoadIndexTests` green, all four, including the zipped eight-row table and the derived duration check.
- [ ] `swift test --package-path HunchCore --filter EchoDifficultyTests` green, all five, including §8.7's worked δ of 0.488 in band 4.
- [ ] `swift test --package-path HunchCore --filter EchoServingTests` green, all eight, including both STALE-POOL branches and the eight-row `ℓ` round-trip.
- [ ] `grep -rn "generate(\|avoid:" HunchCore/Sources/Rounds/EchoDifficulty.swift HunchCore/Sources/Rounds/EchoServing.swift` returns nothing.
- [ ] `grep -rn "8\.4\|10\.4\|11\.9" HunchCore/Sources/Rounds/LoadIndex.swift` returns nothing — the durations are derived.
- [ ] `grep -rn "var difficulty" HunchCore/Sources/Rounds/EchoPool.swift` shows a computed property, not a stored one.
- [ ] `tests.json` carries five entries: the eight-row table, the derived cast duration, `δ_ECHO`'s worked value, the `ℓ` round-trip, and both STALE-POOL branches.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T07: the load table, δ_ECHO, selectFromPool and STALE-POOL"`

## Out of scope

- The 13-step serving policy that produces `targetδ`, the mode rotation, and the pressure term — **E11·T03/T04/T06**.
- `difficulty(of:)` itself and the band table — **E06·T01/T02**.
- The Rasch update that consumes `servedDelta` and the success flag — **E11·T02**; T08 defines the success flag.
- Cast construction from `(L, A)` — **T04**; this task supplies the two numbers.
