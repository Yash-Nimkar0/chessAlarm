import WidgetKit
import SwiftUI

private let appGroupId = "group.com.yashnimkar.chessAlarm"
private let signalColor = Color(red: 1.0, green: 0.72, blue: 0.30) // AppTokens.signal

/// Mirrors lib/utils/sky_gradient.dart's day-cycle key frames so the widget
/// and the app read as the same living sky, not two unrelated designs.
private func skyColors(for date: Date) -> [Color] {
    let hour = Double(Calendar.current.component(.hour, from: date)) +
        Double(Calendar.current.component(.minute, from: date)) / 60.0

    let stops: [(Double, Color, Color)] = [
        (0, Color(red: 0.06, green: 0.07, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.24)),
        (5, Color(red: 0.06, green: 0.07, blue: 0.16), Color(red: 0.18, green: 0.11, blue: 0.31)),
        (7, Color(red: 0.18, green: 0.11, blue: 0.31), Color(red: 1.0, green: 0.56, blue: 0.37)),
        (10, Color(red: 0.36, green: 0.61, blue: 0.84), Color(red: 1.0, green: 0.85, blue: 0.56)),
        (15, Color(red: 0.29, green: 0.56, blue: 0.85), Color(red: 1.0, green: 0.91, blue: 0.72)),
        (18, Color(red: 1.0, green: 0.56, blue: 0.37), Color(red: 0.42, green: 0.17, blue: 0.43)),
        (20, Color(red: 0.18, green: 0.11, blue: 0.31), Color(red: 0.06, green: 0.07, blue: 0.16)),
        (24, Color(red: 0.06, green: 0.07, blue: 0.16), Color(red: 0.10, green: 0.10, blue: 0.24)),
    ]

    for i in 0..<(stops.count - 1) {
        let (h0, a0, b0) = stops[i]
        let (h1, a1, b1) = stops[i + 1]
        if hour >= h0 && hour <= h1 {
            let t = (hour - h0) / (h1 - h0)
            return [lerp(a0, a1, t), lerp(b0, b1, t)]
        }
    }
    return [stops[0].1, stops[0].2]
}

private func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let ua = UIColor(a).cgColor.components ?? [0, 0, 0, 1]
    let ub = UIColor(b).cgColor.components ?? [0, 0, 0, 1]
    func mix(_ i: Int) -> Double { Double(ua[i]) + (Double(ub[i]) - Double(ua[i])) * t }
    return Color(red: mix(0), green: mix(1), blue: mix(2))
}

private func isDay(_ date: Date) -> Bool {
    let hour = Calendar.current.component(.hour, from: date)
    return hour >= 6 && hour < 19
}

struct WakleEntry: TimelineEntry {
    let date: Date
    let nextAlarmLabel: String
    let nextAlarmDate: Date?
    let currentStreak: Int
}

struct WakleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WakleEntry {
        WakleEntry(date: Date(), nextAlarmLabel: "No alarm set", nextAlarmDate: nil, currentStreak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WakleEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WakleEntry>) -> Void) {
        let entry = readEntry()
        // The sky gradient itself is time-dependent, so a handful of
        // same-data entries spread across the day let the background
        // actually drift through dawn/day/dusk/night on schedule even if
        // the app never calls HomeWidget.updateWidget() again that day -
        // the countdown text stays live either way via SwiftUI's own
        // relative-date rendering.
        let now = Date()
        var entries: [WakleEntry] = [entry]
        for hourOffset in stride(from: 1, through: 6, by: 1) {
            if let future = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now) {
                entries.append(WakleEntry(date: future, nextAlarmLabel: entry.nextAlarmLabel, nextAlarmDate: entry.nextAlarmDate, currentStreak: entry.currentStreak))
            }
        }
        completion(Timeline(entries: entries, policy: .after(Calendar.current.date(byAdding: .hour, value: 6, to: now) ?? now)))
    }

    private func readEntry() -> WakleEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let label = defaults?.string(forKey: "next_alarm_label") ?? "No alarm set"
        let streak = defaults?.integer(forKey: "current_streak") ?? 0
        let epoch = defaults?.integer(forKey: "next_alarm_epoch") ?? 0
        let alarmDate = epoch > 0 ? Date(timeIntervalSince1970: TimeInterval(epoch)) : nil
        return WakleEntry(date: Date(), nextAlarmLabel: label, nextAlarmDate: alarmDate, currentStreak: streak)
    }
}

/// A quiet field of stars/light motes behind the hero, matching the app's
/// own SkyParticlesLayer concept. WidgetKit can't run a continuous
/// animation loop the way the app can, so this is a fixed, seeded
/// scattering rather than a twinkle - still gives the background texture
/// instead of a flat gradient rectangle.
private struct SkyParticles: View {
    let night: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<(night ? 22 : 10), id: \.self) { i in
                    let seed = Double(i) * 12.9898
                    let x = (sin(seed) * 0.5 + 0.5) * geo.size.width
                    let y = (cos(seed * 1.7) * 0.5 + 0.5) * geo.size.height
                    let r = night ? CGFloat(0.6 + (seed.truncatingRemainder(dividingBy: 1.4))) : CGFloat(1.5 + (seed.truncatingRemainder(dividingBy: 2.0)))
                    let alpha = night ? 0.25 + (seed.truncatingRemainder(dividingBy: 0.5)) : 0.10 + (seed.truncatingRemainder(dividingBy: 0.12))
                    Circle()
                        .fill(Color.white.opacity(alpha))
                        .frame(width: r * 2, height: r * 2)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

struct WakleWidgetEntryView: View {
    var entry: WakleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let night = !isDay(entry.date)
        let colors = skyColors(for: entry.date)

        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            SkyParticles(night: night)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("NEXT ALARM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: night ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }

                Text(entry.nextAlarmLabel)
                    .font(.system(size: family == .systemSmall ? 30 : 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let alarmDate = entry.nextAlarmDate {
                    Text(alarmDate, style: .relative)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        + Text(" left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                if family != .systemSmall || entry.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(signalColor)
                            .font(.system(size: 13))
                        Text("\(entry.currentStreak) day streak")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
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
        // WidgetKit insets content by its own default margins unless told
        // otherwise, which left a visible strip of the plain containerBackground
        // showing around the gradient instead of the sky reaching every edge
        // the way Apple's own widgets do - contentMarginsDisabled() is what
        // actually fixes that, not anything about the gradient's own sizing.
        // Both APIs are iOS 17+, which is why this extension's own minimum
        // deployment target was raised to 17.0 (it's a standalone native
        // target with no dependency on the main app's SPM packages, so this
        // doesn't reintroduce the deployment-target conflict fixed earlier
        // for home_widget).
        StaticConfiguration(kind: kind, provider: WakleTimelineProvider()) { entry in
            WakleWidgetEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("Next Alarm")
        .description("Shows your next alarm, a live countdown, and your streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct WakleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WakleWidget()
    }
}
