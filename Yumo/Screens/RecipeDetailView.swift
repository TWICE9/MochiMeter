// Screens/RecipeDetailView.swift

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    
    let recipe: Recipe
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var tabRouter: TabRouter
    
    @State private var loadedGoals: UserGoals?

    private var energyUnit: EnergyUnit {
        loadedGoals?.energyUnit ?? .calories
    }
    
    private func convertEnergy(_ kcal: Double) -> Double {
        energyUnit == .kilojoules ? kcal * 4.184 : kcal
    }
    
    @State private var gettingReadyToEdit = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var scale: Double = 1.0
    @State private var showConfirmation = false
    
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }
    
    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.3, green: 0.3, blue: 0.3) : .white.opacity(0.7)
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color("AppSecondaryAccent"))
                            .shadow(color: Color("AppSecondaryAccent").opacity(0.3), radius: 10)
                        
                        Text(recipe.name)
                            .font(.largeTitle).bold()
                            .foregroundStyle(adaptiveTextColor)
                            .multilineTextAlignment(.center)
                        
                        Text("\(recipe.servings, specifier: "%.1f") servings")
                            .font(.headline)
                            .foregroundStyle(adaptiveSecondaryTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(adaptiveSecondaryTextColor.opacity(0.1))
                            )
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Macros Summary (Per Serving)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Per Serving")
                            .font(.headline)
                            .foregroundStyle(adaptiveSecondaryTextColor)
                            .padding(.horizontal, 4)
                        
                        HStack(spacing: 12) {
                            _buildMacroCard(title: "Calories", value: "\(Int(convertEnergy(recipe.caloriesPerServing))) \(energyUnit.unitLabel)", unit: energyUnit.unitLabel, color: Color("AppSecondaryAccent"))
                            _buildMacroCard(title: "Protein", value: String(format: "%.1fg", recipe.proteinPerServing), unit: "Protein", color: .blue)
                            _buildMacroCard(title: "Carbs", value: String(format: "%.1fg", recipe.carbsPerServing), unit: "Carbs", color: .green)
                            _buildMacroCard(title: "Fat", value: String(format: "%.1fg", recipe.fatPerServing), unit: "Fat", color: .orange)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // MARK: - Ingredients List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ingredients")
                            .font(.title3).bold()
                            .foregroundStyle(adaptiveTextColor)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 12) {
                            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                                ForEach(ingredients) { ingredient in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ingredient.name)
                                                .font(.body).fontWeight(.medium)
                                                .foregroundStyle(adaptiveTextColor)
                                            
                                            Text("\(ingredient.servingAmount, specifier: "%.2g") x \(ingredient.servingSizeDescription)")
                                                .font(.caption)
                                                .foregroundStyle(adaptiveSecondaryTextColor)
                                        }
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Int(convertEnergy(ingredient.totalCalories))) \(energyUnit.unitLabel)")
                                                .font(.callout).fontWeight(.semibold)
                                                .foregroundStyle(adaptiveTextColor)
                                        }
                                    }
                                    .padding()
                                    .background(FrostedGlassContainer { EmptyView() })
                                }
                            } else {
                                Text("No ingredients")
                                    .foregroundStyle(adaptiveSecondaryTextColor)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 16)
                    
                    // Log Button (Inline)
                    Button(action: logRecipe) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Log 1 Serving")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("AppPrimaryAccent"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color("AppPrimaryAccent").opacity(0.4), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                }
                .readableContentColumn(600)
            }
            .scrollContentBackground(.hidden)
            

        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                CreateRecipeView(existingRecipe: recipe)
            }
        }
        .alert("Delete Recipe?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
        } message: {
            Text("Are you sure you want to delete '\(recipe.name)'? This cannot be undone.")
        }
        .alert("Recipe Logged!", isPresented: $showConfirmation) {
            Button("Great!", role: .cancel) { }
        } message: {
            Text("One serving of \(recipe.name) has been added to your daily log.")
        }
        .task {
            loadedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
        }
    }
    
    // MARK: - Logic
    
    private func logRecipe() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let newLog = LoggedFood(
            name: recipe.name,
            timestamp: Date(),
            servingSizeDescription: "serving",
            servingAmount: 1.0,
            caloriesPerServing: recipe.caloriesPerServing,
            proteinPerServing: recipe.proteinPerServing,
            carbsPerServing: recipe.carbsPerServing,
            fatPerServing: recipe.fatPerServing,
            fiberPerServing: (recipe.ingredients ?? []).reduce(0) { $0 + $1.totalFiber } / (recipe.servings > 0 ? recipe.servings : 1),
            sugarPerServing: (recipe.ingredients ?? []).reduce(0) { $0 + $1.totalSugar } / (recipe.servings > 0 ? recipe.servings : 1),
            saltPerServing: (recipe.ingredients ?? []).reduce(0) { $0 + $1.totalSalt } / (recipe.servings > 0 ? recipe.servings : 1),
            potassiumPerServing: (recipe.ingredients ?? []).reduce(0) { $0 + $1.totalPotassium } / (recipe.servings > 0 ? recipe.servings : 1)
        )
        
        // Assign current User ID and Sync
        Task {
            let userId = await UserSession.shared.getCurrentUserId()
            
            await MainActor.run {
                newLog.userId = userId
                modelContext.insert(newLog)
                showConfirmation = true
            }
            
            // Sync to Supabase if user is logged in
            if let userId = userId {
                await CloudSyncManager.shared.uploadFoodLogImmediately(newLog, userId: userId)
            }
        }
    }
    
    private func deleteRecipe() {
        let recipeId = recipe.id.uuidString
        let userId = recipe.userId
        
        modelContext.delete(recipe)
        try? modelContext.save()
        
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteRecipeFromCloud(recipeId: recipeId, userId: userId)
            }
        }
        
        dismiss()
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func _buildMacroCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2).textCase(.uppercase)
                .foregroundStyle(adaptiveSecondaryTextColor)
            
            Text(value)
                .font(.title3).bold()
                .foregroundStyle(color)
            
            if unit != "kcal" && unit != "kJ" {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(adaptiveSecondaryTextColor)
                    .opacity(0)
                    .frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(FrostedGlassContainer { EmptyView() })
    }
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            if colorScheme == .light {
                RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.2), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                    .offset(x: -150, y: -150).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.3), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                    .offset(x: 100, y: 150).ignoresSafeArea()
            } else {
                 RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.1), .clear]), center: .topLeading, startRadius: 50, endRadius: 500)
                    .offset(x: -100, y: -100).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.05), .clear]), center: .bottomTrailing, startRadius: 50, endRadius: 450)
                    .offset(x: 100, y: 100).ignoresSafeArea()
            }
        }
        .blur(radius: 60)
    }
}
