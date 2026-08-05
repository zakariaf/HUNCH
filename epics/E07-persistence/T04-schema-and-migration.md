# T04 — Schema and migration

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | §14.1 PERSISTENCE → **Schema and migration** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns the `Codable` shape rules — `LawNode` is `Codable` and `Law` is not, `Mode` carries a `UInt8` raw value rather than a `String` — and owns `W16`'s caseless-enum namespace, which is what `Schema` and `SchemaMigration` are |
| `hunch-swift-testing` | Owns `06 T55`'s "every decoding fixture gets a malformed sibling asserting a *specific typed error*", and owns the ban on `swift-snapshot-testing` — the golden-fixture role is filled by `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])` by hand |

## Objective

There is one global `schema`, it is 1, every file echoes it, and a single decoder can read that
number out of any file in the tree without knowing what the file contains. Migration exists as
working, tested machinery — write the whole new tree into `Hunch.staging/`, synchronise it, then
replace the directory atomically — with an empty step chain, because there is no v2 yet and the
transactional property is the thing that has to be right before there is.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.13, *Migration* paragraph | `schema` starts at 1; additive fields decode with `decodeIfPresent` and a default; removed fields are tolerated; any semantic change bumps `schema` and gets an explicit `migrate_vN_to_vN+1(directory:)`; migration is transactional — staging directory, `fsync`, atomic replace; `Fixtures/v1/` must load green under every future build and **never gets regenerated to make a build pass** |
| `GAME_DESIGN.md` | §11.13, the file table row 1 | `manifest.json` holds `{ schema: Int, createdAt, lastWriteAt }`; every other file echoes `v` |
| `GAME_DESIGN.md` | §11.7 | `AnomalyLedger` is declared with `var v: Int` — the second spelling the envelope has to read |
| `ios-swift-guide/06-TESTING.md` | T55, T56 | Malformed sibling with a typed error; a fixture must have been produced by a shipped binary |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W16, W29 | Caseless enum as a namespace; no `default:` |

## TDD — the test comes first

