# T02 — The pool strip

| | |
|---|---|
| **Epic** | E13 — ECHO |
| **Priority** | P0 |
| **Size** | M |
| **Depends on** | T01 |
| **Delivers** | The pool strip (ECHO) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-design-tokens` | First, because this task draws. The extinguished member is 25 % — a named opacity, not a literal — and `check-source-hygiene.sh` check 9 fails the build on a bare `.opacity(0.25)`. It also owns the High Contrast substitution that takes the cancel hatch to 2.0 pt and *terminates resolution* there rather than also scaling it. |
| `hunch-chrome-and-meta` | `references/extension-thumbnail.md` owns the 16 × 16 deck signature, its two sizes and its `cell = (side − 2·inset)/16` rule. The pool member is that mark at 40 pt, so the strip **composes** the thumbnail and never re-derives it — and this skill's file is the one that will disagree with `hunch-bench-instruments/references/assay-grid.md` by 0.25 pt, which is why the conflict is resolved in this task and not discovered in review. |
| `hunch-shared-marks` | `references/cancel-hatch.md` names the eliminated ECHO pool member as one of the cancel hatch's four sites, with the `.hatch` variant and the `.chrome` paint. Drawing a second hatch here is precisely the §2(g) drift the skill exists to prevent, and it also owns the rule that a mark never sets opacity on the caller's context — which matters because the strip dims a member and the hatch inside it must not dim with it. |
| `hunch-swift-code` | `PrimerChain` and the elimination predicate are core, pure and `Sendable`; the strip is a view. The boundary predicate decides which half of this task goes where, and `01 P24` decides that `PrimerChain` gets its own file rather than riding inside `EchoPool.swift`. |

## Objective

At the end of this task the candidate set is **on screen**: eight 40 pt extension thumbnails in Codex
order, oldest leading, each one extinguishing to 25 % under a diagonal cancel hatch the instant a
primer verdict rules it out. The elimination itself is a pure function of `(pool snapshot, chain,
position)` in `HunchCore`, so §8.9's "recomputed on resume, never stored" is a property of the code
rather than a note in a document.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §8.2 (the second Decision, in full) | the strip's existence and its whole argument: three to five ringed glyphs cannot pin a law out of 27,015, they can only separate members of a candidate set, and if that set is not on screen the deduction is unaided recall |
| `GAME_DESIGN.md` | §8.4 (pool strip row, and the paragraph under the table) | y 68–108, 40 × 40 pt, 6 pt gutters, `8·40 + 7·6 = 362` in 375, Codex order oldest leading, read-only, not a hit target, pinned throughout the round; AX2+ wraps to two rows of four |
| `GAME_DESIGN.md` | §8.8 clause (2) | why the strip is load-bearing rather than helpful — without it §8.8 is false |
| `GAME_DESIGN.md` | §8.9 | the lit/extinguished state is a pure function of `(pool snapshot, primer chain, primer position)` and is never stored |
| `GAME_DESIGN.md` | §3.5 | `prev` semantics — the seed glyph primes position 0, and adjacency inside the chain supplies `prev` for the rest |
| `GAME_DESIGN.md` | §4.2, §13.11 | the 25 % + diagonal cancel hatch idiom, borrowed verbatim from the unlit Bench cell; High Contrast takes the hatch to 2.0 pt |
| `GAME_DESIGN.md` | §12.8 | read-only surfaces are exempt from the 44 pt hit floor, exactly as the ribbon's link arcs are |
| `GAME_DESIGN.md` | §13.10 | the strip is exposed to VoiceOver as a grouped static element with the canonical `fill → shape → pips → hue` labelling and a lit/extinguished state |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §2, §4 | `PrimerChain` is core and `Sendable`; `PoolStripView` is `LoomFeature` and inherits `.defaultIsolation(MainActor.self)` |

## TDD — the test comes first

**Step 1 — write the failing test.** Two files.

`HunchCore/Tests/RoundsTests/PrimerChainTests.swift`:

```swift
import Testing
@testable import Rounds
import Glyphs
import Laws
import HunchTestSupport

@Suite("PrimerChain — verdict vectors and elimination", .tags(.unit, .presubmission))
struct PrimerChainTests {

    private let seed = Deck.glyph(id: 22)

