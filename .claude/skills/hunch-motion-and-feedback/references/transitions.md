# transitions.md — screen, sheet and scene-phase motion

Contents: [1 The table](#1-the-table-1373-in-tokens) · [2 The Dial ↔ Bench drag](#2-the-dial--bench-drag-the-only-interactive-transition) ·
[3 Shared elements](#3-shared-elements-there-are-exactly-two) · [4 Scene phase](#4-scene-phase-127) ·
[5 Spin-up and pause](#5-spin-up-and-pause) · [6 The Swift](#6-the-swift) · [7 RTL](#7-rtl) ·
[8 VoiceOver](#8-voiceover) · [9 Reduce Motion](#9-reduce-motion) · [10 High Contrast](#10-high-contrast) ·
[11 What would be wrong](#11-what-would-be-wrong)

Canon: §13.7.3, §12.7, §12.2–§12.4. Navigation *structure* — `Route`, `Router`, one router per
`NavigationStack`, `[Route]` restored through `@SceneStorage` — is `hunch-swift-code`'s
(`04 A32/A33/A39`). This file owns only what moves.

---

## 1. The table — §13.7.3, in tokens

Every duration and curve below already has an L1 token. **This table contains no numbers, and that is the
test that it is written correctly.**

| From → To | Transition | Duration | Easing |
|---|---|---|---|
| Home → mode | chrome bar persists; content pushes up 24 pt + crossfade | `dur.push` | `ease.inOut` |
| Dial ↔ Bench | interactive drag on the Bench handle; the Dial slides down 332 pt; follows the finger, interruptible | ≤ `dur.sheet` | `ease.sheet` |
| Assay → expanded inspector | zoom from the 64 pt well, `matchedGeometryEffect` | `dur.zoom` | `ease.zoom` |
| Reveal → Codex page | the reveal's beat-5 thumbnail is the shared element | `dur.shared` | `ease.shared` |
| Round end → next round | full crossfade through `ground.base` | `dur.crossfade` | `ease.inOut` |
| Any → Settings | system sheet | system | system |

`ground.base`, not `ground.raised`: the crossfade goes through the room, so the machine reads as having
been dark between rounds. Crossfading through the raised ground makes it read as a page turn.

**Settings is the one stock presentation in the app.** Do not hand-roll it, do not add a custom
transition, and do not give it a `ground` crossfade. The `Form` inside it is one of only three places
stock components appear at all.

---

## 2. The Dial ↔ Bench drag — the only interactive transition

It is the only place in HUNCH where the finger drives the animation, and it earns that because the Bench
is a drawer over the Dial rather than a screen after it. Three properties, all required:

- **It follows the finger.** `offset` tracks the drag translation directly, not through a spring.
- **It is interruptible.** A new drag during the settle picks up from the current offset. `ease.sheet`'s
  spring gives this for free; a `withAnimation` on a `Bool` does not.
- **It resolves by velocity, not by position alone.** A fast flick past a third of the travel commits; a
  slow drag needs half.

Under Reduce Motion the drag is replaced, not merely shortened: **the handle becomes a plain button and
the Bench crossfades at `dur.crossfade`.** A gesture whose whole point is continuous tracking cannot be
"reduced"; it is substituted.

## 3. Shared elements — there are exactly two

`matchedGeometryEffect` appears twice in the app and nowhere else:

1. **Assay well (64 pt) → expanded inspector (368 pt).** Same `namespace`, same `id`, `isSource` on the
   well. The Assay is **never bloomed** at any size, so nothing has to be turned off across the transition.
2. **Reveal beat 5's 64 pt page thumbnail → the Codex page.** The thumbnail *is* the shared element, which
   is why beat 5 docks it below the stack rather than fading it in: it has to exist as a real view before
   the transition can match it.

Both are presented subtrees, so both **re-inject the environment** (`04 A25`). `AssayInspectorView` starting
a fresh environment hierarchy and losing `RenderEnv` is the single most common bug in this area, and it
shows up as an inspector rendered in the dark theme inside a light-theme app.

## 4. Scene phase, §12.7

| Event | PROBE / DRIFT / ECHO | SIEVE |
|---|---|---|
| `.inactive` | nothing visible; the round is already on disk | stream freezes on the current frame **within one display tick**; `SievePauseOverlay` drops a 70 % scrim |
| `.background` | flush + `fsync` `round.json`, then the rest in §11.13's order; **stop `AVAudioEngine`; stop `CHHapticEngine`** | same, plus the frozen stream position |
| `.active` | **600 ms spin-up** (§5) | overlay stays; resuming needs one deliberate tap **on the gate** — the same 375 × 88 pt band the run is played with — then a 3-glyph run-up at `r₀` |
| termination | relaunch opens **directly into the round**, ribbon intact | relaunch opens the Frame; the run is **voided** |
| audio interruption `.began` / `.ended` | engine stops; restarts only on `.shouldResume` | same |
| Low Power Mode on | grain shader off; the Frame's idle glyph stops drifting | plus stream frame rate capped at 60 Hz |

There is **no pause control in PROBE, DRIFT or ECHO**, because there is no clock. SIEVE is the only mode
with time pressure and therefore the only one that needs a freeze.

**Leaving a round** is one tap on a leading chevron in the instrument bar — no confirmation, because
nothing is lost. SIEVE has no chevron while streaming; its exit exists only from `paused` and takes a
second confirming tap. That confirm-by-repeat and the Seal's optional one are **the only two in the app**.

## 5. Spin-up and pause

**The 600 ms spin-up**, on `.active` in PROBE / DRIFT / ECHO: the throat ring re-lights, then ribbon tiles
fade in **leading → trailing at 40 ms each**, then the Dial. It is a stagger, not a crossfade, and the
direction is load-bearing — it re-reads the chain in the order the player built it. With a long ribbon the
stagger is capped so the total stays 600 ms; tiles past the cap arrive together.

**`SievePauseOverlay`** is a presented subtree (`04 A25` again) and is one of three in the app, alongside
`AssayInspectorView` and `ResetConfirmAlert`. Its scrim is 70 %, which is not `opacity.scrim` — the Bench
scrim is a different token for a different job, and borrowing one for the other is how two surfaces end up
sharing a value that only one of them wanted.

## 6. The Swift

```swift
// Modules/Sources/LoomFeature/BenchDrawer.swift
@MainActor
struct BenchDrawer<Dial: View, Bench: View>: View {
    @Binding var isOpen: Bool
    let env: RenderEnv
    @ViewBuilder let dial: Dial
    @ViewBuilder let bench: Bench

    @GestureState private var drag: CGFloat = 0

    var body: some View {
        ZStack {
            dial.offset(y: isOpen ? C.Bench.travel : 0)
            bench.offset(y: (isOpen ? 0 : C.Bench.travel) + drag)
        }
        .gesture(handleDrag, isEnabled: !env.isReduceMotionEnabled)
        .animation(transition, value: isOpen)
    }

    private var transition: Animation {
        env.isReduceMotionEnabled
            ? Easing.easeInOut.animation(for: Dur.crossfade)
            : Easing.sheet.animation(for: Dur.sheet)
    }

    private var handleDrag: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                // velocity decides; position alone would make a fast flick feel dead
                let committed = value.predictedEndTranslation.height < -C.Bench.travel / 3
                isOpen = committed
            }
    }
}
```

The wrong form, and what breaks:

```swift
// WRONG — not interruptible; a second drag during the settle snaps
withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { isOpen.toggle() }
// ...and it is also a literal spring, which check 9 fails.

// WRONG — Reduce Motion handled by shortening the same gesture
.animation(.easeInOut(duration: reduceMotion ? 0.05 : 0.32), value: isOpen)
// A 50 ms drag is still a drag. The substitution is a button plus a crossfade.
```

## 7. RTL

**Chrome mirrors; glyphs never do.** Every horizontal transition above is leading/trailing, not left/right:
the push, the ribbon slide-in, the registration sweep, the Bench drawer's horizontal companion on Pro Max.
Write them with `leading`/`trailing` and let the layout direction do the work — a hard-coded `.left`
survives testing in English and inverts the reveal's sweep in Arabic.

Vertical transitions do not mirror. The Bench drawer slides down in every locale.

## 8. VoiceOver

- Post `.screenChanged` with the screen's name on every entry in §1's table. `.layoutChanged` for the
  Bench drawer and the Assay inspector, because the screen did not change — the layout did.
- **Two-finger scrub (escape) closes the Bench and the expanded Assay.** It is a shipped acceptance gate
  (§13.12 item 5), so both must be dismissible without finding a close control.
- Focus after a transition lands on the first element of the destination in reading order, never on a
  decorative container. On entering the Bench that is rail 1; on the expanded Assay it is the Assay itself,
  which carries the "Read by attribute" action.
- The Settings sheet is stock and gets stock behaviour. Do not intercept its focus.

## 9. Reduce Motion

| Normal | Substitution |
|---|---|
| Dial ↔ Bench interactive spring | `dur.crossfade`; **the handle becomes a plain button** |
| Assay expand, `dur.zoom` | `dur.reduceMotionExpand` crossfade; `matchedGeometryEffect` removed |
| Codex shared element, `dur.shared` | `dur.crossfade` |
| screen push, `dur.push` | `dur.crossfade` |

`matchedGeometryEffect` is **removed**, not shortened, in both shared-element transitions: a 40 ms
geometry match is still a translation and a scale, and gate 9 is "nothing translates, scales or rotates
anywhere". The destination crossfades in place.

The 600 ms spin-up keeps its stagger — a staggered *opacity* ramp translates nothing — but each tile's
fade is a crossfade rather than a slide.

## 10. High Contrast

No transition changes duration, curve or direction. The shader is off, so the crossfade through
`ground.base` between rounds is a flat fade with no grain reseed. Nothing else is conditional.

## 11. What would be wrong

- Writing any of §1's durations as a number. Every one has a token; that is the point of the table.
- Reusing `dur.sheet` for reveal beat 3 because both are 320 ms, or `dur.crossfade` for a Reduce Motion
  row because both are 220. Same number, different fact, and one of them will move.
- Making the Bench drawer a `.sheet` or a `NavigationLink`. It is a drawer over the Dial; a sheet loses the
  interruptible drag and the persistent chrome bar.
- Adding a third `matchedGeometryEffect`. There are exactly two, and each exists because a real view has to
  survive the transition.
- Forgetting to re-inject the environment into `AssayInspectorView`, `SievePauseOverlay` or
  `ResetConfirmAlert`. They are presented subtrees and start a fresh hierarchy.
- Adding a pause control to PROBE, DRIFT or ECHO. There is no clock to pause.
- Giving SIEVE a one-tap exit while the stream runs, or resuming from anywhere but the gate band itself.
- Restoring a SIEVE run after termination. It is voided; the record is still written, marked `void`, so
  the attempt log stays truthful.
- Leaving `AVAudioEngine` or `CHHapticEngine` running into `.background`.
- Hard-coding `.left` / `.right` in any transition.
