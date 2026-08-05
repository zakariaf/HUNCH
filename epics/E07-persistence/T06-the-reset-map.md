# T06 — The reset map

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 PERSISTENCE → **Reset map** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns the second of the three fixture assertions — "each of the five reset actions leaves exactly the specified file set, with `anomaly.json` and `anomaly.hw` byte-identical" — and owns the `StoreSandbox` trait this task runs every case inside |
| `hunch-swift-code` | Owns `W29`. The whole design of `StoreFile` exists so that the reset map is an exhaustive switch and adding a file is a compile error here; if you write `default:` in this file the epic has failed |

## Objective

`enum ResetAction` exists with §11.13's five cases, each describing exactly which files it deletes
and which it rewrites, and one function applies it to any `PersistenceStore`. The suite runs all five
against a copy of the v1 fixture and asserts the exact surviving file set, plus the one assertion the
Anomaly's entire anti-cheat rests on: `anomaly.json` and `anomaly.hw` are byte-identical after every
one of them.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13, *The reset map* | The five rows and their exact effects. **This table is the source; do not restate a single effect in Swift comments** |
| `GAME_DESIGN.md` | §12.6, DATA rows | The same five, from the settings side, with the two consequences: Clear Codex re-locks ECHO and SIEVE and **does not** touch the palette ceiling; only Reset the ladder drops it to its band-2 opening state |
| `GAME_DESIGN.md` | §11.7, *Reset immunity* | "No reset path of any kind touches `anomaly.json` or its `anomaly.hw` sidecar… Otherwise reset *is* the clock exploit: wipe the ledger, and `highWaterDay` goes with it. The migration fixture test asserts this directly" |
| `GAME_DESIGN.md` | §11.12 | Why the three content resets are independent of one another |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | No `default:` — in either switch |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 (the `StoreFile` row), §5 | "§11.13's tree and §11.13's reset map both become exhaustive `switch`es with no `default:`, so adding a file to the tree is a compile error in the reset map" |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/PersistenceTests/ResetMapTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence
import HunchTestSupport

@Suite("The reset map", .tags(.unit, .presubmission))
struct ResetMapTests {

