# T06 — Duplicates, fracture and burnish

| | |
|---|---|
| **Epic** | E15 — The Codex |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Duplicates (the archive half) · Fracture and burnish |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The whole task is an invariant expressed as a type: "a duplicate never mints a second page" has to be unrepresentable rather than remembered, and "a burnish sets exactly two fields" has to be a value somebody can diff. The skill owns `W28` (one type, not two parallel fields), `W29` (no `default:` over an owned enum), and the `A19` boundary that keeps this logic out of the view. |
| `hunch-chrome-and-meta` | `references/codex-page.md` §4, §5 and §6 own the three renders this task drives: the re-strike ring capped at 5+, the fracture hairline that a clean re-find stops drawing, and the burnished page as *"the app's one sanctioned exception to accent rationing"*. It also carries the ruling that a burnish draws **no** ring, which is the mistake this task is most likely to make. |

`hunch-motion-and-feedback` is **not** loaded. The round-end fly-in and the tick-strip re-flow are
E09·T11's beats; this task owns the state they land on.

## Objective

At the end of this task the archive's growth rule is a proved property rather than a policy: over any
sequence of finds, the number of pages equals the number of distinct lawKeys, and every re-find lands
in place — improving the bests, taking one re-strike ring, and healing a fracture when it was clean.
An ECHO round settled at three marks burnishes the page it was holding and changes exactly two
fields. Before this task the write path exists but nothing asserts it cannot fork; after it, forking
it is a failing test.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.3 | The Decision: *"a duplicate **never** creates a second page and is **never** refused as a round. It re-inscribes the existing page in place, improving `bestProbes`, `bestMarks`, `unfractured`, `modesSeen`, `timesFound`, `lastFoundAt`, and — on a first DRIFT find — writing `driftPartner` and `driftHinge`."* Plus the reason: a second page *"would make the extension stop being the identity, which breaks the shelf's whole premise"* |
| `GAME_DESIGN.md` | §11.3 | **Burnish, defined once.** An ECHO round settled at **3 marks** burnishes the pool law it was holding. *"Exhaustively, a burnish sets `burnished = true` and sets ECHO's bit in `modesSeen`. It does **not** touch `timesFound`, `bestProbes`, `bestMarks`, `unfractured` or `lastFoundAt`… It is therefore not a re-find and draws no re-strike ring."* `burnished` latches: there is no un-burnishing |
| `GAME_DESIGN.md` | §11.3 | Round-end presentation: one additional **re-strike ring** on the rim (5 rings, then a single filled ring meaning 5+); if `probes < bestProbes` the tick strip re-flows with the law-declared-correctly haptic; if not, no improvement mark and **no negative signal**. *"There is no 'already collected' state, no dust, no converting duplicates into anything"* |
| `GAME_DESIGN.md` | §11.1 | The Decision: re-finding a fractured page **clean** heals the fracture — `unfractured` latches true and the crack is not drawn. *"A permanent scar for one bad first encounter contradicts the improvement loop"* |
| `GAME_DESIGN.md` | §11.1 | `driftPartner` / `driftHinge` are written on the **first** DRIFT find and never overwritten; they are payload, never identity — keying on them would mint two pages for one law |
| `GAME_DESIGN.md` | §9.10 | ECHO *"no — burnishes an existing page at 3 marks"*; DRIFT's page carries both laws and the hinge; SIEVE inscribes only at `ratio ≥ 0.92` |
| `GAME_DESIGN.md` | §3.6 | Extension identity, and the 64-bit dedup hash **with a full compare on collision** — T01's policy, applied here |
| `GAME_DESIGN.md` | §4.5, §6.9 | A strike fractures the page: `unfractured` means *ever declared correct on the first declaration, zero strikes* |
| `ios-swift-guide/05-CONCURRENCY.md` | R12 | `await store.save(…)` is not a critical section — the resident index must be re-read after the suspension, never captured before it |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files: the mutation rules are core and provable on the host;
the archive-level count invariant needs `Codex`.

Create `HunchCore/Tests/ArchiveTests/PageMutationTests.swift`:

