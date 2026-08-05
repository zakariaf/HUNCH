# audio-cues.md — when each cue fires, and the rules the synth obeys

Contents: [1 Read canon, do not remember it](#1-read-canon-do-not-remember-it) ·
[2 The interval logic](#2-the-interval-logic-the-part-that-is-judgment) ·
[3 The 15 cues and where each fires](#3-the-15-cues-and-where-each-fires) ·
[4 Voices, polyphony, envelopes](#4-voices-polyphony-envelopes) · [5 Mix and session](#5-mix-and-session) ·
[6 The Swift](#6-the-swift) · [7 Accessibility](#7-accessibility) ·
[8 Reduce Motion and Low Power](#8-reduce-motion-and-low-power) · [9 What would be wrong](#9-what-would-be-wrong)

---

## 1. Read canon, do not remember it

**`GAME_DESIGN.md` §13.8's cue table is the single normative source for every frequency, waveform,
attack, decay, peak and bus in the app.** This file does not restate one number of it. Open it:

```
grep -n '^### 13\.8 Audio' GAME_DESIGN.md      # then read from that line
```

Its own supersession clause, which is the reason to read it rather than the mode sections:

> Where §6.4's channel table or §6.8's beat sheets state a frequency, an interval or a duration — a minor
> second at 220/233 Hz, a 140 ms decay, a 220 Hz harmonic series — those numbers are superseded here and
> must be replaced by a citation.

The live trap: **§6.4 describes `reject` as a minor second, which is the opposite of the design.** Reject
is a just tritone a **fifth below** admit — a fall. A minor second above the same root is a rise, and a
rising reject undoes the whole scheme.

The Swift home for the parameters is `Modules/Sources/Feedback/Cue.swift`'s spec table
(`feedback-target.md` §2). Once it exists it is the value's only home and §13.8 is its specification; a
test asserts they agree.

## 2. The interval logic — the part that is judgment

Five-limit just intonation on D3. **Just, not tempered, because a beat-free perfect fifth is *audibly*
locked and a tempered one is not** — the whole point of `admit` is that it resolves. One ratio, 45/32, is
reserved **exclusively** for rejection and appears in no other cue's fundamental.

**Admit is a just fifth up; reject is a just tritone a fifth lower.** With no context whatsoever, admit is
*up and settled*, reject is *down and unresolved*. Every derived cue inherits from that pair:

| Cue | Relation to the pair | Why |
|---|---|---|
| `twin` | the verdict cue, quieter, one added octave partial | marks a repeat **without new information** — same answer, thinner |
| `strike` | built on the reject ratio, square and filtered | mechanical, dry: bookkeeping, not a verdict |
| `incorrect` | the reject dyad held, then falling a semitone | the machine settling, not a buzzer |
| `correct` | four voices ascending the scale, one per 90 ms | the chord *arrives*; it is the only cue that accumulates |
| `streak` | one added partial per streak step, capped at 5 | the chord *grows*; the reward is density, not volume |
| `drift.moment` | a partner detunes away over 480 ms | the pitch **slides off** — beat rate climbs 0 → 5.8 Hz |
| `bar` | low, square, heavily filtered, no pitch movement | a dead thunk: no give, the audible twin of the machined bar |

If a new cue is ever needed, derive it from this table. A cue that does not sit in the scale will be the
one thing in the app that sounds like a different product.

## 3. The 15 cues and where each fires

The frequencies are §13.8's. **The firing points are this file's, and they exist nowhere else as one
table.** Times are absolute in their sheet.

| Cue | Fires at | Sheet |
|---|---|---|
| `probe.submit` | PROBE / twin key depress, t 0 | `verdict-motion.md` §1 |
| `admit` | the verdict beat, t 260 — **same frame as the ring and the haptic** | `verdict-motion.md` §1 |
| `reject` | as `admit` | `verdict-motion.md` §1 |
| `twin` | as the verdict it wraps; it replaces that cue, it does not layer over it | `verdict-motion.md` §5 |
| `declare` | Seal press, t 0 — its 180 ms glide runs under the seal hold | `reveal-beats.md` §2 |
| `bar` | barred Seal press, and barred mode-key press on the Frame | `verdict-motion.md` §8 |
| `strike` | **t 1,300** of the first-strike sheet — a ruling; see `reveal-beats.md` §5 | `reveal-beats.md` §5 |
| `correct` | voices 1–2 at beat 4 (t 1,450), voices 3–4 at beat 6 (t 1,850), 90 ms apart | `reveal-beats.md` §3 |
| `incorrect` | t 640 of the strike or lost sheet; drops a semitone at t 1,060 | `reveal-beats.md` §5 |
| `codex.inscribe` | beat 5, t 1,630 — soft and long **underneath** everything else | `reveal-beats.md` §3 |
| `drift.moment` | t 870 (local 230 of the reveal), one continuous event across all three parts | `verdict-motion.md` §6 |
| `sieve.tick` | once per glyph **arrival**, metronomic | `verdict-motion.md` §7 |
| `sieve.hit` | tap resolves as a hit | `verdict-motion.md` §7 |
| `sieve.miss` | lawful glyph passes the sump untapped | `verdict-motion.md` §7 |
| `streak` | the streak bloom on `solvedClean`, on `InscriptionView` | §11.8 |

Two firing rules that are not in the table:

- **A correct pass in SIEVE fires nothing.** Silence is the reward. Adding a confirmation sound turns
  "do not tap the unlawful ones" into a second thing to listen for.
- **A tap outside the SIEVE gate band fires nothing.** No cue, no haptic, no foul.

## 4. Voices, polyphony, envelopes

- **Everything is computed per sample.** One `AVAudioEngine`, one `AVAudioSourceNode` into a mixer. No
  `AVAudioFile`, no buffers from disk, no assets — the brief bans audio files outright.
- **A fixed 8-slot voice array with an atomic head index, oldest-stolen, polyphony capped at 6.** SIEVE at
  maximum speed requests ~12 cues/s and the cap holds. The array is allocated once in `init`; the render
  block allocates nothing and locks nothing. Ownership of that hatch is
  `hunch-swift-concurrency/references/real-time-audio.md`.
- **Envelopes are AD only** — no sustain stage, no release stage. Decay is exponential to −60 dB over the
  stated time. A cue that needs a sustain is a cue that has outstayed its beat.
- **A 3-pole DC blocker sits on the source node**, and the master has a soft clipper. Both are in §13.8;
  neither is optional, because summing six sine voices with 4 ms attacks clips without them.
- **Sample rate follows `AVAudioSession.sharedInstance().sampleRate`**, and the source node is **rebuilt on
  a route change that alters channel count**. Hard-coding 44,100 gives a chipmunk on a 48 kHz route.

## 5. Mix and session

- **Buses:** play cues 0 dB, chrome cues −6 dB, `sieve.tick` −10 dB. Master ceiling −6 dBFS. No cue peaks
  above −12 dBFS.
- **Category `.ambient`, mode `.default`, options `[]`.** `.ambient` honours the hardware silent switch and
  mixes with other audio, so a podcast keeps playing and HUNCH sits over it. **Never `.playback`** —
  overriding the silent switch in a puzzle game is a hostile act, and §13.12 gate 11(a) asserts the exact
  triple automatically.
- **When `isOtherAudioPlaying`, drop the master a further −4 dB.** Never duck, pause or interrupt the other
  audio; gate 11(c) checks that by hand.
- **Interruptions:** on `.began` pause the engine; on `.ended` **with `.shouldResume`** restart, otherwise
  stay stopped until the next user action.
- **Lifecycle: the engine starts lazily on the first cue and stops after 20 s of silence**, so a player with
  sound off never instantiates an audio unit. Asserted as an engine-lifecycle test — no `AVAudioUnit`
  before the first cue, engine stopped 20 s after the last.
- **Settings: `Sound` (default on) and `Level` — Normal / Low (−8 dB). Two states, not a slider.**

## 6. The Swift

The scheduler takes the beat sheet, so a beat cannot move without its sound moving.

```swift
// Modules/Sources/LoomFeature/RevealCueSchedule.swift
struct RevealCueSchedule: Sendable {
    /// (offset from the Seal press, cue). Offsets are derived from the same [Beat] the view animates.
    static func onsets(for outcome: Outcome, marks: Int, beats: [C.Reveal.Beat]) -> [(Duration, Cue)] {
        var t = C.Reveal.sealHold
        var out: [(Duration, Cue)] = [(.zero, .declare)]
        for (index, beat) in beats.enumerated() {
            if let cue = Cue.reveal(beat: index, outcome: outcome, marks: marks) {
                out.append((t, cue))
            }
            t += beat.duration
        }
        return out
    }
}
```

```swift
// firing it — one Task, cancelled on skip, and the state it decorates was committed long before
@MainActor
func runReveal(_ outcome: Outcome, marks: Int) async {
    let schedule = RevealCueSchedule.onsets(for: outcome, marks: marks, beats: beats)
    let end = env.isReduceMotionEnabled ? C.Reveal.sealHold + Dur.reduceMotionReveal : Dur.reveal
    var elapsed = Duration.zero
    for (at, cue) in schedule where at <= end {          // past `end` ⇒ dropped, never rescheduled
        try? await Task.sleep(for: at - elapsed)
        elapsed = at
        cues.play(cue)
    }
}
```

The wrong forms:

```swift
// WRONG — a second, hand-written list of onsets. It will drift from the beat sheet within a week.
Task { try await Task.sleep(for: .milliseconds(1450)); cues.play(.correct) }

// WRONG — rescheduling a dropped onset into the shortened reveal.
// A haptic or a tone arriving after the screen has settled is a second event, not the same one.
let clamped = min(at, end)

// WRONG — the silent switch is not readable, so this is neither implementable nor verifiable.
if !AVAudioSession.isSilent { engine.start() }
```

## 7. Accessibility

- **Audio is one of three redundant channels and is never the only one.** §6.4: any one channel alone is
  sufficient. Every verdict is readable with sound off, haptics off and colour off, from ring geometry
  alone — that is §13.12 gate 3, played end to end with the screen curtain on.
- **VoiceOver utterances are posted at the same instant as the cue** and at priority `.high` so they
  interrupt. They do not replace the cue and the cue does not duck for them; `.ambient` mixing means both
  are audible.
- **Accessibility labels are audio, so numbers are spoken even though they are never drawn.** The no-text
  rule constrains rendered pixels only.
- **The silent switch cannot be read.** "Engine never started" is not claimable; what is checkable is the
  session triple, plus a manual check that output is inaudible and every verdict still reads.

## 8. Reduce Motion and Low Power

**Neither changes a cue.** Onsets keep their absolute positions under Reduce Motion; onsets past the
shortened end are **dropped, not rescheduled**. Low Power Mode suppresses long *haptics* and touches no
audio. If a change to a sound is being contemplated because a setting is on, the setting is the wrong
reason.

## 9. What would be wrong

- Shipping any audio file, sample or buffer from disk. Everything is computed per sample.
- Copying a frequency, envelope or peak out of §13.8 into a second file, or trusting §6.4's or §6.8's
  numbers over §13.8's.
- Building reject on a minor second, or on anything above admit. It is a tritone a fifth **below**.
- Using 45/32 as any other cue's fundamental.
- Tempering the scale, or "fixing" the fifth to 700 cents. The beat-free lock is the information.
- Allocating, locking or touching main-actor state in the render block.
- Category `.playback`, or any option that overrides the silent switch.
- Ducking, pausing or interrupting other audio.
- Starting the engine at launch, or leaving it running through `.background`.
- Hard-coding a sample rate, or not rebuilding the source node on a channel-count route change.
- Adding a volume slider. Two states — Normal and Low — because a slider invites a mix nobody tested.
- Sounding a correct pass in SIEVE, or a tap outside the gate band.
- Firing `twin` **and** the verdict cue. `twin` replaces it.
