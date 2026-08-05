import Testing

import HunchTestSupport
import Tokens

/// §13.5.1's claim is that all four glyph channels are determined by GEOMETRY alone, so a
/// greyscale screenshot preserves all 256 as distinct rasters. The rasterised half of that
/// proof is `check-coverage-separation.js`, which walks all 32,640 pairs in six environments;
/// this is the half that lives in Swift, and it pins the two things the rasteriser depends on.
@Suite("Triple encoding", .tags(.unit, .presubmission))
struct TripleEncodingTests {
    /// §13.5's ink-density ladder is the `fill` channel's achromatic discriminator, and it is
    /// *derived* from the pitch tokens rather than asserted — so a pitch change that flattened
    /// two rungs would fail here rather than silently compress the channel.
    @Test("The fill coverage ladder is 0 / 22.7 / 38.6 / 100 %, at every size")
    func coverageLadderIsMonotone() {
        for side in [24.0, 44.0, 96.0, 220.0] {
            let pitch = C.Glyph.pitch(side: side)
            let dotRadius = C.Glyph.dotRadius(side: side)
            let stripeWeight = C.Glyph.stripeWeight(side: side)

            // Hex packing: one disc per pitch × (pitch·√3/2) cell.
            let dotted =
                (Double.pi * dotRadius * dotRadius) / (pitch * pitch * (3.0.squareRoot() / 2))
            // Parallel lines: one stripe width per pitch.
            let striped = stripeWeight / pitch

            #expect(abs(dotted - 0.227) < 0.005, "dotted at S=\(side) is \(dotted)")
            #expect(abs(striped - 0.386) < 0.005, "striped at S=\(side) is \(striped)")
            #expect(0 < dotted && dotted < striped && striped < 1)
        }
    }

    /// The pitch floor is what keeps the ladder true at small sizes: below it, `dotted` at the
    /// Codex thumbnail's scale would render perhaps three visible discs and stop being a
    /// texture at all.
    @Test("The pitch floor engages below S ≈ 61 and holds the ladder together")
    func pitchFloorEngages() {
        #expect(C.Glyph.pitch(side: 24) == 5)  // floored
        #expect(C.Glyph.pitch(side: 220) > 5)  // proportional
        // Coverage is size-invariant either side of the floor — that is the point of it.
        #expect(
            C.Glyph.stripeWeight(side: 24) / C.Glyph.pitch(side: 24)
                == C.Glyph.stripeWeight(side: 220) / C.Glyph.pitch(side: 220))
    }

    /// T is §13.5.1's "shipped constant", which the GDD asserts and never states. Measured by
    /// the rasteriser over all 32,640 pairs; the binding case is two pips against three on a
    /// hollow circle in frost, and the tightest environment is High Contrast + Bold Text at a
    /// 12 % margin.
    @Test("T is the measured minimum pairwise ink difference, in pt² at S = 44")
    func theConstantT() {
        #expect(C.Glyph.minimumPairwiseInkDifference == 8.0)
    }

    /// The pip disc is what the limiting pair differs by, so its area is the floor on T. If
    /// this shrinks, T shrinks with it and the margin at High Contrast + Bold Text is the
    /// first thing to go.
    @Test("One pip disc at S = 44 comfortably exceeds T")
    func pipDiscExceedsT() {
        let r = C.Glyph.pipRadius(side: 44)
        let area = Double.pi * r * r
        #expect(area > C.Glyph.minimumPairwiseInkDifference)
    }
}
