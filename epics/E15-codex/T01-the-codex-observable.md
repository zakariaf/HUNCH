# T01 — The `Codex` observable

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | `CodexPage` model (the read path) · Lazy loading and recovery |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | This task sits exactly on the boundary predicate's most-cited example: `08 §2`'s fourth row says `CodexPage` is core and `Codex` is **not**, because `@Observable` is a macro over a `@MainActor` class and would drag Observation into a target that must stay nonisolated. The skill also owns `N40` (`Codex`, never `CodexManager`, never `CodexStore`), the `A45`/`A42` ruling that this class re-implements change notification by hand, and the rule that nothing in `HunchCore` is a class. |
| `hunch-swift-concurrency` | Lazy per-shelf loading is `05 R30` verbatim — **cache the `Task`, not the value** — and the skill carries the one worked example of it (`LawIndexLoader`). It also owns the `05 R12` trap this class walks into on every write: `await store.save(…)` is not a critical section, so the resident index must be re-read after the suspension, not captured before it. |
| `hunch-swift-testing` | The one-file-per-open assertion is a *read-log* assertion, which needs a recording double rather than a value comparison; this skill owns where doubles live (`ModulesTestSupport`, absent from `products:`), the `.copy("Fixtures")` `subdirectory:` trap the 512 KB corpus test walks into, and the ten-second budget the synthesised corpus must not blow. |

`hunch-chrome-and-meta` is **not** loaded. This task draws nothing; T02 opens the drawing work.

## Objective

At the end of this task the archive is an object the app holds rather than a directory it reads: one
`@MainActor @Observable final class Codex` owns the resident `codex-index.json`, loads a shelf file
the first time that shelf is opened and never again, and is the only writer of either. Before this
task nothing can answer "have I found this law?" without parsing up to 3.8 MB; after it, that answer
is a set lookup on a 216 KB worst-case index that was the only Codex file touched at launch.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13 file table | `codex-index.json` — *"`[UInt64]` lawKeys + per-band counts · 27,015 × 8 B = 216 KB worst case. Loaded at launch; the dedup authority."* `codex-b1.json … codex-b8.json` — *"loaded **lazily**, only when a shelf opens. Worst case 27,015 × ~140 B ≈ 3.8 MB across all eight — never parsed at once."* |
| `GAME_DESIGN.md` | §11.13 *Failure states* | A shelf file that fails to decode is **quarantined to `corrupt/` and rebuilt empty**, and the index still holds the lawKeys, so page detail is lost but "already found" is not. `codex-index.json` that fails to decode is **rebuilt by scanning the eight shelf files**, ≈ 200 ms worst case, once |
| `GAME_DESIGN.md` | §11.13 preamble | Why there is no `state.v1.json`: *"a single monolith would have to parse the whole worst-case 3.8 MB Codex at every launch to read a 40-byte suspended round"* |
| `GAME_DESIGN.md` | §11.1 | `CodexPage`'s fields, and that the AST is stored and the table rebuilt on open |
| `GAME_DESIGN.md` | §11.3 | A duplicate is never a second page — the identity rule this class's index enforces at the earliest possible point |
| `GAME_DESIGN.md` | §3.6 | The 64-bit dedup hash **with a full compare on collision** — which is why an index hit is not on its own a decision |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2 (row 4), §4, §7.5, §7.6 | The boundary ruling for `Codex`; the `@MainActor` roster; *"the shard boundary … needs an assertion, not a comment: a test that opening a shelf parses exactly one shelf file, and that no single file exceeds 512 KB"*; and `A45`'s "record which side you are on in the README" |
| `ios-swift-guide/05-CONCURRENCY.md` | R30, R12, R17, R8 | Cache the `Task` not the value; `await` is not a critical section; where mutable state goes; explicit `@MainActor` on anything visible outside its file |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A40, A42, A45, A2 | Plain JSON above 1,000 records is legal *because* of the shard boundary; hand-rolled change notification is the bill; the composition root constructs this |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files, because the invariant has a core half and an app half.

Create `HunchCore/Tests/ArchiveTests/CodexIndexTests.swift`:

