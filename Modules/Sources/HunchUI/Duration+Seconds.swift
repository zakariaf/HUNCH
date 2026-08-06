public import Foundation

/// `Duration`, never `Double`, for time in `HunchCore` — a bare `260` is ambiguous between
/// milliseconds and seconds, and both spellings appear in the GDD. SwiftUI wants seconds, so
/// the conversion happens exactly once, here.
extension Duration {
    /// - Note: **One rounding, not two.** `Double(whole) + Double(atto)/1e18` rounds the
    ///   fraction and then rounds the sum, and for §13.7.1's 1,840 ms reveal it lands one ulp
    ///   below `1.84` — an animation whose duration is not the duration the design states.
    ///   Going through integer nanoseconds is exact for every duration this app names, so the
    ///   single division is the only place a rounding happens. The overflow arm is unreachable
    ///   below 292 years and is written rather than trapped because this is a UI conversion.
    public var seconds: Double {
        let (whole, attoseconds) = components
        let (scaled, overflowed) = whole.multipliedReportingOverflow(by: 1_000_000_000)
        let (nanoseconds, carried) = scaled.addingReportingOverflow(attoseconds / 1_000_000_000)
        guard !overflowed, !carried else { return Double(whole) + Double(attoseconds) / 1e18 }
        return Double(nanoseconds) / 1e9
    }
}
