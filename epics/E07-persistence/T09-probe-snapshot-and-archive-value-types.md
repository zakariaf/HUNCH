# T09 — `ProbeSnapshot` and the archive value types

| | |
|---|---|
| **Epic** | E07 — Persistence and the round core |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T07 (and T08 for `Ribbon`; land after T05 if you want the fixture to hold a real snapshot) |
| **Delivers** | §14.1 PROBE → **Mid-round snapshot**; §14.1 CODEX → **`CodexPage` model** |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Owns the two rulings this task turns on: `LawNode` is `Codable` and `Law` is not — persist the AST, rebuild the table — and `CodexPage` is core while `Codex` is `CodexFeature`, because `@Observable` is a macro over a `@MainActor` class and would drag Observation into a nonisolated target |
| `hunch-swift-testing` | Owns the golden-fixture discipline that replaces `swift-snapshot-testing`: encode with `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])`, and never ship a decoding fixture without a malformed sibling |

## Objective

The suspended round exists as a value that carries **the resolved law itself**, with `lawHash` as a
corruption check and never as a recipe, glyph IDs with no stored verdicts, and an integrity check
that answers §6.1's `arming` fork. Alongside it, the four archive types — `CodexPage`, `RoundRecord`,
`Profile`, `AnomalyLedger` — exist as core `Codable Sendable` values with nothing observable, no
behaviour that needs a clock, and a `v` the schema envelope can read.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.10 | `struct ProbeSnapshot` **verbatim**, including `CounterexampleRef`; the two paragraphs "the law is stored, not regenerated" and "verdicts are still recomputed"; the voided path |
| `GAME_DESIGN.md` | §6.11 cases 23, 29 | A failed `lawHash` is `Outcome.voided`, reached from `arming` and nowhere else; a snapshot whose probe count already equals `cap` is corruption, not a resumable round |
| `GAME_DESIGN.md` | §11.1 | `struct CodexPage` **verbatim**, including why `seed` is not a page field, why `skeleton` is, and why `driftPartner`/`driftHinge` are payload rather than identity |
| `GAME_DESIGN.md` | §11.3 | Burnish, defined once: it sets `burnished` and ECHO's `modesSeen` bit **and nothing else** |
| `GAME_DESIGN.md` | §11.7 | `struct AnomalyLedger`, `enum AnomalyOutcome`, `struct DayEntry` **verbatim**; entries capped at 400; `highWaterDay` monotone |
| `GAME_DESIGN.md` | §11.9, §11.10 | The five axes as a type: `value ∈ [0,1]`, `n ∈ [0,60]`, `lastSampleAt`; `profile.json`'s ghost fields per §11.13 |
| `GAME_DESIGN.md` | §6.10 (end-of-round list), §11.13 | `RoundRecord`'s fields: seed, band, δ, probe list, strikes, outcome, score, marks, elapsed — a 200-entry ring in `stats.json` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1 (`Archive/`, `Rounds/`), §3 | The file homes, and the naming rows for `CodexPage`, `Profile.Axis`, `AnomalyLedger` |

