import Testing

import Glyphs
import HunchUI
import ModulesTestSupport

/// §13.10's element map. It is a value because the table **is** the contract: "the whole Bench
/// is operable with rotor plus single-finger double-tap" is only true if no element is missing a
/// trait, a label or an action, and a view that forgets one ships a button VoiceOver reads as
/// its frame position.
@Suite("The VoiceOver element map", .tags(.unit, .presubmission))
struct AccessibilityMapTests {

    @Test("Every element has traits and a label", arguments: AccessibilityElement.allCases)
    func everyElementIsDescribed(_ element: AccessibilityElement) {
        #expect(element.traits.isEmpty == false)
        #expect(element.hasLabel)
    }

    /// The only non-tap gesture in the declaration UI is the rail's trailing swipe, and §4.2
    /// requires it to have a custom action so the whole Bench stays operable without it.
    @Test("Every gesture the design rules out is reachable as a custom action")
    func gesturesHaveActions() {
        #expect(AccessibilityElement.rail.customActions.contains("Clear rail"))
        #expect(AccessibilityElement.ribbonTile.customActions.contains("Load into the Dial"))
        #expect(AccessibilityElement.sieveGate.customActions.contains("Admit"))
    }

    /// "Read by attribute" solves the 256-cell grid: sixteen marginals as one interruptible
    /// announcement instead of 256 impossible swipes — the non-visual equivalent of reading a
    /// constellation's density.
    @Test("The Assay is one element with a read-by-attribute action, never 256 cells")
    func theAssayIsNotAGrid() {
        #expect(AccessibilityElement.assay.traits.contains(.image))
        #expect(AccessibilityElement.assay.traits.contains(.container) == false)
        #expect(AccessibilityElement.assay.customActions.contains("Read by attribute"))
    }

    /// A cell is a button with `.isSelected`; a ramp is a container. Getting that round the
    /// wrong way collapses five elements into one image and takes the traits with it.
    @Test("Cells are selectable buttons and ramps are containers")
    func containerCellSplit() {
        for cell in [AccessibilityElement.dialCell, .rampCell] {
            #expect(cell.traits.contains(.button))
            #expect(cell.traits.contains(.selected))
        }
        for container in [AccessibilityElement.dialRamp, .rampTile, .rail] {
            #expect(container.traits.contains(.container))
            #expect(container.traits.contains(.button) == false)
        }
    }

    /// The throat is adjustable, which is how the ±1 step survives for a player who cannot
    /// swipe on it — one behaviour, two entry points.
    @Test("The throat is adjustable and updates frequently")
    func theThroatIsAdjustable() {
        #expect(AccessibilityElement.throat.traits.contains(.adjustable))
        #expect(AccessibilityElement.throat.traits.contains(.updatesFrequently))
    }
}

/// §13.10's four rotors, and there is no fifth.
@Suite("Rotors and the Magic Tap", .tags(.unit, .presubmission))
struct RotorTests {

    @Test("Four custom rotors, and the fourth is conditional")
    func fourRotors() {
        #expect(AccessibilityRotor.allCases.count == 4)
        #expect(AccessibilityRotor.counterexample.isAlwaysAvailable == false)
        #expect(
            AccessibilityRotor.allCases.filter(\.isAlwaysAvailable).count == 3)
    }

    /// A rotor that was always present would be empty most of the time, which is a dead swipe —
    /// the same objection as a silent stop on the Rails rotor when a Fork is on the Bench.
    @Test("The counterexample rotor has two stops and exists only after a strike")
    func theCounterexampleRotor() {
        #expect(AccessibilityRotor.counterexample.stopCount == 2)
        #expect(AccessibilityRotor.rails.stopCount == 4)
        #expect(AccessibilityRotor.probes.stopCount == nil)
    }

    /// Probe on the Dial, Seal on the Bench: the most frequent action collapsed to one gesture
    /// from anywhere.
    @Test("The Magic Tap is Probe on the Dial and Seal on the Bench")
    func magicTap() {
        #expect(MagicTap.action(isBenchOpen: false, isSealBarred: false) == .probe)
        #expect(MagicTap.action(isBenchOpen: false, isSealBarred: true) == .probe)
        #expect(MagicTap.action(isBenchOpen: true, isSealBarred: false) == .seal)
    }

    /// A Magic Tap on a barred Seal does **nothing** rather than firing the bar's pulse: the
    /// pulse says *which rail*, and a VoiceOver player cannot see a rail pulse — so it would be
    /// feedback with no content, in place of feedback with content.
    @Test("A barred Seal does not answer the Magic Tap")
    func barredSealIsSilentToTheMagicTap() {
        #expect(MagicTap.action(isBenchOpen: true, isSealBarred: true) == .none)
    }

    /// Verdict → evidence → bookkeeping, so a fast player can move on after two words.
    @Test("Announcements are ordered and verdicts interrupt")
    func announcementOrder() {
        #expect(AnnouncementOrder.Stage.allCases == [.verdict, .evidence, .bookkeeping])
        #expect(AnnouncementOrder.Stage.verdict < AnnouncementOrder.Stage.bookkeeping)
        #expect(AnnouncementOrder.verdictIsHighPriority)
    }
}
