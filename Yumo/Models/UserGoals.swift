// Models/UserGoals.swift

import Foundation
import SwiftData

// MARK: - Enums for Health Data
// We define them here so the model file is self-contained.
// They must be Codable to be used by the @State variables.

enum Gender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case preferNotToSay = "Prefer Not to Say"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case lowActivity = "0-2 workouts a week"
    case moderateActivity = "3-5 workouts a week"
    case highActivity = "6+ workouts a week"

    var multiplier: Double {
        switch self {
        case .lowActivity: 1.375
        case .moderateActivity: 1.55
        case .highActivity: 1.725
        }
    }
}

enum GoalType: String, Codable, CaseIterable {
    case lose = "Lose Weight"
    case maintain = "Maintain Weight"
    case gain = "Gain Muscle"

    var calorieAdjustment: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 300
        }
    }
}

enum Blocker: String, Codable, CaseIterable {
    case lackOfConsistency = "Lack of consistency"
    case unhealthyEatingHabits = "Unhealthy eating habits"
    case lackOfSupport = "Lack of support"
    case busySchedule = "Busy schedule"
    case lackOfMealInspo = "Lack of meal inspo"
}

enum DietType: String, Codable, CaseIterable {
    case regular = "Regular"
    case pescatarian = "Pescatarian"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
}

enum GoalToAccomplish: String, Codable, CaseIterable {
    case eatHealthier = "Eat healthier"
    case boostEnergy = "Boost energy"
    case stayMotivated = "Stay motivated and consistent"
    case feelBetter = "Feel better about myself"
}

enum UnitSystem: String, Codable, CaseIterable {
    case metric = "Metric"
    case imperial = "Imperial"
    var displayName: String {
        return self.rawValue
    }
    
    // Weight units
    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }
    
    // Height units
    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}


enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case k5 = "5K"
    case k10 = "10K"
    case half = "Half Marathon"
    case full = "Marathon"

    var id: String { rawValue }

    /// Short display label ("5K", "Half", etc.)
    var shortLabel: String {
        switch self {
        case .k5: return "5K"
        case .k10: return "10K"
        case .half: return "Half"
        case .full: return "Full"
        }
    }

    /// Exact race distance in km.
    var km: Double {
        switch self {
        case .k5: return 5.0
        case .k10: return 10.0
        case .half: return 21.0975
        case .full: return 42.195
        }
    }

    /// Peak weekly training volume (km) a recreational runner aims for.
    var peakWeeklyKm: Double {
        switch self {
        case .k5: return 32
        case .k10: return 48
        case .half: return 64
        case .full: return 80
        }
    }

    /// Peak long run distance (km) 2-3 weeks out from race day.
    var peakLongRunKm: Double {
        switch self {
        case .k5: return 8
        case .k10: return 14
        case .half: return 21
        case .full: return 32
        }
    }
}

enum EnergyUnit: String, Codable, CaseIterable {
    case calories = "Calories (kcal)"
    case kilojoules = "Kilojoules (kJ)"
    
    var unitLabel: String {
        switch self {
        case .calories: return "kcal"
        case .kilojoules: return "kJ"
        }
    }
}

// MARK: - UserGoals Model

@Model
final class UserGoals {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var name: String = "User"  // User's first name

    // --- User Profile Data ---
    var birthDate: Date
    var weight: Double      // Stored in kg
    var height: Double      // Stored in cm
    
    // ⭐️ FIX: Store the raw String values instead of using .transformable
    var genderRaw: String
    var activityLevelRaw: String
    var weightGoalRaw: String
    var appearanceModeRaw: String = "System"
    var unitSystemRaw: String = "Metric"  // "Metric" or "Imperial"
    var energyUnitRaw: String = EnergyUnit.calories.rawValue // Default to Calories

    var targetWeight: Double  // Stored in kg
    var weeklyWeightChangeKg: Double = 0.5  // kg per week (0.25 to 1.0 typical for weight loss)

    // --- Running Goals ---
    // Stored in km. Displayed in mi when unitSystem is imperial.
    var weeklyRunningGoalKm: Double = 20

    // --- Race Training ---
    var raceDate: Date? = nil
    var raceDistanceRaw: String? = nil
    var raceName: String? = nil

    var raceDistance: RaceDistance? {
        get {
            guard let raw = raceDistanceRaw else { return nil }
            return RaceDistance(rawValue: raw)
        }
        set {
            raceDistanceRaw = newValue?.rawValue
        }
    }

