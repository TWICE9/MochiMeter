// Cloud/CloudModels.swift

import Foundation

/// Cloud data models for Supabase sync
/// These structs mirror the database schema and are used for encoding/decoding
/// All use nonisolated Codable to avoid MainActor isolation issues

struct CloudFoodLog: Sendable {
    let id: String
    let user_id: String
    let name: String
    let timestamp: Date
    let serving_size_description: String
    let serving_amount: Double
    let calories_per_serving: Double
    let protein_per_serving: Double
    let carbs_per_serving: Double
    let fat_per_serving: Double
    let fiber_per_serving: Double
    let sugar_per_serving: Double
    let salt_per_serving: Double
    let potassium_per_serving: Double
    let barcode: String?
    let brand: String?
    let is_halal: Bool
    let recipe_id: String?
    let image_path: String?  // Cloud storage path for the food image
    let updated_at: Date
}

extension CloudFoodLog: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, name, timestamp
        case serving_size_description, serving_amount
        case calories_per_serving, protein_per_serving, carbs_per_serving, fat_per_serving
        case fiber_per_serving, sugar_per_serving, salt_per_serving, potassium_per_serving
        case barcode, brand, is_halal, recipe_id, image_path, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        name = try container.decode(String.self, forKey: .name)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        serving_size_description = try container.decode(String.self, forKey: .serving_size_description)
        serving_amount = try container.decode(Double.self, forKey: .serving_amount)
        calories_per_serving = try container.decode(Double.self, forKey: .calories_per_serving)
        protein_per_serving = try container.decode(Double.self, forKey: .protein_per_serving)
        carbs_per_serving = try container.decode(Double.self, forKey: .carbs_per_serving)
        fat_per_serving = try container.decode(Double.self, forKey: .fat_per_serving)
        fiber_per_serving = try container.decode(Double.self, forKey: .fiber_per_serving)
        sugar_per_serving = try container.decode(Double.self, forKey: .sugar_per_serving)
        salt_per_serving = try container.decode(Double.self, forKey: .salt_per_serving)
        potassium_per_serving = try container.decode(Double.self, forKey: .potassium_per_serving)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        is_halal = try container.decode(Bool.self, forKey: .is_halal)
        recipe_id = try container.decodeIfPresent(String.self, forKey: .recipe_id)
        image_path = try container.decodeIfPresent(String.self, forKey: .image_path)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(serving_size_description, forKey: .serving_size_description)
        try container.encode(serving_amount, forKey: .serving_amount)
        try container.encode(calories_per_serving, forKey: .calories_per_serving)
        try container.encode(protein_per_serving, forKey: .protein_per_serving)
        try container.encode(carbs_per_serving, forKey: .carbs_per_serving)
        try container.encode(fat_per_serving, forKey: .fat_per_serving)
        try container.encode(fiber_per_serving, forKey: .fiber_per_serving)
        try container.encode(sugar_per_serving, forKey: .sugar_per_serving)
        try container.encode(salt_per_serving, forKey: .salt_per_serving)
        try container.encode(potassium_per_serving, forKey: .potassium_per_serving)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encode(is_halal, forKey: .is_halal)
        try container.encodeIfPresent(recipe_id, forKey: .recipe_id)
        try container.encodeIfPresent(image_path, forKey: .image_path)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudWaterLog: Sendable {
    let id: String
    let user_id: String
    let amount_ml: Double
    let timestamp: Date
    let updated_at: Date
}

extension CloudWaterLog: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, amount_ml, timestamp, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        amount_ml = try container.decode(Double.self, forKey: .amount_ml)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(amount_ml, forKey: .amount_ml)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudFastingLog: Sendable {
    let id: String
    let user_id: String
    let start_time: Date
    let end_time: Date?
    let goal_hours: Double
    let updated_at: Date
}

extension CloudFastingLog: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, start_time, end_time, goal_hours, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        start_time = try container.decode(Date.self, forKey: .start_time)
        end_time = try container.decodeIfPresent(Date.self, forKey: .end_time)
        goal_hours = try container.decode(Double.self, forKey: .goal_hours)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(start_time, forKey: .start_time)
        try container.encodeIfPresent(end_time, forKey: .end_time)
        try container.encode(goal_hours, forKey: .goal_hours)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudRecipe: Sendable {
    let id: String
    let user_id: String
    let name: String
    let servings: Double
    let updated_at: Date
}

