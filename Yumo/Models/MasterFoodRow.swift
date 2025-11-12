//
//  MasterFoodRow.swift
//  Yumo
//
//  Represents a single row from the Supabase `master_foods` table.
//  It is a lightweight DTO, not stored with SwiftData.
//

import Foundation

/// A lightweight DTO used only for decoding Supabase rows.
struct MasterFoodRow: Decodable, Identifiable, @unchecked Sendable {
    // We treat `barcode` as the identity
    var id: String { barcode }

    // MARK: - Raw DB columns

    let barcode: String
    let foodName: String
    let brand: String?

    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let salt: Double
    let potassium: Double

    let scanCount: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case barcode
        case foodName   = "food_name"
        case brand
        case calories
        case protein
        case carbs
        case fat
        case fiber
        case sugar
        case salt
        case potassium
        case scanCount  = "scan_count"
        case updatedAt  = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try container.decode(String.self, forKey: .barcode)
        foodName = try container.decode(String.self, forKey: .foodName)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        calories = try container.decode(Double.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        fiber = try container.decode(Double.self, forKey: .fiber)
        sugar = try container.decode(Double.self, forKey: .sugar)
        salt = try container.decode(Double.self, forKey: .salt)
        potassium = try container.decode(Double.self, forKey: .potassium)
        scanCount = try container.decode(Int.self, forKey: .scanCount)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }

    // MARK: - Convenience properties (to look like CommonFood)

    var name: String { foodName }

    var caloriesPerServing: Double { calories }
    var proteinPerServing: Double { protein }
    var carbsPerServing: Double { carbs }
    var fatPerServing: Double { fat }
    var fiberPerServing: Double { fiber }
    var sugarPerServing: Double { sugar }
    var saltPerServing: Double { salt }
    var potassiumPerServing: Double { potassium }

    /// We don't currently store serving size in the DB; you can later add a column.
    var servingSizeDescription: String { "1 serving" }

    /// You can later add a `is_halal` column to the DB and wire it here.
    var isHalal: Bool { false }
}

import Foundation

// MARK: - Conversion into OFFProduct so the rest of the app can reuse it

extension MasterFoodRow {
    /// Convert a DB row into an OFFProduct so all existing code paths can use it.
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
            caloriesServing: caloriesPerServing,
            proteinServing: proteinPerServing,
            carbsServing: carbsPerServing,
            fatServing: fatPerServing,
            fiberServing: fiberPerServing,
            sugarsServing: sugarPerServing,
            saltServing: saltPerServing,
            potassiumServing: potassiumPerServing
        )

        return OFFProduct(
            id: barcode,
            productName: name,
            brands: brand,
            nutriments: nutriments,
            servingSize: servingSizeDescription,
            labelsTags: [] // DB doesn't store labels yet
        )
    }
}
