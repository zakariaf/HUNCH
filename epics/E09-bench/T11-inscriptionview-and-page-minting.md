# T11 — `InscriptionView` and page minting

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T10 |
| **Delivers** | §14.1 `18 screens` (screen 8, `InscriptionView`) · `Duplicates` · `CodexPage` model (the write path) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-chrome-and-meta` | The Inscription is the one round-end screen and it is **chrome** — `references/codex-page.md` owns the page composite it docks, `references/numeral-readout.md` owns whether a probe count is a numeral or a tick row (it is a tick row on screen and a numeral only in VoiceOver), and `references/instrument-bar.md` owns the strip. It also carries the rule that a bar's `64` is a *resolved* height, never a literal. |
| `hunch-swift-code` | The commit happens in `Round` and the writes go through the injected `PersistenceStore`; this skill owns the composition-root rule (no singleton, no ambient store) and the `A18`/`A19` boundary that keeps `Round` thin. `CodexPage` is core and `Codex` the observable archive is not — that split is why the write path can be tested in `HunchCore`. |
| `hunch-shared-marks` | The re-strike ring is `VerdictRing.draw`'s Codex site and the `bestProbes` strip is `TickRow.draw` — both already have one owning function. A round-end screen that draws its own ring is the drift the skill exists to stop. |
| `hunch-motion-and-feedback` | The standing rule this task exists to honour: *"The model never waits on an animation … Animation is decoration over settled state, which is why it can be skipped, interrupted, backgrounded or replayed from the Codex without changing a byte."* |

## Objective

At the end of this task a round ends on one screen for both outcomes, and everything the round
produced — the Codex page, the θ update, the five Profile accumulators and the novelty-ring entry —
is already on disk before the first frame of the reveal, so backgrounding it loses nothing. Before
this task the reveal settles onto nothing; after it, a win mints or re-inscribes a page and a loss
reads as a reading rather than a punishment.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.1 | The Decision: *"the round-end screen is **the Inscription**, in both outcomes — because §5.4 already says a correct declaration 'is inscribed', and giving win and loss the same screen (differing only in whether a page is minted) removes a whole failure-state layout and makes losing feel like a reading rather than a punishment."* |
| `GAME_DESIGN.md` | §12.2 | Screen 8's row: contents, entries (Seal correct, second strike, cap reached), exits (*again*, Frame key, minted-page key), primary action *"tap **again** → next round, same mode"*, and **"No Profile readout of any kind"** |
| `GAME_DESIGN.md` | §6.8 | *"comparison performed and committed — and with it the Codex page, the θ update, the Profile accumulators and the novelty ring entry"* at **t = 0**; §6.1's invariant that the model never waits on an animation |
| `GAME_DESIGN.md` | §6.10 | What is persisted at end of round, in order, with the mid-round snapshot slot cleared **last**, after every other write succeeds |
| `GAME_DESIGN.md` | §6.11 case 6 | *"Backgrounded during the 2,480 ms reveal — the page was written at **t = 0**, on the Seal press … Resume lands on the round card; the reveal is replayable from the Codex page."* |
| `GAME_DESIGN.md` | §11.1 | `CodexPage`'s fields, what a page stores against what a round stores, and that `seed` is **not** a page field |
| `GAME_DESIGN.md` | §11.3 | The Decision: *"a duplicate **never** creates a second page and is **never** refused as a round. It re-inscribes the existing page in place"*; the improved fields; the round-end presentation with **one additional re-strike ring** (5 rings, then a single filled ring meaning 5+); *"There is no 'already collected' state, no dust, no converting duplicates into anything"* |
| `GAME_DESIGN.md` | §11.1 | Re-finding a fractured page **clean** heals the fracture — `unfractured` latches true and the crack is not drawn |
| `GAME_DESIGN.md` | §11.13 | The write order and the storage-full path: *"The round continues in memory. A hairline warning strip appears in the **chrome**, never in the play surface"* |

## TDD — the test comes first

**Step 1 — write the failing tests.** The commit ordering is a `LoomFeature` fact; the page algebra is
core.

Create `HunchCore/Tests/ArchiveTests/CodexPageInscriptionTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Laws
import Rounds
import HunchTestSupport

@Suite("Page minting and re-inscription", .tags(.unit, .presubmission))
struct CodexPageInscriptionTests {

