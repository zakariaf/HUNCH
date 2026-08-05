# T01 — The VoiceOver element map

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P0 |
| **Size** | L |
| **Depends on** | nothing (inside this epic; the epic depends on E18) |
| **Delivers** | VoiceOver element map (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-accessibility` | Owns this task outright. `references/voiceover-elements.md` is the element index **by drawing** — the moment the question arises is when you have just stroked something in a `Canvas` and need to know whether it speaks. It also owns the two rulings this task must not re-litigate: the barred Seal keeps `.isButton` and stays enabled (§4), and `accessibilitySortPriority` is not used anywhere (§12). |
| `hunch-swift-code` | Every file this task touches is a SwiftUI view in `Modules/Sources`. `08 §2`'s boundary rule is why the labels live in `HunchUI` and not in `HunchCore`, and `04 A25` is why a presented subtree (`AssayInspectorView`, `ResetConfirmAlert`, `SievePauseOverlay`) needs the environment re-injected before it can read `loc` at all. |

## Objective

At the end of this task every drawn mark in HUNCH either **is** an accessibility element with a stable
label, a live value, the right traits and its custom actions, or is `.accessibilityHidden(true)`
**explicitly** — across all eighteen screens of §12.2, with no empty label and no label duplicated
inside one screen. The barred Seal is the load-bearing case: it keeps `.isButton`, stays enabled, and
carries `accessibilityRespondsToUserInteraction(true)`, so it is discoverable while it is refusing.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.10 (the element table) | the twenty-odd interactive rows: traits, label, value, custom actions, verbatim |
| `GAME_DESIGN.md` | §12.8 (VoiceOver paragraph) | every control is a standard element with label + trait + value; `accessibilityRespondsToUserInteraction` on the barred Seal; the four rotors are fixed and there is no fifth |
| `GAME_DESIGN.md` | §12.2 | the eighteen screens this map has to cover, and which of them are stock `Form`/`List`/`Alert` |
| `GAME_DESIGN.md` | §12.9 | the key budget: 134 accessibility keys inside a hard 250; control labels are 77 of them |
| `GAME_DESIGN.md` | §11.11 P3 | the five Profile vertex sigils speak §11.11's **behavioural sentences**; *Induction, Retention, Flexibility, Restraint, Tempo* never enter the catalog in any form |
| `GAME_DESIGN.md` | §4.3 | pressing a barred Seal pulses the offending rail and does nothing else — which is why `.disabled(true)` is not available |
| `.claude/skills/hunch-accessibility/references/voiceover-elements.md` | §1–§8, §12, §13 | the index by drawing, the marks that are **not** elements, traversal order, the budget |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §6 | file paths; the boundary rule; `04 A25`'s re-injection into presented subtrees |
| `ios-swift-guide/04-ARCHITECTURE-AND-STATE.md` | A25, A26 | presented subtrees start a fresh environment; `HunchUI` components read `@Environment` in the optional form |

Never restate a geometry, a radius or a colour here — the drawing's own skill owns those, and a row of
this map that spells one out has copied it.

## TDD — the test comes first

**Step 1 — write the failing test.** Two files: a Swift Testing suite over the vocabulary, and two
greps appended to the hygiene script.

Create `Modules/Tests/HunchUITests/AccessibilityVocabularyTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

/// The element index as test data. Its job is to prove the VOCABULARY — that every label exists, is
/// non-empty, is unique inside its screen, carries no state, and that no value carries identity.
/// Its job is NOT to prove the WIRING: that is `performAccessibilityAudit` in E19·T11, which walks
/// the live accessibility tree. Keep the two jobs apart or this fixture becomes a second truth.
struct ElementRow: Sendable {
    let screen: AccessibilityScreen
    let identifier: String                 // matches .accessibilityIdentifier where T11 needs one
    let label: @Sendable (Loc) -> String
    let values: @Sendable (Loc) -> [String]   // the closed vocabulary of this element's values, may be empty
    let isControl: Bool
}

@Suite("The VoiceOver element vocabulary — §13.10, §12.8", .tags(.unit, .presubmission))
struct AccessibilityVocabularyTests {

    /// English resolution with no compiled catalog: every `Loc` accessor is written
    /// `String(localized:defaultValue:bundle:locale:)`, so a missed lookup returns the English
    /// default value. That is what makes the whole vocabulary host-testable under `swift test`.
    private let loc = Loc.english

    @Test("every label in the index resolves to a non-empty string")
    func noEmptyLabel() {
        for row in ElementIndex.all {
            #expect(!row.label(loc).trimmingCharacters(in: .whitespaces).isEmpty,
                    "empty label for \(row.screen)/\(row.identifier)")
        }
    }

    @Test("no two elements on one screen share a label", arguments: AccessibilityScreen.allCases)
    func noDuplicateLabelWithinAScreen(_ screen: AccessibilityScreen) {
        let labels = ElementIndex.all.filter { $0.screen == screen }.map { $0.label(loc) }
        let duplicates = Dictionary(grouping: labels, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(duplicates.isEmpty, "duplicated on \(screen): \(Array(duplicates))")
    }

    @Test("every one of §12.2's eighteen screens appears in the index")
    func everyScreenIsCovered() {
        #expect(AccessibilityScreen.allCases.count == 18)
        for screen in AccessibilityScreen.allCases where screen.hasOwnElements {
            #expect(ElementIndex.all.contains { $0.screen == screen }, "no elements indexed for \(screen)")
        }
    }

    /// "Seal barred" as a LABEL means the rotor reads a different control every time the rail
    /// empties, and `.updatesFrequently` has nothing to attach to.
    @Test("a label is identity: it carries no digit and no state word")
    func labelsCarryNoState() {
        let stateWords = ["barred", "ready", "selected", "admitted", "rejected", "placed",
                          "empty", "on", "off", "suspended", "counted", "bound"]
        for row in ElementIndex.all {
            let label = row.label(loc).lowercased()
            #expect(!label.contains(where: \.isNumber), "\(row.identifier) label carries a number")
            for word in stateWords {
                #expect(!label.split(separator: " ").contains(Substring(word)),
                        "\(row.identifier) label carries the state word '\(word)'")
            }
        }
    }

    @Test("a value is state: no value equals any label on its own screen")
    func valuesCarryNoIdentity() {
        for row in ElementIndex.all {
            let labelsOnScreen = Set(ElementIndex.all.filter { $0.screen == row.screen }.map { $0.label(loc) })
            for value in row.values(loc) {
                #expect(!labelsOnScreen.contains(value), "\(row.identifier) value '\(value)' is a label")
            }
        }
    }

    // MARK: the two elements with a stated ruling

    @Test("the Seal is a button, is never disabled, and responds to user interaction while barred")
    func barredSealStaysDiscoverable() {
        let seal = SealAccessibility(bar: .inertRail(1), loc: loc)
        #expect(seal.traits.contains(.isButton))
        #expect(seal.isEnabled)                                   // never .disabled(true) — §4.3, §12.5 nudge 3
        #expect(seal.respondsToUserInteraction)                   // §12.8 asks for exactly this modifier here
        #expect(seal.label == loc.seal)                           // identity, stable
        #expect(seal.value != loc.seal)                           // the bar is the VALUE
        #expect(seal.value.contains(loc.rail(2)))                 // "barred, rail 2 is empty"
    }

    @Test("the throat is the only adjustable element in the app, and it adjusts fill at round start")
    func throatIsAdjustable() {
        #expect(ElementIndex.all.filter(\.isAdjustable).map(\.identifier).sorted()
                == ["assay.ghostScrubber", "codex.railScrubber", "loom.throat", "tally.counterDial"])
        var throat = ThroatAdjustment(lastTouched: nil)
        throat.increment()
        #expect(throat.attribute == .fill)                        // rank 1 of the canonical order
    }

    // MARK: the five Profile vertex strings

    @Test("the five vertex sigils speak §11.11's behavioural sentences, never an axis name")
    func vertexSigilsSpeakBehaviour() {
        let banned = ["induction", "retention", "flexibility", "restraint", "tempo"]
        for axis in Profile.Axis.allCases {
            let sentence = loc.vertexSentence(axis).lowercased()
            #expect(!sentence.isEmpty)
            for name in banned { #expect(!sentence.contains(name)) }
        }
    }

    // MARK: the budget

    @Test("this map spends no more than §12.9's 77 control-label keys")
    func controlLabelBudget() {
        let controlLabels = Set(ElementIndex.all.filter(\.isControl).map { $0.label(loc) })
        #expect(controlLabels.count <= 77)
    }
}
```

Then append to `Scripts/check-source-hygiene.sh` (this is the first half of what
`audit-in-ci.md` §5 calls **check 11**; T05 adds the counts and T11 closes it):

```bash
# check 11a — no bare literal inside an accessibility modifier.
# A literal is extracted into the catalog and then bypasses `loc`, so it stays English until the
# next cold launch (§12.9 trap 1). Every one of these takes an already-resolved String from `loc`.
if grep -RnE '\.accessibility(Label|Value|Hint|InputLabels|Action)\(\s*"' Modules/Sources --include='*.swift'; then
  fail "bare literal inside an .accessibility* modifier — every string goes through loc"
