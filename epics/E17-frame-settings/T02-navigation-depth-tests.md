# T02 — `NavigationDepthTests`

| | |
|---|---|
| **Epic** | E17 — The Frame, navigation and Settings |
| **Priority** | P0 |
| **Size** | S |
| **Depends on** | T01 |
| **Delivers** | Play key + ≤ 2-tap rule · 18 screens (the inventory guard) |
| **Status** | not started |

## Skills to load

Load these before writing anything:

| Skill | Why |
|---|---|
| `hunch-swift-testing` | This is a test-only task, so the skill that owns *where a test lives and what tag it carries* is the whole of it. Specifically: the file mirrors its source path (`06 T5b`), the suite is tagged on both axes and the `Modules/` package declares its tags through `ModulesTestSupport` rather than importing `HunchTestSupport` (which is absent from `products:`), and the "never restate a value that lives in Swift" rule — this suite must read `Screen.allCases` and `Mode.allCases`, never a literal 18 or 4, or it stops being a guard the day a screen is added. |

## Objective

At the end of this task the ≤ 2-tap rule is a fact the build checks rather than a claim §12.3 makes:
a breadth-first walk over `NavigationGraph` asserts `distanceToPlay(screen) ≤ 2` for every reachable
screen, in every one of the four last-played-mode graphs, and reproduces §12.3's tap-distance audit
table row for row. A nineteenth screen added without a play key fails the build twice — once at
compile time in `Screen`'s exhaustive switches, once here.

## Specification

| Source | Section | What it governs here |
|---|---|---|
| `GAME_DESIGN.md` | §12.3 | the tap-distance audit table (the seven rows this suite reproduces), the sentence *"Worst case in the entire app is two taps. Enforced by `NavigationDepthTests`"*, and the CI requirement: *"fails CI if a new screen is added without one"* |
| `GAME_DESIGN.md` | §12.3 | *"which is why the Codex's three levels cost nothing: every one of them carries the play key"* — the one assertion that explains why three-deep is legal |
| `GAME_DESIGN.md` | §12.2 | the Entry/Exit columns T01 encoded, and the three screens (16, 17, 18) that carry no play key and are therefore the "dismiss, then play key → 2" row |
| `ios-swift-guide/06-TESTING.md` | T5b, T21, T22, T29, T30 | path-mirrored placement · parameterise rather than loop · avoid the Cartesian blow-up · same-named tags across packages are equivalent · tag on both axes |
| `ios-swift-guide/08-APPLIED-TO-HUNCH.md` | §1, §5 | `Modules/Tests/HunchNavigationTests/`; the fast suite never boots a simulator, which is the reason `HunchNavigation` has no SwiftUI import |

## TDD — the test comes first

This task **is** the test. There is no "write the failing test, then implement" step for it, because
T01 already shipped the implementation as an untested value. Step 1 is therefore: write the suite,
watch it fail on a *planted defect*, then remove the plant. That is the same discipline in the shape
this task takes — a suite that has never been seen red is a suite that asserts nothing.

**Step 1 — write the suite.** Create `Modules/Tests/HunchNavigationTests/NavigationDepthTests.swift`:

