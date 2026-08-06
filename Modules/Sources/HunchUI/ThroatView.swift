public import SwiftUI

public import Glyphs
public import Tokens

/// The throat: the live draft glyph in its well (§6.2, §6.3).
///
/// The throat **is** the draft — the glyph here is what the PROBE key feeds to the Loom — so
/// this view has exactly one job beyond drawing it: when a single register changes, that
/// register crossfades and the other three hold *perfectly still*. §6.3 calls that out as
/// epistemics rather than polish, and it is: change-one-hold-three is the inductive move, and a
/// whole-glyph crossfade hides the act inside the result.
///
/// **Read-only, one gesture.** The throat sits above §12.8's y = 220 line. Its horizontal swipe
/// is legal only because the Dial does the same thing with a tap; a second action here would
/// break the reach argument for the entire surface. The `Canvas` therefore takes no touches at
/// all and the gesture lives on the container's `contentShape`.
@MainActor
public struct ThroatView: View {

    /// §13.6's four presentations. `.empty` (ECHO) and `.idle` (the Frame's Loom) are declared
    /// now so those epics extend a state rather than building a second throat.
    public enum Presentation: Hashable, Sendable {
        /// A draft the player can edit and probe.
        case live
        /// The verdict beat: input locked, the aperture turning, nothing else moving.
        case animating
        /// No glyph at all — ECHO's opening (E13).
        case empty
        /// The Frame's ambient Loom (E17).
        case idle
    }

    public var draft: Glyph
    /// The draft as it was before the last edit. `nil` on the first frame, and whenever the
    /// change is not a single-register step.
    public var outgoing: Glyph?
    public var changedRegister: Glyph.Attribute?
    /// §6.6 layer 1: at probe 0 the throat wears the seed's dashed frame and backward chevron,
    /// in **every** band. It is the only place a glyph is marked as not-yours.
    public var isSeed: Bool
    public var presentation: Presentation
    public var ring: VerdictRing.State?
    public var ringProgress: Double
    /// §6.5, 90–260 ms: 0…1 through one turn of the hairline aperture. `nil` when the hold is
    /// not running. Never conditioned on the verdict, the band or contextuality — a Loom that
    /// visibly thinks harder about hard glyphs leaks the family before probe 3.
    public var aperture: Double?
    /// §6.5 t = 0: the throat contracts to `C.Throat.submitContraction` over 90 ms.
    public var contraction: Double
    public var layout: PlaySurfaceLayout
    public var env: RenderEnv
    /// ±1. The same call the Dial makes, so the gesture and VoiceOver's adjustable action are
    /// one behaviour with two entry points.
    public var onStep: (Int) -> Void

    public init(
        draft: Glyph,
        outgoing: Glyph? = nil,
        changedRegister: Glyph.Attribute? = nil,
        isSeed: Bool = false,
        presentation: Presentation = .live,
        ring: VerdictRing.State? = nil,
        ringProgress: Double = 1,
        aperture: Double? = nil,
        contraction: Double = 1,
        layout: PlaySurfaceLayout,
        env: RenderEnv,
        onStep: @escaping (Int) -> Void = { _ in }
    ) {
        self.draft = draft
        self.outgoing = outgoing
        self.changedRegister = changedRegister
        self.isSeed = isSeed
        self.presentation = presentation
        self.ring = ring
        self.ringProgress = ringProgress
        self.aperture = aperture
        self.contraction = contraction
        self.layout = layout
        self.env = env
        self.onStep = onStep
    }

    /// The glyph's drawn side: 96 pt compact, 128 pt large, times `artScale`, **clamped so the
    /// transient admit ring never clips**.
    ///
    /// The clamp is the arithmetic that is easy to get wrong. The ring's radius is
    /// `transientAdmitRadius × R` where `R = 0.37 · S` — it is *not* `1.35 · S`, and using the
    /// side would over-reserve by nearly three times and shrink the glyph for no reason.
    /// The region does not grow under Dynamic Type (§13.11), so above some scale the region
    /// binds and the glyph stops growing rather than the ring starting to clip.
    public static func side(in layout: PlaySurfaceLayout, artScale: Double) -> Double {
        let nominal =
            layout.deviceClass == .large ? C.Throat.glyphSideLarge : C.Throat.glyphSide
        let ceiling =
            Double(layout.throat.height)
            / (2 * C.Glyph.radiusRatio * C.VerdictRing.transientAdmitRadius)
        return min(nominal * artScale, ceiling)
    }

