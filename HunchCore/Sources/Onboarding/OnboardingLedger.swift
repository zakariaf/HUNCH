public import Glyphs

/// §12.5's eight declaration lines — nine stored properties, because `sawAdmit` and `sawReject`
/// share a line.
///
/// The opening round is **measured**, not judged: success is a five-way conjunction over what
/// the player actually did, and the three fields outside it are diagnostics rather than gates.
public struct OnboardingLedger: Codable, Equatable, Sendable {
    public var selfConstructedProbes = 0
    /// A **run**, not a total: it resets on any variation, because nudge 5 fires every two
    /// unvaried probes and a total would fire it forever after the second one.
    public var unvariedRun = 0
    public var sawAdmit = false
    public var sawReject = false
    /// Recorded and **not required**. A player who declares correctly must have opened the
    /// Bench, so requiring it adds nothing — but nudge 2 keys off it, so it has to exist.
    public var openedBench = false
    public var boundAnAttribute = false
    public var clearedTheSealBar = false
    public var declaredCorrectly = false
    public var nudgesFired = 0

    public init() {}

    /// §12.5, verbatim. Five conjuncts; `openedBench`, `clearedTheSealBar` and `nudgesFired` are
    /// §14.6 risk 2's diagnostics and are deliberately not success conditions.
    public var isComplete: Bool {
        declaredCorrectly && selfConstructedProbes >= 1 && sawAdmit && sawReject
            && boundAnAttribute
    }

    public mutating func record(verdict: Verdict) {
        switch verdict {
        case .admit: sawAdmit = true
        case .reject: sawReject = true
        }
    }

    /// - Parameter variedFromPrevious: whether this probe changed an attribute from the last one.
    public mutating func recordProbe(selfConstructed: Bool, variedFromPrevious: Bool) {
        if selfConstructed { selfConstructedProbes += 1 }
        unvariedRun = variedFromPrevious ? 0 : unvariedRun + 1
    }
}

/// §12.5's elastic cap: while the player has never seen a reject, the cap cannot end the round.
///
/// The passive path is the failure this closes — a player who probes admits forever, never
/// learns that the Loom says no, and loses at the cap to a rule they were never shown.
public struct ElasticCap: Equatable, Sendable {
    /// The suspension itself ends here. Elastic is not infinite: a player who has taken 24
    /// probes without a single reject is not being taught by more probes.
    public static let hardStop = 24

    public let base: Int
    public private(set) var limit: Int
    public private(set) var isSuspended: Bool

    /// - Parameter base: `Band.literal.cap`. **Read, never written as 12.** §12.5 writes the
    ///   re-arm as `max(12, probesUsed + 3)` and 12 *is* the band's cap; reading it is the
    ///   difference between a rule and a coincidence that survives until the cap table moves.
    public init(base: Int, isOpeningRound: Bool) {
        self.base = base
        limit = base
        isSuspended = isOpeningRound
    }

    public mutating func record(verdict: Verdict, probesUsed: Int) {
        guard isSuspended, verdict == .reject else { return }
        limit = max(base, probesUsed + 3)
        isSuspended = false
    }

    public func endsRound(atProbe probe: Int) -> Bool {
        probe >= (isSuspended ? Self.hardStop : limit)
    }
}
