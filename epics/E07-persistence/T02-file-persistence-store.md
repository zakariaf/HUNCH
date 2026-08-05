# T02 — `FilePersistenceStore`

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | §14.1 PERSISTENCE → **`PersistenceStore`**, **Backup policy** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-concurrency` | This is one of the two sanctioned actors. The skill owns `05 R17` row 4's three clauses (cohesive state with behaviour, callers already `async`, the critical section must `await`) — write the actor only after checking all three, and owns `05 R12`: `await` is not a critical section, which is exactly the bug a multi-file `commit` invites |
| `hunch-swift-code` | Owns the boundary predicate half (b) — "`Date()` called inside the core is a violation; a `Date` handed in is data", which is why a store whose directory arrives in `init` is core — and owns `04 A46`'s ruling that `try!` is unavailable to you |

## Objective

`actor FilePersistenceStore: PersistenceStore` exists, writes `.atomic` into a directory it was
handed, sequences a multi-file commit in §11.13's order with the suspended round written first and
its slot cleared last, sets `isExcludedFromBackupKey` on `lowerBandIndex.bin` and on nothing else,
and quarantines a bad file into `corrupt/` instead of throwing at a live round. After this task a
relaunch can find what the last launch wrote.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13 | The write order (`round.json` first, smallest file, so an in-progress round is the last thing lost), the backup exclusion set to one file "here and nowhere else", the quarantine-to-`corrupt/` behaviour, the disk-full row |
| `GAME_DESIGN.md` | §11.5 | Why nothing is ever written to `Documents/` — no export, no file format, the app must not appear in Files |
| `GAME_DESIGN.md` | §12.6 (persistence map) | The backup column: the whole tree backs up **except** `lowerBandIndex.bin` |
| `GAME_DESIGN.md` | §12.7 | `scenePhase → .background`: flush + `fsync` `round.json`, then the other dirty files in §11.13's order |
| `GAME_DESIGN.md` | §6.10, §6.11 case 22 | The snapshot slot is cleared last, after every other write succeeds; a failed write retains in-memory state and retries at the next round boundary |
| `ios-swift-guide/05-CONCURRENCY.md` | R17, R12, R21, R30 | Which state shape an actor is for; that `await` is not a critical section |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A46 | Opening a store can fail on data you do not control |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §4 (actors), §1 (path) | The two-actor budget and this file's home |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/PersistenceTests/FilePersistenceStoreTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence
import HunchTestSupport

@Suite("FilePersistenceStore", .tags(.unit, .presubmission))
struct FilePersistenceStoreTests {

    /// A fresh directory per test, made by Foundation rather than by a UUID — `UUID()` is banned
    /// under `HunchCore/Sources/` by check 6 and `HunchTestSupport` lives under it.
    private func makeDirectory() throws -> URL {
        try FileManager.default.url(for: .itemReplacementDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: URL.temporaryDirectory,
                                    create: true)
            .appending(path: "Hunch")
    }

    // ---- the write order, tested as a pure function -------------------------------------------

    @Test("The suspended round is written before every other file")
    func roundSortsFirst() {
        let unordered: Set<StoreFile> = [.codexIndex, .manifest, .round(.probe), .anomaly, .profile]
        let ordered = StoreFile.orderedForWrite(unordered)
        #expect(ordered.first == .round(.probe))
    }

    @Test("The high-water sidecar is written before the ledger it protects")
    func sidecarSortsBeforeTheLedger() {
        let ordered = StoreFile.orderedForWrite([.anomaly, .anomalyHighWater, .profile])
        let hw = try! #require(ordered.firstIndex(of: .anomalyHighWater))
        let ledger = try! #require(ordered.firstIndex(of: .anomaly))
        #expect(hw < ledger)
    }

    @Test("The order is total and deterministic — the same set always writes in the same sequence")
    func orderIsDeterministic() {
        let all = Set(StoreFile.allCases)
        #expect(StoreFile.orderedForWrite(all) == StoreFile.orderedForWrite(all))
        #expect(StoreFile.orderedForWrite(all).count == StoreFile.allCases.count)
    }

    // ---- the actor ----------------------------------------------------------------------------

    @Test("A saved file loads back byte-identical")
    func saveThenLoadIsIdentity() async throws {
        let store = FilePersistenceStore(directory: try makeDirectory())
        let payload = Data("{\"v\":1}".utf8)
        try await store.save(payload, to: .profile)
        #expect(try await store.load(.profile) == payload)
        #expect(try await store.present.contains(.profile))
    }

    @Test("Loading an absent file throws the typed error, not a generic one")
    func loadingAnAbsentFileThrowsMissing() async throws {
        let store = FilePersistenceStore(directory: try makeDirectory())
        await #expect(throws: StoreError.missing(.ladder)) { try await store.load(.ladder) }
    }

    @Test("commit clears the round slot only after every other write has succeeded")
    func aFailedWriteLeavesTheSnapshotIntact() async throws {
        let directory = try makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Occupy stats.json with a *directory*: writing Data there fails, deterministically and
        // portably, with no need to simulate a full disk.
        try FileManager.default.createDirectory(
            at: directory.appending(path: StoreFile.statistics.fileName),
            withIntermediateDirectories: false)

        let store = FilePersistenceStore(directory: directory)
        let snapshot = Data("snapshot".utf8)
        try await store.save(snapshot, to: .round(.probe))

        await #expect(throws: (any Error).self) {
            try await store.commit([.round(.probe): snapshot, .statistics: Data("x".utf8)],
                                   clearingRoundFor: .probe)
        }
        // Both halves matter: the round survived, and the round was written before the failure.
        #expect(try await store.load(.round(.probe)) == snapshot)
        #expect(await store.health == .writeFailed(.statistics))
    }

    @Test("A clean commit clears the round slot last and leaves everything else present")
    func aCleanCommitClearsTheSnapshot() async throws {
        let store = FilePersistenceStore(directory: try makeDirectory())
        try await store.save(Data("snapshot".utf8), to: .round(.probe))
        try await store.commit([.statistics: Data("{}".utf8), .codexIndex: Data("[]".utf8)],
                               clearingRoundFor: .probe)
        let present = try await store.present
        #expect(!present.contains(.round(.probe)))
        #expect(present.isSuperset(of: [.statistics, .codexIndex]))
        #expect(await store.health == .healthy)
    }

    // ---- the backup rule ----------------------------------------------------------------------

    @Test("isExcludedFromBackupKey is set on lowerBandIndex.bin and on nothing else")
    func exactlyOneFileIsExcludedFromBackup() async throws {
        let directory = try makeDirectory()
        let store = FilePersistenceStore(directory: directory)
        for file in StoreFile.allCases { try await store.save(Data("x".utf8), to: file) }

        let excluded = try StoreFile.allCases.filter { file in
            let url = directory.appending(path: file.fileName)
            return try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup == true
        }
        #expect(excluded == [.lawIndex])
    }

    // ---- quarantine ---------------------------------------------------------------------------

    @Test("Quarantine moves the bytes to corrupt/ and leaves the store usable")
    func quarantineMovesRatherThanDeletes() async throws {
        let directory = try makeDirectory()
        let store = FilePersistenceStore(directory: directory)
        let bytes = Data("{\"truncated\":".utf8)
        try await store.save(bytes, to: .codexShelf(.relational))
        try await store.save(Data("[]".utf8), to: .codexIndex)

        try await store.quarantine(.codexShelf(.relational))

        #expect(!(try await store.present.contains(.codexShelf(.relational))))
        #expect(try await store.present.contains(.codexIndex))   // dedup authority survives
        #expect(await store.health == .quarantined(.codexShelf(.relational)))
        let quarantined = directory.appending(path: "corrupt")
            .appending(path: StoreFile.codexShelf(.relational).fileName)
        #expect(try Data(contentsOf: quarantined) == bytes)      // moved, never destroyed
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter FilePersistenceStoreTests`
Confirm every failure is `cannot find 'FilePersistenceStore' in scope` or
`value of type 'StoreFile' has no member 'orderedForWrite'`. If `aFailedWriteLeavesTheSnapshotIntact`
passes before the implementation exists, the `#expect(throws:)` is swallowing a compile-time stub —
check it.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** The refactor worth doing here is extracting `write(_:to:)` so that
`save` and `commit` share exactly one code path; the refactor to avoid is hoisting the `FileManager`
into a stored property typed as anything other than `FileManager` — an injected file-system protocol
is a seam nobody asked for (`W44`) and the temp directory already gives you isolation.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Persistence/FilePersistenceStore.swift` |
| create | `HunchCore/Tests/PersistenceTests/FilePersistenceStoreTests.swift` |
| modify | `HunchCore/Sources/Persistence/StoreFile.swift` — add `writeRank` and `static func orderedForWrite(_:)` |
| modify | `Scripts/check-source-hygiene.sh` — extend check 5's block with one grep: `documentsDirectory` / `.documentDirectory` appear nowhere in `HunchCore/`, `Modules/` or `App/` |
| modify | `DECISIONS.md` — the sidecar-before-ledger write order |

## Implementation notes

### The order, as a pure function on the enum

```swift
extension StoreFile {
    /// §11.13's write order. Lower ranks are written first.
    ///
    /// 0 — the suspended round: "written first and is the smallest file, so an in-progress round is
    ///     the last thing to be lost" (§11.13, disk-full row).
    /// 1 — `anomaly.hw` before `anomaly.json`. §11.13 is silent on their relative order; the
    ///     high-water rule (§11.7) is monotone and "never recovered as a *lower* value", so a crash
    ///     between the two must leave the sidecar **ahead of** the ledger, never behind it.
    ///     Recorded in DECISIONS.md.
    /// 2 — everything else.
    var writeRank: Int {
        switch self {
        case .round:            0
        case .anomalyHighWater: 1
        case .anomaly:          2
        case .manifest, .codexIndex, .codexShelf, .profile, .ladder, .statistics, .lawIndex: 3
        }
    }

