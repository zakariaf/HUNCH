# stock-controls.md — the only four screens allowed a system component

Owning symbols: `MetaFeature/SettingsView.swift`, `StatisticsView.swift`, `AboutView.swift`,
`ResetConfirmAlert.swift`, plus `HunchUI/Chrome/DrawnToggleStyle.swift`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Stock `Form` / `List` / `Alert`*.

Contents: [1 Neutralising the container](#1-neutralising-the-container) · [2 The drawn switch](#2-the-drawn-switch) ·
[3 Rows, separators and headers](#3-rows-separators-and-headers) · [4 Pickers](#4-pickers) ·
[5 The play key and navigation](#5-the-play-key-and-navigation) · [6 The five alerts](#6-the-five-alerts) ·
[7 StatisticsView](#7-statisticsview) · [8 Dynamic Type and VoiceOver](#8-dynamic-type-and-voiceover) ·
[9 Wrong](#9-wrong)

Four screens, and no fifth: `SettingsView` (7 sections, 19 rows, §12.6), `StatisticsView` (5
sections, 19 rows, §11.12), `AboutView` (6 rows, §12.9), `ResetConfirmAlert` (5 variants, §12.2).
Sixteen of the eighteen screens draw into a `Canvas`; these are the exceptions, and they are stock
because a hand-rolled settings list is a large surface of accessibility bugs for no design gain.

---

## 1. Neutralising the container

**This is the one place in the app where the OS picks a colour, and it picks wrong.** A `Form` ships
`systemGroupedBackground` (a blue-grey) and tints every control with the system accent (blue). Both
are palette violations that `check-source-hygiene.sh` check 9 cannot catch, because there is no
literal to grep. Fix it once, at the container:

```swift
// Modules/Sources/MetaFeature/SettingsView.swift
Form { … }
    .scrollContentBackground(.hidden)                              // drop systemGroupedBackground
    .background(env.palette.ground.base.color.ignoresSafeArea())
    .tint(env.palette.stroke.primary.color)                        // never the system accent
    .listRowBackground(env.palette.ground.raised.color)            // §13.2: raised is for sheets and rows
    .listRowSeparatorTint(env.palette.stroke.hairline.color)
    .environment(\.defaultMinListRowHeight, Space.s44)
```

**`.tint(stroke.primary)`, not `accent.brass`.** §13.1 rations the accent to at most three elements
per screen, and a 19-row Settings list has eight toggles and four pickers. Accent is a *verdict*
register (§13.2: admit, the Seal, marks, streak); spending it on a switch would make "the machine has
answered" and "you turned on sound" the same colour. Settings contains **no accent at all**.

---

## 2. The drawn switch

§13.2's register rule forbids `hue.*` on chrome and specifically names the Settings switch. PHOSPHOR
§3 gives the drawing: *"a 51 × 31 track with a `w.hairline` frame and a 27 pt slug; ON = slug filled
`stroke.primary`, at the trailing end; OFF = slug hollow with a `w.thin` frame at `opacity.disabled`,
at the leading end."* **Two independent non-colour channels — position and fill — and no accent.**

**One deviation from PHOSPHOR, and its reason.** PHOSPHOR's sketch implies the system's capsule
shape. §13.3 caps chrome radius at `radius.chrome` and nothing exceeds it except the Bench sheet's
top corners (`hunch-design-tokens/references/dimensions-strokes-opacity.md` §4 holds both values). A
capsule's radius is half its height, which is an order above the cap. The track is therefore a
**rounded rectangle at `Radius.chrome`, and the slug is a square at the same radius** — a rectangular
slug in a rectangular gate, which is what an instrument panel's switch looks like and what makes this
control unmistakably ours rather than iOS's with the colour changed. The 51 × 31 / 27 pt metrics are
kept because they are the platform's travel and hit geometry, and they are declared as
`C.Toggle.trackWidth`, `.trackHeight` and `.slugSide`.

```swift
// Modules/Sources/HunchUI/Chrome/DrawnToggleStyle.swift
struct DrawnToggleStyle: ToggleStyle {
    @Environment(\.renderEnv) private var env

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: Space.s12)
            track(isOn: configuration.isOn)
                .frame(width: C.Toggle.trackWidth, height: C.Toggle.trackHeight)
                .frame(minWidth: Space.s44, minHeight: Space.s44)     // hit rect ≥ 44, §12.8
                .contentShape(Rectangle())
                .onTapGesture { configuration.isOn.toggle() }
                .animation(Easing.easeOut.animation(for: Dur.tap), value: configuration.isOn)
        }
    }

    private func track(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: Radius.chrome, style: .continuous)
            .strokeBorder(env.palette.stroke.secondary.color, lineWidth: env.weight(.hairline))
            .overlay(alignment: isOn ? .trailing : .leading) { slug(isOn: isOn) }
    }
    …
}
```

**Use a `ToggleStyle`, never a hand-rolled `Button`.** The style keeps `Toggle`'s `.isToggle` trait,
its on/off accessibility value, its Magic Tap eligibility and its `legibilityWeight` response for
free. A `Button` that flips a `Bool` announces itself as a button with no state, which is a
Definition-of-Done failure against §13.12 gate 4.

**RTL:** the track mirrors and the slug's travel mirrors with it (PHOSPHOR §3). Use
`.leading`/`.trailing` alignment, never `.left`/`.right` — §12.8.

---

## 3. Rows, separators and headers

**A row.** `ground.raised` background, `Radius.chrome`, no shadow, height ≥ 44. `type.body` in
`stroke.primary` leading; a secondary value in `type.caption` / `stroke.secondary` on a second line
where present; the control trailing with its own ≥ 44 × 44 hit rect. Pressed is `surface.cellLit` — a
ground step, not a tint (PHOSPHOR §3).

**The separator is configured, never drawn.** Inset 16 leading, flush trailing:

```swift
.listRowSeparatorTint(env.palette.stroke.hairline.color)
.alignmentGuide(.listRowSeparatorLeading) { _ in Space.s16 }
.alignmentGuide(.listRowSeparatorTrailing) { d in d[.trailing] }
```

Drawing a `Rule()` inside a row produces two lines. `rules-and-boundaries.md` §5 owns that boundary.

**Section headers.** Settings headers take the `type.section` role; Statistics section heads and
column heads take `type.micro` (§13.4). Both roles are UPPERCASE, and their size, weight, width and
tracking are `hunch-design-tokens/references/type-ramp.md` §1's rows — read them through
`env.type(_:)`, never assemble them.

```swift
Section {
    …
} header: {
    Text(verbatim: Loc.settingsDisplayHeader)   // already cased by Loc, with the resolved locale
        .font(env.type(.section).font)
        .foregroundStyle(env.palette.stroke.secondary.color)
        .textCase(nil)                        // ← stops the system applying a SECOND, locale-unaware
}                                             //   uppercase on top of ours
```

**Casing happens in `Loc`, with `String.uppercased(with: locale)`.** Never `.textCase(.uppercase)`
and never the font's small-caps feature: Turkish maps `i → İ` and the naive path gives `I`; Arabic is
caseless and a transform mangles shaping; SF Pro's small-caps degrades non-Latin to full caps
(§13.4, §12.9 traps 5 and 6). `.textCase(nil)` is written explicitly so the system's own header
casing can never stack on top of the correct one.

Labels sit on a 20 pt band flush to the 16 pt margin with `space.cozy` of air before the first row
beneath (PHOSPHOR §3).

---

## 4. Pickers

§12.6 specifies segmented controls: Theme (4), Reduce motion (2), Level (2), VoiceOver Detail (2).

**Segmented below AX1; inline at AX1 and above.** A four-way segmented control cannot wrap, and
§13.4 forbids `minimumScaleFactor` below 1.0 — so at AX3 in German the four theme labels have nowhere
to go, and §13.11's snapshot gate (AX5 × 5 locales, zero truncation, zero horizontal overflow) fails.
`Picker` swaps style without changing its accessibility contract, so:

```swift
Picker(selection: $preference.theme) {
    ForEach(ThemePreference.allCases) { Text(verbatim: Loc.themeName($0)).tag($0) }
} label: {
    Text(verbatim: Loc.settingsTheme)
}
.pickerStyle(env.isArtScaleClamped ? .inline : .segmented)
.tint(env.palette.stroke.primary.color)
```

**`env.isArtScaleClamped`, never a bare comparison against the ceiling.** The threshold *is* the
Dynamic Type art ceiling — art freezes and layout re-flows at the same category — and the ceiling has
one home, `Prim.artScaleCeiling`. A view may not name a `Prim` (`hunch-design-tokens/SKILL.md`), so
the only spelling available to a call site is the derived predicate
`typeMultiplier >= Prim.artScaleCeiling`, declared beside `artScale` in
`hunch-design-tokens/references/render-env.md` §3. Writing the number here is how twenty files ended
up each holding a copy of it, and `check-source-hygiene.sh` check 9 greps for hexes and `lineWidth:`
literals — it cannot see a bare `1.35`. Do not name the predicate for a Dynamic Type category: the
ceiling is reached at **AX1** (`environment-settings.md` §2), so `isAX3OrAbove` would be wrong on its
face.

`Loc.themeName(_:)` resolves the four theme names; `Text($0.label)` with a bare
`LocalizedStringResource` bypasses `Loc`'s override bundle and stays English until the next cold
launch (§12.9 trap 1).

A `PickerStyle` cannot be written by hand — the protocol has no public requirements — so a
custom-drawn segmented control would have to be a row of `Key`s, and would lose the picker's
adjustable rotor behaviour. Two stock styles beat one hand-rolled control here.

**The language picker (13 entries) is always `.navigationLink`.** Thirteen endonyms in one row is not
a segmented control at any type size, and the endonyms are constants rather than translation units
(§12.9).

---

## 5. The play key and navigation

`SettingsView` is screen 15 and carries a play key (§12.3); `AboutView` is screen 16 and does not.
On these two screens the instrument bar **is the system navigation bar** — do not draw a second one
under it (`instrument-bar.md` §5):

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) { Key(site: .utility, state: .idle, action: play) { ThroatSigil() } }
}
```

`NavigationStack` is used exactly twice in the app — the Codex, and Settings → About (§12.3). Settings
→ About is the only push here.

---

## 6. The five alerts

Five variants, one per DATA row, sharing one cancel: 16 keys total (5 × title + body + destructive
verb, plus the shared cancel) (§12.9). **The bodies differ because the consequences differ** —
`Clear Codex` re-locks ECHO and SIEVE at §9.10's page gates and does *not* touch the palette ceiling;
`Reset the ladder` drops the palette to its band-2 opening state and keeps the Codex (§11.12). A
generic "Are you sure?" would erase exactly the distinction the player needs.

```swift
// Every string here is already resolved by Loc, so every one is `verbatim:` (08 §3, §12.9 trap 1).
.alert(Text(verbatim: Loc.resetTitle(variant)), isPresented: $isPresented) {
    Button(role: .destructive) { perform(variant) } label: { Text(verbatim: Loc.resetVerb(variant)) }
    Button(role: .cancel) { } label: { Text(verbatim: Loc.cancel) }   // exactly one .cancel
} message: {
    Text(verbatim: Loc.resetBody(variant))
}
```

Declare exactly one `.cancel` and one `.destructive` and let the system order and emphasise them —
§12.2 makes **cancel** the primary action, and the `.cancel` role is what delivers that. Do not add
`.defaultAction` to the destructive button.

**Every destructive action in the app lives in Settings → DATA** (§11.12), so the reset set can be
enumerated, alerted and tested once. `StatisticsView` is read-only; the Codex has no delete; a page
cannot be discarded.

---

## 7. `StatisticsView`

`List`, read-only, five sections — MODES · ROUNDS · BANDS · CODEX · ANOMALY — 19 labelled rows and
column heads (§11.12, §12.9). Numerals per `numeral-readout.md` site 3.

Two things it must not contain, both decided rather than omitted:

- **No usage-time or usage-calendar statistic** — no session duration, time of day, days-opened
  heatmap or launch count. §11.12: only facts about *play*, never facts about *attendance*.
- **No `θ`, no difficulty, no band framed as a level, no percentile** (§11.12, §10.5).

The four mode names are **wordmarks**, not translation units: `Text(verbatim: mode.wordmark)`.
`Text(mode.rawValue)` is not extracted at all and `Text("PROBE")` is extracted when it must not be
(`08 §3`, §12.9 trap 1).

---

## 8. Dynamic Type and VoiceOver

| Category | Behaviour |
|---|---|
| xSmall … xxxLarge | reference layout |
| accessibility1 | Settings rows go **label-over-value**; pickers go inline (§4) |
| accessibility2 … 5 | rows keep growing; toggles keep their 44 × 44; nothing truncates or shrinks (§13.11) |

`.lineLimit(nil)` and `.fixedSize(horizontal: false, vertical: true)` on every label;
`minimumScaleFactor` is 1.0 everywhere. **If a row cannot fit, the row grows** (§13.11). Every visible
string is budgeted at ≤ 22 characters in English against +40 % for German, Russian and Turkish
(§12.9 trap 2), and every screen is reviewed under the accented + expanded pseudolocale and under
`-AppleTextDirection YES` before it is called finished (§12.9 trap 8).

**VoiceOver: stock controls carry their own contract, and that is the entire reason they are stock.**
Give a `Toggle` a label and the system says "switch button, on". Do not re-label it, do not add
`.isButton`, do not wrap it in an `.accessibilityElement`. §13.12 gate 4 is an Accessibility
Inspector audit that must be clean on every screen; hand-decorating a stock control is the usual way
it stops being.

Section headers carry `.isHeader` and land on the `.headings` rotor, which §13.10 puts on Codex,
Profile, Statistics and Settings.

---

## 9. Wrong

- **Leaving the container defaults.** `systemGroupedBackground` and the system blue tint are the two
  palette violations no grep will find. §1.
- **`.tint(.accentColor)`, `.buttonStyle(.borderedProminent)`, `.foregroundStyle(.blue)`.**
- **`accent.brass` or `accent.cold` anywhere in Settings.** Rationing (§13.1) and register (§13.2).
- **A stock `Toggle` with its default tint,** or a hand-rolled `Button` in place of a `ToggleStyle`.
  §2.
- **A capsule switch.** Nothing in chrome exceeds `Radius.chrome` (§13.3).
- **A bare `1.35` in a picker-style branch, or anywhere else.** `env.isArtScaleClamped` — §4.
- **`Text(Loc.x)` instead of `Text(verbatim: Loc.x)`.** A `Loc` accessor returns an already-resolved
  `String`; the localizing overload treats it as a key and looks it up a second time against
  `Bundle.main`, which fails silently and renders the key (`hunch-accessibility/SKILL.md`).
- **`.textCase(.uppercase)` or `.uppercased()`.** Turkish and Arabic both break. §3.
- **`Divider()` or a hand-drawn `Rule()` inside a `List` row.** Two lines. §3.
- **A fifth screen with a `Form`,** or a `Form` on a play surface.
- **A destructive action outside Settings → DATA.** §11.12.
- **A generic alert body reused across the five variants.** §6.
- **A settings row for anything §12.6 lists as deliberately absent** — difficulty selector,
  notifications, iCloud sync, Codex export, restore purchases, analytics opt-in, a separate High
  Contrast toggle. Each has a stated reason and each would need a new screen, a new permission or a
  new file format.
- **`.searchable`, `.refreshable`, a swipe action, or a context menu.** None exist in this app; each
  adds a gesture §12.8 rules out.
