//
//  RunningOnboardingFlowManager.swift
//  Yumo
//

import Foundation
import SwiftUI

/// Lightweight, self-contained flow manager for the running onboarding shown
/// from the activity screen. Separate from `OnboardingFlowManager` (the account
/// signup flow) because running onboarding is contextual and has different
/// pages, validation, and completion side effects.
@MainActor
@Observable
final class RunningOnboardingFlowManager {

    // MARK: - Navigation

    var currentPage: Int = 0
    let totalPages: Int = 10
    var isNavigating: Bool = false
    private let navigationCooldown: Double = 0.35

    // MARK: - Collected Data

    /// True when re-editing an existing profile — suppresses availability defaults.
    private(set) var hasLoadedFromProfile: Bool = false

    var experience: RunningExperience = .beginner
    var hasRunBefore: Bool = false
    var primaryGoal: RunningGoalType = .generalFitness

    var weeklyRunDaysTarget: Int = 3
    var availableDays: Set<Weekday> = []
    var longRunDay: Weekday? = nil

    /// When the user wants their plan to begin. Defaults to the upcoming
    /// Monday so we don't backdate sessions into days the user couldn't
    /// have trained — that previously caused fresh plans to read as
    /// "already 3 days behind" the moment midnight rolled over.
    var plannedStartDate: Date = RunningOnboardingFlowManager.defaultStartDate()