> **A spelling to settle before you type.** `08 §1`'s tree calls the file `RoundSnapshot.swift` and
> `08 §4` lists `RoundSnapshot` among the `Sendable` types. §6.10 declares `struct ProbeSnapshot`
> and §14.1's row names `ProbeSnapshot`. The design owns domain names (§0.4), so ship
> **`ProbeSnapshot`** in `HunchCore/Sources/Rounds/ProbeSnapshot.swift` and record the deviation from
> the guide's file name in `DECISIONS.md`.

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.
`HunchCore/Tests/RoundsTests/ProbeSnapshotTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Bench
import Rounds
import HunchTestSupport

@Suite("The mid-round snapshot", .tags(.unit, .presubmission))
struct ProbeSnapshotTests {

    private func makeSnapshot(probes: [UInt8] = [22, 137, 137],
                              strikes: Int = 0) throws -> (ProbeSnapshot, Law) {
        let node = Corpora.law(band: .literal, index: 0)      // a resolved LawNode, not a recipe
        let law = Law(node)
        let snapshot = ProbeSnapshot(
            schema: Schema.current,
            law: node,
            lawHash: law.table.hash,
            seed: 0x48554E4348, band: 1, targetDelta: 0.06, mode: .probe,
            seedGlyph: 22,
            probes: probes,
            strikes: strikes,
            counterexample: nil,
            benchDraft: nil,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            elapsedActive: 42)
        return (snapshot, law)
    }

    // ---- the law is stored, not regenerated ---------------------------------------------------

    @Test("The snapshot carries the resolved law itself, not the arguments that made it")
    func theLawIsStoredWhole() throws {
        let (snapshot, law) = try makeSnapshot()
        #expect(snapshot.law == law.node)
        // §6.10: `avoid` is serving-layer state and it moves while a round is suspended, so a
        // regeneration from the same (seed, band, targetδ, mode) may legitimately resolve to a
        // *different* law. The seed is round-card metadata here, never a recipe.
        #expect(snapshot.seed == 0x48554E4348)
    }

    @Test("Encoding and decoding is identity, and the AST survives it")
    func codableRoundTrip() throws {
        let (snapshot, _) = try makeSnapshot()
        let data = try JSONEncoder.store.encode(snapshot)
        #expect(try JSONDecoder.store.decode(ProbeSnapshot.self, from: data) == snapshot)
        #expect(try SchemaEnvelope(data).version == Schema.current)
    }

    @Test("The payload stays small — §6.10 budgets ≈160 bytes plus the draft")
    func thePayloadIsSmall() throws {
        let (snapshot, _) = try makeSnapshot()
        #expect(try JSONEncoder().encode(snapshot).count < 1024)
    }

    // ---- verdicts are recomputed, never stored ------------------------------------------------

    @Test("The snapshot stores no verdicts at all")
    func noVerdictsOnDisk() throws {
        let (snapshot, _) = try makeSnapshot()
        let json = String(decoding: try JSONEncoder.store.encode(snapshot), as: UTF8.self)
        #expect(!json.contains("verdict"))
        #expect(!json.contains("admit"))
        #expect(!json.contains("reject"))
    }

    @Test("Rehydrating recomputes every verdict from the stored law")
    func rehydrationRecomputesVerdicts() throws {
        let (snapshot, law) = try makeSnapshot()
        let ribbon = snapshot.ribbon(under: law)
        #expect(ribbon.probes.count == snapshot.probes.count)
        #expect(ribbon.seedGlyph == Deck.glyph(id: snapshot.seedGlyph))
        // Every verdict equals a live evaluation, and the twin flags fall out of adjacency.
        #expect(ribbon.probes[2].isTwin)
        #expect(ribbon.probes[1].verdict
                == (law.admits(Deck.glyph(id: 137), after: Deck.glyph(id: 22)) ? .admit : .reject))
    }

    @Test("Tampering with the probe list changes the ribbon but never the law's answers")
    func tamperingAchievesNothing() throws {
        let (clean, law) = try makeSnapshot()
        let (tampered, _) = try makeSnapshot(probes: [22, 137, 200])
        #expect(clean.ribbon(under: law).probes[2].verdict
                != tampered.ribbon(under: law).probes[2].verdict
                || clean.ribbon(under: law).probes[2].glyph
                != tampered.ribbon(under: law).probes[2].glyph)
        #expect(tampered.integrity(cap: 12, lawHash: law.table.hash) == .intact)
    }

    // ---- integrity ---------------------------------------------------------------------------

    @Test("A matching hash is intact")
    func matchingHashIsIntact() throws {
        let (snapshot, law) = try makeSnapshot()
        #expect(snapshot.integrity(cap: 12, lawHash: law.table.hash) == .intact)
    }

    /// §6.11 case 23 — the only realistic cause is on-disk corruption, and the round is voided
    /// rather than silently altered.
    @Test("A mismatched hash is corrupt, and names the reason")
    func mismatchedHashIsCorrupt() throws {
        let (snapshot, _) = try makeSnapshot()
        #expect(snapshot.integrity(cap: 12, lawHash: 0xDEADBEEF)
                == .corrupt(.lawHashMismatch))
    }

    /// §6.11 case 29 — unreachable by construction, therefore corruption when it appears.
    @Test("A snapshot already at cap is corrupt, not a resumable round")
    func snapshotAtCapIsCorrupt() throws {
        let (snapshot, law) = try makeSnapshot(probes: Array(repeating: 22, count: 12))
        #expect(snapshot.integrity(cap: 12, lawHash: law.table.hash)
                == .corrupt(.probeCountAtCap))
    }

    @Test("A snapshot from another schema is corrupt before anything else is checked")
    func foreignSchemaIsCorrupt() throws {
        let (snapshot, law) = try makeSnapshot()
        var stale = snapshot
        stale.schema = Schema.current + 1
        #expect(stale.integrity(cap: 12, lawHash: law.table.hash) == .corrupt(.schemaMismatch))
    }

    /// The tie back to T07: this is exactly the Bool §6.1's `arming` row forks on.
    @Test("Integrity feeds the arming fork and nothing else")
    func integrityDrivesTheArmingFork() throws {
        let (snapshot, law) = try makeSnapshot()
        let holds = snapshot.integrity(cap: 12, lawHash: law.table.hash) == .intact
        #expect(RoundPhase.arming.transition(on: .snapshotRestored(integrityHolds: holds))
                == .to(.probing))
        #expect(RoundPhase.arming.transition(on: .snapshotRestored(integrityHolds: false))
                == .to(.settled(.voided)))
    }
}
```

