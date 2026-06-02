//
//  RunningSessionRow.swift
//  Yumo
//
//  Shared row view for displaying a PlannedSession in lists (today, this week,
//  full plan). Compact enough for 7-day columns but readable.
//

import SwiftUI

struct RunningSessionRow: View {
    let session: PlannedSession
    let isImperial: Bool
    var showsDayLabel: Bool = true
    var isToday: Bool = false
    var onToggleComplete: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.75) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color(red: 140/255, green: 140/255, blue: 150/255)
    }

    private var unitLabel: String { isImperial ? "mi" : "km" }
    private var distanceDisplay: String? {
        guard let km = session.targetDistanceKm, km > 0 else { return nil }
        let value = isImperial ? km * 0.621371 : km
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = (value < 10 ? 1 : 0)
        let num = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(num) \(unitLabel)"
    }
    private var durationDisplay: String? {
        guard let mins = session.targetDurationMinutes, mins > 0 else { return nil }
        return "\(mins) min"
    }
    private var paceDisplay: String? {
        guard let pace = session.targetPaceSecondsPerKm, pace > 0 else { return nil }
        let paceSeconds = isImperial ? Int(Double(pace) / 0.621371) : pace
        let minutes = paceSeconds / 60
        let seconds = paceSeconds % 60
        return String(format: "%d:%02d /%@", minutes, seconds, unitLabel)
    }

    private var sessionTint: Color {
        switch session.sessionType {
        case .easy, .recovery: return .green
        case .long: return .blue
        case .tempo: return .orange
        case .intervals: return .red
        case .race: return .purple
        case .cross: return .teal
        case .rest: return .gray
        }
    }

    private var sessionIcon: String {
        switch session.sessionType {
        case .easy, .recovery: return "figure.run"
        case .long: return "arrow.up.right"
        case .tempo: return "flame.fill"
        case .intervals: return "bolt.fill"
        case .race: return "flag.checkered"
        case .cross: return "figure.mixed.cardio"
        case .rest: return "moon.zzz.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Colored session type icon.
            ZStack {
                Circle()
                    .fill(sessionTint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: sessionIcon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(sessionTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if showsDayLabel {
                        Text(dayLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isToday ? sessionTint : tertiaryText)
                    }
                    Text(session.sessionType.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    if session.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }

                if session.sessionType != .rest {
                    // Metrics chips.
                    HStack(spacing: 8) {
                        if let distance = distanceDisplay { chip(distance) }
                        if let duration = durationDisplay { chip(duration) }
                        if let pace = paceDisplay { chip(pace) }
                    }
                    Text(session.sessionDescription)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                } else {
                    Text("Rest day")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
            }

            Spacer(minLength: 0)

            if let onToggleComplete, session.sessionType.isRun {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onToggleComplete()
                }) {
                    Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(session.isCompleted ? sessionTint : tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(sessionTint.opacity(0.1))
            )
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.scheduledDate).uppercased()
    }
}