    /// Earliest selectable start: today. Latest: 4 weeks out — beyond that
    /// the plan goes stale before it begins.
    var startDateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let upper = cal.date(byAdding: .weekOfYear, value: 4, to: today) ?? today
        return today...upper
    }

    /// Next Monday from now (or today if today is Monday). Used for both
    /// the default and as a "Reset to recommended" affordance.
    static func defaultStartDate() -> Date {
        snapToNextMonday(Date())
    }

    /// Snaps any date forward to the next Monday (or returns the date itself
    /// if it's already a Monday). Used to keep plan generation locked to
    /// Monday-anchored weeks regardless of what date the user picks in the
    /// onboarding date picker — the server enforces this too as a backstop.
    static func snapToNextMonday(_ date: Date) -> Date {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: dayStart) // 1=Sun..7=Sat
        let daysToAdd = (9 - weekday) % 7  // Mon→0, Sun→1, Tue→6, ...
        return cal.date(byAdding: .day, value: daysToAdd, to: dayStart) ?? dayStart
    }

    var currentLongestRunKm: Double? = nil
    var currentWeeklyKm: Double? = nil
    var typicalPaceSecondsPerKm: Int? = nil

    // --- Recent finish times (per distance, in seconds) ---
    var recent1kmSeconds: Int? = nil
    var recent5kmSeconds: Int? = nil
    var recent10kmSeconds: Int? = nil
    var recentHalfMarathonSeconds: Int? = nil
    var recentMarathonSeconds: Int? = nil

    var targetRaceDistance: RaceDistance? = nil
    var targetRaceDate: Date? = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())
    var targetRaceName: String = ""
    var targetRaceGoalTimeSeconds: Int? = nil

    var injuriesOrLimitations: String = ""

    // --- Cross-training ---
    var crossTrainingActivities: Set<CrossTrainingActivity> = []
    /// Per-activity day map. Activities with an empty Set are treated as
    /// "I do this but no fixed schedule" — handy for users with irregular
    /// gym/yoga habits.
    var crossTrainingSchedule: [CrossTrainingActivity: Set<Weekday>] = [:]
    /// Computed from `crossTrainingSchedule` — total fixed cross-training
    /// slots across all activities. Profiles that haven't migrated to the
    /// schedule yet still expose a writable property elsewhere; this one
    /// always reflects the day picker.
    var crossTrainingSessionsPerWeek: Int {
        crossTrainingSchedule.values.reduce(0) { $0 + $1.count }
    }

    // --- Workout reminders ---
    var workoutRemindersEnabled: Bool = false
    /// Defaults to 7:00 AM until the user picks a time.
    var workoutReminderTime: Date = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: Date()
    ) ?? Date()

    // Unit preference (read from UserGoals when the flow starts)
    var unitSystem: UnitSystem = .metric
    var isImperial: Bool { unitSystem == .imperial }

    // MARK: - Progress

    var progress: Double {
        Double(currentPage + 1) / Double(totalPages)
    }

    // MARK: - Navigation

    private func performNavigation(_ action: () -> Void) {
        guard !isNavigating else { return }
        isNavigating = true

        withAnimation(.spring(duration: 0.35)) {
            action()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + navigationCooldown) { [weak self] in
            self?.isNavigating = false
        }
    }

    /// Pages (by index):
    /// 0: Welcome
    /// 1: Primary goal
    /// 2: Experience
    /// 3: Baseline (recent times + weekly volume)
    /// 4: Target race (skipped unless goal == .trainForRace)
    /// 5: Availability (days per week + preferred days + long-run day)
    /// 6: Cross-training (other activities + frequency)
    /// 7: Injuries / limitations
    /// 8: Workout reminders
    /// 9: Summary (preview + recap)
    func goNext() {
        guard canProceed() else { return }

        performNavigation {
            // Skip race page if not training for a race.
            if currentPage == 3 && primaryGoal != .trainForRace {
                // Clear any stale race data so we don't persist ghost info.
                targetRaceDistance = nil
                targetRaceDate = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date())
                targetRaceName = ""
                targetRaceGoalTimeSeconds = nil
                // Entering availability page (page 5) — apply defaults for fresh flow.
                if !hasLoadedFromProfile { applyAvailabilityDefaults() }
                currentPage = min(currentPage + 2, totalPages - 1)
            } else {
                // Entering availability page (5) — apply defaults for fresh flow.
                if currentPage == 4 && !hasLoadedFromProfile { applyAvailabilityDefaults() }
                currentPage = min(currentPage + 1, totalPages - 1)
            }
        }
    }

    /// Pre-fills availability with sensible defaults based on goal + race distance.
    /// Only called on fresh onboarding (not re-edit), so returning users keep their settings.
    private func applyAvailabilityDefaults() {
        switch primaryGoal {
        case .generalFitness, .loseWeight:
            weeklyRunDaysTarget = 3
            availableDays = [.mon, .wed, .fri]
            // Backstop set below picks the last day in availableDays — for
            // these defaults that's Friday, which avoids a "no day selected"
            // dead-end and works whether or not the user runs on weekends.
            longRunDay = nil
        case .buildDistance:
            weeklyRunDaysTarget = 4
            availableDays = [.tue, .thu, .sat, .sun]
            longRunDay = .sun
        case .improvePace:
            weeklyRunDaysTarget = 4
            availableDays = [.mon, .wed, .fri, .sun]
            longRunDay = .sun
        case .trainForRace:
            switch targetRaceDistance {
            case .k5:
                weeklyRunDaysTarget = 3
                availableDays = [.tue, .thu, .sun]
                longRunDay = .sun
            case .k10:
                weeklyRunDaysTarget = 4
                availableDays = [.tue, .thu, .sat, .sun]
                longRunDay = .sun
            case .half:
                weeklyRunDaysTarget = 4
                availableDays = [.mon, .wed, .fri, .sun]
                longRunDay = .sun
            case .full:
                weeklyRunDaysTarget = 5
                availableDays = [.mon, .tue, .thu, .sat, .sun]
                longRunDay = .sun
            case nil:
                weeklyRunDaysTarget = 4
                availableDays = [.tue, .thu, .sat, .sun]
                longRunDay = .sun
            }
        }

        // Backstop: if the goal-specific defaults didn't set a long-run day
        // (e.g. General Fitness / Lose Weight), pick the latest day in the
        // user's available set. This removes the "no day selected" dead-end
        // for fresh onboarding without imposing a weekend bias — works for
        // shift workers (Wed/Fri only → Fri) and weekend trainers (Mon/Wed/
        // Fri/Sat → Sat) alike.
        if longRunDay == nil {
            let order: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
            longRunDay = order.last { availableDays.contains($0) }
        }
    }

    func goBack() {
        performNavigation {
            // Skip race page on back-nav too when the user isn't training for a race.
            if currentPage == 5 && primaryGoal != .trainForRace {
                currentPage = max(currentPage - 2, 0)
            } else {
                currentPage = max(currentPage - 1, 0)
            }
        }
    }

    // MARK: - Validation

    func canProceed() -> Bool {
        switch currentPage {
        case 4:
            // Target race page requires a distance selected.
            return targetRaceDistance != nil
        case 5:
            // At least 1 day per week and must have enough preferred days selected.
            return weeklyRunDaysTarget >= 1 && availableDays.count >= weeklyRunDaysTarget
        default:
            return true
        }
    }

    // MARK: - Persistence

    /// Pre-fill the flow from an existing `RunningProfile` (re-edit path).
    /// Leaves `currentPage` at 0 so the user walks through from the start.
    func loadFrom(profile: RunningProfile) {
        hasLoadedFromProfile = true
        experience = profile.experience
        hasRunBefore = profile.hasRunBefore
        primaryGoal = profile.primaryGoal

        weeklyRunDaysTarget = max(1, profile.weeklyRunDaysTarget)
        availableDays = Set(profile.availableDays)
        longRunDay = profile.longRunDay

        currentLongestRunKm = profile.currentLongestRunKm
        currentWeeklyKm = profile.currentWeeklyKm
        typicalPaceSecondsPerKm = profile.typicalPaceSecondsPerKm
        recent1kmSeconds = profile.recent1kmSeconds
        recent5kmSeconds = profile.recent5kmSeconds
        recent10kmSeconds = profile.recent10kmSeconds
        recentHalfMarathonSeconds = profile.recentHalfMarathonSeconds
        recentMarathonSeconds = profile.recentMarathonSeconds

        targetRaceDistance = profile.targetRaceDistance
        if let date = profile.targetRaceDate {
            // Clamp past race dates to today so the DatePicker (bounded to `Date()...`)
            // doesn't reject the stored value.
            targetRaceDate = max(date, Date())
        }
        targetRaceName = profile.targetRaceName ?? ""
        targetRaceGoalTimeSeconds = profile.targetRaceGoalTimeSeconds

        injuriesOrLimitations = profile.injuriesOrLimitations ?? ""

        crossTrainingActivities = Set(profile.crossTrainingActivities)
        crossTrainingSchedule = profile.crossTrainingSchedule

        workoutRemindersEnabled = profile.workoutRemindersEnabled
        if let h = profile.workoutReminderHour, let m = profile.workoutReminderMinute {
            workoutReminderTime = Calendar.current.date(
                bySettingHour: h, minute: m, second: 0, of: Date()
            ) ?? workoutReminderTime
        }
    }

    /// Writes the collected data into the given `RunningProfile` (or creates one).
    /// Returns the saved profile so the caller can upload it to the cloud.
    func apply(to profile: RunningProfile) {
        profile.hasCompletedOnboarding = true
        profile.experience = experience
        profile.hasRunBefore = hasRunBefore || experience != .never
        profile.primaryGoal = primaryGoal
        profile.weeklyRunDaysTarget = weeklyRunDaysTarget
        profile.availableDays = Array(availableDays)
        profile.longRunDay = longRunDay

        profile.currentLongestRunKm = currentLongestRunKm
        profile.currentWeeklyKm = currentWeeklyKm
        profile.typicalPaceSecondsPerKm = typicalPaceSecondsPerKm
        profile.recent1kmSeconds = recent1kmSeconds
        profile.recent5kmSeconds = recent5kmSeconds
        profile.recent10kmSeconds = recent10kmSeconds
        profile.recentHalfMarathonSeconds = recentHalfMarathonSeconds
        profile.recentMarathonSeconds = recentMarathonSeconds

        if primaryGoal == .trainForRace {
            profile.targetRaceDistance = targetRaceDistance
            profile.targetRaceDate = targetRaceDate
            let trimmedName = targetRaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.targetRaceName = trimmedName.isEmpty ? nil : trimmedName
            profile.targetRaceGoalTimeSeconds = targetRaceGoalTimeSeconds
        } else {
            profile.targetRaceDistance = nil
            profile.targetRaceDate = nil
            profile.targetRaceName = nil
            profile.targetRaceGoalTimeSeconds = nil
        }

        let trimmedInjuries = injuriesOrLimitations.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.injuriesOrLimitations = trimmedInjuries.isEmpty ? nil : trimmedInjuries

        profile.crossTrainingActivities = Array(crossTrainingActivities)
        // Strip schedule entries for activities the user de-selected so we
        // don't ship orphaned slots to the server.
        let cleanedSchedule = crossTrainingSchedule.filter { crossTrainingActivities.contains($0.key) }
        profile.crossTrainingSchedule = cleanedSchedule
        profile.crossTrainingSessionsPerWeek = max(0, crossTrainingSessionsPerWeek)

        profile.workoutRemindersEnabled = workoutRemindersEnabled
        if workoutRemindersEnabled {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: workoutReminderTime)
            profile.workoutReminderHour = comps.hour
            profile.workoutReminderMinute = comps.minute
        } else {
            profile.workoutReminderHour = nil
            profile.workoutReminderMinute = nil
        }

        profile.updatedAt = Date()
    }
}

