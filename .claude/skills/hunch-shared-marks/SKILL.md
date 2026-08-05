---
name: hunch-shared-marks
description: "Draws the seven marks reused across every screen — verdict ring, ghost frame, machined bar, link arc and return elbow, cancel hatch, tick row, arc meter — and names the one Swift function that owns each, so the same idiom is never drawn twice from two files. Use when a verdict animates, a socket shows a ghost, a Seal is barred, a par or tally row renders ticks, or any progress arc appears. These are atoms; the instruments and screens that compose them are the bench and chrome skills."
allowed-tools: Read, Grep, Glob, Bash(ls:*), Bash(grep:*), Bash(sed:*), Bash(echo:*), Bash(head:*)
metadata:
  version: "1.0"
  owns: "the seven shared marks — geometry, states, one owning Swift function each"
---

## Who owns which drawing, right now

```!
r="${CLAUDE_PROJECT_DIR:-.}"
d=$(ls -d "$r"/Modules/Sources/HunchUI/Marks ./Modules/Sources/HunchUI/Marks ../Modules/Sources/HunchUI/Marks 2>/dev/null | head -1)
if [ -n "$d" ]; then
  grep -Hn 'public static func draw' "$d"/*.swift | sed 's|.*/Marks/||'
  echo "--- second declarations outside Marks/ (each hit is the §2(g) bug) ---"
  grep -rnE '(struct|enum|final class) +[A-Za-z]*(VerdictRing|GhostFrame|MachinedBar|LinkArc|ReturnElbow|CancelHatch|TickRow|ArcMeter)' \
    "$r"/Modules/Sources "$r"/HunchCore/Sources --include='*.swift' 2>/dev/null | grep -v '/Marks/' || echo "none"
else
  echo "MARKS NOT BUILT YET — references/ownership.md is normative until Modules/Sources/HunchUI/Marks/ exists."
fi
```

Trust that listing over anything below it. If a mark has two declarations, stop and merge them before drawing anything.

## The rule

**Each of the seven marks below is drawn by exactly one `public static func draw` in exactly one file under `Modules/Sources/HunchUI/Marks/`. Every other file calls it.** The GDD specifies the machined bar twice — §4.3 for the Seal and §12.4 for the mode key, where it says "the identical drawing" and then draws it again — and that is the failure mode. The full census is in `references/ownership.md` §2 and it is larger than `DESIGN-SYSTEM-SCOPE.md` §2(g) reports: ghost frame **6** sites (it says four), cancel hatch **4** (three), tick row 7, verdict ring 8, link arc 6, arc meter 6. Two drawings of one idiom diverge silently, and the Bench and the Codex stop agreeing about what a mark means.

## To draw a mark

1. **Find the idiom in the table below and read its reference file.** Do not infer geometry from a screenshot or from a sibling component.
2. **Call the owning function. Never copy its body**, and never re-derive its path "just for this site" — that is the divergence, in one commit.
3. **Values come from tokens, not from you.** Colour, weight, opacity, duration and easing belong to `hunch-design-tokens`; cite the symbol. Mark geometry is **L2** and lives in `C.<Mark>` in `HunchCore/Sources/Tokens/C.swift`, appended by this skill. A hex, a numeric `lineWidth:` or a bare `260` in a mark file fails `check-source-hygiene.sh` check 9.
4. **A new site for an existing mark is a new argument or a new `case`, never a new function.** If the parameter list is getting long, the mark is being asked to do a second job — split the *state*, not the file.
5. **A new drawing is not a shared mark until it has two sites.** One site means it belongs to that component's skill (`hunch-bench-instruments` or `hunch-chrome-and-meta`). Promote it here on the second site, and delete the original.

## The seven marks

