import SpriteKit
import SweetArrowsCore
import UIKit

/// The "juice" on top of the board: flashes, candy shards, praise words, screen shake and the
/// glowing combo frame. Pure presentation; the scene decides when to call what.
@MainActor
final class SlideEffects: SKNode {
    private var frameNode: SKShapeNode?
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled

    override init() {
        super.init()
        zPosition = 30
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Pops

    /// A white rounded flash where a candy popped.
    func flash(at position: CGPoint, cell: CGFloat, delay: Double = 0) {
        let glow = SKShapeNode(rectOf: CGSize(width: cell * 0.92, height: cell * 0.92), cornerRadius: cell * 0.22)
        glow.fillColor = .white
        glow.strokeColor = .clear
        glow.alpha = 0
        glow.position = position
        glow.zPosition = -2
        addChild(glow)
        glow.run(.sequence([
            .wait(forDuration: delay),
            .group([.fadeAlpha(to: 0.95, duration: 0.05), .scale(to: 1.08, duration: 0.05)]),
            .group([.fadeOut(withDuration: 0.25), .scale(to: 1.35, duration: 0.25)]),
            .removeFromParent(),
        ]))
    }

    /// A glowing streak along a popped line.
    func streak(from start: CGPoint, to end: CGPoint, cell: CGFloat, color: UIColor) {
        let length = hypot(end.x - start.x, end.y - start.y) + cell
        let bar = SKShapeNode(rectOf: CGSize(width: length, height: cell * 0.5), cornerRadius: cell * 0.25)
        bar.fillColor = color.mixed(with: .white, amount: 0.6)
        bar.strokeColor = .white
        bar.lineWidth = 2
        bar.glowWidth = cell * 0.15
        bar.position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        bar.zRotation = atan2(end.y - start.y, end.x - start.x)
        bar.zPosition = -1
        bar.yScale = 0.2
        bar.alpha = 0.9
        addChild(bar)
        bar.run(.sequence([
            .scaleY(to: 1.2, duration: 0.08),
            .group([.scaleY(to: 0.05, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent(),
        ]))
    }

    /// Candy shards fly out, spin and fall with a bit of gravity.
    func shards(at position: CGPoint, color: UIColor, cell: CGFloat, count: Int = 8, delay: Double = 0) {
        let pieces = reduceMotion ? min(count, 3) : count
        for i in 0..<pieces {
            let side = cell * CGFloat.random(in: 0.12...0.24)
            let shard = SKShapeNode(rectOf: CGSize(width: side, height: side * 0.8), cornerRadius: side * 0.25)
            shard.fillColor = i.isMultiple(of: 3) ? .white : color
            shard.strokeColor = .clear
            shard.position = position
            shard.alpha = 0
            addChild(shard)
            let angle = CGFloat(i) / CGFloat(pieces) * 2 * .pi + CGFloat.random(in: -0.4...0.4)
            let speed = cell * CGFloat.random(in: 1.4...2.6)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed + cell * 1.2
            let duration = Double.random(in: 0.55...0.8)
            let gravity = cell * 6
            let start = position
            let fly = SKAction.customAction(withDuration: duration) { node, elapsed in
                MainActor.assumeIsolated {
                    let t = CGFloat(elapsed)
                    node.position = CGPoint(x: start.x + vx * t, y: start.y + vy * t - gravity * t * t / 2)
                }
            }
            shard.run(.sequence([
                .wait(forDuration: delay),
                .fadeIn(withDuration: 0.01),
                .group([fly, .rotate(byAngle: CGFloat.random(in: -9...9), duration: duration),
                        .sequence([.wait(forDuration: duration * 0.6), .fadeOut(withDuration: duration * 0.4)])]),
                .removeFromParent(),
            ]))
        }
    }

    /// A ring that expands from a bomb.
    func shockwave(at position: CGPoint, cell: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: cell * 0.5)
        ring.strokeColor = UIColor(hex: 0xFFC233)
        ring.fillColor = UIColor(hex: 0xFFF1B8, alpha: 0.35)
        ring.lineWidth = cell * 0.12
        ring.position = position
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 3.4, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent(),
        ]))
    }

    // MARK: Words