```swift
import Foundation
import Testing
import Archive
import LawGeneration            // Band, Mode
import HunchTestSupport

@Suite("Re-inscription, fracture and burnish — §11.1, §11.3", .tags(.unit, .presubmission))
struct PageMutationTests {

    private func find(_ band: Band = .relational, probes: UInt16, marks: UInt8,
                      strikes: Int = 0, mode: Mode = .probe, at day: TimeInterval = 0) -> Find {
        Find(law: Corpora.law(band: band, index: 0), band: band, skeleton: 0,
             mode: mode, probesUsed: probes, marks: marks, strikes: strikes,
             at: Date(timeIntervalSince1970: day), anomalyDay: nil,
             driftPartner: nil, driftHinge: nil)
    }

    // MARK: improvement

    @Test("a better find improves bestProbes and bestMarks; a worse one improves neither")
    func bestsAreMonotone() {
        var page = CodexPage(minting: find(probes: 12, marks: 2))
        page.reinscribe(find(probes: 9, marks: 3, at: 100))
        #expect(page.bestProbes == 9)
        #expect(page.bestMarks == 3)

        page.reinscribe(find(probes: 40, marks: 1, at: 200))
        #expect(page.bestProbes == 9, "a worse find never worsens a best")
        #expect(page.bestMarks == 3)
    }

    @Test("every re-inscription increments timesFound and moves lastFoundAt, never firstFoundAt")
    func bookkeeping() {
        var page = CodexPage(minting: find(probes: 12, marks: 2, at: 10))
        let firstFound = page.firstFoundAt
        page.reinscribe(find(probes: 40, marks: 1, at: 999))
        #expect(page.timesFound == 2)
        #expect(page.firstFoundAt == firstFound)
        #expect(page.lastFoundAt == Date(timeIntervalSince1970: 999))
    }

    @Test("firstFoundMode is written once and never overwritten")
    func firstModeLatches() {
        var page = CodexPage(minting: find(mode: .probe, probes: 12, marks: 2))
        page.reinscribe(find(mode: .drift, probes: 11, marks: 2, at: 50))
        #expect(page.firstFoundMode == .probe)
        #expect(page.modesSeen.contains(.probe))
        #expect(page.modesSeen.contains(.drift))
    }

    // MARK: fracture

    @Test("a strike fractures the page on minting")
    func strikeFractures() {
        let page = CodexPage(minting: find(probes: 14, marks: 1, strikes: 1))
        #expect(page.unfractured == false)
    }

    @Test("a later clean find HEALS the fracture and it latches (§11.1)")
    func cleanReFindHeals() {
        var page = CodexPage(minting: find(probes: 14, marks: 1, strikes: 1))
        #expect(page.unfractured == false)
        page.reinscribe(find(probes: 20, marks: 1, strikes: 0, at: 100))
        #expect(page.unfractured, "a clean re-find heals")
        page.reinscribe(find(probes: 13, marks: 2, strikes: 1, at: 200))
        #expect(page.unfractured, "and healing latches — a later strike does not re-crack it")
    }

    // MARK: DRIFT payload

    @Test("driftPartner and driftHinge are written on the FIRST drift find and never overwritten")
    func driftPayloadLatches() {
        let l1 = Corpora.law(band: .guarded, index: 41)
        var page = CodexPage(minting: find(mode: .probe, probes: 20, marks: 2))
        #expect(page.driftPartner == nil)

        var drift = find(mode: .drift, probes: 30, marks: 2, at: 100)
        drift.driftPartner = l1
        drift.driftHinge = 16
        page.reinscribe(drift)
        #expect(page.driftPartner == l1)
        #expect(page.driftHinge == 16)

        var later = find(mode: .drift, probes: 28, marks: 3, at: 200)
        later.driftPartner = Corpora.law(band: .guarded, index: 42)
        later.driftHinge = 4
        page.reinscribe(later)
        #expect(page.driftPartner == l1, "the reveal a page replays is stable forever")
        #expect(page.driftHinge == 16)
    }

    // MARK: burnish — the exhaustive one

    @Test("a burnish sets exactly two fields and touches nothing else (§11.3)")
    func burnishTouchesExactlyTwoFields() {
        var page = CodexPage(minting: find(probes: 14, marks: 1, strikes: 1, at: 10))
        let before = page
        page.burnish()

        #expect(page.burnished)
        #expect(page.modesSeen.contains(.echo))

        // Field by field. A new field on CodexPage must be classified here or this test is a lie,
        // so the comparison is written out rather than done with ==.
        #expect(page.lawKey == before.lawKey)
        #expect(page.law == before.law)
        #expect(page.band == before.band)
        #expect(page.skeleton == before.skeleton)
        #expect(page.firstFoundAt == before.firstFoundAt)
        #expect(page.lastFoundAt == before.lastFoundAt)
        #expect(page.firstFoundMode == before.firstFoundMode)
        #expect(page.timesFound == before.timesFound)
        #expect(page.bestProbes == before.bestProbes)
        #expect(page.bestMarks == before.bestMarks)
        #expect(page.unfractured == before.unfractured)
        #expect(page.driftPartner == before.driftPartner)
        #expect(page.driftHinge == before.driftHinge)
        #expect(page.anomalyDay == before.anomalyDay)
        #expect(page.modesSeen == before.modesSeen.union(.echo))
    }

    @Test("burnished latches — there is no un-burnishing")
    func burnishLatches() {
        var page = CodexPage(minting: find(probes: 14, marks: 1))
        page.burnish()
        page.reinscribe(find(probes: 30, marks: 1, strikes: 1, at: 500))
        #expect(page.burnished)
    }

    @Test("a burnish is not a re-find: it draws no re-strike ring")
    func burnishDrawsNoRing() {
        var page = CodexPage(minting: find(probes: 14, marks: 1))
        let rings = page.restrikeRings
        page.burnish()
        #expect(page.restrikeRings == rings)
    }

    // MARK: rings

    @Test("re-strike rings are min(timesFound, 5), then one filled ring meaning 5+",
          arguments: [(1, 1, false), (5, 5, false), (6, 1, true), (250, 1, true)])
    func ringCap(_ c: (found: Int, rings: Int, filled: Bool)) {
        var page = CodexPage(minting: find(probes: 14, marks: 1))
        while page.timesFound < UInt16(c.found) { page.reinscribe(find(probes: 14, marks: 1, at: 1)) }
        #expect(page.restrikeRings.count == c.rings)
        #expect(page.restrikeRings.isCapped == c.filled)
    }
}
```