```swift
import Foundation
import Testing
import Archive
import LawGeneration          // Band
import HunchTestSupport       // Corpora

@Suite("codex-index.json — the dedup authority", .tags(.unit, .presubmission))
struct CodexIndexTests {

    @Test("an empty index holds nothing and counts zero in every band")
    func emptyIndex() {
        let index = CodexIndex()
        #expect(index.total == 0)
        for band in Band.allCases { #expect(index.count(band) == 0) }
        #expect(index.contains(0xDEAD_BEEF) == false)
    }

    @Test("inserting a lawKey makes it contained and moves exactly that band's count")
    func insertMovesOneCount() {
        var index = CodexIndex()
        index.insert(lawKey: 0x1234, band: .exclusive)
        #expect(index.contains(0x1234))
        #expect(index.count(.exclusive) == 1)
        #expect(index.total == 1)
        for band in Band.allCases where band != .exclusive { #expect(index.count(band) == 0) }
    }

    @Test("inserting the same lawKey twice is idempotent — §11.3, one law one page")
    func insertIsIdempotent() {
        var index = CodexIndex()
        index.insert(lawKey: 0x1234, band: .exclusive)
        index.insert(lawKey: 0x1234, band: .exclusive)
        #expect(index.count(.exclusive) == 1)
        #expect(index.total == 1)
    }

    @Test("the index round-trips through JSON with its counts intact")
    func roundTrip() throws {
        var index = CodexIndex()
        for band in Band.allCases {
            for i in 0..<3 { index.insert(lawKey: Corpora.lawKey(band: band, index: i), band: band) }
        }
        let data = try JSONEncoder().encode(index)
        let decoded = try JSONDecoder().decode(CodexIndex.self, from: data)
        #expect(decoded == index)
        #expect(decoded.total == 24)
    }

    @Test("rebuild-by-scan reproduces an index bit-for-bit from the eight shelves (§11.13)")
    func rebuildByScan() {
        var built = CodexIndex()
        var shelves: [Band: CodexShelf] = [:]
        for band in Band.allCases {
            let pages = (0..<5).map { Corpora.codexPage(band: band, index: $0) }
            shelves[band] = CodexShelf(band: band, pages: pages)
            for page in pages { built.insert(lawKey: page.lawKey, band: band) }
        }
        #expect(CodexIndex(scanning: Band.allCases.map { shelves[$0]! }) == built)
    }
}

@Suite("The shelf-file size budget — 08 §7.5", .tags(.unit, .presubmission))
struct ShelfSizeBudgetTests {

    /// The budget itself. Not a token: it is a persistence invariant and it lives beside the code
    /// that has to honour it.
    private static let budget = CodexShelf.byteBudget          // 512 * 1024

    @Test("the checked-in v1 fixture has no file over the budget")
    func fixtureIsInsideBudget() throws {
        let root = try FixtureTree.v1URL()                     // PersistenceTests' helper, E07·T05
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey]) {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            #expect(size <= Self.budget, "\(url.lastPathComponent) is \(size) B")
        }
    }

    @Test("the §11.4 completion corpus — all three sealable shelves full — stays inside the budget")
    func completionCorpusIsInsideBudget() throws {
        for band in Band.allCases where band.isSealable {
            let shelf = CodexShelf(band: band,
                                   pages: (0..<band.population).map { Corpora.codexPage(band: band, index: $0) })
            let bytes = try JSONEncoder().encode(shelf).count
            #expect(bytes <= Self.budget, "band \(band.rawValue) full shelf is \(bytes) B")
        }
    }

    /// The honest half. A full band-7 shelf is ~10,314 pages and cannot fit; this test *computes*
    /// where the budget is crossed and fails if the figure recorded in DECISIONS.md has moved,
    /// so the number is a measurement rather than an assumption.
    @Test("the crossover page count is measured and matches the recorded figure")
    func crossoverIsRecorded() throws {
        let band = Band.composite
        let perPage = try JSONEncoder().encode(
            CodexShelf(band: band, pages: (0..<256).map { Corpora.codexPage(band: band, index: $0) })
        ).count / 256
        let crossover = Self.budget / perPage
        #expect(crossover == CodexShelf.recordedCrossoverPages,
                "measured \(crossover) pages/shelf at \(perPage) B/page — update DECISIONS.md and the constant together")
        #expect(crossover < band.population,
                "if this ever passes, the sharding note in DECISIONS.md can be deleted")
    }
}
```

