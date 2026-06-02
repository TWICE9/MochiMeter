// Screens/Settings/ProfileGoalsView.swift

import SwiftUI
import SwiftData

struct ProfileGoalsView: View {
    @Bindable var goals: UserGoals

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Personal info
    @State private var birthDate: Date
    @State private var gender: Gender
    @State private var height: Double
    @State private var weight: Double
    @State private var targetWeight: Double

    // Goals & activity
    @State private var activityLevel: ActivityLevel
    @State private var weightGoal: GoalType
    @State private var weeklyWeightChangeKg: Double

    // Burnt calories
    @State private var includeBurntCalories: Bool

    // Manual macro overrides
    @State private var useManualGoals: Bool
    @State private var dailyCalories: Double
    @State private var dailyProtein: Double
    @State private var dailyCarbs: Double
    @State private var dailyFat: Double

    // Water
    @State private var dailyWaterML: Double
    @State private var waterCupSizeML: Double

    // Validation
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    init(goals: UserGoals) {
        self.goals = goals

        _birthDate = State(initialValue: goals.birthDate)
        _gender = State(initialValue: goals.gender)
        _height = State(initialValue: goals.height)
        _weight = State(initialValue: goals.weight)
        _targetWeight = State(initialValue: goals.targetWeight)
        _activityLevel = State(initialValue: goals.activityLevel)
        _weightGoal = State(initialValue: goals.weightGoal)
        _weeklyWeightChangeKg = State(initialValue: goals.weeklyWeightChangeKg < 0.1 ? 0.5 : goals.weeklyWeightChangeKg)
        _includeBurntCalories = State(initialValue: goals.includeBurntCalories)
        _useManualGoals = State(initialValue: goals.useManualGoals)

        let isKJ = goals.energyUnit == .kilojoules
        _dailyCalories = State(initialValue: goals.dailyCalories * (isKJ ? 4.184 : 1.0))
        _dailyProtein = State(initialValue: goals.dailyProtein)
        _dailyCarbs = State(initialValue: goals.dailyCarbs)
        _dailyFat = State(initialValue: goals.dailyFat)
        _dailyWaterML = State(initialValue: goals.dailyWaterML)
        _waterCupSizeML = State(initialValue: goals.waterCupSizeML)
    }

