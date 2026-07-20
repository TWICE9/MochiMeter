// Models/RunningPlan.swift

import Foundation
import SwiftData

// MARK: - Enums

enum RunningPlanStatus: String, Codable, CaseIterable {
    case active
    case completed
    case abandoned
    case replaced
}

enum RunningPlanGenerationSource: String, Codable, CaseIterable {
    case ai
    case manual
    case template
}

enum RunningSessionType: String, Codable, CaseIterable, Identifiable {
    case easy
    case long
    case tempo
    case intervals
    case rest
    case cross
    case recovery
    case race

    var id: String { rawValue }

    /// Short display label, already title-cased.
    var displayLabel: String {
        switch self {
        case .easy: return "Easy"
        case .long: return "Long"
        case .tempo: return "Tempo"
        case .intervals: return "Intervals"
        case .rest: return "Rest"
        case .cross: return "Cross Train"
        case .recovery: return "Recovery"
        case .race: return "Race"
        }
    }

    /// True for session types where HealthKit running data is expected to count as completion.
    var isRun: Bool {
        switch self {
        case .rest, .cross: return false
        default: return true
        }
    }
}

// MARK: - RunningPlan

/// Local SwiftData model for a multi-week running plan.
/// Mirrors the `running_plans` Supabase table. Synced via CloudSyncManager.
@Model
final class RunningPlan {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil

    // Display
    var name: String
    var goalTypeRaw: String
    var statusRaw: String

    // Shape
    var startDate: Date
    var totalWeeks: Int

    // Race target snapshot
    var targetRaceDate: Date? = nil
    var targetRaceDistanceRaw: String? = nil
    var targetRaceName: String? = nil
    var targetRaceGoalTimeSeconds: Int? = nil

    // Generation provenance
    var generationSourceRaw: String = RunningPlanGenerationSource.ai.rawValue
    /// Raw JSON string of the profile snapshot used to generate this plan.
    /// Stored as text for portability; decoded on demand when adapting.
    var generationContextJSON: String? = nil
    var modelVersion: String? = nil

    var createdAt: Date
    var updatedAt: Date

