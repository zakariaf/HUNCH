import LoomFeature
import SwiftUI

/// The app target holds `@main`, the call to the composition root, and nothing else (01 P8).
///
/// E10·T01 replaces this body with `AppView().hunchEnvironment(AppDependencies.live())` — a run
/// frame, a route graph and a generated law. Until then it opens directly on one round of the
/// fixed opening law (§12.5), which is what E08 built and the first thing there is to *play*.
@main
struct HunchApp: App {
    var body: some Scene {
        WindowGroup {
            RoundView(round: .openingRound())
        }
    }
}
