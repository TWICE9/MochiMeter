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
