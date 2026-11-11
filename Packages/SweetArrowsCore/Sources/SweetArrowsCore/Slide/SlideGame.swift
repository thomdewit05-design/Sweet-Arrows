/// "Slide & match", the main game.
///
/// Tap a candy and it slides along its arrow until it hits the edge or another candy.
/// Three or more of the same color in a row or column pop. A candy that cannot move turns its
/// arrow a quarter clockwise instead, so a tap always does something. New candies keep arriving,
/// faster and faster; when one has nowhere to land the run is over.
public struct SlideGame: Sendable {
    public struct Settings: Sendable, Hashable {
        public var width = 7
        public var height = 8
        public var startCandies = 12
        /// Seconds between candies at the start and at full speed.
        public var startInterval = 2.4
        public var fastestInterval = 0.7
        /// How long the warning shadow shows before a candy appears.
        public var warning = 1.0
        /// Candies popped per stage; every stage is a bit faster and may bring a color or a special candy.
        public var popsPerStage = 15
        /// Pops within this many seconds of each other build a combo.
        public var comboWindow = 3.0

        public init() {}
    }

    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case normal
        /// Pops everything around it (3×3) when it pops.
        case bomb
        /// Counts as every color.
        case rainbow
        /// Cannot move and has no color; breaks when a candy next to it pops.
        case stone
    }

    public struct Piece: Hashable, Sendable, Identifiable {
        public var id: Int
        public var color: CandyColor
        public var direction: Direction
        public var kind: Kind
        public var position: GridPoint

        public init(id: Int, color: CandyColor, direction: Direction, kind: Kind = .normal, position: GridPoint) {
            self.id = id
            self.color = color
            self.direction = direction
            self.kind = kind
            self.position = position
        }

        public var canMove: Bool { kind != .stone }

        /// The piece as a level candy, so it can be drawn with the same art (a rainbow wears the changer ring).
        public var candy: Candy {
            var features: Set<CandyFeature> = []
            if kind == .bomb { features.insert(.bomb) }
            if kind == .rainbow { features.insert(.colorChanger) }
            return Candy(id: id, color: color, position: position, direction: direction, features: features)
        }

        func matches(_ other: CandyColor) -> Bool {
            switch kind {
            case .rainbow: true
            case .stone: false
            case .normal, .bomb: color == other
            }
        }
    }

    public enum Status: Hashable, Sendable {
        case playing
        case boardFull
    }

    public enum Move: Hashable, Sendable {
        /// The candy slid from one cell to another.
        case slid(id: Int, from: GridPoint, to: GridPoint)
        /// It was blocked, so its arrow turned.
        case turned(id: Int, to: Direction)
        case ignored
    }

    public struct Report: Hashable, Sendable {
        public var move: Move
        /// Candies that popped in a line, then those blown away by bombs, then broken stones.
        public var popped: [Int] = []
        public var exploded: [Int] = []
        public var brokenStones: [Int] = []
        public var points = 0
        /// Pops in a row (1 for the first), 0 when nothing popped.
        public var combo = 0
        public var clearedBoard = false

        public var didPop: Bool { !popped.isEmpty }
    }

    /// A candy about to appear (shown as a shadow first).
    public struct PendingSpawn: Hashable, Sendable {
        public var piece: Piece
        public var remaining: Double
    }

    public enum Event: Hashable, Sendable {
        case warn(PendingSpawn)
        case spawned(Piece)
        case boardFull
        case stageUp(Int)
    }

    public static let maxComboMultiplier = 5

    public let settings: Settings
    public private(set) var pieces: [Int: Piece] = [:]
    public private(set) var status = Status.playing
    public private(set) var score = 0
    public private(set) var popped = 0
    public private(set) var moves = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    public private(set) var elapsed: Double = 0
    public private(set) var pending: PendingSpawn?
    public private(set) var revivesUsed = 0
    private var grid: [Int?]
    private var untilNext: Double
    private var lastPopAt: Double = -100
    private var announcedStage = 0
    private var nextID = 1
    private var rng: SeededRandom

    public init(seed: UInt64, settings: Settings = Settings()) {
        self.settings = settings
        rng = SeededRandom(seed: seed)
        grid = Array(repeating: nil, count: settings.width * settings.height)
        untilNext = settings.startInterval
        for _ in 0..<settings.startCandies {
            if let piece = makePiece() { place(piece) }
        }
    }

    /// Builds a game from a fixed board (tests, tutorials).
    public init(pieces: [Piece], settings: Settings = Settings(), seed: UInt64 = 1) {
        self.settings = settings
        rng = SeededRandom(seed: seed)
        grid = Array(repeating: nil, count: settings.width * settings.height)
        untilNext = settings.startInterval
        for piece in pieces {
            place(piece)
            nextID = max(nextID, piece.id + 1)
        }
    }

    // MARK: Board

    public var width: Int { settings.width }
    public var height: Int { settings.height }
    public var isOver: Bool { status != .playing }

    public func contains(_ p: GridPoint) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < settings.width && p.y < settings.height
    }

    public func piece(at p: GridPoint) -> Piece? {
        guard contains(p), let id = grid[index(p)] else { return nil }
        return pieces[id]
    }

    /// Pieces in a stable order (top row first).
    public var sortedPieces: [Piece] {
        pieces.values.sorted { ($0.position.y, $0.position.x) < ($1.position.y, $1.position.x) }
    }

    private func index(_ p: GridPoint) -> Int { p.y * settings.width + p.x }

    private mutating func place(_ piece: Piece) {
        pieces[piece.id] = piece
        grid[index(piece.position)] = piece.id
    }

    private mutating func remove(_ id: Int) {
        guard let piece = pieces.removeValue(forKey: id) else { return }
        grid[index(piece.position)] = nil
    }

    /// Where a candy would end up if tapped now (its own cell when blocked).
    public func destination(of piece: Piece) -> GridPoint {
        var p = piece.position
        while true {
            let next = p + piece.direction
            guard contains(next), self.piece(at: next) == nil else { return p }
            p = next
        }
    }

    // MARK: Difficulty

    public var stage: Int { popped / settings.popsPerStage }

    public var interval: Double {
        var value = settings.startInterval
        for _ in 0..<stage { value *= 0.92 }
        return max(settings.fastestInterval, value)
    }

    /// Three colors at first, one more every two stages, up to six.
    public var colorCount: Int { min(3 + (stage + 1) / 2, CandyColor.allCases.count) }

    /// Special candies unlock as the run goes on.
    public var unlockedKinds: [Kind] {
        var kinds: [Kind] = []
        if stage >= 1 { kinds.append(.bomb) }
        if stage >= 2 { kinds.append(.stone) }
        if stage >= 3 { kinds.append(.rainbow) }
        return kinds
    }

    // MARK: Playing

    public mutating func tap(_ id: Int) -> Report {
        guard status == .playing, var piece = pieces[id], piece.canMove else { return Report(move: .ignored) }
        moves += 1
        let target = destination(of: piece)
        guard target != piece.position else {
            piece.direction = piece.direction.rotated(by: 1)
            pieces[id] = piece
            return Report(move: .turned(id: id, to: piece.direction))
        }
        let from = piece.position
        remove(id)
        piece.position = target
        place(piece)
        var report = Report(move: .slid(id: id, from: from, to: target))
        resolve(into: &report)
        return report
    }

    /// Pops every line of three or more, then bombs and stones, and scores it.
    private mutating func resolve(into report: inout Report) {
        let lines = matchedIDs()
        guard !lines.isEmpty else { return }
        var gone = lines
        var exploded: [Int] = []
        // Bombs blow up their neighbours, and a bomb caught in a blast goes off too.
        var queue = lines.filter { pieces[$0]?.kind == .bomb }.sorted()
        while let bomb = queue.popLast() {
            guard let center = pieces[bomb]?.position else { continue }
            for dy in -1...1 {
                for dx in -1...1 {
                    guard let other = piece(at: GridPoint(center.x + dx, center.y + dy)), !gone.contains(other.id)
                    else { continue }
                    gone.insert(other.id)
                    exploded.append(other.id)
                    if other.kind == .bomb { queue.append(other.id) }
                }
            }
        }
        // Stones next to anything that popped break.
        var stones: [Int] = []
        for id in gone {
            guard let p = pieces[id]?.position else { continue }
            for direction in Direction.allCases {
                if let stone = piece(at: p + direction), stone.kind == .stone, !gone.contains(stone.id),
                   !stones.contains(stone.id) {
                    stones.append(stone.id)
                }
            }
        }
        report.popped = lines.sorted()
        report.exploded = exploded.sorted()
        report.brokenStones = stones.sorted()
        for id in gone { remove(id) }
        for id in stones { remove(id) }

        combo = elapsed - lastPopAt <= settings.comboWindow ? combo + 1 : 1
        lastPopAt = elapsed
        bestCombo = max(bestCombo, combo)
        let count = lines.count + exploded.count
        popped += count
        // 10 per candy, 20 for every candy beyond three in a line, times the combo.
        let base = 10 * count + 20 * max(lines.count - 3, 0) + 5 * stones.count
        var points = base * min(combo, SlideGame.maxComboMultiplier)
        if pieces.isEmpty {
            points += 100
            report.clearedBoard = true
            untilNext = min(untilNext, 0.5)
        }
        score += points
        report.points = points
        report.combo = combo
    }

    /// Candies in a horizontal or vertical run of three or more of one color.
    /// Rainbows count as every color, but a run needs at least one real color.
    func matchedIDs() -> Set<Int> {
        var result = Set<Int>()
        let rows = (0..<settings.height).map { y in (0..<settings.width).map { GridPoint($0, y) } }
        let columns = (0..<settings.width).map { x in (0..<settings.height).map { GridPoint(x, $0) } }
        for line in rows + columns {
            for color in CandyColor.allCases {
                var run: [Int] = []
                var colored = false
                for p in line {
                    if let piece = piece(at: p), piece.matches(color) {
                        run.append(piece.id)
                        if piece.kind != .rainbow { colored = true }
                    } else {
                        if run.count >= 3, colored { result.formUnion(run) }
                        run = []
                        colored = false
                    }
                }
                if run.count >= 3, colored { result.formUnion(run) }
            }
        }
        return result
    }

    // MARK: Time

    public mutating func advance(by seconds: Double) -> [Event] {
        guard status == .playing, seconds > 0 else { return [] }
        elapsed += seconds
        var events: [Event] = []
        if var next = pending {
            next.remaining -= seconds
            if next.remaining > 0 {
                pending = next
            } else {
                pending = nil
                var piece = next.piece
                if self.piece(at: piece.position) != nil || wouldMatch(piece) {
                    // the planned cell got taken: land somewhere else
                    guard let other = makePiece() else { return endRun(events) }
                    piece = other
                }
                place(piece)
                events.append(.spawned(piece))
            }
        } else {
            untilNext -= seconds
            if untilNext <= settings.warning {
                guard let piece = makePiece() else { return endRun(events) }
                let warning = PendingSpawn(piece: piece, remaining: max(untilNext, 0.05))
                pending = warning
                events.append(.warn(warning))
                untilNext = interval
            }
        }
        // Pops happen on taps; the stage change is announced with the next clock step.
        if stage > announcedStage {
            announcedStage = stage
            events.append(.stageUp(stage))
        }
        return events
    }

    private mutating func endRun(_ events: [Event]) -> [Event] {
        status = .boardFull
        pending = nil
        return events + [.boardFull]
    }

    // MARK: After the run

    public var canRevive: Bool { revivesUsed == 0 }

    /// Continue offer (once per run): takes a third of the candies away. Returns the removed ids.
    public mutating func revive() -> [Int] {
        guard status != .playing else { return [] }
        revivesUsed += 1
        var ids = pieces.keys.sorted()
        ids.shuffle(using: &rng)
        let removed = Array(ids.prefix(max(ids.count / 3, 6)))
        for id in removed { remove(id) }
        status = .playing
        pending = nil
        untilNext = interval * 2
        return removed.sorted()
    }

    public var coinsEarned: Int { score / 25 }

    // MARK: Spawning

    /// A new candy on a free cell that does not complete a line by itself, or nil when the board is full.
    mutating func makePiece() -> Piece? {
        let reserved = pending?.piece.position
        var free: [GridPoint] = []
        for y in 0..<settings.height {
            for x in 0..<settings.width {
                let p = GridPoint(x, y)
                if piece(at: p) == nil, p != reserved { free.append(p) }
            }
        }
        guard !free.isEmpty else { return nil }
        let palette = Array(CandyColor.allCases.prefix(colorCount))
        for _ in 0..<20 {
            let cell = free[Int(rng.next() % UInt64(free.count))]
            let direction = Direction.allCases[Int(rng.next() % 4)]
            let color = palette[Int(rng.next() % UInt64(palette.count))]
            let piece = Piece(id: nextID, color: color, direction: direction, kind: pickKind(), position: cell)
            if !wouldMatch(piece) {
                nextID += 1
                return piece
            }
        }
        // Every try lined up: look for any normal candy that does not.
        for color in palette.shuffled(using: &rng) {
            for cell in free {
                let piece = Piece(id: nextID, color: color, direction: .up, position: cell)
                if !wouldMatch(piece) {
                    nextID += 1
                    return piece
                }
            }
        }
        return nil
    }

    private mutating func pickKind() -> Kind {
        let kinds = unlockedKinds
        guard !kinds.isEmpty, rng.chance(0.1) else { return .normal }
        return kinds[Int(rng.next() % UInt64(kinds.count))]
    }

    /// Would placing this candy pop a line without the player doing anything?
    func wouldMatch(_ piece: Piece) -> Bool {
        guard self.piece(at: piece.position) == nil else { return true }
        var trial = self
        trial.place(piece)
        return trial.matchedIDs().contains(piece.id)
    }
}
