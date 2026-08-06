public import SwiftUI

public import Glyphs
public import Tokens

/// §4.2's comparator mark, drawn **pictorially and never as ASCII**.
///
/// A construction, not an icon: the apex sits at the midpoint of one edge of the mark box and
/// the two limbs run to the two **far corners**, so the included angle is `2·atan(0.5)` by
/// construction. Writing the angle down instead means the day the mark box stops being square
/// the mark stops meeting its corners.
///
/// Spelled in `minX`/`maxX` of a rect SwiftUI has already flipped — `opensTrailing`, never
/// `opensRight` — so under RTL the wedge mirrors *with* its rail and its wide end still opens
/// physically toward the larger socket.
public nonisolated struct WedgeShape: Shape {
    public var comparator: Glyphs.Comparator

    public init(comparator: Glyphs.Comparator) { self.comparator = comparator }

    /// The limbs' box: square, clamped to **both** `C.Wedge.markSide` and the rect, and placed
    /// so that the whole mark — limbs *plus* the underbar's allowance — is centred.
    ///
    /// The allowance is reserved for all six comparators, not only the two that use it. That
    /// costs `eq` a point of height and buys the one thing a cycling control needs: the limbs
    /// sit in exactly the same place at every step, so tapping through six comparators does not
    /// make the mark jump. And a clipped `gte` loses its underbar and becomes `gt` — a different
    /// law, arrived at by shrinking a container.
    public nonisolated static func markBox(in rect: CGRect) -> CGRect {
        let allowance = 1 + C.Wedge.underbarDrop
        let side = min(C.Wedge.markSide, rect.width, rect.height / allowance)
        return CGRect(
            x: rect.midX - side / 2, y: rect.midY - side * allowance / 2, width: side,
            height: side)
    }

    /// Where the apex sits. `lt` opens toward the trailing edge, so its apex is leading.
    public nonisolated static func apexX(for comparator: Glyphs.Comparator, in rect: CGRect)
        -> Double
    {
        let box = markBox(in: rect)
        return switch comparator {
        case .lt, .lte: box.minX
        case .gt, .gte: box.maxX
        case .eq, .neq: box.midX
        }
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        let box = Self.markBox(in: rect)
        var path = Path()

        switch comparator {
        case .eq, .neq:
            // Two parallel bars; `neq` adds the slash and nothing else.
            for fraction in [0.36, 0.64] {
                let y = box.minY + box.height * fraction
                path.move(to: CGPoint(x: box.minX, y: y))
                path.addLine(to: CGPoint(x: box.maxX, y: y))
            }
            if comparator == .neq {
                path.move(to: CGPoint(x: box.minX + box.width * 0.2, y: box.maxY))
                path.addLine(to: CGPoint(x: box.maxX - box.width * 0.2, y: box.minY))
            }

        case .lt, .lte, .gt, .gte:
            let apex = CGPoint(x: Self.apexX(for: comparator, in: rect), y: box.midY)
            let farX = apex.x == box.minX ? box.maxX : box.minX
            path.move(to: CGPoint(x: farX, y: box.minY))
            path.addLine(to: apex)
            path.addLine(to: CGPoint(x: farX, y: box.maxY))
            if comparator == .lte || comparator == .gte {
                let y = box.maxY + box.height * C.Wedge.underbarDrop
                let inset = box.width * C.Wedge.underbarInset
                path.move(to: CGPoint(x: box.minX + inset, y: y))
                path.addLine(to: CGPoint(x: box.maxX - inset, y: y))
            }
        }
        return path
    }
}

extension Glyphs.Comparator {
    /// Tap the wedge to cycle. Declaration order, wrapping — six taps return you to where you
    /// started, which is what makes a wordless control learnable by exhaustion.
    public var next: Glyphs.Comparator {
        let all = Glyphs.Comparator.allCases
        guard let index = all.firstIndex(of: self) else { return .eq }
        return all[(index + 1) % all.count]
    }
}

/// §4.2's coupler: **one path, two paths that reunite, two paths that do not.** That progression
/// is the whole explanation, and all three are symmetric about the axis because the combinators
/// are commutative and RNF sorts their operands — an asymmetric OR would assert an order the AST
/// does not have.
public nonisolated struct CouplerShape: Shape {
    public var coupler: Coupler

    public init(coupler: Coupler) { self.coupler = coupler }

    public nonisolated static func strandCount(_ coupler: Coupler) -> Int {
        coupler == .and ? 1 : 2
    }

    public nonisolated static func weight(_ coupler: Coupler) -> Double {
        coupler == .and ? C.Coupler.weldWeight : C.Coupler.strandWeight
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let box = CGRect(
            x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let spread = side * C.Coupler.strandSpread
        var path = Path()

        switch coupler {
        case .and:
            // One welded bar, straight through.
            path.move(to: CGPoint(x: box.minX, y: box.midY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.midY))

        case .or:
            // Two strands that split and REJOIN — you may take either path.
            for direction in [-1.0, 1.0] {
                path.move(to: CGPoint(x: box.minX, y: box.midY))
                path.addCurve(
                    to: CGPoint(x: box.maxX, y: box.midY),
                    control1: CGPoint(x: box.midX - side * 0.2, y: box.midY + spread * direction),
                    control2: CGPoint(x: box.midX + side * 0.2, y: box.midY + spread * direction))
            }

        case .xor:
            // Two strands that CROSS and terminate — one path but not both.
            for direction in [-1.0, 1.0] {
                path.move(to: CGPoint(x: box.minX, y: box.midY + spread * direction))
                path.addLine(to: CGPoint(x: box.maxX, y: box.midY - spread * direction))
            }
        }
        return path
    }
}

/// §4.2's Fork: a railway switch whose incoming line originates at the **lit gate cell**.
///
/// The origin moving with the selection is the tile teaching itself: tap a different gate cell,
/// watch the line slide, and lit-routes-to-lit has been said without a word. A fixed origin
/// still looks right and teaches nothing, which is why this is a pure function with its own test
/// rather than a closure inside `path(in:)`.
public nonisolated struct TurnoutShape: Shape {
    public var litCellIndex: Int
    public var cellCount: Int

    public init(litCellIndex: Int, cellCount: Int = 4) {
        self.litCellIndex = litCellIndex
        self.cellCount = cellCount
    }

    public nonisolated static func originX(
        litCellIndex: Int, cellCount: Int, in rect: CGRect
    ) -> Double {
        guard cellCount > 0 else { return rect.midX }
        let clamped = min(max(0, litCellIndex), cellCount - 1)
        let cell = rect.width / Double(cellCount)
        return rect.minX + cell * (Double(clamped) + 0.5)
    }

    public nonisolated func path(in rect: CGRect) -> Path {
        let origin = CGPoint(
            x: Self.originX(litCellIndex: litCellIndex, cellCount: cellCount, in: rect),
            y: rect.minY)
        let separation = rect.height * C.Fork.trackSeparation
        var path = Path()
        // The lit track above, the dim track below; both leave the same point, which is what
        // makes the gate's selection the visible cause of the split.
        path.move(to: origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - separation))
        path.move(to: origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + separation))
        return path
    }
}
