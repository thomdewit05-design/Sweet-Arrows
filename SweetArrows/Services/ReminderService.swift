import Foundation
import SweetArrowsCore
import UserNotifications

/// Daily reminders as local notifications: only after the player said yes, at most one a day,
/// planned again every time the app goes to the background (so playing pushes them back).
@MainActor
enum ReminderService {
    private static let hour = 18
    private static let minute = 30
    private static let prefix = "sweetarrows.reminder."

    /// Asks iOS for permission. Returns true when notifications may be shown.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces the planned reminders (or just clears them when reminders are off).
    static func reschedule(enabled: Bool, streak: Int) {
        let center = UNUserNotificationCenter.current()
        // Our reminders have fixed names (one per planned day), so they can be removed without a lookup.
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { prefix + "\($0)" })
        guard enabled else { return }
        let calendar = Calendar.current
        for reminder in ReminderPlan.plan(streak: streak) {
            guard let day = calendar.date(byAdding: .day, value: reminder.day, to: Date()) else { continue }
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = hour
            parts.minute = minute
            let content = UNMutableNotificationContent()
            content.title = "Sweet Arrows"
            content.body = text(for: reminder.kind, streak: streak)
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + "\(reminder.day)", content: content, trigger: trigger))
        }
    }

    private static func text(for kind: ReminderPlan.Kind, streak: Int) -> String {
        switch kind {
        case .missions: String(localized: "Your daily missions are ready 🍬")
        case .streak: String(localized: "Don't lose your \(streak)-day streak! 🔥")
        case .comeBack: String(localized: "The candies miss you! Come pop a few 🍭")
        }
    }
}
