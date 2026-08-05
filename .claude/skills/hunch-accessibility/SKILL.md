---
name: hunch-accessibility
description: "Wires HUNCH's VoiceOver elements, rotors, Magic Tap and announcement order, and states what Dynamic Type, Bold Text, Differentiate Without Color, Reduce Transparency and High Contrast change on each screen. Use when adding SwiftUI accessibility modifiers, labelling a drawn mark that carries no text, or auditing a screen for the CI accessibility gate. Numeric token deltas belong to the token skill and Reduce Motion substitutions to the motion skill; this skill owns element identity and wording."
allowed-tools: Read, Grep, Glob, Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)
metadata:
  version: "1.0"
  owns: "the element index, four rotors, Magic Tap, escape, announcement order and wording, the narration parity invariant, the CI audit"
---

## Step 0 — read the accessibility surface as it exists right now

**Before anything else, run `bash ${CLAUDE_SKILL_DIR}/scripts/current-state.sh`.** It counts the
`.accessibility*` modifiers in use, prints the five counts `audit-in-ci.md` §5's check 11 asserts,
and says whether the audit is wired.

**Trust that listing over anything below it. A modifier that is not in the listing is not shipped, whatever a reference file claims.**

## The rule

**The play surface renders zero characters in any locale, so a label is not a courtesy — it is the whole alternate reading of the game.** Every drawn mark that carries state is an element with a label, a trait and a value. Everything else is `.accessibilityHidden(true)`, explicitly, so that "unlabelled" and "deliberately silent" are distinguishable in a diff.

Two boundaries come from the guide, not from taste:

- **Strings on the play surface exist only inside `.accessibility*` modifiers.** `Scripts/check-source-hygiene.sh` check 7 fails the build on any `Text`, `Label` or `AttributedString` elsewhere in `RoundView`, `EchoRoundView`, `SieveRoundView`, `BenchView`, `AssayInspectorView` or `InscriptionView` (`08 §5`).
- **Every string goes through `Loc`** (`Modules/Sources/HunchUI/Loc.swift`), which carries the resolved bundle and locale. A bare literal compiles, is extracted into the catalog, and stays English until the next cold launch (§12.9 trap 1, `07 B39`, `01 P36`). Spelled `Loc.x` below; if `Loc` ships as an injected value carrying the resolved locale, the call becomes `loc.x` and nothing else changes. The accessor's shape is `Loc.swift`'s business — **this skill owns which strings exist and what they say.**
- **A `Loc` accessor returns an already-resolved `String`, so every call site is `Text(verbatim:)`.** Re-wrapping it in the localizing `Text` overload is a second lookup against `Bundle.main` that fails silently and yields the key. `verbatim:` also states the intent at the call site, which is what keeps a `07 B39` grep readable — the same reasoning `08 §3` uses to rule `Text(verbatim: mode.wordmark)` the only correct spelling for the mode names.

## To give a drawn mark an accessibility identity

1. **Decide whether it is an element.** It is, iff a sighted player reads state off it. Look the drawing up in `references/voiceover-elements.md`; if it is not in that index, add the row *there first*, then write the modifier. §13.10 indexes by interactive element and silently omits every non-interactive mark — the index closes that gap and is the thing that must not drift.
2. **Collapse the `Canvas`.** A `Canvas` publishes nothing on its own. `.accessibilityElement(children: .ignore)` for one mark; `.contain` for a grid or rail whose children are elements; **never `.combine`** — it glues fragments, which is §12.9 trap 3.
3. **Label = identity, value = state.** `"Seal"` + `"barred, rail 2 is empty"`. Never `"Seal barred"`. The label is stable across a round; the value is what `.updatesFrequently` is about.
4. **Traits, then value, then actions,** in that order in source, so a reviewer reads the element the way VoiceOver speaks it.
5. **Add a custom action for anything needing a gesture VoiceOver cannot make** — see `references/rotors-and-gestures.md` §6. Canon forbids drag, pinch and long-press in the declaration UI (§4.2), which is exactly why the Bench needs so few.
6. **Register the screen in the audit** (`references/audit-in-ci.md` §3) and add `.accessibilityIdentifier` only where XCUITest must find the element — identifiers are not labels and are never localized.

```swift
// Modules/Sources/LoomFeature/RibbonCanvas.swift — the modifier lives beside the drawing it describes.
RibbonTileCanvas(probe: probe, env: env)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: Loc.glyphLabel(probe.glyph, relativeTo: previous, detail: detail)))
    .accessibilityValue(Text(verbatim: Loc.probeState(probe)))          // "admitted" / "rejected" / "seed glyph" / "twin"
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: Text(verbatim: Loc.loadIntoDial)) { round.load(probe.glyph) }
    .accessibilityRotorEntry(id: LoomAnchor.ribbonTile(probe.id), in: loomRotor)
```

```swift
// ✗ Three fragments glued. Word order is grammar: German and Arabic both break, and §12.9 trap 3 bans it.
.accessibilityLabel(Text(fillName) + Text(", ") + Text(shapeName))
// ✗ Extracted into the catalog, but bypasses Loc — English until the next cold launch.
.accessibilityLabel("Loom throat")
// ✓ One format string, four interpolations, plural-aware pips.
.accessibilityLabel(Text(verbatim: Loc.glyphLabel(glyph, relativeTo: previous, detail: detail)))
```