    // §11.1: "A page is one law, identified by its extension. One law, one page, forever."
    @Test("A first find mints one page keyed on the extension")
    func firstFind() throws {
        let law = try #require(Corpora.statelessAtom)
        let page = CodexPage(minting: law, band: .literal, probes: 5, marks: 3,
                             fracture: false, mode: .probe, at: .fixture)

        #expect(page.lawKey == LawTable(law).key)
        #expect(page.timesFound == 1)
        #expect(page.bestProbes == 5)
        #expect(page.unfractured == true)
        #expect(page.firstFoundAt == page.lastFoundAt)
    }

    // §11.3: "a duplicate NEVER creates a second page … It re-inscribes the existing page
    // in place, improving bestProbes, bestMarks, unfractured, modesSeen, timesFound,
    // lastFoundAt."
    @Test("A duplicate re-inscribes in place and never mints a second page")
    func duplicateReinscribes() throws {
        let law = try #require(Corpora.statelessAtom)
        var page = CodexPage(minting: law, band: .literal, probes: 9, marks: 1,
                             fracture: true, mode: .probe, at: .fixture)

        page.reinscribe(probes: 5, marks: 3, fracture: false, mode: .drift, at: .fixture.adding(days: 1))

        #expect(page.timesFound == 2)
        #expect(page.bestProbes == 5)
        #expect(page.bestMarks == 3)
        #expect(page.lastFoundAt > page.firstFoundAt)
        #expect(page.modesSeen.contains(.probe) && page.modesSeen.contains(.drift))
        #expect(page.firstFoundMode == .probe, "never overwritten")
    }

    // §11.1: "re-finding a fractured page clean HEALS the fracture — `unfractured` latches
    // true and the crack is not drawn."
    @Test("A clean re-find heals a fracture, and a later strike does not re-break it")
    func fractureHeals() throws {
        var page = CodexPage(minting: try #require(Corpora.statelessAtom), band: .literal,
                             probes: 9, marks: 1, fracture: true, mode: .probe, at: .fixture)
        #expect(page.unfractured == false)

        page.reinscribe(probes: 8, marks: 2, fracture: false, mode: .probe, at: .fixture)
        #expect(page.unfractured == true)

        page.reinscribe(probes: 12, marks: 1, fracture: true, mode: .probe, at: .fixture)
        #expect(page.unfractured == true, "unfractured latches; it is never un-healed")
    }

    // §11.3: a worse re-find improves nothing and signals nothing negative.
    @Test("A worse re-find leaves the bests alone")
    func worseReFindDoesNotRegress() throws {
        var page = CodexPage(minting: try #require(Corpora.statelessAtom), band: .literal,
                             probes: 5, marks: 3, fracture: false, mode: .probe, at: .fixture)
        page.reinscribe(probes: 40, marks: 1, fracture: false, mode: .probe, at: .fixture)

        #expect(page.bestProbes == 5)
        #expect(page.bestMarks == 3)
        #expect(page.timesFound == 2)
    }

    // §11.3: "5 rings, then a single filled ring meaning 5+."
    @Test("Re-strike rings cap at five and then become one filled ring", arguments: 1...9)
    func restrikeRingCap(_ timesFound: Int) {
        let rings = RestrikeRings(timesFound: UInt16(timesFound))
        if timesFound <= 5 {
            #expect(rings.outlined == timesFound - 1)
            #expect(rings.isFilled == false)
        } else {
            #expect(rings.outlined == 0)
            #expect(rings.isFilled == true)
        }
    }

    // §11.1: seed is NOT a page field; the table is never stored.
    @Test("A page stores the AST and neither the seed nor the table")
    func pageStoresTheAST() throws {
        let page = CodexPage(minting: try #require(Corpora.statelessAtom), band: .literal,
                             probes: 5, marks: 3, fracture: false, mode: .probe, at: .fixture)
        let json = try JSONEncoder().encode(page)
        let object = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        #expect(object["seed"] == nil)
        #expect(object["table"] == nil)
        #expect(object["law"] != nil)
        #expect(json.count < 512, "an AST is ~40 B; a table is 8 KiB")
    }
}
```

Create `Modules/Tests/LoomFeatureTests/InscriptionCommitTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature

@Suite("The t = 0 commit", .tags(.unit, .presubmission))
@MainActor
struct InscriptionCommitTests {

