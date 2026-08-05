# T09 — Difficulty is never a number

| | |
|---|---|
| **Epic** | E11 — The adaptive engine and the harnesses |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T03 |
| **Delivers** | §14.1 Difficulty is never a number |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-build-and-ci` | Owns `Scripts/check-source-hygiene.sh` and its numbered gate roster, and owns the rule that decides *whether* a rule belongs there at all: "Can it be a compile error instead? Can a package test see it? A grep is the third-best answer." This rule cannot be either — the strings live in a String Catalog and the absences live in source — so it is check 13, and this skill is what makes it a gate rather than a note. |
| `hunch-chrome-and-meta` | Owns `references/numeral-readout.md`, which holds *"the resolved site table"* for where a digit may be rendered anywhere in the app — and its gotcha that §13.4, §11's preamble and §14.1 disagree about how many sites there are. Check 13 is only writable against that resolved table, and the statistics-screen exemption below is a ruling against it. |

## Objective

The player gets exactly three signals about difficulty — the length of the par tick row, the palette's
ceiling and the Codex shelves — plus one sub-numeric ambient step in the Loom's drone, and a shipped
grep proves that no band number, percentage, difficulty colour, level string or post-round
"difficulty adjusted" acknowledgement exists anywhere they can reach. At the end of this task the
absence is a build gate rather than a paragraph.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §10.5 | The mechanical argument (a visible band names the family and hands over the whole discovery cost `d`); the three signals and what each reads as; the drone dropping one scale degree every two bands; the explicit forbidden list |
| `GAME_DESIGN.md` | §5.2, §5.4 | The band ↔ family bijection that makes a band label a family label; `d` at 3–8 probes, up to a third of par |
| `GAME_DESIGN.md` | §4.4, §10.4 | Signal 2: the palette ceiling reads as capability acquired, never as an assignment received |
| `GAME_DESIGN.md` | §11.2, §11.12 | Signal 3: the Codex shelves; and the statistics screen's per-band rows, which is where this rule and §11.12 have to be reconciled |
| `GAME_DESIGN.md` | §13.8 | The audio scale the drone step names a degree of; the cue table is normative for sound and this task ships no sound |
| `GAME_DESIGN.md` | §12.9 | The localization surface, its ≈228 keys, and the fact that no play-surface string exists at all |
| `GAME_DESIGN.md` | §1.13 | The banned-lexeme list check 8 already enforces; check 13 extends the same machinery with difficulty vocabulary |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B34a | The script's shape, and that every check runs in an Xcode phase *and* in CI |

## TDD — the test comes first

**Step 1 — write the failing test.** Two artifacts, because half of this is a value and half is a lint.

`HunchCore/Tests/LadderTests/DroneStepTests.swift`:

```swift
import Testing
import LawGeneration
@testable import Ladder

@Suite("The sub-numeric drone step — §10.5", .tags(.unit, .presubmission))
struct DroneStepTests {

    /// §10.5: "the Loom's procedural drone drops one scale degree every two bands (four steps
    /// across the ladder)". Four steps, not eight, is the whole point: nobody derives "band 6"
    /// from a pitch.
    @Test("There are exactly four steps across eight bands")
    func fourStepsNotEight() {
        let steps = Band.allCases.map(DroneStep.init(band:))
        #expect(Set(steps).count == 4)
        #expect(steps == steps.sorted())
        #expect(steps.first == DroneStep.allCases.first)
        #expect(steps.last == DroneStep.allCases.last)
    }

    @Test("Adjacent bands share a step exactly half the time", arguments: Array(1...7))
    func adjacentBandsOftenShareAStep(_ lower: Int) {
        let a = DroneStep(band: Band(rawValue: lower)!)
        let b = DroneStep(band: Band(rawValue: lower + 1)!)
        #expect(lower.isMultiple(of: 2) ? a != b : a == b)
    }

