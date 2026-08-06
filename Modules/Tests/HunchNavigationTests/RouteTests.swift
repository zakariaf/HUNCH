import Testing

import Glyphs
import HunchNavigation
import ModulesTestSupport

/// §12.3. A back-stack you can get lost in is the failure mode of menu-driven design, and this
/// app has nine destinations — so the two-tap rule is what lets every screen carry a play key
/// instead of a breadcrumb.
@Suite("Navigation depth", .tags(.unit, .presubmission))
struct NavigationDepthTests {

    /// The graph walk §12.3 asks for: **every** reachable screen, and it fails the moment a new
    /// one is added without an answer.
    @Test("Every screen is within two taps of a live probe surface", arguments: Route.allCases)
    func twoTapsWorstCase(_ route: Route) {
        #expect(route.distanceToPlay <= Route.maximumDistanceToPlay)
        #expect(route.distanceToPlay >= 0)
    }

    @Test("A suspended round opens in the round, at zero taps")
    func coldLaunchIsZero() {
        #expect(Route.round.distanceToPlay == 0)
        #expect(Route.allCases.filter { $0.distanceToPlay == 0 } == [.round])
    }

    /// The Codex's three levels cost nothing because every one of them carries the play key —
    /// a drill-down through a hierarchy the player can see the whole of, not a menu tree.
    @Test("The Codex is three deep and still one tap from play")
    func theCodexIsFree() {
        for route in [Route.codexRoot, .codexShelf, .codexPage] {
            #expect(route.distanceToPlay == 1)
        }
        #expect(Route.codexShelf.isPushed)
        #expect(Route.codexPage.isPushed)
    }

    /// Only the three dismissible surfaces cost two, and each is dismiss-then-play rather than
    /// a second destination.
    @Test("Exactly three screens cost two taps, and all three are dismissible")
    func theTwoTapScreens() {
        let two = Route.allCases.filter { $0.distanceToPlay == 2 }
        #expect(Set(two) == [.about, .assayInspector, .resetAlert])
    }

    /// `NavigationStack` twice — the Codex and Settings → About — and nothing else pushes.
    @Test("Only four routes are pushes")
    func pushesAreRare() {
        let pushed = Route.allCases.filter(\.isPushed)
        #expect(Set(pushed) == [.codexShelf, .codexPage, .about, .statistics])
    }
}

/// §9.10's unlock row. Each of the three numbers has a different *kind* of reason, and the tests
/// are about the reasons rather than the numbers.
@Suite("Mode gates", .tags(.unit, .presubmission))
struct ModeGateTests {

    @Test("PROBE is never gated")
    func probeIsUngated() {
        #expect(ModeGate.isUnlocked(.probe, pages: 0, highestPageBand: 0))
    }

    /// DRIFT's gate is the mode's **own floor**, not a page count: a count would unbar a mode
    /// whose serving path then has to clamp the player up two bands on their first round — an
    /// unlocked key that lies about what it will hand you.
    @Test("DRIFT unlocks on a band-3 page and never on a page count")
    func driftGatesOnItsOwnFloor() {
        #expect(ModeGate.requirement(for: .drift) == .pageAtBand(3))
        #expect(ModeGate.isUnlocked(.drift, pages: 40, highestPageBand: 2) == false)
        #expect(ModeGate.isUnlocked(.drift, pages: 1, highestPageBand: 3))
    }

    /// Five is the smallest number satisfying `unlockThreshold ≥ poolFloor + blindPrimerDrop`.
    /// Unlocking at exactly three would hand the player a lit key over an unusable pool.
    @Test("ECHO's five is derived from its own pool floor")
    func echoThresholdIsDerived() {
        #expect(ModeGate.requirement(for: .echo) == .pages(5))
        #expect(5 >= ModeGate.echoPoolFloor + ModeGate.echoBlindPrimerDrop)
        #expect(4 < ModeGate.echoPoolFloor + ModeGate.echoBlindPrimerDrop)
        #expect(ModeGate.isUnlocked(.echo, pages: 4, highestPageBand: 8) == false)
        #expect(ModeGate.isUnlocked(.echo, pages: 5, highestPageBand: 1))
    }

    @Test("SIEVE is the last gate")
    func sieveIsLast() {
        #expect(ModeGate.requirement(for: .sieve) == .pages(8))
        #expect(ModeGate.isUnlocked(.sieve, pages: 7, highestPageBand: 8) == false)
    }

    /// Modes unlock on **archive evidence**, not on a round count: DRIFT is only legible to
    /// someone who already believes laws are stable, ECHO to someone who has held one in mind,
    /// SIEVE to someone who can recognise a lawful glyph at a glance.
    @Test("No gate reads a round count", arguments: Mode.allCases)
    func gatesReadTheArchive(_ mode: Mode) {
        // Both arguments are archive facts. A round count would be a fourth kind of input and
        // there is no parameter for one.
        #expect(ModeGate.isUnlocked(mode, pages: 100, highestPageBand: 8))
    }
}
