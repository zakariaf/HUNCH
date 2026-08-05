# T09 — Steady stream

| | |
|---|---|
| **Epic** | E14 — SIEVE |
| **Priority** | P1 |
| **Size** | S |
| **Depends on** | T08 |
| **Delivers** | Steady stream (SIEVE) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-code` | The multiplier has to land in exactly one expression — `points` — and nowhere near `yield`, `ratio`, `marks` or the page gate, which is a placement question rather than an arithmetic one. The skill also owns the `UserDefaults`-holds-preferences-only rule and the composition-root shape that carries a preference from Settings into a core value without a singleton. |
| `hunch-accessibility` | The whole point of this row is that it is **not** an accessibility flag: §12.6 puts it under PLAY, not under VOICEOVER, and §9.8 says it is *"available to anyone, not gated behind an accessibility flag."* The skill's own gotcha warns against collapsing steady stream and VoiceOver step mode into one `isVoiceOverRunning` branch, and its §11.9 note explains why **both** suppress the Tempo sample while only one carries a multiplier. |

`hunch-chrome-and-meta` is **not** loaded: the Settings row's drawing is E17·T07's. This task defines
the preference and its effect.

## Objective

At the end of this task a player can turn on *steady stream* from Settings → PLAY and get a SIEVE run
whose rate is fixed at `r₀` with no ramp, scored at a 0.85 multiplier on the points and on nothing
else — marks, success, and Codex inscription all read the unmultiplied figures. It is available to
anyone, and it emits **no Tempo sample**, because a sample taken under a fixed rate would measure the
setting rather than the player.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §9.8 | *"Settings → steady stream: fixes `r` at `r₀` with no ramp, at a 0.85 score multiplier. Available to anyone, not gated behind an accessibility flag, and it does not disable Codex inscription."* Also, immediately above it, the VoiceOver step mode row and its *"the Tempo axis is not updated, because the timing is not comparable"* |
| `GAME_DESIGN.md` | §12.6 | the Settings row: section **PLAY**, type toggle, default **Off**, key `steadyStream`, and the fact that every `hunch.settings.*` preference lives in `UserDefaults.standard` while game state lives in JSON |
| `GAME_DESIGN.md` | §11.9 | **the single normative axis table**: *"SIEVE emits no Tempo sample at all when the run used §9.8's VoiceOver step mode or the steady stream setting — both fix `r`, so the latency is not comparable and a sample would be a measurement of the setting rather than of the player. It still emits Induction and Restraint."* |
| `GAME_DESIGN.md` | §14.5 open decision 8 | the ECHO-cadence question, decided *against* an accommodation partly because *"SIEVE got steady stream for the same reason"* — so this row is load-bearing for a decision in another mode and may not quietly become an accessibility gate |
| `GAME_DESIGN.md` | §10.5, §12.6 | no difficulty selector anywhere; steady stream is a *pacing* accommodation with a stated price, not a difficulty picker |
| `.claude/skills/hunch-accessibility/references/rotors-and-gestures.md` | §9 | the `SievePacing` seam, and the explicit instruction not to collapse the two fixed-rate routes |

## TDD — the test comes first

**Step 1 — write the failing test.** Create `HunchCore/Tests/RoundsTests/SieveSteadyStreamTests.swift`:

```swift
import Testing
import Glyphs
import Rounds
import HunchTestSupport

@Suite("SIEVE steady stream — §9.8, §12.6, §11.9", .tags(.unit, .presubmission))
struct SieveSteadyStreamTests {

    private func flawless(pacing: SievePacing) -> SieveScore {
        SieveScore(tally: .flawless(glyphCount: 60), glyphCount: 60, resolvedGlyphs: 60,
                   ending: .sieved, scoreMultiplier: pacing.scoreMultiplier)
    }

    // MARK: the multiplier, and its exact reach

    @Test("the multiplier is 0.85 for steady and 1.0 for the other two pacings",
          arguments: [(SievePacing.ramped, 1.0), (.steady, 0.85), (.stepped, 1.0)])
    func multiplierPerPacing(_ pacing: SievePacing, _ expected: Double) {
        #expect(pacing.scoreMultiplier == expected)
    }