    /// The step is a scale degree, not a frequency: §13.8 owns every Hz in the app and this
    /// type must not name one.
    @Test("The step is an ordinal with no frequency, no duration and no description")
    func stepIsPurelyOrdinal() {
        #expect(DroneStep.allCases.count == 4)
        #expect(DroneStep.allCases.map(\.rawValue) == [0, 1, 2, 3])
    }
}
```

`HunchCore/Tests/LadderTests/DifficultySignalsTests.swift`:

```swift
import Testing
import Bench
import LawGeneration
@testable import Ladder

@Suite("Difficulty is never a number — §10.5", .tags(.unit, .presubmission))
struct DifficultySignalsTests {

    /// §10.5: "The three signals the player actually gets — exactly three."
    @Test("The signal inventory is exactly three, and each names its owner")
    func exactlyThreeSignals() {
        #expect(DifficultySignal.allCases.count == 3)
        #expect(Set(DifficultySignal.allCases) == [.parTickRowLength, .paletteCeiling, .codexShelves])
    }

    /// Signal 1's non-injectivity is not an accident — §10.5 says bands 5 and 6 share par 23 and
    /// cap 37 so the most common relief move (6 → 5) is invisible in the instrument bar.
    @Test("Par is deliberately non-injective across the eight bands")
    func parIsNonInjective() {
        #expect(Set(Band.allCases.map(\.par)).count < Band.allCases.count)
        #expect(Band.contextual.par == Band.guarded.par)
        #expect(Band.contextual.cap == Band.guarded.cap)
    }

    /// Signal 2, restated from E09·T04 so the inventory is checkable in one place: the ceiling is
    /// a function of lifetime maximum band served, never of the current round's band.
    @Test("The palette ceiling cannot be asked about the current round")
    func paletteCeilingIsLifetimeOnly() {
        let veteran = PaletteCeiling.opening.raised(toServe: .systemic)
        let afterAnEasyRound = veteran.raised(toServe: .literal)
        #expect(afterAnEasyRound.unlocked == veteran.unlocked)
    }

    /// Signal 3: eight shelves, one per band, and the ladder is legible only retrospectively.
    @Test("There are exactly eight shelves and they are the bands")
    func eightShelves() {
        #expect(Band.allCases.count == 8)
    }
}
```

And the lint itself, added to `Scripts/check-source-hygiene.sh` as **check 13**. Before writing it,
plant a violation and confirm the check is red:

```bash
# Plant, run, expect FAIL:
printf '\nlet planted = "Band \\(band.rawValue)"\n' >> Modules/Sources/MetaFeature/StatisticsView.swift
Scripts/check-source-hygiene.sh   # must exit non-zero naming check 13
git checkout -- Modules/Sources/MetaFeature/StatisticsView.swift
Scripts/check-source-hygiene.sh   # must exit zero
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter 'DroneStepTests|DifficultySignalsTests'` must fail on
missing symbols (`DroneStep`, `DifficultySignal`), and `Scripts/check-source-hygiene.sh` must fail on
the planted string before check 13 exists only if you wrote check 13 first — so write the check, plant
the violation, watch it fail, revert, watch it pass. A check that has never been red is a check nobody
has tested.

**Step 3 — implement** the minimum that turns it green. Files below.

**Step 4 — green, then refactor.** Fold any pattern check 13 shares with check 8 into one loop over a
shared banned-token list rather than two greps that will diverge.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Ladder/DroneStep.swift` |
| create | `HunchCore/Sources/Ladder/DifficultySignal.swift` |
| modify | `Scripts/check-source-hygiene.sh` — check 13 |
| create | `HunchCore/Tests/LadderTests/DroneStepTests.swift` |
| create | `HunchCore/Tests/LadderTests/DifficultySignalsTests.swift` |
| modify | `DECISIONS.md` — the statistics-screen exemption |
| modify | `tests.json` — `difficulty.three-signals`, `difficulty.drone-step`, `hygiene.check-13` |

## Implementation notes

### `DroneStep`

