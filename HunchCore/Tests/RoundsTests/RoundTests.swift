import Foundation
import Testing

import Glyphs
import HunchTestSupport
import LawGeneration
import Laws
import Rounds

/// §6.10's snapshot is what makes "quit mid-round, relaunch, resume at the exact probe" true.
/// The load-bearing decision is that the LAW is stored and the VERDICTS are not.
@Suite("Round state and the snapshot", .tags(.unit, .presubmission))
struct RoundTests {
    static func g(_ f: Glyph.Fill, _ s: Glyph.Shape, _ p: Glyph.Pips, _ h: Glyph.Hue) -> Glyph {
        Glyph(fill: f, shape: s, pips: p, hue: h)
    }
    static let seed = g(.hollow, .triangle, .two, .teal)
    static let contextualLaw = Law(
        .contextual(.init(current: .pips, comparator: .gt, previous: .pips)))

    /// An abandon is an interruption signal, not a failure signal — scoring it as a loss would
    /// let a player farm the adaptive engine downward by quitting hard rounds (§6.10, §10.1).
    @Test("Only a second strike or the cap is a LOSS; an abandon is neither")
    func outcomeClassification() {
        #expect(Outcome.broken.isLoss)
        #expect(Outcome.exhausted.isLoss)
        #expect(!Outcome.abandoned.isLoss)
        #expect(!Outcome.voided.isLoss)
        #expect(!Outcome.inscribed(marks: 3, fracture: false).isLoss)

        // …and neither an abandon nor a void touches the ability estimate at all.
        #expect(!Outcome.abandoned.updatesAbility)
        #expect(!Outcome.voided.updatesAbility)
        #expect(Outcome.broken.updatesAbility)
    }

    /// §3.5 again, at the ribbon level: `prev` advances on every probe.
    @Test("The ribbon's context is the last PROBED glyph, seeded at position 0")
    func ribbonContext() {
        var ribbon = Ribbon(seedGlyph: Self.seed)
        #expect(ribbon.currentContext == Self.seed)
        let first = Self.g(.hollow, .triangle, .one, .amber)
        ribbon.probe(first, against: Self.contextualLaw)
        #expect(ribbon.currentContext == first)  // advanced, though 1 > 2 is a REJECT
        #expect(ribbon.probes[0].verdict == .reject)
    }

    /// §6.11 edge case 3: a twin is an ADJACENT re-probe only. A non-adjacent repeat is not a
    /// twin, because only adjacency holds the context fixed — which is the twin's whole purpose.
    @Test("A twin is adjacent; a non-adjacent repeat is not")
    func twinIsAdjacentOnly() {
        var ribbon = Ribbon(seedGlyph: Self.seed)
        let a = Self.g(.hollow, .triangle, .three, .amber)
        let b = Self.g(.hollow, .triangle, .one, .amber)
        ribbon.probe(a, against: Self.contextualLaw)
        ribbon.probe(a, against: Self.contextualLaw)  // adjacent -> twin
        ribbon.probe(b, against: Self.contextualLaw)
        ribbon.probe(a, against: Self.contextualLaw)  // repeat, but NOT adjacent
        #expect(ribbon.probes.map(\.isTwin) == [false, true, false, false])
    }

    /// §6.6 layer 4: the same glyph giving two different answers is how a player discovers
    /// contextuality at all, and it renders as a SPLIT doubled ring.
    @Test("A twin whose verdicts differ is the rendered contradiction")
    func splitTwinIsDetected() {
        var ribbon = Ribbon(seedGlyph: Self.seed)
        let probe = Self.g(.hollow, .triangle, .three, .amber)
        ribbon.probe(probe, against: Self.contextualLaw)  // 3 > 2 -> admit
        ribbon.probe(probe, against: Self.contextualLaw)  // 3 > 3 -> reject
        #expect(ribbon.probes.map(\.verdict) == [.admit, .reject])
        #expect(ribbon.hasSplitTwin)

        // A stateless law can never produce one, which is what makes it evidence.
        let stateless = Law(.atom(.init(attribute: .pips, subset: Fixture.subset(0b1100))))
        var flat = Ribbon(seedGlyph: Self.seed)
        flat.probe(probe, against: stateless)
        flat.probe(probe, against: stateless)
        #expect(!flat.hasSplitTwin)
    }

