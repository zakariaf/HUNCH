import SwiftUI

/// The app target holds `@main`, the call to the composition root, and nothing else (01 P8).
/// E10·T01 replaces this body with `AppView().hunchEnvironment(AppDependencies.live())`;
/// until `Modules/` exists (E03·T06) there is nothing to compose and nothing to import (01 P9).
@main
struct HunchApp: App {
    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}
