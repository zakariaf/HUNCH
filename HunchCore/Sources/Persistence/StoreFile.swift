public import Foundation
public import Glyphs
public import Laws

/// §11.13's file tree. Every path on disk is one of these; nothing is addressed by a string.
///
/// `08 §3` lists nine cases; §11.13 counts ten kinds of file. The tenth is `anomalyHighWater`,
/// the 16-byte `anomaly.hw` sidecar — it has to be addressable on its own because it is what
/// recovers `anomaly.json` when `anomaly.json` is the thing that failed to decode.
public enum StoreFile: Hashable, Sendable, CaseIterable {
    case manifest
    case codexIndex
    case codexShelf(Band)
    case anomaly
    case anomalyHighWater
    case profile
    case ladder
    case statistics
    case round(Mode)
    case lawIndex

    public static let allCases: [StoreFile] =
        [.manifest, .codexIndex]
        + Band.allCases.map(StoreFile.codexShelf)
        + [.anomaly, .anomalyHighWater, .profile, .ladder, .statistics]
        + Mode.allCases.map(StoreFile.round)
        + [.lawIndex]
}

extension StoreFile {
    /// The bare filename inside `Application Support/Hunch/`. §11.13 owns every spelling; note
    /// `statistics` → `stats.json`: the case is named for the concept, the file for the spec.
    public var fileName: String {
        switch self {
        case .manifest: "manifest.json"
        case .codexIndex: "codex-index.json"
        case .codexShelf(let b): "codex-b\(b.rawValue).json"
        case .anomaly: "anomaly.json"
        case .anomalyHighWater: "anomaly.hw"
        case .profile: "profile.json"
        case .ladder: "ladder.json"
        case .statistics: "stats.json"
        case .round(let m): "round-\(m.slug).json"
        case .lawIndex: "lowerBandIndex.bin"
        }
    }

    /// Derived data, excluded from the device backup (§11.13, and set in exactly one place).
    public var isDerived: Bool { self == .lawIndex }
}

/// What the app does when a file fails to decode. §11.13's failure table, one case per row, so
/// "this file has no stated recovery" is a compile error rather than a discovery in the field.
public enum RecoveryPolicy: Hashable, Sendable {
    /// A codex shelf: quarantine to `corrupt/`, rebuild empty. `codex-index.json` still holds
    /// the lawKeys, so page *detail* is lost but "already found" is not.
    case rebuildEmpty
    case rebuildByScanningShelves
    case resetToDefaults
    /// `anomaly.json` ← `anomaly.hw`, never recovered as a *lower* value.
    case recoverFromSidecar
    /// `round-{mode}.json`: `Outcome.voided`, never a silent alteration — the machine does not
    /// hand back a round it cannot vouch for.
    case voidTheRound
    case regenerate
}

extension StoreFile {
    /// §11.13's failure table.
    public var recoveryPolicy: RecoveryPolicy {
        switch self {
        case .manifest: .regenerate
        case .codexIndex: .rebuildByScanningShelves
        case .codexShelf: .rebuildEmpty
        case .anomaly: .recoverFromSidecar
        // The one row §11.13 does not spell out: if the sidecar is gone and the ledger decodes,
        // the sidecar is rewritten from the ledger. Degenerate regeneration, but stated.
        case .anomalyHighWater: .regenerate
        case .profile: .resetToDefaults
        case .ladder: .resetToDefaults
        case .statistics: .resetToDefaults
        case .round: .voidTheRound
        case .lawIndex: .regenerate
        }
    }
}

/// §11.13's failure states, reduced to what the UI must render.
public enum StoreHealth: Hashable, Sendable {
    case healthy
    case quarantined(StoreFile)
    case writeFailed(StoreFile)
}

public enum StoreError: Error, Hashable, Sendable {
    case missing(StoreFile)
    case unreadable(StoreFile)
    case writeFailed(StoreFile)
}

/// The persistence seam. Injected, never a singleton — `04 A29`'s rule is "no singleton inside a
/// boundary you test across", and this is that boundary.
///
/// Six methods and two properties, so `W44`'s member-count tiebreak never engages; the real
/// reason for the protocol is that the app writes to a container and every test writes to
/// memory, and that substitution is the whole point.
public protocol PersistenceStore: Sendable {
    /// Every file that currently exists.
    var present: Set<StoreFile> { get async throws }

    /// The most recent quarantine or failed write. Drives the chrome hairline (§11.13).
    var health: StoreHealth { get async }

    func load(_ file: StoreFile) async throws -> Data
    func save(_ data: Data, to file: StoreFile) async throws
    func remove(_ file: StoreFile) async throws

    /// Moves a file that failed to decode into `corrupt/` and leaves the store healthy with the
    /// file absent. Only the *caller* can know a payload is malformed — the store moves bytes.
    func quarantine(_ file: StoreFile) async throws

    /// §11.13's write order as one operation: `round-{mode}.json` first because it is the
    /// smallest file, then everything else, and the snapshot slot cleared **last**, only after
    /// every other write has succeeded. Declared on the seam so no caller reinvents the order.
    func commit(_ writes: [StoreFile: Data], clearingRoundFor mode: Mode?) async throws
}
