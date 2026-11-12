/// The guided first game: a calm little board in three steps, no new candies arriving.
public enum Tutorial {
    public enum Step: Int, CaseIterable, Sendable {
        /// Tap the candy: it slides along its arrow (and makes a line of three).
        case slide
        /// A blocked candy: tap it to turn its arrow.
        case turn
        /// Slide it into a column of three.
        case match
        /// Done: the real game starts.
        case finished
    }

    public static let doneKey = "tutorialDone.v1"

    /// Ids of the candies the steps are about.
    public static let slider = 3
    public static let turner = 6

    /// Row 4: mint, mint, (empty), (empty), lemon. A mint above the gap points down; a lemon pointing
    /// right at the edge above two lemons can only turn first.
    public static func board() -> SlideGame {
        typealias Piece = SlideGame.Piece
        return SlideGame(pieces: [
            Piece(id: 1, color: .mint, direction: .up, position: GridPoint(0, 4)),
            Piece(id: 2, color: .mint, direction: .up, position: GridPoint(1, 4)),
            Piece(id: slider, color: .mint, direction: .down, position: GridPoint(2, 0)),
            Piece(id: 4, color: .lemon, direction: .up, position: GridPoint(4, 3)),
            Piece(id: 5, color: .lemon, direction: .up, position: GridPoint(4, 4)),
            Piece(id: turner, color: .lemon, direction: .right, position: GridPoint(4, 1)),
        ])
    }

    /// Where the player is, read from the board itself.
    public static func step(of game: SlideGame) -> Step {
        if game.pieces[slider] != nil { return .slide }
        guard let turnerPiece = game.pieces[turner] else { return .finished }
        return turnerPiece.direction == .right ? .turn : .match
    }

    /// The candy the hand points at in a step.
    public static func target(for step: Step) -> Int? {
        switch step {
        case .slide: slider
        case .turn, .match: turner
        case .finished: nil
        }
    }
}
