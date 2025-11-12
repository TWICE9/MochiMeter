// Screens/CreateRecipeView.swift

import SwiftUI
import SwiftData

struct CreateRecipeView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // --- API & DB Services ---
    private let apiService = OpenFoodFactsService()
    @Query private var allCommonFoods: [CommonFood]

    // --- Recipe State ---
    @State private var recipeName: String = ""
    @State private var recipeServings: Int = 4

    // --- Ingredient State ---
    @State private var ingredientSearchText: String = ""
    @State private var commonFoodResults: [CommonFood] = []
    @State private var apiSearchResults: [OFFProduct] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Error>?

    // Added ingredients
    @State private var addedIngredients: [RecipeIngredient] = []

    // Sheet states
    @State private var ingredientToAdd: IngredientToAdd?
    @State private var ingredientToEdit: RecipeIngredient?
    @State private var showingSearch = false

    // --- Background Animation ---
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    // MARK: - Helper struct for ingredient being added
    struct IngredientToAdd: Identifiable {
        let id = UUID()
        let name: String
        let servingDescription: String
        let caloriesPerServing: Double
        let proteinPerServing: Double
        let carbsPerServing: Double
        let fatPerServing: Double
        var amount: Double = 1.0
    }

    // MARK: - Helper struct for added ingredients
    struct RecipeIngredient: Identifiable {
        let id = UUID()
        var name: String
        var servingDescription: String
        var amount: Double
        var caloriesPerServing: Double
        var proteinPerServing: Double
        var carbsPerServing: Double
        var fatPerServing: Double

        var totalCalories: Double { caloriesPerServing * amount }
        var totalProtein: Double { proteinPerServing * amount }
        var totalCarbs: Double { carbsPerServing * amount }
        var totalFat: Double { fatPerServing * amount }
    }

    // MARK: - Adaptive Colors
    private var primaryText: Color {
        colorScheme == .light ? Color(red: 34/255, green: 34/255, blue: 40/255) : .white
    }
    private var secondaryText: Color {
        colorScheme == .light ? Color(red: 120/255, green: 120/255, blue: 130/255) : .white.opacity(0.7)
    }
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color.white.opacity(0.06)
    }
    private var inputBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.1)
    }
    private var accentColor: Color {
        colorScheme == .light ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color("AppSecondaryAccent")
    }

    // MARK: - Computed Totals
    private var totalCalories: Double { addedIngredients.reduce(0) { $0 + $1.totalCalories } }
    private var totalProtein: Double { addedIngredients.reduce(0) { $0 + $1.totalProtein } }
    private var totalCarbs: Double { addedIngredients.reduce(0) { $0 + $1.totalCarbs } }
    private var totalFat: Double { addedIngredients.reduce(0) { $0 + $1.totalFat } }

    private var caloriesPerServing: Double { Double(recipeServings) > 0 ? totalCalories / Double(recipeServings) : 0 }
    private var proteinPerServing: Double { Double(recipeServings) > 0 ? totalProtein / Double(recipeServings) : 0 }
    private var carbsPerServing: Double { Double(recipeServings) > 0 ? totalCarbs / Double(recipeServings) : 0 }
    private var fatPerServing: Double { Double(recipeServings) > 0 ? totalFat / Double(recipeServings) : 0 }

    // MARK: - Body
    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Recipe Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryText)

                        TextField("e.g., Chicken Stir Fry", text: $recipeName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(primaryText)
                            .padding(16)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // MARK: - Servings Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How many servings does this make?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(secondaryText)

                        HStack(spacing: 0) {
                            ForEach([1, 2, 4, 6, 8], id: \.self) { num in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        recipeServings = num
                                    }
                                } label: {
                                    Text("\(num)")
                                        .font(.headline)
                                        .fontWeight(recipeServings == num ? .bold : .medium)
                                        .foregroundStyle(recipeServings == num ? .white : primaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            recipeServings == num
                                                ? accentColor
                                                : cardBackground
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)

                    // MARK: - Ingredients Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Ingredients")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(primaryText)

                            Spacer()

                            if !addedIngredients.isEmpty {
                                Text("\(addedIngredients.count) items")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }
                        }

                        // Add Ingredient Button
                        Button {
                            showingSearch = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(accentColor)

                                Text("Add Ingredient")
                                    .font(.headline)
                                    .foregroundStyle(primaryText)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }
                            .padding(16)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        // Ingredient List
                        if !addedIngredients.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(addedIngredients.enumerated()), id: \.element.id) { index, ingredient in
                                    _buildIngredientRow(ingredient: ingredient, index: index)

                                    if index < addedIngredients.count - 1 {
                                        Divider()
                                            .background(secondaryText.opacity(0.2))
                                    }
                                }
                            }
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: - Nutrition Summary
                    if !addedIngredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nutrition Per Serving")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(primaryText)

                            VStack(spacing: 16) {
                                // Calories - prominent
                                HStack {
                                    Text("Calories")
                                        .font(.headline)
                                        .foregroundStyle(primaryText)
                                    Spacer()
                                    Text("\(Int(caloriesPerServing))")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(accentColor)
                                    Text("kcal")
                                        .font(.subheadline)
                                        .foregroundStyle(secondaryText)
                                }

                                Divider().background(secondaryText.opacity(0.2))

                                // Macros row
                                HStack(spacing: 20) {
                                    _buildMacroBox(label: "Protein", value: proteinPerServing, color: .pink)
                                    _buildMacroBox(label: "Carbs", value: carbsPerServing, color: accentColor)
                                    _buildMacroBox(label: "Fat", value: fatPerServing, color: .orange)
                                }

                                // Total recipe info
                                HStack {
                                    Text("Total recipe: \(Int(totalCalories)) kcal")
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                    Spacer()
                                }
                            }
                            .padding(16)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                    }

                    // Save Button (at bottom of content)
                    Button {
                        saveRecipe()
                    } label: {
                        Text("Save Recipe")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(canSave ? accentColor : Color.gray.opacity(0.5))
                            )
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("New Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSearch) {
            IngredientSearchSheet(
                onSelect: { ingredient in
                    ingredientToAdd = ingredient
                    showingSearch = false
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $ingredientToAdd) { ingredient in
            AddIngredientSheet(
                ingredient: ingredient,
                onAdd: { finalIngredient in
                    addedIngredients.append(finalIngredient)
                    ingredientToAdd = nil
                },
                onCancel: {
                    ingredientToAdd = nil
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $ingredientToEdit) { ingredient in
            EditIngredientSheet(
                ingredient: ingredient,
                onSave: { updated in
                    if let index = addedIngredients.firstIndex(where: { $0.id == updated.id }) {
                        addedIngredients[index] = updated
                    }
                    ingredientToEdit = nil
                },
                onCancel: {
                    ingredientToEdit = nil
                }
            )
            .presentationDetents([.medium])
        }
    }

    private var canSave: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !addedIngredients.isEmpty
    }

    // MARK: - View Builders

    @ViewBuilder
    private func _buildIngredientRow(ingredient: RecipeIngredient, index: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(primaryText)
                    .lineLimit(1)

                Text("\(ingredient.amount, specifier: "%.1f") × \(ingredient.servingDescription)")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }

            Spacer()

            Text("\(Int(ingredient.totalCalories)) kcal")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(accentColor)

            // Edit button
            Button {
                ingredientToEdit = ingredient
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(secondaryText.opacity(0.6))
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = addedIngredients.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    @ViewBuilder
    private func _buildMacroBox(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))g")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save Logic

    private func saveRecipe() {
        Task {
            let userId = await UserSession.shared.getCurrentUserId()

            let newRecipe = Recipe(
                name: recipeName.trimmingCharacters(in: .whitespacesAndNewlines),
                servings: Double(recipeServings)
            )
            newRecipe.userId = userId
            modelContext.insert(newRecipe)

            for ingredient in addedIngredients {
                let loggedFood = LoggedFood(
                    name: ingredient.name,
                    servingSizeDescription: ingredient.servingDescription,
                    servingAmount: ingredient.amount,
                    caloriesPerServing: ingredient.caloriesPerServing,
                    proteinPerServing: ingredient.proteinPerServing,
                    carbsPerServing: ingredient.carbsPerServing,
                    fatPerServing: ingredient.fatPerServing
                )
                loggedFood.userId = userId
                loggedFood.recipe = newRecipe
                modelContext.insert(loggedFood)
            }

            do {
                try modelContext.save()
                dismiss()
            } catch {
                print("Failed to save recipe: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        let baseColor = colorScheme == .light ? Color(red: 244/255, green: 245/255, blue: 247/255) : Color("AppPrimaryDark")
        ZStack {
            baseColor.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(colorScheme == .light ? 0.15 : 0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(colorScheme == .light ? 0.1 : 0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                .offset(offset2).offset(x: 100, y: 150).ignoresSafeArea()
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

// MARK: - Ingredient Search Sheet

struct IngredientSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var allCommonFoods: [CommonFood]

    let onSelect: (CreateRecipeView.IngredientToAdd) -> Void

    @State private var searchText = ""
    @State private var commonFoodResults: [CommonFood] = []
    @State private var apiSearchResults: [OFFProduct] = []
    @State private var cloudFoodResults: [MasterFoodRow] = []
    @State private var isLoading = false
    @State private var isAICreating = false
    @State private var searchTask: Task<Void, Error>?
    @State private var aiError: String?

    private let apiService = OpenFoodFactsService()
    private let supabaseService = SupabaseService()

    private var primaryText: Color {
        colorScheme == .light ? Color(red: 34/255, green: 34/255, blue: 40/255) : .white
    }
    private var secondaryText: Color {
        colorScheme == .light ? Color(red: 120/255, green: 120/255, blue: 130/255) : .white.opacity(0.7)
    }
    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color.white.opacity(0.08)
    }
    private var accentColor: Color {
        colorScheme == .light ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color("AppSecondaryAccent")
    }
    private var aiGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .light
                ? [Color(red: 0.3, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.5, blue: 0.9)]
                : [Color("AppPrimaryAccent"), Color("AppSecondaryAccent")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var hasNoResults: Bool {
        !searchText.isEmpty && commonFoodResults.isEmpty && apiSearchResults.isEmpty && cloudFoodResults.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(secondaryText)

                    TextField("Search ingredients...", text: $searchText)
                        .foregroundStyle(primaryText)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Results
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(accentColor)
                                .padding(.top, 40)
                        } else if searchText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife")
                                    .font(.largeTitle)
                                    .foregroundStyle(secondaryText.opacity(0.5))
                                Text("Search for ingredients")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }
                            .padding(.top, 60)
                        } else {
                            // Common foods
                            if !commonFoodResults.isEmpty {
                                Section {
                                    ForEach(commonFoodResults) { food in
                                        _buildResultRow(
                                            name: food.name,
                                            serving: food.servingSizeDescription,
                                            calories: food.caloriesPerServing
                                        ) {
                                            onSelect(CreateRecipeView.IngredientToAdd(
                                                name: food.name,
                                                servingDescription: food.servingSizeDescription,
                                                caloriesPerServing: food.caloriesPerServing,
                                                proteinPerServing: food.proteinPerServing,
                                                carbsPerServing: food.carbsPerServing,
                                                fatPerServing: food.fatPerServing
                                            ))
                                        }
                                    }
                                } header: {
                                    Text("Your Foods")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 16)
                                }
                            }

                            // API results
                            if !apiSearchResults.isEmpty {
                                Section {
                                    ForEach(apiSearchResults) { product in
                                        _buildResultRow(
                                            name: product.productName ?? "Unknown",
                                            serving: product.servingSize ?? "1 serving",
                                            calories: product.nutriments?.servingCalories ?? 0
                                        ) {
                                            onSelect(CreateRecipeView.IngredientToAdd(
                                                name: product.productName ?? "Unknown",
                                                servingDescription: product.servingSize ?? "1 serving",
                                                caloriesPerServing: product.nutriments?.servingCalories ?? 0,
                                                proteinPerServing: product.nutriments?.servingProtein ?? 0,
                                                carbsPerServing: product.nutriments?.servingCarbs ?? 0,
                                                fatPerServing: product.nutriments?.servingFat ?? 0
                                            ))
                                        }
                                    }
                                } header: {
                                    Text("Database")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 16)
                                }
                            }

                            // Cloud foods (AI-created by community)
                            if !cloudFoodResults.isEmpty {
                                Section {
                                    ForEach(cloudFoodResults) { food in
                                        _buildResultRow(
                                            name: food.foodName,
                                            serving: "1 serving (100g)",
                                            calories: food.calories
                                        ) {
                                            onSelect(CreateRecipeView.IngredientToAdd(
                                                name: food.foodName,
                                                servingDescription: "1 serving (100g)",
                                                caloriesPerServing: food.calories,
                                                proteinPerServing: food.protein,
                                                carbsPerServing: food.carbs,
                                                fatPerServing: food.fat
                                            ))
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.caption2)
                                        Text("Community AI Foods")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 16)
                                }
                            }

                            // No results - show AI create option
                            if hasNoResults {
                                VStack(spacing: 20) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.largeTitle)
                                            .foregroundStyle(aiGradient)
                                        Text("Can't find \"\(searchText)\"?")
                                            .font(.headline)
                                            .foregroundStyle(primaryText)
                                        Text("Let AI estimate the nutrition")
                                            .font(.subheadline)
                                            .foregroundStyle(secondaryText)
                                    }
                                    .padding(.top, 40)

                                    Button {
                                        Task { await createWithAI() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            if isAICreating {
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(0.9)
                                            } else {
                                                Image(systemName: "sparkles")
                                                    .font(.subheadline.bold())
                                            }
                                            Text(isAICreating ? "Analyzing..." : "Create with AI")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(aiGradient)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isAICreating)
                                    .buttonStyle(.plain)

                                    if let error = aiError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(colorScheme == .light ? Color(red: 244/255, green: 245/255, blue: 247/255) : Color("AppPrimaryDark"))
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            handleSearch(for: newValue)
        }
    }

    @ViewBuilder
    private func _buildResultRow(name: String, serving: String, calories: Double, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                    Text(serving)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                Text("\(Int(calories)) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(accentColor)
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func handleSearch(for term: String) {
        searchTask?.cancel()
        aiError = nil

        if term.isEmpty {
            commonFoodResults = []
            apiSearchResults = []
            cloudFoodResults = []
            isLoading = false
            return
        }

        // Immediately filter local foods (instant)
        commonFoodResults = allCommonFoods.filter {
            $0.name.lowercased().contains(term.lowercased())
        }

        // Only show loading if no local results
        if commonFoodResults.isEmpty {
            isLoading = true
        }

        searchTask = Task {
            // Short debounce (200ms)
            try await Task.sleep(nanoseconds: 200_000_000)

            // Launch both searches independently - results appear as they arrive
            Task {
                do {
                    let cloudFoods = try await supabaseService.searchFoodsByName(term, limit: 10)
                    await MainActor.run {
                        cloudFoodResults = cloudFoods
                        // Hide loading if we got cloud results
                        if !cloudFoods.isEmpty { isLoading = false }
                    }
                } catch {
                    await MainActor.run { cloudFoodResults = [] }
                }
            }

            Task {
                do {
                    let products = try await apiService.searchFoodByName(term, page: 1)
                    await MainActor.run {
                        apiSearchResults = products
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        apiSearchResults = []
                        isLoading = false
                    }
                }
            }
        }
    }

    private func createWithAI() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        await MainActor.run {
            isAICreating = true
            aiError = nil
        }

        do {
            // Use AI to analyze the food description
            let result = try await AIFoodScanner.shared.analyzeMealDescription(query)

            // Save to local database for future searches
            let newFood = CommonFood(
                name: result.name,
                barcode: result.generateAIBarcode(),
                caloriesPerServing: result.calories,
                proteinPerServing: result.protein,
                carbsPerServing: result.carbs,
                fatPerServing: result.fat,
                fiberPerServing: result.fiber,
                sugarPerServing: result.sugar,
                servingSizeDescription: result.servingSize
            )

            // Create upload payload while we have access to result (before leaving main actor context)
            let upload = AIFoodUpload(from: result)

            await MainActor.run {
                modelContext.insert(newFood)
                try? modelContext.save()
                isAICreating = false

                // Return the ingredient
                onSelect(CreateRecipeView.IngredientToAdd(
                    name: result.name,
                    servingDescription: result.servingSize,
                    caloriesPerServing: result.calories,
                    proteinPerServing: result.protein,
                    carbsPerServing: result.carbs,
                    fatPerServing: result.fat
                ))
            }

            // Upload to Supabase so other users can benefit from this AI-created food
            Task.detached {
                try? await SupabaseService().upsertAIFood(upload)
            }
        } catch {
            await MainActor.run {
                isAICreating = false
                aiError = "Failed to analyze: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Add Ingredient Sheet

struct AddIngredientSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let ingredient: CreateRecipeView.IngredientToAdd
    let onAdd: (CreateRecipeView.RecipeIngredient) -> Void
    let onCancel: () -> Void

    @State private var amount: Double = 1.0

    private var primaryText: Color {
        colorScheme == .light ? Color(red: 34/255, green: 34/255, blue: 40/255) : .white
    }
    private var secondaryText: Color {
        colorScheme == .light ? Color(red: 120/255, green: 120/255, blue: 130/255) : .white.opacity(0.7)
    }
    private var accentColor: Color {
        colorScheme == .light ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color("AppSecondaryAccent")
    }

    private var totalCalories: Double { ingredient.caloriesPerServing * amount }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Ingredient info
                VStack(spacing: 8) {
                    Text(ingredient.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)

                    Text(ingredient.servingDescription)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .padding(.top, 8)

                // Amount picker
                VStack(spacing: 12) {
                    Text("How many servings?")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)

                    HStack(spacing: 20) {
                        Button {
                            if amount > 0.5 { amount -= 0.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(amount > 0.5 ? accentColor : secondaryText.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(amount <= 0.5)

                        Text("\(amount, specifier: "%.1f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                            .frame(minWidth: 100)

                        Button {
                            amount += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Calories preview
                VStack(spacing: 4) {
                    Text("\(Int(totalCalories))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)
                    Text("calories")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                // Add button
                Button {
                    let newIngredient = CreateRecipeView.RecipeIngredient(
                        name: ingredient.name,
                        servingDescription: ingredient.servingDescription,
                        amount: amount,
                        caloriesPerServing: ingredient.caloriesPerServing,
                        proteinPerServing: ingredient.proteinPerServing,
                        carbsPerServing: ingredient.carbsPerServing,
                        fatPerServing: ingredient.fatPerServing
                    )
                    onAdd(newIngredient)
                } label: {
                    Text("Add Ingredient")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .background(colorScheme == .light ? Color(red: 244/255, green: 245/255, blue: 247/255) : Color("AppPrimaryDark"))
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }
}

// MARK: - Edit Ingredient Sheet

struct EditIngredientSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let ingredient: CreateRecipeView.RecipeIngredient
    let onSave: (CreateRecipeView.RecipeIngredient) -> Void
    let onCancel: () -> Void

    @State private var amount: Double

    init(ingredient: CreateRecipeView.RecipeIngredient, onSave: @escaping (CreateRecipeView.RecipeIngredient) -> Void, onCancel: @escaping () -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        self.onCancel = onCancel
        self._amount = State(initialValue: ingredient.amount)
    }

    private var primaryText: Color {
        colorScheme == .light ? Color(red: 34/255, green: 34/255, blue: 40/255) : .white
    }
    private var secondaryText: Color {
        colorScheme == .light ? Color(red: 120/255, green: 120/255, blue: 130/255) : .white.opacity(0.7)
    }
    private var accentColor: Color {
        colorScheme == .light ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color("AppSecondaryAccent")
    }

    private var totalCalories: Double { ingredient.caloriesPerServing * amount }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(ingredient.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)

                    Text(ingredient.servingDescription)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    Text("Servings")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)

                    HStack(spacing: 20) {
                        Button {
                            if amount > 0.5 { amount -= 0.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                                .foregroundStyle(amount > 0.5 ? accentColor : secondaryText.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .disabled(amount <= 0.5)

                        Text("\(amount, specifier: "%.1f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                            .frame(minWidth: 100)

                        Button {
                            amount += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 4) {
                    Text("\(Int(totalCalories))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)
                    Text("calories")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }

                Spacer()

                Button {
                    var updated = ingredient
                    updated.amount = amount
                    onSave(updated)
                } label: {
                    Text("Save Changes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .background(colorScheme == .light ? Color(red: 244/255, green: 245/255, blue: 247/255) : Color("AppPrimaryDark"))
            .navigationTitle("Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }
}
