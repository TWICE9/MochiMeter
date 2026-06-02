// Models/RunningProfile.swift

import Foundation
import SwiftData

// MARK: - Running Enums

enum RunningExperience: String, Codable, CaseIterable, Identifiable {
    case never = "Never"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .never: return "I've never run before"
        case .beginner: return "I can run 1–3 km"
        case .intermediate: return "I can run 5–10 km comfortably"
        case .advanced: return "I run 10 km+ regularly"
        }
    }
}

enum RunningGoalType: String, Codable, CaseIterable, Identifiable {
    case generalFitness = "General Fitness"
    case loseWeight = "Lose Weight"
    case buildDistance = "Build Distance"
    case improvePace = "Improve Pace"
    case trainForRace = "Train for a Race"

    var id: String { rawValue }
}

enum Weekday: String, Codable, CaseIterable, Identifiable {
    case mon, tue, wed, thu, fri, sat, sun
    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        case .sun: return "Sun"
        }
    }

    /// Integer matching the edge function's `day_of_week` convention
    /// (Mon=0 … Sun=6). Used when serialising canonical run-day lists
    /// to the plan generator.
    var dayIndex: Int {
        switch self {
        case .mon: return 0
        case .tue: return 1
        case .wed: return 2
        case .thu: return 3
        case .fri: return 4
        case .sat: return 5
        case .sun: return 6
        }
    }
}

/// Other activities the user wants the plan to coexist with. The AI generator
/// uses these to dial back running volume on heavy strength days, suggest
/// rest-day yoga, etc.
enum CrossTrainingActivity: String, Codable, CaseIterable, Identifiable {
    case strength = "Strength"
    case yoga = "Yoga"
    case pilates = "Pilates"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case hiking = "Hiking"
    case other = "Other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .strength: return "🏋️"
        case .yoga:     return "🧘"
        case .pilates:  return "🤸"
        case .cycling:  return "🚴"
        case .swimming: return "🏊"
        case .hiking:   return "🥾"
        case .other:    return "✨"
        }
    }
}

// MARK: - RunningProfile Model

/// Local-first SwiftData model for the user's running profile.
/// Mirrors the `running_profiles` Supabase table. Synced via CloudSyncManager.
@Model
final class RunningProfile {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users

    // --- Onboarding state ---
    var hasCompletedOnboarding: Bool = false

    // --- Background ---
    var experienceRaw: String = RunningExperience.beginner.rawValue
    var hasRunBefore: Bool = false

    // --- Goal ---
    var primaryGoalRaw: String = RunningGoalType.generalFitness.rawValue

    // --- Availability ---
    /// How many days per week the user wants to run.
    var weeklyRunDaysTarget: Int = 3
    /// Preferred days, stored as Weekday rawValues.
    var availableDaysRaw: [String] = []
    /// Preferred long-run day (usually weekend).
    var longRunDayRaw: String? = nil

    // --- Current fitness baseline ---
    /// Stored in km.
    var currentLongestRunKm: Double? = nil
    /// Stored in km.
    var currentWeeklyKm: Double? = nil
    /// Typical easy-run pace, in seconds per km.
    /// Kept for backward compat; prefer per-distance `recent*Seconds` values.
    var typicalPaceSecondsPerKm: Int? = nil

    // --- Recent finish times (per distance) ---
    // Concrete times beat a guessed "typical pace" for AI pace calibration.
    var recent1kmSeconds: Int? = nil
    var recent5kmSeconds: Int? = nil
    var recent10kmSeconds: Int? = nil
    var recentHalfMarathonSeconds: Int? = nil
    var recentMarathonSeconds: Int? = nil

    // --- Target race ---
    var targetRaceDate: Date? = nil
    var targetRaceDistanceRaw: String? = nil
    var targetRaceName: String? = nil
    /// Goal finish time for the target race, in seconds.
    var targetRaceGoalTimeSeconds: Int? = nil

    // --- Notes ---
    var injuriesOrLimitations: String? = nil

    // --- Cross-training ---
    /// Other activities the user already does, stored as CrossTrainingActivity rawValues.
    var crossTrainingActivitiesRaw: [String] = []
    /// Approximate non-running sessions per week. 0 = none.
    /// Derived from `crossTrainingScheduleRaw` whenever the user has picked
    /// specific days; legacy profiles that pre-date the per-day schedule
    /// keep their stored value as a fallback.
    var crossTrainingSessionsPerWeek: Int = 0
    /// Per-activity, per-day commitments expressed as flat `"Activity:day"`
    /// entries (e.g. `["Strength:mon", "Strength:wed", "Yoga:sun"]`). The plan
    /// generator uses this to schedule running sessions around the user's
    /// existing fixed workouts (no intervals the day after leg day, etc.).
    var crossTrainingScheduleRaw: [String] = []