    /// The resume path: verdicts are RECOMPUTED from the stored law and the glyph ids alone.
    @Test("A snapshot rehydrates the ribbon verdict for verdict")
    func snapshotRehydrates() {
        var ribbon = Ribbon(seedGlyph: Self.seed)
        let probes = [
            Self.g(.hollow, .triangle, .three, .amber),
            Self.g(.hollow, .triangle, .four, .amber),
            Self.g(.hollow, .triangle, .one, .amber),
        ]
        for p in probes { ribbon.probe(p, against: Self.contextualLaw) }

        let snapshot = ProbeSnapshot(
            law: Self.contextualLaw.node, seed: 42, band: .contextual,
            targetDelta: Band.contextual.centre, mode: .probe,
            seedGlyph: UInt8(Self.seed.id), probes: probes.map { UInt8($0.id) },
            startedAt: Date(timeIntervalSince1970: 0))

        let restored = snapshot.rehydrateRibbon()
        #expect(restored.probes.map(\.verdict) == ribbon.probes.map(\.verdict))
        #expect(restored.probes.map(\.glyphID) == ribbon.probes.map(\.glyphID))
        #expect(restored.currentContext == ribbon.currentContext)
    }

    /// Tampering with the probe list achieves nothing, because the law re-derives every verdict.
    @Test("A tampered probe list cannot forge a verdict")
    func tamperingIsFutile() {
        var snapshot = ProbeSnapshot(
            law: Self.contextualLaw.node, seed: 1, band: .contextual,
            targetDelta: Band.contextual.centre, mode: .probe,
            seedGlyph: UInt8(Self.seed.id),
            probes: [UInt8(Self.g(.hollow, .triangle, .one, .amber).id)],
            startedAt: Date(timeIntervalSince1970: 0))
        #expect(snapshot.rehydrateRibbon().probes[0].verdict == .reject)

        // Swap the glyph for one that WOULD be admitted; the verdict follows the law, not the file.
        snapshot.probes = [UInt8(Self.g(.hollow, .triangle, .three, .amber).id)]
        #expect(snapshot.rehydrateRibbon().probes[0].verdict == .admit)
    }

    /// §6.11 edge case 23: a mismatch voids the round, never silently alters it.
    @Test("The integrity check catches a swapped law")
    func integrityCheck() {
        var snapshot = ProbeSnapshot(
            law: Self.contextualLaw.node, seed: 1, band: .contextual,
            targetDelta: Band.contextual.centre, mode: .probe,
            seedGlyph: UInt8(Self.seed.id), startedAt: Date(timeIntervalSince1970: 0))
        #expect(snapshot.passesIntegrityCheck)
        snapshot.law = .atom(.init(attribute: .fill, subset: Fixture.subset(0b0100)))
        #expect(!snapshot.passesIntegrityCheck)
    }

    /// §6.11 edge case 29: a snapshot at `cap` is unreachable by construction, so one on disk
    /// is corruption.
    @Test("A snapshot at the cap is structurally invalid")
    func snapshotAtCapIsCorruption() {
        let atCap = ProbeSnapshot(
            law: Self.contextualLaw.node, seed: 1, band: .contextual,
            targetDelta: Band.contextual.centre, mode: .probe, seedGlyph: 0,
            probes: Array(repeating: 0, count: Band.contextual.cap),
            startedAt: Date(timeIntervalSince1970: 0))
        #expect(!atCap.isStructurallyValid)
    }

    @Test("The snapshot round-trips through Codable, law and all")
    func snapshotCodable() throws {
        let snapshot = ProbeSnapshot(
            law: Self.contextualLaw.node, seed: 0xDEAD, band: .contextual,
            targetDelta: 0.5, mode: .probe, seedGlyph: 22, probes: [1, 2, 3], strikes: 1,
            counterexample: .init(current: 7, previous: 9),
            startedAt: Date(timeIntervalSince1970: 1_700_000_000), elapsedActive: 42)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProbeSnapshot.self, from: data)
        #expect(decoded == snapshot)
        #expect(decoded.passesIntegrityCheck)
    }
}