```swift
import Foundation
import Testing
import HunchCore
import ModulesTestSupport
@testable import HunchNavigation

@Suite("The ≤ 2-tap rule — §12.3", .tags(.unit, .presubmission))
struct NavigationDepthTests {

    // MARK: - The rule itself

    @Test("every screen reaches a play surface in at most two taps", arguments: Mode.allCases)
    func everyScreenIsWithinTwoTaps(_ lastPlayed: Mode) throws {
        let graph = NavigationGraph(lastPlayedMode: lastPlayed)
        for screen in Screen.allCases {
            let distance = try #require(graph.distanceToPlay(screen),
                                        "\(screen) cannot reach a play surface at all")
            #expect(distance <= 2,
                    "\(screen) is \(distance) taps from play with last-played \(lastPlayed) — §12.3 caps it at 2")
        }
    }

    @Test("every screen §12.3 gives a per-mode clause reaches EVERY mode in at most two taps",
          arguments: Mode.allCases)
    func everyModeIsWithinTwoTapsFromTheKeyedScreens(_ lastPlayed: Mode) throws {
        // §12.3: Inscription "1 (again), 2 for a different mode"; the seven play-key screens
        // "1 (play key), 2 for a different mode".
        let keyed = Screen.allCases.filter(\.carriesPlayKey) + [.inscription, .frame]
        let graph = NavigationGraph(lastPlayedMode: lastPlayed)
        for screen in keyed {
            for mode in Mode.allCases {
                let distance = try #require(graph.distanceToPlay(screen, mode: mode))
                #expect(distance <= 2, "\(screen) → \(mode) is \(distance) taps")
            }
        }
    }

    @Test("every screen is reachable from a cold launch")
    func everyScreenIsReachable() {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        let orphans = Screen.allCases.filter { !graph.isReachable($0) && $0 != .launchSurface }
        #expect(orphans.isEmpty, "unreachable: \(orphans)")
    }

    // MARK: - §12.3's audit table, row for row

    @Test("cold launch with a suspended round opens IN the round — zero taps")
    func coldLaunchWithSuspendedRoundIsZero() {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        #expect(graph.distanceToPlay(.launchSurface) == 0)
    }

    @Test("the Frame is one tap from every mode", arguments: Mode.allCases)
    func frameIsOneTapFromEveryMode(_ mode: Mode) {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        #expect(graph.distanceToPlay(.frame, mode: mode) == 1)
    }

    @Test("the Inscription's *again* key is one tap to the same mode", arguments: Mode.allCases)
    func inscriptionAgainIsOneTap(_ lastPlayed: Mode) {
        let graph = NavigationGraph(lastPlayedMode: lastPlayed)
        #expect(graph.distanceToPlay(.inscription, mode: lastPlayed) == 1)
    }

    @Test("the play key is one tap on all seven screens that carry it")
    func playKeyIsOneTap() {
        let graph = NavigationGraph(lastPlayedMode: .drift)
        for screen in Screen.allCases where screen.carriesPlayKey {
            #expect(graph.distanceToPlay(screen) == 1, "\(screen) should be one tap via the play key")
        }
    }

    @Test("the three key-less screens are exactly two taps: dismiss, then play key")
    func keylessScreensAreTwo() {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        #expect(graph.distanceToPlay(.about) == 2)
        #expect(graph.distanceToPlay(.resetConfirmAlert) == 2)
        #expect(graph.distanceToPlay(.assayInspector) == 2)
    }

    @Test("SievePause is one tap back to the stream")
    func sievePauseIsOne() {
        let graph = NavigationGraph(lastPlayedMode: .sieve)
        #expect(graph.distanceToPlay(.sievePauseOverlay) == 1)
    }

    @Test("the Codex's three levels each cost one tap, which is why three-deep is legal")
    func codexThreeLevelsAreEachOneTap() {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        for screen in [Screen.codexRoot, .codexShelf, .codexPage] {
            #expect(screen.carriesPlayKey)
            #expect(graph.distanceToPlay(screen) == 1)
        }
    }

    // MARK: - The CI guard

    @Test("every screen that carries a play key actually has an edge to a play surface")
    func playKeyReachesAPlaySurface() {
        for mode in Mode.allCases {
            let graph = NavigationGraph(lastPlayedMode: mode)
            for screen in Screen.allCases where screen.carriesPlayKey {
                let target = Screen.playSurface(for: mode)
                #expect(graph.destinations(from: screen).contains { $0.to == target && $0.taps == 1 },
                        "\(screen) claims a play key but has no one-tap edge to \(target)")
            }
        }
    }

    @Test("no screen without a play key is more than two taps out — the guard for a NEW screen")
    func aScreenWithoutAPlayKeyMustStillBeWithinTwo() throws {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        for screen in Screen.allCases where !screen.carriesPlayKey {
            let distance = try #require(graph.distanceToPlay(screen))
            #expect(distance <= 2,
                    "\(screen) has no play key and is \(distance) taps out. Give it a play key or an exit.")
        }
    }

    @Test("the graph has no self-loop that could hide a dead end, except the Codex page's swipe")
    func selfLoops() {
        let graph = NavigationGraph(lastPlayedMode: .probe)
        let loops = graph.edges.filter { $0.from == $0.to }.map(\.from)
        #expect(loops == [.codexPage])   // §12.2 screen 11: "swipe to the adjacent slot"
    }
}
```

