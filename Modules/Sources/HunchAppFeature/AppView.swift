public import SwiftUI

public import Glyphs
public import LoomFeature
public import Persistence

/// The one view the app target names.
///
/// It decides the first frame from `AppLaunchRoute` and installs the dependency graph. E17 puts
/// the Frame behind `.frame` and E11 the served round behind `.resumeRound`; until then both
/// resolve to §12.5's opening round, which is the only round the app can build without a ladder.
@MainActor
public struct AppView: View {
    private let dependencies: AppDependencies
    @State private var route: AppLaunchRoute

    public init(dependencies: AppDependencies, route: AppLaunchRoute = .openingRound) {
        self.dependencies = dependencies
        _route = State(initialValue: route)
    }

    public var body: some View {
        content
            .hunchEnvironment(dependencies)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        // The Frame is E17's and the served round is E11's. Until they exist this is not a
        // placeholder: §12.5's opening round is a complete round, and routing a returning
        // player to it is a smaller lie than routing them to an empty screen.
        case .openingRound, .frame, .resumeRound:
            RoundView(round: .openingRound(cues: dependencies.cues))
        }
    }
}
