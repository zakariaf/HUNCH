# T01 — Anomaly derivation

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | nothing |
| **Delivers** | Derivation (ANOMALY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Rules that `enum Anomaly` is a caseless namespace in `HunchCore/Sources/Archive/Anomaly.swift`, and — the load-bearing part here — its boundary predicate is what forbids `Date()` inside the derivation. `utcDayIndex` takes a `TimeInterval` *handed in*; the ambient clock never enters the core. It also owns the "no `Calendar`, `Locale` or `TimeZone`" grep this task adds. |
| `hunch-swift-testing` | This is invariant 4 in its table — determinism across runs **and processes** — and the whole point of the task is that the assertion must be against bytes written by a different process on a different day. The skill owns the golden-fixture pattern, the macOS exit test as the cheap second opinion, and the ban on `@testable import`. |

## Objective

At the end of this task the day's law exists as a pure function of one integer: `Anomaly.dayIndex(_:)`
turns a `TimeInterval` into a UTC day index with floor semantics and no calendar of any kind, and
`Anomaly.law(day:)` turns that index into a `LawNode` through the frozen salt, the SplitMix64
finaliser, a band drawn from the low bits, a ±0.05 jitter and the ordinary five-argument generator
with `avoid: []`. A committed 512-day golden fixture, written by a separate process, proves two
devices set to the same UTC date get the same law.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.6 | **the single normative derivation.** `utcDayIndex`, `ANOMALY_SALT`, `anomalySeed(day:)`, `band`, `jitter`, `targetδ`, the `generate(… avoid: [])` call, and the two decisions (always PROBE; never feeds θ) |
| `GAME_DESIGN.md` | §10.6 | states the same constants and **cites** §11.6 rather than restating them — read it to confirm nothing here contradicts it, and never take a number from it |
| `GAME_DESIGN.md` | §5.3 | `generate(seed:band:targetδ:mode:avoid:)`'s purity clause — the reason `avoid: []` is the whole of "G9 is disabled" |
| `GAME_DESIGN.md` | §5.7 | the eight bands' δ ranges, `par` and `cap`; the band the Anomaly draws is an ordinary band and takes the band table's own numbers |
| `GAME_DESIGN.md` | §11.7 | the Anomaly is always PROBE at the band's own par and cap — 32, 37, 37 or 42 for bands 4–7, never one number |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §2, §3 | `Archive/Anomaly.swift`'s path, the boundary predicate, `enum Anomaly` caseless with `dayIndex(_:)` and `seed(day:)` |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | invariant 4: same-process comparison **plus** a committed golden fixture **plus** the macOS exit test |
| `ios-swift-guide/06-TESTING.md` | T4, T30, T42, T49 | plain `import`; tag on both axes; never assert a golden order out of an RNG except where identity *is* the property; exit tests |

Never restate a constant from §11.6 in this file, in a comment or in a second Swift file. There is
one derivation and it lives in `Anomaly.swift`.

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/AnomalyDerivationTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Glyphs
import Laws
import LawGeneration
import HunchTestSupport

@Suite("Anomaly derivation — §11.6's single normative block", .tags(.unit, .presubmission))
struct AnomalyDerivationTests {

    // MARK: - utcDayIndex, floor semantics

    @Test("day 0 is the whole of 1970-01-01Z, and the boundary belongs to the next day")
    func dayZeroIsAWholeDay() {
        #expect(Anomaly.dayIndex(0) == 0)
        #expect(Anomaly.dayIndex(86_399) == 0)
        #expect(Anomaly.dayIndex(86_399.999) == 0)
        #expect(Anomaly.dayIndex(86_400) == 1)
    }

    @Test("negative time floors, it does not truncate toward zero")
    func negativeTimeFloors() {
        #expect(Anomaly.dayIndex(-1) == -1)          // 1969-12-31T23:59:59Z
        #expect(Anomaly.dayIndex(-0.5) == -1)        // fractional, still 1969-12-31
        #expect(Anomaly.dayIndex(-86_400) == -1)     // 1969-12-31T00:00:00Z
        #expect(Anomaly.dayIndex(-86_401) == -2)     // 1969-12-30T23:59:59Z
    }

    /// 2026-07-30T00:00:00Z. Verify independently with `date -u -r 1785369600`.
    @Test("a known UTC instant maps to a known day index")
    func knownInstant() {
        #expect(Anomaly.dayIndex(1_785_369_600) == 20_664)
        #expect(Anomaly.dayIndex(1_785_369_600 + 86_399) == 20_664)
        #expect(Anomaly.dayIndex(1_785_369_600 + 86_400) == 20_665)
    }

    @Test("the day index agrees with a UTC Gregorian calendar for 4,000 consecutive days",
          arguments: [0, 10_957, 18_262, 20_664])
    func agreesWithAUtcCalendar(_ start: Int64) {
        // The oracle lives in the TEST only. `Calendar` may not appear under HunchCore/Sources.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = start + 1_000
        let t = TimeInterval(day) * 86_400
        let components = utc.dateComponents([.year, .month, .day],
                                            from: Date(timeIntervalSince1970: t))
        let midnight = utc.date(from: components)!
        #expect(Anomaly.dayIndex(midnight.timeIntervalSince1970) == day)
        #expect(Anomaly.dayIndex(t + 86_399.5) == day)
    }

    // MARK: - the salt and the finaliser

    @Test("ANOMALY_SALT spells HUNCHANO and is frozen forever")
    func saltIsFrozen() {
        let bytes = withUnsafeBytes(of: Anomaly.salt.bigEndian) { Array($0) }
        #expect(String(decoding: bytes, as: UTF8.self) == "HUNCHANO")
    }

    @Test("anomalySeed is the SplitMix64 FINALISER applied to day + salt, not a SplitMix64 draw")
    func seedIsTheFinaliserNotADraw() {
        let day: Int64 = 20_664
        var rng = SplitMix64(seed: UInt64(bitPattern: day) &+ Anomaly.salt)
        // next() adds the gamma before finalising; the Anomaly seed does not.
        #expect(Anomaly.seed(day: day) != rng.next())
    }

    @Test("the seed is a pure function of the day and avalanches: adjacent days share no low nibble pattern")
    func seedAvalanches() {
        #expect(Anomaly.seed(day: 20_664) == Anomaly.seed(day: 20_664))
        let a = Anomaly.seed(day: 20_664), b = Anomaly.seed(day: 20_665)
        #expect((a ^ b).nonzeroBitCount > 20)      // one flipped input bit moves ~half the output
    }

    // MARK: - the band draw

    @Test("the band is 4…7 for every day in a four-thousand-day window")
    func bandIsAlwaysFourToSeven() {
        let bands = (20_000..<24_000).map { Anomaly.parameters(day: Int64($0)).band }
        #expect(bands.allSatisfy { (4...7).contains($0.rawValue) })
    }

    @Test("the four bands are drawn near-uniformly — the low bits are already avalanched")
    func bandIsNearUniform() {
        var counts = [Band: Int]()
        for day in 20_000..<24_000 {
            counts[Anomaly.parameters(day: Int64(day)).band, default: 0] += 1
        }
        #expect(counts.count == 4)
        #expect(counts.values.allSatisfy { $0 > 900 })    // 1,000 ± 10 % over 4,000 draws
    }

    /// §11.6: "any variant spelling (`(seed >> 32) % 4`) selects a different band from the same day
    /// and is therefore wrong, not merely different." This test is the guard on that sentence.
    @Test("the high-bits spelling picks a different band on at least one day in a 64-day window")
    func theSpellingIsLoadBearing() {
        let disagreements = (20_664..<20_728).filter { day in
            let seed = Anomaly.seed(day: Int64(day))
            return seed % 4 != (seed >> 32) % 4
        }
        #expect(!disagreements.isEmpty)
    }

    // MARK: - jitter and targetδ

    @Test("jitter is drawn from the NEXT SplitMix64 draw and spans exactly [−0.050, +0.050]")
    func jitterRangeAndResolution() {
        let jitters = (20_000..<24_000).map { Anomaly.parameters(day: Int64($0)).jitter }
        #expect(jitters.allSatisfy { $0 >= -0.05 - 1e-12 && $0 <= 0.05 + 1e-12 })
        #expect(Set(jitters.map { Int(($0 * 10_000).rounded()) }).count > 900)   // ≈1001 values
        #expect(jitters.contains { $0 < -0.045 })
        #expect(jitters.contains { $0 > 0.045 })
    }

    @Test("targetδ is the band centre plus jitter and never leaves its own band")
    func targetDeltaStaysInsideItsBand() {
        for day in 20_000..<24_000 {
            let p = Anomaly.parameters(day: Int64(day))
            guard p.band.difficultyRange.contains(p.targetDelta) else {
                Issue.record("day \(day): targetδ \(p.targetDelta) escaped band \(p.band.rawValue)")
                return
            }
        }
    }

    // MARK: - the law

    @Test("the law is a pure function of the day, byte-identical when generated twice")
    func lawIsPureInTheDay() {
        let a = LawTable(Anomaly.law(day: 20_664))
        let b = LawTable(Anomaly.law(day: 20_664))
        #expect(a == b)
    }

    @Test("the law is always PROBE and is served at the band's own par and cap (§11.7)")
    func alwaysProbeAtTheBandsOwnPar() {
        let p = Anomaly.parameters(day: 20_664)
        #expect(p.mode == .probe)
        #expect(p.par == p.band.par)
        #expect(p.cap == p.band.cap)
    }

    /// G9 is disabled *by construction*: there is no `avoid` parameter to pass, and the day's law
    /// therefore never depends on the player. Assert the API shape, not a behaviour.
    @Test("nothing in the Anomaly surface accepts a novelty set")
    func noAvoidParameterExists() {
        // Compiles iff the signatures are exactly these — the assertion is the type, not the value.
        let byDay: (Int64) -> LawNode = Anomaly.law(day:)
        let params: (Int64) -> Anomaly.Parameters = Anomaly.parameters(day:)
        #expect(LawTable(byDay(20_664)) == LawTable(Anomaly.law(day: params(20_664).day)))
    }

    // MARK: - the cross-process golden

    @Test("512 consecutive days match the committed golden written by a separate process")
    func matchesTheCommittedGolden() throws {
        let url = try #require(Bundle.module.url(forResource: "anomaly-days-v1",
                                                 withExtension: "json",
                                                 subdirectory: "Fixtures"))
        let golden = try JSONDecoder().decode([AnomalyGoldenRow].self,
                                              from: try Data(contentsOf: url))
        #expect(golden.count == 512)
        for row in golden {
            let p = Anomaly.parameters(day: row.day)
            let key = LawTable(Anomaly.law(day: row.day)).key
            guard p.band.rawValue == row.band,
                  p.targetDelta.bitPattern == row.targetDeltaBits,
                  key == row.lawKey else {
                Issue.record("day \(row.day) diverged from the golden — reproduce with Anomaly.parameters(day: \(row.day))")
                return
            }
        }
    }
}

