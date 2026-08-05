# E14 — SIEVE

| | |
|---|---|
| **id** | E14 |
| **title** | SIEVE |
| **branch** | `epic/E14-sieve` |
| **depends on** | E13 (which itself carries E01–E12) |
| **gate** | The pitch invariant `P = 132 pt > 88 pt` holds at every `r` across bands 1–6 × tempo steps 0–3 · S1–S5 hold over a seeded stream corpus · §9.6's worked run reproduces (ratio 0.831, score 831, 2 marks) · the Reduce-Motion parity test shows `preview(n) + window(n)` and the station occupied at time `t` identical with Reduce Motion on and off |
| **tasks** | 10 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH has its fourth and last mode, and the only one with a clock. SIEVE is
**induction without experiment design**: the machine chooses every glyph, the player cannot construct
a controlled variation, cannot twin and cannot go back, and every glyph resolves its true verdict as
it leaves the gate whether the player acted on it or not. What exists that did not before is a pure
`SieveSchedule` whose rate ramps in **glyph index rather than wall-clock** — so a run is reproducible
from its seed and a dropped frame delays a glyph without ever shortening its window; a conveyor whose
only tap target is a stationary 375 × 88 pt gate, with the pitch invariant `P > gate height` asserted
at every rate so at most one glyph is ever actionable; a stream built by subtraction into three
reaches that partition it exactly; four outcomes where three fouls end a run and misses never do; a
score that charges accuracy and reach exactly once each; a difficulty mapping that spans the ability
ladder to an effective band 7 while never serving a band-7 law; a pause that freezes at a glyph
boundary and resumes only on a deliberate gate tap; and a void-and-sticky policy that makes
force-quitting a re-roll of the law rather than a re-roll of the difficulty.

It also ships the one Reduce Motion substitution in the app where motion *is* the mechanic, together
with the shipped test that keeps it honest.

## Why now

§14.3's phase 5 is three epics, one per mode, in the order DRIFT → ECHO → SIEVE, and SIEVE is last
for three reasons that are structural rather than cosmetic:

- **SIEVE feeds ECHO's pool, so ECHO must already own it.** A run sieved at `ratio ≥ 0.92` inscribes
  a Codex page which then enters ECHO's pool (§8.2, §9.6). E13·T01 built the pool as a selection over
  the last 8 inscribed pages; E14 only has to set the flag that lets a SIEVE page qualify. Building
  SIEVE first would have meant inventing the pool contract twice.
- **It is the last mode, so it is the mode that closes the four-mode comparison table.** §9.10 is the
  single source for mode unlocks, δ ceilings, strike counts and interruption policies, and three of
  its four columns already exist. This epic makes the fourth true and the table checkable.
- **The Codex (E15) needs a page that was won by demonstration rather than declaration.** §9.6 mints
  exactly that page and marks it with the SIEVE sigil; E15's page-rendering and duplicate rules must
  handle it from the first commit rather than being retrofitted.

It also unblocks two acceptance gates that cannot be reached without it: §13.12 gate 9's automated
half (`preview(n) + window(n)` parity, bands 1–6 × tempo steps 0–3) and §12.2's eighteenth screen,
`SievePauseOverlay`, which is the only screen in the inventory that E01–E13 do not touch.

## Scope

