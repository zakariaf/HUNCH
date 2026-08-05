# T10 — The law-reveal beat sheets

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | T09 |
| **Delivers** | §14.1 `Reveal beat sheets` · `The law-reveal` (§13.7.1's money shot) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/reveal-beats.md` **is** this task: the two clocks and the `absolute = 640 + local` conversion, the four sheets already converted to absolute, the derivation that fixes the lost sheet's beat 3 at 220 ms, the `C.Reveal` Swift shape, and the RULING that the `correct` cue fires twice with two voices each. Its Never list is the review checklist. |
| `hunch-design-tokens` | **`Dur.reveal` and `Dur.revealLost` are L1; the nine beat durations are L2 in `C.Reveal`** — a beat is the motion skill's fact and borrowing an L1 token whose number happens to match is explicitly forbidden (`Dur.admit` is also 260 and will move first). This skill owns the `Easing` cases the beats name and the four Reduce Motion tokens. |
| `hunch-bench-instruments` | Beats 1, 5 and 6 act on instruments this epic already built: the Assay holds at full then contracts into the 64 pt page thumbnail, the machined bar retracts at beat 0, the Seal marks strike in at beat 6. Each of those states is the instrument's, not the beat's. |
| `hunch-swift-testing` | The whole task is an arithmetic invariant suite — sums, derived offsets, a phase count — and this skill owns the shape: assert the sum, never store the offset, and put every number that must match the GDD on the *expectation* side. |

## Objective

At the end of this task all four end-of-round sheets exist as one `phaseAnimator` over a `RevealPhase`
enum, driven by stored **durations** whose running sums reproduce §6.8's absolute tables exactly —
2,480 ms correct, 1,660 ms broken, 2,040 ms exhausted, 1,600 ms first strike — with one skip threshold
at 1,040 ms and the beats' named cue points published as data. Before this task the reveal is four
prose tables in two documents in two different clocks; after it, they are one array that cannot drift,
because there is nothing to drift.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.7.1 | The correct sheet in **local** time — nine beats, 1,840 ms, each duration and easing, and *"built as one `phaseAnimator` over a `RevealPhase` enum so the beats cannot drift apart"*. Plus the lost skeleton at 1,020 ms and the interruption rule at local t = 400 |
| `GAME_DESIGN.md` | §6.8 | The same sheets in **absolute** time, `absolute = 640 + local`; the correct total 2,480; the second strike at 1,660; the exhausted end at 2,040 with its 420 ms verdict and 600 ms pre-roll; the skip threshold at 1,040 ms; the three VoiceOver announcements at 640 / 1,450 / 1,850; and the reconciliation of beat 0 as a **release**, not a press |
| `GAME_DESIGN.md` | §6.1 | The phase durations column — `revealing(Outcome)` is 1,840 / 1,020 / 1,620 ms — and the invariant that the model never waits on an animation |
| `GAME_DESIGN.md` | §13.8 | The cue table: `declare`, `correct` (four voices, one per 90 ms, *"onsets aligned to reveal beats 4 and 6"*), `codex.inscribe`, `incorrect`, `strike` |
| `GAME_DESIGN.md` | §13.9 | The haptic table in **local** offsets, including the mislabelled `law.declared.correctly` opening event that lands on beat 0, not beat 3 |
| `GAME_DESIGN.md` | §13.7.4 | The two reveal rows: one `dur.reduceMotionReveal` crossfade, marks already struck, 900 ms absolute |
| `ios-swift-guide/03-WRITING-THE-CODE.md` | W29 | `RevealPhase` is an enum you own — no `default:` anywhere it is switched |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/LoomFeatureTests/RevealBeatTests.swift`.

This is the epic's gate row 5. Every literal below is quoted from §6.8's table on the **expectation**
side; the implementation side is always a derived running sum.

```swift
import Testing
import HunchCore
@testable import LoomFeature

@Suite("Reveal beat sheets", .tags(.unit, .presubmission))
struct RevealBeatTests {

    // §13.7.1: 90+140+260+320+180+220+240+260+130 = 1,840. Assert the sum.
    @Test("The correct sheet's durations sum to Dur.reveal")
    func correctSum() {
        #expect(C.Reveal.correct.map(\.duration).reduce(.zero, +) == Dur.reveal)
        #expect(Dur.reveal == .milliseconds(1_840))
    }

    // reveal-beats.md §4's derivation: 90+140+260+220+180+130 = 1,020 exactly.
    @Test("The lost sheet's durations sum to Dur.revealLost")
    func lostSum() {
        #expect(C.Reveal.lost.map(\.duration).reduce(.zero, +) == Dur.revealLost)
        #expect(Dur.revealLost == .milliseconds(1_020))
    }

    // THE GATE. §6.8's three absolute totals, each derived, never stored.
    @Test("The three absolute totals are §6.8's 2,480 / 1,660 / 2,040 ms")
    func absoluteTotals() {
        #expect(RevealTimeline.total(for: .inscribed) == .milliseconds(2_480))
        #expect(RevealTimeline.total(for: .broken) == .milliseconds(1_660))
        #expect(RevealTimeline.total(for: .exhausted) == .milliseconds(2_040))

        // …and each is built the way §6.8 builds it, so a change to one part moves the total.
        #expect(RevealTimeline.total(for: .inscribed) == C.Reveal.sealHold + Dur.reveal)
        #expect(RevealTimeline.total(for: .broken) == C.Reveal.sealHold + Dur.revealLost)
        #expect(RevealTimeline.total(for: .exhausted)
                == Dur.verdictBeat + C.Reveal.exhaustedPreRoll + Dur.revealLost)
    }

    // THE PHASE-COUNT ASSERTION, so §6.8 and §13.7.1 cannot drift apart: nine beats,
    // nine phases, and the lost sheet's six.
    @Test("The phase count matches the beat count on both sheets")
    func phaseCount() {
        #expect(RevealPhase.allCases.count == 9)
        #expect(C.Reveal.correct.count == RevealPhase.allCases.count)
        #expect(C.Reveal.lost.count == 6)
        // Beats 5–7 do not exist on the lost sheet, which is why it is an array and not a
        // flag on `correct`.
        #expect(RevealPhase.allCases.filter { $0.isPresent(on: .lost) }.count == 6)
    }

    // §6.8's absolute table for the correct declaration, beat by beat.
    @Test("Derived offsets reproduce §6.8's correct table")
    func correctOffsets() {
        #expect(RevealTimeline.absoluteOffsets(of: .inscribed).map(\.milliseconds)
                == [640, 730, 870, 1_130, 1_450, 1_630, 1_850, 2_090, 2_350])
    }

    // §6.8's lost table: beats 0–2 unchanged, beat 3 shortened, 4 recoloured, 5–7 skipped,
    // 8 at 1,530 settling at 1,660.
    @Test("Derived offsets reproduce §6.8's lost table")
    func lostOffsets() {
        #expect(RevealTimeline.absoluteOffsets(of: .broken).map(\.milliseconds)
                == [640, 730, 870, 1_130, 1_350, 1_530])
    }

    // §6.8: the cap-th probe's verdict resolves IN FULL first (420 ms), then 600 ms in
    // which the Bench opens itself with the law already assembled, then the lost skeleton.
    @Test("The exhausted sheet is verdict + pre-roll + lost skeleton")
    func exhaustedShape() {
        #expect(RevealTimeline.absoluteOffsets(of: .exhausted).first == .milliseconds(1_020))
        #expect(C.Reveal.exhaustedPreRoll == .milliseconds(600))
        #expect(RevealTimeline.playerStackIsEmpty(on: .exhausted))
    }

    // §6.8 / §13.7.1: "Skippable from t = 1,040 ms. … That is the one skip threshold;
    // there is no other." And it is DERIVED: 640 + 400.
    @Test("There is exactly one skip threshold, at 1,040 ms, and it is derived")
    func oneSkipThreshold() {
        #expect(RevealSkip.threshold == .milliseconds(1_040))
        #expect(RevealSkip.threshold == C.Reveal.sealHold + RevealSkip.localThreshold)
        #expect(RevealSkip.accepts(at: .milliseconds(1_039)) == false)
        #expect(RevealSkip.accepts(at: .milliseconds(1_040)) == true)
        #expect(RevealSkip.accepts(at: .milliseconds(2_400)) == true)
        // Skipping snaps straight to settled — no partial states, no half-drawn frame.
        #expect(RevealSkip.destination == .settled)
    }

    // §6.8: three announcements, at the verdict, the registration and the page — and each
    // is a BEAT OFFSET, not a literal, so moving a beat moves its announcement.
    @Test("The three VoiceOver announcements sit on beats 0, 4 and 6")
    func announcementPositions() {
        let offsets = RevealTimeline.absoluteOffsets(of: .inscribed)
        #expect(RevealAnnouncements.absolute == [offsets[0], offsets[4], offsets[6]])
        #expect(RevealAnnouncements.absolute.map(\.milliseconds) == [640, 1_450, 1_850])
        #expect(RevealSkip.isEnabled(underVoiceOver: true) == false)
    }

    // reveal-beats.md §3's RULING: `correct` fires TWICE, two voices each, so §13.8's
    // "onsets aligned to this beat and beat 6" is literally true.
    @Test("The correct cue fires twice, two voices each, on beats 4 and 6")
    func correctCueFiresTwice() {
        let firings = RevealCueSchedule.absolute(for: .inscribed).filter { $0.cue == .correct }
        #expect(firings.count == 2)
        #expect(firings.map(\.at.milliseconds) == [1_450, 1_850])
        #expect(firings.allSatisfy { $0.voices == 2 })
    }

    // Every published cue point is absolute, is at or after the hold, and lands on a beat.
    @Test("Every cue point is absolute and lands on a beat", arguments: Outcome.revealing)
    func cuePointsAreAbsolute(_ outcome: Outcome) {
        let offsets = Set(RevealTimeline.absoluteOffsets(of: outcome))
        for point in RevealCueSchedule.absolute(for: outcome) {
            #expect(point.at >= C.Reveal.sealHold || outcome == .exhausted)
            #expect(offsets.contains(point.at) || point.isContinuous)
        }
    }

    // §13.9's offsets are LOCAL. The conversion is the single most common bug in this area.
    @Test("The registration haptic converts from local 0.810 to absolute 1,450")
    func hapticsAreConverted() {
        #expect(RevealHapticSchedule.absolute(local: .milliseconds(810)) == .milliseconds(1_450))
        #expect(RevealHapticSchedule.absolute(local: .zero) == C.Reveal.sealHold)
        let registration = RevealHapticSchedule.events(for: .inscribed)
            .first { $0.label == .registration }
        #expect(registration?.at == .milliseconds(1_450))
    }

    // §6.8's reconciliation: beat 0 is a RELEASE, not a press. Same 90 ms, opposite sign.
    @Test("Beat 0 releases the Seal's depression")
    func beatZeroIsARelease() {
        #expect(C.Reveal.correct[0].duration == .milliseconds(90))
        #expect(RevealPhase.beat0.sealDepressionDelta == -C.Seal.depression)
    }

    // §6.1's invariant, restated where it is easiest to break.
    @Test("Nothing in the sheet mutates state; the outcome is settled before beat 0")
    func sheetIsDecoration() {
        #expect(RevealTimeline.isPureSchedule)   // no closures, no side effects in C.Reveal
    }
}
```

**Step 2 — run it and watch it fail.**

```bash
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:LoomFeatureTests/RevealBeatTests
```

The right failure is `cannot find 'RevealTimeline' in scope` — a missing symbol, not a malformed
assertion. Fourteen tests, fourteen failures. If any of them *passes* at this point, it is asserting
something about a type that already exists and it is not testing this task.

**Step 3 — implement.**

**Step 4 — green, then refactor.** Then run the reveal in the simulator with a stopwatch: the correct
sheet must end at 2.5 s from the press, and the skip must do nothing at 1.0 s and everything at 1.1 s.

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Reveal` with the ten beat durations, the two sheets, `sealHold` and `exhaustedPreRoll` |
| create | `Modules/Sources/LoomFeature/RevealPhase.swift` — the nine-case enum and `isPresent(on:)` |
| create | `Modules/Sources/LoomFeature/RevealTimeline.swift` — derived offsets, totals, `playerStackIsEmpty(on:)` |
| create | `Modules/Sources/LoomFeature/RevealView.swift` — the `phaseAnimator`, the per-phase composition |
| create | `Modules/Sources/LoomFeature/RevealSkip.swift` — the one threshold and its VoiceOver disable |
| create | `Modules/Sources/LoomFeature/RevealCueSchedule.swift` — the published cue and haptic points, as data |
| modify | `Modules/Sources/LoomFeature/Round.swift` — enter `revealing(_)` and drive `trigger` |
| modify | `Modules/Sources/HunchUI/AssayCanvas.swift` — beat 1 (holds at full) and beat 5 (contracts into the thumbnail) |
| modify | `Modules/Sources/HunchUI/SealView.swift` — beat 0's release and bar retraction, beat 6's mark strike-in |
| create | `Modules/Tests/LoomFeatureTests/RevealBeatTests.swift` |
| modify | `tests.json` — the three absolute totals, the phase count and the single skip threshold |

