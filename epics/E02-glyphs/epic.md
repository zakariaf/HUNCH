# E02 — Glyph vocabulary and the bitboard algebra

| | |
|---|---|
| **id** | E02 |
| **title** | Glyph vocabulary and the bitboard algebra |
| **branch** | `epic/E02-glyphs` |
| **depends on** | E01 (Foundations, bootstrap and CI) |
| **gate** | `Deck.all` is 256 with `glyphID` round-tripping for every one · the lift/tile identities and the `P == lift(P & FULL256)` statelessness test hold · every mask matches a brute-force evaluation over the deck · `MaskTable.resident` measures ≈ 54 KB · the fast suite is still under 10 s |
| **tasks** | 6 |
| **status** | not started |

---

## Goal

When this epic merges, `HunchCore` contains the whole *word-level* vocabulary of the game as data: the 256-glyph deck built from four nested value enums with a stable positional id, the two bitboards (`Bitboard256` over the deck, `Bitboard65536` over ordered pairs) with cross-arity lifting, the ≈54 KB resident mask precompute that every law extension is assembled from, and the four shared value enums (`Verdict`, `Mode`, `Coupler`, `Comparator`) that the AST, the Bench and persistence all spell in `UInt8`. Nothing in it draws, decides, generates or persists — it is the algebra everything later is written in, and it is proved correct against brute force over the real deck rather than asserted.

## Why now

E01 gave the repo a `main`, two packages, a fast-suite budget and CI. E02 is the first epic that puts domain code in `HunchCore`, and it sits immediately after E01 because **every other core epic reads from it and nothing in it reads from anything else**. `Glyphs` is the leaf target of the package graph.

It unblocks, directly:

- **E03 (tokens)** and **E04 (glyph renderer)** — the renderer draws `Glyph.Fill` / `.Shape` / `.Pips` / `.Hue` as four spatially disjoint registers and iterates `Deck.all` for the 256-way distinctness proof. `Glyph.Shape` must already be **nested** or the renderer's first `import SwiftUI` makes `Shape` ambiguous at every use site.
- **E05 (grammar and evaluator)** — `LawTable` *is* a `Bitboard256`/`Bitboard65536`, the evaluator is mask lookups and never an AST walk, `RNF`'s commutative sort key is `(kindOrdinal, attrOrdinal, cmpOrdinal, subsetBitmask)` — three of those four ordinals are frozen here — and equivalence is bit-identity in the common space, which is `lift`.
- **E06 (generator)** — G1/G2/G3 are popcount over `Bitboard256`, G7 is `P != lift(P & FULL256)`, and `generate`'s seed mixing is `seed ^ (band << 32) ^ mode.salt`, so `Mode.salt` must exist and be frozen before the first determinism fixture is written.
- **E07 (persistence)** — `StoreFile.round(Mode)` and the ribbon's `Verdict` need `UInt8` raw values that never move.

Getting any of these wrong later is not a refactor: `glyphID`, the attribute order, the comparator order and `Mode.salt` are all baked into on-disk bytes and into the cross-process determinism golden.

## Scope

| In | Out — and who owns it |
|---|---|
| `struct Glyph` + nested `Fill`, `Shape`, `Pips`, `Hue`, `Attribute`; `id`; `ordinal(of:)` | Drawing any of it — `GlyphShape`, contour pips, fill textures, the index stroke: **E04**. Colour values for `Hue`: **E03**. |
| `enum Deck` — `all`, `glyph(id:)`, canonical order | The spool sheet's grid and the Dial's ramps that *display* the deck: **E08**. |
| `Bitboard256`, `Bitboard65536`, `lift`, row extraction, the statelessness identity | `LawTable`, `Law`, `Metrics`, `admitRate`, the evaluator, RNF, the dedup hash, the band-partitioned `LawIndex`: **E05**. |
| `MaskTable` — 56 atom, 36 relational, 96 × 4 contextual row, 1,214 aggregate masks, resident | Assembling a law's table *from* those masks, and every guardrail that reads one: **E05**, **E06**. |
| `Verdict`, `Mode` (+`salt`, `wordmark`), `Coupler`, `Comparator` (+`flipped`, `complemented`, `matches`) | `Text(verbatim: mode.wordmark)` at a call site: **E17** (Frame) / **E08**. `Band` (the collapsed Band/Family type): **E05·T06**. `LawNode`, which *uses* `Coupler` and `Comparator`: **E05·T01**. |
| The `Laws` target's first file (`MaskTable.swift`) | Every other file in `Laws/`: **E05**. |
| — | `SplitMix64`, `Package.swift`, the eight targets, tags, `Corpora`, `isApproximatelyEqual`, the hygiene script, CI: **E01**. This epic adds **no** manifest entries. |

## The task list — execution order

Work them top to bottom. `T06` runs before `T05` because `MaskTable` needs `Comparator`; the ids follow the plan, the order follows the dependencies.

