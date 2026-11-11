import SpriteKit
import SweetArrowsCore
import UIKit

/// Draws the counter, the candies and the jar, turns taps into moves and animates the results.
/// Contains no game rules: everything comes from `GameSession` / `Game`.
@MainActor
final class GameScene: SKScene {
    let session: GameSession
    private let haptics: HapticsService
    private let audio: AudioService
    private let colorBlind: Bool
    private let boardStyle: Cosmetic
    private let candyStyle: Cosmetic

    /// When set, the next tap on a candy is handed here instead of playing it ("remove candy" booster).
    var onCandySelected: ((Int) -> Void)?
    /// Room SwiftUI needs between the board and the jar (booster bar).
    var boosterBarHeight: CGFloat = 0 { didSet { needsLayout = true } }

    /// Space SwiftUI uses above the board (HUD) and the scene keeps below it (jar).
    var topInset: CGFloat = 96 { didSet { needsLayout = true } }
    var bottomInset: CGFloat = 24 { didSet { needsLayout = true } }

    private let counter = SKShapeNode()
    private let candyLayer = SKNode()
    private var poleNodes: [SKNode] = []
    private var bag: BagNode?
    private var nodes: [Int: CandyNode] = [:]
    private var cell: CGFloat = 48
    private var boardOrigin = CGPoint.zero   // bottom-left of the board
    private var needsLayout = true
    private var launchCount = 0
    private var tutorialHand: SKNode?
    private var art: CandyArt?

    init(
        session: GameSession,
        haptics: HapticsService,
        audio: AudioService,
        colorBlind: Bool,
        boardStyle: Cosmetic = .woodCounter,
        candyStyle: Cosmetic = .classicCandy
    ) {
        self.session = session
        self.haptics = haptics
        self.audio = audio
        self.colorBlind = colorBlind
        self.boardStyle = boardStyle
        self.candyStyle = candyStyle
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(hex: 0xFFF4E6)
        anchorPoint = .zero
        addChild(counter)
        addChild(candyLayer)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        needsLayout = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        needsLayout = true
    }

    override func update(_ currentTime: TimeInterval) {
        if needsLayout, size.width > 0, size.height > 0 {
            needsLayout = false
            layoutBoard()
        }
    }

    // MARK: Layout

    private var level: Level { session.level }

