# E19 — Accessibility

| | |
|---|---|
| **id** | E19 |
| **title** | Accessibility |
| **branch** | `epic/E19-accessibility` |
| **depends on** | E18 (which itself carries E01–E17) |
| **gate** | §13.12's 13 gates green with a `tests.json` entry each · `performAccessibilityAudit` clean on every screen of §12.2's inventory · the `LawNarrator` parity test passes for 10,000 generated laws · the AX5 × 5-locale snapshot shows zero truncation, zero horizontal overflow and every target ≥ 44 × 44 pt |
| **tasks** | 11 |
| **status** | not started |

---

## Goal

When this epic merges, HUNCH is playable **without sight**. Every drawn mark that carries state is an
accessibility element with a stable label, a live value and the right trait, across all eighteen
screens of §12.2 — and every mark that carries none is `.accessibilityHidden(true)` *explicitly*, so
that "unlabelled" and "deliberately silent" stop looking identical in a diff. The 256 glyphs speak as
one localized format string with four interpolations in canonical order. A law speaks as **one
sentence**, built in `HunchCore` as a value tree and rendered from the same String Catalog fragments
the Codex page renders from, so a narrated law and a rendered law are the same law in two media — and
proved so by walking 10,000 generated laws. The 256-cell Assay speaks its sixteen marginals as one
interruptible announcement instead of 256 swipes. Four rotors, a Magic Tap that fires the thing the
player came to do, and a two-finger scrub that closes what is open, cut a full band-5 declaration from
twenty-two gestures to sixteen.

And the settings the system already knows about are honoured rather than tolerated: art scales with
the type multiplier to its ceiling and then re-flows instead of shrinking, `minimumScaleFactor` is 1.0
everywhere so rows grow and nothing truncates, every target is at least 44 × 44 pt inside the thumb
arc, Reduce Transparency kills the shader and the bloom, Bold Text steps every stroke, Differentiate
Without Colour adds a fourth redundant copy of a distinction that was never colour to begin with, and
High Contrast collapses all four hues onto one ink while lengthening the index stroke that then has to
carry the entire hue channel alone.

That closes §14.3's phase 7 and every ACCESSIBILITY row of §14.1.

## Why now

Accessibility is last in phase 7 and not first, for one mechanical reason: **it labels things, and the
things must exist.** An element map written against a screen that has not been drawn is a promise; the
same map written against eighteen shipped screens is a diff. Concretely:

- **E18 must land first.** Every label, value, hint, action name, rotor name and announcement in this
  epic is a String Catalog key, and §12.9 budgets exactly 134 of them inside a hard 250-key ceiling.
  E18 shipped the catalog, the twelve languages and the one accessor that carries the resolved bundle
  and locale; this epic spends the budget and wires the accessors. A label written before `Loc` exists
  is a bare literal, which is extracted, bypasses the override, and stays English until the next cold
  launch (§12.9 trap 1).
- **E19 is the last gate before E20 can archive.** §13.12's thirteen gates are pre-release gates. Four
  of them are manual (3, 5, 6, 12) and three of those test VoiceOver's *own* gesture layer, which no
  harness can synthesise — so they are scripts a person runs on a device, and they need to exist before
  the polish epic starts scheduling device time. Gate 12 (haptics face-down) is the one this epic
  defers, because the haptic patterns are E20·T05's.
- **The narration is the only place a law appears in words, and it is audio-only.** That claim is only
  true if it is enforced by test at the moment it is written. Deferring it to E20 would mean writing
  the parity invariant against a `LawNarrator` that had already been used for a fortnight.

## Scope

