//
//  RunningPlanCard.swift
//  Yumo
//
//  Hero card shown on the activity screen when the user has an active
//  running plan. Surfaces today's session and a week strip, with actions
//  to mark-complete and open the full plan.
//

import SwiftUI
import SwiftData

struct RunningPlanCard: View {
    let plan: RunningPlan
    let isImperial: Bool
    var onMarkComplete: (PlannedSession) -> Void
    var onOpenDetail: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.9) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.72) }

    // Cached once per view identity — sorting 80-120 sessions on every render
    // was the primary source of lag when navigating to this page.
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var sortedSessions: [PlannedSession] {
        plan.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var todaySession: PlannedSession? {
        // sessions are already date-ordered, so the first match is cheapest
        sortedSessions.first { Calendar.current.isDateInToday($0.scheduledDate) }
    }

    /// Week number (1-indexed) that contains `today`. Clamped to plan bounds.
    private var currentWeekNumber: Int {
        if let ts = todaySession { return ts.weekNumber }
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: plan.startDate), to: today
        ).day ?? 0
        return max(1, min(plan.totalWeeks, (daysSinceStart / 7) + 1))
    }

    private var thisWeekSessions: [PlannedSession] {
        sortedSessions.filter { $0.weekNumber == currentWeekNumber }
    }

    // Static date formatter — DateFormatter is expensive to alloc; sharing one
    // instance across all cells eliminates per-cell allocation overhead.
    private static let narrowDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f
    }()

    var body: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let todaySession {
                    todayBlock(todaySession)
                } else {
                    noSessionTodayBlock
                }

                Divider().opacity(0.3)

                weekStripBlock
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpenDetail()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.runAccent.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "figure.run")
                        .foregroundStyle(Color.runAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text("Week \(currentWeekNumber) of \(plan.totalWeeks)")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today block

    @ViewBuilder
    private func todayBlock(_ session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tertiaryText)

            RunningSessionRow(
                session: session,
                isImperial: isImperial,
                showsDayLabel: false,
                isToday: true
            )

            if session.sessionType.isRun {
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onMarkComplete(session)
                    } label: {
                        Label(
                            session.isCompleted ? "Completed" : "Mark Complete",
                            systemImage: session.isCompleted ? "checkmark.circle.fill" : "checkmark.circle"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(session.isCompleted ? Color.runDone.opacity(0.2) : Color.runAccent)
                        )
                        .foregroundStyle(session.isCompleted ? Color.runDone : .white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onOpenDetail()
                    } label: {
                        Label("View Plan", systemImage: "list.bullet.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.runAccent.opacity(0.4), lineWidth: 1.5)
                            )
                            .foregroundStyle(Color.runAccent)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Rest day: just offer the full-plan entry point.
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpenDetail()
                } label: {
                    Label("View Plan", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.runAccent.opacity(0.4), lineWidth: 1.5)
                        )
                        .foregroundStyle(Color.runAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noSessionTodayBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No session scheduled today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryText)
            Text("Your plan resumes soon — open the full plan to see what's next.")
                .font(.caption)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Week strip

    private var weekStripBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tertiaryText)

            HStack(spacing: 6) {
                ForEach(thisWeekSessions, id: \.id) { session in
                    weekDayCell(session)
                }
            }
        }
    }

    @ViewBuilder
    private func weekDayCell(_ session: PlannedSession) -> some View {
        let isTodayCell = Calendar.current.isDate(session.scheduledDate, inSameDayAs: today)
        let tint = sessionTint(session)

        VStack(spacing: 4) {
            Text(shortDayLabel(session.scheduledDate))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isTodayCell ? tint : tertiaryText)
            ZStack {
                Circle()
                    .fill(session.sessionType == .rest
                          ? Color.gray.opacity(0.15)
                          : tint.opacity(session.isCompleted ? 1.0 : 0.2))
                    .frame(width: 32, height: 32)
                if session.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else if session.sessionType == .rest {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundStyle(tertiaryText)
                } else {
                    Text(String(session.sessionType.displayLabel.prefix(1)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .overlay(
                Circle()
                    .stroke(isTodayCell ? tint : Color.clear, lineWidth: 2)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func shortDayLabel(_ date: Date) -> String {
        Self.narrowDayFormatter.string(from: date)
    }

    private func sessionTint(_ session: PlannedSession) -> Color {
        session.sessionType.tint
    }
}