extension CloudRecipe: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, name, servings, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        name = try container.decode(String.self, forKey: .name)
        servings = try container.decode(Double.self, forKey: .servings)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(name, forKey: .name)
        try container.encode(servings, forKey: .servings)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudReminder: Sendable {
    let id: String
    let user_id: String
    let title: String
    let notes: String
    let time: Date
    let is_enabled: Bool
    let weekdays: [Int]
    let notification_id: String
    let updated_at: Date
}

extension CloudReminder: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, title, notes, time, is_enabled, weekdays, notification_id, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        time = try container.decode(Date.self, forKey: .time)
        is_enabled = try container.decode(Bool.self, forKey: .is_enabled)
        weekdays = try container.decode([Int].self, forKey: .weekdays)
        notification_id = try container.decode(String.self, forKey: .notification_id)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(title, forKey: .title)
        try container.encode(notes, forKey: .notes)
        try container.encode(time, forKey: .time)
        try container.encode(is_enabled, forKey: .is_enabled)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(notification_id, forKey: .notification_id)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudWeightLog: Sendable {
    let id: String
    let user_id: String
    let weight_kg: Double
    let note: String?
    let timestamp: Date
    let updated_at: Date
}

extension CloudWeightLog: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, weight_kg, note, timestamp, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        weight_kg = try container.decode(Double.self, forKey: .weight_kg)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(weight_kg, forKey: .weight_kg)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudRunningProfile: Sendable {
    let user_id: UUID
    let has_completed_onboarding: Bool
    let experience: String
    let has_run_before: Bool
    let primary_goal: String
    let weekly_run_days_target: Int
    let available_days: [String]
    let long_run_day: String?
    let current_longest_run_km: Double?
    let current_weekly_km: Double?
    let typical_pace_seconds_per_km: Int?
    let recent_1km_seconds: Int?
    let recent_5km_seconds: Int?
    let recent_10km_seconds: Int?
    let recent_half_marathon_seconds: Int?
    let recent_marathon_seconds: Int?
    let target_race_date: Date?
    let target_race_distance: String?
    let target_race_name: String?
    let target_race_goal_time_seconds: Int?
    let injuries_or_limitations: String?
    let cross_training_activities: [String]?
    let cross_training_sessions_per_week: Int?
    /// Per-activity day commitments — flat `["Strength:mon", "Yoga:sun"]`
    /// strings so the column maps cleanly to a Postgres `text[]`.
    let cross_training_schedule: [String]?
    let workout_reminders_enabled: Bool?
    let workout_reminder_hour: Int?
    let workout_reminder_minute: Int?
    let created_at: Date
    let updated_at: Date
}

