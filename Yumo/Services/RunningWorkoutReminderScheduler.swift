//
//  RunningWorkoutReminderScheduler.swift
//  Yumo
//
//  Schedules per-session local notifications so each day's nudge can describe
//  the actual workout (e.g. "Today: Easy run · 5 km") rather than a generic
//  "time to run." Triggers are one-shot — we maintain a rolling 14-day window
//  and refresh whenever the plan changes (generation, adaptation, app launch,
//  reminder time/toggle change).
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum RunningWorkoutReminderScheduler {

    /// Stable prefix for all workout-reminder identifiers. Anything starting
    /// with this is fair game for cancellation when we re-schedule.
    private static let idPrefix = "yumo.workout-reminder"

    /// How far ahead to schedule. iOS caps pending notifications at 64 per app,
    /// so 14 sessions is well within budget while keeping the rolling window
    /// meaningful — the user won't see "stale" reminders if they don't open
    /// the app for a few days.
    private static let scheduleWindowDays = 14

    // MARK: - Public

    /// Convenience entry point used by all callers — fetches the active plan
    /// + profile from SwiftData and re-schedules. Cancels everything first
    /// regardless of whether reminders are still enabled.
    static func refresh(context: ModelContext) async {
        await cancelAll()

        let profileFetch = FetchDescriptor<RunningProfile>()
        guard let profile = (try? context.fetch(profileFetch))?.first else { return }

        guard profile.workoutRemindersEnabled,
              let hour = profile.workoutReminderHour,
              let minute = profile.workoutReminderMinute
        else { return }

        // If the user revoked permission outside the app, bail silently —
        // attempting to add() returns success but nothing fires.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        else { return }

        let planFetch = FetchDescriptor<RunningPlan>()
        let activePlan = (try? context.fetch(planFetch))?
            .first { $0.status == .active }

        guard let plan = activePlan else {
            // Plan-less users opted into reminders — fall back to a single
            // morning-of nudge for each available weekday so they don't go
            // silent until the plan is generated.
            scheduleFallbackWeekdayReminders(profile: profile, hour: hour, minute: minute)
            return
        }

        let imperial = profileIsImperial(profile, context: context)
        let upcoming = upcomingSessions(in: plan)

        for session in upcoming {
            scheduleOneShot(
                session: session,
                hour: hour,
                minute: minute,
                imperial: imperial
            )
        }

        // Phase 3 of plan adaptation: weekly check-in nudge. Lives behind the
        // same `workoutRemindersEnabled` toggle since it shares notification
        // permission. Fires Sunday at 6 PM regardless of the user's chosen
        // workout-reminder time — reflection prompts work better in the
        // evening than at dawn, and decoupling from the morning hour makes
        // the cadence more predictable.
        scheduleWeeklyCheckin()
    }

    /// Cancels every workout-reminder request. Used when the user disables
    /// reminders, when a plan is deleted, and as the first step of refresh.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ourIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(idPrefix) }
        if !ourIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ourIds)
        }
    }

    // MARK: - Session selection

    /// Returns the next ~14 days of run/quality sessions, oldest first, with
    /// rest/cross/already-completed days filtered out — those don't earn a
    /// notification.
    private static func upcomingSessions(in plan: RunningPlan) -> [PlannedSession] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let cutoff = cal.date(byAdding: .day, value: scheduleWindowDays, to: startOfToday) ?? now

        return plan.sessions
            .filter { $0.scheduledDate >= startOfToday && $0.scheduledDate < cutoff }
            .filter { $0.sessionType.isRun }   // skip rest + cross
            .filter { !$0.isCompleted && !$0.skipped }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // MARK: - One-shot scheduling

    private static func scheduleOneShot(
        session: PlannedSession,
        hour: Int,
        minute: Int,
        imperial: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = titleFor(session)
        content.body = bodyFor(session, imperial: imperial)
        content.sound = .default
        content.categoryIdentifier = "running-workout"

        // Anchor the trigger to the session's local date at the user's chosen
        // morning time. Sessions are stored at 06:00 UTC, so we strip the time
        // component and rebuild it from the user's preference.
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: session.scheduledDate
        )
        components.hour = hour
        components.minute = minute

        // If the chosen time has already passed today, drop the trigger —
        // firing at 4 PM for a 7 AM reminder feels worse than not firing.
        if let fireAt = Calendar.current.date(from: components), fireAt < Date() {
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "\(idPrefix).session.\(session.id.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule reminder for session \(session.id): \(error.localizedDescription)")
            }
        }
    }

    /// Sunday-evening weekly check-in notification. Repeating, so we schedule
    /// it once per refresh and let the system fire it every week. Tapping
    /// opens the app — `WeeklyCheckinController.shouldShow` then surfaces
    /// the 3-button sheet inside HealthRingsView.
    private static func scheduleWeeklyCheckin() {
        let content = UNMutableNotificationContent()
        content.title = "How was this week? 🤔"
        content.body = "Tap to check in — we'll fine-tune your plan based on how it felt."
        content.sound = .default
        content.categoryIdentifier = "running-weekly-checkin"

        var components = DateComponents()
        components.weekday = 1   // Sunday
        components.hour = 18     // 6 PM local
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let id = "\(idPrefix).weekly-checkin"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule weekly check-in: \(error.localizedDescription)")
            }
        }
    }

    /// Plan-less fallback: weekday-repeating generic reminders. Mirrors the
    /// pre-session-aware behaviour so users who enable reminders before a plan
    /// is generated still see something on their selected days.
    private static func scheduleFallbackWeekdayReminders(
        profile: RunningProfile,
        hour: Int,
        minute: Int
    ) {
        for day in profile.availableDays {
            let content = UNMutableNotificationContent()
            content.title = "Time to run 👟"
            content.body = "Open Yumo to plan your session."
            content.sound = .default
            content.categoryIdentifier = "running-workout"

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = calendarWeekday(day)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let id = "\(idPrefix).fallback.\(day.rawValue)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    private static func calendarWeekday(_ day: Weekday) -> Int {
        switch day {
        case .sun: return 1
        case .mon: return 2
        case .tue: return 3
        case .wed: return 4
        case .thu: return 5
        case .fri: return 6
        case .sat: return 7
        }
    }

    // MARK: - Notification copy

    private static func titleFor(_ session: PlannedSession) -> String {
        switch session.sessionType {
        case .race:      return "Race day 🏁"
        case .long:      return "Long run day 🏃"
        case .intervals: return "Intervals day ⚡️"
        case .tempo:     return "Tempo day 🔥"
        case .recovery:  return "Recovery jog 🌿"
        case .easy, .cross, .rest: return "Today's run 👟"
        }
    }

    /// One-line body, kept under ~80 chars so it doesn't truncate on the lock
    /// screen. Pace info is omitted — too much for a glanceable nudge.
    private static func bodyFor(_ session: PlannedSession, imperial: Bool) -> String {
        let label = sessionLabel(session.sessionType)
        let metric = primaryMetric(for: session, imperial: imperial)
        if let metric = metric {
            return "\(label) · \(metric)"
        }
        return label
    }

    private static func sessionLabel(_ type: RunningSessionType) -> String {
        switch type {
        case .easy:      return "Easy run"
        case .long:      return "Long run"
        case .tempo:     return "Tempo run"
        case .intervals: return "Intervals"
        case .recovery:  return "Recovery jog"
        case .race:      return "Race day"
        case .cross:     return "Cross-train"
        case .rest:      return "Rest day"
        }
    }

    /// Prefers distance, falls back to duration. Returns nil when both are
    /// missing so the body collapses cleanly to just the session label.
    private static func primaryMetric(for session: PlannedSession, imperial: Bool) -> String? {
        if let km = session.targetDistanceKm, km > 0 {
            return formatDistance(km, imperial: imperial)
        }
        if let mins = session.targetDurationMinutes, mins > 0 {
            return "\(mins) min"
        }
        return nil
    }

    private static func formatDistance(_ km: Double, imperial: Bool) -> String {
        if imperial {
            let mi = km * 0.621371
            let rounded = (mi * 2).rounded() / 2
            return rounded.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rounded)) mi"
                : String(format: "%.1f mi", rounded)
        }
        let rounded = (km * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rounded)) km"
            : String(format: "%.1f km", rounded)
    }

    // MARK: - Unit pref lookup

    /// Reads the user's km/mi preference from `UserGoals` so the reminder body
    /// matches the rest of the app. Falls back to metric on miss.
    private static func profileIsImperial(_ profile: RunningProfile, context: ModelContext) -> Bool {
        let goalsFetch = FetchDescriptor<UserGoals>()
        let goals = (try? context.fetch(goalsFetch))?.first
        return goals?.unitSystem == .imperial
    }
}
