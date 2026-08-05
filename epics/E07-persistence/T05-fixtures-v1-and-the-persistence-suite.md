# T05 — `Fixtures/v1/` and the persistence suite

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | §14.1 VERIFICATION → **Persistence tests**; §14.1 PERSISTENCE → **Lazy loading and recovery** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | Owns brief invariant 6 end to end: the `.copy("Fixtures")` trap that kills fixture suites, the `#bundle`-in-a-support-target trap that looks identical and is a different bug, the `TestScoping` trait that replaces `deinit`, and `06 T55`'s malformed sibling with a *specific typed error* |
| `hunch-swift-code` | Owns `04 A46`'s "opening a store can fail on data you do not control, so `try!` is not available to you", and `08 §7.5`'s shard ruling — the 512 KB assertion is what keeps `A40`'s JSON verdict true |

## Objective

A whole `Application Support/Hunch/` tree from schema v1 is checked in, copied into a fresh temporary
directory for each test by a scoping trait, and asserted to load green under the current schema —
forever. Around it sits the suite that closes the brief's sixth invariant: save → kill → relaunch is
identity for every `StoreFile` case, a truncated `codex-b4.json` quarantines and rebuilds rather than
crashing, and no single file in the store exceeds 512 KB.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13, *Migration* + *Failure states* | "A checked-in `Fixtures/v1/` tree must load green under every future build — this is the brief's persistence-migration test and it never gets regenerated to make a build pass"; the per-file failure behaviours; the disk-full row |
| `GAME_DESIGN.md` | §11.13 file table | Every file's stated size ceiling: `codex-index.json` 216 KB worst case, `anomaly.json` ~16 KB, `profile.json` < 1 KB, `ladder.json` < 2 KB, `stats.json` < 40 KB |
| `GAME_DESIGN.md` | §11.4 | The 27,015 ceiling and the per-band populations the shelf sizes derive from |
| `ios-swift-guide/06-TESTING.md` | T20, T54, T55, T56, T19 | `TestScoping` over `deinit`; `.copy` preserves the directory so every lookup passes `subdirectory:`; malformed sibling; a fixture must have been produced by a shipped binary |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B22 | `#bundle`, never `Bundle.module` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 (*Persistence and migration*), §7.5 | The three assertions verbatim, and the shard boundary that needs an assertion rather than a comment |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files. First the trait and the accessor
(`HunchCore/Sources/HunchTestSupport/StoreSandbox.swift`) — it is test *support*, so it is written
first and is itself covered by the suite that uses it:

```swift
import Foundation
import Testing

/// A fresh copy of a checked-in fixture tree, per test, removed after. `06 T20`: scoped setup and
/// teardown is a `TestScoping` trait, never a `deinit`.
public struct StoreSandbox: TestTrait, SuiteTrait, TestScoping {
    /// The version directory inside `Fixtures/` to copy — `"v1"` today, `"v2"` when there is one.
    public let version: String
    /// The bundle holding the resources. `#bundle` expands to the *enclosing target's* bundle and
    /// the resources are declared on the test target, so this type cannot say `#bundle` itself.
    public let bundle: Bundle

    /// The live copy, for the duration of one test.
    @TaskLocal public static var root: URL = URL(filePath: "/dev/null")

    public func provideScope(for test: Test,
                             testCase: Test.Case?,
                             performing function: () async throws -> Void) async throws {
        // No `UUID()`: check 6's grep covers HunchCore/Sources/ and this file lives under it.
        let container = try FileManager.default.url(for: .itemReplacementDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: URL.temporaryDirectory,
                                                    create: true)
        let destination = container.appending(path: "Hunch")
        let source = try #require(
            bundle.url(forResource: version, withExtension: nil, subdirectory: "Fixtures"),
            "No Fixtures/\(version)/ in \(bundle.bundleURL.lastPathComponent) — is the test target's "
            + "resources: [.copy(\"Fixtures\")] missing, or did a lookup drop `subdirectory:`?")
        try FileManager.default.copyItem(at: source, to: destination)

        defer { try? FileManager.default.removeItem(at: container) }
        try await StoreSandbox.$root.withValue(destination) { try await function() }
    }
}