`HunchCore/Tests/ArchiveTests/ArchiveValueTests.swift`:

```swift
import Foundation
import Testing
import Glyphs
import Laws
import LawGeneration
import Rounds
import Archive
import Persistence
import HunchTestSupport

@Suite("The archive value types", .tags(.unit, .presubmission))
struct ArchiveValueTests {

    @Test("CodexPage round-trips and its identity is the extension, not the syntax")
    func codexPageRoundTrips() throws {
        let page = Corpora.codexPage(band: .relational)
        let data = try JSONEncoder.store.encode(page)
        #expect(try JSONDecoder.store.decode(CodexPage.self, from: data) == page)
        #expect(try SchemaEnvelope(data).version == Schema.current)
    }

    @Test("A page stores the AST and never the table — that is what keeps the Codex small")
    func aPageStoresTheAST() throws {
        let page = Corpora.codexPage(band: .contextual)
        let bytes = try JSONEncoder.store.encode(page).count
        // §11.1: a contextual table is 8 KiB, an AST is ~40 B. A page that carried its table
        // would blow the shelf budget by two orders of magnitude.
        #expect(bytes < 1024)
    }

    @Test("Burnish sets exactly two things and touches nothing a *find* owns")
    func burnishIsNarrow() {
        var page = Corpora.codexPage(band: .literal)
        let before = page
        page.burnish()
        #expect(page.burnished)
        #expect(page.modesSeen != before.modesSeen)
        #expect(page.timesFound == before.timesFound)
        #expect(page.bestProbes == before.bestProbes)
        #expect(page.bestMarks == before.bestMarks)
        #expect(page.unfractured == before.unfractured)
        #expect(page.lastFoundAt == before.lastFoundAt)
    }

    @Test("Burnish latches — there is no un-burnishing")
    func burnishLatches() {
        var page = Corpora.codexPage(band: .literal)
        page.burnish()
        page.burnish()
        #expect(page.burnished)
    }

    @Test("RoundRecord carries what §6.10 lists and round-trips")
    func roundRecordRoundTrips() throws {
        let record = RoundRecord(v: Schema.current, seed: 1, mode: .probe, band: 5,
                                 servedDelta: 0.525, probes: [22, 137], strikes: 0,
                                 outcome: .inscribed(marks: 3, fracture: false),
                                 score: 1000, elapsed: 61,
                                 settledAt: Date(timeIntervalSinceReferenceDate: 0))
        let data = try JSONEncoder.store.encode(record)
        #expect(try JSONDecoder.store.decode(RoundRecord.self, from: data) == record)
    }

    @Test("A day-1 Profile is unformed: every axis at zero value and zero confidence")
    func dayOneProfileIsUnformed() {
        let profile = Profile()
        #expect(Profile.Axis.allCases.allSatisfy { profile[$0].value == 0 })
        #expect(Profile.Axis.allCases.allSatisfy { profile[$0].confidence == 0 })
        #expect(profile.ghost == nil)
    }

    @Test("The five axes are the five §11.10 places at fixed angles, in fixed order")
    func theAxisOrderIsLocked() {
        #expect(Profile.Axis.allCases
                == [.induction, .retention, .flexibility, .restraint, .tempo])
    }

    @Test("AnomalyLedger round-trips and keeps at most 400 entries")
    func anomalyLedgerRoundTrips() throws {
        var ledger = AnomalyLedger()
        for day in 0..<450 {
            ledger.record(DayEntry(day: Int64(day), outcome: .solvedClean, probes: 9, band: 4,
                                   settledAt: Date(timeIntervalSinceReferenceDate: 0)))
        }
        #expect(ledger.entries.count == 400)
        #expect(ledger.entries.last?.day == 449)     // the ring drops the oldest, never the newest
        let data = try JSONEncoder.store.encode(ledger)
        #expect(try JSONDecoder.store.decode(AnomalyLedger.self, from: data) == ledger)
        #expect(try SchemaEnvelope(data).version == Schema.current)
    }

    @Test("Every archive type carries a `v` the envelope can read", arguments: ArchiveFile.allCases)
    func everyTypeIsVersioned(_ file: ArchiveFile) throws {
        #expect(try SchemaEnvelope(file.encodedSample()).version == Schema.current)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter ProbeSnapshotTests` and `--filter ArchiveValueTests`.
