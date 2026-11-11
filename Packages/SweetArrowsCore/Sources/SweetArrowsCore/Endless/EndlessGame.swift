/// The endless mode: candies keep arriving on a small board, faster and faster, until the board
/// or the jar is full. No levels, just a score to beat.
///
/// Fairness: a new candy only ever arrives pointing in a direction that keeps the board solvable
/// when the jar is ignored (no two candies blocking each other forever, never straight at a pole),
/// and its color often matches something already in the jar.
public struct EndlessGame: Sendable {
    public struct Settings: Sendable, Hashable {
        public var width = 6
        public var height = 6
        public var bagCapacity = 5
        public var startCandies = 8
        /// Seconds between candies at the start and at full speed.
        public var startInterval = 2.6
        public var fastestInterval = 0.8
        /// How long the warning shadow shows before a candy appears.
        public var warning = 1.0
        /// Pops per stage; every stage is a bit faster and may bring a new color or element.
        public var popsPerStage = 6

        public init() {}
    }

    /// A candy that is about to appear (shown as a shadow first).
    public struct PendingSpawn: Hashable, Sendable {
        public var candy: Candy
        /// Seconds until it appears.
        public var remaining: Double
    }

    public enum Event: Hashable, Sendable {
        /// A shadow appeared where a candy will land.
        case warn(PendingSpawn)
        /// A candy landed.
        case spawned(CandyState)
        /// No free cell: the run is over.
        case boardFull
        /// The stage went up (faster, maybe a new color or element).
        case stageUp(Int)
    }

    /// Pops in a row multiply their points, up to this.
    public static let maxComboMultiplier = 5

    public let settings: Settings
    public private(set) var game: Game
    public private(set) var score = 0
    public private(set) var pops = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    public private(set) var elapsed: Double = 0
    public private(set) var pending: PendingSpawn?
    public private(set) var revivesUsed = 0
    private var untilNext: Double
    private var lastPopAt: Double = -100
    private var nextID = 1
    private var rng: SeededRandom

    public init(seed: UInt64, settings: Settings = Settings()) {
        self.settings = settings
        rng = SeededRandom(seed: seed)
        let board = Level(
            id: 0, width: settings.width, height: settings.height, bagCapacity: settings.bagCapacity,
            hearts: 1, candies: [], changerColors: CandyColor.allCases
        )
        game = Game(level: board, endless: true)
        untilNext = settings.startInterval
        for _ in 0..<settings.startCandies {
            if let candy = makeCandy() { game.spawn(candy) }
        }
    }

    // MARK: Difficulty

    /// 0, 1, 2… goes up every few pops.
    public var stage: Int { pops / settings.popsPerStage }

    /// Seconds between new candies right now.
    public var interval: Double {
        max(settings.fastestInterval, settings.startInterval * pow(0.9, Double(stage)))
    }

    /// Colors in play: three at first, one more every two stages, up to six.
    public var colorCount: Int { min(3 + stage / 2, CandyColor.allCases.count) }

    /// Special candies unlock as the run goes on.
    public var unlockedFeatures: [CandyFeature] {
        var features: [CandyFeature] = []
        if stage >= 2 { features.append(.caramel) }
        if stage >= 3 { features.append(.bomb) }
        if stage >= 5 { features.append(.wrapped) }
        if stage >= 6 { features.append(.colorChanger) }
        if stage >= 8 { features.append(.rotating) }
        return features
    }

    public var status: GameStatus { game.status }
    public var isOver: Bool { game.status.isOver }

    // MARK: Playing

    /// Taps a candy. Scores launches, pops and combos.
    public mutating func tap(_ id: Int) -> MoveReport {
        let report = game.tap(id)
        guard case .launched(let launch) = report.result else { return report }
        score += 1 + report.exploded.count
        if launch.bag.didPop {
            pops += 1
            // Pops within three seconds of each other build a combo.
            combo = elapsed - lastPopAt <= 3 ? combo + 1 : 1
            bestCombo = max(bestCombo, combo)
            lastPopAt = elapsed
            score += 10 * min(combo, EndlessGame.maxComboMultiplier)
        }
        if game.candies.isEmpty {
            score += 50  // cleared the board
            untilNext = min(untilNext, 0.5)
        }
        return report
    }

