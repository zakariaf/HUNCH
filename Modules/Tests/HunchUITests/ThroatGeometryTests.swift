import CoreGraphics
import Testing

import Glyphs
import HunchUI
import ModulesTestSupport
import Tokens

/// The well has to clear the transient admit ring at every art scale on both devices, and the
/// arithmetic that does it is the one most likely to be written wrong — the ring's radius is a
/// multiple of the **body radius**, not of the box side.
@Suite("The throat well clears the transient admit ring", .tags(.unit, .presubmission))
struct ThroatGeometryTests {

    @Test("The glyph side is 96 on the compact device and 128 on the large one")
    func nominalSides() {
        #expect(ThroatView.side(in: .reference(.compact), artScale: 1) == C.Throat.glyphSide)
        #expect(ThroatView.side(in: .reference(.large), artScale: 1) == C.Throat.glyphSideLarge)
    }

    @Test(
        "The ring never clips, at every art scale on both devices",
        arguments: [PlaySurfaceLayout.reference(.compact), .reference(.large)],
        [1.0, 1.2, Prim.artScaleCeiling])
    func theRingFitsTheRegion(_ layout: PlaySurfaceLayout, _ artScale: Double) {
        let side = ThroatView.side(in: layout, artScale: artScale)
        let ringDiameter =
            2 * C.Glyph.radius(side: side) * C.VerdictRing.transientAdmitRadius
        #expect(ringDiameter <= Double(layout.throat.height))
        #expect(side > 0)
    }

    @Test("Art scale grows the glyph until the region binds, and then stops")
    func artScaleIsClampedByTheRegion() {
        let layout = PlaySurfaceLayout.reference(.compact)
        let plain = ThroatView.side(in: layout, artScale: 1)
        let scaled = ThroatView.side(in: layout, artScale: Prim.artScaleCeiling)
        #expect(scaled >= plain)
        #expect(scaled <= C.Throat.glyphSide * Prim.artScaleCeiling)
        // The compact region is the binding one: 112 pt of well against a 96 pt glyph leaves
        // 16 pt of headroom, and 1.35 × 96 would need 34. The clamp must actually engage here,
        // or this whole suite would be asserting nothing.
        #expect(scaled < C.Throat.glyphSide * Prim.artScaleCeiling)
    }

    @Test("The large region is not the binding one")
    func theLargeRegionHasHeadroom() {
        let layout = PlaySurfaceLayout.reference(.large)
        #expect(
            ThroatView.side(in: layout, artScale: Prim.artScaleCeiling)
                == C.Throat.glyphSideLarge * Prim.artScaleCeiling)
    }

    @Test("The ring's expansion factor is declared once, by the ring")
    func noSecondDeclaration() {
        // `C.Throat` must not carry a ring headroom member; it moves when §13.7.2 moves.
        #expect(C.VerdictRing.transientAdmitRadius > 1)
    }

    /// §6.3's held registers, as a set operation rather than as a hope. Hue is the exception
    /// and is the one worth pinning: it is the ink colour of every pass, so a hue step moves no
    /// geometry and recolours everything.
    @Test(
        "Exactly one register moves — except hue, which is the ink of all four",
        arguments: Glyph.Attribute.allCases)
    func onlyTheChangedRegisterMoves(_ attribute: Glyph.Attribute) {
        let moving = ThroatView.affectedRegisters(by: attribute)
        #expect(moving.contains(attribute))
        if attribute == .hue {
            #expect(moving == Set(Glyph.Attribute.allCases))
        } else {
            #expect(moving.count == 1)
            let held = Set(Glyph.Attribute.allCases).subtracting(moving)
            #expect(held.count == 3)
        }
    }
}
