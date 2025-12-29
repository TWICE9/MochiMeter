// Screens/ReportsView.swift

import SwiftUI
import SwiftData
import Charts
import HealthKit
import Auth

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var healthManager = HealthKitManager.shared

    @State private var allFoodLogs: [LoggedFood] = []
    @State private var allWaterLogs: [LoggedWater] = []
    @Query private var allWeightLogs: [LoggedWeight]
    
    init(userId: String = "") {
        let predicate = #Predicate<LoggedWeight> { $0.userId == userId }
        _allWeightLogs = Query(filter: predicate, sort: \.timestamp, order: .reverse)
    }
    @State private var goals: UserGoals = UserGoals()
    @State private var selectedDate: Date = Date().startOfDay
    @State private var currentMonth: Date = Date()
    @State private var weeklySteps: [(date: Date, steps: Double)] = []
    @State private var weeklyWater: [(date: Date, amountML: Double)] = []
    @State private var selectedDateCaloriesEaten: Double = 0
    @State private var showLogWeightSheet: Bool = false
    @State private var showWeightHistory: Bool = false
    @State private var isCalendarExpanded: Bool = false

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    
    // Feedback States
    @State private var showConfetti: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var toastIcon: String = ""

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    // MARK: - Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(red: 140/255, green: 140/255, blue: 150/255)
    }

    private var chartGridColor: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.08)
    }

    private var chartAxisColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 80/255, green: 80/255, blue: 90/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 244/255, green: 245/255, blue: 247/255)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    // Theme-aware accent colors
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    private var secondaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkSecondaryColor : themeManager.currentTheme.secondaryColor
    }
    
    // Unit system helpers
    private var unitSystem: UnitSystem {
        goals.unitSystem
    }
    
    private var weightUnit: String {
        unitSystem.weightUnit
    }
    
    private func formatWeight(_ weightInKg: Double) -> String {
        let converted = unitSystem.formatWeight(weightInKg)
        return String(format: "%.1f", converted)
    }

    private var lastWeekSummaries: [DaySummary] {
        HistoryManager.generateLastWeekSummaries(from: allFoodLogs, goals: goals, endDate: selectedDate)
    }

    private var netCalories: Double {
        selectedDateCaloriesEaten - healthManager.todayBurntCalories
    }

    private var selectedDateLabel: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.title2).fontWeight(.medium).foregroundStyle(secondaryTextColor)
                        Text("\(selectedDateLabel)'s Overview")
                            .font(.largeTitle).fontWeight(.bold).foregroundStyle(primaryTextColor)
                            .contentTransition(.interpolate)
                            .animation(.easeInOut(duration: 0.25), value: selectedDateLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                    // Date Selector (compact 7-day or expanded month)
                    _buildDateSelector()
                        .padding(.horizontal, 24)

                    // Ad Banner
                    ConditionalAdBanner(adUnitID: AdManager.reportsBannerAdUnitID)
                        .padding(.vertical, 8)

                    // Today's Activity Summary
                    _buildTodayActivitySummary()
                        .padding(.horizontal, 24)

                    // Micronutrient Tracker
                    _buildMicronutrientCard()
                        .padding(.horizontal, 24)

                    // Net Calories Card
                    _buildNetCaloriesCard()
                        .padding(.horizontal, 24)

                    // Weight Progress Card
                    _buildWeightProgressCard()
                        .padding(.horizontal, 24)

                    // Weight Trend Chart
                    if !allWeightLogs.isEmpty {
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Weight Trend")
                                        .font(.headline).foregroundStyle(primaryTextColor)
                                    Spacer()
                                    Image(systemName: "scalemass.fill")
                                        .foregroundStyle(primaryAccent)
                                }

                                _buildWeightChart()
                                    .frame(height: 200)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // 7-Day Calorie Trend (Eaten)
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Calories Eaten")
                                .font(.headline).foregroundStyle(primaryTextColor)

                            _buildCalorieChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 7-Day Burnt Calories Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Calories Burnt")
                                    .font(.headline).foregroundStyle(primaryTextColor)
                                Spacer()
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                            }

                            _buildBurntCaloriesChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 7-Day Steps Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Steps")
                                    .font(.headline).foregroundStyle(primaryTextColor)
                                Spacer()
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(secondaryAccent)
                            }

                            _buildStepsChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 7-Day Water Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Water Intake")
                                    .font(.headline).foregroundStyle(primaryTextColor)
                                Spacer()
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.blue)
                            }

                            _buildWaterChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .ignoresSafeArea(edges: .top)
            // Toast Overlay
            if showToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: toastIcon)
                            .font(.title3)
                            .foregroundStyle(toastIcon.contains("heart") || toastIcon.contains("flame") ? .pink : .green)
                        Text(toastMessage)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 10)
                    .padding(.top, 50) 
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showToast = false }
                    }
                }
            }
            
            // Confetti Overlay
            if showConfetti {
                ConfettiView()
                    .zIndex(101)
                    .transition(.opacity)
            }
        }
        .onAppear {
            Task { await refreshData() }
            requestHealthKitPermissionIfNeeded()
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await healthManager.fetchActivity(for: newDate)
                await healthManager.fetchWeeklyBurntCalories(endDate: newDate)
                updateCaloriesForSelectedDate()
                fetchWeeklySteps(endDate: newDate)
                weeklyWater = generateWeeklyWater(endDate: newDate)
            }
        }
        .sheet(isPresented: $showLogWeightSheet) {
            LogWeightSheet(
                currentWeight: allWeightLogs.first?.weightKg ?? goals.weight,
                unitSystem: unitSystem,
                onSave: { weightKg in
                    Task { await saveWeightLog(weightKg: weightKg) }
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeightHistory) {
            WeightHistoryView(userId: authManager.currentUser?.id.uuidString.lowercased() ?? "")
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Today's Activity Summary
    @ViewBuilder
    private func _buildTodayActivitySummary() -> some View {
        HStack(spacing: 12) {
            // Steps
            ActivityStatCard(
                icon: "figure.walk",
                value: formatNumber(healthManager.todaySteps),
                label: "Steps",
                color: secondaryAccent
            )

            // Burnt Calories
            ActivityStatCard(
                icon: "flame.fill",
                value: formatNumber(convertEnergy(healthManager.todayBurntCalories)),
                label: "Burnt",
                color: .orange
            )

            // Active Minutes
            ActivityStatCard(
                icon: "timer",
                value: "\(Int(healthManager.todayActiveMinutes))",
                label: "Active min",
                color: .green
            )
        }
    }

    // MARK: - Micronutrient Tracker
    @ViewBuilder
    private func _buildMicronutrientCard() -> some View {
        let todaysLogs = allFoodLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
        
        // Calculate totals
        let fiber = todaysLogs.reduce(0) { $0 + $1.fiberPerServing * $1.servingAmount }
        let sugar = todaysLogs.reduce(0) { $0 + $1.sugarPerServing * $1.servingAmount }
        let salt = todaysLogs.reduce(0) { $0 + $1.saltPerServing * $1.servingAmount }
        let potassium = todaysLogs.reduce(0) { $0 + $1.potassiumPerServing * $1.servingAmount }
        
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Micronutrients")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    Spacer()
                    
                    if !todaysLogs.isEmpty {
                        Text("\(todaysLogs.count) items")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                
                VStack(spacing: 16) {
                    _buildMicroRow(name: "Fiber", value: fiber, unit: "g", color: .green, icon: "leaf.fill")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Sugar", value: sugar, unit: "g", color: .pink, icon: "cube.fill")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Salt", value: salt, unit: "g", color: .gray, icon: "sparkles")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Potassium", value: potassium, unit: "mg", color: .purple, icon: "bolt.fill")
                }
            }
        }
    }
    

    
    private func _buildMicroRow(name: String, value: Double, unit: String, color: Color, icon: String) -> some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(primaryTextColor)
            }
            
            Spacer()
            
            HStack(spacing: 2) {
                Text(formatNumber(value))
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    // MARK: - Net Calories Card
    @ViewBuilder
    private func _buildNetCaloriesCard() -> some View {
        let isDeficit = netCalories < 0

        FrostedGlassContainer {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Calories")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                        HStack(spacing: 4) {
                            Text("\(Int(convertEnergy(abs(netCalories))))")
                                .contentTransition(.numericText())
                            Text(isDeficit ? "deficit" : "surplus")
                        }
                        .font(.title2.bold())
                        .foregroundStyle(isDeficit ? .green : (netCalories > goals.dailyCalories ? .orange : primaryTextColor))
                        .animation(.easeInOut(duration: 0.3), value: netCalories)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 8)
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: min(selectedDateCaloriesEaten / max(goals.dailyCalories, 1), 1.0))
                            .stroke(primaryAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)
                            .animation(.easeInOut(duration: 0.4), value: selectedDateCaloriesEaten)

                        VStack(spacing: 0) {
                            Text("\(Int(convertEnergy(selectedDateCaloriesEaten)))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: selectedDateCaloriesEaten)
                            Text("eaten")
                                .font(.system(size: 9))
                                .foregroundStyle(tertiaryTextColor)
                        }
                    }
                }

                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                        Text("\(Int(convertEnergy(selectedDateCaloriesEaten)))")
                            .contentTransition(.numericText())
                        Text("eaten")
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .animation(.easeInOut(duration: 0.3), value: selectedDateCaloriesEaten)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                        Text("\(Int(convertEnergy(healthManager.todayBurntCalories)))")
                            .contentTransition(.numericText())
                        Text("burnt")
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .animation(.easeInOut(duration: 0.3), value: healthManager.todayBurntCalories)
                }
            }
        }
    }

    // MARK: - Data
    private func refreshData() async {
        allFoodLogs = await UserScopedQuery.fetchFoodLogs(context: modelContext)
        allWaterLogs = await UserScopedQuery.fetchWaterLogs(context: modelContext)
        if let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
            goals = fetchedGoals
        }
        
        // Update calories for initial load
        updateCaloriesForSelectedDate()
        
        // Fetch HealthKit data for selected date
        await healthManager.fetchActivity(for: selectedDate)
        await healthManager.fetchWeeklyBurntCalories(endDate: selectedDate)
        await healthManager.fetchLatestWeight()
        
        // Fetch Steps
        fetchWeeklySteps(endDate: selectedDate)
        
        weeklyWater = generateWeeklyWater(endDate: selectedDate)
    }

    private func saveWeightLog(weightKg: Double) async {
        // Capture old weight for feedback
        let oldWeight = allWeightLogs.first?.weightKg ?? goals.weight
        
        let userId = await UserSession.shared.getCurrentUserId()
        let newLog = LoggedWeight(weightKg: weightKg)
        newLog.userId = userId
        modelContext.insert(newLog)
        try? modelContext.save()

        // Trigger Feedback
        await MainActor.run {
            if weightKg < oldWeight {
                // Weight Loss / New Low
                showConfetti = true
                toastMessage = "New Low Recorded! 🎉"
                toastIcon = "arrow.down.heart.fill"
                
                // Hide confetti after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { showConfetti = false }
                }
            } else {
                // Weight gain or same (Neutral/Encouraging)
                toastMessage = "Weight Updated"
                toastIcon = "checkmark.circle.fill"
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showToast = true
            }
        }

        // Also save to HealthKit if authorized
        if healthManager.isAuthorized {
            try? await healthManager.saveWeight(weightKg)
        }

        // Update user's current weight in goals
        goals.weight = weightKg
        try? modelContext.save()

        // Sync to Supabase cloud if user is signed in
        if let userId = userId {
            await CloudSyncManager.shared.uploadWeightLogImmediately(newLog, userId: userId)
        }
    }

    private func updateCaloriesForSelectedDate() {
        selectedDateCaloriesEaten = allFoodLogs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) && $0.recipe == nil }
            .reduce(0) { $0 + $1.totalCalories }
    }

    // MARK: - HealthKit
    private func requestHealthKitPermissionIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if success {
                Task { @MainActor in
                    fetchWeeklySteps(endDate: selectedDate)
                    await healthManager.fetchActivity(for: selectedDate)
                    await healthManager.fetchWeeklyBurntCalories(endDate: selectedDate)
                    await healthManager.fetchLatestWeight()
                }
            } else if let error = error {
                print("HealthKit auth failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Water
    private func generateWeeklyWater(endDate: Date) -> [(Date, Double)] {
        guard calendar.date(byAdding: .day, value: -6, to: endDate.startOfDay) != nil else { return [] }

        let grouped = Dictionary(grouping: allWaterLogs) { log in
            calendar.startOfDay(for: log.timestamp)
        }

        var result: [(Date, Double)] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate.startOfDay) else { continue }
            let dayLogs = grouped[date] ?? []
            let total = dayLogs.reduce(0) { $0 + $1.amountML }
            result.append((date, total))
        }
        return result.reversed()
    }

    private func fetchWeeklySteps(endDate: Date) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate.startOfDay) else { return }

        let anchorDate = calendar.startOfDay(for: endDate)
        let daily = DateComponents(day: 1)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            anchorDate: anchorDate,
            intervalComponents: daily
        )

        query.initialResultsHandler = { _, results, error in
            guard let statsCollection = results else {
                print("Step stats failed: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            var data: [(Date, Double)] = []
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let count = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                data.append((stats.startDate, count))
            }

            DispatchQueue.main.async {
                self.weeklySteps = data
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helpers
    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return "\(Int(value))"
    }
    
    private func convertEnergy(_ kcal: Double) -> Double {
        goals.energyUnit == .kilojoules ? kcal * 4.184 : kcal
    }

    // MARK: - Streak Logic
    private func getStreakDates() -> Set<Date> {
        guard goals.dailyCalories > 0 else { return [] }
        let today = Date().startOfDay
        // Exclude recipe ingredients from streak calculation
        let standaloneLogs = allFoodLogs.filter { $0.recipe == nil }
        let grouped = Dictionary(grouping: standaloneLogs) { calendar.startOfDay(for: $0.timestamp) }

        var streakDates = Set<Date>()
        var checkDate = today

        if let todayLogs = grouped[today] {
            let todayCalories = todayLogs.reduce(0) { $0 + $1.totalCalories }
            if todayCalories >= goals.dailyCalories * 0.8 {
                streakDates.insert(today)
            } else {
                return streakDates
            }
        } else {
            return streakDates
        }

        while let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            if let logs = grouped[previousDay] {
                let calories = logs.reduce(0) { $0 + $1.totalCalories }
                if calories >= goals.dailyCalories * 0.8 {
                    streakDates.insert(previousDay)
                    checkDate = previousDay
                } else {
                    break
                }
            } else {
                break
            }
        }

        return streakDates
    }

    private func dateHasLogs(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return allFoodLogs.contains { 
            calendar.startOfDay(for: $0.timestamp) == startOfDay && $0.recipe == nil
        }
    }

    // MARK: - Date Selector
    @ViewBuilder
    private func _buildDateSelector() -> some View {
        let last7Days = getLast7Days()
        let streakDates = getStreakDates()

        FrostedGlassContainer(clipsContent: false) {
            VStack(spacing: 12) {
                // Compact 7-day picker (always visible)
                HStack(spacing: 8) {
                    ForEach(last7Days, id: \.self) { date in
                        _buildCompactDayCell(
                            date: date,
                            hasLogs: dateHasLogs(date),
                            isInStreak: streakDates.contains(date)
                        )
                    }
                }

                // Expand/Collapse button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCalendarExpanded.toggle()
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Text(isCalendarExpanded ? "Show Less" : "Show Full Month")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: isCalendarExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(primaryAccent)
                    .padding(.vertical, 8)
                }

                // Expanded month view
                if isCalendarExpanded {
                    _buildExpandedMonthView(streakDates: streakDates)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
        }
        .zIndex(isCalendarExpanded ? 1 : 0)
    }

    @ViewBuilder
    private func _buildCompactDayCell(date: Date, hasLogs: Bool, isInStreak: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)
        let weekdaySymbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]

        let cellBackground: Color = {
            if isSelected {
                return secondaryAccent
            } else if isInStreak {
                return Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.15)
            } else if hasLogs {
                return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
            }
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
        }()

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = date
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Text(weekdaySymbol.prefix(1))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : tertiaryTextColor)

                Text("\(dayNumber)")
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : primaryTextColor)

                // Indicator
                if isInStreak {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? .white : .orange)
                } else if hasLogs {
                    Circle()
                        .fill(isSelected ? .white : primaryAccent)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cellBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isToday && !isSelected ? secondaryAccent : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func _buildExpandedMonthView(streakDates: Set<Date>) -> some View {
        let daysInMonth = getDaysInMonth(for: currentMonth)

        VStack(spacing: 12) {
            Divider()
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

            // Month navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 36, height: 36)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }

                Spacer()

                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 36, height: 36)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.prefix(1))
                        .font(.caption.bold())
                        .foregroundStyle(tertiaryTextColor)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        _buildDayCell(date: date, hasLogs: dateHasLogs(date), isInStreak: streakDates.contains(date))
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    private func getLast7Days() -> [Date] {
        let today = Date().startOfDay
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    @ViewBuilder
    private func _buildDayCell(date: Date, hasLogs: Bool, isInStreak: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        let cellBackground: Color = {
            if isSelected {
                return secondaryAccent
            } else if isInStreak {
                return Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.15)
            } else if hasLogs {
                return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
            }
            return Color.clear
        }()

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = date
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cellBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isToday && !isSelected ? secondaryAccent : .clear, lineWidth: 2)
                    )

                VStack(spacing: 2) {
                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : primaryTextColor)

                    if isInStreak {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? .white : .orange)
                    } else if hasLogs {
                        Circle()
                            .fill(isSelected ? .white : primaryAccent)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }

    private func getDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let _ = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return days
    }

    // MARK: - Charts
    @ViewBuilder
    private func _buildBurntCaloriesChart() -> some View {
        Chart {
            ForEach(healthManager.weeklyBurntCalories, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Calories", convertEnergy(day.calories))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red.opacity(0.7)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(chartAxisColor)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel().foregroundStyle(chartAxisColor)
            }
        }
    }

    @ViewBuilder
    private func _buildStepsChart() -> some View {
        Chart {
            ForEach(weeklySteps, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(secondaryAccent)
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(chartAxisColor)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel().foregroundStyle(chartAxisColor)
            }
        }
    }

    @ViewBuilder
    private func _buildWaterChart() -> some View {
        let goalLineColor = colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.4)

        Chart {
            ForEach(weeklyWater, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Water (ml)", day.amountML)
                )
                .foregroundStyle(Color.blue.opacity(0.8))
                .cornerRadius(6)

                if goals.dailyWaterML > 0 {
                    RuleMark(y: .value("Goal", goals.dailyWaterML))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(goalLineColor)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(chartAxisColor)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel().foregroundStyle(chartAxisColor)
            }
        }
    }

    // MARK: - Weight Progress Card
    @ViewBuilder
    private func _buildWeightProgressCard() -> some View {
        let currentWeight = allWeightLogs.first?.weightKg ?? goals.weight
        let targetWeight = goals.targetWeight
        let startWeight = goals.weight  // Initial weight from onboarding
        let isLosingWeight = goals.weightGoal == .lose
        let isGainingWeight = goals.weightGoal == .gain

        // Calculate progress (0 to 1)
        let totalChange = abs(startWeight - targetWeight)
        let currentChange = abs(startWeight - currentWeight)
        let progress: Double = totalChange > 0 ? min(currentChange / totalChange, 1.0) : 0

        // Determine if on track
        let isOnTrack: Bool = {
            if isLosingWeight {
                return currentWeight <= startWeight && currentWeight >= targetWeight
            } else if isGainingWeight {
                return currentWeight >= startWeight && currentWeight <= targetWeight
            }
            return abs(currentWeight - targetWeight) < 2  // Within 2kg for maintenance
        }()

        let weightToGo = abs(currentWeight - targetWeight)
        let hasReachedGoal = weightToGo < 0.5

        FrostedGlassContainer {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight Progress")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)

                        HStack(spacing: 4) {
                            Text(formatWeight(currentWeight))
                                .font(.title.bold())
                                .foregroundStyle(primaryTextColor)
                                .contentTransition(.numericText())
                            Text(weightUnit)
                                .font(.title3)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }

                    Spacer()

                    Button {
                        showWeightHistory = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(secondaryTextColor)
                            .padding(8)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }

                    Button {
                        showLogWeightSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Log")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(primaryAccent)
                        .clipShape(Capsule())
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                .frame(height: 12)

                            // Progress
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    hasReachedGoal ? Color.green :
                                    (isOnTrack ? primaryAccent : Color.orange)
                                )
                                .frame(width: geo.size.width * progress, height: 12)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text("Start: \(formatWeight(startWeight)) \(weightUnit)")
                            .font(.caption)
                            .foregroundStyle(tertiaryTextColor)

                        Spacer()

                        Text("Goal: \(formatWeight(targetWeight)) \(weightUnit)")
                            .font(.caption)
                            .foregroundStyle(tertiaryTextColor)
                    }
                }

                Divider()
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

                // Status row
                HStack {
                    if hasReachedGoal {
                        Label("Goal reached!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: isLosingWeight ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(isOnTrack ? primaryAccent : .orange)
                            Text("\(formatWeight(weightToGo)) \(weightUnit) to go")
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                        }

                        Spacer()

                        if let lastLog = allWeightLogs.first {
                            Text(lastLog.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(tertiaryTextColor)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Weight Chart
    @ViewBuilder
    private func _buildWeightChart() -> some View {
        let sortedLogs = allWeightLogs.sorted { $0.timestamp < $1.timestamp }
        let targetWeight = goals.targetWeight

        let goalLineColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.35)
        let annotationTextColor = colorScheme == .dark ? Color.white.opacity(0.8) : primaryTextColor
        let annotationBgColor = colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.9)

        let areaGradient = Gradient(colors: [
            primaryAccent.opacity(0.4),
            primaryAccent.opacity(0.05)
        ])
        
        // Convert weights to display units
        let targetWeightDisplay = unitSystem.formatWeight(targetWeight)
        let weightsInDisplayUnit = sortedLogs.map { unitSystem.formatWeight($0.weightKg) }
        let minWeight = weightsInDisplayUnit.min() ?? 0

        Chart {
            // Target weight line
            RuleMark(y: .value("Goal", targetWeightDisplay))
                .lineStyle(.init(lineWidth: 1, dash: [6, 6]))
                .foregroundStyle(goalLineColor)
                .annotation(position: .topTrailing, alignment: .trailing) {
                    Label("Goal \(formatWeight(targetWeight))", systemImage: "flag.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(annotationTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(annotationBgColor)
                        .clipShape(Capsule())
                }

            ForEach(Array(sortedLogs.enumerated()), id: \.element.id) { index, log in
                let weightDisplay = weightsInDisplayUnit[index]
                
                AreaMark(
                    x: .value("Date", log.timestamp),
                    yStart: .value("Baseline", minWeight),
                    yEnd: .value("Weight", weightDisplay)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(gradient: areaGradient, startPoint: .top, endPoint: .bottom))

                LineMark(
                    x: .value("Date", log.timestamp),
                    y: .value("Weight", weightDisplay)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(primaryAccent)

                PointMark(
                    x: .value("Date", log.timestamp),
                    y: .value("Weight", weightDisplay)
                )
                .symbol(.circle)
                .symbolSize(60)
                .foregroundStyle(primaryAccent)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(chartAxisColor)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel().foregroundStyle(chartAxisColor)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    @ViewBuilder
    private func _buildCalorieChart() -> some View {
        let sortedData = lastWeekSummaries.sorted { $0.date < $1.date }
        let targetCalories = convertEnergy(Double(goals.dailyCalories))
        let areaGradient = Gradient(colors: [
            primaryAccent.opacity(0.55),
            primaryAccent.opacity(0.08)
        ])

        let goalLineColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.35)
        let annotationTextColor = colorScheme == .dark ? Color.white.opacity(0.8) : primaryTextColor
        let annotationBgColor = colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.9)
        let pointDefaultColor = colorScheme == .dark ? Color.white : primaryAccent
        let capsuleDefaultColor = colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.2)

        Chart {
            if targetCalories > 0 {
                RuleMark(y: .value("Goal", targetCalories))
                    .lineStyle(.init(lineWidth: 1, dash: [6, 6]))
                    .foregroundStyle(goalLineColor)
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Label("Goal \(Int(targetCalories))", systemImage: "flag.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(annotationTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(annotationBgColor)
                            .clipShape(Capsule())
                    }
            }

            ForEach(sortedData.indices, id: \.self) { index in
                let day = sortedData[index]

                AreaMark(
                    x: .value("Day", day.date),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Calories", convertEnergy(day.totalCalories))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(gradient: areaGradient, startPoint: .top, endPoint: .bottom))

                LineMark(
                    x: .value("Day", day.date),
                    y: .value("Calories", convertEnergy(day.totalCalories))
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(primaryAccent)

                PointMark(
                    x: .value("Day", day.date),
                    y: .value("Calories", convertEnergy(day.totalCalories))
                )
                .symbol(.circle)
                .symbolSize(day.metCalorieGoal ? 120 : 80)
                .foregroundStyle(day.metCalorieGoal ? Color.green : pointDefaultColor)
                .annotation(position: .top) {
                    VStack(spacing: 2) {
                        Text("\(Int(convertEnergy(day.totalCalories)))")
                            .font(.caption2.bold())
                            .foregroundStyle(primaryTextColor)
                        Capsule()
                            .fill(day.metCalorieGoal ? Color.green.opacity(0.6) : capsuleDefaultColor)
                            .frame(width: 1, height: 10)
                    }
                }

                if day.metCalorieGoal {
                    RectangleMark(
                        xStart: .value("Highlight Start", day.date.addingTimeInterval(-18_000)),
                        xEnd: .value("Highlight End", day.date.addingTimeInterval(18_000)),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Calories Highlight", convertEnergy(day.totalCalories))
                    )
                    .foregroundStyle(Color.green.opacity(0.08))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .foregroundStyle(chartAxisColor)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel()
                    .foregroundStyle(chartAxisColor)
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
                }
        }
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.5), value: sortedData.map { Int($0.totalCalories) })
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if colorScheme == .light {
                RadialGradient(
                    gradient: Gradient(colors: [
                        secondaryAccent.opacity(0.15),
                        .clear
                    ]),
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 450
                )
                .offset(offset1)
                .offset(x: -150, y: -150)
                .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        primaryAccent.opacity(0.12),
                        .clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
                .offset(offset2)
                .offset(x: 100, y: 150)
                .ignoresSafeArea()
            } else {
                // Dark Mode: Subtle white "spotlight" effects
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        .clear
                    ]),
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 500
                )
                .offset(offset1)
                .offset(x: -100, y: -100)
                .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.05),
                        .clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 500
                )
                .offset(offset2)
                .offset(x: 100, y: 100)
                .ignoresSafeArea()
            }
        }
        .blur(radius: 60)
        .onAppear { animateOrbs() }
    }

    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
        }
    }
}

