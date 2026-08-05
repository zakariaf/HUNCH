# T07 — The `loomGrain` shader

| | |
|---|---|
| **Epic** | E20 — Polish and ship |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T04 |
| **Delivers** | `loomGrain` shader (ART / MOTION) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | `references/render-env.md` §3 already ships the three predicates this shader is a consumer of — `isShaderEnabled` (Reduce Transparency **or** High Contrast **or** Low Power), `isScanlineEnabled` (that, **and** dark), `isShaderTimeFrozen` (Reduce Motion) — and §6's rule that a call site never re-derives a predicate. §1 says why they are folded: eight files each deciding what "transparency off" means is the failure the record exists to prevent. `references/durations-and-easing.md` owns `dur.grainReseed` (125 ms = the 8 Hz reseed), which is the one duration in the shader and must not be typed as a number. |
| `hunch-motion-and-feedback` | `references/reduce-motion.md` §2's grain row and, more importantly, its "What would be wrong" entry: **freezing the shader by setting `amt = 0` is wrong.** Reduce Motion freezes `t`; Reduce Transparency, High Contrast and Low Power set `amt = 0`. Two settings, two predicates, and conflating them is the single most likely defect in this task. §2 is also where the row's completeness claim lives, which T08 re-verifies. |
| `hunch-swift-testing` | `references/budget.md` owns what may enter the 10-second fast suite and what may not: `GrainGovernor` is a pure value and belongs in a package test; an Instruments Metal-counter figure is a **measurement recorded in `PROGRESS.md`**, not a test, and pretending otherwise produces a performance assertion that flakes on CI hardware. It also owns the `.performance` tag and the rule that a slow suite is gated, never deleted. |

`hunch-bench-instruments` is not loaded, but one of its sentences is load-bearing here and is quoted
rather than looked up: `references/throat.md` §1 — *"the shader's own vignette term does this for the
whole play surface, so the throat does **not** draw a second one."* If the vignette ends up drawn
twice, this task is where it happened.

## Objective

At the end of this task the play surface has its texture: one stitchable `colorEffect` over the region
below the chrome bar — a 3 px scanline, a grain field reseeded at 8 Hz and a vignette — costing
≤ 0.4 ms/frame at 120 Hz on an A15, measured with Instruments and written down. Its two uniforms are
resolved from `RenderEnv`'s existing predicates and from the `Grain` Settings row, never re-derived;
`amt` is 0 under Reduce Transparency, High Contrast and Low Power, and `t` is frozen at 0 under Reduce
Motion. A pure `GrainGovernor` — the only part of this that a test can see — turns the effect off after
two contiguous seconds below 30 fps and turns it back on **only at a round boundary**.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.6 | the whole shader: the Metal function verbatim, the 3 px scanline period at ±2.8 %, the ±1.6 % grain reseeded at 8 Hz, the 1.00 → 0.88 vignette, the ≤ 0.4 ms/frame budget on an A15, `amt = 0` under three conditions and `t` frozen under Reduce Motion |
| `GAME_DESIGN.md` | §13.6 (placement) | *"over the play surface, below the chrome bar"* — one `colorEffect`, one region, and not over the instrument bar |
| `GAME_DESIGN.md` | §12.6 (DISPLAY) | the `Grain` toggle, default On, *"ignored — held at `amt = 0` — under High Contrast, Reduce Transparency or Low Power"*. **E17·T06 owns the row and the `grain` key**; this task consumes the value |
| `GAME_DESIGN.md` | §13.11 | Reduce Transparency ⇒ shader off; High Contrast ⇒ shader off. Both already fold into `env.isShaderEnabled` |
| `GAME_DESIGN.md` | §12.7 | Low Power Mode ⇒ grain shader off; SIEVE additionally caps the stream at 60 Hz |
| `GAME_DESIGN.md` | §14.6 risk 6 | the governor, stated as a mitigation: *"the shader auto-disables below 30 fps for 2 s and re-enables at a round boundary"* |
| `GAME_DESIGN.md` | §13.5 | the Assay is excluded from bloom entirely because the reveal frame cannot afford a fourth offscreen layer **against this budget** — the sentence that prices this shader |
| `.claude/skills/hunch-design-tokens/references/render-env.md` | §3, §6 | the three predicates and the ban on re-deriving them |
| `.claude/skills/hunch-motion-and-feedback/references/reduce-motion.md` | §2, §9 | the grain row; `amt = 0` is not the Reduce Motion substitution |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | `B22`, `B34a`, `B41`, `B44` | package resources are loaded through the module's own bundle; a new numbered check must be proved able to fail; Instruments is the measurement tool; the size implication of adding a `.metal` file |