    // --- Computed properties for easy access ---
    // This lets the rest of our app use the enum safely
    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .preferNotToSay }
        set { genderRaw = newValue.rawValue }
    }
    
    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderateActivity }
        set { activityLevelRaw = newValue.rawValue }
    }
    
    var weightGoal: GoalType {
        get { GoalType(rawValue: weightGoalRaw) ?? .maintain }
        set { weightGoalRaw = newValue.rawValue }
    }

    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        set { unitSystemRaw = newValue.rawValue }
    }
    
    var energyUnit: EnergyUnit {
        get { EnergyUnit(rawValue: energyUnitRaw) ?? .calories }
        set { energyUnitRaw = newValue.rawValue }
    }

    // --- Computed properties for new fields ---
    var blockers: [Blocker] {
        get {
            blockersRaw?.compactMap { Blocker(rawValue: $0) } ?? []
        }
        set {
            blockersRaw = newValue.map { $0.rawValue }
        }
    }

    var dietType: DietType? {
        get {
            guard let raw = dietTypeRaw else { return nil }
            return DietType(rawValue: raw)
        }
        set {
            dietTypeRaw = newValue?.rawValue
        }
    }

    var goalsToAccomplish: [GoalToAccomplish] {
        get {
            goalsToAccomplishRaw?.compactMap { GoalToAccomplish(rawValue: $0) } ?? []
        }
        set {
            goalsToAccomplishRaw = newValue.map { $0.rawValue }
        }
    }
    
    // --- Nutrition Goals ---
    var dailyCalories: Double {
        didSet { dailyCalories = InputValidation.capDailyCalories(dailyCalories) }
    }
    var dailyProtein: Double {
        didSet { dailyProtein = InputValidation.capDailyMacro(dailyProtein) }
    }
    var dailyCarbs: Double {
        didSet { dailyCarbs = InputValidation.capDailyMacro(dailyCarbs) }
    }
    var dailyFat: Double {
        didSet { dailyFat = InputValidation.capDailyMacro(dailyFat) }
    }

    // --- Water Goals ---
    var dailyWaterML: Double {
        didSet { dailyWaterML = InputValidation.capWater(dailyWaterML) }
    }
    var waterCupSizeML: Double {
        didSet { waterCupSizeML = InputValidation.capCupSize(waterCupSizeML) }
    }

    // --- New Onboarding Fields ---
    var blockersRaw: [String]?
    var dietTypeRaw: String?
    var goalsToAccomplishRaw: [String]?
    var referralCode: String?
    
    // --- Notification Preferences ---
    var mealRemindersEnabled: Bool = true
    var weeklyWeightReminderEnabled: Bool = true
    
    var healthKitEnabled: Bool
    var useManualGoals: Bool = false
    var includeBurntCalories: Bool = false

    init(
        id: UUID = UUID(),
        name: String = "User",
        birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date(),
        weight: Double = 70,
        height: Double = 170,
        gender: Gender = .preferNotToSay,
        activityLevel: ActivityLevel = .moderateActivity,
        targetWeight: Double = 70,
        weightGoal: GoalType = .maintain,
        appearanceMode: AppearanceMode = .system,
        dailyCalories: Double = 2000,
        dailyProtein: Double = 150,
        dailyCarbs: Double = 250,
        dailyFat: Double = 60,
        dailyWaterML: Double = 3000,
        waterCupSizeML: Double = 250,
        blockersRaw: [String]? = nil,
        dietTypeRaw: String? = nil,
        goalsToAccomplishRaw: [String]? = nil,
        referralCode: String? = nil,
        healthKitEnabled: Bool = false,
        energyUnit: EnergyUnit = .calories
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.weight = weight
        self.height = height

        // ⭐️ FIX: Store the rawValue
        self.genderRaw = gender.rawValue
        self.activityLevelRaw = activityLevel.rawValue
        self.targetWeight = targetWeight
        self.weightGoalRaw = weightGoal.rawValue
        self.appearanceModeRaw = appearanceMode.rawValue
        self.energyUnitRaw = energyUnit.rawValue

        self.dailyCalories = InputValidation.capDailyCalories(dailyCalories)
        self.dailyProtein = InputValidation.capDailyMacro(dailyProtein)
        self.dailyCarbs = InputValidation.capDailyMacro(dailyCarbs)
        self.dailyFat = InputValidation.capDailyMacro(dailyFat)
        self.dailyWaterML = InputValidation.capWater(dailyWaterML)
        self.waterCupSizeML = InputValidation.capCupSize(waterCupSizeML)

        // New fields
        self.blockersRaw = blockersRaw
        self.dietTypeRaw = dietTypeRaw
        self.goalsToAccomplishRaw = goalsToAccomplishRaw
        self.referralCode = referralCode
        self.healthKitEnabled = healthKitEnabled
    }
}
