public import Foundation

/// Where a round's 64-bit seed comes from — the one place in the app that is allowed to be
/// nondeterministic on purpose.
///
/// Everything downstream of it is a pure function of the seed, which is what makes a bug
/// reproducible from a round record: paste the seed, get the round back.
public struct SeedSource: Sendable {
    public let next: @Sendable () -> UInt64

    public init(next: @escaping @Sendable () -> UInt64) { self.next = next }

    public static let system = SeedSource(next: {
        var generator = SystemRandomNumberGenerator()
        return UInt64.random(in: .min ... .max, using: &generator)
    })

    public static func fixed(_ seed: UInt64) -> SeedSource { SeedSource(next: { seed }) }
}
