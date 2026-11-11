/// Boosters the player can use during a run.
/// Raw values stay the same as in older saves (`extraSlot` is now the slow-down).
public enum Booster: String, CaseIterable, Codable, Sendable {
    /// Points at a candy whose slide pops a line.
    case hint
    /// Taps one candy (or stone) off the board.
    case hammer = "removeCandy"
    /// New candies arrive at half speed for a while.
    case slowDown = "extraSlot"

    /// Price in coins when the player has none in stock.
    public var price: Int {
        switch self {
        case .hint: 60
        case .hammer: 90
        case .slowDown: 120
        }
    }
}

/// Boosters in stock.
public struct BoosterInventory: Hashable, Codable, Sendable {
    public var counts: [Booster: Int]

    public init(counts: [Booster: Int] = [:]) {
        self.counts = counts
    }

    public subscript(booster: Booster) -> Int {
        get { counts[booster] ?? 0 }
        set { counts[booster] = max(newValue, 0) }
    }

    public mutating func add(_ booster: Booster, _ amount: Int = 1) {
        self[booster] += amount
    }
}
