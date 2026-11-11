import SpriteKit
import SweetArrowsCore
import UIKit

/// Draws the slide & match board, turns taps into moves and animates slides, pops and new candies.
/// Contains no game rules: everything comes from `SlideSession` / `SlideGame`.
@MainActor
final class SlideScene: SKScene {
    let session: SlideSession
    private let haptics: HapticsService
    private let audio: AudioService
    private let colorBlind: Bool
    private let boardStyle: Cosmetic
    private let backdrop: Cosmetic
    private let backdropNode = SKSpriteNode()
    /// Pink haze over the backdrop during combo fever.
    private let feverTint = SKSpriteNode(color: UIColor(hex: 0xFF5C8A), size: .zero)
    private let candyStyle: Cosmetic

    /// Space SwiftUI uses above the board (HUD) and below it (booster bar).
    var topInset: CGFloat = 132 { didSet { needsLayout = true } }
    var bottomInset: CGFloat = 24 { didSet { needsLayout = true } }

    /// When set, the next tap on a candy is handed here instead of playing it (hammer booster).
    var onCandySelected: ((Int) -> Void)?

    /// Everything that shakes together: counter, candies and effects.
    private let boardRoot = SKNode()
    private let counter = SKShapeNode()
    private let candyLayer = SKNode()
    private let effects = SlideEffects()
    private let marquee = MarqueeLights()
    /// Time of the last idle sparkle on a random candy.
    private var lastGlint: TimeInterval = 0
    private var nodes: [Int: SKNode] = [:]
    /// Candy color per piece, for shards and streaks.
    private var colors: [Int: UIColor] = [:]
    private var boardFrame = CGRect.zero
    private var feverOn = false
    private var warningNode: SKNode?
    private var cell: CGFloat = 48
    private var boardOrigin = CGPoint.zero  // bottom-left of the board
    private var needsLayout = true
    private var art: CandyArt?
    private var tutorialHand: SKNode?

    private var run: SlideGame { session.run }

    init(
        session: SlideSession,
        haptics: HapticsService,
        audio: AudioService,
        colorBlind: Bool,
        boardStyle: Cosmetic = .woodCounter,
        candyStyle: Cosmetic = .classicCandy,
        backdrop: Cosmetic = .candyMeadow
    ) {
        self.backdrop = backdrop
        self.session = session
        self.haptics = haptics
        self.audio = audio
        self.colorBlind = colorBlind
        self.boardStyle = boardStyle
        self.candyStyle = candyStyle
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(hex: 0xFFF4E6)
        backdropNode.anchorPoint = .zero
        backdropNode.zPosition = -50
        addChild(backdropNode)
        feverTint.anchorPoint = .zero
        feverTint.zPosition = -49
        feverTint.alpha = 0
        addChild(feverTint)
        anchorPoint = .zero
        addChild(boardRoot)
        boardRoot.addChild(counter)
        boardRoot.addChild(candyLayer)
        boardRoot.addChild(effects)
        marquee.zPosition = -5
        boardRoot.addChild(marquee)
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
        // Combo fever: a glowing frame and a warmer background while pops keep coming.
        let fever = run.comboIsLive && run.combo >= 3 && !run.isOver
        // Now and then a candy catches the light.
        if currentTime - lastGlint > 2.8, !run.isOver, let node = nodes.values.randomElement() {
            lastGlint = currentTime
            effects.twinkles(at: node.position, cell: cell, count: 1)
        }
        if fever != feverOn {
            feverOn = fever
            marquee.setRunning(fever)
            effects.setFever(fever, around: boardFrame, cornerRadius: cell * 0.4)
            feverTint.removeAllActions()
            feverTint.run(fever
                ? .repeatForever(.sequence([.fadeAlpha(to: 0.22, duration: 0.4), .fadeAlpha(to: 0.12, duration: 0.4)]))
                : .fadeAlpha(to: 0, duration: 0.3))
        }
    }