Failures must be missing symbols. `noVerdictsOnDisk` is the one to watch: if it passes before
`ProbeSnapshot` exists, the string search is matching an empty document — check it fails for the
right reason once the type is there but stores `[Probe]`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the tests as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/ProbeSnapshot.swift` — `ProbeSnapshot`, its nested `CounterexampleRef`, `SnapshotIntegrity` |
| create | `HunchCore/Sources/Archive/CodexPage.swift` |
| create | `HunchCore/Sources/Archive/RoundRecord.swift` |
| create | `HunchCore/Sources/Archive/Profile.swift` — `Profile`, its nested `Axis` and `AxisState` |
| create | `HunchCore/Sources/Archive/AnomalyLedger.swift` — `AnomalyLedger`, `DayEntry`, `AnomalyOutcome`, `MonotonicAnchor` |
| create | `HunchCore/Tests/RoundsTests/ProbeSnapshotTests.swift` |
| create | `HunchCore/Tests/ArchiveTests/ArchiveValueTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `codexPage(band:)`, `law(band:index:)` seeded builders |
| modify | `HunchCore/Package.swift` — the `Archive` target (dependencies `["Glyphs", "Laws", "LawGeneration", "Rounds"]`) and `ArchiveTests` |
| modify | `DECISIONS.md` — `ProbeSnapshot` over `RoundSnapshot` |

## Implementation notes

### `ProbeSnapshot`, verbatim

Copy §6.10's declaration field for field, comments included — they are the reasoning and they belong
in the source. Add `Sendable`, `Equatable`, a hand-written `public init`, and `decodeIfPresent`
defaults on the two optional fields so a v2 that drops one still decodes (T04's additive-field
mechanism).

Three fields are the whole design and each needs its own doc line:

- **`law: LawNode`.** The resolved law, in RNF, ~40 B. Not a recipe. §6.10's argument is worth
  restating in the comment because it is not obvious: `avoid` is serving-layer state and it *moves*
  while a round is suspended, so regeneration from `(seed, band, targetδ, mode)` can legitimately
  resolve to a different law and destroy the round by its own consistency check.
- **`lawHash: UInt64`.** The extension hash. It is only ever asked *"is this the law I wrote
  down"*, never *"which law was this"*. Say that in the comment, because the second question is the
  one someone will try to answer with it.
- **`probes: [UInt8]`.** Glyph IDs only. Verdicts are recomputed from `law` on every resume, so
  every resume is a live evaluator check over the whole transcript and tampering achieves nothing.

`benchDraft: BenchLayout?` makes `Rounds` depend on `Bench` — that is correct and already in the
target's dependency list; `BenchLayout` is core precisely because G10 is a generation-time guardrail
(`08 §2`).

`CounterexampleRef` is a nested struct and not a tuple, for the reason §6.10 gives in the source: a
tuple cannot conform to `Codable` and cannot be extended, so synthesis would simply fail to compile.
Keep that sentence.

### Rehydration and integrity

