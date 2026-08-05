# T03 — The gesture inventory

| | |
|---|---|
| **Epic** | E09 — The Bench, the Assay, the Seal and resolution |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T02 |
| **Delivers** | §14.1 `The Bench` (the "tap and trailing-swipe only" half of the row) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-bench-instruments` | Standing rule 6 is the rule this task enforces — *"No drag, pinch, long-press or double-tap anywhere in the declaration UI (§4.2). Every action is a tap or a trailing-edge swipe. This is the reason the whole Bench is VoiceOver-operable, so adding one drag breaks the accessibility argument, not just a gesture."* The skill also owns the exhaustive eight-row gesture table this task turns into a Swift value. |
| `hunch-accessibility` | Step 5 of its procedure — *"Add a custom action for anything needing a gesture VoiceOver cannot make"* — is the other half of the invariant: the swipe that clears a rail must have a `"Clear rail"` custom action or the gesture is simply unavailable under VoiceOver. This skill owns which actions exist. |
| `hunch-build-and-ci` | The lint lands as a new check in `Scripts/check-source-hygiene.sh` beside checks 7 and 8, which are the same shape — repo-relative source greps that no package test can see. This skill owns the script's structure, its exit contract and how a new check is added without breaking the run-script build phase. |

## Objective

At the end of this task §4.2's gesture table is a Swift value with a test that says it has exactly
eight rows, every row is a tap or a trailing swipe, and every non-tap row carries a VoiceOver custom
action — and a source lint in CI fails the build the first time anybody writes a `LongPressGesture`,
a `MagnifyGesture`, a `RotateGesture` or a two-count tap in the declaration UI. Before this task the
rule is prose in the GDD; after it, breaking the rule breaks the build.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §4.2 | The exhaustive gesture table — eight rows — and the Decision: *"there is no drag, no pinch, no long-press and no double-tap anywhere in the declaration UI. Every action is a tap or a trailing swipe. Reason: drag and pinch are precisely the gestures VoiceOver cannot perform and that no textless affordance can teach."* |
| `GAME_DESIGN.md` | §12.8 | *"Every control is a standard accessibility element with a label, a trait and a value; there is no drag, pinch, long-press or double-tap in the declaration UI (§4.2), so the whole Bench is operable with rotor + single-finger double-tap."* |
| `GAME_DESIGN.md` | §6.7 | The one gesture the rule appears to contradict, and does not: the Bench handle's upward drag. See the two allowlisted sites below |
| `ios-swift-guide/07-TOOLING-BUILD-AND-SHIPPING.md` | B34a | The hygiene script's shape — the check number, the failure message convention, and the exit contract |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §5 | Why checks 7 and 8 are lints and not package tests: *"neither artifact exists in a test bundle"*. The same reasoning applies here — a gesture modifier is a repo-relative source fact |

## TDD — the test comes first

This task ships **two** artefacts and each gets its own failing check first: a Swift value with a
Swift Testing suite, and a source lint with a planted violation.

**Step 1a — write the failing Swift test.** Create
`Modules/Tests/HunchUITests/BenchGestureInventoryTests.swift`:

```swift
import Testing
import HunchCore
@testable import HunchUI

@Suite("Bench gesture inventory", .tags(.unit, .presubmission))
struct BenchGestureInventoryTests {

    // §4.2's table is exhaustive. Eight rows, and a ninth is a design change, not a commit.
    @Test("The declaration UI has exactly eight gestures")
    func inventoryIsExhaustive() {
        #expect(BenchGesture.allCases.count == 8)
        #expect(Set(BenchGesture.allCases).count == 8)
    }

    // "Every action is a tap or a trailing swipe." Two kinds, and there is no third.
    @Test("Every gesture is a tap or a trailing swipe", arguments: BenchGesture.allCases)
    func onlyTwoKinds(_ gesture: BenchGesture) {
        #expect(gesture.kind == .tap || gesture.kind == .trailingSwipe)
    }

    @Test("There is no third gesture kind")
    func kindsAreClosed() {
        #expect(BenchGesture.Kind.allCases.count == 2)
    }

