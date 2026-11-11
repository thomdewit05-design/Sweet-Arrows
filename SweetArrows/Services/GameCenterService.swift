import Foundation

/// Game Center achievements and the daily-puzzle leaderboard. Implemented in phase 5.
@MainActor
protocol GameCenterService: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate()
}

@MainActor
final class PlaceholderGameCenterService: GameCenterService {
    private(set) var isAuthenticated = false
    func authenticate() {}
}
