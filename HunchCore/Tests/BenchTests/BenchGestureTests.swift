import Testing

import Bench
import HunchTestSupport

/// §4.2's table, as a test. The rule it encodes is an accessibility rule: drag and pinch are
/// exactly the gestures VoiceOver cannot perform and that no textless affordance can teach.
@Suite("The gesture inventory", .tags(.unit, .presubmission))
struct BenchGestureTests {

    @Test("Eight rows, and no ninth")
    func exhaustive() {
        #expect(BenchGesture.allCases.count == 8)
    }

    @Test("Every gesture is a tap or a trailing swipe", arguments: BenchGesture.allCases)
    func onlyTapsAndTrailingSwipes(_ gesture: BenchGesture) {
        #expect(gesture.kind == .tap || gesture.kind == .trailingSwipe)
    }

    @Test("Exactly one row is not a tap, and it carries a custom action")
    func oneNonTap() {
        let nonTaps = BenchGesture.allCases.filter { $0.kind != .tap }
        #expect(nonTaps == [.swipeRailTrailing])
        #expect(nonTaps.filter(\.needsCustomAction).count == nonTaps.count)
        #expect(BenchGesture.allCases.filter(\.needsCustomAction).count == 1)
    }
}