fi

# check 11b — .combine glues fragments in source order, which German and Arabic both break.
if grep -Rn 'accessibilityElement(children: .combine)' Modules/Sources --include='*.swift'; then
  fail "children: .combine is banned on the play surface (voiceover-elements.md §14)"
fi
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter AccessibilityVocabularyTests`

It must fail on **missing symbols** — `Loc.english`, `ElementIndex`, `AccessibilityScreen`,
`SealAccessibility`, `ThroatAdjustment`, `loc.vertexSentence(_:)` — not on a malformed assertion. Two
of these will pass accidentally if you implement them badly: `noDuplicateLabelWithinAScreen` passes on
an empty index, and `controlLabelBudget` passes on an empty index. Before implementing, confirm
`everyScreenIsCovered` fails with a count of `0`, which is what proves the other two are live.

Run the greps by hand too, and plant one violation of each (`\.accessibilityLabel("Seal")` and a
`.combine`) to see them fire before reverting.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/AccessibilityScreen.swift` — the 18 cases of §12.2 plus `hasOwnElements` |
| create | `Modules/Sources/HunchUI/SealAccessibility.swift` — the label/value/traits/enabled record for the one element with a ruling |
| create | `Modules/Sources/HunchUI/ThroatAdjustment.swift` — `.increment`/`.decrement` → ±1 rank of the last-touched attribute |
| modify | `Modules/Sources/HunchUI/Loc.swift` — the accessibility accessor group (labels, values, action names, the five vertex sentences) |
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift`, `RibbonCanvas.swift`, `AssayCanvas.swift`, `ThroatView.swift`, `ParTickRow.swift`, `RuleTileCanvas.swift` |
| modify | `Modules/Sources/LoomFeature/RoundView.swift`, `BenchView.swift`, `AssayInspectorView.swift`, `InscriptionView.swift`, `EchoRoundView.swift`, `SieveRoundView.swift`, `SievePauseOverlay.swift` |
| modify | `Modules/Sources/CodexFeature/CodexRootView.swift`, `CodexShelfView.swift`, `CodexPageView.swift` |
| modify | `Modules/Sources/MetaFeature/FrameView.swift`, `AnomalyView.swift`, `ProfileView.swift`, `StatisticsView.swift`, `SettingsView.swift`, `AboutView.swift`, `ResetConfirmAlert.swift` |
| create | `Modules/Tests/HunchUITests/AccessibilityVocabularyTests.swift` |
| create | `Modules/Tests/HunchUITests/ElementIndex.swift` — the test fixture, one row per indexed element |
| modify | `Scripts/check-source-hygiene.sh` — check 11a, 11b |
| modify | `tests.json` — the gate-4 entry (label completeness half; T11 adds the audit half) |
| modify | `DECISIONS.md` — the `ElementIndex` fixture's job, and its boundary against T11's audit |

## Implementation notes

### The procedure, applied once per drawing

`hunch-accessibility`'s SKILL.md gives six steps. They are not optional and they are in this order:

1. **Decide whether it is an element.** It is, iff a sighted player reads state off it. Look the
   drawing up in `voiceover-elements.md`; if it is not in that index, **add the row there first**, then
   write the modifier.
2. **Collapse the `Canvas`.** A `Canvas` publishes nothing on its own. `.accessibilityElement(children: .ignore)`
   for one mark; `.contain` for a grid or a rail whose children are elements; **never `.combine`**.
3. **Label = identity, value = state.** `"Seal"` + `"barred, rail 2 is empty"`. Never `"Seal barred"`.
4. **Traits, then value, then actions,** in that order in source, so a reviewer reads the element the
   way VoiceOver speaks it.
5. **A custom action for anything needing a gesture VoiceOver cannot make.** T05 owns the complete
   list; this task attaches the ones §13.10's table names on the elements it wires.
6. **Register the screen for the audit** (T11) and add `.accessibilityIdentifier` only where the
   XCUITest bundle must find the element. Identifiers are never localized and are never labels.

### The index, by screen and by file

Every row below already exists in `voiceover-elements.md` §3–§8. This table is the **wiring plan** —
which file, which accessor — and it deliberately carries no geometry.

**`RoundView` (PROBE, DRIFT) — `Modules/Sources/LoomFeature/RoundView.swift`**

| Drawing | Element | Traits | Label | Value | Actions |
|---|---|---|---|---|---|
| the throat | `.ignore` | `.isImage`, `.updatesFrequently`, adjustable | `loc.loomThroat` | glyph label + last verdict | adjustable ±1 rank of the last-touched attribute |
| the ribbon | `.contain` | — | — | — | — |
| ribbon tile | `.ignore` | `.isButton` | glyph label | `loc.probeState(_:)` | `loc.loadIntoDial` |
| Dial ramp | `.contain` | — | the attribute name | the current value name | — |
| Dial ramp cell | `.ignore` | `.isButton`, `.isSelected` | the value name | `loc.selected` | — |
| PROBE key | — | `.isButton` | `loc.probeKey` | the composed glyph label | — |
| twin key | — | `.isButton` | `loc.twinKey` | the last-probed glyph label | — |
| probe tally | `.ignore` | `.isStaticText`, `.updatesFrequently` | `loc.probes` | `loc.probeTally(used:par:cap:)` | — |
| Bench handle | — | `.isButton` | `loc.bench` | `loc.railsFilled(_:of:)` | — |
| leading chevron | — | `.isButton` | `loc.leaveTheRound` | — | — |

The throat is the **only adjustable element on the play surface**, and it is the non-visual twin of
§6.3's throat swipe. With no last-touched attribute (round start), adjust `fill`, which is rank 1 of
the canonical order:

```swift
// Modules/Sources/HunchUI/ThroatAdjustment.swift
public struct ThroatAdjustment: Sendable {
    public private(set) var attribute: Glyph.Attribute
    public init(lastTouched: Glyph.Attribute?) { attribute = lastTouched ?? .fill }
    public mutating func increment() { … }        // +1 rank, wrapping off (§6.3)
    public mutating func decrement() { … }
}
```

```swift
// RoundView
ThroatView(glyph: round.draft, env: env)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits([.isImage, .updatesFrequently])
    .accessibilityLabel(Text(verbatim: loc.loomThroat))
    .accessibilityValue(Text(verbatim: loc.throatValue(round.draft,
                                                       relativeTo: round.ribbon.last?.glyph,
                                                       lastVerdict: round.ribbon.last?.verdict,
                                                       detail: detail)))
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: round.stepLastTouchedAttribute(by: +1)
        case .decrement: round.stepLastTouchedAttribute(by: -1)
        @unknown default: break      // W29 bans `default:` on OUR enums; this one is Apple's
        }
    }
