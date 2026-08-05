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
        /// The silhouette weight. The size regime is a **rule**, not a token.
        public static func bodyStroke(side: Double, in env: RenderEnv) -> Double {
            env.weight(side < 48 ? .bodySm : .body)
        }

        /// The light theme's keyline weight, or `nil` where no keyline is drawn.
        /// `+1.0` is a *geometric relationship* — the keyline must show 0.5 pt on each
        /// side of the hue — so it is derived from the already-resolved weight and is
        /// never itself multiplied or offset.
        public static func keylineStroke(side: Double, in env: RenderEnv) -> Double? {
            guard env.palette.glyphKeyline != nil else { return nil }
            return bodyStroke(side: side, in: env) + 1.0
        }

        /// Pass B widens the resolved stroke ×3 (§13.5). Derived last, like the keyline.
        public static func haloStroke(side: Double, in env: RenderEnv) -> Double {
            bodyStroke(side: side, in: env) * 3
        }
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