## TDD — the test comes first

Two halves, because this deliverable is two artefacts. The governor and the uniform resolution are
Swift values and get a Swift Testing suite. The Metal function and its single application site are
neither — nothing in a test bundle can see whether `.colorEffect` was applied twice — so they get a
**numbered hygiene check, proved by planting a violation and proved not to fire on the legal spelling.**

**Step 1a — write the failing Swift test.** Create
`Modules/Tests/HunchUITests/GrainGovernorTests.swift`:

```swift
import Testing
import Tokens
@testable import HunchUI

@Suite("The grain governor — §14.6 risk 6", .tags(.unit, .presubmission))
struct GrainGovernorTests {

    /// A frame at the given rate, fed n times from t = 0.
    private func run(_ governor: inout GrainGovernor, fps: Double, for span: Duration) {
        let interval = Duration.seconds(1 / fps)
        var now = governor.clockForTesting
        let end = now + span
        while now < end {
            now += interval
            governor.observe(frameInterval: interval, at: now)
        }
    }

    // MARK: the disable rule

    @Test("a contiguous run below 30 fps for two seconds disables the effect")
    func twoSlowSecondsDisable() {
        var g = GrainGovernor()
        #expect(g.state == .enabled)
        run(&g, fps: 24, for: .milliseconds(1_900))
        #expect(g.state == .enabled)                    // 1.9 s is not 2 s
        run(&g, fps: 24, for: .milliseconds(200))
        #expect(g.state == .disabled)
    }

    @Test("the window is contiguous, not cumulative")
    func aRecoveryResetsTheWindow() {
        var g = GrainGovernor()
        run(&g, fps: 24, for: .milliseconds(1_800))
        run(&g, fps: 120, for: .milliseconds(100))      // one good frame is enough
        run(&g, fps: 24, for: .milliseconds(1_800))
        #expect(g.state == .enabled)                    // 1.8 + 1.8 is not a 2 s run
    }

    @Test("exactly 30 fps is not below 30 fps", arguments: [30.0, 30.5, 60.0, 120.0])
    func theFloorIsNotStrict(_ fps: Double) {
        var g = GrainGovernor()
        run(&g, fps: fps, for: .seconds(10))
        #expect(g.state == .enabled)
    }

    @Test("a single dropped frame never disables anything")
    func oneHitchIsNotAFailure() {
        var g = GrainGovernor()
        g.observe(frameInterval: .milliseconds(120), at: .milliseconds(120))
        run(&g, fps: 120, for: .seconds(3))
        #expect(g.state == .enabled)
    }

    // MARK: the re-enable rule — the half people get wrong

    @Test("recovery alone never re-enables: only a round boundary does")
    func recoveryDoesNotReEnable() {
        var g = GrainGovernor()
        run(&g, fps: 24, for: .seconds(2))
        #expect(g.state == .disabled)
        run(&g, fps: 120, for: .seconds(30))            // thirty good seconds
        #expect(g.state == .disabled)                   // …and it stays off
        g.roundBoundary()
        #expect(g.state == .enabled)
    }

    @Test("a round boundary while enabled changes nothing and clears no partial window")
    func boundaryIsNotAReset() {
        var g = GrainGovernor()
        run(&g, fps: 24, for: .milliseconds(1_500))
        g.roundBoundary()
        run(&g, fps: 24, for: .milliseconds(600))
        #expect(g.state == .disabled)                   // the window survived the boundary
    }

    @Test("a boundary that arrives mid-slow-run re-enables and then the run re-disables")
    func flappingIsBoundedByTheTwoSecondRule() {
        var g = GrainGovernor()
        run(&g, fps: 24, for: .seconds(2))
        g.roundBoundary()
        #expect(g.state == .enabled)
        run(&g, fps: 24, for: .milliseconds(1_900))
        #expect(g.state == .enabled)                    // it costs a fresh 2 s every time
    }

    @Test("the governor is a value: copying it does not share state")
    func itIsAValue() {
        var a = GrainGovernor()
        run(&a, fps: 24, for: .seconds(2))
        var b = a
        b.roundBoundary()
        #expect(a.state == .disabled)
        #expect(b.state == .enabled)
    }
}
```

