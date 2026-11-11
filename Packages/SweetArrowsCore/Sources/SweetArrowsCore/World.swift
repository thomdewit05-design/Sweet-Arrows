/// The candy worlds. Each has 20 levels and introduces one new element.
/// After world 8 the themes repeat as "season 2" (levels 161–300) with every element mixed in.
public struct World: Hashable, Sendable, Identifiable {
    public static let levelsPerWorld = 20

    public enum Theme: String, CaseIterable, Sendable {
        case gummyGarden, lollipopLane, chocolateFalls, marshmallowMountains
        case caramelCanyon, cottonCandyClouds, licoriceLab, iceCreamIsland
    }

    /// World number, starting at 1 (may exceed 8: themes repeat).
    public let id: Int

    public var theme: Theme { Theme.allCases[(id - 1) % Theme.allCases.count] }
    public var season: Int { (id - 1) / Theme.allCases.count + 1 }
    public var firstLevel: Int { (id - 1) * World.levelsPerWorld + 1 }
    public var levels: ClosedRange<Int> { firstLevel...(firstLevel + World.levelsPerWorld - 1) }

    /// The element this world introduces (nil for the first world and for repeats).
    public var newElement: BoardElement? {
        guard season == 1 else { return nil }
        switch theme {
        case .gummyGarden: return nil
        case .lollipopLane: return .pole
        case .chocolateFalls: return .chocolateBar
        case .marshmallowMountains: return .wrapped
        case .caramelCanyon: return .caramel
        case .cottonCandyClouds: return .iced
        case .licoriceLab: return .rotating
        case .iceCreamIsland: return nil
        }
    }

    /// Every element a level in this world may use.
    public var availableElements: [BoardElement] {
        let order: [BoardElement] = [.pole, .chocolateBar, .wrapped, .caramel, .iced, .rotating]
        if season > 1 || theme == .iceCreamIsland { return order }
        let unlocked = Theme.allCases.firstIndex(of: theme)!  // world 2 unlocks 1 element, ...
        return Array(order.prefix(unlocked))
    }

    public init(id: Int) {
        precondition(id >= 1)
        self.id = id
    }

    public static func number(forLevel level: Int) -> Int {
        (max(level, 1) - 1) / levelsPerWorld + 1
    }

    public static func forLevel(_ level: Int) -> World {
        World(id: number(forLevel: level))
    }
}
