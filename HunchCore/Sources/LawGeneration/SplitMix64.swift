/// The project's only random number generator.
///
/// A struct of one `UInt64`, therefore trivially `Sendable` and trivially copied. It is never
/// stored: `generate(seed:band:targetDelta:mode:avoid:)` constructs one as a local `var` and
/// threads `&rng` down a synchronous call tree, and it dies at the closing brace (08 §4).
///
/// **Randomness is a parameter, never an ambient.** Every function that needs it takes
/// `using rng: inout some RandomNumberGenerator`. No RNG is stored in a class, an actor, a
/// `static var` or an `@Observable` property, and none ever crosses an isolation boundary — if
/// band-8 generation ever measures slow, the *seed* crosses (a `UInt64`) and the callee builds
/// its own generator (08 §4 consequence 1).
///
/// - Note: The finaliser is `GAME_DESIGN.md` §11.6's, which is also the single normative
///   derivation of the daily Anomaly. `Anomaly.seed(day:)` (E16·T01) **calls** `mix(_:)`; it
///   does not re-type the constants, because a globally shared law with two derivations is a
///   coin flip at implementation time.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    /// The increment applied to the state before each finalise.
    ///
    /// Canon fixes the finaliser and **not** the increment (§11.6 states one and is silent on
    /// the other), so this is a decision recorded in `DECISIONS.md`: the reference SplitMix64
    /// gamma, the odd 64-bit approximation of 2⁶⁴/φ. Two spellings of `next()` are two different
    /// games; the cross-process golden fixture (E06·T10) freezes this one.
    public static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    /// The SplitMix64 finaliser — `GAME_DESIGN.md` §11.6, copied from there and nowhere else.
    ///
    /// Every step is a xor-shift or a multiply, and all of them fix zero, so `mix(0) == 0`.
    /// That is precisely why `next()` adds the gamma *before* finalising: an implementation
    /// that finalised first would return 0 forever from seed 0 and look correct on every
    /// other seed.
    public static func mix(_ input: UInt64) -> UInt64 {
        var z = input
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func next() -> UInt64 {
        state &+= Self.gamma  // increment FIRST — the finaliser fixes zero
        return Self.mix(state)
    }
}
