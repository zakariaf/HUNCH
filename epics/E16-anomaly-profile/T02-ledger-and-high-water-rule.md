# T02 — The ledger and the high-water rule

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T01 |
| **Delivers** | One attempt per UTC day (ANOMALY) · High-water anti-cheat (ANOMALY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The `MonotonicAnchor` is the one place in this epic where the boundary predicate has real teeth: `bootID + uptime + wall-clock` is three ambient readings, so the *value* is core and the *sampler* is not. This skill's half-(b) rule ("bans ambient sources, not parameters") is what decides where the split falls, and its `StoreFile` ruling is why `anomaly.hw` needs a home in the enum. |
| `hunch-swift-testing` | Every rule in this task is a boundary condition on an integer, and the failure mode is an off-by-one nobody sees for a year. The skill owns the fixture-tree pattern (`resources: [.copy("Fixtures")]` + a `TestScoping` trait) that the reset-immunity assertion runs on, and the ban on `Date()` inside a test's subject. |

## Objective

At the end of this task the app knows which single day is playable and cannot be talked out of it.
`AnomalyLedger` carries a `highWaterDay` that only ever increases and that no user-facing reset can
clear, 400 capped day entries, the tally, the streak and the longest streak; a clock moved forward
burns days permanently, a clock moved backward enters a sticky `.clockBehind` that releases only at
`highWaterDay + 1`, and jump detection may only ever refuse to shorten that lock.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.7 | the `AnomalyLedger` / `DayEntry` / `AnomalyOutcome` declarations verbatim, the playability rule, clock-forward, clock-back, jump detection, reset immunity, timezone travel, day rollover mid-round |
| `GAME_DESIGN.md` | §11.8 | streak increments on `solvedClean` only; resets on `solvedFractured`, `failed`, `missed`, `abandoned`; the tally is lifetime `solvedClean + solvedFractured` and never resets |
| `GAME_DESIGN.md` | §11.13 | `anomaly.json`'s row (entries capped at 400, aggregates forever, reset-immune); the `anomaly.hw` sidecar and its "never recovered as a *lower* value" clause; the five-action reset map; the clock-set-forward-by-years failure row — missed is derived from **absence**, not from a stored record |
| `GAME_DESIGN.md` | §10.6 | the read-only-past clause: a past Anomaly is playable forever from the Codex but can never retroactively extend the streak |
| `GAME_DESIGN.md` | §12.6 | the DATA section's five rows, none of which touches the ledger |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §3, §5 | the boundary predicate; `StoreFile` as an exhaustive enum with no `default:`; the `Fixtures/v1/` + `TestScoping` pattern |
| `ios-swift-guide/04-ARCHITECTURE.md` | A29 | the `MonotonicAnchorSource` closure seam is the same shape as `SeedSource` and `Now`, and lives in the same place |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/ArchiveTests/AnomalyLedgerTests.swift`:

```swift
import Foundation
import Testing
import Archive
import HunchTestSupport

@Suite("AnomalyLedger — §11.7's high-water rule", .tags(.unit, .presubmission))
struct AnomalyLedgerTests {

    private func ledger(highWater: Int64, entries: [DayEntry] = []) -> AnomalyLedger {
        var l = AnomalyLedger()
        l.highWaterDay = highWater
        l.entries = entries
        return l
    }

    private func settled(_ day: Int64, _ outcome: AnomalyOutcome) -> DayEntry {
        DayEntry(day: day, outcome: outcome, probes: 12, band: 5,
                 settledAt: Date(timeIntervalSince1970: TimeInterval(day) * 86_400 + 3_600))
    }

    // MARK: - monotonicity

    @Test("highWaterDay never decreases, whatever the clock says")
    func highWaterNeverDecreases() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_600)
        #expect(l.highWaterDay == 20_664)
        l.observe(day: 20_665)
        #expect(l.highWaterDay == 20_665)
        l.observe(day: 20_000)
        #expect(l.highWaterDay == 20_665)
    }

    // MARK: - playability

    @Test("today is playable iff observed == highWaterDay and no settled entry exists")
    func playability() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_664)
        #expect(l.availability(on: 20_664) == .playable)

        l.record(settled(20_664, .failed))
        #expect(l.availability(on: 20_664) == .alreadySettled)
    }

    @Test("a past day is never playable, even unsettled", arguments: [20_663, 20_600, 20_000])
    func pastDaysAreNeverPlayable(_ day: Int64) {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_664)
        #expect(l.availability(on: day) != .playable)
    }

    // MARK: - clock forward

    @Test("a forward clock burns the skipped days permanently and resets the streak")
    func clockForwardBurnsDays() {
        var l = ledger(highWater: 20_664, entries: [settled(20_664, .solvedClean)])
        l.streak = 9; l.longestStreak = 9; l.tally = 40

        l.observe(day: 20_700)                       // clock jumped 36 days
        #expect(l.highWaterDay == 20_700)
        #expect(l.streak == 0)                       // days were missed
        #expect(l.longestStreak == 9)                // the record is kept
        #expect(l.tally == 40)                       // the tally never resets
        #expect(l.availability(on: 20_700) == .playable)

        l.observe(day: 20_665)                       // clock put back to "the real" day
        #expect(l.highWaterDay == 20_700)            // gone, permanently
        #expect(l.availability(on: 20_665) != .playable)
    }

    @Test("skipped days allocate no entries — missed is derived from absence (§11.13)")
    func missedDaysAllocateNoEntries() {
        var l = ledger(highWater: 20_664, entries: [settled(20_664, .solvedClean)])
        l.observe(day: 30_000)                       // ~25 years forward
        #expect(l.entries.count == 1)
        #expect(l.day(30_000 - 1) == .missed)        // derived, not stored
    }

    // MARK: - clock back, and the sticky lock

    @Test("a backward clock enters .clockBehind")
    func clockBackLocks() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_660)
        #expect(l.availability(on: 20_660) == .clockBehind(unlocksAt: 20_665))
    }

    /// §11.7: "It unlocks only when true wall-clock reaches `highWaterDay + 1`." The lock is
    /// therefore STICKY — returning the clock to `highWaterDay` does not release it, which is what
    /// makes setting the clock back strictly worse than doing nothing.
    @Test("the lock survives the clock being restored to highWaterDay")
    func lockIsSticky() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_660)                       // locked
        l.observe(day: 20_664)                       // clock restored
        #expect(l.availability(on: 20_664) == .clockBehind(unlocksAt: 20_665))
        #expect(l.highWaterDay == 20_664)
    }

    @Test("the lock releases exactly at highWaterDay + 1, and not one day earlier",
          arguments: [(20_663 as Int64, false), (20_664, false), (20_665, true)])
    func locksAndUnlocksAtHighWaterPlusOne(_ observed: Int64, _ shouldBeFree: Bool) {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_660)                       // enter the lock
        l.observe(day: observed)
        if shouldBeFree {
            #expect(l.availability(on: observed) == .playable)
            #expect(l.highWaterDay == observed)
        } else {
            #expect(l.availability(on: observed) == .clockBehind(unlocksAt: 20_665))
        }
    }

    @Test("no lock exists before a backward clock is ever seen")
    func noLockByDefault() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_664)
        #expect(l.availability(on: 20_664) == .playable)
        l.observe(day: 20_665)
        #expect(l.availability(on: 20_665) == .playable)
    }

    // MARK: - jump detection

    @Test("a detected jump refuses to SHORTEN a lock, and does nothing else")
    func jumpRefusesToShortenALock() {
        var l = ledger(highWater: 20_664)
        l.observe(day: 20_660)                                   // locked through 20_664
        l.observe(day: 20_665, jumpDetectedThisSession: true)     // "it's tomorrow now, honest"
        #expect(l.availability(on: 20_665) == .clockBehind(unlocksAt: 20_665))
        #expect(l.clockJumpCount == 1)
    }

    @Test("a detected jump never lengthens a lock, never wipes and never bars an unlocked player")
    func jumpNeverPunishes() {
        var l = ledger(highWater: 20_664, entries: [])
        l.observe(day: 20_700, jumpDetectedThisSession: true)     // no lock was ever entered
        #expect(l.availability(on: 20_700) == .playable)
        #expect(l.clockJumpCount == 1)
        #expect(l.entries.isEmpty)
        #expect(l.tally == 0)
    }

    @Test("MonotonicAnchor detects a wall-clock advance beyond monotonic elapsed by 120 s")
    func anchorDetectsAJump() {
        let a = MonotonicAnchor(bootID: .init(uuidString: "00000000-0000-0000-0000-0000DEADBEEF")!,
                                uptimeAtStamp: 1_000, wallAtStamp: Date(timeIntervalSince1970: 0))
        // 60 s of uptime, 61 s of wall time — inside tolerance.
        #expect(!a.jumpDetected(against: MonotonicAnchor(bootID: a.bootID, uptimeAtStamp: 1_060,
                                                         wallAtStamp: Date(timeIntervalSince1970: 61))))
        // 60 s of uptime, 300 s of wall time — a jump.
        #expect(a.jumpDetected(against: MonotonicAnchor(bootID: a.bootID, uptimeAtStamp: 1_060,
                                                        wallAtStamp: Date(timeIntervalSince1970: 300))))
        // A different boot session is not a jump — uptime is not comparable across boots.
        #expect(!a.jumpDetected(against: MonotonicAnchor(bootID: .init(), uptimeAtStamp: 5,
                                                        wallAtStamp: Date(timeIntervalSince1970: 9_999))))
    }

    // MARK: - streak, tally, longestStreak

    @Test("the streak increments only on solvedClean")
    func streakIncrementsOnCleanOnly() {
        var l = ledger(highWater: 20_660)
        for (offset, outcome): (Int64, AnomalyOutcome) in
            [(0, .solvedClean), (1, .solvedClean), (2, .solvedClean)] {
            l.observe(day: 20_660 + offset); l.record(settled(20_660 + offset, outcome))
        }
        #expect(l.streak == 3)
        #expect(l.tally == 3)

        l.observe(day: 20_663); l.record(settled(20_663, .solvedFractured))
        #expect(l.streak == 0)          // a strike forfeits it (§4.5, §11.8)
        #expect(l.tally == 4)           // …and the tally still counts the day
        #expect(l.longestStreak == 3)
    }

    @Test("every non-clean outcome resets the streak",
          arguments: [AnomalyOutcome.solvedFractured, .failed, .abandoned])
    func nonCleanOutcomesResetTheStreak(_ outcome: AnomalyOutcome) {
        var l = ledger(highWater: 20_664)
        l.streak = 7; l.longestStreak = 7
        l.observe(day: 20_664); l.record(settled(20_664, outcome))
        #expect(l.streak == 0)
        #expect(l.longestStreak == 7)
    }

    @Test("the tally counts solvedClean and solvedFractured only, and is monotone")
    func tallyIsMonotoneAndCountsSolves() {
        var l = ledger(highWater: 20_660)
        let script: [(Int64, AnomalyOutcome)] =
            [(0, .solvedClean), (1, .failed), (2, .solvedFractured), (3, .abandoned), (4, .solvedClean)]
        for (offset, outcome) in script {
            l.observe(day: 20_660 + offset); l.record(settled(20_660 + offset, outcome))
        }
        #expect(l.tally == 3)
    }

    @Test("a missed day breaks the streak without a stored entry")
    func aMissedDayBreaksTheStreak() {
        var l = ledger(highWater: 20_660)
        l.observe(day: 20_660); l.record(settled(20_660, .solvedClean))
        #expect(l.streak == 1)
        l.observe(day: 20_662)                   // 20_661 was never played
        #expect(l.streak == 0)
        #expect(l.entries.count == 1)
    }

    @Test("a consecutive day keeps the streak alive across an observe")
    func consecutiveDaysKeepTheStreak() {
        var l = ledger(highWater: 20_660)
        l.observe(day: 20_660); l.record(settled(20_660, .solvedClean))
        l.observe(day: 20_661)                   // yesterday was clean, streak survives
        #expect(l.streak == 1)
        l.record(settled(20_661, .solvedClean))
        #expect(l.streak == 2)
    }

    // MARK: - the 400-entry cap

    @Test("entries are capped at 400, oldest evicted first, and aggregates survive eviction")
    func entriesAreCappedAtFourHundred() {
        var l = AnomalyLedger()
        for day in Int64(20_000)..<Int64(20_500) {
            l.observe(day: day); l.record(settled(day, .solvedClean))
        }
        #expect(l.entries.count == 400)
        #expect(l.entries.first?.day == 20_100)
        #expect(l.entries.last?.day == 20_499)
        #expect(l.tally == 500)                 // the aggregate is not a count of entries
        #expect(l.longestStreak == 500)
    }

    // MARK: - the past is read-only

    @Test("a past day already in the Codex is read-only and cannot re-mark or extend the streak")
    func thePastIsReadOnly() {
        var l = ledger(highWater: 20_664, entries: [settled(20_660, .failed)])
        l.streak = 0
        l.observe(day: 20_664)
        #expect(l.availability(on: 20_660) == .alreadySettled)
        l.record(settled(20_660, .solvedClean))       // a replay from the Codex
        #expect(l.streak == 0)                        // §10.6: never retroactively extends
        #expect(l.day(20_660) == .failed)             // the original entry stands
    }

    // MARK: - round-trip

    @Test("the ledger round-trips through JSON with exactly §11.7's key set")
    func roundTrips() throws {
        var l = ledger(highWater: 20_664, entries: [settled(20_664, .solvedClean)])
        l.streak = 3; l.longestStreak = 9; l.tally = 41; l.clockJumpCount = 2
        let data = try JSONEncoder().encode(l)
        #expect(try JSONDecoder().decode(AnomalyLedger.self, from: data) == l)

        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["v", "highWaterDay", "entries", "streak", "longestStreak",
                                     "tally", "clockJumpCount", "anchor", "lockedThroughDay"])
    }

    @Test("a ledger written before lockedThroughDay existed still decodes (additive schema, §11.13)")
    func decodesWithoutTheAdditiveField() throws {
        let json = Data("""
        {"v":1,"highWaterDay":20664,"entries":[],"streak":0,"longestStreak":0,
         "tally":0,"clockJumpCount":0,
         "anchor":{"bootID":"00000000-0000-0000-0000-0000DEADBEEF","uptimeAtStamp":1,"wallAtStamp":0}}
        """.utf8)
        let decoded = try JSONDecoder().decode(AnomalyLedger.self, from: json)
        #expect(decoded.highWaterDay == 20_664)
        #expect(decoded.availability(on: 20_664) == .playable)
    }
}
```

`HunchCore/Tests/PersistenceTests/ResetImmunityTests.swift` — extend E07·T06's suite rather than
writing a second one, and add these two cases:

```swift
@Test("all five resets leave anomaly.json and anomaly.hw byte-identical, on a POPULATED ledger",
      .tags(.unit, .presubmission), arguments: ResetAction.allCases)
