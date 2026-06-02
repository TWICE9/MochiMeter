//
//  RunningCrossTrainingPage.swift
//  Yumo
//
//  Asks what other activities the user already does AND which days they
//  typically do them. The plan generator uses the per-day schedule to slot
//  running sessions around existing fixed workouts — no intervals the day
//  after leg day, recovery jogs near gym days, etc.
//

import SwiftUI

struct RunningCrossTrainingPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    private let allDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]

    var body: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)

        OnboardingQuestionView(
            question: "Anything else you do?",
            subtitle: "Pick the days you already train so we can build your runs around them.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 22) {
                activityGrid

                if !flowManager.crossTrainingActivities.isEmpty {
                    Divider().opacity(0.3)

                    schedulePicker

                    summaryFooter
                } else {
                    Text("Skip if you only run — leave activities unselected.")
                        .font(.caption)
                        .foregroundColor(muted)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 8)

                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
    }

    // MARK: - Activity multi-select

    private var activityGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(CrossTrainingActivity.allCases) { activity in
                activityCard(activity)
            }
        }
    }

    @ViewBuilder
    private func activityCard(_ activity: CrossTrainingActivity) -> some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)
        let isSelected = flowManager.crossTrainingActivities.contains(activity)

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(duration: 0.25)) {
                if isSelected {
                    flowManager.crossTrainingActivities.remove(activity)
                    // Clear out any day selections that belonged to this activity
                    // — keeping orphaned slots around makes the schedule lie about
                    // what the user picked.
                    flowManager.crossTrainingSchedule.removeValue(forKey: activity)
                } else {
                    flowManager.crossTrainingActivities.insert(activity)
                    if flowManager.crossTrainingSchedule[activity] == nil {
                        flowManager.crossTrainingSchedule[activity] = []
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(activity.emoji).font(.title3)
                Text(activity.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? Color("AppSecondaryAccent") : primary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(Color("AppSecondaryAccent"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color("AppSecondaryAccent").opacity(0.12) : background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color("AppSecondaryAccent") : stroke,
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .foregroundColor(muted)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Per-activity day picker

    private var schedulePicker: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)
        // Render selected activities in the same order they appear in
        // CrossTrainingActivity.allCases so the layout stays stable as the
        // user toggles items.
        let orderedSelected = CrossTrainingActivity.allCases
            .filter { flowManager.crossTrainingActivities.contains($0) }

        return VStack(alignment: .leading, spacing: 14) {
            Text("WHEN DO YOU DO THEM")
                .font(.caption.weight(.bold))
                .foregroundColor(muted)

            ForEach(orderedSelected) { activity in
                activityScheduleRow(activity)
            }
        }
    }

    @ViewBuilder
    private func activityScheduleRow(_ activity: CrossTrainingActivity) -> some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)
        let pickedDays = flowManager.crossTrainingSchedule[activity] ?? []

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(activity.emoji).font(.subheadline)
                Text(activity.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(primary)
                Spacer(minLength: 0)
                Text(pickedDays.isEmpty ? "no fixed days" : "\(pickedDays.count) / wk")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(muted)
            }

            HStack(spacing: 6) {
                ForEach(allDays) { day in
                    let isOn = pickedDays.contains(day)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var days = flowManager.crossTrainingSchedule[activity] ?? []
                        if isOn { days.remove(day) } else { days.insert(day) }
                        flowManager.crossTrainingSchedule[activity] = days
                    } label: {
                        Text(day.shortLabel)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isOn ? Color("AppSecondaryAccent") : background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isOn ? Color("AppSecondaryAccent") : stroke,
                                                    lineWidth: 1)
                                    )
                            )
                            .foregroundColor(isOn ? .white : primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(background.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(stroke, lineWidth: 1))
        )
    }

    // MARK: - Footer

    private var summaryFooter: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)
        let total = flowManager.crossTrainingSessionsPerWeek
        let label: String
        if total == 0 {
            label = "Pick days for the activities you do regularly — leave blank for occasional ones."
        } else {
            label = "We'll plan your runs around \(total) cross-training session\(total == 1 ? "" : "s") a week."
        }
        return Text(label)
            .font(.caption)
            .foregroundColor(muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
