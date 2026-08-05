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
    /// `C.Glyph` and the model type `Glyphs.Glyph` are different modules and L2 is always
    /// written fully qualified, so there is no ambiguity at a call site.
    public enum Glyph {
        // ── Lengths, all ratios of the box side S (§13.5) ──────────────────
        public static func radius(side S: Double) -> Double { 0.37 * S }
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

    public enum Ramp {
        /// §13.11 gives an explicit High Contrast value, so this is a **substitution**:
        /// it terminates resolution and is never also offset.
        public static func cellUnlitInk(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 0.40 : 0.25
        }

        public static let inertInk = 0.30

        /// 1.0 → **2.0** under High Contrast, not 1.0 + 0.5. Another substitution.
        public static func cancelHatchWeight(in env: RenderEnv) -> Double {
            env.theme == .highContrast ? 2.0 : 1.0
        }
    }
}
