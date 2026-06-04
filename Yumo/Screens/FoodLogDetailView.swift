// Screens/FoodLogDetailView.swift

import SwiftUI
import SwiftData
import WidgetKit
import UIKit
import Auth
@preconcurrency import Supabase

struct FoodLogDetailView: View {

    @Bindable var log: LoggedFood
    let goals: UserGoals

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }

    // Matches HomeScreen._getFoodIcon so the placeholder banner uses the same
    // SF Symbol shown next to the item in the recent logs list.
    private var placeholderFoodIcon: String {
        let lowerName = log.name.lowercased()

        if lowerName.contains("egg") { return "oval.portrait.fill" }
        if lowerName.contains("fish") || lowerName.contains("tuna") || lowerName.contains("salmon") || lowerName.contains("cod") || lowerName.contains("shrimp") || lowerName.contains("prawn") { return "fish.fill" }
        if lowerName.contains("milk") || lowerName.contains("dairy") || lowerName.contains("whey") || lowerName.contains("cheese") { return "refrigerator.fill" }
        if lowerName.contains("bread") || lowerName.contains("toast") || lowerName.contains("bagel") || lowerName.contains("sandwich") || lowerName.contains("wrap") || lowerName.contains("burger") || lowerName.contains("pizza") || lowerName.contains("potato") || lowerName.contains("fries") { return "takeoutbag.and.cup.and.straw.fill" }
        if lowerName.contains("salad") || lowerName.contains("lettuce") { return "leaf.fill" }
        if lowerName.contains("apple") || lowerName.contains("banana") || lowerName.contains("orange") || lowerName.contains("citrus") || lowerName.contains("berry") || lowerName.contains("strawberry") || lowerName.contains("blueberry") || lowerName.contains("watermelon") { return "carrot.fill" }
        if lowerName.contains("water") || lowerName.contains("drink") || lowerName.contains("honey") || lowerName.contains("syrup") { return "drop.fill" }
        if lowerName.contains("coffee") || lowerName.contains("espresso") || lowerName.contains("latte") { return "cup.and.saucer.fill" }

        let teaTestString = lowerName.replacingOccurrences(of: "tea spoon", with: "")
        let words = teaTestString.components(separatedBy: CharacterSet.alphanumerics.inverted)
        if words.contains("tea") || words.contains("teas") { return "mug.fill" }

        if lowerName.contains("chocolate") || lowerName.contains("candy") || lowerName.contains("sweet") || lowerName.contains("ice cream") || lowerName.contains("dessert") || lowerName.contains("cookie") || lowerName.contains("biscuit") || lowerName.contains("cake") || lowerName.contains("muffin") { return "birthday.cake.fill" }

        return "fork.knife"
    }

    @State private var showingDeleteConfirmation = false
    @State private var showEdit = false
    @State private var showMacroEditor = false
    @State private var macroToEdit: MacroType?
    @State private var displayImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showFixSheet = false
    @State private var isFixing = false
    @State private var fixError: String?
    @State private var isNameExpanded = false
    @ObservedObject private var storeKitManager = StoreKitManager.shared
    @State private var showPaywall = false
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showSavedFeedback = false
    @State private var savedToastMessage = "Food Saved!"
    @State private var savedToastIcon = "star.fill"
    @State private var savedToastIconColor: Color = .yellow

    // All SavedFoods — filtered in `matchingSavedFood` for the current user and log.
    @Query private var allSavedFoods: [SavedFood]

    private var currentSaveUserId: String {
        authManager.currentUser?.id.uuidString.lowercased() ?? log.userId ?? "anonymous"
    }

    private var matchingSavedFood: SavedFood? {
        let uid = currentSaveUserId
        return allSavedFoods.first { food in
            guard food.userId == uid else { return false }
            if let logBarcode = log.barcode, !logBarcode.isEmpty,
               let foodBarcode = food.barcode, !foodBarcode.isEmpty {
                return foodBarcode == logBarcode
            }
            return food.foodName == log.name && food.brand == log.brand
        }
    }

    private var isAlreadySaved: Bool { matchingSavedFood != nil }

    // Ingredient editor state
    @State private var showIngredientEditor = false
    @State private var ingredientToEdit: (name: String, calories: Double)?

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    _buildHeroHeader()

                    _buildMacroGrid()
                        .padding(.horizontal, 24)

                    // Fix Result Button (only for AI-scanned items)
                    if log.brand == "AI Analyzed" || log.aiConfidence != nil {
                        Button {
                            if storeKitManager.isPremium {
                                showFixSheet = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Fix result")
                                    .font(.headline)
                            }
                            .foregroundColor(adaptiveTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(buttonBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(cardBorderColor, lineWidth: 1.5)
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Show recipe ingredients if this is from a recipe
                    if let recipe = log.recipe, let ingredients = recipe.ingredients, !ingredients.isEmpty {
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ingredients")
                                    .font(.headline)
                                    .foregroundStyle(adaptiveTextColor)
                                
                                ForEach(ingredients) { ingredient in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ingredient.name)
                                                .font(.subheadline)
                                                .foregroundStyle(adaptiveTextColor)
                                            Text("\(ingredient.servingAmount, specifier: "%.1f") × \(ingredient.servingSizeDescription)")
                                                .font(.caption)
                                                .foregroundStyle(adaptiveSecondaryTextColor)
                                        }
                                        Spacer()
                                        Text("\(Int(convertEnergy(ingredient.totalCalories))) \(goals.energyUnit.unitLabel)")
                                            .font(.caption)
                                            .foregroundStyle(adaptiveSecondaryTextColor)
                                    }
                                    
                                    if ingredient.id != ingredients.last?.id {
                                        Divider()
                                            .background(adaptiveSecondaryTextColor.opacity(0.3))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Micronutrients")
                                .font(.headline).foregroundStyle(adaptiveTextColor)
                            _buildNutrientRow(title: "Fiber", value: log.totalFiber, unit: "g")
                            Divider().background(adaptiveSecondaryTextColor.opacity(0.3))
                            _buildNutrientRow(title: "Sugar", value: log.totalSugar, unit: "g")
                            Divider().background(adaptiveSecondaryTextColor.opacity(0.3))
                            _buildNutrientRow(title: "Salt", value: log.totalSalt, unit: "g")
                            Divider().background(adaptiveSecondaryTextColor.opacity(0.3))
                            _buildNutrientRow(title: "Potassium", value: log.totalPotassium, unit: "mg")
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Ingredient Calorie Breakdown (AI-analyzed foods only)
                    if let breakdown = log.aiIngredientCalories, !breakdown.isEmpty {
                        _buildIngredientBreakdownSection(breakdown)
                            .padding(.horizontal, 24)
                    }

                    _buildContributionSection()
                        .padding(.horizontal, 24)

                    Spacer(minLength: 60)
                }
                .padding(.bottom, 80)
                // iPad: cap to a readable column. iPhone: keep the container-width clamp
                // that disables horizontal rubber-band bounce (see note below).
                .readableContentColumn(600, clampOnCompact: true)
            }
            .scrollContentBackground(.hidden)
            // Disable horizontal rubber-band bounce. Even with the
            // ScrollView defaulting to vertical-only, iOS can still
            // allow elastic side-to-side motion if anything in the
            // layout reports a wider intrinsic size than the viewport
            // (which can happen with `.scaledToFill` images, AI
            // ingredient breakdowns, or just stray 1-2pt overshoots).
            // `.basedOnSize` only bounces on axes where content
            // actually overflows.
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onAppear {
                Task { await loadImageIfNeeded() }
                // Kill the nav bar's hairline/shadow so the transparent top
                // edge looks clean. `.toolbarBackground(.hidden)` hides the
                // fill but UIKit still draws a separator unless shadowColor
                // is explicitly cleared on both appearances.
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.shadowColor = .clear
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showEdit) {
            EditFoodLogView(log: log)
        }
        .sheet(isPresented: $showMacroEditor) {
            if let macro = macroToEdit {
                SingleMacroEditSheet(
                    log: log,
                    macro: macro,
                    goals: goals
                ) {
                    showMacroEditor = false
                    macroToEdit = nil
                }
            }
        }
        .sheet(isPresented: $showFixSheet) {
            FixAIResultSheet(
                current: logToFoodAnalysisResult(),
                isFixing: $isFixing,
                errorMessage: $fixError,
                onApply: { correction, _ in
                    applyFixedResult(correction)
                    showFixSheet = false
                }
            )
        }
        .sheet(isPresented: $showIngredientEditor) {
            if let ingredient = ingredientToEdit {
                IngredientEditSheet(
                    log: log,
                    ingredientName: ingredient.name,
                    ingredientCalories: ingredient.calories
                ) {
                    showIngredientEditor = false
                    ingredientToEdit = nil
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: "fix_ai_result")
        }
        .ignoresSafeArea(edges: .top)
        .alert("Delete this log?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Log", role: .destructive) {
                deleteLog()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .overlay(alignment: .top) {
            if showSavedFeedback {
                HStack(spacing: 12) {
                    Image(systemName: savedToastIcon)
                        .foregroundStyle(savedToastIconColor)
                        .font(.title3)
                    Text(savedToastMessage)
                        .font(.headline)
                        .foregroundStyle(adaptiveTextColor)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(radius: 10)
                .padding(.top, 10) // Safe area padding
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
    }

    private func deleteLog() {
        let logId = log.id.uuidString
        let userId = log.userId

        modelContext.delete(log)
        WidgetCenter.shared.reloadAllTimelines()

        // Delete from cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteFoodLogFromCloud(logId: logId, userId: userId)
            }
        }

        dismiss()
    }
    
    private func saveFood() {
        let savedFood = SavedFood(
            userId: authManager.currentUser?.id.uuidString.lowercased() ?? "anonymous",
            foodName: log.name,
            brand: log.brand,
            barcode: log.barcode,
            caloriesPerServing: log.caloriesPerServing,
            proteinPerServing: log.proteinPerServing,
            carbsPerServing: log.carbsPerServing,
            fatPerServing: log.fatPerServing,
            fiberPerServing: log.fiberPerServing,
            sugarPerServing: log.sugarPerServing,
            servingSizeDescription: log.servingSizeDescription,
            saltPerServing: log.saltPerServing,
            potassiumPerServing: log.potassiumPerServing,
            savedAt: Date(),
            isSynced: false
        )
        
        // Save locally
        modelContext.insert(savedFood)
        try? modelContext.save()
        
        // Sync to cloud
        if let userId = authManager.currentUser?.id {
             Task {
                 await SavedFoodsSync.uploadSavedFood(savedFood, userId: userId.uuidString.lowercased())
             }
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        savedToastMessage = "Food Saved!"
        savedToastIcon = "star.fill"
        savedToastIconColor = .yellow
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSavedFeedback = true
        }

        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedFeedback = false
            }
        }
    }

    private func unsaveFood(_ food: SavedFood) {
        let foodId = food.id.uuidString.lowercased()
        modelContext.delete(food)
        try? modelContext.save()

        if let userId = authManager.currentUser?.id {
            Task {
                await SavedFoodsSync.deleteSavedFood(foodId: foodId, userId: userId.uuidString.lowercased())
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        savedToastMessage = "Removed from Saved"
        savedToastIcon = "star.slash"
        savedToastIconColor = adaptiveSecondaryTextColor
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSavedFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedFeedback = false
            }
        }
    }

    private func logAgainToday() {
        let newItem = LoggedFood(
            name: log.name,
            timestamp: Date(),
            servingSizeDescription: log.servingSizeDescription,
            servingAmount: log.servingAmount,
            caloriesPerServing: log.caloriesPerServing,
            proteinPerServing: log.proteinPerServing,
            carbsPerServing: log.carbsPerServing,
            fatPerServing: log.fatPerServing,
            fiberPerServing: log.fiberPerServing,
            sugarPerServing: log.sugarPerServing,
            saltPerServing: log.saltPerServing,
            potassiumPerServing: log.potassiumPerServing,
            barcode: log.barcode,
            brand: log.brand,
            isHalal: log.isHalal,
            photoData: log.photoData,
            aiIngredients: log.aiIngredients
        )
        modelContext.insert(newItem)
        try? modelContext.save()

        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AnalyticsManager.shared.trackFoodLogged(name: log.name, calories: log.totalCalories, source: .barcode)

        if let userId = authManager.currentUser?.id.uuidString.lowercased() {
            Task.detached(priority: .background) {
                await MainActor.run { newItem.userId = userId }
                await CloudSyncManager.shared.uploadFoodLogImmediately(newItem, userId: userId)
            }
        }

        dismiss()
    }

    // MARK: - AI Fix Helpers

    private func logToFoodAnalysisResult() -> FoodAnalysisResult {
        return FoodAnalysisResult(
            name: log.name,
            servingSize: log.servingSizeDescription,
            calories: log.caloriesPerServing,
            protein: log.proteinPerServing,
            carbs: log.carbsPerServing,
            fat: log.fatPerServing,
            fiber: log.fiberPerServing,
            sugar: log.sugarPerServing,
            confidence: log.aiConfidence,
            ingredients: log.aiIngredients
        )
    }

    private func applyFixedResult(_ correction: String) {
        // Start analyzing state
        log.isAnalyzing = true
        try? modelContext.save()

        // Capture userId for cloud sync
        let userId = log.userId

        // Dismiss and navigate to home
        dismiss()

        // Run fix in background
        Task {
            do {
                let current = logToFoodAnalysisResult()
                let fixed = try await AIFoodScanner.shared.analyzeFoodCorrection(current: current, correction: correction)

                await MainActor.run {
                    log.name = fixed.name
                    log.servingSizeDescription = fixed.servingSize
                    log.caloriesPerServing = fixed.calories
                    log.proteinPerServing = fixed.protein
                    log.carbsPerServing = fixed.carbs
                    log.fatPerServing = fixed.fat
                    log.fiberPerServing = fixed.fiber
                    log.sugarPerServing = fixed.sugar
                    log.aiConfidence = fixed.confidence
                    log.aiIngredients = fixed.ingredients
                    log.isAnalyzing = false

                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                    NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                // Sync updated log to cloud
                if let userId = userId {
                    await CloudSyncManager.shared.uploadFoodLogImmediately(log, userId: userId)
                    print("✅ Fixed food log synced to cloud")
                }

                // Cache corrected values in master_foods for future users
                let upload = AIFoodUpload(from: fixed)
                try? await SupabaseService().upsertAIFood(upload)
                print("📈 Corrected food cached to master_foods: \(fixed.name)")
            } catch {
                await MainActor.run {
                    log.name = "Fix failed"
                    log.isAnalyzing = false
                    try? modelContext.save()
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    // MARK: - Hero
    @ViewBuilder
    private func _buildHeroHeader() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image only - no placeholder if no photo
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 500)
                    // `scaledToFill` can extend past the frame in either
                    // axis. `clipShape` below only clips the *render* — the
                    // layout-reported size still includes the overflow,
                    // which makes the parent ScrollView think it has
                    // horizontal content and enables side-scrolling. The
                    // explicit `.clipped()` constrains the reported size
                    // to the frame so vertical-only scroll behaves.
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 24,
                            bottomTrailingRadius: 24,
                            topTrailingRadius: 0
                        )
                    )
                    .ignoresSafeArea(edges: .top)
                    // Stretchy header — same pattern as RunDetailView's
                    // map. On overscroll-at-top, scale the image upward
                    // from its bottom anchor so it fills the bounce gap
                    // instead of revealing the page background.
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        let stretch = max(0, minY)
                        let scale = 1 + (stretch / 500)
                        return content.scaleEffect(
                            x: scale,
                            y: scale,
                            anchor: .bottom
                        )
                    }
            } else {
                // Decorative placeholder banner when no photo is available.
                // Uses an opaque base so the animated background orbs don't
                // bleed through as soft shadows behind the gradient tint.
                ZStack {
                    backgroundColor

                    LinearGradient(
                        colors: themeManager.currentTheme.buttonGradient(for: colorScheme).map { $0.opacity(colorScheme == .dark ? 0.22 : 0.14) },
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image(systemName: placeholderFoodIcon)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(Color("AppPrimaryAccent"))
                        .padding(.top, 40)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 0
                    )
                )
                .ignoresSafeArea(edges: .top)
                // Stretchy header for the placeholder banner case.
                // Same scale-from-bottom-anchor trick as the photo case.
                .visualEffect { content, proxy in
                    let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                    let stretch = max(0, minY)
                    let scale = 1 + (stretch / 240)
                    return content.scaleEffect(
                        x: scale,
                        y: scale,
                        anchor: .bottom
                    )
                }
            }

            // All details below the image
            VStack(alignment: .leading, spacing: 8) {
                Text(log.name)
                    .font(.largeTitle).bold()
                    .foregroundStyle(Color("AppTextPrimary"))
                    .lineLimit(isNameExpanded ? nil : 2)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isNameExpanded.toggle()
                        }
                    }

                if let brand = log.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                }

                // Date and AI Confidence inline
                HStack(spacing: 8) {
                    Text(log.timestamp, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))

                    if let confidence = log.aiConfidence, !confidence.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(confidenceColor(for: confidence))
                            Text(confidence.capitalized)
                                .font(.caption).bold()
                                .foregroundStyle(Color("AppTextPrimary"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(confidenceColor(for: confidence).opacity(0.2))
                        .clipShape(Capsule())
                    }
                }

                // Serving size with edit/delete buttons inline
                HStack {
                    Text("\(log.servingAmount, specifier: "%.1f") \(log.servingSizeDescription)")
                        .font(.headline)
                        .foregroundStyle(Color("AppTextPrimary"))

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            showEdit = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color("AppTextPrimary"))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Button {
                            if let matched = matchingSavedFood {
                                unsaveFood(matched)
                            } else {
                                saveFood()
                            }
                        } label: {
                            Image(systemName: isAlreadySaved ? "star.fill" : "star")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isAlreadySaved ? .yellow : Color("AppTextPrimary"))
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.yellow.opacity(isAlreadySaved ? 0.6 : 0), lineWidth: 1.5)
                                )
                                .animation(.easeInOut(duration: 0.2), value: isAlreadySaved)
                        }

                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }

                if !Calendar.current.isDateInToday(log.timestamp) {
                    Button {
                        logAgainToday()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Log again today")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color("AppTextPrimary"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ).opacity(0.25)
                            )
                        )
                        .overlay(
                            Capsule().stroke(Color("AppPrimaryAccent").opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                if log.isHalal {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color("AppTextPrimary"))
                        Text("Halal Certified")
                            .font(.caption).bold()
                            .foregroundStyle(Color("AppTextPrimary"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func _buildMacroGrid() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(adaptiveTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MacroStatCard(
                    icon: "flame.fill",
                    label: "Calories",
                    value: Int(convertEnergy(log.totalCalories)),
                    unit: " \(goals.energyUnit.unitLabel)",
                    iconColor: colorScheme == .light ? Color(red: 0.95, green: 0.6, blue: 0.4) : .orange,
                    isPrimary: true
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    macroToEdit = .calories
                    showMacroEditor = true
                }
                MacroStatCard(
                    icon: "leaf.fill",
                    label: "Carbs",
                    value: Int(log.totalCarbs),
                    unit: "g",
                    iconColor: colorScheme == .dark ? themeManager.currentTheme.darkSecondaryColor : themeManager.currentTheme.secondaryColor
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    macroToEdit = .carbs
                    showMacroEditor = true
                }
                MacroStatCard(
                    icon: "fork.knife",
                    label: "Protein",
                    value: Int(log.totalProtein),
                    unit: "g",
                    iconColor: .pink
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    macroToEdit = .protein
                    showMacroEditor = true
                }
                MacroStatCard(
                    icon: "drop.fill",
                    label: "Fat",
                    value: Int(log.totalFat),
                    unit: "g",
                    iconColor: .orange.opacity(0.8)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    macroToEdit = .fat
                    showMacroEditor = true
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .cornerRadius(20)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // default to calories if tapping elsewhere
            macroToEdit = .calories
            showMacroEditor = true
        }
    }

    @ViewBuilder
    private func _buildNutrientRow(title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(adaptiveSecondaryTextColor)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(adaptiveTextColor)
        }
    }
    
    @ViewBuilder
    private func _buildIngredientBreakdownSection(_ breakdown: [String: Double]) -> some View {
        let sortedBreakdown = breakdown.sorted { $0.value > $1.value } // Sort by calories descending
        let totalFromBreakdown = breakdown.values.reduce(0, +)
        
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(Color("AppPrimaryAccent"))
                    Text("Calorie Breakdown")
                        .font(.headline)
                        .foregroundStyle(adaptiveTextColor)
                    Spacer()
                    Text("Tap to edit")
                        .font(.caption)
                        .foregroundStyle(adaptiveSecondaryTextColor.opacity(0.6))
                }
                
                ForEach(sortedBreakdown, id: \.key) { ingredient, calories in
                    let percentage = totalFromBreakdown > 0 ? (calories / totalFromBreakdown) * 100 : 0
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(ingredient)
                                .font(.subheadline)
                                .foregroundStyle(adaptiveTextColor)
                            Spacer()
                            Text("\(Int(calories)) kcal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(adaptiveSecondaryTextColor)
                            Text("(\(Int(percentage))%)")
                                .font(.caption)
                                .foregroundStyle(adaptiveSecondaryTextColor.opacity(0.7))
                                .frame(width: 40, alignment: .trailing)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(adaptiveSecondaryTextColor.opacity(0.5))
                        }
                        
                        // Progress bar without GeometryReader. Track fills
                        // available width; the colored fill scales from
                        // the leading edge. GeometryReader inside a
                        // ScrollView tends to report unbounded widths
                        // during layout passes which can let the parent
                        // ScrollView's content width exceed the viewport
                        // and unlock horizontal panning.
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cardBackgroundColor)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color("AppPrimaryAccent").opacity(0.7))
                                .frame(height: 6)
                                .scaleEffect(x: max(0, min(percentage / 100, 1.0)), y: 1, anchor: .leading)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        ingredientToEdit = (name: ingredient, calories: calories)
                        showIngredientEditor = true
                    }
                    
                    if ingredient != sortedBreakdown.last?.key {
                        Divider()
                            .background(adaptiveSecondaryTextColor.opacity(0.2))
                    }
                }
            }
        }
    }
    
    private func convertEnergy(_ kcal: Double) -> Double {
        goals.energyUnit == .kilojoules ? kcal * 4.184 : kcal
    }

    private func downsampledImage(from data: Data, maxDimension: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func loadImageIfNeeded() async {
        guard displayImage == nil, !isLoadingImage else { return }
        isLoadingImage = true

        // Try local data first
        var imageData = log.photoData

        // If no local data, try downloading from cloud
        if imageData == nil, let cloudPath = log.cloudImagePath {
            print("📥 Downloading image from cloud: \(cloudPath)")
            if let downloadedData = await ImageStorageManager.shared.downloadImage(path: cloudPath) {
                imageData = downloadedData
                // Cache locally for future use
                await MainActor.run {
                    log.photoData = downloadedData
                }
            }
        }

        guard let data = imageData else {
            await MainActor.run { isLoadingImage = false }
            return
        }

        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1400
            ]
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cgImage)
            }
            return UIImage(data: data)
        }.value

        await MainActor.run {
            displayImage = image
            isLoadingImage = false
        }
    }
    
    private func confidenceColor(for confidence: String) -> Color {
        switch confidence.lowercased() {
        case "high":
            return .green
        case "medium":
            return .orange
        case "low":
            return .red
        default:
            return .gray
        }
    }

    @ViewBuilder
    private func _buildContributionSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("% of Daily Goals")
                .font(.headline)
                .foregroundStyle(adaptiveTextColor)

            ContributionRow(
                label: "Calories",
                value: Int(log.totalCalories),
                goal: Int(goals.dailyCalories),
                color: colorScheme == .light ? Color(red: 0.95, green: 0.6, blue: 0.4) : .orange
            )
            ContributionRow(
                label: "Protein",
                value: Int(log.totalProtein),
                goal: Int(goals.dailyProtein),
                color: .pink
            )
            ContributionRow(
                label: "Carbs",
                value: Int(log.totalCarbs),
                goal: Int(goals.dailyCarbs),
                color: Color("AppSecondaryAccent")
            )
            ContributionRow(
                label: "Fat",
                value: Int(log.totalFat),
                goal: Int(goals.dailyFat),
                color: .orange.opacity(0.8)
            )
        }
        .padding()
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .cornerRadius(20)
        .padding(.top, 8)
    }
}

struct MacroStatCard: View {
    let icon: String
    let label: String
    let value: Int
    let unit: String
    let iconColor: Color
    var isPrimary: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var cardBackground: Color {
        if colorScheme == .dark {
            return isPrimary ? Color.white.opacity(0.12) : Color.white.opacity(0.07)
        } else {
            return isPrimary ? Color.black.opacity(0.08) : Color.black.opacity(0.04)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(adaptiveSecondaryTextColor)
                Text("\(value)\(unit)")
                    .font(.title3).bold()
                    .foregroundColor(adaptiveTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            Spacer()
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContributionRow: View {
    let label: String
    let value: Int
    let goal: Int
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var progressBarBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }

    private var percentage: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(value) / Double(goal)) * 100)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(adaptiveSecondaryTextColor)
                .frame(width: 65, alignment: .leading)

            GeometryReader { geo in
                Capsule()
                    .fill(progressBarBackground)
                    .frame(height: 10)
                    .overlay(
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * progress, height: 10),
                        alignment: .leading
                    )
            }
            .frame(height: 10)

            Text("\(percentage)%")
                .font(.subheadline.bold())
                .foregroundColor(adaptiveTextColor)
                .frame(width: 45, alignment: .trailing)
        }
    }
}