// MARK: - Activity Stat Card
struct ActivityStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(textColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)

            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Log Weight Sheet
struct LogWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    let currentWeight: Double
    let unitSystem: UnitSystem
    let onSave: (Double) -> Void

    @State private var weightInput: String = ""
    @FocusState private var isInputFocused: Bool

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }
    
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    private var weightUnit: String {
        unitSystem.weightUnit
    }
    
    private func formatWeight(_ weightInKg: Double) -> String {
        let converted = unitSystem.formatWeight(weightInKg)
        return String(format: "%.1f", converted)
    }

    private var parsedWeight: Double? {
        Double(weightInput.replacingOccurrences(of: ",", with: "."))
    }
    
    private var parsedWeightInKg: Double? {
        guard let displayWeight = parsedWeight else { return nil }
        return unitSystem.convertWeightToMetric(displayWeight)
    }

    var isValidWeight: Bool {
        guard let weightKg = parsedWeightInKg else { return false }
        return weightKg >= InputValidation.minWeightKg && weightKg <= InputValidation.maxWeightKg
    }

    private func adjustWeight(by amount: Double) {
        let currentDisplay = parsedWeight ?? unitSystem.formatWeight(currentWeight)
        let newDisplayWeight = currentDisplay + amount
        
        // Convert to kg to validate
        let newWeightKg = unitSystem.convertWeightToMetric(newDisplayWeight)
        let validatedKg = max(InputValidation.minWeightKg, min(InputValidation.maxWeightKg, newWeightKg))
        
        // Convert back to display units
        let validatedDisplay = unitSystem.formatWeight(validatedKg)
        weightInput = String(format: "%.1f", validatedDisplay)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Log Weight")
                    .font(.title2.bold())
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Weight input
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    // Decrement Button
                    Button {
                        adjustWeight(by: -0.1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.title2.bold())
                            .foregroundStyle(primaryAccent)
                            .frame(width: 44, height: 44)
                            .background(primaryAccent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    // Input Field
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("0.0", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .multilineTextAlignment(.center)
                            .focused($isInputFocused)
                            .frame(width: 140)
                        
                        Text(weightUnit)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryTextColor)
                    }
                    
                    // Increment Button
                    Button {
                        adjustWeight(by: 0.1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(primaryAccent)
                            .frame(width: 44, height: 44)
                            .background(primaryAccent.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                Text("Current: \(formatWeight(currentWeight)) \(weightUnit)")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()

            // Save button
            Button {
                if let weightKg = parsedWeightInKg, isValidWeight {
                    onSave(weightKg)
                    dismiss()
                }
            } label: {
                Text("Save Weight")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidWeight ? primaryAccent : Color.gray.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!isValidWeight)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            weightInput = formatWeight(currentWeight)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
        }
    }
}
