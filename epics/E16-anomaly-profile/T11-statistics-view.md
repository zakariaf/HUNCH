# T11 — `StatisticsView`

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T10 |
| **Delivers** | Statistics screen (PROFILE) · 18 screens (SCREENS / NAVIGATION) — screen 13 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | This is one of the four screens allowed a stock component, and a stock `List` is the one place in the app where the OS picks a colour and picks wrong. The tokens skill owns the container neutralisation and the `type.numeral` role that carries both SF Mono *and* `monospacedDigit`. |
| `hunch-chrome-and-meta` | Owns the screen: `references/stock-controls.md` §7 is `StatisticsView`'s spec including the two things it must not contain, `references/numeral-readout.md` site 3 is where its digits are licensed, and `references/rules-and-boundaries.md` owns the section separators. |

## Objective

At the end of this task the one screen where numbers are allowed to live exists: five sections —
MODES · ROUNDS · BANDS · CODEX · ANOMALY — nineteen labelled rows and column heads, read-only because
every destructive action lives in Settings → DATA, with mono numerals and every value formatted
through `Date.FormatStyle`, `NumberFormatter` or `Measurement`. It contains no θ, no difficulty, no
band framed as a level, no percentile, and no statistic about attendance of any kind.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.12 | the whole screen: five sections, 19 labelled rows and column heads, the tracked list, the **not tracked at all** list, the no-usage-time decision, read-only-ness, and the three content resets this data belongs to |
| `GAME_DESIGN.md` | §12.9 | the key budget: 5 section headers + 19 row and column labels = 24 keys; the four mode names are **wordmarks**, not translation units |
| `GAME_DESIGN.md` | §12.2, §12.3 | screen 13's row — entry from the Profile's instrument bar, exit back or via the play key, no primary action; and the ≤ 2-tap rule |
| `GAME_DESIGN.md` | §11.13 | `stats.json`'s row: the counters §11.12 renders plus a 200-entry `recentRounds` ring; *"the counters are authoritative and monotone; the ring is for the statistics screen's run figures and the harness, and is never the source of an aggregate"* |
| `GAME_DESIGN.md` | §10.5 | why no band number is ever surfaced, and the three signals that exist instead |
| `GAME_DESIGN.md` | §11.11 P1–P8 | the same grade prohibitions, applied to a screen that *does* carry numerals |
| `GAME_DESIGN.md` | §13.11 | Dynamic Type: rows grow, `minimumScaleFactor` is 1.0 everywhere, nothing shrinks |
| `hunch-chrome-and-meta` | `references/stock-controls.md` §1, §3, §7, §8 | container neutralisation, rows and separators, the screen's own section, Dynamic Type and VoiceOver |
| `hunch-chrome-and-meta` | `references/numeral-readout.md` §2–§4 | site 3; why `monospacedDigit` is not redundant on SF Mono; the formatting rule |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files. The counters are core; the screen's shape is not.

`HunchCore/Tests/ArchiveTests/StatisticsTests.swift`:

