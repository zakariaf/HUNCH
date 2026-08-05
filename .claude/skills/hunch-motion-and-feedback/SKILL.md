---
name: hunch-motion-and-feedback
description: "Choreographs HUNCH's motion, audio and haptics as one timeline — the law reveal beat by beat, the admit and reject rings, screen transitions, the Reduce Motion substitution table, and the audio cues and haptic patterns keyed to the same beats. Use when animating anything, when a cue or haptic should fire, or when Reduce Motion, Low Power or a strike changes behaviour. Duration and easing values come from the token skill; this skill owns what happens when."
allowed-tools: Read Grep Glob
metadata:
  version: "1.0"
  owns: "beat sheets, cue and haptic firing points, the Reduce Motion substitution table, the Feedback target's shape"
---

## What exists right now

```!
root="."
for d in "$CLAUDE_PROJECT_DIR" . .. ../..; do
  [ -n "$d" ] && [ -f "$d/GAME_DESIGN.md" ] && root="$d" && break
done
if [ -d "$root/Modules/Sources/Feedback" ]; then
  all=$(grep -Hn 'case \|public func\|static let' "$root"/Modules/Sources/Feedback/*.swift | sed 's|.*/Feedback/||')
  n=$(printf '%s\n' "$all" | grep -c .)
  printf '%s\n' "$all" | head -40
  [ "$n" -gt 40 ] && echo "(… $n declarations total — 15 audio cues and 11 haptic patterns live here; grep Modules/Sources/Feedback/ for the rest)"
else
  echo "FEEDBACK TARGET NOT BUILT YET — references/feedback-target.md is the file to create."
fi
if [ -f "$root/HunchCore/Sources/Tokens/C.swift" ]; then
  grep -n 'enum Reveal\|enum Verdict\|sealHold\|Beat(' "$root/HunchCore/Sources/Tokens/C.swift"
else
  echo "C.Reveal / C.Verdict NOT BUILT YET — reveal-beats.md and verdict-motion.md are normative until they are."
fi
```

Trust that listing over anything written below it. If Swift and a reference file disagree, the Swift wins and the reference file is the bug.

## The rule

**Motion, audio and haptics are one sheet of paper.** A beat has a time, a curve, a picture, a sound and a feel, and they are written on the same row or they drift apart. Never add an animation in one file and its cue in another.

**The model never waits on an animation.** Every verdict, every declaration, every score and every Codex page is computed and committed to disk *before* the first frame of its animation (§6.1, §6.8, §7.9). Animation is decoration over settled state, which is why it can be skipped, interrupted, backgrounded or replayed from the Codex without changing a byte. If a piece of state only becomes true when an animation ends, that is the bug.

## To animate anything

1. **Find the beat sheet.** Reveal → `references/reveal-beats.md`. Verdict → `references/verdict-motion.md`. Anything that changes what is on screen → `references/transitions.md`. If your animation is not in one of those three, it is a fortieth micro-animation and §13.7's budget says do not add it: *at most one animation over 260 ms per screen state, and the play surface has exactly two recurring animations.*
2. **Name the duration and the easing as tokens.** `Dur.admit`, `Easing.settle` — never a number, never `.spring(response:)` inline. Values live in `hunch-design-tokens/references/durations-and-easing.md`; `Scripts/check-source-hygiene.sh` check 9 fails the build on a literal.
3. **Write the Reduce Motion row at the same time.** `references/reduce-motion.md` is a complete substitution table (§13.7.4) and an animation that is not in it does not ship. Writing the substitution later is how a row goes missing, and acceptance gate 9 checks by hand.
4. **Attach the cue and the haptic on the same row**, from `references/audio-cues.md` and `references/haptic-patterns.md`. One `cues.play(_:)` call at the beat, not two calls in two files.
5. **Check the three clocks below.** Most reveal and verdict bugs are a clock confusion, not a curve.

## The three clocks — confuse them and the round is wrong

| Clock | Governs | Where it is written |
|---|---|---|
| **commit** | when state becomes true | t = 0 of the beat, always. `Round` mutates, `PersistenceStore` is told, then the animation starts. |
| **input lock** | when the next tap is accepted | §6.5: 420 ms after a probe (**320 ms** under Reduce Motion). The Seal is edge-triggered with no queue; the PROBE and twin keys hold a single-slot queue. |
| **decoration** | when pixels stop moving | outlives the lock by design — the admit ring finishes at 520 ms, 100 ms after input unlocks. |

§13.7.2 calls the micro-responses "never blocking". That is true of the **rings** and false of the beat. Read §13.7.2's timings as offsets into §6.5's 260–520 ms window, never as an input policy.

## Where the detail lives

| Read this | When |
|---|---|
| `references/reveal-beats.md` | before touching the reveal — the correct, lost, strike and exhausted sheets in *absolute* time, every cue and haptic onset on the same rows |
| `references/verdict-motion.md` | admit, reject, twin, the DRIFT moment, the SIEVE tap, the barred-Seal pulse — anything that fires on a verdict |
| `references/transitions.md` | any navigation, sheet, shared element, scene-phase change, spin-up or pause |
| `references/reduce-motion.md` | while writing any animation, not after — the substitution table, the SIEVE ruling and the invariant test |
| `references/audio-cues.md` | when deciding *when* a cue fires, or when writing the synth's voice allocation and mix |
| `references/haptic-patterns.md` | when deciding *when* a haptic fires, or when writing `HapticCuePlayer` |
| `references/feedback-target.md` | when creating or editing `Modules/Sources/Feedback/*.swift` |

