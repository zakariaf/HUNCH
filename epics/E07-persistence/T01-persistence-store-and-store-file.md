# T01 — `PersistenceStore` and `StoreFile`

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | §14.1 PERSISTENCE → **File tree**, **`PersistenceStore`** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns the boundary predicate (is a store *core*? yes — its directory arrives in `init`), the `08 §3` naming row that fixes this exact enum's cases, `W44`'s ruling that `PersistenceStore` keeps its protocol because it is a published boundary and not because of member count, and `W29` — the rule that makes the whole design work |
| `hunch-swift-concurrency` | The protocol is `Sendable` and every member is `async`; this skill owns why (`05 R17` row 4, `05 R21`) and owns the actor budget the next task spends |

## Objective

`HunchCore/Sources/Persistence/` exists and declares the seam every later epic injects: a `Sendable`
protocol with `async` members, and one enum whose cases are §11.13's ten kinds of file. At the end of
this task adding a file to the tree is a compile error in four places — the filename map, the write
order, the recovery policy and (in T06) the reset map — and nothing on disk can be addressed by a
string.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13 | The file table: which files exist, what each holds, which is written first, which is excluded from backup. Ten kinds of file, seventeen-plus on disk. **Read the whole section including the failure table** |
| `GAME_DESIGN.md` | §12.6 (persistence map) | That `UserDefaults` holds preferences only and game state is JSON; that nothing is ever written to `Documents/` |
| `GAME_DESIGN.md` | §14.5 decision 3 | Four `round-{mode}.json` slots, SIEVE excluded — which is why the case is `round(Mode)` and not a bare `round` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 (tree), §3 (rows "the ten on-disk files", "the persistence seam"), §2 (boundary rule) | The exact file paths, the exact case list, and why this is core |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29, W44, W28 | No `default:` over an enum you own; a repository boundary keeps its protocol at any member count; a `Bool` meaningful only when an optional is non-nil is a type error |
| `ios-swift-guide/02-NAMING-AND-API-DESIGN.md` | N26, N40, N47 | `…Store` survives the suffix ban because it names a real role; never `PersistenceStoreProtocol` |
| `ios-swift-guide/05-CONCURRENCY.md` | R21 | `: Sendable` written explicitly on every public value type |

Never restate a filename, a size or a reset effect that §11.13 owns — cite the row and read it.

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/PersistenceTests/StoreFileTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence

@Suite("The ten-file tree", .tags(.unit, .presubmission))
struct StoreFileTests {

    // §11.13 counts ten *kinds*; the addressable count is what the tree actually holds:
    // 2 singletons + 8 shelves + 4 anomaly/profile/ladder/statistics + 4 round slots + 1 index.
    @Test("Every kind of file is enumerated, and the count is derived, never typed")
    func allCasesCoversTheTree() {
        let expected = 2                              // manifest, codexIndex
            + Band.allCases.count                     // codex-b1…b8
            + 2                                       // anomaly, anomalyHighWater
            + 3                                       // profile, ladder, statistics
            + Mode.allCases.count                     // round-{mode}
            + 1                                       // lawIndex
        #expect(StoreFile.allCases.count == expected)
        #expect(Set(StoreFile.allCases).count == StoreFile.allCases.count)
    }

    @Test("No two files share a name — a collision would silently alias two owners")
    func fileNamesArePairwiseDistinct() {
        let names = StoreFile.allCases.map(\.fileName)
        #expect(Set(names).count == names.count, "colliding names: \(names)")
    }

    @Test("Every name is a bare filename with an extension and no path separator")
    func fileNamesAreFlat() {
        let bad = StoreFile.allCases.filter {
            $0.fileName.contains("/") || $0.fileName.hasPrefix(".") || !$0.fileName.contains(".")
        }
        #expect(bad.isEmpty, "not flat filenames: \(bad.map(\.fileName))")
    }

