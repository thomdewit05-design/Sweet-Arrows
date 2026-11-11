import SpriteKit
import SweetArrowsCore
import UIKit

/// Renders candy bodies and arrows once per (shape, color, size) and reuses the textures.
/// Hundreds of SKShapeNodes each cost a draw call; cached sprites batch and keep 60 fps.
@MainActor
final class CandyArt {
    private weak var view: SKView?
    private var cache: [String: SKTexture] = [:]

    init(view: SKView?) {
        self.view = view
    }

    func texture(key: String, extent: CGSize, build: () -> SKNode) -> SKTexture? {
        if let cached = cache[key] { return cached }
        guard let view else { return nil }
        let node = build()
        let crop = CGRect(x: -extent.width / 2, y: -extent.height / 2, width: extent.width, height: extent.height)
        guard let texture = view.texture(from: node, crop: crop) else { return nil }
        cache[key] = texture
        return texture
    }
}

/// One candy on the board: glossy body, white arrow, and overlays for special elements.
@MainActor
final class CandyNode: SKNode {
    let candyID: Int
    private let body: SKNode
    private let arrow: SKNode
    private var caramel: SKShapeNode?
    private var ice: SKShapeNode?
    private var wrapper: SKNode?
    private var spinnerBadge: SKShapeNode?
    private let color: CandyColor

    init(state: CandyState, cellSize: CGFloat, colorBlind: Bool, style: Cosmetic = .classicCandy, art: CandyArt? = nil) {
        candyID = state.id
        color = state.color
        let size = cellSize * 0.86
        let bar = state.candy.bar
        let candyColor = state.color

        // Body (shadow + candy + shine), as a cached texture when possible.
        let extent = bar.map { $0 == .horizontal
            ? CGSize(width: cellSize * 2.1, height: cellSize * 1.2)
            : CGSize(width: cellSize * 1.2, height: cellSize * 2.1)
        } ?? CGSize(width: cellSize * 1.2, height: cellSize * 1.2)
        let barKey = bar?.rawValue ?? "single"
        let bodyKey = "body-\(candyColor.rawValue)-\(barKey)-\(style.rawValue)-\(Int(cellSize * 10))"
        let build = { CandyNode.makeBody(color: candyColor, bar: bar, cellSize: cellSize, style: style) }
        let bodyRoot = SKNode()
        if let texture = art?.texture(key: bodyKey, extent: extent, build: build) {
            bodyRoot.addChild(SKSpriteNode(texture: texture, size: extent))
        } else {
            bodyRoot.addChild(build())
        }
        body = bodyRoot

        let arrowExtent = CGSize(width: size * 0.5, height: size * 0.6)
        let arrowKey = "arrow-\(Int(cellSize * 10))"
        let buildArrow = { CandyNode.makeArrow(size: size) }
        if let texture = art?.texture(key: arrowKey, extent: arrowExtent, build: buildArrow) {
            arrow = SKSpriteNode(texture: texture, size: arrowExtent)
        } else {
            arrow = buildArrow()
        }
        arrow.zRotation = CandyShapes.rotation(for: state.direction)
        arrow.zPosition = 3

        super.init()
        isUserInteractionEnabled = false
        addChild(body)
        addChild(arrow)

        if let bar { addChocolateStripes(cellSize: cellSize, axis: bar) }
        if colorBlind { addColorBlindMark(size: size) }
        if state.candy.has(.rotating) { addSpinnerBadge(size: size) }
        if state.caramelIntact { addCaramel(size: size, bar: bar, cellSize: cellSize) }
        if state.frozen { addIce(size: size, bar: bar, cellSize: cellSize) }
        if !state.revealed { addWrapper(size: size, bar: bar, cellSize: cellSize) }
    }

