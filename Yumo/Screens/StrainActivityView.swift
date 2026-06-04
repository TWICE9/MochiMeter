// Screens/StrainActivityView.swift

import SwiftUI
import Charts
import HealthKit

struct StrainActivityView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKit = HealthKitManager.shared
    
    @State private var isLoading = true
    @State private var strainAnimated: Double = 0
    
    // Adaptive colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color(red: 100/255, green: 100/255, blue: 110/255)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.85)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.05, green: 0.05, blue: 0.12), Color(red: 0.08, green: 0.04, blue: 0.15)]
                    : [Color(red: 0.95, green: 0.93, blue: 0.90), Color(red: 0.92, green: 0.90, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                _buildLoadingView()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Activity & Strain")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(primaryTextColor)
                                Text(Date(), format: .dateTime.weekday(.wide).month().day())
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(secondaryTextColor)
                                    .padding(8)
                                    .background(Circle().fill(secondaryTextColor.opacity(0.1)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        
                        // Strain Score Ring
                        _buildStrainRing()
                            .padding(.horizontal, 24)
                        
                        // Today's Workouts
                        _buildTodayWorkoutsSection()
                            .padding(.horizontal, 24)
                        
                        // Activity Summary
                        _buildActivitySummary()
                            .padding(.horizontal, 24)
                        
                        // Weekly Strain Trend
                        _buildWeeklyStrainChart()
                            .padding(.horizontal, 24)
                        
                        // Recovery vs Strain Balance
                        _buildRecoveryStrainBalance()
                            .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 20)
                    .readableContentColumn(640)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            // If strain data is already loaded (warm cache from app launch prefetch),
            // skip the loading spinner entirely — just animate the ring in place.
            let alreadyLoaded = healthKit.strainScore != nil
            if alreadyLoaded {
                isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    strainAnimated = healthKit.strainScore ?? 0
                }
            }

            try? await healthKit.requestAuthorization()
            await healthKit.fetchStrainData()           // no-op if TTL fresh
            if healthKit.recoveryScore == nil {
                await healthKit.fetchRecoveryData()
            }

            if !alreadyLoaded {
                withAnimation(.easeOut(duration: 0.5)) { isLoading = false }
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(alreadyLoaded ? 0 : 0.3)) {
                strainAnimated = healthKit.strainScore ?? 0
            }
        }
        .onChange(of: healthKit.strainScore) { _, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                strainAnimated = newValue ?? 0
            }
        }
    }
    
    // MARK: - Loading
    
    @ViewBuilder
    private func _buildLoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            Text("Analyzing your activity...")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
        }
    }
    
    // MARK: - Strain Score Ring
    
    @ViewBuilder
    private func _buildStrainRing() -> some View {
        let strain = healthKit.strainScore ?? 0
        
        FrostedGlassContainer {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Strain")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                        Text(strainMessage(strain))
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Text(strainLevel(strain))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(strainColor(strain))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(strainColor(strain).opacity(0.15))
                        .clipShape(Capsule())
                }
                
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            strainColor(strain).opacity(0.15),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                    
                    // Animated progress ring
                    Circle()
                        .trim(from: 0, to: strainAnimated / 21.0)
                        .stroke(
                            LinearGradient(
                                colors: [strainColor(strain), strainColor(strain).opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                    
                    // Center text
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", strain))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                        Text("/ 21")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .padding(16)
                .drawingGroup()
                .padding(.vertical, 8)
                
                // Strain factors
                HStack(spacing: 0) {
                    _strainFactor(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(healthKit.todayBurntCalories))",
                        unit: "kcal",
                        color: .orange
                    )
                    
                    Divider().frame(height: 40)
                    
                    _strainFactor(
                        icon: "figure.walk",
                        label: "Steps",
                        value: "\(Int(healthKit.todaySteps))",
                        unit: "",
                        color: .blue
                    )
                    
                    Divider().frame(height: 40)
                    
                    _strainFactor(
                        icon: "timer",
                        label: "Active",
                        value: "\(Int(healthKit.todayActiveMinutes))",
                        unit: "min",
                        color: .green
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func _strainFactor(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Today's Workouts
    
    @ViewBuilder
    private func _buildTodayWorkoutsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Workouts")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                Spacer()
                Text("\(healthKit.todayWorkouts.count) session\(healthKit.todayWorkouts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
            }
            
            if healthKit.todayWorkouts.isEmpty {
                FrostedGlassContainer {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 50, height: 50)
                            Image(systemName: "figure.mixed.cardio")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No workouts yet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            Text("Start a workout on your Apple Watch or log one manually")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                ForEach(healthKit.todayWorkouts) { workout in
                    _buildWorkoutCard(workout)
                }
            }
        }
    }
    
    @ViewBuilder
    private func _buildWorkoutCard(_ workout: WorkoutSummary) -> some View {
        FrostedGlassContainer {
            HStack(spacing: 14) {
                // Workout type icon
                ZStack {
                    Circle()
                        .fill(workout.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: workout.icon)
                        .font(.title2)
                        .foregroundStyle(workout.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.typeName)
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    HStack(spacing: 12) {
                        Label(workout.formattedDuration, systemImage: "clock")
                        Label("\(Int(workout.caloriesBurned)) kcal", systemImage: "flame.fill")
                        if let dist = workout.formattedDistance {
                            Label(dist, systemImage: "location.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                }
                
                Spacer()
                
                // Time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(workout.date, format: .dateTime.hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(secondaryTextColor)
                    
                    Text(workout.sourceName)
                        .font(.system(size: 9))
                        .foregroundStyle(secondaryTextColor.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Activity Summary
    
    @ViewBuilder
    private func _buildActivitySummary() -> some View {
        let totalWorkoutMinutes = healthKit.todayWorkouts.reduce(0.0) { $0 + $1.durationMinutes }
        let totalWorkoutCalories = healthKit.todayWorkouts.reduce(0.0) { $0 + $1.caloriesBurned }
        let workoutTypes = Set(healthKit.todayWorkouts.map { $0.typeName })
        
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Summary")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                
                HStack(spacing: 0) {
                    _activityStat(
                        value: "\(Int(totalWorkoutMinutes))",
                        unit: "min",
                        label: "Workout Time",
                        icon: "timer",
                        color: .green
                    )
                    
                    _activityStat(
                        value: "\(Int(totalWorkoutCalories))",
                        unit: "kcal",
                        label: "Workout Cal",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    _activityStat(
                        value: "\(workoutTypes.count)",
                        unit: workoutTypes.count == 1 ? "type" : "types",
                        label: "Activities",
                        icon: "figure.mixed.cardio",
                        color: .blue
                    )
                }
                
                // Weekly workout count
                let weeklyCount = healthKit.weeklyWorkouts.count
                let avgPerDay = Double(weeklyCount) / 7.0
                
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.purple)
                        .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weeklyCount) workouts this week")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                        Text("Average \(String(format: "%.1f", avgPerDay)) per day")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Trend indicator
                    if weeklyCount >= 4 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Active")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.green)
                    } else if weeklyCount >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Moderate")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    @ViewBuilder
    private func _activityStat(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Weekly Strain Chart
    
    @ViewBuilder
    private func _buildWeeklyStrainChart() -> some View {
        let data = healthKit.weeklyStrain
        
        if data.count >= 2 {
            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("7-Day Strain")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                        
                        Spacer()
                        
                        let avgStrain = data.reduce(0.0) { $0 + $1.strain } / Double(data.count)
                        Text("Avg \(String(format: "%.1f", avgStrain))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(strainColor(avgStrain))
                    }
                    
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Strain", point.strain)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [strainColor(point.strain).opacity(0.6), strainColor(point.strain)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(4)
                        }
                    }
                    .chartYScale(domain: 0...21)
                    .chartYAxis {
                        AxisMarks(values: [0, 7, 14, 21]) { value in
                            AxisValueLabel {
                                Text("\(value.as(Double.self).map { Int($0) } ?? 0)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(secondaryTextColor.opacity(0.2))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                        .font(.system(size: 9))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                    .drawingGroup()
                    
                    // Legend
                    HStack(spacing: 16) {
                        _strainLegend(color: .blue, label: "Light (0-7)")
                        _strainLegend(color: .green, label: "Medium (7-14)")
                        _strainLegend(color: .orange, label: "High (14-18)")
                        _strainLegend(color: .red, label: "Peak (18+)")
                    }
                    .font(.system(size: 9))
                }
            }
        }
    }
    
    @ViewBuilder
    private func _strainLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(secondaryTextColor)
        }
    }
    
    // MARK: - Recovery vs Strain Balance
    
    @ViewBuilder
    private func _buildRecoveryStrainBalance() -> some View {
        let data = healthKit.weeklyRecoverySleep
        
        if data.count >= 2 {
            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recovery vs Strain")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    Text("Balance your training load with adequate recovery")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                    
                    Chart {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, point in
                            // Recovery line
                            LineMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Recovery", point.recovery),
                                series: .value("Type", "Recovery")
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            
                            // Strain as percentage of max (21 → 100)
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
                                    .font(.system(size: 9))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                        .font(.system(size: 9))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale([
                        "Recovery": Color.green,
                        "Strain": Color.orange
                    ])
                    .chartLegend(position: .top, alignment: .trailing) {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 6, height: 6)
                                Text("Recovery").font(.system(size: 10)).foregroundStyle(secondaryTextColor)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(.orange).frame(width: 6, height: 6)
                                Text("Strain").font(.system(size: 10)).foregroundStyle(secondaryTextColor)
                            }
                        }
                    }
                    .frame(height: 140)
                    .drawingGroup()
                    
                    // Balance advice
                    _buildBalanceAdvice()
                }
            }
        }
    }
    
    private func _buildBalanceAdvice() -> some View {
        let strain = healthKit.strainScore ?? 0
        let recovery = healthKit.recoveryScore ?? 50
        
        let advice: (icon: String, message: String, color: Color)
        
        if recovery >= 70 && strain < 10 {
            advice = ("bolt.fill", "High recovery — today is a great day to push hard!", .green)
        } else if recovery >= 70 && strain >= 10 {
            advice = ("checkmark.circle.fill", "Good balance! You're training within your recovery capacity.", .blue)
        } else if recovery < 50 && strain > 14 {
            advice = ("exclamationmark.triangle.fill", "You're pushing hard on low recovery. Consider dialing back tomorrow.", .orange)
        } else if recovery < 40 {
            advice = ("bed.double.fill", "Low recovery — prioritize rest and nutrition today.", .red)
        } else {
            advice = ("figure.walk", "Moderate day. A steady workout would be beneficial.", .blue)
        }
        
        return HStack(spacing: 10) {
            Image(systemName: advice.icon)
                .foregroundStyle(advice.color)
                .font(.system(size: 14))
            
            Text(advice.message)
                .font(.caption)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(advice.color.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func strainColor(_ strain: Double) -> Color {
        if strain >= 18 { return .red }
        if strain >= 14 { return .orange }
        if strain >= 7 { return .green }
        return .blue
    }
    
    private func strainLevel(_ strain: Double) -> String {
        if strain >= 18 { return "Overreaching" }
        if strain >= 14 { return "High" }
        if strain >= 7 { return "Medium" }
        if strain >= 3 { return "Light" }
        return "Minimal"
    }
    
    private func strainMessage(_ strain: Double) -> String {
        if strain >= 18 { return "Extreme exertion today. Make sure to recover." }
        if strain >= 14 { return "Hard effort today. Great for building fitness." }
        if strain >= 7 { return "Solid activity day. Keep it going!" }
        if strain >= 3 { return "Active day with moderate effort." }
        return "Low activity so far. Get moving!"
    }
}

#Preview {
    StrainActivityView()
}
