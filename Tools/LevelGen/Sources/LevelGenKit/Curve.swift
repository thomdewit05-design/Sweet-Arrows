import Foundation
import SweetArrowsCore

/// The difficulty curve from PLAN.md:
/// levels 1–10 are the tutorial; after that a sawtooth of 4 easy, 1 medium, 1 hard,
/// repeating and slowly rising. Every world brings one new element.
public enum Curve {
    public enum Slot: String, Sendable, Codable {
        case tutorial, easy, medium, hard
    }

    public struct Plan: Sendable {
        public var id: Int
        public var slot: Slot
        public var target: Double
        public var world: World
        /// Elements that may appear.
        public var elements: [BoardElement]
        /// Element that must appear (new in this world).
        public var featured: BoardElement?
    }

    public static let firstGenerated = HandmadeLevels.count + 1

    public static func slot(for id: Int) -> Slot {
        guard id >= firstGenerated else { return .tutorial }
        switch (id - firstGenerated) % 6 {
        case 4: return .medium
        case 5: return .hard
        default: return .easy
        }
    }

    /// Baseline difficulty that rises over the game (0–100 scale, see `Difficulty`).
    public static func baseline(for id: Int, total: Int = 300) -> Double {
        let progress = Double(max(id - firstGenerated, 0)) / Double(max(total - firstGenerated, 1))
        return 16 + 50 * pow(min(progress, 1), 0.8)
    }

    public static func plan(for id: Int, total: Int = 300) -> Plan {
        let world = World.forLevel(id)
        let slot = slot(for: id)
        let base = baseline(for: id, total: total)
        var target: Double = switch slot {
        case .tutorial: 10
        case .easy: base * 0.85
        case .medium: base * 1.08
        case .hard: min(base * 1.3 + 6, 92)
        }
        // A world's first level shows off its new element on a calm board.
        let isWorldIntro = id == world.firstLevel && world.newElement != nil
        if isWorldIntro { target = base * 0.7 }
        return Plan(
            id: id, slot: isWorldIntro ? .easy : slot, target: (target * 10).rounded() / 10, world: world,
            elements: world.availableElements, featured: world.newElement
        )
    }
}
