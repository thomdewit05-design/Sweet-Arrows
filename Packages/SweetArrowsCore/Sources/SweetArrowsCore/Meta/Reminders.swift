/// Which reminder notifications to plan after the player leaves the app. At most one a day,
/// and they stop after a few days so the game never nags.
public enum ReminderPlan {
    public enum Kind: String, Sendable, Hashable {
        /// "Your daily missions are ready."
        case missions
        /// "Don't lose your N-day streak!" (only when there is a streak worth keeping).
        case streak
        /// A gentle "the candies miss you" after a few quiet days.
        case comeBack
    }

    public struct Reminder: Sendable, Hashable {
        /// Days from today (1 = tomorrow).
        public var day: Int
        public var kind: Kind
    }

    /// The reminders to schedule, given the streak as it stands today.
    public static func plan(streak: Int) -> [Reminder] {
        [
            Reminder(day: 1, kind: streak >= 2 ? .streak : .missions),
            Reminder(day: 2, kind: .missions),
            Reminder(day: 4, kind: .comeBack),
        ]
    }
}
