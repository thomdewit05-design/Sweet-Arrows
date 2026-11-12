import SwiftUI
import SweetArrowsCore
import WidgetKit

/// Home screen widget: today's daily challenge and how long the season and the weekly tournament still run.
/// Everything follows from the date, so the widget needs no data from the app.
@main
struct SweetArrowsWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyWidget()
    }
}

struct DailyEntry: TimelineEntry {
    let date: Date
    let day: Int

    var seasonDaysLeft: Int { SeasonPass.daysLeft(today: day) }
    var tournamentDaysLeft: Int { WeeklyTournament.daysLeft(today: day) }

    static func make(for date: Date) -> DailyEntry {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let day = DayNumber.from(year: parts.year ?? 2026, month: parts.month ?? 1, day: parts.day ?? 1)
        return DailyEntry(date: date, day: day)
    }
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry { .make(for: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(.make(for: Date()))
    }

    /// One entry now and one at every midnight for the next few days.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries = [DailyEntry.make(for: Date())]
        for offset in 1...3 {
            if let next = calendar.date(byAdding: .day, value: offset, to: today) {
                entries.append(.make(for: next))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DailyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SweetArrowsDaily", provider: DailyProvider()) { entry in
            DailyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 1, green: 0.62, blue: 0.75), Color(red: 0.64, green: 0.35, blue: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName(Text("Daily challenge"))
        .description(Text("Today's board, the season and the weekly tournament at a glance."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyWidgetView: View {
    let entry: DailyEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            star(size: 34)
            Spacer(minLength: 0)
            Text("Daily challenge")
                .font(.system(.headline, design: .rounded).weight(.bold))
            Text("A new board is ready!")
                .font(.system(.caption, design: .rounded))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "sweetarrows://play/daily"))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Link(destination: URL(string: "sweetarrows://play/daily")!) {
                VStack(alignment: .leading, spacing: 4) {
                    star(size: 40)
                    Spacer(minLength: 0)
                    Text("Daily challenge")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Text("A new board is ready!")
                        .font(.system(.caption, design: .rounded))
                        .opacity(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Link(destination: URL(string: "sweetarrows://prizes")!) {
                VStack(alignment: .leading, spacing: 8) {
                    row(icon: "flag.checkered", title: Text("Season"), detail: Text("\(entry.seasonDaysLeft) days left"))
                    row(icon: "trophy.fill", title: Text("Tournament"), detail: Text("\(entry.tournamentDaysLeft) days left"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
    }

    private func row(icon: String, title: Text, detail: Text) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.25)))
            VStack(alignment: .leading, spacing: 0) {
                title.font(.system(.subheadline, design: .rounded).weight(.bold))
                detail.font(.system(.caption, design: .rounded)).opacity(0.9)
            }
        }
    }

    private func star(size: CGFloat) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: size * 0.8, weight: .bold))
            .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.3))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.3)))
    }
}