| In | Out — and who owns it |
|---|---|
| `SieveSchedule` — `r(n)` linear in glyph index, the six band rows, the tempo step, `window`, `preview`, `arrival`, `duration`, the three pacings and the 100 ms auto-pause predicate | The `ContinuousClock.sleep` at the view edge and the frame-time measurement that feeds the predicate — **T02 wires it; there is no `Clock` abstraction** (`hunch-swift-code` gotcha, `08 §5`) |
| `C.GateBand`, the five regions, `GateBandView`, the ±44 pt actionable rule, GATE-STRADDLE / DOUBLE-TAP / THUMB-PARK, the pitch invariant | The travelling glyph's drawing — **E04·T05 `GlyphCanvas`**; the verdict ring in the sump — **E04·T07**; the tail's tiles and link arcs — **E08·T05 `ribbon.md` §3, reused not redrawn** |
| The SIEVE instrument bar's *composition* (three foul ticks, stream progress arc, mode sigil, no numerals) | The tick row and arc meter marks themselves — **E04·T08**; the SIEVE mode sigil's drawing — **E17·T04** (`hunch-sigil-drawing`); the instrument bar's generic geometry — **E15/E17** via `hunch-chrome-and-meta/references/instrument-bar.md` |
| Stream composition, the three reaches, S1–S5, the inert seed glyph priming position 0 | The law itself and G1–G10 — **E06·T05/T06**; `Law.admits(_:after:)` and the seed-glyph priming semantics — **E05·T03** |
| Fouls, outcomes, `SievePhase` and its transition table, the two degenerate strategies asserted dominated | The `Cue` vocabulary (`sieveTick` / `sieveHit` / `sieveMiss` / `lawBroken`) — **E08·T06** declares it; this epic only fires it. The synthesised and haptic players — **E20·T03/T04** |
| SIEVE scoring, marks off `yield`, success, the `ratio ≥ 0.92` page flag and the SIEVE-sigil mark on it | Minting, deduplicating and rendering the page — **E15·T01/T05/T06**; adding it to ECHO's pool — **E13·T01** |
| Difficulty mapping — `lawBand`, `s`, `δ_SIEVE`, `band_SIEVE`, the drop-`s`-before-`lawBand` rule | §10.3's 13 serving steps, its step-6 `δ ≤ 2.99` clamp and its step-8 `1…7` mode clamp — **E11·T03**; the two-consecutive-losses `relief` ladder — **E11·T04**. This epic consumes `targetδ` and returns the pair |
| Pause, the 3-glyph run-up, `SievePauseOverlay`, `Scrim.Kind.sievePause` | The Bench scrim and `Opacity.scrim(in:)` — **E03·T04 / E09·T01**; `scenePhase` plumbing and the 600 ms `.active` spin-up for the other three modes — **E10·T03 / E17·T09** |
| Void / sticky / abandon as values, the always-written `void` record, the third-consecutive rule | Consuming `stickyTarget` in the serving layer and honouring "no ability update" — **E11·T01/T03/T06**; the `RoundRecord` type and the 200-entry ring — **E07·T09 / E16·T11** |
| Steady stream's effect, its `hunch.settings.steadyStream` key and the no-Tempo-sample rule | The Settings **row** and its `SettingsView` placement — **E17·T07**; the Profile's Tempo axis update rule — **E16·T05/T06**. This epic emits the sample tuple or `nil` |
| The Reduce-Motion parity test and the four-station crossfade substitution | The rest of §13.7.4's substitution table — **E09·T12**; gate 9's *manual* half and the accessibility audit — **E19·T09/T11** |
| `Loc` keys for `gate`, `admit`, `tail` as accessibility strings | The catalog itself, the 12 locales and the ≤ 250-key budget — **E18**; the element index rows — **E19·T05** |

