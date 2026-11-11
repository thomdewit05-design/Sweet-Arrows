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

/// One candy on the board: glossy body, white arrow, and a badge for bombs and rainbows.
@MainActor
final class CandyNode: SKNode {
    let candyID: Int
    let isBomb: Bool
    private let body: SKNode
    private let arrow: SKNode

    init(piece: SlideGame.Piece, cellSize: CGFloat, colorBlind: Bool, style: Cosmetic = .classicCandy, art: CandyArt? = nil) {
        candyID = piece.id
        isBomb = piece.kind == .bomb
        let size = cellSize * 0.86

        let bodyRoot = SKNode()
        bodyRoot.addChild(CandyNode.bodySprite(color: piece.color, cellSize: cellSize, style: style, art: art))
        body = bodyRoot

        let arrowExtent = CGSize(width: size * 0.5, height: size * 0.6)
        let arrowKey = "arrow-\(Int(cellSize * 10))"
        let buildArrow = { CandyNode.makeArrow(size: size) }
        if let texture = art?.texture(key: arrowKey, extent: arrowExtent, build: buildArrow) {
            arrow = SKSpriteNode(texture: texture, size: arrowExtent)
        } else {
            arrow = buildArrow()
        }
        arrow.zRotation = CandyShapes.rotation(for: piece.direction)
        arrow.zPosition = 3

        super.init()
        isUserInteractionEnabled = false
        addChild(body)
        addChild(arrow)
        if colorBlind, piece.kind != .rainbow { addColorBlindMark(color: piece.color, size: size) }
        if piece.kind == .rainbow { addRainbowRing(size: size) }
        if piece.kind == .bomb { addBombBadge(size: size) }
        breathe()
    }

    /// A slow, gummy "breathing" so the board never looks frozen (off with Reduce Motion).
    private func breathe() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let duration = Double.random(in: 1.1...1.6)
        let squeeze = SKAction.scaleX(to: 1.025, y: 0.975, duration: duration)
        squeeze.timingMode = .easeInEaseOut
        let relax = SKAction.scale(to: 1, duration: duration)
        relax.timingMode = .easeInEaseOut
        body.run(.sequence([
            .wait(forDuration: Double.random(in: 0...1.2)),
            .repeatForever(.sequence([squeeze, relax])),
        ]), withKey: "idle")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Body (shadow + candy + shine), as a cached texture when possible.
    private static func bodySprite(color: CandyColor, cellSize: CGFloat, style: Cosmetic, art: CandyArt?) -> SKNode {
        // Real artwork wins when it is in the asset catalog ("candy-lemon", "candy-lemon-pastelCandy", ...).
        if let image = UIImage(named: "candy-\(color.rawValue)-\(style.rawValue)") ?? UIImage(named: "candy-\(color.rawValue)") {
            let side = cellSize * 0.92
            return SKSpriteNode(texture: SKTexture(image: image), size: CGSize(width: side, height: side))
        }
        let extent = CGSize(width: cellSize * 1.2, height: cellSize * 1.2)
        let key = "body-\(color.rawValue)-\(style.rawValue)-\(Int(cellSize * 10))"
        let build = { CandyNode.makeBody(color: color, cellSize: cellSize, style: style) }
        if let texture = art?.texture(key: key, extent: extent, build: build) {
            return SKSpriteNode(texture: texture, size: extent)
        }
        return build()
    }