**Step 1 — write the failing test.** Create
`HunchCore/Tests/PersistenceTests/SchemaMigrationTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import LawGeneration
import Persistence

@Suite("Schema and migration", .tags(.unit, .presubmission))
struct SchemaMigrationTests {

    private func makeDirectory() throws -> URL {
        let root = try FileManager.default.url(for: .itemReplacementDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: URL.temporaryDirectory,
                                               create: true)
            .appending(path: "Hunch")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    // ---- the envelope --------------------------------------------------------------------------

    @Test("The envelope reads the manifest's `schema` key")
    func envelopeReadsSchema() throws {
        let payload = Data(#"{"schema":1,"createdAt":0,"lastWriteAt":0}"#.utf8)
        #expect(try SchemaEnvelope(payload).version == 1)
    }

    @Test("The envelope reads every other file's `v` key")
    func envelopeReadsV() throws {
        #expect(try SchemaEnvelope(Data(#"{"v":1,"highWaterDay":20000}"#.utf8)).version == 1)
    }

    @Test("A payload carrying neither key is a typed error, not a crash and not a zero")
    func envelopeRejectsAnUnversionedPayload() {
        #expect(throws: SchemaError.unversioned.self) {
            try SchemaEnvelope(Data(#"{"highWaterDay":20000}"#.utf8))
        }
    }

    @Test("A truncated payload is a typed error naming decoding, not `.unversioned`")
    func envelopeRejectsTruncatedBytes() {
        #expect(throws: (any Error).self) { try SchemaEnvelope(Data(#"{"v":1,"#.utf8)) }
    }

    // ---- additive and removed fields -----------------------------------------------------------

    @Test("An unknown field is tolerated — a file written by a newer build still decodes")
    func unknownFieldsAreTolerated() throws {
        let payload = Data(#"{"schema":1,"createdAt":0,"lastWriteAt":0,"unknownFuture":42}"#.utf8)
        let manifest = try JSONDecoder().decode(Manifest.self, from: payload)
        #expect(manifest.schema == 1)
    }

    @Test("An additive field absent from v1 decodes to its stated default, never to nil-by-accident")
    func additiveFieldsTakeTheirDefault() throws {
        let payload = Data(#"{"schema":1,"createdAt":0,"lastWriteAt":0}"#.utf8)
        let manifest = try JSONDecoder().decode(Manifest.self, from: payload)
        #expect(manifest.migratedAt == nil)      // the one additive field v1 does not carry
    }

    // ---- the transaction -----------------------------------------------------------------------

    @Test("A store already at the current schema is left untouched")
    func upToDateIsANoOp() async throws {
        let directory = try makeDirectory()
        let before = try seedTree(at: directory)
        let outcome = try SchemaMigration.migrate(directory: directory)
        #expect(outcome == .upToDate)
        #expect(try snapshotBytes(of: directory) == before)
    }

    @Test("A successful migration replaces the whole tree and bumps the manifest")
    func migrationReplacesTheTree() async throws {
        let directory = try makeDirectory()
        _ = try seedTree(at: directory)
        let step = MigrationStep(from: 1, to: 2) { staging in
            let url = staging.appending(path: StoreFile.profile.fileName)
            try Data(#"{"v":2,"axes":[]}"#.utf8).write(to: url, options: [.atomic])
        }

        let outcome = try SchemaMigration.migrate(directory: directory, to: 2, steps: [step])

        #expect(outcome == .migrated(from: 1, to: 2))
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: directory.appending(path: "manifest.json")))
        #expect(manifest.schema == 2)
        #expect(try SchemaEnvelope(Data(contentsOf: directory.appending(path: "profile.json")))
            .version == 2)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "../Hunch.staging").path()))
    }

    @Test("A step that throws leaves the original tree byte-identical and no staging behind")
    func aFailedStepRollsBack() async throws {
        let directory = try makeDirectory()
        let before = try seedTree(at: directory)
        struct Boom: Error {}
        let step = MigrationStep(from: 1, to: 2) { _ in throw Boom() }

        #expect(throws: Boom.self) {
            try SchemaMigration.migrate(directory: directory, to: 2, steps: [step])
        }
        #expect(try snapshotBytes(of: directory) == before)
        #expect(!FileManager.default.fileExists(
            atPath: directory.deletingLastPathComponent().appending(path: "Hunch.staging").path()))
    }

    @Test("A migration that edits nothing still preserves anomaly.json and anomaly.hw byte for byte")
    func migrationNeverTouchesTheLedger() async throws {
        let directory = try makeDirectory()
        let before = try seedTree(at: directory)
        let step = MigrationStep(from: 1, to: 2) { _ in }
        _ = try SchemaMigration.migrate(directory: directory, to: 2, steps: [step])
        let after = try snapshotBytes(of: directory)
        #expect(after[StoreFile.anomaly.fileName] == before[StoreFile.anomaly.fileName])
        #expect(after[StoreFile.anomalyHighWater.fileName] == before[StoreFile.anomalyHighWater.fileName])
    }

    @Test("The shipped step chain is empty, because there is no v2")
    func theShippedChainIsEmpty() {
        #expect(SchemaMigration.steps.isEmpty)
        #expect(Schema.current == 1)
    }

    // ---- helpers -------------------------------------------------------------------------------

    /// Writes a minimal but *complete-shaped* tree and returns its bytes, keyed by filename.
    private func seedTree(at directory: URL) throws -> [String: Data] { … }

    private func snapshotBytes(of directory: URL) throws -> [String: Data] { … }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter SchemaMigrationTests`
The failures must be missing symbols (`Schema`, `SchemaEnvelope`, `Manifest`, `MigrationStep`,
`SchemaMigration`). `theShippedChainIsEmpty` is the one case that will pass the moment the types
exist — that is correct and it is the case that will fail on the day someone adds a v2 step without
adding a `Fixtures/v2/` directory alongside it.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.** The refactor to make is folding `seedTree`/`snapshotBytes` into a
shared helper T05 and T06 will both want; put it in `HunchTestSupport` as `StoreTree`, not in the
test file, and move it in this step rather than copy-pasting it later.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Persistence/Schema.swift` — `enum Schema`, `struct SchemaEnvelope`, `enum SchemaError` |
| create | `HunchCore/Sources/Persistence/Manifest.swift` |
| create | `HunchCore/Sources/Persistence/SchemaMigration.swift` — `enum SchemaMigration`, `struct MigrationStep`, `enum MigrationOutcome` |
| create | `HunchCore/Tests/PersistenceTests/SchemaMigrationTests.swift` |
| create | `HunchCore/Sources/HunchTestSupport/StoreTree.swift` — the seed/snapshot helpers T05 and T06 reuse |

## Implementation notes

### `Schema` and the envelope

```swift
/// The single global schema. §11.13: `manifest.json` carries it as `schema`; every other file
/// echoes it as `v`, for validation only — a file that disagrees with the manifest is corrupt,
/// not a file at a different version.
public enum Schema {
    public static let current = 1
}