Create `Modules/Tests/CodexFeatureTests/ShelfLoadingTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import CodexFeature
import ModulesTestSupport        // RecordingPersistenceStore

@Suite("Lazy shelf loading — §11.13, 08 §7.5", .tags(.unit, .presubmission))
@MainActor
struct ShelfLoadingTests {

    private func makeCodex(_ seeded: [Band: [CodexPage]] = [:]) async -> (Codex, RecordingPersistenceStore) {
        let store = RecordingPersistenceStore()
        await store.seedCodex(seeded)
        let codex = Codex(store: store)
        await codex.load()
        store.resetLog()                                   // the launch reads are asserted separately
        return (codex, store)
    }

    @Test("launch parses codex-index.json and no shelf file at all")
    func launchParsesOnlyTheIndex() async {
        let store = RecordingPersistenceStore()
        await store.seedCodex([.literal: [Corpora.codexPage(band: .literal, index: 0)]])
        let codex = Codex(store: store)
        await codex.load()
        #expect(store.readLog == [.codexIndex])
    }

    @Test("opening a shelf parses exactly one shelf file")
    func openingOneShelfParsesOneFile() async {
        let (codex, store) = await makeCodex([.exclusive: [Corpora.codexPage(band: .exclusive, index: 0)]])
        _ = await codex.shelf(.exclusive)
        #expect(store.readLog == [.codexShelf(.exclusive)])
    }

    @Test("opening the same shelf twice parses nothing the second time")
    func secondOpenIsFree() async {
        let (codex, store) = await makeCodex([.exclusive: [Corpora.codexPage(band: .exclusive, index: 0)]])
        _ = await codex.shelf(.exclusive)
        store.resetLog()
        _ = await codex.shelf(.exclusive)
        #expect(store.readLog.isEmpty)
    }

    @Test("two concurrent opens of one shelf still parse one file — 05 R30, cache the Task")
    func concurrentOpensParseOnce() async {
        let (codex, store) = await makeCodex([.systemic: [Corpora.codexPage(band: .systemic, index: 0)]])
        async let a = codex.shelf(.systemic)
        async let b = codex.shelf(.systemic)
        let (left, right) = await (a, b)
        #expect(left.pages == right.pages)
        #expect(store.readLog == [.codexShelf(.systemic)])
    }

    @Test("opening a second shelf never re-reads the first")
    func crossBandOpenIsIsolated() async {
        let (codex, store) = await makeCodex([
            .literal: [Corpora.codexPage(band: .literal, index: 0)],
            .relational: [Corpora.codexPage(band: .relational, index: 0)],
        ])
        _ = await codex.shelf(.literal)
        store.resetLog()
        _ = await codex.shelf(.relational)
        #expect(store.readLog == [.codexShelf(.relational)])
    }

    @Test("`contains` answers from the resident index and reads no file")
    func dedupNeverTouchesDisk() async {
        let page = Corpora.codexPage(band: .guarded, index: 0)
        let (codex, store) = await makeCodex([.guarded: [page]])
        #expect(codex.contains(lawKey: page.lawKey))
        #expect(codex.contains(lawKey: page.lawKey &+ 1) == false)
        #expect(store.readLog.isEmpty)
    }

    @Test("a shelf that fails to decode quarantines and rebuilds empty; the index survives (§11.13)")
    func corruptShelfQuarantines() async {
        let page = Corpora.codexPage(band: .pair, index: 0)
        let store = RecordingPersistenceStore()
        await store.seedCodex([.pair: [page]])
        await store.corrupt(.codexShelf(.pair))
        let codex = Codex(store: store)
        await codex.load()

        let shelf = await codex.shelf(.pair)
        #expect(shelf.pages.isEmpty)
        #expect(codex.contains(lawKey: page.lawKey), "the index still knows it was found")
        #expect(codex.count(.pair) == 1)
        #expect(codex.health == .shelfQuarantined(.pair))
        #expect(await store.quarantined.contains(.codexShelf(.pair)))
    }

    @Test("a corrupt index is rebuilt by scanning the eight shelves, once (§11.13)")
    func corruptIndexRebuildsByScan() async {
        let seeded: [Band: [CodexPage]] = [
            .literal: [Corpora.codexPage(band: .literal, index: 0)],
            .systemic: (0..<3).map { Corpora.codexPage(band: .systemic, index: $0) },
        ]
        let store = RecordingPersistenceStore()
        await store.seedCodex(seeded)
        await store.corrupt(.codexIndex)

        let codex = Codex(store: store)
        await codex.load()

        #expect(codex.count(.literal) == 1)
        #expect(codex.count(.systemic) == 3)
        #expect(codex.health == .indexRebuilt)
        #expect(store.readLog.filter(\.isShelf).count == Band.allCases.count,
                "the scan reads each shelf once and only during recovery")
        #expect(await store.written.contains(.codexIndex), "the rebuilt index is written back")
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter "CodexIndexTests|ShelfSizeBudgetTests"` and
`swift test --package-path Modules --filter ShelfLoadingTests`

