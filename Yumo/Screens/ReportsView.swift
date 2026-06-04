// Screens/ReportsView.swift

import SwiftUI
import SwiftData
import Charts
import HealthKit
import Auth
import Combine

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var tabRouter: TabRouter
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

    // Cached heavy aggregates — recomputed only when their inputs change.
    // Previously these were computed properties scanning allFoodLogs on every
    // body re-eval, which dropped scroll frames when the snapshot published.
    @State private var cachedLastWeekSummaries: [DaySummary] = []
    @State private var cachedWeeklyDietAnalysis: WeeklyDietStats? = nil

    // Selected-date micronutrient totals. Refreshed on logs / date change.
    @State private var cachedMicronutrients: MicronutrientTotals = .zero

    // Weight-chart precomputed values. Refreshed on weight logs / target /
    // unit system changes — never inside body.
    @State private var cachedWeightChart: WeightChartCache = .empty
    @State private var selectedDateCaloriesEaten: Double = 0
    @State private var showLogWeightSheet: Bool = false
    @State private var showWeightHistory: Bool = false
    @State private var showStrainDetail: Bool = false
    @State private var showSleepTracking: Bool = false
    @State private var isCalendarExpanded: Bool = false
    @State private var selectedReportTab: ReportTab = ReportsView.persistedTab

    enum ReportTab: String, CaseIterable {
        case nutrition = "Nutrition"
        case body = "Body"
        case activity = "Activity"
        case wellness = "Wellness"

        var icon: String {
            switch self {
            case .nutrition: return "fork.knife"
            case .body: return "scalemass"
            case .activity: return "figure.walk"
            case .wellness: return "heart"
            }
        }
    }

    // In-memory so the selected sub-tab survives switching between main tabs.
    // Not persisted to disk — resets on app relaunch.
    private static var persistedTab: ReportTab = .nutrition

    // Chart Selection State
    @State private var selectedWeightX: Date?

    // Number of calorie bars that have grown in. Incremented one-by-one on a
    // timer so each bar gets its own clean spring with no SwiftUI delay quirks.
    @State private var calorieChartBarCount: Int = 0
    @State private var slideInGeneration: Int = 0
    @StateObject private var slideInTracker = ReportsSlideInTracker()

    // Cached date-keyed lookups — recomputed only when food data or the calorie goal
    // changes. The expanded calendar grid has 35+ cells; without these, every scroll-
    // driven body re-eval was rerunning O(allFoodLogs) per cell, melting the main thread.
    @State private var datesWithLogs: Set<Date> = []
    @State private var cachedStreakDates: Set<Date> = []

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
        colorScheme == .dark ? Color("AppCardBackground") : Color.white
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

    private var lastWeekSummaries: [DaySummary] { cachedLastWeekSummaries }

    /// Recomputes both heavy aggregates. Call from .onChange of allFoodLogs,
    /// goals, or selectedDate — never from inside the view body.
    private func recomputeAggregates() {
        cachedLastWeekSummaries = HistoryManager.generateLastWeekSummaries(
            from: allFoodLogs, goals: goals, endDate: selectedDate
        )
        cachedWeeklyDietAnalysis = computeWeeklyDietAnalysis()
        recomputeMicronutrients()
    }

    /// Walks the selected day's food logs once and stores the totals. Single
    /// linear pass instead of four `reduce` calls inside body.
    private func recomputeMicronutrients() {
        var fiber: Double = 0
        var sugar: Double = 0
        var salt: Double = 0
        var potassium: Double = 0
        var count = 0
        for log in allFoodLogs where calendar.isDate(log.timestamp, inSameDayAs: selectedDate) {
            let amount = log.servingAmount
            fiber += log.fiberPerServing * amount
            sugar += log.sugarPerServing * amount
            salt += log.saltPerServing * amount
            potassium += log.potassiumPerServing * amount
            count += 1
        }
        cachedMicronutrients = MicronutrientTotals(
            fiber: fiber, sugar: sugar, salt: salt, potassium: potassium, count: count
        )
    }

    /// Builds the precomputed weight-chart cache. The `@Query` is already
    /// sorted descending by timestamp, so we reverse instead of re-sorting.
    private func recomputeWeightChartCache() {
        let sorted = Array(allWeightLogs.reversed())
        let goalConverted = unitSystem.formatWeight(goals.targetWeight)

        guard !sorted.isEmpty else {
            cachedWeightChart = WeightChartCache(
                sortedLogs: [],
                yMin: goalConverted - 1,
                yMax: goalConverted + 1,
                paddedStartDate: Date(),
                effectiveEndDate: Date().addingTimeInterval(604800),
                targetWeightDisplay: goalConverted
            )
            return
        }

        let cal = Calendar.current
        let minDate = sorted.first!.timestamp
        let maxDate = sorted.last!.timestamp
        let paddedStart = cal.date(byAdding: .day, value: -2, to: minDate) ?? minDate
        let paddedEnd = cal.date(byAdding: .day, value: 5, to: maxDate) ?? maxDate
        let effectiveEnd = paddedEnd.timeIntervalSince(paddedStart) < 604800
            ? paddedStart.addingTimeInterval(604800)
            : paddedEnd

        var minData = Double.greatestFiniteMagnitude
        var maxData = -Double.greatestFiniteMagnitude
        for log in sorted {
            let w = unitSystem.formatWeight(log.weightKg)
            if w < minData { minData = w }
            if w > maxData { maxData = w }
        }

        cachedWeightChart = WeightChartCache(
            sortedLogs: sorted,
            yMin: min(minData, goalConverted) - 1.0,
            yMax: max(maxData, goalConverted) + 1.0,
            paddedStartDate: paddedStart,
            effectiveEndDate: effectiveEnd,
            targetWeightDisplay: goalConverted
        )
    }

    private func animateCalorieChartBars(after delay: Double) {
        calorieChartBarCount = 0
        let barCount = lastWeekSummaries.count
        guard barCount > 0 else { return }
        for i in 1...barCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i - 1) * 0.07) {
                calorieChartBarCount = i
            }
        }
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
            DynamicBackgroundView()

            // Subtle radial accent gradient — light mode only while we tune the
            // new dark palette.
            if colorScheme == .light {
                GeometryReader { proxy in
                    ZStack {
                        Circle()
                            .fill(Color("AppSecondaryAccent").opacity(0.08))
                            .frame(width: proxy.size.width * 0.85)
                            .blur(radius: 90)
                            .offset(x: -proxy.size.width * 0.25, y: -proxy.size.height * 0.2)
                        Circle()
                            .fill(Color("AppPrimaryAccent").opacity(0.07))
                            .frame(width: proxy.size.width * 0.85)
                            .blur(radius: 90)
                            .offset(x: proxy.size.width * 0.25, y: proxy.size.height * 0.25)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

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
                    .slideIn(delay: 0)

                    // Date Selector (compact 7-day or expanded month)
                    _buildDateSelector()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.04)

                    // Today's Activity Summary (always visible)
                    _buildTodayActivitySummary()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.08)

                    // Ad Banner (padding handled internally)
                    ConditionalAdBanner(adUnitID: AdManager.reportsBannerAdUnitID)

                    // MARK: - Tab Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ReportTab.allCases, id: \.self) { tab in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedReportTab = tab
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: tab.icon)
                                            .font(.caption.weight(.semibold))
                                        Text(tab.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(selectedReportTab == tab ? .white : primaryTextColor.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedReportTab == tab
                                                  ? AnyShapeStyle(LinearGradient(
                                                      colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                                      startPoint: .topLeading,
                                                      endPoint: .bottomTrailing
                                                  ))
                                                  : AnyShapeStyle(primaryTextColor.opacity(0.06)))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .slideIn(delay: 0.12)
                }

                // Tab Content
                LazyVStack(spacing: 20) {
                    switch selectedReportTab {
                    case .nutrition:
                        // Net Calories Card
                        _buildNetCaloriesCard()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.16)

                        // 7-Day Calorie Trend (Eaten) — Warm Gradient Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    colorScheme == .dark
                                    ? AnyShapeStyle(Color("AppCardBackground"))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.95, blue: 0.88), Color(red: 1.0, green: 0.90, blue: 0.80)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                )

                            Circle()
                                .fill(Color.orange.opacity(colorScheme == .dark ? 0.08 : 0.1))
                                .frame(width: 120, height: 120)
                                .offset(x: 130, y: -40)

                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(LinearGradient(colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Calories Eaten")
                                            .font(.headline)
                                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.3, green: 0.15, blue: 0.0))
                                        Text("7-day trend")
                                            .font(.caption2)
                                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.5, green: 0.3, blue: 0.1))
                                    }
                                    Spacer()
                                }
                                _buildCalorieChart()
                            }
                            .padding(16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.orange.opacity(colorScheme == .dark ? 0.1 : 0.15), radius: 12, y: 6)
                        .drawingGroup()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.20)

                        // Micronutrient Tracker
                        _buildMicronutrientCard()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.24)

                        // Weekly Diet Analysis
                        if let dietAnalysis = weeklyDietAnalysis {
                            _buildWeeklyDietAnalysisCard(dietAnalysis)
                                .padding(.horizontal, 24)
                                .slideIn(delay: 0.28)
                        }

                    case .body:
                        // Weight Progress Card
                        _buildWeightProgressCard()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.16)

                        // Weight Trend Chart
                        if !allWeightLogs.isEmpty {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        colorScheme == .dark
                                        ? AnyShapeStyle(Color("AppCardBackground"))
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color(red: 0.95, green: 0.95, blue: 0.97), Color(red: 0.9, green: 0.9, blue: 0.93)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                    )
                                RadialGradient(
                                    colors: [primaryAccent.opacity(0.08), Color.clear],
                                    center: .topLeading,
                                    startRadius: 20,
                                    endRadius: 250
                                )
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(LinearGradient(colors: [primaryAccent, primaryAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "scalemass.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Weight Trend")
                                                .font(.headline)
                                                .foregroundStyle(primaryTextColor)
                                            Text("Your journey")
                                                .font(.caption2)
                                                .foregroundStyle(secondaryTextColor)
                                        }
                                        Spacer()
                                    }
                                    _buildWeightChart()
                                        .frame(height: 200)
                                }
                                .padding(16)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: primaryAccent.opacity(colorScheme == .dark ? 0.08 : 0.12), radius: 12, y: 6)
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.20)
                        }

                    case .activity:
                        // 7-Day Burnt Calories — Dark Ember Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    colorScheme == .dark
                                    ? AnyShapeStyle(Color("AppCardBackground"))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 0.12, green: 0.06, blue: 0.06), Color(red: 0.2, green: 0.08, blue: 0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                )
                            if colorScheme == .light {
                                RadialGradient(
                                    colors: [Color.orange.opacity(0.15), Color.clear],
                                    center: .bottomTrailing,
                                    startRadius: 20,
                                    endRadius: 200
                                )
                            }
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle().fill(Color.orange.opacity(0.2)).frame(width: 40, height: 40)
                                        Circle().fill(Color.red.opacity(0.3)).frame(width: 28, height: 28)
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Calories Burnt")
                                            .font(.headline).foregroundStyle(.white)
                                        Text("Active energy")
                                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                }
                                _buildBurntCaloriesChart()
                            }
                            .padding(16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.red.opacity(0.2), radius: 12, y: 6)
                        .drawingGroup()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.16)

                        // 7-Day Steps — Nature Green Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    colorScheme == .dark
                                    ? AnyShapeStyle(Color("AppCardBackground"))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 0.92, green: 0.98, blue: 0.93), Color(red: 0.85, green: 0.95, blue: 0.88)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                )
                            HStack(spacing: 8) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(secondaryAccent.opacity(Double(i + 1) * 0.05))
                                        .frame(width: CGFloat(8 + i * 3), height: CGFloat(8 + i * 3))
                                }
                            }
                            .offset(x: 80, y: -50)
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(LinearGradient(colors: [secondaryAccent, secondaryAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Steps")
                                            .font(.headline)
                                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.1, green: 0.3, blue: 0.15))
                                        Text("Keep moving")
                                            .font(.caption2)
                                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.2, green: 0.5, blue: 0.3))
                                    }
                                    Spacer()
                                    Image(systemName: "shoeprints.fill")
                                        .font(.title3)
                                        .foregroundStyle(secondaryAccent.opacity(0.3))
                                }
                                _buildStepsChart()
                            }
                            .padding(16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: secondaryAccent.opacity(colorScheme == .dark ? 0.1 : 0.15), radius: 12, y: 6)
                        .drawingGroup()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.20)

                        // 7-Day Strain — Intense Energy Card
                        if healthManager.weeklyStrain.count >= 2 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        colorScheme == .dark
                                        ? AnyShapeStyle(Color("AppCardBackground"))
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color(red: 0.18, green: 0.06, blue: 0.04), Color(red: 0.22, green: 0.1, blue: 0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                    )
                                if colorScheme == .light {
                                    RadialGradient(
                                        colors: [Color.red.opacity(0.12), Color.orange.opacity(0.06), Color.clear],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 200
                                    )
                                }
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.orange.opacity(0.2)).frame(width: 40, height: 40)
                                            Circle().fill(Color.red.opacity(0.25)).frame(width: 28, height: 28)
                                            Image(systemName: "bolt.heart.fill")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Strain")
                                                .font(.headline).foregroundStyle(.white)
                                            let avgStrain = healthManager.weeklyStrain.reduce(0.0) { $0 + $1.strain } / Double(healthManager.weeklyStrain.count)
                                            Text("Avg \(String(format: "%.1f", avgStrain)) / 21")
                                                .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        Image(systemName: "waveform.path.ecg")
                                            .font(.title3)
                                            .foregroundStyle(.orange.opacity(0.3))
                                    }
                                    Chart {
                                        ForEach(Array(healthManager.weeklyStrain.enumerated()), id: \.offset) { _, point in
                                            BarMark(
                                                x: .value("Day", point.date, unit: .day),
                                                y: .value("Strain", point.strain)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [_strainColor(point.strain).opacity(0.4), _strainColor(point.strain)],
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                            .cornerRadius(6)
                                        }
                                    }
                                    .chartYScale(domain: 0...21)
                                    .chartYAxis {
                                        AxisMarks(values: [0, 7, 14, 21]) { value in
                                            AxisValueLabel {
                                                Text("\(value.as(Double.self).map { Int($0) } ?? 0)")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 140)
                                }
                                .padding(16)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.red.opacity(0.15), radius: 12, y: 6)
                            .drawingGroup()
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                showStrainDetail = true
                            }
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.24)
                        }

                        // 6-month Weekly Mileage History
                        _buildWeeklyMileageHistoryCard()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.28)

                    case .wellness:
                        // Last Night Sleep Report (tap to view full tracking)
                        if healthManager.lastNightSleep != nil {
                            _buildSleepReportWidget()
                                .padding(.horizontal, 24)
                                .slideIn(delay: 0.16)
                        }

                        // 7-Day Water — Ocean Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    colorScheme == .dark
                                    ? AnyShapeStyle(Color("AppCardBackground"))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Color(red: 0.88, green: 0.94, blue: 1.0), Color(red: 0.82, green: 0.9, blue: 1.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                )
                            Ellipse()
                                .fill(Color.blue.opacity(colorScheme == .dark ? 0.08 : 0.06))
                                .frame(height: 120)
                                .offset(y: 60)
                                .clipped()
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.2, green: 0.4, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "drop.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Water Intake")
                                            .font(.headline)
                                            .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.1, green: 0.2, blue: 0.45))
                                        Text("Stay hydrated")
                                            .font(.caption2)
                                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.3, green: 0.45, blue: 0.7))
                                    }
                                    Spacer()
                                    Image(systemName: "humidity.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue.opacity(0.3))
                                }
                                _buildWaterChart()
                            }
                            .padding(16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.15), radius: 12, y: 6)
                        .drawingGroup()
                        .padding(.horizontal, 24)
                        .slideIn(delay: 0.20)

                        // 7-Day Sleep — Night Sky Card
                        if !healthManager.weeklySleep.isEmpty {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.06, green: 0.04, blue: 0.18), Color(red: 0.12, green: 0.06, blue: 0.28)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                ZStack {
                                    Circle().fill(Color.white.opacity(0.12)).frame(width: 3, height: 3).offset(x: -100, y: -60)
                                    Circle().fill(Color.white.opacity(0.08)).frame(width: 2, height: 2).offset(x: -30, y: -45)
                                    Circle().fill(Color.white.opacity(0.15)).frame(width: 4, height: 4).offset(x: 100, y: -65)
                                    Circle().fill(Color.white.opacity(0.06)).frame(width: 2, height: 2).offset(x: 130, y: -35)
                                    Circle().fill(Color.indigo.opacity(0.06)).frame(width: 100, height: 100).offset(x: 130, y: 40)
                                }
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle().fill(Color.indigo.opacity(0.3)).frame(width: 40, height: 40)
                                            Image(systemName: "moon.zzz.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Sleep")
                                                .font(.headline).foregroundStyle(.white)
                                            let avgSleep = healthManager.weeklySleep.reduce(0.0) { $0 + $1.totalSleepHours } / Double(healthManager.weeklySleep.count)
                                            Text("Avg \(String(format: "%.1f", avgSleep))h / night")
                                                .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                        }
                                        Spacer()
                                        Image(systemName: "bed.double.fill")
                                            .font(.title3)
                                            .foregroundStyle(.indigo.opacity(0.3))
                                    }
                                    Chart {
                                        ForEach(healthManager.weeklySleep) { night in
                                            BarMark(
                                                x: .value("Day", night.date, unit: .day),
                                                y: .value("Hours", night.totalSleepHours)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.purple.opacity(0.5), .indigo, .indigo.opacity(0.8)],
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                            .cornerRadius(6)
                                        }
                                        RuleMark(y: .value("Target", 8))
                                            .foregroundStyle(.green.opacity(0.5))
                                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                            .annotation(position: .top, alignment: .trailing) {
                                                Text("8h goal")
                                                    .font(.system(size: 8, weight: .medium))
                                                    .foregroundStyle(.green.opacity(0.8))
                                            }
                                    }
                                    .chartYScale(domain: 0...12)
                                    .chartYAxis {
                                        AxisMarks(values: [0, 4, 8, 12]) { value in
                                            AxisValueLabel {
                                                Text("\(value.as(Double.self).map { Int($0) } ?? 0)h")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 140)
                                }
                                .padding(16)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.indigo.opacity(0.2), radius: 12, y: 6)
                            .drawingGroup()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.24)
                        }

                        // Recovery vs Strain — Dual-Tone Card
                        if healthManager.weeklyRecoverySleep.count >= 2 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        colorScheme == .dark
                                        ? AnyShapeStyle(Color("AppCardBackground"))
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color(red: 0.92, green: 0.97, blue: 0.93), Color(red: 0.98, green: 0.95, blue: 0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                    )
                                if colorScheme == .light {
                                    HStack(spacing: 0) {
                                        RadialGradient(colors: [Color.green.opacity(0.08), Color.clear], center: .center, startRadius: 10, endRadius: 150)
                                        RadialGradient(colors: [Color.orange.opacity(0.08), Color.clear], center: .center, startRadius: 10, endRadius: 150)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(LinearGradient(colors: [.green, .orange], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "heart.text.square.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Recovery vs Strain")
                                                .font(.headline)
                                                .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.15, green: 0.2, blue: 0.15))
                                            Text("Balance training load")
                                                .font(.caption2)
                                                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.35, green: 0.4, blue: 0.35))
                                        }
                                        Spacer()
                                        HStack(spacing: 10) {
                                            HStack(spacing: 4) {
                                                Circle().fill(.green).frame(width: 7, height: 7)
                                                Text("Recovery").font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.3, green: 0.5, blue: 0.3))
                                            }
                                            HStack(spacing: 4) {
                                                Circle().fill(.orange).frame(width: 7, height: 7)
                                                Text("Strain").font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 0.5, green: 0.35, blue: 0.2))
                                            }
                                        }
                                    }
                                    Chart {
                                        ForEach(Array(healthManager.weeklyRecoverySleep.enumerated()), id: \.offset) { _, point in
                                            LineMark(
                                                x: .value("Day", point.date, unit: .day),
                                                y: .value("Recovery", point.recovery),
                                                series: .value("Type", "Recovery")
                                            )
                                            .foregroundStyle(.green)
                                            .interpolationMethod(.catmullRom)
                                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                                            LineMark(
                                                x: .value("Day", point.date, unit: .day),
                                                y: .value("Strain", (point.strain / 21.0) * 100),
                                                series: .value("Type", "Strain")
                                            )
                                            .foregroundStyle(.orange)
                                            .interpolationMethod(.catmullRom)
                                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                                        }
                                    }
                                    .chartYScale(domain: 0...100)
                                    .chartYAxis {
                                        AxisMarks(values: [0, 50, 100]) { value in
                                            AxisValueLabel {
                                                Text("\(value.as(Double.self).map { Int($0) } ?? 0)%")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 0.4, green: 0.4, blue: 0.4))
                                            }
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                                        .font(.system(size: 9, weight: .medium))
                                                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 0.4, green: 0.4, blue: 0.4))
                                                }
                                            }
                                        }
                                    }
                                    .chartForegroundStyleScale([
                                        "Recovery": Color.green,
                                        "Strain": Color.orange
                                    ])
                                    .chartLegend(.hidden)
                                    .frame(height: 140)
                                }
                                .padding(16)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.green.opacity(colorScheme == .dark ? 0.08 : 0.1), radius: 12, y: 6)
                            .drawingGroup()
                            .padding(.horizontal, 24)
                            .slideIn(delay: 0.28)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 100)
                .readableContentColumn(640)
            }
            .environment(\.reportsSlideInGeneration, slideInGeneration)
            .environmentObject(slideInTracker)
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
                    .background(cardBackground)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: colorScheme == .dark ? 0 : 10, y: colorScheme == .dark ? 0 : 4)
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
            
            // Removed manual gradient overlay for performance.
        }
        .onAppear {
            animateOrbs()
            rebuildDateCaches()
            recomputeWeightChartCache()
            Task {
                try? await healthManager.requestAuthorization()
                await refreshData()
            }
        }
        .onChange(of: allFoodLogs.count) { _, _ in
            rebuildDateCaches()
            recomputeMicronutrients()
        }
        .onChange(of: goals.dailyCalories) { _, _ in
            rebuildDateCaches()
        }
        .onChange(of: allWeightLogs.count) { _, _ in
            recomputeWeightChartCache()
        }
        .onChange(of: goals.targetWeight) { _, _ in
            recomputeWeightChartCache()
        }
        .onChange(of: goals.unitSystem) { _, _ in
            recomputeWeightChartCache()
        }
        .onChange(of: selectedDate) { _, newDate in
            recomputeAggregates()
            Task {
                await healthManager.fetchActivity(for: newDate)
                await healthManager.fetchWeeklyBurntCalories(endDate: newDate)
                updateCaloriesForSelectedDate()
                fetchWeeklySteps(endDate: newDate)
                weeklyWater = generateWeeklyWater(endDate: newDate)
            }
        }
        .onChange(of: selectedReportTab) { _, newTab in
            Self.persistedTab = newTab
        }
        .onChange(of: tabRouter.selectedTab) { _, newTab in
            guard newTab == .reports else { return }
            slideInGeneration += 1
            animateCalorieChartBars(after: 0.35)
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
        .sheet(isPresented: $showStrainDetail) {
            StrainActivityView()
        }
        .sheet(isPresented: $showSleepTracking) {
            SleepTrackingView()
        }
    }

    // MARK: - Sleep Report Widget
    @ViewBuilder
    private func _buildSleepReportWidget() -> some View {
        if let sleep = healthManager.lastNightSleep {
            Button {
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
                showSleepTracking = true
            } label: {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.05, blue: 0.12), Color(red: 0.15, green: 0.1, blue: 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    GeometryReader { _ in
                        Circle().fill(Color.white.opacity(0.04)).frame(width: 80, height: 80).position(x: 30, y: 10)
                        Circle().fill(Color.white.opacity(0.02)).frame(width: 140, height: 140).position(x: 320, y: 100)
                        Circle().fill(Color.white.opacity(0.1)).frame(width: 4, height: 4).position(x: 180, y: 30)
                        Circle().fill(Color.white.opacity(0.06)).frame(width: 2, height: 2).position(x: 230, y: 15)
                        Circle().fill(Color.yellow.opacity(0.1)).frame(width: 6, height: 6).position(x: 280, y: 40)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.25))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "moon.stars.fill")
                                    .font(.headline)
                                    .foregroundStyle(Color.yellow.opacity(0.9))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sleep Report")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Last Night")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()

                            Text(SleepData.formatDuration(sleep.totalSleepSeconds))
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }

                        Divider()
                            .background(Color.white.opacity(0.15))

                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quality")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))

                                let qualityColor: Color = {
                                    switch sleep.sleepQualityColor {
                                    case "green": return .green
                                    case "yellow": return .yellow
                                    case "orange": return .orange
                                    default: return .red
                                    }
                                }()

                                Text(sleep.sleepQuality)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(qualityColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Deep Sleep")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(SleepData.formatDuration(sleep.deepSleepSeconds))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("In Bed")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(SleepData.formatDuration(sleep.timeInBedSeconds))
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 6-Month Weekly Mileage History
    @ViewBuilder
    private func _buildWeeklyMileageHistoryCard() -> some View {
        WeeklyMileageHistoryCard(isImperial: goals.unitSystem == .imperial)
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

    // MARK: - Weekly Diet Analysis

    struct WeeklyDietStats {
        let avgProtein: Double
        let avgCarbs: Double
        let avgFat: Double
        let avgFiber: Double
        let avgSugar: Double
        let avgSalt: Double
        let avgPotassium: Double
        let focusTitle: String
        let focusMessage: String
        let focusColor: Color
    }

    /// Body reads this through the cached aggregate; recomputed via
    /// `recomputeAggregates()` only when allFoodLogs / goals change.
    private var weeklyDietAnalysis: WeeklyDietStats? { cachedWeeklyDietAnalysis }

    private func computeWeeklyDietAnalysis() -> WeeklyDietStats? {
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }

        let weekLogs = allFoodLogs.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
        if weekLogs.isEmpty { return nil }

        var totalP = 0.0, totalC = 0.0, totalF = 0.0
        var totalFiber = 0.0, totalSugar = 0.0, totalSalt = 0.0, totalPotassium = 0.0

        for log in weekLogs {
            totalP += log.totalProtein
            totalC += log.totalCarbs
            totalF += log.totalFat
            totalFiber += (log.fiberPerServing * log.servingAmount)
            totalSugar += (log.sugarPerServing * log.servingAmount)
            totalSalt += (log.saltPerServing * log.servingAmount)
            totalPotassium += (log.potassiumPerServing * log.servingAmount)
        }

        let daysUsed = 7.0
        let avgP = totalP / daysUsed
        let avgC = totalC / daysUsed
        let avgF = totalF / daysUsed
        let avgFiber = totalFiber / daysUsed
        let avgS = totalSugar / daysUsed
        let avgSalt = totalSalt / daysUsed
        let avgK = totalPotassium / daysUsed

        let gP = goals.dailyProtein > 0 ? goals.dailyProtein : 150
        let gC = goals.dailyCarbs > 0 ? goals.dailyCarbs : 200
        let gF = goals.dailyFat > 0 ? goals.dailyFat : 60
        let gS = 50.0
        let gK = 3500.0

        var title = "Balanced"
        var msg = "Your diet is well balanced this week. Keep it up!"
        var color = Color.green

        if avgS > gS * 1.5 {
            let diff = Int(avgS - gS)
            title = "Sugar Spike"
            msg = "You're averaging \(Int(avgS))g sugar (\(diff)g over). Try cutting visible sugars."
            color = .red
        } else if avgP < gP * 0.8 {
            let diff = Int(gP - avgP)
            title = "Protein"
            msg = "You are lacking \(diff)g avg. Add chicken, tofu, or greek yogurt."
            color = .purple
        } else if avgC < gC * 0.7 {
            let diff = Int(gC - avgC)
            title = "Carbs"
            msg = "Energy levels might be low. You're missing \(diff)g carbs avg."
            color = .blue
        } else if avgK < gK * 0.6 {
            title = "Micronutrients"
            msg = "Potassium is low (\(Int(avgK))mg avg). Eat more bananas or potatoes."
            color = .orange
        } else if avgF > gF * 1.3 {
            let diff = Int(avgF - gF)
            title = "Fat Intake"
            msg = "Fat intake is high (\(diff)g over). Watch out for oils and fried food."
            color = .orange
        }

        return WeeklyDietStats(
            avgProtein: avgP, avgCarbs: avgC, avgFat: avgF,
            avgFiber: avgFiber, avgSugar: avgS, avgSalt: avgSalt,
            avgPotassium: avgK, focusTitle: title, focusMessage: msg, focusColor: color
        )
    }

    @ViewBuilder
    private func _buildWeeklyDietAnalysisCard(_ dietAnalysis: WeeklyDietStats) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.blue)
                    Text("Weekly Average")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus on: ")
                        .font(.title3)
                        .foregroundStyle(primaryTextColor)
                    + Text(dietAnalysis.focusTitle)
                        .font(.title3.bold())
                        .foregroundStyle(primaryTextColor)

                    Text(dietAnalysis.focusMessage)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 16) {
                    _buildAnalysisMacroRow(name: "Protein", current: dietAnalysis.avgProtein, goal: goals.dailyProtein, color: .purple)
                    _buildAnalysisMacroRow(name: "Carbs", current: dietAnalysis.avgCarbs, goal: goals.dailyCarbs, color: .blue)
                    _buildAnalysisMacroRow(name: "Fat", current: dietAnalysis.avgFat, goal: goals.dailyFat, color: .orange)

                    Divider().padding(.vertical, 4)

                    _buildAnalysisMacroRow(name: "Fiber", current: dietAnalysis.avgFiber, goal: 30, color: .green)
                    _buildAnalysisMacroRow(name: "Sugar", current: dietAnalysis.avgSugar, goal: 50, color: dietAnalysis.avgSugar > 50 ? .pink : .green)
                    _buildAnalysisMacroRow(name: "Sodium", current: dietAnalysis.avgSalt, goal: 2300, color: .gray)
                    _buildAnalysisMacroRow(name: "Potassium", current: dietAnalysis.avgPotassium, goal: 3500, color: .yellow)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: colorScheme == .dark ? 0 : 10, y: colorScheme == .dark ? 0 : 4)
    }

    @ViewBuilder
    private func _buildAnalysisMacroRow(name: String, current: Double, goal: Double, color: Color) -> some View {
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
                        .fill(tertiaryTextColor.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * (current / max(goal, 1)), geo.size.width))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Micronutrient Tracker
    @ViewBuilder
    private func _buildMicronutrientCard() -> some View {
        let micros = cachedMicronutrients
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Micronutrients")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    if micros.count > 0 {
                        Text("\(micros.count) items")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                VStack(spacing: 16) {
                    _buildMicroRow(name: "Fiber", value: micros.fiber, unit: "g", color: .green, icon: "leaf.fill")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Sugar", value: micros.sugar, unit: "g", color: .pink, icon: "cube.fill")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Salt", value: micros.salt, unit: "g", color: .gray, icon: "sparkles")
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    _buildMicroRow(name: "Potassium", value: micros.potassium, unit: "mg", color: .purple, icon: "bolt.fill")
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

        // Pre-compute the heavy aggregates once now that inputs are loaded —
        // body reads cached values, so scroll re-evals stay cheap.
        recomputeAggregates()

        // Update calories for initial load
        updateCaloriesForSelectedDate()
        
        // Fetch HealthKit data for selected date
        await healthManager.fetchActivity(for: selectedDate)
        await healthManager.fetchWeeklyBurntCalories(endDate: selectedDate)
        await healthManager.fetchLatestWeight()
        
        // Fetch Steps
        fetchWeeklySteps(endDate: selectedDate)
        
        weeklyWater = generateWeeklyWater(endDate: selectedDate)
        
        // Phase 2: Fetch strain & recovery trends
        await healthManager.fetchRecoveryData()
        await healthManager.fetchStrainData()
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
    private func _strainColor(_ strain: Double) -> Color {
        if strain >= 18 { return .red }
        if strain >= 14 { return .orange }
        if strain >= 7 { return .green }
        return .blue
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
    private func dateHasLogs(_ date: Date) -> Bool {
        datesWithLogs.contains(calendar.startOfDay(for: date))
    }

    /// Single-pass rebuild of the date-keyed caches. Called from `.onAppear` and
    /// `.onChange(of: allFoodLogs.count / goals.dailyCalories)`.
    private func rebuildDateCaches() {
        let standalone = allFoodLogs.filter { $0.recipe == nil }
        let grouped = Dictionary(grouping: standalone) { calendar.startOfDay(for: $0.timestamp) }

        // Set of all days that have at least one standalone log.
        datesWithLogs = Set(grouped.keys)

        // Streak: walk back from today while each day's calories ≥ 80% of the daily goal.
        guard goals.dailyCalories > 0 else {
            cachedStreakDates = []
            return
        }
        let today = Date().startOfDay
        guard let todayLogs = grouped[today] else {
            cachedStreakDates = []
            return
        }
        let goalThreshold = goals.dailyCalories * 0.8
        let todayCalories = todayLogs.reduce(0) { $0 + $1.totalCalories }
        guard todayCalories >= goalThreshold else {
            cachedStreakDates = []
            return
        }

        var streak: Set<Date> = [today]
        var checkDate = today
        while let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate),
              let logs = grouped[previousDay],
              logs.reduce(0, { $0 + $1.totalCalories }) >= goalThreshold
        {
            streak.insert(previousDay)
            checkDate = previousDay
        }
        cachedStreakDates = streak
    }

    // MARK: - Date Selector
    @ViewBuilder
    private func _buildDateSelector() -> some View {
        let last7Days = getLast7Days()
        let streakDates = cachedStreakDates

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
                .padding(.horizontal, 4)

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
        let data = healthManager.weeklyBurntCalories
        let avg = data.isEmpty ? 0 : data.reduce(0) { $0 + convertEnergy($1.calories) } / Double(data.count)
        let maxValue = max(data.map { convertEnergy($0.calories) }.max() ?? 500, avg * 1.5)

        VStack(alignment: .leading, spacing: 12) {
            Text("Avg: \(Int(avg)) \(goals.energyUnit == .kilojoules ? "kJ" : "kcal")")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { item in
                    let val = convertEnergy(item.calories)
                    VStack(spacing: 6) {
                        let height = CGFloat(min(val / max(maxValue, 1), 1.0)) * 110
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 16, height: 110)
                            
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [.yellow, .orange, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 16, height: max(height, 8))
                                .opacity(val == 0 ? 0 : 1)
                                .shadow(color: .orange.opacity(val == 0 ? 0 : 0.4), radius: 4, y: 2)
                        }
                        Text(item.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .drawingGroup()
        }
    }

    @ViewBuilder
    private func _buildStepsChart() -> some View {
        let avg = weeklySteps.isEmpty ? 0 : weeklySteps.reduce(0) { $0 + $1.steps } / Double(weeklySteps.count)
        let maxValue = max(weeklySteps.map { $0.steps }.max() ?? 5000, avg * 1.5)

        VStack(alignment: .leading, spacing: 12) {
            Text("Avg: \(Int(avg)) steps")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 0.2, green: 0.4, blue: 0.25))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklySteps, id: \.date) { item in
                    VStack(spacing: 6) {
                        let height = CGFloat(min(item.steps / max(maxValue, 1), 1.0)) * 110
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(secondaryAccent.opacity(0.1))
                                .frame(width: 18, height: 110)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [secondaryAccent, secondaryAccent.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 18, height: max(height, 8))
                                .opacity(item.steps == 0 ? 0 : 1)
                        }
                        Text(item.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 0.3, green: 0.5, blue: 0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .drawingGroup()
        }
    }

    @ViewBuilder
    private func _buildWaterChart() -> some View {
        let avg = weeklyWater.isEmpty ? 0 : weeklyWater.reduce(0) { $0 + $1.amountML } / Double(weeklyWater.count)
        let goal = goals.dailyWaterML
        let maxValue = max(weeklyWater.map { $0.amountML }.max() ?? 2000, max(goal, avg * 1.5))

        VStack(alignment: .leading, spacing: 12) {
            Text("Avg: \(Int(avg)) ml")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 0.2, green: 0.35, blue: 0.6))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weeklyWater, id: \.date) { item in
                    VStack(spacing: 6) {
                        let val = item.amountML
                        let height = CGFloat(min(val / max(maxValue, 1), 1.0)) * 110
                        let metGoal = val >= goal
                        
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.08))
                                .frame(width: 16, height: 110)
                            
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: metGoal
                                            ? [Color(red: 0.2, green: 0.7, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)]
                                            : [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.45, blue: 0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 16, height: max(height, 8))
                                .opacity(val == 0 ? 0 : 1)
                        }
                        Text(item.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 0.3, green: 0.45, blue: 0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .drawingGroup()
        }
    }
    
    @ViewBuilder
    private func _buildCalorieChart() -> some View {
        let sortedData = lastWeekSummaries.sorted { $0.date < $1.date }
        let avg = sortedData.isEmpty ? 0 : sortedData.reduce(0) { $0 + convertEnergy($1.totalCalories) } / Double(sortedData.count)
        let maxValue = max(sortedData.map { convertEnergy($0.totalCalories) }.max() ?? 2000, avg * 1.3)
        let goal = convertEnergy(Double(goals.dailyCalories))

        VStack(alignment: .leading, spacing: 12) {
            Text("Avg: \(Int(avg)) \(goals.energyUnit == .kilojoules ? "kJ" : "kcal")")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 0.5, green: 0.3, blue: 0.1))
                
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(sortedData.enumerated()), id: \.element.date) { index, day in
                    let val = convertEnergy(day.totalCalories)
                    let targetHeight = max(CGFloat(min(val / max(maxValue, 1), 1.0)) * 110, 8)

                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.orange.opacity(colorScheme == .dark ? 0.1 : 0.12))
                                .frame(width: 14, height: 110)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    val > goal * 1.1 ?
                                        LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) :
                                    val < goal * 0.8 ?
                                        LinearGradient(colors: [Color(red: 1.0, green: 0.7, blue: 0.3), .orange], startPoint: .top, endPoint: .bottom) :
                                        LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 0.4), .green], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 14, height: index < calorieChartBarCount ? targetHeight : 0)
                                .opacity(val == 0 ? 0 : (index < calorieChartBarCount ? 1 : 0))
                                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: calorieChartBarCount)
                        }

                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.5) : Color(red: 0.5, green: 0.3, blue: 0.1))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            animateCalorieChartBars(after: 0.35)
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
        let cache = cachedWeightChart
        let sortedLogs = cache.sortedLogs
        let targetWeightDisplay = cache.targetWeightDisplay
        let yMin = cache.yMin
        let yMax = cache.yMax
        let paddedStartDate = cache.paddedStartDate
        let effectiveEndDate = cache.effectiveEndDate

        let goalLineColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.35)
        let areaGradient = Gradient(colors: [
            primaryAccent.opacity(0.4),
            primaryAccent.opacity(0.05)
        ])

        // Selected point depends on the live scrub position; cheap O(n) over
        // already-sorted logs.
        let selectedLog: LoggedWeight? = {
            guard let date = selectedWeightX else { return nil }
            return sortedLogs.min(by: {
                abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
            })
        }()

        Chart {
            // Target weight line
            RuleMark(y: .value("Goal", targetWeightDisplay))
                .lineStyle(.init(lineWidth: 1, dash: [6, 6]))
                .foregroundStyle(goalLineColor)

            ForEach(sortedLogs) { log in
                let weightDisplay = unitSystem.formatWeight(log.weightKg)
                
                AreaMark(
                    x: .value("Date", log.timestamp),
                    yStart: .value("Base", yMin),
                    yEnd: .value("Weight", weightDisplay)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(gradient: areaGradient, startPoint: .top, endPoint: .bottom))

                LineMark(
                    x: .value("Date", log.timestamp),
                    y: .value("Weight", weightDisplay)
                )
                .interpolationMethod(.monotone)
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(primaryAccent)
            }
            
            if let selected = selectedLog {
                RuleMark(x: .value("Selected", selected.timestamp))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.2))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(spacing: 4) {
                            Text(selected.timestamp.formatted(.dateTime.month().day()))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text("\(unitSystem.formatWeight(selected.weightKg), specifier: "%.1f") \(weightUnit)")
                                .font(.headline.bold())
                                .foregroundStyle(primaryTextColor)
                        }
                        .padding(8)
                        .background(colorScheme == .dark ? Color("AppCardBackground") : Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                    }
                
                PointMark(
                    x: .value("Date", selected.timestamp),
                    y: .value("Weight", unitSystem.formatWeight(selected.weightKg))
                )
                .symbol(.circle)
                .symbolSize(150)
                .foregroundStyle(cardBackground)

                PointMark(
                    x: .value("Date", selected.timestamp),
                    y: .value("Weight", unitSystem.formatWeight(selected.weightKg))
                )
                .symbol(.circle)
                .symbolSize(120)
                .foregroundStyle(primaryAccent)
            }
        }
        .chartXSelection(value: $selectedWeightX)
        .chartXScale(domain: paddedStartDate...effectiveEndDate)
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
        .chartYScale(domain: yMin...yMax)
    }

    // Calorie chart was replaced in the chunk above combined with others.
    // This empty chunk targets the _buildCalorieChart function to ensure it's removed appropriately 
    // but the logic above actually REPLACES the function definitions in the single block
    // Wait, I need to make sure I am replacing the _buildCalorieChart as well.
    // The previous chunk (EndLine: 1424) REPLACED _buildBurnt, _buildSteps, _buildWater.
    // I need to add _buildCalorieChart replacement to that chunk or a separate one.
    // The above chunk DOES include _buildCalorieChart at the end.
    // But I must target the original _buildCalorieChart lines.
    // Original _buildCalorieChart starts around 1319 and ends at 1424.
    // Original _buildBurnt (1001) ... _buildWater (1097).
    // The previous replacements spanned strictly 1001-1424? No.
    // My previous chunk targeted 1001 to 1424, which actually covers Burnt, Steps, Water, WeightProgressCard??
    // NO! WeightProgressCard is at 1100!
    // I must separate the chunks carefully.
    
    // Chunk 1: Replace Burnt, Steps, Water (Lines 1001 - 1097)
    // Chunk 2: Replace Calorie Chart (Lines 1319 - 1424)


    private func animateOrbs() {
        // Animation handled in DynamicBackgroundView
    }
}