| In | Out — and who owns it |
|---|---|
| Element identity: labels, values, traits, custom actions, and the explicit `.accessibilityHidden(true)` on every silent mark, across all 18 screens | The **drawings** those modifiers attach to — `hunch-glyph-renderer`, `hunch-shared-marks`, `hunch-bench-instruments`, `hunch-chrome-and-meta` components, all shipped in **E04, E08, E09, E13–E17** |
| `loc.glyphLabel(_:relativeTo:detail:)`, the plural-aware pips unit, the terse enumeration | The `Localizable.xcstrings` entries themselves, the twelve translations, and the ≤ 250-key CI assertion — **E18·T01/T03/T08** |
| `Narration` in `HunchCore`, `loc.narration(_:)` in `HunchUI`, the 10,000-law parity invariant | `LawNode`, `LawTable`, RNF and `BenchLayout` — **E05·T01/T02/T04**, **E06·T03**; the Codex page's rendering — **E15·T05** |
| The Assay's `accessibilityValue` (the on-screen **slice**) and "Read by attribute" over sixteen marginals | The Assay drawing, the pin, the ghost scrubber and the band-4 evidence overlay — **E09·T05/T06**; the marginal projection used by Codex thumbnails — **E15·T03** |
| Four rotors, Magic Tap ×2, escape ×2, the `.headings` rotor, `Announcer`, the three reveal announcements | The reveal beat sheets and their cue points — **E09·T10**; the verdict beat — **E08·T06**; the gesture-inventory lint on the Bench — **E09·T03** |
| The Dynamic Type **threshold table** and its assertions; the `minimumScaleFactor` ban as a lint | Each re-flow's own geometry — the Bench pager **E09·T02**, ECHO's tray **E13·T05**, the Codex grid **E15·T04**, the mode rack **E17·T03**, the Profile stat block and vertex sigils **E16·T08/T09** |
| The targets-and-reach audit over the shipped layout constants, and the two undo-shaped exceptions | The layout constants themselves — **E08·T02**, **E09·T01**, **E13·T05**, **E14·T02**, **E17·T03** |
| Applying Reduce Transparency, Bold Text and Differentiate Without Colour at every component that honours them | `RenderEnv`, the resolution order, the derived predicates and the token arithmetic — **E03·T03/T04/T05** |
| Applying the High Contrast theme and re-proving 256-glyph distinguishability under it | The palette, the ratios and `check-tokens.swift` — **E03·T01/T05**; the greyscale distinctness harness and constant `T` — **E04·T06** |
| SIEVE's `.stepped` pacing, the gate's single element and "Admit" action, ECHO's pool and primer strips, nudge suppression **wiring and assertion** | `SieveSchedule` and the speed curve — **E14·T01**; the steady-stream toggle — **E14·T09**; ECHO's pool, primer and cast — **E13·T01/T03/T04**; the nudge scheduler — **E10·T08** |
| `HunchUITests/AccessibilityAuditTests.swift`, the screen list, the AX5 × 5-locale plan configuration, hygiene check 11, all 13 `tests.json` entries | The CI workflow and the three test plans — **E01·T07**; `check-source-hygiene.sh` itself — **E01·T06** (this epic *appends* check 11) |
| Gates 3, 5, 6 as written manual scripts, run and recorded | Gate 9 (Reduce Motion) — **E09·T12 / E14·T10** · gate 11 (audio session) — **E20·T04** · gate 12 (haptics face-down) — **E20·T05/T12**, three testers · gate 13 (banned lexemes) — **E18·T08 / E20·T11** |
| The three VOICEOVER preferences **consumed** (`voiceOverDetail`, `announceVerdicts`, `announceAssay`) | Those three Settings rows as UI and as `UserDefaults` keys — **E17·T07** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The VoiceOver element map](T01-voiceover-element-map.md) | P0 | L | — | Every control labelled, valued and traited across all 18 screens; `accessibilityRespondsToUserInteraction` on the barred Seal; every silent mark explicitly hidden; no empty and no duplicated label |
| T02 | [The glyph label](T02-glyph-label.md) | P0 | S | T01 | One format string, four interpolations in `fill → shape → pips → hue`, pips its own plural-aware entry, terse joined by the locale's list grammar; 256 labels non-empty and pairwise distinct |
| T03 | [`LawNarrator`](T03-law-narrator.md) | P0 | L | T02 | `Narration` as a value tree in `HunchCore`, rendered by `loc.narration(_:)`; only the player's draft or an already-revealed law; parity over 10,000 generated laws |
| T04 | ["Read by attribute"](T04-read-by-attribute.md) | P1 | M | T03 | Sixteen marginals as one interruptible announcement instead of 256 cells; the Assay's value pinned to the on-screen slice, never the unconditional projection |
| T05 | [Rotors, Magic Tap, escape and announcements](T05-rotors-magic-tap-and-announcements.md) | P0 | M | T01 | Four rotors with Counterexample conditional on a strike; Magic Tap = Probe / Seal; escape ×2; `.high` announcements in the order verdict → evidence → bookkeeping; the reveal's three at 640 / 1,450 / 1,850 ms with tap-to-skip off |
| T06 | [Dynamic Type](T06-dynamic-type.md) | P0 | M | T05 | Art to the 1.35× ceiling then frozen; every re-flow at its ruled threshold; `minimumScaleFactor` 1.0 everywhere, enforced by a lint |
| T07 | [Targets and reach](T07-targets-and-reach.md) | P0 | M | T06 | ≥ 44 × 44 with the smallest shipped 56 × 44, ≥ 8 pt apart, three reach tiers on both devices, everything above y = 220 read-only or undo-shaped with a same-effect route inside the arc |
| T08 | [System settings](T08-system-settings.md) | P1 | M | T07 | Reduce Transparency, Bold Text and Differentiate Without Colour applied at every component that honours them, through the derived predicates and never through a raw flag |
| T09 | [The High Contrast theme](T09-high-contrast-theme.md) | P0 | M | T08 | Four hues onto `stroke.primary`, index stroke `0.273·S → 0.409·S`, shader off, +0.5 pt strokes, unlit cells at 40 % with a 2 pt hatch — and all 256 glyphs still distinguishable |
| T10 | [SIEVE and ECHO accessibility](T10-sieve-and-echo-accessibility.md) | P0 | M | T05 | `.stepped` pacing at 0.75 g/s with no ramp and no Tempo sample; the gate as one element with an "Admit" action; ECHO's pool and primer strips; nudges suppressed under VoiceOver |
| T11 | [The §13.12 checklist and the CI audit](T11-checklist-and-ci-audit.md) | P0 | M | T10 | All 13 gates green with a `tests.json` entry each; `performAccessibilityAudit` across every §12.2 screen; the AX5 × 5-locale plan configuration; hygiene check 11; the manual gates run and recorded |

