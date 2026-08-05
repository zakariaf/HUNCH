# E15 — The Codex

| | |
|---|---|
| **id** | E15 |
| **title** | The Codex |
| **branch** | `epic/E15-codex` |
| **depends on** | E14 (which itself carries E01–E13) |
| **gate** | Opening a shelf parses **exactly one** shelf file and no single file on disk exceeds 512 KB · a duplicate re-inscribes in place and **never** mints a second page · the eight shelf counts and their fill arcs agree with `codex-index.json` · thumbnails are extension-derived and therefore **collision-free** across a seeded page corpus |
| **tasks** | 9 |
| **status** | not started |

---

## Goal

When this epic merges, everything the player has found is a place they can go. `codex-index.json`
becomes the resident, launch-time dedup authority — the only Codex file parsed at launch — and the
eight shelf files are parsed one at a time, on the shelf that is opened and no other. Above that sits
a browse hierarchy that is **textless by construction**: band → skeleton → canonical key, eight 64 pt
shelf plates each carrying a family sigil, a fill arc and its four most recent thumbnails; a
five-column grid of 60 pt extension constellations with skeleton dividers and a rail scrubber that
snaps to sections rather than to pixels; and a page that renders one law in the same rule-tile
grammar the player declared it with, at 0.78×, over that law's own Assay and an instrument strip.

A page is identified by its extension and by nothing else, so the archive **only grows**: finding a
law a second time re-inscribes the page in place, improves its bests, takes one re-strike ring and
heals its fracture if the find was clean; an ECHO round settled at three marks burnishes it and
touches exactly two fields. Three shelves (`|H| ≤ 512`) draw every law as a permanent socket and can
be sealed; five accrete behind a log-scaled arc. There is no global meter anywhere, and there is no
word on any of it above the page's instrument strip.

## Why now

§14.3's phase 6 opens here because the Codex is what three earlier systems have been writing into
without being able to read back. E09·T11 has been minting pages since the first correct declaration,
E13·T01's echo pool is *defined* as "the last 8 inscribed Codex laws", and §9.10 gates DRIFT, ECHO
and SIEVE on archive evidence — a band-≥ 3 page, five pages, eight pages. Until this epic those are
counts in a file nobody can look at.

- **E16 cannot start without it.** The Anomaly page carries the doubled-rim seal this epic draws, and
  §11.6 says the Anomaly "feeds the Codex fully"; the Profile's five axes are the *other* reading of
  the same round records.
- **E17's `NavigationDepthTests` needs three real screens.** §12.3: *"Exactly one path is three deep,
  and it is the Codex"* — root → shelf → page. The ≤ 2-tap rule survives only because each of those
  three carries a play key, and there is nothing to walk until the three exist.
- **It is the last epic that can still discover a persistence problem cheaply.** `08 §7.5` rules that
  the shard boundary is what keeps `04 A40`'s "plain JSON under ~1000 records" ruling true for a
  27,015-page archive, and that the boundary *"needs an assertion, not a comment"*. That assertion is
  T01's, and it is worth failing now rather than in E20.

## Scope

| In | Out — and who owns it |
|---|---|
| `@MainActor @Observable final class Codex` in `CodexFeature`: lazy per-shelf loading, the resident index, quarantine and rebuild-by-scan, and the one-file-per-open assertion | `CodexPage`, `RoundRecord`, `Profile`, `AnomalyLedger` as core `Codable` values — **E07·T09**. `PersistenceStore`, `StoreFile`, atomic writes and the write order — **E07·T01/T02** |
| `CodexIndex` as a core value type, and `Codex` as its single writer | `CodexPage.init(minting:)` / `reinscribe(…)` / `RestrikeRings` and the t = 0 round-end write sequence — **E09·T11**. This epic re-points that call site at `Codex.inscribe(_:)` and adds nothing to the round |
| Taxonomy (band → skeleton → canonical key), `CodexRootView`, `CodexShelfView`, `CodexPageView`, the shelf plate, the extension thumbnail, the skeleton divider, the facet bar | `Route`, the `Router`, the play key's *destination* and the ≤ 2-tap graph walk — **E17·T01/T02**. Each screen here exposes the play-key slot and takes its action as an injected closure |
| The eight `family.*` sigils, their skeleton detail level, `SigilCatalogue` and `SigilRenderer` | The four `mode.*` sigils — **E12·T05 / E17·T04**; the five `profile.*` vertex sigils — **E16·T09**. If `Sigil.swift` does not exist yet, T09 creates it and those epics extend it |
| Duplicates, fracture healing and burnish **as archive-level invariants and as renders** | The ECHO round that *causes* a burnish, its 3-mark condition and `modesSeen` — **E13·T08**; this epic ships the `Codex.burnish(lawKey:)` seam it calls |
| Slot maps versus accretion, the `\|H\| ≤ 512` threshold, the fill arc's scale and notches | The serving layer's soft-avoid, which uses the same threshold — **E11·T06**. `ArcMeter.draw` itself — **E04·T08** |
| The five facet stamps and their predicate composition | The 16 renderings of `facet.attributes` are one drawing with one state parameter, not sixteen sigils — `codex-facet-stamps.md` §3 |
| `LawTable.marginal()` and the four-level density quantisation, because the thumbnail needs them and they are pure | `AssayCanvas` itself — **E09·T05**. The thumbnail *calls* the grid; it never draws a second 16 × 16 |
| The Codex's VoiceOver contract at the six budgeted labels (root 6, shelf 3) | The element map across all 18 screens, the rotor set and the announcement order — **E19·T01/T05**; `LawNarrator`, whose sentence is a thumbnail's label — **E19·T03**. Until it exists, the label closure is `Unimplemented` |
| 5 → 2 columns at AX2+, and the rule that a thumbnail is a picture and never scales | The full Dynamic Type pass across every screen — **E19·T06** |
| The Inscription → page shared-element arrival as a *receiving* geometry | The reveal's beats, durations and cue points — **E09·T10**; the transition's Reduce Motion substitution row — **E20·T08** |