## Implementation notes

### Store durations, derive offsets, assert the sum

This is the whole design and `reveal-beats.md` §1 states it as a rule: *"Offsets are derived, never
stored. The nine beat durations are exactly contiguous: `t[n+1] = t[n] + dur[n]`, and they sum to
`Dur.reveal`. That is why §13.7.1 says the reveal is built as one `phaseAnimator` over a `RevealPhase`
enum — the beats **cannot** drift apart, because there is nothing to drift."*

A stored offset beside a stored duration is two homes for one fact and it will disagree within a
release. `C.Reveal` therefore holds ten `Duration` constants and two `[Beat]` arrays and **no
offsets**; `RevealTimeline.absoluteOffsets(of:)` is the running sum, seeded at `C.Reveal.sealHold`.

The beats are **L2** in `C.Reveal`, not `Dur.*`. `Dur.admit` is also 260 ms and will move first; a
beat is this skill's fact. The two totals `Dur.reveal` and `Dur.revealLost` *are* L1, because they are
the phase durations §6.1's table names.

### The two clocks, and the conversion that is the most common bug here

`absolute = 640 + local`. §13.7.1 numbers beats from the start of the reveal; §6.8 numbers them from
the Seal press; **§13.9's audio and haptic offsets are in §13.7.1's LOCAL clock** — its own labels
prove it, since `law.declared.correctly` annotates the transient at t 0.810 as *(beat 4, registration
lands)* and beat 4 is local 810 / absolute 1,450.

