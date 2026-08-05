# reveal-beats.md — the four end-of-round sheets, in absolute time

Contents: [1 The two clocks](#1-the-two-clocks) · [2 The seal hold](#2-the-seal-hold-0640-ms-identical-for-both-outcomes) ·
[3 Correct — 2,480 ms](#3-correct--2480-ms) · [4 Lost — 1,660 ms](#4-lost--1660-ms) ·
[5 First strike — 1,600 ms](#5-first-strike--1600-ms-not-a-reveal) · [6 Exhausted — 2,040 ms](#6-exhausted--2040-ms) ·
[7 DRIFT's reveal](#7-drifts-reveal-is-a-different-sheet) · [8 The Swift](#8-the-swift) ·
[9 Interruption, skip, VoiceOver](#9-interruption-skip-voiceover) · [10 Reduce Motion](#10-reduce-motion) ·
[11 High Contrast](#11-high-contrast) · [12 What would be wrong](#12-what-would-be-wrong)

Canon: `GAME_DESIGN.md` §13.7.1 (local time), §6.8 (absolute time), §7.9 (DRIFT), §13.8, §13.9.
Swift home: `C.Reveal` in `HunchCore/Sources/Tokens/C.swift` (L2 — the token skill owns the layer, this
skill owns the members). Read the live values with the `!` block at the top of `SKILL.md`.

---

## 1. The two clocks

`absolute = 640 + local`. §13.7.1 numbers beats from the *start of the reveal*; §6.8 numbers them from
the *Seal press*. **§13.9's audio and haptic offsets are in §13.7.1's LOCAL clock, not §6.8's** — its
own labels prove it: `law.declared.correctly` annotates the transient at t 0.810 as *(beat 4,
registration lands)*, and beat 4 is local 810 / absolute 1,450; `law.broken`'s continuous t 0.020–0.420
is §6.8's 660–1,060. Convert with `absolute = 640 + local` before scheduling anything. **The §3 and §5
tables below are already converted** — read a haptic offset out of them, never straight out of §13.9.
Use absolute everywhere in code. The beat *numbers* are the join between the two documents and must
not be renumbered.

**Offsets are derived, never stored.** The nine beat durations are exactly contiguous:
`t[n+1] = t[n] + dur[n]`, and they sum to `Dur.reveal`. That is why §13.7.1 says the reveal is built as
one `phaseAnimator` over a `RevealPhase` enum — the beats *cannot* drift apart, because there is nothing
to drift. Store durations; compute offsets; assert the sum.

---

## 2. The seal hold, 0–640 ms, identical for both outcomes

| t | What happens |
|---|---|
| 0 | Seal depresses 3 pt. Input locks. **The comparison is performed and committed** — Codex page, θ update, Profile accumulators, novelty-ring entry, all of it, before a pixel moves. `declare` cue: a 180 ms exponential glide (§13.8). |
| 0–240 | A hairline circuit lights from each rule-tile, through the coupler, to the Seal — 80 ms apart. |
| 240–640 | A slow ring rotation in the Seal. Nothing else moves. |

This hold is **verdict-blind**: identical in content and duration whether the declaration was right or
wrong, so the answer is not readable off the clock. It is unchanged under Reduce Motion for the same
reason. Do not shorten it, do not branch on the outcome inside it, do not start prefetching the correct
sheet's assets in a way that changes its length.

---

## 3. Correct — 2,480 ms

Fires when `extension(declared) == extension(hidden)`.

| Beat | abs t | dur | Easing | Picture | Audio | Haptic (`law.declared.correctly`) |
|---|---|---|---|---|---|---|
| 0 | 640 | 90 | `ease.in` | Seal **releases** its 3 pt and the ring completes; the machined bar, if any, retracts off the trailing edge | — | continuous 640–820, I 0.15 → 0.55, Sh 0.10 |
| 1 | 730 | 140 | `ease.inOut` | all unlit Bench chrome → 0; the ribbon → `opacity.ribbonDim`; **the Assay holds at full** — for 140 ms it is the only thing at full brightness, and that is the beat that says *meaning, not syntax* | — | — |
| 2 | 870 | 260 | `ease.settle` | the player's rule-tiles leave their rails and gather into one centred stack, **8 pt overshoot** | — | — |
| 3 | 1130 | 320 | `ease.out` | the hidden law's tiles fade in **behind** the player's at 14 pt offset and `opacity.lawGhost`, then converge to zero offset | — | — |
| 4 | 1450 | 180 | `ease.linear` sweep, `ease.out` per tile | **Registration.** A 4 pt `accent.brass` hairline sweeps leading→trailing at **1,900 pt/s**; as it passes, each tile's stroke steps `stroke.primary` → `accent.brass`, staggered 0 / 60 / 120 ms by position | `correct`, voices 1–2 (90 ms apart) | transient I 0.75 Sh 0.85 — the pawl dropping — then continuous 1450–1690, I 0.60 → 0.10, Sh 0.40 |
| 5 | 1630 | 220 | `ease.dock` | the Assay's lit constellation contracts into a 64 pt page thumbnail and docks below the stack | `codex.inscribe` | — |
| 6 | 1850 | 240 | `ease.out` | Seal marks strike in, one per 80 ms; each scales 1.25 → 1.00 over 90 ms with a 60 ms brass bloom. A fracture, if present, draws as a hairline crack across the page | `correct`, voices 3–4 | **N** transients at 1850 / 1930 / 2010, N = marks earned (1–3), I 0.50 / 0.60 / 0.70, Sh 0.70 |
| 7 | 2090 | 260 | `ease.inOut` | the Codex page frame draws itself — a hairline rectangle stroked from the top-leading corner, clockwise | — | continuous 2090–2350, I 0.30 → 0.05, Sh 0.15 |
| 8 | 2350 | 130 | `ease.out` | a 3 pt global downward drift resolves to 0; the continue affordance fades in → `settled(.inscribed)` | — | — |

`90 + 140 + 260 + 320 + 180 + 220 + 240 + 260 + 130 = 1840 = Dur.reveal`. Assert it.

**Why it reads as a mechanism unlocking** (§13.7.1, and the reason no beat may be re-curved): beats 2–3
are *approach and misalignment*, beat 4 is *the pawl dropping*, beats 5–7 are *the result being filed*.
No beat eases in and out symmetrically; each either accelerates into a stop or decelerates out of one.

> **RULING — `correct` is fired twice, two voices each.** §13.8 gives the cue four voices one per 90 ms and
> §6.8 says its onsets are "aligned to this beat and beat 6". Beats 4 and 6 are 400 ms apart, so a single
> firing would put onsets 3 and 4 at 1,630 and 1,720, aligned to nothing. Two firings of two voices —
> 1450 / 1540 and 1850 / 1940 — make the sentence literally true and keep the chord growing across the
> registration and the marks. If this is ever contradicted, the cue table wins, not this file.

---

## 4. Lost — 1,660 ms

Second strike, or the outcome of a lost round that reached the Seal. Same skeleton, six beats.

| Beat | abs t | dur | Change from §3 |
|---|---|---|---|
| 0 | 640 | 90 | unchanged |
| 1 | 730 | 140 | unchanged |
| 2 | 870 | 260 | unchanged |
| 3 | 1130 | **220** | the hidden law fades in **alone**; the player's stack falls 24 pt and fades out over 180 ms. No convergence — there is nothing to register against |
| 4 | 1350 | 180 | the sweep is **`accent.cold`**, not brass |
| 5–7 | — | — | **skipped** — no thumbnail, no mark, no page to file |
| 8 | 1530 | 130 | as §3; settles at 1,660 → `Outcome.broken` |

> **Derivation, because the GDD leaves beat 3's lost duration unstated.** §13.7.1 fixes beat 8 at local
> t = 890 and the total at 1,020 ms (`Dur.revealLost`). With beats 0–2 unchanged (490 ms) and beat 4 at
> 180 ms, beat 3 is forced to **220 ms**: `90 + 140 + 260 + 220 + 180 + 130 = 1020` exactly. Any other
> value opens a dead gap in the sheet, and a `phaseAnimator` with a dead phase is a sheet nobody can
> read. Assert the sum, the same way as §3.

No Codex page, no score.

---

## 5. First strike — 1,600 ms, not a reveal

The round **continues**, so this is a counterexample presentation, not a reveal. It reuses no beat
numbers; do not model it as a `RevealPhase`.

| abs t | What happens |
|---|---|
| 640 | The Seal ring **breaks**: it splits at two points and the arcs slide 6 pt apart. `incorrect` cue — held, dropping a semitone at 1,060. `law.broken` haptic: transient I 0.85 Sh 1.00, continuous 660–1,060 I 0.55 → 0.00 Sh 0.75, settling transient I 0.35 Sh 0.20 at 1,060, **on the semitone fall** |
| 640–1000 | Bench dims to 30 %. The counterexample rises from its Assay cell and travels to centre at 96 pt. In contextual bands, **two** glyphs joined by the link arc, the leading one wearing the ghost frame |
| 1000–1300 | It takes **two rings at once** — inner = the declaration's verdict, outer = the Loom's, in the same open/closed aperture idiom as every probe verdict. The contradiction is legible with no colour |
| 1300–1600 | The counterexample docks **below** the ribbon's trailing end as a marginal island with a doubled outline and stays for the rest of the round. The Bench auto-collapses to the Dial |

The counterexample is **not a probe**: it does not increment `probesUsed`, does not become `prev`, and
draws with no link arc into the chain. Selection is `HunchCore`'s (§4.5, pure and tested); only the
presentation is here.

> **RULING — the `strike` cue and haptic fire at 1,300**, on the dock, not at 640. The GDD pins every
> other onset and leaves this one open. Reason: 640 already carries `incorrect` + `law.broken`, which are
> the *verdict*; `strike` is the *bookkeeping* — dry, mechanical, 120 ms — and belongs on the beat where
> the strike tick is inscribed and the Bench collapses. Two hard events on one frame would also blur the
> face-down discriminability that §13.12 gate 12 tests.

---

## 6. Exhausted — 2,040 ms

Cap reached. There is no `sealing` phase because there was no Seal press: `probing → adjudicating →
revealing(.exhausted)`.

1. **The cap-th probe's verdict resolves in full first — 420 ms.** A paid-for bit is never withheld.
2. **+600 ms:** the Dial's ramps go dark and inert, the dim tick row empties completely, and **the Bench
   opens itself with the Loom's law already assembled on the rails.**
3. **+1,020 ms:** the lost skeleton of §4 runs exactly, with the player's stack empty — so beat 3 is the
   law arriving on an unclaimed Bench.

Score 0, no page, `Outcome.exhausted`.

---

## 7. DRIFT's reveal is a different sheet

§7.9, five parts, and it is about the *hinge*, not about a law being right. Adjudication commits to disk
before it starts, as everywhere else.

1. **The seam**, 500 ms — a hairline sweeps the ribbon leading→trailing and stops at `t_hinge`, docking to
   the trigger-(b) seam marker if one exists.
2. **The split** — every ribbon tile is re-evaluated under both laws. Tiles `L₁` explains rise 18 pt; tiles
   `L₂` explains fall 18 pt; tiles both explain hold. The ribbon becomes two lanes forking at the seam.
3. **The dead stretch** — tiles probed after `t_evidence` that lie in the agreement set drop to
   `opacity.cellUnlit` and take the diagonal cancel hatch. No count, no label.
4. **The morph**, 900 ms eased — `L₁` assembles above the seam over 700 ms, staggered; `L₂` assembles below,
   except the shared leaves do not redraw, they *slide down*. **Only the edited leaf animates.**
5. **The hold** — two laws, one moving part, three seconds of silence, then the Codex page.

Reduce Motion replaces parts 1–4 with four crossfades of the **same total duration**; the two-lane
geometry and the single changed leaf remain, because they are information, not motion.

The 520 ms `drift.moment` (`Dur.drift`) is a different thing — it is inserted at local t = 230 of a
*round* reveal, i.e. absolute 870. It lives in `verdict-motion.md`.

---

## 8. The Swift

The sheet is one value. `phaseAnimator` advances when each phase's animation finishes, so contiguity is
not a convention here — it is the mechanism.

```swift
// HunchCore/Sources/Tokens/C.swift — L2, values only, no SwiftUI
extension C {
    public enum Reveal {
        public struct Beat: Sendable, Hashable {
            public let duration: Duration
            public let easing: Easing
            /// Unlabelled on purpose, so a beat sheet in source reads like the sheet in §3.
            /// The memberwise `init(duration:easing:)` alone would not accept these call sites.
            public init(_ duration: Duration, _ easing: Easing) {
                self.duration = duration
                self.easing = easing
            }
        }

        /// The nine beat durations, and §4's one substitution. **L2, not `Dur.*`:** a beat is
        /// this skill's fact, and borrowing an L1 token whose number happens to match is the
        /// thing SKILL.md's Never list forbids — `Dur.admit` is also 260 and will move first.
        /// §3's table is the picture of exactly these values; there is no second copy.
        public static let release: Duration = .milliseconds(90)
        public static let chromeOut: Duration = .milliseconds(140)
        public static let gather: Duration = .milliseconds(260)
        public static let converge: Duration = .milliseconds(320)
        public static let convergeLost: Duration = .milliseconds(220)   // §4's derivation
        public static let register: Duration = .milliseconds(180)
        public static let dock: Duration = .milliseconds(220)
        public static let strike: Duration = .milliseconds(240)
        public static let frame: Duration = .milliseconds(260)
        public static let settleOut: Duration = .milliseconds(130)

        /// Beats 0…8 in order. Offsets are the running sum; nothing stores an offset.
        public static let correct: [Beat] = [
            Beat(release,   .easeIn),      Beat(chromeOut, .easeInOut),
            Beat(gather,    .settle),      Beat(converge,  .easeOut),
            Beat(register,  .linear),      Beat(dock,      .dock),
            Beat(strike,    .easeOut),     Beat(frame,     .easeInOut),
            Beat(settleOut, .easeOut),
        ]

        /// §4's six beats. Beats 0–2 are §3's; beat 3 shortens; beats 5–7 do not exist,
        /// which is why the lost sheet is an array and not a flag on `correct`.
        public static let lost: [Beat] = [
            Beat(release,      .easeIn),   Beat(chromeOut,   .easeInOut),
            Beat(gather,       .settle),   Beat(convergeLost, .easeOut),
            Beat(register,     .linear),   Beat(settleOut,   .easeOut),
        ]

        /// The seal hold. Verdict-blind, and not substituted under Reduce Motion.
        public static let sealHold: Duration = .milliseconds(640)
    }
}
```

`.settle` and `.dock` resolve because `Easing.settle` and `Easing.dock` are static members of the L1
`Easing` enum (`hunch-design-tokens/references/durations-and-easing.md` §3), so leading-dot syntax
works in a position typed `Easing`. `.tap` would **not** resolve — `Duration` has no such member, and
the duration tokens are `Dur.tap`, which is a different fact from beat 0 anyway.

```swift
// Modules/Sources/LoomFeature/RevealView.swift
@MainActor
struct RevealView: View {
    let outcome: Outcome
    let env: RenderEnv
    let cues: any CuePlayer
    @State private var trigger = 0

    private var beats: [C.Reveal.Beat] {
        outcome == .inscribed ? C.Reveal.correct : C.Reveal.lost
    }

    var body: some View {
        composition
            .phaseAnimator(RevealPhase.allCases, trigger: trigger) { content, phase in
                content.revealPhase(phase, outcome: outcome)
            } animation: { phase in
                guard let beat = phase.beat(in: beats) else { return nil }   // nil ⇒ no animation
                return beat.easing.animation(for: beat.duration)
            }
            .onChange(of: trigger) { _, _ in cues.play(.declare) }
    }
}
```

Two things this shape buys, and both are the reason to keep it:

- **`animation:` returning `nil` for a skipped phase** is how the lost sheet drops beats 5–7 without a
  second enum, a second view, or an `if` in the body.
- **The cue schedule is a function of the same `[Beat]` array**, so a beat cannot move without its sound
  moving. See `audio-cues.md` §3 for the scheduler.

Guard the arithmetic in `LoomFeatureTests`:

```swift
@Test("Reveal beat durations sum to their total")
func revealSums() {
    #expect(C.Reveal.correct.map(\.duration).reduce(.zero, +) == Dur.reveal)
    #expect(C.Reveal.lost.map(\.duration).reduce(.zero, +) == Dur.revealLost)
}
```

---

## 9. Interruption, skip, VoiceOver

- **Taps before absolute 1,040 ms are swallowed**, so the moment always starts. A tap at ≥ 1,040 snaps the
  phase to `.settled` immediately — no partial states, no half-drawn frame. **That is the one skip
  threshold in the game; there is no other.**
- **Backgrounding resumes at `.settled`.** The state was committed at t = 0, so there is nothing to replay.
- **VoiceOver posts three announcements — at 640 (the verdict), 1,450 (beat 4, the law lands) and 1,850
  (beat 6, the page and its marks)** — and **disables tap-to-skip**, which would collide with
  tap-to-focus. VO users skip with the Magic Tap. Wording is
  `hunch-accessibility/references/voiceover-elements.md`; this file owns only the three positions and the
  fixed order *verdict → evidence → bookkeeping*.

## 10. Reduce Motion

The 640 ms hold runs unchanged; then **one crossfade at `dur.reduceMotionReveal` to the settled
composition, marks already struck** — 900 ms absolute, both outcomes. Every audio and haptic onset keeps
its absolute position, and the ones past 900 ms are **dropped rather than rescheduled**: a haptic arriving
after the screen has settled is a second event, not the same one. Full table in `reduce-motion.md`.

## 11. High Contrast

Nothing in this file changes. The reveal's colours resolve through `env.palette` like everything else, so
beat 4's sweep is `accent.brass` in all three themes and beat 4-lost is `accent.cold` in all three. Bloom
and the shader are off (`env.isBloomEnabled`, `env.isShaderEnabled` both false), which means beat 6's
"60 ms brass bloom" is a **stroke-weight step, not a glow** — the mark still changes, and it changes by
geometry. Do not branch on `theme` here; branch on the predicate.

## 12. What would be wrong

- Scheduling a §13.9 offset without adding 640. Its offsets are local; the sheets above are absolute.
- Starting the `phaseAnimator` before the 640 ms seal hold has run, so the reveal opens on the press.
- Storing beat offsets alongside beat durations. Two homes, one fact, guaranteed drift.
- Modelling the first strike as a `RevealPhase`. The round continues; there is no reveal.
- Branching the seal hold on the outcome, or shortening it under Reduce Motion. Both leak the answer.
- Committing the Codex page, the θ update or the Profile accumulators at the *end* of the reveal. They are
  committed at t = 0; the animation is decoration over settled state.
- Giving beat 4 a symmetric ease, or beat 2 anything but `ease.settle`. Beat 2's 8 pt overshoot is the
  only overshoot in the app.
- Adding a second skip threshold, a "hold to skip", or making the swallow window configurable.
- Letting the counterexample become `prev`, increment `probesUsed`, or draw a link arc into the chain.
- Re-deriving a verdict from the animation state. Verdicts come from `Round`, which got them from
  `Law.admits(_:after:)` before the first frame.
