// Models/USDAFoodRow.swift

import Foundation

struct USDAFoodRow: Decodable, Identifiable, Sendable {
    var id: String { foodName }  // Use food name as stable ID

    let foodName: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let salt: Double?
    let potassium: Double?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case calories
        case protein
        case carbs
        case fat
        case fiber
        case sugar
        case salt
        case potassium
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foodName = try container.decode(String.self, forKey: .foodName)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories)
        protein = try container.decodeIfPresent(Double.self, forKey: .protein)
        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs)
        fat = try container.decodeIfPresent(Double.self, forKey: .fat)
        fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        sugar = try container.decodeIfPresent(Double.self, forKey: .sugar)
        salt = try container.decodeIfPresent(Double.self, forKey: .salt)
        potassium = try container.decodeIfPresent(Double.self, forKey: .potassium)
    }

    // Convenience properties to match CommonFood interface (default to 0 if nil)
    var name: String { foodName }
    var caloriesPerServing: Double { calories ?? 0.0 }
    var proteinPerServing: Double { protein ?? 0.0 }
    var carbsPerServing: Double { carbs ?? 0.0 }
    var fatPerServing: Double { fat ?? 0.0 }
    var fiberPerServing: Double { fiber ?? 0.0 }
    var sugarPerServing: Double { sugar ?? 0.0 }
    var saltPerServing: Double { salt ?? 0.0 }
    var potassiumPerServing: Double { potassium ?? 0.0 }

    var servingSizeDescription: String { "100g" }  // USDA uses 100g as standard
    var isHalal: Bool { false }  // USDA doesn't track halal certification

    // Convert to OFFProduct for compatibility with existing logging flow
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
            id: foodName,  // Use food name as ID since no barcode
            productName: foodName,
            brands: nil,  // USDA foods don't have brand info
            nutriments: nutriments,
            servingSize: servingSizeDescription,
            labelsTags: []
        )
    }
}
