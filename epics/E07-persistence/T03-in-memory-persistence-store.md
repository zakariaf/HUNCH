# T03 — `InMemoryPersistenceStore`

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | §14.1 PERSISTENCE → **`PersistenceStore`** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns the rule this task exists to satisfy: `InMemoryPersistenceStore` **ships** in `HunchCore/Sources/Persistence/` and imports no `Testing`, so `import Testing` can never reach the release binary (`06 T5`/`T5a`, `01 P20`), and it is what `AppDependencies.preview(seed:date:)` composes with `Now.fixed`, `SeedSource.fixed` and `SilentCuePlayer` |
| `hunch-swift-testing` | Owns the shape of the parity suite: hand-written fakes, no mocking framework, assert on resulting *state* rather than recorded calls, and the `unimplemented` double that belongs in `HunchTestSupport` and not here |

## Objective

A second, complete `PersistenceStore` exists that keeps files in memory, ships in the app, and
imports nothing from `Testing`. With it comes one parity suite — the behavioural contract both
stores must satisfy — so a divergence between the store a preview uses and the store a device uses
becomes a test failure instead of a bug report.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13 | The behaviours being mirrored: missing-file failure, quarantine, the commit order, the snapshot cleared last |
| `ios-swift-guide/06-TESTING.md` | T5, T5a, T36, T38, T39 | Never `import Testing` from a shipping target; hand-write the fake; the `unimplemented` double lives elsewhere |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §6 (bullet "Previews get the real types, not fakes"), §1 (file path) | Why this type ships rather than living in a test target |
| `ios-swift-guide/05-CONCURRENCY.md` | R17, R18 | Why this is an actor and not a `struct` with a `Mutex` — and why that is a *third* actor against a stated budget of two |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W44 | The seam is published, so both sides of it are real types |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/PersistenceTests/PersistenceStoreContractTests.swift`. This is the parity suite:
every case runs twice, once per store, and a store that behaves differently fails by name.

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence

/// Which store a contract case is running against. `Codable` so a single failing case can be
/// re-run from the test navigator (`06 T23`).
enum StoreUnderTest: String, CaseIterable, Codable, Sendable {
    case file, inMemory

    func make() throws -> any PersistenceStore {
        switch self {
        case .inMemory:
            InMemoryPersistenceStore()
        case .file:
            FilePersistenceStore(
                directory: try FileManager.default.url(for: .itemReplacementDirectory,
                                                       in: .userDomainMask,
                                                       appropriateFor: URL.temporaryDirectory,
                                                       create: true)
                    .appending(path: "Hunch"))
        }
    }
}

@Suite("Both stores satisfy the same contract", .tags(.unit, .presubmission))
struct PersistenceStoreContractTests {

    @Test("A fresh store is empty and healthy", arguments: StoreUnderTest.allCases)
    func aFreshStoreIsEmpty(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        #expect(try await store.present.isEmpty)
        #expect(await store.health == .healthy)
    }

    @Test("save then load is identity, for a representative file of every payload kind",
          arguments: StoreUnderTest.allCases)
    func saveThenLoadIsIdentity(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        let cases: [StoreFile: Data] = [
            .manifest: Data("{\"schema\":1}".utf8),
            .codexShelf(.literal): Data("[]".utf8),
            .anomalyHighWater: Data(repeating: 0x7F, count: 16),   // the 16-byte sidecar
            .round(.probe): Data("{\"v\":1}".utf8),
            .lawIndex: Data(repeating: 0xAB, count: 1024),         // binary, not JSON
        ]
        for (file, payload) in cases { try await store.save(payload, to: file) }
        for (file, payload) in cases {
            #expect(try await store.load(file) == payload, "\(kind) lost \(file)")
        }
        #expect(try await store.present == Set(cases.keys))
    }

    @Test("Loading an absent file throws .missing with the file named",
          arguments: StoreUnderTest.allCases)
    func absentFileThrowsMissing(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        await #expect(throws: StoreError.missing(.profile)) { try await store.load(.profile) }
    }

    @Test("Saving twice replaces rather than appends", arguments: StoreUnderTest.allCases)
    func savingTwiceReplaces(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        try await store.save(Data("first".utf8), to: .ladder)
        try await store.save(Data("second".utf8), to: .ladder)
        #expect(try await store.load(.ladder) == Data("second".utf8))
    }

    @Test("remove is idempotent and never throws on an absent file",
          arguments: StoreUnderTest.allCases)
    func removeIsIdempotent(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        try await store.save(Data("x".utf8), to: .statistics)
        try await store.remove(.statistics)
        try await store.remove(.statistics)
        #expect(try await store.present.isEmpty)
    }

    @Test("quarantine removes the file from present and reports it in health",
          arguments: StoreUnderTest.allCases)
    func quarantineIsVisibleInHealth(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        try await store.save(Data("{ truncated".utf8), to: .codexShelf(.relational))
        try await store.quarantine(.codexShelf(.relational))
        #expect(!(try await store.present.contains(.codexShelf(.relational))))
        #expect(await store.health == .quarantined(.codexShelf(.relational)))
    }

    @Test("commit writes everything and clears the round slot last",
          arguments: StoreUnderTest.allCases)
    func commitClearsTheRoundSlot(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        try await store.save(Data("snapshot".utf8), to: .round(.drift))
        try await store.commit([.profile: Data("{}".utf8), .statistics: Data("{}".utf8)],
                               clearingRoundFor: .drift)
        let present = try await store.present
        #expect(present == [.profile, .statistics])
    }

    @Test("commit with no mode leaves the round slot alone — a suspend is not a round end",
          arguments: StoreUnderTest.allCases)
    func commitWithoutAModeKeepsTheSnapshot(_ kind: StoreUnderTest) async throws {
        let store = try kind.make()
        try await store.save(Data("snapshot".utf8), to: .round(.probe))
        try await store.commit([.profile: Data("{}".utf8)], clearingRoundFor: nil)
        #expect(try await store.present.contains(.round(.probe)))
    }

    @Test("A seeded store starts with exactly what it was seeded with")
    func seedingIsExact() async throws {
        let store = InMemoryPersistenceStore([.manifest: Data("{\"schema\":1}".utf8)])
        #expect(try await store.present == [.manifest])
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter PersistenceStoreContractTests`
Every case must fail with `cannot find 'InMemoryPersistenceStore' in scope`. The `.file` half of each
parameterised case should already pass once it compiles — if a `.file` case fails, T02 has a bug and
you have just found it, which is the parity suite doing its job on day one.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** Move any behaviour the two stores now duplicate into a
`PersistenceStore` extension — `commit`'s ordering loop is the obvious candidate and it belongs
there, since ordering is a property of the seam and not of either implementation.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Persistence/InMemoryPersistenceStore.swift` |
| create | `HunchCore/Tests/PersistenceTests/PersistenceStoreContractTests.swift` |
| modify | `HunchCore/Sources/Persistence/PersistenceStore.swift` — add the default `commit(_:clearingRoundFor:)` in a protocol extension, in terms of `save`/`remove` |
| modify | `HunchCore/Sources/HunchTestSupport/Unimplemented.swift` — bring `UnimplementedPersistenceStore` up to the current member list |
| modify | `DECISIONS.md` — the third actor |

## Implementation notes

### The type

```swift
/// Ships. Imports no `Testing` — that is what keeps `import Testing` out of the release binary
/// (`06 T5`, `T5a`). `AppDependencies.preview(seed:date:)` composes it with `Now.fixed`,
/// `SeedSource.fixed` and `SilentCuePlayer` into a deterministic graph (E10·T01).
public actor InMemoryPersistenceStore: PersistenceStore {
    private var files: [StoreFile: Data]
    private var quarantined: [StoreFile: Data] = [:]
    private var currentHealth: StoreHealth = .healthy

    public init(_ seed: [StoreFile: Data] = [:]) { files = seed }

    public var present: Set<StoreFile> { Set(files.keys) }
    public var health: StoreHealth { currentHealth }

    public func load(_ file: StoreFile) throws -> Data {
        guard let data = files[file] else { throw StoreError.missing(file) }
        return data
    }

    public func save(_ data: Data, to file: StoreFile) { files[file] = data }
    public func remove(_ file: StoreFile) { files[file] = nil }

    public func quarantine(_ file: StoreFile) {
        quarantined[file] = files.removeValue(forKey: file)   // moved, mirroring corrupt/
        currentHealth = .quarantined(file)
    }
}
```

`present` and `health` are non-`throws` here and `throws` on the protocol; a conformance may narrow
`throws`, so this compiles and is the right shape — the file store can fail to list a directory, the
memory store cannot.

`quarantined` is not merely symmetry: T05's quarantine test asserts the bytes survive, and a store
that silently dropped them would pass a weaker test and fail a real diagnosis.

### The default `commit`

Both stores must sequence identically, so the sequencing lives on the seam exactly once:

```swift
extension PersistenceStore {
    /// §11.13's write order, implemented once for every conformer: `round-{mode}.json` first,
    /// everything else after, and the snapshot slot cleared **last**, only when every other write
    /// has succeeded. A conformer overrides this only to add durability (T02 does, for `fsync`).
    public func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) async throws {
        for file in StoreFile.orderedForWrite(writes.keys) {
            try await save(writes[file]!, to: file)
        }
        if let mode { try await remove(.round(mode)) }
    }
}
```

If T02 already wrote its own `commit`, keep it — an actor-local synchronous loop is stronger than a
sequence of `await`s across the actor boundary (`05 R12`) — and let the extension serve
`InMemoryPersistenceStore` and any future conformer. Say so in a comment at both sites, or the next
reader will delete one of them.

### The third actor, and why it is not a budget violation

`hunch-swift-concurrency` states a hard budget of **exactly two** actors and asks for a
`DECISIONS.md` entry before a third. Write the entry, with this reasoning:

> `InMemoryPersistenceStore` is not a third *seam*; it is the second implementation of the first
> one. `PersistenceStore` has `async` members because `FilePersistenceStore` needs them, so any
> conformer must isolate its own mutable state; `05 R17` row 3 (`Mutex`) is explicitly empty in this
> project, and a `struct` with a `[StoreFile: Data]` cannot conform to a protocol whose contract is
> mutation. The alternative — making the protocol's members non-`mutating` and non-`async` — would
> put file I/O on the caller's actor, which is the thing row 4 exists to prevent. Budget therefore
> reads **two seams, three actor instances**, and the grep in the skill's step 0 is updated to
> expect `FilePersistenceStore`, `InMemoryPersistenceStore`, `LawIndexLoader`.

Do not skip the entry. The skill's opening script prints the actor list on every future invocation
and an unexplained third actor will be read as a regression by whoever reads it next.

### `UnimplementedPersistenceStore`

E01·T04 shipped it against a smaller protocol. Regenerate its member list from
`PersistenceStore.swift` — not from memory, and not from the skill reference, which predates
`commit` and `quarantine`. It lives in `HunchTestSupport`, which is absent from `products:`, so it is
the one persistence type that *may* `import Testing`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter PersistenceStoreContractTests` green — 17 cases
      (8 parameterised × 2 stores + the seeding case).
