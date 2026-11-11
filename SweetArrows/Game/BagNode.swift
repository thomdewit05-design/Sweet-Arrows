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

    /// Redraws the jar to match `bag`; the slot that just received a candy bounces in.
    func show(_ bag: Bag, landedSlot: Int? = nil) {
        layoutSlots(capacity: bag.capacity)
        render(bag.slots, landedSlot: landedSlot)
        updateWarning(filled: bag.slots.count, free: bag.freeSlots)
    }

    /// Shows the three matching candies side by side, then pops them in a sugar cloud
    /// and settles on `bag` (the state after the pop).
    func showPop(_ bag: Bag, insertion: Bag.Insertion, color: CandyColor, completion: @escaping @MainActor () -> Void) {
        layoutSlots(capacity: bag.capacity)
        var before = bag.slots
        for index in insertion.popped.sorted() where index <= before.count {
            before.insert(color, at: index)
        }
        render(before, landedSlot: insertion.slot)
        let popped = insertion.popped.compactMap { $0 < candyNodes.count ? candyNodes[$0] : nil }
        guard !popped.isEmpty else {
            completion()
            return
        }
        let center = CGPoint(
            x: popped.map(\.position.x).reduce(0, +) / CGFloat(popped.count),
            y: popped.map(\.position.y).reduce(0, +) / CGFloat(popped.count)
        )
        for node in popped {
            let gather = SKAction.move(to: center, duration: 0.14)
            gather.timingMode = .easeIn
            node.run(.sequence([
                .wait(forDuration: 0.12),
                .group([gather, .scale(to: 1.25, duration: 0.14)]),
                .group([.scale(to: 0.1, duration: 0.1), .fadeOut(withDuration: 0.1)]),
            ]))
        }
        run(.wait(forDuration: 0.36)) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.puff(at: center, color: color)
                completion()
            }
        }
    }

    private func layoutSlots(capacity newCapacity: Int) {
        guard newCapacity != capacity else { return }
        capacity = newCapacity
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

    private func render(_ slots: [CandyColor], landedSlot: Int?) {
        candyNodes.forEach { $0.removeFromParent() }
        candyNodes = slots.enumerated().map { index, color in
            let node = MiniCandyNode(color: color, size: slotSize * 0.8)
            node.position = slotPosition(min(index, max(capacity - 1, 0)))
            node.zPosition = 2
            addChild(node)
            if index == landedSlot {
                node.setScale(0.4)
                let grow = SKAction.scale(to: 1.15, duration: 0.1)
                grow.timingMode = .easeOut
                node.run(.sequence([grow, .scale(to: 1, duration: 0.08)]))
            }
            return node
        }
    }

    private func updateWarning(filled: Int, free: Int) {
        for (index, slot) in slotNodes.enumerated() {
            // Warn when only one slot is left.
            let danger = free <= 1 && index >= filled
            slot.strokeColor = danger ? UIColor(hex: 0xFF5C8A) : UIColor(hex: 0xB9DDF0)
            slot.lineWidth = danger ? 3 : 1.5
            slot.removeAction(forKey: "danger")
            if danger {
                let pulse = SKAction.sequence([.fadeAlpha(to: 0.5, duration: 0.4), .fadeAlpha(to: 1, duration: 0.4)])
                slot.run(.repeatForever(pulse), withKey: "danger")
            } else {
                slot.alpha = 1
            }
        }
    }

    func wobble() {
        run(.sequence([.scaleX(to: 1.04, y: 0.96, duration: 0.07), .scale(to: 1, duration: 0.12)]))
    }

    /// Sugar cloud: white puffs plus sparkles in the candy's color.
    private func puff(at center: CGPoint, color: CandyColor) {
        for i in 0..<12 {
            let isSparkle = i.isMultiple(of: 3)
            let dot = SKShapeNode(circleOfRadius: slotSize * (isSparkle ? 0.1 : 0.2))
            dot.fillColor = isSparkle ? UIColor.candy(color) : UIColor.white
            dot.strokeColor = .clear
            dot.zPosition = 5
            dot.position = center
            addChild(dot)
            let angle = CGFloat(i) / 12 * 2 * .pi + CGFloat.random(in: -0.2...0.2)
            let reach = slotSize * CGFloat.random(in: 0.8...1.4)
            let move = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach * 0.8 + slotSize * 0.3, duration: 0.4)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, .fadeOut(withDuration: 0.4), .scale(to: 0.3, duration: 0.4)]), .removeFromParent()]))
        }
        wobble()
    }
}