    @Test("the multiplier reduces POINTS and nothing else")
    func multiplierTouchesPointsOnly() {
        let normal = flawless(pacing: .ramped)
        let steady = flawless(pacing: .steady)
        #expect(steady.points == Int((1000 * normal.yield * 0.85).rounded()))
        #expect(steady.ratio == normal.ratio)
        #expect(steady.completion == normal.completion)
        #expect(steady.yield == normal.yield)
        #expect(steady.marks == normal.marks)
        #expect(steady.isSuccess == normal.isSuccess)
        #expect(steady.inscribesCodexPage == normal.inscribesCodexPage)
    }

    @Test("steady stream does not disable Codex inscription (§9.8, verbatim)")
    func inscriptionSurvives() {
        #expect(flawless(pacing: .steady).inscribesCodexPage)
        #expect(flawless(pacing: .steady).pageMode == .sieve)
    }

    @Test("a run that would earn 3 marks still earns 3 marks under steady stream")
    func marksAreUnaffected() {
        #expect(flawless(pacing: .steady).marks == 3)
    }

    @Test("the Rasch update sees the same success bit with the setting on and off")
    func successIsUnaffected() {
        let borderline = SieveScore(tally: .atRatio(0.81, glyphCount: 60), glyphCount: 60,
                                    resolvedGlyphs: 60, ending: .sieved,
                                    scoreMultiplier: SievePacing.steady.scoreMultiplier)
        #expect(borderline.isSuccess)
    }

    // MARK: the pacing itself

    @Test("steady fixes r at r₀ and never ramps", arguments: Band.sieveServable, 0...3)
    func steadyIsFlat(_ band: Band, _ step: Int) {
        let schedule = SieveSchedule(band: band, tempoStep: step, pacing: .steady)
        let rates = Set((0..<schedule.glyphCount).map(schedule.rate(at:)))
        #expect(rates.count == 1)
        #expect(rates.first == schedule.rateStart)
    }

    @Test("steady keeps the tempo step — the setting removes the ramp, not the difficulty",
          arguments: Band.sieveServable)
    func steadyStillHonoursTheTempoStep(_ band: Band) {
        let base = SieveSchedule(band: band, tempoStep: 0, pacing: .steady)
        let stepped = SieveSchedule(band: band, tempoStep: 3, pacing: .steady)
        #expect(stepped.rate(at: 0) > base.rate(at: 0))
    }