## The task list

Execution order is top to bottom. `deps` are task ids inside this epic.

| # | Task | P | Size | Deps | Summary |
|---|---|---|---|---|---|
| T01 | [The `Codex` observable](T01-the-codex-observable.md) | P0 | M | — | `@MainActor @Observable final class Codex` in `CodexFeature`, `CodexIndex` in core; lazy per-shelf loading that caches the `Task` and not the value; quarantine and rebuild-by-scan; the one-file-per-shelf-open and 512 KB assertions |
| T02 | [Taxonomy and `CodexRootView`](T02-taxonomy-and-codex-root-view.md) | P0 | M | T01 | `CanonicalKey`, `CodexTaxonomy` and `ShelfSection` in core; eight 64 pt plates with a 44 pt family sigil, a 3 pt fill arc and four 40 pt recents; one dashed plate when the Codex is empty |
| T09 | [The eight family sigils and the skeleton silhouettes](T09-family-sigils-and-skeleton-silhouettes.md) | P0 | M | T02 | One drawing at two detail levels, cleared through the distinctness harness, transcribed into `SigilCatalogue` and frozen by the `--json` parity fixture |
| T03 | [Extension thumbnails](T03-extension-thumbnails.md) | P0 | M | T02 | The 16 × 16 constellation in `glyphID` order at 3.5 pt; contextual laws project to four ink densities reusing the fill ladder; fracture notch, anomaly rim, dashed empty slot; collision-freeness proved over a seeded corpus |
| T04 | [`CodexShelfView`](T04-codex-shelf-view.md) | P0 | M | T03 | Five columns of 60 pt with 10 pt gutters, skeleton dividers, and a rail scrubber that snaps to skeleton sections; 5 → 2 columns at AX2+; faceting dims in place and never reflows |
| T05 | [`CodexPageView`](T05-codex-page-view.md) | P0 | L | T04 | Rule-tiles at `C.RuleTile.codexScale` laid out by `BenchLayout(law)`; the law's Assay at 9.5 pt with a draggable ghost; the eight-element instrument strip; the find log; horizontal swipe through empty slots; screenshot-clean |
| T06 | [Duplicates, fracture and burnish](T06-duplicates-fracture-and-burnish.md) | P1 | M | T05 | Page count is the count of distinct lawKeys, always; the re-strike ring capped at 5+; a clean re-find heals a fracture; a burnish sets exactly two fields and draws no ring |
| T07 | [Slot maps versus accretion shelves](T07-slot-maps-versus-accretion-shelves.md) | P1 | M | T06 | `ShelfKind` from `Band.population ≤ 512`; every law a permanent socket on bands 1, 3 and 8; the log-scaled arc with its six notches on the other five; no global meter anywhere |
| T08 | [The facet bar](T08-the-facet-bar.md) | P2 | M | T07 | Five 44 pt stamps composing one predicate: mode cycling four sigils plus off, unfractured-only, anomaly-only, attribute participation, 3-marks-only |

**On T09's position.** It depends on T02 because T02 fixes the sites the sigil is drawn at, but it is
executed third, immediately after T02, because the plate has nothing to draw until it lands. T02
therefore composes `SigilRenderer.draw(.family(band), …)` and asserts the *call*; T09 ships the
drawing and the parity fixture that freezes it.

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E15-codex

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
git push -u origin epic/E15-codex
gh pr create --title "E15 — The Codex" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start E16 until this PR is merged.** If a check fails, fix it on the same branch and push
again; never merge red, and never disable, skip or weaken a check to reach green. A `tests.json`
entry is never removed or weakened to make a build pass (§14.1, VERIFICATION).

