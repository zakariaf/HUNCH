# haptic-patterns.md — when each pattern fires, and the rules the engine obeys

Contents: [1 Read canon, do not remember it](#1-read-canon-do-not-remember-it) ·
[2 The discriminability argument](#2-the-discriminability-argument-the-part-that-is-judgment) ·
[3 The 11 patterns and where each fires](#3-the-11-patterns-and-where-each-fires) ·
[4 Why the count is 11](#4-why-the-count-is-11) · [5 Low Power](#5-low-power-and-what-it-actually-suppresses) ·
[6 Engine and settings](#6-engine-and-settings) · [7 The Swift](#7-the-swift) ·
[8 Accessibility](#8-accessibility) · [9 Reduce Motion and High Contrast](#9-reduce-motion-and-high-contrast) ·
[10 What would be wrong](#10-what-would-be-wrong)

---

## 1. Read canon, do not remember it

**`GAME_DESIGN.md` §13.9's pattern table is the single normative source for every event kind, time,
intensity and sharpness in the app.** This file restates none of them. Open it:

```
grep -n '^### 13\.9 Haptics' GAME_DESIGN.md     # then read from that line
```

Its supersession clause, and the live trap it names:

> §6.4's "two short transients at 0 ms and 55 ms, sharpness 0.3" for `reject` is superseded by the
> `reject` row here (t 0.000 at Sh 0.90 and t 0.075 at Sh 0.90), and the difference matters — a soft, low
> double is admit's texture doubled, where reject must read as *hard and bright*, the opposite corner of
> the intensity/sharpness square from `bar`.

The Swift home is `Modules/Sources/Feedback/HapticCuePlayer.swift`'s pattern builders
(`feedback-target.md` §3). Once they exist they are the values' only home and §13.9 is their
specification; a test asserts they agree.

`I` = intensity, `Sh` = sharpness, throughout.

## 2. The discriminability argument — the part that is judgment

Three events must be separable **by feel alone, with the screen face-down**, and §13.12 gate 12 is three
testers who were not told which is which:

| Event | Shape | Corner of the (I, Sh) square |
|---|---|---|
| `admit` | **one** transient | soft, round, **low** |
| `reject` | **two** transients | hard, bright, **doubled** |
| `bar` | **one** transient | **high I, low Sh** — the only such event in the game. A dull heavy thud: no give |

**The contrast is count and sharpness together**, not intensity. Do not "improve" `admit` by making it
crisper: a sharp admit and a soft reject are the same event to a thumb, and the separation collapses.
Do not add a second transient to `admit` for emphasis — that makes it a quiet reject.

Everything else derives from those three corners. `probe.submit` is a key click **quieter than either
verdict**, so the answer always outranks the question. `strike` pairs a bright transient with a short
decaying continuous — mechanical, not painful. `drift.moment` is the only pattern whose sensation
**slides**, via `hapticIntensityControl` and `hapticSharpnessControl` ramps, matching the audio detune.

## 3. The 11 patterns and where each fires

Event times, intensities and sharpnesses are §13.9's. **The firing points are this file's.** Times are
absolute in their sheet.

| Pattern | Fires at | Sheet |
|---|---|---|
| `probe.submit` | PROBE / twin key depress, t 0 | `verdict-motion.md` §1 |
| `admit` | the verdict beat, t 260 — **same frame as the ring and the cue** | `verdict-motion.md` §1 |
| `reject` | as `admit` | `verdict-motion.md` §1 |
| `twin` | a prefix transient, then **the verdict pattern offset +60 ms** | `verdict-motion.md` §5 |
| `bar` | barred Seal press, and barred mode-key press on the Frame | `verdict-motion.md` §8 |
| `strike` | t 1,300 of the first-strike sheet — a ruling; see `reveal-beats.md` §5 | `reveal-beats.md` §5 |
| `law.declared.correctly` | its five events span the whole correct reveal: beat 0 (t 640), beat 4 (t 1,450), beat 6 (t 1,850 / 1,930 / 2,010), beat 7 (t 2,090) | `reveal-beats.md` §3 |
| `law.broken` | t 640 of the strike or lost sheet; the settling transient at t 1,060, **on the semitone fall** | `reveal-beats.md` §5 |
| `drift.moment` | t 870, one continuous 0–0.70 s event across all three parts | `verdict-motion.md` §6 |
| `streak` | the streak bloom on `solvedClean` | §11.8 |
| `sieve.hit` / `sieve.miss` | tap resolves as a hit / lawful glyph passes untapped | `verdict-motion.md` §7 |

Two firing rules not in the table: **a correct pass in SIEVE fires nothing**, and **a tap outside the gate
band fires nothing**.

> **§13.9's first `law.declared.correctly` event is mislabelled, not mistimed.** It is annotated
> *(beat 3, convergence)* and its own offsets are t 0.000–0.180, which is beat 0. §6.8 places it at beat 0.
> Every other offset in the table agrees with §13.7.1's beats exactly. Fix the label; never the timing.

## 4. Why the count is 11

§13.9 says "11 players", and the table has 11 rows. The arithmetic only closes under one reading, and it
is the right one:

- **`twin` is not a cached player.** It is a prefix transient plus **the verdict player** scheduled +60 ms.
  Caching it would mean two more players and would let a twin's verdict drift from a plain verdict's.
- **`sieve.hit` and `sieve.miss` share a row but are two players.**

That gives `probe.submit`, `admit`, `reject`, `bar`, `strike`, `law.declared.correctly`, `law.broken`,
`drift.moment`, `streak`, `sieve.hit`, `sieve.miss` = **11**.

**Two of the eleven are parameterised** and expand at the cache key, not at the count:
`law.declared.correctly` by marks earned (N = 1…3) and `streak` by streak step (N = 1…5, capped). Cache on
`(kind, n)`, build on first use, never rebuild. The stated ≈ 2 KB is the pattern data, not the instance
count.

## 5. Low Power, and what it actually suppresses

**Patterns longer than 0.4 s are suppressed under `isLowPowerModeEnabled`; transients still fire.**
Applied to the eleven, that is a short and slightly surprising list — derive it once, here, rather than at
eleven call sites:

| Pattern | Total | Under Low Power |
|---|---|---|
| `law.declared.correctly` | ~1.71 s | **transients only** — beat 4's landing and beat 6's N marks. The three continuous events drop |
| `law.broken` | ~0.45 s | **transients only** — the crack at t 0 and the settle at t 0.420 |
| `drift.moment` | 0.70 s | **nothing** — it is purely continuous and has no transient to keep |
| everything else | ≤ 0.36 s | unchanged |

`drift.moment` vanishing is the interesting case, and it is safe for exactly the reason the rule is safe:
**haptics never carry information that is not also visual and audible.** The DRIFT moment still has its
brass rule drawing through the ribbon and its detuning partner tone. Verify that property before adding
any pattern — if suppressing it would lose something, the something belonged in another channel.

## 6. Engine and settings

- `CHHapticEngine`. **All calls no-op when `CHHapticEngine.capabilitiesForHardware().supportsHaptics ==
  false`** — check once, at construction, and keep the player rather than making it optional.
- `isAutoShutdownEnabled = true`; **`resetHandler` and `stoppedHandler` recreate and re-prepare.** Without
  both, haptics die silently after the first media-services reset and nothing in the UI shows it.
- Patterns are compiled to `CHHapticPatternPlayer` **on first use** and cached.
- **iOS exposes no public read of the System Haptics switch for Core Haptics** — it gates
  `UIFeedbackGenerator` only. Our own `Haptics` toggle, default **on**, directly above `Sound` in §12.6's
  FEEDBACK section, is the player's control and is **honoured before any engine call**, not by muting
  output.
- **It is a toggle, not a three-way.** A "Light" tier would need a defined half-strength spelling of all
  eleven patterns, and every one of them already has a visual and an audible twin — so the honest options
  are *these patterns* or *none*.

## 7. The Swift

```swift
// Modules/Sources/Feedback/HapticCuePlayer.swift
@MainActor
public final class HapticCuePlayer: CuePlayer {
    private var engine: CHHapticEngine?
    private var players: [PatternKey: CHHapticPatternPlayer] = [:]
    private let isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    public var isEnabled = true          // the Settings toggle, checked before any engine call
    public var isLowPowerModeEnabled = false

    public func play(_ cue: Cue) {
        guard isSupported, isEnabled else { return }
        for pattern in cue.hapticPatterns {                      // twin => [prefix, verdict(+60 ms)]
            guard !(isLowPowerModeEnabled && pattern.exceedsLowPowerBudget) else {
                pattern.transientsOnly.map(schedule)             // transients still fire
                continue
            }
            schedule(pattern)
        }
    }

    private func schedule(_ pattern: HapticPattern) {
        do {
            let player = try players[pattern.key] ?? makePlayer(pattern)
            players[pattern.key] = player
            try player.start(atTime: CHHapticTimeImmediate + pattern.offset)
        } catch {
            // A haptic failure is never user-visible: every pattern has a visual and an audible twin.
            engine = nil
        }
    }
}
```

The wrong forms:

```swift
// WRONG — the toggle muting output instead of gating the call. The engine still spins up,
// still holds the haptic server awake, and still costs battery for a player who turned it off.
try player.start(atTime: 0)
if !isEnabled { engine?.stop() }

// WRONG — a "Light" tier by scaling intensity. Half of I 0.55 is not a softer admit;
// it is an admit that no longer separates from probe.submit at I 0.28.
let scaled = intensity * (tier == .light ? 0.5 : 1.0)

// WRONG — suppressing every pattern under Low Power. Transients still fire; only
// patterns over 0.4 s are cut, and dropping the beat-6 marks removes the payoff.
guard !isLowPowerModeEnabled else { return }

// WRONG — surfacing a haptic error. There is nothing for the player to do,
// and the information is already on screen and in the mix.
if error != nil { showAlert() }
```

## 8. Accessibility

- **Haptics never carry information that is not also visual and audible.** This is the property that lets
  the Settings toggle be a toggle and lets Low Power drop long patterns. Check it before adding a pattern.
- **Face-down discriminability is a shipped manual test** (§13.12 gate 12): `admit`, `reject` and `bar`,
  three testers, blind.
- Haptics are **independent of VoiceOver** and are not suppressed while it runs. They fire on the same
  frame as the utterance and the cue.
- Do not route a haptic through `UIFeedbackGenerator` for "consistency with the system". It obeys a
  different switch, has none of these patterns, and would make two of our eleven behave differently from
  the other nine.

## 9. Reduce Motion and High Contrast

**Neither changes a haptic.** Under Reduce Motion the onsets keep their absolute positions and the ones
past the shortened end are **dropped, not rescheduled**. High Contrast touches nothing here. The only
setting that changes a pattern is Low Power, and the only setting that silences one is the `Haptics`
toggle.

## 10. What would be wrong

- Copying an intensity, a sharpness or an event time out of §13.9 into a second file, or trusting §6.4's
  `reject` numbers over §13.9's.
- Making `admit` sharper, or `reject` softer, or giving either the other's event count.
- Adding a second high-intensity low-sharpness event. `bar` owns that corner alone.
- Caching a `twin` player instead of composing the prefix with the verdict player.
- Suppressing transients under Low Power, or suppressing nothing.
- Adding a "Light" tier or an intensity slider.
- Muting output instead of gating the call when the toggle is off.
- Omitting `resetHandler` or `stoppedHandler`, or leaving `isAutoShutdownEnabled` false.
- Leaving `CHHapticEngine` running into `.background`.
- Adding a pattern that carries information with no visual and audible twin.
- Surfacing a haptic failure to the player.