extension CloudRunningProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case user_id, has_completed_onboarding, experience, has_run_before
        case primary_goal, weekly_run_days_target, available_days, long_run_day
        case current_longest_run_km, current_weekly_km, typical_pace_seconds_per_km
        case recent_1km_seconds, recent_5km_seconds, recent_10km_seconds
        case recent_half_marathon_seconds, recent_marathon_seconds
        case target_race_date, target_race_distance, target_race_name, target_race_goal_time_seconds
        case injuries_or_limitations
        case cross_training_activities, cross_training_sessions_per_week, cross_training_schedule
        case workout_reminders_enabled, workout_reminder_hour, workout_reminder_minute
        case created_at, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        has_completed_onboarding = try container.decode(Bool.self, forKey: .has_completed_onboarding)
        experience = try container.decode(String.self, forKey: .experience)
        has_run_before = try container.decode(Bool.self, forKey: .has_run_before)
        primary_goal = try container.decode(String.self, forKey: .primary_goal)
        weekly_run_days_target = try container.decode(Int.self, forKey: .weekly_run_days_target)
        available_days = try container.decodeIfPresent([String].self, forKey: .available_days) ?? []
        long_run_day = try container.decodeIfPresent(String.self, forKey: .long_run_day)
        current_longest_run_km = try container.decodeIfPresent(Double.self, forKey: .current_longest_run_km)
        current_weekly_km = try container.decodeIfPresent(Double.self, forKey: .current_weekly_km)
        typical_pace_seconds_per_km = try container.decodeIfPresent(Int.self, forKey: .typical_pace_seconds_per_km)
        recent_1km_seconds = try container.decodeIfPresent(Int.self, forKey: .recent_1km_seconds)
        recent_5km_seconds = try container.decodeIfPresent(Int.self, forKey: .recent_5km_seconds)
        recent_10km_seconds = try container.decodeIfPresent(Int.self, forKey: .recent_10km_seconds)
        recent_half_marathon_seconds = try container.decodeIfPresent(Int.self, forKey: .recent_half_marathon_seconds)
        recent_marathon_seconds = try container.decodeIfPresent(Int.self, forKey: .recent_marathon_seconds)
        target_race_date = try container.decodeIfPresent(Date.self, forKey: .target_race_date)
        target_race_distance = try container.decodeIfPresent(String.self, forKey: .target_race_distance)
        target_race_name = try container.decodeIfPresent(String.self, forKey: .target_race_name)
        target_race_goal_time_seconds = try container.decodeIfPresent(Int.self, forKey: .target_race_goal_time_seconds)
        injuries_or_limitations = try container.decodeIfPresent(String.self, forKey: .injuries_or_limitations)
        cross_training_activities = try container.decodeIfPresent([String].self, forKey: .cross_training_activities)
        cross_training_sessions_per_week = try container.decodeIfPresent(Int.self, forKey: .cross_training_sessions_per_week)
        cross_training_schedule = try container.decodeIfPresent([String].self, forKey: .cross_training_schedule)
        workout_reminders_enabled = try container.decodeIfPresent(Bool.self, forKey: .workout_reminders_enabled)
        workout_reminder_hour = try container.decodeIfPresent(Int.self, forKey: .workout_reminder_hour)
        workout_reminder_minute = try container.decodeIfPresent(Int.self, forKey: .workout_reminder_minute)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(has_completed_onboarding, forKey: .has_completed_onboarding)
        try container.encode(experience, forKey: .experience)
        try container.encode(has_run_before, forKey: .has_run_before)
        try container.encode(primary_goal, forKey: .primary_goal)
        try container.encode(weekly_run_days_target, forKey: .weekly_run_days_target)
        try container.encode(available_days, forKey: .available_days)
        try container.encodeIfPresent(long_run_day, forKey: .long_run_day)
        try container.encodeIfPresent(current_longest_run_km, forKey: .current_longest_run_km)
        try container.encodeIfPresent(current_weekly_km, forKey: .current_weekly_km)
        try container.encodeIfPresent(typical_pace_seconds_per_km, forKey: .typical_pace_seconds_per_km)
        try container.encodeIfPresent(recent_1km_seconds, forKey: .recent_1km_seconds)
        try container.encodeIfPresent(recent_5km_seconds, forKey: .recent_5km_seconds)
        try container.encodeIfPresent(recent_10km_seconds, forKey: .recent_10km_seconds)
        try container.encodeIfPresent(recent_half_marathon_seconds, forKey: .recent_half_marathon_seconds)
        try container.encodeIfPresent(recent_marathon_seconds, forKey: .recent_marathon_seconds)
        try container.encodeIfPresent(target_race_date, forKey: .target_race_date)
        try container.encodeIfPresent(target_race_distance, forKey: .target_race_distance)
        try container.encodeIfPresent(target_race_name, forKey: .target_race_name)
        try container.encodeIfPresent(target_race_goal_time_seconds, forKey: .target_race_goal_time_seconds)
        try container.encodeIfPresent(injuries_or_limitations, forKey: .injuries_or_limitations)
        try container.encodeIfPresent(cross_training_activities, forKey: .cross_training_activities)
        try container.encodeIfPresent(cross_training_sessions_per_week, forKey: .cross_training_sessions_per_week)
        try container.encodeIfPresent(cross_training_schedule, forKey: .cross_training_schedule)
        try container.encodeIfPresent(workout_reminders_enabled, forKey: .workout_reminders_enabled)
        try container.encodeIfPresent(workout_reminder_hour, forKey: .workout_reminder_hour)
        try container.encodeIfPresent(workout_reminder_minute, forKey: .workout_reminder_minute)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

// MARK: - Running Plans

struct CloudRunningPlan: Sendable {
    let id: UUID
    let user_id: UUID
    let name: String
    let goal_type: String
    let status: String
    let start_date: Date
    let total_weeks: Int
    let target_race_date: Date?
    let target_race_distance: String?
    let target_race_name: String?
    let target_race_goal_time_seconds: Int?
    let generation_source: String
    /// JSON-encoded string; re-decoded as JSONB server-side.
    let generation_context: String?
    let model_version: String?
    let created_at: Date
    let updated_at: Date
}