/// Reads the version out of any file in the tree without knowing what the file contains.
/// Two key spellings because §11.13 uses `schema` in the manifest and `v` everywhere else
/// (`AnomalyLedger.v` in §11.7, `ProbeSnapshot.schema` in §6.10 — read both).
public struct SchemaEnvelope: Sendable, Equatable {
    public let version: Int

    public init(_ data: Data) throws {
        struct Payload: Decodable {
            let version: Int
            enum CodingKeys: String, CodingKey { case schema, v }
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let schema = try container.decodeIfPresent(Int.self, forKey: .schema) {
                    version = schema
                } else if let v = try container.decodeIfPresent(Int.self, forKey: .v) {
                    version = v
                } else {
                    throw SchemaError.unversioned
                }
            }
        }
        version = try JSONDecoder().decode(Payload.self, from: data).version
    }
}

public enum SchemaError: Error, Hashable, Sendable {
    case unversioned
    case unsupported(found: Int, current: Int)
    case noPathFrom(Int, to: Int)
}
```

`ProbeSnapshot` (T09) spells its field `schema`, matching §6.10's declaration; the envelope reading
both spellings is what makes that harmless. Do not "fix" §6.10 to say `v` — the spec owns it, and
the envelope is the one place the two spellings meet.

`lowerBandIndex.bin` is binary and carries no envelope. It is derived and regenerable
(`RecoveryPolicy.regenerate`), so migration copies it or drops it; **dropping it is the better
default** — a schema change that alters the generator would leave a stale index that regenerates
correctly anyway. State which you chose in a comment.

### `Manifest`

```swift
/// §11.13's first row. The only file whose *only* job is to say what version the tree is.
public struct Manifest: Codable, Hashable, Sendable {
    public let schema: Int
    public let createdAt: Date
    public var lastWriteAt: Date
    /// Additive from v2. `decodeIfPresent` with a default is §11.13's stated additive-field
    /// mechanism, and this field exists at v1 purely so the mechanism has a live test.
    public var migratedAt: Date?

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema      = try c.decode(Int.self, forKey: .schema)
        createdAt   = try c.decode(Date.self, forKey: .createdAt)
        lastWriteAt = try c.decode(Date.self, forKey: .lastWriteAt)
        migratedAt  = try c.decodeIfPresent(Date.self, forKey: .migratedAt)
    }
}
```

Write the memberwise `public init` by hand as well (`04 A29`: a `public struct`'s synthesised
initialiser is internal, and `Modules/` constructs this).

`JSONDecoder` ignores unknown keys by default, which is exactly "removed fields are tolerated" — do
**not** add a custom `init(from:)` that validates the key set, and do not set
`allowsJSON5`/`keyDecodingStrategy`. `unknownFieldsAreTolerated` is the test that pins that
behaviour so nobody adds strictness later.

Dates encode as `timeIntervalSinceReferenceDate` doubles under the default strategy; the fixture in
T05 must be written with the same decoder settings or it will not load. Fix the settings once:

```swift
extension JSONDecoder {
    /// The one decoder the store uses. Defaults, deliberately — the fixture is only a
    /// migration test if the encoder that wrote it and the decoder that reads it never drift.
    public static let store = JSONDecoder()
}
extension JSONEncoder {
    /// `.sortedKeys` so a golden fixture diffs; `.prettyPrinted` so a human can read a bug report.
    public static let store: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }()
}
```

These two are the hand-rolled replacement for `swift-snapshot-testing`, which is banned. Every
`Codable` type in T09 is encoded with `JSONEncoder.store` and nothing else.

### The migration transaction

```swift
public struct MigrationStep: Sendable {
    public let from: Int
    public let to: Int
    /// Runs against the **staging** directory, which already holds a full copy of the live tree.
    public let apply: @Sendable (_ staging: URL) throws -> Void
}

public enum MigrationOutcome: Hashable, Sendable {
    case upToDate
    case migrated(from: Int, to: Int)
}

public enum SchemaMigration {
    /// The chain. Empty at v1 — and it stays empty until a `Fixtures/v2/` directory lands beside it.
    public static let steps: [MigrationStep] = []

