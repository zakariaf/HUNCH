# T08 — System settings

| | |
|---|---|
| **Epic** | E19 — Accessibility |
| **Priority** | P1 |
| **Size** | M |
| **Depends on** | T07 |
| **Delivers** | System settings (ACCESSIBILITY) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | Load **first**. `references/render-env.md` §2 owns the resolution order (Bold Text ×, *then* High Contrast +) and §3 owns the derived predicates `isBloomEnabled`, `isBloomBedEnabled`, `isShaderEnabled` — the mechanism that stops eight files disagreeing about what "transparency off" means. `references/dimensions-strokes-opacity.md` §1–§2 owns the five weights, `respondsToBoldText`, and the resolved matrix. |
| `hunch-accessibility` | `references/environment-settings.md` §3–§5 owns *which marks are eligible* for Bold Text and why the play surface honours a text setting at all; §4 owns the Differentiate Without Colour additions and the rule that anything added there is a **fourth** copy of a distinction, never a first. |

## Objective

At the end of this task the three system settings that are not a theme and not a size are honoured
everywhere they apply, and every one of them is read through a **derived predicate** rather than a raw
flag. Reduce Transparency kills the shader and both bloom passes and flattens every material; Bold Text
steps every type role one weight and every eligible stroke by its multiplier; Differentiate Without
Colour doubles the broken ring's gap and gives the counterexample's two rings distinct dash patterns.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §13.11 (Reduce Transparency) | shader `amt = 0`; bloom off; every material becomes opaque `ground.raised`; the Bench scrim goes from a 0.6 α blur to a flat 0.85 α `ground` |
| `GAME_DESIGN.md` | §13.11 (Bold Text) | every type role steps one weight (regular → medium → semibold → bold), **and** glyph and rule-tile stroke weights step ×1.25, with the three worked examples that pin the multiplication to the base |
| `GAME_DESIGN.md` | §13.11 (Differentiate Without Colour) | true by construction, and then: ribbon admit tiles draw a fully closed ring, reject tiles a broken ring at **2× the normal gap**, and the counterexample's two rings take distinct dash patterns |
| `GAME_DESIGN.md` | §13.7.2 | the verdict's non-colour encoding is ring direction and closure — admit expands and stays closed, reject contracts and breaks; colour, tone and haptic are three redundant copies layered on that |
| `GAME_DESIGN.md` | §13.6 | the shader is one stitchable `colorEffect`; `amt` is what Reduce Transparency zeroes |
| `GAME_DESIGN.md` | §13.5.1 | every one of the glyph's four channels survives greyscale — which is why Differentiate Without Colour changes no token |
| `.claude/skills/hunch-accessibility/references/environment-settings.md` | §3, §4, §5 | the eligible mark set, the reasoning, and the two rows the setting adds |
| `.claude/skills/hunch-design-tokens/references/render-env.md` | §2, §3 | the resolution order and the derived predicates |

## TDD — the test comes first

`RenderEnv` is a value with a defaulted initialiser, so the whole matrix is one line per case and no
simulator is involved. E03·T05 already asserts the **arithmetic**; this task asserts the
**application** — that each component actually reads the predicate and changes what §13.11 says it
changes.

