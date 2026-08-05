public import Foundation

/// `Duration`, never `Double`, for time in `HunchCore` — a bare `260` is ambiguous between
/// milliseconds and seconds, and both spellings appear in the GDD. SwiftUI wants seconds, so
/// the conversion happens exactly once, here.
extension Duration {
    public var seconds: Double {
        let (whole, attoseconds) = components
        return Double(whole) + Double(attoseconds) / 1e18
    }
}
