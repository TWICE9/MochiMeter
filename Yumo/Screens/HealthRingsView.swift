// Screens/HealthRingsView.swift

import SwiftUI
import SwiftData
import HealthKit
import Auth
import os.signpost

private let activitySignposter = OSSignposter(subsystem: "com.yumo.perf", category: "HealthRingsView")

struct HealthRingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var tabRouter: TabRouter

    @Query(sort: \LoggedFood.timestamp, order: .reverse) private var allFoodLogs: [LoggedFood]
    // Water + fitness: scoped to today to avoid loading all-time history into memory.
    @Query(sort: \LoggedWater.timestamp, order: .reverse) private var allWaterLogs: [LoggedWater]
    @State private var loadedGoals: UserGoals?
    @Query private var allFitnessLogs: [LoggedFitness]
    @StateObject private var fitnessService = FitnessService.shared
    
    @StateObject private var healthManager = HealthKitManager.shared
    
    // HealthKit Data State
    @State private var healthKitSteps: Double = 0
    @State private var healthKitActiveCalories: Double = 0
    
    // Animation State
    @State private var animatedCalories: Double = 0
    @State private var animatedSteps: Double = 0
    @State private var animatedActive: Double = 0
    
    // UI State
    @State private var showManualEntry = false
    @State private var showCoach = false // Health Coach State

    @State private var selectedSuggestion: SmartFoodSuggestion? // For Detail View Sheet
    @State private var showReadinessInfo = false // Info Sheet State
    @State private var selectedRunForDetail: LoggedRun? = nil
    @State private var selectedSessionForDetail: PlannedSession? = nil
    @State private var showStrainDetail = false // Strain Detail Sheet State
    @State private var showPaceCalculator = false // Pace Calculator Sheet State
    @State private var showRunHistory = false      // Run History Sheet State
    @State private var showRouteHeatmap = false    // Route Heatmap Sheet State
    @State private var showWeeklyMileageEditor = false
    @State private var showWeeklyMileageHistory = false
    @State private var animateMileageRing = false
    @State private var activityDetailTab: ActivityDetailTab = .today
    @Namespace private var segmentNS

    // Pull-to-refresh state
    @State private var isRefreshing = false

    // Running onboarding banner + sheet
    @Query private var runningProfiles: [RunningProfile]
    @State private var showRunningOnboarding = false
    @AppStorage("running_onboarding_banner_dismissed") private var runningBannerDismissed = false

    // Running plan (Phase 3c)
    @Query(sort: \RunningPlan.createdAt, order: .reverse) private var allRunningPlans: [RunningPlan]
    @State private var isRegeneratingPlan = false
    @State private var planGenerationError: String?
    private static let planGenKey = "yumo.planGenerationInProgress"
    /// Reactive view of the plan-gen progress flag. The onboarding flow
    /// writes this UserDefault directly (line `RunningOnboardingScreen.finish`),
    /// and the surrounding view needs to observe those writes so the
    /// "generating…" state surfaces even if the user swiped the onboarding
    /// sheet away mid-generation. @State + a one-shot init read missed
    /// that case — switching to @AppStorage so SwiftUI redraws on any
    /// write to the same key.
    @AppStorage("yumo.planGenerationInProgress") private var showPlanGenBanner: Bool = false
    /// Last error from a background plan-generation attempt. Non-empty means
    /// the in-progress card should flip into its error / retry state. Cleared
    /// on success or when the user dismisses the error from the card.
    @AppStorage("yumo.planGenerationLastError") private var planGenLastError: String = ""

    // Session completion sheet (Phase 4)
    @State private var sessionToComplete: PlannedSession? = nil

    // Weekly plan-adaptation check-in. Surfaces Sun-evening through Wed when
    // workout reminders are enabled and we haven't prompted in 5 days.
    // Decision lives in `WeeklyCheckinController.shouldShow`.
    @State private var showWeeklyCheckin = false
    @State private var isApplyingWeeklyCheckin = false

    // Paywall state for premium-gated running actions (regenerate, etc.).
    @State private var showRunningPaywall = false
    @State private var runningPaywallTrigger: String = "running_regenerate"

    // Rest-day / unplanned run logging
    @State private var showRestDayRunSheet = false
    @State private var pendingRestDayWorkout: WorkoutSummary? = nil
    /// When the type-picker dismisses with no HK workout attached, we store the just-typed
    /// session here and open SessionCompleteSheet for manual entry after the sheet closes.
    @State private var sessionPickedFromRestDaySheet: PlannedSession? = nil

    // Cached heavy computations — updated in updateCachedAnalysis()
    @State private var cachedSuggestions: [SmartFoodSuggestion] = []

    private let healthStore = HKHealthStore()

    // MARK: - Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var mutedTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(red: 150/255, green: 150/255, blue: 160/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 244/255, green: 245/255, blue: 247/255)
    }

    /// Shows the running onboarding banner when the current user hasn't
    /// completed running onboarding yet and hasn't dismissed the banner.
    private var shouldShowRunningBanner: Bool {
        if runningBannerDismissed { return false }
        let userId = authManager.currentUser?.id.uuidString.lowercased()
        let scoped = runningProfiles.first { $0.userId == userId }
            ?? runningProfiles.first { $0.userId == nil }
        return scoped?.hasCompletedOnboarding != true
    }

    /// The current user's active running plan, or nil if none exists.
    private var activeRunningPlan: RunningPlan? {
        let userId = authManager.currentUser?.id.uuidString.lowercased()
        return allRunningPlans.first { plan in
            plan.status == .active && (plan.userId == userId || plan.userId == nil)
        }
    }

    private var accentColor: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.darkPrimaryColor
            : themeManager.currentTheme.primaryColor
    }

    @ViewBuilder
    private var ambientBackground: some View {
        ZStack {
            backgroundColor

            // Light-mode-only ambient gradient. Dark mode keeps the flat
            // tonal-grey background to match the new palette.
            if colorScheme == .light {
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.35),
                        backgroundColor.opacity(0),
                        themeManager.currentTheme.complementaryColor.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 20)
            }
        }
        .ignoresSafeArea()
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white
    }
    
    // MARK: - Computed Properties

    private var goals: UserGoals { loadedGoals ?? UserGoals() }
    private var energyUnit: EnergyUnit { goals.energyUnit }
    private func convertEnergy(_ kcal: Double) -> Double {
        energyUnit == .kilojoules ? kcal * 4.184 : kcal
    }

    // ─── Cached derived values ──────────────────────────────────────────────
    // These properties are computed once and stored in @State, then refreshed
    // only when the underlying @Query collections change (via .onChange).
    // Previously each one re-scanned allFoodLogs / allWaterLogs on every
    // SwiftUI body evaluation (which can fire dozens of times per second).
    // ───────────────────────────────────────────────────────────────────────

    // Live computed — cheap single-pass, called only from cache-update paths.
    private var todayFoodLogs: [LoggedFood] {
        let start = Date().startOfDay
        let end   = Date().endOfDay
        return allFoodLogs.filter { $0.timestamp >= start && $0.timestamp <= end && $0.recipe == nil }
    }

    // Cached aggregates — read directly in the view body (no scan on diff).
    @State private var cachedTotalCalories: Double   = 0
    @State private var cachedTotalCarbs: Double      = 0
    @State private var cachedTotalProtein: Double    = 0
    @State private var cachedTotalFat: Double        = 0
    @State private var cachedFuelCarbs: Double       = 0
    @State private var cachedWaterToday: Double      = 0
    @State private var cachedSmartWaterGoal: Double  = 2000
    @State private var cachedManualFitness: LoggedFitness? = nil
    // Today's running-typed workouts only. Cached so we don't allocate a
    // fresh filtered array every body re-eval (this used to be passed
    // inline into RunningTodayView and re-filtered on every HK publish).
    @State private var cachedTodayRunningWorkouts: [WorkoutSummary] = []
    // performanceReadiness is cached so the body doesn't recompute it 5 times.
    @State private var cachedReadiness: (status: String, color: Color, message: String) =
        ("Good", .green, "")

    // Convenience aliases used throughout the body (kept for naming consistency).
    private var totalCaloriesToday: Double  { cachedTotalCalories }
    private var totalCarbs: Double          { cachedTotalCarbs }
    private var totalProtein: Double        { cachedTotalProtein }
    private var totalFat: Double            { cachedTotalFat }
    private var totalWaterToday: Double     { cachedWaterToday }
    private var smartWaterGoal: Double      { cachedSmartWaterGoal }
    private var manualFitnessToday: LoggedFitness? { cachedManualFitness }
    private var performanceReadiness: (status: String, color: Color, message: String) { cachedReadiness }
    private var fuelCarbs: Double           { cachedFuelCarbs }

    /// Recomputes all cached aggregates in one pass over today's food/water logs.
    /// Called from .onChange of food logs, water logs, and workouts.
    private func recomputeAll() {
        let todayLogs = todayFoodLogs          // single filter pass
        let cals    = todayLogs.reduce(0) { $0 + $1.totalCalories }
        let carbs   = todayLogs.reduce(0) { $0 + $1.totalCarbs }
        let protein = todayLogs.reduce(0) { $0 + $1.totalProtein }
        let fat     = todayLogs.reduce(0) { $0 + $1.totalFat }

        // Fuel carbs: rolling window so last night's dinner counts for AM runs.
        let hour = Calendar.current.component(.hour, from: Date())
        var fuelC = carbs
        if hour < 11 {
            let startOfToday = Date().startOfDay
            if let yesterdayEvening = Calendar.current.date(byAdding: .hour, value: -7, to: startOfToday) {
                let eveningCarbs = allFoodLogs
                    .filter { $0.timestamp >= yesterdayEvening && $0.timestamp < startOfToday && $0.recipe == nil }
                    .reduce(0) { $0 + $1.totalCarbs }
                fuelC = carbs + eveningCarbs * 0.6
            }
        }

        // Water
        let start = Date().startOfDay; let end = Date().endOfDay
        let water = allWaterLogs.filter { $0.timestamp >= start && $0.timestamp <= end }
                                .reduce(0) { $0 + $1.amountML }
        let baseWaterGoal = (loadedGoals?.dailyWaterML ?? 0) > 0 ? (loadedGoals?.dailyWaterML ?? 2000) : 2000
        let workoutBurn = healthKitWorkouts.reduce(0.0) {
            $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        let smartWater = baseWaterGoal + (workoutBurn / 400.0) * 500.0

        // Manual fitness (today)
        let startDay = Date().startOfDay
        let manualFitness = allFitnessLogs.first { Calendar.current.isDate($0.date, inSameDayAs: startDay) }

        // Readiness (computed once here, not 5 times in the body)
        let readiness = computeReadiness(todayCarbs: carbs, fuelCarbs: fuelC,
                                         manualFitness: manualFitness)

        cachedTotalCalories  = cals
        cachedTotalCarbs     = carbs
        cachedTotalProtein   = protein
        cachedTotalFat       = fat
        cachedFuelCarbs      = fuelC
        cachedWaterToday     = water
        cachedSmartWaterGoal = smartWater
        cachedManualFitness  = manualFitness
        cachedReadiness      = readiness
        cachedTodayRunningWorkouts = healthManager.todayWorkouts.filter { $0.activityType == .running }
    }

    /// Cheap update for tab switches: only the readiness tuple depends on
    /// `selectedActivity`, so reuse the already-cached carbs/fuel values.
    private func recomputeReadinessOnly() {
        cachedReadiness = computeReadiness(
            todayCarbs: cachedTotalCarbs,
            fuelCarbs: cachedFuelCarbs,
            manualFitness: cachedManualFitness
        )
    }

    // Extracted readiness logic (was `performanceReadiness` computed prop).
    private func computeReadiness(
        todayCarbs: Double,
        fuelCarbs: Double,
        manualFitness: LoggedFitness?
    ) -> (status: String, color: Color, message: String) {
        var totalWorkoutEnergy = healthKitWorkouts.reduce(0.0) {
            $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        if let manualCal = manualFitness?.caloriesBurned { totalWorkoutEnergy += manualCal }

        if totalWorkoutEnergy > 200 {
            if lastWorkoutHeartRate > 0 {
                let age = Calendar.current.dateComponents([.year], from: goals.birthDate, to: Date()).year ?? 25
                let maxHR = Double(220 - age)
                let pct = lastWorkoutHeartRate / maxHR
                if pct > 0.85 {
                    return ("High Strain", .red,
                            "Avg HR: \(Int(lastWorkoutHeartRate)) bpm. Intense session! Prioritize protein & sleep immediately.")
                } else if pct > 0.75 {
                    return ("Recovery Mode", .orange,
                            "Avg HR: \(Int(lastWorkoutHeartRate)) bpm. Use protein to repair muscle tissue.")
                } else {
                    return ("Aerobic Base", Color(red: 0.4, green: 0.8, blue: 0.6),
                            "Avg HR: \(Int(lastWorkoutHeartRate)) bpm (Zone 2). Great for endurance. Rehydrate well.")
                }
            }
            return ("Recovery Mode", .purple, "Great effort! Refuel with protein to repair muscle.")
        }

        switch selectedActivity {
        case .running:
            if fuelCarbs < 30  { return ("Needs Fuel", .red,    "Glycogen low. Eat a banana (25g) or toast before your run.") }
            if fuelCarbs < 60  { return ("Good",       .yellow,  "Okay for a 5k. For longer runs, aim for 60g+.") }
            return                        ("Prime",      .green,   "Carbs topped up! Ready for a high-performance run.")
        case .cycling:
            if fuelCarbs < 50  { return ("Needs Fuel", .red,    "Cycling burns glycogen fast. Load up on 50g+ carbs.") }
            if fuelCarbs < 100 { return ("Good",       .yellow,  "Sufficient for a flat ride. Hill climbs need more fuel.") }
            return                        ("Prime",      .green,   "Excellent fuel status. Ready for a long distance ride.")
        case .swimming:
            if fuelCarbs < 20  { return ("Needs Fuel", .red,    "Eat a small snack to prevent fatigue in the pool.") }
            if fuelCarbs < 50  { return ("Good",       .yellow,  "Good levels for a moderate swim.") }
            return                        ("Prime",      .green,   "Fully energized for laps.")
        }
    }

    // Manual fitness data — now driven by the cached value above.
    private var displaySteps: Double {
        if let manual = manualFitnessToday, let steps = manual.steps { return Double(steps) }
        return healthKitSteps
    }
    private var displayActiveCalories: Double {
        if let manual = manualFitnessToday, let cal = manual.caloriesBurned { return cal }
        return healthKitActiveCalories
    }

    // MARK: - Activity Types
    
    enum ActivityType: String, CaseIterable {
        case cycling = "Today"
        case running = "Running"
        case swimming = "Plan"

        var icon: String {
            switch self {
            case .cycling: return "house.fill"
            case .running: return "figure.run"
            case .swimming: return "list.bullet.clipboard.fill"
            }
        }

        // Custom color for each sport
        var color: Color {
            switch self {
            case .cycling: return .indigo
            case .running: return .blue
            case .swimming: return .cyan
            }
        }
    }

    enum ActivityDetailTab: String, CaseIterable, Identifiable {
        case today = "Today"
        case bests = "Personal Bests"
        var id: String { rawValue }
    }
    
    @State private var selectedActivity: ActivityType = HealthRingsView.persistedActivity
    @State private var slideInGeneration: Int = 0

    // In-memory so the selected activity survives switching between main tabs.
    // Not persisted to disk — resets on app relaunch.
    private static var persistedActivity: ActivityType = .cycling

    // MARK: - Macro & Performance Logic
    
    @State private var healthKitWorkouts: [HKWorkout] = []
    @State private var lastWorkoutHeartRate: Double = 0 // Added for Strain Analysis
    
    private func quickAddWater() {
        let entry = LoggedWater(timestamp: Date(), amountML: 250)
        if let userId = authManager.currentUser?.id.uuidString.lowercased() {
            entry.userId = userId
        }
        modelContext.insert(entry)
        Task {
            if let userId = entry.userId {
                await CloudSyncManager.shared.uploadWaterLogImmediately(entry, userId: userId)
            }
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)! // Added Heart Rate

        let typesToRead: Set<HKObjectType> = [stepType, activeEnergyType, workoutType, heartRateType]

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if success {
                fetchHealthData()
            }
        }
    }

    private func fetchHealthData() {
        fetchStepCount()
        fetchActiveCalories()
        fetchWorkouts() // Fetch workouts
    }

    private func fetchWorkouts() {
        let workoutType = HKObjectType.workoutType()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 50, sortDescriptors: nil) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else { return }
            
            DispatchQueue.main.async {
                self.healthKitWorkouts = workouts
                // Refresh readiness now that workout data has changed.
                self.recomputeAll()
                
                if let lastWorkout = workouts.last {
                    self.fetchHeartRate(for: lastWorkout)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHeartRate(for workout: HKWorkout) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Query statistics over the duration of the workout
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let options: HKStatisticsOptions = .discreteAverage
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: options) { _, result, error in
            guard let result = result, let averageQuantity = result.averageQuantity() else { return }
            
            let avgBPM = averageQuantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            
            DispatchQueue.main.async {
                self.lastWorkoutHeartRate = avgBPM
            }
        }
        
        healthStore.execute(query)
    }

    // MARK: - Smart Suggestions Logic

    // Only surface smart suggestions when the user actually has a gap to fill —
    // low pre-run fuel or post-workout recovery. Hide when readiness is "Good", "Prime", or "Aerobic Base".
    private var shouldShowSmartSuggestions: Bool {
        switch performanceReadiness.status {
        case "Needs Fuel", "Recovery Mode", "High Strain": return true
        default: return false
        }
    }

    struct SmartFoodSuggestion: Identifiable {
        let id = UUID()
        let name: String
        let carbs: Double
        let protein: Double
        let calories: Double
        let servingSize: String
        let icon: String // "bolt.fill" for Energy, "heart.fill" for Recovery
    }
    

    
    // Fallback/Default Suggestions when history is empty
    private var defaultSuggestions: [SmartFoodSuggestion] {
        let status = performanceReadiness.status
        
        if status == "Needs Fuel" || status == "Moderate" {
            return [
                SmartFoodSuggestion(name: "Banana", carbs: 27, protein: 1, calories: 105, servingSize: "1 medium", icon: "bolt.fill"),
                SmartFoodSuggestion(name: "Toast with Honey", carbs: 30, protein: 4, calories: 150, servingSize: "2 slices", icon: "bolt.fill"),
                SmartFoodSuggestion(name: "Oatmeal", carbs: 25, protein: 5, calories: 150, servingSize: "1 cup cooked", icon: "bolt.fill")
            ]
        } else if status == "Recovery Mode" {
             return [
                SmartFoodSuggestion(name: "Protein Shake", carbs: 5, protein: 25, calories: 120, servingSize: "1 scoop", icon: "heart.fill"),
                SmartFoodSuggestion(name: "Greek Yogurt", carbs: 8, protein: 15, calories: 100, servingSize: "1 cup", icon: "heart.fill"),
                SmartFoodSuggestion(name: "Chicken Breast", carbs: 0, protein: 30, calories: 165, servingSize: "100g", icon: "heart.fill")
            ]
        } else {
             return [
                SmartFoodSuggestion(name: "Apple", carbs: 25, protein: 0, calories: 95, servingSize: "1 medium", icon: "leaf.fill"),
                SmartFoodSuggestion(name: "Almonds", carbs: 6, protein: 6, calories: 160, servingSize: "1 oz", icon: "leaf.fill")
            ]
        }
    }
    
    private var smartSuggestions: [SmartFoodSuggestion] {
        let status = performanceReadiness.status
        let uniqueFoods = Dictionary(grouping: allFoodLogs.prefix(150), by: { $0.name })
            .compactMap { $0.value.first } // Get one representative for each unique name
        
        // Filter out obvious unhealthy items
        let junkKeywords = ["mcd", "burger", "pizza", "fries", "fried", "cake", "cookie", "donut", "ice cream", "candy", "soda", "coke", "pepsi", "kfc", "taco bell", "wendy", "popeye", "shake shack", "beer", "alcohol", "wine"]
        
        let cleanFoods = uniqueFoods.filter { food in
            let name = food.name.lowercased()
            // 1. Name check
            let isJunk = junkKeywords.contains { name.contains($0) }
            if isJunk { return false }
            
            // 2. Nutritional check (Limit sugar unless it's fruit/natural)
            // Allow fruit (high sugar but healthy) - maybe check name? For now, cap added sugar imply by name check or just loose sugar limit
            if food.sugarPerServing > 30 { return false }
            
            return true
        }
        
        var suggestions: [SmartFoodSuggestion] = []
        
        // 1. Try to find personalized suggestions from history
        if status == "Needs Fuel" || status == "Moderate" {
            // High Carb, Low Fat (Quick Energy)
            let energyFoods = cleanFoods.filter { $0.totalCarbs > 25 && $0.totalFat < 12 && $0.totalFiber < 6 }
            for food in energyFoods {
                suggestions.append(SmartFoodSuggestion(name: food.name, carbs: food.totalCarbs, protein: food.totalProtein, calories: food.totalCalories, servingSize: food.servingSizeDescription, icon: "bolt.fill"))
            }
        } else if status == "Recovery Mode" || status == "High Strain" {
            // High Protein, Moderate Fat (Muscle Repair)
            let recoveryFoods = cleanFoods.filter { $0.totalProtein > 18 && $0.totalFat < 20 }
            for food in recoveryFoods {
                suggestions.append(SmartFoodSuggestion(name: food.name, carbs: food.totalCarbs, protein: food.totalProtein, calories: food.totalCalories, servingSize: food.servingSizeDescription, icon: "heart.fill"))
            }
        } else {
            // Balanced / Snack
            let balancedFoods = cleanFoods.filter { $0.totalProtein > 8 && $0.totalCarbs > 15 && $0.totalCarbs < 50 && $0.totalFat < 15 }
            for food in balancedFoods {
                 suggestions.append(SmartFoodSuggestion(name: food.name, carbs: food.totalCarbs, protein: food.totalProtein, calories: food.totalCalories, servingSize: food.servingSizeDescription, icon: "leaf.fill"))
            }
        }
        
        // 2. If no history match, use defaults
        if suggestions.isEmpty {
            return defaultSuggestions
        }
        
        // Return top 5 distinct suggestions
        return Array(suggestions.prefix(5))
    }
    
    private func logSmartFood(_ suggestion: SmartFoodSuggestion) {
        let finalLog: LoggedFood
        
        // 1. Try to find the original log to copy ALL details (most accurate macros)
        if let sourceLog = allFoodLogs.first(where: { $0.name == suggestion.name }) {
             finalLog = LoggedFood(
                name: sourceLog.name,
                timestamp: Date(),
                servingSizeDescription: sourceLog.servingSizeDescription,
                servingAmount: sourceLog.servingAmount,
                caloriesPerServing: sourceLog.caloriesPerServing,
                proteinPerServing: sourceLog.proteinPerServing,
                carbsPerServing: sourceLog.carbsPerServing,
                fatPerServing: sourceLog.fatPerServing,
                fiberPerServing: sourceLog.fiberPerServing,
                sugarPerServing: sourceLog.sugarPerServing,
                saltPerServing: sourceLog.saltPerServing,
                potassiumPerServing: sourceLog.potassiumPerServing,
                barcode: sourceLog.barcode,
                brand: sourceLog.brand,
                isHalal: sourceLog.isHalal
             )
        } else {
            // 2. Fallback: Create new log from suggestion data (defaults)
            finalLog = LoggedFood(
                name: suggestion.name,
                timestamp: Date(),
                servingSizeDescription: suggestion.servingSize,
                servingAmount: 1.0, 
                caloriesPerServing: suggestion.calories,
                proteinPerServing: suggestion.protein,
                carbsPerServing: suggestion.carbs,
                fatPerServing: 0 // Default
            )
        }
        
        // 3. Assign User ID & Insert
        if let userId = authManager.currentUser?.id.uuidString.lowercased() {
             finalLog.userId = userId
        }
        
        modelContext.insert(finalLog)
        
        // 4. Trigger Sync
        Task {
             if let userId = finalLog.userId {
                 await CloudSyncManager.shared.uploadFoodLogImmediately(finalLog, userId: userId)
             }
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // Header + sport selector — shared between the pinned Today layout and the regular scroll
    private var activityPageHeader: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(secondaryTextColor)
                    Text(Date(), format: .dateTime.weekday().month().day())
                        .font(.headline)
                        .foregroundStyle(tertiaryTextColor)
                }
                Spacer()

                if let strain = healthManager.strainScore, strain > 0 {
                    Button { showStrainDetail = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.heart.fill").foregroundStyle(.orange)
                            Text("\(String(format: "%.1f", strain))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            Image(systemName: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ActivityType.allCases, id: \.self) { activity in
                        let isActive = selectedActivity == activity
                        Button {
                            selectedActivity = activity
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: activity.icon)
                                    .font(.subheadline)
                                    .symbolEffect(.bounce, value: isActive && selectedActivity == activity)
                                Text(activity.rawValue).font(.subheadline.weight(.medium))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .foregroundStyle(isActive ? .white : primaryTextColor)
                            .background {
                                ZStack {
                                    if !isActive {
                                        Capsule()
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(Capsule().stroke(tertiaryTextColor.opacity(0.3), lineWidth: 1))
                                    } else {
                                        Capsule()
                                            .fill(activity.color)
                                            .matchedGeometryEffect(id: "activeSegment", in: segmentNS)
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedActivity)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Scroll Content (extracted to avoid type-checker timeout in body)

    @ViewBuilder
    private var mainScrollContent: some View {
        activityPageHeader
            .slideIn(delay: 0)

        // ═══════════════════════════════════════════
        // TODAY TAB
        // ═══════════════════════════════════════════
        if selectedActivity == .cycling {
            if activeRunningPlan == nil && (showPlanGenBanner || !planGenLastError.isEmpty) {
                // Generation is in flight (or just failed) — e.g. the user
                // swiped the onboarding sheet down mid-gen. The card flips
                // between a loading state and an error/retry state based
                // on `planGenLastError` so the surface doesn't read as
                // "nothing's happening" and the user has somewhere to retry.
                PlanGeneratingCard()
                    .padding(.horizontal, 24)
                    .slideIn(delay: 0.02)

                if showPlanGenBanner && planGenLastError.isEmpty {
                    RunningTipsCard()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.04)
                }

                _buildWeeklyMileageCard()
                    .padding(.horizontal, 24)
                    .slideIn(delay: 0.06)

                runningReadinessCard
                    .slideIn(delay: 0.10)

            } else if activeRunningPlan == nil {
                _buildCreatePlanHeroCard()
                    .padding(.horizontal, 24)
                    .slideIn(delay: 0.02)

                _buildWeeklyMileageCard()
                    .padding(.horizontal, 24)
                    .slideIn(delay: 0.06)

                runningReadinessCard
                    .slideIn(delay: 0.10)

            } else {
                RunningTodayView(
                    plan: activeRunningPlan,
                    isImperial: loadedGoals?.unitSystem == .imperial,
                    onMarkComplete: { sessionToComplete = $0 },
                    onSwitchToTab: { _ in },
                    onRunSelected: { selectedRunForDetail = $0 },
                    onSessionTapped: { selectedSessionForDetail = $0 },
                    belowSessionContent: {
                        VStack(spacing: 24) {
                            ConditionalAdBanner(adUnitID: AdManager.activityBannerAdUnitID)
                            _buildWeeklyMileageCard()
                                .padding(.horizontal, 24)
                            // runningReadinessCard self-pads horizontally.
                            runningReadinessCard
                        }
                    },
                    embedded: true,
                    todayRunningWorkouts: cachedTodayRunningWorkouts,
                    onLogUnplannedRun: { workout in
                        pendingRestDayWorkout = workout
                        showRestDayRunSheet = true
                    },
                    onAutoLogSession: { session, workout in
                        let distKm = (workout.distanceMeters ?? 0) / 1000
                        let durMins = Int(workout.durationMinutes)
                        applySessionCompletion(
                            session,
                            distanceKm: distKm > 0.01 ? distKm : nil,
                            durationMinutes: durMins > 0 ? durMins : nil,
                            source: "healthkit"
                        )
                    }
                )
                // Force re-mount on theme switch. Without this, the
                // closure-captured `belowSessionContent` cards (Weekly
                // Mileage, Today Readiness) don't pick up colorScheme
                // changes — SwiftUI's view diffing through the closure
                // boundary skips the body re-evaluation needed to
                // refresh their text colors. `.id(colorScheme)` makes
                // SwiftUI swap the entire subtree with a fresh identity
                // when the theme flips.
                .id(colorScheme)
                // Inner cards stagger themselves via .slideIn modifiers in
                // todayContent — no outer slideIn so we don't double-delay.
            }
        }

        // ═══════════════════════════════════════════
        // RUNNING TAB
        // ═══════════════════════════════════════════
        if selectedActivity == .running {
            VStack(spacing: 16) {
                if shouldShowRunningBanner {
                    RunningOnboardingBanner(
                        onStart: { showRunningOnboarding = true },
                        onDismiss: {
                            withAnimation(.spring(duration: 0.3)) { runningBannerDismissed = true }
                        }
                    )
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            _buildActivityDetailSection()
                .slideIn(delay: 0.1)

            // Readiness card moved to the Today tab (under weekly mileage) so
            // the Running tab focuses on training data + tools.

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaceCalculator = true
            } label: {
                FrostedGlassContainer {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.15)).frame(width: 44, height: 44)
                            Image(systemName: "stopwatch.fill").foregroundStyle(Color.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pace Calculator")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            Text("Distance, pace, finish times & splits")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tertiaryTextColor)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 24)
            .slideIn(delay: 0.2)

            // Run History — moved off the Plan tab so the Plan tab stays
            // focused on the active plan, and historical browsing lives
            // alongside other tools (Pace Calculator).
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showRunHistory = true
            } label: {
                FrostedGlassContainer {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.15)).frame(width: 44, height: 44)
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Run History")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            Text("Browse every run you've logged")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tertiaryTextColor)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 24)
            .slideIn(delay: 0.22)

            RouteHeatmapCard {
                showRouteHeatmap = true
            }
            .padding(.horizontal, 24)
            .slideIn(delay: 0.23)

            if !cachedSuggestions.isEmpty && shouldShowSmartSuggestions {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Smart Suggestions")
                        .font(.title3).fontWeight(.bold)
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 24)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(cachedSuggestions) { suggestionCard($0) }
                        }
                        .padding(.horizontal, 24)
                    }
                    .sheet(item: $selectedSuggestion) { s in
                        SmartFoodDetailView(suggestion: s, onAdd: { logSmartFood(s) })
                    }
                }
                .slideIn(delay: 0.24)
            }

            if let gap = calculateDietGap() {
                FrostedGlassContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill").foregroundStyle(Color.orange)
                            Text("Today's Analysis").font(.headline).foregroundStyle(primaryTextColor)
                            Spacer()
                        }
                        (Text("Focus on: **\(gap.macro)**").font(.title3).foregroundStyle(primaryTextColor)
                         + Text("\nYou are lacking \(Int(gap.deficit))g. \(gap.suggestion)")
                            .font(.subheadline).foregroundStyle(secondaryTextColor))
                        VStack(spacing: 12) {
                            _buildMacroRow(name: "Protein", current: totalProtein, goal: goals.dailyProtein, color: .purple)
                            _buildMacroRow(name: "Carbs",   current: totalCarbs,   goal: goals.dailyCarbs,   color: .blue)
                            _buildMacroRow(name: "Fat",     current: totalFat,     goal: goals.dailyFat,     color: .orange)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
                .padding(.horizontal, 24)
                .slideIn(delay: 0.28)
            }
        }

        // ═══════════════════════════════════════════
        // PLAN TAB
        // ═══════════════════════════════════════════
        if selectedActivity == .swimming {
            RunningTodayView(
                plan: activeRunningPlan,
                isImperial: loadedGoals?.unitSystem == .imperial,
                onMarkComplete: { sessionToComplete = $0 },
                onSwitchToTab: { _ in },
                onRunSelected: { selectedRunForDetail = $0 },
                onSessionTapped: { selectedSessionForDetail = $0 },
                onClearPlan: { clearActivePlan() },
                planEmbedded: true,
                isGenerating: showPlanGenBanner && !isRegeneratingPlan
            )
            // `.equatable()` short-circuits the entire RunningTodayView
            // subtree when our meaningful inputs (plan id, isImperial,
            // isGenerating, etc.) are unchanged. Without this, every
            // HealthKit snapshot publish on the parent forced the whole
            // planContent VStack — all upper cards plus the calendar
            // wrapper — to re-evaluate body, which is the dominant lag
            // source on the Plan tab during background HK sync.
            // (Must come before `.id()` because `.equatable()` requires
            // the wrapped view to be `Equatable`, and `.id()` returns
            // erased `some View`.)
            .equatable()
            // Force re-mount on theme switch. `.equatable()` above
            // blocks `@Environment(\.colorScheme)` updates from
            // propagating into the subtree, so without this the Plan
            // tab keeps stale-mode text colors after a theme flip
            // until you navigate away and back.
            .id(colorScheme)
            // Inner cards stagger themselves via .slideIn modifiers in
            // planContent — no outer slideIn so we don't double-delay.
        }

        Spacer()
    }

    // Readiness + macro fuel gauges extracted for type-checker
    @ViewBuilder
    private var runningReadinessCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill").foregroundStyle(performanceReadiness.color)
                        Text("\(selectedActivity.rawValue) Readiness")
                            .font(.headline).foregroundStyle(primaryTextColor)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Button { showReadinessInfo = true } label: {
                        HStack(spacing: 6) {
                            Text(performanceReadiness.status)
                                .font(.subheadline.weight(.bold))
                                .contentTransition(.interpolate)
                            Image(systemName: "info.circle").font(.caption)
                        }
                        .foregroundStyle(performanceReadiness.color)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(performanceReadiness.color.opacity(0.15))
                        .clipShape(Capsule())
                        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: performanceReadiness.status)
                    }
                    .buttonStyle(PressScaleStyle())
                }
                // Fall back to the description-by-status if the cached
                // message is empty. This happens briefly on first mount
                // before `recomputeAll` runs, and apparently in some
                // edge cases the cache stays empty — so a fallback
                // means the user always sees something useful instead
                // of a blank gap.
                Text(performanceReadiness.message.isEmpty
                     ? getReadinessDescription(for: performanceReadiness.status)
                     : performanceReadiness.message)
                    .font(.subheadline).foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(tertiaryTextColor.opacity(0.3))
                macroFuelGauges.padding(.top, 4)
            }
            .padding(20)
        }
        // `.drawingGroup()` previously applied here for scroll perf, but
        // it captured the view's rasterized state at slideIn opacity 0
        // (so the on-appear animation never showed) and produced
        // unreadable text rendering for some users. Reverted: the
        // FrostedGlassContainer's existing `.compositingGroup()` covers
        // the scroll-perf benefit without those side effects.
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var macroFuelGauges: some View {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Carbs").font(.caption).foregroundStyle(tertiaryTextColor)
                ZStack {
                    Circle().stroke(tertiaryTextColor.opacity(0.2), lineWidth: 6).frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: min(totalCarbs / 200, 1.0))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 52, height: 52)
                        .animation(.spring(response: 0.8, dampingFraction: 0.72), value: totalCarbs)
                    Text("\(Int(totalCarbs))g").font(.caption.weight(.bold)).foregroundStyle(primaryTextColor)
                }
                .padding(4)
            }
            VStack(spacing: 8) {
                Text("Protein").font(.caption).foregroundStyle(tertiaryTextColor)
                ZStack {
                    Circle().stroke(tertiaryTextColor.opacity(0.2), lineWidth: 6).frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: min(totalProtein / 150, 1.0))
                        .stroke(Color.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 52, height: 52)
                        .animation(.spring(response: 0.8, dampingFraction: 0.72), value: totalProtein)
                    Text("\(Int(totalProtein))g").font(.caption.weight(.bold)).foregroundStyle(primaryTextColor)
                }
                .padding(4)
            }
            Button { quickAddWater() } label: {
                VStack(spacing: 8) {
                    Text("Hydration").font(.caption).foregroundStyle(tertiaryTextColor)
                    ZStack {
                        Circle().stroke(tertiaryTextColor.opacity(0.2), lineWidth: 6).frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: min(totalWaterToday / smartWaterGoal, 1.0))
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring, value: totalWaterToday)
                            .frame(width: 52, height: 52)
                        if totalWaterToday >= smartWaterGoal {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Color.cyan)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "plus").font(.caption.bold()).foregroundStyle(Color.cyan)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(4)
                }
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        // Signpost emit on every body re-eval. Frequency here is the
        // "upstream" cost — every tick is a cascade into mainScrollContent
        // and (when Plan tab is active) into RunningTodayView.
        activitySignposter.emitEvent("HealthRingsView.body", "activity=\(selectedActivity.rawValue)")
        return ZStack {
            ambientBackground

            // Single ScrollView — all widget cards inline, toggled by selectedActivity
            ScrollView {
                VStack(spacing: 24) {
                    mainScrollContent
                }
                .padding(.bottom, 80)
            }
            .environment(\.slideInGeneration, slideInGeneration)
            .scrollIndicators(.hidden)
            .refreshable {
                await performHealthKitRefresh(force: true)
            }
            
            // Health Coach FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showCoach = true }) {
                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Circle().fill(Color.blue))
                            .shadow(radius: 4, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showCoach) {
            HealthCoachView(initialContext: coachContext)
        }
        .sheet(isPresented: $showStrainDetail) {
            StrainActivityView()
        }
        .sheet(isPresented: $showPaceCalculator) {
            NavigationStack {
                PaceCalculatorView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showPaceCalculator = false }
                        }
                    }
            }
            .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showRunHistory) {
            RunHistoryView()
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showRouteHeatmap) {
            RouteHeatmapView()
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showWeeklyMileageEditor) {
            if let goals = loadedGoals {
                WeeklyMileageGoalEditor(goals: goals) { newGoalKm in
                    try? modelContext.save()
                    Task {
                        await healthManager.refreshWeeklyRunStats(goalKm: newGoalKm)
                    }
                }
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showWeeklyMileageHistory) {
            let canEditGoal = planWeeklyGoalKm == nil
            WeeklyMileageHistorySheet(
                isImperial: loadedGoals?.unitSystem == .imperial,
                onEditGoal: canEditGoal ? { showWeeklyMileageEditor = true } : nil
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRunningOnboarding) {
            RunningOnboardingScreen {
                showRunningOnboarding = false
                // Reset banner-dismissed so a re-edit in the future could re-surface
                // the prompt if we ever clear the profile. (Safe no-op otherwise.)
                runningBannerDismissed = false
            }
            .interactiveDismissDisabled(false)
        }
        .sheet(item: $selectedRunForDetail) { run in
            RunDetailView(run: run)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedSessionForDetail) { session in
            sessionDetailSheet(session)
        }
        .sheet(item: $sessionToComplete) { session in
            SessionCompleteSheet(
                session: session,
                isImperial: loadedGoals?.unitSystem == .imperial,
                onComplete: { distKm, durMins, source in
                    applySessionCompletion(session, distanceKm: distKm, durationMinutes: durMins, source: source)
                },
                onSkip: { markSessionSkipped(session) },
                onUnmark: { unmarkSession(session) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRestDayRunSheet, onDismiss: {
            // If the type was picked but no HK workout was attached, open SessionCompleteSheet
            // for manual metric entry (can't stack two sheets — must wait for this to close).
            if let session = sessionPickedFromRestDaySheet {
                sessionToComplete = session
                sessionPickedFromRestDaySheet = nil
            }
            pendingRestDayWorkout = nil
        }) {
            let workout = pendingRestDayWorkout
            RestDayRunSheet(
                pendingWorkout: workout,
                isImperial: loadedGoals?.unitSystem == .imperial,
                onPickType: { type in
                    convertTodaySessionAndLog(type: type, workout: workout)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isRegeneratingPlan) {
            PlanGeneratingView()
        }
        .alert("Plan generation hit a snag", isPresented: Binding(
            get: { planGenerationError != nil },
            set: { if !$0 { planGenerationError = nil } }
        )) {
            Button("OK") { planGenerationError = nil }
        } message: {
            Text(planGenerationError ?? "")
        }
        .sheet(isPresented: $showReadinessInfo) {
            let info = getReadinessDescription(for: performanceReadiness.status)
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 6)
                    .padding(.top, 12)
                
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(performanceReadiness.color)
                    .padding(.top, 20)
                
                Text(performanceReadiness.status)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(primaryTextColor)
                
                Text(info)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 40)
                    .lineSpacing(6)
                
                Spacer()
                
                Button {
                    showReadinessInfo = false
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue) // Or app accent
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualFitnessEntryView()
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showWeeklyCheckin) {
            WeeklyCheckinSheet(
                onChoose: { reason in
                    showWeeklyCheckin = false
                    triggerWeeklyCheckin(reason: reason)
                },
                onCancel: { showWeeklyCheckin = false }
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showRunningPaywall) {
            PaywallView(trigger: runningPaywallTrigger)
        }
        .task {
            let taskState = activitySignposter.beginInterval("body.task")
            defer { activitySignposter.endInterval("body.task", taskState) }

            // Light, always-needed work: goals + food analysis
            if loadedGoals == nil {
                let goalsState = activitySignposter.beginInterval("task.fetchUserGoals")
                loadedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
                activitySignposter.endInterval("task.fetchUserGoals", goalsState)
            }
            requestHealthKitPermission()

            let recomputeState = activitySignposter.beginInterval("task.recomputeAll")
            recomputeAll()          // populate caches before first render
            activitySignposter.endInterval("task.recomputeAll", recomputeState)

            updateAnimatedValues()
            updateCachedAnalysis()

            // Heavy HealthKit work: guarded by TTL inside HealthKitManager so they
            // return immediately if data is already fresh (e.g. after a tab switch).
            // On first launch the prefetch in YumoApp will have already warmed these.
            await performHealthKitRefresh(force: false)

            // Weekly check-in surfacing. Runs after the initial work so we
            // don't pop a sheet over a half-loaded screen on first frame.
            if WeeklyCheckinController.shouldShow(context: modelContext) {
                WeeklyCheckinController.markPrompted()
                showWeeklyCheckin = true
            }
        }
        .onChange(of: allFoodLogs) { _, _ in
            recomputeAll()
            updateAnimatedValues()
            updateCachedAnalysis()
        }
        .onChange(of: allWaterLogs) { _, _ in
            recomputeAll()          // update water gauge
        }
        .onChange(of: allFitnessLogs) { _, _ in
            recomputeAll()
            updateAnimatedValues()
        }
        .onChange(of: healthKitSteps) { _, _ in
            updateAnimatedValues()
        }
        .onChange(of: healthManager.todayWorkouts.count) { _, _ in
            cachedTodayRunningWorkouts = healthManager.todayWorkouts.filter { $0.activityType == .running }
        }
        .onChange(of: selectedActivity) { _, newActivity in
            Self.persistedActivity = newActivity
            // Only readiness depends on the selected activity — skip the full
            // food/water/workout aggregate pass to keep the tab switch snappy.
            recomputeReadinessOnly()
        }
        // Replay ring animations every time the user switches back to this tab.
        // With persistent rendering the view is never destroyed, so @State animation
        // values don't reset. This observer snaps them to 0 then springs back.
        .onChange(of: tabRouter.selectedTab) { _, newTab in
            onTabBecameActive(newTab)
        }
        .onChange(of: tabRouter.tabReTapTrigger) { _, _ in
            guard tabRouter.selectedTab == .health else { return }
            // Dismiss all open sheets so the tab returns to its default view.
            showManualEntry = false
            showCoach = false
            showReadinessInfo = false
            showStrainDetail = false
            showPaceCalculator = false
            showWeeklyMileageEditor = false
            showWeeklyMileageHistory = false
            showRunningOnboarding = false
            sessionToComplete = nil
            showRestDayRunSheet = false
        }
        .onChange(of: activeRunningPlan?.id) { _, newId in
            if newId != nil { clearPlanGenBanner() }
        }
    }
    
    // MARK: - Diet Analysis Logic
    
    struct DietAnalysisGap {
        let macro: String
        let deficit: Double
        let suggestion: String
    }
    
    // Coach Context Helper
    private var coachContext: CoachContext {
        CoachContext(
            currentCalories: totalCaloriesToday,
            goalCalories: goals.dailyCalories,
            currentProtein: totalProtein,
            goalProtein: goals.dailyProtein,
            currentCarbs: totalCarbs,
            goalCarbs: goals.dailyCarbs,
//            currentFat: totalFat, // Not in CoachContext yet, add later if needed
//            goalFat: goals.dailyFat,
            recentActivity: selectedActivity.rawValue.capitalized,
            readinessStatus: performanceReadiness.status
        )
    }

    @ViewBuilder
    private func sessionDetailSheet(_ session: PlannedSession) -> some View {
        let imperial = loadedGoals?.unitSystem == .imperial
        NavigationStack {
            SessionDetailView(
                session: session,
                isImperial: imperial,
                onMarkComplete: { sessionToComplete = $0 }
            )
        }
        .presentationDragIndicator(.visible)
    }

    private func onTabBecameActive(_ newTab: AppTab) {
        guard newTab == .health else { return }
        slideInGeneration += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            playRingAnimations()
            let goal = max(planWeeklyGoalKm ?? loadedGoals?.weeklyRunningGoalKm ?? 0.1, 0.1)
            let mileageProgress = healthManager.thisWeekRunKm / goal
            if mileageProgress >= 1.0 {
                animateMileageRing = true
            } else {
                animateMileageRing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    animateMileageRing = true
                }
            }
        }
    }

    struct WeeklyDayStat: Identifiable {
        let id = UUID()
        let date: Date
        let calories: Double
        let label: String
    }
    
    private func calculateDietGap() -> DietAnalysisGap? {
        // Goals - safety check for 0 to avoid division by zero
        let proteinGoal = max(goals.dailyProtein, 1)
        let carbsGoal = max(goals.dailyCarbs, 1)
        let fatGoal = max(goals.dailyFat, 1)
        
        let pPct = totalProtein / proteinGoal
        let cPct = totalCarbs / carbsGoal
        let fPct = totalFat / fatGoal
        
        // If everything is good (>80%), maybe no gap
        if pPct > 0.9 && cPct > 0.9 {
            return nil
        }
        
        // Find lowest
        if pPct < cPct && pPct < fPct {
            return DietAnalysisGap(macro: "Protein", deficit: proteinGoal - totalProtein, suggestion: "Try eating Greek Yogurt, Chicken, or Tofu.")
        } else if cPct < fPct {
            return DietAnalysisGap(macro: "Carbs", deficit: carbsGoal - totalCarbs, suggestion: "Add Rice, Oats, or Pasta to your next meal.")
        } else {
             return DietAnalysisGap(macro: "Fat", deficit: fatGoal - totalFat, suggestion: "Include Avocado, Nuts, or Olive Oil.")
        }
    }
    
    @ViewBuilder
    private func _buildMacroRow(name: String, current: Double, goal: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                Spacer()
                Text("\(Int(current)) / \(Int(goal))g")
                    .font(.caption.bold())
                    .foregroundStyle(primaryTextColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tertiaryTextColor.opacity(0.1))
                    
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * (current / max(goal, 1)), geo.size.width))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Helper Functions
    
    private func getReadinessDescription(for status: String) -> String {
        switch status {
        case "Aerobic Base":
            return "Your recent activity was mostly in Zone 2 (moderate intensity). This builds endurance and burns fat efficiently without high recovery demands."
        case "High Strain":
            return "Your recent activity was very intense (Zone 4/5). Your body is under significant stress and requires deep recovery (sleep & protein)."
        case "Recovery Mode":
            return "Your body is recovering from recent effort. Focus on rest and light activity to help muscles repair."
        case "Needs Fuel":
            return "Your energy intake is lower than your activity demands. Refuel with carbohydrates to perform at your best."
        case "Prime":
            return "You are well-rested and fueled. Your glycogen stores are full and you're ready for peak performance!"
        case "Good":
            return "Your readiness is solid. Proceed with your normal training schedule."
        default:
            return "Your readiness score is based on your recent activity intensity and nutritional intake."
        }
    }

    /// Replays the counter animations from 0 → current value.
    /// Call this both on initial load and whenever the user navigates back to the tab.
    private func updateAnimatedValues() {
        fetchHealthData()
        playRingAnimations()
    }

    /// Spring-animates ring counters to their current values.
    /// Snaps to 0 first so the animation is visible even on re-entry.
    private func playRingAnimations() {
        let targetCalories = totalCaloriesToday
        let targetSteps    = displaySteps
        let targetActive   = displayActiveCalories

        // Snap to zero so the animation always plays, then animate to real value.
        animatedCalories = 0
        animatedSteps    = 0
        animatedActive   = 0

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            animatedCalories = targetCalories
            animatedSteps    = targetSteps
            animatedActive   = targetActive
        }
    }

    /// Recompute expensive analysis properties only when food data changes.
    private func updateCachedAnalysis() {
        cachedSuggestions = smartSuggestions
    }

    /// Runs all HealthKit fetches. When `force` is false the TTL guards in
    /// HealthKitManager ensure expensive 730-day scans are skipped if fresh data
    /// already exists. When `force` is true (pull-to-refresh) every fetch runs.
    private func performHealthKitRefresh(force: Bool) async {
        let state = activitySignposter.beginInterval("performHealthKitRefresh", "force=\(force)")
        defer { activitySignposter.endInterval("performHealthKitRefresh", state) }

        try? await healthManager.requestAuthorization()
        // Only hit Supabase when there's no data or user explicitly refreshed.
        if force || fitnessService.runs.isEmpty {
            let fetchRunsState = activitySignposter.beginInterval("fitnessService.fetchRuns")
            await fitnessService.fetchRuns()
            activitySignposter.endInterval("fitnessService.fetchRuns", fetchRunsState)
        }
        let weeklyGoalKm = loadedGoals?.weeklyRunningGoalKm ?? 20
        async let strainTask: () = healthManager.fetchStrainData(forceRefresh: force)
        async let weeklyRunTask: () = healthManager.refreshWeeklyRunStats(
            goalKm: weeklyGoalKm,
            forceRefresh: force
        )
        async let personalBestsTask: () = healthManager.refreshPersonalBests(forceRefresh: force)
        _ = await (strainTask, weeklyRunTask, personalBestsTask)
    }

    // MARK: - HealthKit Functions



    private func fetchStepCount() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch step count: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let steps = sum.doubleValue(for: HKUnit.count())

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    self.healthKitSteps = steps
                    // We don't set display property directly here, it's computed
                }
            }
        }

        healthStore.execute(query)
    }

    private func fetchActiveCalories() {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch active calories: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let calories = sum.doubleValue(for: HKUnit.kilocalorie())

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    self.healthKitActiveCalories = calories
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Weekly Mileage Card

    /// Sum of target km for runs scheduled in the current plan week.
    /// Returns nil when there's no active plan or the current week has no run sessions.
    private var planWeeklyGoalKm: Double? {
        guard let plan = activeRunningPlan else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: plan.startDate), to: today
        ).day ?? 0
        let currentWeek = max(1, min(plan.totalWeeks, (days / 7) + 1))
        let total = plan.sessions
            .filter { $0.weekNumber == currentWeek && $0.sessionType.isRun }
            .compactMap(\.targetDistanceKm)
            .reduce(0, +)
        return total > 0 ? total : nil
    }

    @ViewBuilder
    private func suggestionCard(_ suggestion: SmartFoodSuggestion) -> some View {
        let isCarb = suggestion.icon == "bolt.fill"
        let chipColor: Color = isCarb ? .blue : .purple
        FrostedGlassContainer {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(chipColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: suggestion.icon)
                        .foregroundStyle(chipColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                    Text(isCarb ? "\(Int(suggestion.carbs))g Carbs" : "\(Int(suggestion.protein))g Protein")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }
                Spacer()
                Button { logSmartFood(suggestion) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("AppSecondaryAccent"))
                }
            }
            .padding(12)
            .frame(width: 220)
        }
        .onTapGesture { selectedSuggestion = suggestion }
    }

    @ViewBuilder
    private func _buildWeeklyMileageCard() -> some View {
        let isImperial = goals.unitSystem == .imperial
        let planDriven = planWeeklyGoalKm
        let goalKm = max(planDriven ?? goals.weeklyRunningGoalKm, 0.1)
        let currentKm = healthManager.thisWeekRunKm
        let progress = currentKm / goalKm
        let unitLabel = isImperial ? "mi" : "km"
        let currentDisplay = isImperial ? currentKm * 0.621371 : currentKm
        let goalDisplay = isImperial ? goalKm * 0.621371 : goalKm
        let remaining = max(goalDisplay - currentDisplay, 0)
        let streak = healthManager.weeklyRunStreak
        let goalReached = currentKm >= goalKm
        // When a running plan is driving the goal, the goal isn't user-editable
        // here — sessions live in the plan. So drop the tap target & chevron.
        let isInteractive = planDriven == nil

        let cardBody = FrostedGlassContainer {
                HStack(spacing: 18) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.15), lineWidth: 8)
                            .frame(width: 76, height: 76)

                        Circle()
                            .trim(from: 0, to: animateMileageRing ? CGFloat(min(progress, 1.0)) : 0)
                            .stroke(
                                LinearGradient(
                                    colors: goalReached
                                        ? [Color.yellow, Color.green, Color(red: 0.3, green: 0.9, blue: 0.5)]
                                        : [Color.green.opacity(0.7), Color.green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 76, height: 76)
                            .animation(.spring(response: 0.9, dampingFraction: 0.8), value: animateMileageRing)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: currentKm)

                        VStack(spacing: 0) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                            Image(systemName: "figure.run")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Weekly Mileage")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            if planDriven != nil {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                    Text("Plan")
                                        .font(.caption2.weight(.bold))
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.18)))
                            }
                            if streak >= 2 {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                    Text("\(streak)")
                                        .font(.caption2.weight(.bold))
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                            }
                        }

                        Text("\(currentDisplay, specifier: "%.1f") / \(goalDisplay, specifier: goalDisplay == floor(goalDisplay) ? "%.0f" : "%.1f") \(unitLabel)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primaryTextColor)

                        Text(goalReached
                             ? "Goal hit 🎉"
                             : "\(remaining, specifier: "%.1f") \(unitLabel) to go")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tertiaryTextColor)
                }
            }

        Group {
            // Tapping the card opens the 6-month history chart. The goal
            // editor is reachable from a button inside that sheet, but only
            // when the goal is user-editable (no active plan driving it).
            Button {
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
                showWeeklyMileageHistory = true
            } label: { cardBody }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isInteractive
                ? "Weekly mileage history. Tap to view chart and edit goal."
                : "Weekly mileage history. Tap to view chart."
            )
        }
        // `.drawingGroup()` previously applied here for scroll perf,
        // but it broke the slideIn opacity animation (texture cached
        // at opacity 0) and produced unreadable text for some users.
        // Reverted — see matching comment on `runningReadinessCard`.
        .task {
            // Skip the empty→fill bump when the ring is already at the goal —
            // toggling animateMileageRing through `false` makes a full ring
            // visibly snap back to 0 before springing up.
            if progress >= 1.0 {
                animateMileageRing = true
            } else {
                animateMileageRing = false
                try? await Task.sleep(for: .milliseconds(80))
                animateMileageRing = true
            }
        }
    }

    // MARK: - Activity Detail Section (tabbed: Today / Personal Bests)

    @ViewBuilder
    private func _buildActivityDetailSection() -> some View {
        // PBs tab only appears for running users who have PBs to show.
        let showBestsTab = selectedActivity == .running && !healthManager.personalBests.isEmpty
        let activeTab: ActivityDetailTab = showBestsTab ? activityDetailTab : .today

        VStack(alignment: .leading, spacing: 12) {
            if showBestsTab {
                HStack(spacing: 8) {
                    ForEach(ActivityDetailTab.allCases) { tab in
                        let selected = activeTab == tab
                        Button {
                            let h = UIImpactFeedbackGenerator(style: .light)
                            h.impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                activityDetailTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab == .today ? "figure.run.circle.fill" : "medal.fill")
                                    .font(.caption)
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(selected ? primaryTextColor : secondaryTextColor)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule().fill(selected ? Color.white.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selected ? Color.clear : tertiaryTextColor.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
            } else {
                Text("Today's Activity")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 24)
            }

            switch activeTab {
            case .today:
                _buildTodayActivityContent()
            case .bests:
                _buildPersonalBestsContent()
            }
        }
    }

    @ViewBuilder
    private func _buildTodayActivityContent() -> some View {
        if !healthManager.todayWorkouts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(healthManager.todayWorkouts) { workout in
                        Button {
                            let haptic = UIImpactFeedbackGenerator(style: .light)
                            haptic.impactOccurred()
                            if workout.icon == "figure.run" || workout.typeName.localizedCaseInsensitiveContains("run") {
                                if let todayRun = fitnessService.runs.first(where: { Calendar.current.isDateInToday($0.runDate) }) {
                                    selectedRunForDetail = todayRun
                                } else {
                                    // Generate a synthetic LoggedRun straight from Apple Health data
                                    let distKm = (workout.distanceMeters ?? 0) / 1000.0
                                    
                                    var calculatedPace: String? = nil
                                    if distKm > 0 {
                                        let totalSeconds = workout.durationMinutes * 60
                                        let paceSeconds = totalSeconds / distKm
                                        let mins = Int(paceSeconds) / 60
                                        let secs = Int(paceSeconds) % 60
                                        calculatedPace = String(format: "%d:%02d", mins, secs)
                                    }
                                    
                                    selectedRunForDetail = LoggedRun(
                                        id: workout.id,
                                        runDate: workout.date,
                                        distanceKm: distKm,
                                        durationMinutes: workout.durationMinutes,
                                        calories: workout.caloriesBurned > 0 ? workout.caloriesBurned : nil,
                                        avgPace: calculatedPace,
                                        avgHeartRate: workout.avgHeartRate,
                                        elevationGain: workout.elevationAscendedMeters != nil ? Int(workout.elevationAscendedMeters!) : nil,
                                        feedback: "This is a raw session synced directly from Apple Health.\n\nLog your sessions natively through Yumo to receive personalized AI coach feedback and training adjustments!"
                                    )
                                }
                            }
                        } label: {
                            FrostedGlassContainer {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(workout.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: workout.icon)
                                            .foregroundStyle(workout.color)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(workout.typeName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(primaryTextColor)

                                        Text("\(Int(workout.caloriesBurned)) kcal • \(workout.formattedDuration)")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .frame(width: 200)
                            }
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.subheadline)
                    .foregroundStyle(tertiaryTextColor.opacity(0.8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("No activity yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(secondaryTextColor)
                    Text("Get moving to see data here")
                        .font(.caption)
                        .foregroundStyle(tertiaryTextColor)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        tertiaryTextColor.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func _buildPersonalBestsContent() -> some View {
        let bests = healthManager.personalBests
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(bests) { pb in
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text(pb.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(secondaryTextColor)
                            }

                            Text(pb.formattedTime)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(pb.formattedPace)
                                .font(.caption2)
                                .foregroundStyle(tertiaryTextColor)

                            Text(pb.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(tertiaryTextColor)
                        }
                        .padding(12)
                        .frame(width: 130, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Running Plan Actions (Phase 4)

    /// Converts today's planned session (typically `.rest`) to the chosen run type and
    /// logs it. With an HK workout attached, marks completion immediately. Without one,
    /// stores the session so SessionCompleteSheet opens for manual entry on dismiss.
    /// When no plan/session exists for today, falls back to saving a standalone `LoggedRun`.
    private func convertTodaySessionAndLog(type: RunningSessionType, workout: WorkoutSummary?) {
        let todaySession = activeRunningPlan?.sessions.first { Calendar.current.isDateInToday($0.scheduledDate) }
        guard let session = todaySession else {
            if let w = workout {
                let distKm = (w.distanceMeters ?? 0) / 1000
                let durMin = w.durationMinutes
                let spk: Int? = distKm > 0.01 && durMin > 0 ? Int((durMin * 60) / distKm) : nil
                let paceStr = spk.map { String(format: "%d:%02d /km", $0 / 60, $0 % 60) }
                Task {
                    // Build the analytics blob from HealthKit before saving so
                    // route + chart series travel with the run. Skips the blob
                    // gracefully if HK has nothing useful for this run.
                    let probeRun = LoggedRun(
                        runDate: w.date,
                        distanceKm: distKm,
                        durationMinutes: durMin,
                        calories: w.caloriesBurned > 0 ? w.caloriesBurned : nil,
                        avgPace: paceStr,
                        avgHeartRate: w.avgHeartRate,
                        elevationGain: w.elevationAscendedMeters.map { Int($0) }
                    )
                    let blob = await HealthKitManager.shared.buildAnalyticsBlob(matching: probeRun)
                    try? await FitnessService.shared.saveRunRecord(
                        date: w.date,
                        distanceKm: distKm,
                        durationMinutes: durMin,
                        calories: w.caloriesBurned > 0 ? w.caloriesBurned : nil,
                        avgPace: paceStr,
                        avgHeartRate: w.avgHeartRate,
                        elevationGain: w.elevationAscendedMeters.map { Int($0) },
                        feedback: "\(type.displayLabel) run · synced from \(w.sourceName)",
                        analyticsBlob: blob
                    )
                }
            }
            return
        }

        let now = Date()
        session.sessionType = type
        // Clear plan-time prescription that no longer applies after the type change.
        session.targetDistanceKm = nil
        session.targetDurationMinutes = nil
        session.targetPaceSecondsPerKm = nil
        session.sessionDescription = "Logged from a rest day."
        session.notes = nil
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()

        if let w = workout {
            let distKm = (w.distanceMeters ?? 0) / 1000
            let durMins = Int(w.durationMinutes)
            applySessionCompletion(
                session,
                distanceKm: distKm > 0.01 ? distKm : nil,
                durationMinutes: durMins > 0 ? durMins : nil,
                source: "healthkit"
            )
        } else {
            // Open SessionCompleteSheet for manual metric entry once this sheet dismisses.
            sessionPickedFromRestDaySheet = session
            Task.detached(priority: .background) {
                await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
            }
        }
    }

    private func applySessionCompletion(_ session: PlannedSession, distanceKm: Double?, durationMinutes: Int?, source: String) {
        let now = Date()
        session.completedAt = now
        session.completedDistanceKm = distanceKm
        session.completedDurationMinutes = durationMinutes
        session.completedSource = source
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func markSessionSkipped(_ session: PlannedSession) {
        let now = Date()
        session.skipped = true
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func unmarkSession(_ session: PlannedSession) {
        let now = Date()
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    /// Sends the weekly check-in choice to the adapt-running-plan edge function.
    /// `weeklyJustRight` returns no changes server-side so nothing happens UI-side
    /// beyond an audit log row — the banner only surfaces when sessions changed.
    private func triggerWeeklyCheckin(reason: AdaptationReason) {
        guard !isApplyingWeeklyCheckin else { return }
        isApplyingWeeklyCheckin = true
        Task { @MainActor in
            defer { isApplyingWeeklyCheckin = false }
            do {
                _ = try await RunningPlanService.shared.adaptPlan(
                    reason: reason,
                    context: modelContext
                )
                // Refresh reminders so any session whose target distance/pace
                // changed picks up the new body. weeklyJustRight returns no
                // changes so this is essentially a no-op in that case.
                await RunningWorkoutReminderScheduler.refresh(context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                // Errors are swallowed — the weekly check-in is a soft prompt;
                // we don't want to alert on every server hiccup.
                print("ℹ️ Weekly check-in adapt failed: \(error.localizedDescription)")
            }
        }
    }

    private func clearActivePlan() {
        guard let plan = activeRunningPlan else { return }
        let planId = plan.id

        // Delete from Supabase first — otherwise the next syncRunningPlans
        // resurrects the plan locally because cloud row still exists.
        // FK on planned_sessions cascades server-side.
        Task { @MainActor in
            let cloudOK = await CloudSyncManager.shared.deleteRunningPlanFromCloud(planId)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                if let plan = activeRunningPlan, plan.id == planId {
                    modelContext.delete(plan)
                    try? modelContext.save()
                }
            }
            // Plan is gone — refresh reminders so we don't keep firing
            // session-specific nudges that point to deleted PlannedSessions.
            await RunningWorkoutReminderScheduler.refresh(context: modelContext)
            // Land the user on the Today tab once the plan-removal animation
            // has had a moment to play. Without the small delay the tab swap
            // and the scale/fade fight each other.
            // Note: the tab enum's raw values are repurposed display strings —
            // `.cycling` is the "Today" tab, `.swimming` is the "Plan" tab.
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedActivity = .cycling
            }
            if !cloudOK {
                print("⚠️ Plan deleted locally but cloud delete failed — sync may resurrect it.")
            }
        }
    }

    /// Regenerate the active plan via the edge function. Force=true bypasses
    /// the 24h rate limit.
    /// Premium-gated: free users get one plan via onboarding; regenerating is
    /// a paid feature so we don't burn AI calls on indecisive free users.
    private func regenerateRunningPlan() {
        guard !isRegeneratingPlan else { return }
        if !StoreKitManager.shared.isPremium {
            runningPaywallTrigger = "running_regenerate"
            showRunningPaywall = true
            return
        }
        isRegeneratingPlan = true
        showPlanGenBanner = true
        UserDefaults.standard.set(true, forKey: Self.planGenKey)

        // Compute canonical days from the saved profile so the regen lands
        // on the same days the user picked during onboarding (no preview to
        // diverge from here, but we still want preview/plan parity if they
        // re-onboard later). Cross-training days act as a soft constraint
        // so the regen avoids the user's gym/yoga schedule.
        let runDays: [Int]?
        let longRunDayIndex: Int?
        if let profile = runningProfiles.first {
            let allDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
            let availableSet = Set(profile.availableDays)
            let availableSorted = allDays.filter { availableSet.contains($0) }
            let crossDays = Set(profile.crossTrainingSchedule.values.flatMap { $0 })
            let pickedDays = RunningPlanPreviewBuilder.chooseRunDays(
                from: availableSorted,
                target: max(1, profile.weeklyRunDaysTarget),
                longRunDay: profile.longRunDay,
                crossTrainingDays: crossDays
            )
            runDays = pickedDays.map { $0.dayIndex }
            longRunDayIndex = (profile.longRunDay.flatMap { pickedDays.contains($0) ? $0 : nil })?.dayIndex
        } else {
            runDays = nil
            longRunDayIndex = nil
        }

        Task {
            do {
                _ = try await RunningPlanService.shared.generatePlan(
                    force: true,
                    runDays: runDays,
                    longRunDayIndex: longRunDayIndex,
                    context: modelContext
                )
                await MainActor.run {
                    isRegeneratingPlan = false
                    clearPlanGenBanner()
                }
            } catch let error as RunningPlanGenerationError {
                await MainActor.run {
                    isRegeneratingPlan = false
                    clearPlanGenBanner()
                    planGenerationError = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isRegeneratingPlan = false
                    clearPlanGenBanner()
                    planGenerationError = error.localizedDescription
                }
            }
        }
    }

    private func clearPlanGenBanner() {
        showPlanGenBanner = false
        UserDefaults.standard.removeObject(forKey: Self.planGenKey)
    }

    // MARK: - Create Plan Hero Card

    private func _buildCreatePlanHeroCard() -> some View {
        CreatePlanHeroCard {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showRunningOnboarding = true
        }
    }




    // MARK: - Background Functions
    // Dynamic background handled by DynamicBackgroundView
}

// MARK: - Create Plan Hero Card

/// Stand-alone hero card shown when the user has no active running plan.
/// The rotating-glow border on the inner CTA is driven by TimelineView so
/// the rotation is purely time-derived — no state, no `repeatForever` snap
/// each cycle, no interaction with the parent's animation transactions.
private struct CreatePlanHeroCard: View {
    var onTap: () -> Void

    /// Seconds per full revolution of the orbital glow.
    private static let glowPeriod: Double = 3.5

    var body: some View {
        Button(action: onTap) {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.85), Color.indigo.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles — clipped to the rounded shape below.
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .offset(x: 110, y: -70)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 140, height: 140)
                    .offset(x: -90, y: 90)

                VStack(spacing: 24) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))

                    VStack(spacing: 10) {
                        Text("Ready to Run?")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Build a personalised AI training plan tailored to your fitness level and race goals.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Create My Plan")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                    .overlay(rotatingGlowBorder)
                }
                .padding(.vertical, 48)
                .padding(.horizontal, 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }

    /// AngularGradient stroke around the inner capsule's rim. The bright
    /// "wave" tapers off into transparent on either side, creating a single
    /// point of light that travels around the perimeter. Driven by
    /// TimelineView's per-frame date so the rotation is continuous — no
    /// `repeatForever` snap-back glitch and no interaction with the parent's
    /// animation transactions.
    private var rotatingGlowBorder: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let phase = elapsed.truncatingRemainder(dividingBy: Self.glowPeriod) / Self.glowPeriod
            Capsule()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.0),  location: 0.00),
                            .init(color: .white.opacity(0.85), location: 0.10),
                            .init(color: .white.opacity(0.0),  location: 0.25),
                            .init(color: .white.opacity(0.0),  location: 0.75),
                            .init(color: .white.opacity(0.5),  location: 0.90),
                            .init(color: .white.opacity(0.0),  location: 1.00),
                        ]),
                        center: .center,
                        angle: .degrees(360 * phase)
                    ),
                    lineWidth: 1.8
                )
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Plan Generating Card

/// Placeholder hero card shown on the Today tab while the user's first
/// plan is being generated, or surfacing an error if the background
/// generation failed. Surfaces when the onboarding sheet was swiped
/// away mid-generation (or otherwise dismissed before the plan synced).
private struct PlanGeneratingCard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("yumo.planGenerationInProgress") private var inProgress: Bool = false
    @AppStorage("yumo.planGenerationLastError") private var lastError: String = ""
    @AppStorage("yumo.planGenerationStartDate") private var startDateInterval: Double = 0

    @State private var pulse: Bool = false
    @State private var dotIndex: Int = 0
    /// Cancellable handle for the loading-dots ticker. Without this the
    /// ticker `Task` ran indefinitely after the generating card disappeared,
    /// firing a `@State` mutation every 400ms and forcing a full
    /// `HealthRingsView` body re-evaluation each tick — a major
    /// always-running cost for the entire Activity tab.
    @State private var dotsTask: Task<Void, Never>? = nil

    private var isError: Bool { !lastError.isEmpty }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: isError
                    ? [Color(red: 0.55, green: 0.20, blue: 0.20), Color(red: 0.40, green: 0.18, blue: 0.30)]
                    : [Color.purple.opacity(0.85), Color.indigo.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Same decorative circles as the hero card so the surface
            // doesn't visually flicker between the two states.
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: 110, y: -70)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .offset(x: -90, y: 90)

            if isError {
                errorContent
            } else {
                loadingContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isError)
    }

    // MARK: Loading state

    private var loadingContent: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulse ? 1.18 : 1.0)
                    .opacity(pulse ? 0.0 : 1.0)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 92, height: 92)
                Image(systemName: "figure.run")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .scaleEffect(pulse ? 1.05 : 1.0)
            }
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }

            VStack(spacing: 8) {
                Text("Building your plan…")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Your personalised AI plan is being created. It'll appear here automatically when ready.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            // Bouncing-dots loader. Each dot lifts and brightens in turn so
            // the eye reads the loop as a left-to-right wave instead of a
            // hard cut. The frame's bottom-aligned and slightly taller so
            // the lift doesn't get clipped or shift the surrounding layout.
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    let isActive = dotIndex == i
                    Circle()
                        .fill(Color.white.opacity(isActive ? 1.0 : 0.35))
                        .frame(width: 8, height: 8)
                        .offset(y: isActive ? -6 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: dotIndex)
                }
            }
            .frame(height: 16)
            .onAppear { startCycleDots() }
            .onDisappear { stopCycleDots() }
        }
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }

    // MARK: Error state

    private var errorContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }

            VStack(spacing: 8) {
                Text("Plan generation failed")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(lastError)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            HStack(spacing: 10) {
                Button(action: dismissError) {
                    Text("Dismiss")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        )
                }

                Button(action: retry) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.18, blue: 0.30))
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                }
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 22)
    }

    /// Starts the three-dot loading animation on the generating-plan card.
    /// Critically: stored on `dotsTask` so `stopCycleDots()` can cancel it
    /// when the card disappears. The previous version spawned an
    /// uncancellable `Task` that ran for the entire app session, mutating
    /// `dotIndex` every 400ms and forcing a body re-evaluation each tick.
    private func startCycleDots() {
        stopCycleDots()
        dotsTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if Task.isCancelled { return }
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }

    private func stopCycleDots() {
        dotsTask?.cancel()
        dotsTask = nil
    }

    private func dismissError() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        lastError = ""
        inProgress = false
    }

    private func retry() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let storedStart = startDateInterval > 0
            ? Date(timeIntervalSince1970: startDateInterval)
            : nil
        let storedRunDays = UserDefaults.standard
            .array(forKey: "yumo.planGenerationRunDays") as? [Int]
        let storedLongRun = UserDefaults.standard
            .object(forKey: "yumo.planGenerationLongRunDay") as? Int
        let context = modelContext

        lastError = ""
        inProgress = true

        Task {
            do {
                _ = try await RunningPlanService.shared.generatePlan(
                    force: true,
                    startDate: storedStart,
                    runDays: storedRunDays,
                    longRunDayIndex: storedLongRun,
                    context: context
                )
                await RunningWorkoutReminderScheduler.refresh(context: context)
                await MainActor.run {
                    inProgress = false
                    lastError = ""
                }
            } catch let error as RunningPlanGenerationError {
                await MainActor.run {
                    inProgress = false
                    if case .rateLimited = error {
                        // User already has a plan from elsewhere — silently dismiss.
                        lastError = ""
                    } else {
                        lastError = error.errorDescription ?? "Plan generation failed."
                    }
                }
            } catch {
                await MainActor.run {
                    inProgress = false
                    lastError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Running Tips Card

/// Small companion card that sits below `PlanGeneratingCard` while a plan
/// is generating. Cycles through a rotating set of running tips so the
/// wait feels productive instead of empty.
private struct RunningTipsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var index: Int = 0
    @State private var visible: Bool = true

    private let tips: [(icon: String, title: String, body: String)] = [
        ("tortoise.fill",     "Start slow",         "The easy run is your best friend. 80% of training should feel completely comfortable."),
        ("arrow.up.right",    "The 10% rule",       "Never increase your weekly mileage by more than 10%. Most injuries come from doing too much too soon."),
        ("heart.fill",        "Aerobic base first", "Building your aerobic engine takes months, but the speed and endurance gains last for years."),
        ("moon.zzz.fill",     "Sleep is training",  "Your body adapts during sleep. 7–9 hours is as important as the run itself."),
        ("drop.fill",         "Hydrate early",      "Start hydrating 24 hours before a long run. Thirst is already a sign you're behind."),
        ("flame.fill",        "Warm up properly",   "5 minutes of easy jogging and dynamic drills activates muscles and cuts injury risk."),
        ("figure.strengthtraining.traditional", "Add strength work", "Two strength sessions a week improves running economy and protects your joints."),
        ("arrow.down.right",  "Negative splits",    "Running the second half faster than the first is the mark of great pacing — practise it."),
        ("waveform.path",     "Cadence counts",     "Aim for 170–180 steps per minute. Higher cadence means less ground time and fewer injuries."),
        ("mountain.2.fill",   "Run hills",          "Hill repeats build explosive strength and speed without the harsh impact of track intervals."),
        ("brain.head.profile","Trust the process",  "Fitness gains often appear 4–6 weeks after consistent training. Patience is part of the plan."),
        ("cloud.rain.fill",   "Train in all weather","Race day won't wait for perfect conditions. Wind, rain and heat make you adaptable."),
        ("figure.run",        "Form matters",       "Lean slightly forward from the ankles, keep arms relaxed, and look ahead — not at the ground."),
        ("chart.line.uptrend.xyaxis", "Track your effort", "Heart rate and perceived effort tell you more about your fitness than pace alone."),
        ("bandage.fill",      "Listen to your body","There's a difference between discomfort and pain. Pain is a signal — not a challenge.")
    ]

    private var tip: (icon: String, title: String, body: String) { tips[index] }

    private var cardBackground: Color {
        colorScheme == .dark ? Color("AppCardBackground") : Color.white
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: tip.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Tip while you wait")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.5))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                }
                Text(tip.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color("AppTextPrimary"))
                Text(tip.body)
                    .font(.caption)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        // Generous min-height so the card stays a constant size as tips
        // cycle — short tips get extra breathing room rather than the
        // surrounding layout jumping every 6s. `.center` keeps the icon
        // and text vertically centred when the body wraps to fewer lines.
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackground)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05),
                        radius: 6, y: 3)
        )
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: visible)
        .onAppear { cycleTips() }
    }

    private func cycleTips() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                visible = false
                try? await Task.sleep(nanoseconds: 400_000_000)
                index = (index + 1) % tips.count
                visible = true
            }
        }
    }
}

