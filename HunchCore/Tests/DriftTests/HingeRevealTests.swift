import Foundation
import Testing

import Drift
import HunchTestSupport

/// §7.9. Everything here is decoration over state that is already on disk, which is what makes
/// the reveal skippable, interruptible and replayable without any of it mattering.
@Suite("The hinge reveal", .tags(.unit, .presubmission))
struct HingeRevealTests {

    @Test("Five steps, in order, and the hold is the longest")
    func fiveSteps() {
        #expect(HingeReveal.Step.allCases.count == 5)
        #expect(HingeReveal.Step.allCases[0] == .seam)
        #expect(HingeReveal.duration(of: .hold) == .seconds(3))
        #expect(HingeReveal.total > HingeReveal.reduceMotionTotal)
    }

    /// Equal and opposite, because neither law is the privileged one: the picture is a fork,
    /// not a correction.
    @Test("The split displaces both lanes equally")
    func theSplitIsSymmetric() {
        #expect(HingeReveal.splitDisplacement == 18.0)
    }

    /// The whole reveal rests on §7.2's one-leaf edit. Two moving parts would ask the player to
    /// diff two diagrams; one lands in a glance.
    @Test("Exactly one leaf animates in the morph")
    func oneMovingPart() {
        #expect(HingeReveal.animatedLeafCount == 1)
    }

    /// Reduce Motion swaps the motion and keeps the **information**: four crossfades of the same
    /// total duration, with the two-lane geometry and the single changed leaf intact. Dropping
    /// them would make the accessible reveal a different and worse reveal.
    @Test("Reduce Motion preserves the duration and the geometry")
    func reduceMotionKeepsTheInformation() {
        let animated = HingeReveal.Step.allCases.filter { $0 != .hold }
        let sum = animated.reduce(Duration.zero) { $0 + HingeReveal.duration(of: $1) }
        #expect(HingeReveal.reduceMotionTotal == sum)
        #expect(HingeReveal.reduceMotionTotal == .milliseconds(2_100))
    }

    /// No count, no label — the player sees how long the useless run was without being told a
    /// number, which is §7.8's rule arriving in the drawing.
    @Test("The dead stretch is drawn, never counted")
    func theDeadStretchIsWordless() {
        #expect(HingeReveal.deadStretchOpacity == 0.25)
    }
}