    // §6.8 / §6.11 case 6: "the page was written at t = 0, on the Seal press, along with
    // the θ update and the novelty entry."
    @Test("Everything is on disk before the first frame of the reveal")
    func committedAtTZero() async throws {
        let store = InMemoryPersistenceStore()
        let round = Round.fixture(store: store, band: .literal)
        round.openBench()
        round.buildCorrectDraft()

        round.seal()                                     // t = 0, no animation has run

        #expect(round.phase == .sealing)
        let shelf = try await store.load(CodexShelf.self, from: .codexShelf(.literal))
        #expect(shelf.pages.count == 1)
        #expect(try await store.load(Ladder.self, from: .ladder).noveltyRing.contains(round.lawKey))
        #expect(try await store.load(Profile.self, from: .profile).sampleCount > 0)
    }

    // §11.13: the mid-round snapshot slot is cleared LAST, after every other write succeeds.
    @Test("The snapshot slot is cleared last")
    func writeOrder() async throws {
        let store = RecordingPersistenceStore()
        let round = Round.fixture(store: store, band: .literal)
        round.openBench(); round.buildCorrectDraft(); round.seal()

        let clears = store.operations.lastIndex(of: .clear(.round(.probe)))
        let writes = store.operations.indices.filter { store.operations[$0].isWrite }
        #expect(clears != nil)
        #expect(writes.allSatisfy { $0 < clears! })
    }

    // §6.11 case 6: backgrounding mid-reveal changes not one byte.
    @Test("Backgrounding during the reveal loses nothing")
    func backgroundingMidReveal() async throws {
        let store = InMemoryPersistenceStore()
        let round = Round.fixture(store: store, band: .literal)
        round.openBench(); round.buildCorrectDraft(); round.seal()
        let atTZero = await store.snapshotOfEverything()

        round.advance(to: .milliseconds(1_200))          // mid-reveal
        round.scenePhaseChanged(to: .background)

        #expect(await store.snapshotOfEverything() == atTZero)
    }

    // §12.1: ONE screen for both outcomes, differing only in whether a page is minted.
    @Test("One round-end screen serves every outcome", arguments: Outcome.settling)
    func oneScreenBothOutcomes(_ outcome: Outcome) {
        let model = InscriptionView.Model(outcome: outcome, page: outcome.mintsAPage ? .fixture : nil)
        #expect(model.screen == .inscription)
        #expect((model.pageBlock != nil) == outcome.mintsAPage)
        #expect(model.primaryAction == .again)
    }

    // §12.2, screen 8: "No Profile readout of any kind" — §11.11 P6.
    @Test("The Inscription shows no Profile readout and no band number")
    func noProfileNoBand() {
        let model = InscriptionView.Model(outcome: .inscribed(marks: 3, fracture: false),
                                          page: .fixture)
        #expect(model.contains(.profileContour) == false)
        #expect(model.contains(.bandNumeral) == false)
        #expect(model.contains(.percentage) == false)
    }

    // §11.3: "the existing page flies in already inscribed and takes one additional
    // re-strike ring … no 'already collected' state, no dust."
    @Test("A duplicate round ends with a re-strike ring and no second page")
    func duplicateRoundEnd() async throws {
        let store = InMemoryPersistenceStore()
        let round = Round.fixture(store: store, band: .literal)
        round.openBench(); round.buildCorrectDraft(); round.seal()
        let again = Round.fixture(store: store, band: .literal, law: round.law)
        again.openBench(); again.buildCorrectDraft(); again.seal()

        let shelf = try await store.load(CodexShelf.self, from: .codexShelf(.literal))
        #expect(shelf.pages.count == 1)
        #expect(shelf.pages[0].timesFound == 2)
        #expect(InscriptionView.Model(outcome: again.outcome!, page: shelf.pages[0])
                    .restrikeRings.outlined == 1)
    }

    // §11.13 case 22: a failed write does not stop the round; the warning is CHROME.
    @Test("A full disk keeps the round in memory and warns in the chrome only")
    func storageFull() async throws {
        let store = FailingPersistenceStore()
        let round = Round.fixture(store: store, band: .literal)
        round.openBench(); round.buildCorrectDraft(); round.seal()

        #expect(round.phase == .sealing, "the round proceeds")
        #expect(round.outcome != nil, "the outcome is settled in memory")
        #expect(round.storeHealth == .writeFailed)
        #expect(InscriptionView.Model(outcome: round.outcome!, page: nil)
                    .warningStripIsInChrome)
    }
}
```

**Step 2 — run them and watch them fail.**

```bash
swift test --package-path HunchCore --filter CodexPageInscriptionTests
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:LoomFeatureTests/InscriptionCommitTests
```

`value of type 'CodexPage' has no member 'reinscribe'` is the right first failure.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Archive/CodexPage.swift` — `init(minting:…)`, `reinscribe(…)`, `RestrikeRings` |
| create | `HunchCore/Sources/Archive/CodexShelf.swift` — the per-band page container the write path appends to (**if E07·T09 did not ship it**) |
| create | `Modules/Sources/LoomFeature/InscriptionView.swift` — one screen, both outcomes |
| create | `Modules/Sources/LoomFeature/RoundCommit.swift` — the t = 0 write sequence in §11.13's order |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `seal()` calls the commit before the phase change |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — the read-only presentation at `C.RuleTile.codexScale` |
| create | `HunchCore/Tests/ArchiveTests/CodexPageInscriptionTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/InscriptionCommitTests.swift` |
| modify | `HunchCore/Sources/Persistence/InMemoryPersistenceStore.swift` — `snapshotOfEverything()` for the byte-identity test |
| create | `Modules/Tests/LoomFeatureTests/Support/RecordingPersistenceStore.swift` — records the operation order; `FailingPersistenceStore` beside it |
| modify | `tests.json` — the t = 0 commit, the write order and the duplicate rule |