    @Test("a steady run is longer than a ramped one at the same band and step",
          arguments: Band.sieveServable, 0...3)
    func steadyRunsLonger(_ band: Band, _ step: Int) {
        #expect(SieveSchedule(band: band, tempoStep: step, pacing: .steady).duration
                > SieveSchedule(band: band, tempoStep: step, pacing: .ramped).duration)
    }

    // MARK: the Tempo suppression

    @Test("no Tempo sample is emitted under steady OR stepped pacing (§11.9)",
          arguments: [SievePacing.steady, .stepped])
    func noTempoSampleUnderAFixedRate(_ pacing: SievePacing) {
        let sample = flawless(pacing: pacing)
            .profileSample(medianHitLatency: .milliseconds(300),
                           meanWindowOverHits: .milliseconds(600), pacing: pacing)
        #expect(sample.tempo == nil)
        #expect(sample.feedsInduction)
        #expect(sample.feedsRestraint)
    }

    @Test("a ramped run DOES emit a Tempo sample")
    func rampedEmitsTempo() {
        let sample = flawless(pacing: .ramped)
            .profileSample(medianHitLatency: .milliseconds(300),
                           meanWindowOverHits: .milliseconds(600), pacing: .ramped)
        #expect(sample.tempo != nil)
    }

    // MARK: it is not an accessibility gate

    @Test("steady stream is reachable with VoiceOver off — it is a PLAY row, not a VOICEOVER row")
    func notGatedBehindAccessibility() {
        #expect(SieveSettings.steadyStreamSection == .play)
        #expect(SieveSettings.steadyStreamRequiresVoiceOver == false)
        #expect(SieveSettings.pacing(steadyStream: true, isVoiceOverRunning: false) == .steady)
    }

    @Test("VoiceOver wins over the steady-stream toggle — its window is longer and its rate is fixed",
          arguments: [true, false])
    func voiceOverTakesPrecedence(_ steadyStream: Bool) {
        #expect(SieveSettings.pacing(steadyStream: steadyStream, isVoiceOverRunning: true) == .stepped)
    }

    @Test("with neither set, the pacing is ramped")
    func defaultIsRamped() {
        #expect(SieveSettings.pacing(steadyStream: false, isVoiceOverRunning: false) == .ramped)
    }

    @Test("the preference key is the §12.6 one, under the hunch.settings. prefix")
    func preferenceKey() {
        #expect(SieveSettings.steadyStreamKey == "hunch.settings.steadyStream")
        #expect(SieveSettings.steadyStreamDefault == false)
    }
}
```

**Step 2 — run it and watch it fail.** `swift test --package-path HunchCore --filter SieveSteadyStreamTests`

Expect missing `SievePacing.scoreMultiplier`, `SieveSettings`, `SieveTally.atRatio(_:glyphCount:)`
and the `pacing:` parameter on `profileSample`.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Rounds/SieveSchedule.swift` — `SievePacing.scoreMultiplier` |
| create | `HunchCore/Sources/Rounds/SieveSettings.swift` — `pacing(steadyStream:isVoiceOverRunning:)`, the key and the default |
| modify | `HunchCore/Sources/Rounds/SieveProfileSample.swift` — `tempo` becomes `nil` under `.steady` and `.stepped` |
| modify | `Modules/Sources/LoomFeature/SieveRun.swift` — resolve the pacing once, at round start, from the preference and `@Environment(\.accessibilityVoiceOverEnabled)` |
| modify | `Modules/Sources/HunchAppFeature/AppDependencies.swift` — the `steadyStream` preference read; **no** new dependency, it is a `UserDefaults` value like the other eighteen |
| create | `HunchCore/Tests/RoundsTests/SieveSteadyStreamTests.swift` |
| modify | `tests.json` — four entries: multiplier touches points only, inscription survives, no Tempo sample under a fixed rate, not gated behind VoiceOver |
| modify | `DECISIONS.md` — the multiplier's placement, already seeded by T05 |

## Implementation notes

### The multiplier is one number on one enum and one factor in one expression

```swift
extension SievePacing {
    /// §9.8 — steady stream is scored at 0.85. VoiceOver step mode is not: *"Scoring is identical."*
    public var scoreMultiplier: Double {
        switch self {
        case .ramped:  1.0
        case .steady:  0.85
        case .stepped: 1.0
        }
    }
}
```

T05 already put `scoreMultiplier` in `SieveScore.init`, folded into
`points = Int((1000 * yield * scoreMultiplier).rounded())` and nowhere else. This task's entire
arithmetic contribution is supplying the 0.85. `multiplierTouchesPointsOnly` asserts the six
quantities it must not reach; if that test ever needs relaxing, the change is wrong.

Why it must not reach `yield`: §9.8 calls it a **score** multiplier and separately guarantees it
*"does not disable Codex inscription."* The page gate is `ratio ≥ 0.92`; a multiplier on `yield`
would move the gate to an effective 1.08 and make inscription impossible, which is the opposite of
what the sentence promises. It would also move all three mark thresholds and the success bit, which
would make the setting a difficulty selector — the one thing §10.5 forbids outright.

### One resolution point, three inputs, no `isVoiceOverRunning` in the core

```swift
public enum SieveSettings {
    public static let steadyStreamKey = "hunch.settings.steadyStream"
    public static let steadyStreamDefault = false

    /// The one place the two fixed-rate routes are reconciled. VoiceOver wins because its window is
    /// longer (889 ms) and because §9.8 specifies its pacing unconditionally.
    public static func pacing(steadyStream: Bool, isVoiceOverRunning: Bool) -> SievePacing {
        if isVoiceOverRunning { .stepped }
        else if steadyStream { .steady }
        else { .ramped }
    }
}
```

