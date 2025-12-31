//
//  OnboardingFlowManager.swift
//  Yumo
//

import Foundation
import SwiftUI

@MainActor
@Observable
class OnboardingFlowManager {
    // MARK: - Navigation
    var currentPage: Int = 0
    let totalPages: Int = 20  // Added theme selection page
    var isNavigating: Bool = false
    private let navigationCooldown: Double = 0.45  // Prevent rapid double-taps

    // MARK: - Collected Data

    // Demographics
    var name: String = "User"
    var gender: Gender = .male
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var height: Double = 170
    var weight: Double = 70
    var weightWhole: Int = 70
    var weightDecimal: Int = 0
    var activityLevel: ActivityLevel = .moderateActivity
    var weightGoal: GoalType = .maintain
    var targetWeight: Double = 70
    var weeklyWeightChangeKg: Double = 0.5  // Default: 0.5kg per week (range: 0.25 to 1.0)
    
    // Unit System
    var unitSystem: UnitSystem = .metric
    
    // Imperial unit properties
    var weightLbs: Int = 154 // ~70kg
    var heightFeet: Int = 5
    var heightInches: Int = 7 // ~170cm

    // New Psychographic Fields
    var selectedBlockers: Set<Blocker> = []
    var dietType: DietType? = nil
    var selectedGoalsToAccomplish: Set<GoalToAccomplish> = []
    var referralCode: String = ""
    var healthKitEnabled: Bool = false

    // MARK: - Progress
    var progress: Double {
        Double(currentPage) / Double(totalPages)
    }

    // MARK: - Navigation
    private func performNavigation(_ action: () -> Void) {
        guard !isNavigating else { return }
        isNavigating = true

        withAnimation(.spring(duration: 0.4)) {
            action()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + navigationCooldown) { [weak self] in
            self?.isNavigating = false
        }
    }

    func goNext() {
        guard canProceed(for: currentPage) else { return }

        performNavigation {
            // Skip target weight page (9) AND intensity page (10) if weight goal is "maintain"
            if currentPage == 8 && weightGoal == .maintain {
                targetWeight = weight  // Set target to current weight
                currentPage = min(currentPage + 3, totalPages - 1)  // Skip pages 9 and 10
            }
            // Skip intensity page (10) if weight goal is "gain" (target weight still needed)
            else if currentPage == 9 && weightGoal == .gain {
                currentPage = min(currentPage + 2, totalPages - 1)  // Skip page 10
            }
            else {
                currentPage = min(currentPage + 1, totalPages - 1)
            }
        }
    }

    func goBack() {
        performNavigation {
            // Skip intensity page (10) AND target weight page (9) when going back if "maintain"
            if currentPage == 11 && weightGoal == .maintain {
                currentPage = max(currentPage - 3, 0)  // Skip back over pages 10 and 9
            }
            // Skip intensity page (10) when going back if weight goal is "gain"
            else if currentPage == 11 && weightGoal == .gain {
                currentPage = max(currentPage - 2, 0)  // Skip back over page 10
            }
            else {
                currentPage = max(currentPage - 1, 0)
            }
        }
    }

    // MARK: - Validation
    func canProceed(for page: Int? = nil) -> Bool {
        let page = page ?? currentPage

        switch page {
        case 3: // Name
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 6: // Height & Weight
            return height > 0 && weight > 0
        case 9: // Target Weight
            return targetWeight > 0
        case 11: // What's Stopping You (multi-select)
            return !selectedBlockers.isEmpty
        case 12: // Diet Type
            return dietType != nil
        case 13: // What to Accomplish (multi-select)
            return !selectedGoalsToAccomplish.isEmpty
        default:
            return true
        }
    }

