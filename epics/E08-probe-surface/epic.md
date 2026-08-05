# E08 — The PROBE play surface

| | |
|---|---|
| **id** | E08 |
| **title** | The PROBE play surface |
| **branch** | `epic/E08-probe-surface` |
| **depends on** | E04 (`GlyphCanvas`, `GlyphShape`, the seven shared marks, `C.Glyph`/`C.VerdictRing`/`C.TickRow`…) · E07 (`RoundPhase` + its transition function, `Probe`, `Ribbon`, `Score`, `ProbeSnapshot`, `PersistenceStore`) — and transitively E02, E03, E05, E06 |
| **gate** | A probe is composed and fed in the simulator on both reference devices · the 420 / 320 ms input lock and the single-slot queue assert · `tickPitch = min(nominalPitch, rowWidth / N)` and `sheetCells ≥ 1 + max cap over modes and bands` both assert · SE 375 × 667 and Pro Max 440 × 956 layouts match §6.2 region for region |
| **tasks** | 10 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH is **playable as a probing loop**. A `Round` exists — one `@MainActor @Observable` class, thin over `HunchCore`'s phase machine, ribbon and scoring — and around it the five surfaces the player actually touches: the throat that *is* the draft and animates only the register that changed; the Dial's four single-select ramps in canonical `fill → shape → pips → hue` order, preloaded with the seed glyph so probe 1 is one tap; the ribbon of 44 pt tiles at 50 pt pitch, link-arced, ghost-marked on the trailing tile and split-ringed on a contradictory twin; the 420 ms verdict beat with its constant 260 ms adjudication hold, its single-slot queue and its `Cue` seam; and the instrument bar whose par tick row inverts, once and permanently, at the par crossing. Both reference devices lay out region for region against §6.2, with every interactive target inside 460 pt of the bottom safe edge. The spool sheet holds the longest possible round in any mode on one screen, and §6.6's five wordless discoverability layers are wired and asserted to be present in **every** band.

What is not here is the answer: the Bench, the Seal, the Assay and the reveal are E09. This epic builds the half of the round where the player asks questions.

## Why now

E04 made a glyph drawable and E07 made a round's state a value. Neither has ever been on a screen. Every remaining play surface in the project is this one re-parameterised: sec-07 §7.5 gives DRIFT *"PROBE's layout region for region"* and permits it exactly two differences; ECHO reuses the ribbon as its rail and its cast, and the twin key as its replay; SIEVE reuses the ribbon as its tail and the tick row as its foul strip; the Codex page reuses the tick row as its `bestProbes` strip. Building the ribbon four times is the failure `hunch-bench-instruments` and `hunch-shared-marks` exist to prevent, and the only way to build it once is to build it first.

It sits after E07 because `Round` is thin over `RoundPhase`, `Ribbon` and `Score` and would otherwise re-implement them in a view. It sits before E09 because the Bench opens *out of* this surface and §6.7's single most important layout constraint is that **the throat and the ribbon do not move between Dial mode and Bench mode** — a constraint you can only honour if the Dial-mode layout already exists and is asserted. It unblocks E09 (which needs `Round`, the layout, the commit bar and the cue seam), E10 (which resumes into this surface), and E12–E14 (which re-parameterise it).

## Scope

| In | Out — and who owns it |
|---|---|
| `@MainActor @Observable final class Round` — phases, ribbon, draft, strikes, input gate, scoring, the one `commit` point | `RoundPhase`, its pure transition function, `Probe`, `Ribbon`, `Score`, `ProbeSnapshot` — **E07·T07–T09** |
| `PlaySurfaceLayout` — §6.2's seven regions on both devices, `tickRowWidth`, `nominalTickPitch`, the reach predicate | Bench-mode geometry (rails 291 pt, the Assay column, the palette) — **E09·T01** |
| `ThroatView` — the live glyph, the seed's ghost frame, the adjudication aperture, the ±1 swipe, one-register animation | The glyph's four registers and its bloom pass — **E04·T02–T05**. The Frame's idle Loom — **E17·T03** |
| `RampView` in `.single` mode, `RampCell`, `DialView` | `RampView`'s `.multi` / `.exactlyOne` / `.stops` modes, the inert state, `BridgeView`, `ForkView`, `TallyView`, `CouplerView` — **E09·T02** |
| `RibbonView`, `RibbonTile`, the tile model, two lanes with a return elbow, trailing pin | `VerdictRing`, `GhostFrame`, `LinkArc`/return elbow themselves — **E04·T07–T08**. ECHO's rail and cast, SIEVE's tail — **E13·T04–T05, E14·T02** |
| The 420 / 320 ms beat, the constant 260 ms hold, the single-slot queue, `Cue` + `CuePlayer` + `SilentCuePlayer` + `RecordingCuePlayer` | `SynthesizedCuePlayer`, `HapticCuePlayer`, `CompositeCuePlayer`, `VoiceBank`, the §13.8/§13.9 parameter tables — **E20·T01–T06** |
| The twin key, `probeTwin()`, the breath and its Reduce Motion substitution | The Bench key and the Dial ↔ Bench transition — **E09·T01** |
| `InstrumentBar` (the three-slot container), `ParTickRow`, `ParRowModel`, the par crossing | The mode sigil drawing — **E17·T04**. The chevron's *action* (suspend) — **E10·T04**, **E17·T09**. The Frame's own bar contents — **E17·T03** |
| `SpoolSheetView`, chain order, verdict sort, ribbon-load-and-dismiss, `RoundBudget` and the capacity invariant | `cap_DRIFT`'s six rows, which fill `RoundBudget`'s `.drift` case — **E12·T04** |
| §6.6 layers 1–5 wired, and the test that none is band-conditional | Layer 6 (the Bench ghost toggle and the pinned-ghost Assay) — **E09·T02, E09·T05** |
| Reduce Motion substitutions for every animation this epic ships | The complete §13.7.4 sweep re-verified row by row against everything shipped — **E09·T12**, **E20·T08** |
| `.accessibility*` labels, values, traits and adjustable actions on the elements built here | The full §13.10 element map across 18 screens, the rotors, Magic Tap, `LawNarrator` — **E19·T01–T05** |
| — | Persistence writes. `Round.commit` is the single point E10·T02 hangs the snapshot write on; this epic writes nothing to disk. |
| — | The composition root. `AppDependencies` is **E10·T01**; this epic constructs `Round` directly in previews and tests. |