    /// Sessions belonging to this plan. Cascade-deleted with the plan.
    @Relationship(deleteRule: .cascade, inverse: \PlannedSession.plan)
    var sessions: [PlannedSession] = []

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        name: String,
        goalType: RunningGoalType,
        status: RunningPlanStatus = .active,
        startDate: Date,
        totalWeeks: Int,
        targetRaceDate: Date? = nil,
        targetRaceDistance: RaceDistance? = nil,
        targetRaceName: String? = nil,
        targetRaceGoalTimeSeconds: Int? = nil,
        generationSource: RunningPlanGenerationSource = .ai,
        generationContextJSON: String? = nil,
        modelVersion: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.goalTypeRaw = goalType.rawValue
        self.statusRaw = status.rawValue
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.targetRaceDate = targetRaceDate
        self.targetRaceDistanceRaw = targetRaceDistance?.rawValue
        self.targetRaceName = targetRaceName
        self.targetRaceGoalTimeSeconds = targetRaceGoalTimeSeconds
        self.generationSourceRaw = generationSource.rawValue
        self.generationContextJSON = generationContextJSON
        self.modelVersion = modelVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension RunningPlan {
    var goalType: RunningGoalType {
        get { RunningGoalType(rawValue: goalTypeRaw) ?? .generalFitness }
        set { goalTypeRaw = newValue.rawValue }
    }

    var status: RunningPlanStatus {
        get { RunningPlanStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var targetRaceDistance: RaceDistance? {
        get { targetRaceDistanceRaw.flatMap { RaceDistance(rawValue: $0) } }
        set { targetRaceDistanceRaw = newValue?.rawValue }
    }

    var generationSource: RunningPlanGenerationSource {
        get { RunningPlanGenerationSource(rawValue: generationSourceRaw) ?? .ai }
        set { generationSourceRaw = newValue.rawValue }
    }

    /// Marks the plan as completed if the target race date has passed and the
    /// plan is still active. Safe to call on every launch — does nothing when
    /// the plan has no race date, has already been completed, or the race is
    /// still in the future.
    func completeIfRacePassed() {
        guard status == .active,
              let raceDate = targetRaceDate,
              Date() > raceDate
        else { return }
        status = .completed
        updatedAt = Date()
    }
}

// MARK: - PlannedSession

/// A single scheduled workout within a `RunningPlan`.
@Model
final class PlannedSession {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil

    /// Inverse relationship — set automatically when assigned to `RunningPlan.sessions`.
    var plan: RunningPlan? = nil

    // Scheduling
    var weekNumber: Int
    var scheduledDate: Date

    // Prescription
    var sessionTypeRaw: String
    var targetDistanceKm: Double? = nil
    var targetDurationMinutes: Int? = nil
    var targetPaceSecondsPerKm: Int? = nil
    var sessionDescription: String
    var notes: String? = nil

    // Completion
    var completedAt: Date? = nil
    var completedDistanceKm: Double? = nil
    var completedDurationMinutes: Int? = nil
    var completedSource: String? = nil  // healthkit | manual | imported
    var skipped: Bool = false

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        weekNumber: Int,
        scheduledDate: Date,
        sessionType: RunningSessionType,
        targetDistanceKm: Double? = nil,
        targetDurationMinutes: Int? = nil,
        targetPaceSecondsPerKm: Int? = nil,
        description: String,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.weekNumber = weekNumber
        self.scheduledDate = scheduledDate
        self.sessionTypeRaw = sessionType.rawValue
        self.targetDistanceKm = targetDistanceKm
        self.targetDurationMinutes = targetDurationMinutes
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm
        self.sessionDescription = description
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PlannedSession {
    var sessionType: RunningSessionType {
        get { RunningSessionType(rawValue: sessionTypeRaw) ?? .easy }
        set { sessionTypeRaw = newValue.rawValue }
    }

    var isCompleted: Bool { completedAt != nil }
}

// MARK: - Plan Adaptations

/// Logged record of an AI-driven plan adjustment. The actual session edits
/// live on `PlannedSession` rows — this model is the audit log + the source
/// of the "Plan adjusted" banner shown above today's session.
///
/// Mirrors the `running_plan_adaptations` Supabase table. Synced via
/// `CloudSyncManager.syncRunningPlans` so banners survive across devices.
@Model
final class RunningPlanAdaptation {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil
    /// FK to the plan this adaptation belongs to. We keep it as a UUID rather
    /// than a relationship so deleting a plan locally doesn't accidentally
    /// orphan adaptations before the cascade catches up.
    var planId: UUID

    /// Why the adaptation fired. See `AdaptationReason` for canonical values —
    /// stored as raw string for forward compat with new reasons added server-side.
    var reasonRaw: String

    /// Plain-English banner copy shown to the user.
    var summary: String

    /// JSON snapshot of the per-session edits. Shape:
    /// `[{ "session_id": "...", "session_type": "...", ... }]`
    /// Used for audit + future "what changed?" diff view.
    var changesJSON: String?

    /// Number of sessions actually modified. Use this to filter banners — a
    /// no-op adaptation (e.g. weekly_just_right with 0 changes) shouldn't
    /// surface a banner.
    var sessionsChanged: Int

    /// Set when the user dismisses the banner. Nil = unread.
    var acknowledgedAt: Date? = nil

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        planId: UUID,
        reason: AdaptationReason = .manual,
        summary: String,
        changesJSON: String? = nil,
        sessionsChanged: Int = 0,
        acknowledgedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.planId = planId
        self.reasonRaw = reason.rawValue
        self.summary = summary
        self.changesJSON = changesJSON
        self.sessionsChanged = sessionsChanged
        self.acknowledgedAt = acknowledgedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension RunningPlanAdaptation {
    var reason: AdaptationReason {
        get { AdaptationReason(rawValue: reasonRaw) ?? .manual }
        set { reasonRaw = newValue.rawValue }
    }

    var isUnread: Bool { acknowledgedAt == nil }
}

/// Optional context payload sent alongside the adaptation request — gives
/// the AI hints about how big a change is appropriate. All fields are
/// optional; the edge function falls back to its own analysis if missing.
struct AdaptationSignal: Codable, Sendable {
    var missed_sessions_count: Int?
    var pb_improvement_percent: Double?
    var pace_divergence_seconds: Int?
    /// Free-text "this week was…" summary from a weekly check-in.
    var week_summary: String?
}

/// Result of a successful adaptation call. The edge function has already
/// applied the per-session edits; the iOS side just needs to acknowledge
/// it ran and surface the banner.
struct RunningPlanAdaptationResult: Sendable {
    let adaptationId: UUID?
    let planId: UUID
    let sessionsChanged: Int
    let summary: String
}

/// Canonical adaptation triggers. Mirrors the `reason` strings the
/// `adapt-running-plan` edge function expects and writes back.
enum AdaptationReason: String, Codable, CaseIterable {
    case autoMisses     = "auto_misses"
    case autoPB         = "auto_pb"
    case autoPaceFast   = "auto_pace_fast"
    case weeklyTooHard  = "weekly_too_hard"
    case weeklyTooEasy  = "weekly_too_easy"
    case weeklyJustRight = "weekly_just_right"
    case manualEasier   = "manual_easier"
    case manualHarder   = "manual_harder"
    case manual

    /// Short label suitable for the banner subtitle (e.g. "After your weekly check-in").
    var bannerLabel: String {
        switch self {
        case .autoMisses:       return "After missing a few sessions"
        case .autoPB:           return "After your new personal best"
        case .autoPaceFast:     return "Recalibrating your paces"
        case .weeklyTooHard:    return "After your check-in: too hard"
        case .weeklyTooEasy:    return "After your check-in: too easy"
        case .weeklyJustRight:  return "Weekly check-in"
        case .manualEasier:     return "You asked to ease back"
        case .manualHarder:     return "You asked to push harder"
        case .manual:           return "Manual fine-tune"
        }
    }
}
