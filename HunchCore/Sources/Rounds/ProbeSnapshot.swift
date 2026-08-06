public import Foundation
public import Glyphs
public import Laws

/// §6.10's mid-round snapshot — schema v1.
///
/// **The law is stored, not regenerated**, and the reason is not paranoia. `avoid` is
/// serving-layer state and it moves while a round is suspended: suspend a PROBE round, play a
/// SIEVE run that inscribes a page, resume, and regeneration from the same
/// `(seed, band, targetδ, mode)` can legitimately resolve to a *different* law — destroying the
/// round by its own consistency check.
///
/// Verdicts are still recomputed rather than stored: the payload is ≈160 bytes plus the draft,
/// tampering with the probe list achieves nothing because the law re-derives every verdict, and
/// every resume becomes a live evaluator check over the whole transcript.
public struct ProbeSnapshot: Codable, Hashable, Sendable {
    public var schema: Int
    /// The RESOLVED law, in RNF. ~40 B.
    public var law: LawNode
    /// An extension hash — a corruption check, **never** the source of truth. With the law
    /// stored, the only realistic cause of a mismatch is on-disk corruption.
    public var lawHash: UInt64
    /// Round metadata: δ for the θ update, band for par/cap, seed for the round card. **Not a
    /// law recipe.**
    public var seed: UInt64
    public var band: Band
    public var targetDelta: Double
    public var mode: Mode
    public var seedGlyph: UInt8
    /// Glyph ids only; verdicts are RECOMPUTED from `law`.
    public var probes: [UInt8]
    public var strikes: Int
    public var counterexample: CounterexampleRef?
    public var startedAt: Date
    public var elapsedActive: TimeInterval

    /// A tuple cannot conform to `Codable` and cannot be extended, so synthesis would simply
    /// fail to compile.
    public struct CounterexampleRef: Codable, Hashable, Sendable {
        public var current: UInt8
        /// `nil` in stateless bands.
        public var previous: UInt8?

        public init(current: UInt8, previous: UInt8?) {
            self.current = current
            self.previous = previous
        }
    }

    public init(
        schema: Int = 1, law: LawNode, seed: UInt64, band: Band, targetDelta: Double,
        mode: Mode, seedGlyph: UInt8, probes: [UInt8] = [], strikes: Int = 0,
        counterexample: CounterexampleRef? = nil, startedAt: Date, elapsedActive: TimeInterval = 0
    ) {
        self.schema = schema
        self.law = law
        lawHash = Law(law).key.rawValue
        self.seed = seed
        self.band = band
        self.targetDelta = targetDelta
        self.mode = mode
        self.seedGlyph = seedGlyph
        self.probes = probes
        self.strikes = strikes
        self.counterexample = counterexample
        self.startedAt = startedAt
        self.elapsedActive = elapsedActive
    }

    /// The integrity check a resume runs. A mismatch voids the round — never silently alters
    /// it (§6.11 edge case 23).
    public var passesIntegrityCheck: Bool { Law(law).key.rawValue == lawHash }

    /// Rehydrates the ribbon by re-deriving every verdict from the stored law.
    public func rehydrateRibbon() -> Ribbon {
        Ribbon.rehydrate(
            seedGlyph: Deck.glyph(id: Int(seedGlyph)), glyphIDs: probes, law: Law(law))
    }

    /// §6.11 edge case 29: a snapshot whose probe count already equals `cap` is unreachable by
    /// construction — the cap-th verdict transitions straight to `revealing(.exhausted)` and
    /// the slot is cleared at round end. One at `cap` is therefore corruption.
    public var isStructurallyValid: Bool { probes.count < band.cap }
}