And `Modules/Tests/HunchUITests/GrainUniformTests.swift`, which is where the two-settings-two-predicates
mistake gets caught:

```swift
import Testing
import Tokens
@testable import HunchUI

@Suite("The shader's uniforms — §13.6", .tags(.unit, .presubmission))
struct GrainUniformTests {

    private func amount(_ env: RenderEnv, setting: Bool = true,
                        governor: GrainGovernor.State = .enabled) -> Double {
        GrainUniforms(env: env, isGrainSettingOn: setting, governor: governor).amount
    }

    @Test("amt is zero under Reduce Transparency, High Contrast and Low Power")
    func theThreeSuppressors() {
        #expect(amount(RenderEnv(isReduceTransparencyEnabled: true)) == 0)
        #expect(amount(RenderEnv(theme: .highContrast)) == 0)
        #expect(amount(RenderEnv(isLowPowerModeEnabled: true)) == 0)
        #expect(amount(RenderEnv()) > 0)
    }

    @Test("amt is zero with the Grain setting off, and the setting is not an accessibility flag")
    func theSettingIsItsOwnAxis() {
        #expect(amount(RenderEnv(), setting: false) == 0)
        #expect(amount(RenderEnv(), setting: true) > 0)
    }

    @Test("amt is zero when the governor has disabled it")
    func theGovernorSuppresses() {
        #expect(amount(RenderEnv(), governor: .disabled) == 0)
    }

    @Test("REDUCE MOTION DOES NOT ZERO amt — it freezes t")
    func reduceMotionFreezesTimeAndNothingElse() {
        let rm = RenderEnv(isReduceMotionEnabled: true)
        #expect(amount(rm) > 0)                                    // the grain is still there…
        #expect(GrainUniforms(env: rm, isGrainSettingOn: true, governor: .enabled).time == 0)
        #expect(GrainUniforms(env: RenderEnv(), isGrainSettingOn: true, governor: .enabled)
                    .time(at: .seconds(3)) > 0)                    // …and only here does it move
    }

    @Test("the scanline term is dark-only and rides its own uniform", arguments: RenderEnv.Theme.allCases)
    func scanlineFollowsItsPredicate(_ theme: RenderEnv.Theme) {
        let u = GrainUniforms(env: RenderEnv(theme: theme), isGrainSettingOn: true, governor: .enabled)
        #expect((u.scan > 0) == RenderEnv(theme: theme).isScanlineEnabled)
        if theme == .light { #expect(u.amount > 0 && u.scan == 0) }   // grain and vignette stay
    }

    @Test("the reseed period is the token, not a number")
    func theReseedIsAToken() {
        #expect(GrainUniforms.reseedHz == 1.0 / Dur.grainReseed.seconds)
    }

    @Test("no predicate is re-derived: the uniforms read env, never the raw flags")
    func predicatesAreReadNotRebuilt() {
        // Every suppressor already folds into isShaderEnabled; asserting the equality is what
        // stops a fourth suppressor being added to one of the two and not the other.
        for env in RenderEnv.separationMatrix {
            #expect((GrainUniforms(env: env, isGrainSettingOn: true, governor: .enabled).amount > 0)
                    == env.isShaderEnabled)
        }
    }
}
```

**Step 1b — write the failing script check.** The Metal file, the single application site and the
bundle lookup are invisible to every test bundle, so they become **check 12** of
`Scripts/check-source-hygiene.sh`. Write the plant script first — `/tmp/prove-check-12.sh`, scratch,
not committed:

```bash
#!/bin/bash
# Every line must print CAUGHT. A MISSED line is a check that does nothing (07 B6).
set -uo pipefail
probe() { eval "$2"
  if Scripts/check-source-hygiene.sh >/tmp/h.out 2>&1; then echo "$1: MISSED"; else echo "$1: CAUGHT"; fi
  eval "$3"; }

probe 'second colorEffect' \
  'printf "\n// x\nlet y = EmptyView().colorEffect(ShaderLibrary.loomGrain())\n" >> Modules/Sources/LoomFeature/BenchView.swift' \
  'git checkout -- Modules/Sources/LoomFeature/BenchView.swift'

probe 'ShaderLibrary.default on a package resource' \
  'sed -i "" "s/ShaderLibrary.bundle(#bundle)/ShaderLibrary.default/" Modules/Sources/HunchUI/LoomGrainModifier.swift' \
  'git checkout -- Modules/Sources/HunchUI/LoomGrainModifier.swift'

probe 'amt hardcoded past the predicates' \
  'sed -i "" "s/uniforms.amount/1.0/" Modules/Sources/HunchUI/LoomGrainModifier.swift' \
  'git checkout -- Modules/Sources/HunchUI/LoomGrainModifier.swift'

probe 'reduce motion zeroing amt instead of freezing t' \
  'printf "\nlet a = env.isReduceMotionEnabled ? 0.0 : 1.0  // amt\n" >> Modules/Sources/HunchUI/GrainUniforms.swift' \
  'git checkout -- Modules/Sources/HunchUI/GrainUniforms.swift'

# The legal spellings must NOT be caught. A check that flags correct code gets suppressed.
Scripts/check-source-hygiene.sh >/dev/null 2>&1 \
  && echo 'clean tree: OK' || echo 'clean tree: FALSE POSITIVE'
printf '\n// the accessibility-hidden decorative pass\nlet z = env.isReduceMotionEnabled\n' \
  >> Modules/Sources/HunchUI/GrainUniforms.swift
Scripts/check-source-hygiene.sh >/dev/null 2>&1 \
  && echo 'bare isReduceMotionEnabled read: OK' || echo 'bare read: FALSE POSITIVE'
git checkout -- Modules/Sources/HunchUI/GrainUniforms.swift
```

The last plant is the important one: check 12 must fire on `isReduceMotionEnabled` **used to compute an
amount**, and must not fire on `isReduceMotionEnabled` being read at all — the uniforms legitimately
read it to freeze `t`. A check that cannot tell those apart is a check somebody deletes in a week.

**Step 2 — run them and watch them fail.**

```bash
set -o pipefail
xcodebuild test -project Hunch.xcodeproj -scheme Hunch -testPlan Presubmission \
  -destination "id=$UDID" \
  -only-testing:HunchUITests/GrainGovernorTests \
  -only-testing:HunchUITests/GrainUniformTests | xcbeautify
bash /tmp/prove-check-12.sh
```

