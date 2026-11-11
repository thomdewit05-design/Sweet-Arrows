import CoreGraphics
import SweetArrowsCore

/// Vector shapes for the candies, drawn in code until real artwork arrives (phase 4+).
/// All paths are centred on (0, 0) in SpriteKit coordinates (y points up).
enum CandyShapes {
    static func path(for shape: CandyShape, size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

        switch shape {
        case .circle:
            p.addEllipse(in: CGRect(x: -0.46 * s, y: -0.46 * s, width: 0.92 * s, height: 0.92 * s))

        case .square:
            p.addRoundedRect(
                in: CGRect(x: -0.42 * s, y: -0.42 * s, width: 0.84 * s, height: 0.84 * s),
                cornerWidth: 0.2 * s, cornerHeight: 0.2 * s
            )

        case .diamond:
            p.move(to: pt(0, 0.5))
            p.addQuadCurve(to: pt(0.46, 0), control: pt(0.28, 0.28))
            p.addQuadCurve(to: pt(0, -0.5), control: pt(0.28, -0.28))
            p.addQuadCurve(to: pt(-0.46, 0), control: pt(-0.28, -0.28))
            p.addQuadCurve(to: pt(0, 0.5), control: pt(-0.28, 0.28))
            p.closeSubpath()

        case .heart:
            p.move(to: pt(0, -0.44))
            p.addCurve(to: pt(-0.48, 0.1), control1: pt(-0.2, -0.26), control2: pt(-0.48, -0.12))
            p.addCurve(to: pt(0, 0.28), control1: pt(-0.48, 0.44), control2: pt(-0.08, 0.5))
            p.addCurve(to: pt(0.48, 0.1), control1: pt(0.08, 0.5), control2: pt(0.48, 0.44))
            p.addCurve(to: pt(0, -0.44), control1: pt(0.48, -0.12), control2: pt(0.2, -0.26))
            p.closeSubpath()

        case .star:
            let points = 5
            for i in 0..<(points * 2) {
                let radius: CGFloat = i.isMultiple(of: 2) ? 0.5 : 0.24
                let angle = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
                let point = CGPoint(x: cos(angle) * radius * s, y: sin(angle) * radius * s - 0.03 * s)
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()

        case .drop:
            p.move(to: pt(0, 0.5))
            p.addQuadCurve(to: pt(0.38, -0.08), control: pt(0.32, 0.2))
            p.addArc(center: pt(0, -0.12), radius: 0.382 * s, startAngle: 0.105, endAngle: .pi - 0.105, clockwise: true)
            p.addQuadCurve(to: pt(0, 0.5), control: pt(-0.32, 0.2))
            p.closeSubpath()
        }
        return p
    }

    /// Chocolate bar spanning two cells.
    static func barPath(length: CGFloat, thickness: CGFloat, axis: Axis) -> CGPath {
        let w = axis == .horizontal ? length : thickness
        let h = axis == .horizontal ? thickness : length
        return CGPath(
            roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h),
            cornerWidth: thickness * 0.3, cornerHeight: thickness * 0.3, transform: nil
        )
    }

    /// White arrow pointing up; rotate the node for other directions.
    static func arrowPath(size s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 0.26 * s))
        p.addLine(to: CGPoint(x: 0.17 * s, y: 0.06 * s))
        p.addLine(to: CGPoint(x: 0.06 * s, y: 0.06 * s))
        p.addLine(to: CGPoint(x: 0.06 * s, y: -0.22 * s))
        p.addLine(to: CGPoint(x: -0.06 * s, y: -0.22 * s))
        p.addLine(to: CGPoint(x: -0.06 * s, y: 0.06 * s))
        p.addLine(to: CGPoint(x: -0.17 * s, y: 0.06 * s))
        p.closeSubpath()
        return p
    }

    /// SpriteKit rotation for an arrow that points up when unrotated.
    static func rotation(for direction: Direction) -> CGFloat {
        switch direction {
        case .up: 0
        case .right: -.pi / 2
        case .down: .pi
        case .left: .pi / 2
        }
    }

    /// Unit vector in SpriteKit coordinates (y up).
    static func vector(for direction: Direction) -> CGVector {
        CGVector(dx: CGFloat(direction.dx), dy: CGFloat(-direction.dy))
    }
}
