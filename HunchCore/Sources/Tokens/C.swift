import Foundation

/// **L2.** One namespace per row of `DESIGN-SYSTEM-SCOPE.md` §3, owned by that row's
/// skill. L2 may reference L1 and `RenderEnv`; it may never reference `Prim`, and it
/// may never hold a literal that L1 already names.
///
/// The name is one letter deliberately: it appears at every drawing call site and its
/// members are always fully qualified (`C.Ramp.inertInk`), so the letter never stands
/// alone. `DESIGN-SYSTEM-SCOPE.md` §4.1 already fixed the spelling.
///
/// Two worked examples ship here because they belong to the resolution order rather
/// than to a drawing. Everything else is appended by the component skills.
public enum C {

    /// A width × height pair for L2 members that name one. Deliberately not `CGSize`: the token
    /// layer is `HunchCore` and imports no graphics framework, which is what keeps
    /// `swift test` able to assert every dimension with no simulator.
    public struct Size: Hashable, Sendable {
        public let width: Double
        public let height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }
    /// The dashed hollow frame and backward chevron that marks a `prev` referent — §4.2's
    /// diegetic symbol, drawn identically at every one of its four sites so the identity is
    /// what does the naming that words are forbidden from doing.
    public enum GhostFrame {
        /// Fixed at every size, deliberately. The dash is a TEXTURE, and this app pins
        /// textures to an absolute pitch (§13.5's `pitch = max(5, 0.22·R)` and the coverage
        /// ladder that depends on it). A dash that scaled with the box would make the 36 pt
        /// ECHO seed and the 168 pt DRIFT sigil different marks.
        ///
        /// `[3, 3]` is this mark's signature and no other dashed mark may use it: the
        /// counterexample ring is `[4, 3]`, and the empty-rail outline and the Anomaly
        /// `.absent` ring must pick something else.
        public static let dash: [Double] = [3, 3]
        /// Reproduces the PHOSPHOR mockup exactly at `side = 44`.
        public static let chevronRatio = 0.09
        /// Keeps the 36 pt ECHO seed chevron legible once the ratio floors out.
        public static let chevronFloor = 4.0
    }

    /// The bar across a barred control — the Seal and the barred mode-rack key draw the
    /// identical mark (§4.3, §12.4).
    public enum MachinedBar {
        /// The bar runs −0.52 … +0.52 of the control, so it overhangs by 2 % on each side and
        /// reads as a machined part rather than as a drawn line that stops at the edge.
        public static let overhangRatio = 0.02
    }

    /// The mark that strikes a region as excluded — an unlit ramp cell, an inert ramp, an
    /// eliminated ECHO pool member.
    public enum CancelHatch {
        /// Fixed at every site and exactly perpendicular to §13.5's `striped` fill, so the
        /// mark never disappears into a striped glyph.
        public static let angleDegrees = -45.0
        /// Perpendicular spacing — a 14 pt axis step. Coverage is `weight / spacing`, held
        /// below `dotted`'s 22.7 % so the hatch never reads as a fill.
        public static let spacing = 9.9
        /// The transient reject ring's slash is a diameter chord with a little overshoot.
        public static let slashOvershoot = 1.06
    }

    /// `C.Glyph` and the model type `Glyphs.Glyph` are different modules and L2 is always
    /// written fully qualified, so there is no ambiguity at a call site.
    public enum Glyph {
        // ── Lengths, all ratios of the box side S (§13.5) ──────────────────
        /// §13.5's body radius as a fraction of the box side. Named because the throat has to
        /// size a well against `2R × the ring's expansion` and cannot do that from a function
        /// it can only call with a side it has not computed yet.
        public static let radiusRatio = 0.37

        public static func radius(side S: Double) -> Double { radiusRatio * S }
        /// Signed y offset of `bodyCentre` from the box centre, **screen frame**.
        /// §13.5 writes `+0.10·S` in a y-up frame; this is that value negated.
        public static func centreOffset(side S: Double) -> Double { -0.10 * S }
        /// Signed y offset of the index register. §13.5's `−0.43·S`, negated.
        public static func indexCentreOffset(side S: Double) -> Double { 0.43 * S }
        /// High Contrast *substitutes* the longer stroke; it is never also scaled.
        public static func indexLength(side S: Double, in env: RenderEnv) -> Double {
            (env.theme == .highContrast ? 0.409 : 0.273) * S
        }
        public static func pitch(side S: Double) -> Double { max(5, 0.22 * radius(side: S)) }
        public static func dotRadius(side S: Double) -> Double { 0.25 * pitch(side: S) }
        public static func stripeWeight(side S: Double) -> Double { 0.386 * pitch(side: S) }
        public static func pipRadius(side S: Double) -> Double { max(3, 0.11 * radius(side: S)) }

