# E17 — The Frame, navigation and Settings

| | |
|---|---|
| **id** | E17 |
| **title** | The Frame, navigation and Settings |
| **branch** | `epic/E17-frame-settings` |
| **depends on** | E16 (which itself carries E01–E15) |
| **gate** | `NavigationDepthTests` walks the route graph and asserts `distanceToPlay(screen) ≤ 2` for all 18 screens · each of the five reset alerts acts on exactly its DATA row's file set with the Anomaly ledger untouched · mode keys bar and unbar strictly on §9.10's archive evidence · the Frame is withheld until round 1 ends on a fresh install |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH has a **shell**. `FrameView` is the screen the machine is mounted on:
an instrument bar with the Settings key leading and the Anomaly key trailing, a non-interactive idle
Loom above the thumb arc, a 2 × 2 rack of four mode keys that bar and unbar on nothing but what is in
the Codex, and a Codex/Profile shelf — with every interactive target at `y ≥ 300`. Navigation stops
being implicit: `Route`, `Screen` and `NavigationGraph` are values in a target that does not import
SwiftUI, so a graph walk proves the ≤ 2-tap rule on the host and fails CI the day an eighteenth
screen becomes a nineteenth without a play key. The eighteen screens of §12.2 are all present —
`LaunchSurface` and `AboutView` land here and close the inventory. And every preference and every
destructive action arrives in exactly one place: seven sections, nineteen rows, thirteen keys under
`hunch.settings.` and not one byte of game state, plus five reset alerts whose bodies differ because
their consequences do and none of which can reach `anomaly.json`.

The last piece is leaving. §12.7's full `scenePhase` table becomes a pure value covering both column
groups, the leading chevron suspends silently in PROBE, DRIFT and ECHO, SIEVE keeps no chevron while
it streams, and returning to `.active` spins the surface back up over 600 ms.

## Why now

E15 and E16 filled the archive; this epic is what lets a player *reach* it. It sits here for four
reasons:

- **Every screen it frames already exists.** The route graph is only worth building once all
  eighteen nodes are real — `SievePauseOverlay` arrives with E14, the three Codex screens with E15,
  `AnomalyView`, `ProfileView` and `StatisticsView` with E16. Building the graph earlier would mean
  encoding edges to screens nobody could open, and the depth test would assert nothing.
- **The mode gates are archive evidence, and the archive is E15's.** §9.10 unlocks DRIFT on a
  band-≥ 3 page, ECHO at ≥ 5 pages and SIEVE at ≥ 8. Those are questions asked of `codex-index.json`,
  so the gate cannot be written — or tested against a real index — before the Codex ships.
- **The reset map has five consumers, and the last of them is E16's.** §11.13's map covers
  `stats.json`, the eight shelves, `profile.json` and `ladder.json`. E07·T06 proved the file sets;
  this epic wires them to alerts and to the two *downstream* consequences the file sets alone do not
  state — Clear Codex re-locks two mode keys, Reset the ladder drops the palette ceiling.
- **E18 needs a complete screen inventory to localize.** §12.9 budgets 94 visible strings across
  Settings (37), the five reset alerts (16), `AboutView` (6), `StatisticsView` (24), `ProfileView`
  (5) and six screen titles. Thirty-seven of those strings do not exist until T06–T08 write them, so
  the ≤ 250-key catalog cannot be closed until this epic is merged.

## Scope