The Swift run must fail on `cannot find 'GrainGovernor' in scope`; the script must print `MISSED` on
every line, because check 12 does not exist yet. **`-only-testing:HunchUITests/…` is ambiguous** —
`08 §1` puts a `HunchUITests` under `Modules/Tests/` *and* one at the repo root. Confirm the run
reports a non-zero case count for these two suites specifically; a green run over zero tests means the
selector picked the XCUITest bundle (`07 B24`'s failure mode wearing a different hat).

**Step 3 — implement.** `GrainGovernor` and `GrainUniforms` first (pure), then the `.metal` file and
its manifest entry, then the one modifier, then check 12.

**Step 4 — green, then measure.** The budget is not a test. Build Release to an **iPhone SE (3rd
generation)** — the A15 §13.6 names — and run Instruments' Metal System Trace at 120 Hz over a full
band-6 round including a reveal. Record the per-frame figure in `PROGRESS.md` §Shader with the device,
the OS build and the app build number.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/LoomGrain.metal` — §13.6's function, plus the `scan` uniform |
| create | `Modules/Sources/HunchUI/GrainUniforms.swift` — `amount`, `time(at:)`, `scan`, `reseedHz` |
| create | `Modules/Sources/HunchUI/GrainGovernor.swift` — the pure governor |
| create | `Modules/Sources/HunchUI/LoomGrainModifier.swift` — the single `.colorEffect` application site |
| modify | `Modules/Package.swift` — the `HunchUI` target's `resources:` entry for the Metal file |
| modify | `Modules/Sources/LoomFeature/RoundView.swift` — the one call site, below the chrome bar |
| modify | `Modules/Sources/LoomFeature/Round.swift` — `governor.roundBoundary()` at the round transition |
| modify | `Scripts/check-source-hygiene.sh` — check 12 |
| create | `Modules/Tests/HunchUITests/GrainGovernorTests.swift` |
| create | `Modules/Tests/HunchUITests/GrainUniformTests.swift` |
| modify | `PROGRESS.md` — §Shader: the Instruments figure, the device, the date, the build |
| modify | `DECISIONS.md` — the `scan` uniform's addition to §13.6's signature |
| modify | `tests.json` — `shader.governor`, `shader.uniform-suppression`, `shader.budget` (manual) |

## Implementation notes

### The function, and the one uniform §13.6 does not have

§13.6 prints the Metal verbatim and it is transcribed **once**, with the file open. One addition:

```metal
[[ stitchable ]] half4 loomGrain(float2 p, half4 c, float2 size,
                                 float t, float amt, float scan) {
    float scanline = 1.0 + 0.028 * sin(p.y * 2.0943951) * scan;    // 3 px period, ±2.8 %
    float g        = fract(sin(dot(floor(p) + floor(t * 8.0), float2(12.9898, 78.233))) * 43758.5453);
    float grain    = 1.0 + 0.032 * (g - 0.5);                      // ±1.6 %, reseeded at 8 Hz
    float2 d       = (p / size) - 0.5;
    float vig      = mix(1.0, 0.88, saturate(dot(d, d) * 2.0));    // 1.00 centre → 0.88 corner
    return half4(c.rgb * half(mix(1.0, scanline * grain * vig, amt)), c.a);
}
```

**The sixth parameter is a deviation from §13.6's printed signature and needs a `DECISIONS.md` entry.**
`render-env.md` §3 ships `isScanlineEnabled` as *"`isShaderEnabled` **and** theme is dark — the `scan`
term only; grain and vignette stay in light"*, and §13.6's single `amt` cannot express that: zeroing
`amt` in the light theme would also delete the grain and the vignette, which the token skill explicitly
keeps. Multiplying the `sin` term by a 0/1 uniform is the smallest change that makes both documents
true, it costs one multiply, and it keeps every constant in §13.6 untouched. Record the reading, the
alternative rejected (a second shader function), and the reason.

Everything else is transcribed and nothing is "improved": the 2.0943951 is 2π/3 for a 3-pixel period,
the hash constants are the classic ones, and `floor(t * 8.0)` is what makes the reseed 8 Hz. The 8 is
in the shader because it is a Metal expression, and the Swift side spells the same fact as
`Dur.grainReseed` — `GrainUniforms.reseedHz` asserts the two agree so the pair cannot drift.

### Loading it — the trap that costs an afternoon

`ShaderLibrary.default` resolves against `Bundle.main`. `LoomGrain.metal` is a **package** resource, so
it compiles into `HunchUI`'s own bundle and `.default` finds nothing — at runtime, with a shader that
silently draws nothing rather than a compile error.

```swift
// Modules/Sources/HunchUI/LoomGrainModifier.swift
private static let library = ShaderLibrary.bundle(#bundle)      // 07 B22, 01 P36
```

`#bundle` and not `Bundle.module` (`01 P36`), and the manifest needs the resource declared:

```swift
.target(name: "HunchUI", dependencies: ["HunchCore"],
        resources: [.process("Resources"), .process("LoomGrain.metal")],
        swiftSettings: uiSettings)
```

`.process` and not `.copy`: SwiftPM compiles `.metal` sources into the target's `default.metallib`
under processing, and a `.copy` ships the *source text* and no library at all. Check 12's second plant
exists because this failure is invisible — the app runs, the surface is flat, and nobody notices until
someone looks at a device in a dark room.

### `GrainUniforms` — three values, zero decisions

```swift
public struct GrainUniforms: Hashable, Sendable {
    public static let nominalAmount = 1.0
    public static var reseedHz: Double { 1.0 / Dur.grainReseed.seconds }

    private let env: RenderEnv
    private let isGrainSettingOn: Bool
    private let governor: GrainGovernor.State

    /// §13.6's `amt`. Every suppressor is already folded into `env.isShaderEnabled`
    /// (render-env.md §3) — Reduce Transparency, High Contrast, Low Power. The other two
    /// conditions are §12.6's Grain row and §14.6 risk 6's governor.
    public var amount: Double {
        guard env.isShaderEnabled, isGrainSettingOn, governor == .enabled else { return 0 }
        return Self.nominalAmount
    }

    /// The scanline term only. Dark theme only — paper has no scanline.
    public var scan: Double { env.isScanlineEnabled && amount > 0 ? 1 : 0 }

    /// §13.6's `t`, frozen at 0 under Reduce Motion. **This is Reduce Motion's whole effect
    /// on the shader.** It never touches `amount`; see reduce-motion.md §9.
    public func time(at elapsed: Duration) -> Double {
        env.isShaderTimeFrozen ? 0 : elapsed.seconds
    }
}
```

The four `guard` clauses read as three lines and are the entire policy. **Do not add a branch on
`theme == .highContrast` or on `isReduceTransparencyEnabled` here** — both already live inside
`isShaderEnabled`, and a re-derived predicate drifts from the original the first time a fourth
suppressor is added (`render-env.md` §6, and `environment-settings.md` §11 names it as a wrong).

### Reduce Motion freezes time, and it must also stop the redraw

Passing `t = 0` from inside a `TimelineView(.animation)` is correct *and* wasteful: the timeline still
invalidates every frame to hand the shader a constant. Under `env.isShaderTimeFrozen`, drop the
`TimelineView` entirely:

```swift
public func loomGrain(env: RenderEnv, isGrainSettingOn: Bool,
                      governor: GrainGovernor.State) -> some View {
    let uniforms = GrainUniforms(env: env, isGrainSettingOn: isGrainSettingOn, governor: governor)
    return Group {
        if uniforms.amount == 0 {
            self                                   // no effect, no library load, no timeline
        } else if env.isShaderTimeFrozen {
            shaded(uniforms, elapsed: .zero)       // static grain, drawn once
        } else {
            TimelineView(.animation(minimumInterval: Dur.grainReseed.seconds)) { timeline in
                shaded(uniforms, elapsed: timeline.date.timeIntervalSince(start).duration)
            }
        }
    }
}
```

`minimumInterval: Dur.grainReseed.seconds` is the other half of the budget: the grain only *changes*
at 8 Hz, so asking SwiftUI for 120 timeline ticks a second to feed `floor(t * 8)` the same value
fifteen times over buys nothing. The GPU cost of the effect is per-frame regardless; the CPU cost of
re-evaluating the timeline is not.

The `amount == 0` branch returning `self` unmodified matters more than it looks: with High Contrast on,
the play surface must have **no** `colorEffect` in its render graph at all, not a no-op one. A
zero-amplitude effect still costs a full-screen fragment pass.

### `GrainGovernor` — the testable part, and the two rules it encodes

```swift
/// §14.6 risk 6: "the shader auto-disables below 30 fps for 2 s and re-enables at a round
/// boundary." Both halves are policy thresholds, not design tokens — they answer "when does the
/// machine give up", not "how big is this mark" — so they live here with their citation and not
/// in `Dur`/`Space`.
public struct GrainGovernor: Hashable, Sendable {
    public enum State: Hashable, Sendable { case enabled, disabled }

    public static let frameRateFloor = 30.0
    public static let slowRunBeforeDisable = Duration.seconds(2)

    public private(set) var state: State = .enabled
    private var slowRunStartedAt: Duration?

    public mutating func observe(frameInterval: Duration, at now: Duration) {
        guard state == .enabled else { return }               // disabled is sticky until a boundary
        let isSlow = frameInterval.seconds > 1 / Self.frameRateFloor
        guard isSlow else { slowRunStartedAt = nil; return }   // contiguous, not cumulative
        let start = slowRunStartedAt ?? now
        slowRunStartedAt = start
        if now - start >= Self.slowRunBeforeDisable { state = .disabled }
    }

    /// The ONLY thing that re-enables. Called from `Round`'s transition into a new round —
    /// never from a recovery, never from a timer, never from `scenePhase`.
    public mutating func roundBoundary() {
        guard state == .disabled else { return }
        state = .enabled
        slowRunStartedAt = nil
    }
}
```

Three properties the tests pin, each of which a "simpler" version loses:

- **Contiguous, not cumulative.** A round with forty scattered slow frames is a round with forty
  scattered slow frames; a round with two solid seconds under 30 fps is a device that cannot afford the
  effect. Summing them turns a long round into a guaranteed disable.
- **Re-enable only at a boundary.** Recovery-based re-enabling produces visible flapping: the effect
  returns, costs frames, disables again, mid-round, repeatedly. A round boundary is a full crossfade
  through `ground.base` (§13.7.3), which is exactly where a change of texture is invisible.
- **Disabling is per-round-cost, not permanent.** Every re-enable buys a fresh 2 s window, so a device
  that genuinely cannot run it spends 2 s of one round per round on the question and no more. That is
  the bound, and it is why no extra latch is needed.

`observe` takes the interval **and** the timestamp rather than deriving one from the other, so the
whole suite runs with no clock. `Round` feeds it from the play surface's `TimelineView` cadence, and
calls `roundBoundary()` in the same transition that fires the round-end crossfade.

### Where it is applied — once, and below the chrome bar

§13.6: *over the play surface, below the chrome bar.* One call site, in `RoundView`, wrapping the
throat/ribbon/Dial region and **not** the instrument bar, which is chrome and must stay unmodulated —
"the marks glow, the chrome does not" (§13.1) is undone by grain crawling across a rule.

It also must not be applied per-component. A `colorEffect` on the throat and another on the ribbon is
two full fragment passes plus two vignettes, and the vignette is a *screen-space* term — `p / size`
is meaningless on a 112 pt sub-view. That is the same reason `throat.md` §1 says the throat draws no
vignette of its own.

`EchoRoundView` and `SieveRoundView` are play surfaces too and take the same modifier; `BenchView` is a
drawer over the Dial and inherits it from the surface beneath, which is why check 12 counts modifier
applications rather than banning them per file.

### Check 12

Appended to `Scripts/check-source-hygiene.sh` following the conventions in
`hunch-build-and-ci/references/source-hygiene.md` §3 — `|| true` on every grep, one `report` per
category, and its owning rule named in the comment:

```bash
# 12. The shader has one library, one amplitude source and one application site — §13.6.
#     Owner: hunch-design-tokens (the predicates) + this epic (the placement).
hits=$(grep -rn 'ShaderLibrary\.default' --include='*.swift' Modules App || true)
[ -n "$hits" ] && report 'ShaderLibrary.default cannot see a package resource (07 B22) — use .bundle(#bundle):' "$hits"

sites=$(grep -rln '\.colorEffect(' --include='*.swift' Modules App || true)
[ "$(printf '%s\n' "$sites" | grep -c .)" -le 1 ] || \
  report 'More than one .colorEffect in the app (§13.6: one effect over the play surface):' "$sites"

hits=$(grep -rnE 'isReduceMotionEnabled[^)]*\?[^:]*:[^;]*(amt|amount)' --include='*.swift' Modules \
       || true)
[ -n "$hits" ] && report 'Reduce Motion must freeze t, never zero amt (reduce-motion.md §9):' "$hits"

hits=$(grep -rnE 'loomGrain\(.*(1\.0|0\.0)[,)]' --include='*.swift' Modules || true)
[ -n "$hits" ] && report 'Shader amplitude bypassing GrainUniforms (§13.6, §12.6 Grain):' "$hits"
```

### The measurement, and what it is not

**≤ 0.4 ms/frame at 120 Hz on an A15 is a number read off Instruments and written into `PROGRESS.md`.**
It is not a `@Test`, and writing it as one produces a performance assertion that fails on whatever the
CI runner feels like that morning and gets `@disabled` within a fortnight. `hunch-swift-testing`'s
budget file is explicit about the split, and `tests.json` carries the entry as `manual` with
`PROGRESS.md` as its home — an honest `manual` entry is a gate; a flaky automated one is not.

What to actually do:

1. Release build to an **iPhone SE (3rd generation)** (A15 — §13.6 names the chip, and the SE is the
   reference device §6.2 already uses for layout).
2. Instruments → **Metal System Trace**, plus the **Animation Hitches** lane.
3. Play one band-6 round to inscription, including the 1,840 ms reveal — that frame is the worst case,
   because §13.5 already spends three offscreen bloom layers on it and §13.5's Assay exclusion exists
   *because of this budget*.
4. Read the fragment-shader cost per frame. Record: figure, device, iOS build, app build, date.
5. If it is over: the fixes in order are (a) confirm `minimumInterval` is the reseed period and not
   `nil`, (b) confirm the effect is applied once and not per component, (c) confirm the vignette is not
   being drawn twice. Only then consider the shader itself — and a shader change is a §13.6 change and
   needs a `DECISIONS.md` entry.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/GrainGovernorTests` green, all seven tests, with a **non-zero case count** reported (the two `HunchUITests` targets collide by name).
- [ ] `xcodebuild test … -only-testing:HunchUITests/GrainUniformTests` green, all seven.
- [ ] `bash /tmp/prove-check-12.sh` prints `CAUGHT` on all four plants, `OK` on the clean tree and `OK` on the bare `isReduceMotionEnabled` read.
- [ ] `grep -rc '\.colorEffect(' Modules App --include='*.swift' | grep -v ':0'` names exactly one file.
- [ ] `grep -n 'ShaderLibrary' Modules/Sources/HunchUI/LoomGrainModifier.swift` shows `.bundle(#bundle)` and nothing else.
- [ ] `grep -n 'LoomGrain.metal' Modules/Package.swift` shows a `.process` resource entry, and a Release build produces a `default.metallib` inside `HunchUI_HunchUI.bundle`.
- [ ] With High Contrast on, the play surface's render graph contains **no** `colorEffect` — confirmed once by eye in the SwiftUI Instrument's view-body lane.
- [ ] `PROGRESS.md` §Shader carries the Instruments figure with the device (iPhone SE 3rd generation), the OS build, the app build number and the date; the figure is ≤ 0.4 ms/frame.
- [ ] `DECISIONS.md` carries the `scan` uniform ruling, naming §13.6's printed signature and `render-env.md` §3's `isScanlineEnabled` as the two documents being reconciled.
- [ ] `tests.json` carries `shader.governor` and `shader.uniform-suppression` with commands, and `shader.budget` as `manual` with `PROGRESS.md` as its home.
- [ ] `Scripts/check-source-hygiene.sh` reports check 12 in its roster and the roster table in `hunch-build-and-ci/SKILL.md` has its row.
- [ ] The fast suite is still under 10 s (nothing here enters `HunchCore`).

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Reject any suggestion that folds `GrainUniforms.amount` into the modifier or replaces the `amount == 0` early return with a zero-amplitude effect; both delete a test and one of them costs a full-screen pass. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E20/T07: the loomGrain colorEffect, its uniform resolution and the pure GrainGovernor"`

## Out of scope

- `RenderEnv.isShaderEnabled`, `isScanlineEnabled` and `isShaderTimeFrozen` — **E03·T03**. This task consumes them and re-derives none.
- The `Grain` Settings row, its drawn toggle and its `UserDefaults` key — **E17·T06**.
- Bloom, the widened stroke and the blurred bed — **E04·T05**; they share the budget and are not this task's to change. The Assay's exclusion from bloom is **E09·T05**'s and is already shipped.
- The vignette on the throat well — **E08**; §13.6's term is the only one, and `throat.md` §1 already forbids a second.
- The SIEVE 60 Hz cap under Low Power Mode — **E14·T10**.
- Attaching cues and haptics to anything, and the Reduce Motion row-by-row re-verification — **T08**.
- The final token sweep across the eighteen screens — **T09**.
