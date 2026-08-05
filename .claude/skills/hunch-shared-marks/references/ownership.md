# ownership.md — one function per idiom, and the census that proves it

Contents: [1 The declaration](#1-the-declaration) · [2 The site census](#2-the-site-census) ·
[3 The file set and the signatures](#3-the-file-set-and-the-signatures) ·
[4 The `C` namespaces](#4-the-c-namespaces) · [5 Promotion and demotion](#5-promotion-and-demotion) ·
[6 The checks](#6-the-checks) · [7 Name collisions this resolves](#7-name-collisions-this-resolves) ·
[8 What would be wrong](#8-what-would-be-wrong)

---

## 1. The declaration

`DESIGN-SYSTEM-SCOPE.md` §2(g) states the defect: *"Shared idioms have no declared owner — the
machined bar is specified twice, §4.3 (Seal) and §12.4 (mode key, 'the identical drawing'), with no
statement of which file owns the drawing; likewise the ghost frame (four sites), cancel hatch
(three), tick row (seven)."*

**This file is that statement.** Seven idioms, seven files, seven `public static func draw`
entry points, all under `Modules/Sources/HunchUI/Marks/`. No other file in the repository may
produce the geometry of any of them. A composer calls; it does not re-derive.

Three consequences worth naming, because each is a real bug this prevents:

1. **The Bench and the Codex cannot disagree.** A Codex page draws rule-tiles at 0.78× (§11.1) with
   the same ghost frame and the same tick row. A second implementation "for the archive" drifts
   from the live one and the archive stops being a record of what was played.
2. **The machined bar cannot become two bars.** §12.4 says "the identical drawing used for the
   barred Seal (§4.3)" and then re-specifies key state in its own table. Two sections, one mark.
3. **Reduce Motion, High Contrast and Bold Text get applied once.** Every mark resolves through
   `RenderEnv`; a private copy of a mark is a copy that misses the next accessibility rule.

---

## 2. The site census

Counts are the authority for "how many sites" — the scope document undercounts two of them, exactly
as it undercounted the ramp (four stated, seven actual, §2(b)).

| Mark | Live sites | Depictive sites | Total | Scope §2(g) said |
|---|---|---|---|---|
| **Verdict ring** | throat · ribbon tile · counterexample (two concentric) · ECHO primer · SIEVE sump · SIEVE tail · Anomaly ribbon cell | Codex re-strike rim | 8 | — |
| **Ghost frame** | Bridge trailing socket · ribbon `prev` marker · Assay pin thumbnail · ECHO seed glyph | DRIFT mode sigil · Bridge palette stamp | 6 | four |
| **Machined bar** | barred Seal · barred mode-rack key | — | 2 | twice |
| **Link arc / elbow** | ribbon adjacency · spool-sheet row wrap · ECHO rail · contextual counterexample join | Profile *Retention* sigil · ECHO mode sigil (three decaying arcs) | 6 | — |
| **Cancel hatch** | unlit ramp cell (hatch) · inert ramp (slash) · eliminated ECHO pool member (hatch) · reject verdict ring (slash) | — | 4 | three |
| **Tick row** | par row · cap row · Codex `bestProbes` strip · Inscription strip · ECHO cast ticks · SIEVE foul ticks | Profile *Tempo* sigil | 7 | seven |
| **Arc meter** | Codex shelf fill arc · suspended mode-key border · Anomaly 24-segment rollover · streak ring · SIEVE stream progress | Codex facet-bar shelf stamps | 6 | — |

**Depictive sites are the same function with `role: .depictive`.** A depiction is drawn at a
different scale, is never interactive, and never carries state — but it is the *same geometry*, and
that is precisely the thing §11.2 and §11.11 P3 require ("a ramp silhouette", "a link arc", "a tick
strip", "the Seal's bar"). A hand-drawn approximation of a mark inside a sigil is the drift the
whole skill exists to stop: the player is being told *this is the mark you already met*, and a
different drawing makes that sentence false.

**Two additions to the scope census, with reasons.** The ghost frame's fifth and sixth sites are the
DRIFT mode sigil (§12.4: "the trailing one in the dashed hollow ghost frame") and the Bridge palette
stamp, which draws a dashed socket with a backward chevron. The cancel hatch's fourth site is the
reject verdict ring's diagonal (§13.7.2's break, drawn in the PHOSPHOR mockup as one −45° stroke) —
it is a cancel slash, and it must not become a second diagonal-drawing function living inside
`VerdictRing.swift`.

---

## 3. The file set and the signatures

```
Modules/Sources/HunchUI/Marks/
├── VerdictRing.swift      enum VerdictRing
├── GhostFrame.swift       enum GhostFrame
├── MachinedBar.swift      enum MachinedBar
├── LinkArc.swift          enum LinkArc
├── CancelHatch.swift      enum CancelHatch
├── TickRow.swift          enum TickRow
└── ArcMeter.swift         enum ArcMeter
```

One top-level caseless enum per file, named for the mark (`03 W11`, `03 W16`). `Marks/` is a
directory inside the existing `HunchUI` target, not a new target: it needs `RenderEnv`, `Palette`
and `SwiftUI`, all of which `HunchUI` already has, and a new target would buy nothing but a
manifest edge.

**Every entry point has this shape**, and the uniformity is the point — a reviewer can see at a
glance that a call site passes state rather than geometry:

```swift
import SwiftUI
import Tokens                       // RenderEnv, Palette, StrokeWeight, C

public enum VerdictRing {
    public enum State: Hashable, Sendable { /* … */ }

    /// Draws one verdict ring.
    ///
    /// The context is taken **by value**: clip, opacity, blend mode and transform are set on a
    /// local copy and never escape to the caller. `progress` is supplied by the host, which owns
    /// the animation and therefore owns §13.7.4's Reduce Motion substitution.
    ///
    /// - Complexity: O(1) — at most five sub-paths.
    public static func draw(
        into context: GraphicsContext,
        centre: CGPoint,
        bodyRadius: CGFloat,
        state: State,
        progress: Double = 1,
        env: RenderEnv
    ) {
        var ctx = context                       // never mutate the caller's context
        // …
        _ = ctx
    }
}
```

The seven signatures in full live in each mark's own reference file. The invariants they all share:

| Invariant | Why |
|---|---|
| first parameter `into context: GraphicsContext`, taken by value | a mark that sets `context.opacity` on the caller dims the whole host |
| last parameter `env: RenderEnv` | one record, seven axes, injected — never `UIAccessibility` inside a mark |
| every time-varying value is a parameter (`progress`, `retraction`, `fraction`) | the host owns the animation; §13.7.4 is one table in one skill |
| geometry arrives in points, already scaled by `env.artScale` at the *host* | scaling twice is the classic Dynamic Type bug; `render-env.md` §2 |
| returns `Void` | a mark that returns a `Path` invites a second consumer to stroke it differently |
| no `@MainActor` annotation, no `async`, no `throws` | pure drawing; `HunchUI` already carries `.defaultIsolation(MainActor.self)` |

**Why `GraphicsContext` and not `Shape`.** Bloom pass A is one offscreen layer per glyph-bearing
*region* — throat, ribbon, tail — never per glyph (§13.5, PHOSPHOR §2). Marks are drawn inside their
host's `Canvas` so they sit inside that layer. A mark promoted to a `View` sits outside it, and the
three offscreen passes the design budgets become as many as sixteen.

**Where a mark genuinely needs to be hit-tested or matched-geometry** — none currently do; marks have
no touch target (scope §3) — the host draws an invisible `contentShape` of its own. It does not
wrap the mark in a `Shape`.

---

## 4. The `C` namespaces

Mark geometry is **L2**. It lives in `HunchCore/Sources/Tokens/C.swift`, appended by this skill, in
the namespaces below. `hunch-design-tokens` owns the file and the layering rule; this skill owns
these members. L2 may reference L1 and `RenderEnv`; it may never reference `Prim` and may never hold
a value L1 already names.

| Namespace | Holds | Reference file |
|---|---|---|
| `C.VerdictRing` | settled radii, break gap angle, arc separation, twin offset, dash pattern | `verdict-ring.md` §5 |
| `C.GhostFrame` | dash on/off, chevron depth and height, inset | `ghost-frame.md` §5 |
| `C.MachinedBar` | overhang fraction | `machined-bar.md` §5 |
| `C.LinkArc` | rise ratio, elbow corner radius | `link-arc.md` §5 |
| `C.CancelHatch` | hatch pitch, slash inset, the −45° angle | `cancel-hatch.md` §5 |
| `C.TickRow` | full height, stub height, nominal pitch, tick width, crossed-rule height | `tick-row.md` §5 |
| `C.ArcMeter` | start angle, segment count and gap, track weights | `arc-meter.md` §5 |

**One value lives outside its own namespace and stays there.** The cancel hatch's weight is
`C.Ramp.cancelHatchWeight(in:)`, already written in `C.swift` by `hunch-design-tokens` as its worked
example of §13.11's substitution rule. `CancelHatch.draw` **reads** it; it does not re-declare it as
`C.CancelHatch.weight`. The namespace names one of the mark's four sites, which is untidy, and
untidy beats two homes for one number. Moving it later is a rename, and a rename is safe; a second
declaration is not.

---

## 5. Promotion and demotion

**A drawing is not a shared mark until it has two sites.** With one site it belongs to that
component's skill — `hunch-bench-instruments` for anything on the Bench, `hunch-chrome-and-meta` for
chrome and the archive. Premature promotion produces a parameter list shaped by one caller and a
second caller that cannot use it.

**To promote** (one site → two): move the drawing into `Marks/<Name>.swift`, give it the standard
signature, add a `role`/`variant` case for each site, add its `C.<Name>` namespace, add its row to
§2's census and its row to `SKILL.md`'s routing table, and **delete the original**. A promotion that
leaves the original in place has doubled the problem.

**To demote** (a mark that turned out to have one site): reverse it, and remove the reference file
and both table rows. An unreferenced reference file is invisible to the skill and fails `check-skills.sh`.

**To add a site to an existing mark:** add a `case` to its state or role enum, or a parameter with a
default. Never a second function, never an overload that differs only in argument labels, never a
`// swiftlint:disable`-style escape.

---

## 6. The checks

Run these before claiming a mark is done. The first two are greps you can run now; the third is the
snapshot corpus.

**(a) No second declaration.** A hit is the §2(g) bug, in the file that has it:

```bash
grep -rnE '(struct|enum|final class) +[A-Za-z]*(VerdictRing|GhostFrame|MachinedBar|LinkArc|ReturnElbow|CancelHatch|TickRow|ArcMeter)' \
  Modules/Sources HunchCore/Sources --include='*.swift' | grep -v '/Marks/'
```

**(b) No hand-rolled mark geometry outside `Marks/`.** The tells are a dashed stroke style, a
four-arc loop and a trimmed path — each is one of the seven and nothing else in this app draws them:

```bash
grep -rn 'StrokeStyle(.*dash' Modules/Sources --include='*.swift' | grep -v '/Marks/'
grep -rn 'trimmedPath\|addArc(' Modules/Sources --include='*.swift' | grep -v -e '/Marks/' -e 'GlyphShape'
```

`GlyphShape.swift` is the sanctioned exception to the second grep: silhouettes use `addArc` for
`circle` and are `hunch-glyph-renderer`'s.

**(c) `Scripts/check-inventory.sh`** asserts every row of `DESIGN-SYSTEM-SCOPE.md` §3 has exactly
one reference file and exactly one owning symbol. A new component with no owner fails CI, and a
component with **two** fails it unconditionally — that second case is §2(g)'s bug and is the reason
the script exists. The script is written out in
`hunch-build-and-ci/references/source-hygiene.md` §7.1.

**The declaration is one HTML comment**, at the top of the reference file that owns the row:

```markdown
<!-- inventory: Verdict ring | VerdictRing.draw -->
```

The row name must match §3's bolded first cell character for character. All seven marks in this
skill carry theirs; §7.1 records which rows in the rest of the library still do not, and when the
check switches from warning to `--strict`.

**(d) The DEBUG snapshot gallery** (scope §4.4) draws every mark × every state × 3 themes ×
{normal, Bold Text, Reduce Motion}, plus greyscale. A mark drawn differently changes a snapshot,
which is the only mechanism that catches a divergence a grep cannot see.

---

## 7. Name collisions this resolves

Six sources use different words for the same drawing. These are the canonical names; the others are
aliases with no drawing of their own.

| Canonical | Also written as | Where |
|---|---|---|
| `broken` (verdict ring state) | "open", "contracting-broken", "4 arcs" | scope §3, §13.7.2, §13.11 |
| `ghost frame` | "dashed hollow frame", "the ghost", "`prev` marker", "dashed socket" | §4.2, §4.3, §8.4, §12.4 |
| `machined bar` | "the bar", "barred", "physically barred" | §4.2, §4.3, §12.4 |
| `link arc` | "link arcs", "the arc", "adjacency" | §4.1, §6.2, §8.4 |
| `return elbow` | "the wrap", "chain wraps with a return elbow" | §6.2 |
| `cancel hatch` (variant `.hatch`) | "diagonal cancel hatch" | §4.2, §8.4, §13.11 |
| `cancel hatch` (variant `.slash`) | "hairline slash", "one diagonal cancel stroke" | §4.3, mockup exhibit 4 |
| `tick row` | "tick marks", "par tick row", "tick strip", "cast ticks", "foul ticks" | §6.2, §6.9, §9.2, §11.1, §11.8 |
| `arc meter` | "fill arc", "rollover arc", "streak ring", "stream progress", "suspended arc" | §9.2, §11.2, §11.7, §11.8, §12.4 |

`hunch-design-tokens` resolved the same class of problem for token paths (§2(h)); this table is its
counterpart for drawings. Use the canonical name in code, in comments, in test names and in commit
messages. Seven authors write against it.

---

## 8. What would be wrong

- **Adding an eighth mark because a drawing "feels shared".** §5's bar is two *sites*, and the
  promotion is only complete when the original is deleted. A promotion that leaves the original
  in place has doubled the problem it was meant to fix.
- **Declaring ownership in a sentence instead of in §6's comment.** `check-inventory.sh` greps for
  that one shape and nothing else, so a paragraph saying the same thing in English is invisible to
  it and the row reads as unowned. §6 above and `source-hygiene.md` §7.1 are its two homes.
- **Letting the comment's row name drift from `DESIGN-SYSTEM-SCOPE.md` §3's spelling.** The match
  is character for character, so "Tick Row" claims nothing and leaves "Tick row" unowned. The
  script reports that as an orphan rather than silently passing, which is the only reason the
  mistake is survivable.
- **Two files carrying the same inventory comment.** That is `DESIGN-SYSTEM-SCOPE.md` §2(g)
  restated in a machine-readable form, and it is the one category `check-inventory.sh` fails on
  unconditionally.
- **Declaring an owning symbol that is a `View`, a `Shape` or an `AnimatableModifier`.** §3 fixes
  the entry point as one `public static func draw`; a second kind of entry point is a second
  geometry within a year.
- **Treating §2's census as a copy of scope §2(g).** It is *larger* — the ghost frame has six
  sites where the scope says four, the cancel hatch four where it says three. This file's counts
  are the authority; the scope document's are the thing that was undercounted.
- **Adding a value to a `C.<Mark>` namespace that L1 already names.** §4's namespaces hold mark
  *geometry* only. A colour, a weight, an opacity or a duration in one of them is a second home
  for a token, and the cancel hatch's weight is the worked example of resisting exactly that.