## Implementation notes

### The commit is a sequence, and its order is §11.13's

```swift
/// §6.8: performed at t = 0 of the Seal press, before a pixel moves.
/// §11.13: `round.json` first, the snapshot slot cleared LAST, after every other write.
@MainActor
func commit(_ outcome: Outcome, of round: RoundState) async {
    // 1. the RoundRecord, appended to the run log
    // 2. the CodexPage — minted or re-inscribed in place (inscribed only)
    // 3. the θ update                       (E11 owns the estimator; this calls it)
    // 4. the five Profile accumulators      (E16 owns the axes; this calls them)
    // 5. the novelty ring entry             (E11 owns the ring; this appends)
    // 6. …then, and only then, clear the mid-round snapshot slot
}
```

Two things about that ordering:

- **The clear is last** because a crash between any write and the clear leaves a resumable round,
  which is recoverable; a crash after the clear and before the writes leaves nothing, which is not.
- **Steps 3–5 do not exist yet.** E11 ships the estimator and the ring, E16 the Profile axes. Ship the
  sequence with `// E11` / `// E16` seams that call injected closures defaulting to no-ops, and ship
  the *test* that asserts they are called at t = 0 with a spy. That way the ordering invariant is
  locked before the work that would break it arrives.

`Round.seal()` is **synchronous** and returns after the phase change; the writes are launched as a
`Task` that the round holds, and `RoundCommit` computes every value it will write **before** that
`Task` starts. The distinction matters: what must happen at t = 0 is that the state is *decided*; the
`write(2)` may land a millisecond later. Nothing after t = 0 may change what gets written.

### One screen, both outcomes

`InscriptionView.Model` differs in exactly one place: `pageBlock` is `nil` on a loss. Not a second
view, not an `if outcome == .broken { LossView() }`. §12.1's whole reason for the decision is that a
separate failure layout is a layout, a set of states and a tone the game does not want.

What it shows (§12.2 screen 8):

- the staggered rule-tile reveal of the true law — read-only tiles at `C.RuleTile.codexScale`, the
  same drawing T02 shipped, **scaled as a transform, never re-laid-out**;
- that law's Assay with the ribbon overlaid;
- the Seal marks, the probes-vs-par tick row, the fracture mark;
- on a win, the page block with its re-strike rings;
- on an Anomaly round, the 28-cell ribbon and the tally strip appended below — **E16·T04**'s, hooked
  here.

What it must never show: **any Profile readout** (§11.11 P6 — the portrait is not a grade and a
round-end grade is exactly what it would read as), any band numeral, any percentage, any global meter.
The test asserts all three absences, because each is a thing somebody will reasonably try to add.

The primary action is *again* → next round, same mode. Exits are *again*, the Frame key, and the
minted-page key (→ `CodexPageView`, **E15**).

### Numerals: where they are allowed here

`hunch-chrome-and-meta`'s `numeral-readout.md` holds the resolved site table, and the Inscription's
instrument strip is on it. Probe count against par renders as a **tick row** with a mono numeral
beside it; Seal marks render as **pips**, never as "3". The date is `Date.FormatStyle`. Everything
else on this screen is a drawing.

