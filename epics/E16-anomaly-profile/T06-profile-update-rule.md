# T06 — The Profile update rule

| | |
|---|---|
| **Epic** | E16 — The Anomaly, the Profile and Statistics |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T05 |
| **Delivers** | Update rule (PROFILE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | Decides that `Profile` is a `struct … Codable, Sendable` in `HunchCore/Sources/Archive/`, that the update is a `mutating func` on the value rather than a free function or a service, and — the part that matters — that `profile.json`'s shape (§11.13) is the type's storage, so an additive field is a `decodeIfPresent` and never a new file. |

## Objective

At the end of this task the Profile has exactly one update rule and no second one anywhere:
`value += α·(sample − value)` with `α = w · max(0.06, 1/(n+1))` and `n = min(60, n + w)`. `value`
never decays toward anything; confidence does, as `n = max(4, n · 0.5^(daysIdle/60))`, so returning
after a gap makes the portrait *more responsive* rather than *lower*.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §11.9 | the update rule verbatim, the Robbins–Monro justification, the 0.06 floor, the `n ≤ 60` cap, `lastSampleAt`, the idle handling and its reason, and the worked `n = 12 → α = 0.077` |
| `GAME_DESIGN.md` | §11.9 | the decision that **Induction is a mean of settled rounds, not a running maximum**, and why — this rule is what makes that true |
| `GAME_DESIGN.md` | §11.13 | `profile.json`'s row: five `Axis` + `ghost: [Double]` + `ghostTakenAt` + `lastRenderedRadii`, under 1 KB; and the failure row — a corrupt `profile.json` resets to day-1 defaults and affects nothing else |
| `GAME_DESIGN.md` | §11.13 | the reset map's `Reset Profile` row: all `v = 0`, `n = 0`, no ghost |
| `GAME_DESIGN.md` | §10.9 | the *ability* decay it must not be confused with — θ never decays, `n` does, and the Profile's decay is a different constant on a different quantity |
| `GAME_DESIGN.md` | §11.10 | `nᵢ / 24` is what the tremble reads, so the `n` this rule maintains is the confidence the drawing renders |
| `ios-swift-guide/03-WRITING-CODE.md` | W28, W29 | one type for one concept; no `default:` in the axis switch |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/ArchiveTests/ProfileUpdateTests.swift`:

```swift
import Foundation
import Testing
import Archive
import HunchTestSupport

@Suite("The Profile update rule — §11.9's only update rule", .tags(.unit, .presubmission))
struct ProfileUpdateTests {

    private let epoch = Date(timeIntervalSince1970: 1_785_369_600)   // 2026-07-30T00:00:00Z

    // MARK: - α

    @Test("α is w · max(0.06, 1/(n+1)) and reproduces §11.9's worked value")
    func alphaMatchesTheWorkedValue() {
        // §11.9: "With n = 12 and w = 1.0, α = 0.077."
        #expect(isApproximatelyEqual(Profile.alpha(n: 12, weight: 1.0), 0.077, absoluteTolerance: 5e-4))
    }

    @Test("the 0.06 floor binds once n exceeds 15 and the rule never freezes", arguments: [16, 30, 60])
    func floorBinds(_ n: Int) {
        #expect(isApproximatelyEqual(Profile.alpha(n: Double(n), weight: 1.0), 0.06,
                                     absoluteTolerance: 1e-12))
    }

    @Test("α scales linearly with the weight")
    func alphaScalesWithWeight() {
        #expect(isApproximatelyEqual(Profile.alpha(n: 12, weight: 0.5),
                                     0.5 * Profile.alpha(n: 12, weight: 1.0), absoluteTolerance: 1e-12))
    }

    @Test("at n = 0 the rule takes the first sample whole")
    func firstSampleIsTakenWhole() {
        var p = Profile()
        p.apply(AxisSample(axis: .tempo, value: 0.8, weight: 1.0), at: epoch)
        #expect(isApproximatelyEqual(p[.tempo].value, 0.8, absoluteTolerance: 1e-12))   // α = 1.0
        #expect(isApproximatelyEqual(p[.tempo].n, 1.0, absoluteTolerance: 1e-12))
    }

    // MARK: - the update

    @Test("value moves toward the sample by exactly α of the gap")
    func valueMovesByAlphaOfTheGap() {
        var p = Profile()
        p[.restraint] = Axis(value: 0.40, n: 12, lastSampleAt: epoch)
        p.apply(AxisSample(axis: .restraint, value: 0.90, weight: 1.0), at: epoch)
        let alpha = Profile.alpha(n: 12, weight: 1.0)
        #expect(isApproximatelyEqual(p[.restraint].value, 0.40 + alpha * 0.50,
                                     absoluteTolerance: 1e-12))
    }

    @Test("n advances by w and caps at 60")
    func confidenceAdvancesAndCaps() {
        var p = Profile()
        p[.induction] = Axis(value: 0.5, n: 59.6, lastSampleAt: epoch)
        p.apply(AxisSample(axis: .induction, value: 0.5, weight: 1.0), at: epoch)
        #expect(isApproximatelyEqual(p[.induction].n, 60, absoluteTolerance: 1e-12))
        p.apply(AxisSample(axis: .induction, value: 0.5, weight: 1.0), at: epoch)
        #expect(isApproximatelyEqual(p[.induction].n, 60, absoluteTolerance: 1e-12))
    }

    @Test("lastSampleAt is stamped on every applied sample and on no other axis")
    func lastSampleAtIsStamped() {
        var p = Profile()
        let later = epoch.addingTimeInterval(86_400)
        p.apply(AxisSample(axis: .tempo, value: 0.3, weight: 1.0), at: later)
        #expect(p[.tempo].lastSampleAt == later)
        #expect(p[.flexibility].lastSampleAt == nil)
    }

    @Test("a repeated identical sample is a fixed point")
    func repeatedSampleIsAFixedPoint() {
        var p = Profile()
        p[.tempo] = Axis(value: 0.62, n: 30, lastSampleAt: epoch)
        p.apply(AxisSample(axis: .tempo, value: 0.62, weight: 1.0), at: epoch)
        #expect(isApproximatelyEqual(p[.tempo].value, 0.62, absoluteTolerance: 1e-12))
    }

    @Test("the rule converges to the mean of a stationary sample stream — Induction is a MEAN")
    func convergesToTheMean() {
        var p = Profile()
        let stream = [0.2, 0.6, 0.4, 0.8, 0.2, 0.6, 0.4, 0.8]
        for round in 0..<400 {
            p.apply(AxisSample(axis: .induction, value: stream[round % 8], weight: 1.0), at: epoch)
        }
        #expect(isApproximatelyEqual(p[.induction].value, 0.5, absoluteTolerance: 0.06))
    }

    /// §11.9 overrules "highest band cleared": one lucky band-8 clear must not permanently redraw
    /// the portrait.
    @Test("one high sample among many low ones does not ratchet the axis")
    func oneHighSampleDoesNotRatchet() {
        var p = Profile()
        for _ in 0..<60 { p.apply(AxisSample(axis: .induction, value: 0.2, weight: 1.0), at: epoch) }
        let before = p[.induction].value
        p.apply(AxisSample(axis: .induction, value: 1.0, weight: 1.0), at: epoch)
        #expect(p[.induction].value < before + 0.06)
        for _ in 0..<10 { p.apply(AxisSample(axis: .induction, value: 0.2, weight: 1.0), at: epoch) }
        #expect(p[.induction].value < before + 0.02)         // it came back
    }

    // MARK: - the idle rule

    @Test("value does NOT decay, however long the gap", arguments: [1, 30, 90, 365, 3_650])
    func valueNeverDecays(_ daysIdle: Int) {
        var p = Profile()
        p[.restraint] = Axis(value: 0.83, n: 60, lastSampleAt: epoch)
        p.decayConfidence(asOf: epoch.addingTimeInterval(TimeInterval(daysIdle) * 86_400))
        #expect(isApproximatelyEqual(p[.restraint].value, 0.83, absoluteTolerance: 1e-12))
    }

    @Test("confidence halves every 60 idle days and floors at 4")
    func confidenceHalvesAndFloors() {
        var p = Profile()
        p[.restraint] = Axis(value: 0.83, n: 60, lastSampleAt: epoch)
        p.decayConfidence(asOf: epoch.addingTimeInterval(60 * 86_400))
        #expect(isApproximatelyEqual(p[.restraint].n, 30, absoluteTolerance: 1e-9))

        p[.restraint] = Axis(value: 0.83, n: 60, lastSampleAt: epoch)
        p.decayConfidence(asOf: epoch.addingTimeInterval(3_650 * 86_400))
        #expect(isApproximatelyEqual(p[.restraint].n, 4, absoluteTolerance: 1e-12))
    }

    @Test("a decayed axis is MORE responsive, not lower — that is the whole point")
    func decayMakesTheAxisResponsive() {
        var p = Profile()
        p[.tempo] = Axis(value: 0.30, n: 60, lastSampleAt: epoch)
        let before = Profile.alpha(n: p[.tempo].n, weight: 1.0)
        p.decayConfidence(asOf: epoch.addingTimeInterval(180 * 86_400))
        #expect(Profile.alpha(n: p[.tempo].n, weight: 1.0) > before)
        #expect(isApproximatelyEqual(p[.tempo].value, 0.30, absoluteTolerance: 1e-12))
    }

    @Test("an axis that has never sampled is untouched by the idle rule")
    func neverSampledIsUntouched() {
        var p = Profile()
        p.decayConfidence(asOf: epoch.addingTimeInterval(900 * 86_400))
        #expect(isApproximatelyEqual(p[.flexibility].n, 0, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(p[.flexibility].value, 0, absoluteTolerance: 1e-12))
    }

    @Test("the idle rule is idempotent within one day and never runs twice for one gap")
    func idleIsIdempotentWithinADay() {
        var p = Profile()
        p[.tempo] = Axis(value: 0.5, n: 60, lastSampleAt: epoch)
        let asOf = epoch.addingTimeInterval(120 * 86_400)
        p.decayConfidence(asOf: asOf)
        let once = p[.tempo].n
        p.decayConfidence(asOf: asOf)
        #expect(isApproximatelyEqual(p[.tempo].n, once, absoluteTolerance: 1e-12))
    }

    // MARK: - the round path

    @Test("a settled round's samples are scaled by the bookkeeping weight and Induction can be suppressed")
    func roundPathAppliesTheBookkeeping() {
        var anomaly = Profile(), ordinary = Profile()
        let samples = [AxisSample(axis: .induction, value: 0.8, weight: 1.0),
                       AxisSample(axis: .tempo, value: 0.9, weight: 1.0)]
        anomaly.apply(samples, scaledBy: 0.5, suppressing: [.induction], at: epoch)
        ordinary.apply(samples, scaledBy: 1.0, suppressing: [], at: epoch)

        #expect(isApproximatelyEqual(anomaly[.induction].n, 0, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(anomaly[.tempo].n, 0.5, absoluteTolerance: 1e-12))
        #expect(isApproximatelyEqual(ordinary[.induction].n, 1.0, absoluteTolerance: 1e-12))
        #expect(anomaly[.tempo].value < ordinary[.tempo].value)   // half the step
    }

    // MARK: - persistence

    @Test("the profile round-trips through profile.json's shape and stays under 1 KB")
    func roundTrips() throws {
        var p = Profile()
        for axis in ProfileAxis.allCases {
            p[axis] = Axis(value: 0.5, n: 33, lastSampleAt: epoch)
        }
        p.ghost = [0.4, 0.5, 0.6, 0.5, 0.4]
        p.ghostTakenAt = epoch
        p.lastRenderedRadii = [52.8, 61.0, 70.2, 61.0, 52.8]

        let data = try JSONEncoder().encode(p)
        #expect(data.count < 1_024)                                   // §11.13
        #expect(try JSONDecoder().decode(Profile.self, from: data) == p)
    }

    @Test("Reset Profile produces day-1 defaults: all v = 0, n = 0, no ghost")
    func resetProducesDayOneDefaults() {
        let p = Profile()
        #expect(ProfileAxis.allCases.allSatisfy { p[$0].value == 0 && p[$0].n == 0 })
        #expect(p.ghost == nil)
        #expect(p.ghostTakenAt == nil)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter ProfileUpdateTests`
Missing symbols only: `Profile`, `Axis`, `Profile.alpha(n:weight:)`, `apply`, `decayConfidence`. If
`convergesToTheMean` passes before the rule exists, the suite is not selecting it.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Archive/Profile.swift` (or modify E07·T09's stub) |
| create | `HunchCore/Tests/ArchiveTests/ProfileUpdateTests.swift` |
| modify | `Modules/Sources/LoomFeature/Round.swift` — the settle path builds a `RoundTranscript`, asks `AxisSampling`, and applies with `RoundBookkeeping`'s weight and suppression, at t = 0 on the Seal press |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — `decayConfidence(asOf: now.date())` runs once at session start, beside E11·T08's ability-confidence decay, and never per round |
| modify | `HunchCore/Tests/PersistenceTests/Fixtures/v1/profile.json` — five populated axes, a ghost, and `lastRenderedRadii` |
| modify | `tests.json` — eight entries |

## Implementation notes

### The value

```swift
public struct Axis: Codable, Equatable, Sendable {
    public var value: Double = 0            // [0, 1]
    public var n: Double = 0                // confidence, [0, 60]. Double because w is fractional.
    public var lastSampleAt: Date?
}

public struct Profile: Codable, Equatable, Sendable {
    public var v: Int = 1
    private var axes: [Axis]                // five, indexed by ProfileAxis.rawValue
    public var ghost: [Double]?             // five values as they stood 90 days ago (T10)
    public var ghostTakenAt: Date?
    public var lastRenderedRadii: [Double]? // the morph's hold beat (T10)

    public subscript(axis: ProfileAxis) -> Axis { get set }

    public static func alpha(n: Double, weight w: Double) -> Double { w * max(0.06, 1 / (n + 1)) }
    public mutating func apply(_ sample: AxisSample, at date: Date)
    public mutating func apply(_ samples: [AxisSample], scaledBy: Double,
                               suppressing: Set<ProfileAxis>, at date: Date)
    public mutating func decayConfidence(asOf date: Date)
}
```

`n` is a `Double`, not an `Int`, because §11.9's `n = min(60, n + w)` adds a fractional weight (0.35
for PROBE Retention, 0.5 for strike-recovery Flexibility and for every Anomaly sample, 0.7 for SIEVE
Tempo). Rounding it to an `Int` would make a 0.35-weight sample either free or a full round, and
`α`'s `1/(n+1)` would step in a way §11.9 never intended.

### The update, in four lines

```swift
public mutating func apply(_ sample: AxisSample, at date: Date) {
    var axis = self[sample.axis]
    let alpha = Self.alpha(n: axis.n, weight: sample.weight)
    axis.value += alpha * (sample.value - axis.value)
    axis.n = min(60, axis.n + sample.weight)
    axis.lastSampleAt = date
    self[sample.axis] = axis
}
```

Three things a reader will otherwise change:

- **`α` reads `n` *before* the increment.** At `n = 0` that gives `α = w`, so the first sample is
  taken whole and a one-round Profile says exactly what that round said. Incrementing first would
  make the first sample worth half, and the day-1 portrait would be permanently biased toward zero.
- **`value` is not clamped after the update.** It cannot leave `[0, 1]`: it is a convex combination
  of two numbers in `[0, 1]` whenever `α ≤ 1`, and `α ≤ w ≤ 1` always. Adding a clamp would hide a
  weight bug rather than fail on it. T05's `samplesAreBounded` is what guarantees the premise.
- **`n` caps at 60 and `α` floors at 0.06.** §11.9: *"the 0.06 floor means it never freezes."* At the
  cap `1/(n+1) = 0.0164`, so the floor is what is actually in force for a mature axis, and
  `floorBinds` pins the crossover at `n > 15`.

**This is the only update rule for any axis.** §11.9 says so and says why: it subsumes a fixed-α
EWMA, which is its `n → ∞` tail. If a second `+=` on `Axis.value` ever appears anywhere in the
codebase, one of the two is wrong.

### The idle rule

```swift
public mutating func decayConfidence(asOf date: Date) {
    for axis in ProfileAxis.allCases {
        guard let last = self[axis].lastSampleAt else { continue }        // never sampled: nothing to decay
        let daysIdle = date.timeIntervalSince(last) / 86_400
        guard daysIdle > 0 else { continue }
        self[axis].n = max(4, self[axis].n * pow(0.5, daysIdle / 60))
    }
}
```

- **`value` is not touched.** §11.9: *"No decay of `value` toward anything… A decay toward the mean
  would read as punishment for not playing, which is the same lever as a streak reminder."*
  `valueNeverDecays` is parameterised over five gaps up to ten years so this cannot be quietly added.
- **It is a function of `lastSampleAt`, not of a stored "last decayed at".** That is what makes
  `idleIsIdempotentWithinADay` true: running it twice on the same date computes the same `daysIdle`
  from the same anchor and lands on the same `n`. A rule that mutated a cursor would compound.
- **The floor is 4, not the ability model's 6.** §10.9's `n` floor of 6 is a *different quantity on a
  different type*, decaying with a different constant (`exp(−(gap−7)/90)` past 7 days, against
  `0.5^(gap/60)` from day 0). They must not be merged, and a shared helper would be `W28`'s smell.
  Cross-reference both in a doc comment so the next reader does not "unify" them.
- Call it **once at session start**, beside E11·T08's ability decay, from the composition root. Never
  per round — a decay inside `apply` would fire once per sample and compound five times a round.

### The round path

`Round`'s settle path, at t = 0 on the Seal press (§6.1: the model never waits on an animation, and
E09·T11 already writes the page, the θ update and the accumulators there):

```swift
let transcript = RoundTranscript(...)                       // T05's value
let bookkeeping = RoundBookkeeping(for: record)             // T03's value
profile.apply(AxisSampling.samples(for: transcript),
              scaledBy: bookkeeping.profileWeight,
              suppressing: bookkeeping.emitsInductionSample ? [] : [.induction],
              at: now.date())
```

Four lines, one place, and every Anomaly rule arrives through `bookkeeping` rather than through a
second `if`.

### Where the ghost comes from

`ghost` and `ghostTakenAt` are declared here because §11.13 declares them in `profile.json`, but
nothing writes them until **T10**. Ship them as `nil` and let the round-trip test carry them; a field
added later is an additive migration nobody needs.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter ProfileUpdateTests` green, all sixteen tests.
- [ ] `grep -rn "\.value +=\|\.value =" HunchCore/Sources Modules/Sources | grep -i axis` shows exactly one write site — `Profile.apply(_:at:)`.
- [ ] `grep -rn "decayConfidence" Modules/Sources` shows exactly one call site, at session start.
- [ ] `grep -rn "0.06\|max(0.06" HunchCore/Sources` shows the floor only in `Profile.alpha`.
- [ ] `HunchCore/Tests/PersistenceTests/Fixtures/v1/profile.json` is populated and under 1 KB, and `PersistenceTests` is still green.
- [ ] `tests.json` carries eight entries: α's formula and floor, first-sample-whole, the `n` cap, convergence-to-the-mean, no-ratchet, value-never-decays, the confidence half-life with its floor of 4, and the bookkeeping-scaled round path.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. If it proposes unifying this decay with §10.9's ability decay, reject it and point at the doc comment.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E16/T06: the Profile update rule, the n cap and the idle confidence decay"`

## Out of scope

- The five sample formulas — **T05**.
- `H_live` — **T07**.
- Turning `value` into a radius — **T08**; the tremble that reads `n` — **T10**.
- Writing the 90-day ghost and `lastRenderedRadii` — **T10**.
- The `Reset Profile` action and its alert — **E17·T08**; this task only ships the day-1 default the reset writes.
- θ's own confidence decay — **E11·T08**.
