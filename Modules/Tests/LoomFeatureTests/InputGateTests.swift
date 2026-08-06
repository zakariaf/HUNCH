import Testing

import Glyphs
import LoomFeature
import ModulesTestSupport

/// §6.5's single slot, as a pure value — the whole input policy tested with no clock, no view
/// and no `Task.sleep`.
@Suite("The single-slot input queue", .tags(.unit, .presubmission))
struct InputGateTests {

    @Test("An unlocked gate fires immediately and locks")
    func firesWhenOpen() {
        var gate = InputGate()
        #expect(gate.request(.probe(Fixtures.seedGlyph)) == .fires)
        #expect(gate.isLocked)
        #expect(gate.queued == nil)
    }

    @Test("One tap during the lock is queued; the second is dropped — §6.11 case 10")
    func oneSlotOnly() {
        var gate = InputGate()
        _ = gate.request(.probe(Deck.glyph(id: 1)))
        #expect(gate.request(.probe(Deck.glyph(id: 2))) == .queued)
        #expect(gate.request(.probe(Deck.glyph(id: 3))) == .dropped)
        #expect(gate.queued == .probe(Deck.glyph(id: 2)))
    }

    @Test("The queued action fires at the unlock and re-locks the gate")
    func queuedFiresAtUnlock() {
        var gate = InputGate()
        _ = gate.request(.probe(Deck.glyph(id: 1)))
        _ = gate.request(.twin)
        #expect(gate.unlock() == .twin)
        #expect(gate.isLocked)  // the queued action opened its own beat
        #expect(gate.queued == nil)
        #expect(gate.unlock() == nil)
        #expect(gate.isLocked == false)
    }

    @Test("The twin key shares the one slot with the PROBE key")
    func oneQueueForBothKeys() {
        var gate = InputGate()
        _ = gate.request(.twin)
        #expect(gate.request(.probe(Deck.glyph(id: 4))) == .queued)
        #expect(gate.request(.twin) == .dropped)
    }

    /// §6.11 case 11. A queued second declaration would spend the round's second strike on a
    /// press the player made before seeing the first one resolve — catastrophic, and the reason
    /// the Seal is edge-triggered rather than sharing the slot.
    @Test("The Seal is edge-triggered and never queues")
    func theSealHasNoQueue() {
        var gate = InputGate()
        #expect(gate.requestSeal() == .fires)
        _ = gate.request(.probe(Fixtures.seedGlyph))
        #expect(gate.requestSeal() == .dropped)
        #expect(gate.queued == nil)
    }

    @Test("Closing the gate discards the queue")
    func closingDiscardsTheQueue() {
        var gate = InputGate()
        _ = gate.request(.twin)
        _ = gate.request(.twin)
        gate.close()
        #expect(gate.queued == nil)
        #expect(gate.isLocked == false)
    }
}
