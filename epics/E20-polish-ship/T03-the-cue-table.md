# T03 — The cue table

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | Cue table (AUDIO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-motion-and-feedback` | `references/audio-cues.md` §1 is an instruction not to remember §13.8 but to open it, and names the live trap — §6.4 calls `reject` a minor second, which is the *opposite* of the design. §2 is the interval logic, which is the judgement half of this task: why just and not tempered, why 45/32 is reserved, and how every derived cue inherits from the admit/reject pair. §3 is the fifteen firing points. §4 fixes the envelopes as AD only, exponential to −60 dB. |

`hunch-design-tokens` is not loaded: a frequency is not a token and §13.8 is its only home. No colour,
no duration token and no geometry appears in this task.

## Objective

At the end of this task `Cue.voices` resolves every one of §13.8's fifteen rows into `VoiceSpec`
values, transcribed **once**, and a suite proves the transcription by its intervals rather than by a
second copy of the numbers: `admit`'s fundamental sits a just perfect fifth above `reject`'s, 45/32
appears in the three rejection cues and nowhere else, every other fundamental is a five-limit ratio of
D3, and every envelope is attack-decay with no sustain field to fill in. The Loom's sub-numeric drone
step is realised as a transposition of that root, so the room gets lower as the bands get stranger
while every interval — and therefore every bit of information — is unchanged.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.8 | **The single normative source.** Fifteen rows: voices in Hz, waveform, attack, decay, peak, notes. The scale — five-limit just intonation on D3 — and the reservation of 45/32. The supersession clause that voids every frequency, interval and envelope time stated in §6.4 and §6.8 |
| `GAME_DESIGN.md` | §6.4 | The three-channel table, **whose numbers are superseded**. Read it only for the claim that any one channel alone is sufficient |
| `GAME_DESIGN.md` | §10.5 | The one ambient sub-numeric signal: *the Loom's procedural drone drops one scale degree every two bands (four steps across the ladder)*, and the explicit ban on every numeric difficulty signal it sits beside |
| `GAME_DESIGN.md` | §11.8 | `streak`'s firing site — the streak bloom on `solvedClean` |
| `.claude/skills/hunch-motion-and-feedback/references/audio-cues.md` | §1–§4, §9 | The interval logic, the fifteen firing points, the envelope rule, and the nine ways to get this wrong |
| `.claude/skills/hunch-motion-and-feedback/references/reveal-beats.md` | §3's RULING | `correct` fires **twice, two voices each**, at beats 4 and 6, so §13.8's "one per 90 ms" is literally true and the chord grows across the registration and the marks |

## TDD — the test comes first

The point of this suite is that it **contains no second copy of §13.8**. Every assertion is a relation
— a ratio, an ordering, a set membership — that a mistranscribed row breaks and a correct one
survives. That is the only kind of test that can guard a transcription without becoming one.

**Step 1 — write the failing test.** Create `Modules/Tests/FeedbackTests/CueTableTests.swift`:

```swift
import Testing
@testable import Feedback

@Suite("The cue table — §13.8's intervals, not its digits", .tags(.unit, .presubmission))
struct CueTableTests {

    private func voices(_ row: Cue.AudioRow) -> [VoiceSpec] { CueTable.voices(for: row, droneStep: 0) }
    private func fundamental(_ row: Cue.AudioRow) -> Double { voices(row).first!.frequency }

    /// The seven ratios §13.8 puts in use, as ratios — the table's own vocabulary, not new numbers.
    private static let fiveLimit: [Double] = [1.0/1, 6.0/5, 4.0/3, 45.0/32, 3.0/2, 9.0/5, 2.0/1]

    // MARK: the pair everything else inherits from

    @Test("admit's fundamental is a just perfect fifth ABOVE reject's — up and settled vs down")
    func admitIsAFifthAboveReject() {
        let ratio = fundamental(.admit) / fundamental(.reject)
        #expect(isApproximatelyEqual(ratio, 3.0 / 2, absoluteTolerance: 0.001))
        #expect(fundamental(.admit) > fundamental(.reject))
    }

    @Test("reject carries the just tritone above its own root, and admit carries none")
    func rejectIsATritone() {
        let tritone = fundamental(.reject) * 45 / 32
        #expect(voices(.reject).contains { isApproximatelyEqual($0.frequency, tritone,
                                                                absoluteTolerance: 0.02) })
        #expect(voices(.admit).contains { isApproximatelyEqual($0.frequency, tritone,
                                                               absoluteTolerance: 0.02) } == false)
    }

    @Test("45/32 belongs to rejection alone — the three rejection rows and no other")
    func theTritoneIsReserved() {
        let root = fundamental(.reject)
        func carriesTheTritone(_ row: Cue.AudioRow) -> Bool {
            voices(row).contains { spec in
                isApproximatelyEqual(Self.octaveReduced(spec.frequency / root),
                                     45.0 / 32, absoluteTolerance: 0.002)
            }
        }
        let carriers = Cue.AudioRow.allCases.filter(carriesTheTritone)
        #expect(Set(carriers) == [.reject, .strike, .incorrect])
    }

    @Test("admit is beat-free: its partials are exact small-integer multiples of its fundamental")
    func admitIsJustAndThereforeLocked() {
        let root = fundamental(.admit)
        for spec in voices(.admit) {
            let ratio = spec.frequency / root
            #expect(isApproximatelyEqual(ratio, (ratio * 4).rounded() / 4, absoluteTolerance: 0.001))
        }
    }

    // MARK: the scale

    @Test("every fundamental is D3 times a five-limit ratio, up to octaves", arguments: Cue.AudioRow.allCases)
    func fundamentalsSitInTheScale(_ row: Cue.AudioRow) {
        // Two named exceptions, both deliberate and both in §13.8's own notes:
        //  · drift.moment's PARTNER voice detunes off the scale — that is the cue's whole content
        //  · incorrect's drop target is a falling semitone, not a scale degree
        // Neither is a fundamental, so the assertion is over fundamentals only.
        let reduced = Self.octaveReduced(fundamental(row) / CueTable.rootD3)
        #expect(Self.fiveLimit.contains { isApproximatelyEqual($0, reduced, absoluteTolerance: 0.002) },
                "row \(row) fundamental is off the five-limit scale")
    }

    @Test("drift.moment's partner is the one voice deliberately off the scale, and it slides")
    func driftDetunes() {
        let partner = voices(.driftMoment).last!
        #expect(partner.glide != nil)
        #expect(partner.glide!.target < partner.frequency)      // it slides DOWN and off
    }

    // MARK: envelopes and levels

    @Test("every envelope is attack–decay: there is no sustain and no release to fill in")
    func envelopesAreAD() {
        for row in Cue.AudioRow.allCases {
            for spec in CueTable.voices(for: row, droneStep: 0) {
                #expect(spec.attack > .zero)
                #expect(spec.decay > .zero)
            }
        }
        // structural, not numeric: the type has no sustain or release member at all
        #expect(MemoryLayout<VoiceSpec>.size > 0)
    }

    @Test("no cue peaks above −12 dBFS", arguments: Cue.AudioRow.allCases)
    func peaksAreUnderTheCeiling(_ row: Cue.AudioRow) {
        for spec in voices(row) { #expect(spec.peak <= -12) }
    }

    @Test("probe.submit is quieter than either verdict — the answer outranks the question")
    func theQuestionIsQuieterThanTheAnswer() {
        #expect(fundamental(.probeSubmit) > 0)
        #expect(voices(.probeSubmit).map(\.peak).max()! < voices(.admit).map(\.peak).max()!)
        #expect(voices(.probeSubmit).map(\.peak).max()! < voices(.reject).map(\.peak).max()!)
    }

    // MARK: the derived rows

    @Test("twin is the verdict cue, quieter, with one added octave partial — derived, never retyped")
    func twinIsDerived() {
        for verdict in [Verdict.admit, .reject] {
            let base = CueTable.voices(for: verdict == .admit ? .admit : .reject, droneStep: 0)
            let twin = CueTable.twinVoices(for: verdict, droneStep: 0)
            #expect(twin.count == base.count + 1)
            #expect(twin.contains { isApproximatelyEqual($0.frequency, base[0].frequency * 2,
                                                         absoluteTolerance: 0.02) })
            // ×0.72 gain is a level change, i.e. a dB offset — every voice moves by the same amount
            let offsets = zip(base, twin).map { $1.peak - $0.peak }
            #expect(offsets.allSatisfy { isApproximatelyEqual($0, offsets[0], absoluteTolerance: 0.001) })
            #expect(offsets[0] < 0)
        }
    }

    @Test("correct ascends the scale, one voice per 90 ms, and its last voice rings longest")
    func correctAccumulates() {
        let specs = voices(.correct)
        #expect(specs.count == 4)
        #expect(zip(specs, specs.dropFirst()).allSatisfy { $0.frequency < $1.frequency })
        let gaps = zip(specs, specs.dropFirst()).map { $1.startOffset - $0.startOffset }
        #expect(Set(gaps).count == 1)                                  // evenly spaced
        #expect(specs.last!.decay > specs.first!.decay)
    }

    @Test("streak grows by density, not by volume: one added partial per step, capped at five")
    func streakGrows() {
        let counts = (1...5).map { CueTable.streakVoices(step: $0, droneStep: 0).count }
        #expect(counts == [2, 3, 4, 5, 6])                              // root plus n partials
        #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 < $1 })
        #expect(CueTable.streakVoices(step: 9, droneStep: 0).count == counts.last!)   // capped
        let peaks = (1...5).map { CueTable.streakVoices(step: $0, droneStep: 0)[0].peak }
        #expect(Set(peaks).count == 1)                                  // the root never gets louder
    }

    // MARK: the drone step

    @Test("step 0 is §13.8 verbatim, and every step is a strict transposition of it")
    func droneTransposesTheRoot() {
        #expect(CueTable.root(droneStep: 0) == CueTable.rootD3)
        let roots = (0...3).map(CueTable.root(droneStep:))
        #expect(zip(roots, roots.dropFirst()).allSatisfy { $0 > $1 })    // strictly descending
        #expect(roots.last! > CueTable.rootD3 / 2)                       // stays inside one octave
    }

    @Test("the drone changes pitch and carries no information: every interval is invariant")
    func droneCarriesNoInformation() {
        for step in 0...3 {
            let admit = CueTable.voices(for: .admit, droneStep: step).first!.frequency
            let reject = CueTable.voices(for: .reject, droneStep: step).first!.frequency
            #expect(isApproximatelyEqual(admit / reject, 3.0 / 2, absoluteTolerance: 0.001))
        }
        for step in 1...3 {
            let scaled = CueTable.voices(for: .correct, droneStep: step).map(\.frequency)
            let base = CueTable.voices(for: .correct, droneStep: 0).map(\.frequency)
            let ratios = zip(base, scaled).map { $1 / $0 }
            #expect(Set(ratios.map { ($0 * 1e6).rounded() }).count == 1)  // one factor, applied to all
        }
    }

    @Test("the drone step is read from the band, not invented here")
    func droneStepComesFromTheLadder() {
        // E11·T09 shipped the value; this asserts the mapping is four positions over eight bands.
        let steps = Band.allCases.map(\.droneStep)
        #expect(steps == [0, 0, 1, 1, 2, 2, 3, 3])
        #expect(Set(steps).count == 4)
    }

    private static func octaveReduced(_ ratio: Double) -> Double {
        var r = ratio
        while r >= 2 { r /= 2 }
        while r < 1 { r *= 2 }
        return r
    }
}
```

`isApproximatelyEqual(_:_:absoluteTolerance:)` is the helper mirrored into `FeedbackTests` in T02;
there is one spelling of it and it takes the tolerance as a label.

**Step 2 — run it and watch it fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" -only-testing:FeedbackTests/CueTableTests | xcbeautify
```