```swift
import Foundation
import Testing
import Archive
import LawGeneration
import Rounds
import HunchTestSupport

@Suite("Statistics counters — §11.12 and §11.13", .tags(.unit, .presubmission))
struct StatisticsTests {

    private let epoch = Date(timeIntervalSince1970: 1_785_369_600)

    private func record(mode: Mode = .probe, band: Band = .relational, outcome: Outcome = .solved,
                        strikes: Int = 0, probes: Int = 14, twins: Int = 1, duplicates: Int = 0,
                        anomaly: Bool = false, at offset: TimeInterval = 0) -> RoundRecord {
        RoundRecord(mode: mode, band: band, outcome: outcome, strikes: strikes, probesUsed: probes,
                    twinsUsed: twins, duplicatePairProbes: duplicates, score: 700, marks: 2,
                    isAnomaly: anomaly, settledAt: epoch.addingTimeInterval(offset))
    }

    // MARK: - the counters

    @Test("every counter is monotone under recording", arguments: Mode.allCases)
    func countersAreMonotone(_ mode: Mode) {
        var s = Statistics()
        let before = s
        s.record(record(mode: mode))
        #expect(s.roundsPlayed(mode) == before.roundsPlayed(mode) + 1)
        #expect(s.totalProbes >= before.totalProbes)
        #expect(s.twinsUsed >= before.twinsUsed)
    }

    @Test("the three settled outcomes are counted separately")
    func settledOutcomesAreSeparate() {
        var s = Statistics()
        s.record(record(outcome: .solved))
        s.record(record(outcome: .lostOnStrike, strikes: 2))
        s.record(record(outcome: .lostAtCap))
        s.record(record(outcome: .abandoned))            // settled, but none of the three
        #expect(s.solved == 1)
        #expect(s.lostOnSecondStrike == 1)
        #expect(s.lostAtCap == 1)
        #expect(s.solved + s.lostOnSecondStrike + s.lostAtCap < s.roundsSettled)
    }

    @Test("fractures standing is a live count, not a lifetime total")
    func fracturesStandingIsLive() {
        var s = Statistics()
        s.recordFracture(lawKey: 0xABC)
        s.recordFracture(lawKey: 0xDEF)
        #expect(s.fracturesStanding == 2)
        s.recordHeal(lawKey: 0xABC)                      // a later clean find heals it (§11.3)
        #expect(s.fracturesStanding == 1)
    }

    // MARK: - the per-band block

    @Test("the per-band block has exactly eight rows and never names a band as a level")
    func perBandBlockIsEightRows() {
        var s = Statistics()
        for band in Band.allCases { s.record(record(band: band)) }
        #expect(s.perBand.count == 8)
        #expect(s.perBand.allSatisfy { $0.roundsServed >= 0 && $0.solveRate >= 0 && $0.solveRate <= 1 })
    }

    @Test("best probes against par is per band and never worsens")
    func bestProbesNeverWorsens() {
        var s = Statistics()
        s.record(record(band: .pair, probes: 25))
        #expect(s.perBand[Band.pair.index].bestProbes == 25)
        s.record(record(band: .pair, probes: 31))
        #expect(s.perBand[Band.pair.index].bestProbes == 25)
        s.record(record(band: .pair, probes: 19))
        #expect(s.perBand[Band.pair.index].bestProbes == 19)
    }

    // MARK: - runs

    @Test("a run is consecutive solved rounds in one sitting, and Anomaly rounds do not count")
    func runsExcludeTheAnomaly() {
        var s = Statistics()
        s.record(record(outcome: .solved, at: 0))
        s.record(record(outcome: .solved, anomaly: true, at: 300))     // does not extend or break
        s.record(record(outcome: .solved, at: 600))
        #expect(s.currentRun == 2)
        s.record(record(outcome: .lostAtCap, at: 900))
        #expect(s.currentRun == 0)
        #expect(s.longestRun == 2)
    }

    @Test("a new sitting resets the current run but not the longest")
    func sittingBoundaryResetsTheCurrentRun() {
        var s = Statistics()
        s.record(record(outcome: .solved, at: 0))
        s.record(record(outcome: .solved, at: 60))
        s.beginSitting()
        #expect(s.currentRun == 0)
        #expect(s.longestRun == 2)
    }

    // MARK: - the ring is never an aggregate

    @Test("the recentRounds ring is capped at 200 and the aggregates outlive it")
    func ringIsCappedAndAggregatesSurvive() {
        var s = Statistics()
        for i in 0..<500 { s.record(record(at: TimeInterval(i) * 60)) }
        #expect(s.recentRounds.count == 200)
        #expect(s.roundsPlayed(.probe) == 500)
        #expect(s.totalProbes == 500 * 14)
    }

    // MARK: - persistence and reset

    @Test("stats.json round-trips and stays under 40 KB")
    func roundTrips() throws {
        var s = Statistics()
        for i in 0..<200 { s.record(record(at: TimeInterval(i) * 60)) }
        let data = try JSONEncoder().encode(s)
        #expect(data.count < 40 * 1_024)                              // §11.13
        #expect(try JSONDecoder().decode(Statistics.self, from: data) == s)
    }

    @Test("Clear statistics writes zeros and touches nothing else")
    func clearWritesZeros() {
        let s = Statistics()
        #expect(s.totalProbes == 0 && s.recentRounds.isEmpty && s.longestRun == 0)
        #expect(Mode.allCases.allSatisfy { s.roundsPlayed($0) == 0 })
    }

    // MARK: - what must not exist

    /// §11.12: "Not tracked at all: session duration, time of day, days-opened heatmap, launch count."
    @Test("no attendance quantity is representable")
    func noAttendanceQuantity() throws {
        let data = try JSONEncoder().encode(Statistics())
        let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]).keys
        let banned = ["sessionDuration", "timeOfDay", "daysOpened", "launchCount", "lastOpened",
                      "streakOfDays", "playTime", "totalTime"]
        #expect(banned.allSatisfy { !keys.contains($0) })
    }
}
```

