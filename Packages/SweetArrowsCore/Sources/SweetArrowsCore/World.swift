/// The eight candy worlds. The 300 levels of v1 are spread over them (38 or 37 each),
/// and every world introduces one new element; the last one mixes them all.
public struct World: Hashable, Sendable, Identifiable {
    public static let count = 8
    /// Levels in v1. Levels added later continue in the last world until new worlds arrive.
    public static let totalLevels = 300

    public enum Theme: String, CaseIterable, Sendable {
        case gummyGarden, lollipopLane, chocolateFalls, marshmallowMountains
        case caramelCanyon, cottonCandyClouds, licoriceLab, iceCreamIsland
    }

    /// Level count per world: 38, 38, 38, 38, 37, 37, 37, 37.
    public static let sizes: [Int] = (0..<count).map { index in
        totalLevels / count + (index < totalLevels % count ? 1 : 0)
    }

    /// World number, 1...8.
    public let id: Int

    public init(id: Int) {
        precondition((1...World.count).contains(id))
        self.id = id
    }

    public static var all: [World] { (1...count).map(World.init(id:)) }

    public var theme: Theme { Theme.allCases[id - 1] }
    public var firstLevel: Int { World.sizes.prefix(id - 1).reduce(0, +) + 1 }
    public var lastLevel: Int { firstLevel + World.sizes[id - 1] - 1 }
    public var levels: ClosedRange<Int> { firstLevel...lastLevel }

    /// The element this world introduces (nil for the first and the last world).
    public var newElement: BoardElement? {
        switch theme {
        case .gummyGarden, .iceCreamIsland: nil
        case .lollipopLane: .pole
        case .chocolateFalls: .chocolateBar
        case .marshmallowMountains: .wrapped
        case .caramelCanyon: .caramel
        case .cottonCandyClouds: .iced
        case .licoriceLab: .rotating
        }
    }

    /// Every element a level in this world may use.
    public var availableElements: [BoardElement] {
        let order: [BoardElement] = [.pole, .chocolateBar, .wrapped, .caramel, .iced, .rotating]
        return Array(order.prefix(min(id - 1, order.count)))
    }

    public static func number(forLevel level: Int) -> Int {
        var end = 0
        for (index, size) in sizes.enumerated() {
            end += size
            if level <= end { return index + 1 }
        }
        return count
    }

    public static func forLevel(_ level: Int) -> World {
        World(id: number(forLevel: level))
    }
}
