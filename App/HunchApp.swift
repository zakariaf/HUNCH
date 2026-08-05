import HunchUI
import SwiftUI

/// The app target holds `@main`, the call to the composition root, and nothing else (01 P8).
/// E10·T01 replaces this body with `AppView().hunchEnvironment(AppDependencies.live())`.
/// Until then it renders the token layer, which is the first thing there is to look at.
@main
struct HunchApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
                SnapshotGallery()
            #else
                TokenProofView()
            #endif
        }
    }
}
