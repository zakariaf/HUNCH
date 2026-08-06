public import Foundation

public import Glyphs
public import Laws

/// §7.3's hinge — **exactly when the law changes**.
///
/// Three triggers, and the hinge fires at the earliest of them. The design's own decision is
/// that trigger (b) exists at all: without it a fast player solves `L₁` before the hinge and
/// never experiences DRIFT, so the mode's presence would be a function of how good you are at
/// PROBE.
public enum DriftHinge {

    public enum Trigger: Equatable, Sendable {
        /// The probe delivering the `N_admits`-th admit under `L₁`. **That probe's verdict is
        /// `L₁`'s**; probe *t+1* onward is `L₂`'s.
        case satiation
        /// The player's first declaration whose extension equals `L₁`'s. The declaration is
        /// **accepted** — full ring, inscribe haptic, Bench slides away — and then the floor
        /// moves. Being told *yes, that was the law* and then finding that it is not is the
        /// mode stated in one gesture.
        case capture
        /// Probe index `ceil(0.80 · par)` reached with fewer than `N_admits` admits.
        case forced
    }

    /// `N_admits ~ U[3, 6]`, drawn deterministically from the round seed.
    public static func admitsBeforeHinge(seed: UInt64) -> Int {
        var rng = SplitMix64(seed: seed)
        return 3 + Int(rng.next() % 4)
    }

    /// - Returns: the trigger that fires at this probe, or `nil` if the hinge has not fired.
    public static func trigger(
        probeIndex: Int, admitsUnderFirstLaw: Int, admitsBeforeHinge: Int,
        capturedFirstLaw: Bool, forcedAt: Int
    ) -> Trigger? {
        if capturedFirstLaw { return .capture }
        if admitsUnderFirstLaw >= admitsBeforeHinge { return .satiation }
        if probeIndex >= forcedAt { return .forced }
        return nil
    }

    /// **The hinge never resets context.** In the contextual bands the next probe is evaluated
    /// by `L₂` against the **pre-hinge** `prev`: the chain is unbroken and only the predicate
    /// changed. Resetting it would add a second simultaneous change and make the mode measure
    /// two things at once.
    public static let preservesContext = true

    /// Only trigger (b) leaves a visible trace before the reveal — a seam marker in the ribbon —
    /// and only because the player already knows something happened: they were just told they
    /// were right.
    public static func writesSeamMarker(_ trigger: Trigger) -> Bool { trigger == .capture }
}