extension Trait where Self == StoreSandbox {
    public static func storeSandbox(_ version: String = "v1", in bundle: Bundle) -> Self {
        StoreSandbox(version: version, bundle: bundle)
    }
}
```

Then `HunchCore/Tests/PersistenceTests/FixtureV1Tests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence
import HunchTestSupport

@Suite("The v1 fixture tree", .tags(.unit, .presubmission))
struct FixtureV1Tests {

    @Test("Every file in the shipped v1 tree declares schema 1", .storeSandbox(in: #bundle))
    func everyFileDeclaresSchemaOne() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        let present = try await store.present
        #expect(present.contains(.manifest))

        let versioned = present.filter { $0.fileName.hasSuffix(".json") }
        let offenders = try versioned.compactMap { file -> String? in
            let version = try SchemaEnvelope(await store.load(file)).version
            return version == Schema.current ? nil : "\(file.fileName) declares v\(version)"
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("v1 loads green under the current schema — migration is a no-op and changes nothing",
          .storeSandbox(in: #bundle))
    func v1LoadsGreen() throws {
        let before = try StoreTree.bytes(of: StoreSandbox.root)
        let outcome = try SchemaMigration.migrate(directory: StoreSandbox.root,
                                                  at: Date(timeIntervalSinceReferenceDate: 0))
        #expect(outcome == .upToDate)
        #expect(try StoreTree.bytes(of: StoreSandbox.root) == before)
    }

    @Test("The derived index is absent from the fixture and that is not an error",
          .storeSandbox(in: #bundle))
    func theDerivedIndexIsRegenerable() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        #expect(!(try await store.present.contains(.lawIndex)))
        #expect(StoreFile.lawIndex.recovery == .regenerate)
        #expect(await store.health == .healthy)
    }

    @Test("No single file in the store exceeds the 512 KB shard budget",
          .storeSandbox(in: #bundle))
    func noFileExceedsTheShardBudget() throws {
        let sizes = try StoreTree.bytes(of: StoreSandbox.root).mapValues(\.count)
        let budget = 512 * 1024
        let offenders = sizes.filter { $0.value > budget }
            .map { "\($0.key) is \($0.value) B" }
            .sorted()
        #expect(offenders.isEmpty, "\(offenders) — §11.13 shards so that A40's JSON ruling holds")
    }
}
```

And `HunchCore/Tests/PersistenceTests/StoreRoundTripTests.swift` — the brief's headline:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence
import HunchTestSupport

@Suite("Save, kill, relaunch", .tags(.unit, .presubmission))
struct StoreRoundTripTests {

    /// One representative payload per `StoreFile` case, so "every case" is enumerated by the
    /// compiler rather than by a list someone has to remember to extend.
    private static func payload(for file: StoreFile) -> Data {
        switch file {
        case .anomalyHighWater: Data(repeating: 0x5A, count: 16)          // §11.13: 16-byte sidecar
        case .lawIndex:         Data(repeating: 0xC3, count: 4096)        // binary, not JSON
        default:                Data(#"{"v":1,"payload":"\#(file.fileName)"}"#.utf8)
        }
    }

    @Test("Every StoreFile case survives the process it was written by",
          arguments: StoreFile.allCases)
    func everyCaseRoundTrips(_ file: StoreFile) async throws {
        let directory = try StoreTree.makeEmptyDirectory()
        let payload = Self.payload(for: file)

        // launch 1 — write, then drop every reference to the actor
        do {
            let store = FilePersistenceStore(directory: directory)
            try await store.save(payload, to: file)
        }
        // launch 2 — a second actor over the same bytes on disk
        let relaunched = FilePersistenceStore(directory: directory)
        #expect(try await relaunched.load(file) == payload)
        #expect(try await relaunched.present == [file])
    }

    @Test("A whole tree written in one commit reloads identically after a relaunch")
    func aWholeTreeRoundTrips() async throws {
        let directory = try StoreTree.makeEmptyDirectory()
        let writes = Dictionary(uniqueKeysWithValues:
            StoreFile.allCases.map { ($0, Self.payload(for: $0)) })

        do {
            let store = FilePersistenceStore(directory: directory)
            try await store.commit(writes, clearingRoundFor: nil)
        }
        let relaunched = FilePersistenceStore(directory: directory)
        for file in StoreFile.allCases {
            #expect(try await relaunched.load(file) == writes[file], "\(file) changed across launch")
        }
    }

    // §11.13's failure table, the row that matters most: page detail is lost, "already found" is not.
    @Test("A truncated shelf quarantines and rebuilds rather than throwing to the caller",
          .storeSandbox(in: #bundle))
    func truncatedShelfQuarantines() async throws {
        let store = FilePersistenceStore(directory: StoreSandbox.root)
        let truncated = try Fixture.data("codex-b4.truncated", in: #bundle)
        try await store.save(truncated, to: .codexShelf(.relational))

        // The caller decodes and fails — only the caller can know a payload is malformed.
        #expect(throws: (any DecodingError).self) {
            try JSONDecoder.store.decode([CodexPage].self, from: truncated)
        }
        try await store.quarantine(.codexShelf(.relational))
        try await store.save(Data("[]".utf8), to: .codexShelf(.relational))   // rebuilt empty

        #expect(await store.health == .quarantined(.codexShelf(.relational)))
        #expect(try await store.load(.codexShelf(.relational)) == Data("[]".utf8))
        #expect(try await store.present.contains(.codexIndex))     // dedup authority survives
        #expect(try Data(contentsOf: StoreSandbox.root.appending(path: "corrupt")
            .appending(path: "codex-b4.json")) == truncated)
    }

    @Test("A malformed sibling exists for every JSON file kind the tree holds",
          .storeSandbox(in: #bundle))
    func everyJSONFileHasAMalformedSibling() throws {
        let malformed = try FileManager.default.contentsOfDirectory(
            atPath: StoreSandbox.root.deletingLastPathComponent().path())
        #expect(!malformed.isEmpty)   // replaced by the real assertion once the tree lands; see notes
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter FixtureV1Tests`
The first failure will be the `#require` inside the trait — *"No Fixtures/v1/ …"* — because the tree
does not exist yet. **That is the right failure**, and it is the exact message the `.copy`/
`subdirectory:` trap produces, so read it once now and you will recognise it in two years.

**Step 3 — implement**: mint the tree, declare the resource, then make the assertions pass.

**Step 4 — green, then refactor.** Fold anything the three suites share into `StoreTree` in
`HunchTestSupport`; T06 depends on this task and will use it immediately.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Tests/PersistenceTests/Fixtures/v1/` — the tree, see below |
| create | `HunchCore/Tests/PersistenceTests/Fixtures/codex-b4.truncated.json` |
| create | `HunchCore/Sources/HunchTestSupport/StoreSandbox.swift` |
| create | `HunchCore/Sources/HunchTestSupport/Fixture.swift` — the bundle-taking accessor, if E01·T04 did not ship one |
| create | `HunchCore/Tests/PersistenceTests/FixtureV1Tests.swift` |
| create | `HunchCore/Tests/PersistenceTests/StoreRoundTripTests.swift` |
| create | `HunchCore/Sources/hunch-fixtures/StoreFixtureMint.swift` — the `swift run` minting tool (or a subcommand of E06·T10's existing tool) |
| modify | `HunchCore/Package.swift` — `resources: [.copy("Fixtures")]` on `PersistenceTests`; the `hunch-fixtures` executable target, absent from `products:` |
| modify | `tests.json` — entries for the round-trip, the v1 load, the quarantine and the 512 KB budget |
| modify | `DECISIONS.md` — the 512 KB budget versus a full band-7 shelf |

## Implementation notes

### The tree

`HunchCore/Tests/PersistenceTests/Fixtures/v1/` holds a small but structurally complete store:

```
manifest.json          schema 1, two fixed dates
codex-index.json       a handful of lawKeys plus the eight per-band counts
codex-b1.json          2 pages
codex-b2.json          empty array — an empty shelf is a real state (§11.2's dashed plate)
codex-b3.json          1 page
codex-b4.json          3 pages, one fractured, one with anomalyDay set
codex-b5.json … b8     empty arrays; all eight shelves exist, because the reset map asserts on
                       the exact surviving set and an absent shelf would make that ambiguous
anomaly.json           v 1, a non-zero highWaterDay, ~6 entries, a streak, a MonotonicAnchor
anomaly.hw             16 bytes, agreeing with anomaly.json's highWaterDay
profile.json           five axes with non-zero n, a ghost, lastRenderedRadii
ladder.json            an Ability with a defined baseline, a ServingState, both rings non-empty
stats.json             non-zero counters and a short recentRounds ring
round-probe.json       a live ProbeSnapshot: a resolved LawNode, lawHash, 5 probes, 0 strikes
```

`lowerBandIndex.bin` is **deliberately absent** — it is derived, `RecoveryPolicy.regenerate`, and its
absence is a state the app must handle on every fresh install. `round-drift.json` and
`round-echo.json` are absent for the same reason a real store usually lacks them: at most one round
is suspended at a time in practice.

Keep the tree small. Its job is to pin *shape and schema*, not volume; the 512 KB assertion is
carried by the synthetic worst case, below.

### Minting it, and `06 T56`

`06 T56` says a fixture must have been produced by a shipped binary, and at v1 there is no earlier
binary — the v1 code is the only thing that will ever write v1. Resolve it honestly:

- Mint the tree **once**, from a committed `swift run` tool, at the moment v1 is frozen. Reuse
  E06·T10's tool if it exists (`swift run hunch-fixtures store-v1`), or add the target.
- **Never regenerate it afterwards.** §11.13 says this in as many words: *"it never gets regenerated
  to make a build pass"*. Put that sentence in a `README` beside the tree, because the fastest way to
  lose this test is a future engineer running the mint tool to fix a red build.
- From v2 onward the rule is the real one: `Fixtures/v2/` is what the shipped v2 binary wrote, and v1
  stays exactly as it is, forever.

### The `.copy` trap, twice

Two failure modes that look identical and are not:

1. **`resources: [.copy("Fixtures")]`** preserves the directory, so `Fixtures/v1/manifest.json` is
   the bundle path and **every lookup must pass `subdirectory:`**. A bare
   `bundle.url(forResource:withExtension:)` returns `nil` and every `#require` in the suite fails at
   once. `.process` would flatten and is wrong here, because the directory structure *is* the thing
   under test.
2. **`#bundle` inside `HunchTestSupport`** expands to that target's bundle, and the resources are
   declared on `PersistenceTests`. `StoreSandbox` therefore takes a `Bundle` and every call site
   passes `#bundle` — `.storeSandbox(in: #bundle)`. Same `nil`, different cause.

`#bundle` and not `Bundle.module` (`01 P36`, `07 B22`). It carries `@available(macOS 12, …)`, which
`HunchCore/Package.swift`'s `platforms: [.iOS(.v18), .macOS(.v15)]` already satisfies — if the error
says *"'bundle()' is only available in macOS 12 or newer"*, the manifest lost its macOS floor.

### `everyCaseRoundTrips` and the T21 question

This is a parameterised test over `StoreFile.allCases` — 20 cases, one per file, each with its own
temporary directory. That is `06 T21` honoured rather than deviated from: the argument type is
`Hashable` and the arguments are enumerated by the compiler, so a failure names the file. `StoreFile`
must therefore satisfy `@Test(arguments:)`'s conformance requirement — it is not `RawRepresentable`
(it has associated values), so add `CustomTestArgumentEncodable` returning `fileName`, which is both
unique and human-readable in the navigator. That is one small extension in the **test target**, not
in `Sources` — the shipping enum has no business conforming to a `Testing` protocol.

### The 512 KB budget, and the tension worth recording

`08 §7.5` and E15's gate both assert *no single file exceeds 512 KB*. The fixture passes trivially.
The honest arithmetic does not: §11.4 gives band 7 **10,314** laws and §11.13 estimates ~140 B per
page, so a *complete* band-7 shelf is ≈ 1.4 MB. Two things follow.

1. The assertion is over the files **actually in the store**, which is what it can be and what makes
   it useful — it fires the day a real store crosses the line, which is the only day it matters.
2. Record the tension in `DECISIONS.md`: at the point a shelf approaches 512 KB the fix is a
   second-level shard (`codex-b7-a.json` / `-b.json` keyed on skeleton, which §11.2 already uses as
   the sub-section axis), and that is a decision for **E15**, not a reason to weaken the assertion
   now. Add a `.nightly` case that synthesises a full band-7 shelf and records its size as an
   `Attachment` without asserting, so the number is measured rather than estimated before E15 needs
   it.

### The malformed sibling

`codex-b4.truncated.json` is `codex-b4.json` cut mid-object. It lives in `Fixtures/` (not inside
`v1/`), because it is not part of any tree — it is an input. The assertion is `06 T55`'s: a
**specific** typed error (`DecodingError`), then the *stated product behaviour* — quarantine to
`corrupt/`, rebuild empty, `codex-index.json` untouched, and `StoreHealth == .quarantined(...)`. The
last placeholder case in step 1 (`everyJSONFileHasAMalformedSibling`) is a stub: replace it with a
real assertion once the tree lands — that every `.json` file in `v1/` has a `.truncated.json`
sibling, so the next person adding a file to the tree is forced to add its malformed twin too.

### `StoreTree`

```swift
// HunchCore/Sources/HunchTestSupport/StoreTree.swift
public enum StoreTree {
    /// Every regular file under `directory`, keyed by path relative to it. Recursive, so `corrupt/`
    /// shows up — a reset that leaves a quarantined file behind is a reset that did not run.
    public static func bytes(of directory: URL) throws -> [String: Data]
    public static func makeEmptyDirectory() throws -> URL
    /// SHA-256 over one file, for the byte-identity assertions in T06.
    public static func digest(of file: StoreFile, in directory: URL) throws -> String
}
```

`digest` uses `CryptoKit`'s `SHA256`… **no.** `CryptoKit` is neither `Swift` nor `Foundation` and
`08 §2`'s predicate bans it. Compare `Data` directly — the files are kilobytes, and `a == b` on
`Data` is exactly the assertion "byte-identical" means. Delete `digest` and use `bytes(of:)`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter FixtureV1Tests` green, all four cases.
- [ ] `swift test --package-path HunchCore --filter StoreRoundTripTests` green: 20 parameterised
      round-trip cases plus the whole-tree, quarantine and sibling cases.
- [ ] Deleting `subdirectory: "Fixtures"` from the trait's lookup makes every case fail with the
      `#require` message. Do it, read it, revert.
- [ ] Changing `resources: [.copy("Fixtures")]` to `.process("Fixtures")` makes the suite fail. Do
      it, revert.
- [ ] `ls HunchCore/Tests/PersistenceTests/Fixtures/v1 | wc -l` shows **16** files — 8 shelves plus
      `manifest`, `codex-index`, `anomaly.json`, `anomaly.hw`, `profile`, `ladder`, `stats`,
      `round-probe` — and `find HunchCore/Tests/PersistenceTests/Fixtures -size +512k` is empty.
- [ ] Running two tests in the same process leaves two different `StoreSandbox.root` values — add a
      throwaway pair of tests that record the path, confirm they differ, delete them.
- [ ] `tests.json` carries the four new entries.
- [ ] No `deinit` anywhere in `PersistenceTests`; `grep -rn 'deinit' HunchCore/Tests` is empty.

## Close the task

1. `swift test` green, and the fast suite still under 10 s — the fixture copy is per test, so if the
   suite has slowed measurably, the tree is too big; shrink it rather than gating it to nightly.
2. **Run `/simplify`** — re-run the tests after it. Refuse any suggestion to share one sandbox across
   the suite: a shared path is exactly what `06 T20` and `T10` forbid, and it will pass until the day
   the suite runs in a different order.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T05: Fixtures/v1, the store sandbox trait and the persistence suite"`

## Out of scope

- The reset assertions — **T06**, which uses this task's trait and `StoreTree` unchanged.
- Decoding the fixture into domain types. `CodexPage` and friends arrive in **T09**; until then the
  fixture is asserted at the envelope and byte level, and `truncatedShelfQuarantines`'s
  `[CodexPage].self` line lands when T09 does (write the test now with a placeholder type and switch
  it, or land T09 first — the epic's execution order allows either).
- "Opening a shelf parses exactly one file" — **E15·T01**, a `Codex` behaviour.
- Rebuilding `codex-index.json` by scanning the eight shelves — **E15·T01**. This task asserts the
  *policy* (`RecoveryPolicy.rebuildByScanningShelves`) and that the index survives a shelf
  quarantine, not the rebuild itself.