    /// Big praise word (and an optional second line) that pops in, wobbles and floats away.
    func praise(_ text: String, subtitle: String?, level: Int, at position: CGPoint, cell: CGFloat) {
        let root = SKNode()
        root.position = position
        root.zPosition = 5
        let colors: [UInt32] = [0xFF5C8A, 0xFF9F1C, 0xA259FF, 0x3DDC97, 0x5B6CFF]
        let main = outlinedLabel(text, size: cell * (0.75 + CGFloat(min(level, 5)) * 0.1),
                                 fill: UIColor(hex: colors[level % colors.count]))
        root.addChild(main)
        if let subtitle {
            let sub = outlinedLabel(subtitle, size: cell * 0.55, fill: .white)
            sub.position = CGPoint(x: 0, y: -cell * 0.8)
            root.addChild(sub)
        }
        root.setScale(0.2)
        root.zRotation = -0.12
        addChild(root)
        let pop = SKAction.scale(to: 1.15, duration: 0.14)
        pop.timingMode = .easeOut
        root.run(.sequence([
            .group([pop, .rotate(toAngle: 0.04, duration: 0.14)]),
            .group([.scale(to: 1, duration: 0.1), .rotate(toAngle: 0, duration: 0.1)]),
            .wait(forDuration: 0.45 + Double(level) * 0.05),
            .group([.moveBy(x: 0, y: cell * 0.8, duration: 0.3), .fadeOut(withDuration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// "+30" floats up from where the candy landed.
    func points(_ value: Int, at position: CGPoint, cell: CGFloat, big: Bool) {
        let label = outlinedLabel("+\(value)", size: cell * (big ? 0.62 : 0.5), fill: .white)
        label.position = position
        addChild(label)
        label.setScale(0.6)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.12), .moveBy(x: 0, y: cell * 0.9, duration: 0.7)]),
            .fadeOut(withDuration: 0.2),
            .removeFromParent(),
        ]))
    }

    private func outlinedLabel(_ text: String, size: CGFloat, fill: UIColor) -> SKNode {
        let node = SKNode()
        for (offset, color, z) in [(CGPoint(x: 2, y: -3), UIColor(hex: 0x4A2C2A), 0.0), (.zero, fill, 1.0)] {
            let label = SKLabelNode(text: text)
            label.fontName = Theme.spriteFontName
            label.fontSize = size
            label.fontColor = color
            label.verticalAlignmentMode = .center
            label.position = offset
            label.zPosition = CGFloat(z)
            node.addChild(label)
        }
        // A thin white rim around the coloured text.
        if fill != .white {
            let rim = SKLabelNode(text: text)
            rim.fontName = Theme.spriteFontName
            rim.fontSize = size
            rim.fontColor = .white
            rim.verticalAlignmentMode = .center
            rim.position = CGPoint(x: -1, y: 1.5)
            rim.zPosition = 0.5
            node.addChild(rim)
        }
        return node
    }

    // MARK: Shake & fever

    /// Shakes a node (the board) harder for bigger moves.
    func shake(_ target: SKNode, strength: CGFloat) {
        guard !reduceMotion, strength > 0 else { return }
        target.removeAction(forKey: "shake")
        var steps: [SKAction] = []
        var amount = strength
        for _ in 0..<6 {
            let dx = CGFloat.random(in: -amount...amount)
            let dy = CGFloat.random(in: -amount...amount)
            steps.append(.move(to: CGPoint(x: dx, y: dy), duration: 0.035))
            amount *= 0.7
        }
        steps.append(.move(to: .zero, duration: 0.04))
        target.run(.sequence(steps), withKey: "shake")
    }

    /// Glowing frame around the board, cycling through the candy colors, while a combo runs.
    func setFever(_ on: Bool, around rect: CGRect, cornerRadius: CGFloat) {
        if on {
            guard frameNode == nil else { return }
            let frame = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
            frame.fillColor = .clear
            frame.lineWidth = 6
            frame.glowWidth = reduceMotion ? 2 : 10
            frame.strokeColor = UIColor(hex: 0xFF5C8A)
            frame.zPosition = -3
            frame.alpha = 0
            addChild(frame)
            frameNode = frame
            let colors = CandyColor.allCases.map { UIColor(hex: $0.hex) }
            let cycle = SKAction.customAction(withDuration: 2.4) { node, elapsed in
                MainActor.assumeIsolated {
                    let position = CGFloat(elapsed) / 2.4 * CGFloat(colors.count)
                    let index = Int(position) % colors.count
                    let next = (index + 1) % colors.count
                    let blend = position - floor(position)
                    (node as? SKShapeNode)?.strokeColor = colors[index].mixed(with: colors[next], amount: blend)
                }
            }
            frame.run(.sequence([.fadeIn(withDuration: 0.2), .repeatForever(.sequence([
                .fadeAlpha(to: 0.7, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3),
            ]))]))
            frame.run(.repeatForever(cycle))
        } else if let frame = frameNode {
            frameNode = nil
            frame.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
    }
}