    /// Which registers a change to `attribute` moves on the drawing.
    ///
    /// One attribute, one register — **except hue**, which is the index stroke *and* the ink
    /// colour of every other pass. A hue step moves no geometry and recolours the whole glyph,
    /// so all four passes crossfade; the silhouette still holds perfectly still, which is what
    /// §6.3 actually asks for.
    public static func affectedRegisters(by attribute: Glyph.Attribute) -> Set<Glyph.Attribute> {
        attribute == .hue ? Set(Glyph.Attribute.allCases) : [attribute]
    }

    public var body: some View {
        let side = Self.side(in: layout, artScale: env.artScale)
        Canvas { context, size in
            var context = context
            context.scaleBy(x: contraction, y: contraction)
            context.translateBy(
                x: size.width * (1 - contraction) / (2 * contraction),
                y: size.height * (1 - contraction) / (2 * contraction))
            draw(into: &context, canvas: size, side: side)
        }
        // The canvas must not swallow touches: the one gesture lives on the container, and a
        // hit-testing canvas would eat the swipe silently.
        .allowsHitTesting(false)
        .frame(width: layout.throat.width, height: layout.throat.height)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard presentation == .live else { return }
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) else { return }
                    onStep(dx > 0 ? 1 : -1)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityAddTraits(.updatesFrequently)
        // The label, value and the ±1 wording are E19·T02's — a four-part localized format
        // string, never concatenated fragments. The *behaviour* is wired here so E19 fills a
        // catalog entry rather than restructuring the view.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(1)
            case .decrement: onStep(-1)
            @unknown default: break
            }
        }
    }

    private func draw(into context: inout GraphicsContext, canvas: CGSize, side: Double) {
        guard presentation != .empty else { return }

        let box = CGRect(
            x: (canvas.width - side) / 2, y: (canvas.height - side) / 2,
            width: side, height: side)
        let bodyCentre = CGPoint(x: box.midX, y: box.midY + C.Glyph.centreOffset(side: side))
        let bodyRadius = C.Glyph.radius(side: side)

        if isSeed {
            GhostFrame.draw(into: context, box: box, role: .seed, env: env)
        }

        // One canvas, three layers, one bloom bed: the held registers drawn once, and the
        // changed register crossfaded between the outgoing and incoming glyphs.
        let renderer = GlyphRenderer(glyph: draft, side: side, env: env)
        if let changed = changedRegister, let outgoing, outgoing != draft {
            let moving = Self.affectedRegisters(by: changed)
            let held = Set(Glyph.Attribute.allCases).subtracting(moving)
            if !held.isEmpty {
                renderer.draw(into: &context, canvas: canvas, registers: held)
            }
            renderer.draw(into: &context, canvas: canvas, registers: moving)
        } else {
            renderer.draw(into: &context, canvas: canvas)
        }

        if let ring {
            VerdictRing.draw(
                into: context, centre: bodyCentre, bodyRadius: bodyRadius, state: ring,
                role: presentation == .animating ? .transient : .settled,
                progress: ringProgress, env: env)
        }

        if let aperture {
            drawAperture(into: context, centre: bodyCentre, radius: bodyRadius, turn: aperture)
        }
    }

    /// §6.5's adjudication hold: nothing moves but a hairline aperture turning in the ring.
    private func drawAperture(
        into context: GraphicsContext, centre: CGPoint, radius: Double, turn: Double
    ) {
        let start = Angle(degrees: C.Throat.apertureSweepDegrees * turn - 90)
        var path = Path()
        path.addArc(
            center: centre, radius: radius, startAngle: start,
            endAngle: start + .degrees(26), clockwise: false)
        context.stroke(
            path, with: .color(env.palette.stroke.hairline.color),
            style: StrokeStyle(lineWidth: env.weight(.hairline), lineCap: .round))
    }
}
