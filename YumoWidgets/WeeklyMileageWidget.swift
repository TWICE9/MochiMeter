// YumoWidgets/WeeklyMileageWidget.swift

import WidgetKit
import SwiftUI

// MARK: - Provider

struct MileageProvider: TimelineProvider {

    func placeholder(in context: Context) -> MileageEntry {
        MileageEntry(date: .now, currentKm: 24.5, goalKm: 40)
    }

    func getSnapshot(in context: Context, completion: @escaping (MileageEntry) -> Void) {
        completion(MileageEntry(date: .now, currentKm: readCurrentKm(), goalKm: readGoalKm()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MileageEntry>) -> Void) {
        let entry = MileageEntry(date: .now, currentKm: readCurrentKm(), goalKm: readGoalKm())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }

    private func readCurrentKm() -> Double {
        UserDefaults(suiteName: "group.com.jesseta.yumo")?.double(forKey: "weekly_run_km") ?? 0
    }

    private func readGoalKm() -> Double {
        let v = UserDefaults(suiteName: "group.com.jesseta.yumo")?.double(forKey: "weekly_run_goal_km") ?? 0
        return v > 0 ? v : 40
    }
}

// MARK: - Entry

struct MileageEntry: TimelineEntry {
    let date: Date
    let currentKm: Double
    let goalKm: Double
    var progress: Double { goalKm > 0 ? min(currentKm / goalKm, 1.0) : 0 }
}

// MARK: - View

struct WeeklyMileageWidgetView: View {
    var entry: MileageEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    private var themeColor: Color {
        if let name = UserDefaults(suiteName: "group.com.jesseta.yumo")?.string(forKey: "selectedTheme"),
           let theme = MochiTheme(rawValue: name) {
            return colorScheme == .dark ? theme.darkPrimaryColor : theme.primaryColor
        }
        return Color("AppSecondaryAccent")
    }

    private var primaryText: Color { colorScheme == .dark ? .white : .black }
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(white: 0.4)
    }
    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
    }
    private var bgColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .accessoryCircular:
            circularBody
        case .accessoryRectangular:
            rectangularBody
        default:
            smallBody
        }
    }

    // MARK: Small

    private var smallBody: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text("This week")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryText)
                Spacer()
            }

            Spacer()

            // Arc + km
            ZStack {
                Circle()
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(String(format: "%.1f", entry.currentKm))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text("km")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
            }
            .frame(width: 80, height: 80)

            Spacer()

            // Goal line
            Text("Goal: \(String(format: "%.0f", entry.goalKm)) km")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryText)
        }
        .padding(14)
        .widgetURL(URL(string: "yumo://activity"))
        .containerBackground(for: .widget) {
            ZStack {
                bgColor
                if colorScheme == .light {
                    LinearGradient(
                        colors: [themeColor.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    // MARK: Medium

    private var mediumBody: some View {
        HStack(spacing: 20) {
            // Arc
            ZStack {
                Circle()
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(themeColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", entry.currentKm))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text("km")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
            }
            .frame(width: 105, height: 105)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeColor)
                    Text("Weekly Mileage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(secondaryText)
                }

                Text(String(format: "%.1f / %.0f km", entry.currentKm, entry.goalKm))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(trackColor).frame(height: 6)
                        Capsule()
                            .fill(themeColor)
                            .frame(width: geo.size.width * entry.progress, height: 6)
                    }
                }
                .frame(height: 6)

                let remaining = max(entry.goalKm - entry.currentKm, 0)
                Text(remaining > 0
                     ? String(format: "%.1f km to go", remaining)
                     : "Weekly goal reached 🎉")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(remaining > 0 ? secondaryText : themeColor)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .widgetURL(URL(string: "yumo://activity"))
        .containerBackground(for: .widget) {
            ZStack {
                bgColor
                if colorScheme == .light {
                    LinearGradient(
                        colors: [themeColor.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    // MARK: Lock screen circular

    private var circularBody: some View {
        Gauge(value: entry.currentKm, in: 0...max(entry.goalKm, 1)) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(String(format: "%.0f", entry.currentKm))
                    .font(.system(size: 16, weight: .bold))
                Text("km")
                    .font(.system(size: 8))
            }
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Lock screen rectangular

    private var rectangularBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 11, weight: .semibold))
                Text("Weekly Run")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: "%.1f / %.0f km", entry.currentKm, entry.goalKm))
                    .font(.system(size: 12, weight: .bold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.3)).frame(height: 4)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * entry.progress, height: 4)
                }
            }
            .frame(height: 4)
            let remaining = max(entry.goalKm - entry.currentKm, 0)
            Text(remaining > 0
                 ? String(format: "%.1f km remaining this week", remaining)
                 : "Weekly goal reached!")
                .font(.system(size: 11))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

struct WeeklyMileageWidget: Widget {
    let kind = "WeeklyMileageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MileageProvider()) { entry in
            WeeklyMileageWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Mileage")
        .description("Track your running km against your weekly goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