// MARK: - Race goal helpers

extension RunningOnboardingFlowManager {

    /// Suggests a goal finish time for `distance` based on the user's recent
    /// benchmark times, using Riegel's formula:  T2 = T1 * (D2/D1)^1.06.
    ///
    /// Picks the closest available baseline distance (in log-distance terms)
    /// to keep the extrapolation tight. Returns the predicted seconds plus a
    /// short label identifying which baseline was used (e.g. "5K").
    func suggestedGoalTime(for distance: RaceDistance) -> (seconds: Int, sourceLabel: String)? {
        let baselines: [(label: String, km: Double, seconds: Int?)] = [
            ("1K", 1.0, recent1kmSeconds),
            ("5K", 5.0, recent5kmSeconds),
            ("10K", 10.0, recent10kmSeconds),
            ("Half Marathon", 21.0975, recentHalfMarathonSeconds),
            ("Marathon", 42.195, recentMarathonSeconds),
        ]

        // Closest baseline by log-ratio to the target.
        let targetKm = distance.km
        let candidate = baselines
            .compactMap { entry -> (label: String, km: Double, seconds: Int)? in
                guard let secs = entry.seconds, secs > 0 else { return nil }
                return (entry.label, entry.km, secs)
            }
            .min(by: { abs(log($0.km / targetKm)) < abs(log($1.km / targetKm)) })

        guard let best = candidate else { return nil }

        // Riegel's endurance exponent. Reasonably accurate for distances within
        // ~4× of each other; less so when extrapolating 1K → marathon.
        let predicted = Double(best.seconds) * pow(targetKm / best.km, 1.06)
        return (Int(predicted.rounded()), best.label)
    }

    /// Recommended minimum weeks of training for the given race distance. Below
    /// this we surface a soft warning on the race page (we don't block the user).
    func recommendedMinimumWeeks(for distance: RaceDistance) -> Int {
        switch distance {
        case .k5:   return 6
        case .k10:  return 8
        case .half: return 12
        case .full: return 16
        }
    }

    /// Whole weeks between today and the target race date (rounded down).
    /// Returns nil when no race date is set.
    var weeksUntilRace: Int? {
        guard let date = targetRaceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days / 7)
    }
}
