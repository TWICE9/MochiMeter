//
//  InputValidation.swift
//  Yumo
//
//  Input validation and capping helpers to prevent data corruption
//

import Foundation

enum InputValidation {

    // MARK: - Maximum Values

    static let maxCalories: Double = 10_000        // 10,000 kcal per serving
    static let maxMacroGrams: Double = 1_000       // 1,000g for protein, carbs, fat, fiber, sugar
    static let maxServingAmount: Double = 100      // 100 servings max
    static let maxDailyCalories: Double = 10_000   // 10,000 kcal daily goal
    static let maxDailyMacro: Double = 1_000       // 1,000g daily macro goal
    static let maxWaterML: Double = 10_000         // 10 liters
    static let maxCupSizeML: Double = 2_000        // 2 liters per cup
    static let minWeightKg: Double = 20           // 20 kg minimum
    static let maxWeightKg: Double = 500          // 500 kg maximum

    // MARK: - Validation Methods

    /// Caps a calorie value to the maximum allowed
    static func capCalories(_ value: Double) -> Double {
        return min(max(value, 0), maxCalories)
    }

    /// Caps a macro value (protein, carbs, fat, fiber, sugar) to the maximum allowed
    static func capMacro(_ value: Double) -> Double {
        return min(max(value, 0), maxMacroGrams)
    }

    /// Caps a serving amount to the maximum allowed
    static func capServingAmount(_ value: Double) -> Double {
        return min(max(value, 0.1), maxServingAmount)
    }

    /// Caps a daily calorie goal to the maximum allowed
    static func capDailyCalories(_ value: Double) -> Double {
        return min(max(value, 100), maxDailyCalories)
    }

    /// Caps a daily macro goal to the maximum allowed
    static func capDailyMacro(_ value: Double) -> Double {
        return min(max(value, 1), maxDailyMacro)
    }

    /// Caps water volume in mL to the maximum allowed
    static func capWater(_ value: Double) -> Double {
        return min(max(value, 100), maxWaterML)
    }

    /// Caps cup size in mL to the maximum allowed
    static func capCupSize(_ value: Double) -> Double {
        return min(max(value, 50), maxCupSizeML)
    }

    /// Caps weight in kg to the allowed range
    static func capWeight(_ value: Double) -> Double {
        return min(max(value, minWeightKg), maxWeightKg)
    }
}
