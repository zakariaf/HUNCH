import Foundation
import Testing

import HunchTestSupport
import Ladder

/// The measured numbers, printed rather than only asserted. A harness whose output nobody ever
/// looks at is a harness that passes at 0.771 for a year.
@Suite("Harness report", .tags(.integration, .nightly))
struct HarnessReportTests {

    @Test("Report the realised rate across the ability range")
    func report() {
        for theta in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0] {
            let result = ResponseHarness(trueTheta: theta).run(rounds: 20_000, seed: 0xA11CE)
            print(
                "θ_true \(theta): rate \(String(format: "%.4f", result.successRate))",
                "modal band share \(String(format: "%.3f", result.modalBandShare))",
                "longest run \(result.longestSameFamilyRun)")
            #expect(result.rounds == 20_000)
        }
    }
}
