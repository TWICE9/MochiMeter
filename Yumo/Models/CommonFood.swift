// Models/CommonFood.swift

import Foundation
import SwiftData

@Model
final class CommonFood {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(originalName: "barcode")
    var barcode: String?
    
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var carbsPerServing: Double
    var fatPerServing: Double
    
    var fiberPerServing: Double = 0
    var sugarPerServing: Double = 0
    var saltPerServing: Double = 0
    var potassiumPerServing: Double = 0 // Stored in mg
    var servingSizeDescription: String
    var isHalal: Bool = false
    
    init(
        id: UUID = UUID(),
        name: String,
        barcode: String? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbsPerServing: Double,
        fatPerServing: Double,
        fiberPerServing: Double = 0,
        sugarPerServing: Double = 0,
        saltPerServing: Double = 0,
        potassiumPerServing: Double = 0,
        servingSizeDescription: String,
        isHalal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.barcode = barcode
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.carbsPerServing = carbsPerServing
        self.fatPerServing = fatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarPerServing = sugarPerServing
        self.saltPerServing = saltPerServing
        self.potassiumPerServing = potassiumPerServing
        self.servingSizeDescription = servingSizeDescription
        self.isHalal = isHalal
    }
    
    func toLoggedFood(amount: Double) -> LoggedFood {
        return LoggedFood(
            name: self.name,
            servingSizeDescription: self.servingSizeDescription,
            servingAmount: amount,
            caloriesPerServing: self.caloriesPerServing,
            proteinPerServing: self.proteinPerServing,
            carbsPerServing: self.carbsPerServing,
            fatPerServing: self.fatPerServing,
            fiberPerServing: self.fiberPerServing,
            sugarPerServing: self.sugarPerServing,
            saltPerServing: self.saltPerServing,
            potassiumPerServing: self.potassiumPerServing,
            barcode: self.barcode,
            isHalal: self.isHalal
        )
    }
    
    /// Converts this local food item into an OFFProduct
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
