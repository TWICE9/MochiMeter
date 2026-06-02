// Screens/NutritionGoalsView.swift

import SwiftUI
import SwiftData

struct NutritionGoalsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @Bindable var goals: UserGoals

    // Local state to hold edits
    @State private var dailyCalories: Double
    @State private var dailyProtein: Double
    @State private var dailyCarbs: Double
    @State private var dailyFat: Double
    @State private var dailyWaterML: Double
    @State private var waterCupSizeML: Double

    // Alert state
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    init(goals: UserGoals) {
        self.goals = goals
        let isKJ = goals.energyUnit == .kilojoules
        _dailyCalories = State(initialValue: goals.dailyCalories * (isKJ ? 4.184 : 1.0))
        _dailyProtein = State(initialValue: goals.dailyProtein)
        _dailyCarbs = State(initialValue: goals.dailyCarbs)
        _dailyFat = State(initialValue: goals.dailyFat)
        _dailyWaterML = State(initialValue: goals.dailyWaterML)
        _waterCupSizeML = State(initialValue: goals.waterCupSizeML)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var baseBackgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 245/255, green: 245/255, blue: 247/255)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(red: 247/255, green: 247/255, blue: 249/255)
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.08)
    }

    private var accentColor: Color {
        Color("AppSecondaryAccent")
    }

    var body: some View {
        ZStack {
            baseBackgroundColor.ignoresSafeArea()
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nutrition Goals")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(primaryTextColor)

                        Text("Set your daily macro targets")
                            .font(.subheadline)
                            .foregroundColor(secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // Macros Section
                    _adaptiveCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Daily Macros")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)

                            _buildGoalTextField(
                                title: "Calories",
                                binding: $dailyCalories,
                                unit: goals.energyUnit.unitLabel
                            )

                            Divider().background(cardBorderColor)

                            _buildGoalTextField(
                                title: "Protein",
                                binding: $dailyProtein,
                                unit: "g"
                            )
                            _buildGoalTextField(
                                title: "Carbs",
                                binding: $dailyCarbs,
                                unit: "g"
                            )
                            _buildGoalTextField(
                                title: "Fat",
                                binding: $dailyFat,
                                unit: "g"
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Water Section
                    _adaptiveCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Water Goals")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)

                            _buildGoalTextField(
                                title: "Daily Goal",
                                binding: $dailyWaterML,
                                unit: "mL"
                            )
                            _buildGoalTextField(
                                title: "Cup Size",
                                binding: $waterCupSizeML,
                                unit: "mL"
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Save button
                    Button {
                        saveGoals()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Save Goals")
                        }
                        .font(.headline).bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }
                .padding(.top, 24)
                .padding(.bottom, 120) // Extra space so content clears bottom nav/tab bar
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .dismissKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Goals")
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
        .alert("Invalid Value", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .addKeyboardDoneButton()
    }

    // MARK: - Save & Validation

    private func saveGoals() {
        // Validate all fields
        let isKJ = goals.energyUnit == .kilojoules
        let caloriesInKcal = isKJ ? dailyCalories / 4.184 : dailyCalories

        if caloriesInKcal < 100 {
            validationMessage = "Calories must be at least 100 kcal"
            showValidationAlert = true
            return
        }
        if caloriesInKcal > 10000 {
            validationMessage = "Calories must be no more than 10,000 kcal"
            showValidationAlert = true
            return
        }

        if dailyProtein < 0 {
            validationMessage = "Protein must be at least 0g"
            showValidationAlert = true
            return
        }
        if dailyProtein > 1000 {
            validationMessage = "Protein must be no more than 1,000g"
            showValidationAlert = true
            return
        }

        if dailyCarbs < 0 {
            validationMessage = "Carbs must be at least 0g"
            showValidationAlert = true
            return
        }
        if dailyCarbs > 2000 {
            validationMessage = "Carbs must be no more than 2,000g"
            showValidationAlert = true
            return
        }

        if dailyFat < 0 {
            validationMessage = "Fat must be at least 0g"
            showValidationAlert = true
            return
        }
        if dailyFat > 500 {
            validationMessage = "Fat must be no more than 500g"
            showValidationAlert = true
            return
        }

        if dailyWaterML < 100 {
            validationMessage = "Daily water goal must be at least 100 mL"
            showValidationAlert = true
            return
        }
        if dailyWaterML > 20000 {
            validationMessage = "Daily water goal must be no more than 20,000 mL"
            showValidationAlert = true
            return
        }

        if waterCupSizeML < 50 {
            validationMessage = "Cup size must be at least 50 mL"
            showValidationAlert = true
            return
        }
        if waterCupSizeML > 5000 {
            validationMessage = "Cup size must be no more than 5,000 mL"
            showValidationAlert = true
            return
        }

        // All validation passed - save to goals model
        goals.dailyCalories = caloriesInKcal
        goals.dailyProtein = dailyProtein
        goals.dailyCarbs = dailyCarbs
        goals.dailyFat = dailyFat
        goals.dailyWaterML = dailyWaterML
        goals.waterCupSizeML = waterCupSizeML

        // Persist changes to disk
        try? modelContext.save()

        // Notify home screen to refresh with new goals
        NotificationCenter.default.post(name: Notification.Name("GoalsUpdated"), object: nil)

        // Sync to cloud
        syncGoalsToCloud()

        dismiss()
    }

    private func syncGoalsToCloud() {
        Task {
            guard let sessionUserId = await UserSession.shared.getCurrentUserId(), !sessionUserId.isEmpty else {
                print("⚠️ No userId found in session, skipping goals sync")
                return
            }
            
            // Ensure goals has the correct userId locally too before syncing
            if goals.userId == nil {
                goals.userId = sessionUserId
            }
            
            await CloudSyncManager.shared.uploadUserGoalsImmediately(goals, userId: sessionUserId)
        }
    }

    // MARK: - Helper View Builders

    @ViewBuilder
    private func _buildGoalTextField(
        title: String,
        binding: Binding<Double>,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(primaryTextColor)

            Spacer()

            TextField("", value: binding, format: .number.precision(.fractionLength(0)))
                .font(.body.bold())
                .foregroundStyle(accentColor)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(inputBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(inputBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(unit)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 40, alignment: .leading)
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

    // MARK: - Adaptive Card Wrapper

    @ViewBuilder
    private func _adaptiveCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FrostedGlassContainer {
            content()
                .foregroundStyle(primaryTextColor)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Keyboard Helper

private extension View {
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
