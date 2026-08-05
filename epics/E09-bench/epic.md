# E09 — The Bench, the Assay, the Seal and resolution

| | |
|---|---|
| **id** | E09 |
| **title** | The Bench, the Assay, the Seal and resolution |
| **branch** | `epic/E09-bench` |
| **depends on** | E06 (difficulty, `BenchLayout`/`RuleTile`/`SealBar`, the generator, counterexample selection), E08 (the PROBE play surface, `Round`, the ribbon, the throat, the `Cue` seam) |
| **gate** | A full round plays to a correct declaration in the simulator · the barred-Seal states are exhaustive (`SealBar` switch, no `default:`) · counterexample presentation reproduces §4.5's four-step rule on a seeded corpus · the reveal's absolute times match §6.8 (2,480 / 1,660 / 2,040 ms) under a phase-count assertion so §6.8 and §13.7.1 cannot drift apart |
| **tasks** | 12 |
| **status** | not started |

---

## Goal

When this epic merges, a player can state a theory and be judged on it. The Bench exists as a real
surface — four rule-tile canvases, a coupler, a palette whose ceiling is read from the player's
lifetime maximum band served, an Assay that shows the draft's extension live and conditioned on a
pinned ghost, and a Seal that is physically barred until the draft is a law. Pressing it runs the
640 ms verdict-blind hold and then one of four resolutions: the correct reveal at 2,480 ms, the
first-strike counterexample at 1,600 ms, the lost skeleton at 1,660 ms, or the exhausted end at
2,040 ms — every one of them absolute from the Seal press, every one of them decoration over state
that was already committed to disk at t = 0. The round ends on `InscriptionView`, the same screen for
both outcomes, with the Codex page minted or re-inscribed in place.

## Why now

E09 sits directly after E08 because the Bench is the second half of one screen: §6.7's single most
important layout constraint is that **the throat and the ribbon do not move between Dial mode and
Bench mode**, which is unassertable until both modes exist in one layout type. It sits after E06
because `BenchLayout`, `RuleTile`, `SealBar` and counterexample selection are *core* — G10 is a
generation-time guardrail, so the generator already depends on the Bench's grammar and this epic
draws it rather than defines it.

It unblocks E10, which cannot close §14.3's phase 3 without a round that reaches `settled`: the
mid-round snapshot has nothing to restore into, the 13-beat opening script has no palette or Seal
beat to script, and `OnboardingLedger.declaredCorrectly` has no event to record. It also unblocks
E11, whose palette-sufficiency assertion (H20) fires against the ceiling this epic builds, and E15,
whose `CodexPageView` composes the read-only rule-tiles and the Assay at their Codex scale.

This is the design's second-largest named risk — a wordless declaration UI — and this is the epic
that retires it.

## Scope

