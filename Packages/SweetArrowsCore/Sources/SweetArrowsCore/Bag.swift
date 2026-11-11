/// The candy jar at the bottom of the screen. Three candies of the same color pop.
public struct Bag: Hashable, Sendable {
    public static let matchCount = 3
    public static let maxCapacity = 8

    public private(set) var slots: [CandyColor]
    public private(set) var capacity: Int

    public init(capacity: Int, slots: [CandyColor] = []) {
        self.capacity = capacity
        self.slots = slots
    }

    public var isFull: Bool { slots.count >= capacity }
    public var isEmpty: Bool { slots.isEmpty }
    public var freeSlots: Int { max(capacity - slots.count, 0) }

    public func count(of color: CandyColor) -> Int {
        slots.lazy.filter { $0 == color }.count
    }

    public struct Insertion: Hashable, Sendable {
        /// Slot the candy landed in (before any pop).
        public var slot: Int
        /// Slots (indices before removal) that popped, empty if no match.
        public var popped: [Int]
        public var didPop: Bool { !popped.isEmpty }
    }

    /// Inserts next to candies of the same color, then pops a match of three.
    @discardableResult
    public mutating func insert(_ color: CandyColor) -> Insertion {
        let slot: Int
        if let last = slots.lastIndex(of: color) {
            slot = last + 1
        } else {
            slot = slots.count
        }
        slots.insert(color, at: slot)
        let matching = slots.indices.filter { slots[$0] == color }
        guard matching.count >= Bag.matchCount else {
            return Insertion(slot: slot, popped: [])
        }
        let popped = Array(matching.prefix(Bag.matchCount))
        for index in popped.reversed() {
            slots.remove(at: index)
        }
        return Insertion(slot: slot, popped: popped)
    }

    public mutating func addSlot() {
        capacity = min(capacity + 1, Bag.maxCapacity)
    }
}
