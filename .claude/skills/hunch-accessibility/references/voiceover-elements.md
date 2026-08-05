# voiceover-elements.md — the element index, by drawing

Contents: [1 How to read this](#1-how-to-read-this) · [2 Marks that are not elements](#2-marks-that-are-not-elements) ·
[3 PROBE and DRIFT — RoundView](#3-probe-and-drift--roundview) · [4 The Bench](#4-the-bench) ·
[5 The Assay](#5-the-assay) · [6 ECHO](#6-echo) · [7 SIEVE](#7-sieve) ·
[8 Inscription, Frame and the meta screens](#8-inscription-frame-and-the-meta-screens) ·
[9 The glyph label](#9-the-glyph-label) · [10 Narration and the parity invariant](#10-narration-and-the-parity-invariant) ·
[11 Announcements](#11-announcements) · [12 Traversal order](#12-traversal-order) ·
[13 The key budget](#13-the-key-budget) · [14 What would be wrong](#14-what-would-be-wrong)

---

## 1. How to read this

§13.10 is indexed by **interactive element**. This file is indexed by **drawing**, because that is the moment the
question arises: you are in a `Canvas`, you have just stroked something, and you need to know whether it speaks.
Every row of §13.10 appears here; rows marked **†** are marks §13.10 omits and this skill adds, and they are almost
all *not* elements — which is itself the answer that stops a reviewer re-litigating them.

Columns: **Element** (yes / hidden / part of a parent) · **Traits** · **Label** (identity, stable) · **Value**
(state, changes) · **Actions**. The drawing itself belongs to another skill; the "Drawn by" column says which, and
you must not restate its geometry here.

`.accessibilityHidden(true)` is written **explicitly** on every hidden mark. An unmarked mark and a deliberately
silent one look identical in a diff otherwise, and the audit's `.elementDetection` pass cannot tell them apart either.

---

## 2. Marks that are not elements

| Drawing | Why silent | Drawn by |
|---|---|---|
| Link arc / return elbow † | pure adjacency; the ribbon's element order already carries it | `hunch-shared-marks` |
| Ghost frame, when depictive † | it is the *value* of the thing it frames ("previous glyph"), never its own element | `hunch-shared-marks` |
| Machined bar † | it is the Seal's or the mode key's **value** — "barred, rail 2 is empty" | `hunch-shared-marks` |
| Cancel hatch † | it is a ramp cell's value — "not admitted" | `hunch-shared-marks` |
| Bloom, halo, shader grain, scanline, vignette † | no information; §13.5.1 proves every channel survives greyscale | `hunch-glyph-renderer`, `hunch-design-tokens` |
| Rules, section boundaries, scrims † | structure for the eye; `.contain` containers carry it for VoiceOver | `hunch-chrome-and-meta` |
| The Frame's idle Loom † | §12.4 makes it non-interactive scenery. An 8-second crossfade announcing itself is noise | `hunch-chrome-and-meta` |
| Verdict ring † | it is the throat's / tile's **value** (`"admitted"` / `"rejected"`), never a sibling element | `hunch-shared-marks` |
| Par tick row † | the drawing is silent; the **probe tally** element (§3) speaks the same fact as a numeral | `hunch-shared-marks` |
| SIEVE lip and lane † | see §7 — the preview is deliberately not announced | `hunch-bench-instruments` |

---

## 3. PROBE and DRIFT — RoundView

| Drawing | Element | Traits | Label | Value | Actions | Drawn by |
|---|---|---|---|---|---|---|
| the throat | yes | `.isImage`, `.updatesFrequently`, adjustable | "Loom throat" | glyph label + last verdict | adjustable: ↑/↓ steps the last-touched attribute ±1 rank | `hunch-bench-instruments` |
| ribbon tile | yes | `.isButton` | glyph label | "admitted" / "rejected" / "seed glyph" / "twin" | "Load into the Dial" | `hunch-bench-instruments` |
| ribbon (the lane) | container | — | — | — | — | " |
| Dial ramp | container | — | "Fill" (the attribute) | current value | — | `hunch-bench-instruments` |
| Dial ramp cell | yes | `.isButton`, `.isSelected` | the value name ("striped") | "selected" | — | " |
| PROBE key | yes | `.isButton` | "Probe" | the composed glyph label | — | `hunch-chrome-and-meta` |
| twin key | yes | `.isButton` | "Twin" | the last-probed glyph label | — | " |
| probe tally | yes | `.isStaticText`, `.updatesFrequently` | "Probes" | "12 of 23 expected, 37 maximum" | — | `hunch-shared-marks` |
| Bench handle | yes | `.isButton` | "Bench" | "1 of 2 rails filled" | — | `hunch-chrome-and-meta` |
| leading chevron | yes | `.isButton` | "Leave the round" | — | escape action, §rotors §4 | `hunch-chrome-and-meta` |

The throat is the only **adjustable** element in the app. `.accessibilityAdjustableAction { direction in … }` maps
`.increment`/`.decrement` onto ±1 rank of the last-touched attribute — the non-visual twin of the throat swipe (§6.3).
Without a last-touched attribute (round start), adjust `fill`, which is rank 1 of the canonical order.

---

## 4. The Bench

| Drawing | Element | Traits | Label | Value | Actions |
|---|---|---|---|---|---|
| palette stamp ×4 | yes | `.isButton` | "Ramp tile", "Bridge tile", "Fork tile", "Tally tile" | — | — |
| rail | container | — | "Rail 1" | that rail's narration (§10) | "Clear rail" |
| Ramp tile | container | — | "Ramp on shape" | "admits triangle, hexagon" | — |
| Ramp tile cell | yes | `.isButton`, `.isSelected` | the value name | "admitted" | — |
| attribute header | yes | `.isButton`, `.isSelected` | the attribute name | "bound" / "unbound" | — |
| Bridge socket | yes | `.isButton` | "Leading socket" / "Trailing socket" | "pips, this glyph" / "pips, previous glyph" / "empty" | — |
| ghost toggle | yes | `.isButton`, `.isSelected` | "Previous glyph" | "on" / "off" | — |
| wedge | yes | `.isButton` | "Comparator" | "greater than" | "Cycle" |
| coupler | yes | `.isButton` | "Coupler" | "and" / "or" / "exclusive or" | "Cycle" |
| Fork dock ×3 | container | — | "Gate" / "Then" / "Else" | "hue is amber" / "pips admits three, four" | — |
| Tally attribute toggle | yes | `.isButton`, `.isSelected` | the attribute name | "counted" / "not counted" | — |
| Tally counter dial | yes | adjustable | "Count" | "admits 0, 2 and 3" | — |
| the Seal | yes | `.isButton` | "Seal" | "ready" / "barred, rail 2 is empty" | — |
| the Bench itself | container | — | "Bench" | the full narration (§10) | — |

**The barred Seal keeps `.isButton` and stays enabled.** §13.10's trait column says `.notEnabled`; §4.3 makes pressing
it pulse the offending rail and §12.5's nudge 3 counts three such presses. Those cannot both be true. Ruling: the bar is
the **value**, `.accessibilityRespondsToUserInteraction(true)` restores the discoverability `.notEnabled` was buying
(§12.8 asks for exactly that modifier on exactly this element), and the tap keeps reaching the handler. `.disabled(true)`
would delete the pulse, the nudge and the "Seal is barred" announcement in one line.

---

## 5. The Assay

| Drawing | Element | Traits | Label | Value | Actions |
|---|---|---|---|---|---|
| the Assay | yes, `children: .ignore` | `.isImage`, `.updatesFrequently` | "Assay" | the lit count **of the slice on screen** | "Inspect", "Read by attribute" |
| a cell | no | — | — | — | — |

**The value is the pinned slice, never the marginal projection.** §4.3 conditions the live Assay on the pinned ghost,
so a contextual draft reads *"Admits 64 of 256 glyphs, with this previous glyph"* and a stateless one *"Admits 64 of
256 glyphs"*. Quoting the unconditional projection says 48 where the screen shows 64 — the single most likely wrong
answer here, because the projection is the number the model layer hands you first.

**"Read by attribute"** is the answer to 256 cells: one interruptible announcement speaking the sixteen marginals
(*"Of glyphs with shape triangle, 12 of 64 admitted"*). Exposing 256 cells as elements is not an alternative — it is
256 swipes against a 20-second announcement, and it would blow the key budget besides. The cells are `.ignore`d, and
`AssayInspectorView` is a presented subtree, so re-inject the environment there (`04 A25`).

§12.6's `announceAssay` toggle is **off by default**; the Assay's value is still read on focus, and only the
per-edit announcement is gated.

---

## 6. ECHO

| Drawing | Element | Traits | Label | Value | Actions |
|---|---|---|---|---|---|
| primer strip | container | — | "Primer" | "3 glyphs" | — |
| a primer glyph | yes | `.isStaticText` | glyph label | "admitted" / "rejected" | — |
| the rail | container | — | "Rail" | "2 of 16 placed" | — |
| rail tile | yes | `.isButton` | glyph label | "position 2" | "Return to the tray" |
| tray tile | yes | `.isButton`, `.isSelected` when placed | glyph label | "placed, position 2" / "not placed" | — |
| the cast's dark ribbon † | hidden | — | — | — | — |

The cast is silent by construction: §8.4 gives no feedback during it, so the ribbon draws dark and speaks nothing.
A value announcing "cast in progress" would leak the fact that a verdict exists.

---

## 7. SIEVE

| Drawing | Element | Traits | Label | Value | Actions |
|---|---|---|---|---|---|
| the gate | yes | `.isButton`, `.updatesFrequently` | "Gate" | the glyph label of whatever is actionable | **"Admit"** |
| the tail | container | — | "Tail" | the last 6 resolved glyphs, each label + verdict | — |
| foul ticks | yes † | `.isStaticText` | "Fouls" | "1 of 3" | — |
| lip, lane | hidden | — | — | — | — |
| pause key | yes | `.isButton` | "Pause" | — | — |

Announcement, not traversal, carries the stream: each glyph is announced **on gate entry** and its resolution
announced in the sump (§9.8). **Do not add lane announcements to "restore" the preview.** §9.8 already priced that
trade — VoiceOver runs in step mode with `r` fixed at 0.75 g/s (an 889 ms window) and no ramp, in exchange for the
preview a sighted player reads off the lane; the Tempo axis is not updated because the timing is not comparable.
Announcing the lane would hand the VoiceOver player a longer window *and* the preview, which is a different game.

`SieveSchedule` takes the pacing as a parameter — it is a pure value in `HunchCore` and must not read
`UIAccessibility` (`08 §2`). See `rotors-and-gestures.md` §9.

---

## 8. Inscription, Frame and the meta screens

| Screen | Elements | Notes |
|---|---|---|
| `InscriptionView` | the revealed rule-tiles (container, value = narration), Seal marks (`"Three marks"`), probes-vs-par tally, the minted-page key, *again* key, Frame key | 8 keys (§12.9). The reveal is announced once, in §11's fixed order, not beat by beat |
| `FrameView` | 4 mode keys, Codex, Profile, Settings, Anomaly | 8 keys. Mode key label is the **wordmark** — PROBE / DRIFT / ECHO / SIEVE ship untranslated in all 12 locales (§12.9), so the label is `Text(verbatim:)`-shaped, not a catalog entry. Value: "barred" / "suspended, 4 of 7 probes" / — |
| `CodexRootView` | 8 shelf plates, 5 facet stamps, play key | 6 keys; `.headings` rotor on the shelf titles |
| `CodexShelfView` | thumbnail grid (`.contain`), rail scrubber (adjustable), play key | 3 keys |
| `CodexPageView` | rule-tiles (container, value = narration), that law's Assay, instrument strip, find log | no title (§12.9); the page is identified by its narration |
| `AnomalyView` | 28-cell ribbon (`.contain`), today's cell (`.isButton`), tally, streak ring, rollover arc | 5 keys |
| `ProfileView` | contour (`.isImage`), 5 vertex sigils, stat block rows | 3 keys. The vertex sigils speak §11.11's **behavioural sentences**; *Induction, Retention, Flexibility, Restraint, Tempo* never enter the catalog in any form |
| `StatisticsView`, `SettingsView`, `AboutView`, `ResetConfirmAlert` | stock `Form` / `List` / `Alert` | the only stock components in the app; they are already accessible. Do not hand-label a `Toggle` |
| `SievePauseOverlay` | the frozen gate ("Resume"), the abandon chevron | `.isModal` on the overlay |

The **play key** (44 × 44, trailing, on screens 9–15) is one element with a stable label on every screen; its value
says whether it resumes or starts. Do not re-label it per screen — a wordless key whose name changes is a wordless key
nobody learns.

---

## 9. The glyph label

Canon's format, canon's order (`fill → shape → pips → hue`), **one** localized format string with four interpolations:

```
GLYPH_LABEL = "%1$@ %2$@, %3$@, %4$@"        →  "hollow triangle, three pips, teal"
```

`pips` is itself a plural-aware String Catalog entry (`"1 pip"` / `"3 pips"`), a complete grammatical unit — Russian
needs four categories and Arabic six, so `count == 1 ? … : …` is a bug (§12.9 trap 4).

**Terse mode** (§12.6's `voiceOverDetail`) speaks only the attributes that changed since the previous glyph. Joining
those with `joined(separator: ", ")` is trap 3 in disguise; joining them with Foundation's locale-aware list style is
not, because they are an *enumeration*, not a sentence:

```swift
// Modules/Sources/HunchUI/Loc.swift — every accessor returns an ALREADY-RESOLVED String.
public func glyphLabel(_ g: Glyph, relativeTo previous: Glyph?, detail: VoiceOverDetail) -> String {
    let changed = detail == .terse ? previous.map(g.attributes(differingFrom:)) ?? [] : []

    guard !changed.isEmpty, changed.count < Glyph.Attribute.allCases.count else {
        // Full form: ONE format string, four interpolations, `pips` plural-aware inside its own entry.
        return String(localized: "GLYPH_LABEL",
                      defaultValue: "\(name(g.fill)) \(name(g.shape)), \(pipCount(g.pips)), \(name(g.hue))",
                      bundle: .atURL(bundleURL), locale: locale)
    }
    // Terse: an ENUMERATION of the changed values, joined by the locale's own list grammar.
    // Never `joined(separator: ", ")` — that is trap 3 wearing a comma.
    return changed.map { valueName(of: g, $0) }
                  .formatted(.list(type: .and, width: .narrow).locale(locale))
}
```

Three rules the shape encodes. **Every label builder takes `relativeTo previous:`**, even where terse is not yet
wired, because adding the parameter later means touching every call site. **An empty changed-set falls back to the
full label**, so a twin never speaks an empty string — and so does an all-four-changed set, because at that point the
terse form is the full form with worse grammar. And the return type is `String`, not `LocalizedStringResource`:
`LocalizedStringResource(stringLiteral:)` treats its argument as a **key**, so handing it a runtime-joined list looks
like it works and is really a failed lookup falling back to itself. Call sites are `Text(verbatim:)`.

Accessibility labels are audio. Canon's no-text rule constrains **rendered pixels only**, so numbers — probe count,
par, cap, marks — are spoken even though they are never drawn.

---

## 10. Narration and the parity invariant

**`LawNarrator` cannot return a `String` from `HunchCore`.** A localized lookup needs a bundle, and `08 §2`'s boundary
rule bans bundles from the core ("no file path, no bundle"). The ruling:

```swift
// HunchCore/Sources/Laws/Narration.swift — pure over values, no Foundation bundle, no locale.
public indirect enum Narration: Hashable, Sendable {
    case atom(Glyph.Attribute, admits: [Int])                    // "shape admits triangle or hexagon"
    case relation(Glyph.Attribute, Comparator, contextual: Bool) // "pips of this glyph is greater than …"
    case guarded(gate: Narration, then: Narration, else: Narration)
    case aggregate(Glyph.Attribute, counts: [Int])
    case coupled(Coupler, Narration, Narration)

    public init(_ law: LawNode) { … }                            // reads the RNF; drops folded-away terms
}
```

`Loc.narration(_:)` in `HunchUI` renders it: **one format string per node**, children interpolated, so the coupler is
`"%1$@, and %2$@"` and never a `+`. `CodexPageView` and `BenchView` call the same function on the same value, which is
how §13.10's "a narrated law and a rendered law are the same law in two media" stops being an aspiration.

Naming: `…Narrator` is an `N26` service-object ban, the same shape `AudioManager` and `CodexManager` are rejected for
in `08 §3`. A value-preserving conversion drops the label (`N14`), exactly as `Bench.layout(for:)` became
`BenchLayout.init(_:)`.

**Rejected alternative, and why it matters:** `LawNarrator.narrate(_:) -> String` in `HunchCore`. It breaks the
boundary rule; it drags the String Catalog into a package that must build on the host with `swift test`; and the
parity test would then compare *rendered English*, leaving eleven locales untested by a test whose whole job is to
prove the narration is faithful.

**The parity invariant** (§13.10, §13.12 gate 7) — the narrator says nothing a sighted player cannot read off the
tiles, over 10,000 generated laws. `06 T21` bans loops in tests and `08 §7.4` already ruled on this exact tension:
parameterise over the eight bands, loop inside, and pay `T21` back with a reproducing seed in every failure.

```swift
@Test("Bench narration matches the rendered tiles", .tags(.unit, .presubmission), arguments: Band.allCases)
func narrationMatchesTiles(_ band: Band) throws {
    for i in 0..<1_250 {                                          // 8 × 1,250 = 10,000 laws
        let seed = Corpora.seed(band: band, index: i)
        let law = generate(seed: seed, band: band, targetDelta: band.centre, mode: .probe)
        let parsed = LawNode(BenchLayout(law))                    // value-preserving both ways (N14, G10)
        guard LawTable(parsed) == LawTable(law),                  // the tiles mean the law
              Narration(parsed) == Narration(law.renderedNormalForm) else {   // and the words mean the tiles
            Attachment.record(law, named: "narration-b\(band.rawValue)-\(String(seed, radix: 16)).json")
            Issue.record("narration parity failed at band \(band.rawValue), seed 0x\(String(seed, radix: 16))")
            return
        }
    }
}
```

Every failure names one seed; promote it into `@Test(arguments: knownBadSeeds)` as a permanent case (`06 T53`).

**The narration describes only the player's own draft or an already-revealed law.** Never a hidden law mid-round —
`Narration` is built from a `LawNode` the player owns, and the round model never hands it the hidden one. Assert it:
a test that `Round.benchNarration` is `nil` in every phase before `.revealing`.

---

## 11. Announcements

Priority `.high` on verdicts so they interrupt. Order is fixed — **verdict → evidence → bookkeeping** — so a fast
player can move on after two words. §12.6's `announceVerdicts` toggle gates the verdict rows and nothing else.

| Event | Announcement |
|---|---|
| admit / reject | "Admit. Hollow triangle, three pips, amber. Probe 12 of 23." |
| twin | the same, prefixed "Twin. " |
| past par / 5 from cap | "Past the expected probe count." / "Five probes remaining." — each once per round |
| cap reached | "Probe limit reached. Round over. The law was: {narration}." |
| barred Seal pressed | "The Seal is barred. Rail 2 is empty." |
| declaration correct | "Correct. {narration}. Inscribed. Three marks. Fifteen probes." |
| first strike | "Incorrect. Strike one of two. Counterexample: solid square, two pips, rose. Your law rejects it; the Loom admits it. The round continues." |
| second incorrect | "Incorrect. Round over. The law was: {narration}." |
| DRIFT swap revealed | "The law changed after probe 9." |
| streak | "Streak: four." |
| screen change | `AccessibilityNotification.ScreenChanged` with the screen name |

An announcement is an `AttributedString`, so it **may not be built in one of the six play-surface files** — check 7
fails the build on `AttributedString` there. One owner, outside the six:

```swift
// Modules/Sources/HunchUI/Announcer.swift
@MainActor
public struct Announcer: Sendable {
    public var isEnabled: Bool                                   // §12.6 `announceVerdicts`

    /// `text` is already resolved by `Loc` against the override bundle and locale.
    public func announce(_ text: String, priority: AccessibilitySpeechAnnouncementPriority = .high) {
        guard isEnabled else { return }
        var message = AttributedString(text)
        message.accessibilitySpeechAnnouncementPriority = priority
        AccessibilityNotification.Announcement(message).post()
    }

    public func screenChanged(to name: String) {
        AccessibilityNotification.ScreenChanged(AttributedString(name)).post()
    }
}
```

The reveal is announced **once, at settle**, not beat by beat. The eight beats of §13.7.1 are a visual sequence; eight
announcements across `Dur.reveal` would be unreadable and would collide with the verdict announcement that opens them.
(`Dur.reveal` is `hunch-design-tokens/references/durations-and-easing.md` §2's and the beat timeline is
`hunch-motion-and-feedback/references/reveal-beats.md`'s — this file owns only that there is one announcement, and where
it lands.)

---

## 12. Traversal order

**`accessibilitySortPriority` is not used anywhere in HUNCH.** §12.8's three reach tiers already order every surface
correctly by geometry — read-only above y 220, composition at y ≥ 220, commit in the commit bar — so the default
traversal *is* verdict-then-evidence-then-action. A sort priority that restates the layout is a second source of truth
that goes stale the first time a frame moves, and above AX2 several screens re-flow (`environment-settings.md` §2).

If a screen ever seems to need one, the layout is wrong or a container is missing. Reach for `.accessibilityElement(children: .contain)`
and the four rotors instead — that is what they are for.

`.accessibilityIdentifier` is set only where `HunchUITests` must find an element, is never localized, and is never a
substitute for a label. The audit's `.sufficientElementDescription` pass will not accept one.

---

## 13. The key budget

§12.9 budgets **134 accessibility keys** inside a hard total of **250**, asserted by a CI test over
`Localizable.xcstrings` (`08 §5` check 8). The breakdown that matters when adding a label: control labels 77,
attribute and value names 20, hints 14, announcements 9, value formats 8, Profile vertex sentences 5, the glyph label
format 1.

A new label is a budget decision. Three ways to add one for free: reuse an existing value name; make it a *value*
of an element that already has a label; or express it as an interpolation in a format string that already exists.
Whether the pips plural entry counts as one key or four is String Catalog bookkeeping — the assertion that matters is
`catalog.keyCount <= 250`, and it runs in CI, not in the package tests, because the catalog is compiled to `.lproj`
at build time (`08 §5`).

---

## 14. What would be wrong

- **A label that carries state, or a value that carries identity.** `"Seal barred"` as a label means the rotor reads a
  different control every time the rail empties, and `.updatesFrequently` has nothing to attach to.
- **A row here that spells out a radius, a weight, a duration or a colour.** The drawing's own skill owns its geometry;
  this index owns what it says. The reverse is equally banned — a component reference file that spells out a label has
  copied it.
- **A mark that is neither an element nor explicitly `.accessibilityHidden(true)`.** §1: unmarked and deliberately
  silent look identical in a diff, and the audit's `.elementDetection` pass cannot tell them apart either.
- **`.accessibilityElement(children: .combine)` anywhere on the play surface.** It glues fragments in source order,
  which German and Arabic both break (§12.9 trap 3).
- **Quoting the Assay's unconditional marginal projection as its value.** §5. It says 48 where the screen shows 64, and
  it is the number the model layer hands you first.
- **Exposing the Assay's 256 cells as elements.** §5. 256 swipes against a 20-second announcement, and it blows the key
  budget besides.
- **`LawNarrator.narrate(_:) -> String` in `HunchCore`.** §10. It breaks `08 §2`'s boundary rule, and it degrades the
  parity test into a comparison of rendered English — leaving eleven locales untested by the test whose whole job is to
  prove the narration faithful.
- **A label builder without `relativeTo previous:`.** §9. Terse mode then cannot be added without touching every call
  site.
- **`LocalizedStringResource(stringLiteral:)` on a runtime-built string.** §9. Its argument is a *key*, so a joined list
  looks like it works and is really a failed lookup falling back to itself.
- **`joined(separator: ", ")` on the terse enumeration.** §9. Trap 3 wearing a comma; the locale's own list style is the
  only correct join.
- **`accessibilitySortPriority` to fix a traversal order.** §12. The layout is wrong, or a container is missing.
- **Announcing the reveal beat by beat**, or announcing the ECHO cast. §11, §6. Both leak or bury the one thing the
  player came for.
- **Adding a label without spending it against §12.9's budget.** §13. A label with no budget decision behind it is how
  a hard 250-key ceiling is discovered at 251.
