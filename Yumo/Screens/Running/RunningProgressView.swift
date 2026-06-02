//
//  RunningProgressView.swift
//  Yumo
//

import SwiftUI

struct RunningProgressView: View {
    let plan: RunningPlan?
    let isImperial: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    private var unitLabel: String { isImperial ? "mi" : "km" }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    // Sorting once here avoids re-sorting on every access to the derived arrays below.
    private var sortedSessions: [PlannedSession] {
        (plan?.sessions ?? []).sorted { $0.scheduledDate < $1.scheduledDate }
    }
    private var completedSessions: [PlannedSession] { sortedSessions.filter(\.isCompleted) }
    private var skippedCount: Int { sortedSessions.filter(\.skipped).count }
    private var totalCompletedKm: Double {
        completedSessions.compactMap { $0.completedDistanceKm ?? $0.targetDistanceKm }.reduce(0, +)
    }
    private var totalTargetKm: Double {
        sortedSessions.filter { $0.sessionType.isRun }.compactMap(\.targetDistanceKm).reduce(0, +)
    }
    private var completedRuns: Int { completedSessions.filter { $0.sessionType.isRun }.count }
    private var totalRuns: Int { sortedSessions.filter { $0.sessionType.isRun }.count }

    // Single Dictionary pass instead of O(n × totalWeeks) repeated filters.
    private var weekHistory: [(week: Int, sessions: [PlannedSession])] {
        guard let plan else { return [] }
        let grouped = Dictionary(grouping: sortedSessions) { $0.weekNumber }
        return (1...plan.totalWeeks).compactMap { week -> (week: Int, sessions: [PlannedSession])? in
            guard let inWeek = grouped[week],
                  inWeek.contains(where: { $0.isCompleted || $0.skipped }) else { return nil }
            return (week: week, sessions: inWeek)
        }.reversed()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if completedRuns > 0 || skippedCount > 0 {
                    overallCard
                    if !weekHistory.isEmpty { historyCard }
                } else {
                    emptyCard
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Overall card

    private var overallCard: some View {
        let doneDisplay = isImperial ? totalCompletedKm * 0.621371 : totalCompletedKm
        let targetDisplay = isImperial ? totalTargetKm * 0.621371 : totalTargetKm
        let adherence = totalRuns > 0 ? Int((Double(completedRuns) / Double(totalRuns)) * 100) : 0
        let adherenceColor: Color = adherence >= 80 ? .green : adherence >= 60 ? .orange : .red

        return FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill").foregroundStyle(Color.purple)
                    Text("Overall").font(.headline).foregroundStyle(primaryText)
                }

                Divider().opacity(0.3)

                HStack(spacing: 12) {
                    bigStat(value: String(format: "%.1f", doneDisplay), unit: unitLabel,
                            label: "Logged", color: .purple)
                    bigStat(value: "\(completedRuns)", unit: "runs",
                            label: "Completed", color: .green)
                    bigStat(value: "\(adherence)%", unit: "",
                            label: "Adherence", color: adherenceColor)
                }

                if totalTargetKm > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: min(1.0, totalCompletedKm / totalTargetKm)).tint(.purple)
                        Text(String(format: "%.1f of %.1f %@ planned total",
                                    doneDisplay, targetDisplay, unitLabel))
                            .font(.caption).foregroundStyle(tertiaryText)
                    }
                }

                if skippedCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "forward.fill").foregroundStyle(tertiaryText)
                        Text("\(skippedCount) session\(skippedCount == 1 ? "" : "s") skipped")
                            .font(.subheadline).foregroundStyle(secondaryText)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.07)))
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func bigStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.weight(.bold)).foregroundStyle(color).minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit).font(.caption.weight(.semibold)).foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label).font(.caption).foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    // MARK: - History card

    private var historyCard: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .foregroundStyle(Color.purple)
                    Text("Week by Week").font(.headline).foregroundStyle(primaryText)
                }

                Divider().opacity(0.3)

                VStack(spacing: 10) {
                    ForEach(weekHistory, id: \.week) { entry in
                        weekRow(entry.week, sessions: entry.sessions)
                        if entry.week != weekHistory.last?.week {
                            Divider().opacity(0.2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func weekRow(_ week: Int, sessions: [PlannedSession]) -> some View {
        let runs = sessions.filter { $0.sessionType.isRun }
        let done = runs.filter(\.isCompleted)
        let skipped = runs.filter(\.skipped)
        let doneKm = done.compactMap { $0.completedDistanceKm ?? $0.targetDistanceKm }.reduce(0, +)
        let displayKm = isImperial ? doneKm * 0.621371 : doneKm
        let fraction: Double = runs.isEmpty ? 0 : Double(done.count) / Double(runs.count)
        let color: Color = fraction >= 0.8 ? .green : fraction >= 0.6 ? .orange : .red

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Week \(week)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
                Text("\(done.count)/\(runs.count) runs · \(String(format: "%.1f", displayKm)) \(unitLabel)")
                    .font(.caption).foregroundStyle(secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(0..<runs.count, id: \.self) { i in
                        Circle()
                            .fill(i < done.count ? Color.green
                                  : i < done.count + skipped.count ? Color.gray.opacity(0.35)
                                  : Color.gray.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.caption.weight(.bold)).foregroundStyle(color)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 14) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 52)).foregroundStyle(Color.purple.opacity(0.4))
                Text("No sessions logged yet").font(.headline).foregroundStyle(primaryText)
                Text("Complete your first session to start tracking progress here.")
                    .font(.subheadline).foregroundStyle(secondaryText).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
    }
}
