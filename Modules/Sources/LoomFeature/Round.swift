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

    /// The attribute the player most recently moved.
    ///
    /// Seeded to `.fill` — the canonical order's first (§2) — so the throat swipe is live on
    /// the very first frame. A gesture that does nothing until some *other* control has been
    /// used is a gesture nobody discovers, and this one is §6.3's cheapest path to a controlled
    /// variation.
    public private(set) var lastTouched: Glyph.Attribute = .fill

    /// The register that changed on the last edit, or `nil` if nothing moved.
    ///
    /// The throat crossfades exactly this pass and holds the other three (§6.3) — which is not
    /// polish: change-one-hold-three is *the* inductive move, and animating the whole glyph
    /// hides the act inside the result. `nil` after a clamped step, so a swipe that changed
    /// nothing animates nothing.
    public private(set) var changedRegister: Glyph.Attribute?

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

    /// Set the whole draft — the spool sheet's cell tap (T09) and the Dial's own preload.
    /// Refused outside an open-input phase, because the throat is the input.
    ///
    /// A single-register difference is reported as changed so the throat can crossfade that one
    /// register; anything wider reports `nil`, because a wholesale adoption is not a controlled
    /// variation and animating one register would be a lie about what happened.
    public func setDraft(_ glyph: Glyph) {
        guard phase.acceptsInput else { return }
        let differing = Glyph.Attribute.allCases.filter {
            glyph.ordinal(of: $0) != draft.ordinal(of: $0)
        }
        draft = glyph
        loadedIndex = nil
        changedRegister = differing.count == 1 ? differing[0] : nil
    }

    /// The ribbon tile the Dial is currently sourced from, for the ribbon's `loaded` state.
    /// Cleared by any edit, because after an edit the Dial is no longer showing that tile.
    public private(set) var loadedIndex: Int?

    /// Ribbon-load (§6.3, §4.1's mitigation 2): the Dial and the throat adopt that tile's glyph
    /// **wholesale**. Costs nothing, consumes no probe, and out of range is a no-op.
    ///
    /// Index 0 is the seed tile; probe *n* is index *n*. That numbering is the ribbon's, which
    /// draws the seed first with its dashed frame (§6.6 layer 1).
    public func load(ribbonIndex index: Int) {
        guard phase.acceptsInput else { return }
        let glyphs = [seedGlyph] + ribbon.probes.map(\.glyph)
        guard glyphs.indices.contains(index) else { return }
        draft = glyphs[index]
        loadedIndex = index
        // Nothing was *touched*, so the swipe's target must not move under the player; and a
        // wholesale adoption is not a controlled variation, so no single register may animate.
        // The throat crossfades the whole glyph on a load and only on a load.
        changedRegister = nil
    }

    /// One Dial cell tap: that ramp's selection moves and the throat redraws (§6.3).
    ///
    /// - Parameter rank: the **visible** rank, 1…4 — what the ramp shows and VoiceOver reads,
    ///   not the 0-based ordinal that `glyphID` is packed from.
    public func select(_ attribute: Glyph.Attribute, rank: Int) {
        guard phase.acceptsInput, (1...4).contains(rank) else { return }
        lastTouched = attribute
        loadedIndex = nil
        let moved = draft.rank(of: attribute) != rank
        draft = Round.glyph(draft, setting: attribute, toOrdinal: rank - 1)
        changedRegister = moved ? attribute : nil
    }

    /// A horizontal swipe on the throat: step the last-touched attribute by ±1 (§6.3).
    ///
    /// **Wrapping is off**, and that is a decision rather than an omission: §6.3 says so in
    /// three words, and a ramp that wrapped would send a swipe at rank 4 to rank 1, which reads
    /// as a different glyph arriving rather than as one attribute moving by one step.
    public func stepDraft(by delta: Int) {
        guard phase.acceptsInput else { return }
        select(lastTouched, rank: min(4, max(1, draft.rank(of: lastTouched) + delta)))
    }

    /// Called when the register crossfade is spent, so a later frame does not re-animate a
    /// change that has already been shown.
    public func clearChangedRegister() { changedRegister = nil }

    /// The one place a glyph is rebuilt with a single attribute replaced.
    static func glyph(_ base: Glyph, setting attribute: Glyph.Attribute, toOrdinal ordinal: Int)
        -> Glyph
    {
        let raw = UInt8(min(3, max(0, ordinal)))
        return Glyph(
            fill: attribute == .fill ? Glyph.Fill(rawValue: raw) ?? base.fill : base.fill,
            shape: attribute == .shape ? Glyph.Shape(rawValue: raw) ?? base.shape : base.shape,
            pips: attribute == .pips ? Glyph.Pips(rawValue: raw) ?? base.pips : base.pips,
            hue: attribute == .hue ? Glyph.Hue(rawValue: raw) ?? base.hue : base.hue)
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