| Mark | Owning symbol | Read this when |
|---|---|---|
| **Ownership map** | — | `references/ownership.md` — before adding, moving or renaming any mark; it holds the site census, the `C.*` namespace map and the leak-check greps |
| **Verdict ring** | `VerdictRing.draw` | `references/verdict-ring.md` — a verdict resolves, a ribbon/primer/tail tile renders, a counterexample shows two rings, a Codex page shows re-strikes, an Anomaly ribbon cell renders |
| **Ghost frame** | `GhostFrame.draw` | `references/ghost-frame.md` — a Bridge socket is ghosted, the ribbon marks `prev`, the Assay pin thumbnail renders, ECHO shows the seed glyph, the DRIFT sigil or the Bridge palette stamp is drawn |
| **Machined bar** | `MachinedBar.draw` | `references/machined-bar.md` — the Seal is barred, a mode-rack key is barred, or reveal beat 0 retracts a bar |
| **Link arc / return elbow** | `LinkArc.draw` | `references/link-arc.md` — ribbon adjacency, the spool sheet's row wrap, the ECHO rail, a contextual counterexample join, the Profile *Retention* sigil |
| **Cancel hatch** | `CancelHatch.draw` | `references/cancel-hatch.md` — an unlit ramp cell, an inert ramp, an eliminated ECHO pool member, or the reject ring's diagonal |
| **Tick row** | `TickRow.draw` | `references/tick-row.md` — the par row and its crossing, the cap row, a Codex `bestProbes` strip, the Inscription strip, ECHO cast ticks, SIEVE foul ticks, the Profile *Tempo* sigil |
| **Arc meter** | `ArcMeter.draw` | `references/arc-meter.md` — a Codex shelf fill arc, a suspended mode key, the Anomaly 24-segment rollover, the streak ring, SIEVE stream progress |

## Rules that hold for all seven

- **Registers are types, so a miss will not compile.** Marks are `accent.*` (verdict ring, machined bar) or `stroke.*` (everything else). No mark ever takes a `HueColor` — `hue.*` belongs to the glyph body, fill, pips and index stroke and nowhere else (§13.2). If a mark needs a colour from its host, the host passes an `AccentColor` or an `RGB8`, never a hex.
- **A mark never owns an accessibility element.** §13.10's table is indexed by *host* — throat, ribbon tile, Seal, Assay — and has no row for a ring, a frame, a bar, an arc, a hatch, a tick or a meter. That absence is the specification. A mark contributes a fragment to its host's `accessibilityValue` ("admitted", "barred, rail 2 is empty") and is inside the host's `accessibilityElement(children: .ignore)`. Adding `.accessibilityLabel` inside a mark file doubles the utterance and breaks the fixed verdict → evidence → bookkeeping order.
- **A mark never leaks graphics state.** Take `GraphicsContext` **by value** and mutate a local `var`; clip, opacity, blend mode and transform must not escape back to the host. A mark that sets `context.opacity` on the caller's context is how a whole Bench dims on one hatched cell.
- **Marks resolve weight through `env.weight(_:)`, so they inherit Bold Text.** §13.11 scopes Bold Text to "glyph and rule-tile stroke weights", but `respondsToBoldText` travels with the *token* (`hunch-design-tokens`), and PHOSPHOR's reason applies here verbatim: on a textless surface Bold Text is the only signal that this player wants heavier marks. Never hard-code a weight to dodge the multiplier.
- **No mark animates itself.** Every time-varying value — `progress`, `retraction`, `fraction` — is a parameter. The host owns the animation and therefore owns §13.7.4's substitution. A mark reads `env.isReduceMotionEnabled` only where Reduce Motion changes *geometry* (the broken ring's static radius, the Profile tremble's dash), never to decide whether to move.
- **RTL: chrome mirrors, instruments do not.** Ghost-frame chevrons, machined-bar retraction and link-arc/elbow endpoints mirror with the layout, because "leading"/"trailing" are reading-order words. Verdict rings, arc meters and tick rows **do not** mirror: a ring is radially symmetric, an arc meter encodes a clock, and §2 renders instrument scales leading-to-trailing in source order in every locale. Mirroring the rollover arc would say the day runs backwards.
- **High Contrast substitutes; it never also scales.** Where §13.11 states an explicit value — cancel hatch 2.0 pt, index stroke `0.409·S` — that value terminates resolution (`hunch-design-tokens`, resolution order). Every other stroke gets `env.weight(_:)`'s flat +0.5.
- **Differentiate Without Colour adds geometry, never a token.** Exactly two marks respond: the broken verdict ring doubles its gap, and the counterexample's two rings take distinct dash patterns (§13.7.2, §13.11). Nothing else changes, and no colour changes anywhere.

## Gotchas

