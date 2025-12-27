//
//  RecipeListView.swift
//  Yumo
//
//  Created by Apple on 13/11/2025.
//


// Screens/RecipeListView.swift

import SwiftUI
import SwiftData
import Combine


struct RecipeListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    // 1. State to hold user-scoped recipes
    @State private var recipes: [Recipe] = []

    // State for navigating to a selected recipe
    @State private var selectedRecipe: Recipe?

    // State for background animation
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    // Adaptive colors for light/dark mode
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.3, green: 0.3, blue: 0.3) : .white.opacity(0.7)
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()
            
            ScrollView {
                VStack(spacing: 16) {
                    
                    // 2. Check if recipes exist
                    if recipes.isEmpty {
                        // --- Placeholder View ---
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundStyle(Color("AppSecondaryAccent"))

                            Text("No Recipes Yet")
                                .font(.title2).bold()
                                .foregroundStyle(adaptiveTextColor)

                            Text("Recipes you create will appear here. Get started by tapping the '+' button.")
                                .font(.subheadline)
                                .foregroundStyle(adaptiveSecondaryTextColor)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .background(FrostedGlassContainer { EmptyView() })
                        .padding(.top, 100)
                        
                    } else {
                        // --- Recipe List ---
                        ForEach(recipes) { recipe in
                            // Tapping a row will navigate to its detail view
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                _buildRecipeRow(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteRecipe(recipe)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
                .padding(.top, 20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("My Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // 3. Button to navigate to the Create Recipe screen
                NavigationLink(destination: CreateRecipeView()) {
                    Image(systemName: "plus")
                        .font(.headline).bold()
                        .foregroundStyle(Color("AppSecondaryAccent"))
                }
            }
        }
        .task {
            await refreshData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshData() }
            }
        }
    }

    // MARK: - Data Refresh

    private func refreshData() async {
        recipes = await UserScopedQuery.fetchRecipes(context: modelContext)
    }

    private func deleteRecipe(_ recipe: Recipe) {
        let recipeId = recipe.id.uuidString
        let userId = recipe.userId

        // Delete from local database
        modelContext.delete(recipe)

        // Delete from cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteRecipeFromCloud(recipeId: recipeId, userId: userId)
            }
        }

        // Refresh data to update UI
        Task { await refreshData() }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private func _buildRecipeRow(recipe: Recipe) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(adaptiveTextColor)

                Text("\(recipe.servings, specifier: "%.0f") servings")
                    .font(.caption)
                    .foregroundStyle(adaptiveSecondaryTextColor)
            }

            Spacer()

            // Show nutrition per serving
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(recipe.caloriesPerServing, specifier: "%.0f") kcal")
                    .font(.callout).bold()
                    .foregroundStyle(Color("AppSecondaryAccent"))

                Text("per serving")
                    .font(.caption2)
                    .foregroundStyle(adaptiveSecondaryTextColor)
            }
        }
        .padding()
        .background(FrostedGlassContainer { EmptyView() })
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
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
