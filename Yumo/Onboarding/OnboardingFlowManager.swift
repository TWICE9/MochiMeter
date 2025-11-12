//
//  OnboardingFlowManager.swift
//  Yumo
//

import Foundation
import SwiftUI

@Observable
class OnboardingFlowManager {
    // MARK: - Navigation
    var currentPage: Int = 0
    let totalPages: Int = 18  // Reduced by 1 - referral code page removed

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
    func goNext() {
        withAnimation(.spring(duration: 0.4)) {
            // Skip target weight page (8) if weight goal is "maintain"
            if currentPage == 7 && weightGoal == .maintain {
                targetWeight = weight  // Set target to current weight
                currentPage = min(currentPage + 2, totalPages - 1)  // Skip page 8
            } else {
                currentPage = min(currentPage + 1, totalPages - 1)
            }
        }
    }

    func goBack() {
        withAnimation(.spring(duration: 0.4)) {
            // Skip target weight page (8) when going back if weight goal is "maintain"
            if currentPage == 9 && weightGoal == .maintain {
                currentPage = max(currentPage - 2, 0)  // Skip back over page 8
            } else {
                currentPage = max(currentPage - 1, 0)
            }
        }
    }

    // MARK: - Validation
    func canProceed(for page: Int) -> Bool {
        switch page {
        case 2: // Name
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 4: // Gender
            return true // Always valid
        case 5: // Activity Level
            return true // Always valid
        case 6: // Height & Weight
            return height > 0 && weight > 0
        case 7: // Date of Birth
            return true // Always valid
        case 8: // Weight Goal
            return true // Always valid
        case 9: // Target Weight
            return targetWeight > 0
        case 10: // What's Stopping You (multi-select)
            return !selectedBlockers.isEmpty
        case 11: // Diet Type
            return dietType != nil
        case 12: // What to Accomplish (multi-select)
            return !selectedGoalsToAccomplish.isEmpty
        // Referral code page removed (was case 15)
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
        print("   Raw arrays in goals object:")
        print("   - blockersRaw: \(goals.blockersRaw ?? [])")
        print("   - dietTypeRaw: \(goals.dietTypeRaw ?? "nil")")
        print("   - goalsToAccomplishRaw: \(goals.goalsToAccomplishRaw ?? [])")

        // Calculate nutrition goals
        let age = HealthCalculator.calculateAge(birthDate: birthDate)
        let macros = HealthCalculator.calculateDailyGoals(
            gender: gender,
            weightKg: weight,
            heightCm: height,
            age: age,
            activityLevel: activityLevel,
            weightGoal: weightGoal
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
}