/// The golden's row shape. Written by `Tools/AnomalyGolden`, read here, never regenerated to make
/// a build pass. `targetDeltaBits` is the raw `Double` bit pattern because the claim is bit
/// identity, not approximate agreement.
struct AnomalyGoldenRow: Codable, Sendable {
    let day: Int64
    let band: Int
    let targetDeltaBits: UInt64
    let lawKey: UInt64
}
```

And the second opinion, `HunchCore/Tests/ArchiveTests/AnomalyExitTests.swift`:

```swift
import Foundation
import Testing
import Archive
import Laws

@Suite("Anomaly determinism, in a second process", .tags(.unit, .presubmission))
struct AnomalyExitTests {
    @Test("a fresh process derives the same law for the same day")
    func freshProcessAgrees() async throws {
        let expected = LawTable(Anomaly.law(day: 20_664)).key
        await #expect(processExitsWith: .success) {
            let actual = LawTable(Anomaly.law(day: 20_664)).key
            precondition(actual == expected, "day 20664 diverged across processes")
        }
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter AnomalyDerivationTests`
Confirm the failures are missing symbols (`Anomaly.dayIndex`, `Anomaly.salt`, `Anomaly.seed`,
`Anomaly.parameters`, `Anomaly.law`) and a missing fixture, not a malformed test. In particular, a
test that passes before `Anomaly.swift` exists means the suite is not selecting it.

**Step 3 — implement** the minimum that turns it green. Files listed below.

**Step 4 — green, then refactor** with the test as the safety net.

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/Anomaly.swift` |
| create | `HunchCore/Tests/ArchiveTests/AnomalyDerivationTests.swift` |
| create | `HunchCore/Tests/ArchiveTests/AnomalyExitTests.swift` |
| create | `HunchCore/Tests/ArchiveTests/Fixtures/anomaly-days-v1.json` (generated, committed) |
| create | `Tools/AnomalyGolden/main.swift` + its `Package.swift` product entry |
| modify | `HunchCore/Package.swift` — the `Archive` target's `dependencies:` (`Glyphs`, `Laws`, `LawGeneration`) and `ArchiveTests`' `resources: [.copy("Fixtures")]` |
| modify | `Scripts/check-source-hygiene.sh` — append check 13's first clause: no `Calendar`, `Locale` or `TimeZone` under `HunchCore/Sources/` |
| modify | `tests.json` — six entries |
| modify | `SPEC.md` — add `ANOMALY_SALT` and the derivation order to §5.7's locked-constants echo |

## Implementation notes

### The namespace

```swift
/// §11.6's single normative derivation. Nothing else in the codebase derives an Anomaly.
public enum Anomaly {

    /// "HUNCHANO" — frozen forever. Changing this byte changes every past and future daily.
    public static let salt: UInt64 = 0x48_55_4E_43_48_41_4E_4F

    /// Days since 1970-01-01T00:00:00Z, floor semantics.
    /// - Important: no `Calendar`, no `Locale`, no `TimeZone`. See §11.6.
    public static func dayIndex(_ t: TimeInterval) -> Int64

    /// SplitMix64's *finaliser*, applied once to `day &+ salt`. Not a `SplitMix64` draw.
    public static func seed(day: Int64) -> UInt64

    public struct Parameters: Equatable, Sendable {
        public let day: Int64
        public let seed: UInt64
        public let band: Band
        public let jitter: Double
        public let targetDelta: Double
        public let mode: Mode        // always .probe
        public var par: Int { band.par }
        public var cap: Int { band.cap }
    }

    public static func parameters(day: Int64) -> Parameters
    public static func law(day: Int64) -> LawNode
}
```

Five points that are the whole task.

1. **`dayIndex` uses `t.rounded(.down)` before the integer division, and a branch for negatives.**
   `Int64(t)` truncates toward zero, which is wrong for `-0.5`; `s / 86_400` truncates toward zero,
   which is wrong for every pre-1970 second. §11.6 writes both halves; copy the shape, not a
   simplification of it. Pre-1970 will never arise from a real device clock, and that is exactly why
   it must be right: it is the branch nobody will exercise by hand.
2. **`Calendar`, `Locale` and `TimeZone` are the whole point of the no-formatting rule.** A device on
   the Buddhist calendar, or an `ar-SA` default, silently returns a different day. There is no
   formatting step anywhere in this derivation and the hygiene grep makes that mechanical.
3. **`seed(day:)` is the finaliser, not `SplitMix64.next()`.** `SplitMix64.next()` advances state by
   the Weyl gamma *first* and then finalises; §11.6's `anomalySeed` finalises `day &+ salt` directly.
   The two differ, `seedIsTheFinaliserNotADraw` pins it, and reusing `SplitMix64` here to "avoid
   duplication" would silently change every daily forever. Duplicating three lines is correct.
4. **`band = 4 + Int(seed % 4)` reads the low bits, deliberately.** The finaliser's last step is
   `z ^ (z >> 31)`, so the low word is already avalanched and no shift is needed. Any other slice is
   a different band for the same day. The `theSpellingIsLoadBearing` test is the reason this comment
   is a test rather than a comment.
5. **The jitter is the *next* draw.** `var rng = SplitMix64(seed: seed); let jitter = Double(rng.next() % 1001) / 10_000.0 - 0.05`.
   `% 1001` gives 1,001 values inclusive of both endpoints; `% 1000` would be off by one at the top
   and is the mistake this test catches.

`law(day:)` is then one line: the five-argument generator, mode `.probe`, `avoid: []`. **Do not add
an `avoid` parameter, not even defaulted.** §11.6 is explicit that the empty novelty set is exactly
how G9 is disabled — an optional parameter would make a player-dependent Anomaly representable, and
the type system is the cheapest place to make it not.

### `Band` from an `Int`

`band = 4 + Int(seed % 4)` produces 4…7 in the design's 1-based numbering, and `Band` is
`Int`-raw-valued from 1 (`08 §3`). Construct it with `Band(rawValue:)!` behind a `precondition`, or
better, index `Band.allCases[3 + Int(seed % 4)]`. Either is fine; what is not fine is a second
mapping table between §11.6's numbers and `Band`'s cases.

### The golden fixture and the tool

`Tools/AnomalyGolden` is a tiny `swift run` executable that prints 512 rows of
`(day, band, targetDeltaBits, lawKey)` starting at a day index it takes on the command line, as
sorted-keys pretty JSON. Run it **once**, on a different day from the test being written, and commit
the output:

```bash
swift run --package-path Tools/AnomalyGolden anomaly-golden 20664 > \
  HunchCore/Tests/ArchiveTests/Fixtures/anomaly-days-v1.json
```

This is `08 §5`'s determinism pattern, and it is the same shape E06·T10 already established for
`determinism-seeds-v1.json` — reuse that tool's `JSONEncoder(outputFormatting: [.sortedKeys, .prettyPrinted])`
configuration rather than writing a second one. **The fixture is never regenerated to make a build
pass.** If it diverges, the derivation changed and the derivation is wrong.

`resources: [.copy("Fixtures")]` means every lookup passes `subdirectory: "Fixtures"` — this is
where fixture suites die (`06 T54`), and `ArchiveTests` is the second target in the repo to hit it.

### Why the exit test is worth its five lines

The golden proves agreement with a past process. The exit test proves agreement with a *concurrent*
one, on macOS, for free, because `HunchCore` is host-testable. Neither replaces the other: a bug
that captured process-global state would pass the golden and fail the exit test.

### What "two devices, same UTC date" means as an executable claim

There is no second device in the test suite, so the claim is decomposed into three facts, each
separately asserted above: the day index is a function of the instant alone (no calendar, no locale,
no timezone — `agreesWithAUtcCalendar`); the parameters are a function of the day alone
(`lawIsPureInTheDay`, `noAvoidParameterExists`); and the law is a function of the parameters alone
across processes (`matchesTheCommittedGolden`, `freshProcessAgrees`). E16's gate additionally records
a manual two-simulator run in `PROGRESS.md`, but the three facts are what CI holds.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter AnomalyDerivationTests` green, all fourteen tests.
- [ ] `swift test --package-path HunchCore --filter AnomalyExitTests` green on macOS.
- [ ] `grep -rn "Calendar\|Locale\|TimeZone\|DateFormatter" HunchCore/Sources/` returns nothing, and `Scripts/check-source-hygiene.sh` fails when a `Calendar` reference is deliberately planted in `Anomaly.swift` and passes once removed.
- [ ] `grep -n "avoid" HunchCore/Sources/Archive/Anomaly.swift` shows the literal empty set at the single `generate` call site and nowhere else — no parameter, no default, no stored property.
- [ ] `HunchCore/Tests/ArchiveTests/Fixtures/anomaly-days-v1.json` is committed, is 512 rows, and its git blame shows a commit distinct from the one that adds `AnomalyDerivationTests.swift`.
- [ ] `tests.json` carries six entries: day-index floor semantics, salt identity, finaliser-not-a-draw, the low-bits band draw with its variant-spelling guard, jitter range and resolution, and the 512-day cross-process golden.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes replacing the three finaliser lines with a `SplitMix64` call, reject it and point at `seedIsTheFinaliserNotADraw`.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T01: Anomaly derivation — day index, frozen salt, finaliser, band, jitter, law"`

## Out of scope

- The ledger, `highWaterDay`, playability and `.clockBehind` — **T02**.
- Which day is "today" at runtime, and the `Now` that supplies the `TimeInterval` — **E10·T01** owns `Now`; **T02** consumes it.
- Anything about how the Anomaly round is *served*, scored or bookkept — **T03**.
- Drawing the ribbon, the tally or the rollover arc — **T04**.
- `generate`, the guardrails and the 10,000-law suite — **E06**.