    private func layoutBoard() {
        let safeTop = view?.safeAreaInsets.top ?? 0
        let safeBottom = view?.safeAreaInsets.bottom ?? 0
        let margin: CGFloat = 16
        let jarHeight: CGFloat = 96

        let availableWidth = size.width - margin * 2
        let top = size.height - safeTop - topInset
        let bottom = safeBottom + bottomInset + jarHeight + 20 + boosterBarHeight
        let availableHeight = max(top - bottom, 100)

        cell = min(availableWidth / CGFloat(level.width), availableHeight / CGFloat(level.height), 72)
        let boardSize = CGSize(width: cell * CGFloat(level.width), height: cell * CGFloat(level.height))
        boardOrigin = CGPoint(
            x: (size.width - boardSize.width) / 2,
            y: bottom + (availableHeight - boardSize.height) / 2
        )

        // Wooden counter with a soft shadow.
        let padding = cell * 0.25
        let rect = CGRect(origin: boardOrigin, size: boardSize).insetBy(dx: -padding, dy: -padding)
        counter.path = CGPath(roundedRect: rect, cornerWidth: cell * 0.4, cornerHeight: cell * 0.4, transform: nil)
        let palette = BoardPalette(boardStyle)
        counter.fillColor = palette.fill
        counter.strokeColor = palette.edge
        counter.lineWidth = 4
        counter.zPosition = -10
        counter.removeAllChildren()
        let shadow = SKShapeNode(path: counter.path!)
        shadow.fillColor = UIColor(hex: 0x4A2C2A, alpha: 0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        counter.addChild(shadow)
        for y in 0..<level.height {
            for x in 0..<level.width where (x + y).isMultiple(of: 2) {
                let tile = SKShapeNode(rect: CGRect(
                    x: boardOrigin.x + CGFloat(x) * cell, y: boardOrigin.y + CGFloat(level.height - 1 - y) * cell,
                    width: cell, height: cell
                ), cornerRadius: cell * 0.18)
                tile.fillColor = palette.tile
                tile.strokeColor = .clear
                counter.addChild(tile)
            }
        }

        art = CandyArt(view: view)
        tutorialHand?.removeFromParent()
        tutorialHand = nil

        bag?.removeFromParent()
        let jarWidth = min(size.width - margin * 2, 360)
        let newBag = BagNode(width: jarWidth, slotSize: min(52, (jarWidth - 24) / CGFloat(Bag.maxCapacity) * 1.25))
        newBag.position = CGPoint(x: size.width / 2, y: safeBottom + bottomInset + jarHeight / 2)
        addChild(newBag)
        bag = newBag

        rebuild()
    }

    func point(for cellPoint: GridPoint) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(cellPoint.x) + 0.5) * cell,
            y: boardOrigin.y + (CGFloat(level.height - cellPoint.y) - 0.5) * cell
        )
    }

    private func center(of state: CandyState) -> CGPoint {
        let points = state.cells.map(point(for:))
        let x = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let y = points.map(\.y).reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }

    private func gridPoint(at location: CGPoint) -> GridPoint? {
        let x = Int(floor((location.x - boardOrigin.x) / cell))
        let row = Int(floor((location.y - boardOrigin.y) / cell))
        let p = GridPoint(x, level.height - 1 - row)
        return level.contains(p) ? p : nil
    }

    /// Redraws every candy from the current game state (start, undo, restart, boosters).
    func rebuild() {
        guard cell > 0 else { return }
        candyLayer.removeAllChildren()
        nodes.removeAll()
        poleNodes.forEach { $0.removeFromParent() }
        poleNodes = level.poles.map(makePole)
        poleNodes.forEach(candyLayer.addChild)

        for state in session.game.remainingCandies {
            let node = CandyNode(state: state, cellSize: cell, colorBlind: colorBlind, style: candyStyle, art: art)
            node.position = center(of: state)
            candyLayer.addChild(node)
            nodes[state.id] = node
        }
        launchCount += 1  // cancels jar updates from animations still in flight
        bag?.show(session.game.bag)
        if let hinted = session.hintedCandy { nodes[hinted]?.highlight() }
        updateTutorialHand()
    }

    private func makePole(at p: GridPoint) -> SKNode {
        let node = SKNode()
        node.position = point(for: p)
        let stick = SKShapeNode(rectOf: CGSize(width: cell * 0.12, height: cell * 0.5), cornerRadius: cell * 0.06)
        stick.fillColor = .white
        stick.strokeColor = UIColor(hex: 0xE0C9B0)
        stick.position = CGPoint(x: 0, y: -cell * 0.18)
        let candy = SKShapeNode(circleOfRadius: cell * 0.3)
        candy.fillColor = UIColor(hex: 0xFF5C8A)
        candy.strokeColor = .white
        candy.lineWidth = 3
        candy.position = CGPoint(x: 0, y: cell * 0.1)
        let swirl = CGMutablePath()
        swirl.addArc(center: .zero, radius: cell * 0.16, startAngle: 0, endAngle: 1.6 * .pi, clockwise: false)
        let swirlNode = SKShapeNode(path: swirl)
        swirlNode.strokeColor = UIColor.white
        swirlNode.lineWidth = 3
        candy.addChild(swirlNode)
        node.addChild(stick)
        node.addChild(candy)
        return node
    }

    func showHint() {
        if let id = session.hintedCandy { nodes[id]?.highlight() }
    }

    // MARK: Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, session.status == .playing,
              let cellPoint = gridPoint(at: touch.location(in: self)),
              let state = session.game.candy(at: cellPoint)
        else { return }
        if let select = onCandySelected {
            onCandySelected = nil
            select(state.id)
            return
        }
        handleTap(on: state.id)
    }

    /// Public so UI tests and the tutorial can drive the board.
    func handleTap(on id: Int) {
        nodes[id]?.wobble()
        let report = session.tap(id)
        animate(report)
        updateTutorialHand()
        if report.status == .won { celebrate() }
    }

    // MARK: Animation

    private func animate(_ report: MoveReport) {
        switch report.result {
        case .launched(let launch):
            animateLaunch(launch)
        case .crackedCaramel(let id):
            nodes[id]?.crack()
            audio.play(.crack)
            haptics.tap()
        case .bounced(let bounce):
            animateBounce(bounce)
        case .frozen(let id):
            nodes[id]?.shake()
            haptics.bonk()
        case .ignored:
            break
        }
        for (id, direction) in report.rotated { nodes[id]?.turn(to: direction, animated: true) }
        for id in report.melted { nodes[id]?.melt() }
        if !report.melted.isEmpty { audio.play(.melt) }
        for id in report.revealed { nodes[id]?.reveal() }
    }

    private func animateLaunch(_ launch: Launch) {
        guard let node = nodes.removeValue(forKey: launch.candyID) else { return }
        audio.play(.squish)
        haptics.tap()
        launchCount += 1
        let move = LaunchedMove(
            launch: launch, bagAfter: session.game.bag, comboStep: session.comboStep, number: launchCount
        )
        let vector = CandyShapes.vector(for: launch.direction)
        let distance = CGFloat(launch.exitDistance) * cell + cell * 0.6
        // Gummy wiggle, then a quick ease-out slide (150–250 ms) off the counter.
        let wiggle = SKAction.sequence([
            .scaleX(to: 1.15, y: 0.87, duration: 0.05),
            .scaleX(to: 0.92, y: 1.08, duration: 0.05),
        ])
        let slide = SKAction.moveBy(x: vector.dx * distance, y: vector.dy * distance,
                                    duration: min(0.15 + 0.012 * Double(launch.exitDistance), 0.25))
        slide.timingMode = .easeOut
        node.zPosition = 20
        node.run(.sequence([wiggle, .group([slide, .scale(to: 1, duration: 0.1)])])) { [weak self, weak node] in
            MainActor.assumeIsolated {
                guard let self, let node else { return }
                self.flyToJar(node, move: move)
            }
        }
    }

    /// What the jar should show once a launched candy lands.
    private struct LaunchedMove {
        var launch: Launch
        var bagAfter: Bag
        var comboStep: Int
        var number: Int
    }

    /// Second half of a launch: the candy arcs from the board edge into its jar slot.
    private func flyToJar(_ node: CandyNode, move: LaunchedMove) {
        let launch = move.launch
        node.removeAllActions()
        let last = node.position
        let start = CGPoint(x: min(max(last.x, 20), size.width - 20), y: min(max(last.y, 40), size.height - 40))
        node.position = start
        let landing = bag?.landingPoint(for: launch.bag.slot) ?? CGPoint(x: size.width / 2, y: 60)
        let control = CGPoint(x: (start.x + landing.x) / 2, y: max(start.y, landing.y) + 80)
        let duration: CGFloat = 0.32
        let flight = SKAction.customAction(withDuration: duration) { target, elapsed in
            MainActor.assumeIsolated {
                let t = min(elapsed / duration, 1)
                let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
                target.position = CGPoint(
                    x: a * start.x + b * control.x + c * landing.x,
                    y: a * start.y + b * control.y + c * landing.y
                )
                target.setScale(1 - 0.45 * t)
            }
        }
        node.run(.sequence([flight, .removeFromParent()])) { [weak self] in
            MainActor.assumeIsolated {
                self?.land(move)
            }
        }
    }

    private func land(_ move: LaunchedMove) {
        audio.play(.tap)
        // A later launch already landed or is about to: let it draw the jar.
        guard move.number == launchCount else { return }
        let launch = move.launch
        if launch.bag.didPop {
            bag?.showPop(move.bagAfter, insertion: launch.bag, color: launch.color) { [weak self] in
                guard let self else { return }
                self.audio.play(.pop)
                self.audio.playCombo(move.comboStep)
                self.haptics.pop()
                if move.number == self.launchCount { self.bag?.show(self.session.game.bag) }
            }
        } else {
            bag?.show(move.bagAfter, landedSlot: launch.bag.slot)
        }
    }

    private func animateBounce(_ bounce: Bounce) {
        guard let node = nodes[bounce.candyID] else { return }
        audio.play(.bonk)
        haptics.bonk()
        let vector = CandyShapes.vector(for: bounce.direction)
        let distance = (CGFloat(bounce.distance) + 0.22) * cell
        let out = SKAction.moveBy(x: vector.dx * distance, y: vector.dy * distance,
                                  duration: 0.05 * Double(bounce.distance) + 0.07)
        out.timingMode = .easeIn
        let back = SKAction.moveBy(x: -vector.dx * distance, y: -vector.dy * distance, duration: 0.18)
        back.timingMode = .easeOut
        let squash = SKAction.sequence([.scaleX(to: 1.12, y: 0.88, duration: 0.05), .scale(to: 1, duration: 0.12)])
        node.run(.sequence([out, .group([back, squash])]))

        if case .candy(let otherID) = bounce.obstacle, let other = nodes[otherID] {
            let nudge = SKAction.moveBy(x: vector.dx * 4, y: vector.dy * 4, duration: 0.05)
            other.run(.sequence([.wait(forDuration: 0.05 * Double(bounce.distance) + 0.07), nudge, nudge.reversed()]))
        }
    }

    // MARK: Celebration

    /// Confetti in the candy colors, raining over the board.
    func celebrate() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let pieces = reduceMotion ? 16 : 70
        for i in 0..<pieces {
            let color = CandyColor.allCases[i % CandyColor.allCases.count]
            let piece = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 6...11), height: CGFloat.random(in: 10...16)),
                                    cornerRadius: 2)
            piece.fillColor = UIColor.candy(color)
            piece.strokeColor = .clear
            piece.zPosition = 50
            piece.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + CGFloat.random(in: 10...160))
            addChild(piece)
            let fallTime = Double.random(in: 1.4...2.4)
            let fall = SKAction.moveBy(x: CGFloat.random(in: -60...60), y: -(size.height + 220), duration: fallTime)
            fall.timingMode = .easeIn
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -8...8), duration: fallTime)
            piece.run(.sequence([
                .wait(forDuration: Double.random(in: 0...0.5)),
                .group([fall, spin]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: Tutorial

    /// On tutorial levels a pointing hand shows a safe next tap (levels 1–3).
    private var showsTutorialHand: Bool { level.tutorial && level.id <= 3 }

    private func updateTutorialHand() {
        guard showsTutorialHand, session.status == .playing, let target = tutorialTarget(),
              let state = session.game.candies[target]
        else {
            tutorialHand?.removeFromParent()
            tutorialHand = nil
            return
        }
        let hand = tutorialHand ?? makeHand()
        if hand.parent == nil { addChild(hand) }
        tutorialHand = hand
        let point = center(of: state)
        let rest = CGPoint(x: point.x + cell * 0.35, y: point.y - cell * 0.45)
        hand.removeAllActions()
        hand.position = rest
        let press = SKAction.sequence([
            .moveBy(x: -cell * 0.08, y: cell * 0.12, duration: 0.25),
            .scale(to: 0.9, duration: 0.1),
            .scale(to: 1, duration: 0.1),
            .moveBy(x: cell * 0.08, y: -cell * 0.12, duration: 0.25),
            .wait(forDuration: 0.4),
        ])
        hand.run(.sequence([.wait(forDuration: 0.6), .repeatForever(press)]))
    }

    /// The candy the tutorial points at: the next safe move.
    private func tutorialTarget() -> Int? {
        Solver(game: session.game, configuration: .hint).nextMove()
    }

    private func makeHand() -> SKNode {
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        let image = UIImage(systemName: "hand.point.up.left.fill", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        let outline = UIImage(systemName: "hand.point.up.left", withConfiguration: config)?
            .withTintColor(UIColor(hex: 0x4A2C2A), renderingMode: .alwaysOriginal)
        let node = SKNode()
        node.zPosition = 40
        for (img, z) in [(image, 0.0), (outline, 1.0)] {
            guard let img else { continue }
            let sprite = SKSpriteNode(texture: SKTexture(image: img))
            let scale = cell * 0.9 / max(img.size.width, 1)
            sprite.size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            sprite.anchorPoint = CGPoint(x: 0.25, y: 0.9)
            sprite.zPosition = CGFloat(z)
            node.addChild(sprite)
        }
        return node
    }
}

/// Counter colors for each board cosmetic.
struct BoardPalette {
    let fill: UIColor
    let edge: UIColor
    let tile: UIColor

    init(_ style: Cosmetic) {
        switch style {
        case .mintMarble:
            fill = UIColor(hex: 0xD6F5E8); edge = UIColor(hex: 0x9EDFC4); tile = UIColor(hex: 0xFFFFFF, alpha: 0.35)
        case .strawberryCheck:
            fill = UIColor(hex: 0xFFE1EA); edge = UIColor(hex: 0xFFB1C6); tile = UIColor(hex: 0xFF5C8A, alpha: 0.12)
        case .midnightCandy:
            fill = UIColor(hex: 0x3B2F5C); edge = UIColor(hex: 0x2A2145); tile = UIColor(hex: 0xFFFFFF, alpha: 0.08)
        default:
            fill = UIColor(hex: 0xF6D7B0); edge = UIColor(hex: 0xE9B98A); tile = UIColor(hex: 0xFFFFFF, alpha: 0.22)
        }
    }
}