T11 nominally depends on T10 and really depends on all ten: it is the epic's closing gate and cannot
be started until every other task's assertion exists to be recorded.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E19-accessibility

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E19-accessibility
gh pr create --title "E19 — Accessibility" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E20 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, never disable, skip or weaken a check to reach green, and never remove a
`tests.json` entry to make a build pass (§14.1, VERIFICATION). An audit `issueHandler` that returns
`true` suppresses the issue (`07 B46`) — turning one on to reach green is the same offence as deleting
the test, and hygiene check 11 greps for it.

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side host suites are green | `swift test --package-path Modules` |
| 3 | **Gate 7 — the narration matches the rendered tiles for 10,000 generated laws** | `swift test --package-path HunchCore --filter NarrationParityTests` (8 bands × `Corpora.narrationLawsPerBand`) |
| 4 | **Gate 4 — every interactive element has a non-empty, non-duplicated label, and `performAccessibilityAudit` is clean on every screen of §12.2's inventory** | `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Nightly -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -only-testing:HunchUITests/AccessibilityAuditTests` — 18 audit methods over 17 audited screens, `LaunchSurface` excluded and recorded as such |
| 5 | **Gate 8 — AX5 × {en, de, tr, ru, ar}: zero truncation, zero horizontal overflow, every target ≥ 44 × 44 pt** | `xcodebuild test … -testPlan Prerelease` with one configuration per locale plus the two pseudolanguages; five locales × two directions = ten runs |
| 6 | **Gate 10 — High Contrast: the state-bearing set clears its floor, the primary pair clears 21 : 1, hue is index-stroke-only, and all 256 glyphs remain pairwise distinguishable** | `swift test --package-path Modules --filter HighContrastTests` + `--filter GreyscaleDistinctnessTests` re-run at `theme: .highContrast` |
| 7 | Hygiene is green, including check 11 | `Scripts/check-source-hygiene.sh` — exactly 2 Magic Tap handlers, exactly 2 escape handlers, exactly 4 rotors, no `accessibilitySortPriority`, no `{ _ in true }` in `HunchUITests`, no bare literal inside any `.accessibility*` modifier, no `.combine` on a play surface, no `minimumScaleFactor` anywhere |
| 8 | **Gates 3, 5 and 6 have been run on a device and recorded** | `PROGRESS.md` §Accessibility carries a dated entry with the build number for each: the curtain-on band-5 round played end to end in sixteen gestures; Magic Tap and escape; the four rotors with Counterexample absent before the first strike and present with exactly two stops after it |
| 9 | Gates 1, 2, 9, 11, 12 and 13 are present in `tests.json` pointing at their **owning** epic's test, not re-implemented here | `Scripts/check-tests-json.sh` and a read of the thirteen entries |
| 10 | All thirteen §13.12 gates have a `tests.json` entry with a `command` that actually runs | `Scripts/check-tests-json.sh` plus running each entry's `command` |

