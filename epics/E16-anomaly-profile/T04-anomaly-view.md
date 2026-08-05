# T04 — `AnomalyView`

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T03 |
| **Delivers** | Tally, streak, ribbon (ANOMALY) · 18 screens (SCREENS / NAVIGATION) — screen 12 |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | This is a drawing, so tokens come first: the ribbon cell, the tally numeral's type role, the streak ring's accent and the rollover's ink all resolve through `RenderEnv`, and a literal outside `Tokens/` fails hygiene check 9. It also owns the resolution order that decides what High Contrast does to a hairline ring. |
| `hunch-chrome-and-meta` | Owns `AnomalyView`'s chrome: the instrument bar with the play key, `numeral-readout.md` sites 4 and 5 (the tally, and the streak numeral beside its ring), and the rule that the four wordmarks are `Text(verbatim:)`. Its `key.md` gives the 28 ribbon cells' hit geometry. |
| `hunch-shared-marks` | The 28 cells are `VerdictRing.draw` in its `.day(Day)` state — the mapping from §11.8's six render states already exists in `verdict-ring.md` and must not be drawn a second time here. The rollover and the streak ring are both `ArcMeter.draw` cases that already exist. |

## Objective

At the end of this task screen 12 exists: twenty-eight rings of the last twenty-eight UTC days, the
lifetime tally as the headline numeral, the streak as a secondary ring, a 24-segment rollover arc
showing how far into the UTC day the player is, and the `.clockBehind` lock as a full static ring
with no pulse. Tapping any past cell opens that day's law in rule-tiles, regenerated for free from
`anomalySeed(day:)`, and the Inscription grows its appended anomaly strip.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.8 | the six-state ribbon table; the tally as the headline and the streak as the secondary mark, with the reason; tap-a-past-cell-always; no cells beyond `highWaterDay`; the Inscription's appended strip and its four elements |
| `GAME_DESIGN.md` | §11.7 | the 24-segment rollover arc; `.clockBehind` rendered textlessly as a full, static ring with no pulse |
| `GAME_DESIGN.md` | §12.2 | screen 12's row: contents, entry, exit, primary action (*tap today's cell → the Anomaly round starts*) |
| `GAME_DESIGN.md` | §12.3 | the play key in the trailing corner of the instrument bar, and the ≤ 2-tap rule |
| `GAME_DESIGN.md` | §12.9 | screen titles budget — `Anomaly` is one of the six titled screens; nothing else on this screen is a string |
| `hunch-shared-marks` | `references/verdict-ring.md` §2 | `.day(Day)` and its six-row mapping; the `.failed` cell draws the cancel hatch, one direction, at −45° |
| `hunch-shared-marks` | `references/arc-meter.md` §2 | `.rollover` (24 segments of 15° less a 3° gap, quantised **down** to a whole hour) and `.streak(accented:)`; neither mirrors under RTL |
| `hunch-chrome-and-meta` | `references/numeral-readout.md` §2 | sites 4 and 5, and the rule that the Frame's Anomaly key carries **no** numeral |
| `hunch-chrome-and-meta` | `references/instrument-bar.md` | the bar's resolved height, and that the Frame's three-element accent ration does not apply here |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/ArchiveTests/AnomalyRibbonTests.swift` — the ribbon is a *value*, and the value is
what carries the six states, so this is core and fast:

```swift
import Foundation
import Testing
import Archive
import HunchTestSupport

@Suite("The 28-cell Anomaly ribbon, as data", .tags(.unit, .presubmission))
struct AnomalyRibbonTests {

    private func settled(_ day: Int64, _ outcome: AnomalyOutcome) -> DayEntry {
        DayEntry(day: day, outcome: outcome, probes: 20, band: 5,
                 settledAt: Date(timeIntervalSince1970: TimeInterval(day) * 86_400))
    }

    @Test("the ribbon is exactly 28 cells, oldest leading, ending at highWaterDay")
    func twentyEightCellsEndingToday() {
        var l = AnomalyLedger(); l.observe(day: 20_664)
        let ribbon = l.ribbon()
        #expect(ribbon.count == 28)
        #expect(ribbon.first?.day == 20_664 - 27)
        #expect(ribbon.last?.day == 20_664)
    }

