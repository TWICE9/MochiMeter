//
//  RestDayRunSheet.swift
//  Yumo
//

import SwiftUI
import HealthKit

/// Shown when the user taps "Log This Run" / "Log a run anyway" on a planned rest day,
/// or when an unplanned run is detected. Lets them pick the run type — today's rest
/// session is converted to that type and marked completed (with HK data when available).
struct RestDayRunSheet: View {
    let pendingWorkout: WorkoutSummary?
    let isImperial: Bool
    var onPickType: (RunningSessionType) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedType: RunningSessionType? = nil

    private var unitLabel: String { isImperial ? "mi" : "km" }
    private static let pickableTypes: [RunningSessionType] = [.easy, .long, .tempo, .intervals, .recovery]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log a Run")
                            .font(.title2.weight(.bold))
                        Text(pendingWorkout != nil
                             ? "Pick the type — we'll log this run for today."
                             : "Pick the type — today will be logged as this kind of run.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)

                    if let workout = pendingWorkout {
                        workoutPreviewCard(workout)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What kind of run?")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(Self.pickableTypes, id: \.self) { type in
                                typeRow(type)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
            }

            // Sticky action bar
            VStack(spacing: 0) {
                Divider().opacity(0.25)

                Button {
                    guard let type = selectedType else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onPickType(type)
                    dismiss()
                } label: {
                    Text("Log This Run")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedType != nil ? Color.runOrange.opacity(0.18) : Color.gray.opacity(0.08))
                        .foregroundStyle(selectedType != nil ? Color.runOrange : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(selectedType == nil)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Type row

    private func typeRow(_ type: RunningSessionType) -> some View {
        let isSelected = selectedType == type
        let tint = tintFor(type)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) { selectedType = type }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.14)).frame(width: 38, height: 38)
                    Image(systemName: iconFor(type))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayLabel)
                        .font(.subheadline.weight(.semibold))
                    Text(blurbFor(type))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tint.opacity(0.08) : Color.primary.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? tint.opacity(0.3) : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workout preview

    @ViewBuilder
    private func workoutPreviewCard(_ workout: WorkoutSummary) -> some View {
        let distKm = (workout.distanceMeters ?? 0) / 1000
        let durMin = workout.durationMinutes
        let paceSpk: Int? = distKm > 0.01 && durMin > 0 ? Int((durMin * 60) / distKm) : nil

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.runOrange.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: "figure.run")
                        .foregroundStyle(Color.runOrange)
                        .font(.subheadline.weight(.bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detected Run")
                        .font(.subheadline.weight(.semibold))
                    Text("\(workout.sourceName) · \(workout.date.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                if distKm > 0.01 {
                    previewStat(label: "DISTANCE", value: formatDist(distKm))
                    Divider().frame(height: 24).padding(.horizontal, 12)
                }
                previewStat(label: "TIME", value: "\(Int(durMin)) min")
                if let spk = paceSpk {
                    Divider().frame(height: 24).padding(.horizontal, 12)
                    previewStat(label: "PACE", value: formatPace(spk))
                }
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.runOrange.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.runOrange.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private func previewStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
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

    private func tintFor(_ type: RunningSessionType) -> Color {
        type.tint
    }

    private func iconFor(_ type: RunningSessionType) -> String {
        switch type {
        case .easy, .recovery: return "figure.run"
        case .long:            return "arrow.up.right"
        case .tempo:           return "flame.fill"
        case .intervals:       return "bolt.fill"
        case .race:            return "flag.checkered"
        case .cross:           return "figure.mixed.cardio"
        case .rest:            return "moon.zzz.fill"
        }
    }

    private func blurbFor(_ type: RunningSessionType) -> String {
        switch type {
        case .easy:      return "Conversational pace, comfortable effort"
        case .long:      return "Building endurance over distance"
        case .tempo:     return "Sustained, comfortably hard effort"
        case .intervals: return "High-intensity reps with recovery"
        case .recovery:  return "Light shake-out, very easy effort"
        case .race:      return "Race effort"
        case .cross:     return "Cross-training session"
        case .rest:      return "Rest day"
        }
    }
}