## Definition of done

- [ ] All eleven task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `swift test --package-path Modules` green; `Presubmission`, `Nightly` and `Prerelease` plans green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green with check 11 present, and each of its counts demonstrated to fail on a deliberately planted violation (a fifth rotor, a deleted Magic Tap, a third escape, a bare literal label) before being reverted.
- [ ] `tests.json` carries **thirteen** entries, one per §13.12 gate, each with `source: "§13.12 gate N"`, an owning task or epic, and a runnable `command`. No entry is `pending` except gate 12, which names E20·T12 as its owner and its three testers.
- [ ] `PROGRESS.md` §Accessibility records the manual passes for gates 3, 5 and 6 with a build number and a date, per `audit-in-ci.md` §6.
- [ ] `DECISIONS.md` carries this epic's ten entries, each naming the two sources it reconciles:

  | Entry | Task | Reconciles |
  |---|---|---|
  | The `ElementIndex` fixture proves the vocabulary; the audit proves the wiring | T01 | a test fixture that could become a second source of truth |
  | The pips plural entry spells the numeral as a word | T02 | §13.10's `"1 pip"/"3 pips"` against its own *"three pips"* |
  | The shipped type is `Narration`, not `LawNarrator` — plus the corpus-sharing mitigation if the budget fires | T03 | §14.1's row name against `08 §3`'s `N26`/`N14` |
  | "Read by attribute" posts at `.default`, so a verdict at `.high` interrupts it | T04 | §13.10's *interruptible* against §13.10's fixed announcement order |
  | The reveal posts **three** announcements at 640 / 1,450 / 1,850 ms | T05 | §6.8 and §6.11 row 26 against the skill's "announced once, at settle" |
  | The second Magic Tap lives on the shared commit-bar Seal, not on `BenchView` literally | T05 | ECHO's commit against check 11c's count of exactly 2 |
  | The re-flows engage at `.accessibility2`; vertex sigils and Codex rows at `.accessibility3` | T06 | §12.8's ladder against §13.11's "above AX2" and its AX3–AX5 heading |
  | All five L1 weights respond to Bold Text; eligibility is refused at L2 by five named components | T08 | `dimensions-strokes-opacity.md` §1 against `environment-settings.md` §3 |
  | The High Contrast state-bearing floor is the measured **9.68**, which §13.11's "9.7" rounds | T09 | §13.11's stated ratio against the recomputed one |
  | `.stepped` beats `.steady` when both are live, while the 0.85 multiplier stays a property of the *setting* | T10 | §9.8's "scoring is identical" against §9.8's 0.85 multiplier |

  Plus, if either fires: a shipped component moved to clear a reach tier (T07), and the `LaunchSurface`
  audit exclusion with any audit issue accepted rather than fixed (T11).
- [ ] Every ACCESSIBILITY row of §14.1 is closed, and the two VERIFICATION rows (`Accessibility checklist`, `tests.json`) are green.
- [ ] The PR is merged with every check green, and `main` is pulled before E20 begins.