## The gate

Every one of these must be true, and each names the command that proves it, before the PR may merge.

| # | Must be true | Proved by |
|---|---|---|
| 1 | The fast suite is green and still inside its budget | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]` |
| 2 | The app-side suites are green | `swift test --package-path Modules --filter CodexFeatureTests` **and** `xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'` |
| 3 | **Opening a shelf parses exactly one shelf file** — and opening it twice parses none | `swift test --package-path Modules --filter ShelfLoadingTests` — `RecordingPersistenceStore` asserts the exact `[StoreFile]` read sequence for launch, first open, second open and a cross-band open |
| 4 | **No single file on disk exceeds 512 KB**, and the crossover page count is recorded rather than assumed | `swift test --package-path HunchCore --filter ShelfSizeBudgetTests` — the v1 fixture, the §11.4 completion corpus, and the computed crossover written into `DECISIONS.md` |
| 5 | **A duplicate never mints a second page** | `swift test --package-path Modules --filter DuplicateInscriptionTests` — over a seeded find sequence with repeats, `codex.pageCount == Set(finds.map(\.lawKey)).count` at every step, with the shelf resident and with it not |
| 6 | **The eight shelf counts and their fill arcs agree with `codex-index.json`** | `swift test --package-path Modules --filter ShelfCountAgreementTests` — for every band, `plate.arcValue == index.count(band) == shelf(band).pages.count` after a scripted corpus is inscribed and the app is "relaunched" against the same store |
| 7 | **Thumbnails are extension-derived and collision-free** | `swift test --package-path HunchCore --filter ThumbnailSignatureTests` — over `Corpora.lawsPerBand` seeded laws per band, distinct `LawTable` ⇒ distinct signature and equal `LawTable` ⇒ equal signature |
| 8 | The eight family sigils clear the distinctness harness and the Swift has not forked from it | `node .claude/skills/hunch-sigil-drawing/scripts/check-sigil-distinctness.js` (exit 0) **and** `swift test --package-path HunchCore --filter SigilCatalogueTests` **and** the `--json` freshness diff in CI |
| 9 | Hygiene is green, including the check this epic adds | `Scripts/check-source-hygiene.sh` — check 13 (no global completion meter: no view sums `Band.allCases.map(\.population)` and no string, numeral or arc is drawn against 27,015) |
| 10 | The Codex is textless above the page's instrument strip | `swift test --package-path Modules --filter CodexTextlessTests` + the source lint: `Text`/`Label`/`AttributedString` appear in `CodexFeature` only inside `CodexPageView`'s strip and inside `.accessibility*` modifiers |

## Definition of done

- [ ] All nine task files are `Status: done`, each with its own commit.
- [ ] `swift test --package-path HunchCore` green in under 10 s; `Presubmission.xctestplan` green in the simulator.
- [ ] `Scripts/check-source-hygiene.sh` green, with check 13 present and demonstrated to fail on a deliberately planted global meter before being reverted.
- [ ] `tests.json` carries a live entry for every invariant this epic ships: one-file-per-shelf-open, the 512 KB budget and its crossover, index rebuild-by-scan, shelf quarantine, canonical-key stability, thumbnail collision-freeness, the four-level projection ladder, the scrubber's section snapping, 5 → 2 columns at AX2, page-count invariance under duplicates, fracture healing, the burnish's exactly-two-fields, slot-map membership, arc scale selection, no global meter, and the sigil parity fixture.
- [ ] `DECISIONS.md` carries this epic's six entries: `Codex` as the single writer of `codex-index.json` and the eight shelves (the `04 A45`/`A42` hand-rolled-notification side, which `A45` asks be recorded in the README as well); the 512 KB budget's crossover page count and the schema-v2 sharding trigger; the lawKey-collision policy (index hit ⇒ load the shelf and compare the RNF); the 40 pt thumbnail's cell side, resolving `assay-grid.md` §1 against `extension-thumbnail.md` §1; the facet bar pinned to the safe-area bottom rather than to `y 624`; and `ExtensionThumbnail` composing `AssayCanvas` rather than drawing a second 16 × 16 grid.
- [ ] `PROGRESS.md` records a simulator walk: Frame → Codex root → a shelf → a page → swipe to an empty slot → back, with the `RecordingPersistenceStore` read log for the same sequence pasted beside it.
- [ ] The PR is merged with every check green, and `main` is pulled before E16 begins.