The reveal *region* of the Inscription is a play surface and carries **zero** characters — check 7's
file list includes `InscriptionView.swift`, so a `Text` outside `.accessibility*` in the reveal region
fails the build. The instrument strip is chrome and is where the numerals live. If that split is
awkward in one file, split the file — do not weaken the check.

### Duplicates, exhaustively

`CodexPage.reinscribe` improves `bestProbes`, `bestMarks`, `unfractured`, `modesSeen`, `timesFound`
and `lastFoundAt`, and on a **first** DRIFT find writes `driftPartner` and `driftHinge` (never
overwritten — the same rule that governs `firstFoundMode`). It touches nothing else.

It is **not** the same operation as a burnish. §11.3 defines a burnish as what a mode that cannot mint
pages records on a page that already exists: exactly one mode does it, an ECHO round settled at 3
marks, and it sets `burnished = true` and ECHO's bit in `modesSeen` **and nothing else** — not
`timesFound`, not the bests, not `lastFoundAt`. It draws no re-strike ring. Ship `reinscribe` here and
leave `burnish` to **E15·T06**; putting both behind one method is how the two start sharing a field.

The re-strike ring is `VerdictRing.draw`'s Codex site. Five outlined rings, then **one filled ring**
meaning 5+ — so `RestrikeRings(timesFound:)` returns `(outlined: 0, isFilled: true)` past five, not
five outlined plus a filled one.

If `probes < bestProbes` the tick strip re-flows to the new count with the law-declared-correctly
haptic; if not, the page settles with **no improvement mark and no negative signal**. There is no
"already collected" state, no dust, and nothing converts duplicates into anything.

### Storage full

§11.13 case 22: the round continues in memory, the completed-round writes are queued and retried at
the next round boundary and on `.background`, and a hairline warning strip appears **in the chrome,
never in the play surface**. `storeHealth` is an `@Entry` environment value (`04 A27`, `08 §6`) that
E10·T01's composition root installs; this task reads it and draws the strip in the Inscription's
instrument bar.

The round does **not** fail, roll back, or show an alert. The player finished the round; the disk is
the app's problem.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter CodexPageInscriptionTests` green.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/InscriptionCommitTests` green.
- [ ] `grep -n 'func seal' Modules/Sources/LoomFeature/Round.swift` shows a **synchronous**
      signature, and everything it writes is computed before the `Task` starts.
- [ ] `grep -rn 'Text(\|Label(' Modules/Sources/LoomFeature/InscriptionView.swift` returns hits only
      inside `.accessibility*` modifiers **or** inside the instrument-strip type, and check 7 passes.
- [ ] `grep -rn 'burnish' HunchCore/Sources/Archive/CodexPage.swift` returns the stored property only
      — no `burnish()` method in this task.
- [ ] `grep -rn 'ProfileView\|contour\|axis' Modules/Sources/LoomFeature/InscriptionView.swift`
      returns nothing.
- [ ] `tests.json` carries `inscription.commit-at-t-zero`, `inscription.snapshot-cleared-last` and
      `codex.duplicate-never-mints-a-second-page`.
- [ ] In the simulator: win a round, background the app at ~1.2 s into the reveal, force-quit,
      relaunch — the page is in the Codex with its marks.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `swift test --package-path HunchCore --filter CodexPageInscriptionTests && xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:LoomFeatureTests/InscriptionCommitTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T11: InscriptionView, the t = 0 commit and duplicate re-inscription"`

## Out of scope

- **The `Codex` observable, shelves, browse, thumbnails and `CodexPageView`.** **E15**. This task
  writes a page into a shelf file; E15 reads and renders the archive.
- **Burnish, slot maps and the facet bar.** **E15·T06**–**T08**.
- **The θ estimator, the novelty ring's contents and the serving layer.** **E11**. This task calls the
  seams and asserts they are called at t = 0.
- **The five Profile axes and their sample formulas.** **E16·T05**–**T07**.
- **The Anomaly strip appended below the Inscription.** **E16·T04**; the hook is here.
- **The Reveal → Codex page shared element transition.** **E15**; beat 5's thumbnail (T10) is the
  shared element it will match.
- **Navigation out of the Inscription** — *again*, the Frame key, the play key and the ≤ 2-tap rule.
  **E17·T01**–**T03**.
- **Resume, abandon and the mid-round snapshot's own writes.** **E10·T02**–**T04**; this task owns
  only the *clearing* of the slot, last.
