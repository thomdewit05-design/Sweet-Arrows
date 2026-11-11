import GameKit
import UIKit

/// Game Center achievements. The ids must also be created in App Store Connect (see docs/STATUS.md).
enum Achievement: String, CaseIterable, Sendable {
    case firstPop = "sweetarrows.first_pop"
    case score1000 = "sweetarrows.score_1000"
    case score5000 = "sweetarrows.score_5000"
    case combo5 = "sweetarrows.combo_5"
    case speed10 = "sweetarrows.speed_10"
    case runs50 = "sweetarrows.runs_50"
}

enum Leaderboard {
    /// Highest score (create as "high to low", all-time, in App Store Connect).
    static let endless = "sweetarrows.endless_score"
}

@MainActor
protocol GameCenterService: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate()
    func report(_ achievement: Achievement)
    func submitEndlessScore(_ score: Int)
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

    func submitEndlessScore(_ score: Int) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Leaderboard.endless]) { _ in }
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
    func submitEndlessScore(_ score: Int) {}
}
