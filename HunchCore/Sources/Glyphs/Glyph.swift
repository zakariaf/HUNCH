/// One reading of the four independent attributes — the atom of the whole game.
///
/// The deck is exactly 256 of these and never grows (`GAME_DESIGN.md` §2, §5.7). Every
/// attribute occupies a spatially disjoint register of the drawing, which is why the four
/// value types are independent and why `HunchUI` can render each channel with the others
/// removed.
public struct Glyph: Hashable, Sendable, Codable {

    public enum Fill: UInt8, CaseIterable, Sendable, Codable {
        case hollow, dotted, striped, solid
        /// The visible rank, 1…4 — the number the ramp teaches and VoiceOver reads.
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Shape: UInt8, CaseIterable, Sendable, Codable {
        case circle, triangle, square, hexagon
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Pips: UInt8, CaseIterable, Sendable, Codable {
        case one, two, three, four
        public var rank: Int { Int(rawValue) + 1 }
    }

    public enum Hue: UInt8, CaseIterable, Sendable, Codable {
        case amber, teal, frost, rose
        public var rank: Int { Int(rawValue) + 1 }
    }

    /// The four attributes in the canonical `fill → shape → pips → hue` order (§2), which is
    /// the order of everything: VoiceOver labels, the deck sort, ramp rows on the Dial and the
    /// Bench, Codex page layout, AST commutative-operand sorting and serialisation.
    public enum Attribute: UInt8, CaseIterable, Sendable, Codable {
        case fill, shape, pips, hue
    }

    public let fill: Fill
    public let shape: Shape
    public let pips: Pips
    public let hue: Hue

    public init(fill: Fill, shape: Shape, pips: Pips, hue: Hue) {
        self.fill = fill
        self.shape = shape
        self.pips = pips
        self.hue = hue
    }

    /// §2's `glyphID`, `0…255` and stable forever: `fill*64 + shape*16 + pips*4 + hue`.
    ///
    /// It is the index into `Deck.all` and the bit position in `Bitboard256`, so it is on disk
    /// in every snapshot and every Codex page. Changing the packing invalidates saved games.
    public var id: Int {
        Int(fill.rawValue) << 6 | Int(shape.rawValue) << 4 | Int(pips.rawValue) << 2
            | Int(hue.rawValue)
    }

    /// The 0-based ordinal of `attribute` on this glyph; the visible rank is `ordinal + 1`.
    ///
    /// This is the accessor every mask, every relational comparison and every aggregate count
    /// goes through, so it is deliberately the *only* generic way to read an attribute.
    public func ordinal(of attribute: Attribute) -> Int {
        switch attribute {
        case .fill: Int(fill.rawValue)
        case .shape: Int(shape.rawValue)
        case .pips: Int(pips.rawValue)
        case .hue: Int(hue.rawValue)
        }
    }

    /// The 1-based rank of `attribute` — what the BNF's `RANK` means.
    public func rank(of attribute: Attribute) -> Int {
        ordinal(of: attribute) + 1
    }
}

extension Glyph.Shape {
    /// The achromatic discriminator for this channel (§13.5.1). `circle` is 0.
    ///
    /// A model fact, not a drawing fact: the accessibility layer reads it too, and putting it
    /// in `HunchUI` would mean VoiceOver imports the renderer to say "three pips".
    public var cornerCount: Int {
        switch self {
        case .circle: 0
        case .triangle: 3
        case .square: 4
        case .hexagon: 6
        }
    }
}

extension Glyph.Pips {
    /// The number of contour nodes drawn, 1…4. A four-arm switch rather than `rawValue + 1`
    /// because the raw values are frozen by `glyphID` and must not become load-bearing here.
    public var count: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .three: 3
        case .four: 4
        }
    }
}