    /// Total and deterministic: rank first, then `fileName`, so two runs write the same sequence
    /// and the ordering test is not a coin flip on `Set` iteration order.
    public static func orderedForWrite(_ files: some Sequence<StoreFile>) -> [StoreFile] {
        files.sorted { ($0.writeRank, $0.fileName) < ($1.writeRank, $1.fileName) }
    }
}
```

### The actor

```swift
/// `05 R17` row 4: cohesive state with behaviour, callers already `async`, and the critical section
/// must `await`. File I/O has no business on the main actor.
public actor FilePersistenceStore: PersistenceStore {
    private let directory: URL
    private let fileManager: FileManager
    private var currentHealth: StoreHealth = .healthy

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }
    …
}
```

The directory arrives in `init`; that is the whole reason this type passes `08 §2`'s boundary
predicate. **Never** compute it here — `.applicationSupportDirectory.appending(path: "Hunch")` is
named once, in `AppDependencies.live()` (E10·T01).

Create the directory lazily on the first write (`withIntermediateDirectories: true`), not in `init`:
an `init` that touches the file system cannot be called from a preview, and `init` cannot `throw`
here without infecting every construction site.

### Writing

```swift
private func write(_ data: Data, to file: StoreFile) throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    var url = directory.appending(path: file.fileName)
    do {
        try data.write(to: url, options: [.atomic])
    } catch {
        currentHealth = .writeFailed(file)
        throw StoreError.writeFailed(file)
    }
    if file.isExcludedFromBackup {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)     // best-effort: a backup flag never fails a round
    }
}
```

`.atomic` **is** the durability story for a single file: a temporary file plus a rename, so a crash
mid-write leaves the previous version intact. `isExcludedFromBackupKey` is set on the URL *after* the
write, because `.atomic` replaces the inode and would discard a flag set on the old one — this is the
bug that makes the backup exclusion silently stop working, and the test in step 1 catches it.

`url` must be a `var` for `setResourceValues`, which mutates the receiver's cached values.

### `commit` — the ordering and the last clear

```swift
public func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) async throws {
    for file in StoreFile.orderedForWrite(writes.keys) {
        try write(writes[file]!, to: file)      // force-unwrap of a key we just enumerated
    }
    if let mode { try remove(.round(mode)) }    // §11.13: the snapshot slot is cleared LAST
    currentHealth = .healthy
}
```

Three things to be exact about:

1. **The clear is after the loop, not in it.** If any write throws, the loop exits and the round file
   is still there — which is §11.13's stated intent and the reason the round is written first.
2. **No `await` inside the loop.** `05 R12`: `await` is not a critical section. Everything here is
   synchronous file I/O inside the actor, so the whole commit is one indivisible step from every
   caller's point of view. Do not "improve" it with a `TaskGroup`; concurrent writes would destroy
   the order that is the entire point.
3. **`currentHealth` is set to `.healthy` only on success**, and `write` sets `.writeFailed` on the
   failing file, so a caller reading `health` after a throw learns *which* file failed — which is
   what §11.13's disk-full row needs in order to retry it at the next round boundary.

The force-unwrap is safe and is the honest spelling; if `/code-review` objects, replace it with
`writes.sorted(by: …)` over the pairs rather than adding an `if let` that cannot fire.

### Quarantine

```swift
public func quarantine(_ file: StoreFile) throws {
    let corrupt = directory.appending(path: "corrupt")
    try fileManager.createDirectory(at: corrupt, withIntermediateDirectories: true)
    let destination = corrupt.appending(path: file.fileName)
    try? fileManager.removeItem(at: destination)          // a second corruption overwrites the first
    try fileManager.moveItem(at: directory.appending(path: file.fileName), to: destination)
    currentHealth = .quarantined(file)
}
```

Move, never delete. §11.13 does not say the bytes are kept, but the failure table's whole posture is
"page detail is lost, *already found* is not" — keeping the bytes costs nothing and is the difference
between a diagnosable bug report and a shrug. `corrupt/` is not a `StoreFile` and never becomes one:
nothing reads it, and `present` must not list it (assert that if `/code-review` doubts it).

### `present`

```swift
public var present: Set<StoreFile> {
    get throws {
        let names = Set((try? fileManager.contentsOfDirectory(atPath: directory.path())) ?? [])
        return Set(StoreFile.allCases.filter { names.contains($0.fileName) })
    }
}
```

Derived from the directory listing every time, never mirrored in a stored `Set` — `04 A14`/`A15`,
derive, never mirror. A mirrored set is wrong the first time anything writes to the directory that is
not this actor (a migration, a test, the debugger).

### fsync

§12.7's `.background` row says *flush + fsync*. `Data.write(options: .atomic)` gives atomicity, not
durability. Add:

```swift
/// §12.7 — called on `scenePhase → .background`. Foundation exposes no directory-level fsync, so
/// this synchronises the file contents; the rename's durability rides on the volume's own ordering.
/// The stronger guarantee is bought in T04, where a whole tree is replaced with `replaceItemAt`.
public func synchronize(_ file: StoreFile) throws {
    let handle = try FileHandle(forWritingTo: directory.appending(path: file.fileName))
    defer { try? handle.close() }
    try handle.synchronize()
}
```

Do not reach for `import Darwin` and a raw `fsync(2)` on the directory fd: `08 §2`'s boundary
predicate is "imports nothing but `Swift`/`Foundation`", and the honest note above is worth more than
a platform import that makes the target non-portable to the Linux host CI could one day use.

### The `Documents/` ban

There is no code to write; there is a grep to add. §11.5 forbids `Documents/` outright and the app
must not appear in Files. Extend `Scripts/check-source-hygiene.sh` check 5's block with:

```bash
if grep -rn --include='*.swift' -E 'documentsDirectory|\.documentDirectory' HunchCore Modules App; then
  echo "check 5b FAILED: nothing is ever written to Documents/ (GAME_DESIGN §11.5)"; exit 1
