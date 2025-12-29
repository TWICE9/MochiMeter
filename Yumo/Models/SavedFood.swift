// Models/SavedFood.swift

import Foundation
import SwiftData

@Model
final class SavedFood {
    var id: UUID
    var userId: String
    var foodName: String
    var brand: String?
    var barcode: String?
    
    // Nutritional info (per serving)
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    var fiberPerServing: Double
    var sugarPerServing: Double
    var servingSizeDescription: String
    
    // Optional micronutrients
    var saltPerServing: Double?
    var potassiumPerServing: Double?
    
    // Metadata
    var savedAt: Date
    var isSynced: Bool
    
    init(
        id: UUID = UUID(),
        userId: String,
        foodName: String,
        brand: String? = nil,
        barcode: String? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbsPerServing: Double,
        fatPerServing: Double,
        fiberPerServing: Double,
        sugarPerServing: Double,
        servingSizeDescription: String,
        saltPerServing: Double? = nil,
        potassiumPerServing: Double? = nil,
        savedAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.foodName = foodName
        self.brand = brand
        self.barcode = barcode
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbsPerServing = carbsPerServing
        self.fatPerServing = fatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarPerServing = sugarPerServing
        self.servingSizeDescription = servingSizeDescription
        self.saltPerServing = saltPerServing
        self.potassiumPerServing = potassiumPerServing
        self.savedAt = savedAt
        self.isSynced = isSynced
    }

    /// Converts this SavedFood item into an OFFProduct for logging
    func toOFFProduct() -> OFFProduct {
        let nutriments = OFFNutriments(
            calories: nil,
            protein: nil,
            carbs: nil,
            fat: nil,
            fiber: nil,
            sugars: nil,
            salt: nil,
            potassium: nil,
            
            caloriesServing: self.caloriesPerServing,
            proteinServing: self.proteinPerServing,
            carbsServing: self.carbsPerServing,
            fatServing: self.fatPerServing,
            fiberServing: self.fiberPerServing,
            sugarsServing: self.sugarPerServing,
            saltServing: self.saltPerServing,
            potassiumServing: (self.potassiumPerServing ?? 0) / 1000
        )
        
        return OFFProduct(
            id: self.barcode ?? self.id.uuidString,
            productName: self.foodName,
            brands: self.brand,
            nutriments: nutriments,
            servingSize: self.servingSizeDescription,
            labelsTags: []
        )
    }
}

// MARK: - Supabase Codable Representation
struct SavedFoodRow: Decodable, @unchecked Sendable {
    let id: String
    let userId: String
    let foodName: String
    let brand: String?
    let barcode: String?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let carbsPerServing: Double
    let fatPerServing: Double
    let fiberPerServing: Double
    let sugarPerServing: Double
    let servingSizeDescription: String
    let saltPerServing: Double?
    let potassiumPerServing: Double?
    let savedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case foodName = "food_name"
        case brand
        case barcode
        case caloriesPerServing = "calories_per_serving"
        case proteinPerServing = "protein_per_serving"
        case carbsPerServing = "carbs_per_serving"
        case fatPerServing = "fat_per_serving"
        case fiberPerServing = "fiber_per_serving"
        case sugarPerServing = "sugar_per_serving"
        case servingSizeDescription = "serving_size_description"
        case saltPerServing = "salt_per_serving"
        case potassiumPerServing = "potassium_per_serving"
        case savedAt = "saved_at"
    }
    
    nonisolated init(from savedFood: SavedFood) {
        self.id = savedFood.id.uuidString.lowercased()
        self.userId = savedFood.userId
        self.foodName = savedFood.foodName
        self.brand = savedFood.brand
        self.barcode = savedFood.barcode
        self.caloriesPerServing = savedFood.caloriesPerServing
        self.proteinPerServing = savedFood.proteinPerServing
        self.carbsPerServing = savedFood.carbsPerServing
        self.fatPerServing = savedFood.fatPerServing
        self.fiberPerServing = savedFood.fiberPerServing
        self.sugarPerServing = savedFood.sugarPerServing
        self.servingSizeDescription = savedFood.servingSizeDescription
        self.saltPerServing = savedFood.saltPerServing
        self.potassiumPerServing = savedFood.potassiumPerServing
        self.savedAt = ISO8601DateFormatter().string(from: savedFood.savedAt)
    }
    
    nonisolated func toSavedFood() -> SavedFood {
        SavedFood(
            id: UUID(uuidString: id) ?? UUID(),
            userId: userId,
            foodName: foodName,
            brand: brand,
            barcode: barcode,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            carbsPerServing: carbsPerServing,
            fatPerServing: fatPerServing,
            fiberPerServing: fiberPerServing,
            sugarPerServing: sugarPerServing,
            servingSizeDescription: servingSizeDescription,
            saltPerServing: saltPerServing,
            potassiumPerServing: potassiumPerServing,
            savedAt: ISO8601DateFormatter().date(from: savedAt) ?? Date(),
            isSynced: true
        )
    }
}

// MARK: - Encodable Extension
extension SavedFoodRow: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(foodName, forKey: .foodName)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encode(caloriesPerServing, forKey: .caloriesPerServing)
        try container.encode(proteinPerServing, forKey: .proteinPerServing)
        try container.encode(carbsPerServing, forKey: .carbsPerServing)
        try container.encode(fatPerServing, forKey: .fatPerServing)
        try container.encode(fiberPerServing, forKey: .fiberPerServing)
        try container.encode(sugarPerServing, forKey: .sugarPerServing)
        try container.encode(servingSizeDescription, forKey: .servingSizeDescription)
        try container.encodeIfPresent(saltPerServing, forKey: .saltPerServing)
        try container.encodeIfPresent(potassiumPerServing, forKey: .potassiumPerServing)
        try container.encode(savedAt, forKey: .savedAt)
    }
}

/*
Supabase Table Schema:

CREATE TABLE saved_foods (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    calories_per_serving DOUBLE PRECISION NOT NULL,
    protein_per_serving DOUBLE PRECISION NOT NULL,
    carbs_per_serving DOUBLE PRECISION NOT NULL,
    fat_per_serving DOUBLE PRECISION NOT NULL,
    fiber_per_serving DOUBLE PRECISION NOT NULL,
    sugar_per_serving DOUBLE PRECISION NOT NULL,
    serving_size_description TEXT NOT NULL,
    salt_per_serving DOUBLE PRECISION,
    potassium_per_serving DOUBLE PRECISION,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for faster user queries
CREATE INDEX idx_saved_foods_user_id ON saved_foods(user_id);
CREATE INDEX idx_saved_foods_saved_at ON saved_foods(user_id, saved_at DESC);

-- RLS Policies
ALTER TABLE saved_foods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own saved foods"
    ON saved_foods FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own saved foods"
    ON saved_foods FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own saved foods"
    ON saved_foods FOR DELETE
    USING (auth.uid() = user_id);
*/