`Modules/Tests/MetaFeatureTests/StatisticsViewTests.swift`:

```swift
import Foundation
import Testing
import Archive
import MetaFeature
import ModulesTestSupport

@Suite("StatisticsView — §11.12 screen 13", .tags(.unit, .presubmission))
@MainActor
struct StatisticsViewTests {

    @Test("five sections, in §11.12's order")
    func fiveSections() {
        #expect(StatisticsScreen.sections.map(\.id) == [.modes, .rounds, .bands, .codex, .anomaly])
    }

    @Test("exactly nineteen localized row and column labels, and five section headers")
    func nineteenLabels() {
        let labels = StatisticsScreen.sections.flatMap { $0.labelKeys }
        #expect(labels.count == 19)                       // §12.9's budget
        #expect(Set(labels).count == 19)                  // no duplicates
        #expect(StatisticsScreen.sections.count == 5)
    }

    @Test("the four mode names are wordmarks and are not translation units")
    func modeNamesAreWordmarks() {
        #expect(StatisticsScreen.sections.first { $0.id == .modes }?.labelKeys.count == 1)
        #expect(StatisticsScreen.modeRowsAreVerbatim)
    }

    @Test("the screen is read-only — no destructive action, no button, no editable row")
    func readOnly() {
        #expect(StatisticsScreen.interactiveElements == [.backButton, .playKey])
    }

    @Test("every rendered value goes through a formatter, never string arithmetic")
    func everyValueIsFormatted() {
        #expect(StatisticsScreen.unformattedValues(for: .preview).isEmpty)
    }

    @Test("no forbidden quantity appears anywhere on the screen")
    func noForbiddenQuantity() {
        let rendered = StatisticsScreen.renderedQuantities(for: .preview)
        #expect(!rendered.contains(.ability))
        #expect(!rendered.contains(.difficulty))
        #expect(!rendered.contains(.bandAsLevel))
        #expect(!rendered.contains(.percentile))
        #expect(!rendered.contains(.sessionDuration))
        #expect(!rendered.contains(.daysOpened))
    }

    @Test("the eight band rows are identified by sigil and notch, never by a number")
    func bandRowsCarryNoNumber() {
        let rows = StatisticsScreen.bandRows(for: .preview)
        #expect(rows.count == 8)
        #expect(rows.allSatisfy { $0.leadingIdentity == .familySigil })
        #expect(rows.allSatisfy { $0.renderedLabel == nil })
    }

    @Test("numerals use type.numeral, which carries monospacedDigit for non-SF-Mono digit scripts")
    func numeralsAreMonospaced() {
        #expect(StatisticsScreen.numeralRole == .numeral)
        #expect(StatisticsScreen.numeralRoleCarriesMonospacedDigit)
    }

    @Test("rows grow at AX5 and nothing shrinks", arguments: [1.0, 2.35, 3.1])
    func rowsGrowNothingShrinks(_ multiplier: Double) {
        let layout = StatisticsScreen.layout(in: .preview(typeMultiplier: multiplier))
        #expect(layout.minimumScaleFactor == 1.0)
        #expect(layout.rowHeight >= 44)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter StatisticsTests`