```

**`BenchView` — `Modules/Sources/LoomFeature/BenchView.swift`** (rows from `voiceover-elements.md` §4)

palette stamp ×4 (`.isButton`, the four tile-class names) · rail (`.contain`, `loc.rail(_:)`, value =
that rail's narration from T03, action `loc.clearRail`) · Ramp tile (`.contain`, `loc.rampOn(_:)`,
value = `loc.admits(_:)`) · Ramp tile cell (`.isButton`, `.isSelected`) · attribute header
(`.isButton`, `.isSelected`, value bound/unbound) · Bridge socket ×2 (`.isButton`, leading/trailing,
value `pips, this glyph` / `pips, previous glyph` / `empty`) · ghost toggle (`.isButton`,
`.isSelected`, `loc.previousGlyph`, on/off) · wedge (`.isButton`, `loc.comparator`, value = the
comparator name, action `loc.cycle`) · coupler (same shape) · Fork dock ×3 (`.contain`, gate/then/else)
· Tally attribute toggle · Tally counter dial (adjustable, `loc.count`) · **the Seal** · the Bench
itself (`.contain`, `loc.bench`, value = the full narration).

**The barred Seal — the one place §13.10 and §4.3 cannot both be taken literally.** §13.10's trait
column says `.notEnabled`; §4.3 makes pressing a barred Seal pulse the offending rail, and §12.5's
nudge 3 counts three such presses. `.disabled(true)` deletes the pulse, the nudge and the "The Seal is
barred" announcement in one line. Ruling (already made in `voiceover-elements.md` §4, restated here
because it is the single most likely thing to be "fixed" later): the bar is the **value**, the button
stays enabled, and `accessibilityRespondsToUserInteraction(true)` restores the discoverability
`.notEnabled` was buying — which is the exact modifier §12.8 asks for on this exact element.

```swift
Button(action: { round.seal() }) { SealCanvas(bar: round.sealBar, env: env) }
    .accessibilityLabel(Text(verbatim: loc.seal))
    .accessibilityValue(Text(verbatim: loc.sealState(round.sealBar)))
    .accessibilityRespondsToUserInteraction(true)