Explicitly **not** in this epic: SIEVE's Frame key, its unlock at ≥ 8 Codex pages, and the barred /
idle / suspended key states — all **E17·T03/T04**. SIEVE never draws a suspended arc, because it
never suspends.

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [`SieveSchedule` — the speed curve](T01-sieve-schedule-speed-curve.md) | P0 | M | — | `r(n)` linear in glyph index so a run is reproducible from its seed; the six band rows behind `Band.sieveServable`; the tempo step adding `0.20·s` to both ends; the three pacings; the 100 ms frame-budget auto-pause predicate |
| T02 | [Conveyor geometry and the pitch invariant](T02-conveyor-geometry-and-pitch-invariant.md) | P0 | M | T01 | Lip / lane / gate / sump / tail; `C.GateBand`; the 375 × 88 pt gate as the whole target; actionable exactly within ±44 pt of y = 464; `P > gate height` asserted at every `r`; touch-**down** only; taps outside discarded in silence |
| T03 | [Stream composition](T03-stream-composition.md) | P0 | L | T02 | `tell = 12` at weight 0.5, `runOut = round(0.25·N)`, `body` as the **remainder**; the three construction rules; S1–S5; the seed glyph held inert in the gate for 1.5 s in contextual bands |
| T04 | [Fouls and outcomes](T04-fouls-and-outcomes.md) | P0 | M | T03 | Hit / correct pass / miss / foul; `SievePhase` and its transition table; three fouls end a run and misses never do; no foul accrues during the tell; both degenerate strategies asserted numerically dominated |
| T05 | [SIEVE scoring](T05-sieve-scoring.md) | P0 | M | T04 | `ratio` over **resolved** glyphs × `completion`, each charged once; marks read off `yield`; success iff sieved and `ratio ≥ 0.80`; the page flag at `ratio ≥ 0.92`; §9.6's worked run reproduced |
| T06 | [Difficulty mapping](T06-difficulty-mapping.md) | P0 | M | T05 | `lawBand = min(6, floor(targetδ/0.125)+1)`, `s` solved as the remainder, `δ_SIEVE ≤ 0.874` and `band_SIEVE ≤ 7` as two distinct quantities; `targetδ` is difficulty units and a logit traps; speed drops before the idea does |
| T07 | [Pause, run-up and `SievePauseOverlay`](T07-pause-run-up-and-pause-overlay.md) | P0 | M | T02 | Freeze at the next glyph boundary under a 70 % scrim over the frozen lane; resume only on one deliberate tap on the gate; the 3-glyph run-up at `r₀` that costs nothing and is not re-scored; the chevron exists only here |
| T08 | [Void, sticky and abandon](T08-void-sticky-and-abandon.md) | P0 | M | T05 | Termination voids and freezes `δ_served` / `lawBand` / `s`; the third consecutive termination is scored at its frozen `ratio` and `completion`; the two-tap chevron abandons and is scored as a foul-out; the record is always written, marked `void` |
| T09 | [Steady stream](T09-steady-stream.md) | P1 | S | T08 | Fixes `r` at `r₀` with no ramp at a 0.85 score multiplier, ungated, inscription intact, and **no Tempo sample** — the sample would measure the setting |
| T10 | [The Reduce-Motion parity test](T10-reduce-motion-parity-test.md) | P0 | M | T07 | Four stations kept, glyphs crossfading lip → lane → gate → sump at the identical cadence; gate dwell and the ±44 pt rule byte-identical; `preview(n) + window(n)` and the station at time `t` asserted equal in both modes across every band × tempo step × `n` |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E14-sieve

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E14-sieve
gh pr create --title "E14 — SIEVE" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E15 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green | `swift test --package-path Modules` **and** `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |
| 3 | **The pitch invariant holds at every `r`** — `P = 132 pt > 88 pt`, and at most one glyph is ever actionable, across bands 1–6 × tempo steps 0–3 × every `n` | `swift test --package-path HunchCore --filter SievePitchInvariantTests` |
| 4 | **S1–S5 hold over a seeded stream corpus** | `swift test --package-path HunchCore --filter SieveStreamGuardrailTests` — parameterised over `Band.sieveServable`, `Corpora.sieveStreamsPerBand` streams looped inside, every failure naming its reproducing seed with an `Attachment.record` of the stream |
| 5 | **§9.6's worked run reproduces exactly**: `ratio` 0.831, `score` 831, **2** marks | `swift test --package-path HunchCore --filter SieveScoreTests/workedRunFromSection96` |
| 6 | **Reduce Motion changes no SIEVE timing** — `preview(n) + window(n)` and the station occupied at time `t` are identical with the setting on and off, bands 1–6 × tempo steps 0–3 × every `n` | `swift test --package-path HunchCore --filter SieveReduceMotionParityTests` |
| 7 | Both degenerate strategies are strictly dominated, numerically | `swift test --package-path HunchCore --filter SieveDegenerateStrategyTests` — tap-everything fouls out inside the first three body glyphs at `p ≤ 0.60`; tap-nothing sieves and lands below the 1-mark threshold |
| 8 | The difficulty mapping never serves a band-7 or band-8 law and never exceeds `δ_SIEVE = 0.874` or `band_SIEVE = 7` | `swift test --package-path HunchCore --filter SieveDifficultyTests` |
| 9 | Voiding is sticky and bounded: two voids leave the target untouched, the third termination is scored | `swift test --package-path HunchCore --filter SieveTerminationTests` |
| 10 | Hygiene is green, including this epic's added check | `Scripts/check-source-hygiene.sh` — check 13: no numeral, lawful count or admit-rate readout anywhere in `SieveRoundView.swift` or `SievePauseOverlay.swift`, and no `Text`/`Label`/`AttributedString` outside `.accessibility*` in either |
| 11 | A SIEVE run is played end to end in the simulator: streamed, fouled, paused, resumed with the run-up, and abandoned from `paused` | The transcript in `PROGRESS.md` §Phase 5 ▸ SIEVE, with the on-disk `stats.json` `recentRounds` entry quoted for each of the four endings |

## Definition of done

- [ ] All ten task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with check 13 present and demonstrated to fail on a deliberately planted numeral in `SieveRoundView.swift` before being reverted.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: the pitch invariant, the ±44 pt actionable rule, S1–S5, the tell's no-foul rule, the two dominated strategies, `ratio`-over-resolved, marks off `yield`, the `0.92` page gate, `δ_SIEVE ≤ 0.874`, `band_SIEVE ≤ 7`, the run-up's zero cost, void stickiness, the third-void rule, the abandon-as-foul-out rule, steady stream's no-Tempo-sample rule, and the Reduce-Motion parity assertion.
- [ ] `DECISIONS.md` carries this epic's six entries: the three-case `SievePacing` (steady ≠ stepped, because §9.8 gives them different rates); the touch-down gesture that replaces `gate-band.md`'s `.onTapGesture` sketch; `SieveConveyor` carrying the Reduce-Motion presentation flag rather than `SieveSchedule` (a flag a value ignores makes its own test tautological); the 0.85 steady-stream multiplier applied to `score` only and never to `yield`, `ratio`, marks or the page gate; the 200-attempt-then-repair bound on stream construction, which §9.4 does not state; and `C.GateBand.previewTravel` as a spec constant that is not re-derived from region boundaries.
- [ ] `PROGRESS.md` records the four-ending simulator transcript and the measured `SieveStream.build` cost per band, so E20 has a baseline for §14.6 risk 6.
- [ ] The PR is merged with every check green, and `main` is pulled before E15 begins.
