// Models/OpenFoodFactsModels.swift

import Foundation

// The top-level response object for barcode lookups
struct OFFResponse: Decodable {
    let status: Int
    let product: OFFProduct?
    let error: String?
}

struct OFFProduct: Decodable, Identifiable, Hashable, Equatable {

    let id: String
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?

    // This reads the labels (like "Halal", "Vegan", etc.)
    let labelsTags: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case labelsTags = "labels_tags"
    }
    
    // Computed property to check for Halal status
    var isHalal: Bool {
        return labelsTags?.contains(where: { $0.lowercased().contains("halal") }) ?? false
    }
    
    // ⭐️ FIX 1: Add the Decodable init (was auto-deleted)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.productName = try container.decodeIfPresent(String.self, forKey: .productName)
        self.brands = try container.decodeIfPresent(String.self, forKey: .brands)
        self.nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        self.servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        self.labelsTags = try container.decodeIfPresent([String].self, forKey: .labelsTags)
    }
    
    // ⭐️ FIX 2: Add the memberwise init back (was auto-deleted)
    // This is the init that CommonFood and LoggedFood need
    init(id: String, productName: String?, brands: String?, nutriments: OFFNutriments?, servingSize: String?, labelsTags: [String]?) {
        self.id = id
        self.productName = productName
        self.brands = brands
        self.nutriments = nutriments
        self.servingSize = servingSize
        self.labelsTags = labelsTags
    }
    
    // This is the "cleaning" init for the NavigationStack fix
    init(cleaning product: OFFProduct) {
        self.id = product.id
        self.productName = product.productName
        self.brands = product.brands
        self.servingSize = product.servingSize
        self.labelsTags = product.labelsTags
        
        if let nutriments = product.nutriments {
            self.nutriments = OFFNutriments(
                calories: nutriments.calories,
                protein: nutriments.protein,
                carbs: nutriments.carbs,
                fat: nutriments.fat,
                fiber: nutriments.fiber,
                sugars: nutriments.sugars,
                salt: nutriments.salt,
                potassium: nutriments.potassium,
                caloriesServing: nutriments.caloriesServing,
                proteinServing: nutriments.proteinServing,
                carbsServing: nutriments.carbsServing,
                fatServing: nutriments.fatServing,
                fiberServing: nutriments.fiberServing,
                sugarsServing: nutriments.sugarsServing,
                saltServing: nutriments.saltServing,
                potassiumServing: nutriments.potassiumServing
            )
        } else {
            self.nutriments = nil
        }
    }
}


struct OFFNutriments: Decodable, Hashable, Equatable {
    
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugars: Double?
    let salt: Double?
    let potassium: Double?

    let caloriesServing: Double?
    let proteinServing: Double?
    let carbsServing: Double?
    let fatServing: Double?
    let fiberServing: Double?
    let sugarsServing: Double?
    let saltServing: Double?
    let potassiumServing: Double?
    
    enum CodingKeys: String, CodingKey {
        case calories = "energy-kcal_100g"
        case protein = "proteins_100g"
        case carbs = "carbohydrates_100g"
        case fat = "fat_100g"
        case fiber = "fiber_100g"
        case sugars = "sugars_100g"
        case salt = "salt_100g"
        case potassium = "potassium_100g"
        case caloriesServing = "energy-kcal_serving"
        case proteinServing = "proteins_serving"
        case carbsServing = "carbohydrates_serving"
        case fatServing = "fat_serving"
        case fiberServing = "fiber_serving"
        case sugarsServing = "sugars_serving"
        case saltServing = "salt_serving"
        case potassiumServing = "potassium_serving"
    }
    
    // ⭐️ START OF FIX ⭐️
    // This public init is now accessible from other files
    public init(
        calories: Double?, protein: Double?, carbs: Double?, fat: Double?,
        fiber: Double?, sugars: Double?, salt: Double?, potassium: Double?,
        caloriesServing: Double?, proteinServing: Double?, carbsServing: Double?, fatServing: Double?,
        fiberServing: Double?, sugarsServing: Double?, saltServing: Double?, potassiumServing: Double?
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugars = sugars
        self.salt = salt
        self.potassium = potassium
        self.caloriesServing = caloriesServing
        self.proteinServing = proteinServing
        self.carbsServing = carbsServing
        self.fatServing = fatServing
        self.fiberServing = fiberServing
        self.sugarsServing = sugarsServing
        self.saltServing = saltServing
        self.potassiumServing = potassiumServing
    }
    // ⭐️ END OF FIX ⭐️
    
    static var empty: OFFNutriments {
        OFFNutriments(
            calories: nil, protein: nil, carbs: nil, fat: nil,
            fiber: nil, sugars: nil, salt: nil, potassium: nil,
            caloriesServing: nil, proteinServing: nil, carbsServing: nil, fatServing: nil,
            fiberServing: nil, sugarsServing: nil, saltServing: nil, potassiumServing: nil
        )
    }
    
    // --- Computed Properties ---
    var servingCalories: Double { caloriesServing ?? calories ?? 0 }
    var servingProtein: Double { proteinServing ?? protein ?? 0 }
    var servingCarbs: Double { carbsServing ?? carbs ?? 0 }
    var servingFat: Double { fatServing ?? fat ?? 0 }
    var servingFiber: Double { fiberServing ?? fiber ?? 0 }
    var servingSugars: Double { sugarsServing ?? sugars ?? 0 }
    var servingSalt: Double { saltServing ?? salt ?? 0 }
    var servingPotassium: Double {
        let potassiumGrams = potassiumServing ?? potassium ?? 0
        // OpenFoodFacts returns potassium in grams, convert to mg
        // Only multiply if value is small (< 100, likely in grams)
        // If already in mg range (>= 100), use as-is to prevent exponential growth
        return potassiumGrams < 100 ? potassiumGrams * 1000 : potassiumGrams
    }
}

// This struct decodes the response from the search API
struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
    let count: Int
}