    // --- Workout reminders ---
    /// Whether to schedule local notifications for upcoming planned sessions.
    var workoutRemindersEnabled: Bool = false
    /// Reminder time-of-day in 24h. nil before the user has chosen one.
    var workoutReminderHour: Int? = nil
    var workoutReminderMinute: Int? = nil

    // --- Sync metadata ---
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        hasCompletedOnboarding: Bool = false,
        experience: RunningExperience = .beginner,
        hasRunBefore: Bool = false,
        primaryGoal: RunningGoalType = .generalFitness,
        weeklyRunDaysTarget: Int = 3,
        availableDays: [Weekday] = [],
        longRunDay: Weekday? = nil,
        currentLongestRunKm: Double? = nil,
        currentWeeklyKm: Double? = nil,
        typicalPaceSecondsPerKm: Int? = nil,
        targetRaceDate: Date? = nil,
        targetRaceDistance: RaceDistance? = nil,
        targetRaceName: String? = nil,
        targetRaceGoalTimeSeconds: Int? = nil,
        injuriesOrLimitations: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.experienceRaw = experience.rawValue
        self.hasRunBefore = hasRunBefore
        self.primaryGoalRaw = primaryGoal.rawValue
        self.weeklyRunDaysTarget = weeklyRunDaysTarget
        self.availableDaysRaw = availableDays.map { $0.rawValue }
        self.longRunDayRaw = longRunDay?.rawValue
        self.currentLongestRunKm = currentLongestRunKm
        self.currentWeeklyKm = currentWeeklyKm
        self.typicalPaceSecondsPerKm = typicalPaceSecondsPerKm
        self.targetRaceDate = targetRaceDate
        self.targetRaceDistanceRaw = targetRaceDistance?.rawValue
        self.targetRaceName = targetRaceName
        self.targetRaceGoalTimeSeconds = targetRaceGoalTimeSeconds
        self.injuriesOrLimitations = injuriesOrLimitations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Enum Accessors

extension RunningProfile {
    var experience: RunningExperience {
        get { RunningExperience(rawValue: experienceRaw) ?? .beginner }
        set { experienceRaw = newValue.rawValue }
    }

    var primaryGoal: RunningGoalType {
        get { RunningGoalType(rawValue: primaryGoalRaw) ?? .generalFitness }
        set { primaryGoalRaw = newValue.rawValue }
    }

    var availableDays: [Weekday] {
        get { availableDaysRaw.compactMap { Weekday(rawValue: $0) } }
        set { availableDaysRaw = newValue.map { $0.rawValue } }
    }

    var longRunDay: Weekday? {
        get { longRunDayRaw.flatMap { Weekday(rawValue: $0) } }
        set { longRunDayRaw = newValue?.rawValue }
    }

    var targetRaceDistance: RaceDistance? {
        get { targetRaceDistanceRaw.flatMap { RaceDistance(rawValue: $0) } }
        set { targetRaceDistanceRaw = newValue?.rawValue }
    }

    var crossTrainingActivities: [CrossTrainingActivity] {
        get { crossTrainingActivitiesRaw.compactMap { CrossTrainingActivity(rawValue: $0) } }
        set { crossTrainingActivitiesRaw = newValue.map { $0.rawValue } }
    }

    /// Parsed view of `crossTrainingScheduleRaw` as `{activity: Set<day>}`.
    /// Empty entries (activity selected but no day picked) are preserved as
    /// an empty set so the UI can show the activity row without forcing the
    /// user to commit to specific days.
    var crossTrainingSchedule: [CrossTrainingActivity: Set<Weekday>] {
        get {
            var map: [CrossTrainingActivity: Set<Weekday>] = [:]
            // Seed every activity the user picked so activities with no fixed
            // days still appear (their entry is just an empty Set).
            for activity in crossTrainingActivities {
                map[activity] = []
            }
            for entry in crossTrainingScheduleRaw {
                let parts = entry.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2,
                      let activity = CrossTrainingActivity(rawValue: parts[0]),
                      let day = Weekday(rawValue: parts[1]) else { continue }
                map[activity, default: []].insert(day)
            }
            return map
        }
        set {
            // Flatten and persist. Activities are stored separately so they
            // survive even when the user picks no days for them.
            var entries: [String] = []
            for (activity, days) in newValue {
                for day in days {
                    entries.append("\(activity.rawValue):\(day.rawValue)")
                }
            }
            crossTrainingScheduleRaw = entries.sorted()
        }
    }
}