```swift
/// §10.5's one ambient signal, "sub-numeric by design": the Loom's procedural drone drops one
/// scale degree every two bands. Four steps across the ladder.
///
/// This type is an **ordinal**. It names no frequency, no interval and no duration — §13.8's cue
/// table is the single normative source for every sound in the app, and E20·T03 maps this
/// ordinal onto a degree of §13.8's five-limit scale. A `Hz` in this file is a bug.
public enum DroneStep: Int, CaseIterable, Comparable, Sendable {
    case ground = 0, first, second, third

    public init(band: Band) { self = Self(rawValue: (band.rawValue - 1) / 2)! }
}
```

Integer division by two, once, with the citation. `adjacentBandsOftenShareAStep` is the test that says
the mapping is 1·1·2·2·3·3·4·4 and not 1·2·3·4·5·6·7·8 — the second would make the drone a band
readout, which is the thing this whole task forbids.

The type lives in `Ladder` rather than in `Feedback`: it is a pure function of a band, `Feedback` does
not exist until phase 5, and `08 §7.3` says a target is created the day its owner section is
implemented. E20·T03 imports it.

### `DifficultySignal`

```swift
/// §10.5's inventory, as an enumerable value so "exactly three" is checkable. Each case names the
/// one type that renders it; nothing here draws anything.
public enum DifficultySignal: CaseIterable, Sendable {
    /// §5.4 — 7 unlit ticks at band 1, 29 at band 8. Rendered by `ParTickRow` (E08·T08).
    case parTickRowLength
    /// §4.4, §10.4 — lifetime maximum band served + 1. Rendered by `BenchPalette` (E09·T04).
    case paletteCeiling
    /// §11.2 — eight shelves by family. Rendered by `CodexRootView` (E15·T02).
    case codexShelves
}
```

This looks like documentation-as-code and it earns its place for one reason: `exactlyThreeSignals`
fails when someone adds a fourth, and the pull request that adds a fourth is exactly the pull request
that needs a design conversation. Keep the doc comments pointing at the owning view — that list is
what a reviewer checks check 13's scope against.

### Check 13 — what it greps, and where

Check 13 is four greps with one shared exemption list. Its scope is `Modules/Sources`, `App/` and
`Modules/Sources/HunchUI/Resources/Localizable.xcstrings`; `HunchCore` is out of scope because nothing
there can render.

1. **No band number reaches a rendered string.** Fail on `Text(`, `Label(`, `LocalizedStringResource(`
   or `String(localized:` whose argument interpolates `band`, `.rawValue` of a `Band`, `servedBand`,
   `targetDelta`, `servedDelta`, `ability`, `theta` or `difficulty`. Also fail on the identifiers
   `calibrationRound`, `reentryGrant`, `Absence`, `reach` and `relief` appearing anywhere under
   `Modules/Sources` outside `LoomFeature/Ladder.swift` — those are the engine's internals and a view
   has no business naming one.
2. **No difficulty vocabulary in the catalog.** Extend check 8's per-locale banned-token machinery
   with a second list: `level`, `difficulty`, `hard`, `easy`, `tier`, `rank`, `grade`, `band`,
   `advanced`, `beginner`, `expert`, and their equivalents in the other eleven locales. §1.13's
   list is about health claims; this list is about difficulty, and they are two lists sharing one
   loop, not one list.
3. **No difficulty colour.** Fail on any `HueColor`, `AccentColor`, `Color` or `.foregroundStyle`
   expression whose subject is a `Band`, and on any `switch` over `Band` inside
   `HunchCore/Sources/Tokens` or `Modules/Sources/HunchUI` that returns a colour token. §13.1's accent
   budget already forbids a colour ramp; this makes the specific misuse a build failure.
4. **No post-round acknowledgement.** Fail on any `switch`/`if` over a `Band`, `Serving`,
   `reach`, `relief` or `targetOrigin` inside `InscriptionView.swift`, `RevealPhase`'s beat sheet or
   any file matching `*Reveal*.swift`. §10.5's forbidden list ends with *"no post-round 'difficulty
   adjusted' acknowledgement of any kind"*, and the round-end screen is the only place one could
   appear.

