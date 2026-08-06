public import Foundation
public import Glyphs

/// The shipping store: `Codable` JSON in `Application Support/Hunch/`, written atomically.
///
/// An `actor` because every write is a read-modify-write against the same directory, and the
/// alternative — a lock around `FileManager` — is `05 R17`'s second rung for state that is
/// genuinely shared and genuinely async.
public actor FilePersistenceStore: PersistenceStore {
    private let root: URL
    private let corruptDirectory: URL
    private var currentHealth: StoreHealth = .healthy

    /// - Parameter root: injected rather than derived, so a test can point it at a temporary
    ///   directory without touching the real container (`04 A29`).
    public init(root: URL) throws {
        self.root = root
        corruptDirectory = root.appendingPathComponent("corrupt", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// The real container. Only the composition root calls this.
    public static func applicationSupportRoot() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return base.appendingPathComponent("Hunch", isDirectory: true)
    }

    private func url(for file: StoreFile) -> URL {
        root.appendingPathComponent(file.fileName)
    }

    public var present: Set<StoreFile> {
        get throws {
            let names = Set(
                (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
            return Set(StoreFile.allCases.filter { names.contains($0.fileName) })
        }
    }

    public var health: StoreHealth { currentHealth }

    public func load(_ file: StoreFile) throws -> Data {
        let target = url(for: file)
        guard FileManager.default.fileExists(atPath: target.path) else {
            throw StoreError.missing(file)
        }
        do {
            return try Data(contentsOf: target)
        } catch {
            throw StoreError.unreadable(file)
        }
    }

    /// Atomic: `Data.write(options: .atomic)` writes to a temporary and renames, so a crash
    /// mid-write leaves the previous contents rather than a truncated file.
    public func save(_ data: Data, to file: StoreFile) throws {
        do {
            try data.write(to: url(for: file), options: .atomic)
        } catch {
            currentHealth = .writeFailed(file)
            throw StoreError.writeFailed(file)
        }
    }

    public func remove(_ file: StoreFile) throws {
        try? FileManager.default.removeItem(at: url(for: file))
    }

    public func quarantine(_ file: StoreFile) throws {
        try FileManager.default.createDirectory(
            at: corruptDirectory, withIntermediateDirectories: true)
        let destination = corruptDirectory.appendingPathComponent(file.fileName)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: url(for: file), to: destination)
        } catch {
            throw StoreError.missing(file)
        }
        currentHealth = .quarantined(file)
    }

    public func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) throws {
        // The round slot first — it is the smallest file, so it is the last thing to be lost
        // if the disk fills mid-commit.
        if let mode, let roundData = writes[.round(mode)] {
            try save(roundData, to: .round(mode))
        }
        for (file, data) in writes.sorted(by: { $0.key.fileName < $1.key.fileName }) {
            if case .round = file { continue }
            try save(data, to: file)
        }
        // Cleared LAST, only after every other write succeeded — a failure mid-commit must
        // leave a resumable round, never a round that was cleared and never recorded.
        if let mode { try remove(.round(mode)) }
    }

    /// §11.13: the derived index is excluded from the device backup, and this is the one place
    /// that is set.
    public func excludeDerivedFromBackup() throws {
        var target = url(for: .lawIndex)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
    }
}