Write the code in **absolute** throughout. Convert once, at `RevealHapticSchedule.absolute(local:)`,
and never read an offset straight out of §13.9. `reveal-beats.md` §3 and §5's tables are already
converted; use those.

Two corrections that travel with the conversion:

- **Beat 0 is a release, not a press.** §13.7.1 writes it as the Seal *depressing* because its sheet
  starts at the press; by §6.8 the press already happened at t = 0 and spent that travel, so beat 0
  releases it. Same 90 ms, same phase, opposite sign — the phase count is unchanged.
- **§13.9's first `law.declared.correctly` event is mislabelled, not mistimed.** It is annotated
  *(beat 3, convergence)* and lands at t 0.000–0.180, which is beat 0. Fix the label, never the timing;
  every other offset in that table agrees with §13.7.1 exactly.

### The lost sheet's beat 3, derived

The GDD leaves it unstated. §13.7.1 fixes beat 8 at local t = 890 and the total at 1,020 ms. With
beats 0–2 unchanged (90 + 140 + 260 = 490) and beat 4 at 180, beat 3 is forced to **220**:
`90 + 140 + 260 + 220 + 180 + 130 = 1020` exactly. Any other value opens a dead gap, and a
`phaseAnimator` with a dead phase is a sheet nobody can read. `C.Reveal.convergeLost` is that 220, and
`lostSum` is what keeps it honest.