    private static func makeBody(color: CandyColor, bar: Axis?, cellSize: CGFloat, style: Cosmetic) -> SKNode {
        let size = cellSize * 0.86
        let path = bar.map { CandyShapes.barPath(length: cellSize * 1.86, thickness: size, axis: $0) }
            ?? CandyShapes.path(for: color.shape, size: size)
        let root = SKNode()

        let shadow = SKShapeNode(path: path)
        shadow.fillColor = UIColor(hex: 0x4A2C2A, alpha: 0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -cellSize * 0.05)
        root.addChild(shadow)

        let candy = SKShapeNode(path: path)
        candy.fillColor = style == .pastelCandy ? UIColor.candy(color).mixed(with: .white, amount: 0.38) : UIColor.candy(color)
        candy.strokeColor = style == .goldenCandy ? UIColor(hex: 0xFFC233) : UIColor.white.withAlphaComponent(0.9)
        candy.lineWidth = max(2, cellSize * (style == .goldenCandy ? 0.08 : 0.05))
        candy.lineJoin = .round
        root.addChild(candy)

        let shineSize = size * 0.32
        let shine = SKShapeNode(ellipseOf: CGSize(width: shineSize, height: shineSize * 0.6))
        shine.fillColor = UIColor.white.withAlphaComponent(0.45)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -size * 0.16, y: size * 0.2)
        shine.zRotation = 0.5
        root.addChild(shine)

