// Screens/SavedFoodsView.swift

import SwiftUI
import SwiftData
import Auth
@preconcurrency import Supabase

struct SavedFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @Query private var savedFoods: [SavedFood]
    @Query private var userGoals: [UserGoals]
    
    private var energyUnit: EnergyUnit {
        userGoals.first?.energyUnit ?? .calories
    }
    
    init(userId: String) {
        let predicate = #Predicate<SavedFood> { $0.userId == userId }
        _savedFoods = Query(filter: predicate, sort: \.savedAt, order: .reverse)
    }
    
    @State private var searchText = ""
    @State private var showingSyncStatus = false
    @State private var foodToDelete: SavedFood?
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = true
    @FocusState private var searchFocused: Bool
    
    private var filteredFoods: [SavedFood] {
        if searchText.isEmpty {
            return savedFoods
        }
        return savedFoods.filter { food in
            food.foodName.localizedCaseInsensitiveContains(searchText) ||
            (food.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    var body: some View {
        ZStack {
            _buildDynamicBackground()
            
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(secondaryTextColor)
                    
                    TextField("Search saved foods...", text: $searchText)
                        .foregroundStyle(primaryTextColor)
                        .focused($searchFocused)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .padding()
                .background(Color("AppTextPrimary").opacity(colorScheme == .dark ? 0.12 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    searchFocused = true
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content
                if isLoading && savedFoods.isEmpty {
                    _buildSkeletonList()
                } else if filteredFoods.isEmpty {
                    _buildEmptyState()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredFoods) { food in
                                NavigationLink(value: HomeDestination.logProduct(food.toOFFProduct())) {
                                    SavedFoodCard(food: food, energyUnit: energyUnit, onDelete: {
                                        foodToDelete = food
                                        showingDeleteConfirmation = true
                                    })
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredFoods)
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Saved Foods")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Wait a minimum time to prevent flashing if sync is too fast
            let delayTask = Task { try? await Task.sleep(nanoseconds: 700_000_000) }
            await syncSavedFoods()
            _ = await delayTask.value
            
            withAnimation {
                isLoading = false
            }
        }
        .alert("Remove Saved Food?", isPresented: $showingDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let food = foodToDelete {
                    deleteSavedFood(food)
                }
                foodToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                foodToDelete = nil
            }
        } message: {
            Text("Are you sure you want to remove this food from your saved list?")
        }
    }
    
    @ViewBuilder
    private func _buildSkeletonList() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonSavedFoodCard()
                }
            }
            .padding()
        }
        .transition(.opacity)
    }
    
    @ViewBuilder
    private func _buildEmptyState() -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundStyle(secondaryTextColor.opacity(0.5))
            
            Text(searchText.isEmpty ? "No Saved Foods" : "No Results")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(primaryTextColor)
            
            Text(searchText.isEmpty
                 ? "Save your favorite foods for quick logging"
                 : "Try a different search term")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            // Base color
            Color(colorScheme == .dark ? "AppBackgroundDark" : "AppBackgroundLight")
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    accentColor.opacity(colorScheme == .dark ? 0.05 : 0.02),
                    Color.clear,
                    accentColor.opacity(colorScheme == .dark ? 0.03 : 0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    private func deleteSavedFood(_ food: SavedFood) {
        modelContext.delete(food)
        try? modelContext.save()
        
        // Delete from Supabase
        Task {
            if let userId = authManager.currentUser?.id {
                await SavedFoodsSync.deleteSavedFood(foodId: food.id.uuidString.lowercased(), userId: userId.uuidString.lowercased())
            }
        }
    }
    
    private func syncSavedFoods() async {
        guard let userId = authManager.currentUser?.id else { return }
        let userIdString = userId.uuidString.lowercased()
        
        // Upload any unsynced foods
        let unsyncedFoods = savedFoods.filter { !$0.isSynced }
        for food in unsyncedFoods {
            await SavedFoodsSync.uploadSavedFood(food, userId: userIdString)
            food.isSynced = true
        }
        try? modelContext.save()
        
        // Download from cloud
        await SavedFoodsSync.downloadSavedFoods(userId: userIdString, context: modelContext)
    }
}

// MARK: - Skeleton Card
struct SkeletonSavedFoodCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        FrostedGlassContainer {
            VStack(spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title skeleton
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .frame(width: 140, height: 20)
                        
                        // Subtitle skeleton
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                            .frame(width: 80, height: 14)
                        
                        // Tag skeleton
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                            .frame(width: 60, height: 20)
                    }
                    
                    Spacer()
                    
                    // Calories skeleton
                    VStack(alignment: .trailing, spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            .frame(width: 60, height: 32)
                    }
                }
                
                // Macro bars skeleton
                HStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                                .frame(width: 30, height: 10)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                                .frame(height: 6)
                        }
                    }
                }
                
                // Button placeholder
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                        .frame(width: 80, height: 28)
                }
            }
            .padding(4)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
        }
    }
}

