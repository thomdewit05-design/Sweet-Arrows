@testable import SweetArrowsCore

/// Builds a level from a small ASCII map. Arrows: ^ > v <. Letters after the arrow pick the color
/// (s, l, m, b, o, g). `#` is a lollipop pole, `.` an empty cell. Cells are separated by spaces.
///
///     ">s .  ^m"
///     ".  #  ^m"
func makeLevel(
    _ rows: [String],
    bag: Int = 5,
    hearts: Int = 3,
    tutorial: Bool = false,
    features: [Int: Set<CandyFeature>] = [:]
) -> Level {
    var candies: [Candy] = []
    var poles: [GridPoint] = []
    let grid = rows.map { $0.split(separator: " ", omittingEmptySubsequences: true).map(String.init) }
    for (y, row) in grid.enumerated() {
        for (x, token) in row.enumerated() {
            if token == "." { continue }
            if token == "#" {
                poles.append(GridPoint(x, y))
                continue
            }
            let arrow = token.first!
            let direction: Direction = switch arrow {
            case "^": .up
            case ">": .right
            case "v": .down
            default: .left
            }
            let colorCode = token.dropFirst().first ?? "s"
            let color: CandyColor = switch colorCode {
            case "l": .lemon
            case "m": .mint
            case "b": .blueberry
            case "o": .orange
            case "g": .grape
            default: .strawberry
            }
            let id = candies.count + 1
            candies.append(Candy(
                id: id, color: color, position: GridPoint(x, y), direction: direction,
                features: features[id] ?? []
            ))
        }
    }
    return Level(
        id: 1, width: grid.map(\.count).max() ?? 0, height: grid.count,
        bagCapacity: bag, hearts: hearts, tutorial: tutorial, candies: candies, poles: poles
    )
}

extension TapResult {
    var launched: Launch? {
        if case .launched(let launch) = self { return launch }
        return nil
    }

    var bounced: Bounce? {
        if case .bounced(let bounce) = self { return bounce }
        return nil
    }
}
