import SpriteKit
import SweetArrowsCore
import UIKit

/// The glass candy jar with its slots, at the bottom of the screen.
@MainActor
final class BagNode: SKNode {
    private let jar: SKShapeNode
    private var slotNodes: [SKShapeNode] = []
    private var candyNodes: [MiniCandyNode] = []
    private var capacity = 0
    private let slotSize: CGFloat
    private let width: CGFloat

    init(width: CGFloat, slotSize: CGFloat) {
        self.width = width
        self.slotSize = slotSize
        let height = slotSize * 1.5
        jar = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.4)
        jar.fillColor = UIColor(hex: 0xDDF3FF, alpha: 0.85)
        jar.strokeColor = UIColor.white
        jar.lineWidth = 4
        super.init()
        isUserInteractionEnabled = false

        let lid = SKShapeNode(rectOf: CGSize(width: width * 0.5, height: slotSize * 0.22), cornerRadius: slotSize * 0.1)
        lid.fillColor = UIColor(hex: 0xFF5C8A)
        lid.strokeColor = .clear
        lid.position = CGPoint(x: 0, y: height / 2 + slotSize * 0.06)
        addChild(jar)
        addChild(lid)

        let gloss = SKShapeNode(rectOf: CGSize(width: width * 0.8, height: slotSize * 0.12), cornerRadius: slotSize * 0.06)
        gloss.fillColor = UIColor.white.withAlphaComponent(0.6)
        gloss.strokeColor = .clear
        gloss.position = CGPoint(x: 0, y: height * 0.3)
        jar.addChild(gloss)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func slotPosition(_ index: Int) -> CGPoint {
        let spacing = min(slotSize * 1.12, (width - slotSize) / CGFloat(max(capacity, 1)))
        let start = -spacing * CGFloat(capacity - 1) / 2
        return CGPoint(x: start + spacing * CGFloat(index), y: -slotSize * 0.05)
    }

    /// Scene position of a slot, used as the landing point for flying candies.
    func landingPoint(for index: Int) -> CGPoint {
        let local = slotPosition(min(index, max(capacity - 1, 0)))
        return CGPoint(x: position.x + local.x, y: position.y + local.y)
    }

    /// Redraws the jar to match `bag`. `popped` triggers a little sugar puff.
    func show(_ bag: Bag, popped: Bool = false, landedSlot: Int? = nil) {
        if bag.capacity != capacity {
            capacity = bag.capacity
            slotNodes.forEach { $0.removeFromParent() }
            slotNodes = (0..<capacity).map { index in
                let slot = SKShapeNode(circleOfRadius: slotSize * 0.46)
                slot.fillColor = UIColor.white.withAlphaComponent(0.55)
                slot.strokeColor = UIColor(hex: 0xB9DDF0)
                slot.lineWidth = 1.5
                slot.position = slotPosition(index)
                addChild(slot)
                return slot
            }
        }
        candyNodes.forEach { $0.removeFromParent() }
        candyNodes = bag.slots.enumerated().map { index, color in
            let node = MiniCandyNode(color: color, size: slotSize * 0.8)
            node.position = slotPosition(index)
            node.zPosition = 2
            addChild(node)
            if index == landedSlot, !popped {
                node.setScale(0.4)
                node.run(.sequence([.scale(to: 1.15, duration: 0.1), .scale(to: 1, duration: 0.08)]))
            }
            return node
        }
        let freeSlots = bag.freeSlots
        for (index, slot) in slotNodes.enumerated() {
            // Warn when only one slot is left.
            let danger = freeSlots <= 1 && index >= bag.slots.count
            slot.strokeColor = danger ? UIColor(hex: 0xFF5C8A) : UIColor(hex: 0xB9DDF0)
            slot.lineWidth = danger ? 3 : 1.5
        }
        if popped { puff() }
    }

    func wobble() {
        run(.sequence([.scaleX(to: 1.04, y: 0.96, duration: 0.07), .scale(to: 1, duration: 0.12)]))
    }

    private func puff() {
        for i in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: slotSize * 0.18)
            dot.fillColor = UIColor.white
            dot.strokeColor = .clear
            dot.zPosition = 5
            dot.position = CGPoint(x: 0, y: slotSize * 0.2)
            addChild(dot)
            let angle = CGFloat(i) / 8 * 2 * .pi
            let move = SKAction.moveBy(x: cos(angle) * slotSize, y: sin(angle) * slotSize * 0.7, duration: 0.35)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, .fadeOut(withDuration: 0.35), .scale(to: 0.3, duration: 0.35)]), .removeFromParent()]))
        }
        wobble()
    }
}
