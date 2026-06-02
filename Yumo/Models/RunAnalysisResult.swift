import Foundation

struct RunAnalysisResult: Codable, Sendable {
    let distanceKm: Double
    let durationMinutes: Double
    let calories: Double
    let avgPace: String    // e.g. "5:30 /km"
    let avgHeartRate: Int
    let elevationGain: Int // meters
    let feedback: String   // "Great aerobic base work! Your HR stayed low..."
    
    enum CodingKeys: String, CodingKey {
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case calories
        case avgPace = "avg_pace"
        case avgHeartRate = "avg_heart_rate"
        case elevationGain = "elevation_gain"
        case feedback
    }

    // Manual conformance to ensure non-MainActor isolation
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.distanceKm = try container.decode(Double.self, forKey: .distanceKm)
        self.durationMinutes = try container.decode(Double.self, forKey: .durationMinutes)
        self.calories = try container.decode(Double.self, forKey: .calories)
        self.avgPace = try container.decode(String.self, forKey: .avgPace)
        self.avgHeartRate = try container.decode(Int.self, forKey: .avgHeartRate)
        self.elevationGain = try container.decode(Int.self, forKey: .elevationGain)
        self.feedback = try container.decode(String.self, forKey: .feedback)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distanceKm, forKey: .distanceKm)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(calories, forKey: .calories)
        try container.encode(avgPace, forKey: .avgPace)
        try container.encode(avgHeartRate, forKey: .avgHeartRate)
        try container.encode(elevationGain, forKey: .elevationGain)
        try container.encode(feedback, forKey: .feedback)
    }
}