Create `Modules/Tests/CodexFeatureTests/DuplicateInscriptionTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import CodexFeature
import ModulesTestSupport

@Suite("Duplicates never mint a second page — §11.3", .tags(.unit, .presubmission))
@MainActor
struct DuplicateInscriptionTests {

    @Test("page count equals the count of distinct lawKeys at every step of a find sequence")
    func pageCountTracksDistinctKeys() async {
        let store = RecordingPersistenceStore()
        let codex = Codex(store: store)
        await codex.load()

        var seen: Set<UInt64> = []
        for step in 0..<60 {
            let band = Band.allCases[step % Band.allCases.count]
            let find = Corpora.find(band: band, index: step % 7)     // deliberate repeats
            seen.insert(find.lawKey)
            _ = await codex.inscribe(find)
            #expect(codex.pageCount == seen.count, "diverged at step \(step)")
        }
        for band in Band.allCases {
            let shelf = await codex.shelf(band)
            #expect(shelf.pages.count == codex.count(band))
            #expect(Set(shelf.pages.map(\.lawKey)).count == shelf.pages.count)
        }
    }

    @Test("a duplicate re-inscribes in place with the shelf NOT resident")
    func duplicateWithUnloadedShelf() async {
        let find = Corpora.find(band: .systemic, index: 3)
        let store = RecordingPersistenceStore()
        var codex = Codex(store: store)
        _ = await { await codex.load(); return await codex.inscribe(find) }()

        // Relaunch: the index is on disk, the shelf is not resident.
        codex = Codex(store: store)
        await codex.load()
        #expect(codex.loadedShelf(.systemic) == nil)

        let outcome = await codex.inscribe(find)
        #expect(outcome == .reinscribed)
        #expect(codex.pageCount == 1)
        #expect(await codex.shelf(.systemic).pages.count == 1)
        #expect(await codex.shelf(.systemic).pages[0].timesFound == 2)
    }

    @Test("an index hit loads the shelf and compares the RNF before deciding (T01's policy)")
    func indexHitIsNotDecisive() async {
        let store = RecordingPersistenceStore()
        let codex = Codex(store: store)
        await codex.load()
        _ = await codex.inscribe(Corpora.find(band: .pair, index: 0))
        store.resetLog()

        _ = await codex.inscribe(Corpora.find(band: .pair, index: 0))
        #expect(store.readLog.isEmpty, "already resident — no second read")
    }

    @Test("a first find mints and reports .minted; the second reports .reinscribed")
    func inscriptionOutcome() async {
        let store = RecordingPersistenceStore()
        let codex = Codex(store: store)
        await codex.load()
        #expect(await codex.inscribe(Corpora.find(band: .literal, index: 1)) == .minted)
        #expect(await codex.inscribe(Corpora.find(band: .literal, index: 1)) == .reinscribed)
    }

    @Test("burnish never mints, never counts, and is a no-op on an unheld law")
    func burnishIsNotAMint() async {
        let store = RecordingPersistenceStore()
        let codex = Codex(store: store)
        await codex.load()
        let find = Corpora.find(band: .exclusive, index: 2)
        _ = await codex.inscribe(find)

        await codex.burnish(lawKey: find.lawKey)
        #expect(codex.pageCount == 1)
        #expect(await codex.shelf(.exclusive).pages[0].burnished)
        #expect(await codex.shelf(.exclusive).pages[0].timesFound == 1)

        await codex.burnish(lawKey: find.lawKey &+ 1)
        #expect(codex.pageCount == 1, "burnishing a law you do not hold mints nothing")
    }

    @Test("the resident index and the shelf agree after every write (05 R12)")
    func indexAndShelfAgree() async {
        let store = RecordingPersistenceStore()
        let codex = Codex(store: store)
        await codex.load()
        for step in 0..<20 {
            _ = await codex.inscribe(Corpora.find(band: .guarded, index: step % 5))
        }
        #expect(codex.count(.guarded) == (await codex.shelf(.guarded)).pages.count)

        let relaunched = Codex(store: store)
        await relaunched.load()
        #expect(relaunched.count(.guarded) == codex.count(.guarded), "the index was written back")
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter PageMutationTests` and
`swift test --package-path Modules --filter DuplicateInscriptionTests`

