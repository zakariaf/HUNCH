# T03 — The Frame

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T02 |
| **Delivers** | The Frame · 18 screens (screen 2) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**: this task draws. The Frame's four region bounds, the rack's gutters and side margins and the idle Loom's crossfade period land at L2 as `C.Frame.*` in `HunchCore/Sources/Tokens/C.swift`, referencing L1 only; the ring, the ink and the crossfade duration are `env.palette.*`, `env.weight(_:)` and `Dur.*`. A literal `.opacity(` or a numeric `lineWidth:` outside `Tokens/` fails hygiene check 9, and a bare crossfade duration fails it too. |
| `hunch-chrome-and-meta` | Owns rows C and D of the design-system inventory — the `Key` component and its six states, the `InstrumentBar`'s three slots, and specifically `references/instrument-bar.md` §3, which is the per-screen contents table this screen is a row of, and §3.1, which states the Frame's **at most three accented elements** invariant *with a test hook* and rules the streak ring to `.streak(accented: false)`. It also owns the rule that the bar's height is resolved, never the literal 64. |
| `hunch-shared-marks` | The Anomaly key composes an arc meter (the 24-segment rollover), a second arc meter (the streak ring) and — via the run-notch stack — a tick row. All three have exactly one owning `public static func draw` under `Modules/Sources/HunchUI/Marks/`, and this screen calls them. Drawing a second rollover arc "just for the Frame" is the divergence the skill exists to stop. |

## Objective

At the end of this task `FrameView` exists and is the screen §12.4 describes: an instrument bar whose
leading slot is the Settings key, whose centre is a read-only run-notch stack and whose trailing slot
is the Anomaly key with a 24-segment rollover arc outside an unaccented streak ring; a 128 pt idle
Loom that drifts a glyph and crossfades every 8 s and cannot be touched; a 2 × 2 rack of four
168 × 108 mode keys in the order PROBE · DRIFT / ECHO · SIEVE; and a Codex/Profile shelf of two
168 × 52 keys. Every interactive target sits at `y ≥ 300` except the two bar keys, and the screen
never renders more than three accented elements.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.4 | the four regions and their `y` ranges, the rack's 168 × 108 keys / 12 pt gutters / 13.5 pt side margins, the rack order, the shelf's two 168 × 52 keys, the home-indicator clearance, the y ≥ 300 rule and its two named exceptions |
| `GAME_DESIGN.md` | §12.4 | the idle Loom: a 128 pt throat ring, one glyph drifting through it, crossfading every 8 s from a seed derived from the launch time, **non-interactive by design** |
| `GAME_DESIGN.md` | §12.1 | the screen's name — the Frame, "because a loom's frame is the thing every other part is mounted on" |
| `GAME_DESIGN.md` | §11.7, §11.8 | the 24-segment rollover arc, the `.clockBehind` full static ring with no pulse, and the ruling that the **tally** is the headline numeral and lives on `AnomalyView`, not here |
| `GAME_DESIGN.md` | §12.8 | the three reach tiers; the Loom is named in tier 3 as *deliberately unreachable*; ≥ 8 pt inter-target spacing |
| `GAME_DESIGN.md` | §13.1 | the accent is rationed to at most three elements per screen |
| `GAME_DESIGN.md` | §13.11 | at accessibility2…5 the mode rack reflows 2 × 2 → 1 × 4 and scrolls |
| `GAME_DESIGN.md` | §12.6, §12.7 | Reduce motion and Low Power Mode both stop the Frame's idle glyph drifting |
| `GAME_DESIGN.md` | §10.5, §11.2, §11.11 | no band number, no percentage, no global completion meter, no percentile, no rank — the constraint the run-notch stack has to survive |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2 | `Modules/Sources/MetaFeature/FrameView.swift`; screen geometry is app-layer, so the layout is a value in `MetaFeature` and never in `HunchCore` |

