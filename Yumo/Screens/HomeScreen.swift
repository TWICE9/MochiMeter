// Screens/HomeScreen.swift

import SwiftUI
import SwiftData
import Combine
import WidgetKit
import UserNotifications
import Auth

struct HomeScreen: View {
    
    // 1. Environment & Data Queries
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var tabRouter: TabRouter
    @EnvironmentObject private var superwallManager: SuperwallManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var adManager: AdManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - Adaptive Sizing for iPad
    
    /// Returns true if the device has regular horizontal size class (iPad)
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    /// Adaptive calorie ring size - larger on iPad
    private var calorieRingSize: CGFloat {
        isRegularWidth ? 330 : 220
    }
    
    /// Adaptive calorie ring line width - thicker on iPad
    private var calorieRingLineWidth: CGFloat {
        isRegularWidth ? 42 : 28
    }
    
    /// Adaptive macro ring size - larger on iPad
    private var macroRingSize: CGFloat {
        isRegularWidth ? 120 : 80
    }
    
    /// Adaptive macro ring line width - thicker on iPad
    private var macroRingLineWidth: CGFloat {
        isRegularWidth ? 10 : 7
    }
    
    /// Adaptive macro ring spacing - more space on iPad
    private var macroRingSpacing: CGFloat {
        isRegularWidth ? 36 : 24
    }

    // MARK: - State & Animation

    @State private var allFoodLogs: [LoggedFood] = []
    @State private var goals: UserGoals = UserGoals()

    // Animation State
    @State private var animatedCalories: Double = 0
    @State private var animatedOverflowCalories: Double = 0
    @State private var animatedProtein: Double = 0
    @State private var animatedCarbs: Double = 0
    @State private var animatedFat: Double = 0
    @State private var calorieStreak: Int = 0
    @State private var isStreakPending: Bool = false

    // UI State
    @State private var showWaterSheet = false
    @State private var showFastingSheet = false
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var quickMealText: String = ""
    @FocusState private var isQuickMealFocused: Bool
    @State private var showQuickMealRetryAlert = false
    @State private var failedQuickMealText = ""

    // Background animation state
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero


    // MARK: - Computed Properties

