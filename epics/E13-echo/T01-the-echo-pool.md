# T01 — The echo pool

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | The echo pool (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Three placement calls have to be right before a line is typed. The pool is a value with no clock, no bundle and no screen geometry, so the boundary predicate puts it in `HunchCore/Sources/Rounds/` beside `DriftSchedule` and `SieveSchedule` — not in `CodexFeature`, where the *archive* lives. It also owns the ruling that §8.2's contribution table becomes an exhaustive `switch` over `Mode` with no `default:` (`W29`), so adding a fifth mode is a compile error here rather than a silently ignored contributor. |
| `hunch-swift-testing` | The pool is fed by three modes with three different rules and a fourth that feeds it nothing; every one of those is a boundary the test file has to pin. It also owns the `tests.json` obligation and the tag pair this suite carries. |

## Objective

At the end of this task the last eight laws the player actually inscribed exist as a single
deduplicated `Sendable` value with a contribution rule that is exhaustive over `Mode`, and that value
can be frozen at `arming` and carried inside the round's own record. ECHO's premise — *you already
own this law* — becomes a type rather than a promise, and canon's G9 novelty guard is bypassed by
construction because nothing here ever calls the generator.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.2 (the Decision, and the situation table) | the pool is the last **8** laws inscribed in the Codex in any mode; it is selected, never generated; the four situations — under the unlock threshold, a lost round, a mode switch, a won DRIFT round, a sieved SIEVE run |
| `GAME_DESIGN.md` | §9.6 | the `ratio ≥ 0.92` threshold at which a SIEVE run inscribes, and therefore the threshold at which it contributes |
| `GAME_DESIGN.md` | §9.10 (the mode table, and the three bullets under it) | the pool's functional floor of 3, the five-page unlock gate, and the stated rule `unlockThreshold(.echo) ≥ minimumPoolSize + 2` |
| `GAME_DESIGN.md` | §8.10 POOL-CHURN-MID-ROUND | the pool is snapshotted at `arming` and persisted with the round, which is why a Codex write cannot reach it |
| `GAME_DESIGN.md` | §11.3 | a duplicate re-inscribes **in place** and never mints a second page — the fact the dedup rule is derived from |
| `GAME_DESIGN.md` | §11.12, §11.13 (reset map) | Clear Codex empties the pool, and therefore re-locks ECHO; nothing else in the reset map touches it |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 (the tree), §2 (the boundary), §3 (`LawTable`, `Band`, `Mode`) | `Rounds/` is where per-mode pure state lives; `LawNode` is what is stored, never a recipe |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | exhaustive `switch` with no `default:` over `Mode` and over the settlement shape |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/EchoPoolTests.swift`:

```swift
import Testing
@testable import Rounds
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("EchoPool — §8.2's pool of eight", .tags(.unit, .presubmission))
struct EchoPoolTests {

    /// Eight distinct laws with distinct extensions, oldest leading. `Corpora.echoPoolMembers`
    /// is added by this task; it draws from the seeded law corpus and never from the generator
    /// at test time, because a pool member is by definition a law that was already found.
    private let eight = Corpora.echoPoolMembers(count: 8, seed: 0xE0)

    @Test("capacity is 8 and the functional floor is 3, and the unlock gate clears the floor by 2")
    func lockedSizes() {
        #expect(EchoPool.capacity == 8)
        #expect(EchoPool.minimumSize == 3)
        // §9.10's stated rule, shipped as an assertion rather than as prose.
        #expect(Mode.echo.unlockThresholdPages >= EchoPool.minimumSize + 2)
    }

    @Test("the ninth inscription evicts the oldest and the order stays oldest-leading")
    func evictsTheOldest() {
        var pool = EchoPool()
        for member in eight { pool.inscribe(member) }
        #expect(pool.members.count == 8)
        #expect(pool.members.first == eight[0])
        #expect(pool.members.last == eight[7])

        let ninth = Corpora.echoPoolMembers(count: 9, seed: 0xE0)[8]
        pool.inscribe(ninth)
        #expect(pool.members.count == 8)
        #expect(pool.members.first == eight[1])          // the oldest is gone
        #expect(pool.members.last == ninth)
    }

    @Test("a re-inscription moves the member to newest and never occupies two slots")
    func duplicatesAreDeduplicatedByLawKey() {
        var pool = EchoPool()
        for member in eight { pool.inscribe(member) }

        pool.inscribe(eight[2])                          // §11.3: a duplicate re-inscribes in place
        #expect(pool.members.count == 8)
        #expect(Set(pool.members.map(\.lawKey)).count == 8)
        #expect(pool.members.last == eight[2])
        #expect(pool.members.first == eight[0])          // nothing was evicted to make room
        #expect(!pool.members.dropLast().contains(eight[2]))
    }

    @Test("isServable is exactly `members.count >= 3`", arguments: 0...8)
    func servability(_ count: Int) {
        var pool = EchoPool()
        for member in eight.prefix(count) { pool.inscribe(member) }
        #expect(pool.isServable == (count >= EchoPool.minimumSize))
    }

    @Test("dropping the two oldest is BLIND-PRIMER's only mutation, and it preserves order")
    func dropsTwoOldest() {
        var pool = EchoPool()
        for member in eight { pool.inscribe(member) }
        pool.dropTwoOldest()
        #expect(pool.members == Array(eight[2...]))
    }
}

@Suite("EchoPool contributions — §8.2's situation table", .tags(.unit, .presubmission))
struct EchoPoolContributionTests {

    private let probeLaw = Corpora.law(band: .exclusive, index: 3)
    private let driftFirst = Corpora.law(band: .contextual, index: 7)
    private let driftSecond = Corpora.law(band: .contextual, index: 8)
    private let sieveLaw = Corpora.law(band: .relational, index: 1)

    @Test("a correct PROBE declaration contributes its law")
    func probeContributes() {
        let member = EchoPool.contribution(of: .init(
            mode: .probe, outcome: .inscribed(marks: 2, fracture: false),
            laws: .single(probeLaw, band: .exclusive), sieveRatio: nil))
        #expect(member?.law == probeLaw)
    }

    @Test("a lost round contributes nothing, in every mode", arguments: Mode.allCases)
    func lossesContributeNothing(_ mode: Mode) {
        for outcome in [Outcome.broken, .exhausted, .abandoned, .voided] {
            let member = EchoPool.contribution(of: .init(
                mode: mode, outcome: outcome,
                laws: .single(probeLaw, band: .exclusive), sieveRatio: 1.0))
            #expect(member == nil)                       // §8.2: a loss inscribes nothing
        }
    }

    @Test("a won DRIFT round contributes L₂ only — never L₁, never both")
    func driftContributesTheSecondLawOnly() {
        let member = EchoPool.contribution(of: .init(
            mode: .drift, outcome: .inscribed(marks: 3, fracture: false),
            laws: .drifted(first: driftFirst, second: driftSecond, band: .contextual),
            sieveRatio: nil))
        #expect(member?.law == driftSecond)
        #expect(member?.law != driftFirst)
    }

    @Test("a SIEVE run contributes iff it sieved at ratio ≥ 0.92",
          arguments: [(0.9199, false), (0.92, true), (0.9201, true), (0.80, false), (1.0, true)])
    func sieveContributesAtTheInscriptionThreshold(_ ratio: Double, _ contributes: Bool) {
        let member = EchoPool.contribution(of: .init(
            mode: .sieve, outcome: .inscribed(marks: 2, fracture: false),
            laws: .single(sieveLaw, band: .relational), sieveRatio: ratio))
        #expect((member != nil) == contributes)
    }

    @Test("an ECHO round contributes nothing — it burnishes, it does not inscribe")
    func echoContributesNothing() {
        let member = EchoPool.contribution(of: .init(
            mode: .echo, outcome: .inscribed(marks: 3, fracture: false),
            laws: .single(probeLaw, band: .exclusive), sieveRatio: nil))
        #expect(member == nil)
    }
}

@Suite("EchoPool snapshot — §8.10 POOL-CHURN-MID-ROUND", .tags(.unit, .presubmission))
struct EchoPoolSnapshotTests {

    @Test("the snapshot is a value: a later inscription cannot reach it")
    func snapshotIsFrozen() {
        var pool = EchoPool()
        for member in Corpora.echoPoolMembers(count: 8, seed: 0xE1) { pool.inscribe(member) }
        let armed = pool                                  // taken at `arming`

        pool.inscribe(Corpora.echoPoolMembers(count: 9, seed: 0xE1)[8])
        #expect(armed.members.count == 8)
        #expect(armed != pool)
    }

    @Test("the snapshot round-trips through Codable byte-for-byte")
    func snapshotRoundTrips() throws {
        var pool = EchoPool()
        for member in Corpora.echoPoolMembers(count: 8, seed: 0xE2) { pool.inscribe(member) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(pool)
        let decoded = try JSONDecoder().decode(EchoPool.self, from: data)
        #expect(decoded == pool)
        #expect(try encoder.encode(decoded) == data)
    }

    @Test("an emptied archive empties the pool, which is what re-locks ECHO (§11.12)")
    func clearCodexEmptiesThePool() {
        let pool = EchoPool()
        #expect(pool.members.isEmpty)
        #expect(!pool.isServable)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter EchoPool`
It must fail on `cannot find 'EchoPool' in scope` and on the two missing `Corpora` helpers — not on a
malformed suite. If `Outcome`'s case names differ from E07·T07's shipped spelling, use theirs; the
five cases and their meanings do not move.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/EchoPool.swift` |
| create | `HunchCore/Sources/Rounds/EchoSettlement.swift` |
| modify | `HunchCore/Sources/Archive/CodexIndex.swift` — carry the pool as an additive field |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `echoPoolMembers(count:seed:)`, `law(band:index:)` |
| create | `HunchCore/Tests/RoundsTests/EchoPoolTests.swift` |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/codex-index.json` — add the field so the v1 fixture stays loadable |
| modify | `tests.json` — four entries |
| modify | `DECISIONS.md` — the dedup ruling |

## Implementation notes

### The value

```swift
// HunchCore/Sources/Rounds/EchoPool.swift
public struct EchoPool: Codable, Hashable, Sendable {

    public struct Member: Codable, Hashable, Sendable {
        public let lawKey: UInt64          // E05·T05's 64-bit extension hash — identity, §3.6
        public let law: LawNode            // the RESOLVED node, never a recipe (§11.13, canon §5.4)
        public let band: Band

        public init(lawKey: UInt64, law: LawNode, band: Band)
    }

    /// §8.2: "the last **8** laws inscribed in the Codex … Eight is chosen because it is exactly
    /// three bits, and three bits is exactly what a three-glyph primer carries."
    public static let capacity = 8
    /// §8.2's functional floor; §9.10's unlock gate is `minimumSize + 2` and is asserted, not restated.
    public static let minimumSize = 3

    /// Codex order, **oldest leading** (§8.2, §8.4).
    public private(set) var members: [Member]

    public init(members: [Member] = [])
    public mutating func inscribe(_ member: Member)
    public mutating func dropTwoOldest()
    public var isServable: Bool { members.count >= Self.minimumSize }
}
```

`inscribe` is four lines and every one of them is load-bearing:

```swift
public mutating func inscribe(_ member: Member) {
    members.removeAll { $0.lawKey == member.lawKey }    // dedup by identity, not by node spelling
    members.append(member)                              // newest trailing
    if members.count > Self.capacity { members.removeFirst(members.count - Self.capacity) }
}
```

**Why dedup is forced rather than tidy, and the sentence to put in `DECISIONS.md`.** §8.2 says the
pool is "the last 8 laws inscribed"; §11.3 says a re-find re-inscribes in place. Read naively, a
player who re-finds a law they already hold could occupy two of the eight slots with the same
extension. That is not a cosmetic duplicate: T03's primer requires a chain whose verdict vector is
**unique** across the pool, and two members with the same extension have identical verdict vectors
under every possible chain, so no separating chain can ever exist and BLIND-PRIMER would drop pairs
until the pool fell under the floor and ECHO went dark. Dedup by `lawKey` is therefore a
*correctness* requirement of the primer, and the reason belongs in `DECISIONS.md` so nobody
"simplifies" it back out. It is also the same identity rule the Codex already uses — extension is
identity (§3.6) — so the two agree by construction rather than by coincidence.

Removing then appending, rather than leaving the member where it is, is the reading of "the last 8
inscribed" that keeps `members` a genuine recency ordering. `DUPLICATE-SUPPRESSION` in §8.10 is about
the *cast sampler*, not about this, and T04 owns it; do not conflate them.

### The contribution table

```swift
// HunchCore/Sources/Rounds/EchoSettlement.swift
public struct EchoSettlement: Hashable, Sendable {
    public enum Laws: Hashable, Sendable {
        case single(LawNode, band: Band)
        case drifted(first: LawNode, second: LawNode, band: Band)
    }
    public let mode: Mode
    public let outcome: Outcome
    public let laws: Laws
    public let sieveRatio: Double?
}

extension EchoPool {
    /// §9.6: a run sieved at this ratio inscribes a page, and therefore contributes.
    public static let sieveInscriptionRatio = 0.92

    /// §8.2's situation table, exhaustive over `Mode` and over `Outcome` with no `default:`.
    public static func contribution(of settlement: EchoSettlement) -> Member?
}
```

The body, in the order the guards must run:

1. **A loss contributes nothing, in every mode.** `guard case .inscribed = settlement.outcome else { return nil }`. §8.2: *"a loss inscribes nothing, so ECHO still holds the last successful laws."* This guard comes first because it is the one rule with no per-mode exception, and putting it first means the mode switch below never has to repeat it.
2. **Switch on `mode`, no `default:`.**
   - `.probe` — the single law.
   - `.drift` — `case .drifted(_, let second, let band)` and **only** `second`. §8.2: *"`L₁` is on the page but is not the law the player finished holding."* A `.single` payload arriving with `mode == .drift` is a programming error, not a data case: `preconditionFailure` rather than a silent fallthrough, because silently contributing `L₁` is the exact bug this row exists to prevent.
   - `.echo` — `nil`, unconditionally. An ECHO round burnishes (§11.3); it never inscribes, so it never contributes. This is the case a reader will want to "fix" and the test above is what stops them.
   - `.sieve` — contributes iff `(settlement.sieveRatio ?? 0) >= sieveInscriptionRatio`. Note the comparison is `>=` and the constant is `0.92` exactly; `0.9199` does not contribute and the parameterised test pins both sides.

`Mode.allCases` requires `Mode: CaseIterable`; if E02·T06 did not conform it, add the conformance here
rather than hand-listing four cases in the test — a hand-listed set silently stops covering a fifth
mode, which is the failure `W29` is about.

### Where the pool is persisted, and why there

The pool must be readable **at arming without opening a shelf**. §11.13 loads `codex-index.json` at
launch as the dedup authority and leaves `codex-b1…b8.json` lazy, so the pool rides in the index as an
additive field:

```swift
// HunchCore/Sources/Archive/CodexIndex.swift  (E07·T09's value)
public var echoPool: EchoPool = .init()          // decodeIfPresent, defaulted — §11.13's additive rule
```

Three properties fall out of that placement rather than needing rules of their own:

- **"a function of the Codex, not of the session" (§8.2)** is literally true — the pool lives in the archive's own index and no session state can move it.
- **Clear Codex rewrites `codex-index.json` empty**, so the pool empties and ECHO re-locks (§11.12), with no second code path to keep in step.
- **Reset the ladder keeps the Codex**, so it keeps the pool — which is correct: the player still owns those laws.

Size: eight members × (8 B key + ~40 B node + 1 B band) ≈ 400 B against the index's 216 KB worst case.
Adding it does not move the 512 KB per-file assertion (E07·T05).

If E07 shipped `codexIndex` as a bare `[UInt64]` rather than a struct, promote it to a struct here with
`lawKeys`, `perBandCounts` and `echoPool`, decode the legacy array shape through
`init(from:)`'s single-value container, and add the migration note to `DECISIONS.md`. Do **not**
regenerate `Fixtures/v1/` to make the build pass — add the field to the fixture and keep the old
shape decodable, which is exactly what §11.13's additive rule is for.

### What this task deliberately does not do

`EchoPool.contribution(of:)` is a pure function over a settlement value. **Nothing here writes it.**
The call site — the code that builds an `EchoSettlement` when a round settles and hands the result to
the Codex — is E15·T01's, because that is where `codex-index.json` is written. This task ships the
rule and the tests; the wiring arrives with the archive.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter EchoPool` green: all three suites, including the five-case parameterised SIEVE threshold and the nine-case servability sweep.
- [ ] `grep -n "default:" HunchCore/Sources/Rounds/EchoSettlement.swift` returns nothing.
- [ ] `grep -rn "generate(" HunchCore/Sources/Rounds/EchoPool.swift HunchCore/Sources/Rounds/EchoSettlement.swift` returns nothing — ECHO selects, it does not generate.
- [ ] `.claude/skills/hunch-swift-code/scripts/check-boundary.sh HunchCore/Sources/Rounds/EchoPool.swift` exits 0.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/codex-index.json` carries the field and `PersistenceTests` is still green; a copy of the fixture **without** the field also decodes.
- [ ] `tests.json` carries four entries: capacity and eviction order, dedup by `lawKey`, the contribution table (one entry naming all four modes), and snapshot immutability.
- [ ] `DECISIONS.md` records the dedup ruling with the primer-uniqueness reason, not with "tidier".
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T01: the echo pool, its contribution table and the arming snapshot"`

## Out of scope

- Drawing the pool as eight thumbnails, and the elimination that dims seven of them — **T02**.
- Choosing *which* member is in force for a given `targetδ` — **T07**.
- Writing the pool when a round settles, and `codex-index.json`'s loading — **E15·T01**.
- Applying the burnish to a `CodexPage` — **E15·T06**.
- The five-page unlock gate's effect on the mode rack — **E17·T04**; this task only asserts the arithmetic relationship between the gate and the floor.