and `swift test --package-path Modules --filter StatisticsViewTests`. Missing symbols. `nineteenLabels`
will fail on a count for a while — that is the label allocation being decided, and it must land on 19.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/Statistics.swift` |
| create | `HunchCore/Tests/ArchiveTests/StatisticsTests.swift` |
| create | `Modules/Sources/MetaFeature/StatisticsView.swift` |
| create | `Modules/Sources/MetaFeature/StatisticsScreen.swift` — the section/row model |
| create | `Modules/Tests/MetaFeatureTests/StatisticsViewTests.swift` |
| modify | `Modules/Sources/MetaFeature/ProfileView.swift` — the statistics key in the instrument bar |
| modify | `Modules/Sources/HunchUI/Chrome/StockContainer.swift` — the neutralised `List` container, if E17·T06 has not created it yet |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — **24 keys**: 5 section headers + 19 row and column labels |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/stats.json` — populated counters and a partial ring |
| modify | `Scripts/check-source-hygiene.sh` — check 14, the forbidden-quantity grep over `StatisticsView.swift` |
| modify | `tests.json` — seven entries |
| modify | `DECISIONS.md` — the 19-label allocation |

## Implementation notes

### The nineteen labels — the allocation, which must be recorded

§12.9 budgets **24 keys**: 5 section headers plus 19 row and column labels. §11.12 lists what is
tracked but not how it splits into labels, and the split is a decision. Take this one, and record it
in `DECISIONS.md` so nobody re-derives a different 19:

| Section | Labelled | Count |
|---|---|---|
| **MODES** | one column head (rounds). The four mode names are wordmarks, `Text(verbatim: mode.wordmark)`, and are **not** translation units | 1 |
| **ROUNDS** | solved · lost on second strike · lost at cap · probes · twins · duplicate pairs · strikes · fractures standing · longest run · current run | 10 |
| **BANDS** | three column heads: served · solve rate · best probes. The eight rows are identified by family sigil and band notch, never by a number (§10.5) | 3 |
| **CODEX** | pages held · shelves sealed. Per-shelf fill is drawn as an arc, not labelled | 2 |
| **ANOMALY** | tally · current streak · longest streak. The 28-day ribbon is drawn | 3 |
| | | **19** |

`nineteenLabels` asserts the total and the absence of duplicates; hygiene check 8's `keyCount <= 250`
absorbs the 24.

### The counters are authoritative; the ring is not

§11.13 is explicit: *"The counters are authoritative and monotone; the ring is for the statistics
screen's run figures and the harness, and is never the source of an aggregate."*

So `Statistics` holds plain monotone counters plus a 200-entry `recentRounds` ring, and
`ringIsCappedAndAggregatesSurvive` asserts 500 recorded rounds against a 200-entry ring with the
totals intact. Anything computed as `recentRounds.filter { … }.count` and displayed as a lifetime
figure is the bug this test exists to catch. The two legitimate ring readers are the run figures
(which need ordering and sitting boundaries) and E11's harness.

**`fracturesStanding` is a live count, not a lifetime total** — §11.3's heal is a decrement, which is
why it takes a `lawKey` and is not a bare `Int += 1`.

### Runs

*"Longest and current run (consecutive solved rounds in one sitting; Anomaly rounds do not count
toward a run)."* Three consequences, all tested:

- An Anomaly round neither extends nor breaks a run — it is skipped entirely, which is
  `RoundBookkeeping.countsTowardRun` from T03, read here rather than re-decided.
- A "sitting" boundary is a `beginSitting()` called from the composition root on
  `scenePhase → .active` after a cold launch, not a wall-clock gap: §11.12 forbids every attendance
  quantity and a gap threshold is one.
- `longestRun` survives a sitting boundary; `currentRun` does not.

### What must not exist, made mechanical

> **Not tracked at all:** session duration, time of day, days-opened heatmap, launch count. No `θ`,
> no `difficulty`, no band number framed as a level, no percentile. — §11.12

Two enforcement points, because the prohibition has two halves:

- **The type**: `noAttendanceQuantity` encodes a default `Statistics` and asserts eight forbidden key
  names are absent. If someone adds `lastOpened`, that test fails before any view renders it.
- **The screen**: hygiene check 14 greps `StatisticsView.swift` and `StatisticsScreen.swift` for
  `ability`, `baseline`, `theta`, `difficulty`, `targetDelta`, `percentile`, `rank`, `level`,
  `session`, `launch`, `daysOpened` and `band.rawValue`, and fails the build on a hit. Demonstrate it
  failing on a planted violation before committing.

§11.12's reason is worth the doc comment: *"a days-played heatmap is an engagement-pressure device
and is the closest this app could come to a habit-manipulation surface. Only facts about play are
counted, never facts about attendance."*

### The container, the numerals and the formatting