    // Dynamically filter logs for selected date (updates when date changes)
    private var foodLogsToday: [LoggedFood] {
        let startOfDay = selectedDate.startOfDay
        let endOfDay = selectedDate.endOfDay
        return allFoodLogs.filter { log in
            log.timestamp >= startOfDay &&
            log.timestamp <= endOfDay &&
            log.recipe == nil
        }
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    // MARK: - Dynamic Macro Colors (avoid theme color)
    private var proteinColor: Color {
        // Default: Mango yellow
        let defaultColor = Color(red: 1.0, green: 0.85, blue: 0.4)
        // If theme is mango (yellow), use pink instead
        return themeManager.currentTheme == .mango ? Color(red: 1.0, green: 0.55, blue: 0.65) : defaultColor
    }
    
    private var carbsColor: Color {
        // Default: Matcha green
        let defaultColor = Color(red: 0.6, green: 0.9, blue: 0.7)
        // If theme is matcha (green), use orange instead
        return themeManager.currentTheme == .matcha ? Color(red: 1.0, green: 0.7, blue: 0.4) : defaultColor
    }
    
    private var fatColor: Color {
        // Default: Taro purple
        let defaultColor = Color(red: 0.75, green: 0.65, blue: 0.95)
        // If theme is taro (purple), use coral instead
        return themeManager.currentTheme == .taro ? Color(red: 1.0, green: 0.6, blue: 0.5) : defaultColor
    }

    private var totalCaloriesToday: Double {
        guard goals.dailyCalories > 0 else { return 0.0 }
        return foodLogsToday.reduce(0) { $0 + $1.totalCalories }
    }
    private var totalProteinToday: Double { foodLogsToday.reduce(0) { $0 + $1.totalProtein } }
    private var totalCarbsToday: Double { foodLogsToday.reduce(0) { $0 + $1.totalCarbs } }
    private var totalFatToday: Double { foodLogsToday.reduce(0) { $0 + $1.totalFat } }

    private var recentLogs: [LoggedFood] { foodLogsToday }
    
    var body: some View {
        mainContent
            .alert("Quick Meal Timeout", isPresented: $showQuickMealRetryAlert) {
                Button("Try Again") {
                    quickMealText = failedQuickMealText
                    Task {
                        await logQuickMeal()
                    }
                }
                Button("Cancel", role: .cancel) {
                    failedQuickMealText = ""
                }
            } message: {
                Text("The AI took too long to analyze your meal. Would you like to try again?")
            }
    }
    
    private var mainContent: some View {
        NavigationStack(path: $tabRouter.homePath) {
            ZStack {
                _buildDynamicBackground()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            Color.clear
                                .frame(height: 0)
                                .id("homeTopAnchor")

                            _buildHeader()

                            _buildCalorieWheel()

                            _buildDateSelector()

                            // Ad Banner
                            ConditionalAdBanner()
                                .padding(.vertical, 10)

                            _buildRecentLogs()

                            _buildToolsCarousel()
                        }
                        .padding(.bottom, 100)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isQuickMealFocused = false
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                    .ignoresSafeArea(edges: .top)
                    .onChange(of: tabRouter.homeScrollTrigger) { _, _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            proxy.scrollTo("homeTopAnchor", anchor: .top)
                        }
                    }
                    .onChange(of: isQuickMealFocused) { _, isFocused in
                        if isFocused {
                            // Check premium status when user taps on quick meal input
                            if !superwallManager.isPremium {
                                isQuickMealFocused = false
                                superwallManager.showPaywall()
                                return
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    proxy.scrollTo("quickMealInput", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HomeDestination.self) { destination in
                navigationDestinationView(for: destination)
            }
            .sheet(isPresented: $showWaterSheet) {
                WaterScreen()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showFastingSheet) {
                FastingScreen()
                    .presentationDetents([.medium, .large])
            }
            .task {
                await refreshData()
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: ["StreakReminderNoon", "StreakReminderEvening"]
                )
            }
            .onAppear {
                Task { await refreshData() }
            }
            .onChange(of: tabRouter.selectedTab) { oldTab, newTab in
                if newTab == .home {
                    Task {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        await refreshData()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        tabRouter.scrollHomeToTop()
                    }
                }
            }
            .onChange(of: tabRouter.homeRefreshID) { _, _ in
                Task { await refreshData() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await refreshData() }
                }
            }
            .onChange(of: allFoodLogs) { _, _ in
                updateAnimatedValues()
            }
            .onChange(of: selectedDate) { _, _ in
                updateAnimatedValues()
                preloadImagesForSelectedDate()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FoodLogCreated"))) { _ in
                Task {
                    await refreshData()
                }
                tabRouter.scrollHomeToTop()
            }
        }
    }
    
    @ViewBuilder
    private func navigationDestinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .search:
            SearchScreen()
        case .scan:
            AICameraScanView()
        case .recipes:
            RecipeListView()
        case .reminders:
            RemindersView()
        case .detail(let logID):
            if let log = fetchLog(from: logID) {
                FoodLogDetailView(log: log, goals: goals)
            }
        case .logProduct(let product):
            LogScannedFoodView(
                product: product,
                onLogComplete: {
                    tabRouter.homePath = NavigationPath()
                    tabRouter.scrollHomeToTop()
                }
            )
        case .shoppingList:
            ShoppingListView(userId: authManager.currentUser?.id.uuidString.lowercased() ?? "")
        case .reports:
            HealthRingsView()
        case .fasting:
            FastingView()
        case .savedFoods:
            SavedFoodsView(userId: authManager.currentUser?.id.uuidString.lowercased() ?? "")
        case .community:
            Text("Community View (Coming Soon)")
        case .challenges:
            Text("Challenges View (Coming Soon)")
        }
    }

    // Helper to fetch a log from its PersistentIdentifier
    private func fetchLog(from id: PersistentIdentifier) -> LoggedFood? {
        if let log = modelContext.model(for: id) as? LoggedFood {
            return log
        }
        return nil
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func _buildHeader() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Row 1: Title and Premium button
            HStack(alignment: .center) {
                Image(colorScheme == .light ? "LogoHS" : "LogoDarkMode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)

                Spacer()

                if !superwallManager.isPremium {
                    Button {
                        superwallManager.showPaywall()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption.bold())
                            Text("Premium")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Row 2: Compact streak badge
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: isStreakPending ? "flame" : "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(
                            isStreakPending ? Color.cyan :
                            (calorieStreak > 0 ? Color.orange : Color("AppTextPrimary").opacity(0.4))
                        )
                    Text("\(calorieStreak)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AppTextPrimary"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color("AppTextPrimary").opacity(0.08))
                )

                if isStreakPending {
                    Text("Log today to keep it")
                        .font(.caption)
                        .foregroundStyle(Color.cyan)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 50)
    }

    @ViewBuilder
    private func _buildDateSelector() -> some View {
        let streakDates = getStreakDates()

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Generate last 30 days
                    ForEach(generateDateRange(), id: \.self) { date in
                        DateButton(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            hasLogs: dateHasLogs(date),
                            isInStreak: streakDates.contains(date)
                        ) {
                            if !Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                                hapticSelection()
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                        .id(date)
                    }
                }
                .padding(.vertical, 6)
            }
            .contentMargins(.horizontal, 24)
            .padding(.top, 8)
            .onAppear {
                // Scroll to selected date when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(selectedDate, anchor: .center)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                // Smoothly scroll to newly selected date
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
    }

    private func dateHasLogs(_ date: Date) -> Bool {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        return allFoodLogs.contains { log in
            log.timestamp >= startOfDay && log.timestamp <= endOfDay
        }
    }

    private func generateDateRange() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        var dates: [Date] = []

        // Generate last 30 days (from 29 days ago to today)
        for i in (0...29).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(calendar.startOfDay(for: date))
            }
        }

        return dates
    }

    @ViewBuilder
    private func _buildCalorieWheel() -> some View {
        VStack(spacing: isRegularWidth ? 40 : 28) {
            let goalValue = goals.dailyCalories > 0 ? goals.dailyCalories : 1
            let progress = max(0, min(animatedCalories / goalValue, 1))
            let isOverGoal = animatedCalories > goals.dailyCalories
            let overflowProgress = min(animatedOverflowCalories / goalValue, 1.0)
            
            // Adaptive font sizes for iPad
            let calorieFontSize: CGFloat = isRegularWidth ? 64 : 46
            let waterButtonSize: CGFloat = isRegularWidth ? 56 : 42
            let waterButtonOffset: CGFloat = isRegularWidth ? 42 : 28

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color("AppTextPrimary").opacity(0.08), lineWidth: calorieRingLineWidth)
                    .frame(width: calorieRingSize, height: calorieRingSize)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: themeManager.currentTheme.wheelGradient(for: colorScheme)),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: calorieRingLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: calorieRingSize, height: calorieRingSize)
                    .opacity(progress > 0 ? 1 : 0)
                    .animation(.easeOut(duration: 1.2), value: progress)

                // Overflow ring (gradient to red, shows when over goal)
                Circle()
                    .trim(from: 0, to: overflowProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: themeManager.currentTheme.overflowRingGradient(for: colorScheme)),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * max(overflowProgress, 0.01))
                        ),
                        style: StrokeStyle(lineWidth: calorieRingLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: calorieRingSize, height: calorieRingSize)
                    .opacity(overflowProgress > 0 ? 1 : 0)

                // Center text
                VStack(spacing: isRegularWidth ? 6 : 4) {
                    Text("\(Int(convertEnergy(animatedCalories)))")
                        .font(.system(size: calorieFontSize, weight: .bold, design: .default))
                        .foregroundColor(isOverGoal ? .red : Color("AppTextPrimary"))
                        .contentTransition(.numericText())
                    Text("of \(Int(convertEnergy(goals.dailyCalories))) \(goals.energyUnit.unitLabel)")
                        .font(isRegularWidth ? .title3 : .headline)
                        .foregroundColor(Color("AppTextPrimary").opacity(0.7))
                }

                // Floating water button (top-right)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            hapticImpact()
                            showWaterSheet = true
                        } label: {
                            Image(systemName: "drop.fill")
                                .font(isRegularWidth ? .title2 : .title3)
                                .foregroundStyle(Color("AppTextPrimary"))
                                .frame(width: waterButtonSize, height: waterButtonSize)
                                .background(
                                    ZStack {
                                        BlobShape()
                                            .fill(.cyan.opacity(0.2))
                                            .rotationEffect(.degrees(30))
                                        BlobShape()
                                            .stroke(.cyan.opacity(0.6), lineWidth: 2)
                                            .rotationEffect(.degrees(30))
                                    }
                                )
                        }
                        .offset(x: waterButtonOffset, y: -waterButtonOffset)
                    }
                    Spacer()
                }
                .frame(width: calorieRingSize, height: calorieRingSize)
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .padding(.bottom, isRegularWidth ? 24 : 16)

            // Macro rings with adaptive sizing
            HStack(spacing: macroRingSpacing) {
                MacroProgressRing(macroName: "Protein", current: animatedProtein, goal: goals.dailyProtein, color: proteinColor, lineWidth: macroRingLineWidth, ringSize: macroRingSize)
                    .frame(width: macroRingSize, height: macroRingSize)
                MacroProgressRing(macroName: "Carbs", current: animatedCarbs, goal: goals.dailyCarbs, color: carbsColor, lineWidth: macroRingLineWidth, ringSize: macroRingSize)
                    .frame(width: macroRingSize, height: macroRingSize)
                MacroProgressRing(macroName: "Fat", current: animatedFat, goal: goals.dailyFat, color: fatColor, lineWidth: macroRingLineWidth, ringSize: macroRingSize)
                    .frame(width: macroRingSize, height: macroRingSize)
            }
            .padding(.horizontal, isRegularWidth ? 48 : 32)
            .animation(.easeOut(duration: 0.9), value: animatedProtein)
            .animation(.easeOut(duration: 0.9), value: animatedCarbs)
            .animation(.easeOut(duration: 0.9), value: animatedFat)
        }
        .padding(.top, isRegularWidth ? 16 : 10)
        .padding(.horizontal, isRegularWidth ? 32 : 24)
    }
    
    
    @ViewBuilder
    private func _buildRecentLogs() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick meal input (show for all dates)
            _buildQuickMealInput()

            // Recent logs header and list
            if !recentLogs.isEmpty {
                Text(isViewingToday ? "Recent Logs" : "Logs for \(selectedDate, format: .dateTime.month().day())")
                    .font(.headline)
                    .foregroundStyle(Color("AppTextPrimary"))
                    .padding(.horizontal, 24)

                List {
                    ForEach(recentLogs) { log in
                        Button {
                            tabRouter.homePath.append(HomeDestination.detail(log.persistentModelID))
                        } label: {
                            _buildFoodLogCard(log: log)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(log: log)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .environment(\.defaultMinListRowHeight, 0)
                .frame(height: CGFloat(recentLogs.count) * 130)
            } else {
                // Empty state for both today and other dates
                FrostedGlassContainer {
                    HStack {
                        Spacer()
                        Text(isViewingToday ? "Your recent logs will appear here." : "No logs for this date.")
                            .font(.subheadline)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private func _buildFoodLogCard(log: LoggedFood) -> some View {
        // Check if this log has a photo or is analyzing, or has a cloud image path
        let hasVisualContent = log.isAnalyzing || log.photoData != nil || log.cloudImagePath != nil

        if hasVisualContent {
            GeometryReader { geo in
                let cardWidth = geo.size.width
                let cardHeight: CGFloat = 118
                let imageWidth = max(90, cardWidth * 0.25)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(log.isAnalyzing ? Color("AppSecondaryAccent").opacity(0.12) : Color("AppTextPrimary").opacity(colorScheme == .light ? 0.05 : 0.12))


                    // Left image band ~25%
                    HStack(spacing: 0) {
                        Group {
                            if log.isAnalyzing {
                                ZStack {
                                    Rectangle()
                                        .fill(Color("AppSecondaryAccent").opacity(0.22))
                                    AnalyzingProgressView()
                                }
                            } else if let photoData = log.photoData {
                                AsyncThumbnailImage(photoData: photoData, size: max(imageWidth, cardHeight))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            } else if let cloudPath = log.cloudImagePath {
                                // Cloud image placeholder & loader
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                .task {
                                    if let data = await ImageStorageManager.shared.downloadImage(path: cloudPath) {
                                        await MainActor.run {
                                            withAnimation(.easeIn(duration: 0.3)) {
                                                log.photoData = data
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: imageWidth, height: cardHeight)
                        .clipped()

                        Spacer(minLength: 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Text content
                    VStack(alignment: .leading, spacing: 8) {
                        if log.isAnalyzing {
                            // Skeleton loading state with shimmer
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    // Skeleton for food name
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color("AppTextPrimary").opacity(0.15))
                                        .frame(width: 120, height: 14)
                                        .shimmer()

                                    Spacer()

                                    Text(formatTime(log.timestamp))
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }

                                // Skeleton for calories
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color("AppTextPrimary").opacity(0.15))
                                    .frame(width: 70, height: 16)
                                    .shimmer()

                                // Skeleton for macros
                                HStack(spacing: 16) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color("AppTextPrimary").opacity(0.12))
                                        .frame(width: 35, height: 12)
                                        .shimmer()

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color("AppTextPrimary").opacity(0.12))
                                        .frame(width: 35, height: 12)
                                        .shimmer()

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color("AppTextPrimary").opacity(0.12))
                                        .frame(width: 35, height: 12)
                                        .shimmer()
                                }
                            }
                        } else {
                            HStack(alignment: .top) {
                                Text(log.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppTextPrimary"))
                                    .lineLimit(2)

                                Spacer()

                                Text(formatTime(log.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }

                            Text("\(Int(convertEnergy(log.totalCalories))) \(goals.energyUnit.unitLabel)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color("AppTextPrimary").opacity(0.9))

                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Text("P")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.pink)
                                    Text("\(Int(log.totalProtein))g")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                                }

                                HStack(spacing: 4) {
                                    Text("C")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(Color("AppSecondaryAccent"))
                                    Text("\(Int(log.totalCarbs))g")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                                }

                                HStack(spacing: 4) {
                                    Text("F")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                    Text("\(Int(log.totalFat))g")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                                }
                            }
                        }
                    }
                    .padding(.leading, imageWidth + 16)
                    .padding(.trailing, 16)
                }
                .frame(height: cardHeight)
            }
            .frame(height: 118)
            .padding(.horizontal, 24)
        } else {
            // Card WITHOUT image - simpler, text-only design
            VStack(alignment: .leading, spacing: 10) {
                // Line 1: Name & Time
                HStack(alignment: .top) {
                    Text(log.name)
                        .font(.subheadline)
                        .foregroundStyle(Color("AppTextPrimary"))
                        .lineLimit(2)

                    Spacer()

                    Text(formatTime(log.timestamp))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                // Line 2: Calories
                Text("\(Int(convertEnergy(log.totalCalories))) \(goals.energyUnit.unitLabel)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.9))

                // Line 3: Macros breakdown
                HStack(spacing: 16) {
                    // Protein
                    HStack(spacing: 4) {
                        Text("P")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.pink)
                        Text("\(Int(log.totalProtein))g")
                            .font(.caption)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                    }

                    // Carbs
                    HStack(spacing: 4) {
                        Text("C")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("AppSecondaryAccent"))
                        Text("\(Int(log.totalCarbs))g")
                            .font(.caption)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                    }

                    // Fat
                    HStack(spacing: 4) {
                        Text("F")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        Text("\(Int(log.totalFat))g")
                            .font(.caption)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("AppTextPrimary").opacity(colorScheme == .light ? 0.05 : 0.12))

            )
            .padding(.horizontal, 24)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func _buildToolsCarousel() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tools")
                .font(.headline)
                .foregroundStyle(Color("AppTextPrimary"))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink(value: HomeDestination.recipes) {
                        _buildCompactToolButton(title: "Recipes", icon: "list.bullet.clipboard.fill")
                    }.buttonStyle(.plain)

                    NavigationLink(value: HomeDestination.reminders) {
                        _buildCompactToolButton(title: "Reminders", icon: "bell.fill")
                    }.buttonStyle(.plain)

                    NavigationLink(value: HomeDestination.shoppingList) {
                        _buildCompactToolButton(title: "Shopping", icon: "cart.fill")
                    }.buttonStyle(.plain)

                    NavigationLink(value: HomeDestination.savedFoods) {
                        _buildCompactToolButton(title: "Saved", icon: "star.fill")
                    }.buttonStyle(.plain)

                    NavigationLink(value: HomeDestination.fasting) {
                        _buildCompactToolButton(title: "Fasting", icon: "timer")
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private func _buildCompactToolButton(title: String, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color("AppTextPrimary").opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
            }

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
        }
        .frame(width: 70)
    }

    @ViewBuilder
    private func _buildQuickMealInput() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(colorScheme == .light ? Color(red: 0.3, green: 0.7, blue: 0.4) : Color("AppPrimaryAccent"))

            TextField("What did you eat?", text: $quickMealText, prompt: Text("What did you eat?")
                .foregroundColor(Color("AppTextPrimary").opacity(colorScheme == .dark ? 0.5 : 0.4)))
                .focused($isQuickMealFocused)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(Color("AppTextPrimary"))
                .submitLabel(.send)
                .onSubmit {
                    if superwallManager.isPremium {
                        Task { await logQuickMeal() }
                    } else {
                        superwallManager.showPaywall()
                    }
                }

            if !quickMealText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    if superwallManager.isPremium {
                        Task { await logQuickMeal() }
                    } else {
                        superwallManager.showPaywall()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("AppTextPrimary").opacity(colorScheme == .dark ? 0.12 : 0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorScheme == .dark
                        ? Color("AppPrimaryAccent").opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: colorScheme == .dark ? Color("AppPrimaryAccent").opacity(0.15) : .white.opacity(0.15), radius: 8, x: 0, y: -2)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: quickMealText.isEmpty)
        .id("quickMealInput")
    }

    // MARK: - Core Functions

    @MainActor
    private func refreshData() async {
        // Fetch user-scoped data
        allFoodLogs = await UserScopedQuery.fetchFoodLogs(context: modelContext)

        if let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
            goals = fetchedGoals
        }

        let streakResult = computeCalorieStreak()
        calorieStreak = streakResult.streak
        isStreakPending = streakResult.isPending

        // Streak reminder notifications disabled per user request
        // await scheduleStreakReminders(
        //     streakActive: calorieStreak > 1,
        //     hasLoggedToday: !foodLogsToday.isEmpty
        // )

        // Schedule meal reminders (every 4 hours from 7am-9pm if no recent logs)
        await scheduleMealReminders()

        // Schedule weekly weight logging reminder
        await scheduleWeeklyWeightReminder()

        // Update animations with new data
        // Update animations with new data
        updateAnimatedValues()
        
        // Preload images for current view
        preloadImagesForSelectedDate()
    }

    private func preloadImagesForSelectedDate() {
        let logsToCheck = recentLogs
        
        Task(priority: .background) {
            for log in logsToCheck {
                if log.photoData == nil, let path = log.cloudImagePath {
                    if let data = await ImageStorageManager.shared.downloadImage(path: path) {
                        await MainActor.run {
                            withAnimation(.easeIn(duration: 0.3)) {
                                log.photoData = data
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func updateAnimatedValues() {
        let newTotalCalories = totalCaloriesToday
        let newTotalProtein = totalProteinToday
        let newTotalCarbs = totalCarbsToday
        let newTotalFat = totalFatToday

        // Bouncy spring animation for playful "mochi" feel
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animatedCalories = newTotalCalories
            animatedProtein = newTotalProtein
            animatedCarbs = newTotalCarbs
            animatedFat = newTotalFat
        }

        // Animate overflow calories with delay and bounce
        let overflowAmount = max(0, newTotalCalories - goals.dailyCalories)
        let wasOverGoal = animatedOverflowCalories > 0
        let isNowOverGoal = overflowAmount > 0

        Task { @MainActor in
            if isNowOverGoal {
                if !wasOverGoal {
                    // Going from under/at goal to over goal - reset and animate with delay
                    animatedOverflowCalories = 0
                    try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
                }
                // Animate to new overflow amount with bounce
                withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                    animatedOverflowCalories = overflowAmount
                }
            } else {
                // Not over goal anymore - reset immediately
                animatedOverflowCalories = 0
            }
        }
    }
    
    private func delete(log: LoggedFood) {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.warning)

        let logId = log.id.uuidString
        let userId = log.userId

        modelContext.delete(log)
        try? modelContext.save()

        // Manually update the state array to avoid scroll-to-top
        allFoodLogs.removeAll { $0.id == log.id }

        // Delete from cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteFoodLogFromCloud(logId: logId, userId: userId)
            }
        }

        // Reload widgets when a log is deleted
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    private func logQuickMeal() async {
        var trimmed = quickMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Normalize slang terms to proper brand names
        trimmed = normalizeFoodSlang(trimmed)

        // Clear input and dismiss keyboard
        quickMealText = ""
        isQuickMealFocused = false

        // Get user ID
        let userId = await UserSession.shared.getCurrentUserId()

        // Determine the timestamp - use current time on the selected date
        let timestamp: Date
        if isViewingToday {
            timestamp = Date() // Current time for today
        } else {
            // Use selected date but with current time of day
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
            timestamp = calendar.date(bySettingHour: timeComponents.hour ?? 12,
                                       minute: timeComponents.minute ?? 0,
                                       second: timeComponents.second ?? 0,
                                       of: selectedDate) ?? selectedDate
        }

        // Create a placeholder log entry with isAnalyzing = true
        let placeholderLog = LoggedFood(
            name: trimmed,
            timestamp: timestamp,
            servingSizeDescription: "1 serving",
            servingAmount: 1.0,
            caloriesPerServing: 0,
            proteinPerServing: 0,
            carbsPerServing: 0,
            fatPerServing: 0,
            barcode: ""
        )
        placeholderLog.userId = userId
        placeholderLog.isAnalyzing = true

        modelContext.insert(placeholderLog)
        try? modelContext.save()

        // Refresh to show the analyzing state
        await refreshData()

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Track analytics for quick meal usage
        AnalyticsManager.shared.track(.quickMealUsed)

        // Try to find a cached food first, then fall back to AI
        Task.detached(priority: .userInitiated) { @MainActor [weak modelContext = self.modelContext] in
            guard let modelContext = modelContext else { return }

            // First, try to find a similar food in master_foods cache
            if let cachedFood = await self.findCachedFood(for: trimmed) {

                // Update placeholder with cached data
                placeholderLog.name = cachedFood.foodName
                placeholderLog.barcode = cachedFood.barcode
                placeholderLog.caloriesPerServing = cachedFood.calories
                placeholderLog.proteinPerServing = cachedFood.protein
                placeholderLog.carbsPerServing = cachedFood.carbs
                placeholderLog.fatPerServing = cachedFood.fat
                placeholderLog.fiberPerServing = cachedFood.fiber
                placeholderLog.sugarPerServing = cachedFood.sugar
                placeholderLog.saltPerServing = cachedFood.salt
                placeholderLog.potassiumPerServing = cachedFood.potassium
                placeholderLog.servingSizeDescription = cachedFood.servingSizeDescription
                placeholderLog.brand = cachedFood.brand
                placeholderLog.isAnalyzing = false

                try? modelContext.save()

                // Upload to cloud and increment scan count
                if let userId = userId {
                    Task {
                        await CloudSyncManager.shared.uploadFoodLogImmediately(placeholderLog, userId: userId)
                        try? await SupabaseService().incrementScanCount(barcode: cachedFood.barcode)
                    }
                }

                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)
                return
            }

            // Second, try USDA database for verified nutritional data
            if let usdaFood = await self.findUSDAFood(for: trimmed) {

                // Update placeholder with USDA data
                placeholderLog.name = usdaFood.foodName
                placeholderLog.barcode = "USDA-\(usdaFood.foodName.lowercased().replacingOccurrences(of: " ", with: "-"))"
                placeholderLog.caloriesPerServing = usdaFood.caloriesPerServing
                placeholderLog.proteinPerServing = usdaFood.proteinPerServing
                placeholderLog.carbsPerServing = usdaFood.carbsPerServing
                placeholderLog.fatPerServing = usdaFood.fatPerServing
                placeholderLog.fiberPerServing = usdaFood.fiberPerServing
                placeholderLog.sugarPerServing = usdaFood.sugarPerServing
                placeholderLog.saltPerServing = usdaFood.saltPerServing
                placeholderLog.potassiumPerServing = usdaFood.potassiumPerServing
                placeholderLog.servingSizeDescription = usdaFood.servingSizeDescription  // "100g"
                placeholderLog.brand = "USDA"
                placeholderLog.isAnalyzing = false

                try? modelContext.save()

                // Upload to cloud
                if let userId = userId {
                    Task {
                        await CloudSyncManager.shared.uploadFoodLogImmediately(placeholderLog, userId: userId)
                    }
                }

                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)
                return
            }

            // No cache or USDA hit - use AI analysis as fallback
            do {
                let analysis = try await AIFoodScanner.shared.analyzeMealDescription(trimmed)

                // Update the placeholder with real data
                placeholderLog.name = analysis.name
                placeholderLog.barcode = analysis.generateAIBarcode()
                placeholderLog.caloriesPerServing = analysis.calories
                placeholderLog.proteinPerServing = analysis.protein
                placeholderLog.carbsPerServing = analysis.carbs
                placeholderLog.fatPerServing = analysis.fat
                placeholderLog.fiberPerServing = analysis.fiber
                placeholderLog.sugarPerServing = analysis.sugar
                placeholderLog.saltPerServing = analysis.salt
                placeholderLog.potassiumPerServing = analysis.potassium
                placeholderLog.servingSizeDescription = analysis.servingSize
                placeholderLog.aiIngredients = analysis.ingredients
                placeholderLog.aiConfidence = analysis.confidence
                placeholderLog.brand = "AI Analyzed"
                placeholderLog.isAnalyzing = false

                try? modelContext.save()

                // Upload to cloud
                if let userId = userId {
                    Task {
                        await CloudSyncManager.shared.uploadFoodLogImmediately(placeholderLog, userId: userId)
                        // Use reliable client-side upsert to ensure food gets into master_foods
                        try? await SupabaseService().upsertAIFood(AIFoodUpload(from: analysis))
                    }
                }

                // Trigger refresh notification
                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

            } catch {
                // On error, delete the placeholder
                modelContext.delete(placeholderLog)
                try? modelContext.save()

                // Trigger refresh
                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

                print("❌ Quick meal analysis failed: \(error.localizedDescription)")
                
                // Show retry alert if it was a timeout
                if error.localizedDescription.contains("took too long") || error.localizedDescription.contains("timeout") {
                    await MainActor.run {
                        failedQuickMealText = trimmed
                        showQuickMealRetryAlert = true
                    }
                }
            }
        }
    }

    /// Search for a cached food that closely matches the user's input
    private func findCachedFood(for query: String) async -> MasterFoodRow? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Important modifier words that change the item significantly
        let significantModifiers: Set<String> = [
            "double", "triple", "large", "small", "medium", "extra", "big", "mini",
            "half", "whole", "single", "regular", "lite", "light", "diet", "sugar-free",
            "decaf", "iced", "hot", "crispy", "grilled", "spicy", "mild"
        ]

        do {
            // Search master_foods for similar items
            let results = try await SupabaseService().searchFoodsByName(query, limit: 10)

            // Look for a close match
            for food in results {
                let normalizedFoodName = food.foodName.lowercased()

                // Exact match - always accept
                if normalizedFoodName == normalizedQuery {
                    return food
                }

                let queryWords = Set(normalizedQuery.split(separator: " ").map(String.init))
                let foodWords = Set(normalizedFoodName.split(separator: " ").map(String.init))

                // Check for significant modifiers that differ between query and cached item
                let queryModifiers = queryWords.intersection(significantModifiers)
                let foodModifiers = foodWords.intersection(significantModifiers)

                // If modifiers don't match exactly, skip this cached item
                // e.g., "double bacon mcmuffin" vs "bacon mcmuffin" have different modifiers
                if queryModifiers != foodModifiers {
                    continue
                }

                // Calculate bidirectional word coverage
                let commonWords = queryWords.intersection(foodWords)
                let queryWordCoverage = queryWords.isEmpty ? 0 : Double(commonWords.count) / Double(queryWords.count)
                let foodWordCoverage = foodWords.isEmpty ? 0 : Double(commonWords.count) / Double(foodWords.count)

                // Require very high bidirectional match (both ways must be >= 0.95)
                // This prevents loose matches that return different dishes
                if queryWordCoverage >= 0.95 && foodWordCoverage >= 0.95 {
                    return food
                }

                // Also check string similarity for very close matches (95%+)
                let similarity = calculateSimilarity(normalizedQuery, normalizedFoodName)
                if similarity > 0.95 {
                    return food
                }
            }
        } catch {
            print("❌ Cache search failed: \(error.localizedDescription)")
        }

        return nil
    }

    /// Search USDA database for verified nutritional data
    private func findUSDAFood(for query: String) async -> USDAFoodRow? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // Search USDA foods
            // Increase limit to ensure we find the exact match even if other items have higher search rank
            let results = try await SupabaseService().searchUSDAFoodsByName(query, limit: 50)

            // Look for the best match among results
            var bestMatch: USDAFoodRow?
            var highestScore: Double = -1.0
            
            for food in results {
                let normalizedFoodName = food.foodName.lowercased()
                
                // Exact match - always return immediately
                if normalizedFoodName == normalizedQuery {
                    return food
                }
                
                // Word Coverage Check
                let queryWords = Set(normalizedQuery.split(separator: " ").map(String.init))
                
                let foodWords = Set(normalizedFoodName
                    .replacingOccurrences(of: ",", with: " ")
                    .split(separator: " ")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
                
                // Calculate how many query words appear in the food name
                let matchingWords = queryWords.filter { queryWord in
                    foodWords.contains { foodWord in
                        foodWord.contains(queryWord) || queryWord.contains(foodWord)
                    }
                }
                
                let coverage = queryWords.isEmpty ? 0 : Double(matchingWords.count) / Double(queryWords.count)
                
                // Only consider candidates where the query is well-represented
                if coverage >= 0.90 {
                    // Calculate similarity to prefer closer matches (shorter/closer names)
                    let similarity = calculateSimilarity(normalizedQuery, normalizedFoodName)
                    
                    if similarity > highestScore {
                        highestScore = similarity
                        bestMatch = food
                    }
                }
            }
            
            // Enforce a strict minimum quality threshold to prevent returning irrelevant items
            if highestScore >= 0.95 {
                return bestMatch
            }
            
            return nil
        } catch {
            print("❌ USDA search failed: \(error.localizedDescription)")
        }

        return nil
    }

    /// Calculate similarity between two strings (0.0 to 1.0)
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1

        if longer.isEmpty { return 1.0 }

        let editDistance = levenshteinDistance(shorter, longer)
        return Double(longer.count - editDistance) / Double(longer.count)
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    /// Normalize slang terms and abbreviations to proper brand names
    private func normalizeFoodSlang(_ input: String) -> String {
        // Dictionary of slang -> proper name (case-insensitive matching)
        let slangMap: [String: String] = [
            // Australian slang
            "maccas": "McDonald's",
            "macca's": "McDonald's",
            "maccies": "McDonald's",
            "hungry jacks": "Burger King",  // Australian name for BK
            "hj's": "Hungry Jack's",
            "kfc": "KFC",
            "chook": "chicken",
            "arvo snack": "afternoon snack",
            "brekkie": "breakfast",
            "servo": "service station",

            // Common abbreviations
            "bk": "Burger King",
            "mcd": "McDonald's",
            "mcds": "McDonald's",
            "sbux": "Starbucks",
            "dq": "Dairy Queen",
            "tb": "Taco Bell",
            "cfa": "Chick-fil-A",
            "wendys": "Wendy's",
            "popeyes": "Popeyes",

            // UK slang
            "nandos": "Nando's",
            "greggs": "Greggs",
            "spoons": "Wetherspoons",

            // Common misspellings
            "mcdonalds": "McDonald's",
            "starbucks": "Starbucks",
            "chipotle": "Chipotle"
        ]

        var result = input

        // Replace slang terms (case-insensitive, whole word matching)
        for (slang, proper) in slangMap {
            // Create pattern that matches whole words only
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: slang))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: proper
                )
            }
        }

        return result
    }

    private func hapticImpact() {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
    }
    
    private func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Helpers
    private func convertEnergy(_ kcal: Double) -> Double {
        goals.energyUnit == .kilojoules ? kcal * 4.184 : kcal
    }
    
    private func dateWithTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    // MARK: - Streak

    private func getStreakDates() -> Set<Date> {
        guard goals.dailyCalories > 0 else { return [] }
        let calendar = Calendar.current
        let today = Date().startOfDay
        // Exclude recipe ingredients from streak calculation
        let standaloneLogs = allFoodLogs.filter { $0.recipe == nil }
        let grouped = Dictionary(grouping: standaloneLogs) { calendar.startOfDay(for: $0.timestamp) }

        var streakDates = Set<Date>()

        // Check if today has logs
        let todayLogs = grouped[today] ?? []
        let todayTotal = todayLogs.reduce(0) { $0 + $1.totalCalories }
        let hasLoggedToday = !todayLogs.isEmpty

        // If today has logs and is within goal, start collecting from today
        if hasLoggedToday && todayTotal <= goals.dailyCalories {
            streakDates.insert(today)
            for i in 1..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
                let logs = grouped[date] ?? []
                if logs.isEmpty { break }
                let dailyTotal = logs.reduce(0) { $0 + $1.totalCalories }
                if dailyTotal <= goals.dailyCalories {
                    streakDates.insert(date)
                } else {
                    break
                }
            }
        }
        // If today has no logs, collect yesterday's streak (pending state)
        else if !hasLoggedToday {
            for i in 1..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
                let logs = grouped[date] ?? []
                if logs.isEmpty { break }
                let dailyTotal = logs.reduce(0) { $0 + $1.totalCalories }
                if dailyTotal <= goals.dailyCalories {
                    streakDates.insert(date)
                } else {
                    break
                }
            }
        }

        return streakDates
    }

    private func computeCalorieStreak() -> (streak: Int, isPending: Bool) {
        guard goals.dailyCalories > 0 else { return (0, false) }
        let calendar = Calendar.current
        let today = Date().startOfDay
        // Exclude recipe ingredients from streak calculation
        let standaloneLogs = allFoodLogs.filter { $0.recipe == nil }
        let grouped = Dictionary(grouping: standaloneLogs) { calendar.startOfDay(for: $0.timestamp) }

        // Check if today has logs
        let todayLogs = grouped[today] ?? []
        let todayTotal = todayLogs.reduce(0) { $0 + $1.totalCalories }
        let hasLoggedToday = !todayLogs.isEmpty

        // If today has logs and is within goal, start counting from today
        if hasLoggedToday && todayTotal <= goals.dailyCalories {
            var streak = 1
            for i in 1..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
                let logs = grouped[date] ?? []
                if logs.isEmpty { break }
                let dailyTotal = logs.reduce(0) { $0 + $1.totalCalories }
                if dailyTotal <= goals.dailyCalories {
                    streak += 1
                } else {
                    break
                }
            }
            return (streak, false)
        }

        // If today has no logs, check if yesterday has a valid streak (pending state)
        if !hasLoggedToday {
            var yesterdayStreak = 0
            for i in 1..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { break }
                let logs = grouped[date] ?? []
                if logs.isEmpty { break }
                let dailyTotal = logs.reduce(0) { $0 + $1.totalCalories }
                if dailyTotal <= goals.dailyCalories {
                    yesterdayStreak += 1
                } else {
                    break
                }
            }

            // If there's a streak from yesterday, it's pending (waiting for today's log)
            if yesterdayStreak > 0 {
                return (yesterdayStreak, true)
            }
        }

        return (0, false)
    }

    // MARK: - Notifications

    private func scheduleMealReminders() async {
        // Check if user has enabled meal reminders
        guard goals.mealRemindersEnabled else {
            // Remove any existing reminders if disabled
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [
                "MealReminder830AM",
                "MealReminder12PM",
                "MealReminder7PM"
            ])
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        // Check if notifications are authorized
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        // Remove any existing meal reminder notifications
        center.removePendingNotificationRequests(withIdentifiers: [
            "MealReminder830AM",
            "MealReminder12PM",
            "MealReminder7PM"
        ])

        // Check when user last logged food
        let calendar = Calendar.current
        let now = Date()
        let fourHoursAgo = calendar.date(byAdding: .hour, value: -4, to: now) ?? now

        // If user has logged food in the last 4 hours, don't schedule any notifications
        let recentLogs = allFoodLogs.filter { $0.timestamp >= fourHoursAgo }
        if !recentLogs.isEmpty {
            print("🔕 User logged food recently, skipping meal reminders")
            return
        }

        // Schedule notifications for 8:30am, 12pm, and 7pm
        let reminderTimes: [(id: String, hour: Int, minute: Int, message: String)] = [
            ("MealReminder830AM", 8, 30, "Haven't logged breakfast or snacks? Tap to track your meals."),
            ("MealReminder12PM", 12, 0, "Time to log your lunch! Stay on track with your nutrition goals."),
            ("MealReminder7PM", 19, 0, "Don't forget to log dinner! Keep your food diary complete.")
        ]

        for reminder in reminderTimes {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = reminder.hour
            components.minute = reminder.minute

            // Only schedule if the time hasn't passed today
            if let triggerDate = calendar.date(from: components), triggerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Meal Reminder"
                content.body = reminder.message
                content.sound = .default
                content.categoryIdentifier = "MEAL_REMINDER"

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)

                try? await center.add(request)
                print("📅 Scheduled meal reminder: \(reminder.id)")
            }
        }
    }

    private func scheduleStreakReminders(streakActive: Bool, hasLoggedToday: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ids = ["StreakReminderNoon", "StreakReminderEvening"]

        if !streakActive || hasLoggedToday {
            center.removePendingNotificationRequests(withIdentifiers: ids)
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: ids)

        let calendar = Calendar.current
        let now = Date()

        let times: [(id: String, hour: Int, minute: Int, body: String)] = [
            ("StreakReminderNoon", 12, 30, "Keep your streak! Log lunch to stay under your goal."),
            ("StreakReminderEvening", 17, 0, "Don’t lose your streak—log a meal before the day ends.")
        ]

        for time in times {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = time.hour
            components.minute = time.minute
            if let triggerDate = calendar.date(from: components), triggerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Streak active"
                content.body = time.body
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: time.id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    private func scheduleWeeklyWeightReminder() async {
        // Check if user has enabled weekly weight reminders
        guard goals.weeklyWeightReminderEnabled else {
            // Remove any existing reminders if disabled
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["WeeklyWeightReminder"])
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let reminderId = "WeeklyWeightReminder"
        
        // Check if notifications are authorized
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        
        // Remove any existing weekly weight reminder
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])
        
        // Check if user has logged weight this week
        let hasLoggedThisWeek = await checkIfWeightLoggedThisWeek()
        
        // If already logged this week, don't schedule a reminder
        if hasLoggedThisWeek {
            return
        }
        
        // Schedule notification for next Monday at 9:00 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 2  // Monday (1 = Sunday, 2 = Monday, etc.)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Weight Check-In"
        content.body = "Don't forget to log your weight this week! Track your progress and stay motivated."
        content.sound = .default
        content.categoryIdentifier = "WEIGHT_REMINDER"
        
        // Use repeating trigger to fire every Monday
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger)
        
        try? await center.add(request)
    }
    
    private func checkIfWeightLoggedThisWeek() async -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start of the current week (Monday)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return false
        }
        
        // Fetch weight logs
        let weightLogs = await UserScopedQuery.fetchWeightLogs(context: modelContext)
        
        // Check if any weight log exists in the current week
        let logsThisWeek = weightLogs.filter { log in
            log.timestamp >= weekStart && log.timestamp <= now
        }
        
        return !logsThisWeek.isEmpty
    }
    
    // MARK: - Background Functions
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            
            if colorScheme == .light {
                RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                    .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            } else {
                // Subtle Dark Mode Lighting - Increased visibility
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), .clear]), center: .topLeading, startRadius: 50, endRadius: 500)
                    .offset(offset1).offset(x: -100, y: -100).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.08), .clear]), center: .bottomTrailing, startRadius: 50, endRadius: 450)
                    .offset(offset2).offset(x: 100, y: 100).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.06), .clear]), center: .bottomLeading, startRadius: 60, endRadius: 350)
                    .offset(offset1).offset(x: -50, y: 120).ignoresSafeArea()
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