```swift
// ✗ .disabled deletes the tap — and §4.3's rail pulse and §12.5's nudge 3 both need the barred Seal to be pressable.
Button(action: seal) { SealCanvas(bar: bar, env: env) }.disabled(bar != nil)
// ✓ Enabled, discoverable while refusing (§12.8), and the bar is the VALUE.
Button(action: seal) { SealCanvas(bar: bar, env: env) }
    .accessibilityLabel(Text(verbatim: Loc.seal))
    .accessibilityValue(Text(verbatim: Loc.sealState(bar)))             // "ready" / "barred, rail 2 is empty"
    .accessibilityRespondsToUserInteraction(true)
```

## Where the detail lives

| Read this | When |
|---|---|
| `references/voiceover-elements.md` | before writing any `.accessibilityLabel` — the element index by drawing, the glyph label, the Bench narration and its parity invariant, the announcement table, traversal order, the key budget |
| `references/rotors-and-gestures.md` | when adding a rotor, custom action, Magic Tap or escape; when a control needs a gesture VoiceOver cannot make; when changing SIEVE's pacing or a nudge |
| `references/environment-settings.md` | when a screen must change layout, or a mark must change geometry, under Dynamic Type, Bold Text, Differentiate Without Color, Reduce Transparency or High Contrast |
| `references/audit-in-ci.md` | before adding a screen to `HunchUITests`, when suppressing an audit issue, or when clearing §13.12's thirteen gates before an archive |

**The boundary with the drawing skills, in both directions.** `hunch-bench-instruments`, `hunch-chrome-and-meta`, `hunch-shared-marks` and `hunch-glyph-renderer` own *where a modifier attaches to their drawing* and what its geometry does under a setting. This skill owns *what it says* — the element's identity, its traits, its wording, its actions, and whether it speaks at all. A component reference file that spells out a label has copied it; a row of `voiceover-elements.md` that spells out a radius has copied that. Neither is allowed.

## Gotchas

- **`LawNarrator` cannot return a `String` from `HunchCore`.** A localized string needs a bundle and `08 §2`'s boundary rule bans bundles from the core outright. `Narration(_ law: LawNode)` in `HunchCore/Sources/Laws/Narration.swift` returns a **value tree**; `Loc.narration(_:)` renders it in `HunchUI`. That is also what makes the 10,000-law parity test a value comparison that runs under `swift test` with no simulator and no catalog — comparing rendered English would leave eleven locales untested. Full ruling: `voiceover-elements.md` §10.
- **An announcement is an `AttributedString`, so it may not be built in a play-surface file** — check 7 fails the build. Post from `Modules/Sources/HunchUI/Announcer.swift`, which is outside the six.
- **The Assay's value is the pinned slice, not the marginal.** §4.3 makes the live Assay a slice conditioned on the ghost; quoting the unconditional projection says "48" where the screen shows 64. `voiceover-elements.md` §5.
- **A rotor label written as a literal bypasses `Loc`** exactly like a label does. `.accessibilityRotor(Text(verbatim: Loc.rotorRails)) { … }`, never `.accessibilityRotor("Rails")`.
- **`HunchUITests` is `XCTestCase`, not Swift Testing, and that is not a brief violation** — Xcode rejects `import Testing` in a UI test target (`06 T43`, ruled in `08 §7.10`). `performAccessibilityAudit` is a method on `XCUIApplication`.
- **`XCUIApplication` is `@MainActor` and `XCTestCase.setUp()` is not, so the XCTest-era `var app: XCUIApplication!` populated in `setUp()` does not compile under Swift 6** — and `@MainActor override func setUp()` does not fix it, because an override cannot add isolation its superclass method lacks. Launch from a `@MainActor` factory method per test: `audit-in-ci.md` §2.
- **`issueHandler` returning `true` *suppresses* the issue** (`07 B46`). `{ _ in true }` is a test that can never fail.
- **VoiceOver is behaviour, not a token axis.** It changes SIEVE's pacing (§9.8: `r` fixed at 0.75 g/s, no ramp, Tempo axis not updated) and suppresses every nudge (§12.5). Read `@Environment(\.accessibilityVoiceOverEnabled)`; do **not** add an eighth axis to `RenderEnv` — `hunch-design-tokens/references/render-env.md` §6.
- **Terse mode needs the previous glyph.** §12.6's `voiceOverDetail` row omits attributes unchanged since the last one, so every label builder takes `relativeTo previous: Glyph?`. A builder without it cannot implement the setting later without changing every call site.
- **Accessibility strings are 134 of a hard 250-key budget** (§12.9), asserted by a CI test. A new label is a budget decision, not a free line.

## Never

- Never concatenate translated fragments, in a label, a value, an announcement or a narration. One format string per sentence, interpolations only (§12.9 trap 3). Plurals are String Catalog variations — any `count == 1 ? … : …` is a bug.
- Never let a label carry state, or a value carry identity.
- Never write a bare literal or `LocalizedStringKey` literal into an accessibility modifier.
- Never `.accessibilityElement(children: .combine)` on a play surface.
- Never render text to solve a labelling problem. Zero characters, every locale, no exceptions.
- Never let the narration describe a hidden law mid-round — only the player's own draft or an already-revealed law (§13.10), asserted by test.
- Never speak the five Profile axis names. *Induction, Retention, Flexibility, Restraint, Tempo* never enter the catalog in any form, visible or spoken (§11.11 P3, §12.9); the vertex sigils get behavioural sentences. Never announce a band number either (§10.5).
- Never add a fifth rotor (§12.8 fixes the set at four), and never let a hint stand in for a label.
- Never suppress an audit issue without naming both the element and the audit type in the predicate.
- Never `.disabled(true)` on the barred Seal, and never `.accessibilityHidden(true)` on anything a player can touch.
- Never copy a numeric delta out of `hunch-design-tokens` into this skill. Cite the token; the value has one home.
