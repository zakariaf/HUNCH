import Foundation
import Testing

import Archive
import Glyphs
import HunchTestSupport
import Laws

/// §11.6. One law per UTC day, identical for every player on Earth, with zero server — so every
/// test here is really the same test: *two devices must agree.*
@Suite("The Anomaly's derivation", .tags(.unit, .presubmission))
struct AnomalyDerivationTests {

    /// Floor semantics across the epoch, including before it. `Calendar` would give two players
    /// different answers; integer division does not.
    @Test("The day index is floor division and is total across the epoch")
    func dayIndexIsTotal() {
        #expect(Anomaly.utcDayIndex(0) == 0)
        #expect(Anomaly.utcDayIndex(86_399) == 0)
        #expect(Anomaly.utcDayIndex(86_400) == 1)
        #expect(Anomaly.utcDayIndex(-1) == -1)
        #expect(Anomaly.utcDayIndex(-86_400) == -1)
        #expect(Anomaly.utcDayIndex(-86_401) == -2)
        // Monotone everywhere: a later instant is never an earlier day.
        var previous = Anomaly.utcDayIndex(-200_000)
        for time in stride(from: -200_000.0, through: 200_000.0, by: 3_600) {
            let day = Anomaly.utcDayIndex(time)
            #expect(day >= previous)
            previous = day
        }
    }

    /// The salt is frozen forever: changing it changes every Anomaly that has ever existed.
    @Test("The salt is HUNCHANO and the seed is a pure function of the day")
    func theSeedIsPure() {
        #expect(Anomaly.salt == 0x4855_4E43_4841_4E4F)
        for day in Int64(19_000)...19_010 {
            #expect(Anomaly.seed(day: day) == Anomaly.seed(day: day))
        }
        #expect(Anomaly.seed(day: 19_000) != Anomaly.seed(day: 19_001))
    }

    /// §5.7's off-ladder rule: bands 4–7, uniformly. Band 4 is drawn as often as any other,
    /// which is why §11.7 refuses to quote a single par.
    @Test("The band is 4…7 and every one of the four is reachable")
    func bandRange() {
        var seen: Set<Int> = []
        for day in Int64(0)..<2_000 {
            let band = Anomaly.parameters(day: day).band
            #expect((4...7).contains(band.rawValue))
            seen.insert(band.rawValue)
        }
        #expect(seen == [4, 5, 6, 7])
    }

    /// The low bits are used **deliberately**: the finaliser's last step has already avalanched
    /// them. `(seed >> 32) % 4` selects a different band from the same day and is therefore
    /// wrong, not merely different — this test is what makes that a fact rather than a note.
    @Test("The band reads the low bits, and the high-bit spelling disagrees")
    func theLowBitsAreLoadBearing() {
        var disagreements = 0
        for day in Int64(0)..<500 {
            let seed = Anomaly.seed(day: day)
            let low = 4 + Int(seed % 4)
            let high = 4 + Int((seed >> 32) % 4)
            #expect(Anomaly.parameters(day: day).band.rawValue == low)
            if low != high { disagreements += 1 }
        }
        #expect(disagreements > 300)  // the two spellings are not interchangeable
    }

    /// The jitter is ±0.050 around the band's centre, so the Anomaly is a *typical* law of its
    /// band rather than an edge case somebody could feel was unfair.
    @Test("targetδ sits inside its band, near the centre")
    func targetIsNearTheCentre() {
        for day in Int64(0)..<1_000 {
            let parameters = Anomaly.parameters(day: day)
            let lower = 0.125 * Double(parameters.band.rawValue - 1)
            let centre = lower + 0.0625
            #expect(parameters.targetDelta >= lower)
            #expect(parameters.targetDelta < lower + 0.125)
            #expect(abs(parameters.targetDelta - centre) <= 0.0501)
        }
    }

    /// PROBE is the only mode where "how few probes" means the same thing to everyone.
    @Test("The Anomaly is always PROBE and never touches the ladder")
    func modeAndIsolation() {
        #expect(Anomaly.mode == .probe)
        #expect(Anomaly.updatesAbility == false)
        #expect(Anomaly.profileWeight == 0.5)
        #expect(Anomaly.attemptsPerDay == 1)
    }

    /// The claim that matters most and the one no unit test can fully make: two devices with the
    /// same UTC date derive the identical law. What *can* be asserted is that every input is a
    /// pure function of the day index — so if the two devices agree on the date, they agree on
    /// everything downstream.
    @Test("Every parameter is a pure function of the day index")
    func twoDevicesAgree() {
        for day in [Int64(0), 1, 19_723, -5, 500_000] {
            let first = Anomaly.parameters(day: day)
            let second = Anomaly.parameters(day: day)
            #expect(first == second)
        }
        // …and two instants inside the same UTC day derive the same parameters. Midnight and
        // midday of day 19,675 — the boundary is what the day index exists to place, so the
        // sample is anchored to it rather than to a round-looking timestamp.
        let midnight = 19_675.0 * 86_400
        let morning = Anomaly.utcDayIndex(midnight)
        let evening = Anomaly.utcDayIndex(midnight + 43_200)
        #expect(morning == evening)
        #expect(Anomaly.parameters(day: morning) == Anomaly.parameters(day: evening))
    }
}

/// §11.7's high-water rule — the entire anti-cheat, and honest about its limits.
@Suite("The Anomaly ledger", .tags(.unit, .presubmission))
struct AnomalyLedgerTests {

    /// It cannot stop a clock change. What it does is make one worthless: a day already passed
    /// cannot be revisited, so setting the clock back finds nothing to play.
    @Test("A clock set backward finds nothing to play")
    func theHighWaterHolds() {
        var ledger = AnomalyLedger()
        ledger.observe(day: 19_000)
        #expect(ledger.isAvailable(day: 19_000))
        #expect(ledger.isAvailable(day: 18_999) == false)

        ledger.observe(day: 18_500)
        #expect(ledger.highWaterDay == 19_000)  // never decreases
    }

    @Test("One attempt per day, and a claim is permanent")
    func oneAttempt() {
        var ledger = AnomalyLedger()
        ledger.claim(day: 19_000)
        #expect(ledger.isAvailable(day: 19_000) == false)
        #expect(ledger.isAvailable(day: 19_001))
    }

    /// The streak is the one thing in the game a reset cannot launder, which is what makes it
    /// mean anything at all.
    @Test("The ledger survives every reset")
    func resetsDoNotTouchIt() {
        #expect(AnomalyLedger.survivesEveryReset)
    }

    @Test("The ledger round-trips through Codable")
    func codable() throws {
        var ledger = AnomalyLedger()
        ledger.claim(day: 19_000)
        ledger.claim(day: 19_002)
        let data = try JSONEncoder().encode(ledger)
        #expect(try JSONDecoder().decode(AnomalyLedger.self, from: data) == ledger)
    }
}
