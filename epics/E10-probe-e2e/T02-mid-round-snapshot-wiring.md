# T02 — Mid-round snapshot wiring

| | |
|---|---|
| **Epic** | E10 — PROBE end to end: shell, resume and onboarding |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Mid-round snapshot (PROBE) — the cadence half; the value type is E07·T09's |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides the split this task turns on: the *integrity check* is a pure function of a snapshot and therefore core, while the *cadence* is `Round`'s and therefore app-layer. Getting that backwards puts a `Task` in `HunchCore` or a pure predicate behind `@MainActor`. Also owns `Round`'s state ownership (`04 A18`'s earned observable). |

`hunch-swift-concurrency` is **not** required: this task adds no actor and no isolation. It calls into
`FilePersistenceStore` (already an actor) from `@MainActor` code with `await`, which is the normal path.

## Objective

At the end of this task a running round writes itself to disk after every committed verdict, after every
strike resolution, and on `scenePhase → .inactive` — with the Bench draft riding the `.inactive` write
and no other — and a snapshot whose stored law does not hash to its recorded `lawHash` produces
`Outcome.voided` from `arming`, never a silently altered round.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.10 (Mid-round snapshot) | the three write points verbatim, and why the draft rides only the `.inactive` write |
| `GAME_DESIGN.md` | §6.10 (The law is stored, not regenerated) | why the snapshot carries the resolved `LawNode` and `lawHash` is only ever asked "is this the law I wrote down" |
| `GAME_DESIGN.md` | §6.1 (transition table + invariants) | `arming → settled(.voided)` on a failed hash; the model never waits on an animation, so the write is scheduled at t = 0 of the beat |
| `GAME_DESIGN.md` | §6.11 rows 5, 7, 8, 22, 23, 29 | backgrounding mid-beat, force-quit, crash, storage full, failed hash, a snapshot already at cap |
| `GAME_DESIGN.md` | §11.13 | the write order (`round.json` first, smallest file), and the failure row for a full disk |
| `GAME_DESIGN.md` | §12.7 | `.inactive` / `.background` / `.active` behaviour for PROBE, DRIFT and ECHO |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §4 (actors), §5 (persistence) | why `RoundPhase` transitions are core and the durations are not; the `FilePersistenceStore` shape |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | exhaustive `switch` with no `default:` over the failure enum |

Every field of `ProbeSnapshot` is §6.10's and is not restated here.

## TDD — the test comes first

**Step 1 — write the failing test.** Two files, one per layer.

`HunchCore/Tests/RoundsTests/SnapshotIntegrityTests.swift` — the pure half:

```swift
import Testing
@testable import Rounds
import Glyphs
import Laws
import HunchTestSupport

@Suite("Snapshot integrity — §6.10, §6.11 #23 and #29", .tags(.unit, .presubmission))
struct SnapshotIntegrityTests {

    @Test("a snapshot whose law hashes to its recorded lawHash validates")
    func honestSnapshotValidates() {
        let snapshot = ProbeSnapshot.fixture(probes: [22, 30])
        #expect(SnapshotIntegrity.validate(snapshot) == nil)
    }

    @Test("a corrupted lawHash voids the round; it is never silently altered")
    func corruptHashVoids() {
        var snapshot = ProbeSnapshot.fixture(probes: [22, 30])
        snapshot.lawHash ^= 1                                   // one flipped bit is corruption
        #expect(SnapshotIntegrity.validate(snapshot) == .lawHashMismatch)
    }

    @Test("the law is authoritative and the probe list is not — a forged probe carries no forged verdict")
    func probeListIsNotAuthoritative() {
        var tampered = ProbeSnapshot.fixture(probes: [22, 38])
        tampered.probes = [22, 38, 38, 38]
        #expect(SnapshotIntegrity.validate(tampered) == nil)     // still a well-formed snapshot…

        // …and every verdict is recomputed from the stored law, so appending probes buys nothing.
        // Under the opening law `shape ∈ {triangle}`, glyph 22 is a triangle and 38 (shape index 2)
        // is not — derive both from `Deck` rather than trusting these two numbers.
        let law = Law(tampered.law)
        let ribbon = Ribbon(recomputing: tampered, law: law)
        #expect(ribbon.probes.count == 4)
        #expect(ribbon.probes[0].verdict == .admit)
        #expect(ribbon.probes.dropFirst().allSatisfy { $0.verdict == .reject })
        #expect(ribbon.probes.last?.isTwin == true)              // adjacency is recomputed too
    }

    @Test("a snapshot already at cap is corruption, not a playable round (§6.11 #29)")
    func snapshotAtCapIsCorruption() {
        let atCap = ProbeSnapshot.fixture(probes: Array(0..<UInt8(Band.literal.cap)))
        #expect(SnapshotIntegrity.validate(atCap) == .probeCountAtCap)
    }

    @Test("an unknown schema voids rather than guesses")
    func unknownSchemaVoids() {
        var snapshot = ProbeSnapshot.fixture(probes: [22])
        snapshot.schema = 99
        #expect(SnapshotIntegrity.validate(snapshot) == .unknownSchema)
    }

    @Test("a validation failure resolves to settled(.voided), reachable only from arming (§6.1)")
    func failureResolvesToVoided() {
        #expect(SnapshotIntegrity.outcome(for: .lawHashMismatch) == Outcome.voided)
        #expect(RoundPhase.arming.next(on: .snapshotFailedIntegrity) == .settled(.voided))
        // and from nowhere else:
        for phase in RoundPhase.allProbeSideCases where phase != .arming {
            #expect(phase.next(on: .snapshotFailedIntegrity) == phase)
        }
    }
}
```

`Modules/Tests/LoomFeatureTests/SnapshotCadenceTests.swift` — the wiring half:

```swift
import Foundation
import Testing
import HunchCore
@testable import LoomFeature

@Suite("Mid-round snapshot cadence — §6.10")
@MainActor
struct SnapshotCadenceTests {

    private func makeRound(_ store: RecordingPersistenceStore) -> Round {
        Round(serving: .openingRound, store: store, now: { Date(timeIntervalSince1970: 1_700_000_000) },
              cues: SilentCuePlayer())
    }

    @Test("every committed verdict writes exactly one snapshot, and it carries that probe")
    func writesAfterEveryCommittedVerdict() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)

        round.probe(Deck.glyph(id: 22))
        await round.flush()
        round.probe(Deck.glyph(id: 30))
        await round.flush()

        let writes = await store.writes(to: .round(.probe))
        #expect(writes.count == 2)
        let latest = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(latest.probes == [22, 30])
    }

    @Test("the write is scheduled at t = 0 of the beat, not at its end (§6.1's invariant)")
    func writeDoesNotWaitOnTheAnimation() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)

        round.probe(Deck.glyph(id: 22))
        await round.flush()                        // no beat has been advanced at all
        #expect(round.phase == .adjudicating(.admit))
        let latest = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(latest.probes == [22])
    }

    @Test("the Bench draft rides the .inactive write and no other")
    func draftRidesOnlyTheInactiveWrite() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.openBench()
        round.editDraft(.rampBound(to: .shape))     // 2 KB of draft, 40 edits a round
        round.closeBench()
        round.probe(Deck.glyph(id: 22))
        await round.flush()

        let afterVerdict = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(afterVerdict.benchDraft == nil)

        round.scenePhaseChanged(to: .inactive)
        await round.flush()
        let afterInactive = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(afterInactive.benchDraft != nil)
    }

    @Test("a strike resolution writes, carrying strikes and the docked counterexample")
    func writesAfterStrikeResolution() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        await round.flush()
        round.declare(.wrongDraft)                  // first strike
        await round.flush()

        let latest = try #require(await store.latest(ProbeSnapshot.self, from: .round(.probe)))
        #expect(latest.strikes == 1)
        #expect(latest.counterexample != nil)
    }

    @Test("a failed atomic write keeps the round in memory and raises the chrome warning (§6.11 #22)")
    func storageFullDoesNotEndTheRound() async throws {
        let store = RecordingPersistenceStore(failWrites: true)
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        await round.flush()

        #expect(round.phase == .adjudicating(.admit))   // the round continues
        #expect(round.probes.count == 1)                 // in memory, intact
        #expect(round.storeHealth == .writesFailing)     // the hairline strip, in the chrome only
    }

    @Test("the snapshot slot is cleared last, after every other round-end write succeeds (§11.13)")
    func slotClearedLast() async throws {
        let store = RecordingPersistenceStore()
        let round = makeRound(store)
        round.probe(Deck.glyph(id: 22))
        round.declare(.correctDraft)
        await round.flush()

        let order = await store.operations
        let clear = try #require(order.lastIndex(where: { $0 == .delete(.round(.probe)) }))
        #expect(clear == order.count - 1)
    }
}
```