    @Test("there are no cells beyond highWaterDay — the future is not addressable (§11.8)")
    func noFutureCells() {
        var l = AnomalyLedger(); l.observe(day: 20_664)
        #expect(l.ribbon().allSatisfy { $0.day <= 20_664 })
    }

    @Test("each outcome maps to its own render state",
          arguments: zip([AnomalyOutcome.solvedClean, .solvedFractured, .failed, .abandoned],
                         [DayState.clean, .fractured, .failed, .missed]))
    func outcomeMapsToState(_ outcome: AnomalyOutcome, _ state: DayState) {
        var l = AnomalyLedger(); l.observe(day: 20_664); l.record(settled(20_664, outcome))
        #expect(l.ribbon().last?.state == state)
    }

    @Test("an unplayed day with no entry is .missed; today unplayed is .awaiting")
    func absenceAndToday() {
        var l = AnomalyLedger(); l.observe(day: 20_664)
        #expect(l.ribbon().last?.state == .awaiting)
        #expect(l.ribbon().first?.state == .missed)
    }

    @Test("under a clock-back lock today's cell is .locked, not .awaiting")
    func lockedToday() {
        var l = AnomalyLedger(); l.observe(day: 20_664); l.observe(day: 20_660)
        #expect(l.ribbon().last?.state == .locked)
    }

    @Test("every past cell is addressable and carries the day that regenerates its law")
    func everyPastCellIsAddressable() {
        var l = AnomalyLedger(); l.observe(day: 20_664)
        let past = l.ribbon().dropLast()
        #expect(past.allSatisfy { $0.isRevealable })          // including missed and failed (§11.8)
        #expect(Set(past.map(\.day)).count == 27)
    }

    @Test("the rollover fraction quantises DOWN to a whole UTC hour")
    func rolloverQuantisesDown() {
        // 13 h 59 m into the day is still hour 13 of 24.
        let t = TimeInterval(20_664) * 86_400 + 13 * 3_600 + 59 * 60
        #expect(isApproximatelyEqual(Anomaly.rolloverFraction(at: t), 13.0 / 24.0,
                                     absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(Anomaly.rolloverFraction(at: TimeInterval(20_664) * 86_400),
                                     0, absoluteTolerance: 1e-12))
    }
}
```

`Modules/Tests/MetaFeatureTests/AnomalyViewTests.swift` — the screen's contract, not its pixels:

```swift
import Foundation
import Testing
import Archive
import MetaFeature
import ModulesTestSupport

@Suite("AnomalyView — §12.2 screen 12", .tags(.unit, .presubmission))
@MainActor
struct AnomalyViewTests {

    @Test("tapping today's cell starts the round only when the ledger says playable",
          arguments: [(AnomalyAvailability.playable, true),
                      (.alreadySettled, false),
                      (.clockBehind(unlocksAt: 20_665), false)])
    func todayIsTappableOnlyWhenPlayable(_ availability: AnomalyAvailability, _ starts: Bool) {
        let model = AnomalyScreen(availability: availability, ledger: .preview, today: 20_664)
        #expect(model.todayStartsARound == starts)
    }

    @Test("tapping a past cell reveals that day's law and never starts a round")
    func pastCellReveals() {
        let model = AnomalyScreen(availability: .playable, ledger: .preview, today: 20_664)
        model.tap(day: 20_650)
        #expect(model.revealedDay == 20_650)
        #expect(model.startedRound == nil)
        #expect(model.revealedLayout != nil)          // rule-tiles, regenerated from anomalySeed
    }

    @Test("the revealed law is regenerated, never read from the Codex")
    func revealIsRegeneratedNotLoaded() {
        let model = AnomalyScreen(availability: .playable, ledger: .empty, today: 20_664)
        model.tap(day: 20_650)                        // a day never played, no Codex page exists
        #expect(model.revealedLayout != nil)
    }

    @Test("the tally is the headline and the streak is secondary — the sizes are not interchangeable")
    func tallyIsTheHeadline() {
        let m = AnomalyScreen(availability: .playable, ledger: .preview, today: 20_664).metrics
        #expect(m.tallyRole == .numeral)
        #expect(m.streakRole == .micro)
        #expect(m.tallyPointSize > m.streakPointSize)
    }