Expect missing `Find`, `CodexPage.burnish()`, `CodexPage.restrikeRings`, `Codex.inscribe(_:)`,
`Codex.burnish(lawKey:)`, `Inscription`, `Corpora.find(band:index:)`. If `CodexPage(minting:)` and
`reinscribe(_:)` already exist from E09·T11, **extend them**; `burnishTouchesExactlyTwoFields` is the
test that will tell you whether they were written correctly.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/Find.swift` — `Find`, the one value a round hands the archive |
| modify | `HunchCore/Sources/Archive/CodexPage.swift` — `init(minting:)`, `reinscribe(_:)`, `burnish()`, `restrikeRings` (**extend E09·T11's**) |
| create | `HunchCore/Sources/Archive/RestrikeRings.swift` — if E09·T11 left it inline |
| create | `HunchCore/Tests/ArchiveTests/PageMutationTests.swift` |
| modify | `HunchCore/Sources/HunchTestSupport/Corpora.swift` — `find(band:index:)` |
| modify | `Modules/Sources/CodexFeature/Codex.swift` — `inscribe(_:) -> Inscription`, `burnish(lawKey:)`, `Inscription` |
| modify | `Modules/Sources/CodexFeature/CodexPageModel.swift` — the burnished / fractured renders wired to the real fields |
| modify | `Modules/Sources/LoomFeature/RoundCommit.swift` — build a `Find` and call `codex.inscribe(_:)` |
| modify | `Modules/Sources/LoomFeature/EchoRoundView.swift` (or E13's settle path) — call `codex.burnish(lawKey:)` at 3 marks, and nothing else |
| create | `Modules/Tests/CodexFeatureTests/DuplicateInscriptionTests.swift` |
| modify | `tests.json` — page-count invariance, fracture healing, burnish's two fields, the 5+ ring cap |

## Implementation notes

### `Find` — one value, so a round cannot hand the archive a half-truth

```swift
public struct Find: Hashable, Sendable {
    public let law: LawNode                 // already in RNF
    public let band: Band
    public let skeleton: UInt16
    public let mode: Mode
    public let probesUsed: UInt16
    public let marks: UInt8                 // 1…3
    public let strikes: Int                 // 0 means clean
    public let at: Date                     // from `Now`, never `Date()`
    public let anomalyDay: Int64?
    public var driftPartner: LawNode?       // L₁, DRIFT only
    public var driftHinge: UInt16?