Expect missing `CodexIndex`, `CodexShelf.byteBudget`, `Band.isSealable`, `Codex`, `CodexHealth`,
`RecordingPersistenceStore`. **A `CodexIndexTests` that passes before `CodexIndex` exists means you
wrote it against a type that was already there — check the target list first.** If `CodexShelf`
already exists from E09·T11, extend it rather than declaring a second one.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/CodexIndex.swift` — `CodexIndex`, `init(scanning:)` |
| create | `HunchCore/Sources/Archive/CodexShelf.swift` — **if E09·T11 did not ship it**; add `byteBudget`, `recordedCrossoverPages` |
| modify | `HunchCore/Sources/LawGeneration/Band.swift` — `isSealable` (`population <= 512`), used here and by T07 |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `lawKey(band:index:)`, extend `codexPage(band:index:)` |
| create | `HunchCore/Tests/ArchiveTests/CodexIndexTests.swift` |
| create | `HunchCore/Tests/ArchiveTests/ShelfSizeBudgetTests.swift` |
| create | `Modules/Sources/CodexFeature/Codex.swift` — `Codex`, `CodexHealth` |
| create | `Modules/Sources/ModulesTestSupport/RecordingPersistenceStore.swift` — **or move E09·T11's copy here** |
| modify | `Modules/Package.swift` — the `CodexFeature` target (`.defaultIsolation(MainActor.self)`, depends on `HunchCore`), `CodexFeatureTests`, and `ModulesTestSupport` if absent |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — the `codex: Codex` field E10·T01 left out, constructed in `live()` and `preview(seed:date:)` |
| modify | `Modules/Sources/LoomFeature/RoundCommit.swift` — the t = 0 page write goes through `codex.inscribe(_:)`, not straight to the store |
| create | `Modules/Tests/CodexFeatureTests/ShelfLoadingTests.swift` |
| modify | `README.md` — the `04 A45` note: no SwiftData, plain JSON shards, hand-rolled notification |
| modify | `tests.json` · `DECISIONS.md` — see *Acceptance criteria* |

## Implementation notes

### The shape

```swift
// Modules/Sources/CodexFeature/Codex.swift
import HunchCore
import Observation

public enum CodexHealth: Equatable, Sendable {
    case healthy
    case indexRebuilt                    // §11.13: codex-index.json failed to decode, rebuilt by scan
    case shelfQuarantined(Band)          // §11.13: one shelf moved to corrupt/ and rebuilt empty
}

@MainActor
@Observable
public final class Codex {
    /// The dedup authority. Resident from launch; 216 KB worst case (§11.13).
    public private(set) var index = CodexIndex()
    public private(set) var health: CodexHealth = .healthy

    /// Loaded shelves. A shelf is here iff it has been opened this session.
    private var shelves: [Band: CodexShelf] = [:]
    /// In-flight loads. `05 R30`: cache the Task, not the value, so two openings parse one file.
    private var loads: [Band: Task<CodexShelf, Never>] = [:]
    private let store: any PersistenceStore

    public init(store: any PersistenceStore) { self.store = store }

    public var pageCount: Int { index.total }
    public func count(_ band: Band) -> Int { index.count(band) }
    public func contains(lawKey: UInt64) -> Bool { index.contains(lawKey) }

    /// Launch. Parses `codex-index.json` and nothing else.
    public func load() async { … }

    /// Opens one shelf. Parses exactly one file, the first time, and never again.
    public func shelf(_ band: Band) async -> CodexShelf { … }

