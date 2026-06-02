//
//  RunningAvailabilityPage.swift
//  Yumo
//

import SwiftUI

struct RunningAvailabilityPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    private let allDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]

    var body: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        OnboardingQuestionView(
            question: "When can you run?",
            subtitle: "Pick your days and how many you'd like to run each week.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 24) {
                // Plan start date — first because it's the most fundamental
                // scheduling decision and frames what the rest of the page
                // means ("days I can run" assumes a start date).
                VStack(spacing: 10) {
                    HStack {
                        Text("PLAN START DATE")
                            .font(.caption.weight(.bold))
                            .foregroundColor(muted)
                        Spacer()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            flowManager.plannedStartDate = RunningOnboardingFlowManager.defaultStartDate()
                        } label: {
                            Text("Next Monday")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.purple.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DatePicker(
                        "Start date",
                        selection: Binding(
                            get: { flowManager.plannedStartDate },
                            set: { newValue in
                                // Snap forward to the next Monday so plan
                                // structure (deload weeks, taper, week strip)
                                // is always Monday-anchored. The picker
                                // re-renders with the snapped date so the user
                                // sees exactly what they'll get.
                                flowManager.plannedStartDate = RunningOnboardingFlowManager
                                    .snapToNextMonday(newValue)
                            }
                        ),
                        in: flowManager.startDateRange,
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

                    Text("Plans run Monday → Sunday — your start always lands on a Monday.")
                        .font(.caption2)
                        .foregroundColor(muted)
                }

                // Days per week stepper
                VStack(spacing: 10) {
                    Text("RUNS PER WEEK")
                        .font(.caption.weight(.bold))
                        .foregroundColor(muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        ForEach(1...6, id: \.self) { count in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                flowManager.weeklyRunDaysTarget = count
                            } label: {
                                Text("\(count)")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(flowManager.weeklyRunDaysTarget == count ? Color.purple : background)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(stroke, lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(flowManager.weeklyRunDaysTarget == count ? .white : primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Preferred days
                VStack(spacing: 10) {
                    HStack {
                        Text("PREFERRED DAYS")
                            .font(.caption.weight(.bold))
                            .foregroundColor(muted)
                        Spacer()
                        Text("\(flowManager.availableDays.count) / \(flowManager.weeklyRunDaysTarget)+")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(flowManager.availableDays.count >= flowManager.weeklyRunDaysTarget ? Color("AppSecondaryAccent") : muted)
                    }

                    HStack(spacing: 6) {
                        ForEach(allDays) { day in
                            let selected = flowManager.availableDays.contains(day)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selected {
                                    flowManager.availableDays.remove(day)
                                } else {
                                    flowManager.availableDays.insert(day)
                                }
                            } label: {
                                Text(day.shortLabel)
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selected ? Color.purple : background)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(stroke, lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(selected ? .white : primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Long-run day — any of the user's available days, not just
                // weekends. Weekend workers, shift workers, and people who
                // train on Wednesdays should all feel at home here.
                VStack(spacing: 10) {
                    HStack {
                        Text("LONG-RUN DAY (OPTIONAL)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(muted)
                        Spacer()
                        Text("Pick any day you can run long")
                            .font(.caption2)
                            .foregroundColor(muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        ForEach(allDays) { day in
                            let isAvailable = flowManager.availableDays.contains(day)
                            let selected = flowManager.longRunDay == day
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                flowManager.longRunDay = selected ? nil : day
                                // Auto-add the day to availableDays so the
                                // user doesn't have to backtrack to fix the
                                // count tally above.
                                if !selected { flowManager.availableDays.insert(day) }
                            } label: {
                                Text(day.shortLabel)
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selected ? Color.purple : background)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        selected
                                                            ? Color.purple
                                                            : (isAvailable ? Color("AppSecondaryAccent").opacity(0.4) : stroke),
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                    .foregroundColor(selected ? .white : (isAvailable ? primary : muted))
                            }
                            .buttonStyle(.plain)
                        }
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
    }
}
