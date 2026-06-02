// Models/LoggedFood.swift

import Foundation
import SwiftData

@Model
final class LoggedFood {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var name: String
    var timestamp: Date
    var servingSizeDescription: String
    var servingAmount: Double {
        didSet { servingAmount = InputValidation.capServingAmount(servingAmount) }
    }

    // Optional photo captured from AI scan
    var photoData: Data? = nil

    // Cloud storage path for the image (e.g., "food-images/userId/logId.jpg")
    var cloudImagePath: String? = nil

    var caloriesPerServing: Double {
        didSet { caloriesPerServing = InputValidation.capCalories(caloriesPerServing) }
    }
    var proteinPerServing: Double {
        didSet { proteinPerServing = InputValidation.capMacro(proteinPerServing) }
    }
    var carbsPerServing: Double {
        didSet { carbsPerServing = InputValidation.capMacro(carbsPerServing) }
    }
    var fatPerServing: Double {
        didSet { fatPerServing = InputValidation.capMacro(fatPerServing) }
    }

    var fiberPerServing: Double = 0 {
        didSet { fiberPerServing = InputValidation.capMacro(fiberPerServing) }
    }
    var sugarPerServing: Double = 0 {
        didSet { sugarPerServing = InputValidation.capMacro(sugarPerServing) }
    }
    var saltPerServing: Double = 0 {
        didSet { saltPerServing = InputValidation.capMacro(saltPerServing) }
    }
    var potassiumPerServing: Double = 0 { // Stored in mg
        didSet { potassiumPerServing = InputValidation.capMacro(potassiumPerServing) }
    }
    
    var barcode: String?
    var brand: String?
    var isHalal: Bool = false
    var recipe: Recipe?
    var aiIngredients: [String]? = nil  // AI-detected ingredients
    var aiIngredientCalories: [String: Double]? = nil  // AI-detected ingredient calorie breakdown (name → calories)
    var aiConfidence: String? = nil  // AI confidence level: "high", "medium", or "low"
    var isAnalyzing: Bool = false  // True when AI analysis is in progress
    var isAnalysisFailed: Bool = false  // True when AI analysis failed (tap to retry)

    init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        servingSizeDescription: String,
        servingAmount: Double,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbsPerServing: Double,
        fatPerServing: Double,
        fiberPerServing: Double = 0,
        sugarPerServing: Double = 0,
        saltPerServing: Double = 0,
        potassiumPerServing: Double = 0,
        barcode: String? = nil,
        brand: String? = nil,
        isHalal: Bool = false,
        photoData: Data? = nil,
        aiIngredients: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.servingSizeDescription = servingSizeDescription
        self.servingAmount = InputValidation.capServingAmount(servingAmount)
        self.caloriesPerServing = InputValidation.capCalories(caloriesPerServing)
        self.proteinPerServing = InputValidation.capMacro(proteinPerServing)
        self.carbsPerServing = InputValidation.capMacro(carbsPerServing)
        self.fatPerServing = InputValidation.capMacro(fatPerServing)
        self.fiberPerServing = InputValidation.capMacro(fiberPerServing)
        self.sugarPerServing = InputValidation.capMacro(sugarPerServing)
        self.saltPerServing = InputValidation.capMacro(saltPerServing)
        self.potassiumPerServing = InputValidation.capMacro(potassiumPerServing)
        self.barcode = barcode
        self.brand = brand
        self.isHalal = isHalal
        self.photoData = photoData
        self.aiIngredients = aiIngredients
    }
    
    // MARK: - Computed Properties for Totals
    
    var totalCalories: Double { caloriesPerServing * servingAmount }
    var totalProtein: Double { proteinPerServing * servingAmount }
    var totalCarbs: Double { carbsPerServing * servingAmount }
    var totalFat: Double { fatPerServing * servingAmount }
    var totalFiber: Double { fiberPerServing * servingAmount }
    var totalSugar: Double { sugarPerServing * servingAmount }
    var totalSalt: Double { saltPerServing * servingAmount }
    var totalPotassium: Double { potassiumPerServing * servingAmount }
    
    
    /// Converts this LoggedFood item back into an OFFProduct
    func toOFFProduct() -> OFFProduct {
        // ⭐️ START OF FIX ⭐️
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
            fatServing: self.fatPerServing, // ⭐️ FIX: Renamed 'fatPerServing' to 'fatServing'
            fiberServing: self.fiberPerServing,
            sugarsServing: self.sugarPerServing,
            saltServing: self.saltPerServing,
            potassiumServing: self.potassiumPerServing / 1000
        )
        // ⭐️ END OF FIX ⭐️
        
        return OFFProduct(
            id: self.barcode ?? self.id.uuidString,
            productName: self.name,
            brands: nil,
            nutriments: nutriments,
            servingSize: self.servingSizeDescription,
            labelsTags: self.isHalal ? ["en:halal"] : []
        )
    }
}
