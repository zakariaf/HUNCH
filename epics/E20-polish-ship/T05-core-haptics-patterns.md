# T05 — Core Haptics patterns

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | Core Haptics patterns (HAPTICS) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/haptic-patterns.md` §1 sends you to §13.9 rather than to memory and names the live trap — §6.4's `reject` ("two short transients at 0 ms and 55 ms, sharpness 0.3") is *superseded*, and the difference between a soft double and a hard bright one is the whole discriminability argument. §2 is that argument, which is the judgement half of this task. §3 is the eleven firing points. §4 is the arithmetic that makes the count eleven — `twin` is composed, `sieve.hit`/`sieve.miss` are two players. §5 derives the Low Power suppression once, here, rather than at eleven call sites. |

## Objective

At the end of this task §13.9's eleven patterns exist as pure `HapticPattern` values, keyed on
`Cue.HapticRow`, transcribed once, with the two parameterised rows expanding at the cache key rather
than at the count. A suite proves the property the whole design rests on: `admit` is **one** soft
event, `reject` is **two** sharp ones, and `bar` is the only high-intensity low-sharpness event in the
game — three corners of the (I, Sh) square that a thumb can separate with the screen face-down, which
is what §13.12 gate 12's three testers will be asked to do in T12.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.9 | **The single normative source** for every event kind, time, intensity and sharpness. Eleven table rows; the discriminability sentence; the supersession of §6.4's `reject`; `hapticIntensityControl` / `hapticSharpnessControl` on `drift.moment`; the Low Power rule |
| `GAME_DESIGN.md` | §6.4 | The channel table, **whose haptic numbers are superseded**. Read it only for "any one channel alone is sufficient" |
| `GAME_DESIGN.md` | §13.7.1 | The **local** clock §13.9's `law.declared.correctly` offsets are written in. `absolute = 640 + local` |
| `GAME_DESIGN.md` | §6.8 | The absolute clock the reveal is scheduled in — E09·T10 already published the conversion |
| `GAME_DESIGN.md` | §13.12 gate 12 | Three testers discriminate `admit` / `reject` / `bar` face-down without being told which is which. This task makes that possible; T12 runs it |
| `.claude/skills/hunch-motion-and-feedback/references/haptic-patterns.md` | §2–§5, §10 | The discriminability argument, the eleven firing points, why the count is eleven, the Low Power derivation, and the ten wrong turns |
| `.claude/skills/hunch-motion-and-feedback/references/reveal-beats.md` | §1, §3, §5 | The two clocks, and the already-converted absolute tables. **Read a haptic offset out of §3/§5, never straight out of §13.9** |

## TDD — the test comes first

As with the cue table, the suite asserts **relations, not digits**. A pattern table transcribed twice
is a pattern table that will diverge; a pattern table asserted by its corners cannot be mistranscribed
in the way that matters without a test going red.

**Step 1 — write the failing test.** Create `Modules/Tests/FeedbackTests/HapticPatternTests.swift`:

```swift
import Testing
@testable import Feedback

@Suite("The eleven patterns — §13.9", .tags(.unit, .presubmission))
struct HapticPatternTests {

    private func pattern(_ row: Cue.HapticRow) -> HapticPattern { HapticPatterns.pattern(for: row) }
    private func transients(_ row: Cue.HapticRow) -> [HapticPattern.Event] {
        pattern(row).events.filter { $0.kind == .transient }
    }

    // MARK: the discriminability triple — the load-bearing assertion in this file

    @Test("admit is ONE event, reject is TWO, bar is ONE")
    func theEventCounts() {
        #expect(transients(.admit).count == 1)
        #expect(pattern(.admit).events.count == 1)
        #expect(transients(.reject).count == 2)
        #expect(pattern(.reject).events.count == 2)
        #expect(transients(.bar).count == 1)
        #expect(pattern(.bar).events.count == 1)
    }

    @Test("reject is hard and bright; admit is soft, round and low")
    func theSharpnessOrdering() {
        #expect(transients(.reject).allSatisfy { $0.sharpness > transients(.admit)[0].sharpness })
        // reject's two events share one sharpness — it is a doubled texture, not a ramp
        #expect(Set(transients(.reject).map(\.sharpness)).count == 1)
        #expect(transients(.reject)[1].time > transients(.reject)[0].time)
    }

