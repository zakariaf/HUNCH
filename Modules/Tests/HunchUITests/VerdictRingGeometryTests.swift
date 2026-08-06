import CoreGraphics
import SwiftUI
import Testing

import Glyphs
import ModulesTestSupport
import Tokens

@testable import HunchUI

/// The ring's radius is a **multiple** of the body radius, never a length. Reading it as a
/// length draws every ring in the game at about one point across — a dot at the glyph's centre,
/// which looks like a faint ring rather than a missing one, which is why it survived E04's
/// gallery. These tests pin the drawn geometry so it cannot survive again.
@Suite("The verdict ring is drawn at the right radius", .tags(.unit, .presubmission))
struct VerdictRingGeometryTests {

    private static let env = RenderEnv(
        theme: .dark, isReduceMotionEnabled: false, isReduceTransparencyEnabled: false,
        isBoldTextEnabled: false, isDifferentiateWithoutColorEnabled: false,
        isLowPowerModeEnabled: false, typeMultiplier: 1)

    private func radius(_ state: VerdictRing.State, role: VerdictRing.Role = .settled)
        -> [CGFloat]
    {
        let bodyRadius = C.Glyph.radius(side: 44)
        return VerdictRing.rings(
            for: state, role: role, progress: 1, bodyRadius: bodyRadius, env: Self.env
        )
        .map { ring in
            VerdictRing.arcs(
                centre: .zero, ring: ring, bodyRadius: bodyRadius, env: Self.env
            ).boundingRect.width / 2
        }
    }

    @Test("A settled admit ring sits OUTSIDE the silhouette, at 1.18 R")
    func settledAdmitIsOutsideTheBody() {
        let bodyRadius = C.Glyph.radius(side: 44)
        let drawn = radius(.admit)
        #expect(drawn.count == 1)
        #expect(abs(drawn[0] - bodyRadius * C.VerdictRing.settledAdmitRadius) < 0.01)
        #expect(drawn[0] > bodyRadius)  // a ring inside the body is a ring nobody sees
    }

    /// §6.4's geometric opposition: admit completes and blooms outward, reject contracts and
    /// breaks. The broken ring settles ON the silhouette, so the glyph's own outline is what
    /// reads as broken.
    @Test("A settled reject ring settles on the silhouette, at 1.00 R")
    func settledRejectSitsOnTheBody() {
        let bodyRadius = C.Glyph.radius(side: 44)
        let drawn = radius(.reject)
        #expect(abs(drawn[0] - bodyRadius * C.VerdictRing.settledRejectRadius) < 0.01)
    }

    @Test("A transient admit ring expands to 1.35 R and no further")
    func transientAdmitExpandsToTheHeadroom() {
        let bodyRadius = C.Glyph.radius(side: 44)
        let drawn = radius(.admit, role: .transient)
        #expect(abs(drawn[0] - bodyRadius * C.VerdictRing.transientAdmitRadius) < 0.01)
    }

    @Test("A twin's two rings are concentric and separated, never coincident")
    func twinRingsAreSeparated() {
        let drawn = radius(.twin(first: .admit, second: .admit))
        #expect(drawn.count == 2)
        #expect(drawn[1] > drawn[0])
        #expect(
            abs((drawn[1] - drawn[0]) - C.Glyph.radius(side: 44) * C.VerdictRing.twinRingSeparation)
                < 0.01)
    }

    /// The failure this suite exists for: every ring in the game drawn at about a point across.
    @Test(
        "No ring is ever drawn at a radius near 1 pt",
        arguments: [
            VerdictRing.State.admit, .reject, .twin(first: .admit, second: .reject),
            .counterexample(loomAdmits: true), .restrike(count: 3), .day(.clean),
        ])
    func noRingIsADot(_ state: VerdictRing.State) {
        for drawn in radius(state) {
            #expect(drawn > 4)
        }
    }
}