extension CloudRunningPlan: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, name, goal_type, status, start_date, total_weeks
        case target_race_date, target_race_distance, target_race_name, target_race_goal_time_seconds
        case generation_source, generation_context, model_version, created_at, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        name = try c.decode(String.self, forKey: .name)
        goal_type = try c.decode(String.self, forKey: .goal_type)
        status = try c.decode(String.self, forKey: .status)
        start_date = try c.decode(Date.self, forKey: .start_date)
        total_weeks = try c.decode(Int.self, forKey: .total_weeks)
        target_race_date = try c.decodeIfPresent(Date.self, forKey: .target_race_date)
        target_race_distance = try c.decodeIfPresent(String.self, forKey: .target_race_distance)
        target_race_name = try c.decodeIfPresent(String.self, forKey: .target_race_name)
        target_race_goal_time_seconds = try c.decodeIfPresent(Int.self, forKey: .target_race_goal_time_seconds)
        generation_source = try c.decode(String.self, forKey: .generation_source)
        // generation_context is JSONB — may come back as a dictionary or a string.
        // Normalize to a JSON string locally so we can round-trip it without schema drift.
        if let raw = try? c.decodeIfPresent(String.self, forKey: .generation_context) {
            generation_context = raw
        } else if let object = try? c.decodeIfPresent([String: AnyCodable].self, forKey: .generation_context) {
            let data = (try? JSONEncoder().encode(object)) ?? Data()
            generation_context = String(data: data, encoding: .utf8)
        } else {
            generation_context = nil
        }
        model_version = try c.decodeIfPresent(String.self, forKey: .model_version)
        created_at = try c.decode(Date.self, forKey: .created_at)
        updated_at = try c.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(name, forKey: .name)
        try c.encode(goal_type, forKey: .goal_type)
        try c.encode(status, forKey: .status)
        try c.encode(start_date, forKey: .start_date)
        try c.encode(total_weeks, forKey: .total_weeks)
        try c.encodeIfPresent(target_race_date, forKey: .target_race_date)
        try c.encodeIfPresent(target_race_distance, forKey: .target_race_distance)
        try c.encodeIfPresent(target_race_name, forKey: .target_race_name)
        try c.encodeIfPresent(target_race_goal_time_seconds, forKey: .target_race_goal_time_seconds)
        try c.encode(generation_source, forKey: .generation_source)
        try c.encodeIfPresent(generation_context, forKey: .generation_context)
        try c.encodeIfPresent(model_version, forKey: .model_version)
        try c.encode(created_at, forKey: .created_at)
        try c.encode(updated_at, forKey: .updated_at)
    }
}

struct CloudPlannedSession: Sendable {
    let id: UUID
    let user_id: UUID
    let plan_id: UUID
    let week_number: Int
    let scheduled_date: Date
    let session_type: String
    let target_distance_km: Double?
    let target_duration_minutes: Int?
    let target_pace_seconds_per_km: Int?
    let description: String
    let notes: String?
    let completed_at: Date?
    let completed_distance_km: Double?
    let completed_duration_minutes: Int?
    let completed_source: String?
    let skipped: Bool
    let created_at: Date
    let updated_at: Date
}

extension CloudPlannedSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, plan_id, week_number, scheduled_date, session_type
        case target_distance_km, target_duration_minutes, target_pace_seconds_per_km
        case description, notes
        case completed_at, completed_distance_km, completed_duration_minutes, completed_source, skipped
        case created_at, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        plan_id = try c.decode(UUID.self, forKey: .plan_id)
        week_number = try c.decode(Int.self, forKey: .week_number)
        scheduled_date = try c.decode(Date.self, forKey: .scheduled_date)
        session_type = try c.decode(String.self, forKey: .session_type)
        target_distance_km = try c.decodeIfPresent(Double.self, forKey: .target_distance_km)
        target_duration_minutes = try c.decodeIfPresent(Int.self, forKey: .target_duration_minutes)
        target_pace_seconds_per_km = try c.decodeIfPresent(Int.self, forKey: .target_pace_seconds_per_km)
        description = try c.decode(String.self, forKey: .description)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        completed_at = try c.decodeIfPresent(Date.self, forKey: .completed_at)
        completed_distance_km = try c.decodeIfPresent(Double.self, forKey: .completed_distance_km)
        completed_duration_minutes = try c.decodeIfPresent(Int.self, forKey: .completed_duration_minutes)
        completed_source = try c.decodeIfPresent(String.self, forKey: .completed_source)
        skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
        created_at = try c.decode(Date.self, forKey: .created_at)
        updated_at = try c.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(plan_id, forKey: .plan_id)
        try c.encode(week_number, forKey: .week_number)
        try c.encode(scheduled_date, forKey: .scheduled_date)
        try c.encode(session_type, forKey: .session_type)
        try c.encodeIfPresent(target_distance_km, forKey: .target_distance_km)
        try c.encodeIfPresent(target_duration_minutes, forKey: .target_duration_minutes)
        try c.encodeIfPresent(target_pace_seconds_per_km, forKey: .target_pace_seconds_per_km)
        try c.encode(description, forKey: .description)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(completed_at, forKey: .completed_at)
        try c.encodeIfPresent(completed_distance_km, forKey: .completed_distance_km)
        try c.encodeIfPresent(completed_duration_minutes, forKey: .completed_duration_minutes)
        try c.encodeIfPresent(completed_source, forKey: .completed_source)
        try c.encode(skipped, forKey: .skipped)
        try c.encode(created_at, forKey: .created_at)
        try c.encode(updated_at, forKey: .updated_at)
    }
}