and the spy it needs, `Modules/Tests/LoomFeatureTests/RecordingPersistenceStore.swift`:

```swift
import Foundation
import HunchCore

/// App-side spy. It lives here and not in `HunchTestSupport` because that target is absent from
/// `HunchCore`'s `products:` (`06 T5a`) and is therefore invisible to every `Modules` test target.
actor RecordingPersistenceStore: PersistenceStore {
    enum Operation: Equatable { case save(StoreFile), delete(StoreFile) }

    private(set) var operations: [Operation] = []
    private var contents: [StoreFile: Data] = [:]
    private let failWrites: Bool

    init(failWrites: Bool = false) { self.failWrites = failWrites }

    func save<T: Encodable & Sendable>(_ value: T, to file: StoreFile) async throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        operations.append(.save(file))
        contents[file] = try JSONEncoder().encode(value)
    }

    func load<T: Decodable & Sendable>(_ type: T.Type, from file: StoreFile) async throws -> T? {
        try contents[file].map { try JSONDecoder().decode(T.self, from: $0) }
    }

    func delete(_ file: StoreFile) async throws { operations.append(.delete(file)); contents[file] = nil }

    func writes(to file: StoreFile) -> [Operation] { operations.filter { $0 == .save(file) } }
    func latest<T: Decodable & Sendable>(_ type: T.Type, from file: StoreFile) throws -> T? {
        try load(type, from: file)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter SnapshotIntegrityTests` then
`swift test --package-path Modules --filter SnapshotCadenceTests`.
Both must fail on missing symbols (`SnapshotIntegrity`, `Round.flush()`, `Round.storeHealth`), not on a
malformed expectation. If `RecordingPersistenceStore` does not compile, `PersistenceStore`'s real
signatures from E07·T01 differ — adopt those, and change nothing about the assertions.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/SnapshotIntegrity.swift` |
| modify | `HunchCore/Sources/Rounds/RoundPhase.swift` — add the `snapshotFailedIntegrity` event to the transition function |
| modify | `Modules/Sources/LoomFeature/Round.swift` — the three write points, `flush()`, `scenePhaseChanged(to:)`, `storeHealth` |
| create | `Modules/Sources/LoomFeature/RoundSnapshotWriter.swift` |
| create | `HunchCore/Tests/RoundsTests/SnapshotIntegrityTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/SnapshotCadenceTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/RecordingPersistenceStore.swift` |
| modify | `tests.json` — four entries (cadence, draft-on-inactive, void-on-mismatch, slot-cleared-last) |

## Implementation notes

### The pure half

```swift
public enum SnapshotIntegrity {
    public enum Failure: Equatable, Sendable {
        case lawHashMismatch      // §6.11 #23 — on-disk corruption, the only realistic cause
        case probeCountAtCap      // §6.11 #29 — unreachable by construction, therefore corruption
        case unknownSchema        // §11.13 — a file from a future build
    }

