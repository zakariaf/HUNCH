public import Glyphs
public import Laws

/// §6.5's **input** policy, as a value.
///
/// Not `Dur.*` tokens: these are input durations, not animation durations, and the two are
/// different clocks that happen to overlap. §13.7.2 calls the micro-responses "never blocking",
/// which is true of the *rings* — the admit ring finishes at 520 ms, a hundred milliseconds
/// after input unlocks — and false of the beat. Read its timings as offsets into §6.5's
/// 260–520 ms window, never as an input policy. Most bugs in this area are a clock confusion.
public nonisolated struct VerdictBeat: Equatable, Sendable {
    public let reduceMotion: Bool

    public init(reduceMotion: Bool) { self.reduceMotion = reduceMotion }

    /// 420 ms, 320 under Reduce Motion. Caps the probe rate at ~2.4/s.
    ///
    /// Shortened and not removed: the throat must return to a stable draft state before it can
    /// be re-fed, and a 260 ms hold the player can outrun is not a hold.
    public var inputLock: Duration {
        reduceMotion ? .milliseconds(320) : .milliseconds(420)
    }

    /// **260 ms in both motion modes**, and constant regardless of verdict, band or
    /// contextuality. Variable latency is a side channel: a Loom that thought visibly harder
    /// about hard glyphs would leak the family before probe 3. There is nothing to optimise
    /// either way — the real evaluation cost is 5 ns to 0.4 µs.
    public var adjudicationHold: Duration { .milliseconds(260) }

    /// What is left of the lock after the hold — the tile budding off the throat, travelling to
    /// the ribbon and the link arc drawing. Compressed to 180 ms for a queued probe, which is
    /// how §6.5 pays for the tap it honoured at the unlock.
    public func travel(queued: Bool) -> Duration {
        queued ? .milliseconds(180) : inputLock - adjudicationHold
    }

    /// Deliberately ignores both arguments.
    ///
    /// It exists so that an "optimisation" making the hold depend on the verdict or the band
    /// has to delete a test to land. The overload is the guard rail; the constant is the rule.
    public func adjudicationHold(for verdict: Verdict, band: Band) -> Duration {
        adjudicationHold
    }
}