    @Test("a stateless law's verdict vector is its verdict on each chain glyph, in order")
    func statelessVector() {
        let law = Law(Corpora.law(band: .literal, index: 0))
        let glyphs = [Deck.glyph(id: 3), Deck.glyph(id: 88), Deck.glyph(id: 201)]
        let chain = PrimerChain(seed: seed, glyphs: glyphs)

        #expect(chain.verdicts(under: law) == glyphs.map { law.admits($0, after: seed) })
    }

    @Test("a contextual law takes prev from the chain's own adjacency, with the seed priming 0")
    func contextualVectorUsesChainAdjacency() {
        let law = Law(Corpora.law(band: .contextual, index: 4))
        let glyphs = [Deck.glyph(id: 10), Deck.glyph(id: 77), Deck.glyph(id: 150), Deck.glyph(id: 4)]
        let chain = PrimerChain(seed: seed, glyphs: glyphs)

        let expected = [law.admits(glyphs[0], after: seed),          // §3.5: the seed primes position 0
                        law.admits(glyphs[1], after: glyphs[0]),
                        law.admits(glyphs[2], after: glyphs[1]),
                        law.admits(glyphs[3], after: glyphs[2])]
        #expect(chain.verdicts(under: law) == expected)
    }

    @Test("the vector length is the chain length, for every legal m", arguments: 3...5)
    func vectorLength(_ m: Int) {
        let law = Law(Corpora.law(band: .pair, index: 1))
        let chain = PrimerChain(seed: seed, glyphs: (0..<m).map { Deck.glyph(id: UInt8(20 + $0 * 7)) })
        #expect(chain.verdicts(under: law).count == m)
    }

    @Test("survivors after position 0 keep every member agreeing with the first verdict")
    func survivorsAfterOnePosition() {
        let pool = Corpora.separablePool(seed: 0xA1)      // 8 members, known separable at m = 3
        let inForce = pool.members[5]
        let chain = Corpora.separatingChain(for: inForce, in: pool, seed: 0xA1)
        let truth = chain.verdicts(under: Law(inForce.law))

        let after0 = pool.survivors(of: chain, upTo: 1, observed: truth)
        #expect(after0.contains(inForce.lawKey))
        for member in pool.members where !after0.contains(member.lawKey) {
            #expect(chain.verdicts(under: Law(member.law))[0] != truth[0])
        }
    }

    @Test("survivors shrink monotonically and end at exactly one — the strip's whole argument")
    func survivorsShrinkToOne() {
        let pool = Corpora.separablePool(seed: 0xA2)
        let inForce = pool.members[2]
        let chain = Corpora.separatingChain(for: inForce, in: pool, seed: 0xA2)
        let truth = chain.verdicts(under: Law(inForce.law))

        var previous = Set(pool.members.map(\.lawKey))
        for position in 0...chain.glyphs.count {
            let survivors = pool.survivors(of: chain, upTo: position, observed: truth)
            #expect(survivors.isSubset(of: previous))     // a verdict never re-lights a member
            #expect(survivors.contains(inForce.lawKey))   // the law in force is never extinguished
            previous = survivors
        }
        #expect(previous == [inForce.lawKey])             // §8.5's invariant, at the source
    }

    @Test("survivors are a pure function of (pool, chain, position) — nothing is stored")
    func survivorsArePure() {
        let pool = Corpora.separablePool(seed: 0xA3)
        let inForce = pool.members[7]
        let chain = Corpora.separatingChain(for: inForce, in: pool, seed: 0xA3)
        let truth = chain.verdicts(under: Law(inForce.law))

        let first = pool.survivors(of: chain, upTo: 2, observed: truth)
        let second = pool.survivors(of: chain, upTo: 2, observed: truth)
        #expect(first == second)
        // …and computing position 3 first does not change the answer for position 2.
        _ = pool.survivors(of: chain, upTo: 3, observed: truth)
        #expect(pool.survivors(of: chain, upTo: 2, observed: truth) == first)
    }
}
```

`Modules/Tests/LoomFeatureTests/PoolStripTests.swift`:

```swift
import Testing
import HunchCore
@testable import LoomFeature
import ModulesTestSupport

@Suite("The pool strip — §8.4", .tags(.unit, .presubmission))
@MainActor
struct PoolStripTests {