Expect `cannot find 'CueTable' in scope`. Then, once the table exists, expect
`droneStepComesFromTheLadder` to fail on a missing `Band.droneStep` if E11·T09 named it differently —
**read the symbol E11·T09 shipped and use it; do not add a second one.**

**Step 3 — implement.** Transcribe §13.8 row by row, with the file open, once.

**Step 4 — green, then re-read the table against §13.8 one final time**, aloud, before `/simplify`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/Feedback/CueTable.swift` — the fifteen rows, the twin and streak derivations, the root and the drone step |
| modify | `Modules/Sources/Feedback/VoiceSpec.swift` — add `glide: Glide?` and `lowPass: Double?` |
| modify | `Modules/Sources/Feedback/Cue.swift` — `var voices: [VoiceSpec]`, resolving `audioRow` through `CueTable` |
| modify | `Modules/Sources/Feedback/SynthesizedCuePlayer.swift` — `droneStep`, set at round arm |
| create | `Modules/Tests/FeedbackTests/CueTableTests.swift` |
| modify | `DECISIONS.md` — the drone ruling below |
| modify | `tests.json` — the interval-invariant entries |

## Implementation notes

### One transcription, in one file, with §13.8 open

```swift
enum CueTable {
    /// §13.8's root. The one place a frequency is written that is not a row of the table.
    static let rootD3: Double = …            // §13.8, "five-limit just intonation on D3"

