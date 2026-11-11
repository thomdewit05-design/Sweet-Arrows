import SpriteKit
import SweetArrowsCore
import UIKit

/// Light bulbs around the board, like the sign of a candy-shop arcade. A quick chase on good moves,
/// a steady chase during combo fever.
@MainActor
final class MarqueeLights: SKNode {
    private var bulbs: [SKShapeNode] = []
    private var running = false
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled
    private static let colors: [UIColor] = [UIColor(hex: 0xFFD23F), UIColor(hex: 0xFF5C8A), UIColor(hex: 0xFFFFFF)]

    /// Places the bulbs along a rounded rectangle.
    func layout(around rect: CGRect, cornerRadius: CGFloat, cell: CGFloat) {
        removeAllChildren()
        bulbs.removeAll()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let points = Self.points(along: path, spacing: max(cell * 0.42, 12))
        for (index, point) in points.enumerated() {
            let bulb = SKShapeNode(circleOfRadius: max(cell * 0.06, 2.5))
            bulb.fillColor = Self.colors[index % Self.colors.count]
            bulb.strokeColor = .clear
            bulb.glowWidth = reduceMotion ? 0 : max(cell * 0.05, 2)
            bulb.position = point
            bulb.alpha = 0.35
            addChild(bulb)
            bulbs.append(bulb)
        }
        if running { startLoop() }
    }

    /// A bright wave running once (or `loops` times) around the board.
    func chase(loops: Int = 1) {
        guard !reduceMotion, !running, !bulbs.isEmpty else { return }
        let step = 0.9 / Double(bulbs.count)
        for (index, bulb) in bulbs.enumerated() {
            bulb.removeAction(forKey: "chase")
            let blink = SKAction.sequence([
                .wait(forDuration: Double(index) * step),
                .fadeAlpha(to: 1, duration: 0.05),
                .fadeAlpha(to: 0.35, duration: 0.25),
            ])
            bulb.run(.repeat(blink, count: loops), withKey: "chase")
        }
    }

    /// Steady theatre chase (every third bulb lit, stepping round) while combo fever lasts.
    func setRunning(_ on: Bool) {
        guard on != running else { return }
        running = on
        if on { startLoop() } else { stopLoop() }
    }

    private func startLoop() {
        guard !reduceMotion else { return }
        for (index, bulb) in bulbs.enumerated() {
            bulb.removeAllActions()
            let phase = Double(index % 3) * 0.12
            bulb.run(.sequence([
                .wait(forDuration: phase),
                .repeatForever(.sequence([
                    .fadeAlpha(to: 1, duration: 0.04), .wait(forDuration: 0.1),
                    .fadeAlpha(to: 0.3, duration: 0.04), .wait(forDuration: 0.18),
                ])),
            ]), withKey: "loop")
        }
    }

    private func stopLoop() {
        for bulb in bulbs {
            bulb.removeAllActions()
            bulb.run(.fadeAlpha(to: 0.35, duration: 0.2))
        }
    }

    /// Evenly spaced points along a path (flattened into short line pieces).
    private static func points(along path: CGPath, spacing: CGFloat) -> [CGPoint] {
        var segments: [(CGPoint, CGPoint)] = []
        var start = CGPoint.zero
        var current = CGPoint.zero
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]
                start = current
            case .addLineToPoint:
                segments.append((current, e.points[0]))
                current = e.points[0]
            case .addQuadCurveToPoint, .addCurveToPoint:
                let end = e.type == .addQuadCurveToPoint ? e.points[1] : e.points[2]
                let control = e.points[0]
                var previous = current
                for k in 1...8 {
                    let t = CGFloat(k) / 8
                    let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
                    let next = CGPoint(x: a * current.x + b * control.x + c * end.x,
                                       y: a * current.y + b * control.y + c * end.y)
                    segments.append((previous, next))
                    previous = next
                }
                current = end
            case .closeSubpath:
                segments.append((current, start))
                current = start
            @unknown default:
                break
            }
        }
        var result: [CGPoint] = []
        var carry: CGFloat = 0
        for (a, b) in segments {
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            var d = carry
            while d < length {
                let t = d / length
                result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                d += spacing
            }
            carry = d - length
        }
        return result
    }
}

// MARK: Arcade effects