    public var lawKey: UInt64 { … }         // the §3.6 dedup hash of the extension
}
```

`W28`: one value instead of eleven parameters threaded through three call sites. It also makes the
`bestsAreMonotone` and `cleanReFindHeals` tests readable, which is not a small thing for the file that
encodes the improvement loop.

`at` comes from the injected `Now` at the call site — `Date()` is banned under `HunchCore/Sources/`
and the hygiene grep enforces it.

### `reinscribe`, field by field

§11.3 lists exactly what improves; write it as a straight-line function with no branches beyond the
`max`/`min`, and no `default:` anywhere:

```swift
public mutating func reinscribe(_ find: Find) {
    timesFound = timesFound == .max ? .max : timesFound + 1
    lastFoundAt = find.at
    bestProbes = min(bestProbes, find.probesUsed)
    bestMarks  = max(bestMarks,  find.marks)
    if find.strikes == 0 { unfractured = true }        // heals; latches
    modesSeen.insert(find.mode)
    if driftPartner == nil, let partner = find.driftPartner {
        driftPartner = partner
        driftHinge = find.driftHinge
    }
    if anomalyDay == nil { anomalyDay = find.anomalyDay }
}
```

Four things that are decisions rather than code:

1. **`unfractured` heals but never re-cracks.** §11.1's Decision is one-directional: a clean re-find
   sets it true, and a *later* strike does not set it false. Every other field on a page improves;
   a permanent scar for one bad first encounter contradicts the improvement loop. `cleanReFindHeals`
   asserts both halves.
2. **`bestMarks` is a `max` and `bestProbes` a `min`.** Obvious, and obviously worth a test — they
   are the two places a copy-paste inverts silently.
3. **`driftPartner` is written once.** §11.1: the pair is payload, never identity, and it is written
   on the **first** DRIFT find so *"the reveal a page replays is stable forever"* — the same rule that
   governs `firstFoundMode`. `driftPayloadLatches` is that sentence.
4. **`timesFound` saturates.** `UInt16` overflow on a re-find would be an absurd bug to ship, and the
   render caps at 5+ anyway.

### The burnish is the one that has to be exhaustive

```swift
/// §11.3, exhaustively: sets `burnished` and ECHO's `modesSeen` bit, and touches nothing else.
/// It is **not** a re-find: no `timesFound`, no bests, no `lastFoundAt`, and no re-strike ring.
public mutating func burnish() {
    burnished = true
    modesSeen.insert(.echo)
}
```

Two lines, and a test that checks every other field individually. The field-by-field spelling in
`burnishTouchesExactlyTwoFields` is deliberate: a `==` against a mutated copy would pass if a future
field were added and also mutated, and this is precisely the function where "and nothing else" is the
specification.

`burnished` **latches** — there is no un-burnishing (§11.3) — and its render is register 1's brass
(T05), which `codex-page.md` §6 calls *"the app's one sanctioned exception to accent rationing"*: it
paints every tile stroke, which is legitimate because the burnish *is* the page's meaning and there
is no competing accent on the screen. Say so at the call site, because the next reader will otherwise
assume it is a bug.

### `Codex.inscribe(_:)` — the write path, with `05 R12` honoured

```swift
public enum Inscription: Hashable, Sendable { case minted, reinscribed }

