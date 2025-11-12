// Models/Recipe.swift

import Foundation
import SwiftData

@Model
final class Recipe {

    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var name: String
    var servings: Double // How many servings this recipe makes (e.g., 4.0)
    
    // This is the list of ingredients.
    // We use .cascade so that if you delete the recipe,
    // all its hidden ingredient logs are deleted too.
    @Relationship(deleteRule: .cascade, inverse: \LoggedFood.recipe)
    var ingredients: [LoggedFood]? = []
    
    init(
        id: UUID = UUID(),
        name: String,
        servings: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.servings = servings
    }
    
    // MARK: - Computed Properties for Totals
    
    var totalCalories: Double {
        (ingredients ?? []).reduce(0) { $0 + $1.totalCalories }
    }
    
    var totalProtein: Double {
        (ingredients ?? []).reduce(0) { $0 + $1.totalProtein }
    }
    
    var totalCarbs: Double {
        (ingredients ?? []).reduce(0) { $0 + $1.totalCarbs }
    }
    
    var totalFat: Double {
        (ingredients ?? []).reduce(0) { $0 + $1.totalFat }
    }
    
    // MARK: - Computed Properties per Serving
    
    var caloriesPerServing: Double {
        guard servings > 0 else { return 0 }
        return totalCalories / servings
    }
    
    var proteinPerServing: Double {
        guard servings > 0 else { return 0 }
        return totalProtein / servings
    }
    
    var carbsPerServing: Double {
        guard servings > 0 else { return 0 }
        return totalCarbs / servings
    }
    
    var fatPerServing: Double {
        guard servings > 0 else { return 0 }
        return totalFat / servings
    }
}
