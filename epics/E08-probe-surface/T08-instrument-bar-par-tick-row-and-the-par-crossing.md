# T08 — Instrument bar, par tick row and the par crossing

| | |
|---|---|
| **Epic** | E08 — The PROBE play surface |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | §14.1 PROBE → *Par tick row + par crossing* |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `C.TickRow`'s six geometry members exist already; this task must not restate one of them, and the row's ink is `stroke.secondary` for **both** states because a tint gap on a 2 × 11 pt mark fails the 3 : 1 graphical floor. Load it first. |
| `hunch-shared-marks` | `references/tick-row.md` is normative: the four modes, the height-not-tint state channel, the pitch formula, the crossing, the "no audio, no haptic" ruling and the RTL rule that the row never mirrors but the cap row still empties from the trailing end. |
| `hunch-chrome-and-meta` | `references/instrument-bar.md` owns the three slots and §2's ruling that `y 20–64` is a *resolved* height, not a constant — plus the rule that the centre slot is read-only on every screen but one. |

## Objective

`InstrumentBar` exists as the three-slot container every screen in §12.2 will mount, and PROBE's centre slot carries a par tick row whose **length** is proportional to par at constant pitch. At the probe that fills the last par tick the row inverts to one solid rule and the dim cap row lights and begins emptying from the trailing end — once, permanently, with no audio and no haptic.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §6.2 | The bar's region on both devices; `nominalPitch` / `rowWidth` / `tickPitch`; why the clamp engages only in DRIFT |
| `GAME_DESIGN.md` | §6.9 | The par crossing: the row completes and inverts, the cap row lights and empties from the trailing end, at t = 260–420 ms of the verdict beat; and the decision that it has **no audio and no haptic** |
| `GAME_DESIGN.md` | §5.4, §10.5 | The row's length is the only difficulty signal the player gets — 7 ticks at band 1, 29 at band 8, uncountable at a glance past about seven |
| `GAME_DESIGN.md` | §13.10 | The probe tally as `.staticText` `.updatesFrequently`, value "12 of 23 expected, 37 maximum", and the two once-per-round announcements |
| `hunch-shared-marks` | `references/tick-row.md` §1–§7 | Geometry, the four modes, the crossing, the Swift, the environment behaviour, the `C.TickRow` namespace, the ten ways to get it wrong |
| `hunch-chrome-and-meta` | `references/instrument-bar.md` §1–§5, §7–§8 | The slots, the resolved height, per-screen contents, the two rulings, the implementation and the eight ways to get it wrong |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/ParRowTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
import HunchUI

@Suite("The par row and the par crossing", .tags(.unit, .presubmission))
struct ParRowTests {

    private func model(_ used: Int, _ band: Band = .contextual) -> ParRowModel {
        ParRowModel(probesUsed: used, par: band.par(for: .probe), cap: band.cap(for: .probe))
    }

    @Test("Below par the row counts up and the cap row is present but unlit")
    func belowPar() {
        let band = Band.contextual
        let m = model(5, band)
        #expect(m.parMode == .count(filled: 5, total: band.par(for: .probe)))
        #expect(m.hasCrossed == false)
        #expect(m.capIsLit == false)
        // The cap row's total is cap − par: the budget that remains *after* par.
        #expect(m.capMode == .cap(remaining: band.cap(for: .probe) - band.par(for: .probe),
                                  total: band.cap(for: .probe) - band.par(for: .probe)))
    }

    @Test("At par the row inverts to one solid rule and the cap row lights, on the same frame",
          arguments: Band.allCases)
    func theCrossing(_ band: Band) {
        let par = band.par(for: .probe)
        let m = model(par, band)
        #expect(m.hasCrossed)
        #expect(m.parMode == .crossed(total: par))
        #expect(m.capIsLit)
        #expect(m.capMode == .cap(remaining: band.cap(for: .probe) - par,
                                  total: band.cap(for: .probe) - par))
    }

    @Test("Past par the cap row empties, one stop per probe, and bottoms out at the cap")
    func capEmpties() {
        let band = Band.contextual
        let par = band.par(for: .probe), cap = band.cap(for: .probe)
        for used in par...cap {
            let m = model(used, band)
            #expect(m.capMode == .cap(remaining: cap - used, total: cap - par))
            #expect(m.parMode == .crossed(total: par))
        }
        #expect(model(cap, band).capMode == .cap(remaining: 0, total: cap - par))
    }

    @Test("The crossing is one-way: it never un-crosses")
    func theCrossingIsPermanent() {
        let band = Band.literal
        #expect(model(band.par(for: .probe) - 1, band).hasCrossed == false)
        for used in band.par(for: .probe)...band.cap(for: .probe) {
            #expect(model(used, band).hasCrossed)
        }
    }

    @Test("A spent cap stop is an absence, never a dimmed stop")
    func spentStopsAreAbsent() {
        let band = Band.contextual
        let m = model(band.par(for: .probe) + 4, band)
        guard case .cap(let remaining, let total) = m.capMode else { return #expect(Bool(false)) }
        #expect(total - remaining == 4)
        #expect(m.dimmedStopCount == 0)          // there is no such thing
    }

    @Test("The row's ticks never fall below the drawable gap on either device",
          arguments: Band.allCases)
    func theRowFits(_ band: Band) {
        for layout in [PlaySurfaceLayout.reference(.compact), .reference(.large)] {
            let par = band.par(for: .probe)
            #expect(TickRow.pitch(nominalPitch: layout.nominalTickPitch,
                                  rowWidth: layout.tickRowWidth,
                                  total: par) == layout.nominalTickPitch)
        }
    }
}
```

And `Modules/Tests/LoomFeatureTests/ParCrossingSilenceTests.swift` — §6.9's decision, asserted:

```swift
import Testing
import HunchCore
import Feedback
import ModulesTestSupport
import LoomFeature