## The task list

Execute in this order. Each task ends with `/simplify`, then `/code-review`, then one commit.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [LoomFeature scaffold and Round](T01-loomfeature-scaffold-and-round.md) | P0 | M | — | The `LoomFeature` target and `@MainActor @Observable final class Round`, thin over the core phase machine, with A18's earned exception recorded |
| T02 | [Layout constants for two devices](T02-layout-constants-for-two-devices.md) | P0 | M | T01 | `PlaySurfaceLayout` — §6.2's seven regions on SE and Pro Max, laid out upward from the bottom safe edge, with the 460 pt reach predicate asserted |
| T03 | [The throat](T03-the-throat.md) | P0 | M | T02 | The 96 / 128 pt live glyph that *is* the draft, only the changed register animating, plus the ±1 swipe that wraps off |
| T04 | [The Dial](T04-the-dial.md) | P0 | M | T03 | Four single-select ramps in canonical order, retaining the last probe, preloaded with the seed glyph, adopting a ribbon glyph wholesale |
| T05 | [The ribbon](T05-the-ribbon.md) | P0 | M | T02 | 44 pt tiles at 50 pt pitch, link arcs, the permanent ghost mark on the trailing tile, the doubled ring that draws split, two lanes on Pro Max |
| T06 | [The verdict beat](T06-the-verdict-beat.md) | P0 | L | T05 | 420 / 320 ms lock, a constant 260 ms hold, commit at t = 0, the single-slot queue, and the `Cue` vocabulary behind a `SilentCuePlayer` seam |
| T07 | [The twin key and the breath](T07-the-twin-key-and-the-breath.md) | P2 | M | T06 | One tap re-probes the throat glyph, never blocked and never refunded; the breath fires on the same rule in every band and stops permanently on first use |
| T08 | [Instrument bar, par tick row and the par crossing](T08-instrument-bar-par-tick-row-and-the-par-crossing.md) | P0 | M | T05 | The three-slot bar, the length-proportional row at constant pitch, and the one-way inversion at par — geometry only, no cue |
| T09 | [The spool sheet](T09-the-spool-sheet.md) | P1 | M | T05 | The full-screen 7 × 10 grid in chain order with return elbows, the one-tap verdict sort, and the `sheetCells ≥ 1 + max cap` invariant |
| T10 | [Discoverability layers 1–5](T10-discoverability-layers-1-5.md) | P0 | S | T09 | The five wordless layers wired and asserted band-independent, so none of them leaks the family |

`T08` and `T09` both depend only on `T05` and can be reordered against `T06`/`T07` if you are splitting attention; the commit order above is still the order the branch history should read in.

## Notes on APIs shipped by earlier epics

Two call shapes in the task files depend on how an earlier epic spelled something. Check once, at the start of T01, and use the answer everywhere:

```bash
grep -n 'func par\|func cap\|var par\|var cap' HunchCore/Sources/LawGeneration/Band.swift
grep -n 'struct Probe\|struct Ribbon\|struct Score\|func admits' HunchCore/Sources/Rounds/*.swift HunchCore/Sources/Laws/Law.swift
```

- The task files are written against `band.par(for: .probe)` / `band.cap(for: .probe)`. If E05·T06 shipped them mode-less, drop the argument at every call site — **do not** restate 7 / 13 / 16 / 20 / 23 / 23 / 26 / 29 or 12 / 21 / 26 / 32 / 37 / 37 / 42 / 47 anywhere in `Modules/`.
- The task files are written against `law.admits(glyph, after: previous)` (`08 §3`). If it shipped with a different label, adapt; never re-derive a verdict from an AST walk in the UI.

`Fixtures.swift` (T01) is the **one** file in `Modules/` that constructs a `LawNode` by hand. If an initialiser signature differs from the sketch, fix it there and nowhere else.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E08-probe-surface

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E08-probe-surface
gh pr create --title "E08 — The PROBE play surface" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

