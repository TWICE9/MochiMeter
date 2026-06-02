import Foundation

struct InsertRun: Encodable, Sendable {
    let user_id: UUID
    let run_date: Date
    let distance_km: Double
    let duration_minutes: Double
    let calories: Double?
    let avg_pace: String?
    let avg_heart_rate: Int?
    let elevation_gain: Int?
    let feedback: String?
    /// Optional blob — populated when the run was sourced from HealthKit so
    /// the route + chart series follow the user's account across devices.
    let analytics_blob: RunAnalyticsBlob?

    // Manually implement Encodable to enforce non-isolated conformance
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(run_date, forKey: .run_date)
        try container.encode(distance_km, forKey: .distance_km)
        try container.encode(duration_minutes, forKey: .duration_minutes)
        try container.encode(calories, forKey: .calories)
        try container.encode(avg_pace, forKey: .avg_pace)
        try container.encode(avg_heart_rate, forKey: .avg_heart_rate)
        try container.encode(elevation_gain, forKey: .elevation_gain)
        try container.encode(feedback, forKey: .feedback)
        try container.encodeIfPresent(analytics_blob, forKey: .analytics_blob)
    }

    enum CodingKeys: String, CodingKey {
        case user_id, run_date, distance_km, duration_minutes, calories
        case avg_pace, avg_heart_rate, elevation_gain, feedback, analytics_blob
    }
}
