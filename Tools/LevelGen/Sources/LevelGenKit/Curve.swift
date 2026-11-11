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
        // About a quarter harder than the first version, rising faster early on.
        return 20 + 62 * pow(min(progress, 1), 0.75)
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
        // A new element arrives on a calm board, then stays in the spotlight for a few levels.
        let introduced = World.introducedElement(atLevel: id)
        if introduced != nil { target = base * 0.7 }
        let recent = world.introductions.last { $0.level <= id && id - $0.level < 6 }
        return Plan(
            id: id, slot: introduced != nil ? .easy : slot, target: (min(target, 95) * 10).rounded() / 10,
            world: world, elements: World.availableElements(atLevel: id), featured: recent?.element
        )
    }
}

/// How long a level may take. The clock starts at the first tap.
public enum TimeLimit {
    /// Seconds per tap of the solver's solution, by slot: generous in the tutorial, tight on hard levels.
    public static func seconds(for level: Level, slot: Curve.Slot) -> Int {
        let taps = Double(level.stats?.solutionLength ?? level.candies.count)
        let perTap: Double = switch slot {
        case .tutorial: 6
        case .easy: 3.2
        case .medium: 2.8
        case .hard: 2.4
        }
        let raw = 12 + taps * perTap
        let rounded = Int((raw / 5).rounded(.up)) * 5
        return max(rounded, slot == .tutorial ? 45 : 30)
    }
}