    /// Advances the clock; returns what happened (shadows, new candies, a full board).
    public mutating func advance(by seconds: Double) -> [Event] {
        guard game.status == .playing, seconds > 0 else { return [] }
        let stageBefore = stage
        elapsed += seconds
        var events: [Event] = []

        if var next = pending {
            next.remaining -= seconds
            if next.remaining <= 0 {
                pending = nil
                if let state = game.spawn(next.candy) {
                    events.append(.spawned(state))
                } else if let retry = makeCandy(), let state = game.spawn(retry) {
                    events.append(.spawned(state))  // the planned cell got taken: land elsewhere
                } else {
                    game.endRun(.boardFull)
                    events.append(.boardFull)
                    return events
                }
            } else {
                pending = next
            }
        } else {
            untilNext -= seconds
            if untilNext <= settings.warning {
                if let candy = makeCandy() {
                    let warning = PendingSpawn(candy: candy, remaining: max(untilNext, 0.05))
                    pending = warning
                    events.append(.warn(warning))
                } else {
                    game.endRun(.boardFull)
                    events.append(.boardFull)
                    return events
                }
                untilNext = interval
            }
        }
        if stage > stageBefore { events.append(.stageUp(stage)) }
        return events
    }

    /// Continue offer (once per run): clears the jar and takes a third of the candies away.
    public mutating func revive() -> [Int] {
        guard game.status.isOver else { return [] }
        revivesUsed += 1
        let ids = game.remainingCandies.map(\.id)
        var shuffled = ids
        shuffled.shuffle(using: &rng)
        let removed = Array(shuffled.prefix(max(ids.count / 3, 4)))
        game.revive(removing: removed)
        pending = nil
        untilNext = interval * 2
        return removed.sorted()
    }

    public var canRevive: Bool { revivesUsed == 0 }

    /// Coins for a finished run.
    public var coinsEarned: Int { score / 10 }

    // MARK: Spawning

    /// A fair new candy on a free cell, or nil when the board is full.
    mutating func makeCandy() -> Candy? {
        let free = freeCells()
        guard !free.isEmpty else { return nil }
        let palette = Array(CandyColor.allCases.prefix(colorCount))
        for _ in 0..<12 {
            let cell = free[Int(rng.next() % UInt64(free.count))]
            for direction in Direction.allCases.shuffled(using: &rng) {
                var candy = Candy(id: nextID, color: pickColor(palette), position: cell, direction: direction)
                if let feature = pickFeature() { candy.features.insert(feature) }
                if candy.has(.colorChanger) {
                    // keep cycling within the colors in play
                    candy.features.remove(.colorChanger)
                    if colorCount > 1 { candy.features.insert(.colorChanger) }
                }
                if staysSolvable(adding: candy) {
                    nextID += 1
                    return candy
                }
            }
        }
        return nil
    }

    private func freeCells() -> [GridPoint] {
        var cells: [GridPoint] = []
        let reserved = pending.map { Set($0.candy.cells) } ?? []
        for y in 0..<settings.height {
            for x in 0..<settings.width {
                let p = GridPoint(x, y)
                if game.candy(at: p) == nil, !reserved.contains(p) { cells.append(p) }
            }
        }
        return cells
    }

    /// Half the time a color that is already waiting in the jar, so triples stay within reach.
    private mutating func pickColor(_ palette: [CandyColor]) -> CandyColor {
        let waiting = game.bag.slots.filter(palette.contains)
        if !waiting.isEmpty, rng.chance(0.5) {
            return waiting[Int(rng.next() % UInt64(waiting.count))]
        }
        return palette[Int(rng.next() % UInt64(palette.count))]
    }

    private mutating func pickFeature() -> CandyFeature? {
        let features = unlockedFeatures
        guard !features.isEmpty, rng.chance(0.12) else { return nil }
        return features[Int(rng.next() % UInt64(features.count))]
    }

    /// Ignoring the jar: can every candy, including the new one, still get off the board in some order?
    /// Peels off every candy with a clear route until nothing changes.
    private func staysSolvable(adding candy: Candy) -> Bool {
        var trial = game
        guard trial.spawn(candy) != nil else { return false }
        var progress = true
        while !trial.candies.isEmpty, progress {
            progress = false
            for state in trial.remainingCandies {
                let free: Bool
                if state.candy.has(.rotating) {
                    free = Direction.allCases.contains { direction in
                        var turned = state
                        turned.direction = direction
                        return trial.trace(for: turned).isClear
                    }
                } else {
                    free = trial.trace(for: state).isClear
                }
                if free {
                    trial.removeForPlanning(state.id)
                    progress = true
                }
            }
        }
        return trial.candies.isEmpty
    }
}

private func pow(_ base: Double, _ exponent: Double) -> Double {
    var result = 1.0
    for _ in 0..<Int(exponent) { result *= base }
    return result
}
