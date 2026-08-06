public import SwiftUI

public import Glyphs
public import HunchUI
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

    /// §12.5's first frame, decided from state alone.
    ///
    /// The store's `present` is `async` because a file listing is, and that is the right shape:
    /// the alternative is a synchronous read on the launch path, which is the one place an app
    /// cannot afford one. The route therefore *starts* at the opening round — the honest answer
    /// for a fresh install, which is also the common case — and corrects itself on the first
    /// frame if there is a snapshot to resume or a manifest to return from.
    private func resolveLaunchRoute() async {
        let present = (try? await dependencies.store.present) ?? []
        let suspended = Set(Mode.allCases.filter { present.contains(.round($0)) })
        route = AppLaunchRoute.decide(
            suspended: suspended, hasPlayed: present.contains(.manifest))
    }

    public var body: some View {
        content
            .hunchEnvironment(dependencies)
            .task { await resolveLaunchRoute() }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .frame:
            RenderEnvReader { env in
                FrameView(
                    availability: availability, env: env,
                    onPlay: { _ in route = .openingRound })
            }
        // The *served* round is E11's serving layer. §12.5's opening round is a complete round,
        // so routing here is a smaller lie than routing to an empty screen — and it is the only
        // round the app can build without a ladder.
        case .openingRound, .resumeRound:
            RoundView(round: .openingRound(cues: dependencies.cues))
        }
    }

    /// What the Frame can offer. E15 reads it from the Codex; until then every gate is honest
    /// about a Codex with no pages, which is what a new player actually has.
    private var availability: FrameView.Availability {
        FrameView.Availability()
    }
}
