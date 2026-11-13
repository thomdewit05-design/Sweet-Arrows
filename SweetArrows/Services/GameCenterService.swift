import GameKit
import SweetArrowsCore
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
    /// The daily challenge: create as a recurring leaderboard that resets every day.
    static let daily = "sweetarrows.daily_challenge"
    static let zen = "sweetarrows.zen_score"
    static let blitz = "sweetarrows.blitz_score"
    /// The weekly tournament: a recurring leaderboard that resets every Monday.
    static let weekly = "sweetarrows.weekly_tournament"

    static func id(for mode: GameMode) -> String {
        switch mode {
        case .classic: endless
        case .daily: daily
        case .zen: zen
        case .blitz: blitz
        }
    }
}

@MainActor
protocol GameCenterService: AnyObject {
    var isAuthenticated: Bool { get }
    func authenticate()
    func report(_ achievement: Achievement)
    func submit(score: Int, mode: GameMode)
    /// Opens the Game Center leaderboards (scores of friends and everyone).
    func showLeaderboards()
}

/// Game Center through GameKit. Everything is optional: offline or signed out, calls do nothing.
@MainActor
final class GameKitService: GameCenterService {
    private(set) var isAuthenticated = false
    private var reported = Set<Achievement>()

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { @Sendable viewController, _ in
            nonisolated(unsafe) let viewController = viewController
            onMain {
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if let viewController { GameKitService.present(viewController) }
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

    func submit(score: Int, mode: GameMode) {
        guard isAuthenticated, score > 0 else { return }
        // Classic runs also count for the weekly tournament.
        let boards = mode == .classic ? [Leaderboard.id(for: mode), Leaderboard.weekly] : [Leaderboard.id(for: mode)]
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: boards) { _ in }
    }

    func showLeaderboards() {
        guard isAuthenticated else {
            authenticate()
            return
        }
        let viewController = GKGameCenterViewController(state: .leaderboards)
        viewController.gameCenterDelegate = LeaderboardCloser.shared
        Self.present(viewController)
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
    func submit(score: Int, mode: GameMode) {}
    func showLeaderboards() {}
}

/// Closes the Game Center screen when the player taps Done.
private final class LeaderboardCloser: NSObject, GKGameCenterControllerDelegate {
    @MainActor static let shared = LeaderboardCloser()

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        nonisolated(unsafe) let controller = gameCenterViewController
        onMain { controller.dismiss(animated: true) }
    }
}
