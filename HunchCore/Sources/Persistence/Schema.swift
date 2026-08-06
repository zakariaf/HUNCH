public import Foundation

/// §11.13's schema versioning. One global `schema`, starting at 1; every other file echoes `v`
/// for validation.
public struct Manifest: Codable, Hashable, Sendable {
    public var schema: Int
    public var createdAt: Date
    public var lastWriteAt: Date

    public init(schema: Int = Schema.current, createdAt: Date, lastWriteAt: Date) {
        self.schema = schema
        self.createdAt = createdAt
        self.lastWriteAt = lastWriteAt
    }
}

public enum Schema {
    /// Bumped only by a semantic change, and every bump gets an explicit
    /// `migrate_vN_to_vN+1(directory:)`.
    public static let current = 1

    /// The migration ladder. A gap is a compile-time hole rather than a runtime surprise,
    /// because `migrations` is asserted contiguous from 1 to `current`.
    public static let migrations: [Int: @Sendable (any PersistenceStore) async throws -> Void] = [:]

    public enum MigrationError: Error, Hashable, Sendable {
        /// The stored schema is newer than this build understands — a downgrade, which must
        /// refuse rather than guess.
        case fromTheFuture(stored: Int, understood: Int)
        case missingStep(Int)
    }

    /// Additive fields decode with `decodeIfPresent` and a default; removed fields are
    /// tolerated. Only a *semantic* change bumps the version and needs a step here.
    public static func plan(from stored: Int) throws -> [Int] {
        guard stored <= current else {
            throw MigrationError.fromTheFuture(stored: stored, understood: current)
        }
        guard stored >= 1 else { throw MigrationError.missingStep(stored) }
        return Array(stored..<current)
    }
}
