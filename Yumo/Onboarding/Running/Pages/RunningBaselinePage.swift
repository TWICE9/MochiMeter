//
//  RunningBaselinePage.swift
//  Yumo
//
//  Captures recent benchmark times (1K / 5K / 10K / HM / Full) so the AI plan
//  generator has real pace data to calibrate against. Supports prefilling
//  from Apple Health. Typical weekly volume is captured here too since the
//  pace calibration and volume progression need each other.
//

import SwiftUI

struct RunningBaselinePage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var weeklyKmInput: String = ""
    @State private var activeEntry: BenchmarkDistance? = nil
    @State private var isLoadingHealth = false
    @State private var healthPrefillMessage: String? = nil

    private var unitLabel: String { flowManager.isImperial ? "mi" : "km" }

    enum BenchmarkDistance: String, Identifiable, CaseIterable {
        case k1 = "1K"
        case k5 = "5K"
        case k10 = "10K"
        case half = "Half"
        case full = "Full"

        var id: String { rawValue }

        var km: Double {
            switch self {
            case .k1: return 1.0
            case .k5: return 5.0
            case .k10: return 10.0
            case .half: return 21.0975
            case .full: return 42.195
            }
        }

        var longLabel: String {
            switch self {
            case .k1: return "1K"
            case .k5: return "5K"
            case .k10: return "10K"
            case .half: return "Half Marathon"
            case .full: return "Marathon"
            }
        }
    }

    var body: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)

        OnboardingQuestionView(
            question: "Recent times",
            subtitle: "Tap any distances you've run recently. This tunes your plan's training paces.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 20) {
                distanceGrid

                healthPrefillButton

                if let msg = healthPrefillMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(muted)
                        .multilineTextAlignment(.center)
                }

                Divider().opacity(0.3)

                weeklyVolumeField

                Text("All fields are optional — leave blank if you're not sure.")
                    .font(.caption)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: {
                        commitWeekly()
                        flowManager.goNext()
                    }
                )
            }
        }
        .onAppear {
            weeklyKmInput = flowManager.currentWeeklyKm.map {
                String(format: "%g", flowManager.isImperial ? $0 * 0.621371 : $0)
            } ?? ""
        }
        .sheet(item: $activeEntry) { distance in
            TimeEntrySheet(
                distance: distance,
                seconds: currentSeconds(for: distance),
                onSave: { seconds in setSeconds(seconds, for: distance) },
                onClear: { setSeconds(nil, for: distance) }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Distance grid

    private var distanceGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(BenchmarkDistance.allCases) { distance in
                distanceCard(distance)
            }
        }
    }

    @ViewBuilder
    private func distanceCard(_ distance: BenchmarkDistance) -> some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)
        let seconds = currentSeconds(for: distance)
        let isSet = seconds != nil

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeEntry = distance
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(distance.longLabel)
                        .font(.caption.weight(.bold))
                        .foregroundColor(isSet ? Color("AppSecondaryAccent") : muted)
                    Spacer()
                    if isSet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color("AppSecondaryAccent"))
                    }
                }
                Text(isSet ? Self.formatSeconds(seconds!) : "Add time")
                    .font(.title3.weight(.bold))
                    .foregroundColor(isSet ? primary : muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSet ? Color("AppSecondaryAccent").opacity(0.12) : background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSet ? Color("AppSecondaryAccent") : stroke, lineWidth: isSet ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apple Health prefill

    private var healthPrefillButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await prefillFromHealth() }
        } label: {
            HStack(spacing: 8) {
                if isLoadingHealth {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                }
                Text(isLoadingHealth ? "Checking Apple Health…" : "Import from Apple Health")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(OnboardingTheme.primaryText(colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pink.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoadingHealth)
    }

    private func prefillFromHealth() async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }

        let candidates = await HealthKitRunTimes.fetchRecentBestTimes()

        await MainActor.run {
            var filledCount = 0
            if let s = candidates.k1Seconds, flowManager.recent1kmSeconds == nil {
                flowManager.recent1kmSeconds = s; filledCount += 1
            }
            if let s = candidates.k5Seconds, flowManager.recent5kmSeconds == nil {
                flowManager.recent5kmSeconds = s; filledCount += 1
            }
            if let s = candidates.k10Seconds, flowManager.recent10kmSeconds == nil {
                flowManager.recent10kmSeconds = s; filledCount += 1
            }
            if let s = candidates.halfMarathonSeconds, flowManager.recentHalfMarathonSeconds == nil {
                flowManager.recentHalfMarathonSeconds = s; filledCount += 1
            }
            if let s = candidates.marathonSeconds, flowManager.recentMarathonSeconds == nil {
                flowManager.recentMarathonSeconds = s; filledCount += 1
            }

            if filledCount > 0 {
                healthPrefillMessage = "Imported \(filledCount) time\(filledCount == 1 ? "" : "s") from Apple Health."
            } else if candidates.hasAny {
                healthPrefillMessage = "No new times to add — keeping your entries."
            } else {
                healthPrefillMessage = "No benchmark-distance runs found in Apple Health."
            }
        }
    }

    // MARK: - Weekly volume

    private var weeklyVolumeField: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        return VStack(alignment: .leading, spacing: 10) {
            Text("TYPICAL WEEKLY VOLUME")
                .font(.caption.weight(.bold))
                .foregroundColor(muted)

            HStack(spacing: 8) {
                TextField("e.g. 20", text: $weeklyKmInput)
                    .keyboardType(.decimalPad)
                    .foregroundColor(primary)
                Text(unitLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func currentSeconds(for distance: BenchmarkDistance) -> Int? {
        switch distance {
        case .k1: return flowManager.recent1kmSeconds
        case .k5: return flowManager.recent5kmSeconds
        case .k10: return flowManager.recent10kmSeconds
        case .half: return flowManager.recentHalfMarathonSeconds
        case .full: return flowManager.recentMarathonSeconds
        }
    }

    private func setSeconds(_ seconds: Int?, for distance: BenchmarkDistance) {
        switch distance {
        case .k1: flowManager.recent1kmSeconds = seconds
        case .k5: flowManager.recent5kmSeconds = seconds
        case .k10: flowManager.recent10kmSeconds = seconds
        case .half: flowManager.recentHalfMarathonSeconds = seconds
        case .full: flowManager.recentMarathonSeconds = seconds
        }
    }

    private func commitWeekly() {
        let trimmed = weeklyKmInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
            flowManager.currentWeeklyKm = nil
            return
        }
        flowManager.currentWeeklyKm = flowManager.isImperial ? value / 0.621371 : value
    }

    static func formatSeconds(_ total: Int) -> String {
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Time Entry Sheet

private struct TimeEntrySheet: View {
    let distance: RunningBaselinePage.BenchmarkDistance
    let seconds: Int?
    var onSave: (Int) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var secondsPart: Int = 0

    /// Longer distances need an hours column; shorter ones don't.
    private var showsHours: Bool {
        distance == .half || distance == .full
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(distance.longLabel)
                    .font(.title2.weight(.bold))
                Text("Enter your time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)

            HStack(spacing: 0) {
                if showsHours {
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<8) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Text("h").foregroundStyle(.secondary)
                }
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                Text("m").foregroundStyle(.secondary)

                Picker("Seconds", selection: $secondsPart) {
                    ForEach(0..<60) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                Text("s").foregroundStyle(.secondary)
            }
            .frame(height: 150)
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                if seconds != nil {
                    Button(role: .destructive) {
                        onClear()
                        dismiss()
                    } label: {
                        Text("Clear")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    let total = (hours * 3600) + (minutes * 60) + secondsPart
                    if total > 0 { onSave(total) }
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            let total = seconds ?? Self.defaultSeconds(for: distance)
            hours = total / 3600
            minutes = (total % 3600) / 60
            secondsPart = total % 60
        }
    }

    /// Pre-set a reasonable starting time if the user hasn't entered one yet —
    /// speeds up data entry vs starting at 0:00.
    static func defaultSeconds(for distance: RunningBaselinePage.BenchmarkDistance) -> Int {
        switch distance {
        case .k1: return 5 * 60 + 30
        case .k5: return 28 * 60
        case .k10: return 58 * 60
        case .half: return 2 * 3600 + 5 * 60
        case .full: return 4 * 3600 + 30 * 60
        }
    }
}
