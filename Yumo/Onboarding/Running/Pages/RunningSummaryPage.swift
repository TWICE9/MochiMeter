//
//  RunningSummaryPage.swift
//  Yumo
//
//  Final onboarding step: shows a Runna-style preview of week 1 plus a
//  condensed recap of the user's inputs. Generated client-side from
//  RunningPlanPreviewBuilder — the actual plan from the AI generator may
//  differ in pacing/structure, but the preview sets the right expectation.
//

import SwiftUI

struct RunningSummaryPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var onFinish: () -> Void

    private var previewWeek: [PreviewSession] {
        RunningPlanPreviewBuilder.buildWeek(from: flowManager)
    }

    var body: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)

        OnboardingQuestionView(
            question: "Your first week",
            subtitle: "Here's what we'll build. The plan adapts as you log runs.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 18) {
                previewSection

                recapSection

                Text("Preview only — paces and distances are tuned by the AI based on your full profile.")
                    .font(.caption2)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        } footer: {
            ContinueButton(
                title: "Finish Setup",
                isEnabled: !flowManager.isNavigating,
                action: onFinish
            )
        }
    }

    // MARK: - Preview section

    private var previewSection: some View {
        VStack(spacing: 8) {
            ForEach(previewWeek) { session in
                previewRow(session)
            }
        }
    }

    @ViewBuilder
    private func previewRow(_ session: PreviewSession) -> some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)
        let accent = sessionColor(session.type)
        let isHighlight = session.type == .long
        let isRest = session.type == .rest

        HStack(spacing: 12) {
            // Day badge
            Text(session.weekday.shortLabel.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(isRest ? muted : accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isRest ? Color.gray.opacity(0.12) : accent.opacity(0.18))
                )

            // Session detail
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: sessionIcon(session.type))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(isRest ? muted : accent)
                    Text(session.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isRest ? muted : primary)
                }
                Text(session.detail)
                    .font(.caption)
                    .foregroundColor(muted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlight ? accent.opacity(0.10) : background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlight ? accent.opacity(0.4) : stroke,
                                lineWidth: isHighlight ? 1.5 : 1)
                )
        )
    }

    // MARK: - Recap section

    private var recapSection: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        return VStack(spacing: 8) {
            recapRow(
                icon: "target",
                label: "Goal",
                value: goalRecapValue,
                background: background, stroke: stroke,
                primary: primary, muted: muted
            )

            recapRow(
                icon: "calendar",
                label: "Schedule",
                value: scheduleRecapValue,
                background: background, stroke: stroke,
                primary: primary, muted: muted
            )
        }
    }

    private var goalRecapValue: String {
        if flowManager.primaryGoal == .trainForRace, let dist = flowManager.targetRaceDistance {
            let name = flowManager.targetRaceName.trimmingCharacters(in: .whitespaces)
            let titleLine = name.isEmpty ? dist.rawValue : "\(name) · \(dist.rawValue)"
            if let date = flowManager.targetRaceDate {
                return "\(titleLine) · \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return titleLine
        }
        return flowManager.primaryGoal.rawValue
    }

    private var scheduleRecapValue: String {
        let sortedDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
            .filter { flowManager.availableDays.contains($0) }
        let dayList = sortedDays.map { $0.shortLabel }.joined(separator: " · ")
        return "\(flowManager.weeklyRunDaysTarget) runs / week · \(dayList)"
    }

    @ViewBuilder
    private func recapRow(
        icon: String,
        label: String,
        value: String,
        background: Color,
        stroke: Color,
        primary: Color,
        muted: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(muted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(primary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(stroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Session styling helpers

    private func sessionColor(_ type: RunningSessionType) -> Color {
        switch type {
        case .easy:      return .green
        case .long:      return .purple
        case .tempo:     return .orange
        case .intervals: return .red
        case .recovery:  return .blue
        case .cross:     return .teal
        case .race:      return .yellow
        case .rest:      return .gray
        }
    }

    private func sessionIcon(_ type: RunningSessionType) -> String {
        switch type {
        case .easy:      return "figure.run"
        case .long:      return "arrow.up.right.circle.fill"
        case .tempo:     return "speedometer"
        case .intervals: return "bolt.fill"
        case .recovery:  return "leaf.fill"
        case .cross:     return "figure.strengthtraining.traditional"
        case .race:      return "flag.checkered"
        case .rest:      return "moon.zzz.fill"
        }
    }
}