This is a pure function of two `Bool`s, so it is core; the `Bool`s are **read at the view edge**.
`SieveRun` resolves the pacing once at round start from `UserDefaults` and
`@Environment(\.accessibilityVoiceOverEnabled)` and hands the resulting `SievePacing` to
`SieveSchedule`. `08 §2`'s boundary rule bans a `UIAccessibility` read below the composition root
outright, and `render-env.md` §6 is explicit that VoiceOver is **not** an eighth `RenderEnv` axis —
it changes behaviour and structure, not tokens.

Resolving once at round start rather than per frame matters: toggling VoiceOver mid-run must not
change the rate under the player's thumb. The schedule is a value captured at `arming`.

### The Tempo suppression is one rule with two causes

§11.9 is the single normative axis table and it names both routes in one sentence. So the suppression
predicate reads the **pacing**, not the setting:

```swift
public func profileSample(medianHitLatency: Duration, meanWindowOverHits: Duration,
                          pacing: SievePacing) -> SieveProfileSample {
    let tempo: Double? = pacing == .ramped
        ? clamp01(1 - medianHitLatency.seconds / meanWindowOverHits.seconds)
        : nil                       // §11.9 — a fixed rate measures the setting, not the player
    …
}
```

Induction and Restraint are emitted regardless — §11.9 says so explicitly — so a player who uses
steady stream still has a portrait that moves. Only the axis whose measurement the setting invalidates
goes quiet, and it goes quiet by being absent rather than by being zero: a zero sample would pull the
Tempo vertex *down*, which is a punishment for using an accommodation and is precisely the failure
`nil` avoids.

### It is not an accessibility feature and the tests say so

§12.6 places the row under **PLAY**, beside *Confirm the Seal*, and §9.8 spells out *"available to
anyone, not gated behind an accessibility flag."* §14.5 open decision 8 then leans on this row when
declining an ECHO cadence accommodation, so quietly moving it under VOICEOVER would invalidate a
decision in another mode. `notGatedBehindAccessibility` is a small test defending a cross-section
claim; keep it.

### What P1 means here

This row is P1 in §14.1's inventory, so it is in §14.2's drop order. If it is cut, cut it whole:
the `scoreMultiplier` seam stays (it costs one parameter and T05 already ships it), `SievePacing`
keeps all three cases (VoiceOver's `.stepped` is P0), and only the Settings row and the `.steady`
case's reachability go. Do not cut it by leaving the toggle and removing the multiplier — that would
ship a free difficulty reduction, which is worse than not shipping it.

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter SieveSteadyStreamTests` green — all thirteen tests.
- [ ] `grep -n "0.85" HunchCore/Sources/Rounds/` returns exactly one hit, in `SievePacing.scoreMultiplier`.
- [ ] `grep -rn "scoreMultiplier" HunchCore/Sources/Rounds/SieveScore.swift` shows it only in the `points` expression.
- [ ] `grep -rn "UIAccessibility\|isVoiceOverRunning" HunchCore/Sources/` returns nothing — the flag arrives as a `Bool` parameter.
- [ ] `SieveProfileSample.tempo` is `nil` under `.steady` and `.stepped` and non-`nil` under `.ramped`, asserted in both directions.
- [ ] The pacing is resolved once at `arming` and captured in the schedule — verified by a test that flipping the preference mid-run does not change `schedule.rate(at:)`.
- [ ] `tests.json` carries the four entries.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it. Expect it to propose collapsing `.steady` and `.stepped` again now that both suppress Tempo; decline, and point at `multiplierPerPacing` and at T01's `DECISIONS.md` entry.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding. Ask it specifically whether the multiplier can reach `marks`, `isSuccess` or `inscribesCodexPage` by any path.
4. Commit: `git commit -m "E14/T09: steady stream — fixed rate, 0.85 on points only, no Tempo sample"`

## Out of scope

- The Settings row's drawing, its section placement in `SettingsView` and its label — **E17·T07**. This task fixes the key, the default and the effect.
- The Profile's α, weights and the Tempo axis update — **E16·T05/T06**. This task emits `nil` or a value.
- VoiceOver's step mode as an *experience* — announcements, the gate element, the sump resolution — **E19·T05**. This task only owns its rate and its Tempo suppression.
- The 889 ms window's derivation — **T01**.
- The score's presentation on the Inscription — **E09·T11**.