- **The cancel hatch runs at −45°, exactly perpendicular to `striped`'s +45° (§13.5).** Parallel and it vanishes into a striped mark. And its ink coverage must stay **below `dotted`'s 22.7 %** or it becomes a fifth rung of the `fill` ladder and corrupts the glyph channel — the shipped pitch gives ≈10 %, and ≈20 % under High Contrast's 2.0 pt. Check the arithmetic before changing either number. `cancel-hatch.md` §2.
- **`weight.heavy` is used by two different marks.** The machined bar (§4.3, §12.4) and the AND welded coupler bar (§4.2) are both 4.0 pt and are **not** the same drawing; the coupler belongs to `hunch-bench-instruments`. Sharing the token is correct; sharing the function is the bug.
- **Three barred keys on the Frame spend the entire per-screen accent ration.** At first launch DRIFT, ECHO and SIEVE are all barred, each carrying an `accent.cold` bar — that is §13.1's "at most three elements per screen", exactly. Nothing else on `FrameView` may take an accent, including the Anomaly streak ring.
- **The ribbon tile's reject ring is the *settled* broken ring, not a frame of the animation.** Sources call it "open" (scope §3) and "broken" (§13.11); they are one state. `broken` is the name; `open` is an alias with no drawing of its own.
- **The Anomaly's 28-cell ribbon is rings, not ticks** (§11.8) — `VerdictRing`, not `TickRow`. Scope §3 lists "Anomaly tally" under the tick row; that site is the Inscription's appended strip (§11.8), which is a tick row against the day's par. Two different marks, adjacent screens.
- **`opacity.cellUnlit` is withdrawn by PHOSPHOR, and the library still disagrees about it.** The mockup (`design/mockup-phosphor.html`, exhibit 4 and its own token grid, which lists the token as *"withdrawn — Exhibit 4"*) rules that an unlit ramp cell swaps ink to `stroke.secondary` at full weight rather than dimming, because a quarter of that token over `surface.cell` lands under the 3 : 1 graphical floor and so does the hatch — *"two channels neither of which clears 3 : 1 is not two channels"*. `DIRECTION-A-PHOSPHOR.md` §1.4's token table still lists a value, and `hunch-design-tokens` still ships `C.Ramp.cellUnlitInk(in:)` with five call sites in the bench and glyph skills. **Both cannot be right, and this skill does not own the ruling — `hunch-design-tokens` does.** What is ours either way: the **hatch is never dimmed with the cell**. Until the tokens skill rules, do not add a sixth call site and do not copy either number here.
- **`GraphicsContext.stroke` is not `Shape`.** These marks are drawn inside their host's `Canvas` so that bloom pass A can wrap one offscreen layer per *region* (throat, ribbon, tail — §13.5, PHOSPHOR §2). Promoting a mark to a `View` puts it outside that layer and turns three offscreen passes into sixteen.

## Never

- Never draw one of the seven from any file outside `Marks/`, including "just this once for the Codex thumbnail". That thumbnail is why the skill exists.
- Never give a mark its own `Shape`, `View` or `AnimatableModifier` alongside the `draw` function. Two entry points is two geometries within a year.
- Never let a mark read `UIAccessibility`, `Date()`, `UIScreen` or any singleton. Everything it needs arrives in `RenderEnv` and its arguments; that is what makes the snapshot gallery reproducible.
- Never write a literal into a mark file. Geometry constants go to `C.<Mark>` in `C.swift`; colours, weights, opacities and durations are already named by `hunch-design-tokens`.
- Never mirror a verdict ring, an arc meter or a tick row under RTL.
- Never add an accessibility label, trait or action inside a mark.
- Never copy a value out of this skill into a bench or chrome reference file. Cite the mark and its `C.*` symbol; the value has one home.
- **Never write a hex or a measured contrast ratio anywhere in this skill.** Both belong to `hunch-design-tokens/references/palette.md`, whose *measured* column is the only correct one — canon's stated ratios are wrong in nine cells and a copied ratio imports the error. Grep-able: `grep -rn '#[0-9A-Fa-f]\{6\}' .claude/skills/hunch-*/` must return only `hunch-design-tokens`, and no file here may contain `: 1` after a number. To argue from contrast, name the tokens and run `swift .claude/skills/hunch-design-tokens/scripts/contrast.swift`.
