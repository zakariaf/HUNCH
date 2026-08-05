internal import LawGeneration

/// Shared, immutable test corpora. Everything here is a `let` of a `Sendable` value: tests run
/// in parallel *in one process* (06 T10), so a `static var` here would be a data race across
/// every suite, not merely an ordering hazard.
public enum Corpora {
    /// The brief's invariant-1 count. The single authoritative home: tests cite this, never a
    /// literal (`hunch-swift-testing`, *Never* — "never restate a value that lives in Swift").
    public static let lawsPerBand = 10_000

    /// Reproducible from `(band, index)` alone, so a failure message is a complete repro.
    ///
    /// - Note: `band` is an `Int` only until `Band` exists (E05·T06), at which point the
    ///   parameter type changes to `Band` and the body reads `UInt64(band.rawValue)`. `Band`'s
    ///   raw values are 1…8, so the change moves no bits — `CorporaTests.derivationIsFrozen`
    ///   is what proves it.
    public static func seed(band: Int, index: Int) -> UInt64 {
        var rng = SplitMix64(seed: 0xC0FF_EE00_0000_0000 ^ UInt64(band))
        for _ in 0..<index { _ = rng.next() }
        return rng.next()
    }
}
