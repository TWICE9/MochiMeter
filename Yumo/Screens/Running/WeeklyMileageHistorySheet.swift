// Screens/Running/WeeklyMileageHistorySheet.swift

import SwiftUI

/// Bottom sheet shown when the user taps the weekly mileage card. Displays
/// running mileage as an interactive bar chart with a range picker
/// (1M / 3M / 6M / YTD / 1Y) and exposes a quick-edit button for the goal.
struct WeeklyMileageHistorySheet: View {
    let isImperial: Bool
    /// Callback to open the weekly mileage goal editor (parent owns that sheet).
    var onEditGoal: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var allBuckets: [HealthKitManager.WeeklyMileageBucket] = []
    @State private var isLoading: Bool = true
    @State private var range: MileageRange = .sixMonths

    private var visibleBuckets: [HealthKitManager.WeeklyMileageBucket] {
        let count = min(range.weeksBack, allBuckets.count)
        return Array(allBuckets.suffix(count))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker

                if isLoading {
                    loadingState
                } else if visibleBuckets.allSatisfy({ $0.km <= 0 }) {
                    emptyState
                } else {
                    WeeklyMileageHistoryChart(
                        buckets: visibleBuckets,
                        isImperial: isImperial,
                        chartHeight: 220
                    )
                    .id(range) // Reset selection state on range change.
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color("AppCardBackground"))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .navigationTitle("Weekly Mileage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let onEditGoal {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onEditGoal()
                            }
                        } label: {
                            Label("Goal", systemImage: "target")
                        }
                    }
                }
            }
            .task {
                // Fetch the longest range up front so range switches are instant.
                allBuckets = await HealthKitManager.shared.fetchWeeklyMileageHistory(weeksBack: 52)
                isLoading = false
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(MileageRange.allCases) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        range = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(range == option
                                      ? Color("AppSecondaryAccent")
                                      : Color("AppCardBackground"))
                        )
                        .foregroundStyle(
                            range == option
                            ? .white
                            : (colorScheme == .dark ? .white.opacity(0.7) : .black)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Loading…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No runs in this range")
                .font(.headline)
            Text("Try a longer range, or log a run with Apple Health, Garmin or Strava.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
