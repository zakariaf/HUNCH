import Testing

import HunchTestSupport
import Ladder

/// §14's H1–H21, accounted for exactly once each: a named assertion in this repository, or a
/// named row here with the epic that owns it. The ledger is the artefact — "the harness covers
/// it" is how a hypothesis goes unmeasured for a year.
@Suite("The H1–H21 ledger", .tags(.unit, .presubmission))
struct HypothesisLedgerTests {

    /// Asserted here, in `ResponseHarnessTests` and `LadderCensoringTests`.
    static let assertedHere: [Int: String] = [
        1: "H1 — the estimate converges on the player's true ability",
        3: "H3 — the realised success rate is 0.80 ± 0.03 across the servable range",
        8: "H8 — the modal band stays under 60 % for a converged player",
        19: "H19 — a player past the ceiling saturates rather than diverging",
    ]

    /// Owned elsewhere, with the epic that owns it. Every row names a *place*, not a promise.
    static let delegated: [Int: String] = [
        2: "E06 — the generator's invariants at 10,000 laws per band",
        4: "E11·T11 — the Level-B reasoner harness",
        5: "E09 — the counterexample-conditional recovery rate r ≈ 0.474",
        6: "E06 — difficulty(of:) predicts failure, Spearman ρ ≥ 0.75",
        7: "E06 — within-band ρ ≥ 0.45",
        9: "E12 — DRIFT's hinge detection rate",
        10: "E13 — ECHO's pool sufficiency",
        11: "E14 — SIEVE's tempo ladder",
        12: "E11·T03 — DRIFT's −0.50 mode bias, measured",
        13: "E16 — the Anomaly's cross-device determinism",
        14: "E15 — Codex dedup at scale",
        15: "E16 — the Profile's five axes are independent",
        16: "E18 — localisation completeness across twelve locales",
        17: "E19 — VoiceOver traversal covers every control",
        18: "E20 — audio and haptic land on the same frame",
        20: "E20 — frame budget under the shader",
        21: "E20 — install size under 15 MB",
    ]

    @Test("Every hypothesis is accounted for exactly once")
    func theLedgerIsComplete() {
        let here = Set(Self.assertedHere.keys)
        let there = Set(Self.delegated.keys)
        #expect(here.isDisjoint(with: there))
        #expect(here.union(there) == Set(1...21))
    }

    @Test("Every delegated row names an owner")
    func everyRowNamesAnOwner() {
        for (number, owner) in Self.delegated {
            #expect(owner.contains("E"), "H\(number) has no owning epic")
            #expect(owner.contains("—"), "H\(number) has no statement")
        }
    }
}
