public import Glyphs
public import Laws
public import Rounds

// Public because @Observable synthesises a public conformance to Observation.Observable, which
// an internal import cannot carry (07 B7a's price, paid rather than worked around).
public import Observation

internal import LawGeneration

/// One live PROBE round.
///
/// Thin over `HunchCore`, and the thinness is the design: this type owns *when* things happen
/// on a screen and never *what* they mean. Phases come from `RoundPhase.advance(_:on:)`,
/// verdicts from `Law.admits(_:after:)`, the ribbon from `Ribbon.probe(_:against:)`, score and
/// marks from `Scoring`. Nothing in this file computes a rule.
///
/// `04 A18`'s triggers 1 and 2 both fire, which is what earns a screen-scoped observable here:
/// the round is an eight-phase machine with locked-input windows, two strikes and a draft, and
/// that state is read by four sibling views — throat, Dial, ribbon, instrument bar — that must
/// agree on it frame by frame. `A19`'s pass-through test still passes: delete `Round` and the
/// phase *timing*, the input lock and the snapshot cadence break; the phase table, the ribbon
/// and the score do not, because they are `HunchCore`'s and are tested there.
@MainActor
@Observable
public final class Round {

    public let law: Law
    public let band: Band
    public let mode: Mode

    /// §6.4: `prev(1)`. Primed, and **not** a probe — it costs nothing and it is not in the
    /// ribbon, which is why a round can be declared at probe 0 (§6.11 case 1).
    public let seedGlyph: Glyph

    public let seed: UInt64
    public let targetDelta: Double

    public private(set) var phase: RoundPhase
    public private(set) var ribbon: Ribbon
    public private(set) var strikes = 0

    /// The throat **is** the draft (§6.3): one glyph, always present, always probeable. It
    /// starts at the seed glyph so probe 1 is one tap, and it survives a probe untouched so a
    /// twin is one more.
    public private(set) var draft: Glyph

    /// Set by the cap-th commit and read by `endVerdictBeat()`. §6.11 case 4 delivers that
    /// verdict in full and only *then* ends the round, so exhaustion cannot be part of the
    /// commit — a phase change there would swallow the last bit the player paid for.
    private var hasReachedCap = false

    public init(
        law: Law,
        band: Band,
        mode: Mode,
        seedGlyph: Glyph,
        seed: UInt64,
        targetDelta: Double
    ) {
        self.law = law
        self.band = band
        self.mode = mode
        self.seedGlyph = seedGlyph
        self.seed = seed
        self.targetDelta = targetDelta
        ribbon = Ribbon(seedGlyph: seedGlyph)
        draft = seedGlyph
        // A fresh round's first frame is this one. `arming` exists for the *resumed* round,
        // where a law is integrity-checked before anything is drawn (E10 owns that route).
        phase = .probing
    }

    // ── What the four sibling views read ─────────────────────────────────────────────────

    public var probesUsed: Int { ribbon.count }

    /// §6.4's `prev(n)`: the previously **probed** glyph regardless of that probe's verdict.
    /// A rejected probe is still context — that is what makes a contextual band learnable.
    public var previousGlyph: Glyph { ribbon.currentContext }

    public var par: Int { band.par }
    public var cap: Int { band.cap }
    public var probesRemaining: Int { cap - probesUsed }

    /// §6.9's par crossing: the round's one non-verdict event, and the point at which the par
    /// row inverts and the dim cap row begins emptying.
    public var hasCrossedPar: Bool { probesUsed >= par }
    public var probesPastPar: Int { max(0, probesUsed - par) }

    public var outcome: Outcome? { phase.outcome }
    public var acceptsInput: Bool { phase.acceptsInput }

    /// §6.9, read from `Scoring` and never restated. Meaningful only once the round is
    /// inscribed; before that it is what the round *would* pay, which the instrument bar does
    /// not show and the round card does.
    public var score: Int {
        Scoring.score(probesUsed: probesUsed, par: par, strikes: strikes)
    }

    public var marks: Int {
        Scoring.marks(probesUsed: probesUsed, par: par, cap: cap)
    }

    // ── Composing ────────────────────────────────────────────────────────────────────────

    /// Ribbon-load and every Dial edit land here: the throat adopts a glyph wholesale (§6.3).
    /// Refused outside an open-input phase, because the throat is the input.
    public func setDraft(_ glyph: Glyph) {
        guard phase.acceptsInput else { return }
        draft = glyph
    }

    // ── Probing ──────────────────────────────────────────────────────────────────────────

    /// The PROBE key: feed the Loom whatever the throat is holding.
    @discardableResult
    public func probeDraft() -> Verdict? { probe(draft) }

    /// Feed the Loom one glyph.
    ///
    /// The verdict is computed and committed **synchronously, at t = 0 of the beat sheet**, and
    /// merely displayed over the 420 ms that follow (§6.1). Killing the app mid-animation
    /// therefore loses nothing, and no view can be the reason a verdict is or is not true.
    ///
    /// - Returns: the verdict, or `nil` when the probe was refused — input is locked, or the
    ///   cap is already spent.
    @discardableResult
    public func probe(_ glyph: Glyph) -> Verdict? {
        guard phase == .probing, probesUsed < cap else { return nil }
        draft = glyph
        return commit(glyph)
    }

    /// **The one point at which round state becomes true.** The beat, the cue, the snapshot
    /// (E10·T02) and the VoiceOver announcement all hang off this call and off nothing else.
    private func commit(_ glyph: Glyph) -> Verdict? {
        let record = ribbon.probe(glyph, against: law)
        guard let next = RoundPhase.advance(phase, on: .verdict(record.verdict)) else {
            return nil
        }
        phase = next
        hasReachedCap = ribbon.count >= cap
        return record.verdict
    }

    /// Called when the adjudication beat's input lock expires — T06 owns the clock and calls
    /// this; nothing here measures time. Exposing the beat's *end* as a method is what lets the
    /// whole machine be tested with no `Task.sleep` (`06 T27`).
    public func endVerdictBeat() {
        guard case .adjudicating = phase else { return }
        guard let next = RoundPhase.advance(phase, on: hasReachedCap ? .capReached : .beatCompleted)
        else { return }
        phase = next
    }

    /// Leaving from the run frame. Below one probe this is not a transition at all: the round
    /// is discarded outright, with no record and no `Outcome` (§6.10), and `phase` is left
    /// where it was for the caller to dismiss.
    public func abandon() {
        guard let next = RoundPhase.advance(phase, on: .abandoned(probesUsed: probesUsed))
        else { return }
        phase = next
    }
}