| In | Out — and who owns it |
|---|---|
| `Route`, `Screen`, `NavigationGraph` in `HunchNavigation`; one `Router` per `NavigationStack`; `@SceneStorage` restoring an encoded `[Route]` | `AppDependencies`, `hunchEnvironment(_:)`, the `@Entry` values and `AppLaunchRoute` — **E10·T01**. Routers are deliberately *not* in the dependency graph (`04 A33`) |
| `NavigationDepthTests` and the play-key inventory assertion | The 44 pt throat sigil drawing the play key carries — `hunch-bench-instruments`' throat, shipped **E08·T03** |
| `FrameView` — instrument bar, idle Loom, mode rack, shelf, the y ≥ 300 invariant, the ≤ 3-accent invariant | The *withholding* of the Frame on first launch and its key lighting at beat 13 — **E10·T06**. T03 ships the regression assertion, not the mechanism |
| Mode key states (barred / idle / suspended-with-arc), the trailing-swipe discard, `ModeUnlock` as a pure function of archive evidence | The `Sigil` catalogue, `SigilCatalogue.strokes(for:)` and `SigilRenderer` — **E15·T09**; the `Key` component and `KeyState` — **E04/E15** via `hunch-chrome-and-meta`; the machined bar and arc meter drawings — **E04·T07/T08** |
| `LaunchSurface`, `AboutView`, the closed-inventory test and the deliberate-absence lint | The other sixteen screens, each in its own epic — **E08, E09, E13, E14, E15, E16** |
| Settings: all 7 sections, 19 rows, the 13 `hunch.settings.` keys, `DrawnToggleStyle`, the segmented→inline picker rule | The *effects* of every preference. Grain → **E20·T07**; Haptics/Sound/Level → **E20·T04/T06**; Steady stream → **E14·T09**; VoiceOver Detail/Announce → **E19·T02/T05**; the language **override mechanism** (`Loc`, `AppleLanguages`, `layoutDirection`) → **E18·T05**. This epic ships the control and the key; the consumer reads it |
| Five DATA rows, five alert variants, the two downstream consequences, the "no reset touches the Anomaly" assertion at the UI layer | `ResetAction` and the on-disk file-set assertions — **E07·T06**; `AnomalyLedger` reset immunity — **E16·T02** |
| §12.7's full `scenePhase` table as a pure value; the chevron policy for all four modes; the 600 ms `.active` spin-up | SIEVE's freeze-at-glyph-boundary, the 70 % scrim and the 3-glyph run-up — **E14·T07**; the two-tap abandon's *scoring* as a foul-out — **E14·T08**; the 900 ms cold-launch re-entry beat — **E10·T03** |
| The English copy for the 37 Settings strings, 16 alert strings and 6 About strings, written into `Localizable.xcstrings` | The eleven other languages, the completeness test, the banned-lexeme test and the pseudolocale gate — **E18·T02/T03/T08/T09** |
| VoiceOver labels/traits/values for every control this epic adds | The full element map across all 18 screens, the four rotors, Magic Tap and the audit — **E19·T01/T05/T11** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [`HunchNavigation`](T01-hunch-navigation.md) | P0 | M | — | `Route`, `Screen` and `NavigationGraph` in a target with no SwiftUI import; `@MainActor @Observable Router` per stack, owned by the stack's container and absent from `AppDependencies`; `@SceneStorage` holding encoded `[Route]` |
| T02 | [`NavigationDepthTests`](T02-navigation-depth-tests.md) | P0 | S | T01 | A BFS over the route graph asserting `distanceToPlay(screen) ≤ 2` for every reachable screen and every last-played mode, plus the inventory guard that fails when a screen is added without a play key |
| T03 | [The Frame](T03-the-frame.md) | P0 | M | T02 | `FrameView` — instrument bar, run-notch stack, Anomaly key with its rollover arc and unaccented streak ring, the idle Loom at 72–288 crossfading every 8 s and non-interactive, the 2 × 2 rack of 168 × 108 keys, the Codex/Profile shelf, every target at y ≥ 300 |
| T04 | [Mode sigils, key states and gates](T04-mode-sigils-key-states-and-gates.md) | P0 | M | T03 | The four mode sigils on the rack key in three states — barred with the Seal's identical machined bar, idle, suspended with a border arc at `probesUsed / par` — `ModeUnlock` as a pure function of §9.10's archive evidence, and a trailing swipe that discards |
| T05 | [The screen inventory completed](T05-screen-inventory-completed.md) | P0 | M | T03 | `LaunchSurface` as a storyboard covering the cold-start hitch, `AboutView`, the closed-inventory test over all 18 screens, and the lint that keeps the eleven deliberately-absent screen kinds absent |
| T06 | [Settings — DISPLAY and FEEDBACK](T06-settings-display-and-feedback.md) | P0 | M | T05 | `SettingsView`'s container neutralised, `DrawnToggleStyle`, Theme as four-way with the `isDarkerSystemColorsEnabled` forcing rule, Grain, Reduce motion, Left-hand keys mirroring only two things; Haptics, Sound, Level as two states |
| T07 | [Settings — PLAY, VOICEOVER and LANGUAGE](T07-settings-play-voiceover-and-language.md) | P1 | M | T06 | Confirm the Seal, Steady stream; Detail Full/Terse, Announce verdicts on, Announce the Assay off; the 13-option language picker defaulting to System; all 13 keys under `hunch.settings.` and game state never |
| T08 | [Settings — DATA and the reset alerts](T08-settings-data-and-reset-alerts.md) | P0 | M | T07 | Five destructive rows wired to §11.13's map, five alert variants with distinct bodies and cancel focused, the Anomaly untouched by all five, Clear Codex re-locking ECHO and SIEVE while leaving the palette ceiling alone |
| T09 | [Pause, interruption and leaving a round](T09-pause-interruption-and-leaving-a-round.md) | P0 | M | T08 | §12.7's full `scenePhase` table as a pure `ScenePhasePolicy`, the silent chevron in PROBE/DRIFT/ECHO, SIEVE's chevron existing only in `paused` behind a confirming second tap, and the 600 ms spin-up on `.active` |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E17-frame-settings

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E17-frame-settings
gh pr create --title "E17 — The Frame, navigation and Settings" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E18 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed or softened to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green | `swift test --package-path Modules` **and** `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |
| 3 | **`distanceToPlay(screen) ≤ 2` for all 18 screens**, for every last-played mode, and every screen is reachable | `swift test --package-path Modules --filter NavigationDepthTests` |
| 4 | Adding a screen without a play key fails CI | The planted-case demonstration recorded in T02's commit message: add a nineteenth `Screen` case, watch `NavigationGraph.edges(lastPlayedMode:)` fail to compile and then `playKeyReachesAPlaySurface` fail, then revert |
| 5 | **Each of the five reset alerts acts on exactly its DATA row's file set, and `anomaly.json` / `anomaly.hw` are byte-identical after all five** | `swift test --package-path HunchCore --filter ResetMapTests` (E07·T06's, re-run unchanged) **and** `swift test --package-path Modules --filter ResetActionWiringTests` (this epic's — that each alert variant dispatches exactly one `ResetAction` and that no variant's file set contains `.anomaly`) |
| 6 | **Mode keys bar and unbar strictly on §9.10's archive evidence** — a band-≥ 3 page for DRIFT, 5 pages for ECHO, 8 for SIEVE — and on nothing else | `swift test --package-path HunchCore --filter ModeUnlockTests`, including the `unlockThreshold(.echo) >= minimumPoolSize + 2` assertion §9.10 requires and the property that `ModeUnlock` reads no round count, no `Ability`, no `ServingState` and no clock |
| 7 | Clear Codex re-locks ECHO and SIEVE and leaves the palette ceiling alone; only Reset the ladder drops it to its band-2 opening state | `swift test --package-path Modules --filter ResetConsequenceTests` |
| 8 | **The Frame is withheld until round 1 ends on a fresh install** | `swift test --package-path Modules --filter FrameWithheldTests` — `AppLaunchRoute` over an empty `InMemoryPersistenceStore` resolves to the opening round, never to `.frame`, and resolves to `.frame` only once `OnboardingLedger` records a settled round 1 |
| 9 | Every interactive target on the Frame sits at `y ≥ 300`, with the Settings and Anomaly keys as the two named exceptions | `swift test --package-path Modules --filter FrameLayoutTests` |
| 10 | The Frame renders at most three accented elements across the Cartesian product of unlock state × streak-present | `swift test --package-path Modules --filter FrameAccentBudgetTests` |
| 11 | All eighteen screens of §12.2 exist and the eleven deliberately-absent screen kinds are absent | `swift test --package-path Modules --filter ScreenInventoryTests` and `Scripts/check-source-hygiene.sh` check 11 |
| 12 | Every preference is a `hunch.settings.` key and no game state reaches `UserDefaults` | `swift test --package-path Modules --filter PreferenceKeyTests` and `Scripts/check-source-hygiene.sh` check 12 (`UserDefaults` named in exactly one file) |
| 13 | Hygiene, tokens, boundary and inventory are all green | `Scripts/check-source-hygiene.sh` · `Scripts/check-pbxproj-clean.sh` · `.claude/skills/hunch-swift-code/scripts/check-boundary.sh --all` · `swift .claude/skills/hunch-design-tokens/scripts/check-tokens.swift` · `Scripts/check-inventory.sh` |

## Definition of done

- [ ] All nine task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `swift test --package-path Modules` green; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with checks 11 (deliberately-absent screen kinds) and 12 (`UserDefaults` in one file) present and each demonstrated to fail on a planted violation before being reverted.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: route-graph reachability, `distanceToPlay ≤ 2` overall and per mode, the play-key inventory guard, the Frame's y ≥ 300 and ≤ 3-accent invariants, the Frame-withheld rule, `ModeUnlock`'s three gates and the ECHO pool-floor inequality, the suspended-key arc fraction, the closed screen inventory, the 13 preference keys, the five alert→`ResetAction` bindings, the two reset consequences, and every row of §12.7's `scenePhase` table.
- [ ] `DECISIONS.md` carries this epic's rulings: the run-notch stack's meaning (§12.4 names it and defines it nowhere); the `Inscription → Codex` edge chosen from §12.2's Entry column over §12.3's diagram and §13.7.3's shared element; Profile → Statistics as a full-surface transition rather than a third `NavigationStack`; the placement of `ThemePreference` in `HunchCore/Sources/Tokens/`; `ScenePhasePolicy` living in `HunchCore` as effects-as-data; and `@SceneStorage` restoring navigation only, never game state.
- [ ] `PROGRESS.md` records the simulator walk: launch → Frame → each of the four mode keys in each of its three states → Codex root → shelf → page → play key → Settings → About → each of the five alerts cancelled → each performed against a disposable container.
- [ ] The PR is merged with every check green, and `main` is pulled before E18 begins.