func resetsNeverTouchTheAnomaly(_ action: ResetAction) async throws {
    let tree = try FixtureTree.copyOfV1()                       // the TestScoping trait's temp dir
    let before = (try Data(contentsOf: tree.anomalyJSON), try Data(contentsOf: tree.anomalyHW))
    #expect(before.0.count > 200)   // the fixture ledger is populated, not an empty stub
    try await FilePersistenceStore(directory: tree.root).apply(action)
    #expect(try Data(contentsOf: tree.anomalyJSON) == before.0)
    #expect(try Data(contentsOf: tree.anomalyHW) == before.1)
}

@Test("anomaly.hw recovers highWaterDay when anomaly.json is unreadable, and never as a lower value")
func sidecarRecoversTheHighWater() async throws {
    let tree = try FixtureTree.copyOfV1()
    try Data("{ not json".utf8).write(to: tree.anomalyJSON, options: .atomic)
    let store = FilePersistenceStore(directory: tree.root)
    let recovered: AnomalyLedger = try await store.load(.anomaly)
    #expect(recovered.highWaterDay == FixtureTree.v1HighWaterDay)
    #expect(recovered.entries.isEmpty)                     // entries are lost; the high water is not
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter AnomalyLedgerTests` then `--filter ResetImmunityTests`.
The first run must fail on missing symbols (`AnomalyLedger.observe`, `.availability(on:)`, `.record`,
`.day(_:)`, `MonotonicAnchor.jumpDetected`) and on the v1 fixture's `anomaly.json` being an empty
stub. A green `resetsNeverTouchTheAnomaly` before the fixture is populated is testing nothing —
populate the fixture first and watch the assertion become meaningful.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/AnomalyLedger.swift` |
| create | `HunchCore/Sources/Archive/MonotonicAnchor.swift` |
| create | `Modules/Sources/HunchAppFeature/MonotonicAnchorSource.swift` |
| create | `HunchCore/Tests/ArchiveTests/AnomalyLedgerTests.swift` |
| modify | `HunchCore/Sources/Persistence/StoreFile.swift` — the `anomaly` case gains its `.hw` sidecar sibling in the path switch |
| modify | `HunchCore/Sources/Persistence/FilePersistenceStore.swift` — write the 16-byte sidecar on every ledger mutation; recover from it when the JSON fails to decode |
| modify | `HunchCore/Tests/PersistenceTests/ResetImmunityTests.swift` — the two cases above |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/anomaly.json` — populate: a real `highWaterDay`, ~30 entries, non-zero aggregates |
| create | `HunchCore/Tests/PersistenceTests/Fixtures/v1/anomaly.hw` — 16 bytes |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — add `anchors: MonotonicAnchorSource` to `live()` and `preview(seed:date:)` |
| modify | `tests.json` — nine entries |
| modify | `DECISIONS.md` — the sticky-lock reading and the `KERN_BOOTTIME` `bootID` |

## Implementation notes

### The value

```swift
public struct AnomalyLedger: Codable, Equatable, Sendable {
    public var v: Int = 1
    public var highWaterDay: Int64 = 0          // monotone. Never decreases. Never cleared by a reset.
    public var entries: [DayEntry] = []         // last 400 only, ascending by day
    public var streak: Int = 0
    public var longestStreak: Int = 0
    public var tally: Int = 0
    public var clockJumpCount: Int = 0
    public var anchor: MonotonicAnchor = .zero
    /// ADDITIVE, §11.13's rules. Non-nil while a clock-back lock is in force; the lock releases at
    /// `lockedThroughDay + 1`. See DECISIONS.md — §11.7's struct listing predates the sticky reading.
    public var lockedThroughDay: Int64?

    public mutating func observe(day: Int64, jumpDetectedThisSession: Bool = false)
    public mutating func record(_ entry: DayEntry)
    public func availability(on day: Int64) -> AnomalyAvailability
    public func day(_ day: Int64) -> DayState
}

public enum AnomalyAvailability: Equatable, Sendable {
    case playable
    case alreadySettled
    case notToday                       // a past or future day that is neither settled nor locked
    case clockBehind(unlocksAt: Int64)
}

/// The six render states of §11.8's table, as data. `AnomalyView` switches on this and nothing else.
public enum DayState: Equatable, Sendable {
    case clean, fractured, failed, missed, awaiting, locked
}
```

`DayEntry` and `AnomalyOutcome` are §11.7's, verbatim, and `AnomalyOutcome` is `Int`-raw-valued
`Codable` so the file format does not depend on case names.

### `observe(day:jumpDetectedThisSession:)` — the whole rule, in order

```
1. if jumpDetectedThisSession { clockJumpCount += 1 }

2. if let locked = lockedThroughDay {
       if day > locked && !jumpDetectedThisSession { lockedThroughDay = nil }   // released
       // otherwise the lock stands. A jump may only ever REFUSE TO SHORTEN it (§11.7).
   }

3. if day < highWaterDay {
       lockedThroughDay = max(lockedThroughDay ?? .min, highWaterDay)           // enter / hold
   }

4. highWaterDay = max(highWaterDay, day)

5. if let last = lastSettledDay, day > last + 1 { streak = 0 }                  // missed, derived
```

Five points a reader will otherwise "tidy":

- **Step 2 runs before step 4.** Releasing the lock is decided against the `highWaterDay` that was
  in force when the lock was taken, not against one this very call is about to raise. Swap them and
  a forward clock releases its own lock.
- **A jump never lengthens the lock.** Step 2's `&& !jumpDetectedThisSession` makes the release wait;
  it does not move `lockedThroughDay`. Next session, with no jump flagged and a genuine clock, the
  same call releases. §11.7: *"It never punishes, never wipes, never bans."*
- **`highWaterDay` still advances on a jump** (step 4). §11.7 is explicit that a forward clock burns
  days permanently, and that is true whether or not the jump was detected. Detection buys the lock a
  session, not the ledger a rollback.
- **Missed is derived from absence** (step 5, and `day(_:)`), never stored. §11.13's clock-set-forward-
  by-years row says so directly: a 25-year jump must not allocate 9,000 entries.
- **The streak break in step 5 tests `day > last + 1`, not `day != last + 1`.** Observing the same
  day twice, or a day before the last settled one, must not break anything.

### `availability(on:)`

```
if let locked = lockedThroughDay, day <= locked { return .clockBehind(unlocksAt: locked + 1) }
if settledEntry(for: day) != nil                { return .alreadySettled }
if day == highWaterDay                          { return .playable }
return .notToday
```

Four lines, and every clause of §11.7's playability sentence is one of them. There is no fifth
condition and no `default:`.

### `record(_:)` — and why a Codex replay changes nothing

`record` is idempotent per day: if a settled entry for that day already exists it is kept and the new
one is dropped. That is §10.6's *"Every past Anomaly remains playable forever from the Codex,
inscribed normally, but cannot retroactively extend the streak"* — the round runs, the Codex page is
minted by E15's path, and the ledger declines the write. Recording a **new** day:

```
entries.append(entry); if entries.count > 400 { entries.removeFirst(entries.count - 400) }
switch entry.outcome {
case .solvedClean:      tally += 1; streak += 1; longestStreak = max(longestStreak, streak)
case .solvedFractured:  tally += 1; streak = 0
case .failed, .abandoned:            streak = 0
}
```

No `default:` — adding a fifth outcome must break this switch (`W29`).

**The aggregates are not derived from `entries`.** `tally` and `longestStreak` outlive eviction, and
`entriesAreCappedAtFourHundred` asserts a tally of 500 against 400 entries precisely so nobody
"simplifies" them into a `filter().count`.

### `MonotonicAnchor` — the value is core, the sampling is not

```swift
public struct MonotonicAnchor: Codable, Equatable, Sendable {
    public let bootID: UUID          // stable for the life of one boot; see below
    public let uptimeAtStamp: Double // ProcessInfo.systemUptime at the stamp
    public let wallAtStamp: Date

    public static let jumpTolerance: TimeInterval = 120     // §11.7

    /// True iff wall-clock advanced more than `jumpTolerance` beyond monotonic elapsed *within one
    /// boot session*. Across boots `uptime` is not comparable and the answer is always false.
    public func jumpDetected(against later: MonotonicAnchor) -> Bool {
        guard later.bootID == bootID else { return false }
        let monotonic = later.uptimeAtStamp - uptimeAtStamp
        let wall = later.wallAtStamp.timeIntervalSince(wallAtStamp)
        return wall - monotonic > Self.jumpTolerance
    }
}
```

`jumpDetected` is a pure function of two values, so it is core and it is tested here. **Sampling** an
anchor reads `ProcessInfo.systemUptime`, the kernel boot time and the wall clock — three ambient
sources — so it lives in `Modules/Sources/HunchAppFeature/MonotonicAnchorSource.swift`, beside
`SeedSource` and `Now`, in the same closure shape (`04 A29`):

```swift
public struct MonotonicAnchorSource: Sendable {
    public var sample: @Sendable () -> MonotonicAnchor
    public static func live(now: Now) -> Self { … }
    public static func fixed(_ anchor: MonotonicAnchor) -> Self { Self { anchor } }
}
```

**`bootID` is derived from `KERN_BOOTTIME`, not from `UUID()`.** Two reasons, and record both in
`DECISIONS.md`:

1. A `UUID()` minted at launch changes every launch, so `jumpDetected` would return `false` on the
   very comparison that matters — the one across an app restart, which is exactly when a clock is
   most easily moved. A boot identity must be stable for the boot.
2. `UUID()` is on the hygiene grep's ban list, and E10·T01's check 12 scopes it to `SeedSource.swift`.
   Reading `sysctl(CTL_KERN, KERN_BOOTTIME)` gives a 16-byte `timeval` that *is* the boot identity;
   build the `UUID` from those bytes with `UUID(uuid:)` and no random source is involved.

`live(now:)` takes `Now` rather than calling `Date()` so check 12 stays a one-file rule.

### The `anomaly.hw` sidecar

16 bytes: `Int64` little-endian `highWaterDay` followed by an `Int64` FNV-1a checksum of it. Written
by `FilePersistenceStore` on **every** ledger mutation, in the same `.atomic` write batch, after
`anomaly.json`. On load, decode the JSON; on failure, read the sidecar and rebuild an otherwise-empty
ledger with that `highWaterDay`. §11.13: *"Never recovered as a lower value"* — take
`max(sidecar, anythingElseKnown)` and never the minimum, and never zero on a checksum failure (a
failed checksum leaves `highWaterDay` at whatever the in-memory ledger already held).

`StoreFile.anomaly` maps to two paths, so the enum grows a `sidecarPath` rather than a ninth case:
the reset map must keep treating "the Anomaly" as one thing that no action touches.

### Day rollover mid-round

§11.7: an in-progress round runs to completion and is credited to the day it *started*; an Anomaly
round left unsettled when its day is no longer `highWaterDay` is recorded `abandoned`. The round's
`startedOnDay` rides in `round-probe.json` (E07·T09's snapshot) and `record` takes the entry's own
`day` field — which is why `DayEntry.day` exists rather than being derived from `settledAt`. The
`abandoned` write itself happens in the reconciliation path T03 wires; this task only guarantees
`record` honours whatever day it is handed.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AnomalyLedgerTests` green, all nineteen tests.
- [ ] `swift test --package-path HunchCore --filter ResetImmunityTests` green, and the parameterised case covers all five `ResetAction` cases with a **populated** `anomaly.json` (> 200 bytes) in `Fixtures/v1/`.
- [ ] `grep -rn "UUID()" HunchCore/Sources Modules/Sources` returns only `SeedSource.swift`'s sanctioned site, if any — never `MonotonicAnchorSource.swift`.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/AnomalyLedger.swift` returns nothing.
- [ ] The three boundary cases are individually visible in the test output: `observed = highWaterDay − 1` locked, `= highWaterDay` locked-if-a-lock-was-taken, `= highWaterDay + 1` free.
- [ ] `DECISIONS.md` carries two new entries: the sticky `.clockBehind` reading with its §11.7 quotation and the additive `lockedThroughDay` field; and `bootID` from `KERN_BOOTTIME`.
- [ ] `tests.json` carries nine entries: high-water monotonicity, playability, clock-forward burn, no-entry-per-missed-day, the sticky lock, the `highWaterDay + 1` release boundary, jump-refuses-to-shorten, the 400-entry cap with surviving aggregates, and reset immunity on a populated ledger.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes deriving `tally` or `longestStreak` from `entries`, reject it and point at `entriesAreCappedAtFourHundred`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T02: AnomalyLedger, the high-water rule, the sticky clock-behind lock and reset immunity"`

## Out of scope

- Deriving the day's law from its index — **T01**.
- Serving the Anomaly round, the palette grant and the ladder isolation — **T03**.
- Drawing the ribbon's six states, the rollover arc or the lock's static ring — **T04**.
- The five reset *actions* and their alerts — **E17·T08**; this task only asserts what they must not do.
- `PersistenceStore`, atomic writes and the migration machinery — **E07·T01/T02/T04**.