    // §4.2 + accessibility step 5: a gesture VoiceOver cannot make needs a custom action
    // beside it, or the gesture is simply unavailable.
    @Test("Every non-tap gesture carries a VoiceOver custom action",
          arguments: BenchGesture.allCases.filter { $0.kind != .tap })
    func swipesHaveActions(_ gesture: BenchGesture) {
        #expect(gesture.voiceOverAction != nil)
    }

    // The rule's *reason*: the whole Bench is operable with rotor + single-finger double-tap.
    @Test("Every gesture is reachable without sight", arguments: BenchGesture.allCases)
    func everyGestureIsOperable(_ gesture: BenchGesture) {
        // A tap is operable by definition (single-finger double-tap on a focused element);
        // anything else needs an action.
        #expect(gesture.kind == .tap || gesture.voiceOverAction != nil)
    }

    // §4.2's rows, named, so a renamed control cannot silently drop one.
    @Test("The eight rows are canon's eight rows")
    func rowsMatchCanon() {
        #expect(BenchGesture.allCases == [
            .addTileFromPalette,      // tap a palette stamp
            .toggleCellOrDock,        // tap a cell / dock / dial stop
            .cycleCoupler,            // tap a coupler
            .cycleComparator,         // tap a wedge
            .toggleGhost,             // tap the ghost toggle
            .bindSocketAttribute,     // tap an empty socket, then an attribute header
            .clearRail,               // swipe a rail toward the trailing edge
            .seal,                    // tap the Seal
        ])
    }

    // The two allowlisted DragGesture sites both have a tap equivalent, so the rule holds
    // in effect even where a drag exists as a convenience. See Implementation notes.
    @Test("Every allowlisted drag site has a tap route to the same effect",
          arguments: BenchDragSite.allCases)
    func dragsAreNeverRequired(_ site: BenchDragSite) {
        #expect(site.hasTapEquivalent)
        #expect(site.voiceOverAction != nil)
    }
}
```

**Step 1b — plant the lint's violation.** Add check 11 to `Scripts/check-source-hygiene.sh`, then
prove it works the way E01·T06 proved the `URLSession` check:

```bash
# plant
printf '\n// planted for the lint self-test\nlet _planted = LongPressGesture(minimumDuration: 0.5)\n' \
  >> Modules/Sources/HunchUI/RuleTileCanvas.swift

bash Scripts/check-source-hygiene.sh; echo "exit=$?"     # MUST be non-zero, naming check 11
                                                          # and the file and line

# unplant
git checkout -- Modules/Sources/HunchUI/RuleTileCanvas.swift
bash Scripts/check-source-hygiene.sh; echo "exit=$?"     # MUST be 0
```

Repeat the plant/unplant with each of `MagnifyGesture`, `RotateGesture`,
`.onLongPressGesture`, `.onTapGesture(count: 2)` and a bare `DragGesture` in a non-allowlisted file.
Five plants, five non-zero exits. Paste the transcript into the commit message.

**Step 2 — run the Swift suite and watch it fail.**

```bash
xcodebuild test -scheme Hunch \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -testPlan Presubmission -only-testing:HunchUITests/BenchGestureInventoryTests
```

`cannot find 'BenchGesture' in scope` is the right failure.

**Step 3 — implement.** `BenchGesture`, `BenchDragSite`, the wiring at each call site, and check 11.

**Step 4 — green, then refactor.** The refactor here is deleting whatever ad-hoc gesture modifiers
T01 and T02 left behind and routing every one through `BenchGesture`.

## Files

| Action | Path |
|---|---|
| create | `Modules/Sources/HunchUI/BenchGesture.swift` — the inventory as a value, its two kinds, its VoiceOver actions, and `BenchDragSite` |
| modify | `Modules/Sources/HunchUI/RuleTileCanvas.swift` — every gesture routed through `BenchGesture`; `RailView`'s clear swipe gains its `"Clear rail"` custom action |
| modify | `Modules/Sources/HunchUI/BenchHandle.swift` — declared as a `BenchDragSite` with its tap equivalent |
| modify | `Modules/Sources/LoomFeature/BenchView.swift` — the Seal and palette rows wired |
| modify | `Scripts/check-source-hygiene.sh` — check 11 |
| create | `Modules/Tests/HunchUITests/BenchGestureInventoryTests.swift` |
| modify | `tests.json` — the gesture-inventory invariant and the lint |

## Implementation notes

### The value

```swift
/// §4.2's exhaustive gesture table, as a value. A ninth case is a design change.
public enum BenchGesture: CaseIterable, Hashable, Sendable {
    case addTileFromPalette
    case toggleCellOrDock
    case cycleCoupler
    case cycleComparator
    case toggleGhost
    case bindSocketAttribute
    case clearRail
    case seal