**Step 2 — run it and watch it fail, on a plant.** `swift test --package-path Modules --filter NavigationDepthTests`

It should be **green** on the first run, because T01 encoded the right graph. That is not proof, so
run three plants and record each in the commit message:

| Plant | Expected failure |
|---|---|
| Delete `settings` from `Screen.carriesPlayKey`'s true list | `keylessScreensAreTwo` still passes, `playKeyIsOneTap` no longer covers Settings, and `aScreenWithoutAPlayKeyMustStillBeWithinTwo` reports Settings at 2 — which is legal, so **also** check that `playKeyInventory` in `RouteTests` (T01) goes red. That pairing is the guard; neither test alone is |
| Add `case leaderboard = 19` to `Screen` | **Compile error** in `Screen.carriesPlayKey`, `Screen.isPlaySurface`'s helper and `NavigationGraph.edges` — three exhaustive switches, no `default:` (`W29`). Give it `carriesPlayKey = false` and no edges, and `everyScreenIsReachable` plus `everyScreenIsWithinTwoTaps` both go red |
| Change the `about → settings` edge's `taps` to 2 | `keylessScreensAreTwo` reports About at 3 |

Revert all three. A guard that has only ever been seen green is a guard nobody has tested.

**Step 3 — implement** nothing new, unless a plant reveals the graph is wrong. If `distanceToPlay`
needs a fix, it is T01's file and this task fixes it there.

**Step 4 — green, then refactor.** Fold any helper the suite grew into `NavigationGraph` itself if a
second caller wants it; otherwise leave it in the test.

## Files

| Action | Path |
|---|---|
| create | `Modules/Tests/HunchNavigationTests/NavigationDepthTests.swift` |
| modify | `Modules/Sources/HunchNavigation/NavigationGraph.swift` — only if a plant proves an edge or a distance wrong |
| modify | `tests.json` — four entries: `distanceToPlay ≤ 2` (all screens × all modes), the per-mode ≤ 2 for keyed screens, reachability, and the play-key-has-an-edge guard |
| modify | `.github/workflows/*.yml` — nothing; the suite is already selected by `Presubmission.xctestplan` through its tags |

## Implementation notes

### Why this is a graph walk and not eighteen hand-written expectations

Eighteen hand-written distances are eighteen copies of the spec that go stale silently. A walk asserts
the *property*, so the day someone adds an edge — say a "back to Frame" on `AboutView` — the property
either still holds or the suite says which screen broke it and by how much. The failure message is
the whole value: `"\(screen) is \(distance) taps from play with last-played \(lastPlayed)"` names the
screen, the number and the graph variant, which is enough to fix it without reading the graph.

### The four graphs

`NavigationGraph` is parameterised on `lastPlayedMode` (T01), so the suite parameterises on
`Mode.allCases` — four cases, not four `for` loops, so a failure names the mode (`06 T21` in the
direction it actually helps; the T21 *deviation* is the 10,000-law suite's and does not apply here,
where the argument set is four).