// MARK: - Weekly Mileage Goal Editor

struct WeeklyMileageGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var goals: UserGoals
    var onSave: (Double) -> Void

    @State private var draftKm: Double = 20

    private var isImperial: Bool { goals.unitSystem == .imperial }
    private var unitLabel: String { isImperial ? "mi" : "km" }

    private var displayValue: Double {
        isImperial ? draftKm * 0.621371 : draftKm
    }

    private var minDisplay: Double { isImperial ? 3 : 5 }
    private var maxDisplay: Double { isImperial ? 75 : 120 }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Weekly Running Goal")
                    .font(.title2.weight(.bold))
                Text("Set a weekly distance target to stay on pace.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text("\(displayValue, specifier: displayValue == floor(displayValue) ? "%.0f" : "%.1f") \(unitLabel)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())

                Text("per week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { displayValue },
                    set: { newDisplay in
                        draftKm = isImperial ? newDisplay / 0.621371 : newDisplay
                    }
                ),
                in: minDisplay...maxDisplay,
                step: 1
            )
            .tint(.green)
            .padding(.horizontal, 24)

            HStack {
                Text("\(Int(minDisplay)) \(unitLabel)")
                Spacer()
                Text("\(Int(maxDisplay)) \(unitLabel)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)

            Button {
                goals.weeklyRunningGoalKm = draftKm
                onSave(draftKm)
                dismiss()
            } label: {
                Text("Save Goal")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .onAppear { draftKm = goals.weeklyRunningGoalKm }
    }
}

struct SmartFoodDetailView: View {
    let suggestion: HealthRingsView.SmartFoodSuggestion
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("AppPrimaryDark").ignoresSafeArea() // Use app background
            
            VStack(spacing: 24) {
                // Header / Icon
                ZStack {
                    Circle()
                        .fill(suggestion.icon == "bolt.fill" ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: suggestion.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(suggestion.icon == "bolt.fill" ? Color.blue : Color.purple)
                }
                .padding(.top, 20)
                
                // Content
                VStack(spacing: 8) {
                    Text(suggestion.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    
                    Text(suggestion.servingSize)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                // Macros Grid
                HStack(spacing: 40) {
                    MacroDetailItem(value: Int(suggestion.calories), label: "kcal", color: .orange)
                    MacroDetailItem(value: Int(suggestion.protein), label: "Protein", color: .purple)
                    MacroDetailItem(value: Int(suggestion.carbs), label: "Carbs", color: .blue)
                }
                .padding(.vertical, 10)
                
                Spacer()
                
                // Add Button
                Button {
                    onAdd()
                    dismiss()
                } label: {
                    Text("Add to Log")
                        .font(.headline)
                        .foregroundStyle(Color("AppPrimaryDark"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AppSecondaryAccent"))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .padding()
            .padding(.top, 60) // Prevent cut-off
            .background(
                // subtle themed glow
                RadialGradient(
                    colors: [
                        (suggestion.icon == "bolt.fill" ? Color.blue : Color.purple).opacity(0.15),
                        .clear
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 300
                )
            )
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }
}

struct MacroDetailItem: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Micro-animation helpers (HealthRingsView-scoped)

// Internal (was `private`) so child views in other files —
// `RunningTodayView`'s slideIn modifier — can observe the same generation
// counter and re-animate when HealthRingsView increments it. Reports has
// its own separately-named key, so no naming conflict.
struct SlideInGenerationKey: EnvironmentKey {
    static let defaultValue: Int = 0
}
extension EnvironmentValues {
    var slideInGeneration: Int {
        get { self[SlideInGenerationKey.self] }
        set { self[SlideInGenerationKey.self] = newValue }
    }
}

/// Slides content up from a slight offset with a fade. Replays both when the
/// view enters the hierarchy (sub-tab switch) and when `slideInGeneration` in
/// the environment increments (parent tab re-entry).
private struct SlideIn: ViewModifier {
    let delay: Double
    @Environment(\.slideInGeneration) private var generation
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    visible = true
                }
            }
            .onDisappear { visible = false }
            .onChange(of: generation) { _, _ in
                visible = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    visible = true
                }
            }
    }
}

/// Scales down to 0.97 on press and springs back — gives tappable cards
/// a tactile feel without adding any explicit gesture recognisers.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private extension View {
    func slideIn(delay: Double = 0) -> some View {
        modifier(SlideIn(delay: delay))
    }
}