// MARK: - Async Thumbnail Image

/// Shared cache for decoded thumbnail images
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [Data: UIImage] = [:]

    func image(for data: Data) -> UIImage? {
        cache[data]
    }

    func store(_ image: UIImage, for data: Data) {
        cache[data] = image
    }
}

struct AsyncThumbnailImage: View {
    let photoData: Data
    let size: CGFloat

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // Simple placeholder (no ProgressView to avoid animation overhead)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)

                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .task {
            await decodeImage()
        }
    }

    private func decodeImage() async {
        // Check cache first
        if let cached = await ThumbnailCache.shared.image(for: photoData) {
            withAnimation(.easeOut(duration: 0.3)) {
                loadedImage = cached
            }
            return
        }

        // Decode on background thread if not cached
        let image = await Task.detached(priority: .userInitiated) {
            UIImage(data: photoData)
        }.value

        // Store in cache
        if let image = image {
            await ThumbnailCache.shared.store(image, for: photoData)
        }

        // Update UI on main thread
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                loadedImage = image
            }
        }
    }
}

// MARK: - Date Button Component

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasLogs: Bool
    let isInStreak: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 9))
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                Text(dayNumber)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)

                // Show flame for streak dates, or dot for today
                if isInStreak {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(isSelected ? .white : .orange)
                } else if isToday {
                    Circle()
                        .fill(colorScheme == .light ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.darkSecondaryColor)
                        .frame(width: 3, height: 3)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                BlobShape()
                    .fill(backgroundColor)
                    .rotationEffect(.degrees(Double((Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0) * 137 % 360)))
            )
        }
        .buttonStyle(.plain)
        .opacity(hasLogs || isSelected ? 1.0 : 0.4)
    }

    private var textColor: Color {
        if isSelected {
            return colorScheme == .light ? .white : .black
        } else if hasLogs {
            return Color("AppTextPrimary").opacity(0.8)
        } else {
            return Color("AppTextPrimary").opacity(0.5)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            // Use a muted, softer version of the theme color
            let baseColor = colorScheme == .light 
                ? themeManager.currentTheme.primaryColor 
                : themeManager.currentTheme.darkPrimaryColor
            return baseColor.opacity(colorScheme == .light ? 0.65 : 0.75)
        } else if hasLogs {
            return Color("AppTextPrimary").opacity(0.08)
        } else {
            return Color("AppTextPrimary").opacity(0.03)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.clear
        } else if hasLogs {
            return Color.clear
        } else {
            return Color.clear
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: max(0, phase - 0.3)),
                            .init(color: .white.opacity(0.2), location: max(0, phase - 0.15)),
                            .init(color: .white.opacity(0.4), location: phase),
                            .init(color: .white.opacity(0.2), location: min(1, phase + 0.15)),
                            .init(color: .clear, location: min(1, phase + 0.3)),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: -geometry.size.width)
                    .offset(x: phase * geometry.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Analyzing Progress View

struct AnalyzingProgressView: View {
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color("AppTextPrimary").opacity(0.15), lineWidth: 8)
                .frame(width: 70, height: 70)

            // Spinning arc
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    Color("AppSecondaryAccent"),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isSpinning
                )

            // Analyzing text
            Text("Analyzing")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color("AppTextPrimary").opacity(0.7))
        }
        .onAppear {
            isSpinning = true
        }
    }
}