**Step 1 — write the failing test.** Create `Modules/Tests/HunchUITests/SystemSettingsTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
@testable import HunchUI

@Suite("Reduce Transparency, Bold Text, Differentiate Without Colour — §13.11", .tags(.unit, .presubmission))
struct SystemSettingsTests {

    // MARK: Reduce Transparency

    @Test("Reduce Transparency turns the shader and both bloom passes off")
    func reduceTransparencyKillsShaderAndBloom() {
        let env = RenderEnv(isReduceTransparencyEnabled: true)
        #expect(env.isShaderEnabled == false)
        #expect(env.isBloomEnabled == false)
        #expect(env.isBloomBedEnabled == false)
    }

    @Test("the Bench scrim becomes a flat opaque fill, not a blur")
    func benchScrimGoesFlat() {
        let blurred = C.Scrim.bench(in: RenderEnv())
        let flat = C.Scrim.bench(in: RenderEnv(isReduceTransparencyEnabled: true))
        #expect(blurred.isBlurred)
        #expect(!flat.isBlurred)
        #expect(flat.opacity == C.Scrim.opaqueAlpha)
        #expect(flat.fill == Palette(theme: .dark).ground.base)
    }

    @Test("the SIEVE pause scrim takes the same substitution")
    func sievePauseScrimGoesFlat() {
        #expect(!C.Scrim.sievePause(in: RenderEnv(isReduceTransparencyEnabled: true)).isBlurred)
    }

    @Test("every material becomes an opaque raised ground", arguments: MaterialRole.allCases)
    func everyMaterialGoesOpaque(_ role: MaterialRole) {
        let material = C.Material.resolve(role, in: RenderEnv(isReduceTransparencyEnabled: true))
        #expect(material.isOpaque)
        #expect(material.fill == Palette(theme: .dark).ground.raised)
    }

    @Test("Low Power Mode reaches the same three predicates by a different route and is NOT an accessibility setting")
    func lowPowerIsADifferentRoute() {
        let lowPower = RenderEnv(isLowPowerModeEnabled: true)
        #expect(lowPower.isShaderEnabled == false)
        #expect(lowPower.isBloomEnabled == false)
        #expect(lowPower.isReduceTransparencyEnabled == false)     // the flag itself is untouched
    }

    // MARK: Bold Text

    @Test("every eligible stroke steps by the multiplier; the resolved ladder stays strictly increasing")
    func boldTextStepsTheLadder() {
        let plain = RenderEnv(), bold = RenderEnv(isBoldTextEnabled: true)
        let order: [StrokeWeight] = [.hairline, .thin, .bodySm, .body, .heavy]
        let boldValues = order.map { bold.weight($0) }
        #expect(zip(boldValues, boldValues.dropFirst()).allSatisfy { $0 < $1 })
        for token in order { #expect(bold.weight(token) > plain.weight(token)) }
    }

    @Test("§13.11's three worked examples pin the multiplication to the BASE")
    func workedExamples() {
        let bold = RenderEnv(isBoldTextEnabled: true)
        #expect(bold.weight(.hairline) == 0.625)
        #expect(bold.weight(.bodySm)   == 1.875)
        #expect(bold.weight(.body)     == 3.750)
    }

    @Test("every type role steps exactly one notch and clamps at bold", arguments: TypeRole.allCases)
    func typeRolesStepOneNotch(_ role: TypeRole) {
        let plain = RenderEnv().type(role).weight
        let bold = RenderEnv(isBoldTextEnabled: true).type(role).weight
        #expect(bold == plain.steppedOnce)
        #expect(bold <= .bold)
    }

    @Test("the opt-out set is exactly the five component weights that must not thicken")
    func optOutSet() {
        let optedOut = C.allComponentWeights.filter { !$0.respondsToBoldText }.map(\.id).sorted()
        #expect(optedOut == ["assay.gridline", "chrome.rule", "glyph.pipKnockout",
                             "shader.scanline", "tickRow.tick"])
    }

    @Test("an opted-out component weight is identical with Bold Text on and off")
    func optedOutWeightsDoNotMove() {
        for token in C.allComponentWeights where !token.respondsToBoldText {
            #expect(token.resolved(in: RenderEnv(isBoldTextEnabled: true))
                    == token.resolved(in: RenderEnv()))
        }
    }

    @Test("Bold Text never multiplies a LENGTH — art has its own axis")
    func boldTextTouchesNoLength() {
        #expect(RenderEnv(isBoldTextEnabled: true).artScale == RenderEnv().artScale)
    }

    // MARK: Differentiate Without Colour

    @Test("the setting changes no token — it only adds geometry", arguments: RenderEnv.Theme.allCases)
    func differentiateChangesNoToken(_ theme: RenderEnv.Theme) {
        let off = RenderEnv(theme: theme)
        let on = RenderEnv(theme: theme, isDifferentiateWithoutColorEnabled: true)
        #expect(Palette(theme: theme) == Palette(theme: theme))     // same palette either way
        #expect(off.weight(.body) == on.weight(.body))
        #expect(off.artScale == on.artScale)
    }

    @Test("an admit ring is fully closed and a reject ring's gap doubles")
    func ringGapsUnderDifferentiate() {
        let on = RenderEnv(isDifferentiateWithoutColorEnabled: true)
        #expect(VerdictRing.gap(for: .admit, in: on) == 0)
        #expect(VerdictRing.gap(for: .reject, in: on)
                == VerdictRing.gap(for: .reject, in: RenderEnv()) * 2)
    }

    @Test("the counterexample's two rings take distinct dash patterns: solid is the Loom, dashed is you")
    func counterexampleDashPatterns() {
        let on = RenderEnv(isDifferentiateWithoutColorEnabled: true)
        let rings = CounterexampleRings.patterns(in: on)
        #expect(rings.loom.dash.isEmpty)                            // solid = the Loom's verdict
        #expect(!rings.declaration.dash.isEmpty)                    // dashed = your declaration's
        #expect(rings.loom.dash != rings.declaration.dash)
    }

    @Test("the two rings stay distinguishable without colour AND without memory: they differ in dash, not in hue")
    func counterexampleRingsAreNotTwoColours() {
        let rings = CounterexampleRings.patterns(in: RenderEnv(isDifferentiateWithoutColorEnabled: true))
        #expect(rings.loom.dash != rings.declaration.dash)
        #expect(rings.loom.strokeRole == rings.declaration.strokeRole)   // NOT two colours plus a legend
    }
}
```