    @Test("The spellings §11.13 fixes are the spellings on disk")
    func spellingsMatchTheSpecTable() {
        #expect(StoreFile.manifest.fileName == "manifest.json")
        #expect(StoreFile.codexIndex.fileName == "codex-index.json")
        #expect(StoreFile.codexShelf(.relational).fileName == "codex-b4.json")
        #expect(StoreFile.anomaly.fileName == "anomaly.json")
        #expect(StoreFile.anomalyHighWater.fileName == "anomaly.hw")
        #expect(StoreFile.statistics.fileName == "stats.json")
        #expect(StoreFile.round(.probe).fileName == "round-probe.json")
        #expect(StoreFile.lawIndex.fileName == "lowerBandIndex.bin")
    }

    @Test("The shelf a band writes to is that band's own shelf, for all eight",
          arguments: Band.allCases)
    func shelfNameCarriesTheBandNumber(_ band: Band) {
        #expect(StoreFile.codexShelf(band).fileName == "codex-b\(band.rawValue).json")
    }

    // §11.13's failure table, as data. A file with no stated recovery is a file with no owner.
    @Test("Every file declares §11.13's recovery policy")
    func everyFileHasARecoveryPolicy() {
        #expect(StoreFile.codexShelf(.relational).recovery == .rebuildEmpty)
        #expect(StoreFile.codexIndex.recovery == .rebuildByScanningShelves)
        #expect(StoreFile.profile.recovery == .resetToDefaults)
        #expect(StoreFile.ladder.recovery == .resetToDefaults)
        #expect(StoreFile.anomaly.recovery == .recoverFromSidecar)
        #expect(StoreFile.round(.probe).recovery == .voidTheRound)
        #expect(StoreFile.lawIndex.recovery == .regenerate)
    }