    @Test("eight members, 40 pt each, 6 pt gutters, fit the SE's 375 pt width exactly")
    func stripFitsTheReferenceWidth() {
        let layout = PoolStripLayout(memberCount: 8, width: Device.se.width, env: .reference)
        #expect(layout.rows == 1)
        #expect(layout.contentWidth == 8 * C.Echo.poolThumbSide + 7 * C.Echo.poolGutter)
        #expect(layout.contentWidth <= Device.se.width)
        #expect(layout.frame.minY == C.Echo.poolStripTop)
        #expect(layout.frame.height == C.Echo.poolThumbSide)
    }

    @Test("a short pool draws only its own members and never a placeholder", arguments: 3...8)
    func shortPoolDrawsWhatItHas(_ count: Int) {
        let layout = PoolStripLayout(memberCount: count, width: Device.se.width, env: .reference)
        #expect(layout.slots == count)
    }

    @Test("at AX2 and above the strip wraps to two rows of four (§8.4)")
    func wrapsAtAX2() {
        let layout = PoolStripLayout(memberCount: 8, width: Device.se.width, env: .ax2)
        #expect(layout.rows == 2)
        #expect(layout.columns == 4)
    }

    @Test("an extinguished member is 25 % and carries the hatch; a lit one carries neither")
    func extinguishedRendering() {
        #expect(PoolMemberStyle.extinguished.ink(in: .reference) == C.Echo.memberExtinguishedInk(in: .reference))
        #expect(PoolMemberStyle.extinguished.drawsCancelHatch)
        #expect(!PoolMemberStyle.lit.drawsCancelHatch)
    }

    @Test("the strip is read-only: no member is a hit target and none is a Button")
    func stripIsNotAHitTarget() {
        let probe = InteractionProbe(PoolStripView(pool: Fixtures.echoPool,
                                                   survivors: [Fixtures.echoPool.members[1].lawKey],
                                                   env: .reference))
        #expect(probe.hitTargets.isEmpty)
        #expect(probe.buttonCount == 0)
    }

    @Test("VoiceOver sees one container with a per-member lit/extinguished value")
    func voiceOverShape() {
        let elements = AccessibilityProbe(PoolStripView(pool: Fixtures.echoPool,
                                                        survivors: [Fixtures.echoPool.members[1].lawKey],
                                                        env: .reference)).elements
        #expect(elements.count == Fixtures.echoPool.members.count)
        #expect(elements.allSatisfy { $0.traits.contains(.isStaticText) })
        #expect(elements[1].value == Loc.poolMemberLit)
        #expect(elements[0].value == Loc.poolMemberExtinguished)
    }

    @Test("the strip never renders a character outside an accessibility modifier")
    func noText() throws {
        let source = try String(contentsOfFile: SourcePath.poolStripView, encoding: .utf8)
        #expect(!source.contains("Text(") || source.ranges(of: "Text(").allSatisfy {
            source.accessibilityModifierEncloses($0)
        })
    }
}
```

**Step 2 — run it and watch it fail.**
`swift test --package-path HunchCore --filter PrimerChainTests`, then
`xcodebuild test … -only-testing:LoomFeatureTests/PoolStripTests`.
Missing symbols only. `InteractionProbe`, `AccessibilityProbe` and `SourcePath` are
`ModulesTestSupport`'s; if E08/E09 spelled them differently, use theirs and do not add a second set.

**Step 3 — implement** the minimum that turns it green.

**Step 4 — green, then refactor.**

## Files

| Action | Path |
|---|---|
| create | `HunchCore/Sources/Rounds/PrimerChain.swift` |
| modify | `HunchCore/Sources/Rounds/EchoPool.swift` — `survivors(of:upTo:observed:)` |
| modify | `HunchCore/Sources/Tokens/C.swift` — the `C.Echo` namespace opens here |
| create | `Modules/Sources/LoomFeature/PoolStripView.swift` |
| create | `Modules/Sources/LoomFeature/PoolStripLayout.swift` |
| modify | `Modules/Sources/HunchUI/Loc.swift` — two accessibility values |
| modify | `Modules/Sources/HunchUI/Resources/Localizable.xcstrings` — two keys |
| create | `HunchCore/Tests/RoundsTests/PrimerChainTests.swift` |
| create | `Modules/Tests/LoomFeatureTests/PoolStripTests.swift` |
| modify | `tests.json` — three entries |
| modify | `DECISIONS.md` — the 2.25 / 2.5 pt ruling |

## Implementation notes

### `PrimerChain` — the value, and only the value

```swift
// HunchCore/Sources/Rounds/PrimerChain.swift
/// The `m` ringed glyphs that identify which pool member is in force (§8.2). The chain is the
/// *stimulus*; the verdicts are derived, never stored, because storing them would let a resumed
/// round disagree with the law it restored.
public struct PrimerChain: Codable, Hashable, Sendable {
    public let seed: Glyph                 // primes position 0 (§3.5); not itself a primer glyph
    public let glyphs: [Glyph]             // m ∈ {3,4,5}; pairwise distinct

