import SwiftUI
import Testing

@testable import HunchUI
import Tokens

/// The adapter is the one place a token becomes a SwiftUI value, and every mistake it can make
/// is invisible to `HunchCore`'s tests — which have no `Color` at all.
@Suite("SwiftUI adapter", .tags(.unit, .presubmission))
struct AdapterTests {
    /// The pin that matters. `Color(.displayP3, …)` with the same three numbers is a DIFFERENT
    /// colour and moves every ratio in palette.md, and no test in HunchCore could see it.
    @MainActor
    @Test("RGB8 → Color resolves in sRGB, byte for byte")
    func colourIsSRGB() {
        let token = Prim.okabeItoAmber
        let resolved = Color(token).resolve(in: EnvironmentValues())
        // resolve() hands back linear sRGB components; convert back and compare as bytes.
        func encode(_ linear: Float) -> Int {
            let s =
                linear <= 0.003_130_8
                ? linear * 12.92 : 1.055 * pow(linear, 1 / 2.4) - 0.055
            return Int((s * 255).rounded())
        }
        #expect(encode(resolved.linearRed) == Int(token.red))
        #expect(encode(resolved.linearGreen) == Int(token.green))
        #expect(encode(resolved.linearBlue) == Int(token.blue))
    }

    /// This suite tests the Duration→seconds CONVERSION itself, so it must name durations
    /// literally: naming a Motion token would assert the token's value rather than the
    /// arithmetic, and would still pass if `.seconds` were wrong.
    @Test("Duration → seconds is exact for the durations the design actually states")
    func durationConversion() {
        // TOKENS-EXEMPT: the literals ARE the fixture — see the doc comment above.
        let cases: [(Duration, Double)] = [
            (.milliseconds(260), 0.260), (.milliseconds(1_840), 1.840), (.milliseconds(640), 0.640),
        ]
        for (duration, expected) in cases {
            #expect(duration.seconds == expected)
        }
    }

    @Test("The Dynamic Type multiplier saturates at §13.11's AX2 ceiling")
    func dynamicTypeSaturates() {
        #expect(RenderEnvReader<EmptyView>.multiplier(for: .large) == 1.00)
        #expect(RenderEnvReader<EmptyView>.multiplier(for: .accessibility2) == 1.35)
        #expect(RenderEnvReader<EmptyView>.multiplier(for: .accessibility5) == 1.35)
        // Monotone non-decreasing across the whole ordinal range.
        let all = DynamicTypeSize.allCases.map { RenderEnvReader<EmptyView>.multiplier(for: $0) }
        #expect(all == all.sorted())
    }
}
