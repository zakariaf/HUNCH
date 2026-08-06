import Testing

import HunchTestSupport
import Tokens

/// §13.11. The rule that has to hold on **every** screen is "above AX2 nothing shrinks", and a
/// table is how it stops being checked one screen at a time.
@Suite("Dynamic Type behaviour", .tags(.unit, .presubmission))
struct AccessibilityLayoutTests {

    @Test("No screen shrinks anything, at any size", arguments: AccessibilityLayout.Screen.allCases)
    func nothingShrinks(_ screen: AccessibilityLayout.Screen) {
        #expect(screen.shrinksAnything == false)
    }

    /// Every screen has an answer for above-AX2, and the answers are *different kinds of thing*
    /// — scroll, page, reflow, hold — which is why a single global rule would be wrong.
    @Test("Every screen has an above-AX2 behaviour")
    func everyScreenAnswers() {
        let behaviours = Set(AccessibilityLayout.Screen.allCases.map(\.aboveAX2))
        #expect(behaviours.count >= 4)
        #expect(AccessibilityLayout.Screen.probeSurface.aboveAX2 == .scrollsInsideItsRegion)
        #expect(AccessibilityLayout.Screen.bench.aboveAX2 == .pages)
    }

    /// A drawing, not text. The portrait holds §11.10's geometry at every size — and its axis
    /// names appear at no size, because they do not exist in the app.
    @Test("The Profile is a drawing and holds its geometry")
    func theProfileHolds() {
        #expect(AccessibilityLayout.Screen.profile.aboveAX2 == .holdsItsGeometry)
    }

    /// The onboarding script has no text by construction, so it is the one screen where the
    /// whole section is a no-op — which is worth stating rather than leaving as an absence.
    @Test("Onboarding is unaffected because it has no text at all")
    func onboardingIsUnaffected() {
        #expect(AccessibilityLayout.Screen.onboarding.aboveAX2 == .unaffected)
    }

    /// §12.8 tier 1 at the largest text size: a scrolling commit bar would move the thing that
    /// ends a decision at exactly the size where reach matters most.
    @Test("The commit bar never scrolls and a thumbnail never scales")
    func pinnedThings() {
        #expect(AccessibilityLayout.commitBarScrolls == false)
        #expect(AccessibilityLayout.thumbnailSide == 44)
    }

    /// Bold Text is the only signal the system gives us that a player wants heavier marks, and
    /// the play surface has no text for it to reach — so it reaches the strokes instead.
    @Test("Bold Text steps the strokes, on a surface with no text")
    func boldTextReachesTheMarks() {
        #expect(AccessibilityLayout.boldTextStrokeScale == 1.25)
        let bold = RenderEnv(
            theme: .dark, isReduceMotionEnabled: false, isReduceTransparencyEnabled: false,
            isBoldTextEnabled: true, isDifferentiateWithoutColorEnabled: false,
            isLowPowerModeEnabled: false, typeMultiplier: 1)
        #expect(StrokeWeight.body.resolved(in: bold) == 3.75)
        #expect(StrokeWeight.hairline.resolved(in: bold) == 0.625)
    }

    @Test("Reduce Transparency swaps the blur for a flat scrim")
    func reduceTransparency() {
        #expect(
            AccessibilityLayout.scrimOpacity(reduceTransparency: true) == Opacity.scrimFlat)
        #expect(
            AccessibilityLayout.scrimOpacity(reduceTransparency: false) == Opacity.scrimBlurred)
        #expect(Opacity.scrimFlat > Opacity.scrimBlurred)
    }

    /// True by construction: every verdict is a shape before it is a colour, so the setting adds
    /// emphasis rather than adding a channel that was missing.
    @Test("Differentiate Without Colour is the default state of the design")
    func differentiateIsDefault() {
        #expect(AccessibilityLayout.differentiateWithoutColourIsDefault)
    }
}
