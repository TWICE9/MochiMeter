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

    private var placeholderFoodIcon: String {
        let icons = ["food-icon-1", "food-icon-2", "food-icon-3", "food-icon-4", "food-icon-5"]
        let index = abs(log.name.hashValue) % icons.count
        return icons[index]
    }

    @State private var showingDeleteConfirmation = false
    @State private var showEdit = false
    @State private var showMacroEditor = false
    @State private var macroToEdit: MacroType?
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var displayImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showFixSheet = false
    @State private var isFixing = false
    @State private var fixError: String?
    @State private var isNameExpanded = false
    @ObservedObject private var superwallManager = SuperwallManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showSavedFeedback = false

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 12) {
                    _buildHeroHeader()

                    _buildMacroGrid()
                        .padding(.horizontal, 24)

                    // Fix Result Button (only for AI-scanned items)
                    if log.brand == "AI Analyzed" || log.aiConfidence != nil {
                        Button {
                            if superwallManager.isPremium {
                                showFixSheet = true
                            } else {
                                superwallManager.showPaywall()
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

                    _buildContributionSection()
                        .padding(.horizontal, 24)

                    Spacer(minLength: 60)
                }
                .padding(.bottom, 80)
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                Task { await loadImageIfNeeded() }
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
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.title3)
                    Text("Food Saved!")
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
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 24,
                            bottomTrailingRadius: 24,
                            topTrailingRadius: 0
                        )
                    )
                    .ignoresSafeArea(edges: .top)
            } else {
                // Add top spacing for safe area when no image
                Spacer().frame(height: 100)
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
                            saveFood()
                        } label: {
                            Image(systemName: "star")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color("AppTextPrimary")) // Could change to yellow if checked
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
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
    private func _buildDynamicBackground() -> some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(colorScheme == .dark ? 0.3 : 0.2), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(colorScheme == .dark ? 0.4 : 0.25), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                .offset(offset2).offset(x: 100, y: 150).ignoresSafeArea()
        }
        .blur(radius: 60)
        .onAppear { animateOrbs() }
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
    
    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
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