    @Test("bar owns the high-intensity low-sharpness corner alone")
    func barIsTheOnlyBluntHeavyEvent() {
        let barEvent = transients(.bar)[0]
        let others = Cue.HapticRow.allCases
            .filter { $0 != .bar }
            .flatMap { transients($0) }
        #expect(others.contains { $0.intensity >= barEvent.intensity
                               && $0.sharpness <= barEvent.sharpness } == false)
        #expect(barEvent.sharpness < transients(.admit)[0].sharpness)   // blunter even than admit
        #expect(barEvent.intensity > transients(.reject)[0].intensity)  // heavier than either verdict
    }

    @Test("probe.submit is quieter than either verdict — the answer outranks the question")
    func theQuestionIsQuieterThanTheAnswer() {
        let submit = transients(.probeSubmit)[0].intensity
        #expect(submit < transients(.admit)[0].intensity)
        #expect(submit < transients(.reject).map(\.intensity).min()!)
    }

    // MARK: the two parameterised rows

    @Test("law.declared.correctly gains one mark transient per mark earned", arguments: 1...3)
    func marksExpandAtTheKey(_ marks: Int) {
        let earned = HapticPatterns.pattern(for: .lawDeclaredCorrectly, n: marks)
        let markEvents = earned.events.filter { $0.label == .mark }
        #expect(markEvents.count == marks)
        #expect(zip(markEvents, markEvents.dropFirst()).allSatisfy { $0.time < $1.time })
        // §13.9: the marks get progressively stronger, so the third one lands hardest
        #expect(zip(markEvents, markEvents.dropFirst()).allSatisfy { $0.intensity < $1.intensity })
        #expect(markEvents.allSatisfy { $0.kind == .transient })
    }

    @Test("streak grows to five and then stops growing", arguments: [1, 2, 3, 4, 5, 6, 9])
    func streakIsCappedAtFive(_ step: Int) {
        let events = HapticPatterns.pattern(for: .streak, n: step).events
        #expect(events.count == min(step, 5))
        #expect(zip(events, events.dropFirst()).allSatisfy { $0.intensity < $1.intensity })
    }

    // MARK: twin is composed, not cached

    @Test("twin is a prefix transient plus the verdict pattern, offset — and is not a cached row")
    func twinComposes() {
        #expect(Cue.HapticRow.allCases.contains(where: { "\($0)" == "twin" }) == false)
        for verdict in [Verdict.admit, .reject] {
            let composed = HapticPatterns.composed(for: .verdict(verdict, isTwin: true), n: 0)
            #expect(composed.count == 2)
            #expect(composed[0].offset == .zero)              // the prefix
            #expect(composed[1].offset > .zero)               // the verdict, delayed
            #expect(composed[1].events == pattern(verdict == .admit ? .admit : .reject).events)
            // the prefix is softer and blunter than the verdict it introduces
            #expect(composed[0].events[0].intensity < composed[1].events[0].intensity)
        }
    }

    @Test("a plain verdict composes to exactly one pattern at zero offset")
    func plainVerdictIsNotOffset() {
        let composed = HapticPatterns.composed(for: .verdict(.admit, isTwin: false), n: 0)
        #expect(composed.count == 1)
        #expect(composed[0].offset == .zero)
    }

    // MARK: the clocks

    @Test("the reveal pattern's own offsets are LOCAL, and convert to E09's published absolutes")
    func localOffsetsConvertToAbsolute() {
        let registration = HapticPatterns.pattern(for: .lawDeclaredCorrectly, n: 3)
            .events.first { $0.label == .registration }
        let local = try! #require(registration).time
        #expect(RevealHapticSchedule.absolute(local: local) == .milliseconds(1_450))
        // beat 0's continuous starts at local zero, i.e. absolute 640 — the seal hold's end
        #expect(RevealHapticSchedule.absolute(local: .zero) == .milliseconds(640))
    }

    // MARK: Low Power

    @Test("Low Power suppresses patterns over 0.4 s and keeps their transients", arguments: Cue.HapticRow.allCases)
    func lowPowerSuppression(_ row: Cue.HapticRow) {
        let full = pattern(row)
        let reduced = full.underLowPower
        if full.duration > .milliseconds(400) {
            #expect(reduced.events.allSatisfy { $0.kind == .transient })
            #expect(reduced.events.count == full.events.filter { $0.kind == .transient }.count)
        } else {
            #expect(reduced == full)
        }
    }

    @Test("the three interesting Low Power cases, derived once")
    func lowPowerWorkedCases() {
        // drift.moment is purely continuous, so under Low Power it vanishes entirely — and that
        // is safe precisely because a haptic never carries information the other channels lack.
        #expect(HapticPatterns.pattern(for: .driftMoment).underLowPower.events.isEmpty)
        // law.declared.correctly keeps the registration landing and the N marks
        #expect(HapticPatterns.pattern(for: .lawDeclaredCorrectly, n: 3)
                    .underLowPower.events.count == 1 + 3)
        // law.broken keeps the crack and the settle
        #expect(HapticPatterns.pattern(for: .lawBroken).underLowPower.events.count == 2)
        // every short row is untouched
        #expect(HapticPatterns.pattern(for: .admit).underLowPower == HapticPatterns.pattern(for: .admit))
    }

    // MARK: the count

    @Test("eleven cached players, and every row is reachable from a cue")
    func elevenPlayers() {
        #expect(Cue.HapticRow.allCases.count == 11)
        let reached = Set(Cue.representatives.flatMap(\.hapticRows))
        #expect(reached == Set(Cue.HapticRow.allCases))
    }

    @Test("every pattern is non-empty and every event is inside the unit square")
    func wellFormed() {
        for row in Cue.HapticRow.allCases {
            let events = pattern(row).events
            #expect(events.isEmpty == false)
            #expect(events.allSatisfy { (0...1).contains($0.intensity) })
            #expect(events.allSatisfy { (0...1).contains($0.sharpness) })
            #expect(events.allSatisfy { $0.time >= .zero })
        }
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:FeedbackTests/HapticPatternTests | xcbeautify
```

Expect `cannot find 'HapticPatterns' in scope`. Watch `localOffsetsConvertToAbsolute` in particular:
if it fails after the table exists, the offsets were transcribed in the wrong clock, which is the
single most common bug in this area and the one `reveal-beats.md` §1 exists to prevent.

**Step 3 — implement.** Transcribe §13.9 row by row with the file open, once, and cross-check every
reveal offset against `reveal-beats.md` §3's already-converted table rather than converting by hand.

**Step 4 — green, then feel them.** Build to a device and play all three of `admit`, `reject` and `bar`
from the DEBUG gallery with the screen face-down before `/simplify`. If you cannot tell them apart,
neither can T12's testers, and the fix is in this file.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/HapticPatterns.swift` — the eleven rows, the twin composition, the Low Power derivation |
| modify | `Modules/Sources/Feedback/HapticPattern.swift` — `Event`, `Kind`, `Label`, `ControlCurve`, `duration`, `underLowPower` |
| modify | `Modules/Sources/Feedback/Cue.swift` — `var hapticPatterns: [HapticPattern]` resolving through `HapticPatterns.composed(for:n:)` |
| create | `Modules/Tests/FeedbackTests/HapticPatternTests.swift` |
| modify | `DECISIONS.md` — the `strike` firing-point ruling adopted from `reveal-beats.md` §5 |
| modify | `tests.json` — the pattern-shape and Low Power entries |

## Implementation notes

### The discriminability argument is the design, and it is easy to "improve" into nothing

Three events must be separable **by feel alone, with the screen face-down**:

| Event | Shape | Corner of the (I, Sh) square |
|---|---|---|
| `admit` | **one** transient | soft, round, **low** |
| `reject` | **two** transients | hard, bright, **doubled** |
| `bar` | **one** transient | **high I, low Sh** — the only such event in the game |

**The contrast is count and sharpness together, not intensity.** Do not make `admit` crisper so it
"reads better": a sharp admit and a soft reject are the same event to a thumb, and gate 12's three
testers are not told which is which. Do not add a second transient to `admit` for emphasis — that
makes it a quiet reject. Do not add a second high-intensity low-sharpness event anywhere: `bar` owns
that corner alone, which is what lets a barred Seal read as *the machine refusing* rather than as a
verdict.

`barIsTheOnlyBluntHeavyEvent` above is the mechanical form of that paragraph and it is the test to
keep if you keep only one.

### Why the count is eleven, and what expands where

`haptic-patterns.md` §4's arithmetic, and it only closes one way:

- **`twin` is not a cached player.** It is a prefix transient plus **the verdict player** started
  +60 ms later. Caching it would mean two more players and would let a twin's verdict drift from a
  plain verdict's — the same argument that makes `twin`'s *audio* a derivation of the verdict cue
  rather than a hand-written row.
- **`sieve.hit` and `sieve.miss` share one printed row and are two players.**
- **`law.declared.correctly` and `streak` are parameterised** — by marks earned (1…3) and streak step
  (1…5, capped). They expand at the **cache key**, `(row, n)`, not at the count. Build on first use,
  cache, never rebuild. §13.9's "≈ 2 KB" is the pattern data, not the instance count.

### The clocks — convert once, in the right direction

§13.9's `law.declared.correctly` offsets are in §13.7.1's **local** clock; §6.8 is absolute;
`absolute = 640 + local`. A `CHHapticPattern` is *started* at a time and carries its own internal
offsets, so the conversion lands in exactly one place and it is not this file: **the pattern's event
times stay local, and `HapticCuePlayer` starts the pattern at the absolute time E09·T10's
`RevealHapticSchedule` publishes.** That is why `localOffsetsConvertToAbsolute` asserts the two agree
rather than asserting a converted table.

One documented label error to carry forward and not to "fix": §13.9 annotates
`law.declared.correctly`'s first continuous event *(beat 3, convergence)* while its own offsets put it
at beat 0, and §6.8 places it at beat 0. **The label is wrong; the timing is right.** Every other
offset in the table agrees with §13.7.1's beats exactly.

`reveal-beats.md` §5 additionally rules that the `strike` cue and haptic fire at absolute **1,300**,
on the dock, rather than at 640 — the GDD pins every other onset and leaves this one open, 640 already
carries the verdict pair, and two hard events on one frame would blur exactly the discriminability
gate 12 tests. Adopt it and record it in `DECISIONS.md`.

### The Low Power derivation, done once

**Patterns longer than 0.4 s are suppressed under `isLowPowerModeEnabled`; transients still fire.**
Applied to the eleven that is a short and slightly surprising list, so derive it once as a property on
the value rather than at eleven call sites:

```swift
extension HapticPattern {
    /// §13.9: over 0.4 s ⇒ transients only. `haptic-patterns.md` §5 works the eleven rows.
    var underLowPower: HapticPattern {
        duration > .milliseconds(400)
            ? HapticPattern(events: events.filter { $0.kind == .transient }, offset: offset)
            : self
    }
}
```

`drift.moment` vanishing entirely is the interesting case, and it is safe for exactly the reason the
rule is safe: **haptics never carry information that is not also visual and audible.** The DRIFT
moment still has its brass rule drawing through the ribbon and its detuning partner tone. Check that
property before adding any pattern — if suppressing it would lose something, the something belonged in
another channel.

Do **not** suppress everything under Low Power (that removes the beat-6 payoff), and do **not**
suppress nothing (that is the rule not implemented). Both wrong forms are in `haptic-patterns.md` §7.

### `drift.moment` is the one pattern that slides

It is a single continuous event with `hapticIntensityControl` and `hapticSharpnessControl` parameter
curves — the sensation *slides*, matching the audio detune, and the two are one gesture rather than
three. Model the curves as data on the `Event` (`[(time, value)]`) so the pattern stays a value and
the `CHHapticParameterCurve` construction lives in T06's builder.

### Never route any of this through `UIFeedbackGenerator`

It obeys a different switch, has none of these patterns, and would make two of our eleven behave
differently from the other nine. `CHHapticEngine` is the only path, and the `Haptics` toggle in §12.6
is the only control (T06).

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests/HapticPatternTests` green, all twelve tests.
- [ ] `HapticPatterns.pattern(for:n:)` is one exhaustive `switch` over `Cue.HapticRow` with no `default:`.
- [ ] `grep -rn 'UIFeedbackGenerator\|UIImpactFeedback\|UINotificationFeedback\|UISelectionFeedback' Modules/ App/` returns nothing.
- [ ] `grep -rn '0.055\|sharpness: 0.3' Modules/Sources/Feedback/` returns nothing — §6.4's superseded `reject` is not present in any form.
- [ ] Each of the eleven rows carries a trailing comment citing §13.9's row, and the transcription was checked against canon by eye.
- [ ] `admit`, `reject` and `bar` were felt on a real device, face-down, by the implementer, before the task closed; the note is in the commit body.
- [ ] `DECISIONS.md` carries the `strike`-at-1,300 ruling and the §13.9 label correction (beat 3 → beat 0), both with the reasoning.
- [ ] `tests.json` carries `haptics.discriminability-triple`, `haptics.eleven-players` and `haptics.low-power`, each with the `-only-testing` command; §13.12 gate 12 is entered as `pending` with T12 and three named testers as its owner.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T05: the eleven Core Haptics patterns — one soft, two sharp, one blunt heavy"`

## Out of scope

- `CHHapticEngine`, the cached `CHHapticPatternPlayer`s, the capability no-op, `resetHandler`/`stoppedHandler`, `isAutoShutdownEnabled` and the `Haptics` toggle — **T06**. This task ships values only and starts nothing.
- **When** each pattern fires: the verdict beat is **E08·T06**, the strike and reveal are **E09·T09/T10**, the hinge is **E12·T08**, SIEVE's two are **E14·T04**, the streak bloom is **E16·T04**.
- Running gate 12's three-tester panel — **T12**.
- Every frequency and envelope — **T03**. No sound is made here.
- The `Haptics` Settings row and its `UserDefaults` key — **E17·T06**.