        // ── Weights ────────────────────────────────────────────────────────
        public static func bodyStroke(side S: Double, in env: RenderEnv) -> Double {
            env.weight(S < 48 ? .bodySm : .body)
        }
        /// Never `bodySm`: the hue channel is the heaviest non-colour mark on the glyph.
        public static func indexStroke(in env: RenderEnv) -> Double { env.weight(.body) }
        public static func keylineStroke(side S: Double, in env: RenderEnv) -> Double? {
            guard env.palette.glyphKeyline != nil else { return nil }
            return bodyStroke(side: S, in: env) + 1.0
        }
        public static func haloStroke(side S: Double, in env: RenderEnv) -> Double {
            bodyStroke(side: S, in: env) * 3
        }
        public static func haloIndexStroke(in env: RenderEnv) -> Double { indexStroke(in: env) * 3 }
        /// A geometric separator, not a design weight: it opts out of Bold Text and of
        /// the High Contrast offset, because 1 pt is what keeps the node visible at all.
        public static let pipKnockoutWeight = 1.0

        // ── Derived regions ────────────────────────────────────────────────
        /// The fill clip is inset `1.5 × bodyWeight` from the silhouette centre-line,
        /// which is exactly the halo half-width — see bloom-and-squash.md §3.
        public static func fillInset(side S: Double, in env: RenderEnv) -> Double {
            1.5 * bodyStroke(side: S, in: env)
        }
        /// Scale factor about `bodyCentre` that turns the silhouette into the fill clip.
        /// Offsetting a regular polygon is a change of apothem, so this is exact.
        public static func fillClipScale(cornerCount n: Int, side S: Double, in env: RenderEnv)
            -> Double
        {
            let apothem = radius(side: S) * (n == 0 ? 1 : cos(.pi / Double(n)))
            return max(0, (apothem - fillInset(side: S, in: env)) / apothem)
        }

        // ── Bloom and layout ───────────────────────────────────────────────
        /// The `S >= 32` half of the bloom gate. The environment half is `env.isBloomEnabled`.
        public static func isBloomed(side S: Double, in env: RenderEnv) -> Bool {
            env.isBloomEnabled && S >= 32
        }
        /// How far outside the S-box the drawing reaches, per axis. The four terms are
        /// frost (90°), {teal, rose} (45°/135°), amber (0°) and the silhouette; §6
        /// derives them. A flat `0.08 · S` clips {teal, rose} for `32 <= S < 59.5` and
        /// clips frost under High Contrast at every size.
        public static func bleed(side S: Double, in env: RenderEnv) -> (x: Double, y: Double) {
            let bloomed = isBloomed(side: S, in: env)
            let halfIndex = (bloomed ? haloIndexStroke(in: env) : indexStroke(in: env)) / 2
            // A round halo join reaches half its width; a miter join on the triangle's
            // 60° corner reaches `(W/2) / sin 30°` = W, the worst of the four shapes.
            let bodyReach =
                bloomed ? haloStroke(side: S, in: env) / 2 : bodyStroke(side: S, in: env)
            let halfLength = indexLength(side: S, in: env) / 2
            let diagonal = 0.5.squareRoot()
            let register = indexCentreOffset(side: S)
            let y = max(
                register + halfLength,  // frost, 90°
                register + (halfLength + halfIndex) * diagonal,  // teal and rose
                register + halfIndex,  // amber, 0°
                0.47 * S + bodyReach)  // the silhouette
            let x = max(
                halfLength,  // amber, 0°
                (halfLength + halfIndex) * diagonal,  // teal and rose
                halfIndex,  // frost, 90°
                radius(side: S) + bodyReach)  // the silhouette
            return (x: max(0, x - S / 2), y: max(0, y - S / 2))
        }

        /// §13.5.1's shipped constant: the minimum pairwise ink difference over the deck,
        /// in pt² at S = 44. Measured, not asserted — `check-coverage-separation.js`.
        public static let minimumPairwiseInkDifference = 8.0
    }

    public enum VerdictRing {
        /// The transient admit ring's radius at the end of its expansion, as a multiple of the
        /// body radius — §13.7.2's 200 ms bloom. **Declared exactly once, here**: the throat's
        /// well is sized against it, the reject ring contracts *from* it, and if it were also a
        /// `C.Throat` member the two would drift the day §13.7.2 moves.
        public static let transientAdmitRadius = 1.35

        /// The reject ring's gap, degrees. Doubled under Differentiate Without Colour (§13.11),
        /// which is why it is a pair rather than a constant.
        public static let rejectGapDegrees = 30.0
        public static let rejectGapDegreesDifferentiated = 60.0
    }

    /// §6.2's live-draft well. `submitContraction` and `registerCrossfade` are §6.5's and
    /// §6.3's respectively, and they are deliberately different clocks from the verdict beat.
    public enum Throat {
        public static let glyphSide = 96.0
        public static let glyphSideLarge = 128.0

        /// §6.5 t = 0: the throat glyph contracts to 0.92 over 90 ms, ease-in.
        public static let submitContraction = 0.92

        /// §6.3: "the throat redraws in 80 ms". One register crossfades and three hold, so this
        /// is neither the verdict beat's clock nor the rings' — three clocks, kept apart.
        public static let registerCrossfade = Duration.milliseconds(80)

