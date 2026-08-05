# E16 — The Anomaly, the Profile and Statistics

| | |
|---|---|
| **id** | E16 |
| **title** | The Anomaly, the Profile and Statistics |
| **branch** | `epic/E16-anomaly-profile` |
| **depends on** | E15 (which itself carries E01–E14) |
| **gate** | Two devices set to the same UTC date produce the identical Anomaly law, asserted from `utcDayIndex` through `generate` · no reset path alters `anomaly.json` or `anomaly.hw` · `.clockBehind` locks and unlocks exactly at `highWaterDay + 1` · every axis sample is monotone, so a strictly better transcript never yields a smaller sample · a uniform rise across all five axes leaves the contour pixel-identical |
| **tasks** | 11 |
| **status** | not started |

---

## Goal

When this epic merges the game has a **today** and a **shape**.

*Today* is the Anomaly: one law per UTC day, identical for every player on Earth, derived with zero
server from an integer day index, a frozen salt and a SplitMix64 finaliser, and served through the
same five-argument generator every other round uses with `avoid: []`. It is protected by the
high-water rule — a monotone `highWaterDay` that no reset can touch, a `.clockBehind` lock that
makes moving the clock back strictly worse than doing nothing, and jump detection that is only ever
allowed to refuse to *shorten* a lock. It grants the full palette and the Assay evidence overlay for
that round and reverts them, and it is invisible to the Rasch estimator: θ, `reach`, `relief`,
`winStreak`, `consecutiveLosses` and `maxBandEverServed` are all bit-identical with and without it.

*The shape* is the Profile: five axes with one normative sample formula each, oriented so that more
is always more of the thing the vertex is named for, updated by a single Robbins–Monro rule in which
`value` never decays and confidence does; drawn as a closed Catmull–Rom spline whose radii are
normalised against the player's own five-axis mean, so a uniform rise is pixel-identical and only
asymmetry is visible. Five vertex sigils carry the axes' identity without their names existing
anywhere a translator or a player can reach. And `StatisticsView` is the one screen where numbers
are allowed to live — five sections, nineteen labelled rows, read-only, with no θ, no band framed as
a level, no percentile and no statistic about attendance of any kind.

## Why now

§14.3 puts the Codex, the Anomaly/Profile and the Frame in phase 6, and the internal order inside
that phase is forced:

- **The Anomaly cannot be built before E15.** An Anomaly round inscribes a Codex page like any other
  round (§11.6), the Anomaly shelf sorts by probes used, and `CodexPageView`'s instrument strip
  carries the anomaly seal. Every one of those is E15's.
- **The Profile cannot be built before E11–E14.** Four of the five axes are fed by transcript
  quantities the mode epics own and nothing else does — `R` from DRIFT (§7.8), `hit`/`A`/`order`
  from ECHO (§8.7), gate-entry-to-tap latency from SIEVE (§9.6). §11.9 is explicitly the *only*
  place those become samples; writing it earlier would mean writing it against quantities that did
  not exist yet, which is exactly how five axes ended up with three spellings.
- **E17 cannot start without it.** The Frame's Anomaly key carries the 24-segment rollover arc and
  the streak ring, and the Frame's shelf carries the Profile key — both are E17·T03, and both need
  the values this epic defines. The Settings → DATA reset alerts (E17·T08) need `Reset Profile` to
  have a `profile.json` to reset and need the Anomaly's reset immunity to already be a shipped test.
- **The Anomaly is the one thing in the app that two devices must agree about**, and it is the only
  place in the codebase where a spelling variant (`(seed >> 32) % 4` for `seed % 4`) is not a style
  question but a wrong answer. It gets its own golden fixture, in this epic, before anything reads
  it.

## Scope