// ✗ .disabled(round.sealBar != nil)
```

`SealAccessibility` exists so `loc.sealState(_:)` is an exhaustive `switch` over `SealBar` with no
`default:` (`W29`): `.inertRail(i)` → "barred, rail *i+1* is empty"; `.unboundSocket(i)` → "barred,
socket *i+1* is empty"; `.constantExtension` → "barred, this law admits everything" / "admits
nothing"; `nil` → "ready". Adding a `SealBar` case is then a compile error here, which is the point of
E06·T03 having made the bar an enum.

**`AssayCanvas` and `AssayInspectorView`.** One element, `children: .ignore`, `.isImage` +
`.updatesFrequently`, label `loc.assay`, actions `loc.inspect` and `loc.readByAttribute`. **The 256
cells are not elements** — 256 swipes against a 20-second announcement, and it would blow the key
budget besides. The *value* is T04's and is deliberately left as a `TODO(E19·T04)` stub returning the
slice count with the wrong conditioning flag, so that T04's test has something to turn red first.
`AssayInspectorView` is a presented subtree: re-inject `hunchEnvironment` (`04 A25`) or `loc` resolves
against nothing.

**`EchoRoundView`, `SieveRoundView`, `SievePauseOverlay`.** Wire the rows this task owns — ECHO's rail
(`.contain`), rail tile (`.isButton`, action `loc.returnToTheTray`), tray tile (`.isButton`,
`.isSelected` when placed); SIEVE's tail (`.contain`), foul ticks (`.isStaticText`, `loc.fouls`,
"1 of 3"), pause key. **T10 owns** the pool strip, the primer strip, the gate and the cast's silence,
because each of those carries a behavioural rule as well as an identity.

**`InscriptionView`, `FrameView`, the Codex, `AnomalyView`, `ProfileView`.** Per
`voiceover-elements.md` §8. Two things to get right:

- **The Frame's mode-key label is the wordmark**, `Text(verbatim: mode.wordmark)`, because §12.9 ships
  PROBE / DRIFT / ECHO / SIEVE untranslated in all twelve locales. It is not a catalog entry. The
  *value* is "barred" / "suspended, 4 of 7 probes" / nothing, and those are.
- **The play key** (44 × 44, trailing, screens 9–15) is **one element with one label on every screen**;
  only its value says whether it resumes or starts. Do not re-label it per screen — a wordless key
  whose name changes is a wordless key nobody learns. This is also why
  `noDuplicateLabelWithinAScreen` is scoped to one screen and not to the whole index.

**`StatisticsView`, `SettingsView`, `AboutView`, `ResetConfirmAlert`.** Stock `Form` / `List` /
`Alert`. They are the only stock components in the app and they are already accessible. **Do not
hand-label a `Toggle`.** The work here is the `.headings` trait, and even that is emitted by
`Section(header:)` on its own — T05 covers the two custom screens that need it added by hand.

### Everything else is explicitly silent

Write `.accessibilityHidden(true)` on each of these, in the file that draws it. An unmarked mark and a
deliberately silent one look identical in a diff, and the audit's `.elementDetection` pass cannot tell
them apart either:

link arc and return elbow · the ghost frame when depictive (it is the *value* of the thing it frames)
· the machined bar (it is the Seal's or the mode key's value) · the cancel hatch (it is a ramp cell's
value) · bloom, halo, shader grain, scanline, vignette · rules, section boundaries, scrims · the
Frame's idle Loom (§12.4 makes it non-interactive scenery; an 8-second crossfade announcing itself is
noise) · the verdict ring (it is the tile's value) · the par tick row (the probe tally speaks the same
fact as a numeral) · SIEVE's lip and lane · ECHO's dark ribbon during the cast.

### Traversal order is geometry, not a sort priority

`accessibilitySortPriority` is **not used anywhere in HUNCH**, and T11's hygiene check greps for it.
§12.8's three reach tiers already order every surface correctly — read-only above y 220, composition
at y ≥ 220, commit in the commit bar — so the default traversal *is* verdict-then-evidence-then-action.
A sort priority that restates the layout is a second source of truth that goes stale the first time a
frame moves, and above AX2 several screens re-flow anyway (T06). If a screen seems to need one, the
layout is wrong or a container is missing: reach for `.accessibilityElement(children: .contain)` and
T05's four rotors instead.

### The glyph label's seam

Several rows above call `loc.glyphLabel(_:relativeTo:detail:)`, which **T02 owns**. This task lands the
signature and a full-form-only implementation so every call site is already correct; T02 makes it
plural-aware, adds the terse enumeration and adds the 256-label distinctness test. Do not invent a
second builder, and **do not omit `relativeTo previous:`** at any call site: adding the parameter later
means touching every one of them, which is exactly what `voiceover-elements.md` §9 says not to do.

### The key budget is a decision, not a line

§12.9 budgets 134 accessibility keys inside a hard 250, and control labels are 77 of them. Three ways
to add a label for free, in the order to try them: reuse an existing value name; make it a **value** of
an element that already has a label; or express it as an interpolation in a format string that already
exists. E18 shipped the catalog and the CI count; if this task needs a key E18 did not write, the key
goes into the catalog **and** the budget assertion is re-run before the commit.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter AccessibilityVocabularyTests` green, all eight tests.
- [ ] `Scripts/check-source-hygiene.sh` green, and checks 11a and 11b each demonstrated to fail on a planted `.accessibilityLabel("Seal")` and a planted `.combine` before reverting.
- [ ] `grep -Rn 'accessibilityHidden(true)' Modules/Sources --include='*.swift' | wc -l` is at least 11 — one per row of the silent list above — and every one of them sits in the file that draws the mark.
- [ ] `grep -Rn 'disabled(' Modules/Sources/LoomFeature/BenchView.swift` returns nothing on the Seal.
- [ ] `grep -Rn 'accessibilitySortPriority' Modules/Sources` returns nothing.
- [ ] `grep -Rn 'glyphLabel(' Modules/Sources --include='*.swift'` shows **every** call passing `relativeTo:` and `detail:`.
- [ ] `AccessibilityScreen.allCases.count == 18` and every screen with its own elements has at least one indexed row.
- [ ] `tests.json` carries the gate-4 label-completeness entry with a runnable `command`.
- [ ] The fast suite is still under 10 s and `swift test --package-path Modules` is green.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T01: the VoiceOver element map across all 18 screens"`

## Out of scope

- The glyph label's plural-aware pips and terse form — **T02**; this task lands the signature only.
- The Bench and Codex-page narration values — **T03**; the rail and Bench rows carry a `TODO(E19·T03)` stub value until then.
- The Assay's `accessibilityValue` conditioning and "Read by attribute" — **T04**.
- Rotors, Magic Tap, escape, `.headings` on the two custom screens, and every announcement — **T05**.
- ECHO's pool and primer strips, SIEVE's gate, and nudge suppression — **T10**.
- `performAccessibilityAudit`, `.accessibilityIdentifier` values consumed by XCUITest, and the AX5 × 5-locale snapshot — **T11**.
- The drawings themselves, and any geometry change under an accessibility setting — **T06 – T09** and the component epics they cite.
