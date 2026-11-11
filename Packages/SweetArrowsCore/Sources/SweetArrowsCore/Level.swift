import Foundation

/// A level as stored in `SweetArrows/Resources/levels/*.json`.
public struct Level: Hashable, Codable, Sendable, Identifiable {
    public static let maxCandies = 64
    public static let maxWidth = 7
    public static let maxHeight = 9

    /// Level number, starting at 1.
    public var id: Int
    public var width: Int
    public var height: Int
    public var bagCapacity: Int
    public var hearts: Int
    /// Tutorial levels cannot be lost: bounces cost no hearts.
    public var tutorial: Bool
    /// Shown with a "Hard level" label.
    public var hard: Bool
    public var candies: [Candy]
    /// Lollipop poles: fixed obstacles that candies have to go around.
    public var poles: [GridPoint]
    /// Filled in by the solver when the level is approved.
    public var stats: LevelStats?

    public init(
        id: Int,
        width: Int,
        height: Int,
        bagCapacity: Int = 5,
        hearts: Int = 3,
        tutorial: Bool = false,
        hard: Bool = false,
        candies: [Candy],
        poles: [GridPoint] = [],
        stats: LevelStats? = nil
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.bagCapacity = bagCapacity
        self.hearts = hearts
        self.tutorial = tutorial
        self.hard = hard
        self.candies = candies
        self.poles = poles
        self.stats = stats
    }

    public var world: Int { World.number(forLevel: id) }

    public func contains(_ p: GridPoint) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }

    /// Every feature or element that appears in this level.
    public var elements: Set<BoardElement> {
        var result = Set<BoardElement>()
        if !poles.isEmpty { result.insert(.pole) }
        for candy in candies {
            if candy.isChocolateBar { result.insert(.chocolateBar) }
            for feature in candy.features { result.insert(BoardElement(feature)) }
        }
        return result
    }

    // MARK: Validation

    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case badSize
        case tooManyCandies
        case outOfBounds(candyID: Int)
        case overlap(GridPoint)
        case duplicateID(Int)
        case colorCountNotMultipleOfThree(CandyColor)
        case badBag
        case iceWithoutNeighbours(candyID: Int)

        public var description: String {
            switch self {
            case .badSize: "board size outside 2...\(Level.maxWidth) x 2...\(Level.maxHeight)"
            case .tooManyCandies: "more than \(Level.maxCandies) candies"
            case .outOfBounds(let id): "candy \(id) is outside the board"
            case .overlap(let p): "two things share cell \(p)"
            case .duplicateID(let id): "duplicate candy id \(id)"
            case .colorCountNotMultipleOfThree(let c): "number of \(c.rawValue) candies is not a multiple of 3"
            case .badBag: "bag capacity must be 3...8 and hearts >= 1"
            case .iceWithoutNeighbours(let id): "iced candy \(id) has no neighbour that could free it"
            }
        }
    }

    /// Checks structural rules. Solvability is checked separately by `Solver`.
    public func validate() throws(ValidationError) {
        guard (2...Level.maxWidth).contains(width), (2...Level.maxHeight).contains(height) else {
            throw .badSize
        }
        guard candies.count <= Level.maxCandies else { throw .tooManyCandies }
        guard (3...8).contains(bagCapacity), hearts >= 1 else { throw .badBag }

        var occupied = Set<GridPoint>()
        var ids = Set<Int>()
        for pole in poles {
            guard contains(pole) else { throw .overlap(pole) }
            guard occupied.insert(pole).inserted else { throw .overlap(pole) }
        }
        for candy in candies {
            guard ids.insert(candy.id).inserted else { throw .duplicateID(candy.id) }
            for cell in candy.cells {
                guard contains(cell) else { throw .outOfBounds(candyID: candy.id) }
                guard occupied.insert(cell).inserted else { throw .overlap(cell) }
            }
        }
        var counts: [CandyColor: Int] = [:]
        for candy in candies { counts[candy.color, default: 0] += 1 }
        for (color, count) in counts where count % 3 != 0 {
            throw .colorCountNotMultipleOfThree(color)
        }
        let cellOwner = Dictionary(
            candies.flatMap { candy in candy.cells.map { ($0, candy.id) } },
            uniquingKeysWith: { first, _ in first }
        )
        for candy in candies where candy.has(.iced) {
            let hasNeighbour = candy.cells.flatMap(\.neighbors).contains { cell in
                if let owner = cellOwner[cell] { return owner != candy.id }
                return false
            }
            guard hasNeighbour else { throw .iceWithoutNeighbours(candyID: candy.id) }
        }
    }

    // MARK: JSON

    public static func decode(from data: Data) throws -> Level {
        try JSONDecoder().decode(Level.self, from: data)
    }

    public func encoded(pretty: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case id, width, height, bagCapacity, hearts, tutorial, hard, candies, poles, stats
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        bagCapacity = try c.decodeIfPresent(Int.self, forKey: .bagCapacity) ?? 5
        hearts = try c.decodeIfPresent(Int.self, forKey: .hearts) ?? 3
        tutorial = try c.decodeIfPresent(Bool.self, forKey: .tutorial) ?? false
        hard = try c.decodeIfPresent(Bool.self, forKey: .hard) ?? false
        candies = try c.decode([Candy].self, forKey: .candies)
        poles = try c.decodeIfPresent([GridPoint].self, forKey: .poles) ?? []
        stats = try c.decodeIfPresent(LevelStats.self, forKey: .stats)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(bagCapacity, forKey: .bagCapacity)
        try c.encode(hearts, forKey: .hearts)
        if tutorial { try c.encode(true, forKey: .tutorial) }
        if hard { try c.encode(true, forKey: .hard) }
        try c.encode(candies, forKey: .candies)
        if !poles.isEmpty { try c.encode(poles, forKey: .poles) }
        try c.encodeIfPresent(stats, forKey: .stats)
    }
}

/// Elements that can appear on a board, used for world themes and the level report.
public enum BoardElement: String, CaseIterable, Codable, Sendable, Comparable {
    case pole, chocolateBar, wrapped, caramel, iced, rotating

    public init(_ feature: CandyFeature) {
        switch feature {
        case .caramel: self = .caramel
        case .rotating: self = .rotating
        case .iced: self = .iced
        case .wrapped: self = .wrapped
        }
    }

    public static func < (lhs: BoardElement, rhs: BoardElement) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// Numbers the solver attaches to an approved level.
public struct LevelStats: Hashable, Codable, Sendable {
    /// Taps in the shortest solution (caramel counts twice).
    public var solutionLength: Int
    /// Moves along the solution that are legal but make the level unwinnable.
    public var pitfalls: Int
    /// Number of distinct winning move orders, capped (see `solutionsCapped`).
    public var solutions: Int
    public var solutionsCapped: Bool
    /// Highest bag fill along the solution.
    public var peakBag: Int
    /// 0–100, see `Difficulty`.
    public var difficulty: Double
    /// A winning move order (candy ids). Used for hints and tests.
    public var solution: [Int]

    public init(
        solutionLength: Int,
        pitfalls: Int,
        solutions: Int,
        solutionsCapped: Bool,
        peakBag: Int,
        difficulty: Double,
        solution: [Int]
    ) {
        self.solutionLength = solutionLength
        self.pitfalls = pitfalls
        self.solutions = solutions
        self.solutionsCapped = solutionsCapped
        self.peakBag = peakBag
        self.difficulty = difficulty
        self.solution = solution
    }
}