**Do not restate a `y` bound, a rectangle or a gutter in prose here.** §12.4's table is the source;
this task turns it into one `FrameLayout` value and asserts the invariants over it.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `Modules/Tests/MetaFeatureTests/FrameLayoutTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("The Frame's layout and its two invariants — §12.4, §12.8, §13.1", .tags(.unit, .presubmission))
struct FrameLayoutTests {

    private let se = FrameLayout.Device(size: .init(width: 375, height: 667),
                                        safeTop: 20, safeBottom: 20)
    private let proMax = FrameLayout.Device(size: .init(width: 440, height: 956),
                                            safeTop: 62, safeBottom: 34)

    // MARK: - §12.8's reach rule, which is the reason the screen is laid out at all

    @Test("every interactive target sits at y ≥ 300, except the two bar keys",
          arguments: [RenderEnv.standard, .boldText, .highContrast, .ax1])
    func everyTargetIsInsideTheThumbArc(_ env: RenderEnv) {
        let layout = FrameLayout(device: se, in: env)
        for target in layout.interactiveTargets {
            if target.role == .settingsKey || target.role == .anomalyKey {
                #expect(target.rect.minY < layout.thumbArcFloor)   // the two named exceptions
            } else {
                #expect(target.rect.minY >= layout.thumbArcFloor,
                        "\(target.role) starts at \(target.rect.minY), above the thumb arc floor")
            }
        }
    }

    @Test("the idle Loom carries no interactive target at all — §12.8 tier 3")
    func theLoomIsUnreachable() {
        let layout = FrameLayout(device: se, in: .standard)
        #expect(!layout.interactiveTargets.contains { layout.loom.rect.intersects($0.rect) })
    }

    @Test("every target clears 44 × 44 and every pair clears 8 pt of air — §12.8")
    func targetsAndSpacing() {
        let layout = FrameLayout(device: se, in: .standard)
        for target in layout.interactiveTargets {
            #expect(target.rect.width >= 44 && target.rect.height >= 44, "\(target.role) is too small")
        }
        for (a, b) in layout.interactiveTargets.adjacentPairs() {
            #expect(layout.gap(between: a, and: b) >= 8, "\(a.role) and \(b.role) are \(layout.gap(between: a, and: b)) pt apart")
        }
    }

    // MARK: - The rack

    @Test("the rack is 2 × 2 in the order PROBE · DRIFT / ECHO · SIEVE")
    func rackOrder() {
        let layout = FrameLayout(device: se, in: .standard)
        #expect(layout.rack.map(\.mode) == [.probe, .drift, .echo, .sieve])
        #expect(layout.rack[0].rect.minY == layout.rack[1].rect.minY)   // one row
        #expect(layout.rack[2].rect.minY == layout.rack[3].rect.minY)
        #expect(layout.rack[0].rect.maxX <= layout.rack[1].rect.minX)   // leading before trailing
    }

    @Test("every rack key is the mode-rack rectangle, from C.Key and nowhere else")
    func rackKeyRect() {
        let layout = FrameLayout(device: se, in: .standard)
        let expected = C.Key.rect(.modeRack, in: .standard)
        for key in layout.rack { #expect(key.rect.size == expected) }
    }

    @Test("at AX2 and above the rack reflows 2 × 2 → 1 × 4 and scrolls — §13.11")
    func rackReflowsAtAX2() {
        let layout = FrameLayout(device: se, in: .ax2)
        #expect(layout.rackColumns == 1)
        #expect(layout.isRackScrollable)
        #expect(layout.rack.map(\.mode) == [.probe, .drift, .echo, .sieve])   // order is preserved
        for key in layout.rack { #expect(key.rect.size == C.Key.rect(.modeRack, in: .ax2)) }
    }

    @Test("the shelf holds Codex leading and Profile trailing at the shelf rectangle")
    func shelf() {
        let layout = FrameLayout(device: se, in: .standard)
        #expect(layout.shelf.map(\.role) == [.codexKey, .profileKey])
        #expect(layout.shelf[0].rect.minX < layout.shelf[1].rect.minX)
        for key in layout.shelf { #expect(key.rect.size == C.Key.rect(.shelf, in: .standard)) }
    }

    // MARK: - The bar

    @Test("the bar's height is resolved, never the literal 64 — instrument-bar.md §2")
    func barHeightIsResolved() {
        let large = FrameLayout(device: se, in: .standard)
        let ax5 = FrameLayout(device: se, in: .ax5)
        #expect(ax5.bar.rect.height >= large.bar.rect.height)
        #expect(large.rack[0].rect.minY > large.bar.rect.maxY)
        #expect(ax5.rack[0].rect.minY > ax5.bar.rect.maxY)   // regions follow the bar, not a constant
    }

    @Test("on a Pro Max the extra height is absorbed by the Loom, not by the rack or the shelf")
    func proMaxAbsorbsIntoTheLoom() {
        let small = FrameLayout(device: se, in: .standard)
        let large = FrameLayout(device: proMax, in: .standard)
        #expect(large.loom.rect.height > small.loom.rect.height)
        #expect(large.rack[0].rect.size == small.rack[0].rect.size)
        #expect(large.shelf[0].rect.size == small.shelf[0].rect.size)
    }
}
```