    // MARK: Layout

    private func layoutBoard() {
        backdropNode.texture = SKTexture(image: BackdropArt.image(for: backdrop, size: size))
        backdropNode.size = size
        feverTint.size = size
        let safeTop = view?.safeAreaInsets.top ?? 0
        let safeBottom = view?.safeAreaInsets.bottom ?? 0
        let margin: CGFloat = 16
        let availableWidth = size.width - margin * 2
        let top = size.height - safeTop - topInset
        let bottom = safeBottom + bottomInset
        let availableHeight = max(top - bottom, 100)

        cell = min(availableWidth / CGFloat(run.width), availableHeight / CGFloat(run.height), 72)
        let boardSize = CGSize(width: cell * CGFloat(run.width), height: cell * CGFloat(run.height))
        boardOrigin = CGPoint(x: (size.width - boardSize.width) / 2, y: bottom + (availableHeight - boardSize.height) / 2)

        let padding = cell * 0.25
        let rect = CGRect(origin: boardOrigin, size: boardSize).insetBy(dx: -padding, dy: -padding)
        boardFrame = rect.insetBy(dx: -4, dy: -4)
        marquee.layout(around: rect.insetBy(dx: -10, dy: -10), cornerRadius: cell * 0.5, cell: cell)
        let path = CGPath(roundedRect: rect, cornerWidth: cell * 0.4, cornerHeight: cell * 0.4, transform: nil)
        counter.path = path
        let palette = BoardPalette(boardStyle)
        counter.fillColor = palette.fill
        counter.strokeColor = palette.edge
        counter.lineWidth = 4
        counter.zPosition = -10
        counter.removeAllChildren()
        let shadow = SKShapeNode(path: path)
        shadow.fillColor = UIColor(hex: 0x4A2C2A, alpha: 0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -6)
        shadow.zPosition = -1
        counter.addChild(shadow)
        for y in 0..<run.height {
            for x in 0..<run.width where (x + y).isMultiple(of: 2) {
                let tile = SKShapeNode(rect: CGRect(
                    x: boardOrigin.x + CGFloat(x) * cell, y: boardOrigin.y + CGFloat(run.height - 1 - y) * cell,
                    width: cell, height: cell
                ), cornerRadius: cell * 0.18)
                tile.fillColor = palette.tile
                tile.strokeColor = .clear
                counter.addChild(tile)
            }
        }
        art = CandyArt(view: view)
        rebuild()
    }

    func point(for p: GridPoint) -> CGPoint {
        CGPoint(
            x: boardOrigin.x + (CGFloat(p.x) + 0.5) * cell,
            y: boardOrigin.y + (CGFloat(run.height - p.y) - 0.5) * cell
        )
    }

    private func gridPoint(at location: CGPoint) -> GridPoint? {
        let x = Int(floor((location.x - boardOrigin.x) / cell))
        let row = Int(floor((location.y - boardOrigin.y) / cell))
        let p = GridPoint(x, run.height - 1 - row)
        return run.contains(p) ? p : nil
    }

    /// Redraws every candy from the current state (start, revive, new run).
    func rebuild() {
        guard cell > 0 else { return }
        candyLayer.removeAllChildren()
        nodes.removeAll()
        colors.removeAll()
        warningNode = nil
        for piece in run.sortedPieces {
            let node = makeNode(piece)
            candyLayer.addChild(node)
            nodes[piece.id] = node
        }
        if let pending = run.pending { showWarning(pending) }
        updateTutorialHand()
    }

    private func makeNode(_ piece: SlideGame.Piece) -> SKNode {
        let node: SKNode
        if piece.kind == .stone {
            node = makeStone()
        } else {
            node = CandyNode(piece: piece, cellSize: cell, colorBlind: colorBlind, style: candyStyle, art: art)
        }
        node.position = point(for: piece.position)
        colors[piece.id] = piece.kind == .stone ? UIColor(hex: 0xB9AFC4) : UIColor.candy(piece.color)
        return node
    }

