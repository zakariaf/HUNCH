public import Foundation

public import Glyphs
public import Laws

/// §11.1: **one law, one page, forever** — identified by its extension, because §3.6 makes the
/// extension the canonical form and the AST merely one spelling of it.
///
/// The page stores the **AST and not the table**: a contextual table is 8 KiB and an AST is
/// ~40 B, and the table is rebuilt on open in about 2 µs. That is what keeps a Codex of
/// thousands of pages small enough to load in one read.
public struct CodexPage: Codable, Hashable, Sendable {

    /// §3.6's dedup key: a 64-bit hash of the extension. Identity, and the only identity.
    public let lawKey: UInt64
    /// RNF AST. Rebuilt into a table on open, never stored as one.
    public let law: LawNode
    public let band: Band
    /// Index into the family's skeleton list. A **page** field rather than a round field,
    /// because §11.2 browses by it and recomputing it from the AST on every shelf open is two
    /// thousand tree walks per scroll.
    public let skeleton: UInt16

    public var firstFoundAt: Date
    public var lastFoundAt: Date
    public let firstFoundMode: Mode
    /// Bitset over `Mode`.
    public var modesSeen: UInt8
    /// Rendered as re-strike rings, capped at 5+.
    public var timesFound: UInt16
    /// Minimum over all finds.
    public var bestProbes: UInt16
    /// 1…3.
    public var bestMarks: UInt8
    /// Ever declared correct on the first declaration, zero strikes.
    public var unfractured: Bool
    /// Latches true on an ECHO 3-mark round held on this law (§11.3).
    public var burnished: Bool

    /// **Payload, never identity.** A DRIFT page is keyed on `L₂` and carries `L₁`; folding the
    /// partner into `lawKey` would mint two pages for one law found behind two different dead
    /// laws and break §11.2's premise. Written on the **first** DRIFT find and never
    /// overwritten, so the reveal a page replays is stable forever.
    public var driftPartner: LawNode?
    public var driftHinge: UInt16?

    /// UTC day index, if ever found as the Anomaly.
    public var anomalyDay: Int64?

    public init(
        lawKey: UInt64, law: LawNode, band: Band, skeleton: UInt16, firstFoundAt: Date,
        lastFoundAt: Date, firstFoundMode: Mode, modesSeen: UInt8, timesFound: UInt16,
        bestProbes: UInt16, bestMarks: UInt8, unfractured: Bool, burnished: Bool,
        driftPartner: LawNode? = nil, driftHinge: UInt16? = nil, anomalyDay: Int64? = nil
    ) {
        self.lawKey = lawKey
        self.law = law
        self.band = band
        self.skeleton = skeleton
        self.firstFoundAt = firstFoundAt
        self.lastFoundAt = lastFoundAt
        self.firstFoundMode = firstFoundMode
        self.modesSeen = modesSeen
        self.timesFound = timesFound
        self.bestProbes = bestProbes
        self.bestMarks = bestMarks
        self.unfractured = unfractured
        self.burnished = burnished
        self.driftPartner = driftPartner
        self.driftHinge = driftHinge
        self.anomalyDay = anomalyDay
    }
}

extension CodexPage {
    /// What one won round contributes to a page. Everything here is a *round* fact; the page
    /// decides what to keep.
    public struct Find: Equatable, Sendable {
        public var law: Law
        public var band: Band
        public var skeleton: UInt16
        public var mode: Mode
        public var at: Date
        public var probes: UInt16
        public var marks: UInt8
        public var fractured: Bool
        public var anomalyDay: Int64?
        public var driftPartner: LawNode?
        public var driftHinge: UInt16?

        public init(
            law: Law, band: Band, skeleton: UInt16, mode: Mode, at: Date, probes: UInt16,
            marks: UInt8, fractured: Bool, anomalyDay: Int64? = nil,
            driftPartner: LawNode? = nil, driftHinge: UInt16? = nil
        ) {
            self.law = law
            self.band = band
            self.skeleton = skeleton
            self.mode = mode
            self.at = at
            self.probes = probes
            self.marks = marks
            self.fractured = fractured
            self.anomalyDay = anomalyDay
            self.driftPartner = driftPartner
            self.driftHinge = driftHinge
        }
    }

    /// Mint a page from a first find.
    public static func mint(_ find: Find) -> CodexPage {
        CodexPage(
            lawKey: find.law.key.rawValue, law: find.law.node, band: find.band,
            skeleton: find.skeleton, firstFoundAt: find.at, lastFoundAt: find.at,
            firstFoundMode: find.mode, modesSeen: 1 << find.mode.rawValue, timesFound: 1,
            bestProbes: find.probes, bestMarks: find.marks, unfractured: !find.fractured,
            burnished: false, driftPartner: find.driftPartner, driftHinge: find.driftHinge,
            anomalyDay: find.anomalyDay)
    }

    /// Re-inscribe an existing page.
    ///
    /// **Every field improves or holds; nothing regresses.** A worse round never makes a page
    /// worse, because the page is a record of what the player has *ever* done and an archive
    /// that could degrade would punish practice.
    public func reinscribed(with find: Find) -> CodexPage {
        var page = self
        page.lastFoundAt = find.at
        page.modesSeen |= 1 << find.mode.rawValue
        page.timesFound = timesFound &+ 1
        page.bestProbes = min(bestProbes, find.probes)
        page.bestMarks = max(bestMarks, find.marks)
        // §11.1's decision: re-finding a fractured page **clean heals the fracture**. Every
        // other field improves; a permanent scar for one bad first encounter contradicts the
        // improvement loop and makes early rounds feel like they damage the archive.
        page.unfractured = unfractured || !find.fractured
        page.anomalyDay = anomalyDay ?? find.anomalyDay
        // Written on the FIRST DRIFT find and never overwritten, so the reveal a page replays
        // is stable forever — the same rule that governs `firstFoundMode`.
        if page.driftPartner == nil {
            page.driftPartner = find.driftPartner
            page.driftHinge = find.driftHinge
        }
        return page
    }

    public func hasSeen(_ mode: Mode) -> Bool { modesSeen & (1 << mode.rawValue) != 0 }

    /// Re-strike rings, capped at 5+.
    public var restrikeRings: Int { min(Int(timesFound), 5) }
}