extension SlideEffects {
    /// Gold candy coins burst out of `origin` and arc up into the score. `arrived` runs when the first one lands.
    func coinShower(
        from origin: CGPoint, to target: CGPoint, count: Int, cell: CGFloat, arrived: @escaping @MainActor () -> Void
    ) {
        let coins = UIAccessibility.isReduceMotionEnabled ? min(count, 2) : count
        for index in 0..<coins {
            let coin = SKNode()
            let radius = cell * 0.17
            let body = SKShapeNode(circleOfRadius: radius)
            body.fillColor = UIColor(hex: 0xFFC233)
            body.strokeColor = UIColor(hex: 0xFFF1B8)
            body.lineWidth = radius * 0.25
            coin.addChild(body)
            let shine = SKShapeNode(ellipseOf: CGSize(width: radius * 0.7, height: radius * 0.4))
            shine.fillColor = UIColor.white.withAlphaComponent(0.7)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -radius * 0.25, y: radius * 0.3)
            coin.addChild(shine)
            coin.position = origin
            coin.zPosition = 8
            coin.setScale(0.1)
            addChild(coin)

            // First a little pop outwards, then an arc into the score.
            let angle = CGFloat(index) / CGFloat(max(coins, 1)) * 2 * .pi
            let burst = CGPoint(x: origin.x + cos(angle) * cell * 0.9, y: origin.y + sin(angle) * cell * 0.9)
            let control = CGPoint(x: (burst.x + target.x) / 2 + CGFloat.random(in: -cell...cell),
                                  y: max(burst.y, target.y) + cell * 1.5)
            let flight: CGFloat = 0.55
            let arc = SKAction.customAction(withDuration: flight) { node, elapsed in
                MainActor.assumeIsolated {
                    let t = min(elapsed / flight, 1)
                    let eased = t * t
                    let a = (1 - eased) * (1 - eased), b = 2 * (1 - eased) * eased, c = eased * eased
                    node.position = CGPoint(x: a * burst.x + b * control.x + c * target.x,
                                            y: a * burst.y + b * control.y + c * target.y)
                    node.setScale(1 - 0.5 * t)
                }
            }
            let flip = SKAction.repeatForever(.sequence([.scaleX(to: 0.2, duration: 0.12), .scaleX(to: 1, duration: 0.12)]))
            body.run(flip)
            let sequence = SKAction.sequence([
                .wait(forDuration: Double(index) * 0.04),
                .group([.scale(to: 1, duration: 0.12), .move(to: burst, duration: 0.18)]),
                arc,
                .removeFromParent(),
            ])
            if index == 0 {
                coin.run(sequence) { MainActor.assumeIsolated { arrived() } }
            } else {
                coin.run(sequence)
            }
        }
    }

    /// Slowly turning golden rays behind a big praise word.
    func sunburst(at position: CGPoint, level: Int, cell: CGFloat) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let rays = SKNode()
        rays.position = position
        rays.zPosition = 4
        let count = 14
        let length = cell * (2.2 + CGFloat(level) * 0.3)
        for i in 0..<count {
            let a0 = CGFloat(i) / CGFloat(count) * 2 * .pi
            let a1 = a0 + .pi / CGFloat(count)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: cos(a0) * length, y: sin(a0) * length))
            path.addLine(to: CGPoint(x: cos(a1) * length, y: sin(a1) * length))
            path.closeSubpath()
            let ray = SKShapeNode(path: path)
            ray.fillColor = (i.isMultiple(of: 2) ? UIColor(hex: 0xFFD23F) : UIColor.white).withAlphaComponent(0.4)
            ray.strokeColor = .clear
            rays.addChild(ray)
        }
        rays.setScale(0.2)
        rays.alpha = 0
        addChild(rays)
        rays.run(.rotate(byAngle: .pi / 2, duration: 1.4))
        rays.run(.sequence([
            .group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.15)]),
            .wait(forDuration: 0.6 + Double(level) * 0.08),
            .group([.scale(to: 1.2, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    /// Little four-point stars that twinkle around a spot.
    func twinkles(at position: CGPoint, cell: CGFloat, count: Int = 3) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for _ in 0..<count {
            let size = cell * CGFloat.random(in: 0.12...0.22)
            let star = SKShapeNode(path: CandyShapes.path(for: .star, size: size))
            star.fillColor = Bool.random() ? .white : UIColor(hex: 0xFFE27A)
            star.strokeColor = .clear
            star.position = CGPoint(x: position.x + CGFloat.random(in: -cell * 0.6...cell * 0.6),
                                    y: position.y + CGFloat.random(in: -cell * 0.6...cell * 0.6))
            star.setScale(0)
            star.zPosition = 6
            addChild(star)
            star.run(.sequence([
                .wait(forDuration: Double.random(in: 0...0.2)),
                .group([.scale(to: 1, duration: 0.15), .rotate(byAngle: .pi / 2, duration: 0.4)]),
                .group([.scale(to: 0, duration: 0.25), .fadeOut(withDuration: 0.25)]),
                .removeFromParent(),
            ]))
        }
    }

    /// A short white flash over everything, for the very biggest moves.
    func screenFlash(size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let flash = SKSpriteNode(color: .white, size: CGSize(width: size.width * 2, height: size.height * 2))
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.alpha = 0
        flash.zPosition = 20
        addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.05), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