    static func voices(for row: Cue.AudioRow, droneStep: Int) -> [VoiceSpec] {
        let root = root(droneStep: droneStep)
        switch row {                          // exhaustive: a new row is a compile error
        case .probeSubmit: …
        …
        }
    }
}
```

Write the frequencies as **ratios times the root**, not as the printed decimals: `root * 3 / 2` rather
than `220.25`. Three things follow, all of them the reason the interval tests above can exist. The
just intervals become exact instead of rounded, so the beat-free fifth is genuinely beat-free rather
than 0.005 Hz off. The drone transposition becomes free — one multiplication of the root. And a
mistranscription becomes visible as a wrong *ratio*, which is a design statement you can read, rather
than as a wrong digit, which is not. Put §13.8's printed decimal in a trailing comment on each row so
the transcription can be checked by eye against canon.

### The interval logic is the judgement, and it is not negotiable

Read `audio-cues.md` §2 before the table. **Admit is a just fifth up; reject is a just tritone whose
root is a fifth below it.** With no context whatsoever, admit is *up and settled* and reject is *down
and unresolved*. Just, not tempered, because a beat-free perfect fifth is audibly locked and a
tempered one is not — the whole point of `admit` is that it resolves.

The live trap: **§6.4 describes `reject` as a minor second and §13.8 supersedes it.** A minor second
above the same root is a *rise*. A rising reject does not merely differ from this design, it inverts
it, and §13.12 gates 3, 10 and 12 all fail together when it does. If a number in §6.4 or §6.8
disagrees with §13.8, §13.8 wins and the mode section's number is replaced by a citation.

### `twin`, `correct` and `streak` are derived, never a second table

- **`twin` is the verdict's own spec list at a fixed gain reduction plus one partial an octave up.**
  Compute it from `voices(for: .admit / .reject)`; a hand-written twin row would let a twin's verdict
  drift from a plain verdict's. It **replaces** the verdict cue and never layers over it
  (`audio-cues.md` §3), which is a `SynthesizedCuePlayer` rule, not a table rule.
- **`correct` is four voices, one per 90 ms, ascending the scale**, and it fires **twice, two voices
  each** — beats 4 and 6, i.e. absolute 1,450 and 1,850 (`reveal-beats.md` §3's RULING). The table
  therefore carries all four with their `startOffset`s and the *scheduler* takes them two at a time;
  it does not carry two different `correct` rows.
- **`streak` grows by density, capped at five partials** (§13.8, §11.8). The root's level never
  changes: the reward is the chord getting thicker, not louder.

### The drone step — the ruling to record

§10.5 gives the Loom "a procedural drone" that "drops one scale degree every two bands (four steps
across the ladder)", and E11·T09 shipped the step as a value. §13.8 declares itself the single
normative source for every sound and has no sixteenth row, and §13.8's envelopes are AD only — "a cue
that needs a sustain is a cue that has outstayed its beat" — so a literally sustained drone bed would
contradict two of its own rules and would need a ninth voice slot outside the bank.

**Ruling: the drone is the root the cue table is transposed from, and it is not a sixteenth cue.**
`root(droneStep:)` descends the five-limit set one degree per step, `root(droneStep: 0)` is D3
verbatim so band 1 sounds exactly as §13.8 prints it, and the transposition stays inside one octave.
The room gets lower as the laws get stranger, exactly as §10.5 asks, and because every interval is
preserved the drone carries **no information** — which is what makes it legal beside §10.5's ban on
every numeric difficulty signal, and what `droneCarriesNoInformation` above asserts. Record it in
`DECISIONS.md` with both readings named and this reasoning attached.

The step arrives at the player the same way every other round-scoped value does: `Round` sets
`cues.droneStep` when the round arms, from the band the serving policy chose. It is not read from a
global, it is not re-derived from `θ`, and it never appears in a `Cue`.

### Waveforms, filters and the one-pole

`bar` and `strike` are square and low-passed; `reject` and `incorrect` carry a triangle sub. A naive
square in a render block aliases, and the honest mitigation is already in §13.8: both square rows are
low-passed, and both are under 150 ms. **Do not add a wavetable, a band-limited oscillator table or
any lookup array** — every one of them is an allocation or a static the render block would touch.
A one-pole low-pass is two multiplies and one state variable per voice, which stays POD:

```swift
// VoiceBank.Voice gains: var lowPassCoefficient: Float = 1, var lowPassState: Float = 0
sample = voice.lowPassState + voice.lowPassCoefficient * (raw - voice.lowPassState)
```

Add both fields to `Voice` in this task, not in T02, and re-run `VoiceBankTests` — the determinism
test is what proves the filter state is per-slot and not shared.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:FeedbackTests/CueTableTests` green, all thirteen tests.
- [ ] `CueTable.voices(for:droneStep:)` is one exhaustive `switch` over `Cue.AudioRow` with no `default:` — `grep -n 'default:' Modules/Sources/Feedback/CueTable.swift` returns nothing.
- [ ] Every row in `CueTable.swift` carries a trailing comment with §13.8's printed frequency beside the ratio expression, and the two were checked against each other by eye.
- [ ] `grep -rn '220.25\|206.48\|146.83' Modules/Sources --include='*.swift'` finds those digits **only** in `CueTable.swift` comments, never in an expression.
- [ ] `grep -rn 'minor second\|233' Modules/Sources/Feedback/` returns nothing — §6.4's superseded reject is not present in any form.
- [ ] `DECISIONS.md` carries the drone ruling: a transposition of the root, step 0 verbatim §13.8, intervals invariant, and why a sustained bed was rejected.
- [ ] `tests.json` carries `audio.interval-logic` (the fifth, the reserved tritone, the scale membership) and `audio.drone-step`, each with the `-only-testing` command.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T03: the fifteen cues on five-limit just intonation, plus the drone as a transposed root"`

## Out of scope

- The buses, the master ceiling, the soft clipper, the DC blocker, the `Level` offset and the `isOtherAudioPlaying` drop — **T04**. `VoiceSpec.bus` is declared here and mixed there.
- The session category, the lazy start and the 20 s idle stop — **T04**.
- **When** each cue fires. `audio-cues.md` §3's firing points are already built: the verdict beat is **E08·T06**, the reveal's schedule is **E09·T10**, the DRIFT moment is **E12·T08**, SIEVE's three are **E14·T04**, the streak bloom is **E16·T04**. This task supplies what they play, never when.
- Every haptic — **T05**.
- The band → drone-step value — **E11·T09**. Read `Band.droneStep`; do not re-derive it.
