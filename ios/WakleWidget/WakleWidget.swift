import WidgetKit
import SwiftUI

private let appGroupId = "group.com.yashnimkar.chessAlarm"
private let signalColor = Color(red: 1.0, green: 0.72, blue: 0.30) // AppTokens.signal
private let nightBg = Color(red: 0.02, green: 0.02, blue: 0.05)

struct WakleEntry: TimelineEntry {
    let date: Date
    let nextAlarmLabel: String
    let currentStreak: Int
}

struct WakleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WakleEntry {
        WakleEntry(date: Date(), nextAlarmLabel: "No alarm set", currentStreak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WakleEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WakleEntry>) -> Void) {
        let entry = readEntry()
        // Widget content only changes when the app writes new data (a new
        // alarm is set, or a streak updates), so a single-entry timeline
        // that never expires on its own is correct here - WidgetKit is told
        // to reload explicitly via HomeWidget.updateWidget() from Dart.
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func readEntry() -> WakleEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let label = defaults?.string(forKey: "next_alarm_label") ?? "No alarm set"
        let streak = defaults?.integer(forKey: "current_streak") ?? 0
        return WakleEntry(date: Date(), nextAlarmLabel: label, currentStreak: streak)
    }
}

struct WakleWidgetEntryView: View {
    var entry: WakleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            nightBg
            VStack(alignment: .leading, spacing: 6) {
                Text("NEXT ALARM")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                Text(entry.nextAlarmLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Spacer()
                if family != .systemSmall || entry.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(signalColor)
                            .font(.system(size: 13))
                        Text("\(entry.currentStreak) day streak")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(signalColor)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WakleWidget: Widget {
    let kind: String = "WakleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WakleTimelineProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                WakleWidgetEntryView(entry: entry)
                    .containerBackground(nightBg, for: .widget)
            } else {
                WakleWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Next Alarm")
        .description("Shows your next alarm and current streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WakleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WakleWidget()
    }
}
