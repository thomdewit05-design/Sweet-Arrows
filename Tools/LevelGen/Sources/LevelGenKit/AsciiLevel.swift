import SweetArrowsCore

/// Reads and writes levels as small ASCII maps, which is how the hand-made levels are authored.
///
/// One token per cell, separated by spaces:
/// - `.` empty, `#` lollipop pole
/// - an arrow `^ > v <` followed by a color letter: s(trawberry) l(emon) m(int) b(lueberry) o(range) g(rape)
/// - optional suffixes: `c` caramel, `r` rotating, `i` iced, `w` wrapped
///   e.g. `>sc` = strawberry pointing right with caramel
public enum AsciiLevel {
    public enum ParseError: Error, CustomStringConvertible {
        case badToken(String, x: Int, y: Int)

        public var description: String {
            switch self {
            case let .badToken(token, x, y): "bad token '\(token)' at (\(x),\(y))"
            }
        }
    }

    private static let colorCodes: [Character: CandyColor] = [
        "s": .strawberry, "l": .lemon, "m": .mint, "b": .blueberry, "o": .orange, "g": .grape,
    ]
    private static let directionCodes: [Character: Direction] = ["^": .up, ">": .right, "v": .down, "<": .left]
    private static let featureCodes: [Character: CandyFeature] = [
        "c": .caramel, "r": .rotating, "i": .iced, "w": .wrapped,
    ]

    public static func parse(
        _ rows: [String],
        id: Int,
        bagCapacity: Int = 5,
        hearts: Int = 3,
        tutorial: Bool = false
    ) throws -> Level {
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
                let chars = Array(token)
                guard chars.count >= 2,
                      let direction = directionCodes[chars[0]],
                      let color = colorCodes[chars[1]]
                else { throw ParseError.badToken(token, x: x, y: y) }
                var features = Set<CandyFeature>()
                for code in chars.dropFirst(2) {
                    guard let feature = featureCodes[code] else { throw ParseError.badToken(token, x: x, y: y) }
                    features.insert(feature)
                }
                candies.append(Candy(
                    id: candies.count + 1, color: color, position: GridPoint(x, y),
                    direction: direction, features: features
                ))
            }
        }
        return Level(
            id: id, width: grid.map(\.count).max() ?? 0, height: grid.count,
            bagCapacity: bagCapacity, hearts: hearts, tutorial: tutorial,
            candies: candies, poles: poles
        )
    }

    /// Renders a level as an ASCII map (chocolate bars are shown as `=` on their second cell).
    public static func render(_ level: Level) -> [String] {
        var cells = Array(repeating: Array(repeating: ".", count: level.width), count: level.height)
        for pole in level.poles { cells[pole.y][pole.x] = "#" }
        let arrows: [Direction: String] = [.up: "^", .right: ">", .down: "v", .left: "<"]
        let colors = Dictionary(uniqueKeysWithValues: colorCodes.map { ($0.value, String($0.key)) })
        let features = Dictionary(uniqueKeysWithValues: featureCodes.map { ($0.value, String($0.key)) })
        for candy in level.candies {
            var token = arrows[candy.direction]! + colors[candy.color]!
            for feature in candy.features.sorted() { token += features[feature]! }
            let cellsOfCandy = candy.cells
            cells[cellsOfCandy[0].y][cellsOfCandy[0].x] = token
            for extra in cellsOfCandy.dropFirst() { cells[extra.y][extra.x] = "=" }
        }
        let width = cells.flatMap { $0 }.map(\.count).max() ?? 1
        return cells.map { row in
            row.map { $0.padded(to: width) }.joined(separator: " ")
                .replacingTrailingSpaces()
        }
    }
}

private extension String {
    func padded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }

    func replacingTrailingSpaces() -> String {
        var result = self
        while result.last == " " { result.removeLast() }
        return result
    }
}