Update `.github/pr-body.md` with this epic's summary — the nine gate rows, the two device layout tables and the recorded simulator run — before step 3.

**Do not start the next epic (E09) until this PR is merged.** If a check fails, fix it on the same branch and push again. Never merge red, and never disable, weaken or `--filter` around a check to get green. In particular: the 260 ms adjudication hold is never made conditional to speed a test up, and `sheetCells` is never lowered to fit a smaller grid.

## The gate

Every one of these must be true, and each names the command that proves it. The Presubmission plan excludes the root `HunchUITests` XCUITest bundle (E01·T07), so `-only-testing:HunchUITests` selects the `Modules` package suite unambiguously.

| # | Must be true | Command |
|---|---|---|
| 1 | The fast suite is still green and under 10 s with `RoundBudget` added to `HunchCore` | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | SE 375 × 667 matches §6.2 region for region, and every interactive target is within 460 pt of the bottom safe edge | `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -only-testing:HunchUITests/PlaySurfaceLayoutTests` |
| 3 | Pro Max 440 × 956 does the same, with the surplus in the throat, the ribbon and the bezel gap | the same command with `-destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'` |
| 4 | The 420 / 320 ms lock, the constant 260 ms hold and the single-slot queue all hold | `… -only-testing:LoomFeatureTests/VerdictBeatTests -only-testing:LoomFeatureTests/InputGateTests` |
| 5 | `tickPitch = min(nominalPitch, rowWidth / N)` holds, is never clamped inside PROBE, and clamps to 7.2 pt on SE at `N = 40` | `… -only-testing:HunchUITests/TickPitchTests` |
| 6 | `sheetCells ≥ 1 + max cap over every mode and band`, and the grid is 7 × 10 with every cell ≥ 44 pt | `… -only-testing:LoomFeatureTests/SpoolSheetTests` |
| 7 | §6.6's layers 1–5 are present in every band and none of them reads `band` | `… -only-testing:LoomFeatureTests/DiscoverabilityTests`, then `bash Scripts/check-source-hygiene.sh` |
| 8 | No `Text`, `Label` or `AttributedString` outside `.accessibility*` in `RoundView.swift`, `ThroatView.swift`, `RibbonCanvas.swift`, `RuleTileCanvas.swift`, `SpoolSheetView.swift`, `ParTickRow.swift`; no literal colour, weight, opacity or duration in any of them | `bash Scripts/check-source-hygiene.sh` (checks 7, 9, 10) — and a planted `Text("probe")` in `RoundView.swift` fails it |
| 9 | A probe is composed and fed by hand on both reference devices | build and run in each simulator; compose a glyph on the Dial, press PROBE, watch the tile land, cross par, open the sheet, sort it, load a cell; paste the steps and the outcome into `PROGRESS.md` |

## Definition of done

- [ ] Ten tasks committed, each with `/simplify` and `/code-review` run and their findings resolved.
- [ ] `Modules/Sources/LoomFeature/` holds `Round.swift`, `RoundView.swift`, `DialView.swift`, `VerdictBeat.swift`, `CommitKey.swift`, `BreathPresentation.swift`, `SpoolSheetView.swift`; `Modules/Sources/HunchUI/` gains `PlaySurfaceLayout.swift`, `CommitBar.swift`, `ThroatView.swift`, `RibbonCanvas.swift`, `RibbonTileModel.swift`, `RuleTileCanvas.swift`, `AttributeHeaderView.swift`, `ParTickRow.swift`, `SpoolSheetLayout.swift`, `Chrome/InstrumentBar.swift`; `Modules/Sources/Feedback/` holds `Cue.swift` and `CuePlayer.swift` and imports neither `AVFoundation` nor `CoreHaptics`; `HunchCore/Sources/Rounds/` gains `RoundBudget.swift`.
- [ ] `HunchCore/Sources/Tokens/C.swift` gains `C.Throat`, `C.Ribbon`, `C.Ramp`'s Dial members, `C.Verdict` and `C.TwinKey` — with no colour, no opacity and no hex in any of them.
- [ ] The nine gate rows pass, with output pasted into `.github/pr-body.md`.
- [ ] `DECISIONS.md` records: `Round` as A18's earned exception under a bare domain noun (T01); the Pro Max commit-bar height conflict resolved in favour of §6.2's coordinates (T02); `lastTouched` defaulting to `.fill` (T03); a wholesale ribbon-load leaving `lastTouched` unchanged (T04); `isTwin == false` at probe 0 (T07); and the `Feedback` target created early for its value half only (T06).
- [ ] `SPEC.md` records that `Round` is the only screen-scoped observable in the play surface and that `Round.commit(_:)` is the single point at which round state becomes true.
- [ ] `tests.json` carries the tick-pitch invariant, the sheet-capacity invariant, the constant-hold invariant and the five discoverability layers as passing entries.
- [ ] `PROGRESS.md` records the two simulator runs of gate row 9.
- [ ] The PR is green on every check and squash-merged; `epic/E08-probe-surface` is deleted.