    // The backup rule, stated once and read from one place (§11.13, §12.6's persistence map).
    @Test("lowerBandIndex.bin is excluded from backup and nothing else is")
    func exactlyOneFileIsExcludedFromBackup() {
        let excluded = StoreFile.allCases.filter(\.isExcludedFromBackup)
        #expect(excluded == [.lawIndex])
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter StoreFileTests`
Confirm it fails on **missing symbols** (`cannot find 'StoreFile' in scope`), not on a malformed
test. If it compiles at this point, something already declared `StoreFile` and you are about to
write a second one.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net. The refactor to look for here is
the one that turns three parallel `switch`es into one — resist it: `fileName`, `recovery`,
`isExcludedFromBackup` and `writeRank` (T02) are four independent facts about the same enum, and
merging them into a record makes adding a case *easier*, which is the opposite of the goal.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Persistence/StoreFile.swift` |
| create | `HunchCore/Sources/Persistence/PersistenceStore.swift` |
| create | `HunchCore/Sources/Persistence/StoreHealth.swift` |
| create | `HunchCore/Sources/Persistence/StoreError.swift` |
| create | `HunchCore/Sources/Persistence/RecoveryPolicy.swift` |
| create | `HunchCore/Tests/PersistenceTests/StoreFileTests.swift` |
| modify | `HunchCore/Package.swift` — add the `Persistence` target (dependencies `["Glyphs", "LawGeneration"]`) and the `PersistenceTests` test target (dependencies `["Persistence", "HunchTestSupport"]`) |
| modify | `DECISIONS.md` — the tenth `StoreFile` case |

## Implementation notes

### The enum, and the one case `08 §3` left out

`08 §3` lists nine cases. §11.13 says **ten kinds of file** and its failure table makes the
difference load-bearing: *"`highWaterDay` is recovered from a 16-byte sidecar `anomaly.hw` written on
every mutation"*. The sidecar is the recovery source **for the file that failed to decode**, so it
must be loadable when the ledger is not — i.e. independently addressable. Ship the tenth case and
record the deviation:

```swift
/// §11.13's file tree. Every path on disk is one of these; nothing is addressed by a string.
///
/// `08 §3` lists nine cases; §11.13 counts ten kinds of file. The tenth is `anomalyHighWater`,
/// the 16-byte `anomaly.hw` sidecar — it has to be addressable on its own because it is what
/// recovers `anomaly.json` when `anomaly.json` is the thing that failed to decode.
public enum StoreFile: Hashable, Sendable, CaseIterable {
    case manifest
    case codexIndex
    case codexShelf(Band)
    case anomaly
    case anomalyHighWater
    case profile
    case ladder
    case statistics
    case round(Mode)
    case lawIndex

    public static let allCases: [StoreFile] =
        [.manifest, .codexIndex]
        + Band.allCases.map(StoreFile.codexShelf)
        + [.anomaly, .anomalyHighWater, .profile, .ladder, .statistics]
        + Mode.allCases.map(StoreFile.round)
        + [.lawIndex]
}
```

`CaseIterable` with associated values needs a hand-written `allCases`; that is expected and is why
`allCasesCoversTheTree` derives its count from `Band.allCases.count` and `Mode.allCases.count`
rather than typing `20`.

### `fileName` — one exhaustive switch, no `default:`

```swift
extension StoreFile {
    /// The bare filename inside `Application Support/Hunch/`. §11.13 owns every spelling;
    /// note `statistics` → `stats.json`: the case is named for the concept, the file for the spec.
    public var fileName: String {
        switch self {
        case .manifest:            "manifest.json"
        case .codexIndex:          "codex-index.json"
        case .codexShelf(let b):   "codex-b\(b.rawValue).json"
        case .anomaly:             "anomaly.json"
        case .anomalyHighWater:    "anomaly.hw"
        case .profile:             "profile.json"
        case .ladder:              "ladder.json"
        case .statistics:          "stats.json"
        case .round(let m):        "round-\(m.slug).json"
        case .lawIndex:            "lowerBandIndex.bin"
        }
    }
}
```

`Mode.slug` is a lowercase stable string (`probe`/`drift`/`echo`/`sieve`). If E02·T06 did not ship
one, add it there — **not** here, and never derive it from `String(describing:)`, which is a
reflection spelling that changes when the case is renamed. `Mode` already carries a `UInt8` raw value
for persistence (§6.10); the slug is for the *filename*, which a human reads in a bug report.

`StoreFile.round(.sieve)` is representable and never written: §9.8 voids a SIEVE run rather than
suspending it (§14.5 decision 3 — "four slots, SIEVE excluded, so three files in practice"). That
invariant belongs to **E14·T08** and is asserted there; do not encode it in the type, because a
five-case `Mode` that excluded SIEVE from suspension at the type level would be a second `Mode`.

### `RecoveryPolicy` — §11.13's failure table as data

```swift
/// What the app does when a file fails to decode. §11.13's failure table, one case per row,
/// so "this file has no stated recovery" is a compile error rather than a discovery in the field.
public enum RecoveryPolicy: Hashable, Sendable {
    case rebuildEmpty              // a codex shelf: quarantine to corrupt/, rebuild empty
    case rebuildByScanningShelves  // codex-index.json: rebuilt by scanning the eight shelves
    case resetToDefaults           // profile / ladder / statistics: day-1 defaults
    case recoverFromSidecar        // anomaly.json ← anomaly.hw, never as a *lower* value
    case voidTheRound              // round-{mode}.json: Outcome.voided, never a silent alteration
    case regenerate                // lowerBandIndex.bin (derived), manifest.json (rewritten)
}
```

The `anomalyHighWater` case's own recovery is `.regenerate` in the degenerate sense — if the sidecar
is gone and the ledger decodes, the sidecar is rewritten from the ledger. Write that as a doc
comment on the case, because it is the one row §11.13 does not spell out and the next reader will
ask.

### The protocol

```swift
/// The persistence seam. Injected, never a singleton; `04 A29`'s rule is "no singleton inside a
/// boundary you test across", and this is that boundary. `W44`: a repository keeps its protocol
/// at any member count.
public protocol PersistenceStore: Sendable {
    /// Every file that currently exists. The reset map and the fixture suite both assert on it.
    var present: Set<StoreFile> { get async throws }

    /// The most recent quarantine or failed write. Drives the chrome hairline (§11.13, disk full).
    var health: StoreHealth { get async }

    func load(_ file: StoreFile) async throws -> Data
    func save(_ data: Data, to file: StoreFile) async throws
    func remove(_ file: StoreFile) async throws

    /// Moves a file that failed to decode into `corrupt/` and leaves the store healthy with the
    /// file absent. Only the *caller* can know a payload is malformed — the store moves bytes.
    func quarantine(_ file: StoreFile) async throws

    /// §11.13's write order, as one operation: `round-{mode}.json` first because it is the smallest
    /// file, then everything else, and the snapshot slot cleared **last**, only after every other
    /// write has succeeded. T02 implements the ordering; the seam declares it so no caller can
    /// reinvent the order at a call site.
    func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) async throws
}
```

Six members plus two properties, so `W44`'s size tiebreak never even engages — but state the real
reason in the doc comment, because someone will one day count members.

`present` and `health` are `async` property requirements; that is legal and it is the right shape
(`await store.present` reads better than `await store.present()` for a value the store simply has).

### `StoreHealth` and `StoreError`

```swift
/// §11.13's failure states, reduced to what the UI must render. `04 A46`: opening a store can fail
/// on data you do not control, so `try!` is not available to you.
public enum StoreHealth: Hashable, Sendable {
    case healthy
    case quarantined(StoreFile)   // the shelf was moved to corrupt/ and rebuilt empty
    case writeFailed(StoreFile)   // disk full: in-memory state retained, retried at round end
}

public enum StoreError: Error, Hashable, Sendable {
    case missing(StoreFile)
    case unreadable(StoreFile)
    case writeFailed(StoreFile)
    case directoryUnavailable(URL)
}
```

`StoreError` is `Hashable` so tests can `#expect(error == .missing(.profile))` with no casting; `06
T55` requires a **specific typed error**, and an untyped `Error` makes that impossible to write.

### Package manifest

The `Persistence` target's `dependencies:` are `["Glyphs", "LawGeneration"]` — `Mode` comes from
`Glyphs` (E02·T06's shared value enums) and `Band` from `LawGeneration` (E05·T06). It deliberately
does **not** depend on `Archive`: the store moves `Data`, so it never learns a domain type, which is
what keeps `Archive` free to change without recompiling the store. Do not add the dependency in a
later task "for convenience".

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter StoreFileTests` is green, all seven cases.
- [ ] `grep -c 'default:' HunchCore/Sources/Persistence/StoreFile.swift` returns `0`.
- [ ] `grep -n 'case ' HunchCore/Sources/Persistence/StoreFile.swift | head -12` shows the ten cases
      in §11.13's table order.
- [ ] Adding a throwaway eleventh case to `StoreFile` makes `swift build --package-path HunchCore`
      fail with at least three distinct errors (`fileName`, `recovery`, `isExcludedFromBackup`).
      Do this once, read the errors, revert. That check *is* the deliverable.
- [ ] `PersistenceStore` has no implementation in this task — `grep -rn ': PersistenceStore'
      HunchCore/Sources` returns nothing.
- [ ] `DECISIONS.md` carries an entry for the tenth case with §11.13's "ten kinds" sentence cited.
- [ ] `swift build --package-path HunchCore` emits zero warnings.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it. Reject any suggestion that collapses the four
   per-case switches into one table literal; see step 4 above.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E07/T01: PersistenceStore seam and the ten-file StoreFile tree"`

## Out of scope

- Any conforming type. `FilePersistenceStore` is **T02**, `InMemoryPersistenceStore` is **T03**,
  `UnimplementedPersistenceStore` is E01·T04's `HunchTestSupport` (extend it in T03 if the member
  list grew).
- `writeRank` / `orderedForWrite` — **T02**, because the order is a property of *writing*, not of
  the tree, and its test needs a real directory.
- `ResetAction` and the five surviving file sets — **T06**.
- `Manifest`, `Schema`, `SchemaEnvelope` — **T04**.
- The contents of any file. `CodexPage` is **T09**; `Ability` is **E11·T01**; `OnboardingLedger` is
  **E10·T07**; the `Statistics` counters are **E16·T11**.
- The directory URL. `.applicationSupportDirectory.appending(path: "Hunch")` is named exactly once,
  in `AppDependencies.live()` — **E10·T01**. This task must not mention `applicationSupportDirectory`
  at all; the store takes its directory as a parameter, which is the half of `08 §2`'s boundary
  predicate that keeps it in `HunchCore`.