    /// Day-1 bytes for the files a reset rewrites rather than deletes. The *contents* belong to the
    /// types' owners (E11 for ladder, E16 for profile and statistics); the file-level map is ours,
    /// so the test supplies bytes and asserts presence, never a field.
    private static let defaults: [StoreFile: Data] = [
        .statistics: Data(#"{"v":1,"rounds":0}"#.utf8),
        .profile:    Data(#"{"v":1,"axes":[]}"#.utf8),
        .ladder:     Data(#"{"v":1,"calibrationRound":1}"#.utf8),
        .codexIndex: Data(#"{"v":1,"lawKeys":[]}"#.utf8),
    ]

    // ---- the map, as data ----------------------------------------------------------------------

    @Test("Clear statistics moves stats.json and nothing else")
    func clearStatisticsIsNarrow() {
        #expect(ResetAction.clearStatistics.deletes.isEmpty)
        #expect(ResetAction.clearStatistics.rewrites == [.statistics])
    }

    @Test("Clear Codex deletes all eight shelves and empties the index")
    func clearCodexTouchesTheArchiveOnly() {
        let action = ResetAction.clearCodex
        #expect(action.deletes == Set(Band.allCases.map(StoreFile.codexShelf)))
        #expect(action.rewrites == [.codexIndex])
        #expect(!action.deletes.contains(.ladder))   // §12.6: the palette ceiling is ServingState
    }

    @Test("Reset the ladder keeps the Codex")
    func resetLadderKeepsTheCodex() {
        let action = ResetAction.resetLadder
        #expect(action.rewrites == [.ladder])
        #expect(action.deletes.isEmpty)
    }

    @Test("Reset everything deletes every file except the ledger and its sidecar")
    func resetEverythingSparesTheLedger() {
        let action = ResetAction.resetEverything
        let spared = Set(StoreFile.allCases).subtracting(action.deletes)
        #expect(spared == [.anomaly, .anomalyHighWater])
        #expect(action.deletes.contains(.lawIndex))  // §11.13: "including lowerBandIndex.bin"
        #expect(action.rewrites.isEmpty)
    }

    @Test("No action of any kind names the ledger or its sidecar", arguments: ResetAction.allCases)
    func nothingEverNamesTheLedger(_ action: ResetAction) {
        let named = action.deletes.union(action.rewrites)
        #expect(!named.contains(.anomaly))
        #expect(!named.contains(.anomalyHighWater))
    }

    // ---- the map, applied ----------------------------------------------------------------------

    @Test("Each action leaves exactly the specified file set",
          .storeSandbox(in: #bundle), arguments: ResetAction.allCases)
    func eachActionLeavesItsExactFileSet(_ action: ResetAction) async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        let before = try await store.present

        try await store.apply(action, writingDefaults: Self.defaults)

        let after = try await store.present
        let expected = before.subtracting(action.deletes).union(action.rewrites)
        #expect(after == expected,
                "\(action): unexpectedly gone \(expected.subtracting(after)), "
                + "unexpectedly present \(after.subtracting(expected))")
    }

    /// THE anti-cheat assertion. Not a courtesy to the ledger: `highWaterDay` is the only thing
    /// standing between the daily and the clock (§11.7), and a reset that cleared it would *be*
    /// the exploit.
    @Test("anomaly.json and anomaly.hw are byte-identical after every reset, and after all five",
          .storeSandbox(in: #bundle))
    func anomalyLedgerSurvivesEveryReset() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        let ledgerBefore = try await store.load(.anomaly)
        let sidecarBefore = try await store.load(.anomalyHighWater)

        for action in ResetAction.allCases {
            try await store.apply(action, writingDefaults: Self.defaults)
            #expect(try await store.load(.anomaly) == ledgerBefore, "\(action) altered anomaly.json")
            #expect(try await store.load(.anomalyHighWater) == sidecarBefore,
                    "\(action) altered anomaly.hw")
        }
        // …and after all five have run in sequence, the two files are still exactly what shipped.
        #expect(try await store.present.isSuperset(of: [.anomaly, .anomalyHighWater]))
        #expect(try await store.load(.anomaly) == ledgerBefore)
        #expect(try await store.load(.anomalyHighWater) == sidecarBefore)
    }

    @Test("Reset everything leaves the directory itself in place", .storeSandbox(in: #bundle))
    func noResetDeletesTheDirectory() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        try await store.apply(.resetEverything, writingDefaults: [:])
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: StoreSandbox.root.path(),
                                               isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test("A quarantined shelf is cleared by Clear Codex too — corrupt/ is not a hiding place",
          .storeSandbox(in: #bundle))
    func clearCodexAlsoClearsQuarantinedShelves() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        try await store.quarantine(.codexShelf(.relational))
        try await store.apply(.clearCodex, writingDefaults: Self.defaults)
        let leftovers = try StoreTree.bytes(of: StoreSandbox.root).keys
            .filter { $0.hasPrefix("corrupt/codex-") }
        #expect(leftovers.isEmpty, "\(leftovers)")
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ResetMapTests`
Every case fails on `cannot find 'ResetAction' in scope`. If `anomalyLedgerSurvivesEveryReset`
compiles and passes early, check that `apply` is actually being called — a no-op `apply` passes that
test and fails every other one, which is why the exact-file-set case is written first.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Nothing here should need refactoring; if it does, the `deletes`/
`rewrites` split is wrong. The one thing to check is that `apply` has no `switch` of its own — it
consumes the two sets and knows nothing about which action it is running.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Persistence/ResetAction.swift` |
| create | `HunchCore/Tests/PersistenceTests/ResetMapTests.swift` |
| modify | `HunchCore/Sources/Persistence/PersistenceStore.swift` — the `apply(_:writingDefaults:)` extension |
| modify | `tests.json` — the reset-map and Anomaly-immunity entries |

## Implementation notes

### The type

```swift
/// §11.13's reset map — five actions, one row each, all in Settings → DATA (§12.6).
///
/// The two sets are deliberately separate. A reset either **deletes** a file (it should not exist
/// afterwards) or **rewrites** it to day-1 defaults (it must exist afterwards, holding different
/// bytes). Collapsing them into "clear" loses that distinction, and the distinction is the whole
/// difference between "Clear statistics" and "Clear Codex".
public enum ResetAction: String, CaseIterable, Codable, Sendable {
    case clearStatistics
    case clearCodex
    case resetProfile
    case resetLadder
    case resetEverything

    /// Files removed outright.
    public var deletes: Set<StoreFile> {
        switch self {
        case .clearStatistics, .resetProfile, .resetLadder:
            []
        case .clearCodex:
            Set(Band.allCases.map(StoreFile.codexShelf))
        case .resetEverything:
            Set(StoreFile.allCases).subtracting([.anomaly, .anomalyHighWater])
        }
    }

    /// Files rewritten in place to their day-1 defaults. The *bytes* are supplied by the caller;
    /// their content belongs to the type's owner, not to the file map.
    public var rewrites: Set<StoreFile> {
        switch self {
        case .clearStatistics: [.statistics]
        case .clearCodex:      [.codexIndex]
        case .resetProfile:    [.profile]
        case .resetLadder:     [.ladder]
        case .resetEverything: []
        }
    }
}
```

Two details that are easy to get wrong and both are asserted:

- **`resetEverything.deletes` is derived by subtraction from `StoreFile.allCases`**, not typed out.
  That is what makes adding a file to the tree automatically deleted by "Reset everything" — and it
  is why the exclusion list is the thing written down, which is also how §11.13 words it.
- **`resetEverything.rewrites` is empty.** §11.13 says *deletes every file*; the manifest is
  recreated by the next write, and `ladder.json`'s day-1 state arrives when the ladder next saves.
  Rewriting on reset would mean this enum knowing four types' defaults.

`Codable` + `String` raw value so a single failing parameterised case re-runs from the navigator
(`06 T23`), and so `ResetAction` can later be logged in `DECISIONS`-adjacent diagnostics without a
second spelling.

### `apply`

```swift
extension PersistenceStore {
    /// Runs §11.13's reset map. `defaults` supplies the day-1 bytes for the files this action
    /// rewrites — the file map is core, the file *contents* belong to `Profile` (E16), `Ability`
    /// (E11) and the statistics counters (E16·T11).
    ///
    /// Deletes run before rewrites so that `.clearCodex` cannot delete the index it just wrote.
    public func apply(_ action: ResetAction,
                      writingDefaults defaults: [StoreFile: Data]) async throws {
        for file in action.deletes.sorted(by: { $0.fileName < $1.fileName }) {
            try await remove(file)
        }
        for file in action.rewrites.sorted(by: { $0.fileName < $1.fileName }) {
            guard let bytes = defaults[file] else { throw StoreError.missing(file) }
            try await save(bytes, to: file)
        }
    }
}
```

- **Sorted** so two runs behave identically; `Set` iteration order is not stable and a failing test
  that reorders itself is worse than no test.
- **A missing default is an error, not a skip.** A caller that forgets `profile.json`'s day-1 bytes
  must find out at the call site, not by shipping a reset that silently leaves the old profile in
  place.
- `remove` must be tolerant of an absent file (T03's contract test pins that), so a reset against a
  partially-populated store cannot throw halfway and leave the tree in a third state.

### Quarantined shelves

`clearCodexAlsoClearsQuarantinedShelves` is not pedantry: `corrupt/codex-b4.json` holds real page
data, and a player who clears their Codex on a shared device has asked for it to be gone. `remove`
therefore also removes the quarantined twin, or `apply` does it explicitly. Choose one, and say which
in a comment — the failure mode if neither does it is that Clear Codex looks like it worked and the
bytes are still on disk.

### What this task deliberately does not know

- That Clear Codex **re-locks ECHO and SIEVE** at §9.10's page gates. That is a consequence of the
  archive being empty, computed by **E17·T04** from the page count; it is not a file effect.
- That Clear Codex **does not** touch the palette ceiling. That is already true here for free —
  `maxBandEverServed` lives in `ServingState` in `ladder.json`, which `.clearCodex` does not name.
  The test `clearCodexTouchesTheArchiveOnly` pins it anyway, because it is the exact confusion
  §14.5's closed question records.
- The alert copy, the destructive verb and the focused cancel — **E17·T08**.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ResetMapTests` green: 4 map cases, 5
      parameterised ledger cases, 5 parameterised file-set cases, plus the three named cases.
- [ ] `grep -c 'default:' HunchCore/Sources/Persistence/ResetAction.swift` returns `0`.
- [ ] Adding a throwaway `case telemetry` to `StoreFile` makes `ResetAction.swift` fail to compile.
      Do it, read the error, revert. **This is the acceptance criterion the epic exists for.**
- [ ] Changing `.resetEverything`'s exclusion set to `[.anomaly]` alone makes
      `anomalyLedgerSurvivesEveryReset` fail on `anomaly.hw`. Do it, watch it fail, revert.
- [ ] `tests.json` carries `reset-map-file-sets` and `anomaly-ledger-reset-immunity` as separate
      entries — separate, because §11.7 treats them as separate claims.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — re-run the tests after it. Refuse any suggestion to merge `deletes` and
   `rewrites` into one `Set` plus a flag; that is `W28`'s "a `Bool` meaningful only when…" in
   miniature and it loses the Clear-statistics/Clear-Codex distinction.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T06: the five-action reset map and the Anomaly immunity assertion"`

## Out of scope

- The five alert variants, their bodies and the focused cancel — **E17·T08**.
- Clearing `hunch.settings.*` from `UserDefaults` on Reset everything, and the two keys that survive
  (`languageTag`, `theme`) — **E17·T08**. `UserDefaults` is not a `StoreFile` and never becomes one:
  §12.6 is explicit that preferences and game state are different stores.
- Re-arming onboarding from beat 0 after Reset everything — **E10·T07** (`OnboardingLedger` lives in
  `ladder.json`, which Reset everything deletes; the re-arm is a consequence, not an effect).
- The day-1 *contents* of `profile.json`, `ladder.json` and `stats.json` — **E16·T05/T06**,
  **E11·T01**, **E16·T11**.