// Minimal AnyCodable so we can decode JSONB objects into a round-trippable string.
private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull(); return }
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value); return }
        if let v = try? c.decode([String: AnyCodable].self) {
            value = v.mapValues(\.value); return
        }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as [Any]: try c.encode(v.map { AnyCodable(value: $0) })
        case let v as [String: Any]: try c.encode(v.mapValues { AnyCodable(value: $0) })
        default: try c.encodeNil()
        }
    }

    private init(value: Any) { self.value = value }
}

struct CloudFitnessLog: Sendable {
    let id: String
    let user_id: String
    let date: String  // ISO8601 date string (YYYY-MM-DD)
    let steps: Int?
    let calories_burned: Double?
    let updated_at: Date
}

extension CloudFitnessLog: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, date, steps, calories_burned, updated_at
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        user_id = try container.decode(String.self, forKey: .user_id)
        date = try container.decode(String.self, forKey: .date)
        steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        calories_burned = try container.decodeIfPresent(Double.self, forKey: .calories_burned)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(steps, forKey: .steps)
        try container.encodeIfPresent(calories_burned, forKey: .calories_burned)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

// MARK: - Running Plan Adaptations

struct CloudRunningPlanAdaptation: Sendable {
    let id: UUID
    let user_id: UUID
    let plan_id: UUID
    let reason: String
    let summary: String
    /// JSONB column. We store as a JSON string locally to round-trip cleanly.
    let changes: String?
    let sessions_changed: Int
    let acknowledged_at: Date?
    let created_at: Date
    let updated_at: Date
}

extension CloudRunningPlanAdaptation: Codable {
    enum CodingKeys: String, CodingKey {
        case id, user_id, plan_id, reason, summary, changes, sessions_changed
        case acknowledged_at, created_at, updated_at
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        plan_id = try c.decode(UUID.self, forKey: .plan_id)
        reason = try c.decode(String.self, forKey: .reason)
        summary = try c.decode(String.self, forKey: .summary)
        // `changes` is JSONB — Postgres returns it as either a JSON string
        // or a decoded array. Normalize to a JSON string locally so we can
        // keep the audit trail without schema drift.
        if let raw = try? c.decodeIfPresent(String.self, forKey: .changes) {
            changes = raw
        } else if let arr = try? c.decodeIfPresent([AnyCodable].self, forKey: .changes) {
            let data = (try? JSONEncoder().encode(arr)) ?? Data()
            changes = String(data: data, encoding: .utf8)
        } else {
            changes = nil
        }
        sessions_changed = (try? c.decodeIfPresent(Int.self, forKey: .sessions_changed)) ?? 0
        acknowledged_at = try c.decodeIfPresent(Date.self, forKey: .acknowledged_at)
        created_at = try c.decode(Date.self, forKey: .created_at)
        updated_at = try c.decode(Date.self, forKey: .updated_at)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(plan_id, forKey: .plan_id)
        try c.encode(reason, forKey: .reason)
        try c.encode(summary, forKey: .summary)
        try c.encodeIfPresent(changes, forKey: .changes)
        try c.encode(sessions_changed, forKey: .sessions_changed)
        try c.encodeIfPresent(acknowledged_at, forKey: .acknowledged_at)
        try c.encode(created_at, forKey: .created_at)
        try c.encode(updated_at, forKey: .updated_at)
    }
}