    /// A grey rock candy without an arrow: it cannot move and breaks when a neighbour pops.
    private func makeStone() -> SKNode {
        let node = SKNode()
        let size = cell * 0.82
        let rock = SKShapeNode(rectOf: CGSize(width: size, height: size * 0.86), cornerRadius: size * 0.3)
        rock.fillColor = UIColor(hex: 0xB9AFC4)
        rock.strokeColor = UIColor(hex: 0x8E849B)
        rock.lineWidth = 3
        node.addChild(rock)
        for (dx, dy, r) in [(-0.18, 0.12, 0.09), (0.16, -0.1, 0.12), (0.2, 0.2, 0.06)] {
            let spot = SKShapeNode(circleOfRadius: size * r)
            spot.fillColor = UIColor(hex: 0x9C92A8)
            spot.strokeColor = .clear
            spot.position = CGPoint(x: size * dx, y: size * dy)
            rock.addChild(spot)
        }
        return node
    }

    // MARK: Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !run.isOver,
              let p = gridPoint(at: touch.location(in: self)),
              let piece = run.piece(at: p)
        else { return }
        if let select = onCandySelected {
            onCandySelected = nil
            select(piece.id)
            return
        }
        handleTap(on: piece.id)
    }

    /// Public so UI tests can drive the board.
    func handleTap(on id: Int) {
        let report = session.tap(id)
        animate(report)
        updateTutorialHand()
    }

    // MARK: Animation

    private func animate(_ report: SlideGame.Report) {
        switch report.move {
        case .slid(let id, let from, let to):
            guard let node = nodes[id] else { return }
            audio.play(.squish)
            haptics.tap()
            let distance = Double(abs(to.x - from.x) + abs(to.y - from.y))
            let slide = SKAction.move(to: point(for: to), duration: 0.06 + 0.035 * distance)
            slide.timingMode = .easeIn
            let squash = SKAction.sequence([
                .scaleX(to: 1.12, y: 0.88, duration: 0.05), .scale(to: 1, duration: 0.1),
            ])
            node.zPosition = 10
            node.run(.sequence([slide, squash])) { [weak self, weak node] in
                MainActor.assumeIsolated {
                    node?.zPosition = 0
                    self?.showPops(report, at: to)
                }
            }
        case .turned(let id, let direction):
            (nodes[id] as? CandyNode)?.turn(to: direction, animated: true)
            (nodes[id] as? CandyNode)?.wobble()
            audio.play(.tap)
            haptics.tap()
        case .ignored:
            haptics.bonk()  // a stone
        }
    }

    private func showPops(_ report: SlideGame.Report, at landing: GridPoint) {
        guard report.didPop else {
            audio.play(.tap)
            return
        }
        let level = report.celebration
        showStreaks(for: report.popped)
        for id in report.popped { popNode(id, delay: 0) }
        for id in report.exploded { popNode(id, delay: 0.08) }
        for id in report.brokenStones { popNode(id, delay: 0.12) }
        audio.play(.pop)
        audio.playCombo(report.combo)
        if report.exploded.isEmpty {
            haptics.burst(level)
        } else {
            audio.play(.crack)
            haptics.rumble()
        }
        let landingPoint = point(for: landing)
        effects.points(report.points, at: landingPoint, cell: cell, big: report.combo > 1 || level >= 3)
        celebrateArcade(level: level, from: landingPoint)
        let shakes: [CGFloat] = [0, 0, 3, 6, 9, 12]
        let blast: CGFloat = report.exploded.isEmpty ? 1 : 1.4
        effects.shake(boardRoot, strength: shakes[min(level, 5)] * blast)
        if let word = Self.praiseWord(for: level) {
            let combo = report.combo > 1
                ? String(localized: "Combo ×\(min(report.combo, SlideGame.maxComboMultiplier))") : nil
            let center = CGPoint(x: boardFrame.midX, y: boardFrame.midY + cell * 0.5)
            if level >= 3 { effects.sunburst(at: center, level: level, cell: cell) }
            effects.praise(word, subtitle: combo, level: level, at: center, cell: cell)
        }
        if report.clearedBoard { celebrate() }
    }

    /// The arcade touch: chasing lights, a shower of coins into the score and, for the biggest moves, a flash.
    private func celebrateArcade(level: Int, from origin: CGPoint) {
        guard level >= 2 else { return }
        marquee.chase(loops: level >= 4 ? 2 : 1)
        let coins = [0, 0, 3, 6, 9, 12][min(level, 5)]
        let safeTop = view?.safeAreaInsets.top ?? 0
        let scoreSpot = CGPoint(x: size.width / 2, y: size.height - safeTop - 40)
        effects.coinShower(from: origin, to: scoreSpot, count: coins, cell: cell) { [weak self] in
            self?.audio.play(.coin)
            self?.haptics.tap()
        }
        if level >= 4 { effects.screenFlash(size: size) }
    }

    /// Words that grow with the move (level 1, a plain line of three, gets none).
    static func praiseWord(for level: Int) -> String? {
        switch level {
        case 2: String(localized: "Sweet!")
        case 3: String(localized: "Tasty!")
        case 4: String(localized: "Sugar rush!")
        case 5: String(localized: "Board clear!")
        default: nil
        }
    }

    /// A glowing streak along every row or column of three or more that popped.
    private func showStreaks(for ids: [Int]) {
        let cells = ids.compactMap { id in nodes[id].map { (id, $0.position) } }
        var groups: [CGFloat: [(Int, CGPoint)]] = [:]
        var columns: [CGFloat: [(Int, CGPoint)]] = [:]
        for entry in cells {
            groups[(entry.1.y / 2).rounded(), default: []].append(entry)
            columns[(entry.1.x / 2).rounded(), default: []].append(entry)
        }
        for line in Array(groups.values) + Array(columns.values) where line.count >= 3 {
            let xs = line.map(\.1.x), ys = line.map(\.1.y)
            let start = CGPoint(x: xs.min() ?? 0, y: ys.min() ?? 0)
            let end = CGPoint(x: xs.max() ?? 0, y: ys.max() ?? 0)
            effects.streak(from: start, to: end, cell: cell, color: colors[line[0].0] ?? .white)
        }
    }

    private func popNode(_ id: Int, delay: Double) {
        guard let node = nodes.removeValue(forKey: id) else { return }
        let color = colors.removeValue(forKey: id) ?? .white
        effects.flash(at: node.position, cell: cell, delay: delay)
        effects.twinkles(at: node.position, cell: cell, count: 2)
        effects.shards(at: node.position, color: color, cell: cell, delay: delay)
        if (node as? CandyNode)?.isBomb == true {
            effects.shockwave(at: node.position, cell: cell)
        }
        if let candy = node as? CandyNode {
            candy.run(.wait(forDuration: delay)) { [weak candy] in
                MainActor.assumeIsolated { candy?.explode() }
            }
        } else {
            node.run(.sequence([
                .wait(forDuration: delay),
                .group([.scale(to: 1.2, duration: 0.1), .fadeOut(withDuration: 0.18)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: Boosters

    /// Hint: the candy pulses.
    func highlight(_ id: Int) {
        (nodes[id] as? CandyNode)?.highlight()
    }

    /// Hammer: the candy (or stone) is knocked off the board.
    func smashed(_ id: Int) {
        guard let node = nodes[id] else { return }
        audio.play(.crack)
        haptics.pop()
        let knock = SKAction.sequence([.scale(to: 0.8, duration: 0.06), .scale(to: 1.1, duration: 0.06)])
        node.run(knock) { [weak self] in
            MainActor.assumeIsolated { self?.popNode(id, delay: 0) }
        }
        updateTutorialHand()
    }

    /// Slow-down: the board turns a little blue while it lasts.
    func showSlowDown(_ active: Bool) {
        let tint = active ? UIColor(hex: 0xDDF3FF) : BoardPalette(boardStyle).fill
        counter.fillColor = tint
    }

    // MARK: Arrivals

    /// Pulsing shadow on the cell where the next candy will land.
    func showWarning(_ pending: SlideGame.PendingSpawn) {
        warningNode?.removeFromParent()
        let piece = pending.piece
        let shape = piece.kind == .stone ? CandyShape.square : piece.color.shape
        let tint = piece.kind == .stone ? UIColor(hex: 0x9C92A8) : UIColor.candy(piece.color)
        let shadow = SKShapeNode(path: CandyShapes.path(for: shape, size: cell * 0.8))
        shadow.fillColor = tint.withAlphaComponent(0.25)
        shadow.strokeColor = tint.withAlphaComponent(0.7)
        shadow.lineWidth = 2
        shadow.position = point(for: piece.position)
        shadow.zPosition = -1
        shadow.setScale(0.6)
        shadow.run(.repeatForever(.sequence([.scale(to: 1, duration: 0.25), .scale(to: 0.85, duration: 0.25)])))
        candyLayer.addChild(shadow)
        warningNode = shadow
    }

    func spawn(_ piece: SlideGame.Piece) {
        warningNode?.removeFromParent()
        warningNode = nil
        guard cell > 0, nodes[piece.id] == nil else { return }
        let node = makeNode(piece)
        node.setScale(0.2)
        node.alpha = 0
        candyLayer.addChild(node)
        nodes[piece.id] = node
        let grow = SKAction.scale(to: 1.12, duration: 0.14)
        grow.timingMode = .easeOut
        node.run(.sequence([.group([grow, .fadeIn(withDuration: 0.1)]), .scale(to: 1, duration: 0.08)]))
        audio.play(.tap)
    }

    func boardFull() {
        warningNode?.removeFromParent()
        warningNode = nil
        tutorialHand?.removeFromParent()
        tutorialHand = nil
        haptics.bonk()
        audio.play(.lose)
        let shake = SKAction.sequence([
            .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 12, y: 0, duration: 0.1), .moveBy(x: -6, y: 0, duration: 0.05),
        ])
        candyLayer.run(.repeat(shake, count: 2))
    }

    /// Confetti in the candy colors.
    func celebrate() {
        let pieces = UIAccessibility.isReduceMotionEnabled ? 16 : 70
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
            piece.run(.sequence([
                .wait(forDuration: Double.random(in: 0...0.5)),
                .group([fall, .rotate(byAngle: CGFloat.random(in: -8...8), duration: fallTime)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: First run help

    /// Until the first pop of a player's first runs, a hand points at a candy whose slide makes a line.
    var showsTutorialHand = false { didSet { updateTutorialHand() } }

    private func updateTutorialHand() {
        guard showsTutorialHand, run.popped == 0, !run.isOver, let target = tutorialTarget(),
              let node = nodes[target]
        else {
            tutorialHand?.removeFromParent()
            tutorialHand = nil
            return
        }
        let hand = tutorialHand ?? makeHand()
        if hand.parent == nil { addChild(hand) }
        tutorialHand = hand
        let rest = CGPoint(x: node.position.x + cell * 0.35, y: node.position.y - cell * 0.45)
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

    private func tutorialTarget() -> Int? { run.hint() }

    private func makeHand() -> SKNode {
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        let node = SKNode()
        node.zPosition = 40
        let images = [
            UIImage(systemName: "hand.point.up.left.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal),
            UIImage(systemName: "hand.point.up.left", withConfiguration: config)?
                .withTintColor(UIColor(hex: 0x4A2C2A), renderingMode: .alwaysOriginal),
        ]
        for (z, img) in images.enumerated() {
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