// MARK: - Blob Shape (Gentle mochi - slightly taller)
struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        
        // Start top center
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        
        // Top right - gentle curve
        path.addCurve(to: CGPoint(x: w, y: h * 0.5),
                      control1: CGPoint(x: w * 0.85, y: 0),
                      control2: CGPoint(x: w, y: h * 0.25))
        
        // Bottom right
        path.addCurve(to: CGPoint(x: w * 0.5, y: h),
                      control1: CGPoint(x: w, y: h * 0.75),
                      control2: CGPoint(x: w * 0.85, y: h))
        
        // Bottom left
        path.addCurve(to: CGPoint(x: 0, y: h * 0.5),
                      control1: CGPoint(x: w * 0.15, y: h),
                      control2: CGPoint(x: 0, y: h * 0.75))
        
        // Top left
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                      control1: CGPoint(x: 0, y: h * 0.25),
                      control2: CGPoint(x: w * 0.15, y: 0))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Blob Shape 2 (Perfect mochi - round)
struct BlobShape2: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        
        // Start top
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        
        // Top right - very smooth
        path.addCurve(to: CGPoint(x: w, y: h * 0.5),
                      control1: CGPoint(x: w * 0.9, y: 0),
                      control2: CGPoint(x: w, y: h * 0.2))
        
        // Bottom right - very smooth
        path.addCurve(to: CGPoint(x: w * 0.5, y: h),
                      control1: CGPoint(x: w, y: h * 0.8),
                      control2: CGPoint(x: w * 0.9, y: h))
        
        // Bottom left - very smooth
        path.addCurve(to: CGPoint(x: 0, y: h * 0.5),
                      control1: CGPoint(x: w * 0.1, y: h),
                      control2: CGPoint(x: 0, y: h * 0.8))
        
        // Top left - very smooth
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                      control1: CGPoint(x: 0, y: h * 0.2),
                      control2: CGPoint(x: w * 0.1, y: 0))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Blob Shape 3 (Squished mochi - slightly wider)
struct BlobShape3: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height
        
        // Start top
        path.move(to: CGPoint(x: w * 0.5, y: 0.02))
        
        // Top right - wide and gentle
        path.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.5),
                      control1: CGPoint(x: w * 0.9, y: 0.05),
                      control2: CGPoint(x: w * 0.98, y: h * 0.2))
        
        // Bottom right - wide and gentle
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.98),
                      control1: CGPoint(x: w * 0.98, y: h * 0.8),
                      control2: CGPoint(x: w * 0.9, y: h * 0.95))
        
        // Bottom left - wide and gentle
        path.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.5),
                      control1: CGPoint(x: w * 0.1, y: h * 0.95),
                      control2: CGPoint(x: w * 0.02, y: h * 0.8))
        
        // Top left - wide and gentle
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0.02),
                      control1: CGPoint(x: w * 0.02, y: h * 0.2),
                      control2: CGPoint(x: w * 0.1, y: 0.05))
        
        path.closeSubpath()
        return path
    }
}
