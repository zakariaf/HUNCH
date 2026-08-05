import XCTest

/// Renamed from the wizard's `HunchUITests` so that `-only-testing:HunchUITests` is never
/// ambiguous: `06 T5b` mirrors source paths, so `HunchUI`'s package tests are
/// `Modules/Tests/HunchUITests` (E03·T06). Two test bundles with one name puts two
/// identically-named rows in every scheme and plan.
/// E19·T11 fills this with `performAccessibilityAudit`; it is deliberately empty until then.
final class HunchAutomationTests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