    public enum Kind: CaseIterable, Hashable, Sendable { case tap, trailingSwipe }

    public var kind: Kind {
        switch self {                       // no `default:` — W29
        case .addTileFromPalette, .toggleCellOrDock, .cycleCoupler, .cycleComparator,
             .toggleGhost, .bindSocketAttribute, .seal:
            .tap
        case .clearRail:
            .trailingSwipe
        }
    }

    /// nil iff the gesture is a plain tap, which VoiceOver performs natively as a
    /// single-finger double-tap on the focused element.
    public var voiceOverAction: LocKey? {
        switch self {
        case .clearRail: .clearRail
        default: nil                        // ← the one legal `default:` in this file: it is
        }                                   //   over the *absence* of an action, not a case map
    }
}
```

Note the two switches are different shapes on purpose. `kind` maps every case and must break the
build when a ninth arrives (`W29`), so it has no `default:`. `voiceOverAction` is "everything else is
nil", which is the sanctioned use — and if you would rather not argue that at review time, spell it
exhaustively too. Either is fine; a `default:` in `kind` is not.

### The two allowlisted drags, and why the rule still holds

§4.2 abolishes drag *"anywhere in the declaration UI"*, and §6.7 opens the Bench with *"Tap the Bench
handle, drag it upward, or tap the Bench key … the handle is exposed to VoiceOver as a button so the
drag is never required."* Those are consistent because the rule's real content is **no gesture is ever
the only route**, not "no `DragGesture` symbol appears in the file". Two sites therefore carry a
`DragGesture` and both are allowlisted by name in check 11:

| Site | Drag | Tap equivalent | VoiceOver |
|---|---|---|---|
| `BenchHandle` | upward drag opens the drawer, downward closes it | tap the handle; tap the Bench key; tap the Dial key | `.isButton` + open/close custom action; **becomes a plain button entirely under Reduce Motion** |
| `RailView` | trailing-edge swipe clears the rail | — (this is §4.2's own row 7) | `"Clear rail"` custom action |

`BenchDragSite` names exactly these two, `hasTapEquivalent` is asserted for both, and check 11's
allowlist is those two file:symbol pairs and nothing else. Adding a third site means editing the
allowlist in a diff a reviewer will see, which is the entire mechanism.

The rail's trailing swipe reads `translation.width > 0` **in the view's own space**, after SwiftUI has
applied the RTL flip to the container. Write `leading`/`trailing` in every comment and let the
mirrored layout carry the sign; a `left`/`right` test inverts the gesture in Arabic (§12.8).

### Check 11

Beside checks 7 and 8 in `Scripts/check-source-hygiene.sh`, over the declaration UI's file set —
`Modules/Sources/HunchUI/RuleTileCanvas.swift`, `AttributeHeaderView.swift`, `AssayCanvas.swift`,
`SealView.swift`, `BenchPalette.swift`, `BenchHandle.swift`, and
`Modules/Sources/LoomFeature/BenchView.swift`, `AssayInspectorView.swift`:

```sh
# 11 — the declaration UI is tap and trailing-swipe only (§4.2, §12.8).
banned='LongPressGesture|MagnifyGesture|MagnificationGesture|RotateGesture|RotationGesture|SpatialTapGesture|onLongPressGesture|onTapGesture\(count: *[2-9]'
if grep -nE "$banned" $DECLARATION_UI_FILES; then
  fail 11 "banned gesture in the declaration UI — §4.2 allows tap and trailing swipe only"