        if style == .sparkleCandy {
            // Three tiny glitter stars.
            for (x, y, r) in [(0.22, 0.18, 0.05), (0.12, -0.2, 0.035), (-0.22, -0.08, 0.03)] {
                let star = SKShapeNode(path: CandyShapes.path(for: .star, size: size * CGFloat(r) * 4))
                star.fillColor = .white
                star.strokeColor = .clear
                star.position = CGPoint(x: size * CGFloat(x), y: size * CGFloat(y))
                root.addChild(star)
            }
        }
        return root
    }

    private static func makeArrow(size: CGFloat) -> SKNode {
        let arrow = SKShapeNode(path: CandyShapes.arrowPath(size: size))
        arrow.fillColor = .white
        arrow.strokeColor = UIColor(hex: 0x4A2C2A, alpha: 0.35)
        arrow.lineWidth = 1.2
        return arrow
    }

    /// Gummy wobble when the candy is touched.
    func wobble() {
        body.removeAction(forKey: "wobble")
        let squish = SKAction.sequence([
            .scaleX(to: 1.12, y: 0.9, duration: 0.06),
            .scaleX(to: 0.95, y: 1.06, duration: 0.07),
            .scale(to: 1, duration: 0.08),
        ])
        body.run(squish, withKey: "wobble")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: State changes

    func turn(to direction: Direction, animated: Bool) {
        let target = CandyShapes.rotation(for: direction)
        guard animated else {
            arrow.zRotation = target
            return
        }
        // Always turn clockwise (negative in SpriteKit).
        var delta = target - arrow.zRotation
        while delta > 0 { delta -= 2 * .pi }
        while delta <= -2 * .pi { delta += 2 * .pi }
        let spin = SKAction.rotate(byAngle: delta, duration: 0.22)
        spin.timingMode = .easeOut
        arrow.run(spin)
    }

    func crack() {
        guard let caramel else { return }
        self.caramel = nil
        let burst = SKAction.group([.scale(to: 1.3, duration: 0.18), .fadeOut(withDuration: 0.18)])
        caramel.run(.sequence([burst, .removeFromParent()]))
        run(.sequence([.scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.1)]))
    }

    func melt() {
        guard let ice else { return }
        self.ice = nil
        ice.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 0.9, duration: 0.25)]), .removeFromParent()]))
    }

    func reveal() {
        guard let wrapper else { return }
        self.wrapper = nil
        wrapper.run(.sequence([.group([.fadeOut(withDuration: 0.2), .scaleX(to: 0.1, duration: 0.2)]), .removeFromParent()]))
    }

    /// Little wiggle used when a frozen candy is tapped.
    func shake() {
        let left = SKAction.moveBy(x: -3, y: 0, duration: 0.04)
        let right = SKAction.moveBy(x: 6, y: 0, duration: 0.08)
        run(.sequence([left, right, left]))
    }

    func highlight() {
        let pulse = SKAction.sequence([.scale(to: 1.12, duration: 0.25), .scale(to: 1, duration: 0.25)])
        run(.repeat(pulse, count: 3), withKey: "hint")
    }

    // MARK: Decorations

    private func overlayPath(size: CGFloat, bar: Axis?, cellSize: CGFloat) -> CGPath {
        if let bar { return CandyShapes.barPath(length: cellSize * 1.92, thickness: size * 1.08, axis: bar) }
        let s = size * 1.06
        return CGPath(
            roundedRect: CGRect(x: -s / 2, y: -s / 2, width: s, height: s),
            cornerWidth: s * 0.28, cornerHeight: s * 0.28, transform: nil
        )
    }

    private func addCaramel(size: CGFloat, bar: Axis?, cellSize: CGFloat) {
        let node = SKShapeNode(path: overlayPath(size: size, bar: bar, cellSize: cellSize))
        node.fillColor = UIColor(hex: 0xD98A2B, alpha: 0.55)
        node.strokeColor = UIColor(hex: 0xA85F12)
        node.lineWidth = 3
        node.zPosition = 2
        addChild(node)
        caramel = node
    }

    private func addIce(size: CGFloat, bar: Axis?, cellSize: CGFloat) {
        let node = SKShapeNode(path: overlayPath(size: size, bar: bar, cellSize: cellSize))
        node.fillColor = UIColor(hex: 0xBDEBFF, alpha: 0.65)
        node.strokeColor = UIColor.white
        node.lineWidth = 2
        node.zPosition = 4
        let glint = SKShapeNode(rectOf: CGSize(width: size * 0.5, height: size * 0.08), cornerRadius: size * 0.04)
        glint.fillColor = UIColor.white.withAlphaComponent(0.8)
        glint.strokeColor = .clear
        glint.zRotation = .pi / 4
        glint.position = CGPoint(x: size * 0.12, y: size * 0.12)
        node.addChild(glint)
        addChild(node)
        ice = node
    }

    private func addWrapper(size: CGFloat, bar: Axis?, cellSize: CGFloat) {
        let node = SKShapeNode(path: overlayPath(size: size, bar: bar, cellSize: cellSize))
        node.fillColor = UIColor(hex: 0xFFF4E6)
        node.strokeColor = UIColor(hex: 0xE0C9B0)
        node.lineWidth = 2
        node.zPosition = 2.5
        let label = SKLabelNode(text: "?")
        label.fontName = Theme.spriteFontName
        label.fontSize = size * 0.42
        label.fontColor = UIColor(hex: 0xC4A68A)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size * 0.24, y: size * 0.22)
        node.addChild(label)
        addChild(node)
        wrapper = node
    }

    private func addSpinnerBadge(size: CGFloat) {
        let badge = SKShapeNode(circleOfRadius: size * 0.14)
        badge.fillColor = UIColor(hex: 0x4A2C2A)
        badge.strokeColor = .white
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: size * 0.34, y: -size * 0.34)
        badge.zPosition = 5
        let arc = CGMutablePath()
        arc.addArc(center: .zero, radius: size * 0.07, startAngle: 0.4, endAngle: 2 * .pi - 0.4, clockwise: true)
        let swirl = SKShapeNode(path: arc)
        swirl.strokeColor = .white
        swirl.lineWidth = 1.5
        badge.addChild(swirl)
        addChild(badge)
        spinnerBadge = badge
    }

    private func addChocolateStripes(cellSize: CGFloat, axis: Axis) {
        for offset: CGFloat in [-0.32, 0.32] {
            let line = SKShapeNode(rectOf: axis == .horizontal
                ? CGSize(width: 2, height: cellSize * 0.6)
                : CGSize(width: cellSize * 0.6, height: 2))
            line.fillColor = UIColor.white.withAlphaComponent(0.35)
            line.strokeColor = .clear
            line.position = axis == .horizontal
                ? CGPoint(x: offset * cellSize, y: 0)
                : CGPoint(x: 0, y: offset * cellSize)
            line.zPosition = 1
            addChild(line)
        }
    }

    /// Extra symbol per color for color-blind players (on top of the unique shape).
    private func addColorBlindMark(size: CGFloat) {
        let marks: [CandyColor: String] = [
            .strawberry: "S", .lemon: "L", .mint: "M", .blueberry: "B", .orange: "O", .grape: "G",
        ]
        let label = SKLabelNode(text: marks[color])
        label.fontName = Theme.spriteFontName
        label.fontSize = size * 0.22
        label.fontColor = UIColor(hex: 0x4A2C2A)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -size * 0.3, y: -size * 0.3)
        label.zPosition = 5
        addChild(label)
    }
}

/// Small candy used inside the jar.
@MainActor
final class MiniCandyNode: SKShapeNode {
    convenience init(color: CandyColor, size: CGFloat) {
        self.init()
        path = CandyShapes.path(for: color.shape, size: size)
        fillColor = UIColor.candy(color)
        strokeColor = UIColor.white.withAlphaComponent(0.9)
        lineWidth = 2
        lineJoin = .round
    }
}

extension UIColor {
    /// Blends towards `other` by `amount` (0...1).
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount, alpha: a1 + (a2 - a1) * amount
        )
    }
}