Write each grep with `-nE`, print the offending file and line, and name **check 13** and the §10.5
citation in the failure message. `hunch-build-and-ci`'s roster table gains a row; the six separate
checker programs it lists run after, unchanged.

### The statistics screen — the one reconciliation this task must rule on

> **Ruling, to be recorded in `DECISIONS.md`.** §11.12 specifies a statistics screen with *"per band
> (8 rows) rounds served, solve rate, best probes against par"*. A per-band solve rate is a
> percentage, and §10.5 forbids "no percentage … tied to difficulty". Both are shipped requirements.
>
> They are reconciled by scope, not by dropping one. §10.5's forbidden list governs the **round** —
> what the player is told before, during and after playing — because its whole argument is that
> knowing the band in advance hands over the discovery cost `d` and makes the Rasch estimate
> unidentifiable. `StatisticsView` is retrospective chrome, one tap from the Profile, read-only, and
> §11.12 itself already forbids the two things that would break §10.5: *"no θ, no `difficulty`, no
> band number framed as a level, no percentile"*.
>
> The operative constraint is therefore: the eight rows are labelled by **family sigil** (E15·T09's
> marks), never by an integer or an ordinal word, and check 13's grep 2 covers the catalog side. A
> solve rate is a fact about the player's history, in the one screen where numerals are permitted
> (§11's preamble names three such places), and it is allowed there and **nowhere else**.
>
> Check 13's grep 1 therefore exempts `Modules/Sources/MetaFeature/StatisticsView.swift` from the
> percentage clause only, and from nothing else. The exemption is one path in one list with this
> ruling's `DECISIONS.md` anchor cited beside it.

### What this task deliberately does not do

It draws nothing and it plays nothing. The par tick row is E08·T08, the palette stamps are E09·T04, the
shelf plates are E15·T02, the drone is E20·T03. This task's product is one ordinal, one three-case
inventory, one build gate and one ruling — and the gate is the part that survives.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter 'DroneStepTests|DifficultySignalsTests'` is green.
- [ ] `Set(Band.allCases.map(DroneStep.init(band:))).count == 4` and the mapping is monotone non-decreasing.
- [ ] `grep -in 'hz\|frequency\|duration\|Cue' HunchCore/Sources/Ladder/DroneStep.swift` returns nothing outside the doc comment.
- [ ] `DifficultySignal.allCases.count == 3`.
- [ ] `Scripts/check-source-hygiene.sh` carries a numbered **check 13** with a §10.5 citation in its failure message, and `hunch-build-and-ci`'s roster table has the matching row.
- [ ] Check 13 was demonstrated red on **each of its four greps** in turn — a planted band interpolation, a planted catalog key `"difficulty"`, a planted `switch band { … return HueColor… }`, and a planted `if serving.band == .systemic` inside `InscriptionView.swift` — and green after each revert. All four transcripts go in `PROGRESS.md`.
- [ ] `grep -rn 'calibrationRound\|reentryGrant\|\breach\b\|\brelief\b' Modules/Sources | grep -v 'LoomFeature/Ladder.swift'` returns nothing.
- [ ] `DECISIONS.md` carries the statistics-screen ruling, and check 13's exemption list names the ruling's anchor.
- [ ] `tests.json` carries the three entries, with `hygiene.check-13`'s status naming the four planted-violation runs.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, `Scripts/check-source-hygiene.sh` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests **and the script** after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge
   over an unresolved finding.
4. Commit: `git commit -m "E11/T09: three signals, the drone ordinal, and hygiene check 13 for the absences"`

## Out of scope

- Drawing the par tick row and its crossing inversion — **E08·T08**.
- Drawing the palette and its locked stamps — **E09·T04**.
- Drawing the Codex shelf plates and the eight family sigils — **E15·T02/T09**.
- Synthesising the drone and mapping the ordinal onto §13.8's scale — **E20·T03**.
- `StatisticsView` itself, its 19 rows and its formatting — **E16·T11**.
- Check 8's health-claim lexeme list — **E01·T06**; this task adds a second list to the same loop.
- The VoiceOver announcements, which may name probes and marks but never a band — **E19·T05**.