    public init(seed: Glyph, glyphs: [Glyph])

    /// - Complexity: O(m), one mask lookup per position.
    public func verdicts(under law: Law) -> [Verdict]
}
```

`verdicts(under:)` is a fold with `prev` starting at `seed`:

```swift
public func verdicts(under law: Law) -> [Verdict] {
    var previous = seed
    return glyphs.map { glyph in
        defer { previous = glyph }
        return law.admits(glyph, after: previous) ? .admit : .reject
    }
}
```

Two things this pins that a reader would otherwise get wrong. **The seed is not a primer glyph** — it
is drawn at 36 pt in a dashed ghost frame (§8.4), it carries no verdict ring, and it is not in
`glyphs`. And **`prev` is chain adjacency, not probe history**: ECHO has no probes, so §3.5's
"previously probed glyph" resolves to "the preceding glyph in the chain", which is the only reading
under which §8.2's *"the chain's adjacent pairs supply `prev`"* is true.

The search that *finds* a chain is T03's. This file holds no search, no RNG and no 200-attempt loop.

### Elimination

```swift
extension EchoPool {
    /// §8.2: every member inconsistent with the verdict vector so far is extinguished.
    /// §8.9: a pure function of (snapshot, chain, position) — recomputed on resume, never stored.
    /// - Parameter position: how many primer verdicts have resolved, 0…chain.glyphs.count.
    public func survivors(of chain: PrimerChain, upTo position: Int,
                          observed: [Verdict]) -> Set<UInt64>
}
```

The body is one filter: a member survives iff its own vector agrees with `observed` on every index
below `position`. `position == 0` returns all members — the strip opens with all eight lit (§8.5's
`arming → priming` row). `position == chain.glyphs.count` is the transition T09 asserts on.

Take `observed` as a parameter rather than recomputing it from the in-force law. The strip must be
drawable from `(snapshot, chain, position)` alone — that is §8.9's phrasing verbatim — and a signature
that needs the in-force law to dim the others would leak which member is in force one frame early.

Cost: 8 members × 5 positions × one mask lookup. Nothing here needs caching, and caching it would
re-introduce the stored state §8.9 forbids.

### The strip's geometry, and a conflict to resolve before drawing

`C.Echo` opens in `HunchCore/Sources/Tokens/C.swift` with the strip's four numbers, each carrying its
§8.4 citation: the thumbnail side, the gutter, the strip's top, and the wrap threshold. The arithmetic
identity `8·side + 7·gutter = 362 ≤ 375` is asserted in the test, not commented.

**The 0.25 pt conflict, and the ruling.** Two reference files describe the same 40 pt mark:

- `hunch-chrome-and-meta/references/extension-thumbnail.md` §1 — side 40, `cell = (40 − 2·2)/16 = 2.25`, with a 2 pt inset "the hairline frame somewhere to sit".
- `hunch-bench-instruments/references/assay-grid.md` — `C.Assay.cellSide(.echoPool) = 2.5`, grid 40 × 40, no inset.

They cannot both be the drawing: `16 · 2.5 = 40` leaves no room for a frame, and `16 · 2.25 + 4 = 40`
does. **Rule for the framed one**, and record it in `DECISIONS.md`: §8.2 calls the pool member an
*extension thumbnail*, `ExtensionThumbnail` is that mark's one owning symbol, and the strip must
distinguish lit from extinguished at 25 % — which is unreadable without a frame the hatch can key
against. So `PoolStripView` composes `ExtensionThumbnail(law:side:)` and the `.echoPool` case is
removed from `C.Assay.Site` (or, if E09·T05 already depends on that case elsewhere, its value is
corrected to 2.25 and the accessor keeps one home). The scope document lists the 40 pt ECHO pool under
*both* rows; the decision entry is what stops that ambiguity turning into two drawings.

If `ExtensionThumbnail` does not exist yet — it is E15·T03's owning symbol and E15 has not run — create
it **now**, in `Modules/Sources/HunchUI/ExtensionThumbnail.swift`, to the geometry and ink rules
`references/extension-thumbnail.md` §§1–2 already fix, and record in the ownership table that E15·T03
extends it with the Codex's 60 pt site, the four-level contextual projection and the three overlays.
Creating it here and extending it there is correct; drawing a second 16 × 16 grid inside
`PoolStripView` is the failure mode.

### Extinguished

The extinguished member is exactly the unlit Bench cell's idiom (§4.2), borrowed on purpose so the
player has already learned it:

```swift
// Modules/Sources/LoomFeature/PoolStripView.swift
ExtensionThumbnail(law: member.law, side: C.Echo.poolThumbSide, env: env)
    .opacity(isLit ? 1 : C.Echo.memberExtinguishedOpacity(in: env))
    .overlay {
        if !isLit {
            Canvas { context, size in
                CancelHatch.draw(context, in: CGRect(origin: .zero, size: size),
                                 variant: .hatch, paint: .chrome, env: env)
            }
            .accessibilityHidden(true)
        }
    }