```swift
extension ProbeSnapshot {
    /// Rebuilds the transcript, recomputing every verdict from the stored law (§6.10). The twin
    /// flags fall out of adjacency in `Ribbon.append`, so a resume cannot draw a different ribbon
    /// than the player left.
    ///
    /// - Complexity: O(n) in the probe count, one mask lookup per probe.
    public func ribbon(under law: Law) -> Ribbon {
        var ribbon = Ribbon(seedGlyph: Deck.glyph(id: seedGlyph))
        for id in probes {
            let glyph = Deck.glyph(id: id)
            ribbon.append(glyph, verdict: law.admits(glyph, after: ribbon.context) ? .admit : .reject)
        }
        return ribbon
    }

    /// §6.1's `arming` fork, as a value. Checked **before any frame is shown**.
    public func integrity(cap: Int, lawHash expected: UInt64) -> SnapshotIntegrity {
        if schema != Schema.current { return .corrupt(.schemaMismatch) }
        if lawHash != expected { return .corrupt(.lawHashMismatch) }
        // §6.11 case 29: unreachable by construction — the cap-th verdict goes straight to
        // revealing(.exhausted) and the slot is cleared at round end. So it is corruption.
        if probes.count >= cap { return .corrupt(.probeCountAtCap) }
        return .intact
    }
}

public enum SnapshotIntegrity: Sendable, Equatable {
    case intact
    case corrupt(Reason)
    public enum Reason: Sendable, Equatable { case schemaMismatch, lawHashMismatch, probeCountAtCap }
}
```

`ribbon(under:)` takes a `Law`, not a `LawNode`: the resolved table is what evaluates, and `Law` is
where E05·T02 put the cached metrics. Building it costs 20 ns stateless / 2 µs contextual, once per
resume — cite §5.7 in the comment rather than measuring again.

The order of the three checks is deliberate: schema first (a foreign file may not even mean what its
other fields say), then the hash, then the cap.

### `CodexPage`

§11.1's declaration verbatim, plus `Sendable`, `Equatable` and `v: Int`. The three things to get
right:

- **`lawKey` is identity and `driftPartner`/`driftHinge` are payload.** §11.1 spells out why: the
  same law found twice behind two different dead laws would otherwise mint two pages and break
  §11.2's premise. Keep that sentence in the source.
- **`seed` is not a field.** If someone adds it, `codexPageRoundTrips` will not catch it — so write
  the reason in the type's doc comment where a reviewer sees it.
- **`burnish()` is a method on the page**, exhaustively defined by §11.3: it sets `burnished = true`
  and ECHO's bit in `modesSeen`, and touches `timesFound`, `bestProbes`, `bestMarks`, `unfractured`
  and `lastFoundAt` **not at all**. `burnishIsNarrow` is the test; the method is four lines and it is
  the only mutation this task ships, because a duplicate re-inscription (§11.3) is E15·T06's.

### `Profile`

```swift
public struct Profile: Codable, Sendable, Equatable {
    public var v: Int
    /// §11.10 locks the order and the angles: Induction (−90°), Retention (−18°), Flexibility
    /// (54°), Restraint (126°), Tempo (198°). These five identifiers are **code-only** — §12.9
    /// forbids them entering the String Catalog in any form, visible or spoken.
    public enum Axis: String, CaseIterable, Codable, Sendable {
        case induction, retention, flexibility, restraint, tempo
    }
    /// `value ∈ [0,1]`, `n ∈ [0,60]` (§11.9). `n` is *confidence*, not a count of anything the
    /// player can see.
    public struct AxisState: Codable, Sendable, Equatable {
        public var value: Double
        public var confidence: Double
        public var lastSampleAt: Date?
    }
    private var axes: [Axis: AxisState]
    public var ghost: [Double]?            // §11.13: the 90-day contour, five radii
    public var ghostTakenAt: Date?
    public var lastRenderedRadii: [Double]?

    public subscript(axis: Axis) -> AxisState { get set }
}
```

**No update rule here.** `value += α(sample − value)` with `α = w·max(0.06, 1/(n+1))`, the `n` cap at
60 and the idle decay are all **E16·T06**. This task ships the shape, the day-1 state and the
subscript; a `Profile` that could update itself would put §11.9's normative table in two places.

`[Axis: AxisState]` encodes as a JSON object keyed by the raw strings, which is stable and readable;
a five-element array would be smaller and would silently reorder the day someone edits the enum.

### `AnomalyLedger`

