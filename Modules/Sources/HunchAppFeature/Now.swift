public import Foundation

/// The clock, as a capability.
///
/// It lives here rather than in `HunchCore` because `Date()` is banned under `HunchCore/Sources`
/// by hygiene check 6 — a pure domain that reads a clock is a domain whose tests are not
/// reproducible. And it is a one-field struct whose whole value *is* its closure, which is what
/// lets `LoomFeature` take `@Sendable () -> Date` directly instead of importing the composition
/// root it sits below. See `DECISIONS.md` 82.
public struct Now: Sendable {
    public let date: @Sendable () -> Date

    public init(date: @escaping @Sendable () -> Date) { self.date = date }

    public static let system = Now(date: { Date() })

    public static func fixed(_ date: Date) -> Now { Now(date: { date }) }
}