@Suite("The par crossing is geometry only", .tags(.unit, .presubmission))
@MainActor
struct ParCrossingSilenceTests {

    @Test("Crossing par fires no cue of its own — the verdict owns that frame")
    func silentCrossing() {
        let recorder = RecordingCuePlayer()
        let round = Fixtures.round(band: .literal, cues: recorder)
        let par = round.band.par(for: .probe)

        for _ in 0..<par {
            round.probe(Deck.glyph(id: 3))
            round.landVerdict()
            round.endVerdictBeat()
        }

        #expect(round.hasCrossedPar)
        // Exactly two cues per probe — submit and verdict — and not one more on the crossing probe.
        #expect(recorder.cues.count == par * 2)
        #expect(recorder.cues.allSatisfy { cue in
            if case .probeSubmit = cue { return true }
            if case .verdict = cue { return true }
            return false
        })
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -only-testing:HunchUITests/ParRowTests -only-testing:LoomFeatureTests/ParCrossingSilenceTests
```

Expect `cannot find 'ParRowModel' in scope`, and possibly `type 'TickRow' has no member 'pitch'` — see the notes for the right fix.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/Chrome/InstrumentBar.swift` |
| create | `Modules/Sources/HunchUI/ParTickRow.swift` |
| modify | `Modules/Sources/HunchUI/Marks/TickRow.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` |
| create | `Modules/Tests/HunchUITests/ParRowTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/ParCrossingSilenceTests.swift` |

## Implementation notes

**`ParRowModel` is a pure value and is the whole of the crossing's logic.**

```swift
public struct ParRowModel: Equatable, Sendable {
    public init(probesUsed: Int, par: Int, cap: Int)

    public var hasCrossed: Bool          // probesUsed >= par
    public var parMode: TickRow.Mode     // .count(filled:total:) → .crossed(total:)
    public var capMode: TickRow.Mode     // .cap(remaining:total:), total = cap − par
    public var capIsLit: Bool            // false until the crossing, then true forever
}
```

Two details the spec is precise about and an implementation usually is not:

- **The cap row's `total` is `cap − par`, not `cap`.** It is the budget that remains *after* par, which is what "begins emptying" means; at band 5 that is 14 stops.
- **A spent cap stop is an absence.** Dimming it would put a second, weaker copy of the same fact on the row and reintroduce exactly the tint channel the height-based state channel removed. There is no `dimmedStopCount`; the test asserts zero because the concept must not exist.

**The pitch formula has one home and it is the mark's.** `TickRow.draw` already computes `min(nominalPitch, rowWidth / total)` internally (E04·T08). If it does not expose that arithmetic, **extract** it as `public static func pitch(nominalPitch:rowWidth:total:)` in `Marks/TickRow.swift` and have `bars(...)` call it — do not re-derive it in `ParTickRow.swift` or in `PlaySurfaceLayout`. Two implementations of a clamp is how a row silently stops being proportional.

**Why the proportionality matters enough to test.** §5.4 makes the row's *length* the only difficulty signal the player gets, and §10.5 makes it uncountable at a glance past about seven. Pitch is therefore held constant and length varies. Inside PROBE the clamp never engages — 29 ticks at 9 pt is 261 pt inside a 288 pt budget — and the only place it does engage is DRIFT's band-8 par of 40, where the pitch compresses to 7.2 pt on the SE and the tick stays 2 pt wide, leaving over 5 pt of gap. DRIFT's tick count already identifies the mode by design, so compressing its row costs no signal that was not already given away.

