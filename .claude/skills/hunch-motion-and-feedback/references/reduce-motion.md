# reduce-motion.md — the complete substitution table

Contents: [1 The rule](#1-the-rule) · [2 The table](#2-the-table-1374-complete) ·
[3 The four tokens §13.7.4 left unnamed](#3-the-four-tokens-1374-left-unnamed) · [4 SIEVE](#4-sieve-motion-is-the-mechanic-so-it-is-replaced-not-removed) ·
[5 Timing that does not change](#5-timing-that-does-not-change) · [6 The Swift](#6-the-swift) ·
[7 The tests](#7-the-tests) · [8 Conflicts in canon](#8-conflicts-in-canon) ·
[9 What would be wrong](#9-what-would-be-wrong)

Canon: §13.7.4 (the table), §9.8 (SIEVE), §13.12 gate 9 (acceptance).
Predicate: `env.isReduceMotionEnabled`. It also freezes the shader's `t` at 0
(`env.isShaderTimeFrozen`) — that is a token-layer fact and lives in
`hunch-design-tokens/references/render-env.md`.

---

## 1. The rule

**Every animation in the app appears in the table below. The substitution is a crossfade unless motion
*is* the mechanic.** Write the row at the same time as the animation, never after: a row that is missing
is invisible until a hand audit finds it, and §13.12 gate 9 is a hand audit — *"Reduce Motion on: nothing
translates, scales or rotates anywhere, including SIEVE; every substitution in §13.7.4 verified by hand."*

Three things a substitution may never do:

1. **Delete information the animation carried.** The rule is *replace every animation with a crossfade*,
   not *remove what the animation was showing*. §4 is the worked case.
2. **Change timing that the game is scored on.** Beat positions, hit windows, holds and previews are
   identical with the setting on and off.
3. **Merely shorten a gesture.** A 50 ms drag is still a drag; a 40 ms `matchedGeometryEffect` is still a
   translation and a scale. Gestures are substituted by controls, geometry matches are removed.

---

## 2. The table — §13.7.4, complete

| Animation | Normal | `isReduceMotionEnabled` |
|---|---|---|
| law reveal, correct | `dur.reveal`, 8 beats | one `dur.reduceMotionReveal` crossfade to the settled composition; **marks already struck** |
| law reveal, lost | `dur.revealLost` | `dur.reduceMotionReveal` crossfade to the final state |
| admit ring | expands, `dur.ringAdmit` | `dur.reduceMotionRing` crossfade of a **static closed** ring at **1.18 R**, in then out |
| reject ring | contracts + breaks, `dur.reject` | `dur.reduceMotionRing` crossfade of a **static broken** ring at **1.00 R** |
| throat scale 1.04 | 70 ms + `dur.micro` | none; opacity 1.0 → 0.72 → 1.0 over `dur.reduceMotionRing` |
| throat submit contraction to 0.92 | `dur.tap` | folded into the throat's opacity substitution above; no second crossfade |
| throat register crossfade on a Dial change | `C.Throat.registerCrossfade` | **unchanged** — a crossfade is already the substitution |
| reject shudder | `dur.tap` + 40 ms translate | none; the cold opacity pulse above carries it |
| ribbon tile slide-in | `dur.micro` slide | `dur.reduceMotionSwap` crossfade **in place** |
| ribbon auto-scroll | animated | instant `scrollTo` |
| Dial ↔ Bench | interactive spring | `dur.crossfade`; **the handle becomes a plain button** |
| Assay expand | `dur.zoom` zoom | `dur.reduceMotionExpand` crossfade; `matchedGeometryEffect` removed |
| Assay live morph, per cell | `dur.reduceMotionStrike` per cell | cells switch **instantly**; the whole Assay crossfades over `dur.micro` |
| Codex shared element | `dur.shared` | `dur.crossfade`; `matchedGeometryEffect` removed |
| screen push | `dur.push` | `dur.crossfade` |
| DRIFT moment | `dur.drift`, 3 parts | `dur.reduceMotionMorph` crossfade to the final marked ribbon |
| Seal marks strike-in | 3 × `dur.pulse` scale | already struck; `dur.reduceMotionStrike` crossfade |
| Seal / any key depression | 2 pt sink over `dur.tap` | **no translation** (gate 9); an interior step to `surface.cellLit` for `dur.tap` |
| streak bloom | `dur.streak` | `dur.reduceMotionStrike` crossfade |
| Profile morph | 2.4 s continuous morph | new shape **instantly**; `dur.reduceMotionMorph` crossfade |
| barred-Seal rail pulse | 3 × `dur.pulse` | rail crossfades to `accent.cold` at 0.5 α and back, `dur.reduceMotionExpand` |
| empty-rail hairline pulse | 1.6 s loop | **static** hairline at 60 % |
| Tally dial collapse, 5 → 2 stops | `dur.micro` | the two dial drawings crossfade in place over `dur.reduceMotionSwap`; **no cell slides** |
| idle Loom, drift + 8 s crossfade | continuous drift | the **crossfade stays** at its 8 s period; the drift stops. The glyph is static between changes |
| grain / scanline shimmer | reseeds at 8 Hz (`dur.grainReseed`) | **frozen at `t = 0`** — `env.isShaderTimeFrozen` |
| bloom pulse on admit | `dur.micro` | **static** bloom |
| **SIEVE glyph travel** | glyphs stream across the screen | **§4 — replaced, not removed** |

Every duration in that table is a token. The four that were bare numbers here until recently —
140, 180, 200, 240 — are now `dur.reduceMotionSwap` / `…Strike` / `…Expand` / `…Morph` (§3). The one bare
70 ms that remains is §13.7.2's normal-column figure for the throat scale's lead-in, not a
substitution; the throat's own register crossfade is `C.Throat.registerCrossfade`, declared once in
`hunch-bench-instruments/references/throat.md` §1.

Two values in that table are *geometry*, not timing, and they are the easiest rows to get wrong:

- **The static closed ring is at 1.18 R, not 1.35 R.** It sits between rest and full expansion so a still
  frame reads as *larger than the glyph*. At 1.35 R it reads as a second, unrelated circle.
- **The static broken ring is at 1.00 R**, its rest radius, because there was never an expansion to freeze.

## 3. The four tokens §13.7.4 left unnamed

§13.7.4 writes **140, 180, 200 and 240 ms** as bare numbers. Each is shared by two or more components —
140 by the ribbon tile and the Tally dial, 180 by the Seal strike-in and the streak bloom, 200 by the
Assay expand and the barred rail, 240 by the DRIFT moment and the Profile morph — which is
`hunch-design-tokens`' own test for **L1**, not L2. They are now named there:

| Token | ms | Rows above that use it |
|---|---|---|
| `dur.reduceMotionSwap` | 140 | ribbon tile slide-in · Tally dial collapse |
| `dur.reduceMotionStrike` | 180 | Seal marks · streak bloom · Assay per-cell morph |
| `dur.reduceMotionExpand` | 200 | Assay expand · barred-Seal rail pulse |
| `dur.reduceMotionMorph` | 240 | DRIFT moment · Profile morph |

Cite the token, never the number: `hunch-design-tokens/references/durations-and-easing.md` §2 is the
one home, and an inlined literal fails `check-source-hygiene.sh` check 9. Do not borrow a same-valued
token that means something else — `dur.ringAdmit` is also 200 and is the *normal* admit ring;
`dur.crossfade` is 220 and none of these is 220; `dur.micro` is 120 and covers only the whole-Assay row.

**These rows had a second copy.** Before the tokens existed, `hunch-bench-instruments`' throat, Seal,
ribbon, rule-tile, Assay, Fork, Tally and ramp files each carried their own raw-millisecond substitution
table, and four rows lived *only* there — the throat's submit contraction, its Dial register crossfade,
the key depression and the idle Loom's crossfade — while §1 of this file claimed completeness. They are
in §2 now. A component file states which rows apply to it and cites this table for what they become; it
never restates a duration.

## 4. SIEVE — motion *is* the mechanic, so it is replaced, not removed

§9.8, verbatim in effect: the lane keeps its four stations and a glyph **crossfades lip → lane → gate →
sump at the identical cadence**. Nothing translates. The gate dwell is byte-identical, the ±44 pt
actionable rule is byte-identical, and the **preview count** — how many glyphs are visible above the gate
at once — is unchanged at every band and every tempo step. Scoring and difficulty are unchanged.

**Why it is written that way.** Collapsing the lane to a single centre slot would delete the *preview*, and
the preview is not decoration: §9.3 budgets worst-case decision time as `preview + window` = 0.87 s +
0.226 s = **1.10 s**, and a one-slot substitution leaves roughly one inter-glyph period (≈ 0.34 s at band 6,
`s = 3`). That would cut the hardest decision in the game to a third of its length **for exactly the
players who asked for less motion**.

This is the reason the general rule is worded as *replace*, not *remove*. Reach for it whenever a
substitution is tempting to simplify.

## 5. Timing that does not change

| Thing | Value | Why it is invariant |
|---|---|---|
| the seal hold | 640 ms | verdict-blind; shortening it for some players hands them a different game |
| the adjudication hold | 260 ms | a variable hold is a side channel |
| every audio and haptic onset | absolute | onsets past the shortened end are **dropped, not rescheduled** |
| SIEVE `window(n)` and `preview(n)` | §9.3 | asserted equal with the setting on and off |
| the station a glyph occupies at time `t` | §9.3 | asserted equal with the setting on and off |
| the DRIFT reveal's total | §7.9 | parts 1–4 become four crossfades of the **same total duration** |

The one timing that *does* change: **the probe input lock shortens from 420 ms to 320 ms** (§6.5). The
260 ms hold is unchanged; a 60 ms crossfade replaces the contraction, the travel and the arc draw. A queued
tap is honoured at 320.

## 6. The Swift

Resolve the substitution **once, at the token seam**, not with an `if` at every call site. Eight files
each deciding what Reduce Motion means is how a row goes missing.

```swift
// Modules/Sources/HunchUI/Motion.swift
extension RenderEnv {
    /// The animation for a normal/substituted pair. One place decides; call sites just ask.
    func animation(_ normal: (Duration, Easing), reducedTo substitute: (Duration, Easing)) -> Animation {
        let (duration, easing) = isReduceMotionEnabled ? substitute : normal
        return easing.animation(for: duration)
    }
    /// For rows whose substitution is "none" — the animation is dropped entirely.
    func animationOrNone(_ normal: (Duration, Easing)) -> Animation? {
        isReduceMotionEnabled ? nil : normal.1.animation(for: normal.0)
    }
}
```

```swift
// call site
.animation(env.animation((Dur.push, .easeInOut), reducedTo: (Dur.crossfade, .easeInOut)),
           value: route)

// a row whose substitution removes the effect rather than shortening it
if !env.isReduceMotionEnabled {
    tile.matchedGeometryEffect(id: page.id, in: namespace)
}
```

The wrong forms:

```swift
// WRONG — shortens a gesture instead of substituting a control
.animation(.easeInOut(duration: reduceMotion ? 0.04 : 0.28), value: isOpen)

// WRONG — keeps the geometry match and hopes a short duration hides it.
// It still translates and scales; gate 9 fails.
.matchedGeometryEffect(id: id, in: ns)
.animation(reduceMotion ? .linear(duration: 0.01) : .spring, value: expanded)

// WRONG — collapses SIEVE's lane to one slot. Deletes the preview and
// cuts worst-case decision time from 1.10 s to ≈ 0.34 s.
GlyphView(current).position(gateCentre)
```

## 7. The tests

Two, and the second is the one that matters.

```swift
// LoomFeatureTests — every §13.7.4 row has a substitution, and none of them translates.
@Test("Every animation declares a Reduce Motion substitution", arguments: MotionRow.allCases)
func substitutionExists(_ row: MotionRow) {
    #expect(row.substitution != nil)
    #expect(row.substitution?.transform == .none)     // no translate, scale or rotate
}
```

```swift
// SieveTests — §13.12 gate 9's automated half. Bands 1–6 × tempo steps 0–3 × every n.
@Test("Reduce Motion changes no SIEVE timing",
      arguments: Band.sieveServable, 0...3)
func sieveTimingIsInvariant(_ band: Band, _ tempoStep: Int) {
    let on  = SieveSchedule(band: band, tempoStep: tempoStep, isReduceMotionEnabled: true)
    let off = SieveSchedule(band: band, tempoStep: tempoStep, isReduceMotionEnabled: false)
    for n in 0..<on.glyphCount {
        #expect(on.window(n) == off.window(n))
        #expect(on.preview(n) == off.preview(n))
        #expect(on.station(at: on.arrival(n)) == off.station(at: off.arrival(n)))
    }
}
```

`SieveSchedule` is a pure value in `HunchCore` — that is why this test costs microseconds and fits the
10-second budget. If it needs a view, the schedule is in the wrong module.

## 8. Conflicts in canon

- **The Profile morph.** §11.10 says tremble becomes a static dash pattern and *"all motion below becomes a
  0.35 s crossfade"*; §13.7.4 says *"new shape instantly; 240 ms crossfade"*. **§13.7.4 wins** — it opens by
  declaring that every animation in the app appears in it, which is a normative-source clause, and §11.10
  is a section about geometry. Keep §11.10's dash-gap-scales-with-`A` rule; take §13.7.4's 240 ms.
- **The reveal.** §13.7.4 gives one `dur.reduceMotionReveal` crossfade; §6.8 gives the 640 ms hold **plus**
  that crossfade, 900 ms absolute. Both are true and they are in different clocks — §13.7.4 is local, §6.8
  is absolute. `reveal-beats.md` §1.

## 9. What would be wrong

- Shipping an animation with no row here.
- Substituting by shortening a gesture or a geometry match instead of replacing it with a control or
  removing it.
- Collapsing SIEVE's lane to one slot, or changing its cadence, dwell, preview count, scoring or difficulty.
- Changing the seal hold, the adjudication hold or any audio/haptic onset.
- Rescheduling a dropped onset to land inside the shortened reveal. It becomes a second event.
- Inlining 140, 180, 200 or 240 rather than citing `dur.reduceMotion{Swap,Strike,Expand,Morph}`.
- Borrowing `dur.crossfade` for a row that is not 220 ms, or `dur.micro` for a row that is not 120.
- Writing a second substitution table in a component's reference file. State which rows apply; cite §2
  for what they become. Two tables is how §1's completeness claim stopped being true.
- Freezing the shader by setting `amt = 0`. Reduce Motion freezes `t`; Reduce Transparency, High Contrast
  and Low Power set `amt = 0`. Two different settings, two different predicates.
- Reading `UIAccessibility.isReduceMotionEnabled` in a view. It arrives through `RenderEnv`, built once by
  `RenderEnvReader`, so every surface agrees about what the setting means.