    @Test("the screen renders no numeral other than the tally and the streak")
    func onlyTwoNumerals() {
        let m = AnomalyScreen(availability: .playable, ledger: .preview, today: 20_664).metrics
        #expect(m.numeralSites == [.tally, .streak])
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter AnomalyRibbonTests` and
`swift test --package-path Modules --filter AnomalyViewTests`. The second will not even build until
`MetaFeature` and `MetaFeatureTests` exist in `Modules/Package.swift` — that is the first
implementation step, and it is a compile error, not a test failure.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `Modules/Package.swift` — **create the `MetaFeature` target** with `.defaultIsolation(MainActor.self)`, depending on `HunchCore` and `HunchUI`; and `MetaFeatureTests` |
| create | `Modules/Sources/MetaFeature/AnomalyView.swift` |
| create | `Modules/Sources/MetaFeature/AnomalyScreen.swift` — `@MainActor @Observable`, the screen's state |
| create | `Modules/Sources/MetaFeature/AnomalyRibbonCanvas.swift` |
| create | `HunchCore/Sources/Archive/AnomalyRibbon.swift` — `ribbon()`, `RibbonCell`, `rolloverFraction(at:)` |
| create | `HunchCore/Tests/ArchiveTests/AnomalyRibbonTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/AnomalyViewTests.swift` |
| create | `Modules/Sources/ModulesTestSupport/…` — mirror the eight `@Tag` declarations if E15 has not already |
| modify | `Modules/Sources/LoomFeature/InscriptionView.swift` — the appended anomaly strip |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — one key: the screen title |
| modify | `tests.json` — five entries |

## Implementation notes

### The target, first

`MetaFeature` does not exist yet — `01 P12` and `08 §7.3` say a target is created the day its owner
section is implemented, and this is that day. Add it to `Modules/Package.swift` with
`.defaultIsolation(MainActor.self)` (`08 §4`) and a path-mirrored `MetaFeatureTests`. E17 will fill it
with `FrameView`, `SettingsView`, `AboutView` and `ResetConfirmAlert`; this task adds `AnomalyView`
and T08–T11 add the Profile and Statistics. Record the addition in `DECISIONS.md` — the tree in
`08 §1` lists `MetaFeatureTests` nowhere and it is needed.

### The ribbon is a value

`AnomalyLedger.ribbon()` returns 28 `RibbonCell`s — `(day: Int64, state: DayState, probes: UInt16?, isRevealable: Bool)` —
ending at `highWaterDay`. It is core, it is pure, and it is why the six-state table is asserted in a
microsecond suite instead of a snapshot. The canvas switches on `state` and does no derivation of its
own.

**`missed` is derived from absence** (T02), so a 25-year clock jump produces a ribbon of 28 `.missed`
cells and zero stored records. `isRevealable` is `true` for every cell except today's when today is
`.awaiting` or `.locked` — §11.8: *"Tapping a past cell reveals that day's law in rule-tiles,
always — including days you missed and days you failed."*

### The six render states

Do not draw them. `VerdictRing.draw(state: .day(cell.state), …)` already maps all six —
`verdict-ring.md` §2's `Day` table is the authority and the `.failed` cell's "cross-hatch" is prose
for the **cancel hatch at −45°**, one direction, because a crossed hatch would be a second ink
coverage and coverage is a channel the glyph owns. Cells are 11 pt (§11.8) inside a 44 × 44 hit rect,
which is `key.md`'s smallest rectangle with a drawn mark inside it; the 11 pt is the *ring*, not the
target.

The `.awaiting` pulse belongs to the **host**, not to the mark (`arc-meter.md` §3 and
`verdict-ring.md`'s rule that no mark animates itself). Under Reduce Motion it becomes a static dash
— `reduce-motion.md`'s row, cited, not restated.

### Tally, streak, rollover

- **Tally**: `numeral-readout.md` site 4, `type.numeral`, the largest thing on the screen. §11.8's
  reason is the load-bearing part and belongs in the doc comment: *"a single harsh counter as the
  headline converts the daily into a loss-aversion device."* The tally is monotone and un-loseable.
- **Streak**: site 5 — an `ArcMeter.draw(.streak(accented:))` **with** its count beside it. Secondary
  type role, secondary size. `accented` is `true` only while the streak is live; §13.1's three-element
  accent ration is not binding on this screen (that constraint is the **Frame**'s, per
  `instrument-bar.md` §3.1) but the screen still spends at most two.
- **Rollover**: `ArcMeter.draw(.rollover, fraction: Anomaly.rolloverFraction(at:))`. 24 segments,
  quantised **down** — a partial hour would imply a precision the day index does not have. It does
  **not** mirror under RTL: mirroring it would say the day runs backwards.
- **`.clockBehind`**: the rollover ring drawn full and static with no pulse. That absence is the whole
  distinction from a genuinely completed day, and it is textless — no explanation, no alert, no copy.

### Tap-a-past-cell

Free, by construction: `Anomaly.law(day:)` regenerates from `anomalySeed(day:)` in microseconds, and
`BenchLayout(law)` gives the rule-tiles G10 already guarantees are expressible. It does **not** read
the Codex — `revealIsRegeneratedNotLoaded` pins that, and it is what makes a *missed* day interesting
rather than a hole. Reveal in place, on this screen, at `CodexPageView`'s 0.78× rule-tile scale
(E15·T05 owns that layout; call it, do not re-lay-it-out).

### The Inscription's appended strip

§11.8's four elements, appended below the ordinary round-end layout — the single round-end screen
§12.1 decided on stays single:

1. the day's law in full rule-tiles (already the Inscription's own reveal);
2. the probe count as a `TickRow.draw` against the day's par with the par silhouette beneath;
3. the 28-cell ribbon with today's cell newly inscribed;
4. the tally numeral incrementing.

That strip is a **tick row**, not the ribbon's rings — `hunch-shared-marks`' gotcha names this exact
confusion. And §11.8's closing clause is a scope rule, not a caution: no percentile, no distribution,
no "you beat X %", no rank. They are unavailable, because the device knows about one player.

### Accessibility, in the same pass

Per `hunch-chrome-and-meta` step 4 and §13.10's Anomaly row (5 control labels in §12.9's budget):
each ribbon cell is one element with a date label (`Date.FormatStyle`) and a state value; the tally
and streak are elements with their numerals spoken; the rollover arc is `.accessibilityHidden(true)`
because "how far into the UTC day you are" has no spoken form worth 24 utterances. Today's cell takes
`.isButton`; a locked today's cell stays enabled and discoverable while refusing, the same rule the
barred Seal follows.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AnomalyRibbonTests` green, all seven tests.
- [ ] `swift test --package-path Modules --filter AnomalyViewTests` green, all five tests.
- [ ] `Modules/Package.swift` declares `MetaFeature` with `.defaultIsolation(MainActor.self)` and a path-mirrored `MetaFeatureTests`; `swift build --package-path Modules` is clean.
- [ ] `grep -rn "VerdictRing\|ArcMeter\|TickRow\|CancelHatch" Modules/Sources/MetaFeature/` shows only *calls*; `grep -rn "func draw" Modules/Sources/MetaFeature/` returns nothing.
- [ ] `Scripts/check-source-hygiene.sh` check 9 passes — no hex, no numeric `lineWidth:`, no literal `.opacity(` in any new `MetaFeature` file.
- [ ] `Localizable.xcstrings` gained exactly one visible key on this screen (the title) and the catalog is still ≤ 250.
- [ ] The screen renders correctly at Reduce Motion (static dash for today's pulse), High Contrast and AX5 in the simulator, and the transcript is in `PROGRESS.md`.
- [ ] `tests.json` carries five entries: the 28-cell window, no future cells, the six-state mapping, past-cell revealability, and the rollover's downward quantisation.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes inlining a ring or an arc "just for the 11 pt cell", reject it: that is the §2(g) bug `hunch-shared-marks` exists to prevent.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T04: AnomalyView — the 28-cell ribbon, tally, streak, rollover and the Inscription strip"`

## Out of scope

- The Frame's Anomaly key, its own rollover arc and streak ring — **E17·T03/T04**.
- `InscriptionView` itself, its reveal beats and its round-end layout — **E09·T10/T11**; this task appends one strip to it.
- The Codex page an Anomaly round mints and its anomaly seal — **E15·T05/T06**.
- The rule-tile canvases the reveal composes — **E09·T02**.
- The Anomaly's full VoiceOver element rows, rotors and announcements — **E19·T01**; this task ships the labels named above and nothing more.