// MARK: - Cached Aggregate Types

/// Per-day micronutrient totals used by `_buildMicronutrientCard`. Keeping
/// this as a value type means the SwiftUI body just reads precomputed
/// numbers instead of running four `reduce` passes per render.
private struct MicronutrientTotals {
    let fiber: Double
    let sugar: Double
    let salt: Double
    let potassium: Double
    let count: Int

    static let zero = MicronutrientTotals(fiber: 0, sugar: 0, salt: 0, potassium: 0, count: 0)
}

/// Pre-derived inputs for the weight chart so the body never sorts or scans
/// `allWeightLogs` itself. Refreshed on weight-log / goal / unit changes.
private struct WeightChartCache {
    let sortedLogs: [LoggedWeight]
    let yMin: Double
    let yMax: Double
    let paddedStartDate: Date
    let effectiveEndDate: Date
    let targetWeightDisplay: Double

    static let empty = WeightChartCache(
        sortedLogs: [],
        yMin: 0,
        yMax: 100,
        paddedStartDate: Date(),
        effectiveEndDate: Date().addingTimeInterval(604800),
        targetWeightDisplay: 0
    )
}

// MARK: - Activity Stat Card
struct ActivityStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color("AppCardBackground") : Color.white
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
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: colorScheme == .dark ? 0 : 8, y: colorScheme == .dark ? 0 : 4)
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