| # | Task | P | Size | Depends on | One line |
|---|---|---|---|---|---|
| T01 | [Glyph and its four nested enums](T01-glyph-and-its-four-nested-enums.md) | P0 | S | nothing | `struct Glyph` with `Fill`/`Shape`/`Pips`/`Hue`/`Attribute` nested inside it, cases verbatim from §2, and `id = fill*64 + shape*16 + pips*4 + hue`. |
| T02 | [Deck](T02-deck.md) | P0 | S | T01 | Caseless `enum Deck` with `all` as a `static let` of 256 index-aligned glyphs and an O(1) `glyph(id:)`, round-trip asserted for all 256. |
| T03 | [Bitboard256](T03-bitboard256.md) | P0 | M | T01 | 4 × `UInt64` over the deck: popcount, set/test, complement, and the three combinators `&` `\|` `^`, plus the ≈20 ns build / ≈5 ns compare budgets measured and recorded. |
| T04 | [Bitboard65536 and cross-arity lifting](T04-bitboard65536-and-lifting.md) | P0 | M | T03 | 1024 × `UInt64` indexed `prev*256 + cur`, `lift` as a word-aligned scatter, comparison at the larger arity, and `P == lift(P & FULL256)`. |
| T06 | [Shared value enums](T06-shared-value-enums.md) | P0 | S | T01 | `Verdict`, `Mode` (+ the frozen `salt` and the untranslated `wordmark`), `Coupler`, `Comparator` (+ `flipped`, `complemented`, `matches`) — all `UInt8`-backed and `Sendable`. |
| T05 | [MaskTable — the 54 KB resident precompute](T05-masktable-resident-precompute.md) | P0 | L | T04, T06 | 1,690 masks built once as `MaskTable.resident`, every one checked entry by entry against a brute-force walk over `Deck.all`. |

## The git workflow

```bash
# 1. start from an up-to-date main
git checkout main && git pull
git checkout -b epic/E02-glyphs

# 2. work the tasks IN ORDER, committing per task
#    (each task ends with /simplify, then /code-review, then a commit)

# 3. push and open the PR
#    write this epic's summary into .github/pr-body.md (the template E01 committed) first
git push -u origin epic/E02-glyphs
gh pr create --title "E02 — Glyph vocabulary and the bitboard algebra" --body-file .github/pr-body.md

# 4. WAIT for pipelines. Do not merge on a pending or failing check.
gh pr checks --watch

# 5. merge only when every check is green
gh pr merge --squash --delete-branch

# 6. only now move to the next epic
git checkout main && git pull
```

**Do not start the next epic until this PR is merged.** E03 and E04 both branch from a `main` that contains `Glyph`, `Deck` and `Bitboard256`; branching earlier means resolving this epic's files by hand in two other branches. If a check fails, fix it **on this branch** and push again. Never merge red, and never disable, skip or weaken a check to get green — the hygiene greps and the 10-second budget check are the two things E01 exists to install.

## The gate

Every one of these must be true, and each line is the command that proves it. Run them from the repo root on the epic branch, immediately before `gh pr create`.

| # | What must be true | Proof |
|---|---|---|
| 1 | `Deck.all` is 256 glyphs, pairwise distinct, index-aligned with `id`, in canonical `fill → shape → pips → hue` order | `swift test --package-path HunchCore --filter DeckTests` — 256 parameterised round-trip cases green |
| 2 | `glyphID` round-trips for every one of the 256 | same suite: `Deck.glyph(id: g.id) == g` for all `g in Deck.all` |
| 3 | The lift/tile identities hold — `lift` is injective, a homomorphism over `&`, `\|`, `^`, `~`, and `lift(t).row(after: p) == t` for every `p` | `swift test --package-path HunchCore --filter Bitboard65536Tests` |
| 4 | `P == lift(P & FULL256)` answers statelessness both ways: true for every lifted table, false for a genuinely contextual one | same suite: `isStateless` cases green |
| 5 | Every mask in `MaskTable.resident` equals a brute-force evaluation over `Deck.all` — all 56 + 36 + 384 + 1,204 + 10 = **1,690** | `swift test --package-path HunchCore --filter MaskTableTests` |
| 6 | `MaskTable.resident` measures ≈ 54 KB | same suite: `byteCount == 54_080` (1,690 × 32 B), and the five per-class counts asserted individually |
| 7 | The fast suite is still under 10 s | `START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ] && echo OK` |
| 8 | No source-hygiene regression | `Scripts/check-source-hygiene.sh` exits 0 |
| 9 | `tests.json` carries an entry for each of 1–6 with status `pass`, and nothing was removed or weakened | `git diff main -- tests.json` reviewed by eye |

## Definition of done

- [ ] All six task files are worked, each ending in its own commit with the `E02/T0n:` prefix.
- [ ] `HunchCore/Sources/Glyphs/` contains `Glyph.swift`, `Deck.swift`, `Bitboard.swift`, `Verdict.swift`, `Mode.swift`, `Coupler.swift`, `Comparator.swift` and nothing else.
- [ ] `HunchCore/Sources/Laws/` contains `MaskTable.swift` and nothing else (E05 fills the rest).
- [ ] No file in this epic imports anything but `Swift` and `Foundation`; `Scripts/check-source-hygiene.sh` and `hunch-swift-code`'s `check-boundary.sh --all` both pass.
- [ ] Nothing in `HunchCore/Sources/` added by this epic is a `class`, an `actor`, a `static var`, or carries `@unchecked Sendable` — the two shared values (`Deck.all`, `MaskTable.resident`) are `static let` of immutable `Sendable` values, rung 1 of `05 R50`.
- [ ] All nine gate rows pass on the branch.
- [ ] `DECISIONS.md` records the four decisions this epic makes that the spec does not fix: `Glyph.Attribute` nested rather than top-level; `Glyph.id` as the Swift spelling of §2's `glyphID`; `Mode.salt` as the big-endian ASCII packing of the wordmark; and `PARITY` taken over **ranks 1…4**, not ordinals.
- [ ] `PROGRESS.md` names the epic, the merge commit and the measured build/compare figures from T03.
- [ ] The PR is merged with every check green, and the branch is deleted.