### The `phaseAnimator`, and how the lost sheet drops three beats

```swift
composition
    .phaseAnimator(RevealPhase.allCases, trigger: trigger) { content, phase in
        content.revealPhase(phase, outcome: outcome)
    } animation: { phase in
        guard let beat = phase.beat(in: beats) else { return nil }   // nil ⇒ no animation
        return beat.easing.animation(for: beat.duration)
    }
```

`animation:` returning `nil` for a skipped phase is how the lost sheet drops beats 5–7 without a
second enum, a second view or an `if` in the body. `phaseAnimator` advances when each phase's
animation finishes, so contiguity is not a convention here — it is the mechanism.

**No beat may ease in and out symmetrically.** Each accelerates into a stop or decelerates out of one;
that is what makes beats 2–3 read as *approach and misalignment*, beat 4 as *the pawl dropping*, and
beats 5–7 as *the result being filed*. Beat 2's 8 pt overshoot is the only overshoot in the app.
§13.1 lists a bounce on a verdict as a PR-rejection offence.

### The exhausted sheet is a different shape

There is no `sealing` phase, because there was no Seal press: `probing → adjudicating →
revealing(.exhausted)`.

1. The cap-th probe's verdict resolves **in full** first — `Dur.verdictBeat`, 420 ms. A paid-for bit is
   never withheld (§6.11 case 4).
2. `C.Reveal.exhaustedPreRoll`, 600 ms: the Dial's ramps go dark and inert, the dim tick row empties
   completely, and **the Bench opens itself with the Loom's law already assembled on the rails**.