And `Modules/Tests/MetaFeatureTests/FrameAccentBudgetTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
@testable import MetaFeature

@Suite("The Frame draws at most three accented elements — §13.1, instrument-bar.md §3.1",
       .tags(.unit, .presubmission))
struct FrameAccentBudgetTests {

    /// Every combination of unlock state × streak-present × clock state, which is the product
    /// §3.1 names. `FrameModel` is a value; no view is instantiated.
    @Test("≤ 3 accents across the whole product",
          arguments: FrameModel.unlockStates, [true, false], AnomalyKeyState.allCases)
    func accentBudget(_ unlocks: ModeUnlockSet, _ hasStreak: Bool, _ anomaly: AnomalyKeyState) {
        let model = FrameModel(unlocked: unlocks, hasStreak: hasStreak, anomaly: anomaly,
                               suspended: [:], runNotches: 4)
        #expect(model.accentedElementCount <= 3,
                "unlocks \(unlocks), streak \(hasStreak), anomaly \(anomaly) → \(model.accentedElementCount)")
    }

    @Test("the worst case is real and is exactly 3: three barred keys after Reset everything")
    func theWorstCaseIsThree() {
        // §11.7's reset immunity means a player can hold a live streak with an empty Codex.
        let model = FrameModel(unlocked: .onlyProbe, hasStreak: true, anomaly: .playable,
                               suspended: [:], runNotches: 0)
        #expect(model.accentedElementCount == 3)
    }

    @Test("the streak ring on the FRAME is never accented — the fourth accent, closed")
    func streakRingIsUnaccented() {
        let model = FrameModel(unlocked: .onlyProbe, hasStreak: true, anomaly: .playable,
                               suspended: [:], runNotches: 0)
        #expect(model.streakRingStyle == .streak(accented: false))
    }

    @Test("the run-notch stack renders no numeral and no accent — §10.5, §13.1")
    func runNotchStackIsMute() {
        let model = FrameModel(unlocked: .all, hasStreak: false, anomaly: .playable,
                               suspended: [:], runNotches: 7)
        #expect(model.runNotchStack.rendersNumeral == false)
        #expect(model.runNotchStack.isAccented == false)
    }
}
```

And `Modules/Tests/MetaFeatureTests/FrameWithheldTests.swift`:

```swift
import Testing
import HunchCore
import ModulesTestSupport
@testable import HunchAppFeature
@testable import MetaFeature

@Suite("The Frame is withheld until round 1 ends — §12.4, §12.5 beat 0", .tags(.unit, .presubmission))
struct FrameWithheldTests {

    @Test("a fresh install never resolves to the Frame")
    @MainActor
    func freshInstallOpensOnTheMachine() async throws {
        let dependencies = AppDependencies.preview()          // InMemoryPersistenceStore, empty
        let route = try await AppLaunchRoute.resolve(using: dependencies)
        #expect(route != .frame)
        #expect(route == .openingRound)
    }

    @Test("once round 1 has settled, the Frame is the launch destination")
    @MainActor
    func afterRoundOneTheFrameAppears() async throws {
        let dependencies = AppDependencies.preview()
        try await dependencies.ladder.recordSettledOpeningRound()   // E10·T07's ledger write
        let route = try await AppLaunchRoute.resolve(using: dependencies)
        #expect(route == .frame)
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path Modules --filter "FrameLayoutTests|FrameAccentBudgetTests|FrameWithheldTests"`

Failures must be missing symbols — `FrameLayout`, `FrameModel`, `C.Frame`, `AnomalyKeyState` — or a
wrong coordinate. A green `everyTargetIsInsideTheThumbArc` before `FrameLayout` exists means
`interactiveTargets` is returning an empty array; assert non-emptiness first if that is in doubt.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/MetaFeature/FrameView.swift` |
| create | `Modules/Sources/MetaFeature/FrameLayout.swift` |
| create | `Modules/Sources/MetaFeature/FrameModel.swift` |
| create | `Modules/Sources/MetaFeature/IdleLoom.swift` |
| create | `Modules/Sources/MetaFeature/AnomalyKey.swift` |
| create | `Modules/Sources/MetaFeature/RunNotchStack.swift` |
| modify | `HunchCore/Sources/Tokens/C.swift` — add the `C.Frame` namespace |
| modify | `Modules/Sources/HunchAppFeature/AppView.swift` — present `FrameView` for the `.frame` surface |
| modify | `Modules/Package.swift` — add `MetaFeatureTests` if E16 did not |
| create | `Modules/Tests/MetaFeatureTests/FrameLayoutTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/FrameAccentBudgetTests.swift` |
| create | `Modules/Tests/MetaFeatureTests/FrameWithheldTests.swift` |
| modify | `tests.json` — four entries: y ≥ 300, ≤ 3 accents, the rack reflow, and Frame-withheld |
| modify | `DECISIONS.md` — the run-notch stack ruling |

## Implementation notes

### Split the screen into a layout value, a model value, and a thin view

The two invariants that matter — reach and accent budget — are properties of *numbers* and *counts*,
not of pixels. Putting them behind a snapshot test would cost a simulator and prove less. So:

- **`FrameLayout`** — a `Sendable` value computed from `(device, RenderEnv)`, exposing `bar`,
  `loom`, `rack`, `shelf`, `interactiveTargets`, `thumbArcFloor`, `rackColumns`, `isRackScrollable`.
  Pure geometry; no SwiftUI types beyond `CGRect`/`CGSize`.
- **`FrameModel`** — a `Sendable` value computed from `(ModeUnlockSet, suspended rounds, anomaly
  state, streak, run length)`, exposing `accentedElementCount`, `streakRingStyle`, `runNotchStack`
  and the per-key `KeyState`. This is what `FrameAccentBudgetTests` walks.
- **`FrameView`** — reads the environment, builds both values, and renders. It contains no
  arithmetic.

`08 §2`'s boundary rule keeps both in `Modules/`: screen geometry in `HunchCore` would make
`swift test` depend on a device idiom.

### The bar's height is resolved, and every region hangs off it

`hunch-chrome-and-meta/references/instrument-bar.md` §2 is unambiguous: `y 20–64` is the bar *at
Dynamic Type Large with no wrapped title*, not a constant. The Frame's bar carries no title (a
Settings key, a notch stack and the Anomaly key), so it is a 44 pt bar in practice — but lay the
Loom, the rack and the shelf out relative to `bar.rect.maxY` anyway. `.padding(.top, 64)` is the
single most likely defect in this component and `barHeightIsResolved` is the test that catches it.

On a Pro Max the bar starts lower because the safe area does; `proMaxAbsorbsIntoTheLoom` fixes where
the surplus goes — the Loom region absorbs it, so reach does not degrade with device size (§12.8's
closing paragraph).

### `C.Frame` — what is a token here and what is not

`hunch-chrome-and-meta/SKILL.md`'s rule: this skill owns geometry, state and behaviour, and **no
values**. A coordinate, a ratio or a count is *not a value in the token sense*. So:

| Fact | Where it goes |
|---|---|
| region bounds, gutters, side margins, home-indicator clearance | `C.Frame.*` as L2 geometry, each with its §12.4 citation |
| the rack key rectangle 168 × 108, the shelf key rectangle 168 × 52, the utility key 44 × 44 | **`C.Key.rect(_:in:)`** — `key.md` §1 is the single accessor and there is no seventh size |
| the idle Loom's 128 pt ring diameter | `C.Frame.loomRingDiameter` |
| the 8 s crossfade period, and the crossfade's own duration | `Dur.*` in `hunch-design-tokens/references/durations-and-easing.md`. If the 8 s period has no token, add one there — not here |
| every colour, ink, weight, opacity | `env.palette.*`, `env.weight(_:)`, `Opacity.*` |

### The idle Loom — scenery, and the three ways it must prove it

```swift
// Modules/Sources/MetaFeature/IdleLoom.swift
@MainActor
struct IdleLoom: View {
    let seed: UInt64          // "derived from the launch time" — passed in, never read here
    let isDrifting: Bool      // false under Reduce Motion or Low Power (§12.6, §12.7)
    let env: RenderEnv

