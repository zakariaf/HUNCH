public import Bench
public import Feedback
public import Glyphs
public import Laws
public import Rounds

// Public because @Observable synthesises a public conformance to Observation.Observable, which
// an internal import cannot carry (07 B7a's price, paid rather than worked around).
public import Observation

public import LawGeneration

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

    /// §4.5's counterexample — one glyph, never the law. Set when the first strike lands.
    public private(set) var counterexample: Counterexample.Choice?

    /// Computed when the Seal is pressed and revealed 640 ms later. Held rather than recomputed
    /// so the hold cannot become verdict-dependent by accident.
    private var pendingSeal: SealResult?

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

    /// §6.5's input policy and its single slot. The gate is the authority on whether a tap is
    /// accepted; the phase follows it, never the other way round.
    public private(set) var beat: VerdictBeat
    private var gate = InputGate()
    private var beatTask: Task<Void, Never>?

    /// True from the end of the 260 ms hold to the unlock: the verdict has *landed* and its
    /// ring is resolving. Not a phase — leaving `adjudicating` early would reopen input at
    /// t = 260 and let the player outrun the beat.
    public private(set) var hasLandedVerdict = false

    /// What plays. Injected, never constructed here and never a singleton: E10·T01's
    /// `AppDependencies` hands over the composite, and every test gets silence by default.
    private let cues: any CuePlayer

    /// Set by the cap-th commit and read by `endVerdictBeat()`. §6.11 case 4 delivers that
    /// verdict in full and only *then* ends the round, so exhaustion cannot be part of the
    /// commit — a phase change there would swallow the last bit the player paid for.
    private var hasReachedCap = false

    /// Latched forever on the first twin press. The breath stops on first *use*, not on first
    /// success — its job is to teach that the key exists, and it has done that either way.
    private var twinEverUsed = false

    public init(
        law: Law,
        band: Band,
        mode: Mode,
        seedGlyph: Glyph,
        seed: UInt64,
        targetDelta: Double,
        beat: VerdictBeat = VerdictBeat(reduceMotion: false),
        cues: any CuePlayer = SilentCuePlayer()
    ) {
        self.beat = beat
        self.cues = cues
        self.law = law
        self.band = band
        self.mode = mode
        self.seedGlyph = seedGlyph
        self.seed = seed
        self.targetDelta = targetDelta
        ribbon = Ribbon(seedGlyph: seedGlyph)
        draft = seedGlyph
        assayPin = seedGlyph
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
    /// - Returns: the verdict, or `nil` when the tap was queued or dropped rather than fired.
    @discardableResult
    public func probe(_ glyph: Glyph) -> Verdict? {
        guard outcome == nil, probesUsed < cap else { return nil }
        switch gate.request(.probe(glyph)) {
        case .fires: return beginBeat(.probe(glyph), queued: false)
        case .queued, .dropped: return nil  // §6.11 case 10 — silently, with no feedback
        }
    }

    /// The twin key: re-feed the glyph currently in the throat, unchanged (§6.3).
    ///
    /// Never blocked and never refunded, and there is no cooldown and no cap exemption — under
    /// previously-probed semantics the twin is the experiment that detects statefulness *at
    /// all* (same glyph, different verdict), so a repeat guard here would be a bug rather than
    /// a courtesy. It costs one probe like anything else.
    ///
    /// Whether the ribbon *marks* a twin pair is decided by adjacency inside `Ribbon.probe`,
    /// never by which key was pressed: at probe 0 there is no previous probe to be a twin of,
    /// so a twin-of-seed is an ordinary first probe. See `DECISIONS.md` 52.
    @discardableResult
    public func probeTwin() -> Verdict? {
        // Latched on the PRESS, not on the verdict: a player who presses twin and immediately
        // backgrounds the app must not get the breath back on resume.
        twinEverUsed = true
        guard outcome == nil, probesUsed < cap else { return nil }
        switch gate.request(.twin) {
        case .fires: return beginBeat(.twin, queued: false)
        case .queued, .dropped: return nil
        }
    }

    /// The twin key is live in every band from probe 0 and stays live until the round ends.
    public var isTwinAvailable: Bool { outcome == nil && probesUsed < cap }

    /// §6.6 layer 3's breath: past the point where three marks are still reachable, the twin
    /// key breathes — a 1.2 s hairline pulse every 8 s, no arrow, no badge, no text.
    ///
    /// **The same rule in every band**, which is what stops it leaking contextuality: at bands
    /// 1–4 following it costs one mildly wasted probe, and that waste *is* the lesson.
    public var isBreathing: Bool {
        Round.breathes(probesUsed: probesUsed, par: par, twinEverUsed: twinEverUsed)
    }

    /// A predicate, not a timer — so it cannot drift with the frame rate and needs no clock to
    /// test. The 0.6 is §6.9's three-mark threshold and is `Scoring`'s, not this file's.
    public static func breathes(probesUsed: Int, par: Int, twinEverUsed: Bool) -> Bool {
        !twinEverUsed && Double(probesUsed) > Scoring.threeMarkFraction * Double(par)
    }

    /// t = 0 of the beat sheet: commit, announce, and start the clock.
    @discardableResult
    private func beginBeat(_ action: InputGate.Action, queued: Bool) -> Verdict? {
        if case .probe(let glyph) = action { draft = glyph }
        guard let verdict = commit(draft) else { return nil }
        hasLandedVerdict = false
        cues.play(.probeSubmit)

        // Inherits `@MainActor` from `Round`: no `Task.detached`, no `nonisolated(unsafe)`, no
        // `assumeIsolated`. The repository's escape-hatch budget is exactly one and it is
        // spent in E20. Cancelled and replaced on every beat, so a queued probe cannot end up
        // with two timers running against one round.
        beatTask?.cancel()
        beatTask = Task { [beat] in
            try? await Task.sleep(for: beat.adjudicationHold)
            guard !Task.isCancelled else { return }
            landVerdict()
            try? await Task.sleep(for: beat.travel(queued: queued))
            guard !Task.isCancelled else { return }
            endVerdictBeat()
        }
        return verdict
    }

    /// t = 260: the verdict lands. The ring opens or closes, the cue and the haptic fire on the
    /// same frame, and VoiceOver speaks.
    ///
    /// **It does not change `phase`.** Input stays locked until `endVerdictBeat()`, which is
    /// what stops a player outrunning the hold — and what lets every suite written before this
    /// task keep passing unchanged. Idempotent, because §6.11 case 5 can background the app
    /// mid-beat and leave the task unfinished.
    public func landVerdict() {
        guard case .adjudicating(let verdict) = phase, !hasLandedVerdict else { return }
        hasLandedVerdict = true
        cues.play(.verdict(verdict, isTwin: ribbon.probes.last?.isTwin ?? false))
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
        hasLandedVerdict = false
        guard outcome == nil else {
            // The round ended on this verdict. A tap made before it landed must not be honoured
            // into a probe past the cap.
            gate.close()
            return
        }
        if let queued = gate.unlock() { beginBeat(queued, queued: true) }
    }

    /// The law the player is building on the Bench, or `nil` while the rails are empty.
    ///
    /// **Never `law`.** The Assay draws *this*, and drawing the hidden law there would hand the
    /// answer over in one picture — which is why the Assay's input is a separate property with a
    /// separate name rather than an argument some call site could get the wrong way round.
    public private(set) var benchDraft: Law?

    public func setBenchDraft(_ draft: Law?) {
        guard phase.acceptsInput else { return }
        benchDraft = draft
    }

    /// What the Assay shows: the draft's extension conditioned on the pinned `prev`, or an
    /// all-dark grid when the rails are empty — which is not a placeholder but the truth, since
    /// an empty Bench admits nothing and the Seal is barred for exactly that.
    public var assay: Assay {
        guard let benchDraft else { return Assay(lit: .empty, pinned: assayPin) }
        return Assay.live(for: benchDraft, pinned: assayPin)
    }

    /// §4.3's evidence overlay, gated at band 4 — a free consistency check trivialises the low
    /// bands, where the reasoning *is* the game.
    public var assayEvidence: AssayEvidence {
        guard let benchDraft,
            AssayEvidence.isUnlocked(band: band)
        else { return .none }
        var transcript: [(glyph: Glyph, previous: Glyph, verdict: Verdict)] = []
        var previous = seedGlyph
        for record in ribbon.probes {
            transcript.append((glyph: record.glyph, previous: previous, verdict: record.verdict))
            previous = record.glyph
        }
        return AssayEvidence.overlay(
            draft: benchDraft, pinned: assayPin, transcript: transcript)
    }

    /// §4.3: the pin **defaults to the seed glyph** and is scrubbable to any of the 256, so the
    /// first slice a player sees is the one their next probe will actually be judged against.
    public private(set) var assayPin: Glyph

    public func pinAssay(to glyph: Glyph) {
        guard phase.acceptsInput else { return }
        assayPin = glyph
    }

    /// §6.2's spool sheet, and the three-tap cycle that drives it. Not a filter and not a mode
    /// switch: the sort re-orders the same cells.
    public enum SheetState: Hashable, Sendable {
        case closed
        case chainOrder
        case verdictSorted
    }

    public private(set) var sheet: SheetState = .closed

    /// One tap on the spool — the 24 pt rail-cap at the ribbon's leading edge. It costs
    /// nothing, consumes no probe and is available from probe 0.
    public func toggleSpool() {
        sheet =
            switch sheet {
            case .closed: .chainOrder
            case .chainOrder: .verdictSorted
            case .verdictSorted: .closed
            }
    }

    public func closeSpool() { sheet = .closed }

    /// The Bench handle or the Bench key: raise the Bench and lower the Dial (§6.1). The
    /// declaration itself, the Seal and the counterexample are E09's; this is the one
    /// transition the commit bar needs to have a third key at all.
    public func openBench() {
        guard let next = RoundPhase.advance(phase, on: .benchOpened) else { return }
        phase = next
    }

    /// The Dial key from the Bench. §6.7: the draft survives verbatim — a player probes
    /// specifically to test a specific draft, so discarding it would make the trip pointless.
    public func closeBench() {
        guard let next = RoundPhase.advance(phase, on: .benchDismissed) else { return }
        phase = next
    }

    /// A sheet cell tap: ribbon-load that cell's glyph and dismiss.
    ///
    /// Under verdict sort the cell index is **not** the chain index, and that mapping is the one
    /// bug in this component worth a test of its own — a sorted sheet that loaded by cell index
    /// would silently load a different probe than the one the player touched.
    public func loadFromSheet(cellIndex: Int, chainIndex: (Int) -> Int?) {
        guard let index = chainIndex(cellIndex) else { return }
        load(ribbonIndex: index)
        closeSpool()
    }

    // ── Declaring (§4.5, §6.8) ───────────────────────────────────────────────────────────

    /// Why the Seal is barred right now, or `nil` when the draft may be declared.
    ///
    /// The rail states come from the Bench's own editing model (E09·T02's tiles); until a rail
    /// exists the draft is either absent — barred as empty — or a whole law, which is one ready
    /// rail. Both are honest and neither invents a rail the player cannot see.
    public var sealBarReason: SealBar.Reason? {
        SealBar.reason(
            rails: benchDraft == nil ? [] : [.ready], extension: benchDraft?.table)
    }

    public var isSealBarred: Bool { sealBarReason != nil }

    /// Press the Seal.
    ///
    /// Barred is **not** an error: no text, no state, no modal. The offending rail pulses and
    /// the round does not move — which is why this returns the reason rather than throwing, and
    /// why the caller's only job with it is to choose a rail to pulse.
    ///
    /// The Seal is edge-triggered and never queues (§6.11 case 11): a queued second declaration
    /// would spend the round's second strike on a press made before the first one resolved.
    @discardableResult
    public func seal() -> SealBar.Reason? {
        guard phase == .declaring || phase == .probing else { return .empty }
        if let reason = sealBarReason { return reason }
        guard gateAcceptsSeal(), let declared = benchDraft else { return .empty }

        // §4.5, and the whole of the judgement: **extension equality in the common space.**
        // Tile arrangement, spelling, coupler choice and complement direction are irrelevant;
        // rejecting an equivalent phrasing would punish the player for the grammar rather than
        // for the induction.
        pendingSeal =
            if declared.isSameLaw(as: law) {
                .correct(
                    marks: Scoring.marks(probesUsed: probesUsed, par: par, cap: cap),
                    fracture: strikes > 0)
            } else {
                strikes == 0 ? .wrongFirstStrike : .wrongSecondStrike
            }
        if phase == .probing, let next = RoundPhase.advance(phase, on: .benchOpened) {
            phase = next
        }
        guard let next = RoundPhase.advance(phase, on: .sealPressed) else { return .empty }
        phase = next
        cues.play(.declare)
        return nil
    }

    /// The 640 ms hold expires. **Verdict-blind**: the hold is identical in content and duration
    /// whether the declaration was right or wrong, so the answer is not readable off the clock.
    public func resolveSeal() {
        guard case .sealing = phase, let result = pendingSeal else { return }
        pendingSeal = nil
        switch result {
        case .correct:
            cues.play(.lawDeclaredCorrectly(marks: marks))
        case .wrongFirstStrike:
            strikes = 1
            counterexample = Counterexample.select(
                declared: benchDraft ?? law, hidden: law,
                ribbon: ribbon.probes.map(\.glyph), seedGlyph: seedGlyph)
            cues.play(.strike)
        case .wrongSecondStrike:
            strikes = 2
            cues.play(.lawBroken)
        }
        guard let next = RoundPhase.advance(phase, on: .sealResolved(result)) else { return }
        phase = next
    }

    /// §6.8's decision: **the counterexample is not a probe.** It does not increment
    /// `probesUsed`, it does not become `prev`, and it draws below the chain with no link arc
    /// into it — a player's carefully arranged context should not be destroyed by their own
    /// failure, which has nothing to do with the law.
    public var previousGlyphIsUnaffectedByCounterexample: Bool { true }

    /// §6.1: the counterexample beat completes and the round **continues** — strikes stand at 1,
    /// the Bench collapses, and the draft is preserved. A counterexample you cannot act on is
    /// pedagogically worthless, which is the whole argument for two strikes over one.
    public func dismissCounterexample() {
        guard let next = RoundPhase.advance(phase, on: .beatCompleted) else { return }
        phase = next
    }

    /// The reveal beat completes, or is skipped.
    public func endReveal() {
        guard let next = RoundPhase.advance(phase, on: .beatCompleted) else { return }
        phase = next
    }

    /// A third declaration is structurally impossible: the second strike settles the round, and
    /// `settled` is terminal in §6.1's table.
    public var canDeclare: Bool { strikes < 2 && outcome == nil }

    private func gateAcceptsSeal() -> Bool { gate.requestSeal() == .fires }

    /// Leaving from the run frame. Below one probe this is not a transition at all: the round
    /// is discarded outright, with no record and no `Outcome` (§6.10), and `phase` is left
    /// where it was for the caller to dismiss.
    public func abandon() {
        guard let next = RoundPhase.advance(phase, on: .abandoned(probesUsed: probesUsed))
        else { return }
        phase = next
    }
}
