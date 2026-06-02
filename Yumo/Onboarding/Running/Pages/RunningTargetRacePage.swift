//
//  RunningTargetRacePage.swift
//  Yumo
//

import SwiftUI

struct RunningTargetRacePage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingGoalTimePicker = false

    var body: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        OnboardingQuestionView(
            question: "Tell us about the race",
            subtitle: "We'll use this to build your plan week by week.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 20) {
                // Distance picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("DISTANCE")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)
                    HStack(spacing: 10) {
                        ForEach(RaceDistance.allCases) { dist in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                flowManager.targetRaceDistance = dist
                            } label: {
                                Text(dist.shortLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(flowManager.targetRaceDistance == dist ? Color.purple : background)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(stroke, lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(flowManager.targetRaceDistance == dist ? .white : primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Race name
                VStack(alignment: .leading, spacing: 10) {
                    Text("EVENT NAME (OPTIONAL)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)
                    TextField("e.g. Boston Marathon", text: $flowManager.targetRaceName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(stroke, lineWidth: 1)
                                )
                        )
                        .foregroundColor(primary)
                }

                // Race date
                VStack(alignment: .leading, spacing: 10) {
                    Text("RACE DATE")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)
                    DatePicker(
                        "Race Date",
                        selection: Binding(
                            get: { flowManager.targetRaceDate ?? Date() },
                            set: { flowManager.targetRaceDate = $0 }
                        ),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(stroke, lineWidth: 1)
                            )
                    )

                    if let warning = feasibilityWarning {
                        feasibilityCallout(warning)
                    }
                }

                // Goal time
                VStack(alignment: .leading, spacing: 10) {
                    Text("GOAL TIME (OPTIONAL)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingGoalTimePicker = true
                    } label: {
                        HStack {
                            if let secs = flowManager.targetRaceGoalTimeSeconds {
                                Text(formatSeconds(secs))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(primary)
                            } else {
                                Text("Set a goal time")
                                    .font(.subheadline)
                                    .foregroundColor(muted)
                            }
                            Spacer()
                            Image(systemName: flowManager.targetRaceGoalTimeSeconds != nil ? "clock.badge.checkmark" : "clock")
                                .foregroundColor(flowManager.targetRaceGoalTimeSeconds != nil ? Color("AppSecondaryAccent") : muted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(flowManager.targetRaceGoalTimeSeconds != nil ? Color("AppSecondaryAccent").opacity(0.12) : background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            flowManager.targetRaceGoalTimeSeconds != nil ? Color("AppSecondaryAccent") : stroke,
                                            lineWidth: flowManager.targetRaceGoalTimeSeconds != nil ? 1.5 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    if flowManager.targetRaceGoalTimeSeconds == nil,
                       let dist = flowManager.targetRaceDistance,
                       let suggestion = flowManager.suggestedGoalTime(for: dist) {
                        suggestionChip(suggestion: suggestion)
                    }
                }

                Spacer().frame(height: 8)

                ContinueButton(
                    title: "Continue",
                    isEnabled: flowManager.canProceed() && !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
        .sheet(isPresented: $showingGoalTimePicker) {
            let suggestedSeconds = flowManager.targetRaceDistance
                .flatMap { flowManager.suggestedGoalTime(for: $0)?.seconds }
            GoalTimeSheet(
                seconds: flowManager.targetRaceGoalTimeSeconds,
                distance: flowManager.targetRaceDistance,
                suggestedSeconds: suggestedSeconds,
                onSave: { flowManager.targetRaceGoalTimeSeconds = $0 },
                onClear: { flowManager.targetRaceGoalTimeSeconds = nil }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
    }

    private func formatSeconds(_ total: Int) -> String {
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Suggested goal time chip

    @ViewBuilder
    private func suggestionChip(suggestion: (seconds: Int, sourceLabel: String)) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            flowManager.targetRaceGoalTimeSeconds = suggestion.seconds
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                Text("Try \(formatSeconds(suggestion.seconds)) — based on your \(suggestion.sourceLabel)")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Race-feasibility warning

    /// Returns a warning message when the chosen race date doesn't leave enough
    /// runway given the target distance. Soft warning only — we don't block.
    private var feasibilityWarning: String? {
        guard let dist = flowManager.targetRaceDistance,
              let weeks = flowManager.weeksUntilRace
        else { return nil }
        let minWeeks = flowManager.recommendedMinimumWeeks(for: dist)
        guard weeks < minWeeks else { return nil }
        return "Most runners need ~\(minWeeks) weeks to prepare for a \(dist.shortLabel). Your race is \(weeks) week\(weeks == 1 ? "" : "s") away — we'll build the best plan we can, but consider a later date if you're starting from scratch."
    }

    @ViewBuilder
    private func feasibilityCallout(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(OnboardingTheme.primaryText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Goal Time Sheet

private struct GoalTimeSheet: View {
    let seconds: Int?
    let distance: RaceDistance?
    /// Optional Riegel-derived prediction from the user's baseline times.
    /// Used as the picker's starting value when no goal has been set yet.
    let suggestedSeconds: Int?
    var onSave: (Int) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int = 1
    @State private var minutes: Int = 45
    @State private var secondsPart: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Goal Time")
                    .font(.title2.weight(.bold))
                if let dist = distance {
                    Text("for \(dist.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)

            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(0..<12) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                Text("h").foregroundStyle(.secondary)

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
            if let s = seconds {
                hours = s / 3600
                minutes = (s % 3600) / 60
                secondsPart = s % 60
            } else if let s = suggestedSeconds, s > 0 {
                // Prefer the Riegel-derived prediction when we have one.
                hours = s / 3600
                minutes = (s % 3600) / 60
                secondsPart = s % 60
            } else {
                // Sensible fallback defaults per distance.
                switch distance {
                case .k5:   hours = 0; minutes = 28; secondsPart = 0
                case .k10:  hours = 0; minutes = 58; secondsPart = 0
                case .half: hours = 2; minutes = 5;  secondsPart = 0
                case .full: hours = 4; minutes = 30; secondsPart = 0
                case .none: hours = 1; minutes = 0;  secondsPart = 0
                }
            }
        }
    }
}
