# E12 — DRIFT

| | |
|---|---|
| **id** | E12 |
| **title** | DRIFT |
| **branch** | `epic/E12-drift` |
| **depends on** | E11 (which itself carries E01–E10) |
| **gate** | D1–D7 hold over a seeded pair corpus · §7.7's worked band-5 round reproduces numerically (score 600, 2 marks, fractured, `R = 16`, Flexibility sample 0.303) · a DRIFT round suspends and resumes with the hinge **neither re-firing nor un-firing** · the par tick row compresses correctly to 7.2 pt on SE at `par_DRIFT = 40` |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH has a **second mode**, and it is the first proof that the four-mode
claim is real rather than aspirational. DRIFT removes exactly one property from PROBE — the
permanence of evidence — and adds **no controls, no chrome and no timer** to its surface. A round
holds two laws, `L₂` a one-leaf edit of `L₁` in the same family and skeleton, both individually legal
and jointly constrained by seven pair guardrails. Partway through, the floor moves: at the
`N_admits`-th admit, at a correct pre-hinge declaration that is *accepted and does not end the
round*, or forced at `ceil(0.80·par(b))`. Nothing on screen changes at that instant, which is the
entire mode. The round is budgeted against `par_DRIFT` and `cap_DRIFT`, scored by canon's formula
with one substitution, and closed by a reveal that re-reads the whole transcript on both sides of the
seam and morphs one law into the other with **one moving part**.

It also lands the two things that make the mode measurable rather than merely present: the dead-law
counterexample, which guarantees the lesson is delivered at least once per round, and the transcript
metrics `(R, rec(b), deadDeclaration)` that DRIFT hands the Profile and that no surface may ever
render as a number.

## Why now

§14.3's phase 5 is the three non-PROBE modes in a fixed order and DRIFT is first, because it is the
one that reuses PROBE wholesale and therefore proves the reuse.

- **E11 is the hard dependency.** DRIFT is served, not chosen: the 13-step policy's per-mode clamp
  gives DRIFT bands **3…8** (E11·T03), the mode offset and `K_Δ` give it its own θ (E11·T01), and
  `avoid` assembly (E11·T06) is what D5 reads. A DRIFT round generated outside the serving layer
  would be a demo, not a mode.
- **It is the mode that stresses everything E08 and E09 built** without extending it. §7.5 permits
  exactly two differences from PROBE's surface, so every region, every duration, the ribbon, the
  Bench, the Seal, the strike path and the counterexample are reused *as shipped* or the claim is
  false. If PROBE's surface were secretly PROBE-shaped, this is where it breaks.
- **It unblocks E13 and E15.** ECHO's pool takes `L₂` from a DRIFT page (§8.2), and the Codex page's
  `driftPartner` / `driftHinge` fields (§11.1, written by E09·T11) have no producer until this epic
  exists. DRIFT is also the mode whose `cap_DRIFT = 64` the spool sheet was already sized against
  (E08·T09), and that assertion stays a promise until T04 fills the row.
- **Three forward obligations from earlier epics come due here** and were written into their task
  files as such: `RoundBudget.cap(mode:band:)`'s `.drift` case (E08·T09), `Counterexample.select`'s
  injectable candidate set (E06·T08), and `DriftPhase` (E07·T07).

## Scope