`everyScreenIsWithinTwoTaps` loops `Screen.allCases` *inside* the parameterised test rather than
taking a second `arguments:` list. That is `06 T22`'s Cartesian trap avoided deliberately: 4 × 18 = 72
runner nodes for assertions that cost microseconds, and the inner loop's `#expect` message already
names the screen. Eighteen is small enough that the first failure is not hiding a second — but if it
ever is, promote the failing screen into its own named case (`06 T53`).

### `#require` before `#expect`, on the optional distance

`distanceToPlay` returns `Int?` — `nil` means *no path exists*, which is a different and worse defect
than *the path is too long*. `try #require(...)` separates them, so an orphaned screen reports
"cannot reach a play surface at all" rather than a nil-coalesced `0` that silently passes. A
`graph.distanceToPlay(screen) ?? 0 <= 2` would make the worst bug in this file invisible, which is
exactly the shape `06`'s optional guidance warns about.

### Reachability excludes `launchSurface`, and only that

`launchSurface` has no inbound edge because its entry is "process launch". Every other screen must
have one, and the assertion lists the orphans rather than asserting a count, so the failure names
them.

### The tag import

`Modules/` cannot import `HunchTestSupport` — it is a `.target` deliberately absent from `products:`
(`06 T5a`, `01 P20`), which is what keeps `import Testing` out of the release binary. The eight
`@Tag static var` declarations are mirrored into `ModulesTestSupport`, and `06 T29` treats same-named
tags in different modules as equivalent, so `-only-testing-tags presubmission` still selects both
packages. If `ModulesTestSupport` does not exist yet, create it as a `.target` in `Modules/Package.swift`
with the eight tags and nothing else, and add it to every `Modules/Tests/*` target's dependencies.

### What "fails CI when a new screen is added without a play key" actually means

Two mechanisms, and both are needed:

1. **Compile time.** `Screen.carriesPlayKey` and `NavigationGraph.edges` are exhaustive switches with
   no `default:` (`W29`). A new case does not compile until someone has decided both answers.
2. **Test time.** Having decided them, `everyScreenIsWithinTwoTaps` and
   `aScreenWithoutAPlayKeyMustStillBeWithinTwo` then check that the decision was a *good* one.

Neither alone is the guard. The plant table in step 2 exercises both.

## Acceptance criteria

- [ ] `swift test --package-path Modules --filter NavigationDepthTests` green, all thirteen tests.
- [ ] All three plants from step 2 were run, each produced the stated failure, and each was reverted — the three failure messages are pasted into the task's commit message.
- [ ] `grep -n "18\|== 4" Modules/Tests/HunchNavigationTests/NavigationDepthTests.swift` returns nothing: the suite reads `Screen.allCases` and `Mode.allCases` and never a literal count.
- [ ] `grep -n "?? 0\|!" Modules/Tests/HunchNavigationTests/NavigationDepthTests.swift` shows no force-unwrap and no nil-coalesce of a distance.
- [ ] The suite runs in under 50 ms — `swift test --package-path Modules --filter NavigationDepthTests` with the timing line recorded — so it costs nothing against the 10 s budget.
- [ ] `tests.json` carries the four entries, each phrased as the property and not as a number.

## Close the task

1. `swift test` green, and the fast suite still under 10 s.
2. **Run `/simplify`** — reviews the changed code for reuse, simplification and efficiency, then applies the fixes. Re-run the tests after it.
3. **Run `/code-review`** — reviews the working diff for correctness. Fix what it finds; do not merge over an unresolved finding.
4. Commit: `git commit -m "E17/T02: NavigationDepthTests — the ≤2-tap rule as a graph walk, with three plants recorded"`

## Out of scope

- The graph itself and any edge change that is not forced by a plant — **T01**.
- Drawing the play key, or making it do anything at runtime — **T03** (its place in the bar) and **E10·T01** (`AppLaunchRoute`, which decides what it resumes).
- Screen *existence* — that the eighteen views compile and present — **T05**'s `ScreenInventoryTests`.
- `performAccessibilityAudit` over the eighteen screens — **E19·T11**.