**Dynamic Type scales the heights and never the pitch**, and this is load-bearing rather than fussy: `tick-row.md` §5 works out that a scaled pitch would engage the clamp *inside* PROBE and compress band 8's row while leaving band 1's alone — distorting the ratio of the only difficulty signal in the game from 4.14 to 3.39. T02's `tickPitch(total:artScale:)` already ignores its `artScale`; keep it that way and keep the test that says so.

**The crossing's animation is a crossfade in both motion modes.** §13.7.4 has no row for it because nothing translates, scales or rotates: the two drawings crossfade over `Dur.micro`. The substitution is the identity. Note that in the code, because a reader will look for the row and not find it.

**No audio and no haptic — and this is the one place in the round where silence is the specification.** The crossing lands on the same frame as a verdict, which owns those two channels absolutely (§6.4). A second cue there would either mask the verdict or be misread as part of it, and a player would learn "sometimes the admit tone is different", which is a lie about the law. Do not wire a `Cue` to `hasCrossedPar`. VoiceOver already carries it: the probe tally is `.updatesFrequently` and speaks par and cap as numbers, which is legal because accessibility labels are audio and the no-text rule constrains rendered pixels only.

**`InstrumentBar` is a generic container, built once here and reused by every screen.**

```swift
struct InstrumentBar<Leading: View, Centre: View, Trailing: View>: View
```

Three slots, `.frame(minHeight: Space.s44)` and **never** `.frame(height:)`; the 44 pt slots supply the horizontal margin, with no extra outer padding; no `.frame(alignment:)` on the trailing slot, because the centre's `maxWidth: .infinity` is what pins it. On a play surface the bar is exactly 44 pt because a play surface has zero text and therefore nothing that can wrap — but the *height must still be resolved and read*, and every region below it positioned from its `maxY`, because `RoundView` shares this component with titled screens that do grow. Writing `.padding(.top, 64)` is §2's bug in one line and is the single most likely defect in this component.

PROBE's bar: chevron leading, par tick row plus mode sigil centre, nothing trailing. This task supplies the tick row and leaves the other two as slot contents the owning epics fill — the chevron's *action* (suspend, one tap, no confirmation) is E10·T04 and E17·T09; the mode sigil's *drawing* is E17·T04. Pass them in as view builders so neither epic has to reopen this file.

**RTL.** The row does not mirror: §2 renders instrument scales leading-to-trailing in source order in every locale, and probe 1 is at the leading end everywhere. The one thing `layout` is in the signature for is that the cap row empties from the **trailing** end, and "trailing" is a reading-order word.

## Acceptance criteria

- [ ] `ParRowTests` (6 cases) and `ParCrossingSilenceTests` green on both destinations.
- [ ] `TickPitchTests` (T02) still green — the extraction of `TickRow.pitch(...)` changed no behaviour.
- [ ] `grep -rn 'min(nominalPitch\|rowWidth /' Modules/Sources` shows exactly one implementation, in `Marks/TickRow.swift`.
- [ ] `grep -rn 'cues.play' Modules/Sources/HunchUI/ParTickRow.swift Modules/Sources/LoomFeature/Round.swift | grep -i 'cross\|par'` returns nothing.
- [ ] `grep -n 'frame(height:' Modules/Sources/HunchUI/Chrome/InstrumentBar.swift` returns nothing.
- [ ] `grep -n '11\|4\|7\|2' Modules/Sources/HunchUI/ParTickRow.swift` shows no bare tick geometry — heights and widths are `C.TickRow.*`.
- [ ] With Reduce Motion on and off, the crossing crossfades and nothing on the row translates — checked in the DEBUG gallery and recorded in `PROGRESS.md`.

## Close the task

1. `swift test --package-path HunchCore` green and under 10 s; both new filters green on both destinations.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E08/T08: the instrument bar, the length-proportional par row and the silent crossing"`

## Out of scope

- The `TickRow` mark itself — **E04·T08**. This task may extract a `pitch(...)` accessor from it; it may not add a second drawing.
- The mode sigil — **E17·T04** — and the chevron's suspend action — **E10·T04**, **E17·T09**. Both arrive as slot contents.
- The Frame's own instrument bar (Settings key, run-notch stack, Anomaly key with its rollover arc and streak ring) — **E17·T03**, reusing this container. The three-accent invariant on `FrameView` is that task's assertion, not this one's.
- SIEVE's bar (three foul ticks, stream progress arc, no chevron, and explicitly no lawful count, which would leak the admit rate) — **E14·T02, E14·T07**.
- The Codex page's `bestProbes` strip and the Inscription's appended strip — **E15·T05**, **E16·T04**. Same mark, different hosts.
- DRIFT's 40-tick compressed row — **E12·T04**. The formula is here and already correct for it; the par table is not.
- The two once-per-round VoiceOver announcements ("Past the expected probe count.", "Five probes remaining.") — **E19·T05**.