| In | Out — and who owns it |
|---|---|
| `generateDriftPair`, the one-leaf edit neighbourhood, the seven pair guardrails D1–D7, the six anchor pairs | Canon's `generate`, G1–G10, the anchor **law**, `LawIndex` — **E06·T05/T06**. D-guardrails run *after* both laws clear G1–G10; they never re-implement one |
| `DriftSchedule`, `N_admits`, the three hinge triggers, `lawInForce(atProbe:)`, `t_hinge` | The serving policy's band clamp 3…8, `targetδ`, the mode offset and the θ update — **E11·T01/T03/T06**. This epic *asserts* the clamp at arm time; it does not implement it |
| `DriftPhase`, its transition table, the dead-law strike path, `cap_DRIFT` loss, second-strike loss | `RoundPhase` and PROBE's eight-phase machine — **E07·T07**, reused unchanged; the 420 ms probe beat and its single-slot input lock — **E08·T06**, reused unchanged |
| `DriftBudget` (the six-row table), `par_DRIFT`, `cap_DRIFT`, `rec(b)`, DRIFT scoring and the three mark rules | `Score`'s formula and the multiply-then-round-once order — **E06·T07**; `TickRow.draw` and `tickPitch` — **E04·T08** / **E08·T08**. T04 supplies numbers to both and changes neither |
| `ModeSigil.drift`, the seam marker, and the parity test that proves those are the **only** two differences from PROBE | The other three mode sigils, the rack key's six states and the archive-evidence gates — **E17·T04**; the instrument bar's chevron action — **E10·T04** / **E17·T09** |
| The dead-law step 0 (selection) | Canon §4.5's four steps — **E06·T08**; the two-ring presentation, the 640 ms hold and the docking island — **E09·T09**, reused unchanged (the dead-law case draws the *twin* ring, which already exists) |
| `DriftTranscript` — `t_hinge`, `t_evidence`, `t_recover`, `C`, `R`, `deadDeclaration` — and the `(R, rec(b), deadDeclaration)` emission | The Flexibility **sample formula**, `L*`, the update rule and `α` — **§11.9 / E16·T05/T06**. T07 ships one pinned worked number and a forward note that E16 owns the formula |
| The hinge reveal: seam, split, dead stretch, morph, hold; its Reduce Motion row; its published cue points | `RevealPhase` and the four end-of-round sheets — **E09·T10**; attaching audio and haptic players to cue points — **E20** |
| DRIFT's extra snapshot fields, resume without re-randomisation, the seven named edge cases, the discard policy and its alert | `ProbeSnapshot`, `StoreFile`, atomic writes and the write order — **E07**; snapshot **cadence** and the `lawHash` → `.voided` path — **E10·T02**; the Frame key that presents the alert — **E17·T04** |
| — | **Not in this epic at all:** ECHO's pool contribution rule (**E13·T01**), the Codex page's rendering of a DRIFT find (**E15·T05**), the Flexibility vertex (**E16·T08/T09**), DRIFT's VoiceOver element map (**E19**) |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [`DriftSchedule` and two-law generation](T01-drift-schedule-and-two-law-generation.md) | P0 | L | — | `L₂` as a one-leaf edit of `L₁` in the same family and skeleton; D1–D7 after both clear G1–G10; 200 attempts then the family's anchor pair; bands 3–8 only, made mechanically true by `DriftBudget` having no row below 3 |
| T02 | [The hinge](T02-the-hinge.md) | P0 | M | T01 | `N_admits ~ U[3,6]` drawn once from the round seed; satiation, capture and forced triggers; `lawInForce(atProbe:)`; the hinge never resets context |
| T03 | [`DriftPhase` and the lifecycle](T03-drift-phase-and-the-lifecycle.md) | P0 | M | T02 | The nine phases verbatim and the complete transition table, including the post-hinge `L₁` path that produces the dead-law strike and the two loss paths into `hinge` |
| T04 | [`par_DRIFT`, `cap_DRIFT` and scoring](T04-par-drift-cap-drift-and-scoring.md) | P0 | M | T03 | The six-row table 25/40 → 40/64 with `rec(b)`; canon's formula with `par_DRIFT` substituted; 3 marks need both conditions; the par row compresses to 7.2 pt at 40 ticks |
| T05 | [The DRIFT surface](T05-the-drift-surface.md) | P0 | M | T04 | PROBE's layout region for region; `ModeSigil.drift` authored under the sigil grammar; the seam marker; a parity test that the difference set is exactly those two |
| T06 | [The dead-law counterexample](T06-the-dead-law-counterexample.md) | P1 | M | T03 | Step 0 in front of canon's four steps, tie-broken by most recent ribbon index then lowest `glyphID`, rendered as the twin ring; falls through when `D` holds no ribbon member |
| T07 | [Transcript metrics](T07-transcript-metrics.md) | P1 | S | T04 | `t_hinge`, `t_evidence`, `t_recover`, `C`, `R`, `deadDeclaration` derived at `settled`; emitted as a triple; never rendered, spoken or stored as a displayable value |
| T08 | [The hinge reveal](T08-the-hinge-reveal.md) | P0 | L | T06 | 500 ms seam → two-lane split at ±18 pt → hatched dead stretch → 900 ms morph in which only the edited leaf animates → 3 s hold; Reduce Motion keeps the geometry and the leaf |
| T09 | [DRIFT persistence and the seven edge cases](T09-drift-persistence-and-the-seven-edge-cases.md) | P0 | M | T08 | The record's nine extra fields, nothing re-randomised on resume, the seven named edge-case tests, and the discard confirmation that lives outside the play surface |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E12-drift

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E12-drift
gh pr create --title "E12 — DRIFT" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E13 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed or weakened to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | **D1–D7 hold over a seeded pair corpus** — every band 3–8, 2,000 pairs each | `swift test --package-path HunchCore --filter DriftPairGuardrailTests`; every failure names its reproducing seed and attaches both ASTs |
| 3 | The anchor-pair fallback rate stays under §5.3's 2 % per band | `swift test --package-path HunchCore --filter DriftFallbackRateTests` |
| 4 | **§7.7's worked band-5 round reproduces numerically** — `probesUsed = 27`, `score = 600`, 2 marks, fractured, `R = 16` against `rec(5) = 9`, Flexibility sample `0.303` | `swift test --package-path HunchCore --filter WorkedDriftRoundTests` |
| 5 | **A DRIFT round suspends and resumes with the hinge neither re-firing nor un-firing** | `swift test --package-path HunchCore --filter DriftSnapshotTests` **and** the simulator transcript in `PROGRESS.md`: play past the hinge, quit, relaunch, dump `round-drift.json`, confirm `hingeFired`, `tHinge`, `nAdmits` and the probe list are byte-identical either side |
| 6 | **The par tick row compresses to 7.2 pt on SE at `par_DRIFT = 40`**, and the cap row does not compress at all | `swift test --package-path Modules --filter DriftTickRowTests` |
| 7 | The seven named edge cases each pass as their own test | `swift test --package-path HunchCore --filter DriftEdgeCaseTests` — EARLY-SEAL, STARVED-HINGE, DEAD-HINGE, CONTEXT-CARRY, BLIND-EDIT, DOUBLE-STRIKE-PRE-HINGE, TWIN-OF-THE-HINGE |
| 8 | DRIFT adds **no** control, chrome or timer to PROBE's surface | `swift test --package-path Modules --filter DriftSurfaceParityTests` — the region table is identical and the difference set is exactly `{modeSigil, seamMarker}` |
| 9 | No transcript metric is ever rendered or spoken | `Scripts/check-source-hygiene.sh` check 13 — none of the six identifiers appears inside `Text(`, `Label(`, `.accessibilityLabel(` or `.accessibilityValue(`, and no catalog key mentions them |
| 10 | The reveal's phases sum to their stated total in both motion modes | `swift test --package-path Modules --filter HingeRevealTests` |

## Definition of done

- [ ] All nine task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with check 13 present and demonstrated to fail on a deliberately planted violation before being reverted.
- [ ] The play-past-the-hinge → quit → relaunch → resume transcript is in `PROGRESS.md`, with `round-drift.json` quoted either side.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: D1–D7, the one-leaf-edit invariant, the fallback rate, the three hinge triggers, `t_hinge`'s off-by-one, the nine-phase transition table, the six budget rows, the two mark conditions, the tick-row clamp, the surface parity set, the dead-law step 0, the six transcript metrics, the reveal totals in both motion modes, and each of the seven named edge cases.
- [ ] `DECISIONS.md` carries this epic's entries: the double-salt resolution on `seed ^ Mode.drift.salt`; `adjudicating` read as the declaration hold rather than the probe beat; two **strikes** rather than two declarations in DRIFT; D7's pair reading in contextual bands; the anchor pair's exemptions; whether L₂ is held to G8's proximity clause (with the measured fallback rate that decided it); the two unspecified reveal durations and the tokens they were taken from; the §7.2-versus-band-2 reading; and the rule that an undefined `t_evidence` emits no Flexibility sample.
- [ ] The PR is merged with every check green, and `main` is pulled before E13 begins.