3. The lost skeleton runs its 1,020 ms exactly, **with the player's stack empty** — so beat 3 is the
   law arriving on an unclaimed Bench.

`420 + 600 + 1,020 = 2,040`. Score 0, no page, `Outcome.exhausted`. `playerStackIsEmpty(on:)` is what
distinguishes it from `.broken`, which runs the same 1,020 ms with a stack that falls 24 pt and fades.

### The one skip threshold

Taps before absolute 1,040 ms are **swallowed**, so the moment always starts. A tap at ≥ 1,040 snaps
the phase straight to `.settled` — no partial states, no half-drawn frame. That is the one skip
threshold in the game and there is no other: no "hold to skip", no configurable swallow window, no
second threshold for the lost sheet.

Under VoiceOver tap-to-skip is **disabled entirely**, because it collides with tap-to-focus; VO users
skip with the Magic Tap (E19·T05). Backgrounding resumes at `.settled` — the state was committed at
t = 0, so there is nothing to replay.

### Publishing the cue points for E20

```swift
public struct RevealCuePoint: Hashable, Sendable {
    public let at: Duration          // ABSOLUTE, from the Seal press
    public let cue: Cue
    public let voices: Int           // §13.8's per-firing voice count
    public let isContinuous: Bool    // a continuous haptic spans beats; a cue does not
}
```

The schedule is a **function of the same `[Beat]` array** the animation reads, so a beat cannot move
without its sound moving. That is the point of publishing it here rather than letting E20 discover it:
E20·T01 attaches players to firing points that already exist and have already been timing-tested.

Nothing in this task makes a sound. `Round` calls `cues.play(_:)` on the `SilentCuePlayer` seam E08·T06
built; the schedule is what it iterates.

### Reduce Motion, in one line here and in full in T12

The 640 ms hold runs unchanged; then **one crossfade at `dur.reduceMotionReveal` to the settled
composition, marks already struck** — 900 ms absolute, both outcomes. Every audio and haptic onset
keeps its absolute position and the ones past 900 ms are **dropped rather than rescheduled**: a haptic
arriving after the screen has settled is a second event, not the same one. Wire the branch here;
T12 owns the table and its completeness test.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/RevealBeatTests` green — the epic's gate row 5.
- [ ] `grep -n 'offset\|at:' HunchCore/Sources/Tokens/C.swift` shows **no** stored beat offset inside
      `C.Reveal` — durations only.
- [ ] `grep -rn '0\.810\|0\.020\|1\.21\|1\.45' Modules/Sources/LoomFeature/` returns nothing: no
      §13.9 local offset was scheduled without conversion.
- [ ] `grep -c 'default:' Modules/Sources/LoomFeature/RevealPhase.swift` returns `0`.
- [ ] `grep -rn 'RevealSkip.threshold\|1040\|skipAfter' Modules/Sources` returns exactly one
      definition and no second threshold.
- [ ] `grep -rnE '\.easeInOut|\.bouncy|\.interpolatingSpring' Modules/Sources/LoomFeature/RevealView.swift`
      shows `.easeInOut` only on beats 1 and 7, which §13.7.1 assigns it.
- [ ] `tests.json` carries `reveal.absolute-totals`, `reveal.phase-count` and `reveal.one-skip-threshold`.
- [ ] Stopwatch check in the simulator: correct reveal ends at 2.5 s ± 0.1 from the press; a tap at
      1.0 s does nothing; a tap at 1.1 s ends it immediately.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:LoomFeatureTests/RevealBeatTests`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T10: the four reveal sheets in absolute time, with the phase-count assertion"`

## Out of scope

- **The 640 ms hold's own content.** **T09** ships `SealHold` and this task consumes it.
- **The first-strike sheet.** **T09**. It is not a `RevealPhase` and reuses no beat number.
- **The Inscription screen the sheet settles onto, and the page it mints.** **T11**.
- **The complete Reduce Motion substitution table and its completeness test.** **T12**.
- **Audio and haptic players.** **E20·T01–T06**. This task publishes the points and plays them into a
  `SilentCuePlayer`.
- **The three announcements' wording, Magic Tap and the rotors.** **E19·T05**; this task owns only the
  three *positions* and the fixed order verdict → evidence → bookkeeping.
- **DRIFT's hinge reveal** (seam, split, dead stretch, morph, hold). **E12·T08** — a different sheet
  about a different thing.
- **The Reveal → Codex page shared element.** **E15**; beat 5's thumbnail is drawn here so that it
  exists as a real view for the match to find.
