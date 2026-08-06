public import Glyphs

/// §6.5's single-slot queue, as a pure value — so the whole input policy is testable with no
/// clock, no view and no simulator.
///
/// Input is locked for the length of the beat. **One** tap during the lock is honoured at the
/// unlock; a second is dropped, silently and with no feedback (§6.11 case 10) — a rejection
/// animation for a tap the player already knows was too fast is noise. The PROBE and twin keys
/// share the one slot, because they are the same act with different arguments.
public nonisolated struct InputGate: Equatable, Sendable {

    public enum Action: Equatable, Sendable {
        case probe(Glyph)
        case twin
    }

    public enum Disposition: Equatable, Sendable {
        case fires
        case queued
        case dropped
    }

    public private(set) var isLocked = false
    public private(set) var queued: Action?

    public init() {}

    public mutating func request(_ action: Action) -> Disposition {
        guard isLocked else {
            isLocked = true
            return .fires
        }
        guard queued == nil else { return .dropped }
        queued = action
        return .queued
    }

    /// **The Seal is edge-triggered and never queues** (§6.11 case 11). A queued second
    /// declaration would be catastrophic: it would spend the round's second strike on a press
    /// the player made before seeing the first one resolve.
    public mutating func requestSeal() -> Disposition {
        isLocked ? .dropped : .fires
    }

    /// Ends the beat. Returns the queued action, if any, and **re-locks** — the queued action
    /// opens its own beat rather than arriving into an open gate.
    public mutating func unlock() -> Action? {
        guard let action = queued else {
            isLocked = false
            return nil
        }
        queued = nil
        isLocked = true
        return action
    }

    /// Ends the beat and discards anything queued — the round is over, and honouring a tap
    /// made before the last verdict landed would spend a probe past the cap.
    public mutating func close() {
        queued = nil
        isLocked = false
    }
}