// MARK: - Slide-in animation

private struct ReportsSlideInGenerationKey: EnvironmentKey {
    static let defaultValue: Int = 0
}
private extension EnvironmentValues {
    var reportsSlideInGeneration: Int {
        get { self[ReportsSlideInGenerationKey.self] }
        set { self[ReportsSlideInGenerationKey.self] = newValue }
    }
}

/// Tracks which slide-in delays have already animated for the current generation.
/// Survives `LazyVStack` view recycling (which would otherwise reset @State and
/// replay the animation each time a card scrolls back into view).
private final class ReportsSlideInTracker: ObservableObject {
    var fired: Set<Double> = []
    var generation: Int = 0
}

private struct ReportsSlideIn: ViewModifier {
    let delay: Double
    @Environment(\.reportsSlideInGeneration) private var generation
    @EnvironmentObject private var tracker: ReportsSlideInTracker
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear { triggerIfNeeded() }
            .onChange(of: generation) { _, newGen in
                if tracker.generation != newGen {
                    tracker.generation = newGen
                    tracker.fired.removeAll()
                }
                visible = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    visible = true
                }
                tracker.fired.insert(delay)
            }
    }

    private func triggerIfNeeded() {
        // Reset the tracker if the generation bumped while this card was offscreen.
        if tracker.generation != generation {
            tracker.generation = generation
            tracker.fired.removeAll()
        }
        if tracker.fired.contains(delay) {
            // Already played this intro — show fully visible without animating.
            visible = true
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
            visible = true
        }
        tracker.fired.insert(delay)
    }
}

private extension View {
    func slideIn(delay: Double = 0) -> some View {
        modifier(ReportsSlideIn(delay: delay))
    }
}
