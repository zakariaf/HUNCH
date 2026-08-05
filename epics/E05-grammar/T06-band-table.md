# T06 — Band, the collapsed Band/Family type

| | |
|---|---|
| **Epic** | E05 — Grammar, evaluator and equivalence |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | Band table |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | It owns this exact collapse — "band **and** family → one `enum Band`", because §5.3 puts them in bijection and `Family(band)` is an identity function that will drift (`W28`). It also carries the compile gotcha this task will hit in its first minute: **`enum Band: Int, CaseIterable, Comparable, Sendable` does not compile** — a raw type suppresses SE-0266's synthesized `Comparable`, and `08 §3` states the declaration without the hand-written `<`. |

## Objective

One type, `enum Band`, carries everything §5.2 and §5.4 tabulate: the eight cases named for their families, `par`, `cap`, `population`, `difficultyRange`, `minLeaves` and `admitWindow`. Two words survive in prose; one type ships. The collapse is recorded in `DECISIONS.md` so nobody reintroduces `Family` in E06.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §5.2 | The eight rows: family name, δ range, `\|H\|`, `log₂\|H\|`, exemplar law, `p`, δ. `population` is this table's `\|H\|` column and T08 is what proves it. |
| `GAME_DESIGN.md` | §5.3 | "`family = Family(band)` — **strictly one family per band, no reprises.**" That sentence is the whole justification for the collapse. |
| `GAME_DESIGN.md` | §5.3 | G3's admit-rate window `[0.15, 0.60]`, identical for every band, and its asymmetry argument. |
| `GAME_DESIGN.md` | §5.4 | `par(band) = ceil(k·log₂\|H\| + d)` and `cap(band) = ceil(1.6 × par)`, plus the eight `k` and `d` values and the locked par/cap rows. |
| `GAME_DESIGN.md` | §5.7 | The locked-constants rows: band populations, par, cap, `[0.000, 1.000)` with width 0.125. |
| `GAME_DESIGN.md` | §5.1 | `family.minLeaves`, which `m1` subtracts. The value per family is derived in T02's cross-check and is listed below. |
| `GAME_DESIGN.md` | §10.5 | Difficulty is never a number — which is why `Band` has no `displayName`, no `localizedTitle` and no `rawValue` that ever reaches a `Text`. |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §3 | The one-type ruling and the case list, verbatim. |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/LawGenerationTests/BandTests.swift`:

```swift
import Testing
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Band table", .tags(.unit, .presubmission))
struct BandTests {

    @Test("There are eight bands, one per family, numbered 1…8")
    func inventory() {
        #expect(Band.allCases.count == 8)
        #expect(Band.allCases.map(\.rawValue) == Array(1...8))
        #expect(Band.literal < Band.pair)
        #expect(Band.allCases == Band.allCases.sorted())
    }

    @Test("Par matches §5.7's locked row")
    func par() {
        #expect(Band.allCases.map(\.par) == [7, 13, 16, 20, 23, 23, 26, 29])
    }

    @Test("Cap is computed as ceil(1.6 × par) and matches §5.7's locked row")
    func cap() {
        // GDD §5.4: `cap(band) = ceil(1.6 × par)`. Compute it; do not table it, or the two
        // rows can drift and §5.7 would no longer be one source of truth.
        #expect(Band.allCases.map(\.cap) == [12, 21, 26, 32, 37, 37, 42, 47])
        for band in Band.allCases {
            #expect(band.cap == Int((1.6 * Double(band.par)).rounded(.up)))
        }
    }

    @Test("Population matches §5.2's |H| column and sums to the permanent ceiling")
    func population() {
        #expect(Band.allCases.map(\.population) == [40, 1_272, 108, 2_322, 6_934, 5_688, 10_314, 337])
        #expect(Band.allCases.map(\.population).reduce(0, +) == 27_015)
    }

    @Test("Difficulty ranges tile [0.000, 1.000) at width 0.125 with no gap and no overlap")
    func difficultyRanges() {
        var cursor = 0.0
        for band in Band.allCases {
            expectApproximatelyEqual(band.difficultyRange.lowerBound, cursor, absoluteTolerance: 1e-12)
            expectApproximatelyEqual(band.difficultyRange.upperBound, cursor + 0.125, absoluteTolerance: 1e-12)
            cursor += 0.125
        }
        expectApproximatelyEqual(cursor, 1.0, absoluteTolerance: 1e-12)
    }

