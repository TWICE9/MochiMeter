//
//  SessionCompleteSheet.swift
//  Yumo

import SwiftUI

struct SessionCompleteSheet: View {
    let session: PlannedSession
    let isImperial: Bool
    var onComplete: (_ distanceKm: Double?, _ durationMinutes: Int?, _ source: String) -> Void
    var onSkip: () -> Void
    var onUnmark: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var allRuns: [WorkoutSummary] = []
    @State private var selectedWorkout: WorkoutSummary? = nil
    @State private var isSearchingHK = true
    @State private var hkSearchDone = false

    private var unitLabel: String { isImperial ? "mi" : "km" }

    // Mirror main app text colours
    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    private var recommendedRun: WorkoutSummary? {
        let sessionDay = Calendar.current.startOfDay(for: session.scheduledDate)
        let sameDay = allRuns.first {
            abs(Calendar.current.dateComponents([.day], from: sessionDay,
                to: Calendar.current.startOfDay(for: $0.date)).day ?? 99) == 0
        }
        return sameDay ?? allRuns.first {
            abs(Calendar.current.dateComponents([.day], from: sessionDay,
                to: Calendar.current.startOfDay(for: $0.date)).day ?? 99) <= 1
        }
    }

    private var otherRuns: [WorkoutSummary] {
        allRuns.filter { $0.id != recommendedRun?.id }
    }

    private var sessionTint: Color {
        switch session.sessionType {
        case .easy, .recovery: return .green
        case .long:            return .blue
        case .tempo:           return .orange
        case .intervals:       return .red
        case .race:            return .purple
        case .cross:           return .teal
        case .rest:            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    sessionHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    healthKitContent
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 48)
                }
            }

            actionBar
        }
        // Custom Capsule drag handle removed — the system drag
        // indicator (set at the call site) is what users actually see.
        // Showing both stacked the two grabbers visually.
        .presentationDragIndicator(.visible)
        .task { await searchHealthKit() }
    }

    // MARK: - Session header

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(sessionTint.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: sessionIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(sessionTint.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sessionType.displayLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(session.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if let km = session.targetDistanceKm, km > 0   { chip(formatDist(km), color: sessionTint) }
                if let m  = session.targetDurationMinutes, m > 0 { chip("\(m) min", color: sessionTint) }
                if let p  = session.targetPaceSecondsPerKm, p > 0 { chip(formatPace(p), color: sessionTint) }
            }

            if !session.sessionDescription.isEmpty {
                Text(session.sessionDescription)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - HealthKit content

    @ViewBuilder
    private var healthKitContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.pink.opacity(0.8))
                    .font(.subheadline)
                Text("From Apple Health")
                    .font(.headline)
                    .foregroundStyle(primaryText)
                Spacer()
                if isSearchingHK {
                    ProgressView().controlSize(.small)
                }
            }

            if isSearchingHK {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.04))
                    .frame(height: 72)
                    .overlay(
                        Text("Searching for runs…")
                            .font(.subheadline)
                            .foregroundStyle(tertiaryText)
                    )
            } else if allRuns.isEmpty {
                Text("No runs found in Apple Health for the past 2 weeks.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
            } else {
                if let rec = recommendedRun {
                    runRow(rec, label: "BEST MATCH")
                }

                if !otherRuns.isEmpty {
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                        Text("other runs")
                            .font(.caption2)
                            .foregroundStyle(tertiaryText)
                            .fixedSize()
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 0.5)
                    }
                    .padding(.vertical, 4)

                    VStack(spacing: 8) {
                        ForEach(otherRuns) { run in
                            runRow(run, label: nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Run row

    private func runRow(_ run: WorkoutSummary, label: String?) -> some View {
        let isSelected = selectedWorkout?.id == run.id
        let distKm = (run.distanceMeters ?? 0) / 1000
        let durMin = run.durationMinutes

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) { selectedWorkout = run }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.pink.opacity(0.12) : Color.primary.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "figure.run")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.pink.opacity(0.8) : tertiaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(relativeDay(run.date))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryText)
                        if let label {
                            Text(label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.pink)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.pink.opacity(0.12)))
                        }
                    }
                    HStack(spacing: 4) {
                        if distKm > 0.01 {
                            Text(formatDist(distKm)).font(.caption).foregroundStyle(secondaryText)
                            Text("·").font(.caption).foregroundStyle(tertiaryText)
                        }
                        Text("\(Int(durMin)) min").font(.caption).foregroundStyle(secondaryText)
                        if distKm > 0.01 && durMin > 0 {
                            Text("·").font(.caption).foregroundStyle(tertiaryText)
                            Text(formatActualPace(distanceKm: distKm, durationMinutes: durMin))
                                .font(.caption).foregroundStyle(secondaryText)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.pink.opacity(0.06) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.pink.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.25)

            VStack(spacing: 10) {
                if session.isCompleted {
                    Button(role: .destructive) {
                        onUnmark(); dismiss()
                    } label: {
                        Text("Mark as Not Done")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else {
                    if let selected = selectedWorkout {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            let distKm = selected.distanceMeters.map { $0 / 1000 }
                            let durMins = Int(selected.durationMinutes)
                            onComplete(distKm, durMins > 0 ? durMins : nil, "healthkit")
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill").font(.subheadline)
                                Text("Link \(relativeDay(selected.date))")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.pink.opacity(0.14))
                            .foregroundStyle(Color.pink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }

                    HStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onComplete(session.targetDistanceKm, session.targetDurationMinutes, "manual")
                            dismiss()
                        } label: {
                            Text("Done manually")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(secondaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSkip(); dismiss()
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(secondaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
    }

    // MARK: - HealthKit search

    private func searchHealthKit() async {
        isSearchingHK = true
        defer { isSearchingHK = false; hkSearchDone = true }

        let manager = HealthKitManager.shared
        let runs = await manager.fetchRecentRuns(limit: 20, daysBack: 14)

        await MainActor.run {
            allRuns = runs
            selectedWorkout = recommendedRun
        }
    }

    // MARK: - Helpers

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        let time = date.formatted(.dateTime.hour().minute())
        switch diff {
        case 0:  return "Today · \(time)"
        case 1:  return "Yesterday · \(time)"
        default: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) + " · \(time)"
        }
    }

    private func formatDist(_ km: Double) -> String {
        let v = isImperial ? km * 0.621371 : km
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, unitLabel)
    }

    private func formatPace(_ spk: Int) -> String {
        let s = isImperial ? Int(Double(spk) / 0.621371) : spk
        return String(format: "%d:%02d /%@", s / 60, s % 60, unitLabel)
    }

    private func formatActualPace(distanceKm: Double, durationMinutes: Double) -> String {
        guard distanceKm > 0 else { return "" }
        let d = isImperial ? distanceKm * 0.621371 : distanceKm
        let s = (durationMinutes * 60) / d
        return String(format: "%d:%02d /%@", Int(s) / 60, Int(s) % 60, unitLabel)
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private var sessionIcon: String {
        switch session.sessionType {
        case .easy, .recovery: return "figure.run"
        case .long:            return "arrow.up.right"
        case .tempo:           return "flame.fill"
        case .intervals:       return "bolt.fill"
        case .race:            return "flag.checkered"
        case .cross:           return "figure.mixed.cardio"
        case .rest:            return "moon.zzz.fill"
        }
    }
}