// MARK: - Saved Food Card
struct SavedFoodCard: View {
    let food: SavedFood
    let energyUnit: EnergyUnit
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }
    
    var body: some View {
        FrostedGlassContainer {
            VStack(spacing: 16) {
                // Header Row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.foodName)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(2)
                        
                        if let brand = food.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                        }
                        
                        Text(food.servingSizeDescription)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(secondaryTextColor.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Calories Badge
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(displayedEnergy))")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.heavy)
                            .foregroundStyle(themeManager.currentTheme.primaryColor)
                        Text(energyUnit.unitLabel.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(themeManager.currentTheme.primaryColor.opacity(0.8))
                    }
                }
                
                // Macro Bars
                HStack(spacing: 12) {
                    MacroBar(label: "Prot", value: food.proteinPerServing, total: maxMacroValue, color: .pink)
                    MacroBar(label: "Carb", value: food.carbsPerServing, total: maxMacroValue, color: Color("AppSecondaryAccent"))
                    MacroBar(label: "Fat", value: food.fatPerServing, total: maxMacroValue, color: .orange)
                }
                
                // Footer (Delete Button)
                HStack {
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Remove")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(4)
        }
    }
    
    private var maxMacroValue: Double {
        max(food.proteinPerServing, max(food.carbsPerServing, food.fatPerServing))
    }
    
    private var displayedEnergy: Double {
        energyUnit == .kilojoules ? food.caloriesPerServing * 4.184 : food.caloriesPerServing
    }
}

// MARK: - Macro Bar Component
struct MacroBar: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Text("\(Int(value))g")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))
                    
                    if total > 0 {
                        Capsule()
                            .fill(color)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * (value / total))))
                    }
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Sync Helper
struct SavedFoodsSync {
    nonisolated static func uploadSavedFood(_ food: SavedFood, userId: String) async {
        do {
            let row = SavedFoodRow(from: food)
            
            try await supabase
                .database
                .from("saved_foods")
                .upsert(row)
                .execute()
            
            print("✅ Uploaded saved food: \(food.foodName)")
        } catch {
            print("❌ Failed to upload saved food: \(error)")
        }
    }
    
    nonisolated static func deleteSavedFood(foodId: String, userId: String) async {
        do {
            try await supabase
                .database
                .from("saved_foods")
                .delete()
                .eq("id", value: foodId)
                .execute()
            
            print("✅ Deleted saved food from cloud")
        } catch {
            print("❌ Failed to delete saved food: \(error)")
        }
    }
    
    nonisolated static func downloadSavedFoods(userId: String, context: ModelContext) async {
        do {
            let response = try await supabase
                .database
                .from("saved_foods")
                .select()
                .eq("user_id", value: userId)
                .order("saved_at", ascending: false)
                .execute()
            
            let results = try JSONDecoder().decode([SavedFoodRow].self, from: response.data)
            
            // Insert foods that don't exist locally
            for row in results {
                let foodId = row.id.lowercased()
                
                // Check if this food already exists
                let allSaved = try? context.fetch(FetchDescriptor<SavedFood>())
                let exists = allSaved?.contains(where: { $0.id.uuidString.lowercased() == foodId }) ?? false
                
                if !exists {
                    let newFood = row.toSavedFood()
                    context.insert(newFood)
                }
            }
            
            try? context.save()
            print("✅ Downloaded \(results.count) saved foods")
        } catch {
            print("❌ Failed to download saved foods: \(error)")
        }
    }
}