| In | Out — and who owns it |
|---|---|
| `BenchView`, the drawer, the handle, the palette, the Bench's regions on both reference devices | The Dial, throat, ribbon, par tick row, spool sheet, verdict beat — **E08** |
| `RampView`, `BridgeView`, `ForkView`, `TallyView`, `CouplerView`, `WedgeShape`, `TurnoutShape`, `CombShape`, `RuleTileFrame`, `RailView` | The glyph fragment drawn *inside* a ramp cell — **E04** (`hunch-glyph-renderer`) |
| The Bench's exhaustive gesture inventory and the lint that holds it | The four rotors, Magic Tap, escape, every label and announcement's wording — **E19** |
| `PaletteCeiling` — the derivation, the raise-at-serve-time rule, the sufficiency assertion | `ServingState`, `maxBandEverServed`'s persistence, the galloping ladder's full-palette grant — **E11** |
| `AssayCanvas`, `AssayInspectorView`, the pinned-ghost slice, the six cell sites, the evidence overlay and its grant | `LawTable.row(after:)` and `.marginal()` as algebra — **E05**; the Codex thumbnail's projection and its overlays — **E15** |
| `SealView`, `BenchLayout.sealBar`, the rail pulse | The `SealBar` enum's declaration and the 200 k-configuration Bench fuzzer — **E06** |
| Declaration adjudication, two strikes, the two-declaration ceiling | Extension identity with lifting as an algorithm — **E05**; par/cap/score arithmetic — **E06** |
| The counterexample's *presentation* — rise, two rings, dock, auto-collapse | The counterexample's *selection* (§4.5's four steps) — **E06**; the DRIFT dead-law step 0 — **E12** |
| `C.Reveal`, `RevealPhase`, all four end-of-round sheets in absolute time, the one skip threshold, the published cue points | Attaching audio and haptic players to those cue points — **E20**; DRIFT's hinge reveal — **E12** |
| `InscriptionView`, page minting, duplicate re-inscription, the t = 0 commit | `Codex` the observable, shelves, browse, `CodexPageView` — **E15**; the Anomaly strip appended to the Inscription — **E16** |
| The Reduce Motion substitution rows for every animation E08 and E09 added | SIEVE's replaced-not-removed row — **E14**; the Profile morph and streak bloom rows — **E16**; the final row-by-row re-verification against the shipped app — **E20** |
| — | The composition root, snapshot wiring, resume, abandon, the fixed opening round, the five nudges, §6.11's 29 edge cases — **E10** |

## The task list

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [Bench layout, palette and the handle](T01-bench-layout-palette-and-handle.md) | P0 | M | — | 291 pt rails, the Assay's 64 pt trailing column, four 68 × 44 palette stamps, the Dial/Seal commit bar; the throat and ribbon hold their rects across both modes; the handle drag with its tap equivalent; the draft preserved verbatim on backing out |
| T02 | [The four rule-tile canvases](T02-the-four-rule-tile-canvases.md) | P0 | L | T01 | `RampView` (7 instances, one inert state), `BridgeView` (two sockets, pictorial wedge, trailing-only ghost toggle), `ForkView` (gate / lit / dim, turnout follows the lit gate cell), `TallyView` (column, rank ramp, counter dial, parity comb), `CouplerView` (welded / forked / crossed) |
| T03 | [The gesture inventory](T03-the-gesture-inventory.md) | P0 | S | T02 | §4.2's eight gestures as a Swift value; tap and trailing-swipe only; no drag, pinch, long-press or double-tap in the declaration UI; enforced by hygiene check 11 over the Bench's gesture surface |
| T04 | [The palette ceiling](T04-the-palette-ceiling.md) | P0 | M | T02 | `PaletteCeiling` derived from `maxBandEverServed + 1` and never from the current round's band; `required(for:)` derived from the generator, not hand-listed; raised at serve time, asserted before the round arms |
| T05 | [The Assay](T05-the-assay.md) | P0 | L | T02 | The 16 × 16 deck at all six cell sites, the live slice pinned to the ghost, the 256-position scrubber, the full-screen inspector, never bloomed; the slice-versus-projection test reproduces §6.7's 64-not-48 |
| T06 | [The Assay evidence overlay](T06-the-assay-evidence-overlay.md) | P1 | M | T05 | Ribbon rings plus a wrong-cell flash against the transcript; granted at band ≥ 4, always on the Anomaly, permanently after §10.7's floor rescue, and never at bands 1–3 otherwise |
| T07 | [The Seal and the machined bar](T07-the-seal-and-the-machined-bar.md) | P0 | M | T02 | `BenchLayout.sealBar` as the one predicate; the bar drawn by `MachinedBar.draw`; a barred press pulses the offending rail 3 × 90 ms and does nothing else; §6.7's nine-tap walkthrough reproduced step by step |
| T08 | [Declaration verdict and two strikes](T08-declaration-verdict-and-two-strikes.md) | P0 | M | T07 | Extension identity in the common space with lifting; arrangement, spelling, coupler choice and complement direction irrelevant; strike 1 continues, strike 2 ends, two declarations per round hard |
| T09 | [The counterexample presentation](T09-the-counterexample-presentation.md) | P0 | M | T08 | The 640 ms verdict-blind hold identical in content and duration for both outcomes, then the 960 ms beat: two rings at once, a link-arc-joined pair in contextual bands, docking below the ribbon as a marginal island; not a probe, never `prev`, Bench auto-collapses with no forced probe |
| T10 | [The law-reveal beat sheets](T10-the-law-reveal-beat-sheets.md) | P0 | L | T09 | One `phaseAnimator` over `RevealPhase`; correct 2,480 / broken 1,660 / exhausted 2,040 ms absolute, `absolute = 640 + local`; offsets derived from stored durations; skippable from 1,040 ms and nowhere else; cue points published as data |
| T11 | [`InscriptionView` and page minting](T11-inscriptionview-and-page-minting.md) | P0 | M | T10 | One round-end screen for both outcomes; page, θ update, Profile accumulators and novelty-ring entry all written at t = 0 on the Seal press; a duplicate re-inscribes in place with a re-strike ring and never mints a second page |
| T12 | [The round's Reduce Motion substitutions](T12-the-rounds-reduce-motion-substitutions.md) | P0 | M | T10 | Every E08 and E09 animation given its named substitution; input lock 420 → 320 ms; the 640 ms seal hold deliberately unchanged; onsets keep absolute positions and those past 900 ms are dropped, not rescheduled |

Execution order is the table order. T01 → T02 is a hard chain; T03, T04, T05 and T07 all branch off
T02 and may be interleaved, but each must be committed green before the next starts.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E09-bench

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E09-bench
gh pr create --title "E09 — The Bench, the Assay, the Seal and resolution" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E10 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip, weaken or delete a check to get green. A `tests.json`
entry may be added but never removed.

## The gate

Every item must be true, and the command beside it is what proves it.

| # | What must be true | Command |
|---|---|---|
| 1 | The `HunchCore` fast suite is green **and still under 10 s** — this epic adds `BenchTests` and `RoundsTests` cases and must not spend the budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The Modules suites are green in the simulator | `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests -only-testing:LoomFeatureTests` |
| 3 | **The barred-Seal states are exhaustive.** `SealBar.Kind.allCases.count == 3`, all three kinds are produced by real drafts, a complete draft yields `nil`, and no `switch` over `SealBar` or `SealBar.Kind` carries a `default:` | `swift test --package-path HunchCore --filter SealBarTests` and `! grep -rn 'default:' HunchCore/Sources/Bench Modules/Sources/HunchUI/SealView.swift` |
| 4 | **Counterexample presentation reproduces §4.5's four-step rule on a seeded corpus** — over `Corpora`'s (law, ribbon, declaration) triples the presented counterexample is byte-identical to `Counterexample.select(…)`'s output, and the view never re-selects | `xcodebuild test … -only-testing:LoomFeatureTests/CounterexamplePresentationTests` |
| 5 | **The reveal's absolute times match §6.8 under a phase-count assertion.** `sealHold + Σ correct == 2,480 ms`, `sealHold + Σ lost == 1,660 ms`, `verdict + preRoll + Σ lost == 2,040 ms`, `C.Reveal.correct.count == RevealPhase.allCases.count`, `C.Reveal.lost.count == 6`, and the derived offset arrays equal §6.8's tables | `xcodebuild test … -only-testing:LoomFeatureTests/RevealBeatTests` |
| 6 | Source hygiene is clean, including the new gesture-inventory check 11 and the no-literals checks over every file this epic added | `bash Scripts/check-source-hygiene.sh` |
| 7 | **A full round plays to a correct declaration in the simulator.** Launch the app, open the Bench from the Dial, build a draft, watch the bar lift, press the Seal, watch the 2,480 ms reveal, land on `InscriptionView` with a minted page | `xcodebuild -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build && xcrun simctl …` — record the run in `PROGRESS.md` with the seed used |
| 8 | Reduce Motion: nothing added by E08 or E09 translates, scales or rotates, every added animation has a row, and the 640 ms hold is unchanged | `xcodebuild test … -only-testing:LoomFeatureTests/ReduceMotionTableTests` plus a hand pass of §13.12 gate 9 on `RoundView`, `BenchView`, `AssayInspectorView`, `InscriptionView` |

## Definition of done

- [ ] All 12 task files are `status: done`, each with its own commit.
- [ ] All eight gate rows above pass, and the exact commands are pasted into `PROGRESS.md`.
- [ ] `tests.json` carries an entry for every invariant this epic ships: the throat/ribbon layout
      identity, the palette-ceiling monotonicity and sufficiency, the Assay slice-not-projection
      assertion, the `SealBar` exhaustiveness, the two-declaration ceiling, the counterexample
      corpus, the four reveal totals, the t = 0 commit, the duplicate rule, and the Reduce Motion
      table. No entry is removed or weakened.
- [ ] `DECISIONS.md` records the three rulings this epic makes:
      (a) §6.7's 380 ms Dial ↔ Bench transition is the **tap-driven** path and §13.7.3's `dur.sheet`
      bounds the **interactive drag** settle — they are two facts, not one contradiction;
      (b) §6.7's walkthrough places "the machined bar lifts" on tap 9 while §4.3's predicate lifts it
      on tap 8 — the predicate is normative and the prose is descriptive of the finished state;
      (c) `RuleTileCanvas.swift` holds five top-level `View` types against `01 P24`, because
      `08 §1`'s tree and all five reference files name that one file as their owner.
- [ ] `PROGRESS.md` names the branch, the PR number, the merge commit and the simulator run.
- [ ] `/simplify` and `/code-review` have both been run on every task's diff with no unresolved finding.
- [ ] The PR is merged with every check green.

## Two standing rules for this epic

**Cite, never restate.** No implementation file in this epic may contain a hex, an opacity, a
`lineWidth:`, a duration literal or a bare `1.35`. Colours, weights, spaces, radii, opacities and
durations resolve through `hunch-design-tokens`; component geometry lives at L2 in `C.<Component>` in
`HunchCore/Sources/Tokens/C.swift`. `Scripts/check-source-hygiene.sh` check 9 fails the build on a
literal. The one place a spec number may be written down is **inside a test**, where quoting §6.8's
table is the entire point of the assertion — and even there the implementation side of the comparison
must be *derived* (a running sum of stored durations), never a second copy of the same array.

**Commit before you animate.** Every verdict, page, θ update and accumulator is committed at t = 0 of
its beat sheet and merely displayed later (§6.1, §6.8). If a piece of state only becomes true when an
animation ends, that is the bug — and `/code-review` should reject it.
