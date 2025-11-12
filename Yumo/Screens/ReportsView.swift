// Screens/ReportsView.swift

import SwiftUI
import SwiftData
import Charts
import HealthKit

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var allFoodLogs: [LoggedFood] = []
    @State private var allWaterLogs: [LoggedWater] = []
    @State private var goals: UserGoals = UserGoals()
    @State private var selectedDate: Date = Date().startOfDay
    @State private var currentMonth: Date = Date()
    @State private var weeklySteps: [(date: Date, steps: Double)] = []
    @State private var weeklyWater: [(date: Date, amountML: Double)] = []

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

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

    private var lastWeekSummaries: [DaySummary] {
        HistoryManager.generateLastWeekSummaries(from: allFoodLogs, goals: goals)
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reports")
                            .font(.title2).fontWeight(.medium).foregroundStyle(secondaryTextColor)
                        Text("Insights & Trends")
                            .font(.largeTitle).fontWeight(.bold).foregroundStyle(primaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                    // Month Calendar with Streak
                    _buildMonthCalendar()
                        .padding(.horizontal, 24)

                    // 7-Day Calorie Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("7-Day Calorie Trend")
                                .font(.headline).foregroundStyle(primaryTextColor)

                            _buildCalorieChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 7-Day Steps Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("7-Day Steps Trend")
                                .font(.headline).foregroundStyle(primaryTextColor)

                            _buildStepsChart()
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal, 24)

                    // 7-Day Water Trend
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("7-Day Water Trend")
                                .font(.headline).foregroundStyle(primaryTextColor)

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
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            Task { await refreshData() }
            requestHealthKitPermissionIfNeeded()
        }
    }

    // MARK: - Data
    private func refreshData() async {
        allFoodLogs = await UserScopedQuery.fetchFoodLogs(context: modelContext)
        allWaterLogs = await UserScopedQuery.fetchWaterLogs(context: modelContext)
        if let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
            goals = fetchedGoals
        }
        weeklyWater = generateWeeklyWater()
    }

    // MARK: - HealthKit Steps
    private func requestHealthKitPermissionIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            if success {
                fetchWeeklySteps()
            } else if let error = error {
                print("HealthKit auth failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Water
    private func generateWeeklyWater() -> [(Date, Double)] {
        let endDate = Date()
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

    private func fetchWeeklySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let endDate = Date()
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

    // MARK: - Streak Logic
    private func getStreakDates() -> Set<Date> {
        guard goals.dailyCalories > 0 else { return [] }
        let today = Date().startOfDay
        let grouped = Dictionary(grouping: allFoodLogs) { calendar.startOfDay(for: $0.timestamp) }

        var streakDates = Set<Date>()
        var checkDate = today

        // Check today first
        if let todayLogs = grouped[today] {
            let todayCalories = todayLogs.reduce(0) { $0 + $1.totalCalories }
            if todayCalories >= goals.dailyCalories * 0.8 {
                streakDates.insert(today)
            } else {
                return streakDates // Streak broken, return early
            }
        } else {
            return streakDates // No logs today, no streak
        }

        // Go backwards
        while let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) {
            if let logs = grouped[previousDay] {
                let calories = logs.reduce(0) { $0 + $1.totalCalories }
                if calories >= goals.dailyCalories * 0.8 {
                    streakDates.insert(previousDay)
                    checkDate = previousDay
                } else {
                    break // Streak broken
                }
            } else {
                break // No logs
            }
        }

        return streakDates
    }

    private func dateHasLogs(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return allFoodLogs.contains { calendar.startOfDay(for: $0.timestamp) == startOfDay }
    }

    // MARK: - Month Calendar View
    @ViewBuilder
    private func _buildMonthCalendar() -> some View {
        let streakDates = getStreakDates()
        let daysInMonth = getDaysInMonth(for: currentMonth)

        FrostedGlassContainer {
            VStack(spacing: 16) {
                // Month header with navigation
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(primaryTextColor)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(currentMonth, format: .dateTime.month(.wide).year())
                        .font(.title3.bold())
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(primaryTextColor)
                            .frame(width: 44, height: 44)
                    }
                }

                // Weekday labels
                HStack(spacing: 0) {
                    ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.caption.bold())
                            .foregroundStyle(tertiaryTextColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(daysInMonth, id: \.self) { date in
                        if let date = date {
                            _buildDayCell(date: date, hasLogs: dateHasLogs(date), isInStreak: streakDates.contains(date))
                        } else {
                            Color.clear
                                .frame(height: 50)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func _buildDayCell(date: Date, hasLogs: Bool, isInStreak: Bool) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        let cellBackground: Color = {
            if isSelected {
                return Color("AppSecondaryAccent")
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
                            .stroke(isToday && !isSelected ? Color("AppSecondaryAccent") : .clear, lineWidth: 2)
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
                            .fill(isSelected ? .white : Color("AppPrimaryAccent"))
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
    private func _buildStepsChart() -> some View {
        Chart {
            ForEach(weeklySteps, id: \.date) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(Color("AppSecondaryAccent"))
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(chartGridColor)
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
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
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
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
    private func _buildCalorieChart() -> some View {
        let sortedData = lastWeekSummaries.sorted { $0.date < $1.date }
        let targetCalories = Double(goals.dailyCalories)
        let areaGradient = Gradient(colors: [
            Color("AppPrimaryAccent").opacity(0.55),
            Color("AppPrimaryAccent").opacity(0.08)
        ])

        let goalLineColor = colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.35)
        let annotationTextColor = colorScheme == .dark ? Color.white.opacity(0.8) : primaryTextColor
        let annotationBgColor = colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.9)
        let pointDefaultColor = colorScheme == .dark ? Color.white : Color("AppPrimaryAccent")
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
                    yEnd: .value("Calories", day.totalCalories)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(gradient: areaGradient, startPoint: .top, endPoint: .bottom))

                LineMark(
                    x: .value("Day", day.date),
                    y: .value("Calories", day.totalCalories)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3))
                .foregroundStyle(Color("AppPrimaryAccent"))

                PointMark(
                    x: .value("Day", day.date),
                    y: .value("Calories", day.totalCalories)
                )
                .symbol(.circle)
                .symbolSize(day.metCalorieGoal ? 120 : 80)
                .foregroundStyle(day.metCalorieGoal ? Color.green : pointDefaultColor)
                .annotation(position: .top) {
                    VStack(spacing: 2) {
                        Text("\(Int(day.totalCalories))")
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
                        yEnd: .value("Calories Highlight", day.totalCalories)
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

            RadialGradient(
                gradient: Gradient(colors: [
                    Color("AppSecondaryAccent").opacity(colorScheme == .dark ? 0.3 : 0.15),
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
                    Color("AppPrimaryAccent").opacity(colorScheme == .dark ? 0.4 : 0.12),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(offset2)
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
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
