import Testing
@testable import SweetArrowsCore

@Suite("Game rules")
struct GameTests {
    @Test func clearPathLaunchesIntoBag() throws {
        var game = Game(level: makeLevel([">s .  ."]))
        let report = game.tap(1)
        let launch = try #require(report.result.launched)
        #expect(launch.exitDistance == 3)
        #expect(launch.color == .strawberry)
        #expect(game.candies.isEmpty)
        #expect(report.status == .won)
        #expect(game.moves == 1)
    }

    @Test func blockedCandyBouncesAndCostsAHeart() throws {
        var game = Game(level: makeLevel([">s . <l"]))
        let report = game.tap(1)
        let bounce = try #require(report.result.bounced)
        #expect(bounce.obstacle == .candy(2))
        #expect(bounce.distance == 1)
        #expect(bounce.heartLost)
        #expect(game.hearts == 2)
        #expect(game.candies.count == 2)
        #expect(game.moves == 0)
        #expect(!game.canUndo)
    }

    @Test func runningOutOfHeartsLoses() {
        var game = Game(level: makeLevel([">s <l"], hearts: 2))
        game.tap(1)
        #expect(game.status == .playing)
        game.tap(2)
        #expect(game.status == .lost(.outOfHearts))
        #expect(game.tap(1).result == .ignored)
    }

    @Test func tutorialBouncesAreFree() {
        var game = Game(level: makeLevel([">s <l"], hearts: 1, tutorial: true))
        let report = game.tap(1)
        #expect(report.result.bounced?.heartLost == false)
        #expect(game.hearts == 1)
        #expect(game.status == .playing)
    }

    @Test func threeOfAKindPop() {
        var game = Game(level: makeLevel(["^s ^s ^s"]))
        game.tap(1)
        game.tap(2)
        #expect(game.bag.slots == [.strawberry, .strawberry])
        let report = game.tap(3)
        #expect(report.result.launched?.bag.popped == [0, 1, 2])
        #expect(game.bag.isEmpty)
        #expect(game.status == .won)
    }

