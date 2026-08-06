public import Foundation
public import Glyphs

/// The in-memory store. Ships in the binary rather than in `HunchTestSupport`, because previews
/// need it too and `HunchTestSupport` is absent from `products:` by design (06 T5a).
///
/// An `actor` rather than a `@MainActor` class: it is mutable state reached from a test suite
/// that runs in parallel and from a view that does not, which is exactly `05 R17`'s third rung.
public actor InMemoryPersistenceStore: PersistenceStore {
    private var files: [StoreFile: Data] = [:]
    private var quarantined: [StoreFile: Data] = [:]
    private var currentHealth: StoreHealth = .healthy

    /// Set to fail the next `save` to this file, so a caller's disk-full path is testable.
    public var failWritesTo: Set<StoreFile> = []

    public init(seeded: [StoreFile: Data] = [:]) {
        files = seeded
    }

    public var present: Set<StoreFile> { Set(files.keys) }
    public var health: StoreHealth { currentHealth }

    public func setFailingWrites(_ files: Set<StoreFile>) { failWritesTo = files }

    public func load(_ file: StoreFile) throws -> Data {
        guard let data = files[file] else { throw StoreError.missing(file) }
        return data
    }

    public func save(_ data: Data, to file: StoreFile) throws {
        if failWritesTo.contains(file) {
            currentHealth = .writeFailed(file)
            throw StoreError.writeFailed(file)
        }
        files[file] = data
    }

    public func remove(_ file: StoreFile) throws { files[file] = nil }

    public func quarantine(_ file: StoreFile) throws {
        guard let data = files.removeValue(forKey: file) else { throw StoreError.missing(file) }
        quarantined[file] = data
        currentHealth = .quarantined(file)
    }

    public func quarantinedData(for file: StoreFile) -> Data? { quarantined[file] }

    /// §11.13's ordering, and the reason it matters: the round slot is cleared LAST, only after
    /// every other write has succeeded, so a failure mid-commit leaves a resumable round rather
    /// than a round that was cleared and never recorded.
    public func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) throws {
        if let mode, let roundData = writes[.round(mode)] {
            try save(roundData, to: .round(mode))
        }
        for (file, data) in writes.sorted(by: { $0.key.fileName < $1.key.fileName }) {
            if case .round = file { continue }
            try save(data, to: file)
        }
        if let mode { try remove(.round(mode)) }
    }
}