And append **check 11e** to `Scripts/check-source-hygiene.sh`:

```bash
# check 11e — read the PREDICATE, never the flag. A view that re-derives one drifts from it the
# first time a fourth suppressor is added (render-env.md §3).
if grep -Rn 'isReduceTransparencyEnabled\|isLowPowerModeEnabled' Modules/Sources --include='*.swift' \
   | grep -v 'RenderEnv.swift' | grep -v 'RenderEnvReader.swift'; then
  fail "branch on env.isBloomEnabled / isShaderEnabled, not on the raw flag"
fi
```

**Step 2 — run it and watch it fail.** `swift test --package-path Modules --filter SystemSettingsTests`

Missing `C.Scrim`, `C.Material`, `C.allComponentWeights`, `VerdictRing.gap(for:in:)`,
`CounterexampleRings.patterns(in:)`, `TypeWeight.steppedOnce`. `differentiateChangesNoToken` will pass
immediately and must — it is a **regression guard**, not a driver, and its job is to fail the day
somebody "implements" the setting by re-lighting a colour. Say so in the test's comment.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| modify | `HunchCore/Sources/Tokens/C.swift` — `C.Scrim`, `C.Material`, and `respondsToBoldText` on the five opted-out component weights |
| modify | `Modules/Sources/HunchUI/Typography.swift` — `TypeWeight.steppedOnce` and the clamp at bold |
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift` — bloom gated on `env.isBloomEnabled` / `env.isBloomBedEnabled`, never on a raw flag |
| modify | `Modules/Sources/HunchUI/LoomGrain.metal` call site — `amt` from `env.isShaderEnabled` |
| modify | `Modules/Sources/HunchUI/VerdictRing.swift` *(E04·T07)* — the doubled gap |
| modify | `Modules/Sources/HunchUI/CounterexampleRings.swift` *(E04·T07 / E09·T09)* — the two dash patterns |
| modify | `Modules/Sources/LoomFeature/BenchView.swift`, `SievePauseOverlay.swift` — the scrim substitution |
| modify | `Modules/Sources/HunchUI/GlyphCanvas.swift`, `RuleTileCanvas.swift` — eligible strokes read `env.weight(_:)` |
| modify | `Modules/Sources/HunchUI/SnapshotGallery.swift` *(E04·T09)* — rows for the three settings |
| create | `Modules/Tests/HunchUITests/SystemSettingsTests.swift` |
| modify | `Scripts/check-source-hygiene.sh` — check 11e |
| modify | `tests.json` — the three system-settings entries |
| modify | `DECISIONS.md` — the Bold Text eligibility ruling below |

## Implementation notes

### Read the predicate, never the flag

`env.isBloomEnabled`, `env.isBloomBedEnabled` and `env.isShaderEnabled` each fold Reduce Transparency
together with High Contrast **and** Low Power Mode. A view that writes `if env.isReduceTransparencyEnabled`
has re-derived a predicate that already exists and will drift from it the first time a fourth
suppressor appears — and Low Power Mode is precisely that fourth suppressor already, reaching the same
three predicates by a different route while **not** being an accessibility setting. Check 11e is the
mechanical version of this paragraph.

The one place the raw flags are legal is `RenderEnvReader`, which builds the record, and `RenderEnv`
itself, which derives the predicates from them.

### Reduce Transparency, row by row

| Screen / element | What happens |
|---|---|
| every play surface | the shader is off (`env.isShaderEnabled` is false) |
| every glyph-bearing region | bloom is off — **both** the widened stroke (pass B) and the layer filter (pass A) |
| the Bench scrim | 0.6 α blur → a flat 0.85 α `ground` fill |
| `SievePauseOverlay` scrim | the same substitution |
| every material anywhere | becomes an opaque raised ground |

Two passes, not one: `isBloomEnabled` gates the widened halo and `isBloomBedEnabled` gates the blurred
region clone that is the app's only offscreen layer. Turning off one and leaving the other is the bug
this split exists to make visible, and `reduceTransparencyKillsShaderAndBloom` asserts both.

### Bold Text — and the eligibility contradiction, ruled

`dimensions-strokes-opacity.md` §1 says **all five L1 weights respond**, because eligibility is a
property of the token and because the ladder has to move together — if `weight.body` stepped while
`weight.heavy` held, the gap that makes the AND welded bar read heavier than a body stroke would
collapse. `environment-settings.md` §3 says the eligible **marks** are the glyph body, index stroke and
pip ring plus rule-tile strokes, and that chrome hairlines, the Assay grid, tick rows and the shader
are *not* eligible.

**Ruling, which satisfies both reasons rather than picking a side: all five L1 `weight.*` tokens
respond to Bold Text, and eligibility is refused at L2, per component, through
`respondsToBoldText = false`.** The opt-out set is exactly five component weights:

| Component weight | Why it opts out |
|---|---|
| `glyph.pipKnockout` | a 1 pt geometric separator that must stay 1 pt or it eats the pip |
| `chrome.rule` | thickening it undoes §13.1's *marks glow, chrome does not* commitment |
| `assay.gridline` | 256 cells at 4 pt; a heavier grid reads as more ink, which is the Assay's only channel |
| `tickRow.tick` | tick *length* is the signal; weight is not, and a heavier row reads as a longer par |
| `shader.scanline` | not a mark at all |

Everything else — the glyph body, the index stroke, the pip stroke, every rule-tile stroke, the wedge,
the coupler strands, the machined bar — steps. Record the ruling in `DECISIONS.md` with both skill
files cited, because the next reader will find the same apparent contradiction.

The reasoning worth keeping, because it is the thing somebody will try to "fix": **the play surface has
no text, so Bold Text is the only signal iOS gives us that this player wants heavier marks.** Honouring
it on the glyph is more useful than ignoring it because "there is no text here".

Reading it: `@Environment(\.legibilityWeight) == .bold`. **There is no `\.accessibilityBoldText`**, and
reaching for `UIAccessibility.isBoldTextEnabled` in a view means wiring a notification observer for a
value SwiftUI already invalidates on.

### Differentiate Without Colour — the fourth copy, never the first

**True by construction, and then made truer.** §13.5.1 already proves every one of the glyph's four
channels survives greyscale, so nothing on the play surface depends on chromatic discrimination before
the setting is read. The setting therefore **changes no token** — it is in `RenderEnv` anyway because
components need it, and because a seven-axis record that silently dropped an axis is the failure the
whole design exists to prevent.

| Element | What is added when on |
|---|---|
| ribbon admit tile | the ring draws fully closed |
| ribbon reject tile | the ring breaks at **twice** the normal gap |
| the counterexample's two rings | distinct dash patterns — **solid = the Loom's verdict, dashed = your declaration's** |

The counterexample row is the one carrying real information: two contradictory readings of one glyph
become separable without colour *and without memory*. **Do not re-encode it as two colours plus a
legend** — `counterexampleRingsAreNotTwoColours` asserts the two rings share a stroke role and differ
only in dash, which is what makes that impossible to do by accident.

Anything added under this setting must be a **fourth** copy of a distinction, never a first: the
verdict is already expand-and-close against contract-and-break, with colour, tone and haptic as three
redundant copies of that.

### The snapshot gallery

E04·T09's DEBUG gallery already draws every component × state × three themes × {normal, Bold Text,
Reduce Motion}. Add the two rows this task needs — Reduce Transparency and Differentiate Without
Colour — so the visual-regression corpus covers the settings rather than only the themes. The gallery
is a `.snapshot`-tagged suite and does not run in the presubmission plan.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter SystemSettingsTests` green, all fourteen tests.
- [ ] `Scripts/check-source-hygiene.sh` green with check 11e, demonstrated to fire on a planted `if env.isReduceTransparencyEnabled` in a view before reverting.
- [ ] `grep -Rn 'isBloomEnabled\|isBloomBedEnabled\|isShaderEnabled' Modules/Sources --include='*.swift'` shows every bloom and shader site reading a predicate.
- [ ] `grep -Rn 'respondsToBoldText' HunchCore/Sources/Tokens/C.swift` shows exactly five `false`s, and they are the five named above.
- [ ] `RenderEnv(isBoldTextEnabled: true)`'s five resolved weights are strictly increasing and match §13.11's three worked examples exactly (`==`, not a tolerance — all ten values are exact in binary).
- [ ] The snapshot gallery renders Reduce Transparency and Differentiate Without Colour rows.
- [ ] `tests.json` carries three entries — one per setting — `source: "§13.11"`.
- [ ] `DECISIONS.md` carries the Bold Text eligibility ruling.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E19/T08: Reduce Transparency, Bold Text and Differentiate Without Colour, through the predicates"`

## Out of scope

- The High Contrast theme — **T09**, which is a *theme* and not a toggle, and whose substitutions terminate resolution rather than composing with these.
- `RenderEnv`'s definition, the resolution order and the token arithmetic — **E03·T03/T04/T05**.
- Reduce Motion — **E09·T12**, **E14·T10**; it is a different axis and the motion skill owns the whole substitution table.
- The `loomGrain` shader itself and its performance budget — **E20·T07**; this task only zeroes `amt`.
- The verdict ring and counterexample ring **drawings** — **E04·T07**, **E09·T09**; this task only changes their gap and dash under one flag.