- [ ] `grep -n 'import Testing' HunchCore/Sources/Persistence/*.swift` returns nothing.
- [ ] `swift package describe --package-path HunchCore --type json | grep -A3 '"name" : "Persistence"'`
      shows no dependency on `HunchTestSupport`.
- [ ] `InMemoryPersistenceStore` is `public` with a `public init` — construct one from a scratch file
      in `Modules/` to prove the memberwise-init trap (`04 A29`) is not waiting for E10.
- [ ] `DECISIONS.md` carries the third-actor entry.
- [ ] Deleting one member from `PersistenceStore` breaks both conformers and
      `UnimplementedPersistenceStore`. Try it, read the three errors, revert.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — re-run the tests after it. The likely finding is duplicated `commit` logic;
   accept the extension, keep T02's override, and comment both.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T03: InMemoryPersistenceStore and the store contract suite"`

## Out of scope

- `AppDependencies.preview(seed:date:)` itself — **E10·T01**. This task only makes the type it will
  compose exist and be `public`.
- `SilentCuePlayer` — **E08·T06** defines the `Cue` seam, **E20·T01** ships the players.
- Any fixture tree or file on disk — **T05**.
- A `SpyCuePlayer`, or any spy at all. The only seam where the call *is* the observable behaviour is
  `CuePlayer`, and that is not this epic.