public func inscribe(_ find: Find) async -> Inscription {
    let shelf = await shelf(find.band)                     // one file, at most once (T01)
    var pages = shelf.pages
    let outcome: Inscription

    if let i = pages.firstIndex(where: { $0.lawKey == find.lawKey
                                      && $0.law == find.law.renderedNormalForm }) {
        pages[i].reinscribe(find)                          // §11.3 — in place
        outcome = .reinscribed
    } else {
        pages.append(CodexPage(minting: find))
        outcome = .minted
    }

    let updated = CodexShelf(band: find.band, pages: pages)
    shelves[find.band] = updated                           // publish BEFORE the await, 05 R12
    var next = index
    next.insert(lawKey: find.lawKey, band: find.band)
    index = next

    try? await store.save(updated, to: .codexShelf(find.band))
    try? await store.save(index, to: .codexIndex)
    return outcome
}
```

Three points:

- **The RNF comparison is T01's collision policy, applied.** An index hit is not decisive; equality of
  `renderedNormalForm` is. The cost is bounded because the shelf is already loaded — a find lands on
  the band being played, and `shelf(_:)` parses at most one file.
- **`05 R12`.** The in-memory publish happens *before* the two `await`s so a `body` re-evaluating
  during the save sees a consistent archive; and nothing read before the first `await` is used after
  it. A write failure leaves the in-memory state ahead of disk, which is §11.13's disk-full behaviour
  verbatim: *"in-memory state is retained, one non-modal instrument warning is shown, the write is
  retried at the next round end"* — surface it through `StoreHealth`, not through a thrown error.
- **`insert` on the index is idempotent** (T01), so a re-inscription does not move a count. That is
  what makes `indexAndShelfAgree` hold after a relaunch.

`burnish(lawKey:)` is the same shape minus the mint arm, and it is a **no-op on an unheld law** — an
ECHO pool member is by construction a held law, but a stale pool across a "Clear Codex" is reachable,
and minting a page from a burnish would be a second identity path.

### Round-end presentation, and what must **not** be added

§11.3's last paragraph is a list of absences and each one is enforceable:

- One additional **re-strike ring** on the rim. `VerdictRing.draw`'s `.restrike(count:)` already caps
  at `C.VerdictRing.restrikeCap` and draws one filled ring at 6+.
- If `probes < bestProbes`, the tick strip re-flows with the law-declared-correctly haptic. If not,
  **the page settles with no improvement mark and no negative signal.**
- **No "already collected" state, no dust, no converting duplicates into anything**, and no "new",
  "duplicate" or "×3" badge on a thumbnail (`extension-thumbnail.md` §7).

The haptic and the fly-in belong to E09·T11 and E20; this task's obligation is that `Inscription` is
returned so those beats can branch on it without re-deriving it.

### ECHO's call site

E13's settle path calls `codex.burnish(lawKey:)` **iff** the round settled at 3 marks (§8.7, §9.10),
and calls nothing else on the Codex. It does not build a `Find`; there is no find. If E13 currently
constructs a `Find` for ECHO, delete it — that is the bug §11.3 spends a paragraph preventing.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter PageMutationTests` green, all nine tests.
- [ ] `swift test --package-path Modules --filter DuplicateInscriptionTests` green, all six tests.
- [ ] `grep -rn "func burnish" HunchCore/Sources/Archive/CodexPage.swift` shows a body of exactly two statements.
- [ ] `grep -rn "timesFound\|bestProbes\|bestMarks\|lastFoundAt\|unfractured" HunchCore/Sources/Archive/CodexPage.swift | sed -n '/func burnish/,/^}/p'` returns nothing.
- [ ] `grep -rn "Find(" Modules/Sources/LoomFeature/EchoRound*.swift Modules/Sources/LoomFeature/Echo*.swift 2>/dev/null` returns nothing — ECHO never builds a find.
- [ ] `grep -rn "append\|insert" Modules/Sources/CodexFeature/Codex.swift | grep -i "page"` shows exactly one mint site.
- [ ] `grep -rn "Date()" HunchCore/Sources/Archive/` returns nothing.
- [ ] `grep -rn "default:" HunchCore/Sources/Archive/CodexPage.swift` returns nothing.
- [ ] `tests.json` carries: page-count-equals-distinct-keys, re-inscription with an unloaded shelf, monotone bests, fracture healing and its latch, drift payload latching, burnish's exactly-two-fields, burnish-draws-no-ring, and the 5+ ring cap.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E15/T06: re-inscription in place, fracture healing and the two-field burnish"`

## Out of scope

- **`InscriptionView`, the round-end fly-in, the t = 0 write sequence and the storage-full hairline** — **E09·T11**; this task supplies the `Inscription` result it branches on.
- **ECHO's 3-mark condition, `setF1`, the LIS order term and the pool** — **E13·T08/T01**; this task supplies the `burnish(lawKey:)` seam.
- **DRIFT's `L₁`, `t_hinge` and the hinge reveal replayed from a page** — **E12·T02/T08**; this task only stores the payload and refuses to overwrite it.
- **The Anomaly's `anomalyDay` derivation and its ledger** — **E16·T01/T02**; this task only latches the field.
- **The haptic and the tick-strip re-flow animation** — **E20·T05/T08**.
- **Slot maps, the sealed rim and the fill arc's scale** — **T07**.
- **The facet that filters on `unfractured` or `timesFound`** — **T08**.