fi
# DragGesture is allowed at exactly two allowlisted sites, each with a tap equivalent.
if grep -n 'DragGesture' $DECLARATION_UI_FILES | grep -vE 'BenchHandle\.swift|RuleTileCanvas\.swift: *[0-9]+: *.*// allowlisted: rail clear'; then
  fail 11 "DragGesture outside the two allowlisted sites (BenchHandle, RailView rail clear)"
fi
```

Two things the naive version gets wrong and this one does not:

1. **`onTapGesture(count:)` with a literal 2 is a double-tap and is banned; `count: 1` is a tap and is
   not.** Grepping bare `onTapGesture` would ban the Assay's expand tap.
2. **`SpatialTapGesture` is a tap** and would pass a `LongPressGesture`-only grep while carrying a
   location payload nobody needs here. It is banned because a second tap idiom is a second thing to
   keep operable.

`$DECLARATION_UI_FILES` is a variable defined once at the top of the check, so adding a Bench file
means adding it in one place. If a new Bench file is created and not added, the check silently stops
covering it — so the acceptance criteria below include a count assertion on that list.

### Why this is a lint and not a runtime test

A gesture modifier is a **source** fact. Nothing in a compiled test bundle can see whether
`RuleTileCanvas.swift` contains the characters `LongPressGesture`, exactly as nothing in a test bundle
can see a String Catalog's key count (`08 §5`, checks 7 and 8). The Swift suite above covers the half
that *is* a runtime fact — that the inventory is closed and every row is operable — and the lint
covers the half that is not. Two artefacts, two facts, no overlap.

## Acceptance criteria

- [ ] `xcodebuild test … -only-testing:HunchUITests/BenchGestureInventoryTests` is green.
- [ ] The five plant/unplant transcripts are in the commit message, each showing a non-zero exit that
      names check 11, the file and the line.
- [ ] `bash Scripts/check-source-hygiene.sh` exits 0 on a clean tree.
- [ ] `grep -c '' <(printf '%s\n' $DECLARATION_UI_FILES)` — the file list covers **every** `.swift`
      file under `Modules/Sources/HunchUI` and `Modules/Sources/LoomFeature` that this epic's T01, T02,
      T05 and T07 create. Verified by a second grep in the script itself that fails if a Bench file
      exists on disk and is absent from the list.
- [ ] `grep -rn 'DragGesture' Modules/Sources/HunchUI Modules/Sources/LoomFeature` returns exactly two
      hits, both carrying the allowlist comment.
- [ ] `tests.json` carries `bench.gesture-inventory-closed` and `lint.gesture-inventory`.

## Close the task

1. `swift test --package-path HunchCore` green, and the fast suite still under 10 s
   (`START=$SECONDS; swift test --package-path HunchCore; [ $((SECONDS-START)) -lt 10 ]`).
   This task's own suite: `xcodebuild test -scheme Hunch -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' -testPlan Presubmission -only-testing:HunchUITests/BenchGestureInventoryTests && bash Scripts/check-source-hygiene.sh`
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then
   applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not
   merge over an unresolved finding.
4. Commit: `git commit -m "E09/T03: the Bench gesture inventory as a value, plus hygiene check 11"`

## Out of scope

- **The rotors, Magic Tap and the two-finger escape scrub.** **E19·T05**. This task asserts that
  *some* action exists on every non-tap gesture; E19 owns the four-rotor set, the wording and
  Magic Tap = Seal on the Bench.
- **SIEVE's gate tap, ECHO's tray tap and the Dial's taps.** Those are not the declaration UI. E08,
  E13 and E14 own them, and check 11's file list does not cover them.
- **The play-surface `Text` ban (check 7) and the catalog checks (check 8).** E01·T06 and E18.
- **Adding a gesture.** If a task later needs one, it is a GDD change and a `DECISIONS.md` entry, not
  an allowlist edit.
