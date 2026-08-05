# instrument-bar.md — the top band of every screen

Owning symbol: `HunchUI/Chrome/InstrumentBar.swift` → `struct InstrumentBar<Leading, Centre, Trailing>: View`.
Inventory row: `DESIGN-SYSTEM-SCOPE.md` §3 row C, *Instrument bar*.

Contents: [1 The three slots](#1-the-three-slots) · [2 Height is resolved, not constant](#2-height-is-resolved-not-constant) ·
[3 Per-screen contents](#3-per-screen-contents) · [3.1 The Frame's three-accent invariant](#31-the-frame-draws-at-most-three-accented-elements-and-the-streak-ring-is-not-one-of-them) ·
[4 Two rulings](#4-two-rulings) ·
[5 Implementation](#5-implementation) · [6 VoiceOver](#6-voiceover) · [7 Environment behaviour](#7-environment-behaviour) ·
[8 Wrong](#8-wrong)

---

## 1. The three slots

Every screen in §12.2 except the launch surface, the alert and the SIEVE pause overlay carries one
instrument bar at the top of the safe area. It has exactly three slots and they never move:

```
┌──────────────────────────────────────────────────────────────────┐
│ [ leading 44 ] [        centre — the remainder        ] [ 44 ] │  height = resolved, ≥ 44
└──────────────────────────────────────────────────────────────────┘
   a key, or nothing    an indicator, never scrollable    the play key
```

- **Leading** — one 44 pt key, or empty. The chevron on PROBE/DRIFT/ECHO (§12.7), `back` on a pushed
  screen, the Settings key on the Frame, a family or mode sigil where the screen has no exit key.
- **Centre** — an *indicator*: a tick row, an arc, a stamp row, a screen title. Read-only on every
  screen but one (§4). It never scrolls and never clips; it wraps or the bar grows.
- **Trailing** — the **play key** on screens 9–15, the Anomaly key on the Frame, nothing on 3–8 and
  16–18. §12.3: *"Every non-play screen carries a play key — a 44 × 44 throat sigil in the trailing
  corner of its instrument bar"*, and that is what makes the ≤ 2-tap rule hold.

The centre slot is `screenWidth − 88`: 287 pt on the SE, 352 pt on a Pro Max. §6.2's `rowWidth` of
288 / 348 is the **par tick row's own budget** for its pitch arithmetic, not the slot — the row
centres inside the slot, and at PROBE's longest par (29 ticks at 9 pt) it is 261 pt wide and nowhere
near either bound. The one pt of SE overhang at DRIFT band 8 is absorbed the same way §13.3 absorbs
the Dial's rounding into its header.

---

## 2. Height is resolved, not constant

§4.1, §6.2, §9.2, §11.2 and §12.4 all write `y 20–64`. That is the bar **at Dynamic Type Large with
no wrapped title**, on the 375 × 667 reference device — not a constant.

| Screen class | Bar height | Why |
|---|---|---|
| play surfaces (3, 4, 5, 6, 7, 8) | exactly 44, always | zero text by construction (§12.9), so nothing can wrap |
| titled screens (9, 12, 13, 14) | `max(44, titleHeight + 2 · Space.s4)` | §13.4 forbids `minimumScaleFactor`; a German title at AX5 wraps and the bar grows |
| stock screens (15, 16) | the system navigation bar | §5 below |

**Lay every region below the bar out relative to the resolved height.** Writing `.padding(.top, 64)`
or `.offset(y: 64)` is the bug this section exists to prevent: it survives every snapshot at Large
and fails at AX3 in German, which is exactly the case §13.11's snapshot matrix tests.

On a Pro Max the bar is at `y 62–106` (§6.2) because the safe area starts lower; the height rule is
identical. Never hardcode either origin — read the safe area.

---

## 3. Per-screen contents

| Screen | Leading | Centre | Trailing |
|---|---|---|---|
| `RoundView` (PROBE/DRIFT) | chevron — suspends, one tap, no confirmation (§12.7) | par tick row + mode sigil | — |
| `EchoRoundView` | chevron | mode sigil | — |
| `SieveRoundView` | **nothing** — §12.7 is explicit | three foul ticks · stream progress arc · mode sigil. **No lawful count**: it would leak the law's admit rate `p` (§9.2) | — |
| `BenchView`, `AssayInspectorView` | — | — | — (both are covered surfaces; see `scrim.md`) |
| `InscriptionView` | — | — | *again* / Frame / minted-page keys sit in the commit bar, not here |
| `FrameView` | Settings key | run-notch stack | Anomaly key — 24-segment rollover arc outside a **`.streak(accented: false)`** ring, **no numeral** (§12.4). See the invariant below |
| `CodexRootView` | Codex sigil | active facet stamps | play key |
| `CodexShelfView` | family sigil | fill arc + facet state | play key |
| `CodexPageView` | back | — (a page is titled by its law, §12.9) | play key |
| `AnomalyView` | back | title | play key |
| `StatisticsView` | back | title | play key |
| `ProfileView` | back | title | **statistics key, then play key** — §4 |
| `SettingsView`, `AboutView` | the system navigation bar | | |

Every sigil named above is `hunch-sigil-drawing`'s; the tick row and the arc are
`hunch-shared-marks`'. This file owns the slots and nothing that goes in them.

### 3.1 The Frame draws at most three accented elements, and the streak ring is not one of them

**Invariant, asserted rather than assumed: `FrameView` renders at most three accented elements, for
every combination of unlock state and streak.** §13.1 rations the accent to three per screen, and on
the Frame the budget is already spoken for: at first launch DRIFT, ECHO and SIEVE are each barred and
each carries an `accent.cold` machined bar. Three.

The fourth is reachable and `hunch-shared-marks/references/arc-meter.md` §4 works out how: "Reset
everything" deletes every file *except* `anomaly.json`, which §11.7's reset-immunity rule keeps
byte-identical because wiping the ledger is the clock exploit. A player who resets therefore holds a
live streak, an empty Codex and three barred keys — and `.streak`'s default fill ink is
`accent.brass`, so a chrome-first implementation puts four accents on the Frame.

**The ruling is arc-meter.md §4's and it lands here: the Frame's Anomaly key takes
`.streak(accented: false)`; `accented: true` belongs to `AnomalyView` and to the Inscription.** No
conditional and no state to get wrong — a conditional accent is a fourth accent waiting for the state
that enables it. It also agrees with §12.4, which already makes the Frame's key a locator rather than
a celebration ("no numeral — the tally lives on `AnomalyView`").

**Test hook, this skill's to write:** count the accented elements `FrameView` renders across the
Cartesian product of unlock state × streak-present and assert `≤ 3`. It is a value assertion over the
view's own model, not a snapshot, so it runs in `Modules/Tests/HunchUITests` inside the fast budget —
`hunch-swift-testing` owns where it lives, this file owns the claim.

---

## 4. Two rulings

**(a) The trailing slot may stack two keys, and the play key is always the outermost.** §12.2 gives
`ProfileView` three exits — back, statistics, play — which is one more than three slots allow. The
resolution is not a fourth slot: it is that the play key's *position* is the thing that must never
move, because §12.3's ≤ 2-tap guarantee is only worth anything if the player's thumb finds it without
looking. A second key docks **inboard** of it with `Space.s4` between (≥ 8 pt after the two 44 pt hit
rects are laid out, satisfying §12.8). Profile is the only screen that uses this, and a third would
mean the screen has too many destinations.

**(b) The centre slot is read-only everywhere.** It is an indicator: it shows probe count, foul
count, stream progress, active facets, or the screen's name. The one apparent exception,
`CodexRootView`'s facet stamps, is not one — those are five 44 pt **keys** (`key.md` site 5) that
happen to be laid out in the centre, and §11.2 places them in a bar of their own at `y 624–667`, not
in the instrument bar. The instrument bar shows *which* facets are active; the facet bar changes
them.

---

## 5. Implementation

```swift
// Modules/Sources/HunchUI/Chrome/InstrumentBar.swift
struct InstrumentBar<Leading: View, Centre: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let centre: () -> Centre
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.renderEnv) private var env

    var body: some View {
        HStack(spacing: 0) {
            leading().frame(width: Space.s44, alignment: .leading)
            centre().frame(maxWidth: .infinity)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate (§13.4)
            trailing()                                          // may contain two keys — §4(a)
        }
        .frame(minHeight: Space.s44)                            // grows; never a fixed height
        .padding(.horizontal, 0)                                // the 44 pt slots ARE the margin
        .accessibilityElement(children: .contain)
    }
}
```

Three things that look like details and are not:

- `.frame(minHeight:)`, never `.frame(height:)`. A fixed height is §2's bug in one line.
- **No `.frame(alignment:)` on the trailing slot.** Every parameter of `frame(width:height:alignment:)`
  is defaulted, so `.frame(alignment: .trailing)` compiles, does nothing, and reads as if it were
  doing the alignment the `HStack` is actually doing. The centre slot's `maxWidth: .infinity` is what
  pins the trailing content to the trailing edge.
- `.padding(.horizontal, 0)` with the slots supplying the margin. `space.marginOuter` is 16 and the
  24 pt sigil centred in a 44 pt slot sits 10 pt from the screen edge — close enough to the 16 pt
  margin to read as aligned, far enough that the hit rect reaches the edge, which is what makes a
  corner key reachable one-handed. Adding a 16 pt outer padding *and* the slots pushes both keys
  inward and breaks the ≤ 2-tap ergonomics the trailing key exists for.

On the two stock screens the bar is the system navigation bar and the play key is a
`ToolbarItem(placement: .topBarTrailing)`. Do not draw a second bar underneath one — see
`stock-controls.md` §4.

---

## 6. VoiceOver

The bar is a container (`.accessibilityElement(children: .contain)`), not an element. Reading order
follows layout, so it mirrors correctly under RTL with no `sortPriority` (§12.8: mirror the chrome,
never the glyph).

- The centre title takes `.accessibilityAddTraits(.isHeader)` — this is what puts Codex, Profile,
  Statistics and Settings on the `.headings` rotor (§13.10).
- Every screen posts `.screenChanged` with its name on appear, in §13.10's fixed announcement order.
- The chevron's label describes the *effect*, not the shape: it suspends and returns, and nothing is
  lost. A label of "Back" would be a lie on a round surface.
- The par tick row is `.staticText, .updatesFrequently` with the value
  `"12 of 23 expected, 37 maximum"` (§13.10). Numbers are spoken even though they are never drawn —
  the no-text rule constrains rendered pixels only.

---

## 7. Environment behaviour

| Setting | Effect on the bar |
|---|---|
| **Reduce Motion** | nothing in the bar animates except the Frame's Anomaly arc, which is static anyway; screen changes take `Dur.crossfade` in place of the `Dur.push` push (§13.7.4) |
| **High Contrast** | the bar's bottom rule picks up the flat weight offset via `env.weight(.hairline)`; no substitution of its own |
| **Bold Text** | the title steps one type weight; slot geometry is unchanged |
| **Dynamic Type** | titled bars grow (§2). Play-surface bars do not, because they have no text |
| **Reduce Transparency** | the bar has no material to lose. It is opaque `ground.base` at every setting — §13.1 forbids a material as a primary surface |
| **RTL** | key order mirrors, the chevron glyph mirrors, the centre indicator's *reading* order mirrors; the tick row still renders leading-to-trailing in source order (§12.8) |
| **Left-hand keys** (§12.6) | **no effect.** That setting mirrors only the commit bar order and the Bench handle side. The instrument bar never mirrors for handedness |

---

## 8. Wrong

- **A fixed `y = 64` or `.frame(height: 64)`.** §2. This is the single most likely defect in the
  whole component.
- **A fourth slot,** or a floating element over the bar. §11.5 requires `CodexPageView` to be
  screenshot-clean — full-bleed, no floating chrome, no transient overlay — and the same composition
  discipline holds everywhere.
- **A play key anywhere but the outermost trailing position,** or a play key on `AboutView`, the
  reset alert or the SIEVE pause overlay (§12.3 excludes screens 16, 17, 18).
- **A chevron in SIEVE's bar.** §12.7 is explicit: SIEVE's only exit is from `paused`, via the commit
  bar, on a second confirming tap. A stray thumb near the chrome must not be able to end a timed run.
- **A lawful-glyph count in SIEVE's bar.** It leaks the law's admit rate `p` (§9.2).
- **A numeral on the Frame's Anomaly key.** The tally lives on `AnomalyView` (§12.4); the key carries
  the arc and the ring only.
- **`.streak(accented: true)` on the Frame,** or any conditional that decides accent from state. §3.1:
  after "Reset everything" that is the fourth accent on a screen §13.1 limits to three.
- **`.truncationMode`, `.minimumScaleFactor` or a fixed `lineLimit(1)` on the title.** §13.4: text
  wraps, containers grow, no exceptions.
- **`NavigationTitle` + a hand-drawn bar on the same screen.** Pick one per screen: stock screens use
  the navigation bar, custom screens use this component.