```

Three rules from `hunch-shared-marks` that the code above obeys and a hand-rolled version would not:

- The hatch is `CancelHatch.draw`, one owning function, four sites. Not a `Path` here.
- **The hatch is never dimmed with the cell.** Put the `.opacity` on the thumbnail, not on the group; a hatch at 25 % of 25 % is invisible and the member reads as merely faint rather than as ruled out.
- The mark takes `GraphicsContext` by value and must not leak clip, opacity or blend back to the host. If the whole strip ever dims, this is the line to look at.

**High Contrast substitutes rather than scales**: `references/cancel-hatch.md` fixes the hatch at
2.0 pt under High Contrast and that value *terminates* resolution — it does not then take
`env.weight(_:)`'s flat +0.5. The extinguished opacity likewise moves to its High Contrast value
(40 %) through the token, never through a branch in the view.

### Read-only, and why that is legal

The strip is not a hit target (§8.4) and is therefore exempt from the 44 pt floor (§12.8), exactly as
the ribbon's link arcs are. The exemption is only honest if the strip is *exposed*, so:

```swift
.accessibilityElement(children: .contain)      // the strip is a container…
```

with each member an element carrying `.isStaticText`, the canonical `fill → shape → pips → hue` label
through `Loc.glyphLabel`, and a value of `Loc.poolMemberLit` / `Loc.poolMemberExtinguished`. Never
`.combine` — gluing fragments is §12.9 trap 3. And never a `Button`: `InteractionProbe.hitTargets`
being empty is the assertion that keeps the exemption true after a refactor.

Two catalog keys, both inside the 250-key budget (§12.9's VoiceOver row).

## Acceptance criteria

- [ ] `swift test --package-path HunchCore --filter PrimerChainTests` green, all six tests, including the monotone-shrink sweep.
- [ ] `xcodebuild test … -only-testing:LoomFeatureTests/PoolStripTests` green, all seven tests.
- [ ] `grep -rn "0\.25\|opacity(0\." Modules/Sources/LoomFeature/PoolStripView.swift` returns nothing, and `Scripts/check-source-hygiene.sh` check 9 is green.
- [ ] `grep -rn "16" Modules/Sources/LoomFeature/PoolStripView.swift` shows no 16 × 16 grid loop — the thumbnail is composed, not redrawn.
- [ ] `bash .claude/skills/hunch-shared-marks/SKILL.md`'s Step 0 listing shows exactly one `CancelHatch` declaration.
- [ ] `DECISIONS.md` records the 2.25 pt ruling with both reference files named and the reason stated.
- [ ] `tests.json` carries three entries: elimination purity, monotone shrink to one member, and the strip's read-only exposure.
- [ ] The fast suite is still under 10 s.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E13/T02: PrimerChain, the elimination predicate and the pool strip"`

## Out of scope

- **Finding** a chain that separates the pool — **T03**. This task evaluates a chain it is handed.
- The primer strip itself (the `m` ringed glyphs at 44 pt and the 36 pt seed in its ghost frame) — **T03**.
- Asserting that exactly one member is lit at the `primer → casting` transition — **T09**, which owns the phase table the invariant is attached to.
- The Codex's 60 pt thumbnail, the four-level contextual projection, the fracture notch and the anomaly rim — **E15·T03**.