    // MARK: - Convert to UserGoals
    func buildUserGoals() -> UserGoals {
        let goals = UserGoals()

        // Demographics
        goals.name = name
        goals.birthDate = birthDate
        goals.gender = gender
        goals.height = height
        goals.weight = weight
        goals.activityLevel = activityLevel
        goals.weightGoal = weightGoal
        // If maintaining weight, target should equal current weight
        goals.targetWeight = weightGoal == .maintain ? weight : targetWeight
        goals.weeklyWeightChangeKg = weeklyWeightChangeKg
        goals.unitSystem = unitSystem  // Save selected unit system

        // Psychographics
        goals.blockers = Array(selectedBlockers)
        goals.dietType = dietType
        goals.goalsToAccomplish = Array(selectedGoalsToAccomplish)
        goals.referralCode = referralCode.isEmpty ? nil : referralCode
        goals.healthKitEnabled = healthKitEnabled

        // Debug logging
        print("🐛 Building UserGoals:")
        print("   Blockers: \(selectedBlockers.map { $0.rawValue })")
        print("   Diet Type: \(dietType?.rawValue ?? "nil")")
        print("   Goals: \(selectedGoalsToAccomplish.map { $0.rawValue })")
        print("   Weekly Weight Change: \(weeklyWeightChangeKg) kg/week")
        print("   Raw arrays in goals object:")
        print("   - blockersRaw: \(goals.blockersRaw ?? [])")
        print("   - dietTypeRaw: \(goals.dietTypeRaw ?? "nil")")
        print("   - goalsToAccomplishRaw: \(goals.goalsToAccomplishRaw ?? [])")

        // Calculate nutrition goals with dynamic deficit
        let age = HealthCalculator.calculateAge(birthDate: birthDate)
        let macros = HealthCalculator.calculateDailyGoals(
            gender: gender,
            weightKg: weight,
            heightCm: height,
            age: age,
            activityLevel: activityLevel,
            weightGoal: weightGoal,
            weeklyWeightChangeKg: weeklyWeightChangeKg
        )

        goals.dailyCalories = macros.targetCalories
        goals.dailyProtein = macros.protein
        goals.dailyCarbs = macros.carbs
        goals.dailyFat = macros.fat

        return goals
    }

    // MARK: - Helper: Update weight from pickers
    func updateWeightFromPickers() {
        weight = Double(weightWhole) + (Double(weightDecimal) / 10.0)

        // Also update target weight if it's still default
        if targetWeight == 0 || targetWeight == Double(weightWhole) {
            targetWeight = weight
        }
    }
    
    // MARK: - Imperial Conversion Methods
    func updateWeightFromImperialPickers() {
        // Convert lbs to kg for storage
        weight = unitSystem.convertWeightToMetric(Double(weightLbs))
        
        // Update target weight if needed
        if targetWeight == 0 || abs(targetWeight - weight) < 1 {
            targetWeight = weight
        }
    }
    
    func updateHeightFromImperialPickers() {
        // Convert feet/inches to cm for storage
        height = unitSystem.convertHeightToMetric(primary: Double(heightFeet), secondary: Double(heightInches))
    }
    
    func convertUnitsOnChange(from oldSystem: UnitSystem, to newSystem: UnitSystem) {
        if oldSystem == .metric && newSystem == .imperial {
            // Convert current metric values to imperial
            let (feet, inches) = newSystem.formatHeight(height)
            heightFeet = Int(feet)
            heightInches = Int(inches ?? 0)
            weightLbs = Int(newSystem.formatWeight(weight))
        } else if oldSystem == .imperial && newSystem == .metric {
            // Convert current imperial values to metric
            height = oldSystem.convertHeightToMetric(primary: Double(heightFeet), secondary: Double(heightInches))
            weight = oldSystem.convertWeightToMetric(Double(weightLbs))
            weightWhole = Int(weight)
            weightDecimal = Int((weight - Double(weightWhole)) * 10)
        }
    }
    
    // MARK: - HealthKit Integration
    
    /// Apply HealthKit profile data to pre-fill onboarding fields
    func applyHealthKitData(weight weightKg: Double?, height heightCm: Double?, dob: Date?, sex: Int?) {
        if let weightKg = weightKg, weightKg > 0 {
            self.weight = weightKg
            self.weightWhole = Int(weightKg)
            self.weightDecimal = Int((weightKg - Double(Int(weightKg))) * 10)
            self.weightLbs = Int(weightKg * 2.20462)
            self.targetWeight = weightKg  // Start with current as target
            print("✅ Pre-filled weight from HealthKit: \(weightKg) kg")
        }
        
        if let heightCm = heightCm, heightCm > 0 {
            self.height = heightCm
            // Also update imperial values
            let totalInches = heightCm / 2.54
            self.heightFeet = Int(totalInches / 12)
            self.heightInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            print("✅ Pre-filled height from HealthKit: \(heightCm) cm")
        }
        
        if let dob = dob {
            self.birthDate = dob
            print("✅ Pre-filled DOB from HealthKit: \(dob)")
        }
        
        // Convert HKBiologicalSex raw value to our Gender enum
        // HKBiologicalSex: 0 = notSet, 1 = female, 2 = male, 3 = other
        if let sexRaw = sex {
            switch sexRaw {
            case 1: // female
                self.gender = .female
                print("✅ Pre-filled gender from HealthKit: female")
            case 2: // male
                self.gender = .male
                print("✅ Pre-filled gender from HealthKit: male")
            default:
                print("ℹ️ HealthKit sex not set or other, keeping default")
            }
        }
    }
}
