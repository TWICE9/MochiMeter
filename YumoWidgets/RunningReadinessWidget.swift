// YumoWidgets/RunningReadinessWidget.swift

import WidgetKit
import SwiftUI

// MARK: - Provider

struct ReadinessProvider: TimelineProvider {

    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: .now, recovery: 78, sleepHours: 7.5, strain: 8.4, hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = read()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }

    private func read() -> ReadinessEntry {
        let d = UserDefaults(suiteName: "group.com.jesseta.yumo")
        let recovery = d?.integer(forKey: "readiness_recovery") ?? -1
        let strain = d?.double(forKey: "readiness_strain") ?? -1
        let sleep = d?.double(forKey: "readiness_sleep_hours") ?? 0
        let hasData = recovery >= 0
        return ReadinessEntry(
            date: .now,
            recovery: hasData ? recovery : 0,
            sleepHours: sleep,
            strain: strain >= 0 ? strain : 0,
            hasData: hasData
        )
    }
}

// MARK: - Entry

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let recovery: Int          // 0–100
    let sleepHours: Double
    let strain: Double         // 0–21
    let hasData: Bool

    /// Combines recovery, sleep and strain into a single 0–100 readiness.
    /// Recovery is the dominant signal; sleep and strain nudge it ±15 each way.
    var readinessScore: Int {
        let base = Double(recovery)
        let sleepDelta: Double = {
            if sleepHours <= 0 { return 0 }
            if sleepHours >= 7.5 { return 5 }
            if sleepHours >= 6.5 { return 0 }
            if sleepHours >= 5.5 { return -8 }
            return -15
        }()
        let strainDelta: Double = {
            if strain <= 0 { return 0 }
            if strain >= 17 { return -10 }
            if strain >= 13 { return -5 }
            return 0
        }()
        return max(0, min(100, Int((base + sleepDelta + strainDelta).rounded())))
    }

    var statusLabel: String {
        switch readinessScore {
        case 80...: return "Prime to Run"
        case 60..<80: return "Good to Run"
        case 40..<60: return "Take it Easy"
        case 20..<40: return "Recovery Day"
        default: return "Rest Today"
        }
    }

    var statusColor: Color {
        switch readinessScore {
        case 80...: return .green
        case 60..<80: return Color(red: 0.55, green: 0.85, blue: 0.4)
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
}

// MARK: - View

struct RunningReadinessWidgetView: View {
    var entry: ReadinessEntry
    @Environment(\.colorScheme) var colorScheme

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
        if entry.hasData {
            mainBody
        } else {
            emptyBody
        }
    }

    private var mainBody: some View {
        HStack(spacing: 18) {
            // Big readiness ring + score
            ZStack {
                Circle()
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                Circle()
                    .trim(from: 0, to: Double(entry.readinessScore) / 100.0)
                    .stroke(entry.statusColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(entry.readinessScore)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text("readiness")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(secondaryText)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(entry.statusColor)
                    Text("Running Readiness")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryText)
                }

                Text(entry.statusLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)

                VStack(alignment: .leading, spacing: 4) {
                    statRow(icon: "heart.fill", color: .pink,
                            label: "Recovery", value: "\(entry.recovery)")
                    statRow(icon: "moon.fill", color: .indigo,
                            label: "Sleep", value: String(format: "%.1fh", entry.sleepHours))
                    statRow(icon: "bolt.fill", color: .orange,
                            label: "Strain", value: String(format: "%.1f", entry.strain))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .widgetURL(URL(string: "yumo://activity"))
        .containerBackground(for: .widget) { bgColor }
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(primaryText)
        }
    }

    private var emptyBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 26))
                .foregroundStyle(secondaryText)
            Text("Open Yumo to sync\nrunning readiness")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "yumo://activity"))
        .containerBackground(for: .widget) { bgColor }
    }
}

// MARK: - Widget

struct RunningReadinessWidget: Widget {
    let kind = "RunningReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            RunningReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Running Readiness")
        .description("Your daily readiness to run, based on recovery, sleep, and strain.")
        .supportedFamilies([.systemMedium])
    }
}
