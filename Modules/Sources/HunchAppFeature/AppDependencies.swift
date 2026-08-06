public import Foundation
public import SwiftUI

public import Feedback
public import Glyphs
public import HunchUI
public import Persistence

/// The composition root. **Every** dependency the app has is constructed here, in one function,
/// and travels down through one environment modifier.
///
/// The app target holds `@main`, a call to this, and nothing else (`01 P8`): a second place that
/// builds a store or a clock is a second app, and the two disagree the first time one of them is
/// changed.
@MainActor
public struct AppDependencies {
    public let store: any PersistenceStore
    public let now: Now
    public let seeds: SeedSource
    /// `SilentCuePlayer` until E20 ships the synthesiser and the haptic engine. Silence is a
    /// complete implementation, not a stub (see `Feedback`), so nothing here is pretending.
    public let cues: any CuePlayer
    public let storeHealth: StoreHealth

    public init(
        store: any PersistenceStore,
        now: Now,
        seeds: SeedSource,
        cues: any CuePlayer,
        storeHealth: StoreHealth = .healthy
    ) {
        self.store = store
        self.now = now
        self.seeds = seeds
        self.cues = cues
        self.storeHealth = storeHealth
    }

    /// The real graph.
    ///
    /// A store that cannot be created is **not** a fatal error: §11.13 says a player whose disk
    /// is full still gets to play, they just do not get to keep it. So the fallback is the
    /// in-memory store plus `writesFailing`, which is exactly what the chrome's hairline
    /// reports — and the round machinery never learns the difference, because it only ever
    /// talks to `any PersistenceStore`.
    public static func live() -> AppDependencies {
        if let root = try? FilePersistenceStore.applicationSupportRoot(),
            let store = try? FilePersistenceStore(root: root)
        {
            return AppDependencies(
                store: store, now: .system, seeds: .system, cues: SilentCuePlayer())
        }
        return AppDependencies(
            store: InMemoryPersistenceStore(), now: .system, seeds: .system,
            cues: SilentCuePlayer(), storeHealth: .writeFailed(.round(.probe)))
    }

    /// Previews and tests: a fixed clock and a fixed seed, so a preview is the same picture
    /// every time it is opened and a test is the same run every time it is run.
    public static func preview(
        seed: UInt64 = 0x00C0_FFEE, date: Date = Date(timeIntervalSince1970: 0)
    ) -> AppDependencies {
        AppDependencies(
            store: InMemoryPersistenceStore(), now: .fixed(date), seeds: .fixed(seed),
            cues: SilentCuePlayer())
    }
}

extension View {
    /// `04 A28`: the module that knows what the graph contains is the module that installs it.
    ///
    /// Re-applied at **every presented subtree** — a `.sheet`, a `.fullScreenCover`, an
    /// `.alert`, a `.popover` each start a new environment hierarchy (`04 A25`), and "remember
    /// to re-inject" is exactly the rule reviews forget, so check 13 makes it mechanical.
    public func hunchEnvironment(_ dependencies: AppDependencies) -> some View {
        environment(\.storeHealth, dependencies.storeHealth)
    }
}
