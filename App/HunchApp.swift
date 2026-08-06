import HunchAppFeature
import SwiftUI

/// The app target holds `@main`, the call to the composition root, and nothing else (`01 P8`).
@main
struct HunchApp: App {
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            AppView(dependencies: dependencies)
        }
    }
}
