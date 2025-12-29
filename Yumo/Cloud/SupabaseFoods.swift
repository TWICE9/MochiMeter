//
//  SupabaseService.swift
//  Yumo
//
//  Created by Apple on 24/11/2025.
//


//
//  SupabaseService.swift
//  Yumo
//

import Foundation
@preconcurrency import Supabase

// Update payload struct - use @unchecked Sendable to bypass encoder isolation
private struct MasterFoodUpdatePayload: @unchecked Sendable {
    let scan_count: Int
    let updated_at: String
}

extension MasterFoodUpdatePayload: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scan_count, forKey: .scan_count)
        try container.encode(updated_at, forKey: .updated_at)
    }

    private enum CodingKeys: String, CodingKey {
        case scan_count
        case updated_at
    }
}

struct SupabaseService: Sendable {

    // MARK: - Search master_foods by name or brand
    nonisolated func searchFoodsByName(_ term: String, limit: Int = 25) async throws -> [MasterFoodRow] {

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Search in both food_name and brand columns
        let response = try await supabase
            .database
            .from("master_foods")
            .select()
            .or("food_name.ilike.%\(trimmed)%,brand.ilike.%\(trimmed)%")
            .order("scan_count", ascending: false)
            .limit(limit)
            .execute()

        let results = try JSONDecoder().decode([MasterFoodRow].self, from: response.data)
        return results
    }

    // MARK: - Fetch by exact barcode
    nonisolated func fetchByBarcode(_ barcode: String) async throws -> MasterFoodRow? {
        let response = try await supabase
            .database
            .from("master_foods")
            .select()
            .eq("barcode", value: barcode)
            .limit(1)
            .execute()

        let results = try JSONDecoder().decode([MasterFoodRow].self, from: response.data)
        return results.first
    }

    // MARK: - Increment scan count
    nonisolated func incrementScanCount(barcode: String) async throws {
        // First fetch the current scan count
        if let currentFood = try await fetchByBarcode(barcode) {
            let newCount = currentFood.scanCount + 1
            let now = ISO8601DateFormatter().string(from: Date())

            let payload = MasterFoodUpdatePayload(
                scan_count: newCount,
                updated_at: now
            )

            try await supabase
                .database
                .from("master_foods")
                .update(payload)
                .eq("barcode", value: barcode)
                .execute()
        }
    }

    // MARK: - Search USDA foods by name
    nonisolated func searchUSDAFoodsByName(_ term: String, limit: Int = 25) async throws -> [USDAFoodRow] {

        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let response = try await supabase
            .database
            .from("usda_foods")
            .select()
            .ilike("food_name", value: "%\(trimmed)%")
            .limit(limit)
            .execute()

        let results = try JSONDecoder().decode([USDAFoodRow].self, from: response.data)
        return results
    }

    // MARK: - Upsert AI-created food to master_foods
    nonisolated func upsertAIFood(_ food: AIFoodUpload) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        // Check if food already exists
        if let existing = try await fetchByBarcode(food.barcode) {
            // Food exists - just increment scan count
            let newCount = existing.scanCount + 1
            let payload = MasterFoodUpdatePayload(
                scan_count: newCount,
                updated_at: now
            )
            try await supabase
                .database
                .from("master_foods")
                .update(payload)
                .eq("barcode", value: food.barcode)
                .execute()
        } else {
            // New food - insert it
            try await supabase
                .database
                .from("master_foods")
                .insert(food)
                .execute()
        }
    }
}

// MARK: - AI Food Upload Payload
struct AIFoodUpload: @unchecked Sendable {
    let barcode: String
    let food_name: String
    let brand: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let salt: Double
    let potassium: Double
    let scan_count: Int
    let updated_at: String

    init(from result: FoodAnalysisResult) {
        self.barcode = result.generateAIBarcode()
        self.food_name = result.name
        self.brand = "AI Created"
        self.calories = result.calories
        self.protein = result.protein
        self.carbs = result.carbs
        self.fat = result.fat
        self.fiber = result.fiber
        self.sugar = result.sugar
        self.salt = result.salt
        self.potassium = result.potassium
        self.scan_count = 1
        self.updated_at = ISO8601DateFormatter().string(from: Date())
    }
}

extension AIFoodUpload: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(barcode, forKey: .barcode)
        try container.encode(food_name, forKey: .food_name)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(fiber, forKey: .fiber)
        try container.encode(sugar, forKey: .sugar)
        try container.encode(salt, forKey: .salt)
        try container.encode(potassium, forKey: .potassium)
        try container.encode(scan_count, forKey: .scan_count)
        try container.encode(updated_at, forKey: .updated_at)
    }

    private enum CodingKeys: String, CodingKey {
        case barcode, food_name, brand, calories, protein, carbs, fat, fiber, sugar, salt, potassium, scan_count, updated_at
    }
}