    @Test func fullBagLoses() {
        // Five different colors on the board, bag of 3.
        var game = Game(level: makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 3))
        game.tap(1)
        game.tap(2)
        let report = game.tap(3)
        #expect(report.status == .lost(.bagFull))
        #expect(game.bag.isFull)
    }

    @Test func extraSlotRevivesFullBag() {
        var game = Game(level: makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 3))
        game.tap(1); game.tap(2); game.tap(3)
        #expect(game.status == .lost(.bagFull))
        game.addBagSlot()
        #expect(game.status == .playing)
        #expect(game.bag.capacity == 4)
    }

    @Test func undoRestoresBoardAndBagButNotHearts() {
        var game = Game(level: makeLevel([">s . <l", ".  ^m ."]))
        game.tap(1)        // bounce: -1 heart
        game.tap(3)        // launch mint
        #expect(game.bag.slots == [.mint])
        let undone = game.undo()
        #expect(undone)
        #expect(game.bag.isEmpty)
        #expect(game.candies[3] != nil)
        #expect(game.hearts == 2)
        #expect(game.moves == 0)
        let undoneAgain = game.undo()
        #expect(!undoneAgain)
    }

    @Test func undoAfterFullBagRevives() {
        var game = Game(level: makeLevel(["^s ^l ^m ^s ^l ^m ^s ^l ^m"], bag: 3))
        game.tap(1); game.tap(2); game.tap(3)
        let undone = game.undo()
        #expect(undone)
        #expect(game.status == .playing)
        #expect(game.bag.slots.count == 2)
    }

    @Test func polesBlock() throws {
        var game = Game(level: makeLevel([">s # ."]))
        let bounce = try #require(game.tap(1).result.bounced)
        #expect(bounce.obstacle == .pole(GridPoint(1, 0)))
        #expect(bounce.distance == 0)
    }

    @Test func caramelNeedsTwoTaps() {
        var game = Game(level: makeLevel(["^s"], features: [1: [.caramel]]))
        #expect(game.tap(1).result == .crackedCaramel(candyID: 1))
        #expect(game.candies[1]?.caramelIntact == false)
        #expect(game.moves == 1)
        #expect(game.tap(1).result.launched != nil)
        #expect(game.moves == 2)
    }

    @Test func blockedCaramelStillBounces() {
        var game = Game(level: makeLevel([">s <l"], features: [1: [.caramel]]))
        #expect(game.tap(1).result.bounced != nil)
        #expect(game.candies[1]?.caramelIntact == true)
    }

    @Test func rotatingArrowTurnsAfterEveryMove() {
        var game = Game(level: makeLevel(["^s .", "^l ."], features: [2: [.rotating]]))
        // Candy 2 points up into candy 1.
        #expect(game.path(for: 2)?.isClear == false)
        let report = game.tap(1)
        #expect(report.rotated == [2: .right])
        #expect(game.candies[2]?.direction == .right)
        // A bounce is not a move: no rotation.
        var blocked = Game(level: makeLevel([">s <l", "^m ."], features: [3: [.rotating]]))
        let bounce = blocked.tap(1)
        #expect(bounce.rotated.isEmpty)
        #expect(blocked.candies[3]?.direction == .up)
    }

    @Test func iceMeltsWhenNeighbourLeaves() {
        var game = Game(level: makeLevel(["^s ^l", ".  ."], features: [2: [.iced]]))
        #expect(game.tap(2).result == .frozen(candyID: 2))
        #expect(game.hearts == 3)
        let report = game.tap(1)
        #expect(report.melted == [2])
        #expect(game.tap(2).result.launched != nil)
    }

    @Test func wrappedRevealsWhenPathClears() {
        var game = Game(level: makeLevel(["^s .", "^l ."], features: [2: [.wrapped], 1: [.wrapped]]))
        #expect(game.candies[1]?.revealed == true)  // path already clear at start
        #expect(game.candies[2]?.revealed == false)
        let report = game.tap(1)
        #expect(report.revealed == [2])
        #expect(game.candies[2]?.revealed == true)
    }

    @Test func chocolateBarMovesAsOne() throws {
        let bar = Candy(id: 1, color: .orange, position: GridPoint(0, 1), direction: .right, bar: .horizontal)
        let blocker = Candy(id: 2, color: .mint, position: GridPoint(2, 0), direction: .up)
        var game = Game(level: Level(id: 1, width: 4, height: 2, candies: [bar, blocker]))
        // Bar on row 1 cells (0,1),(1,1) moving right: (2,1),(3,1) free.
        let launch = try #require(game.tap(1).result.launched)
        // The rear cell has to travel 4 cells to leave the board.
        #expect(launch.exitDistance == 4)

        // Vertical bar moving up is blocked by something above either cell? Only its own column.
        let vertical = Candy(id: 1, color: .orange, position: GridPoint(0, 1), direction: .up, bar: .vertical)
        let above = Candy(id: 2, color: .mint, position: GridPoint(0, 0), direction: .left)
        var game2 = Game(level: Level(id: 1, width: 2, height: 3, candies: [vertical, above]))
        #expect(game2.tap(1).result.bounced?.obstacle == .candy(2))

        // Horizontal bar moving up is blocked if either column is blocked.
        let wide = Candy(id: 1, color: .orange, position: GridPoint(0, 1), direction: .up, bar: .horizontal)
        let corner = Candy(id: 2, color: .mint, position: GridPoint(1, 0), direction: .right)
        var game3 = Game(level: Level(id: 1, width: 2, height: 2, candies: [wide, corner]))
        #expect(game3.tap(1).result.bounced?.obstacle == .candy(2))
    }

    @Test func removeCandyBoosterClearsHistory() throws {
        var game = Game(level: makeLevel(["^s ^s ^s", "^l ^l ^l"], features: [6: [.iced]]))
        game.tap(1)
        #expect(game.canUndo)
        let removal = game.removeCandy(5)
        let report = try #require(removal)
        #expect(report.melted == [6])
        #expect(!game.canUndo)
        #expect(game.candies[5] == nil)
        #expect(game.bag.slots == [.strawberry])
    }

    @Test func candyAtFindsBarCells() {
        let bar = Candy(id: 7, color: .grape, position: GridPoint(1, 1), direction: .down, bar: .vertical)
        let game = Game(level: Level(id: 1, width: 3, height: 3, candies: [bar]))
        #expect(game.candy(at: GridPoint(1, 2))?.id == 7)
        #expect(game.candy(at: GridPoint(0, 0)) == nil)
    }
}

@Suite("Bag")
struct BagTests {
    @Test func groupsSameColors() {
        var bag = Bag(capacity: 5)
        bag.insert(.mint)
        bag.insert(.lemon)
        let insertion = bag.insert(.mint)
        #expect(insertion.slot == 1)
        #expect(bag.slots == [.mint, .mint, .lemon])
        #expect(!insertion.didPop)
    }

    @Test func popsThree() {
        var bag = Bag(capacity: 5, slots: [.lemon, .mint, .mint])
        let insertion = bag.insert(.mint)
        #expect(insertion.slot == 3)
        #expect(insertion.popped == [1, 2, 3])
        #expect(bag.slots == [.lemon])
    }

    @Test func capacityIsCapped() {
        var bag = Bag(capacity: Bag.maxCapacity)
        bag.addSlot()
        #expect(bag.capacity == Bag.maxCapacity)
        #expect(bag.freeSlots == Bag.maxCapacity)
    }
}

@Suite("Geometry")
struct GeometryTests {
    @Test func rotation() {
        #expect(Direction.up.rotated(by: 1) == .right)
        #expect(Direction.left.rotated(by: 1) == .up)
        #expect(Direction.up.rotated(by: -1) == .left)
        #expect(Direction.down.rotated(by: 6) == .up)
        #expect(Direction.right.axis == .horizontal)
    }

    @Test func pointArithmetic() {
        #expect(GridPoint(1, 1) + .up == GridPoint(1, 0))
        #expect(GridPoint(0, 0).neighbors.count == 4)
    }
}