| In | Out — and who owns it |
|---|---|
| `utcDayIndex`, `ANOMALY_SALT`, `anomalySeed(day:)`, the band draw, the jitter draw, `targetδ`, and the call into `generate(… avoid: [])` | `generate` itself, G1–G10, `SplitMix64` and the determinism harness — **E06·T05/T06/T10**, **E01·T05** |
| `AnomalyLedger`, `DayEntry`, `MonotonicAnchor`, the high-water rule, `.clockBehind`, jump detection, the streak/tally/longestStreak arithmetic | The `PersistenceStore` protocol, `StoreFile.anomaly`, atomic writes and the `anomaly.hw` sidecar mechanics — **E07·T01/T02/T09**. The five reset *actions* — **E17·T08**; E07·T06 already asserts immunity and this epic extends that assertion to the real ledger |
| The bookkeeping table that makes an Anomaly round invisible to the ladder, and the palette/overlay grants and their reversion | `Ability`, `AbilityEstimator`, the 13-step serving policy, `reach`/`relief`/`π₀` and H14's harness run — **E11·T01–T05, T12**. The palette ceiling rule itself — **E09·T04**; the Assay evidence overlay drawing — **E09·T06** |
| `AnomalyView`: the 28-cell ribbon, tally numeral, streak ring, rollover arc, `.clockBehind` ring, tap-a-past-cell reveal; and the Inscription's appended anomaly strip | `InscriptionView` itself and the reveal beat sheets — **E09·T10/T11**. The Frame's Anomaly key — **E17·T03/T04** |
| The five axis sample formulas, the update rule, the idle confidence decay, and the Restraint margin's `H_live` count | The transcript quantities the samples read — **E12·T07** (`R`), **E13·T08** (`hit`, `A`, `order`), **E14·T05** (latency, window). The lower-band index the margin reads — **E05·T07** |
| Profile geometry (mean-normalised radii, closed Catmull–Rom spline), tremble, the 2.4 s morph, the 90-day ghost, the five vertex sigils | The token layer every value resolves through — **E03·T02/T03/T04**. The shared marks the sigils quote — **E04·T07/T08**. The eight family sigils — **E15·T09** |
| `StatisticsView` — five sections, nineteen labelled rows, read-only | Every destructive action, all five reset alerts, and the DATA section — **E17·T08**. The stock-`Form` container neutralisation is `HunchUI`'s and is **E17·T06**'s to create if it does not exist yet; T11 here consumes it |
| Creating the `MetaFeature` target and `MetaFeatureTests` in `Modules/Package.swift` | Everything else that lands in `MetaFeature` later — `FrameView`, `SettingsView`, `AboutView`, `ResetConfirmAlert` — **E17** |
| The five approved VoiceOver sentences as the vertex labels, and the axis-identifier catalog ban as a hygiene check | The whole VoiceOver element map, rotors, announcements and the CI audit — **E19**. The catalog's ≤ 250-key budget and the banned-lexeme test — **E18·T01/T08** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic. T05 has no dependency on
T01–T04 and may be started in parallel by a second engineer; nothing else may be reordered.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [Anomaly derivation](T01-anomaly-derivation.md) | P0 | M | — | `utcDayIndex` with floor semantics and no `Calendar`/`Locale`/`TimeZone`, the frozen `ANOMALY_SALT`, the SplitMix64 finaliser, `band = 4 + Int(seed % 4)` on the low bits, the ±0.05 jitter, `generate(… avoid: [])`, and a 512-day golden fixture written by a separate process |
| T02 | [The ledger and the high-water rule](T02-ledger-and-high-water-rule.md) | P0 | L | T01 | `AnomalyLedger` with a monotone `highWaterDay`, 400 capped entries, tally/streak/longestStreak, `MonotonicAnchor`; playable iff `observed == highWaterDay` with no settled entry; clock-forward burns days permanently, clock-back enters a **sticky** `.clockBehind` released only at `highWaterDay + 1`; jump detection refuses only to shorten a lock; reset immunity asserted against `Fixtures/v1/` |
| T03 | [Grants and isolation](T03-grants-and-isolation.md) | P0 | M | T02 | The full palette and the Assay overlay for that round only, with `maxBandEverServed` untouched; one exhaustive bookkeeping table proving θ, `reach`, `relief`, `winStreak` and `consecutiveLosses` are all bit-identical with 400 Anomaly rounds injected; Codex fed fully, Profile at 0.5 weight, no Induction loss-sample |
| T04 | [`AnomalyView`](T04-anomaly-view.md) | P1 | M | T03 | The 28-cell ribbon with its six render states, the tally as the headline numeral and the streak as a secondary ring, the 24-segment rollover arc, the `.clockBehind` static ring, tap-a-past-cell reveal regenerated for free from `anomalySeed(day:)`, and the Inscription's appended anomaly strip. Creates the `MetaFeature` target |
| T05 | [The five Profile axes](T05-five-profile-axes.md) | P0 | L | — | One normative sample formula per axis with direction fixed by the geometry — Tempo samples `par/probes` — plus a shipped monotonicity test per axis |
| T06 | [The Profile update rule](T06-profile-update-rule.md) | P0 | M | T05 | `value += α·(sample − value)`, `α = w·max(0.06, 1/(n+1))`, `n` capped at 60; no decay of `value` at all; confidence decays as `n = max(4, n·0.5^(daysIdle/60))` |
| T07 | [The Restraint margin](T07-restraint-margin.md) | P1 | M | T06 | `H_live` as the laws in the band's materialised set still consistent with the whole ribbon at declaration time, drawn from the lower-band index, skipped at bands 5 and 7, ≈50 µs at band 4 once per declaration |
| T08 | [Profile geometry](T08-profile-geometry.md) | P0 | M | T06 | Five vertices at `−90° + i·72°`, radii mean-normalised so a uniform rise is pixel-identical, a closed Catmull–Rom spline converted to cubic Bézier rather than a polygon, no gridlines, rings, ticks, axis labels or numerals |
| T09 | [Vertex sigils](T09-vertex-sigils.md) | P0 | M | T08 | Five vector marks drawn from the existing vocabulary at their own locked vertex angles, the axis identifiers absent from the app and from the catalog in any form, reflowing from a ring to a vertical list at AX3 keeping 44 × 44 hit rects |
| T10 | [Tremble, morph and the 90-day ghost](T10-tremble-morph-and-ghost.md) | P1 | M | T09 | Vertex noise amplitude falling as `n` rises, a 2.4 s staggered spring on entering the Profile screen and never during play and never at round end, and the 90-day ghost at 12 % opacity, dashed, unlabelled and self-to-self |
| T11 | [`StatisticsView`](T11-statistics-view.md) | P1 | M | T10 | Five sections and 19 labelled rows, read-only, mono numerals, every value formatted through `Date.FormatStyle` / `NumberFormatter` / `Measurement`; no θ, no difficulty, no band-as-level, no percentile, no attendance statistic |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E16-anomaly-profile

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E16-anomaly-profile
gh pr create --title "E16 — The Anomaly, the Profile and Statistics" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E17 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, never disable, skip or weaken a check to reach green, and never remove or
soften a `tests.json` entry to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green | `swift test --package-path Modules` **and** `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |
| 3 | **Two devices set to the same UTC date produce the identical Anomaly law**, asserted from `utcDayIndex` all the way through `generate` | `swift test --package-path HunchCore --filter AnomalyDerivationTests` — including the 512-day golden `ArchiveTests/Fixtures/anomaly-days-v1.json` written by a separate `swift run` process on a different day, and the macOS exit test as the second opinion |
| 4 | **No reset path alters `anomaly.json` or `anomaly.hw`** | `swift test --package-path HunchCore --filter ResetImmunityTests` — all five §11.13 actions run against a copy of `Fixtures/v1/`, both files compared byte-for-byte |
| 5 | **`.clockBehind` locks and unlocks exactly at `highWaterDay + 1`** | `swift test --package-path HunchCore --filter AnomalyLedgerTests` — the three boundary cases `observed = highWaterDay − 1`, `= highWaterDay`, `= highWaterDay + 1`, plus the sticky-lock case that proves returning the clock to `highWaterDay` does **not** release it |
| 6 | **Every axis sample is monotone** — a strictly better transcript never yields a smaller sample | `swift test --package-path HunchCore --filter ProfileAxisTests` — one parameterised monotonicity test per axis, five in total |
| 7 | **A uniform rise across all five axes leaves the contour pixel-identical** | `swift test --package-path HunchCore --filter ProfileGeometryTests` — `uniformRiseLeavesTheShapeIdentical`, radii compared with `isApproximatelyEqual(_:_:absoluteTolerance: 1e-9)` |
| 8 | The axis identifiers exist nowhere a translator or a player can reach | `Scripts/check-source-hygiene.sh` check 13: zero case-insensitive hits for `induction`, `retention`, `flexibility`, `restraint` or `tempo` anywhere in `Modules/Sources/HunchUI/Resources/Localizable.xcstrings`, and zero `Text(`/`Label(` sites naming them |
| 9 | The Statistics screen contains no forbidden quantity | `Scripts/check-source-hygiene.sh` check 14: zero references to `ability`, `theta`, `difficulty`, `percentile`, `band.rawValue` as a rendered value, or any session/date/launch counter, in `StatisticsView.swift` |
| 10 | The Profile never appears at round end | `swift test --package-path Modules --filter ProfileVisibilityTests` — `ProfileContour` and `Profile` are unreachable from `InscriptionView`'s view graph, asserted as a source lint over the Inscription's imports and body |
| 11 | Hygiene and the catalog budget are green | `Scripts/check-source-hygiene.sh` (checks 1–14) — including check 8's `keyCount <= 250` with this epic's Statistics and Profile keys added |

## Definition of done

- [ ] All eleven task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with checks 13 and 14 present and each demonstrated to fail on a deliberately planted violation before being reverted.
- [ ] `ArchiveTests/Fixtures/anomaly-days-v1.json` is committed, was produced by a separate `swift run` invocation, and is never regenerated to make a build pass.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/` carries a populated `anomaly.json` and `anomaly.hw`, and `profile.json` with five axes and a ghost, and all five reset actions still leave the two anomaly files byte-identical.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: day-index floor semantics, salt identity, the low-bits band draw and its variant-spelling guard, jitter range, cross-process day-to-law identity, high-water monotonicity, playability, sticky `.clockBehind`, jump-refusal, reset immunity, the bookkeeping table, θ bit-identity under 400 injected Anomaly rounds, the five sample formulas, the five monotonicity properties, the update rule and its idle decay, `H_live` skipping at bands 5 and 7, mean-normalised pixel identity, sigil distinctness, the axis-name absence, and the Statistics forbidden-quantity list.
- [ ] `DECISIONS.md` carries this epic's five entries: the sticky reading of `.clockBehind` and the additive `lockedThroughDay` field; `bootID` derived from `KERN_BOOTTIME` rather than `UUID()` so the boundary grep stays clean and the anchor survives relaunch; the ruling that mean-normalised radius arithmetic is core while the spline is `MetaFeature`; the `MetaFeature`/`MetaFeatureTests` targets added to `Modules/Package.swift` ahead of E17; and the Statistics 19-label allocation.
- [ ] `PROGRESS.md` records the two-device check: the same fixed `Now.fixed(date:)` on two simulators of different device idioms produces the same `lawKey`.
- [ ] The PR is merged with every check green, and `main` is pulled before E17 begins.