        /// §6.5, 90–260 ms: the adjudication hold's rotating hairline aperture. One turn.
        public static let apertureSweepDegrees = 360.0
    }

    /// §6.2's transcript strip. Four surfaces share this drawing — the PROBE ribbon, ECHO's
    /// rail, ECHO's cast and SIEVE's tail — at different sizes and states.
    public enum Ribbon {
        /// **A floor, not a preference.** A 44 pt tile is below the `S = 48` regime boundary, so
        /// the body takes `weight.bodySm` while the index stroke stays at `weight.body` — the
        /// hue channel is deliberately the heaviest non-colour mark on the glyph. Under High
        /// Contrast all four hues collapse to `stroke.primary` and are told apart by a
        /// 90°-separated rotation and nothing else, which any shrink below 44 pt attacks
        /// directly.
        public static let tileSide = 44.0

        /// §6.2: 50 pt pitch on both devices — the tile plus the link arc's run.
        public static let tilePitch = 50.0

        /// The rail-cap at the ribbon's leading edge that opens the spool sheet (T09).
        public static let spoolCapWidth = 24.0

        /// The elbow's vertical drop when the chain wraps to the next lane.
        public static let returnElbowDrop = 18.0
    }

    public enum TickRow {
        /// The tick itself never scales with the pitch (§6.2): at DRIFT band 8's 40 ticks the
        /// pitch compresses to 7.2 pt on the compact class and the tick stays 2 pt, which is
        /// what leaves ≥ 5.2 pt of gap. A tick that scaled with the pitch would close that gap
        /// into a solid bar exactly where the row is longest and the count matters most.
        public static let tickWidth = 2.0

        /// The dim rows — the unfilled remainder, the cap row, a Codex silhouette — are drawn
        /// at this fraction of the row's height.
        public static let dimHeightRatio = 0.45
    }

    public enum Ramp {
        /// §13.11 gives an explicit High Contrast value, so this is a **substitution**:
        /// it terminates resolution and is never also offset.
        public static func cellUnlitInk(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 0.40 : 0.25
        }

        public static let inertInk = 0.30

        // Geometry. Canon fixes the header width and the cell size on both devices (§4.1, §6.2)
        // and never fixes the Bench rail's gutter, so that one is derived rather than pinned as
        // a fifth constant that would disagree with the rail the day the rail moves.
        public static let dialCell = C.Size(width: 70, height: 48)
        public static let dialCellLarge = C.Size(width: 82, height: 62)
        public static let benchCell = C.Size(width: 56, height: 44)
        public static let headerWidth = 44.0
        public static let headerWidthLarge = 52.0

        /// Between cells only — the header abuts cell 1. The header and its four cells are one
        /// semantic group, and §12.8 exempts intra-group spacing from the 8 pt inter-target
        /// floor for exactly that reason. Between two *ramps* the gutter is inter-target.
        public static let dialGutter = 6.0
        public static let dialGutterLarge = 10.0

        /// §12.8: the Dial gutter tightens to 4 pt **at accessibility1 only** — not across
        /// xLarge–xxxLarge, where the table leaves it at 6. It is the only gutter in the app
        /// that moves with type size.
        public static let dialGutterAccessible = Space.s4

        /// The row's whole horizontal budget: §4.1's own sum on the compact device
        /// (`44 + 4 × 70 + 3 × 6`) and §6.2's on the large one (`52 + 4 × 82 + 3 × 10`).
        ///
        /// It exists because §12.8's Dynamic Type row does not fit: `44 + 4 × 84 + 3 × 6 = 398`
        /// on a 375 pt screen. A ramp cannot scroll horizontally anywhere in the design, so the
        /// budget binds the cell's **width** and Dynamic Type's growth lands in its height,
        /// where §13.11 already sanctions the region scrolling. See `DECISIONS.md` 46.
        public static let dialRowWidth = 342.0
        public static let dialRowWidthLarge = 410.0

        public static func benchGutter(railContent: Double) -> Double {
            max(Space.s4, (railContent - headerWidth - 4 * benchCell.width) / 4)
        }

        /// 1.0 → **2.0** under High Contrast, not 1.0 + 0.5. Another substitution.
        public static func cancelHatchWeight(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 2.0 : 1.0
        }
    }

    /// The leading 44 pt of every ramp — the one drawing canon names on five surfaces and never
    /// specifies. `attribute-header.md` §3 derives it: the attribute's **whole ladder drawn at
    /// once, in its own register**, so no value is selected and the header is a legend for the
    /// row rather than an emblem to memorise.
    public enum AttributeHeader {
        /// The hue rosette's spoke length, as a fraction of the box side. `0.273 · S / 2`.
        public static let hueSpokeRatio = 0.273 / 2

        /// The four hue spokes, degrees. The whole rotation ladder as one rosette.
        public static let hueSpokeDegrees: [Double] = [0, 45, 90, 135]

        /// The `pips` header's contour guide: hairline, so all four compass positions read as
        /// positions rather than as a fifth silhouette.
        public static let contourGuideInk = 0.55
    }
}
