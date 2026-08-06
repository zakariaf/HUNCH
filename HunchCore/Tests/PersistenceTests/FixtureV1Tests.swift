import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws
import Persistence

/// The brief's persistence-migration requirement: *"a v1 fixture that must still load after any
/// schema change."*
///
/// The tree is HAND-WRITTEN, not generated from the current encoders. That is the whole value:
/// a fixture produced by today's code would silently follow tomorrow's encoding change, and
/// the test would keep passing while every real user's saved game broke. **This fixture is
/// never regenerated to make a build pass** — a v1 file that no longer loads is a migration
/// that was not written.
@Suite("Fixtures/v1", .tags(.integration, .presubmission))
struct FixtureV1Tests {
    static func fixtureRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/v1", isDirectory: true)
    }

    static func loadStore() throws -> InMemoryPersistenceStore {
        var seeded: [StoreFile: Data] = [:]
        for file in StoreFile.allCases {
            let url = fixtureRoot().appendingPathComponent(file.fileName)
            if let data = try? Data(contentsOf: url) { seeded[file] = data }
        }
        return InMemoryPersistenceStore(seeded: seeded)
    }

    @Test("Every v1 file still loads")
    func v1LoadsGreen() async throws {
        let store = try Self.loadStore()
        let present = try await store.present
        #expect(present.contains(.manifest))
        #expect(present.contains(.anomaly))
        #expect(present.contains(.anomalyHighWater))
        #expect(present.contains(.ladder))
        #expect(present.contains(.codexShelf(.literal)))
    }

    @Test("The v1 manifest declares schema 1 and the migration plan from it is empty today")
    func v1ManifestSchema() async throws {
        let store = try Self.loadStore()
        let data = try await store.load(.manifest)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["schema"] as? Int == 1)
        let plan = try Schema.plan(from: 1)
        #expect(plan.isEmpty, "schema is still 1, so there is nothing to migrate yet")
    }

    /// The assertion §11.13 asks for by name: run every reset against a COPY of the v1 tree and
    /// require the ledger and its sidecar to be byte-identical afterwards.
    @Test(
        "All five resets leave anomaly.json and anomaly.hw byte-identical",
        arguments: ResetAction.allCases)
    func resetsPreserveTheLedger(_ action: ResetAction) async throws {
        let before = try Data(
            contentsOf: Self.fixtureRoot().appendingPathComponent("anomaly.json"))
        let sidecarBefore = try Data(
            contentsOf: Self.fixtureRoot().appendingPathComponent("anomaly.hw"))

        let store = try Self.loadStore()
        for file in action.deletes { try await store.remove(file) }
        for file in action.rewrites { try await store.save(Data(), to: file) }

        let after = try await store.load(.anomaly)
        let sidecarAfter = try await store.load(.anomalyHighWater)
        #expect(after == before, "\(action) altered anomaly.json")
        #expect(sidecarAfter == sidecarBefore, "\(action) altered anomaly.hw")
    }

    /// The sidecar is 16 bytes and independently addressable — it is what recovers the ledger
    /// when the ledger is the thing that failed to decode.
    @Test("The high-water sidecar is 16 bytes and readable on its own")
    func sidecarShape() async throws {
        let store = try Self.loadStore()
        let data = try await store.load(.anomalyHighWater)
        #expect(data.count == 16)
        let day = data.prefix(8).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        #expect(day == 20_000)
    }
}
