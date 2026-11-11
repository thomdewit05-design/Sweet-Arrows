import GameKit
import UIKit

/// Game Center achievements. The ids must also be created in App Store Connect (see docs/STATUS.md).
enum Achievement: String, CaseIterable, Sendable {
    case firstWin = "sweetarrows.first_win"
    case tutorialDone = "sweetarrows.tutorial_done"
    case world1 = "sweetarrows.world_1"
    case world2 = "sweetarrows.world_2"
    case world3 = "sweetarrows.world_3"
    case world4 = "sweetarrows.world_4"
    case world5 = "sweetarrows.world_5"
    case world6 = "sweetarrows.world_6"
    case world7 = "sweetarrows.world_7"
    case world8 = "sweetarrows.world_8"
    case stars100 = "sweetarrows.stars_100"
    case dailyStreak7 = "sweetarrows.daily_streak_7"

    static func world(_ number: Int) -> Achievement? {
        allCases.first { $0.rawValue == "sweetarrows.world_\(number)" }
    }
}

enum Leaderboard {
    /// Daily puzzle: fastest time in seconds (create as "low to high", recurring daily, in App Store Connect).
    static let dailyPuzzle = "sweetarrows.daily_time"
}

@MainActor
protocol GameCenterService: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate()
    func report(_ achievement: Achievement)
    func submitDailyTime(seconds: Int)
}

/// Game Center through GameKit. Everything is optional: offline or signed out, calls do nothing.
@MainActor
final class GameKitService: GameCenterService {
    private(set) var isAuthenticated = false
    private var reported = Set<Achievement>()

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            MainActor.assumeIsolated {
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if let viewController { Self.present(viewController) }
            }
        }
    }

    func report(_ achievement: Achievement) {
        guard isAuthenticated, reported.insert(achievement).inserted else { return }
        let entry = GKAchievement(identifier: achievement.rawValue)
        entry.percentComplete = 100
        entry.showsCompletionBanner = true
        GKAchievement.report([entry]) { _ in }
    }

    func submitDailyTime(seconds: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            seconds, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Leaderboard.dailyPuzzle]
        ) { _ in }
    }

    private static func present(_ viewController: UIViewController) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}

/// Does nothing: previews, tests and UI tests.
@MainActor
final class OfflineGameCenterService: GameCenterService {
    let isAuthenticated = false
    func authenticate() {}
    func report(_ achievement: Achievement) {}
    func submitDailyTime(seconds: Int) {}
}
