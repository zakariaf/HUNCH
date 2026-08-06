public import CoreGraphics

internal import Tokens

/// §6.2's play surface, resolved for one screen — **the only place a play-surface coordinate
/// exists.** Every other file in the epic asks this type where its region is.
///
/// It reads no environment, no `UIScreen` and no `@Environment`: the caller passes what
/// `GeometryReader` and `safeAreaInsets` gave it. That is what makes seven regions on two
/// devices assertable on the host with no simulator.
///
/// The derivation order matters and is §6.2's decision made structural:
///
/// 1. **The commit bar, the Bench handle and the Dial lay out *upward* from the bottom safe
///    edge.** They must stay inside the thumb arc, which is anchored to that edge and not to
///    the screen height — growing the Dial on a big phone pushes its top row out of reach.
/// 2. **The instrument bar sits at the top safe edge** at its resolved height. A play surface
///    carries zero text, so nothing on that bar can wrap and the height is 44 (`instrument-bar`
///    §2). Everything below is positioned from the bar's resolved `maxY`, never from a literal.
/// 3. **The throat absorbs what is left**, after the separator between the ribbon and the Dial.
///    Surplus height goes to the evidence display, which benefits from every point it gets.
// `nonisolated`, and it has to be said out loud: this target's default isolation is
// `MainActor` (01 P17), and a layout is a value — a test cannot even build an `arguments:`
// collection of main-actor values, which is how this was found. `05 R8`.
public nonisolated struct PlaySurfaceLayout: Equatable, Sendable {

    /// The two reference devices §6.2 tabulates, and the two layouts that ship.
    ///
    /// A class, not a device: an iPhone 16 is `compact` because it cannot hold the large class's
    /// fixed rows plus a throat, not because of its name.
    public nonisolated enum DeviceClass: String, CaseIterable, Equatable, Sendable {
        case compact, large
    }

    public let deviceClass: DeviceClass
    public let width: CGFloat
    public let safeTop: CGFloat
    public let safeBottom: CGFloat

    public let instrumentBar: CGRect
    public let throat: CGRect
    public let ribbon: CGRect

    /// Pro Max only: a machined dead band that carries no controls. `nil` on `compact`, where
    /// the same interval is an 8 pt gutter — a gutter is spacing, a bezel gap is a *surface*,
    /// and the difference is that one of them gets drawn.
    public let bezelGap: CGRect?

    public let dial: CGRect
    public let benchHandle: CGRect
    public let commitBar: CGRect

    /// 1 on `compact`, 2 on `large`. Follows the ribbon's height rather than the device name.
    public let ribbonLanes: Int

    public init(size: CGSize, safeAreaTop: CGFloat, safeAreaBottom: CGFloat) {
        let safeTop = safeAreaTop
        let safeBottom = size.height - safeAreaBottom
        let metrics = Metrics.forSafeHeight(safeBottom - safeTop)

        self.deviceClass = metrics.deviceClass
        self.width = size.width
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.ribbonLanes = metrics.ribbonLanes

        func row(_ minY: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: 0, y: minY, width: size.width, height: height)
        }

        // 1 — upward from the bottom safe edge.
        commitBar = row(safeBottom - metrics.commitBarHeight, metrics.commitBarHeight)
        benchHandle = row(
            commitBar.minY - metrics.handleToCommitGap - metrics.benchHandleHeight,
            metrics.benchHandleHeight)
        dial = row(
            benchHandle.minY - metrics.dialToHandleGap - metrics.dialHeight, metrics.dialHeight)

        // 2 — downward from the top safe edge.
        instrumentBar = row(safeTop, metrics.instrumentBarHeight)

        // 3 — the throat takes the residual; the ribbon does not, because a lane is discrete.
        // A ribbon 20 pt taller shows no more history, so surplus there would be wasted; the
        // throat's glyph is the one thing on the surface that reads better at any extra size.
        // `max` rather than a negative height: below the compact floor the surface overflows
        // visibly instead of silently squeezing the evidence.
        let fixed =
            metrics.instrumentBarHeight + metrics.ribbonHeight + metrics.separatorHeight
            + metrics.dialHeight + metrics.dialToHandleGap + metrics.benchHandleHeight
            + metrics.handleToCommitGap + metrics.commitBarHeight
        let throatHeight = max(metrics.minimumThroatHeight, safeBottom - safeTop - fixed)

        throat = row(instrumentBar.maxY, throatHeight)
        ribbon = row(throat.maxY, metrics.ribbonHeight)
        bezelGap =
            metrics.hasBezelGap ? row(ribbon.maxY, metrics.separatorHeight) : nil
    }

    /// The two devices §6.2 tabulates, for tests and previews.
    public static func reference(_ deviceClass: DeviceClass) -> Self {
        switch deviceClass {
        case .compact:
            Self(size: CGSize(width: 375, height: 667), safeAreaTop: 20, safeAreaBottom: 0)
        case .large:
            Self(size: CGSize(width: 440, height: 956), safeAreaTop: 62, safeAreaBottom: 34)
        }
    }

    /// Top to bottom, gaps excluded. The bezel gap is a gap, so it is not here.
    public var orderedRegions: [CGRect] {
        [instrumentBar, throat, ribbon, dial, benchHandle, commitBar]
    }

    /// §12.8 tier 1–2: everything the thumb reaches, and everything the reach predicate covers.
    public var interactiveRegions: [CGRect] { [dial, benchHandle, commitBar] }

    /// §12.8 tier 3: read, not touched. The throat swipe and the ribbon-load tap are
    /// low-frequency convenience paths, each with a Dial equivalent, which is what makes it
    /// legal for these three to sit outside the 460 pt band.
    public var readOnlyRegions: [CGRect] { [instrumentBar, throat, ribbon] }

    /// The live glyph's side inside the throat — art, so this is the one length here that
    /// `env.artScale` may multiply.
    public var throatGlyphSide: CGFloat { metrics.throatGlyphSide }

    // ── The par tick row (§6.2) ──────────────────────────────────────────────────────────

    /// 9 pt (compact) · 10 pt (large).
    public var nominalTickPitch: CGFloat { metrics.nominalTickPitch }

    /// The row's own budget for the pitch arithmetic — 288 / 348. **Not** the instrument bar's
    /// centre slot, which is `screenWidth − 88` (`instrument-bar` §1). The two numbers have
    /// different owners and are within a few points of each other today; merging them would
    /// couple the row's difficulty signal to the bar's furniture.
    public var tickRowWidth: CGFloat { metrics.tickRowWidth }

    /// The instrument bar's centre slot, which the row centres inside.
    public var instrumentCentreSlotWidth: CGFloat { width - Metrics.instrumentSlotInset }

    /// §6.2: `min(nominalPitch, rowWidth / N)`.
    ///
    /// - Parameter artScale: accepted and **deliberately unused**. Dynamic Type scales tick
    ///   *heights*; scaling the pitch would lengthen the row at large text sizes, engage the
    ///   clamp inside PROBE and turn §10.5's only difficulty signal into a lie.
    public func tickPitch(total: Int, artScale: CGFloat = 1) -> CGFloat {
        _ = artScale
        return TickRow.pitch(
            nominalPitch: nominalTickPitch, rowWidth: tickRowWidth, total: total)
    }

    /// The row's drawn length. Proportional to `total` wherever the clamp does not engage,
    /// which is everywhere in PROBE.
    public func tickRowLength(total: Int) -> CGFloat {
        tickPitch(total: total) * CGFloat(total)
    }

    // ── The Dial's ramps (§4.1) ──────────────────────────────────────────────────────────

    public var dialRowCount: Int { Metrics.dialRowCount }

    /// Read from `C.Ramp`, never restated: the cell is the ramp's, and the ramp is drawn on the
    /// Bench and in the Codex as well as here.
    public var dialCellSize: CGSize {
        let cell = deviceClass == .large ? C.Ramp.dialCellLarge : C.Ramp.dialCell
        return CGSize(width: cell.width, height: cell.height)
    }

    /// The ramp header's **width** — §4.1's "header 44 + 4 cells 70 × 48" is a row's horizontal
    /// budget, not a stacked height: `44 + 4 × 70 = 324` fits inside 375 and `52 + 4 × 82 = 380`
    /// fits inside 440, while any vertical reading overflows a 60 pt row immediately.
    public var dialHeaderWidth: CGFloat {
        deviceClass == .large ? C.Ramp.headerWidthLarge : C.Ramp.headerWidth
    }

    /// One ramp row. `dialRow(0).minY == dial.minY`: the compact class's 8 pt residual
    /// (`4 × 60 + 3 × 8 = 264` inside 272) goes to the **bottom**, so the first ramp sits
    /// directly under the ribbon and the Dial's top edge is exactly where §6.2's reach
    /// paragraph measures it. The large class has no residual: `4 × 78 + 3 × 10 = 342`.
    public func dialRow(_ index: Int) -> CGRect {
        let pitch = metrics.dialRowHeight + metrics.dialRowGutter
        return CGRect(
            x: dial.minX, y: dial.minY + CGFloat(index) * pitch,
            width: dial.width, height: metrics.dialRowHeight)
    }

    private var metrics: Metrics { Metrics.forDeviceClass(deviceClass) }
}

