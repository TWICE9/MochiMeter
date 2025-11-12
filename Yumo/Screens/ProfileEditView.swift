// Screens/ProfileEditView.swift

import SwiftUI
import SwiftData

struct ProfileEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var goals: UserGoals

    // Local state to hold edits
    @State private var birthDate: Date
    @State private var gender: Gender
    @State private var height: Double
    @State private var weight: Double
    @State private var activityLevel: ActivityLevel
    @State private var weightGoal: GoalType
    @State private var targetWeight: Double

    init(goals: UserGoals) {
        self.goals = goals
        _birthDate = State(initialValue: goals.birthDate)
        _gender = State(initialValue: goals.gender)
        _height = State(initialValue: goals.height)
        _weight = State(initialValue: goals.weight)
        _activityLevel = State(initialValue: goals.activityLevel)
        _weightGoal = State(initialValue: goals.weightGoal)
        _targetWeight = State(initialValue: goals.targetWeight)
    }

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

    private var inputAccentColor: Color {
        Color("AppSecondaryAccent")
    }

    private var baseBackgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 245/255, green: 245/255, blue: 247/255)
    }

    var body: some View {
        ZStack {
            baseBackgroundColor.ignoresSafeArea()
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Personal Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Personal Info")
                            .font(.title3).bold()
                            .foregroundStyle(primaryTextColor)

                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                // Birthday
                                HStack {
                                    Label("Birthday", systemImage: "calendar")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(primaryTextColor)

                                    Spacer()

                                    DatePicker("", selection: $birthDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(inputAccentColor)
                                }

                                Divider().background(inputBorderColor)

                                // Gender
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
                    .padding(.horizontal, 24)

                    // MARK: - Body Measurements Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Body Measurements")
                            .font(.title3).bold()
                            .foregroundStyle(primaryTextColor)

                        FrostedGlassContainer {
                            VStack(spacing: 16) {
                                // Height
                                _buildNumberInput(
                                    label: "Height",
                                    icon: "ruler",
                                    value: $height,
                                    unit: "cm"
                                )

                                Divider().background(inputBorderColor)

                                // Weight
                                _buildNumberInput(
                                    label: "Current Weight",
                                    icon: "scalemass",
                                    value: $weight,
                                    unit: "kg"
                                )

                                Divider().background(inputBorderColor)

                                // Target Weight
                                _buildNumberInput(
                                    label: "Target Weight",
                                    icon: "target",
                                    value: $targetWeight,
                                    unit: "kg"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: - Goals Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Goals & Activity")
                            .font(.title3).bold()
                            .foregroundStyle(primaryTextColor)

                        FrostedGlassContainer {
                            VStack(spacing: 20) {
                                // Activity Level
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Activity Level", systemImage: "figure.run")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(primaryTextColor)

                                    _buildActivityPicker()
                                }

                                Divider().background(inputBorderColor)

                                // Primary Goal
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Primary Goal", systemImage: "flag.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(primaryTextColor)

                                    _buildGoalPicker()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: - Save Button
                    Button {
                        saveAndRecalculate()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Save & Recalculate Goals")
                        }
                        .font(.headline).bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("AppSecondaryAccent"))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .padding(.top, 24)
                .padding(.bottom, 120) // Extra space so content clears bottom nav/tab bar
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if modelContext.hasChanges {
                        modelContext.rollback()
                    }
                    dismiss()
                }
                .foregroundStyle(primaryTextColor)
            }
        }
        .addKeyboardDoneButton()
    }

    // MARK: - Number Input Builder

    @ViewBuilder
    private func _buildNumberInput(
        label: String,
        icon: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(primaryTextColor)

            Spacer()

            HStack(spacing: 8) {
                TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(inputAccentColor)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(inputBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(inputBorderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 30, alignment: .leading)
            }
        }
    }

    // MARK: - Activity Picker

    @ViewBuilder
    private func _buildActivityPicker() -> some View {
        VStack(spacing: 8) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activityLevel = level
                    }
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
                    .background(activityLevel == level ? inputAccentColor : inputBackgroundColor)
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
        case .lowActivity:
            return "Little to light exercise"
        case .moderateActivity:
            return "Regular workouts"
        case .highActivity:
            return "Intense training schedule"
        }
    }

    // MARK: - Goal Picker

    @ViewBuilder
    private func _buildGoalPicker() -> some View {
        HStack(spacing: 8) {
            ForEach(GoalType.allCases, id: \.self) { goal in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        weightGoal = goal
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: _goalIcon(goal))
                            .font(.title3)
                        Text(goal.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(weightGoal == goal ? inputAccentColor : inputBackgroundColor)
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
        case .lose:
            return "arrow.down.circle"
        case .maintain:
            return "equal.circle"
        case .gain:
            return "arrow.up.circle"
        }
    }

    // MARK: - Save and Recalculate

    private func saveAndRecalculate() {
        let age = HealthCalculator.calculateAge(birthDate: birthDate)

        let calculatedMacros = HealthCalculator.calculateDailyGoals(
            gender: gender,
            weightKg: weight,
            heightCm: height,
            age: age,
            activityLevel: activityLevel,
            weightGoal: weightGoal
        )

        // Save profile data
        goals.birthDate = birthDate
        goals.height = height
        goals.weight = weight
        goals.targetWeight = targetWeight
        goals.gender = gender
        goals.activityLevel = activityLevel
        goals.weightGoal = weightGoal

        // Save calculated goals
        goals.dailyCalories = calculatedMacros.targetCalories
        goals.dailyProtein = calculatedMacros.protein
        goals.dailyCarbs = calculatedMacros.carbs
        goals.dailyFat = calculatedMacros.fat

        // Sync goals to cloud
        syncGoalsToCloud()

        dismiss()
    }

    // MARK: - Sync to Cloud

    private func syncGoalsToCloud() {
        guard let userId = goals.userId else {
            print("⚠️ No userId set, skipping goals sync")
            return
        }

        Task {
            await CloudSyncManager.shared.uploadUserGoalsImmediately(goals, userId: userId)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
    }
}

// MARK: - Keyboard Helper

fileprivate extension View {
    func addKeyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .tint(Color("AppSecondaryAccent"))
            }
        }
    }
}