§11.7's declaration verbatim: `v`, `highWaterDay`, `entries`, `streak`, `longestStreak`, `tally`,
`clockJumpCount`, `anchor`. Plus `DayEntry`, `enum AnomalyOutcome: Int, Codable`, and
`struct MonotonicAnchor { bootID: UUID; uptimeAtStamp: TimeInterval; wallAtStamp: Date }`.

`UUID` as a **stored type** is fine under the boundary rule; `UUID()` as a *call* is banned by check
6 and would be a violation — the boot ID is minted in `Modules/` and handed in. Say so in the
comment, because the next reader will see `UUID` and reach for the initialiser.

This task ships exactly two behaviours:

- `record(_:)` — appends and caps at 400, dropping the **oldest**. §11.13: "entries capped at 400
  (~16 KB); aggregates kept forever".
- `init()` — the day-1 ledger.

Everything else is **E16·T02**: the high-water rule, `observed == highWaterDay`, `.clockBehind`, jump
detection, and the sidecar's own bytes. Do not add a `var isPlayable` here; it needs today's date,
which this target cannot have.

### `RoundRecord`

§6.10's list, as a `Codable Sendable Equatable` struct: `v`, `seed`, `mode`, `band`, `servedDelta`,
`probes: [UInt8]`, `strikes`, `outcome: Outcome`, `score`, `elapsed`, `settledAt`. `marks` is **not**
a field — it is `outcome.marks` (T08), and a second copy would let a record disagree with its own
outcome (`W28`).

`servedDelta`, not `δ` and not `targetδ`: `08 §3`'s naming row, and §6.10 stores what was *served*.

### `Corpora` builders

Add `Corpora.codexPage(band:)` and `Corpora.law(band:index:)` to `HunchTestSupport` as
deterministic seeded builders over E06's generator. They are `let`s of immutable `Sendable` values or
pure functions — never a `static var` (`06 T10`: tests run parallel in one process).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ProbeSnapshotTests` green, all ten cases.
- [ ] `swift test --package-path HunchCore --filter ArchiveValueTests` green, all nine cases.
- [ ] `grep -n 'verdict' HunchCore/Sources/Rounds/ProbeSnapshot.swift` finds only comments — no
      stored property.
- [ ] `grep -n 'seed' HunchCore/Sources/Archive/CodexPage.swift` finds only the doc comment saying
      why it is absent.
- [ ] `grep -rn 'UUID()\|Date()' HunchCore/Sources/Archive HunchCore/Sources/Rounds` is empty.
- [ ] `grep -rn 'import Observation\|@Observable' HunchCore/Sources` is empty.
- [ ] The v1 fixture's `round-probe.json` decodes into a `ProbeSnapshot` and its `integrity(cap:
      lawHash:)` reports `.intact` — add that one case to `FixtureV1Tests` (T05) rather than here,
      so the fixture suite owns every fixture assertion.
- [ ] `swift build --package-path HunchCore` emits zero warnings; every `public struct` has a
      hand-written `public init`.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — re-run the tests after it. Refuse any proposal to give `Profile` its update
   rule or `AnomalyLedger` its high-water logic "while you are here"; both have owners in E16 and the
   normative table lives in §11.9/§11.7, not in two Swift files.
3. **Run `/code-review`** — fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E07/T09: ProbeSnapshot and the four archive value types"`

## Out of scope

- **When** a snapshot is written (after every committed verdict, after every strike resolution, on
  `scenePhase → .inactive`, draft on the `.inactive` write only) — **E10·T02**.
- The 900 ms re-entry beat — **E10·T03**.
- `utcDayIndex`, `anomalySeed(day:)`, `ANOMALY_SALT` and the band derivation — **E16·T01**; the
  high-water rule and `.clockBehind` — **E16·T02**.
- The Profile update rule, the five axis samples and the Restraint margin — **E16·T05/T06/T07**;
  the geometry — **E16·T08**.
- `Codex`, lazy shelf loading, the dedup authority and re-inscription — **E15·T01/T06**.
- The `Statistics` counters that share `stats.json` with the `RoundRecord` ring — **E16·T11**.
- DRIFT's extra snapshot fields and ECHO's cast snapshot — **E12·T09** and **E13·T09**, both of which
  extend `ProbeSnapshot` additively through `decodeIfPresent`, which is why T04's mechanism had to
  exist first.