extension PlaySurfaceLayout {
    /// The two constant tables §6.2 publishes. Everything here is a *height* or a pitch; no
    /// origin is stored, because an origin is what the derivation computes.
    /// Every scalar here is `CGFloat`, not `Double`, and that is load-bearing: a
    /// `#expect(rect.minY == someDouble)` inside a Swift Testing macro compiles through the
    /// implicit conversion and then evaluates **false** — a test that can only fail, or, with
    /// `!=`, one that can only pass. One type across the whole layout removes the mixed
    /// comparison rather than remembering not to write it. See `DECISIONS.md` 39.
    nonisolated struct Metrics: Equatable, Sendable {
        var deviceClass: DeviceClass
        var instrumentBarHeight: CGFloat
        var ribbonHeight: CGFloat
        var ribbonLanes: Int
        var separatorHeight: CGFloat
        var hasBezelGap: Bool
        var dialHeight: CGFloat
        var dialRowHeight: CGFloat
        var dialRowGutter: CGFloat
        var dialToHandleGap: CGFloat
        var benchHandleHeight: CGFloat
        var handleToCommitGap: CGFloat
        var commitBarHeight: CGFloat
        var minimumThroatHeight: CGFloat
        var throatGlyphSide: CGFloat
        var nominalTickPitch: CGFloat
        var tickRowWidth: CGFloat

        static let dialRowCount = 4

        /// `instrument-bar` §1: the centre slot is `screenWidth − 88`.
        static let instrumentSlotInset: CGFloat = 88

        /// iPhone SE 2/3, and §4.1 verbatim. Its fixed rows plus the minimum throat come to
        /// exactly 647 — the SE's whole safe height — which is why it is the floor.
        static let compact = Metrics(
            deviceClass: .compact,
            instrumentBarHeight: Space.targetMin,
            ribbonHeight: 52, ribbonLanes: 1,
            separatorHeight: Space.s8, hasBezelGap: false,
            dialHeight: 272, dialRowHeight: 60, dialRowGutter: Space.s8,
            dialToHandleGap: Space.s8,
            benchHandleHeight: Space.targetMin, handleToCommitGap: Space.s44,
            commitBarHeight: 63,
            minimumThroatHeight: 112, throatGlyphSide: 96,
            nominalTickPitch: 9, tickRowWidth: 288)

        /// iPhone 16 Pro Max.
        static let large = Metrics(
            deviceClass: .large,
            instrumentBarHeight: Space.targetMin,
            ribbonHeight: 114, ribbonLanes: 2,
            separatorHeight: 50, hasBezelGap: true,
            dialHeight: 342, dialRowHeight: 78, dialRowGutter: 10,
            dialToHandleGap: Space.s8,
            benchHandleHeight: Space.targetMin, handleToCommitGap: Space.s4,
            commitBarHeight: 54,
            minimumThroatHeight: 144, throatGlyphSide: 128,
            nominalTickPitch: 10, tickRowWidth: 348)

        static func forDeviceClass(_ deviceClass: DeviceClass) -> Metrics {
            switch deviceClass {
            case .compact: compact
            case .large: large
            }
        }

        /// The large class needs its fixed rows **plus a throat at least as tall as its glyph**.
        /// A screen that cannot hold that is compact however it is marketed — which is the
        /// reason this is a predicate over the safe height and not a list of device names.
        static func forSafeHeight(_ safeHeight: CGFloat) -> Metrics {
            safeHeight >= large.minimumSafeHeight ? large : compact
        }

        var minimumSafeHeight: CGFloat {
            instrumentBarHeight + minimumThroatHeight + ribbonHeight + separatorHeight
                + dialHeight + dialToHandleGap + benchHandleHeight + handleToCommitGap
                + commitBarHeight
        }
    }
}
