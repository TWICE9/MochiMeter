import SwiftUI
import SwiftData

struct IngredientEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var log: LoggedFood
    let originalName: String
    var onClose: () -> Void

    @State private var ingredientName: String
    @State private var ingredientCalories: Double
    @State private var showDeleteConfirm = false

    init(log: LoggedFood, ingredientName: String, ingredientCalories: Double, onClose: @escaping () -> Void) {
        self.log = log
        self.originalName = ingredientName
        self.onClose = onClose
        _ingredientName = State(initialValue: ingredientName)
        _ingredientCalories = State(initialValue: ingredientCalories)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Edit Ingredient")
                        .font(.largeTitle).bold()
                        .foregroundStyle(primaryTextColor)

                    VStack(spacing: 16) {
                        // Current ingredient preview
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color("AppPrimaryAccent").opacity(colorScheme == .dark ? 0.2 : 0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color("AppPrimaryAccent"))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ingredientName.isEmpty ? "Ingredient" : ingredientName)
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor)
                                    .lineLimit(1)
                                Text("\(Int(ingredientCalories)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor.opacity(0.9))

                            TextField("Ingredient name", text: $ingredientName)
                                .font(.title3)
                                .foregroundStyle(primaryTextColor)
                                .padding()
                                .background(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(cardBorderColor, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Calories field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calories")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor.opacity(0.9))

                            HStack {
                                TextField("0", value: $ingredientCalories, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.title.bold())
                                    .foregroundStyle(primaryTextColor)
                                    .onChange(of: ingredientCalories) { _, newValue in
                                        ingredientCalories = max(0, min(newValue, 5000))
                                    }
                                Text("kcal")
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .padding()
                            .background(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(cardBorderColor, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Delete Button
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Ingredient")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)

                    // Save Button
                    Button {
                        save()
                        onClose()
                    } label: {
                        Text("Save")
                            .font(.headline).bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("AppSecondaryAccent"))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { onClose() }
                        .foregroundStyle(primaryTextColor)
                }
            }
            .confirmationDialog("Remove this ingredient?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    deleteIngredient()
                    onClose()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func save() {
        var breakdown = log.aiIngredientCalories ?? [:]
        
        // Calculate the original calories for this ingredient
        let originalCalories = breakdown[originalName] ?? 0
        
        // Calculate the calorie difference
        let calorieDifference = ingredientCalories - originalCalories
        
        // If name changed, remove old entry
        if ingredientName != originalName {
            breakdown.removeValue(forKey: originalName)
        }
        
        // Update/add the entry with new values
        breakdown[ingredientName] = ingredientCalories
        log.aiIngredientCalories = breakdown
        
        // Update the food's total calories based on the difference
        if calorieDifference != 0 {
            log.caloriesPerServing = max(0, log.caloriesPerServing + calorieDifference)
            print("📊 Recalculated calories: \(calorieDifference > 0 ? "+" : "")\(Int(calorieDifference)) = \(Int(log.caloriesPerServing)) kcal")
        }
        
        try? modelContext.save()

        // Sync to cloud in background
        let userId = log.userId
        Task {
            if let userId = userId {
                await CloudSyncManager.shared.uploadFoodLogImmediately(log, userId: userId)
                print("✅ Ingredient edit synced to cloud")
            }
        }
    }
    
    private func deleteIngredient() {
        var breakdown = log.aiIngredientCalories ?? [:]
        
        // Get the calories being removed
        let removedCalories = breakdown[originalName] ?? 0
        
        breakdown.removeValue(forKey: originalName)
        log.aiIngredientCalories = breakdown.isEmpty ? nil : breakdown
        
        // Subtract the removed ingredient's calories from total
        if removedCalories > 0 {
            log.caloriesPerServing = max(0, log.caloriesPerServing - removedCalories)
            print("📊 Removed \(Int(removedCalories)) kcal from total. New total: \(Int(log.caloriesPerServing)) kcal")
        }
        
        try? modelContext.save()

        // Sync to cloud in background
        let userId = log.userId
        Task {
            if let userId = userId {
                await CloudSyncManager.shared.uploadFoodLogImmediately(log, userId: userId)
                print("✅ Ingredient deletion synced to cloud")
            }
        }
    }

    // MARK: - Colors
    
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 248/255, green: 248/255, blue: 250/255)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.7)
            : Color(red: 120/255, green: 120/255, blue: 128/255)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.05)
    }
}