    /// §11.13: write the whole new tree into `Hunch.staging/`, synchronise, then atomically
    /// replace the directory.
    @discardableResult
    public static func migrate(directory: URL,
                               to target: Int = Schema.current,
                               steps: [MigrationStep] = steps,
                               fileManager: FileManager = .default) throws -> MigrationOutcome
}
```

The body, in order, and every step matters:

1. Read `manifest.json` through `SchemaEnvelope`. Absent manifest → the tree is new; write one at
   `target` and return `.upToDate`. Version `== target` → `.upToDate`, touching nothing.
   Version `> target` → `throw SchemaError.unsupported(found:current:)`; a store written by a
   *newer* build must never be silently downgraded.
2. Resolve the chain: the steps whose `from` walks version → target, contiguously.
   No path → `throw SchemaError.noPathFrom(_:to:)`.
3. `let staging = directory.deletingLastPathComponent().appending(path: "Hunch.staging")`.
   Remove any leftover staging first — a previous crash may have left one, and `copyItem` into an
   existing path throws.
4. `try fileManager.copyItem(at: directory, to: staging)` — the whole tree, including
   `anomaly.json`, `anomaly.hw` and `corrupt/`.
5. Run each step against `staging`. **Any throw exits here**, after `try? fileManager.removeItem(at:
   staging)` in a `defer` that is disarmed on success — so the live directory has not been touched at
   all and the assertion in `aFailedStepRollsBack` holds by construction rather than by cleanup.
6. Rewrite `staging/manifest.json` with `schema = target` and `migratedAt = <the caller's date>`.
   **The date is a parameter**, not `Date()`: `Date()` is banned under `HunchCore/Sources/` by check
   6, and `Now` is the injected time source (`08 §5`). Signature therefore carries `at now: Date`.
7. Synchronise each staged file with `FileHandle.synchronize()` before the swap. This is the `fsync`
   §11.13 asks for; the note in T02 about directory-level fsync applies here too and the atomicity is
   bought by step 8, not by the flush.
8. `try fileManager.replaceItemAt(directory, withItemAt: staging)` — Foundation's atomic directory
   swap. Not `removeItem` + `moveItem`: that pair has a window in which neither tree exists, which is
   the one failure mode this whole design exists to prevent.

`replaceItemAt` returns an optional `URL` and consumes `staging`; do not also try to delete it
afterwards or you will delete the *replaced original's* backup.

### Why the chain is empty and the machinery is not dead code

There is no v2. The temptation is to write the staging machinery when it is first needed, and the
reason not to is stated by §11.13 itself: *a checked-in `Fixtures/v1/` tree must load green under
every future build*. The test injects a synthetic step, so every line of the transaction — copy,
apply, rewrite, synchronise, swap, roll back — is exercised today by the `steps:` parameter that
defaults to the empty shipped chain. That parameter is the only reason this is testable before v2
exists; do not remove it as "unused" in `/simplify`.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SchemaMigrationTests` green, all ten cases.
- [ ] `grep -rn 'Date()' HunchCore/Sources/Persistence` returns nothing; `migrate` takes its date.
- [ ] `grep -rn 'JSONEncoder(' HunchCore/Sources | grep -v 'Schema.swift'` returns nothing — every
      encode goes through `JSONEncoder.store`.
- [ ] Adding a second `MigrationStep` to `SchemaMigration.steps` without bumping `Schema.current`
      makes `theShippedChainIsEmpty` fail. Try it, revert.
- [ ] After `aFailedStepRollsBack`, `ls` of the parent directory shows no `Hunch.staging`.
- [ ] `swift build --package-path HunchCore` emits zero warnings.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — re-run the tests after it. Refuse any suggestion to delete the `steps:`
   parameter or to inline `MigrationStep`; leave the comment above in place as the reason.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T04: global schema, envelope and the transactional migration"`

## Out of scope

- `Fixtures/v1/` itself and the assertion that it loads green — **T05**. This task ships the code
  that reads a tree; T05 ships the tree.
- The domain types whose additive fields will one day need a step: `CodexPage`, `Profile`,
  `AnomalyLedger`, `RoundRecord` are **T09**; `Ability`/`ServingState` are **E11·T01**.
- The `v` field on those types. T09 adds it to each; this task only guarantees the envelope can read
  it wherever it lands.
- Anything about *when* migration runs at launch — **E10·T01** calls it from `AppDependencies.live()`
  before the first store read.