    /// The synchronous read a `body` uses; `nil` means "not loaded yet, kick off `shelf(_:)`".
    public func loadedShelf(_ band: Band) -> CodexShelf? { shelves[band] }
}
```

### Why `Codex` is not in `HunchCore`, stated once so it is not re-litigated

`08 §2`'s table is the ruling: `@Observable` expands to a `@MainActor` class conforming to
`Observable`, which requires `import Observation` and main-actor isolation in whatever target holds
it. `HunchCore` has **no default isolation and no classes at all** (`08 §4`), and the whole value of
that is that `swift test --package-path HunchCore` needs no simulator. `CodexPage`, `CodexShelf` and
`CodexIndex` are values and are core; `Codex` is the app's view of them and is `CodexFeature`. The
practical consequence, and the reason the tests above are split across two packages: everything about
*identity and size* is provable on the host in microseconds, and only *loading* needs the observable.

### `05 R30`, and the one line that makes it work

```swift
public func shelf(_ band: Band) async -> CodexShelf {
    if let shelf = shelves[band] { return shelf }
    if let load = loads[band] { return await load.value }

    let task = Task { [store] in await Self.loadShelf(band, from: store) }
    loads[band] = task                       // synchronous — lands before the first suspension
    let shelf = await task.value
    shelves[band] = shelf
    loads[band] = nil
    return shelf
}
```

`loads[band] = task` **must** be written before the first `await`, exactly as `LawIndexLoader` does
it (`08 §4`). If it is written after, two concurrent opens each start a task and the
`concurrentOpensParseOnce` test fails with a read log of two — which is the whole invariant.

`Self.loadShelf` is `static` and takes the store so the closure captures no `self` and the compiler
does not have to prove main-actor re-entry. It never throws: a decode failure is a *state*
(`quarantined`), not an error the caller can do anything about.

### Quarantine and rebuild, per §11.13's failure table

```swift
private static func loadShelf(_ band: Band, from store: any PersistenceStore) async -> CodexShelf {
    do { return try await store.load(CodexShelf.self, from: .codexShelf(band)) }
    catch {
        try? await store.quarantine(.codexShelf(band))     // → corrupt/, E07·T02's seam
        let empty = CodexShelf(band: band, pages: [])
        try? await store.save(empty, to: .codexShelf(band))
        return empty
    }
}
```

Two facts the test pins and the code must not blur:

1. **The index survives a quarantined shelf.** §11.13: *"`codex-index.json` still holds the lawKeys,
   so page detail is lost but 'already found' is not — the shelf meter and dedup survive."* So
   `count(band)` keeps its old value while `shelf(band).pages` is empty, and T02's plate is allowed
   to disagree with T04's grid **for that band only**. Do not "fix" it by zeroing the count; that
   would re-offer a law the player already solved.
2. **The rebuild reads all eight shelves and writes the index back.** It is the one moment the class
   parses more than one shelf file, it happens only in recovery, and §11.13 budgets it at ≈ 200 ms
   once. Guard it behind the decode failure and nothing else — a rebuild on every launch is the
   monolith §11.13 exists to avoid, wearing a different hat.

### `Codex` is the single writer — the `A42` bill, paid here

`04 A45` says record which side of the SwiftData decision you are on; `08 §7.6` says the bill for
being on the plain-JSON side is that **change notification is hand-rolled**. Concretely:

- **Every write to `codex-index.json` or `codex-b*.json` goes through `Codex`.** E09·T11's
  `RoundCommit` currently calls `store.save(page, to: .codexShelf(band))`; re-point it at
  `codex.inscribe(_:)` in this task. If a second writer exists, the resident index goes stale and the
  gate's item 6 (counts agree) fails on the *next* launch rather than in the test.
- **The observable surface is `index` and `health`.** Both are stored properties on an `@Observable`
  class, so SwiftUI's dependency tracking is automatic; what is hand-rolled is the *funnelling*, not
  the notification mechanism. Say so in the README note — `A45` asks for the ruling, not an essay.
- **`05 R12`.** `inscribe` will `await store.save(…)`. Anything read from `index` before that
  suspension is stale after it. Read the index, decide, `await`, then mutate the index from the
  post-suspension value. T06 has the full write path; this task only establishes the ownership.

### The lawKey collision policy

§11.1 keys a page on a 64-bit hash of the extension; §3.6 requires *"a full compare on collision"*.
Those two are reconciled here, once, and recorded in `DECISIONS.md`:

> An index **miss** is decisive: the law has never been found, mint. An index **hit** is not: load
> that band's shelf (one file, a round-boundary event, already the common case since a find lands on
> the band being played) and compare the candidate's `renderedNormalForm` against the stored page's.
> Equal ⇒ re-inscribe. Unequal ⇒ a genuine 64-bit collision; mint a second page and record it, since
> at 27,015 laws the birthday probability is ≈ 2 × 10⁻¹¹ and a wrong merge would silently destroy a
> page.

`CodexShelf` therefore needs `page(lawKey:) -> CodexPage?`, which T06 uses.

### The 512 KB budget, honestly

`08 §7.5` demands the assertion; §11.13's own arithmetic makes it unprovable as a theorem — a full
band-7 shelf is 10,314 pages at ~140 B and is ~1.4 MB. The resolution is the third test above:
measure bytes per page from a 256-page sample, compute the crossover, and assert it against a
constant that is also written into `DECISIONS.md`. Then record what happens if a real player ever
reaches it:

> A shelf crossing `CodexShelf.byteBudget` is a **schema-v2 sharding event**, not a crash: the shelf
> splits into `codex-b7-0.json`, `codex-b7-1.json` … behind `StoreFile.codexShelf(Band)`'s existing
> case, and `migrate_v1_to_v2(directory:)` performs it. It is not built now because the crossover is
> ~N pages against a §11.4 completion figure of 485 and a 1,375-hour band-7 shelf. `StoreHealth`
> surfaces the approach through the same hairline the disk-full path uses (§11.13).

Do not lower the budget to make the test pass, and do not raise it to cover band 7 — the number comes
from `08 §7.5` and it is what keeps `04 A40`'s ruling true.

### `RecordingPersistenceStore`

An `actor` conforming to `PersistenceStore`, in `ModulesTestSupport` so both `LoomFeatureTests`
(E09·T11) and `CodexFeatureTests` use one copy. `06 T5a`: the target is a `.target` absent from
`products:`, exactly like `HunchTestSupport`, and it imports no `Testing`.

```swift
public actor RecordingPersistenceStore: PersistenceStore {
    public private(set) var readLog: [StoreFile] = []
    public private(set) var written: Set<StoreFile> = []
    public private(set) var quarantined: Set<StoreFile> = []
    private var blobs: [StoreFile: Data] = [:]
    private var corrupted: Set<StoreFile> = []

    public func seedCodex(_ shelves: [Band: [CodexPage]]) { … }   // writes the eight shelves + index
    public func corrupt(_ file: StoreFile) { corrupted.insert(file) }   // decode throws on next load
    public func resetLog() { readLog.removeAll() }
}
```

`readLog` is an **ordered** array, not a set: the gate asserts a *sequence*, because "one file" and
"one file, then that file again" are different bugs. `StoreFile` needs `Hashable` — it is already, per
E07·T01's enum.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter "CodexIndexTests|ShelfSizeBudgetTests"` green.
- [ ] `swift test --package-path Modules --filter ShelfLoadingTests` green, all eight tests.
- [ ] `grep -rn "final class\|import Observation\|import SwiftUI" HunchCore/Sources/Archive/` returns nothing.
- [ ] `grep -rn "codexShelf(\|\.codexIndex" Modules/Sources --include=*.swift | grep -v "CodexFeature/Codex.swift"` shows **no** `save(` call site — `Codex` is the single writer.
- [ ] `.claude/skills/hunch-swift-concurrency`'s state block reports the actor budget still at two (`FilePersistenceStore`, `LawIndexLoader`) — `Codex` is a `@MainActor` class, not a third actor.
- [ ] `DECISIONS.md` carries three entries: `Codex` as single writer plus the `A45` side; the 512 KB crossover with its measured page count and the schema-v2 sharding trigger; the lawKey-collision policy.
- [ ] `README.md` carries the `04 A45` note.
- [ ] `tests.json` carries: one-file-per-shelf-open, second-open-is-free, concurrent-open-parses-once, shelf quarantine keeps the index, index rebuild-by-scan, and the 512 KB budget with its crossover.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T01: the Codex observable, the resident index, lazy shelves and the 512 KB budget"`

## Out of scope

- **Taxonomy, ordering and every drawing.** T02 onward. This task exposes `shelf(_:)` and nothing that renders it.
- **`Codex.inscribe(_:)`'s mutation semantics** — improving the bests, the re-strike ring, fracture healing, burnish. **T06**. This task establishes only that `Codex` is where the write lands.
- **`CodexPage.init(minting:)` and `reinscribe(…)`** — **E09·T11**, in core. If they are missing, add them there, not here.
- **`PersistenceStore`, `StoreFile`, atomic writes, the quarantine directory and migration** — **E07·T01/T02/T04**. `store.quarantine(_:)` is E07's seam; if it does not exist, add it in `Persistence/`.
- **The `Fixtures/v1/` tree and its scoping trait** — **E07·T05**. This task reuses `FixtureTree.v1URL()`.
- **`Ladder` on `AppDependencies`** — **E11·T01**.
- **The Codex's place in the route graph and the play key's destination** — **E17·T01/T02**.