    // MARK: - Colors

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 34/255, green: 34/255, blue: 40/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 118/255, green: 118/255, blue: 126/255)
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }

    private var accentColor: Color {
        Color("AppSecondaryAccent")
    }

    private var baseBackgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 245/255, green: 245/255, blue: 247/255)
    }

    // MARK: - Pace Helpers

    private var intensityLabel: String {
        if weightGoal == .maintain { return "Maintaining" }
        switch weeklyWeightChangeKg {
        case 0..<0.3: return "Gentle"
        case 0.3..<0.6: return "Moderate"
        case 0.6..<0.85: return "Ambitious"
        default: return "Intense"
        }
    }

    private var intensityColor: Color {
        if weightGoal == .maintain { return accentColor }
        switch weeklyWeightChangeKg {
        case 0..<0.3: return .green
        case 0.3..<0.6: return accentColor
        case 0.6..<0.85: return .orange
        default: return .red
        }
    }

    private var paceLabel: String {
        switch weightGoal {
        case .lose: return "Weight Loss Pace"
        case .gain: return "Weight Gain Pace"
        case .maintain: return "Weekly Target"
        }
    }

    private var paceIcon: String {
        switch weightGoal {
        case .lose: return "arrow.down.circle"
        case .gain: return "arrow.up.circle"
        case .maintain: return "equal.circle"
        }
    }

    private var estimatedEndDate: Date? {
        let diff = abs(weight - targetWeight)
        guard diff > 0, weeklyWeightChangeKg > 0 else { return nil }
        let days = Int(ceil((diff / weeklyWeightChangeKg) * 7))
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
    }

    private var formattedEndDate: String {
        guard let date = estimatedEndDate else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            baseBackgroundColor.ignoresSafeArea()
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Personal Info
                    _section("Personal Info") {
                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                HStack {
                                    Label("Birthday", systemImage: "calendar")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(primaryTextColor)
                                    Spacer()
                                    DatePicker("", selection: $birthDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(accentColor)
                                }

                                Divider().background(inputBorderColor)

                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Gender", systemImage: "person.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(primaryTextColor)
                                    Picker("Gender", selection: $gender) {
                                        ForEach(Gender.allCases, id: \.self) { g in
                                            Text(g.rawValue).tag(g)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                    }

                    // MARK: - Body Measurements
                    _section("Body Measurements") {
                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                _numberRow(label: "Height", icon: "ruler", value: $height, unit: "cm")
                                Divider().background(inputBorderColor)
                                _numberRow(label: "Current Weight", icon: "scalemass", value: $weight, unit: "kg")
                                Divider().background(inputBorderColor)
                                _numberRow(label: "Target Weight", icon: "target", value: $targetWeight, unit: "kg")
                            }
                        }
                    }

                    // MARK: - Calorie Adjustments
                    _section("Calorie Adjustments") {
                        FrostedGlassContainer {
                            Toggle(isOn: $includeBurntCalories) {
                                HStack(spacing: 10) {
                                    Image(systemName: "flame.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Include Burnt Calories")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(primaryTextColor)
                                        Text("Add exercise calories to your daily goal")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                }
                            }
                            .tint(accentColor)
                            .onChange(of: includeBurntCalories) { _, newValue in
                                goals.includeBurntCalories = newValue
                                try? modelContext.save()
                                NotificationCenter.default.post(name: Notification.Name("GoalsUpdated"), object: nil)
                            }
                        }
                    }

                    // MARK: - Goals & Activity
                    _section("Goals & Activity") {
                        FrostedGlassContainer {
                            VStack(spacing: 20) {
                                // Activity Level
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Activity Level", systemImage: "figure.run")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(useManualGoals ? secondaryTextColor : primaryTextColor)
                                    _activityPicker()
                                }
                                .opacity(useManualGoals ? 0.4 : 1.0)
                                .allowsHitTesting(!useManualGoals)

                                Divider().background(inputBorderColor)

                                // Primary Goal
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Primary Goal", systemImage: "flag.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(useManualGoals ? secondaryTextColor : primaryTextColor)
                                    _goalPicker()
                                }
                                .opacity(useManualGoals ? 0.4 : 1.0)
                                .allowsHitTesting(!useManualGoals)

                                Divider().background(inputBorderColor)

                                // Pace
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Label(paceLabel, systemImage: paceIcon)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(useManualGoals ? secondaryTextColor : primaryTextColor)
                                        Spacer()
                                        Text(intensityLabel)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(useManualGoals ? Color.gray : intensityColor)
                                            .clipShape(Capsule())
                                    }

                                    if weightGoal == .maintain {
                                        HStack {
                                            Text("0 kg/week")
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(accentColor)
                                            Spacer()
                                            Text("No change target")
                                                .font(.caption)
                                                .foregroundStyle(secondaryTextColor)
                                        }
                                    } else {
                                        HStack {
                                            Text(String(format: "%.2f kg/week", weeklyWeightChangeKg))
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(intensityColor)
                                            Spacer()
                                            if estimatedEndDate != nil {
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text("Goal by")
                                                        .font(.caption)
                                                        .foregroundStyle(secondaryTextColor)
                                                    Text(formattedEndDate)
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(primaryTextColor)
                                                }
                                            }
                                        }

                                        Slider(value: $weeklyWeightChangeKg, in: 0.1...1.0, step: 0.05)
                                            .tint(intensityColor)

                                        HStack {
                                            Text("0.1 kg").font(.caption).foregroundStyle(secondaryTextColor)
                                            Spacer()
                                            Text("1.0 kg").font(.caption).foregroundStyle(secondaryTextColor)
                                        }

                                        if weeklyWeightChangeKg >= 0.85 {
                                            Text("This is an intense pace. Consider a gentler rate for sustainable results.")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                                .opacity(useManualGoals ? 0.4 : 1.0)
                                .allowsHitTesting(!useManualGoals)
                            }
                        }
                    }

                    // MARK: - Nutrition Targets
                    _section("Nutrition Targets") {
                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                // Manual toggle
                                Toggle(isOn: $useManualGoals.animation(.easeInOut(duration: 0.25))) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.subheadline)
                                            .foregroundStyle(accentColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Manual Goals")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(primaryTextColor)
                                            Text(useManualGoals ? "You set your own targets" : "Calculated from your profile")
                                                .font(.caption)
                                                .foregroundStyle(secondaryTextColor)
                                        }
                                    }
                                }
                                .tint(accentColor)
                                .onChange(of: useManualGoals) { _, newValue in
                                    goals.useManualGoals = newValue
                                    try? modelContext.save()
                                    NotificationCenter.default.post(name: Notification.Name("GoalsUpdated"), object: nil)
                                }

                                Divider().background(inputBorderColor)

                                if useManualGoals {
                                    _macroRow(title: "Calories", value: $dailyCalories, unit: goals.energyUnit.unitLabel)
                                    Divider().background(inputBorderColor)
                                    _macroRow(title: "Protein", value: $dailyProtein, unit: "g")
                                    _macroRow(title: "Carbs", value: $dailyCarbs, unit: "g")
                                    _macroRow(title: "Fat", value: $dailyFat, unit: "g")
                                } else {
                                    // Show calculated preview (read-only)
                                    let preview = calculatedMacros
                                    _macroSummaryRow(title: "Calories", value: preview.targetCalories, unit: goals.energyUnit.unitLabel, isKJ: goals.energyUnit == .kilojoules)
                                    Divider().background(inputBorderColor)
                                    _macroSummaryRow(title: "Protein", value: preview.protein, unit: "g")
                                    _macroSummaryRow(title: "Carbs", value: preview.carbs, unit: "g")
                                    _macroSummaryRow(title: "Fat", value: preview.fat, unit: "g")
                                }
                            }
                        }
                    }

                    // MARK: - Water Goals
                    _section("Water Goals") {
                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                _macroRow(title: "Daily Goal", value: $dailyWaterML, unit: "mL")
                                Divider().background(inputBorderColor)
                                _macroRow(title: "Cup Size", value: $waterCupSizeML, unit: "mL")
                            }
                        }
                    }

                    // MARK: - Save
                    Button {
                        save()
                    } label: {
                        HStack {
                            Image(systemName: useManualGoals ? "checkmark.circle" : "arrow.triangle.2.circlepath")
                            Text(useManualGoals ? "Save Goals" : "Save & Recalculate")
                        }
                        .font(.headline).bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Profile & Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if modelContext.hasChanges { modelContext.rollback() }
                    dismiss()
                }
                .foregroundStyle(primaryTextColor)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .tint(accentColor)
            }
        }
        .alert("Invalid Value", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Calculated Preview

    private var calculatedMacros: (targetCalories: Double, protein: Double, carbs: Double, fat: Double) {
        let age = HealthCalculator.calculateAge(birthDate: birthDate)
        let result = HealthCalculator.calculateDailyGoals(
            gender: gender,
            weightKg: weight,
            heightCm: height,
            age: age,
            activityLevel: activityLevel,
            weightGoal: weightGoal,
            weeklyWeightChangeKg: weeklyWeightChangeKg
        )
        return (result.targetCalories, result.protein, result.carbs, result.fat)
    }

    // MARK: - Save

    private func save() {
        // Validate water
        if dailyWaterML < 100 {
            validationMessage = "Daily water goal must be at least 100 mL"
            showValidationAlert = true
            return
        }
        if waterCupSizeML < 50 {
            validationMessage = "Cup size must be at least 50 mL"
            showValidationAlert = true
            return
        }

        // Save profile data
        goals.birthDate = birthDate
        goals.height = height
        goals.weight = weight
        goals.targetWeight = targetWeight
        goals.gender = gender
        goals.activityLevel = activityLevel
        goals.weightGoal = weightGoal
        goals.weeklyWeightChangeKg = weeklyWeightChangeKg
        goals.useManualGoals = useManualGoals
        goals.includeBurntCalories = includeBurntCalories

        if useManualGoals {
            // Validate manual entries
            let isKJ = goals.energyUnit == .kilojoules
            let kcal = isKJ ? dailyCalories / 4.184 : dailyCalories

            if kcal < 100 || kcal > 10000 {
                validationMessage = "Calories must be between 100 and 10,000 kcal"
                showValidationAlert = true
                return
            }
            if dailyProtein < 0 || dailyProtein > 1000 {
                validationMessage = "Protein must be between 0 and 1,000g"
                showValidationAlert = true
                return
            }
            if dailyCarbs < 0 || dailyCarbs > 2000 {
                validationMessage = "Carbs must be between 0 and 2,000g"
                showValidationAlert = true
                return
            }
            if dailyFat < 0 || dailyFat > 500 {
                validationMessage = "Fat must be between 0 and 500g"
                showValidationAlert = true
                return
            }

            goals.dailyCalories = kcal
            goals.dailyProtein = dailyProtein
            goals.dailyCarbs = dailyCarbs
            goals.dailyFat = dailyFat
        } else {
            // Auto-calculate from profile
            let macros = calculatedMacros
            goals.dailyCalories = macros.targetCalories
            goals.dailyProtein = macros.protein
            goals.dailyCarbs = macros.carbs
            goals.dailyFat = macros.fat
        }

        // Water
        goals.dailyWaterML = dailyWaterML
        goals.waterCupSizeML = waterCupSizeML

        try? modelContext.save()
        NotificationCenter.default.post(name: Notification.Name("GoalsUpdated"), object: nil)
        syncGoalsToCloud()
        dismiss()
    }

    private func syncGoalsToCloud() {
        Task {
            guard let userId = await UserSession.shared.getCurrentUserId(), !userId.isEmpty else { return }
            if goals.userId == nil { goals.userId = userId }
            await CloudSyncManager.shared.uploadUserGoalsImmediately(goals, userId: userId)
        }
    }

    // MARK: - Reusable Builders

    @ViewBuilder
    private func _section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3).bold()
                .foregroundStyle(primaryTextColor)
            content()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func _numberRow(label: String, icon: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(primaryTextColor)
            Spacer()
            HStack(spacing: 8) {
                TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(inputBackgroundColor)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(inputBorderColor, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 30, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func _macroRow(title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(primaryTextColor)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .font(.body.bold())
                .foregroundStyle(accentColor)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(inputBackgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(inputBorderColor, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 40, alignment: .leading)
        }
    }

    @ViewBuilder
    private func _macroSummaryRow(title: String, value: Double, unit: String, isKJ: Bool = false) -> some View {
        let displayValue = isKJ ? value * 4.184 : value
        HStack {
            Text(title)
                .foregroundStyle(primaryTextColor)
            Spacer()
            Text("\(Int(displayValue))")
                .font(.body.bold())
                .foregroundStyle(accentColor)
            Text(unit)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 40, alignment: .leading)
        }
    }

    @ViewBuilder
    private func _activityPicker() -> some View {
        VStack(spacing: 8) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { activityLevel = level }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(activityLevel == level ? .black : primaryTextColor)
                            Text(_activityDescription(level))
                                .font(.caption)
                                .foregroundStyle(activityLevel == level ? .black.opacity(0.7) : secondaryTextColor)
                        }
                        Spacer()
                        if activityLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(activityLevel == level ? accentColor : inputBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(activityLevel == level ? Color.clear : inputBorderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func _activityDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .lowActivity: return "Little to light exercise"
        case .moderateActivity: return "Regular workouts"
        case .highActivity: return "Intense training schedule"
        }
    }

    @ViewBuilder
    private func _goalPicker() -> some View {
        HStack(spacing: 8) {
            ForEach(GoalType.allCases, id: \.self) { goal in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weightGoal = goal }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: _goalIcon(goal))
                            .font(.title3)
                        Text(goal.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(weightGoal == goal ? accentColor : inputBackgroundColor)
                    .foregroundStyle(weightGoal == goal ? .black : primaryTextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(weightGoal == goal ? Color.clear : inputBorderColor, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func _goalIcon(_ goal: GoalType) -> String {
        switch goal {
        case .lose: return "arrow.down.circle"
        case .maintain: return "equal.circle"
        case .gain: return "arrow.up.circle"
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]),
                center: .topLeading, startRadius: 50, endRadius: 450
            )
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]),
                center: .bottomTrailing, startRadius: 100, endRadius: 500
            )
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
    }
}
