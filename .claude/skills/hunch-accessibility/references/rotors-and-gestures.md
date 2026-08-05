# rotors-and-gestures.md — four rotors, Magic Tap, escape, and every custom action

Contents: [1 The four rotors](#1-the-four-rotors) · [2 Building one](#2-building-one) ·
[3 Magic Tap](#3-magic-tap) · [4 Escape](#4-escape) · [5 The headings rotor](#5-the-headings-rotor) ·
[6 Custom actions — the complete list](#6-custom-actions--the-complete-list) ·
[7 The sixteen-gesture walkthrough](#7-the-sixteen-gesture-walkthrough) ·
[8 The gesture constraints that make this work](#8-the-gesture-constraints-that-make-this-work) ·
[9 SIEVE under VoiceOver](#9-sieve-under-voiceover) · [10 Nudges under VoiceOver](#10-nudges-under-voiceover) ·
[11 What would be wrong](#11-what-would-be-wrong)

---

## 1. The four rotors

§12.8 fixes the set at four and says there is no fifth. Each one exists because it removes a *specific* count of
swipes from a specific task; a rotor that does not have that number attached is decoration.

| Rotor | Stops | Where | What it buys |
|---|---|---|---|
| **Rails** | rail 1, rail 2, coupler, Seal | `BenchView` | cuts a full declaration traversal from ~22 gestures to ~16 |
| **Attributes** | the Dial's four ramps | `RoundView` | jumps the four composition groups without walking sixteen cells |
| **Probes** | the ribbon, **newest first**, announcing glyph + verdict | `RoundView` | reading the evidence backwards is the actual induction task |
| **Counterexample** | the counterexample glyph, then the nearest ribbon tile it was chosen against | `RoundView`, **only after a strike** | pairs the two readings that contradict each other |

**"Counterexample" must not exist before the first strike** — §13.12 gate 6 asserts exactly that, so an always-present
rotor with zero entries fails the gate. Apply the modifier conditionally, through a `ViewModifier`, rather than
emitting an empty builder:

```swift
// Modules/Sources/LoomFeature/CounterexampleRotor.swift
struct CounterexampleRotor: ViewModifier {
    let counterexample: Counterexample?
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if let counterexample {
            content.accessibilityRotor(Text(verbatim: Loc.rotorCounterexample)) {
                AccessibilityRotorEntry(Text(verbatim: Loc.glyphLabel(counterexample.glyph, relativeTo: nil, detail: .full)),
                                        id: LoomAnchor.counterexample, in: namespace)
                AccessibilityRotorEntry(Text(verbatim: Loc.rotorCounterexampleAgainst),
                                        id: LoomAnchor.ribbonTile(counterexample.nearestProbeID), in: namespace)
            }
        } else {
            content
        }
    }
}
```

---

## 2. Building one

Three parts, and forgetting the third is why a rotor silently does nothing: a `Namespace`, the rotor declaration, and
`.accessibilityRotorEntry(id:in:)` on each target view.

```swift
struct RoundView: View {
    @Namespace private var loomRotor
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverRunning

    var body: some View {
        surface
            .accessibilityRotor(Text(verbatim: Loc.rotorProbes)) {
                ForEach(round.ribbon.probes.reversed()) { probe in          // newest first
                    AccessibilityRotorEntry(
                        Text(verbatim: Loc.glyphLabel(probe.glyph, relativeTo: nil, detail: detail)),
                        id: LoomAnchor.ribbonTile(probe.id),
                        in: loomRotor,
                        prepare: { round.scrollRibbon(to: probe.id) }        // the ribbon is lazy — see below
                    )
                }
            }
            .modifier(CounterexampleRotor(counterexample: round.counterexample, namespace: loomRotor))
    }
}
```

- **`prepare:` is not optional for the ribbon.** Its tiles live in a lazy horizontal stack, so an off-screen tile has
  no view to navigate to. `prepare` runs before VoiceOver moves there; use it to scroll the entry into existence.
  Without it the rotor stops at whatever happens to be on screen, which is the failure mode that looks like "the rotor
  works" during a five-probe smoke test and breaks at probe 20.
- **The rotor label is a string like any other.** `.accessibilityRotor(Text(verbatim: Loc.rotorRails))`, never
  `.accessibilityRotor("Rails")` — a `LocalizedStringKey` literal is extracted into the catalog and then bypasses
  `Loc`, so it stays English until the next cold launch (§12.9 trap 1).
- **The "Rails" rotor is four fixed stops, so its builder is four literals**, not a `ForEach`:

```swift
.accessibilityRotor(Text(verbatim: Loc.rotorRails)) {
    AccessibilityRotorEntry(Text(verbatim: Loc.rail(1)),  id: BenchAnchor.rail(0),  in: benchRotor)
    AccessibilityRotorEntry(Text(verbatim: Loc.rail(2)),  id: BenchAnchor.rail(1),  in: benchRotor)
    AccessibilityRotorEntry(Text(verbatim: Loc.coupler),  id: BenchAnchor.coupler,  in: benchRotor)
    AccessibilityRotorEntry(Text(verbatim: Loc.seal),     id: BenchAnchor.seal,     in: benchRotor)
}
```

`LoomAnchor` and `BenchAnchor` are plain `Hashable` enums beside their views. They are not `accessibilityIdentifier`s
and not `Route`s — a rotor id is an in-view anchor and has no business in `HunchNavigation` (`04 A32`).

---

## 3. Magic Tap

**Magic Tap is the single largest VoiceOver win in the app**: two fingers, double tap, anywhere on the screen, and the
thing the player came to do happens. §13.10 assigns it PROBE on the Dial and the Seal on the Bench.

```swift
// RoundView
.accessibilityAction(.magicTap) { round.probe() }
// BenchView — inside the presented subtree, not on RoundView
.accessibilityAction(.magicTap) { round.seal() }
```

Magic Tap resolves to the frontmost handler, so the Bench's wins while the Bench is up **only if the modifier lives
inside the presented subtree**. Putting both on `RoundView` and branching on a `isBenchPresented` flag is the version
that works in the simulator and fails on device once the Bench is a real presentation. The same presentation boundary
is why `04 A25` makes you re-inject dependencies into `BenchView`, `AssayInspectorView`, `ResetConfirmAlert` and
`SievePauseOverlay`.

Magic Tap on a **barred** Seal still fires `seal()`, which pulses the offending rail and posts "The Seal is barred.
Rail 2 is empty." Swallowing it silently would make the one gesture that always works the one gesture that sometimes
does nothing.

There is no Magic Tap in ECHO or SIEVE: ECHO's commit is the Seal on the Bench-shaped commit bar and gets the same
handler; SIEVE's only act is the gate, which is a single full-width element and needs no shortcut.

---

## 4. Escape

Two-finger scrub. `.accessibilityAction(.escape)` on exactly two views:

```swift
// BenchView          → pull-down
// AssayInspectorView → dismiss
.accessibilityAction(.escape) { dismiss() }
```

**Not on `RoundView`.** Leaving a round is a deliberate act with a persisted consequence (§12.7 suspends and returns
to the Frame); the leading chevron is that act and it is a plain button. A scrub that abandons a round is the accident
§12.7's SIEVE confirm-by-repeat exists to prevent, one screen over.

`SievePauseOverlay` gets `.accessibilityAddTraits(.isModal)` instead, so VoiceOver stops walking the frozen lane
behind it; its own exit is §9.2's confirming double chevron, unchanged.

---

## 5. The headings rotor

`.headings` carries `CodexRootView`, `CodexShelfView`, `ProfileView`, `StatisticsView` and `SettingsView` (§12.8).
For the three built on stock `Form`/`List`, `Section(header:)` already emits the trait — do not add it by hand. For the
two custom screens, `.accessibilityAddTraits(.isHeader)` goes on the section label, and nowhere else: a heading that is
not a section start makes the rotor useless faster than no headings at all.

The play surfaces have no headings, because they have no sections and no text.

---

## 6. Custom actions — the complete list

The rule that generates this table: **any act a sighted player performs with a gesture VoiceOver cannot make needs a
custom action.** Canon forbids drag, pinch and long-press in the declaration UI (§4.2), so the residue is small — and
every remaining trailing-swipe is here.

| Element | Action | Replaces | Source |
|---|---|---|---|
| ribbon tile | "Load into the Dial" | tap-to-load | §13.10 |
| Bench rail | "Clear rail" | trailing swipe (§4.2) | §13.10 |
| wedge | "Cycle" | repeated tap through 6 comparators | §13.10 |
| coupler | "Cycle" | repeated tap through and / or / xor | §13.10 |
| the Assay | "Inspect" | tap to expand | §13.10 |
| the Assay | "Read by attribute" | *nothing* — it has no sighted equivalent, and that is deliberate | §13.10 |
| ECHO rail tile | "Return to the tray" | trailing swipe | §13.10 |
| SIEVE gate | "Admit" | tap the 375 × 88 band | §13.10, §9.8 |
| Frame mode key, suspended | **"Discard and start fresh"** † | §12.4's trailing swipe on the key | added here |
| Assay inspector ghost scrubber | adjustable ±1 | drag | added here † |
| `CodexShelfView` rail scrubber | adjustable ±1 section | drag | added here † |

Rows marked † are gestures §13.10's table does not cover. They are not new features — the gesture already exists in
§12.4, §4.3 and §11.2 — they are the same act reachable without a drag. Adding a gesture anywhere in the app and not
adding its row here is how a screen becomes unplayable under VoiceOver without anyone noticing.

```swift
// The generated shape. Note: the action name is a Text built from Loc, like every other string.
.accessibilityActions {
    Button(action: { round.load(probe.glyph) }) { Text(verbatim: Loc.loadIntoDial) }
}
// Adjustable, for the throat, the Tally counter dial and the two scrubbers:
.accessibilityAdjustableAction { direction in
    switch direction {
    case .increment: round.stepLastTouchedAttribute(by: +1)
    case .decrement: round.stepLastTouchedAttribute(by: -1)
    @unknown default: break                       // W29 bans `default:` on our own enums; this one is Apple's
    }
}
```

---

## 7. The sixteen-gesture walkthrough

§13.12 gate 3 is manual: *a complete band-5 round is playable end to end with the screen curtain on*. This is that
test's script, for canon's `RANK pips(cur) > PREV RANK pips AND shape ∈ {triangle, hexagon}` — nine taps sighted,
sixteen gestures here. Run it on device, curtain on, before any archive.

1. Rotor → **Rails** → Bench. *"Bench. Rail 1 empty, rail 2 empty. Seal barred."*
2. Swipe to "Bridge tile", double tap. *"Bridge added to rail 1. Leading socket empty."*
3. Swipe to the first socket, double tap → the four attribute headers become focusable inside it; swipe to "Pips", double tap. *"pips, this glyph."*
4. Swipe to "Previous glyph", double tap. *"Previous glyph on."* — the entire contextual grammar, one toggle.
5. Swipe to "Comparator", double tap until *"greater than."* Swipe to the other socket, double tap, swipe to "Pips", double tap.
6. Swipe to "Coupler". *"Coupler, and."* Leave it. Swipe to "Ramp tile", double tap; "Attribute", double tap; "Shape", double tap.
7. Swipe to "triangle", double tap. *"triangle, admitted."* Swipe ×2 to "hexagon", double tap.
8. Rotor → **Rails** → Bench reads the full narration. Optionally: Assay → "Read by attribute" for the marginals.
9. **Magic Tap** → the Seal fires.

Every step is a single-finger swipe or a double tap. If a step you add cannot be written that way, the feature is not
finished.

---

## 8. The gesture constraints that make this work

The walkthrough is not a happy accident. It holds because §4.2 and §12.8 already forbid, in the declaration UI:
**drag, pinch, long-press, and double-tap-meaning-something-other-than-activate.** VoiceOver's double tap *is*
activate, so a double-tap shortcut would collide with the only gesture the player has.

Treat that as a standing constraint on new work, not as a historical note. The moment a long-press appears on the
Bench — "hold a cell to clear the ramp", the obvious convenience — the whole of §7 stops being reachable and gate 3
fails at the end of the project rather than at the commit. If a control needs a second act, it gets a custom action
(§6) and, if it must be reachable by touch, a second visible control.

Minimum target 44 × 44 pt, ≥ 8 pt apart; the smallest shipped is 56 × 44 (§12.8). The audit's `.hitRegion` pass
enforces it, and `environment-settings.md` §2 covers what happens to those targets above AX2.

---

## 9. SIEVE under VoiceOver

§9.8, in full: **step mode, `r` fixed at 0.75 g/s (an 889 ms window), no ramp.** The gate is one element with an
"Admit" custom action; each glyph is announced on gate entry and its resolution announced in the sump. Scoring is
identical. **The Tempo axis is not updated**, because the timing is not comparable.

The pacing is a parameter of a pure value, never a read of `UIAccessibility` — `SieveSchedule` lives in `HunchCore`
and `08 §2`'s boundary rule bans that read outright:

```swift
// HunchCore/Sources/Rounds/SieveSchedule.swift
public enum SievePacing: Sendable { case adaptive, stepped }        // stepped == VoiceOver or §12.6 steady stream

public struct SieveSchedule: Sendable {
    public init(band: Band, tempoStep: Int, pacing: SievePacing) { … }
    public func window(at index: Int) -> Duration { … }             // pure; `stepped` returns 889 ms, flat
}
```

The app layer supplies it once, at round start, from `@Environment(\.accessibilityVoiceOverEnabled)`. Note that
§12.6's **steady stream** toggle reaches the same `.stepped` pacing by a different route and at a 0.85 score
multiplier — it is available to anyone and is deliberately *not* gated behind an accessibility flag, so do not collapse
the two into one `isVoiceOverRunning` branch.

Do not "restore" the preview by announcing the lane. `voiceover-elements.md` §7 states why: §9.8 already traded the
preview for the longer window, and giving back both changes the game's information content.

---

## 10. Nudges under VoiceOver

**Every nudge is suppressed when VoiceOver is running** (§12.5) — idle, no-Bench, barred-Seal, global idle and the
opening round's *Unvaried*. The rotor already enumerates every control, so a breathing opacity cycle is noise that
interrupts nothing and helps nobody.

Suppression is at the nudge scheduler, not at the animation:

```swift
// Modules/Sources/LoomFeature/Round.swift
func scheduleNudge(_ nudge: Nudge) {
    guard !isVoiceOverRunning else { return }        // §12.5 — before the timer, not inside the animation
    …
}
```

Two things that survive VoiceOver and must not be swept up with the nudges, because they are information rather than
attention-getting: the **barred Seal's rail pulse** (it is the answer to a press the player made, and it is also
announced) and the **empty-rail hairline**, which is a static state, not a nudge.

Reduce Motion is a different axis and is not this skill's — every substitution, including the nudges' crossfade form,
belongs to `hunch-motion-and-feedback/references/reduce-motion.md`.

---

## 11. What would be wrong

- **A fifth rotor.** §12.8 fixes the set at four and `audit-in-ci.md` §5's check 11 counts them. A
  rotor that cannot state how many swipes it removes from a named task is decoration.
- **An always-present "Counterexample" rotor with an empty builder.** §1. §13.12 gate 6 asserts it is
  *absent* before the first strike, so the empty builder fails the gate while looking correct.
- **A rotor without `.accessibilityRotorEntry(id:in:)` on the targets, or without `prepare:` on the
  ribbon.** §2. Both fail silently, and the `prepare:` omission passes a five-probe smoke test and
  breaks at probe 20.
- **`.accessibilityRotor("Rails")` with a literal.** §2. A `LocalizedStringKey` literal is extracted
  into the catalog and then bypasses `Loc`, so it is English until the next cold launch.
- **Putting both Magic Taps on `RoundView` and branching on an `isBenchPresented` flag.** §3. Magic
  Tap resolves to the frontmost handler; the branch works in the simulator and fails on device.
- **Swallowing Magic Tap on a barred Seal.** §3. The one gesture that always works must not become
  the one gesture that sometimes does nothing.
- **`.accessibilityAction(.escape)` on `RoundView`.** §4. A two-finger scrub that abandons a round is
  the accident §12.7 exists to prevent.
- **A `.isHeader` trait on anything that is not a section start,** or adding it by hand inside a
  stock `Section(header:)`. §5. Both make the `.headings` rotor useless faster than no headings.
- **A new gesture without a matching row in §6.** A drag, a long-press or a trailing swipe with no
  custom action makes a screen unplayable under VoiceOver, and nothing announces it.
- **A long-press or a drag on the Bench "for convenience".** §8. The whole of §7's sixteen-gesture
  walkthrough stops being reachable, and gate 3 fails at the end of the project instead of at the
  commit.
- **A double-tap that means anything other than activate.** §8. It collides with the only gesture the
  player has.
- **Reading `UIAccessibility.isVoiceOverRunning` inside `SieveSchedule`.** §9. `08 §2`'s boundary
  rule bans it outright; the pacing is a parameter of a pure value.
- **Collapsing §12.6's steady-stream toggle and VoiceOver into one `isVoiceOverRunning` branch.** §9.
  They reach the same pacing by different routes and at different score multipliers.
- **Announcing the SIEVE lane to "restore" the preview.** §9. §9.8 already traded the preview for the
  longer window; giving back both is a different game.
- **Suppressing a nudge inside the animation instead of at the scheduler,** or sweeping up the barred
  Seal's rail pulse and the empty-rail hairline with the nudges. §10. Both are information, not
  attention-getting.
