// Screens/HealthRingsView.swift

import SwiftUI
import SwiftData
import HealthKit

struct HealthRingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \LoggedFood.timestamp, order: .reverse) private var allFoodLogs: [LoggedFood]
    @Query private var allGoals: [UserGoals]

    @State private var stepCount: Double = 0
    @State private var activeCalories: Double = 0
    @State private var animatedCalories: Double = 0
    @State private var animatedSteps: Double = 0
    @State private var animatedActive: Double = 0

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

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

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white
    }

    private var ringBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.1)
    }

    private var progressBarBackground: Color {
        colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08)
    }

    // MARK: - Computed Properties

    private var goals: UserGoals {
        allGoals.first ?? UserGoals()
    }

    private var foodLogsToday: [LoggedFood] {
        let startOfDay = Date().startOfDay
        let endOfDay = Date().endOfDay
        return allFoodLogs.filter { log in
            log.timestamp >= startOfDay &&
            log.timestamp <= endOfDay &&
            log.recipe == nil
        }
    }

    private var totalCaloriesToday: Double {
        foodLogsToday.reduce(0) { $0 + $1.totalCalories }
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 32) {

                    // --- Header ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Activity")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryTextColor)
                        Text("Steps")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 100)

                    // --- Activity Rings ---
                    _buildActivityRings()

                    // --- Stats Cards ---
                    _buildStatsCards()

                    Spacer()
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            requestHealthKitPermission()
            updateAnimatedValues()
        }
        .onChange(of: allFoodLogs) { _, _ in
            updateAnimatedValues()
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func _buildActivityRings() -> some View {
        VStack(spacing: 20) {
            // Walking GIF in a circle with dynamic progress ring
            ZStack {
                // Background circle
                Circle()
                    .fill(cardBackgroundColor)
                    .frame(width: 280, height: 280)

                // Progress ring background
                Circle()
                    .stroke(ringBackgroundColor, lineWidth: 8)
                    .frame(width: 260, height: 260)

                // Dynamic progress ring based on steps
                Circle()
                    .trim(from: 0, to: min(animatedSteps / 10000, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.63, green: 0.98, blue: 0.27),
                                Color(red: 0.5, green: 0.8, blue: 0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animatedSteps)

                // Animated GIF (clipped to circle)
                AnimatedGIFImage(name: "manwalking")
                    .frame(width: 240, height: 240)
                    .scaleEffect(0.34)
                    .clipShape(Circle())
            }

            // Stats below the image - Steps focused
            VStack(spacing: 4) {
                Text("\(Int(animatedSteps))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .contentTransition(.numericText())
                Text("Steps Today")
                    .font(.caption)
                    .foregroundStyle(tertiaryTextColor)
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func _buildStatsCards() -> some View {
        VStack(spacing: 16) {
            // Combined Stats Card
            FrostedGlassContainer {
                VStack(spacing: 20) {
                    // Calories Row
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.98, green: 0.24, blue: 0.45))
                                .frame(width: 10, height: 10)
                            Text("CALORIES")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(tertiaryTextColor)
                        }

                        Spacer()

                        Text("\(Int(animatedCalories))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextColor)
                            .contentTransition(.numericText())

                        Text("/ \(Int(goals.dailyCalories))")
                            .font(.caption)
                            .foregroundStyle(mutedTextColor)
                    }

                    Divider().background(dividerColor)

                    // Steps Row
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.63, green: 0.98, blue: 0.27))
                                .frame(width: 10, height: 10)
                            Text("STEPS")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(tertiaryTextColor)
                        }

                        Spacer()

                        Text("\(Int(animatedSteps))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextColor)
                            .contentTransition(.numericText())

                        Text("/ 10,000")
                            .font(.caption)
                            .foregroundStyle(mutedTextColor)
                    }

                    Divider().background(dividerColor)

                    // Active Calories Row
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.0, green: 0.87, blue: 0.98))
                                .frame(width: 10, height: 10)
                            Text("ACTIVE")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(tertiaryTextColor)
                        }

                        Spacer()

                        Text("\(Int(animatedActive))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextColor)
                            .contentTransition(.numericText())

                        Text("/ 500 kcal")
                            .font(.caption)
                            .foregroundStyle(mutedTextColor)
                    }
                }
                .padding()
            }

            // Steps Bar Graph
            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("STEPS PROGRESS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(tertiaryTextColor)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 8)
                                .fill(progressBarBackground)
                                .frame(height: 40)

                            // Progress bar
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.63, green: 0.98, blue: 0.27),
                                            Color(red: 0.5, green: 0.8, blue: 0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: min(geometry.size.width * (animatedSteps / 10000), geometry.size.width), height: 40)
                                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animatedSteps)

                            // Percentage text
                            HStack {
                                Spacer()
                                Text("\(Int((animatedSteps / 10000) * 100))%")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(primaryTextColor)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                    .frame(height: 40)
                }
                .padding()
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helper Functions

    private func updateAnimatedValues() {
        fetchHealthData()

        let newCalories = totalCaloriesToday

        withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
            animatedCalories = newCalories
        }
    }

    // MARK: - HealthKit Functions

    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available")
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        let typesToRead: Set<HKObjectType> = [stepType, activeEnergyType]

        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if success {
                fetchHealthData()
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }

    private func fetchHealthData() {
        fetchStepCount()
        fetchActiveCalories()
    }

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
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                    self.stepCount = steps
                    self.animatedSteps = steps
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
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                    self.activeCalories = calories
                    self.animatedActive = calories
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Background Functions

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.98, green: 0.24, blue: 0.45).opacity(colorScheme == .dark ? 0.3 : 0.15), .clear]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(offset1)
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color(red: 0.63, green: 0.98, blue: 0.27).opacity(colorScheme == .dark ? 0.3 : 0.15), .clear]),
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