    var body: some View {
        Canvas { context, size in … }
            .allowsHitTesting(false)          // 1. no touch reaches it
            .accessibilityHidden(true)        // 2. no rotor lands on it
            // 3. it declares no target, so FrameLayout.interactiveTargets never contains it
    }
}
```

All three, because each closes a different hole: `allowsHitTesting(false)` stops a stray thumb,
`accessibilityHidden(true)` stops VoiceOver offering a control that does nothing, and its absence
from `interactiveTargets` is what `theLoomIsUnreachable` actually asserts. §12.8 tier 3 names the
Loom explicitly as *"deliberately unreachable"* — this is a designed property, not an omission.

**The seed is derived from the launch time and is passed in.** `Date()` is banned from `HunchCore`
and the seed source is the composition root's (`08 §4`, `§6`), so `FrameView` takes the seed from
`AppDependencies.seeds` and the glyph sequence is `SplitMix64(seed:)` threaded down one synchronous
call tree. Never `Int.random`, never a `Timer` that reseeds itself.

**The drift stops under Reduce Motion and under Low Power Mode.** Both are stated (§12.6's *Reduce
motion* row; §12.7's *Low Power Mode on* row) and both reach the view through `RenderEnv`
(`env.isReduceMotionEnabled`, `env.isLowPowerModeEnabled`). Stopped means *the glyph holds*, not
*the Loom disappears* — the crossfade becomes a static composition, per §13.7.4's doctrine that a
substitution never deletes the information the motion carried.

### The Anomaly key

Three drawings composed, none of them invented here:

1. the **24-segment rollover arc** — `ArcMeter.draw` in its segmented variant
   (`hunch-shared-marks/references/arc-meter.md`), showing how far into the UTC day the player is
   (§11.7);
2. the **streak ring** inside it — `ArcMeter.draw` in its `.streak` variant, and on this screen
   **always** `.streak(accented: false)` (`instrument-bar.md` §3.1);
3. the `.clockBehind` state — a **full static ring with no pulse** (§11.7, §11.8), which is a
   `barred` key in `KeyState` terms and *not* `disabled` (`key.md` §3's last paragraph).

**No numeral.** §12.4 says so in the region table itself: *"no numeral — the tally lives on
`AnomalyView`"*. `numeral-readout.md` holds the resolved site table and the Frame is not one of its
sites.

Model the three as `enum AnomalyKeyState { case playable, settled, clockBehind }` so the switch is
exhaustive and the `.clockBehind` lock cannot be spelled as a `Bool` beside `isPlayable`.

### The run-notch stack — §12.4 names it and defines it nowhere

`grep -rn "run-notch" GAME_DESIGN.md` returns exactly one line, and no other section defines the
term. That is a spec gap and this task closes it with a written ruling, not with an invention.

**Constraints it has to satisfy**, all of them already law:

- the centre slot is **read-only** (`instrument-bar.md` §4(b));
- **no numeral** anywhere on this screen (§12.4, `numeral-readout.md`);
- **no band number, no percentage, no completion meter, no percentile, no rank** (§10.5, §11.2,
  §11.11 P1–P8);
- **no attendance metric of any kind** — §11.12 rules out session duration, days-opened and launch
  count, and a "notch per day you opened the app" would be exactly that;
- it may spend **no accent** (§13.1's budget is already at three).

**Ruling.** The run-notch stack is a `TickRow.draw` at `stroke.secondary` showing **one notch per
round in the current unbroken run of clean declarations** — correct on the first declaration, zero
strikes, in any mode — capped at the slot width and drawn empty at zero. It is the same quantity
`ProfileView` already surfaces in words as *"longest run"* (§12.9), so it introduces no new fact
about the player; it is monotone within a run and resets to empty on a strike or a loss, so it is a
fact about *play* and not about attendance; and it reuses the tick row rather than inventing a mark.
Record this in `DECISIONS.md` under "spec gaps closed", with the four constraints above as the
reasoning, so the next reader does not re-litigate it.

### The accent budget, and why it is a test

`instrument-bar.md` §3.1 does the arithmetic: at first launch DRIFT, ECHO and SIEVE are each barred
and each carries an `accent.cold` machined bar — that is three, the whole ration. The fourth is
reachable: "Reset everything" deletes every file *except* `anomaly.json` (§11.7's reset immunity, and
the whole anti-cheat), so a player can hold a live streak over an empty Codex, and a chrome-first
implementation would paint the streak ring `accent.brass` and put four accents on the screen. The
ruling is unconditional — `.streak(accented: false)` on the Frame, `accented: true` on `AnomalyView`
and the Inscription — because *a conditional accent is a fourth accent waiting for the state that
enables it*.

`FrameAccentBudgetTests` walks the Cartesian product of unlock state × streak × anomaly state and
asserts `≤ 3`. It is a value assertion over `FrameModel`, not a snapshot, so it costs microseconds.

### AX2 and the 1 × 4 reflow

§13.11 reflows the rack to a scrolling `1 × 4` at accessibility2 and above. `key.md` §9 is explicit
that this is **layout, not scale** — the key rectangles are unchanged and `env.artScale` never
reaches a key. `rackReflowsAtAX2` asserts both halves: one column, and the same rectangle.

The reflow threshold is a Dynamic Type category, not the art ceiling, so it is *not*
`env.isArtScaleClamped` (which is reached at AX1 — `stock-controls.md` §4's warning about naming a
predicate after the wrong category). Read `@Environment(\.dynamicTypeSize)` and compare against
`.accessibility2`.

### VoiceOver

Eight elements, which is exactly §12.9's budget for the Frame ("VoiceOver: control labels … Frame 8"):
Settings key, Anomaly key, four rack keys, Codex key, Profile key. The run-notch stack and the idle
Loom are `.accessibilityHidden(true)` — the Loom because it is scenery, the notch stack because it is
an indicator whose fact is already in the Anomaly key's value and the Profile's stat block, and
adding a ninth label would break the budget §12.9 asserts.

The bar itself is `.accessibilityElement(children: .contain)`, so reading order mirrors under RTL
with no `sortPriority` (`instrument-bar.md` §6). Wording, traits and the barred key's silence are
**T04**'s and **E19·T01**'s; this task ships the elements, not the sentences.

### Reduce Transparency, High Contrast, Bold Text, RTL

- **Reduce Transparency** — the bar has no material to lose; it is opaque `ground.base` at every
  setting (`instrument-bar.md` §7). The Loom's bloom, if any, is off (`env.isBloomEnabled`).
- **High Contrast** — no substitution of the bar's own; the bottom rule picks up the flat weight
  offset through `env.weight(.hairline)`.
- **Bold Text** — reaches the screen only through `env.weight(_:)` and `env.type(_:)`. Nothing here
  branches on it.
- **RTL** — the instrument bar's key order mirrors; the rack's 2 × 2 *layout* mirrors, so PROBE sits
  top-trailing in Arabic, and the **sigils do not** (`sigil-grammar.md` §7, `mode-sigils.md`). The
  rollover arc does **not** mirror: an arc meter encodes a clock and mirroring it would say the day
  runs backwards (`hunch-shared-marks/SKILL.md`).

### The Frame is withheld — this task asserts it, E10 implements it

§12.4's third decision and §12.5 beat 0 both say first launch never shows the Frame. The mechanism is
`AppLaunchRoute` (E10·T01) reading `OnboardingLedger` (E10·T07). `FrameWithheldTests` is a
**regression assertion** placed here because this is the epic where `FrameView` first becomes
presentable and therefore the first moment the rule could be broken by accident. If the test fails,
the fix is in E10's files, not this one.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter "FrameLayoutTests|FrameAccentBudgetTests|FrameWithheldTests"` green.
- [ ] `grep -rnE "\.opacity\(|lineWidth: *[0-9]|cornerRadius: *[0-9]|#[0-9A-Fa-f]{6}" Modules/Sources/MetaFeature/Frame*.swift Modules/Sources/MetaFeature/IdleLoom.swift Modules/Sources/MetaFeature/AnomalyKey.swift` returns nothing, and `Scripts/check-source-hygiene.sh` check 9 passes.
- [ ] `grep -rn "\.padding(\.top, 64)\|frame(height: 64)\|offset(y: 64)" Modules/Sources/MetaFeature/` returns nothing.
- [ ] `grep -rn "Text(" Modules/Sources/MetaFeature/FrameView.swift` returns nothing outside `.accessibility*` — the Frame is textless.
- [ ] `grep -rn "struct ArcMeter\|struct TickRow\|func drawRolloverArc" Modules/Sources/MetaFeature/` returns nothing: the marks are called, never redrawn (`hunch-shared-marks`' second-declaration grep is clean).
- [ ] `grep -rn "accent" Modules/Sources/MetaFeature/AnomalyKey.swift` shows `.streak(accented: false)` and no conditional.
- [ ] Simulator walk recorded in the commit message: SE and Pro Max, Large and AX3, dark and High Contrast — the rack reflows at AX2, the Loom crossfades and stops under Reduce Motion, and the Anomaly key draws its full static ring with the clock set back.
- [ ] `DECISIONS.md` carries the run-notch stack ruling with its four constraints.
- [ ] `tests.json` carries the four entries.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T03: FrameView — bar, idle Loom, 2x2 mode rack, shelf; y>=300 and <=3 accents asserted"`

## Out of scope

- The four mode sigils, the three key states and the §9.10 gates that decide which key is barred — **T04**. T03 renders `KeyState` values it is handed.
- `LaunchSurface` and `AboutView` — **T05**.
- `SettingsView`, which the Settings key leads to — **T06**–**T08**.
- `AnomalyView`, which the Anomaly key leads to, including the 28-cell ribbon and the tally numeral — **E16·T04**.
- The 280 ms Home → mode transition — **E20·T08**.
- The Frame's withholding *mechanism* and beat 13's key lighting — **E10·T06**.
- Every VoiceOver label's wording — **E19·T01**.
