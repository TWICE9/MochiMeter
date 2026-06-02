//
//  RunningPlanDetailView.swift
//  Yumo
//
//  Full-plan view presented as a sheet from the activity screen. Shows every
//  session grouped by week, with per-session completion controls.
//

import SwiftUI
import SwiftData

struct RunningPlanDetailView: View {
    let plan: RunningPlan
    let isImperial: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var selectedWeek: Int = 1
    @State private var sessionToComplete: PlannedSession? = nil

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.75) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color(red: 140/255, green: 140/255, blue: 150/255)
    }

    private var sortedSessions: [PlannedSession] {
        plan.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var sessionsForSelectedWeek: [PlannedSession] {
        sortedSessions.filter { $0.weekNumber == selectedWeek }
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// Current training week based on today's date.
    private var todayWeek: Int {
        if let todaySession = sortedSessions.first(where: { Calendar.current.isDate($0.scheduledDate, inSameDayAs: today) }) {
            return todaySession.weekNumber
        }
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: plan.startDate), to: today
        ).day ?? 0
        let week = (daysSinceStart / 7) + 1
        return max(1, min(plan.totalWeeks, week))
    }

    private var completionSummary: (done: Int, runs: Int) {
        let runs = sortedSessions.filter { $0.sessionType.isRun }
        let done = runs.filter(\.isCompleted).count
        return (done, runs.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    planHeader
                    weekPicker
                    weekSessions
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Running Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Jump to the current week on first open.
                selectedWeek = todayWeek
            }
        }
    }

    // MARK: - Plan header

    private var planHeader: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "figure.run")
                            .foregroundStyle(Color.purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.headline)
                            .foregroundStyle(primaryText)
                        if let raceDate = plan.targetRaceDate {
                            Text("Race: \(raceDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        } else {
                            Text("\(plan.totalWeeks) weeks · \(plan.goalType.rawValue)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }
                    }
                    Spacer()
                }

                let summary = completionSummary
                if summary.runs > 0 {
                    ProgressView(value: Double(summary.done), total: Double(summary.runs))
                        .tint(Color.purple)
                    Text("\(summary.done) of \(summary.runs) runs complete")
                        .font(.caption)
                        .foregroundStyle(tertiaryText)
                }
            }
        }
    }

    // MARK: - Week picker

    private var weekPicker: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedWeek = max(1, selectedWeek - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selectedWeek > 1 ? primaryText : tertiaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.gray.opacity(0.15)))
                }
                .disabled(selectedWeek <= 1)
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("Week \(selectedWeek) of \(plan.totalWeeks)")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    if selectedWeek == todayWeek {
                        Text("Current week")
                            .font(.caption2)
                            .foregroundStyle(Color.purple)
                    }
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedWeek = min(plan.totalWeeks, selectedWeek + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selectedWeek < plan.totalWeeks ? primaryText : tertiaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.gray.opacity(0.15)))
                }
                .disabled(selectedWeek >= plan.totalWeeks)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Week sessions

    private var weekSessions: some View {
        FrostedGlassContainer {
            VStack(spacing: 4) {
                ForEach(sessionsForSelectedWeek, id: \.id) { session in
                    RunningSessionRow(
                        session: session,
                        isImperial: isImperial,
                        showsDayLabel: true,
                        isToday: Calendar.current.isDate(session.scheduledDate, inSameDayAs: today),
                        onToggleComplete: session.sessionType.isRun
                            ? { sessionToComplete = session }
                            : nil
                    )
                    if session.id != sessionsForSelectedWeek.last?.id {
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .sheet(item: $sessionToComplete) { session in
            SessionCompleteSheet(
                session: session,
                isImperial: isImperial,
                onComplete: { distKm, durMins, source in
                    applyCompletion(session, distanceKm: distKm, durationMinutes: durMins, source: source)
                },
                onSkip: { markSkipped(session) },
                onUnmark: { unmark(session) }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Session actions

    private func applyCompletion(_ session: PlannedSession, distanceKm: Double?, durationMinutes: Int?, source: String) {
        let now = Date()
        session.completedAt = now
        session.completedDistanceKm = distanceKm
        session.completedDurationMinutes = durationMinutes
        session.completedSource = source
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func markSkipped(_ session: PlannedSession) {
        let now = Date()
        session.skipped = true
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func unmark(_ session: PlannedSession) {
        let now = Date()
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }
}