Four facts live outside this skill and are cited, never copied. Paths are relative to `.claude/skills/`:

- **every `dur.*` and `ease.*`** → `hunch-design-tokens/references/durations-and-easing.md`
- **the verdict ring's static geometry** (radius, weight, gap, arc count) → `hunch-shared-marks/references/verdict-ring.md`; this skill owns only how it moves
- **the real-time audio hatch** (`VoiceBank`, the one `@unchecked Sendable`) → `hunch-swift-concurrency/references/real-time-audio.md`
- **announcement wording and VoiceOver element traits** → `hunch-accessibility/references/voiceover-elements.md`; this skill owns only *when* an announcement is posted

To read canon rather than remember it: `grep -n '^#### 13\.7\|^### 13\.[89]' GAME_DESIGN.md`, then read from that line.

## Gotchas

- **Two beat sheets exist for the reveal and they are in different clocks.** §13.7.1 is *local* — beat 0 at t = 0. §6.8 is *absolute* — beat 0 at t = 640, after the seal hold. `absolute = 640 + local`. **§13.9's offsets are LOCAL** — they share §13.7.1's clock, which is why §13.9 labels `law.declared.correctly`'s registration transient t 0.810 as *(beat 4)* while §6.8 puts the same event at 1,450. Convert every one with `absolute = 640 + local` before scheduling. Write the code in absolute time throughout; `reveal-beats.md` §3 and §5 are the already-converted tables.
- **Beat 0 is a release, not a press.** §13.7.1 writes it as the Seal depressing because its sheet starts at the press; by §6.8 the press already happened at t = 0 and spent that travel, so beat 0 *releases* it. Same 90 ms, same phase, opposite sign.
- **The 640 ms seal hold is verdict-blind and is not shortened under Reduce Motion.** It is identical in content and duration for a correct and an incorrect declaration, which is what stops the answer being readable off the clock. Shortening it for some players hands them a different game.
- **The adjudication hold is a constant 260 ms regardless of verdict, band or contextuality.** Variable latency is a side channel: a Loom that thinks harder about hard glyphs leaks the family before probe 3.
- **§6.4 and §6.8 state frequencies, intervals and envelope times that are superseded.** §13.8 and §13.9 declare themselves the single normative source; where a mode section names a number, replace it with a citation. The live trap: §6.4's `reject` as "a minor second" is the *opposite* of the design — reject is a just tritone a **fifth below** admit, a fall, not a rise.
- **§13.9's first `law.declared.correctly` event is mislabelled, not mistimed.** It is annotated *(beat 3, convergence)* and lands at t 0.000–0.180, which is beat 0. §6.8 places it at beat 0. Every other offset in that table agrees with §13.7.1 exactly — fix the label, never the timing.
- **Under Reduce Motion, onsets past the shortened end are dropped, not rescheduled.** The reveal collapses to 900 ms absolute; a haptic arriving after the screen has settled is a second event, not the same one.
- **All six Reduce Motion durations now have L1 tokens.** `Dur.reduceMotionReveal` 260, `…Ring` 160, `…Swap` 140, `…Strike` 180, `…Expand` 200, `…Morph` 240 — `hunch-design-tokens/references/durations-and-easing.md` §2. The last four were raw numbers in §13.7.4 and had been copied into four component reference files before they were named; if you find a bare 140/180/200/240 in a substitution row anywhere, it is a leftover, not a new fact. Never borrow a same-valued token that means something else: `dur.ringAdmit` is also 200 and is the *normal* ring, not a substitution.

## Never

- Never let state depend on an animation completing. Commit first, animate second — always.
- Never write a duration, an easing curve or a spring literal. `Dur.*` and `Easing.*` or it does not compile past check 9.
- Never reuse a `dur.*` token because the number happens to match. `dur.sheet` is 320 and so is reveal beat 3; they are different facts and one of them will move.
- Never put a beat offset in Swift. Store the nine beat **durations** in `C.Reveal`; offsets are the running sum, and a test asserts the sum equals `Dur.reveal`. A stored offset and a stored duration are two homes for one fact.
- Never bounce, rubber-band or symmetrically ease a verdict or a reveal beat. Each beat accelerates into a stop or decelerates out of one; a symmetric curve erases its direction. §13.1 lists bounce-on-a-verdict as a PR-rejection offence.
- Never ship an animation without its Reduce Motion row, and never substitute a row by deleting the information the animation carried. SIEVE is the worked case: the lane keeps four stations and crossfades between them at the identical cadence.
- Never let a haptic carry information that is not also visual and audible, and never let audio carry information that is not also visual.
- Never make the reveal's skip threshold configurable or add a second one. Taps before absolute 1,040 ms are swallowed so the moment always starts; from 1,040 ms a tap snaps straight to `.settled`. VoiceOver disables tap-to-skip entirely and skips with the Magic Tap.
- Never call `AVAudioSession.setCategory(.playback)` or start the engine eagerly. `.ambient`, lazy on the first cue, stopped after 20 s of silence — overriding the silent switch in a puzzle game is a hostile act.
- Never add a "Light" haptic tier or a volume slider. Two states each, and the reason is in `references/haptic-patterns.md`.
