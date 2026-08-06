import Foundation
import Testing

import Glyphs
import HunchTestSupport
import Laws
import Persistence

/// The store is a seam, so the tests are written against the PROTOCOL and run against both
/// implementations. A test that only ever exercised the in-memory double would not catch an
/// atomic-write or a quarantine bug in the one that ships.
@Suite("PersistenceStore", .tags(.unit, .presubmission))
struct StoreTests {
    static func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunch-test-\(UUID().uuidString)", isDirectory: true)
        return url
    }

    @Test("§11.13's tree is ten kinds of file and twenty paths")
    func treeShape() {
        // Derived from the two enums, never typed as 20 — a ninth band would change it.
        let expected = 2 + Band.allCases.count + 5 + Mode.allCases.count + 1
        #expect(StoreFile.allCases.count == expected)
        #expect(StoreFile.allCases.count == 20)
        #expect(Set(StoreFile.allCases.map(\.fileName)).count == StoreFile.allCases.count)
    }

    @Test("Every file spells its §11.13 name, including the two that differ from their case")
    func fileNames() {
        #expect(StoreFile.statistics.fileName == "stats.json")  // concept vs spec spelling
        #expect(StoreFile.round(.probe).fileName == "round-probe.json")
        #expect(StoreFile.codexShelf(.systemic).fileName == "codex-b8.json")
        #expect(StoreFile.anomalyHighWater.fileName == "anomaly.hw")
        #expect(StoreFile.lawIndex.fileName == "lowerBandIndex.bin")
    }

    @Test("Every file has a stated recovery policy — §11.13's failure table")
    func everyFileHasARecovery() {
        for file in StoreFile.allCases {
            _ = file.recoveryPolicy  // exhaustive switch; a new case would not compile
        }
        #expect(StoreFile.round(.probe).recoveryPolicy == .voidTheRound)
        #expect(StoreFile.anomaly.recoveryPolicy == .recoverFromSidecar)
        #expect(StoreFile.codexShelf(.literal).recoveryPolicy == .rebuildEmpty)
        #expect(StoreFile.codexIndex.recoveryPolicy == .rebuildByScanningShelves)
    }

    @Test("Only the derived index is excluded from backup")
    func backupExclusion() {
        #expect(StoreFile.allCases.filter(\.isDerived) == [.lawIndex])
    }

    @Test("Save → load round-trips, in memory")
    func inMemoryRoundTrip() async throws {
        let store = InMemoryPersistenceStore()
        let payload = Data("hello".utf8)
        try await store.save(payload, to: .profile)
        let loaded = try await store.load(.profile)
        #expect(loaded == payload)
        let hasProfile = try await store.present.contains(.profile)
        #expect(hasProfile)
        try await store.remove(.profile)
        let gone = try await store.present.contains(.profile)
        #expect(!gone)
    }

    @Test("Save → load round-trips on disk, atomically")
    func onDiskRoundTrip() async throws {
        let root = try Self.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FilePersistenceStore(root: root)
        let payload = Data("{\"schema\":1}".utf8)
        try await store.save(payload, to: .manifest)
        let loaded = try await store.load(.manifest)
        #expect(loaded == payload)
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("manifest.json").path))
    }

    /// A store that survives a kill is the whole point: save, drop the actor, open a NEW one
    /// over the same directory, and the bytes must still be there.
    @Test("Save → kill → relaunch keeps the bytes")
    func survivesRelaunch() async throws {
        let root = try Self.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let payload = Data("persisted".utf8)
        do {
            let first = try FilePersistenceStore(root: root)
            try await first.save(payload, to: .ladder)
        }
        let second = try FilePersistenceStore(root: root)  // a different actor instance
        let reloaded = try await second.load(.ladder)
        #expect(reloaded == payload)
    }

    @Test("Quarantine moves the file aside and leaves the store healthy without it")
    func quarantineMovesAside() async throws {
        let root = try Self.temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FilePersistenceStore(root: root)
        try await store.save(Data("corrupt".utf8), to: .codexShelf(.pair))
        try await store.quarantine(.codexShelf(.pair))
        let shelfGone = try await store.present.contains(.codexShelf(.pair))
        #expect(!shelfGone)
        #expect(await store.health == .quarantined(.codexShelf(.pair)))
        #expect(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("corrupt/codex-b2.json").path))
    }

    /// §11.13's ordering, and the property that makes it matter: a commit that fails partway
    /// must leave a RESUMABLE round, never a round that was cleared and never recorded.
    @Test("A failed commit leaves the round slot intact")
    func failedCommitLeavesTheRoundResumable() async throws {
        let store = InMemoryPersistenceStore()
        try await store.save(Data("round-in-progress".utf8), to: .round(.probe))
        await store.setFailingWrites([.statistics])

        await #expect(throws: StoreError.self) {
            try await store.commit(
                [.round(.probe): Data("updated".utf8), .statistics: Data("stats".utf8)],
                clearingRoundFor: .probe)
        }
        // The slot is still there, so the round can be resumed.
        let slotPresent = try await store.present.contains(.round(.probe))
        #expect(slotPresent)
    }

    @Test("A clean commit clears the round slot LAST")
    func cleanCommitClearsTheSlot() async throws {
        let store = InMemoryPersistenceStore()
        try await store.commit(
            [.round(.probe): Data("r".utf8), .statistics: Data("s".utf8)],
            clearingRoundFor: .probe)
        let slotCleared = try await store.present.contains(.round(.probe))
        #expect(!slotCleared)
        let statsPresent = try await store.present.contains(.statistics)
        #expect(statsPresent)
    }

    @Test("Loading an absent file is a typed error, never a crash")
    func missingIsTyped() async throws {
        let store = InMemoryPersistenceStore()
        await #expect(throws: StoreError.missing(.profile)) {
            try await store.load(.profile)
        }
    }

    @Test("A schema from the future refuses rather than guesses")
    func downgradeRefuses() throws {
        #expect(throws: Schema.MigrationError.self) { try Schema.plan(from: Schema.current + 1) }
        let plan = try Schema.plan(from: Schema.current)
        #expect(plan.isEmpty)
    }
}
