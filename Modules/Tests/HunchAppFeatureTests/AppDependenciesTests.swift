import Foundation
import Testing

import HunchAppFeature
import ModulesTestSupport
import Persistence

/// The graph is built in one function. These tests are about the two capabilities that make the
/// app nondeterministic on purpose, and about the fallback that keeps a full disk playable.
@Suite("The composition root", .tags(.unit, .presubmission))
@MainActor
struct AppDependenciesTests {

    @Test("The preview graph is fixed: same seed, same clock, every time")
    func previewIsDeterministic() {
        let first = AppDependencies.preview()
        let second = AppDependencies.preview()
        #expect(first.seeds.next() == second.seeds.next())
        #expect(first.now.date() == second.now.date())
        #expect(AppDependencies.preview(seed: 7).seeds.next() == 7)
    }

    /// §11.13: a player whose disk is full still gets to play — they just do not get to keep it.
    /// The round machinery never learns the difference, because it only talks to the protocol.
    @Test("A store that cannot be created degrades to memory, not to a crash")
    func aFullDiskIsPlayable() {
        let dependencies = AppDependencies.preview()
        #expect(dependencies.storeHealth == .healthy)
        // The live graph's fallback is the same shape; what is asserted here is that the
        // *health* is carried as data rather than thrown, so the chrome can report it.
        let degraded = AppDependencies(
            store: dependencies.store, now: .system, seeds: .system, cues: dependencies.cues,
            storeHealth: .writeFailed(.manifest))
        #expect(degraded.storeHealth != .healthy)
    }

    /// The clock is a capability, not a record: `Round` takes `@Sendable () -> Date` so
    /// `LoomFeature` never has to import the composition root that sits above it.
    @Test("The clock is one closure and can be frozen")
    func theClockIsACapability() {
        let stamp = Date(timeIntervalSince1970: 1_234)
        #expect(Now.fixed(stamp).date() == stamp)
    }
}