    @Test("A band contains its own centre and every §5.2 exemplar's published δ",
          arguments: Corpora.bandExemplars)
    func exemplarsSitInsideTheirBand(_ exemplar: Corpora.BandExemplar) throws {
        let band = try #require(Band(rawValue: exemplar.bandNumber))
        #expect(band.difficultyRange.contains(exemplar.publishedDelta))
        #expect(band.difficultyRange.contains(band.centre))
    }

    @Test("Every band carries the same admit window, and it is asymmetric")
    func admitWindow() {
        // GDD §5.3: `p ∈ [0.15, 0.60]`, deliberately asymmetric, identical in every band.
        for band in Band.allCases {
            expectApproximatelyEqual(band.admitWindow.lowerBound, 0.15, absoluteTolerance: 1e-12)
            expectApproximatelyEqual(band.admitWindow.upperBound, 0.60, absoluteTolerance: 1e-12)
        }
    }

    @Test("Minimum leaves per family")
    func minimumLeaves() {
        // Derived in T02's δ cross-check: these are the only values for which §5.1's m1
        // reproduces all eight of §5.2's published δ figures.
        #expect(Band.allCases.map(\.minLeaves) == [1, 2, 2, 1, 1, 3, 2, 3])
        for band in Band.allCases { #expect(band.minLeaves <= LawNode.maxLeaves) }
    }

    @Test("Bands 5 and 7 are the contextual ones, and nothing else is")
    func contextualBands() {
        #expect(Band.allCases.filter(\.isContextual) == [.contextual, .composite])
    }

    @Test("log₂|H| agrees with the population to two decimals")
    func informationContent() {
        // GDD §5.2's log₂|H| column is a derived quantity; compute it and assert the table.
        let published = [5.32, 10.31, 6.75, 11.18, 12.76, 12.47, 13.33, 8.40]
        for (band, value) in zip(Band.allCases, published) {
            expectApproximatelyEqual(band.informationContent, value, absoluteTolerance: 0.005)
        }
    }

    @Test("Nothing on Band is renderable text")
    func noDisplayString() {
        // GDD §10.5: difficulty is never a number. `Band` must expose no name, title or
        // description that a `Text` could pick up. The grep in the acceptance list is the
        // real gate; this test documents the intent at the definition.
        #expect(Band.self is any CustomStringConvertible.Type == false)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter BandTests`
The first failure is a compile error — `enum Band declares raw type 'Int', preventing synthesized conformance of 'Band' to 'Comparable'`. That is expected; write the `<` by hand. After that the failures are missing members, then wrong numbers.

**Step 3 — implement.**

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/LawGeneration/Band.swift` |
| create | `HunchCore/Tests/LawGenerationTests/BandTests.swift` |
| modify | `HunchCore/Package.swift` — add the `LawGeneration` target (dependencies `Glyphs`, `Laws`) and `LawGenerationTests`, if E01 did not already |
| modify | `DECISIONS.md` — the `Band`/`Family` collapse |
| modify | `SPEC.md` — the eight-row band table as locked constants |
| modify | `tests.json` — "Band table" |

## Implementation notes

### The declaration, with the gotcha already handled

```swift
/// A difficulty band and, because §5.3 fixes strictly one family per band with no reprises,
/// also the law family. Two words in prose; one type in code (`08 §3`, `W28`).
///
/// The raw value is the band number 1…8 and is **never rendered** — §10.5 permits exactly three
/// signals of difficulty and a numeral is not one of them.
public enum Band: Int, CaseIterable, Sendable, Codable {
    case literal = 1, pair, exclusive, relational, contextual, guarded, composite, systemic
}

extension Band: Comparable {
    // A raw type suppresses SE-0266's synthesized `Comparable` (verified on Swift 6.3.3),
    // so the operator is written by hand. `08 §3` states the declaration without it.
    public static func < (lhs: Band, rhs: Band) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

### The members

| Member | Value | Note |
|---|---|---|
| `par: Int` | `7, 13, 16, 20, 23, 23, 26, 29` | §5.7's locked row. Table it — §5.4's `ceil(k·log₂\|H\| + d)` is the *derivation*, and `k`/`d` are design-time priors that the harness may regenerate (§5.4). Put `k` and `d` on the type too, as `frictionCoefficient` and `discoveryCost`, so E11's H12 can re-derive and compare. |
| `cap: Int` | `Int((1.6 * Double(par)).rounded(.up))` | **Computed, never tabled.** Two rows that must agree are one row too many. |
| `population: Int` | `40, 1_272, 108, 2_322, 6_934, 5_688, 10_314, 337` | §5.2's `\|H\|`. T08 is what proves it; this is the declaration it is proved against. |
| `informationContent: Double` | `log2(Double(population))` | §5.2's `log₂\|H\|` column, derived. |
| `difficultyRange: Range<Double>` | `Double(rawValue - 1) * 0.125 ..< Double(rawValue) * 0.125` | Half-open, so `[0.000, 1.000)` tiles exactly (§5.7). |
| `centre: Double` | midpoint | What the generator suite serves as `targetDelta` (`hunch-swift-testing`'s worked example). |
| `admitWindow: ClosedRange<Double>` | `0.15...0.60` | G3, identical in every band (§5.3). It lives on `Band` because that is where callers reach for it, not because it varies. |
| `minLeaves: Int` | `1, 2, 2, 1, 1, 3, 2, 3` | §5.1's `m1` subtrahend. Derived in T02's δ cross-check. |
| `isContextual: Bool` | `self == .contextual \|\| self == .composite` | Bands 5 and 7 — G7's scope, the two contextual hash runs, and the two bands DRIFT and SIEVE treat specially. |

Every one of these is a `switch` over `self` with **no `default:`** (`W29`), so a ninth band — which §14.4 forbids — would break every one of them at compile time rather than silently taking a fallback.

### What `Band` must not gain

- **No display string.** No `description`, no `displayName`, no `localizedName`, no `CustomStringConvertible`. §10.5's three permitted signals are the par row's length, the palette ceiling and the Codex shelves; a band numeral anywhere is the leak. The `tests.json` entry E11 T09 adds greps for exactly this.
- **No `skeletons` yet.** T07 adds `Band.skeletons` in `Skeleton.swift` because it is large and it is the enumeration's business. Leave it out here so this task stays S.
- **No classification.** There is no `Band(classifying: LawNode)`. The generator samples *from* a band's skeletons (§5.3 step 3); nothing in HUNCH ever asks "which band is this arbitrary law?", and an inverse function would be a second source of truth for family membership.
- **No `Family` typealias.** Not even for readability. That is the drift `W28` names, and the whole point of the collapse.

### `DECISIONS.md`

Write the entry now, in this task, with this shape:

> **`Band` and `Family` are one type.** §5.3 fixes "strictly one family per band, no reprises", so the two are in bijection and `Family(band)` would be an identity function that eventually drifts (`W28`, `08 §3`). Both words survive in prose. `enum Band: Int` carries `par`, `cap`, `population`, `difficultyRange`, `minLeaves`, `admitWindow`, `frictionCoefficient` and `discoveryCost`. `Comparable` is hand-written because a raw type suppresses the synthesized conformance.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter BandTests` is green.
- [ ] `Band.allCases.map(\.par)` is `[7, 13, 16, 20, 23, 23, 26, 29]` and `cap` is computed from it, matching `[12, 21, 26, 32, 37, 37, 42, 47]`.
- [ ] `Band.allCases.map(\.population).reduce(0, +) == 27_015`.
- [ ] `Band` has a hand-written `<` and the file carries the one-line comment explaining why.
- [ ] `grep -rn 'enum Family\|typealias Family' HunchCore Modules` returns nothing.
- [ ] `grep -n 'description\|displayName\|CustomStringConvertible' HunchCore/Sources/LawGeneration/Band.swift` returns nothing.
- [ ] `grep -n 'default:' HunchCore/Sources/LawGeneration/Band.swift` returns nothing.
- [ ] `DECISIONS.md` carries the collapse entry above.
- [ ] `SPEC.md` carries the eight-row band table with §5.2 and §5.7 cited.
- [ ] `swift test --package-path HunchCore` still finishes under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E05/T06: Band — the collapsed band/family type"`

## Out of scope

- **`difficulty(of:)` and the Rasch coupling.** E06 T01/T02. `Band` carries the ranges; it does not compute a law's position inside one.
- **Skeleton lists.** T07's `Skeleton.swift` adds `Band.skeletons`.
- **Proving `population`.** T08. This task declares the number; T08 enumerates it.
- **Serving.** Per-mode band clamps (1…8 / 3…8 / 1…8 / 1…7), the quantiser and `targetDelta` derivation are E11 T03.
- **DRIFT's `par_DRIFT` / `cap_DRIFT`.** A separate six-row table in §7.7, owned by E12 T04. Do not fold it into `Band`.
