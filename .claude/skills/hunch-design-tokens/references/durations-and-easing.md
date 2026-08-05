# durations-and-easing.md — L1 time

Contents: [1 Why `Duration`](#1-why-duration) · [2 The durations](#2-the-durations) ·
[3 The easings](#3-the-easings) · [4 Reduce Motion](#4-reduce-motion) ·
[5 Forbidden](#5-forbidden) · [6 The boundary](#6-the-boundary)

---

## 1. Why `Duration`

Every time token is a `Swift.Duration`, never a `Double`. A bare `260` is ambiguous between
milliseconds and seconds and **both spellings appear in the GDD** — §13.7 works in ms, §13.8's
envelopes in ms, §11.11's Profile morph in seconds ("2.4 s"), §13.8's engine idle in seconds
("20 s"). The type removes the whole class of bug at zero cost, and `HunchCore` gets it from the
stdlib with no import.

The single conversion lives in the SwiftUI adapter:

```swift
// Modules/Sources/HunchUI/Duration+Seconds.swift
extension Duration {
    /// SwiftUI animations take seconds as `Double`. This is the only place that division happens.
    var seconds: Double {
        let (s, atto) = components
        return Double(s) + Double(atto) * 1e-18
    }
}
```

---

## 2. The durations

`Dur.<name>`. Values are PHOSPHOR §1.5, which is §13.7 made exhaustive.

| Token | ms | Token | ms | Token | ms |
|---|---|---|---|---|---|
| `dur.tap` | 90 | `dur.micro` | 120 | `dur.ringAdmit` | 200 |
| `dur.ringReject` | 160 | `dur.admit` | 260 | `dur.reject` | 250 |
| `dur.crossfade` | 220 | `dur.push` | 280 | `dur.sheet` | 320 |
| `dur.zoom` | 300 | `dur.shared` | 340 | `dur.streak` | 600 |
| `dur.drift` | 520 | `dur.reveal` | 1840 | `dur.revealLost` | 1020 |
| `dur.grainReseed` | 125 | `dur.pulse` | 90 | | |

The six Reduce Motion substitution durations. Each is shared by two or more components, which is
this file's own test for L1 rather than L2 — see §4.

| Token | ms | Substitutes |
|---|---|---|
| `dur.reduceMotionReveal` | 260 | both reveal sheets, and any beat inside them |
| `dur.reduceMotionRing` | 160 | the admit and reject rings, and the throat's opacity pulse |
| `dur.reduceMotionSwap` | 140 | an element that slid or scaled now switches **in place** — ribbon tile arrival, the Tally's dial collapse |
| `dur.reduceMotionStrike` | 180 | an accent event that has **already completed** — Seal marks, the streak bloom |
| `dur.reduceMotionExpand` | 200 | a zoom or a pulse replaced by a crossfade — the Assay expand, the barred-Seal rail |
| `dur.reduceMotionMorph` | 240 | a continuous shape change replaced by its endpoint — the DRIFT moment, the Profile morph |

**The budget these serve, and the only two rules about durations that are not values:** at most one
animation over 260 ms per screen state, and the play surface has exactly two recurring animations —
admit and reject — both under 260 ms and neither blocking input. `dur.reveal` (1840) and
`dur.revealLost` (1020) are the sanctioned exceptions: they are the once-per-round orchestrated
moment, and they are not on the play surface's recurring path.

`dur.grainReseed` 125 ms is 8 Hz, §13.6's grain reseed rate. It is a shader parameter, not an
animation; do not hand it to `withAnimation`.

---

## 3. The easings

`Easing.<name>`. Platform-free: the adapter maps each case to a SwiftUI `Animation`, and the CSS
column exists so a mockup and the app cannot drift.

| Token | SwiftUI | CSS |
|---|---|---|
| `ease.linear` | `.linear` | `linear` |
| `ease.in` | `.easeIn` | `cubic-bezier(.42,0,1,1)` |
| `ease.out` | `.easeOut` | `cubic-bezier(0,0,.58,1)` |
| `ease.inOut` | `.easeInOut` | `cubic-bezier(.42,0,.58,1)` |
| `ease.snap` | `.spring(response: 0.18, dampingFraction: 0.90)` | `cubic-bezier(.22,.61,.36,1)` |
| `ease.settle` | `.spring(response: 0.26, dampingFraction: 0.78)` | `cubic-bezier(.34,1.12,.64,1)` |
| `ease.dock` | `.spring(response: 0.30, dampingFraction: 0.85)` | `cubic-bezier(.30,.90,.40,1)` |
| `ease.sheet` | `.spring(response: 0.32, dampingFraction: 0.86)` | `cubic-bezier(.32,.88,.40,1)` |
| `ease.zoom` | `.spring(response: 0.30, dampingFraction: 0.88)` | `cubic-bezier(.30,.88,.40,1)` |
| `ease.shared` | `.spring(response: 0.34, dampingFraction: 0.86)` | `cubic-bezier(.34,.88,.40,1)` |

`ease.settle` is **the only overshoot in the app** — 8 pt, reveal beat 2, and nowhere else. Its CSS
equivalent is the only one whose control points leave the unit box, which is how you spot a misuse
in a mockup diff.

The adapter, in full:

```swift
// Modules/Sources/HunchUI/Easing+Animation.swift
extension Easing {
    func animation(for duration: Duration) -> Animation {
        switch self {
        case .linear: .linear(duration: duration.seconds)
        case .easeIn: .easeIn(duration: duration.seconds)
        case .easeOut: .easeOut(duration: duration.seconds)
        case .easeInOut: .easeInOut(duration: duration.seconds)
        case .spring(let response, let dampingFraction):
            .spring(response: response, dampingFraction: dampingFraction)
        }
    }
}
```

A spring ignores the duration argument by design — SwiftUI derives its own from `response`. That is
why `ease.snap` and friends carry no companion `dur.*` token and why pairing one with a duration in
a table would be a lie.

---

## 4. Reduce Motion

**Six durations exist for it**, listed in §2. Four of them — `Swap` 140, `Strike` 180, `Expand` 200,
`Morph` 240 — were raw numbers in §13.7.4 with no token, which is how they ended up copied into four
component reference files. They are **L1 and not L2** because each is shared by two or more
components; that is this file's standing test.

Do not borrow a same-valued token that means something else. `dur.crossfade` is 220 and none of these
is 220; `dur.ringAdmit` is 200 and is the *normal* admit ring, not a substitution; `dur.micro` is 120
and covers only the whole-Assay row.

**The substitution table itself is not here.** Twenty-three rows of "this animation becomes that
crossfade" are choreography, and they belong to `hunch-motion-and-feedback`. This file owns the six
numbers; that skill owns which animation each replaces, and owns the SIEVE row, where motion *is*
the mechanic and is replaced rather than removed.

`env.isReduceMotionEnabled` is the predicate. It also freezes the shader's `t` at 0
(`env.isShaderTimeFrozen`), which is a token-layer fact and is in `render-env.md`.

---

## 5. Forbidden

- **Any bounce or rubber-band on a verdict.** Admit and reject are the machine answering; a bounce
  makes the machine cute. §13.1 lists it as a PR-rejection offence.
- **Any symmetric ease on a reveal beat.** A reveal beat has a direction; `ease.inOut` erases it.
- **Any duration literal.** `withAnimation(.easeOut(duration: 0.26))` fails
  `check-source-hygiene.sh` check 9. Write `Easing.easeOut.animation(for: Dur.admit)`.
- **A second spring.** Six spring tokens already exist. A seventh means someone did not read this
  table.

---

## 6. The boundary

This file owns **how long** and **what curve**. It does not own **what happens when**: beat sheets,
the 8-beat reveal, micro-responses, transitions, audio cue alignment and haptic pattern timing are
`hunch-motion-and-feedback`. When that skill needs a duration it cites `dur.*` by name and does not
copy the number.
