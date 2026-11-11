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

    /// Elements this world introduces: one at its first level, one halfway.
    public var newElements: [BoardElement] {
        switch theme {
        case .gummyGarden, .licoriceLab, .iceCreamIsland: []
        case .lollipopLane: [.pole, .mirror]
        case .chocolateFalls: [.chocolateBar, .wrapped]
        case .marshmallowMountains: [.lock, .caramel]
        case .caramelCanyon: [.bomb, .iced]
        case .cottonCandyClouds: [.colorChanger, .rotating]
        }
    }

    /// First element this world introduces (shown on the map).
    public var newElement: BoardElement? { newElements.first }

    /// Level at which each new element appears for the first time.
    public var introductions: [(level: Int, element: BoardElement)] {
        let halfway = firstLevel + World.sizes[id - 1] / 2
        return zip([firstLevel, halfway], newElements).map { ($0, $1) }
    }

    /// Every element unlocked by the end of this world.
    public var availableElements: [BoardElement] {
        World.all.prefix(id).flatMap(\.newElements)
    }

    /// Elements a given level may use (everything introduced up to and including it).
    public static func availableElements(atLevel level: Int) -> [BoardElement] {
        all.flatMap(\.introductions).filter { $0.level <= level }.map(\.element)
    }

    /// The element introduced exactly at this level, if any.
    public static func introducedElement(atLevel level: Int) -> BoardElement? {
        all.flatMap(\.introductions).first { $0.level == level }?.element
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