    /// Rainbow candy: a turning ring in every candy color (it counts as each of them).
    private func addRainbowRing(size: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: size * 0.52)
        ring.strokeColor = UIColor.white
        ring.lineWidth = 3
        ring.zPosition = 1.5
        let colors = CandyColor.allCases.map(\.hex)
        for (index, hex) in colors.enumerated() {
            let arc = CGMutablePath()
            let start = CGFloat(index) / CGFloat(colors.count) * 2 * .pi
            arc.addArc(center: .zero, radius: size * 0.52, startAngle: start,
                       endAngle: start + 2 * .pi / CGFloat(colors.count), clockwise: false)
            let piece = SKShapeNode(path: arc)
            piece.strokeColor = UIColor(hex: hex)
            piece.lineWidth = 4
            ring.addChild(piece)
        }
        ring.run(.repeatForever(.rotate(byAngle: -2 * .pi, duration: 6)))
        addChild(ring)
    }

    private func addBombBadge(size: CGFloat) {
        let badge = SKShapeNode(circleOfRadius: size * 0.16)
        badge.fillColor = UIColor(hex: 0x2B2B3A)
        badge.strokeColor = .white
        badge.lineWidth = 1.5
        badge.position = CGPoint(x: size * 0.34, y: size * 0.34)
        badge.zPosition = 5
        let spark = SKShapeNode(path: CandyShapes.path(for: .star, size: size * 0.2))
        spark.fillColor = UIColor(hex: 0xFFC233)
        spark.strokeColor = .clear
        spark.position = CGPoint(x: size * 0.1, y: size * 0.12)
        badge.addChild(spark)
        spark.run(.repeatForever(.sequence([.scale(to: 1.3, duration: 0.3), .scale(to: 0.9, duration: 0.3)])))
        addChild(badge)
    }

    static let colorLetters: [CandyColor: String] = [
        .strawberry: "S", .lemon: "L", .mint: "M", .blueberry: "B", .orange: "O", .grape: "G",
    ]

    /// Extra symbol per color for color-blind players (on top of the unique shape).
    private func addColorBlindMark(color: CandyColor, size: CGFloat) {
        let label = SKLabelNode(text: CandyNode.colorLetters[color])
        label.fontName = Theme.spriteFontName
        label.fontSize = size * 0.22
        label.fontColor = UIColor(hex: 0x4A2C2A)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -size * 0.3, y: -size * 0.3)
        label.zPosition = 5
        addChild(label)
    }

    private static func makeBody(color: CandyColor, cellSize: CGFloat, style: Cosmetic) -> SKNode {
        let size = cellSize * 0.86
        let path = CandyShapes.path(for: color.shape, size: size)
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

        // Depth: a darker belly, clipped to the candy's own shape.
        let crop = SKCropNode()
        let mask = SKShapeNode(path: path)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        let belly = SKShapeNode(ellipseOf: CGSize(width: size * 1.3, height: size * 0.9))
        belly.fillColor = UIColor(hex: 0x4A2C2A, alpha: 0.16)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: size * 0.08, y: -size * 0.42)
        crop.addChild(belly)
        root.addChild(crop)

        let shineSize = size * 0.32
        let shine = SKShapeNode(ellipseOf: CGSize(width: shineSize, height: shineSize * 0.6))
        shine.fillColor = UIColor.white.withAlphaComponent(0.45)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -size * 0.16, y: size * 0.2)
        shine.zRotation = 0.5
        root.addChild(shine)
        let glint = SKShapeNode(circleOfRadius: size * 0.05)
        glint.fillColor = UIColor.white.withAlphaComponent(0.9)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -size * 0.24, y: size * 0.26)
        root.addChild(glint)

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

    // MARK: Animations

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

    /// The arrow turns, always clockwise.
    func turn(to direction: Direction, animated: Bool) {
        let target = CandyShapes.rotation(for: direction)
        guard animated else {
            arrow.zRotation = target
            return
        }
        var delta = target - arrow.zRotation
        while delta > 0 { delta -= 2 * .pi }
        while delta <= -2 * .pi { delta += 2 * .pi }
        let spin = SKAction.rotate(byAngle: delta, duration: 0.22)
        spin.timingMode = .easeOut
        arrow.run(spin)
    }

    /// Pops (line, bomb blast or hammer).
    func explode() {
        removeAllActions()
        run(.sequence([
            .group([.scale(to: 1.3, duration: 0.12), .fadeAlpha(to: 0.6, duration: 0.12)]),
            .group([.scale(to: 0.1, duration: 0.15), .fadeOut(withDuration: 0.15)]),
            .removeFromParent(),
        ]))
    }

    /// Pulses a few times (hint booster).
    func highlight() {
        let pulse = SKAction.sequence([.scale(to: 1.12, duration: 0.25), .scale(to: 1, duration: 0.25)])
        run(.repeat(pulse, count: 4), withKey: "hint")
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
