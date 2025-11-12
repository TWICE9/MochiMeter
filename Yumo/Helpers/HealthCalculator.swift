// Helpers/HealthCalculator.swift

import Foundation

// MARK: - TDEE Calculation Service
struct HealthCalculator {
    
    // ⭐️ REMOVED: The enums (Gender, ActivityLevel, GoalType)
    
    /// Calculates Basal Metabolic Rate (BMR)
    static func calculateBMR(gender: Gender, weightKg: Double, heightCm: Double, age: Int) -> Double {
        var bmr: Double = 0
        
        if gender == .male {
            bmr = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * Double(age))
        } else if gender == .female {
            bmr = 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * Double(age))
        } else {
            let bmrMale = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * Double(age))
            let bmrFemale = 447.593 + (9.247 * weightKg) + (3.098 * heightCm) - (4.330 * Double(age))
            bmr = (bmrMale + bmrFemale) / 2
        }
        return max(0, bmr)
    }
    
    /// Calculates Total Daily Energy Expenditure (TDEE)
    static func calculateTDEE(gender: Gender, weightKg: Double, heightCm: Double, age: Int, activityLevel: ActivityLevel) -> Double {
        let bmr = calculateBMR(gender: gender, weightKg: weightKg, heightCm: heightCm, age: age)
        return bmr * activityLevel.multiplier
    }
    
    /// Helper to get age from a birthdate
    static func calculateAge(birthDate: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }
    
    // MARK: - Goal Calculation
    
    struct CalculatedGoals {
        let targetCalories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }
    
    /// Calculates target calories and macros
    static func calculateDailyGoals(
        gender: Gender,
        weightKg: Double,
        heightCm: Double,
        age: Int,
        activityLevel: ActivityLevel,
        weightGoal: GoalType
    ) -> CalculatedGoals {
        
        let tdee = calculateTDEE(
            gender: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            activityLevel: activityLevel
        )
        
        let targetCalories = tdee + weightGoal.calorieAdjustment
        
        let proteinGrams = weightKg * 1.8
        let proteinCalories = proteinGrams * 4
        
        let fatCalories = targetCalories * 0.25
        let fatGrams = fatCalories / 9
        
        let carbCalories = targetCalories - proteinCalories - fatCalories
        let carbGrams = carbCalories / 4
        
        return CalculatedGoals(
            targetCalories: max(0, targetCalories),
            protein: max(0, proteinGrams),
            carbs: max(0, carbGrams),
            fat: max(0, fatGrams)
        )
    }
}
