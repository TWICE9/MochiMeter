//
//  RunningPlanBrowserView.swift
//  Yumo
//

import SwiftUI
import SwiftData

struct RunningPlanBrowserView: View {
    let plan: RunningPlan?
    let isImperial: Bool
    var onMarkComplete: (PlannedSession) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Pulled in so the multi-week calendar can decorate days with the
    /// user's cross-training schedule (Strength / Yoga / etc.) on the
    /// rest days that line up with their gym week.
    @Query private var runningProfiles: [RunningProfile]
    private var crossTrainingSchedule: [CrossTrainingActivity: Set<Weekday>] {
        runningProfiles.first?.crossTrainingSchedule ?? [:]
    }

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    private var unitLabel: String { isImperial ? "mi" : "km" }

    // Static formatter — avoids per-call heap allocation.
    private static let mediumDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    // Sorted once per render cycle; all derived arrays filter from this copy.
    private var sortedSessions: [PlannedSession] {
        (plan?.sessions ?? []).sorted { $0.scheduledDate < $1.scheduledDate }
    }
    private var currentWeek: Int {
        guard let plan else { return 1 }
        if let s = sortedSessions.first(where: { Calendar.current.isDateInToday($0.scheduledDate) }) {
            return s.weekNumber
        }
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: plan.startDate), to: today
        ).day ?? 0
        return max(1, min(plan.totalWeeks, (days / 7) + 1))
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if let plan {
                        trainingCalendar(plan)
                    } else {
                        emptyCard
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            .onAppear {
                // Auto-scroll to the current week so the calendar opens to
                // "now" rather than week 1 on plans that span 12+ weeks.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("week-\(currentWeek)", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Multi-week training calendar

    /// Scrollable list of every week in the plan with all 7 days laid out.
    /// Mirrors the calendar pattern used by other running apps (Runna et al.)
    /// — gives the user a single view of their entire training block instead
    /// of stepping through one week at a time. Auto-scrolls to the current
    /// week on first appear via the parent ScrollViewReader.
    @ViewBuilder
    private func trainingCalendar(_ plan: RunningPlan) -> some View {
        let groupedByWeek = Dictionary(grouping: sortedSessions, by: \.weekNumber)
        ForEach(1...max(1, plan.totalWeeks), id: \.self) { weekNum in
            let sessions = (groupedByWeek[weekNum] ?? []).sorted { $0.scheduledDate < $1.scheduledDate }
            weekCard(weekNum: weekNum, sessions: sessions, totalWeeks: plan.totalWeeks)
                .padding(.horizontal, 24)
                .id("week-\(weekNum)")
        }
    }

    @ViewBuilder
    private func weekCard(weekNum: Int, sessions: [PlannedSession], totalWeeks: Int) -> some View {
        let runs = sessions.filter { $0.sessionType.isRun }
        let done = runs.filter(\.isCompleted).count
        let totalKm = runs.compactMap(\.targetDistanceKm).reduce(0, +)
        let doneKm = runs.filter(\.isCompleted).compactMap { $0.completedDistanceKm ?? $0.targetDistanceKm }.reduce(0, +)
        let displayDone = isImperial ? doneKm * 0.621371 : doneKm
        let displayTotal = isImperial ? totalKm * 0.621371 : totalKm
        let isCurrent = weekNum == currentWeek

        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(weekDateRangeFor(sessions))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryText)
                            Text("WEEK \(weekNum)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(isCurrent ? Color.purple : Color.gray.opacity(0.5)))
                            if isCurrent {
                                Text("NOW")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.green))
                            }
                        }
                        if totalKm > 0 {
                            Text(String(format: "Total: %.1f / %.1f %@", displayDone, displayTotal, unitLabel))
                                .font(.caption)
                                .foregroundStyle(tertiaryText)
                        }
                    }
                    Spacer()
                    if !runs.isEmpty {
                        Text("\(done)/\(runs.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(done == runs.count ? Color.green : tertiaryText)
                    }
                }

                Divider().opacity(0.3)

                // Day rows
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, session in
                        calendarRow(session)
                        if idx < sessions.count - 1 {
                            Divider().opacity(0.15)
                        }
                    }
                }
            }
        }
    }

    /// Single-day row in the calendar. Three visual modes:
    ///   1. Run session — coloured leading bar + name + metric chips (tappable).
    ///   2. Rest day with cross-training — purple activity row.
    ///   3. Plain rest day — muted "Rest" label.
    @ViewBuilder
    private func calendarRow(_ session: PlannedSession) -> some View {
        let isToday = Calendar.current.isDateInToday(session.scheduledDate)
        let cross = crossActivities(for: session.scheduledDate)
        let isRun = session.sessionType.isRun
        let isCrossOnly = !isRun && session.sessionType == .rest && !cross.isEmpty

        let tint: Color = isCrossOnly ? .purple : tintFor(session)
        let label: String = isCrossOnly
            ? cross.map(\.rawValue).joined(separator: " + ")
            : session.sessionType.displayLabel

        Button {
            guard isRun else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onMarkComplete(session)
        } label: {
            HStack(spacing: 12) {
                // Date column — day-of-week label + day number stacked
                VStack(spacing: 1) {
                    Text(session.scheduledDate.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isToday ? tint : tertiaryText)
                    Text(session.scheduledDate.formatted(.dateTime.day()))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isToday ? tint : primaryText)
                }
                .frame(width: 30)

                // Coloured bar — visual separator between empty / run / cross
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRun || isCrossOnly ? tint : Color.gray.opacity(0.18))
                    .frame(width: 4, height: 36)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if isCrossOnly,
                           let first = cross.first {
                            Image(systemName: crossActivityIcon(first))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tint)
                        }
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isCrossOnly ? tint : primaryText)
                        if session.skipped {
                            Text("skipped")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(tertiaryText)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray.opacity(0.1)))
                        }
                    }

                    if isRun {
                        HStack(spacing: 4) {
                            if let km = session.targetDistanceKm, km > 0 {
                                Text(formatDist(km)).font(.caption).foregroundStyle(secondaryText)
                            }
                            if let m = session.targetDurationMinutes, m > 0 {
                                Text("· \(m) min").font(.caption).foregroundStyle(secondaryText)
                            }
                            if let p = session.targetPaceSecondsPerKm, p > 0 {
                                Text("· \(formatPace(p))").font(.caption).foregroundStyle(secondaryText)
                            }
                            // Surface cross-training even on run days so the
                            // user sees both commitments for the day.
                            if !cross.isEmpty, let first = cross.first {
                                HStack(spacing: 3) {
                                    Image(systemName: crossActivityIcon(first))
                                    Text("· also \(cross.map(\.rawValue).joined(separator: " + "))")
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.purple.opacity(0.8))
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                if isRun {
                    Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(session.isCompleted ? .green : Color.gray.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isRun)
    }

    // MARK: - Calendar helpers

    private func weekDateRangeFor(_ sessions: [PlannedSession]) -> String {
        guard let first = sessions.first, let last = sessions.last else { return "" }
        let fmt = Self.mediumDayFormatter
        return "\(fmt.string(from: first.scheduledDate)) – \(fmt.string(from: last.scheduledDate))"
    }

    private func crossActivities(for date: Date) -> [CrossTrainingActivity] {
        let weekday: Weekday?
        switch Calendar.current.component(.weekday, from: date) {
        case 1: weekday = .sun
        case 2: weekday = .mon
        case 3: weekday = .tue
        case 4: weekday = .wed
        case 5: weekday = .thu
        case 6: weekday = .fri
        case 7: weekday = .sat
        default: weekday = nil
        }
        guard let day = weekday else { return [] }
        let schedule = crossTrainingSchedule
        return CrossTrainingActivity.allCases.filter {
            schedule[$0]?.contains(day) ?? false
        }
    }

    private func crossActivityIcon(_ activity: CrossTrainingActivity) -> String {
        switch activity {
        case .strength: return "figure.strengthtraining.traditional"
        case .yoga:     return "figure.yoga"
        case .pilates:  return "figure.pilates"
        case .cycling:  return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .hiking:   return "figure.hiking"
        case .other:    return "figure.cooldown"
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 14) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 52)).foregroundStyle(Color.purple.opacity(0.4))
                Text("No Plan Yet").font(.headline).foregroundStyle(primaryText)
                Text("Generate a personalised AI running plan to see it here.")
                    .font(.subheadline).foregroundStyle(secondaryText).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func formatDist(_ km: Double) -> String {
        let v = isImperial ? km * 0.621371 : km
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, unitLabel)
    }

    private func formatPace(_ spk: Int) -> String {
        let s = isImperial ? Int(Double(spk) / 0.621371) : spk
        return String(format: "%d:%02d /%@", s / 60, s % 60, unitLabel)
    }

    private func tintFor(_ session: PlannedSession) -> Color {
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

    private func iconFor(_ session: PlannedSession) -> String {
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
