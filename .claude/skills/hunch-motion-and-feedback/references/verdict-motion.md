# verdict-motion.md — everything that fires on a verdict

Contents: [1 The 420 ms beat](#1-the-420-ms-beat-the-frame-everything-else-hangs-on) ·
[2 Admit](#2-admit-duradmit) · [3 Reject](#3-reject-durreject) · [4 The non-colour encoding](#4-the-non-colour-encoding-and-why-it-is-geometry) ·
[5 Twin](#5-twin) · [6 The DRIFT moment](#6-the-drift-moment-durdrift) · [7 SIEVE](#7-sieve) ·
[8 The barred Seal](#8-the-barred-seal) · [9 The Swift](#9-the-swift) ·
[10 VoiceOver](#10-voiceover) · [11 Reduce Motion](#11-reduce-motion) · [12 High Contrast and Differentiate Without Colour](#12-high-contrast-and-differentiate-without-colour) ·
[13 What would be wrong](#13-what-would-be-wrong)

Canon: §6.4 (the three-channel encoding), §6.5 (the beat), §13.7.2 (the micro-responses), §9.5 (SIEVE).
The verdict ring's **static** geometry — base radius, stroke weight, gap width, arc count — is
`hunch-shared-marks/references/verdict-ring.md`. This file owns only how it moves.
Swift home for the animated parameters: `C.Verdict` in `HunchCore/Sources/Tokens/C.swift`.

---

## 1. The 420 ms beat — the frame everything else hangs on

| t (ms) | What happens |
|---|---|
| 0 | Key depresses 2 pt. **Input locks. The verdict is computed and appended to `RoundState.probes`; the snapshot is scheduled.** Throat glyph contracts to 0.92 over 90 ms, `ease.in`. `probe.submit` cue + haptic — quieter than either verdict. |
| 90–260 | **The adjudication hold.** Nothing moves but a hairline aperture rotating in the throat ring. |
| 260 | **Verdict lands.** Aperture opens or closes. Audio, haptic and the VoiceOver utterance fire **on the same frame**. §13.7.2's local t = 0 is this t = 260. |
| 260–420 | The tile buds off the throat, travels to the ribbon's trailing edge, the link arc draws over `dur.micro`, the ribbon re-pins, one par tick fills. On the probe that fills the **last** par tick, the par crossing fires here. |
| 420 | **Input unlocks.** |
| 420–520 | The rings finish. Non-blocking by design: the decoration outlives the lock so the next probe can start while the last one is still fading. |

**The hold is a constant 260 ms** regardless of verdict, band, or whether the law is contextual. Variable
latency is a side channel — a Loom that thinks harder about hard glyphs would leak the family before
probe 3, and the real evaluation cost is 5 ns to 0.4 µs either way.

**Fast probing.** Input locked 0–420 ms caps the rate at ~2.4 probes/s. The PROBE and twin keys hold a
**single-slot queue**: one tap during the lock is honoured at t = 420 and compresses the following ribbon
travel to 180 ms; a second tap during the lock is dropped. **The Seal has no queue and is edge-triggered**
— a queued second declaration would be catastrophic.

---

## 2. Admit, `dur.admit`

Local t is offset into §1's 260–520 ms window.

| local t | dur | Easing | What |
|---|---|---|---|
| 0 | 70 | `ease.out` | throat glyph scale 1.00 → **1.04** |
| 0 | `dur.ringAdmit` | `ease.out` | the ring **expands** R → **1.35 R**, opacity 0.9 → 0, weight 3 → 1 pt, `accent.brass`. **It stays closed.** |
| 70 | `dur.micro` | `ease.snap` | scale 1.04 → 1.00 |
| 140 | `dur.micro` | `ease.out` | the new ribbon tile slides in from the trailing edge; the ribbon scrolls to hold it 24 pt off the trailing margin |

## 3. Reject, `dur.reject`

| local t | dur | Easing | What |
|---|---|---|---|
| 0 | `dur.ringReject` | `ease.in` | the ring **contracts** 1.35 R → R, `accent.cold` |
| 0 | 130 | — | a **shudder**: ∓2 pt horizontal, leading → trailing → rest, amplitude 2 pt. **Not a bounce** — it does not overshoot past rest, and it is the only translation on the play surface |
| 160 | `dur.tap` | `ease.out` | the ring **breaks into 4 arcs** that separate 3 pt and fade |
| 140 | `dur.micro` | `ease.out` | ribbon tile slides in with a cold hairline and an **open** ring |

---

## 4. The non-colour encoding, and why it is geometry

> The non-colour encoding of the verdict is **ring direction and closure** — admit expands and stays
> closed, reject contracts and breaks. Colour, tone and haptic are three redundant copies layered on that.

This is the load-bearing decision in the whole feedback design and it is the reason for every asymmetry
above. In greyscale, with sound off and haptics off, the two are still opposite: *closed and growing* vs
*broken and shrinking*. Any change that makes admit and reject differ only by colour, only by pitch, or
only by count breaks §13.12 gates 3, 10 and 12 at once.

The three channels, from §6.4 — **any one alone is sufficient**:

| Channel | admit | reject |
|---|---|---|
| geometry (primary) | ring **completes** and grows | ring **collapses** and breaks |
| colour (redundant) | `accent.brass` | `accent.cold` |
| audio | a just perfect fifth — beat-free, it *locks* | a just tritone a fifth **below** — down, unresolved |
| haptic | **one** soft, round, low transient | **two** hard, bright transients |

Do not "improve" admit by making it crisper. A sharp admit and a soft reject are the same event to a
thumb, and gate 12 is three testers who were not told which is which.

---

## 5. Twin

The verdict animation at **0.7 × amplitude**, plus canon's doubled ribbon ring. A twin must not read as a
fresh discovery. Audio is the verdict cue at gain ×0.72 with one added partial an octave up; the haptic is
a soft prefix transient with the verdict pattern offset **+60 ms**.

**The split doubled ring** is not an animation and is not this file's: when a twin pair's two verdicts
differ, the ring draws **split** — one half open, one half closed, on a single drawing of a single glyph.
That is a rendered contradiction and it belongs to `hunch-shared-marks`. What is this file's: it does not
animate. It draws in its final state.

## 6. The DRIFT moment, `dur.drift`

Inserted at **local t = 230 of the reveal** — absolute 870, i.e. over reveal beat 2.

| part | dur | What |
|---|---|---|
| 1 | 220 | pre-swap ribbon tiles desaturate to `stroke.secondary` |
| 2 | 180 | a 2 pt brass rule draws **downward** through the ribbon at the swap index |
| 3 | 120 | post-swap tiles brighten |

`drift.moment` cue and haptic run 0–700 ms across all three parts as one continuous event: the pitch
slides off and the sensation slides with it. They are one gesture, not three.

## 7. SIEVE

**Tap response inside 120 ms: a `dur.tap` ring only. No scale, no shudder.** SIEVE resolves ~2.4 glyphs/s
at band 6 tempo 3; the full admit choreography would still be on screen when the next glyph arrives.

The four SIEVE outcomes and what fires (§9.5):

| Outcome | Definition | Feedback |
|---|---|---|
| **hit** | lawful, tapped in window | score, `sieve.hit` cue + haptic |
| **correct pass** | unlawful, not tapped | score, **nothing** — silence is the reward |
| **miss** | lawful, not tapped | no score. The sump shows the Loom's admit ring with the player's ring **absent**: a hollow result |
| **foul** | unlawful, tapped | penalty + one of three fouls. Two-ring conflict, `law.broken` haptic |

`sieve.tick` fires once per glyph **arrival**, metronomic, at −10 dB on its own bus. Taps outside the gate
band are discarded **silently** — no foul, no sound, no haptic. A fumble costs nothing, and making it cost
a click makes the gate feel smaller than its 375 × 88 pt.

Third foul → `fouling`: the stream halts mid-lane and freezes for **400 ms** before the reveal.

## 8. The barred Seal

**The offending rail pulses 3 × `dur.pulse`, `opacity.railPulse`. Nothing else moves.** No error text, no
error state, no modal — §4.3 abolishes the error state outright. `bar` cue and haptic: the only
high-intensity, low-sharpness event in the game, a dull heavy thud with no give, and the opposite corner
of the intensity/sharpness square from `reject`.

Which rail pulses comes from `SealBar` (`HunchCore`), which is data — `case inertRail(Int)`,
`unboundSocket(Int)`, `constantExtension` — not a `Bool`. A `Bool isSealBarred` cannot answer *which*, so
the animation would need a second parallel field.

The same drawing and the same pulse serve the **barred mode-rack key** on the Frame (§12.4, "the identical
drawing"). One owner: `hunch-shared-marks/references/machined-bar.md`.

---

## 9. The Swift

Both micro-responses are one `Shape` plus one `Animatable` progress, not two views. Driving them from a
single `0...1` keeps admit and reject the same object under Reduce Motion, where both collapse to a
crossfade of a static ring.

```swift
// Modules/Sources/HunchUI/VerdictRing.swift
struct VerdictRing: Shape {
    var progress: Double            // 0 = at rest, 1 = finished
    let verdict: Verdict
    let gapWidening: Double         // 1.0, or 2.0 under Differentiate Without Colour

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let base = min(rect.width, rect.height) / 2
        switch verdict {
        case .admit:
            // closed, growing: R -> C.Verdict.ringExpansion * R
            return Path(ellipseIn: rect.insetBy(
                dx: base * (1 - scale), dy: base * (1 - scale)))
        case .reject:
            // shrinking, then four arcs separating by C.Verdict.arcSeparation
            return brokenRing(in: rect, radius: base * scale,
                              separation: C.Verdict.arcSeparation * progress * gapWidening)
        }
    }

    private var scale: Double {
        switch verdict {
        case .admit:  1 + (C.Verdict.ringExpansion - 1) * progress
        case .reject: C.Verdict.ringExpansion - (C.Verdict.ringExpansion - 1) * progress
        }
    }
}
```

```swift
// the call site — one place, both verdicts, cue and haptic on the same statement
func land(_ verdict: Verdict, isTwin: Bool) {
    cues.play(.verdict(verdict, isTwin: isTwin))          // audio + haptic, same frame
    withAnimation(env.isReduceMotionEnabled
                  ? Easing.easeInOut.animation(for: Dur.reduceMotionRing)
                  : Easing.easeOut.animation(for: verdict == .admit ? Dur.ringAdmit : Dur.ringReject)) {
        ringProgress = 1
    }
}
```

The wrong form, and what it costs:

```swift
// WRONG — two views, two animations, two chances to diverge, and no shared Reduce Motion path
if verdict == .admit { AdmitRing().scaleEffect(1.35) } else { RejectRing().offset(x: shudder) }
// WRONG — a verdict read off animation state instead of off Round
let admitted = (ringProgress > 0 && ringScale > 1)
```

## 10. VoiceOver

- **The utterance is posted at §1's t = 260, on the same frame as the audio and the haptic** — not at 420,
  not when the ring finishes. Priority `.high` so it interrupts.
- **Order is fixed: verdict → evidence → bookkeeping.** "Admit. Hollow triangle, three pips, amber.
  Probe 12 of 23." A fast player can move on after two words. Wording and the glyph label's four-interpolation
  format string are `hunch-accessibility`'s; the position and the order are this file's.
- **Twin prefixes the same utterance.** It does not get its own sentence.
- The throat carries `.updatesFrequently`; the ring itself is never an accessibility element. A decorative
  ring that takes focus is one more swipe on every probe.

## 11. Reduce Motion

| Normal | Substitution |
|---|---|
| admit ring expands, `dur.ringAdmit` | crossfade a **static closed** ring at **1.18 R**, in then out, `dur.reduceMotionRing` |
| reject ring contracts + breaks, `dur.reject` | crossfade a **static broken** ring at **1.00 R**, `dur.reduceMotionRing` |
| throat scale 1.04 | none; opacity 1.0 → 0.72 → 1.0 over `dur.reduceMotionRing` |
| reject shudder | none; the cold opacity pulse above carries it |
| ribbon tile slide-in | `dur.reduceMotionSwap` crossfade **in place** |
| ribbon auto-scroll | instant `scrollTo` |

**The input lock shortens to 320 ms**, not to zero: the 260 ms hold is unchanged, then a 60 ms crossfade
replaces the contraction, travel and arc draw. Same audio, same haptic, same beat positions; a queued tap
is honoured at 320. The rings' own substitution runs 260–420 and, as always, never blocks.

**1.18 R is not 1.35 R.** The static closed ring sits between rest and full expansion so that a still frame
still reads as *larger than the glyph*; a static ring at 1.35 R reads as a second, unrelated circle.

## 12. High Contrast and Differentiate Without Colour

- **High Contrast** changes no timing here. It removes bloom and the shader (`env.isBloomEnabled`,
  `env.isShaderEnabled`), so admit's "expand and fade" is carried entirely by radius and weight — which is
  what §4 said it was carrying anyway. `accent.brass` and `accent.cold` resolve to their High Contrast
  values through `env.palette`; do not substitute a hue.
- **`isDifferentiateWithoutColorEnabled` moves no token and adds geometry**: the broken ring's gap
  **doubles**. That is the `gapWidening` parameter in §9 and it is the whole change — do not also lengthen
  the animation, add a second ring, or introduce a dash pattern that the counterexample rings already own.

## 13. What would be wrong

- Making the adjudication hold depend on the verdict, the band or the law's contextuality.
- Treating §13.7.2's "never blocking" as an input policy. It describes the rings, not the beat; the next
  probe cannot be issued before 420 ms (320 under Reduce Motion).
- Giving the Seal a queue, or giving the PROBE key a two-deep one.
- Any bounce or rubber-band on a verdict. The reject shudder settles *to* rest and never past it.
- Distinguishing admit from reject by colour, by pitch or by count **alone**. Each of the three channels
  must stand by itself.
- Making the admit haptic sharper "so it reads better". It then reads as reject to a thumb.
- Playing a sound or firing a haptic on a tap outside the SIEVE gate band.
- Animating the split doubled ring. It is a rendered contradiction, drawn in its final state.
- Adding an error label, an alert or a shake to the barred Seal. The pulse and the `bar` thud are the
  entire vocabulary, and §4.3 removed the error state on purpose.
- Reading a verdict out of `ringProgress`, `scaleEffect` or any other animation state. Verdicts live in
  `Round` and were committed before the first frame.