    public static func validate(_ snapshot: ProbeSnapshot) -> Failure?
    public static func outcome(for failure: Failure) -> Outcome { .voided }
}
```

Three points the implementation must get right:

1. **The hash is asked one question only.** `LawTable(snapshot.law).extensionHash != snapshot.lawHash`
   → `.lawHashMismatch`. It is never used to look a law up, and the snapshot is never repaired,
   regenerated or partially trusted. §6.10 is explicit: *voided, never silently altered.*
2. **Verdicts are recomputed, always.** Rehydration walks `snapshot.probes` through
   `Law.admits(_:after:)` with `prev` being the previously **probed** glyph and the seed glyph priming
   position 0 (§3.5). Nothing on disk carries a verdict, which is why a tampered probe list buys
   nothing.
3. **Cap validation reads the band's own cap** (`Band.cap`, E05·T06), never a copy. `probes.count >= cap`
   is corruption because the cap-th verdict transitions straight to `revealing(.exhausted)` and the slot
   is cleared at round end.

`Outcome.voided` scores 0, mints no page and updates no θ (§6.9, §6.10) — that consequence is
T04's `RoundEffects` table, not this file's.

### The cadence half

Extract the writing into `RoundSnapshotWriter` so `Round` keeps one line per write point and the
serialisation policy has one owner:

```swift
@MainActor
final class RoundSnapshotWriter {
    private var inFlight: Task<Void, Never>?

    /// Coalescing is deliberate: a queued probe at t = 420 must not race the write from t = 0.
    func write(_ snapshot: ProbeSnapshot, to store: any PersistenceStore,
               onFailure: @escaping @MainActor (Error) -> Void) { … }

    func flush() async { await inFlight?.value }
}
```

- **Write point 1 — every committed verdict.** Called from `Round.probe(_:)`/`probeTwin()` at **t = 0**
  of the 420 ms beat, on the same line the verdict is appended, before any animation is scheduled.
  §6.11 #5 and #8 are consequences of that placement, not extra code.
- **Write point 2 — every strike resolution.** After the counterexample is selected and docked, with
  `strikes` and `counterexample` populated. §6.8 already committed the model at t = 0 of the seal beat.
- **Write point 3 — `scenePhase → .inactive`.** The only write that carries `benchDraft`. §6.10's
  reasoning is the comment to write: 2 KB on every ramp-cell tap is 40 writes a round for state the
  player can re-tap in two seconds.
- **`.background`** additionally flushes and `fsync`s in §11.13's order (`round-{mode}.json` first) —
  the flush is `flush()`, the order is `FilePersistenceStore`'s (E07·T02).
- **Round end** clears the slot **last**, after the page, the θ update, the Profile accumulators and the
  novelty entry have all been written (§6.10). The `slotClearedLast` test is what keeps that ordering
  from drifting when E11 and E15 add their writes.

### Storage full

A throwing write does not end the round and does not roll the model back (§6.11 #22): catch, set
`storeHealth = .writesFailing`, keep playing, and retry at the next round boundary and on `.background`.
The strip it drives is chrome; the play surface is untouched (§13.10's "never in the play surface").

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SnapshotIntegrityTests` green.
- [ ] `swift test --package-path Modules --filter SnapshotCadenceTests` green.
- [ ] `grep -n "case " HunchCore/Sources/Rounds/SnapshotIntegrity.swift` shows exactly three failures, and the `switch` mapping them to an outcome has no `default:`.
- [ ] `grep -rn "benchDraft" Modules/Sources/LoomFeature` shows the draft populated at exactly one call site.
- [ ] `grep -rn "store.save\|writer.write" Modules/Sources/LoomFeature/Round.swift` shows exactly three write points and one slot-clear.
- [ ] `tests.json` carries the four entries, each with the test name that proves it.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E10/T02: snapshot cadence, integrity check and the voided path"`

## Out of scope

- `ProbeSnapshot`, `StoreFile`, `PersistenceStore`, `FilePersistenceStore`, atomic writes and the §11.13 write order — **E07·T01/T02/T09**.
- What the *resume* looks like on screen — **T03**.
- What an abandon or a discard does to the record and to θ — **T04**.
- DRIFT's and ECHO's extra snapshot fields — **E12·T09**, **E13·T09**.
- SIEVE, which voids rather than snapshots — **E14·T08**.
- The round card's broken-seal drawing for `.voided` — **E09·T11** owns `InscriptionView`; this task only produces the outcome.