fi
```

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter FilePersistenceStoreTests` green, all nine cases.
- [ ] `grep -rn 'actor ' HunchCore/Sources` lists exactly `FilePersistenceStore` and (from E05·T07)
      `LawIndexLoader`.
- [ ] `grep -rn 'applicationSupportDirectory' HunchCore/Sources` returns nothing.
- [ ] `bash Scripts/check-source-hygiene.sh` passes, and planting `let x = URL.documentsDirectory`
      in any Swift file makes it fail. Plant it, watch it fail, remove it.
- [ ] `aFailedWriteLeavesTheSnapshotIntact` fails if the `remove` is moved inside the loop. Move it,
      watch the test go red, move it back.
- [ ] `swift build --package-path HunchCore` emits zero warnings; no `try!` anywhere in the file.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — then re-run the tests. Watch specifically for it proposing a `TaskGroup`
   inside `commit`; refuse, and leave a one-line comment saying why.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T02: FilePersistenceStore — atomic writes in §11.13's order"`

## Out of scope

- The in-memory conformance and the parity suite — **T03**.
- The schema envelope, `Manifest`, migration and the staging directory — **T04**.
- The `Fixtures/v1/` tree, the `StoreSandbox` trait and the round-trip over every case — **T05**.
- Deciding *when* a shelf is malformed. The store moves bytes on request; the decoder that failed is
  the `Codex` (**E15·T01**) and the snapshot loader (**E10·T02**).
- Retrying a failed write at the next round boundary (§6.11 case 22) — **E10·T02** owns the cadence;
  this task only makes `health` say which file to retry.
- The chrome hairline that renders `.writeFailed` — **E10·T01** wires `@Entry var storeHealth`.