- **A stock `List` is the one place the OS picks a colour and picks wrong.** `stock-controls.md` §1's
  neutralisation — `.scrollContentBackground(.hidden)`, the ground background, `.tint(stroke.primary)`
  and never the system accent, the raised row background, the hairline separator tint — applied once
  at the container. **Settings contains no accent at all**, and neither does this screen.
- **Every number is `type.numeral`**, which carries SF Mono **and** `monospacedDigit`. That is not
  redundant: SF Mono has no Eastern Arabic digits, those come from a proportional system fallback, and
  `monospacedDigit` is what stops the columns jumping in Arabic (§12.9 trap 7 rules locale-native
  numerals *correct*). Read the role; never assemble the font.
- **Every value goes through `Date.FormatStyle`, `NumberFormatter` or `Measurement`** against the
  resolved locale — never string arithmetic, never `"\(n) / \(m)"`. Solve rate is a
  `.percent` `FormatStyle`; best-probes-against-par is one format string with two interpolations, not
  a concatenation (§12.9 trap 3).

### Read-only, and why

*"This screen is read-only. Every destructive action lives in one place, Settings → DATA (§12.6), so
that the reset set can be enumerated, alerted and tested once."* The two interactive elements are the
back affordance and the play key (§12.3). `readOnly` asserts the list exactly, so a "Clear" button
cannot be added here without failing.

Three of the five DATA resets own this screen's data — Clear statistics (`stats.json`), Clear Codex
(`codex-b1…b8.json` + `codex-index.json`), Reset Profile (`profile.json`) — and each is independent
of the other two. None of the five touches `anomaly.json` or `anomaly.hw` (T02).

### Dynamic Type and VoiceOver

Rows grow, nothing shrinks: `minimumScaleFactor` is **1.0 everywhere, no exceptions** (§13.11), and
`defaultMinListRowHeight` is `Space.s44`. Each row is one element whose label is the row label and
whose value is the formatted number, so VoiceOver speaks "twins used, 41" rather than two fragments;
the eight band rows take the family sigil's own label from E15·T09 as their identity and never a band
number. Register the screen in the audit (`hunch-accessibility/references/audit-in-ci.md` §3) — E19
runs it, but the registration belongs with the screen.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter StatisticsTests` green, all eleven tests.
- [ ] `swift test --package-path Modules --filter StatisticsViewTests` green, all nine tests, with `nineteenLabels` landing on exactly 19.
- [ ] `Scripts/check-source-hygiene.sh` check 14 is present, passes, and was demonstrated to fail on a planted `ability` reference in `StatisticsView.swift`.
- [ ] `grep -rn "systemGroupedBackground\|\.accentColor\|Color.blue" Modules/Sources/MetaFeature/StatisticsView.swift` returns nothing.
- [ ] `grep -rnE '"\\\\\(' Modules/Sources/MetaFeature/StatisticsView.swift` returns nothing — no string interpolation of a number outside a format style.
- [ ] `Localizable.xcstrings` gained exactly 24 keys and the catalog is still ≤ 250.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/stats.json` is populated, under 40 KB, and `PersistenceTests` is still green.
- [ ] The screen is checked at AX5 in English, German and Arabic in the simulator with zero truncation and zero horizontal overflow, and the screenshots are in `PROGRESS.md`.
- [ ] `tests.json` carries seven entries: counter monotonicity, the ring cap with surviving aggregates, the eight-row band block with no band number, the run rule with the Anomaly exclusion, the nineteen labels, read-only-ness, and the forbidden-quantity list.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes deriving a lifetime total from `recentRounds`, reject it and point at §11.13.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T11: StatisticsView — five sections, nineteen labels, read-only, no attendance"`

## Out of scope

- The five DATA resets, their alerts and their file sets — **E17·T08**; this screen is read-only and asserts it.
- `SettingsView`, `AboutView` and the stock-`Form` container's other three consumers — **E17·T05/T06/T07**.
- The Codex's per-shelf fill arcs and sealed-shelf marks this screen quotes — **E15·T02/T07**.
- The eight family sigils the band rows use as their identity — **E15·T09**.
- The `performAccessibilityAudit` run over this screen — **E19·T11**; this task registers it.
- The catalog completeness and banned-lexeme tests across twelve languages — **E18·T03/T08**.
